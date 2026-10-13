#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Setting up torii-dotfiles"

sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu
bash packages/install.sh

echo "==> Installing powerlevel10k"
[ -d ~/.local/share/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k

echo "==> Backing up existing configs"
for p in ~/.zprofile ~/.config/hypr ~/.config/kitty ~/.config/nvim ~/.config/tmux ~/.config/waybar ~/.config/dotfiles ~/.zshrc ~/.p10k.zsh; do
  if [ -e "$p" ] && [ ! -L "$p" ]; then mv "$p" "$p.bak-$(date +%s)"; fi
done

echo "==> Linking dotfiles"
stow .

echo "==> Authorizing SSH keys from GitHub"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
keys="$(curl -fsSL https://github.com/equa-tory.keys)"
while IFS= read -r key; do
  grep -qxF "$key" ~/.ssh/authorized_keys || echo "$key" >> ~/.ssh/authorized_keys
done <<< "$keys"
ssh-keygen -q -N "" -t ed25519 -f ~/.ssh/id_ed25519

echo "==> Setting zsh as default shell"
chsh -s "$(command -v zsh)"

echo "==> Setup complete"
