# Dotfiles

Personal dotfiles for Linux, macOS, FreeBSD, and OpenBSD, installed as symlinks with OS overlays.

## Install

```sh
git clone https://github.com/OleksandrChekhovskyi/dotfiles ~/source/dotfiles
cd ~/source/dotfiles
./install.sh
```

Existing files move to `~/.dotfiles-backup/<timestamp>/`; reruns skip correct symlinks.

## Layout

- `home/` mirrors `$HOME` and contains shared files.
- `home.macos/`, `home.linux/`, `home.freebsd/`, and `home.openbsd/` are optional overlays.
- An overlay file replaces the corresponding shared file on that OS.

For example, `home.freebsd/.config/example` overrides `home/.config/example` on FreeBSD.

## Plugin dependencies

`plugins.py` manages external Git repositories separately from `install.sh`, which stays offline.
It requires Python 3.11+ and Git.

`plugins.json` declares groups, targets, URLs, and branch/tag refs; `plugins.lock` pins exact commits.
Track both files in Git. Checkouts are installed outside this repository.

Two groups are defined, `vim` and `nvim`. Neither config repeats the plugin list, so a sync is
enough to make a machine match the checked-in configuration.

```sh
./plugins.py sync vim            # Install locked revisions
./plugins.py status --all
./plugins.py sync --all --dry-run
./plugins.py update vim fzf.vim   # Update one dependency and its lock entry
./plugins.py update vim          # Update the whole group
./plugins.py sync --all          # Also clean up removed dependencies/groups
./plugins.py gc --dry-run
./plugins.py gc                  # Confirm permanent deletion of quarantined checkouts
```

To add a dependency, edit the manifest and run `update GROUP NAME`. To remove one, delete its
manifest entry and run `sync GROUP`. Sync never selects newer revisions; missing or stale pins
require an explicit update.

Ownership records and quarantine live under `${XDG_STATE_HOME:-~/.local/state}/dotfiles/plugins/`.
Keep this state: existing directories cannot be adopted without it. Unknown paths, changed origins,
and local edits in retained checkouts are refused. Removed and replaced checkouts are quarantined,
not deleted, until `gc` is confirmed.

To change a group's target, first empty its repository list and sync at the old target, then change
the target and restore the list. Targets support `~` and `${XDG_DATA_HOME}` (default `~/.local/share`).
The optional group setting `"helptags": true` generates help indexes using Vim. Dependencies must be
listed explicitly; binary installation, submodules, and arbitrary build hooks are not supported.

A repository pinned to a tag ref stays on that tag; bumping it means editing `ref` in the manifest
rather than running `update`. blink.cmp is pinned this way because it downloads a prebuilt library
for the release it is checked out at.

## Tests

```sh
python3 -m unittest discover -s tests -v
```

The Python tests use only temporary local Git repositories and never modify installed plugins.

## Shell setup

The shell files are split by responsibility:

| File | Role |
| --- | --- |
| `~/.profile` | Login environment: `PATH`, `EDITOR`, `ENV`, and local environment |
| `~/.shrc` | Interactive settings shared by Bash, FreeBSD `sh`, and OpenBSD `ksh` |
| `~/.bashrc` | Bash-only history, bindings, and local interactive configuration |
| `~/.bash_profile` | Bash login bridge that loads `.profile` and `.bashrc` |

Typical loading paths are:

```text
Bash login:                 .bash_profile -> .profile + .bashrc -> .shrc
Bash interactive non-login: .bashrc -> .shrc
FreeBSD/OpenBSD login:      .profile -> .shrc through ENV
BSD interactive non-login:  .shrc through inherited ENV
```

Non-interactive scripts normally load none of these files.

## Machine-local configuration

Put exported environment variables, paths, and secrets in `~/.profile.local`:

```sh
export ANTHROPIC_API_KEY='...'
export OPENAI_API_KEY='...'
```

Protect files containing secrets:

```sh
chmod 600 ~/.profile.local
```

Use `~/.bashrc.local` only for machine-specific Bash aliases, functions, or bindings.
Neither local file is tracked.

The hostname is bright white by default; set an ANSI SGR color in `~/.profile.local`:

```sh
export DOTFILES_PROMPT_HOST_COLOR='1;31'  # bright red
```

Common values include blue (`1;34`), magenta (`1;35`), and cyan (`1;36`). Exported shell
variables are inherited by child processes; system services need environment configuration through
their service manager instead.
