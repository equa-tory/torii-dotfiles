#!/usr/bin/env bash
# Copy the private folder from the home server to the backup place on the Umbrel share, so a new machine can still
# be set up when the server is down (packages/personal.sh falls back to it). Run it after changing system/ files;
# packages/private-push.sh calls it at the end by itself.
#   bash packages/private-mirror.sh
# Environment: PRIVATE_SRC=user@host:path/   PRIVATE_BACKUP=/mnt/umbrel/Documents/torii-private
set -euo pipefail
SRC="${PRIVATE_SRC:-equa@192.168.1.50:torii-private/}"; SRC="${SRC%/}/"
BACKUP_DIR="${PRIVATE_BACKUP:-/mnt/umbrel/Documents/torii-private}"
# the share is an automount: listing the parent wakes it up
ls "$(dirname "$BACKUP_DIR")" >/dev/null 2>&1 || { echo "Umbrel share is not mounted ($BACKUP_DIR): skipping the backup copy" >&2; exit 0; }
mkdir -p "$BACKUP_DIR"
# cifs has no unix permissions: --no-perms. --delete keeps it an exact copy of the server
rsync -rltD --no-perms --delete -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8" "$SRC" "$BACKUP_DIR/"
echo "Backup copy updated: $BACKUP_DIR"
