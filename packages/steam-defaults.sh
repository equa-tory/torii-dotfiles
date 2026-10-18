#!/usr/bin/env bash
# Defaults for every Steam game (Proton): gamemode around the game, and GE-Proton as the compatibility tool.
#   bash packages/steam-defaults.sh        (run it again after installing new games)
# - every installed game that has no launch options gets "gamemoderun %command%" (yours are kept as they are)
# - GE-Proton (newest in compatibilitytools.d) becomes the default tool for all games, unless a default is already set
# The env vars that are good for every Proton game (PROTON_ENABLE_NVAPI, PROTON_USE_NTSYNC) are in .config/uwsm/env.
# Steam rewrites its config files when it quits, so it must be closed for this (a copy of each file is kept as *.torii-bak).
set -euo pipefail

STEAM="${STEAM_DIR:-$HOME/.local/share/Steam}"
[[ -d $STEAM/userdata ]] || { echo "  no Steam here, skipping"; exit 0; }
if pgrep -x steam >/dev/null; then echo "  Steam is running: close it (Steam > Exit) and run  bash packages/steam-defaults.sh"; exit 0; fi

python3 -I - "$STEAM" <<'PY'
import glob, os, re, shutil, sys

steam = sys.argv[1]

def parse(text):
    """Valve text KeyValues -> nested dicts (a repeated key keeps the last one, which is how Steam reads it)."""
    toks = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', text)
    pos = 0
    def block():
        nonlocal pos
        d = {}
        while pos < len(toks):
            k, brace = toks[pos]; pos += 1
            if brace == "}": return d
            if brace == "{": continue
            nk, nb = toks[pos]
            if nb == "{":
                pos += 1; d[k] = block()
            else:
                pos += 1; d[k] = nk
        return d
    return block()

def dump(d, depth=0):
    out = []
    t = "\t" * depth
    for k, v in d.items():
        if isinstance(v, dict):
            out.append(f'{t}"{k}"\n{t}{{\n{dump(v, depth + 1)}{t}}}\n')
        else:
            out.append(f'{t}"{k}"\t\t"{v}"\n')
    return "".join(out)

def child(d, *path):
    for p in path:
        key = next((k for k in d if k.lower() == p.lower()), None)
        if key is None:
            key = p; d[key] = {}
        d = d[key]
    return d

def load(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return parse(f.read())

def save(path, data):
    if not os.path.exists(path + ".torii-bak"): shutil.copy2(path, path + ".torii-bak")
    with open(path + ".tmp", "w", encoding="utf-8") as f:
        f.write(dump(data))
    os.replace(path + ".tmp", path)

# installed games of every library (not Proton, runtimes or Steamworks)
libs = [steam]
lf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
if os.path.exists(lf):
    for v in load(lf).get("libraryfolders", {}).values():
        if isinstance(v, dict) and v.get("path") and v["path"] not in libs: libs.append(v["path"])
skip = re.compile(r"proton|steam linux runtime|steamworks|steamvr|redistributable|soundtrack|spacewar|blender|godot|aseprite|obs studio|soundpad", re.I)
games = {}
for lib in libs:
    for m in glob.glob(os.path.join(lib, "steamapps", "appmanifest_*.acf")):
        a = load(m).get("AppState", {})
        if a.get("appid") and a.get("name") and not skip.search(a["name"]): games[a["appid"]] = a["name"]

# games with their own preferred options (Deadlock: skip the intro video, high priority)
special = {"1422450": "gamemoderun %command% -novid -high"}

# 1. launch options
for lc in glob.glob(os.path.join(steam, "userdata", "*", "config", "localconfig.vdf")):
    data = load(lc)
    apps = child(data, "UserLocalConfigStore", "Software", "Valve", "Steam", "apps")
    for appid, name in sorted(games.items(), key=lambda x: x[1]):
        app = child(apps, appid)
        if not app.get("LaunchOptions", "").strip():
            app["LaunchOptions"] = special.get(appid, "gamemoderun %command%")
            print(f"  {name}: {app['LaunchOptions']}")
    save(lc, data)

# 2. default compatibility tool
tools = sorted(glob.glob(os.path.join(steam, "compatibilitytools.d", "GE-Proton*")))
cfg = os.path.join(steam, "config", "config.vdf")
if tools and os.path.exists(cfg):
    data = load(cfg)
    mapping = child(data, "InstallConfigStore", "Software", "Valve", "Steam", "CompatToolMapping")
    if not mapping.get("0", {}).get("name"):
        mapping["0"] = {"name": os.path.basename(tools[-1]), "config": "", "priority": "75"}
        print(f"  default compatibility tool: {os.path.basename(tools[-1])}")
        save(cfg, data)
# 3. Deadlock video: windowed in the game (Hyprland makes it fullscreen: its own fullscreen mode breaks the mouse under XWayland),
# 240 Hz. Only when the game has written its settings once (it rewrites them on every start, so they are kept)
for vt in glob.glob(os.path.join(steam, "userdata", "*", "1422450", "local", "cfg", "video.txt")):
    t = open(vt, encoding="utf-8").read()
    n = re.sub(r'("setting\.fullscreen"\s+)"\d+"', r'\1"0"', t)
    n = re.sub(r'("setting\.refreshrate_numerator"\s+)"\d+"', r'\1"240000"', n)
    n = re.sub(r'("setting\.refreshrate_denominator"\s+)"\d+"', r'\1"1000"', n)
    if n != t:
        open(vt, "w", encoding="utf-8").write(n)
        print("  Deadlock video: windowed, 240 Hz")
print("  done")
PY
