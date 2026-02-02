# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
export PS1='\[\033[1;37m\][\u@\h \[\033[1;33m\]\w\[\033[1;37m\]]\$\[\033[0m\] '
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

# Source machine-local config (not tracked in git)
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
