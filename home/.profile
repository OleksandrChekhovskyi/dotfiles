# Login/session environment.
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

# FreeBSD sh and OpenBSD ksh read ENV for every interactive shell.
ENV=$HOME/.shrc
export ENV

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
