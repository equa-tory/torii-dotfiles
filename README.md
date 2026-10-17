# Torii distro dotfiles

This dir contains the dotfiles for my system

## Installation

Clone the repo anywhere in your `$HOME` and run the installer. It can be run again at any time.

```
git clone https://github.com/equa-tory/torii-dotfiles.git
cd torii-dotfiles
./install.sh
```

| System | What you get | Notes |
|---|---|---|
| **Arch Linux** | the whole desktop: Hyprland, the Quickshell shell, apps, zsh, tmux, nvim | `./install.sh` (profile `desktop`) |
| **macOS** | the terminal set: zsh + powerlevel10k, shell aliases, tmux, nvim, kitty | needs [Homebrew](https://brew.sh); `./install.sh` picks profile `terminal` |
| **Ubuntu / Debian server** | the terminal set: zsh + powerlevel10k, shell aliases, tmux, nvim (>= 0.11 from the official release) | `./install.sh` picks profile `terminal`, uses `sudo apt` |

Force a profile with `./install.sh --profile terminal` (or `desktop`).

**Your existing files are never overwritten.** Anything that is in the way (an old `~/.zshrc`, a `~/.config/nvim` folder, a
single file inside `~/.config/hypr`, ...) is moved to `~/.local/state/torii/backup/<date-time>/` under the same path first.
To put a backup back: `packages/link.sh --restore <date-time>` (list them with `ls ~/.local/state/torii/backup`).

The terminal profile links these paths only: `.zshrc .zprofile .p10k.zsh .config/dotfiles (shell aliases) .config/nvim
.config/tmux` (+ `.config/kitty` on macOS). The files work without the desktop: the wallpaper-theme parts are optional.

The desktop is a Quickshell shell with a wallpaper-driven theme: see [docs/shell/README.md](docs/shell/README.md).
