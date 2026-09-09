# Dotfiles

Personal dotfiles managed via symlinks.

## Structure

- `home/` — mirrors `$HOME`; each file is symlinked to its corresponding path under `~`
- `home.macos/` — macOS overlay; files override or add to `home/` on macOS
- `home.linux/`, `home.freebsd/`, `home.openbsd/` — optional OS overlays
- `install.sh` — creates symlinks and backs up files under `~/.dotfiles-backup/<timestamp>/`
- `plugins.py` / `plugins.json` / `plugins.lock` — pinned Vim and Neovim plugin checkouts
- `treesitter.py` / `treesitter.json` — Tree-sitter parsers and queries built for Neovim
- `~/.profile.local` — machine-specific environment and secrets (not tracked)
- `~/.bashrc.local` — machine-specific Bash interactive config (not tracked)

## Adding a new dotfile

1. Place the file under `home/` at its path relative to `$HOME`, e.g. `home/.config/git/ignore`.
2. Put OS-specific files at the same path under the matching `home.<os>/` overlay.
3. Run `./install.sh`.

## Portability

- Shared shell scripts must be portable across Linux, macOS, FreeBSD, and OpenBSD. Check with `sh -n`.
- Keep `install.sh`, `home/.profile`, `home/.shrc`, and `home/.local/bin/` scripts POSIX `sh`.
- Keep Bash-only behavior in `home/.bashrc`; shared interactive settings belong in `home/.shrc`.
- Avoid GNU-only flags in shared files. Use `uname` or an OS overlay when behavior must differ.

## Testing

```sh
python3 -m unittest discover -s tests -v
```

The Python tests use temporary local Git repositories and stub checkouts, never the network or
installed plugins and parsers.

For interactive shell, editor, or tmux changes, use a dedicated tmux test session: `new-session -d`,
`send-keys`, and `capture-pane -p`. Scope cleanup to the exact session you created (`kill-session -t`)
or PID you captured at launch. The user or agent may itself be inside tmux: never use `kill-server`
or broad `pkill` / `killall` commands that could terminate their sessions or your own.

## Conventions

- Keep source files and Markdown prose approximately under 100 columns.
- Keep docs concise: setup and usage in `README.md`, agent workflows and checks here.
- Keep machine-specific paths and secrets in `~/.profile.local`, never in tracked files.
- `install.sh` is idempotent; re-running it skips already-correct symlinks.
