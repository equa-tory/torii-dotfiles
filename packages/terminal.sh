#!/usr/bin/env bash
# The terminal set (zsh, p10k, tmux, nvim, shell aliases) on macOS (Homebrew) and Debian/Ubuntu (apt).
# Arch uses packages/install.sh instead. No GUI, no sudo on macOS.
set -euo pipefail

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO="sudo"

nvim_ok() { command -v nvim >/dev/null && nvim --version | head -1 | grep -qE 'v0\.(1[1-9]|[2-9][0-9])|v[1-9]'; }

case "$(uname)" in
  Darwin)
    command -v brew >/dev/null || { echo "!!  Homebrew is missing: https://brew.sh"; exit 1; }
    brew install git curl zsh tmux neovim ripgrep fd fzf zoxide eza zsh-autosuggestions zsh-syntax-highlighting
    brew install --cask kitty || true
    ;;
  Linux)
    command -v apt-get >/dev/null || { echo "!!  only apt based systems are handled here (Arch: ./install.sh)"; exit 1; }
    $SUDO apt-get update
    $SUDO apt-get install -y git curl zsh tmux ripgrep fd-find fzf zoxide build-essential unzip \
      zsh-autosuggestions zsh-syntax-highlighting
    $SUDO apt-get install -y eza 2>/dev/null || echo "    (eza is not in this release, ll falls back to ls)"
    # Debian names the fd binary fdfind; shellrc already handles that
    if ! nvim_ok; then
      echo "==> Neovim >= 0.11 from the official release (apt's is too old)"
      arch="$(uname -m)"; case "$arch" in aarch64|arm64) asset=nvim-linux-arm64 ;; *) asset=nvim-linux-x86_64 ;; esac
      mkdir -p ~/.local/opt ~/.local/bin
      tmp="$(mktemp -d)"
      curl -fL "https://github.com/neovim/neovim/releases/latest/download/$asset.tar.gz" -o "$tmp/nvim.tgz"
      rm -rf ~/.local/opt/nvim && mkdir -p ~/.local/opt/nvim
      tar -xzf "$tmp/nvim.tgz" -C ~/.local/opt/nvim --strip-components=1
      ln -sf ~/.local/opt/nvim/bin/nvim ~/.local/bin/nvim
      rm -rf "$tmp"
    fi
    ;;
  *) echo "!!  unsupported system: $(uname)"; exit 1 ;;
esac

echo "==> Installing powerlevel10k"
[ -d ~/.local/share/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k

echo "==> Setting zsh as default shell"
[ "$(basename "${SHELL:-}")" = zsh ] || chsh -s "$(command -v zsh)" || echo "    (chsh failed: run it yourself)"
