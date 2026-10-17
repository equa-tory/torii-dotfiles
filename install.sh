#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PROFILE=""
if [ "${1:-}" = "--profile" ]; then PROFILE="${2:?terminal|desktop}"; fi
if [ -z "$PROFILE" ]; then
  if [ "$(uname)" = Darwin ]; then PROFILE=terminal
  elif [ -f /etc/arch-release ]; then PROFILE=desktop
  else PROFILE=terminal; fi
fi

echo "==> Setting up torii-dotfiles ($PROFILE profile)"

if [ "$PROFILE" = terminal ]; then
  # macOS / Ubuntu server: zsh, p10k, aliases, tmux, nvim only
  bash packages/terminal.sh
  bash packages/link.sh terminal
  echo "==> Setup complete (existing files were moved to ~/.local/state/torii/backup, restore: packages/link.sh --restore <stamp>)"
  exit 0
fi

sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu
bash packages/install.sh
if [ -f /boot/limine.conf ] && ! grep -q '^quiet:' /boot/limine.conf; then
  sudo sed -i '/^timeout:.*/a quiet: yes' /boot/limine.conf
fi


echo "==> Installing powerlevel10k"
[ -d ~/.local/share/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k

echo "==> Linking dotfiles (anything in the way is moved to ~/.local/state/torii/backup first)"
bash packages/link.sh desktop

echo "==> Torii shell (wallpapers, theme, services)"
bash packages/torii-setup.sh

echo "==> Personal data from the home server (skipped if unreachable)"
bash packages/personal.sh || true
bash packages/apps-sync.sh || true

echo "==> Mirrors on the home server (skipped if unreachable)"
bash packages/mirrors.sh || true

echo "==> Claude Code status line (adds one key to ~/.claude/settings.json)"
bash packages/claude-statusline.sh || true

echo "==> NVIDIA driver (skipped without an NVIDIA GPU)"
bash packages/nvidia.sh || true

echo "==> Authorizing SSH keys from GitHub"
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

echo "==> Setting zsh as default shell"
[ "$(basename "$SHELL")" = zsh ] || chsh -s "$(command -v zsh)"

echo "==> Setup complete"
