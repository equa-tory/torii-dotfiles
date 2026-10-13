#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Setting up torii-dotfiles"

sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu
bash packages/install.sh
if [ -f /boot/limine.conf ] && ! grep -q '^quiet:' /boot/limine.conf; then
  sudo sed -i '/^timeout:.*/a quiet: yes' /boot/limine.conf
fi


echo "==> Installing powerlevel10k"
[ -d ~/.local/share/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k

echo "==> Backing up existing configs"
for p in ~/.zprofile ~/.config/hypr ~/.config/kitty ~/.config/nvim ~/.config/tmux ~/.config/waybar ~/.config/dotfiles ~/.config/torii ~/.config/quickshell ~/.config/uwsm ~/.zshrc ~/.p10k.zsh; do
  if [ -e "$p" ] && [ ! -L "$p" ]; then mv "$p" "$p.bak-$(date +%s)"; fi
done

echo "==> Linking dotfiles"
# real parent dirs first, otherwise stow folds all of ~/.config into this repo (and apps would write into it)
mkdir -p ~/.config ~/.local/share ~/.local/state
stow .

echo "==> Torii shell (wallpapers, theme, services)"
bash packages/torii-setup.sh

echo "==> Personal data from the home server (skipped if unreachable)"
bash packages/personal.sh || true

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
