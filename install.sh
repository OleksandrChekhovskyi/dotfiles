#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"

case "$(uname -s)" in
    Darwin) OS_HOME="$SCRIPT_DIR/home.macos" ;;
    Linux) OS_HOME="$SCRIPT_DIR/home.linux" ;;
    *) OS_HOME="" ;;
esac

has_os_override() {
    local relpath="$1"
    [ -n "$OS_HOME" ] && [ -f "$OS_HOME/$relpath" ]
}

link_file() {
    local src="$1"
    local relpath="$2"
    local target="$HOME/$relpath"
    local backup

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        echo "skip $relpath"
        return
    fi

    # Symlink left by a previous run from this repo: drop without backup.
    if [ -L "$target" ] && [[ "$(readlink "$target")" == "$SCRIPT_DIR"/home*/* ]]; then
        rm "$target"
        echo "relink $relpath"
    elif [ -e "$target" ] || [ -L "$target" ]; then
        backup="$BACKUP_DIR/$relpath"
        mkdir -p "$(dirname "$backup")"
        mv "$target" "$backup"
        echo "backup $relpath -> $backup"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$src" "$target"
    echo "link $relpath"
}

install_tree() {
    local root="$1"
    local skip_overridden="${2:-false}"

    [ -d "$root" ] || return 0

    find "$root" -type f | while read -r src; do
        local relpath="${src#"$root/"}"

        if [ "$skip_overridden" = true ] && has_os_override "$relpath"; then
            continue
        fi

        link_file "$src" "$relpath"
    done
}

install_tree "$SCRIPT_DIR/home" true
install_tree "$OS_HOME"

if [ ! -f "$HOME/.bashrc.local" ]; then
    echo ""
    echo "Reminder: create ~/.bashrc.local for machine-specific config."
fi
