#!/usr/bin/env bash
# torii-dotfiles installer.
#   ./install.sh                  pick what to install in a list (space toggles, enter starts); safe to run again
#   ./install.sh --all            everything for this system, no questions (also what happens without a terminal)
#   ./install.sh --only zsh,tmux  just these parts            ./install.sh --skip nvim,nvidia   everything except these
#   ./install.sh --list           the parts and their names   ./install.sh --profile terminal|desktop   force a profile
#
# Whatever is in the way of a config is moved to ~/.local/state/torii/backup/<date-time>/ first
# (restore with packages/link.sh --restore <date-time>).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
REPO="$PWD"

PROFILE="" ONLY="" SKIP="" ALL=0 LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?terminal|desktop}"; shift ;;
    --only)    ONLY="${2:?names}"; shift ;;
    --skip)    SKIP="${2:?names}"; shift ;;
    --all|--yes|-y) ALL=1 ;;
    --list)    LIST=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
  shift
done

if [ -z "$PROFILE" ]; then
  if [ "$(uname)" = Darwin ]; then PROFILE=terminal
  elif [ -f /etc/arch-release ]; then PROFILE=desktop
  else PROFILE=terminal; fi
fi

# ---- the parts: id | group | label | where (desktop, terminal or both)
PARTS='
pkg-pacman|Packages|System and desktop packages (pacman)|desktop
pkg-aur|Packages|AUR packages (yay)|desktop
pkg-terminal|Packages|Terminal tools (apt / Homebrew)|terminal
zsh|Configs|zsh + prompt (.zshrc, powerlevel10k)|both
shell|Configs|Shell aliases (shellrc)|both
tmux|Configs|tmux|both
nvim|Configs|Neovim|both
kitty|Configs|kitty terminal|desktop
hypr|Configs|Hyprland + session (hypr, uwsm, autostart)|desktop
torii|Configs|Torii shell: notch, launcher, theme (quickshell, torii, waybar)|desktop
setup|Desktop setup|Wallpapers, services, Dolphin, app launcher entries|desktop
personal|Desktop setup|Personal data from the home server (skipped if unreachable)|desktop
mirrors|Desktop setup|Package mirrors on the home server (skipped if unreachable)|desktop
claude|Desktop setup|Claude Code status line|desktop
nvidia|Desktop setup|NVIDIA driver (skipped without an NVIDIA GPU)|desktop
ssh|Account|Authorize your GitHub SSH keys, make an SSH key|both
login-shell|Account|Make zsh the login shell|both
'
ITEM_ID=() ITEM_GROUP=() ITEM_LABEL=() ITEM_ON=()
while IFS='|' read -r id group label where; do
  [ -n "$id" ] || continue
  if [ "$where" = both ] || [ "$where" = "$PROFILE" ]; then
    # kitty is part of the terminal set on macOS only
    ITEM_ID+=("$id"); ITEM_GROUP+=("$group"); ITEM_LABEL+=("$label"); ITEM_ON+=(1)
  fi
done <<< "$PARTS"
[ "$PROFILE" = terminal ] && [ "$(uname)" = Darwin ] && { ITEM_ID+=(kitty); ITEM_GROUP+=(Configs); ITEM_LABEL+=("kitty terminal"); ITEM_ON+=(1); }

if [ "$LIST" = 1 ]; then
  echo "profile: $PROFILE"
  for i in "${!ITEM_ID[@]}"; do printf '  %-13s %s: %s\n' "${ITEM_ID[i]}" "${ITEM_GROUP[i]}" "${ITEM_LABEL[i]}"; done
  exit 0
fi

