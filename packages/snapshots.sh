#!/usr/bin/env bash
# System snapshots you can boot from the Limine menu (and roll back to): btrfs + snapper + snap-pac.
#   - snapper config for / (no timeline snapshots; snap-pac takes one before and after every pacman transaction)
#   - /usr/local/bin/torii-snapshots (root-owned copy of packages/torii-snapshots) + two pacman hooks that keep the Limine
#     "Snapshots" entries and a kernel copy per snapshot up to date
# Needs sudo. Safe to run again. Only for a btrfs root with the layout 1-base.sh makes (@ mounted as /).
#   bash packages/snapshots.sh
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi

[[ $(findmnt -no FSTYPE /) == btrfs ]] || { echo "  root is not btrfs, snapshots skipped"; exit 0; }
[[ -f /boot/limine.conf ]] || { echo "  no /boot/limine.conf (not Limine), snapshots skipped"; exit 0; }

$SUDO pacman -S --needed --noconfirm snapper snap-pac
if ! $SUDO snapper list-configs 2>/dev/null | grep -q '^root'; then
  $SUDO snapper -c root create-config /
fi
# no timeline snapshots; keep the newest 8 numbered ones (pre + post of a few upgrades, and manual ones)
$SUDO snapper -c root set-config TIMELINE_CREATE=no TIMELINE_CLEANUP=no NUMBER_CLEANUP=yes NUMBER_LIMIT=8 NUMBER_LIMIT_IMPORTANT=8 EMPTY_PRE_POST_CLEANUP=yes
$SUDO systemctl enable --now snapper-cleanup.timer >/dev/null 2>&1 || true

# the script runs as root from pacman hooks: a root-owned copy, never the one in your home
$SUDO install -m 755 -o root -g root "$REPO/packages/torii-snapshots" /usr/local/bin/torii-snapshots
$SUDO install -d /etc/pacman.d/hooks
for when in pre post; do
  if [[ $when == pre ]]; then file=06-torii-snapshots-pre.hook; w=PreTransaction; desc="Saving the kernel of the new snapshot"
  else file=zzz-torii-snapshots-post.hook; w=PostTransaction; desc="Updating the boot menu snapshot entries"; fi
  $SUDO tee /etc/pacman.d/hooks/$file >/dev/null <<HOOK
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = $desc
When = $w
Exec = /usr/local/bin/torii-snapshots sync
HOOK
done

# a first snapshot, so the menu has something to offer
if [[ -z $($SUDO snapper -c root list --columns number | awk 'NR>2 && $1 != 0') ]]; then
  $SUDO /usr/local/bin/torii-snapshots create "torii: first snapshot"
else
  $SUDO /usr/local/bin/torii-snapshots sync
fi
echo "  Snapshots ready. Boot menu > Snapshots; roll back with: sudo torii-snapshots rollback"
