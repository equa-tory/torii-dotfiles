#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
 
# Print a package list without blank lines or comments
read_list() { grep -vE '^\s*(#|$)' "$1"; }
 
# PKG_ONLY=pacman or PKG_ONLY=aur (set by ./install.sh) does just that half; unset does both
ONLY="${PKG_ONLY:-}"

echo "==> Installing build prerequisites"
sudo pacman -S --needed --noconfirm base-devel git

if [ -z "$ONLY" ] || [ "$ONLY" = pacman ]; then
echo "==> Installing pacman packages"
mapfile -t pacman_pkgs < <(read_list "$PKG_DIR/pacman.txt")
sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
fi

if [ "$ONLY" = pacman ]; then exit 0; fi

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
fi
 
echo "==> Installing AUR packages"
mapfile -t aur_pkgs < <(read_list "$PKG_DIR/aur.txt")
if ((${#aur_pkgs[@]})); then
  yay -S --needed --noconfirm "${aur_pkgs[@]}"
fi
 
