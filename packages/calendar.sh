#!/usr/bin/env bash
# Connect the notch calendar to iCloud (two-way, over CalDAV with vdirsyncer). Run it from a terminal:
#   packages/calendar.sh            ask for the Apple ID and an app-specific password, set everything up
#   packages/calendar.sh --remove   stop syncing (local events stay)
#
# The app-specific password comes from https://account.apple.com > Sign-In and Security > App-Specific Passwords
# (your normal Apple password does not work). It is kept in ~/.local/state/torii/private/ (mode 600), never in the repo.
set -euo pipefail

CONF="$HOME/.config/vdirsyncer/config"
PRIV="$HOME/.local/state/torii/private"
CALS="$HOME/.local/share/torii/calendars"
UNITS="$HOME/.config/systemd/user"

if [ "${1:-}" = "--remove" ]; then
  systemctl --user disable --now torii-calendar-sync.timer 2>/dev/null || true
  rm -f "$CONF" "$UNITS/torii-calendar-sync.service" "$UNITS/torii-calendar-sync.timer" "$PRIV/icloud-password"
  systemctl --user daemon-reload
  echo "iCloud sync removed; events in $CALS stay."
  exit 0
fi

command -v vdirsyncer >/dev/null || { echo "!!  vdirsyncer is missing (sudo pacman -S vdirsyncer)"; exit 1; }

id="${ICLOUD_ID:-}"; pw="${ICLOUD_PASSWORD:-}"
[ -n "$id" ] || read -r -p "Apple ID (email): " id
[ -n "$pw" ] || { read -r -s -p "App-specific password: " pw; echo; }
[ -n "$id" ] && [ -n "$pw" ] || { echo "both are needed"; exit 1; }

mkdir -p "$PRIV" "$CALS" "$(dirname "$CONF")" "$UNITS" "$HOME/.local/state/vdirsyncer"
chmod 700 "$PRIV"
umask 077
printf '%s' "$pw" > "$PRIV/icloud-password"
umask 022

cat > "$CONF" <<CFG
[general]
status_path = "$HOME/.local/state/vdirsyncer/status/"

[pair icloud]
a = "icloud_remote"
b = "icloud_local"
collections = ["from a", "from b"]
conflict_resolution = "a wins"
metadata = ["displayname", "color"]

[storage icloud_remote]
type = "caldav"
url = "https://caldav.icloud.com/"
username = "$id"
password.fetch = ["command", "cat", "$PRIV/icloud-password"]

[storage icloud_local]
type = "filesystem"
path = "$CALS"
fileext = ".ics"
CFG
chmod 600 "$CONF"

echo "==> Finding your calendars"
yes | vdirsyncer discover icloud
echo "==> First sync"
vdirsyncer sync

cat > "$UNITS/torii-calendar-sync.service" <<UNIT
[Unit]
Description=Sync the torii calendar with iCloud

[Service]
Type=oneshot
ExecStart=$HOME/.config/torii/bin/torii-calendar sync
UNIT
cat > "$UNITS/torii-calendar-sync.timer" <<UNIT
[Unit]
Description=Sync the torii calendar every 15 minutes

[Timer]
OnStartupSec=1min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now torii-calendar-sync.timer
echo "Done: the calendar (click the clock) now shows your iCloud events and syncs every 15 minutes."
