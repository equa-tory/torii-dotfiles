#!/usr/bin/env bash
set -euo pipefail

cd ~/torii-dots

echo "==> Setting up torii-dotfiles"

sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
sudo pacman -Syu
bash "packages/install.sh"

mv ~/.config/hypr ~/.config/hypr.bak
mv ~/.config/kitty ~/.config/kitty.bak
mv ~/.zshrc ~/.zshrc.bak
stow .

mkdir ~/.ssh && chmod 700 ~/.ssh
curl https://github.com/equa-tory.keys > ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

echo "==> Setup complete"

