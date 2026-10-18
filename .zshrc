# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Created by equa for 5.9.1
bindkey -e   # emacs line editing (Ctrl+A/E, Alt+B/F); zsh would pick vi mode because EDITOR=nvim
source ~/.config/dotfiles/shellrc
[[ -r ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# prompt colours follow the wallpaper (torii-theme); open shells pick up a new wallpaper at the next prompt
zmodload -F zsh/stat b:zstat 2>/dev/null     # portable mtime (no GNU/BSD stat flags)
_torii_p10k=~/.local/state/torii/theme/p10k-colors.zsh
[[ -r $_torii_p10k ]] && source $_torii_p10k
_torii_p10k_sync() {
  local m; m=$(zstat +mtime $_torii_p10k 2>/dev/null) || return
  [[ $m == $_torii_p10k_m ]] && return
  [[ -n $_torii_p10k_m ]] && { source $_torii_p10k; (( $+functions[p10k] )) && p10k reload }
  _torii_p10k_m=$m
}
precmd_functions+=(_torii_p10k_sync)

# suggestions as you type (grey, accept with right arrow) and command colours; syntax-highlighting must be last
# plugin locations: Arch, Debian/Ubuntu, Homebrew (Apple silicon, Intel), a manual clone
# command history that survives a reboot (kept in your home only: it can hold secrets, it is not synced anywhere)
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d ${HISTFILE:h} ]] || mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY EXTENDED_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_FIND_NO_DUPS

_torii_plugin() {
  local p
  for p in /usr/share/zsh/plugins/$1/$1.zsh /usr/share/$1/$1.zsh /opt/homebrew/share/$1/$1.zsh \
           /usr/local/share/$1/$1.zsh ~/.local/share/$1/$1.zsh; do
    [[ -r $p ]] && { source $p; return; }
  done
}
_torii_plugin zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
_torii_plugin zsh-syntax-highlighting
unset -f _torii_plugin

# Home/End (also what Super+Left/Right send in kitty) and word jumps with Ctrl+arrows
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line '^[[F' end-of-line '^[OF' end-of-line
bindkey '^[[1;5D' backward-word '^[[1;5C' forward-word
# Delete (without this the terminal prints a ~) and Ctrl+Delete
bindkey '^[[3~' delete-char '^[[3;5~' kill-word
