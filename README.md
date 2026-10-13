# Torii distro dotfiles

This dir contains the dotfiles for my system

## Requirements

Ensure you have git installed

### Git
```
pacman -S git
```

### Stow
```
pacman -S stow
```

## Installation
First, clone repo in your $HOME using git
```
git clone git@github.com/equa-tory/torii-dotfiles.git
cd torii-dotfiles
```

then run the installer. It installs the packages, links the dotfiles with stow and sets up the desktop (it can be run again):
```
./install.sh
```

The desktop is a Quickshell shell with a wallpaper-driven theme: see [docs/shell/README.md](docs/shell/README.md).
