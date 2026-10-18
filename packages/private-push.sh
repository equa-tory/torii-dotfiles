#!/usr/bin/env bash
# Push private data TO the home server, the reverse of personal.sh (which pulls it):
#   Helium browser profile (cookies, extensions, settings)   ~/.config/net.imput.helium
#   LocalSend settings (alias, port, key)                    ~/.local/share/org.localsend.localsend_app
#   your web apps and terminal apps (private addresses)      ~/.local/state/torii/{webapps,tuis}.json
#   your own apps: .desktop files you made in ~/.local/share/applications (not the generated torii-* ones) and the program
#   folders in ~/apps that the repo does not ship (v2rayN, your own tools)
# They go to ~/torii-private/home/ on the server, never into the public repo. This only READS the local profile.
#   bash packages/private-push.sh [--dry-run]
# The server folder is also copied to the Umbrel share afterwards (packages/private-mirror.sh).
# Close Helium first for a consistent copy. Options (environment): PRIVATE_DST="user@host:path/ user2@host2:path/"
#   ONLY=localsend   push just LocalSend (works while Helium is open);  ONLY=helium  just the browser
#   ONLY=apps        push just your own apps and .desktop files
#   ONLY=webapps     push the web apps and terminal apps lists (Telegram, Discord, ...) and their logins (the browser's
#                    cookies and site storage, not the 400 MB of caches), so a fresh install is still signed in
set -euo pipefail

# Both home servers get the same copy (set PRIVATE_DST to push to just one): the second one is a second backup
DSTS="${PRIVATE_DST:-equa@192.168.1.50:torii-private/home/ equa@192.168.1.23:torii-private/home/}"
extra=(); [[ ${1:-} == --dry-run ]] && extra=(--dry-run)
command -v rsync >/dev/null || { echo "rsync is not installed" >&2; exit 1; }

ONLY="${ONLY:-all}"
if [[ $ONLY != localsend && $ONLY != apps ]] && ps -eo comm= | grep -qxE 'helium(-browser)?'; then
  echo "!!  Helium is running (the web apps like Telegram and Discord are Helium windows too): the copy may be" >&2
  echo "!!  inconsistent (databases open). Close them and run again," >&2
  echo "!!  or continue anyway with  FORCE=1 bash packages/private-push.sh" >&2
  [[ ${FORCE:-0} == 1 ]] || exit 1
fi

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
cd "$HOME"
# your own apps: .desktop files you wrote yourself, and ~/apps folders that are not shipped with the repo
own_apps() {
  local f d
  for f in .local/share/applications/*.desktop; do
    [[ -f $f ]] || continue
    case $(basename "$f") in torii-*|claude-code-url-handler.desktop) continue ;; esac
    printf '%s\n' "$f"
  done
  for d in apps/*/; do
    [[ -d $d ]] || continue
    [[ -d $REPO/apps/$(basename "$d") ]] && continue
    printf '%s\n' "${d%/}"
  done
}
case $ONLY in
  localsend) paths=(.local/share/org.localsend.localsend_app) ;;
  helium)    paths=(.config/net.imput.helium) ;;
  webapps)   paths=(.local/state/torii/webapps.json .local/state/torii/tuis.json .config/net.imput.helium/Local\ State
                    .config/net.imput.helium/Default/{Cookies,Cookies-journal,Preferences,"Local Storage","Session Storage",IndexedDB}
                    ".config/net.imput.helium/Default/Service Worker/Database" ".config/net.imput.helium/Default/Service Worker/ScriptCache") ;;
  apps)      mapfile -t paths < <(own_apps) ;;
  *)         mapfile -t mine < <(own_apps)
             paths=(.config/net.imput.helium .local/share/org.localsend.localsend_app .local/state/torii/webapps.json .local/state/torii/tuis.json "${mine[@]}") ;;
esac
pushed=0 first=""
for DST in $DSTS; do
  DST="${DST%/}/"
  echo "##  $DST"
  if ! ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o BatchMode=yes "${DST%%:*}" true 2>/dev/null; then
    echo "!!  ${DST%%:*} is not reachable, skipped" >&2; continue
  fi
  for p in "${paths[@]}"; do
    [[ -e $p ]] || { echo "skip $p (not there)"; continue; }
    echo "==> $p"
    # relative paths (-R) keep the layout, caches are rebuilt by the browser and just waste time
    rsync -aR --chmod=Dgo-rwx,Fgo-rwx "${extra[@]}" -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8" \
      --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='GrShaderCache/' \
      --exclude='ShaderCache/' --exclude='component_crx_cache/' --exclude='Crash Reports/' \
      --exclude='BrowserMetrics*' --exclude='DeferredBrowserMetrics/' --exclude='GPUPersistentCache/' \
      --exclude='DawnGraphiteCache/' --exclude='DawnWebGPUCache/' --exclude='CacheStorage/' \
      --exclude='SingletonLock' --exclude='SingletonCookie' --exclude='SingletonSocket' \
      "$p" "$DST"
  done
  pushed=$((pushed + 1)); [[ -n $first ]] || first=$DST
done
((pushed)) || { echo "No server could be reached, nothing was pushed" >&2; exit 1; }
PRIVATE_SRC="${first%home/}" bash "$REPO/packages/private-mirror.sh" || echo "(backup copy on the Umbrel share was not updated)" >&2
echo "Pushed to $pushed server(s). Restore on a new machine with: bash packages/personal.sh"
