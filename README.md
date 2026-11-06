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

`./install.sh` opens a list where you pick what to install (up/down, **space** toggles a part or a whole group, `a` all, `n` none,
**enter** starts, `q` cancels): packages, each config (zsh, shell aliases, tmux, nvim, kitty, Hyprland, the torii shell), the desktop
setup steps and the account steps. Without a terminal, or with `--all`, everything for the system is installed.

```
./install.sh --all                   # no questions
./install.sh --only zsh,tmux         # just these parts
./install.sh --skip nvim,nvidia      # everything except these
./install.sh --list                  # names of the parts for this system
./install.sh --profile terminal      # force the terminal profile (or desktop)
```

**Your existing files are never overwritten.** Anything that is in the way (an old `~/.zshrc`, a `~/.config/nvim` folder, a
single file inside `~/.config/hypr`, ...) is moved to `~/.local/state/torii/backup/<date-time>/` under the same path first.
To put a backup back: `packages/link.sh --restore <date-time>` (list them with `ls ~/.local/state/torii/backup`).

The terminal profile links these paths only: `.zshrc .zprofile .p10k.zsh .config/dotfiles (shell aliases) .config/nvim
.config/tmux` (+ `.config/kitty` on macOS). The files work without the desktop: the wallpaper-theme parts are optional.

The desktop is a Quickshell shell with a wallpaper-driven theme: see [docs/shell/README.md](docs/shell/README.md).

### SSH terminal compatibility

The shared shell config uses `TERM=xterm-256color` for outgoing `ssh` commands
when running in Kitty or Ghostty. This avoids depending on their terminal
definitions being installed on every destination. Other terminal types, including
screen/tmux, are preserved. The local terminal environment is unchanged.

Update this repo on every machine you connect **from**, then open a fresh shell.
Zsh loads the shared config automatically. For Bash, add this to `~/.bashrc`:

```bash
[[ -r ~/.config/dotfiles/shellrc ]] && source ~/.config/dotfiles/shellrc
```

This also covers nested SSH when the intermediate machine loads the shared config.
It applies to interactive shell invocations of `ssh`; applications calling SSH
directly bypass shell functions. Use `command ssh` to bypass the fallback, or
`kitten ssh` for Kitty's native terminal-definition and shell-integration setup.

If redraw problems remain, try `TERM=xterm-256color command ssh user@host`, then
run `zsh -f` on the destination. If the clean shell works, inspect that host's
prompt/plugins. In an affected zsh, `unset RPS1 RPROMPT; PROMPT='%n@%m:%~%# '`
and `(( $+functions[autosuggest-disable] )) && autosuggest-disable` can help
isolate prompt-width and autosuggestion issues. These are temporary diagnostics.
