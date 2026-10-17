#!/usr/bin/env bash
# Copy the app manifests from the repo (apps/<name>/app.json) into ~/apps. Existing manifests are never replaced,
# and program folders are never moved. Programs that arrive as plain folders (v2rayN from personal.sh) get their
# .desktop file from `torii-apps generate`, which this runs last.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for d in "$REPO"/apps/*/; do
  name=$(basename "$d"); dst="$HOME/apps/$name"
  mkdir -p "$dst"; cp -n "$d"app.json "$dst/app.json"
done
"$REPO/.config/torii/bin/torii-apps" generate >/dev/null || true
# real .desktop files (~/.local/share/applications/torii-app-*.desktop) so other launchers and xdg-open see them too
"$REPO/.config/torii/bin/torii-apps" desktop >/dev/null || true
# web apps and terminal apps restored from the home server (state files) become launcher entries again
"$REPO/.config/torii/bin/torii-apps" webapp sync >/dev/null || true
"$REPO/.config/torii/bin/torii-apps" tui sync >/dev/null || true
