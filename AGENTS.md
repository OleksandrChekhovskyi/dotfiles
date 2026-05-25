# Dotfiles

Personal dotfiles managed via symlinks.

## Structure

- `home/` — mirrors `$HOME`; each file is symlinked to its corresponding path under `~`
- `home.macos/` — macOS overlay; files here override or add to `home/` when running on macOS
- `home.linux/` — optional Linux overlay using the same convention
- `install.sh` — creates symlinks, backs up existing files to `~/.dotfiles-backup/<timestamp>/`
- `~/.bashrc.local` — machine-specific shell config (not tracked)

## Adding a new dotfile

1. Place the file under `home/` at the path it should occupy relative to `$HOME` (e.g. `home/.config/git/ignore`)
2. For OS-specific files, place them at the same relative path under `home.macos/` or `home.linux/`
3. Run `bash install.sh`

## Conventions

- Keep source files and Markdown prose approximately under 120 columns when practical.
- Keep machine-specific paths and secrets in `~/.bashrc.local`, never in tracked files.
- `install.sh` is idempotent — re-running it skips already-correct symlinks.
