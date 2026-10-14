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
