#!/usr/bin/env bash
# Dolphin as the minimal default file manager: opens in Downloads, sidebar with Desktop / Documents / Downloads / Pictures /
# Videos / Network (local and removable drives appear on their own under Devices), no menu bar or status bar.
# Seed only: Dolphin rewrites its own files (it would replace a stow link), so existing files are never touched.
#   bash packages/dolphin.sh [--reset]     --reset overwrites the three files with the shipped ones
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED="$REPO/.config/torii/seed/dolphin"
RESET=0; [[ ${1:-} == --reset ]] && RESET=1

seed() {   # seed <file in the seed folder> <destination>
  local src="$SEED/$1" dst="$2"
  if [[ -e $dst && $RESET == 0 ]]; then echo "  keep   $dst"; return; fi
  mkdir -p "$(dirname "$dst")"
  sed "s|@HOME@|$HOME|g" "$src" > "$dst"
  echo "  seeded $dst"
}

seed dolphinrc "$HOME/.config/dolphinrc"
seed user-places.xbel "$HOME/.local/share/user-places.xbel"
mkdir -p "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Videos"
[[ -f $SEED/dolphinui.rc ]] && seed dolphinui.rc "$HOME/.local/share/kxmlgui5/dolphin/dolphinui.rc"
[[ -f $SEED/../darkly/darklyrc ]] && SEED=$SEED/../darkly seed darklyrc "$HOME/.config/darklyrc"

# make it the default for folders (the launcher's Setup > Defaults does the same)
if [[ -e /usr/share/applications/org.kde.dolphin.desktop ]]; then
  "$HOME/.config/torii/bin/torii-default" set files org.kde.dolphin.desktop 2>/dev/null \
    || xdg-mime default org.kde.dolphin.desktop inode/directory || true
else
  echo "  (Dolphin is not installed yet: pacman -S dolphin kio-extras breeze-icons)"
fi
