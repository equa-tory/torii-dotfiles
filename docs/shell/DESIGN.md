# torii shell (Quickshell) + wallpaper theme system — plan

## Context
`~/torii-dotfiles` (stowed into `$HOME`) runs Hyprland 0.56.2 (Lua config) with Waybar + hyprpaper + swaync.
Goal (spec in `~/t`): replace Waybar/hyprlauncher/hyprpaper with one Quickshell shell (notch, control panel,
wallpaper/theme switcher, launcher) and a CLI-driven theme pipeline that recolors the whole desktop from the
wallpaper. Built in a QEMU VM (1 monitor `Virtual-1`, ethernet + `singbox_tun`, no Wi-Fi/BT, bluetoothd not
running), but the real target has 2 monitors (DP-2 240Hz + HDMI-A-1, already in `monitors.lua`), NVIDIA,
Wi-Fi, BT. **A fresh `git clone && ./install.sh` must reproduce everything** on the real machine.
Design brief from the user: minimal and good-looking. **No settings buttons or toggles in the UI**; all tuning is
in one config file.

First execution step: copy this plan into `docs/shell/DESIGN.md` (the spec wants it there; plan mode only allows
writing here). Approving this plan is the approval stop the spec asks for.

## Facts found while exploring
- Not installed yet (all verified in `extra`): quickshell 0.3.2, matugen 4.2.0, grim, slurp, jq, imagemagick,
  fastfetch, adw-gtk-theme, qt6ct, bluez-utils, **brightnessctl (already used by the XF86 binds, so those binds
  are broken right now)**. wallust is AUR-only, so the plan uses **matugen**, run only as a JSON extractor
  (`matugen image <img> -t scheme-tonal-spot -m dark --source-color-index 0 --json hex --dry-run -q`; the
  JSON has `colors.<role>.dark.color`).
- Hyprland 0.56 with Lua: `hyprctl keyword` doesn't work, so runtime config uses `hyprctl eval 'hl.config({...})'`.
  Dispatches must be written in Lua syntax (`hl.dsp.focus({workspace="3"})`). Quickshell 0.3 detects Lua
  (`Hyprland.usingLua`), and `HyprlandWorkspace.activate()` already sends the Lua form.
- Quickshell 0.3.2 has native modules for everything required: Pipewire (settable `preferredDefaultAudioSink/Source`,
  `PwNodePeakMonitor` for the input level), Bluetooth (pair, connect, forget, battery; "just works" pairing only, **no
  PIN/passkey agent**), Networking (NetworkManager: Wi-Fi list, strength, security, known, `connectWithPsk`,
  forget, scan, wired link; **no IP address**, so the IP comes from `ip -j addr`), SystemTray, DesktopEntries,
  IpcHandler, FileView+JsonAdapter (watching).
- Helium 0.19.2 reads policies from **`/etc/chromium/policies/managed`** (checked in the binary) and supports
  `BrowserThemeColor`. Live apply: `helium-browser --refresh-platform-policy --no-startup-window`.
  Side effects of any policy: Helium shows "managed by your organization" and turns off DNS-over-HTTPS.
- On a clean install, `stow .` would fold `~/Pictures` into the repo, so wallpapers you drop in later would end up
  in the public repo. install.sh must create `~/Pictures/wallpapers` as a real directory before stowing.
- `install.sh` can't be rerun: `ssh-keygen` prompts when a key exists, and the limine `sed` appends `quiet: yes`
  again. Both get guards so reinstalling is safe.
- `border_size = 0`, so theme border colors only become visible if you raise it. I'll leave it and note it.
- `.zshrc` puts `~/.local/bin` on PATH, but only in interactive zsh. uwsm and Hyprland don't see it.

## Architecture
```
torii-theme (CLI: python3 stdlib + matugen) ──writes──▶ ~/.local/state/torii/theme/* (tokens + per-app files)
   ▲ called by shell UI, keybinds, terminal                └─ reload hooks: kitty USR1, nvim --remote, tmux,
   │                                                          hyprctl eval, gsettings, helium policy refresh
Quickshell config "torii" (~/.config/quickshell/torii) ◀── FileView watches shell.json + ~/.config/torii/config.json
  per screen: Wallpaper (Background layer, crossfade) + Notch (Top layer) that grows into one panel at a time
  services: Hypr, Audio, Bluetooth, Network, Tray, Weather, Apps, Quicklinks — each with a Mock (TORII_MOCK=1)
```

