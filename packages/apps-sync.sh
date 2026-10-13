#!/usr/bin/env bash
# Copy the app manifests from the repo (apps/<name>/app.json) into ~/apps. Existing manifests are never replaced,
# and program folders are never moved. A manifest whose program is missing is skipped (v2rayN comes from personal.sh).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for d in "$REPO"/apps/*/; do
  name=$(basename "$d"); dst="$HOME/apps/$name"
  [[ $name == v2rayN && ! -e $dst/v2rayN-linux-64/v2rayN ]] && { echo "  $name: program not there yet, skipped"; continue; }
  mkdir -p "$dst"; cp -n "$d"app.json "$dst/app.json"
done
