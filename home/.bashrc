# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
export PS1='\[\033[1;37m\][\u@\h \[\033[1;33m\]\w\[\033[1;37m\]]\$\[\033[0m\] '
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth   # Ignore duplicates and space-prefixed commands
shopt -s histappend      # Append to history file instead of overwriting
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"  # Flush after each command

# Source machine-local config (not tracked in git)
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
