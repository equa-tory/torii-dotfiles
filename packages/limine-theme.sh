#!/usr/bin/env bash
# Limine boot menu in the colours of the current wallpaper (and the wallpaper itself, darkened and blurred).
# torii-theme writes ~/.local/state/torii/theme/{limine.conf,limine-wallpaper.jpg}; this copies them to /boot and keeps a
# marked block at the top of /boot/limine.conf. The boot entries are never touched, and the first original is kept as
# /boot/limine.conf.torii-bak. Needs sudo; it runs when you run it (install.sh, or again after changing the wallpaper):
#   bash packages/limine-theme.sh
# Undo: sudo cp /boot/limine.conf.torii-bak /boot/limine.conf
set -euo pipefail

THEME="${TORII_STATE:-$HOME/.local/state/torii}/theme"
CONF="${LIMINE_CONF:-/boot/limine.conf}"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi

# make the files from the current settings first (config.json "limine": image, brightness, blur, panel)
if [[ $EUID -ne 0 && -x $HOME/.config/torii/bin/torii-theme ]]; then "$HOME/.config/torii/bin/torii-theme" limine || true; fi

[[ -f $CONF ]] || { echo "  no $CONF (not booted with Limine), skipping"; exit 0; }
[[ -f $THEME/limine.conf && -f $THEME/limine-wallpaper.jpg ]] || { echo "  no generated Limine theme yet: run torii-theme restore first" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
{
  echo "# torii-theme begin"
  grep -v '^#' "$THEME/limine.conf"
  echo "# torii-theme end"
  # the old block and the "quiet" line (it hides the menu) go; everything else stays as it is
  awk '/^# torii-theme begin/ {skip=1; next} /^# torii-theme end/ {skip=0; next} !skip && !/^quiet:/' "$CONF"
} > "$tmp"

# never write a config whose boot entries differ from the current one
if [[ $(grep -c '^/' "$tmp") -ne $(grep -c '^/' "$CONF") || $(grep -c '^/' "$tmp") -eq 0 ]]; then
  echo "!!  refusing: the boot entries would change" >&2; exit 1
fi

$SUDO mkdir -p "$(dirname "$CONF")/torii"
$SUDO install -m 644 "$THEME/limine-wallpaper.jpg" "$(dirname "$CONF")/torii/wallpaper.jpg"
[[ -f $CONF.torii-bak ]] || $SUDO cp "$CONF" "$CONF.torii-bak"
$SUDO install -m 644 "$tmp" "$CONF"
echo "  Limine theme applied to $CONF (backup: $CONF.torii-bak)"
