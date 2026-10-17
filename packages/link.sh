#!/usr/bin/env bash
# link.sh desktop|terminal      link the dotfiles into $HOME, moving whatever is in the way to a backup first
# link.sh paths <path>...       link just these paths (relative to $HOME, e.g. .config/nvim .zshrc); the installer uses this
# link.sh --restore <stamp>     put a backup back (stamps: ls ~/.local/state/torii/backup)
#
# desktop   the whole repo through stow (Arch + Hyprland)
# terminal  only zsh, p10k, shell aliases, tmux, nvim (+ kitty on macOS), as plain symlinks (Ubuntu server, macOS)
# Nothing is ever deleted: a file or folder that is not already our link goes to
# ~/.local/state/torii/backup/<stamp>/<same path under $HOME>. Running it twice moves nothing the second time.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="$HOME/.local/state/torii/backup"
STAMP="$(date +%Y%m%d-%H%M%S)"

TERMINAL_PATHS=(.zshrc .zprofile .p10k.zsh .config/dotfiles .config/nvim .config/tmux)
[ "$(uname)" = Darwin ] && TERMINAL_PATHS+=(.config/kitty)

backup() {   # path relative to $HOME
  local rel="$1" dest="$BACKUP_ROOT/$STAMP/$1"
  mkdir -p "$(dirname "$dest")"
  mv "$HOME/$rel" "$dest"
  echo "    backed up ~/$rel -> $dest"
}

is_ours() {  # a symlink that points into this repo
  [ -L "$1" ] && case "$(readlink -f "$1")" in "$REPO"/*|"$REPO") return 0 ;; esac
  return 1
}

link_paths() {
  local rel
  for rel in "$@"; do
    [ -e "$REPO/$rel" ] || continue
    if is_ours "$HOME/$rel"; then continue; fi
    if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then backup "$rel"; fi
    mkdir -p "$(dirname "$HOME/$rel")"
    ln -s "$REPO/$rel" "$HOME/$rel"
    echo "    linked ~/$rel"
  done
}

link_terminal() { link_paths "${TERMINAL_PATHS[@]}"; }

link_desktop() {
  command -v stow >/dev/null || { echo "!!  stow is missing"; exit 1; }
  # real parent dirs first, otherwise stow folds all of ~/.config into this repo (and apps would write into it)
  mkdir -p "$HOME/.config" "$HOME/.config/autostart" "$HOME/.local/share" "$HOME/.local/state"
  # stow names every file it cannot link; move each one aside (a few rounds: moving a folder can expose more)
  local round conflicts rel
  for round in 1 2 3 4 5; do
    conflicts="$(cd "$REPO" && stow -n -t "$HOME" . 2>&1 | sed -n \
      -e 's/.* over existing target \(.*\) since .*/\1/p' \
      -e 's/.*existing target is not owned by stow: *//p' || true)"
    [ -n "$conflicts" ] || break
    while IFS= read -r rel; do
      [ -n "$rel" ] && { [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; } && backup "$rel"
    done <<< "$conflicts"
  done
  (cd "$REPO" && stow -t "$HOME" .)
  echo "    stowed $REPO into $HOME"
}

restore() {
  local dir="$BACKUP_ROOT/$1"
  [ -d "$dir" ] || { echo "no such backup: $1"; ls "$BACKUP_ROOT" 2>/dev/null; exit 1; }
  (cd "$dir" && find . \( -type f -o -type l \) | sed 's|^\./||') | while IFS= read -r rel; do
    if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then
      if is_ours "$HOME/$rel" || [ -L "$HOME/$rel" ]; then rm "$HOME/$rel"; else mv "$HOME/$rel" "$HOME/$rel.torii-replaced"; fi
    fi
    mkdir -p "$(dirname "$HOME/$rel")"
    cp -a "$dir/$rel" "$HOME/$rel"
    echo "    restored ~/$rel"
  done
}

case "${1:-}" in
  desktop)    link_desktop ;;
  terminal)   link_terminal ;;
  paths)      shift; link_paths "$@" ;;
  --restore)  restore "${2:?stamp}" ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
