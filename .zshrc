# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Created by equa for 5.9.1
source ~/.config/dotfiles/shellrc
source ~/.local/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# suggestions as you type (grey, accept with right arrow) and command colours; syntax-highlighting must be last
for _p in /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do [[ -r $_p ]] && source $_p; done
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
for _p in /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do [[ -r $_p ]] && source $_p; done
unset _p
