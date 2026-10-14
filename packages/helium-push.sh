#!/usr/bin/env bash
# Back up the Helium browser profile to the home server, on demand (the profile is only read, never changed):
#   bash packages/helium-push.sh [--dry-run]
# Close Helium first for a consistent copy (FORCE=1 to copy anyway). Restore on a new machine with packages/personal.sh.
exec env ONLY=helium bash "$(dirname "$(readlink -f "$0")")/private-push.sh" "$@"
