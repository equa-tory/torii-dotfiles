#!/usr/bin/env bash
# Copy the app manifests from the repo (apps/<name>/app.json) into ~/apps. A manifest you edited is never replaced
# (one still equal to what was shipped last time is updated when the repo changes it), and program folders are never moved. Programs that arrive as plain folders (v2rayN from personal.sh) get their
# .desktop file from `torii-apps generate`, which this runs last.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for d in "$REPO"/apps/*/; do
  name=$(basename "$d"); dst="$HOME/apps/$name"
  mkdir -p "$dst"
  if [ ! -e "$dst/app.json" ]; then
    cp "$d"app.json "$dst/app.json"; cp "$d"app.json "$dst/.app.json.shipped"
  elif [ -e "$dst/.app.json.shipped" ] && cmp -s "$dst/app.json" "$dst/.app.json.shipped" && ! cmp -s "$d"app.json "$dst/app.json"; then
    cp "$d"app.json "$dst/app.json"; cp "$d"app.json "$dst/.app.json.shipped"          # not edited by you: take the new one
  fi
done
"$REPO/.config/torii/bin/torii-apps" generate >/dev/null || true
# real .desktop files (~/.local/share/applications/torii-app-*.desktop) so other launchers and xdg-open see them too
"$REPO/.config/torii/bin/torii-apps" desktop >/dev/null || true
# web apps and terminal apps restored from the home server (state files) become launcher entries again
"$REPO/.config/torii/bin/torii-apps" webapp sync >/dev/null || true
"$REPO/.config/torii/bin/torii-apps" tui sync >/dev/null || true
