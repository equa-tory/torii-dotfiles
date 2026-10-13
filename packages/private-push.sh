#!/usr/bin/env bash
# Push private data TO the home server, the reverse of personal.sh (which pulls it):
#   Helium browser profile (cookies, extensions, settings)   ~/.config/net.imput.helium
#   LocalSend settings (alias, port, key)                    ~/.local/share/org.localsend.localsend_app
# They go to ~/torii-private/home/ on the server, never into the public repo. This only READS the local profile.
#   bash packages/private-push.sh [--dry-run]
# Close Helium first for a consistent copy. Options (environment): PRIVATE_DST=user@host:path/
#   ONLY=localsend   push just LocalSend (works while Helium is open);  ONLY=helium  just the browser
set -euo pipefail

DST="${PRIVATE_DST:-equa@192.168.1.50:torii-private/home/}"; DST="${DST%/}/"
extra=(); [[ ${1:-} == --dry-run ]] && extra=(--dry-run)
command -v rsync >/dev/null || { echo "rsync is not installed" >&2; exit 1; }

ONLY="${ONLY:-all}"
if [[ $ONLY != localsend ]] && { pgrep -x helium >/dev/null 2>&1 || pgrep -f '[h]elium-browser' >/dev/null 2>&1; }; then
  echo "!!  Helium is running: the copy may be inconsistent (databases open). Close it and run again," >&2
  echo "!!  or continue anyway with  FORCE=1 bash packages/private-push.sh" >&2
  [[ ${FORCE:-0} == 1 ]] || exit 1
fi

case $ONLY in
  localsend) paths=(.local/share/org.localsend.localsend_app) ;;
  helium)    paths=(.config/net.imput.helium) ;;
  *)         paths=(.config/net.imput.helium .local/share/org.localsend.localsend_app) ;;
esac
cd "$HOME"
for p in "${paths[@]}"; do
  [[ -e $p ]] || { echo "skip $p (not there)"; continue; }
  echo "==> $p"
  # relative paths (-R) keep the layout, caches are rebuilt by the browser and just waste time
  rsync -aR --chmod=Dgo-rwx,Fgo-rwx "${extra[@]}" -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8" \
    --exclude='Cache/' --exclude='Code Cache/' --exclude='GPUCache/' --exclude='GrShaderCache/' \
    --exclude='ShaderCache/' --exclude='component_crx_cache/' --exclude='Crash Reports/' \
    --exclude='BrowserMetrics*' --exclude='SingletonLock' --exclude='SingletonCookie' --exclude='SingletonSocket' \
    "$p" "$DST"
done
echo "Pushed. Restore on a new machine with: bash packages/personal.sh"
