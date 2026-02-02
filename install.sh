#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"

find "$SCRIPT_DIR/home" -type f | while read -r src; do
    relpath="${src#"$SCRIPT_DIR/home/"}"
    target="$HOME/$relpath"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        echo "skip $relpath"
        continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        backup="$BACKUP_DIR/$relpath"
        mkdir -p "$(dirname "$backup")"
        mv "$target" "$backup"
        echo "backup $relpath -> $backup"
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$src" "$target"
    echo "link $relpath"
done

if [ ! -f "$HOME/.bashrc.local" ]; then
    echo ""
    echo "Reminder: create ~/.bashrc.local for machine-specific config."
fi
