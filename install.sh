#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"

OS_NAME=$(uname -s)
case $OS_NAME in
    Darwin) OS_HOME="$SCRIPT_DIR/home.macos" ;;
    Linux) OS_HOME="$SCRIPT_DIR/home.linux" ;;
    FreeBSD) OS_HOME="$SCRIPT_DIR/home.freebsd" ;;
    OpenBSD) OS_HOME="$SCRIPT_DIR/home.openbsd" ;;
    *) OS_HOME= ;;
esac

has_os_override() {
    [ -n "$OS_HOME" ] && [ -f "$OS_HOME/$1" ]
}

link_file() {
    link_src=$1
    link_relpath=$2
    link_target=$HOME/$link_relpath

    if [ -L "$link_target" ] && [ "$(readlink "$link_target")" = "$link_src" ]; then
        echo "skip $link_relpath"
        return
    fi

    # Symlink left by a previous run from this repo: drop without backup.
    if [ -L "$link_target" ]; then
        case $(readlink "$link_target") in
            "$SCRIPT_DIR"/home*/*)
                rm "$link_target"
                echo "relink $link_relpath"
                ;;
            *)
                link_backup=$BACKUP_DIR/$link_relpath
                mkdir -p "$(dirname "$link_backup")"
                mv "$link_target" "$link_backup"
                echo "backup $link_relpath -> $link_backup"
                ;;
        esac
    elif [ -e "$link_target" ]; then
        link_backup=$BACKUP_DIR/$link_relpath
        mkdir -p "$(dirname "$link_backup")"
        mv "$link_target" "$link_backup"
        echo "backup $link_relpath -> $link_backup"
    fi

    mkdir -p "$(dirname "$link_target")"
    ln -s "$link_src" "$link_target"
    echo "link $link_relpath"
}

install_tree() {
    install_root=$1
    install_skip_overridden=${2:-false}

    [ -d "$install_root" ] || return 0

    find "$install_root" -type f | while IFS= read -r install_src; do
        install_relpath=${install_src#"$install_root/"}

        if [ "$install_skip_overridden" = true ] && has_os_override "$install_relpath"; then
            continue
        fi

        link_file "$install_src" "$install_relpath"
    done
}

install_tree "$SCRIPT_DIR/home" true
install_tree "$OS_HOME"

if [ ! -f "$HOME/.profile.local" ]; then
    echo ""
    echo "Reminder: create ~/.profile.local for machine-specific environment config."
fi