### Repo layout (stowed unless marked)
```
.config/quickshell/torii/   shell.qml · Config.qml · Theme.qml (singletons) · Ipc.qml
  bar/       Notch.qml (shape, mask, grow animation), Workspaces.qml, Clock.qml, Weather.qml
  panels/    ControlPanel.qml (+ Audio/Bluetooth/Network/Tray sections), Switcher.qml, Launcher.qml
  services/  Hypr, Audio, Bluetooth, Network, Tray, Weather, Apps, Quicklinks (.qml) + services/mock/*.qml
  widgets/   Capsule, Slider, Row, Icon, TextField … (small, theme-token driven)
.config/torii/
  config.json      the single visual config (hot-reloaded)
  quicklinks.json  keyword → URL template (hot-reloaded)
  bin/             torii-theme, torii-shell (start | reload | fallback | mock)
  templates/       kitty.conf, nvim.lua, tmux.conf, hypr.lua, gtk.css, qt6ct.conf, fastfetch.jsonc,
                   helium-policy.json, shell.json, hyprpaper.conf   (placeholders like {{accent}})
  overrides/       <wallpaper-file-name>.json → {"accent": "#ff8800"}
.config/uwsm/env   export PATH="$HOME/.config/torii/bin:$PATH"   (Hyprland, binds and qs see the scripts)
.config/nvim/lua/torii_theme.lua   (new)
docs/shell/DESIGN.md, docs/shell/README.md   NOT stowed (`^/docs` added to .stow-local-ignore)
wallpapers/        NOT stowed (moved from Pictures/wallpapers; install.sh copies into ~/Pictures/wallpapers)
```
Generated files (never in the repo): `~/.local/state/torii/{current.json, theme/*, launcher-recent.json,
weather.json}` and `~/.cache/torii/palettes/<sha>.json`. It's fine for `~/.config/torii` to fold into the repo,
because only hand-edited, tracked files live there.

### Config (`~/.config/torii/config.json`; every key optional, defaults live in Config.qml)
```json
{ "notch": { "shape": "attached", "opacity": 1.0, "radius": 16, "height": 34, "gap": 6 },
  "workspaces": { "count": 5 },
  "weather": { "lat": 55.75, "lon": 37.62, "refreshMin": 20 },
  "wallpaper": { "dir": "~/Pictures/wallpapers", "transitionMs": 600 },
  "theme": { "tint": 0.15 },
  "quicklinks": "~/.config/torii/quicklinks.json",
  "font": { "family": "JetBrainsMono Nerd Font", "size": 13 } }
```

