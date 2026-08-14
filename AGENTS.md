# Dotfiles

Personal dotfiles managed via symlinks.

## Structure

- `home/` — mirrors `$HOME`; each file is symlinked to its corresponding path under `~`
- `home.macos/` — macOS overlay; files override or add to `home/` on macOS
- `home.linux/`, `home.freebsd/`, `home.openbsd/` — optional OS overlays
- `install.sh` — creates symlinks and backs up files under `~/.dotfiles-backup/<timestamp>/`
- `~/.profile.local` — machine-specific environment and secrets (not tracked)
- `~/.bashrc.local` — machine-specific Bash interactive config (not tracked)

## Adding a new dotfile

1. Place the file under `home/` at its path relative to `$HOME`, e.g. `home/.config/git/ignore`.
2. Put OS-specific files at the same path under the matching `home.<os>/` overlay.
3. Run `./install.sh`.

## Portability

- Keep `install.sh`, `home/.profile`, `home/.shrc`, and `home/.local/bin/` scripts POSIX `sh`.
- Keep Bash-only behavior in `home/.bashrc`; shared interactive settings belong in `home/.shrc`.
- Avoid GNU-only flags in shared files. Use `uname` or an OS overlay when behavior must differ.
- Test portable files with `sh -n` and relevant changes in `~/source/vmctl` BSD guests.

## Conventions

- Keep source files and Markdown prose approximately under 100 columns.
- Keep machine-specific paths and secrets in `~/.profile.local`, never in tracked files.
- `install.sh` is idempotent; re-running it skips already-correct symlinks.