# --only / --skip
set_all() { for i in "${!ITEM_ON[@]}"; do ITEM_ON[i]=$1; done; }
mark() {   # mark <comma list> <0|1>
  local name found
  for name in ${1//,/ }; do
    found=0
    for i in "${!ITEM_ID[@]}"; do [ "${ITEM_ID[i]}" = "$name" ] && { ITEM_ON[i]=$2; found=1; }; done
    [ "$found" = 1 ] || echo "!!  no such part for this system: $name (see --list)"
  done
}
[ -n "$ONLY" ] && { set_all 0; mark "$ONLY" 1; }
[ -n "$SKIP" ] && mark "$SKIP" 0

if [ -z "$ONLY$SKIP" ] && [ "$ALL" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
  # shellcheck source=packages/select.sh
  . packages/select.sh
  torii_select "torii-dotfiles: what to install on this system ($PROFILE)" || { echo "Cancelled, nothing was changed."; exit 1; }
fi

want() { local i; for i in "${!ITEM_ID[@]}"; do [ "${ITEM_ID[i]}" = "$1" ] && [ "${ITEM_ON[i]}" = 1 ] && return 0; done; return 1; }
say() { printf '\n==> %s\n' "$*"; }

chosen=""; for i in "${!ITEM_ID[@]}"; do [ "${ITEM_ON[i]}" = 1 ] && chosen="$chosen ${ITEM_ID[i]}"; done
[ -n "$chosen" ] || { echo "Nothing selected."; exit 0; }
say "Installing:$chosen"

# ---- packages
if [ "$PROFILE" = desktop ]; then
  if want pkg-pacman || want pkg-aur; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Syu
  fi
  if want pkg-pacman; then
    say "pacman packages"
    PKG_ONLY=pacman bash packages/install.sh
    if [ -f /boot/limine.conf ] && ! grep -q '^quiet:' /boot/limine.conf; then
      sudo sed -i '/^timeout:.*/a quiet: yes' /boot/limine.conf
    fi
  fi
  if want pkg-aur; then
    say "AUR packages"
    PKG_ONLY=aur bash packages/install.sh
  fi
else
  want pkg-terminal && { say "Terminal tools"; bash packages/terminal.sh; }
fi

# ---- configs (each is a plain symlink; whatever was there goes to the backup folder first)
paths=()
want zsh   && paths+=(.zshrc .zprofile .p10k.zsh)
want shell && paths+=(.config/dotfiles)
want tmux  && paths+=(.config/tmux)
want nvim  && paths+=(.config/nvim)
want kitty && paths+=(.config/kitty)
want hypr  && paths+=(.config/hypr .config/uwsm .config/autostart/localsend_app.desktop)
want torii && paths+=(.config/torii .config/quickshell .config/waybar)
if [ ${#paths[@]} -gt 0 ]; then
  say "Linking configs (anything in the way is moved to ~/.local/state/torii/backup first)"
  mkdir -p ~/.config ~/.local/share ~/.local/state
  bash packages/link.sh paths "${paths[@]}"
fi

if want zsh; then
  say "powerlevel10k"
  [ -d ~/.local/share/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k
fi

# ---- desktop setup
want setup    && { say "Torii shell (wallpapers, theme, services)"; bash packages/torii-setup.sh; }
want personal && { say "Personal data from the home server"; bash packages/personal.sh || true; bash packages/apps-sync.sh || true; }
want mirrors  && { say "Mirrors on the home server"; bash packages/mirrors.sh || true; }
want claude   && { say "Claude Code status line (adds one key to ~/.claude/settings.json)"; bash packages/claude-statusline.sh || true; }
want nvidia   && { say "NVIDIA driver"; bash packages/nvidia.sh || true; }

# ---- account
if want ssh; then
  say "SSH keys"
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
  if keys="$(curl -fsSL https://github.com/equa-tory.keys)"; then
    while IFS= read -r key; do
      grep -qxF "$key" ~/.ssh/authorized_keys || echo "$key" >> ~/.ssh/authorized_keys
    done <<< "$keys"
  else
    echo "!!  could not fetch the GitHub keys, skipping"
  fi
  [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -N "" -t ed25519 -f ~/.ssh/id_ed25519
fi
if want login-shell; then
  say "zsh as the login shell"
  [ "$(basename "${SHELL:-}")" = zsh ] || chsh -s "$(command -v zsh)" || echo "    (chsh failed: run it yourself)"
fi

say "Setup complete. Anything that was in the way is in ~/.local/state/torii/backup (restore: packages/link.sh --restore <date-time>)"