### Theme tokens (`tokens.json`, also rendered as the shell's `shell.json`)
- **Neutrals:** `bg` (#000000 at tint 0), `surface`, `surface2`, `overlay`, `border`, `muted`, `subtle`, `fg`, `fgDim`.
- **Accent:** `accent`, `accentDim`, `onAccent`.
- **Fixed semantic colors:** `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`.
- **Other:** `term0..15`, `wallpaper`, `hash`.

Rules:
- Neutrals use an OKLCH lightness ladder with chroma = tint × 0.03 at the wallpaper's hue.
- The accent is matugen's `primary` (dark), clamped to L 0.68–0.82 and C ≥ 0.09 so it never goes muddy or too dark.
- Contrast is enforced at WCAG ≥ 4.5 for accent on bg, fg on bg and onAccent on accent.
- An override file replaces the extracted accent.
- The cache key is sha256(image) + tint + override contents.

### torii-theme CLI (source of truth; atomic writes; idempotent)
Commands: `torii-theme set <img> | next | prev | random | restore | palette <img> (JSON only) | current`

`set` does three things:
1. Extract the palette, or take it from cache.
2. Render all templates into the state dir with tmp+rename.
3. Write `current.json`, then run each reload hook below. Every hook is best-effort and skipped if its app isn't
   running. If the hash hasn't changed, `set` does nothing.

Reload hooks:
- **Shell:** watches `shell.json` and `current.json`, then recolors and crossfades the wallpaper.
- **Hyprland:** `decorations.lua` gets one line, `pcall(dofile, HOME.."/.local/state/torii/theme/hypr.lua")`.
  Live: `hyprctl eval 'hl.config({general={col={...}}})'`.
- **kitty:** the hardcoded colors stay as the fallback, followed by
  `globinclude ~/.local/state/torii/theme/kitty.conf` (a missing file is fine). Live: `pkill -USR1 -x kitty`.
  `background_opacity 0.6` stays.
- **nvim:** catppuccin and all plugins stay. `torii_theme.lua` feeds the generated palette into catppuccin's
  `color_overrides` and falls back to stock mocha if the file is missing. Live: for each
  `$XDG_RUNTIME_DIR/nvim.*` socket, run `nvim --server S --remote-expr 'v:lua.require("torii_theme").reload()'`.
- **tmux:** `source-file -q ~/.local/state/torii/theme/tmux.conf` goes at the end and replaces the hardcoded
  `blue`. Live: `tmux source-file` when a server is running.
- **GTK:** `adw-gtk3` + `color-scheme prefer-dark` set via gsettings. `~/.config/gtk-{3,4}.0/gtk.css` (created
  by install.sh, not stowed) holds a single `@import` of the state file. GTK apps pick it up on restart; I'll say so.
- **Qt:** qt6ct color scheme in the state dir, with `QT_QPA_PLATFORMTHEME` changed to `qt6ct`. Low priority;
  apps pick it up on restart.
- **fastfetch:** generated config. The shellrc `ff` alias becomes `fastfetch -c <state>/fastfetch.jsonc` (it
  currently calls neofetch, which isn't installed).
- **Helium:** install.sh puts a root-owned symlink at `/etc/chromium/policies/managed/torii-theme.json` pointing
  to `<state>/helium-policy.json` (`{"BrowserThemeColor": accent-tinted dark}`). Live:
  `helium-browser --refresh-platform-policy --no-startup-window`. The browser profile is never touched. P0
  checks that Chromium follows the symlink; if it doesn't, the fallback is a sudoers rule for one copy command.

### Shell
- **Notch:** one `PanelWindow` per screen, created from `Variants { model: Quickshell.screens }` (hotplug-safe),
  anchored top/left/right with a transparent window.
  - Visible shape drawn in QML:
    - *attached:* flat top that meets the screen edge, with concave "ears" and rounded bottom corners.
    - *floating:* a pill with a gap.
  - `mask: Region` covers only the visible shape. The exclusive zone is the notch height, plus the gap when floating.
  - `opacity` applies to the background only; text stays opaque.
  - Order: workspaces · clock · weather · control button (a single small glyph).
- **Workspaces:** event-driven through Quickshell.Hyprland.
  - Each monitor shows ids 1..count as placeholders, except an id that lives on another monitor, plus any
    occupied or active id on this monitor.
  - Capsules are gray and vertical. The active one is taller and accent-colored, an occupied one gets a small
    dot, and changes animate with springs.
  - Click: `ws.activate()`, or a Lua dispatch for an empty placeholder.
  - When a special workspace (magic) is open on that monitor, a small accent pip appears; clicking it toggles it.
- **Clock:** clicking swaps inline, `21:30` → `Tue 13 Oct  21:30`, with an animated width change. I chose this
  over a dropdown because it adds no extra surface and fits the notch.
- **Weather:** XMLHttpRequest to Open-Meteo (`current=temperature_2m,weather_code,is_day`) every 20 minutes and
  on network-up, cached in `weather.json`. Offline: last value dimmed. No data at all: hidden. Icons map WMO codes
  to `nf-md-weather_*` (sunny F0599, night F0594, partly cloudy F0595 / night F0F31, cloudy F0590, fog F0591,
  drizzle F0F33, rain F0597, pouring F0596, freezing rain F067F, snow F0598, heavy snow F0F36, storm F0593, hail
  F0592). Rendering of each glyph gets checked on a screenshot.
- **Panels:** one at a time, only on the focused monitor (`Hyprland.focusedMonitor` matched to the screen). The
  notch itself grows with an animated width and height into the panel: same black, same corners, no extra
  window edges.
  - Keyboard: `WlrLayershell.keyboardFocus` is OnDemand while a panel is open and None otherwise.
  - Esc or an outside click (`HyprlandFocusGrab.cleared`) closes the panel and gives focus back.
- **Control panel** (compact, no settings toggles beyond what the spec lists):
  - **Volume:** slider + mute on the default sink. Expanding rows choose the default output and input, and the
    input row shows a live level (`PwNodePeakMonitor`).
  - **Bluetooth:** power, a scan button, and paired devices (connected state, battery when available) with
    connect/disconnect and forget. Discovered devices pair with one click ("just works"). PIN pairing is reported
    as unsupported, not faked.
  - **Network:** native Networking module. Shows the active physical connection (ethernet/wifi device types only,
    so `singbox_tun`, tun, docker, virbr and lo never appear) and its IP from `ip -j addr`, refreshed on device
    state change.
    - Wi-Fi list: name, strength, lock, saved/connected.
    - Clicking a saved network connects directly. A secured network opens an inline password field
      (`connectWithPsk`).
    - Each network can disconnect or forget. A rescan button sits in the header.
    - The Wi-Fi section is hidden when there is no Wi-Fi device.
  - **Background apps:** tray icons in a row. Left click runs `activate()`; right click shows the item's menu
    through QsMenuAnchor. The shell is the only tray host.
- **Switcher:** a horizontal strip of thumbnails (Image `sourceSize` 320px, async, cached by Qt), re-listed
  whenever the folder changes.
  - ←/→ moves and live-previews the highlighted wallpaper (and its accent, from `torii-theme palette`) on the
    focused monitor only.
  - Esc reverts. Enter/Space runs `torii-theme set`.
- **Launcher:** attached to the notch: one input with a short list below it.
  - Fuzzy JS scorer (subsequence + word-start bonus) with a recency boost from `launcher-recent.json`.
  - Sources: DesktopEntries (system + user), mac-style apps (below), and quicklinks.
  - Launching goes through `uwsm app -- …`; URLs open via `uwsm app -- xdg-open <url>`.
  - Typing `ql` offers "Edit quicklinks", which opens the file in nvim inside kitty.
- **Mac-style apps (your idea, adopted):** each folder in `~/apps/` is an app, and its `app.json`
  (`{"name": "v2rayN", "exec": "v2rayN", "icon": "icon.png", "keywords": ["vpn"]}`, paths relative to the
  folder) works like Info.plist.
  - The launcher scans first-level subfolders of `~/apps` for `app.json` each time it opens. That's cheap, so no
    daemon is needed.
  - Nothing is moved. `personal.sh` already restores `~/apps/v2rayN`, and I only document the `app.json` to drop
    into it (you add it, or I copy a sample when you ask).
- **Mock mode:** `torii-shell mock` (`TORII_MOCK=1`) fakes the hardware the VM lacks:
  - Wi-Fi: open, WPA, saved, connected and weak networks.
  - Bluetooth: devices that are paired, connected, have battery, or were just discovered.
  - Audio: 3 sinks and 2 sources.
  - Tray: Steam and v2rayN-like items.
- **IPC targets** (`qs -c torii ipc call …`): `launcher toggle`, `control toggle`, `switcher toggle`,
  `panels close`, `shell reload`.

### Hyprland integration (only autostart.lua, binds.lua and one dofile line in decorations.lua)
- **autostart:** `torii-theme restore; uwsm app -- qs -c torii`, so the theme exists before the shell paints.
  swaync stays; the waybar and hyprpaper lines are removed.
- **Binds** (all with `mainMod`; checked against every existing bind):
  - `SPACE`: launcher
  - `N`: control panel
  - `CTRL + SPACE`: wallpaper switcher
  - `SHIFT + R`: `torii-shell reload` (replaces the waybar/hyprpaper restart)
- **Emergency fallback:** `torii-shell fallback` stops qs and starts waybar plus hyprpaper with a hyprpaper
  config generated for the current wallpaper. The Waybar config stays in the repo.
- Layer rules for namespace `torii-*`: no blur when opacity is 1, plus a fade animation.

## Decisions (made)
| Topic | Decision |
|---|---|
| Wallpaper | The shell draws it. hyprpaper is used only by the fallback. |
| Apps | `~/apps/<name>/app.json`, scanned by the launcher. Nothing is moved. |
| Helium | Managed `BrowserThemeColor` policy with a live refresh. The profile is never touched. |
| Keybinds | `mainMod+SPACE`, `mainMod+N`, `CTRL+mainMod+SPACE`, `mainMod+SHIFT+R`. |
| Notifications | swaync stays for now. A later phase moves them into the shell (Services.Notifications), never both at once. |

## Phases (branch `quickshell-shell`; commit after each verified phase; never push)
- **P0 theme pipeline.** Packages, `torii-theme`, templates, app includes, Helium policy.
  - Accept: `set` on all 4 wallpapers works headless. Built-in contrast asserts pass. The second run is a cache
    hit and a no-op.
  - Accept: kitty, tmux and nvim recolor live (screenshots). The Hyprland eval applies. Helium's color changes.
- **P1 shell core.** quickshell, grim. Notch, workspaces, clock, weather, wallpaper layer, IPC, config hot-reload;
  autostart switched.
  - Accept: screenshots of attached, floating and 0.85 opacity.
  - Accept: `hyprctl output create headless` gives a notch on both outputs (`grim -o`), and removing the output
    doesn't crash anything.
  - Accept: idle CPU is about 0 (`top` sample).
- **P2 control panel.** Volume, then Bluetooth, then network, then tray, each with a real and a mock backend.
  - Accept: screenshots of every mock state. Real audio and ethernet work in the VM.
  - Accept: typing goes back to the window after Esc.
- **P3 switcher.**
  - Accept: ←/→ previews, Esc restores, Enter themes everything. A new file dropped into the folder appears.
- **P4 launcher + quicklinks + `~/apps`.**
  - Accept: fuzzy search and recents ordering work. `yt cats` and `git` work. A sample `~/apps/demo/app.json`
    shows up.
- **P5 integration.**
  - `packages/pacman.txt`: quickshell, matugen, grim, slurp, jq, imagemagick, fastfetch, adw-gtk-theme, qt6ct,
    brightnessctl, bluez, bluez-utils, playerctl, python, uwsm.
  - install.sh:
    - creates real dirs before stow (`~/Pictures/wallpapers`, `~/.local/state/torii`) and copies the wallpapers
    - adds the new paths to the backup loop
    - enables `bluetooth.service`
    - creates the Helium policy link and sets the default browser (`xdg-settings` + http/https/text/html mimeapps)
    - creates the gtk.css imports
    - runs `torii-theme restore` (with a default wallpaper on first run)
    - gets the ssh-keygen and limine rerun guards
  - `.stow-local-ignore` gets `^/docs` and `^/wallpapers`.
  - `docs/shell/README.md` covers config keys, fallback and uninstall.
  - Accept: `stow -n -v .` is clean, and install.sh's new steps work in a throwaway `HOME` and are idempotent on
    rerun.

## Risks
- Quickshell is pre-1.0, so the API can drift; I'll pin to 0.3.2 behavior and check the changelog.
- NVIDIA + layer-shell on the real machine.
- `CTRL+ALT+SPACE` in the VM vs `grp:ctrl_alt_toggle` layout switching. I'll test it; on SUPER there's no clash.
- Helium policy side effects (DoH off, "managed" label).
- GTK4/Qt apps only recolor on restart.
- No Bluetooth PIN agent.
- OnDemand focus holding on. Mitigation: explicit None when closed.

## Verification
- Every phase gets `grim` screenshots (plus `grim -o HEADLESS-n` for the second monitor). I look at each one and
  fix problems before reporting.
- The final report lists what works, what was verified only against mocks, and a real-machine checklist: two
  monitors, Wi-Fi connect, Bluetooth pair/forget, Steam + v2rayN in the tray, Helium theme, SUPER as `mainMod`.

---

## As built (differences from the plan above)

* **Token rename:** `onAccent` became `accentFg` (`onAccent` is parsed by QML as a signal handler).
* **Dark / light:** `torii-theme mode dark|light|toggle`, dark by default, bound to `mainMod + SHIFT + D`. Adds the
  tokens `browser`, `mode`, `gtkTheme`, `catppuccin`. Helium gets a dark-toned seed colour (a bright seed makes
  Chromium derive a light frame even with `BrowserColorScheme = dark`).
* **Singleton `State` is `Panels`:** `State` collides with the QtQuick type.
* **Click outside:** a transparent full-screen scrim and `HyprlandFocusGrab` both failed (Hyprland routes pointer input only to the
  exclusive-keyboard layer). The notch window is full height instead, and its input mask grows to the whole window
  while a panel is open.
* **No QML `Shortcut`:** it segfaults in Qt 6.12 when the shell hot-reloads; Esc is a key handler.
* **Switcher:** previews the wallpaper (and shows the accent swatch) on the focused monitor; it does not recolour the
  shell until you confirm.
* **Mac-style apps:** `~/apps/<name>/app.json`, scanned by the launcher; no `.desktop` generation (nothing is moved).
* **Wallpapers in the repo** moved from `Pictures/wallpapers` to the stow-ignored `wallpapers/` so that `~/Pictures`
  stays a real directory.
* **Idempotent install:** `packages/torii-setup.sh`, `TORII_NO_HOOKS=1` / `TORII_SKIP_SYSTEM=1` for tests.
* **Shell state/IPC:** targets are `shell reload`, `panels close`, `control|launcher|switcher toggle`.
