#!/usr/bin/env bash
set -euo pipefail

DOTFILESDIR="(cd −− "(dirname -- "${BASHSOURCE[0]}")" && pwd)"

echo "==> Setting up torii-dotfiles"

bash "$DOTFILESDIR/packages/install.sh"

sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
echo "source ~/.config/dotfiles/shellrc" >> "$DOTFILESDIR/../.zshrc"
echo "source ~/powerlevel10k/powerlevel10k.zsh-theme" >> "$DOTFILESDIR/../.zshrc"

echo "source ~/.config/dotfiles/shellrc" >> ~/.zshrc
echo "source ~/.config/powerlevel10k/powerlevel10k.zsh-theme" >> ~/.zshrc

mkdir ~/.ssh
curl https://github.com/equa-tory.keys > ~/.ssh/authorized_keys

echo "==> Setup complete"

