# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Created by equa for 5.9.1
bindkey -e   # emacs line editing (Ctrl+A/E, Alt+B/F); zsh would pick vi mode because EDITOR=nvim
source ~/.config/dotfiles/shellrc
source ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# prompt colours follow the wallpaper (torii-theme); open shells pick up a new wallpaper at the next prompt
_torii_p10k=~/.local/state/torii/theme/p10k-colors.zsh
[[ -r $_torii_p10k ]] && source $_torii_p10k
_torii_p10k_sync() {
  local m; m=$(stat -c %Y $_torii_p10k 2>/dev/null) || return
  [[ $m == $_torii_p10k_m ]] && return
  [[ -n $_torii_p10k_m ]] && { source $_torii_p10k; (( $+functions[p10k] )) && p10k reload }
  _torii_p10k_m=$m
}
precmd_functions+=(_torii_p10k_sync)

# suggestions as you type (grey, accept with right arrow) and command colours; syntax-highlighting must be last
for _p in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do [[ -r $_p ]] && source $_p; done
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
for _p in /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do [[ -r $_p ]] && source $_p; done
unset _p

# Home/End (also what Super+Left/Right send in kitty) and word jumps with Ctrl+arrows
bindkey '^[[H' beginning-of-line '^[OH' beginning-of-line '^[[F' end-of-line '^[OF' end-of-line
bindkey '^[[1;5D' backward-word '^[[1;5C' forward-word
