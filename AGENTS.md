# Dotfiles

Personal dotfiles managed via symlinks.

## Structure

- `home/` — mirrors `$HOME`; each file is symlinked to its corresponding path under `~`
- `install.sh` — creates symlinks, backs up existing files to `~/.dotfiles-backup/<timestamp>/`
- `~/.bashrc.local` — machine-specific shell config (not tracked)

## Adding a new dotfile

1. Place the file under `home/` at the path it should occupy relative to `$HOME` (e.g. `home/.config/git/ignore`)
2. Run `bash install.sh`

## Conventions

- Keep machine-specific paths and secrets in `~/.bashrc.local`, never in tracked files.
- `install.sh` is idempotent — re-running it skips already-correct symlinks.
- For `nvim-ide` changes, do not run Neovim in sandbox to validate setup (it commonly fails there); validate Lua syntax and ask the user to verify behavior locally.
