# Login/session environment.
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"

# Suppress Sway's unsupported GPU driver warning at startup.
export SWAY_UNSUPPORTED_GPU=true

# FreeBSD sh and OpenBSD ksh read ENV for every interactive shell.
ENV=$HOME/.shrc
export ENV

if [ -f "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
