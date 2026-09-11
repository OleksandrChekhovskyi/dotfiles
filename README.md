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

## Plugins and parsers

Editor plugins and Neovim's Tree-sitter parsers are installed outside this repository by two
scripts. Both need the network, so `install.sh` never runs them and stays offline. Both reconcile
what is on disk against a tracked JSON manifest, and neither editor repeats the list in its own
config, so a sync is enough to make a machine match the checked-in configuration.

- `plugins.py` checks out pinned Git repositories into the Vim and Neovim package directories.
  `plugins.json` declares groups, targets, and branch/tag refs; `plugins.lock` pins exact commits.
  Two groups are defined, `vim` and `nvim`.
- `treesitter.py` builds Neovim's Tree-sitter parsers and installs their queries.
  `treesitter.json` lists the languages. Revisions and query files come from the pinned
  `nvim-treesitter` checkout, so `plugins.lock` pins the parsers too.

```sh
./plugins.py sync --all             # Install the locked revisions, drop removed ones
./plugins.py update nvim fzf-lua    # Bump one plugin and its lock entry
./treesitter.py sync                # Rebuild parsers that moved, drop unpinned ones
```

To set up or update a machine, run `./install.sh` and then those two syncs, `treesitter.py` last:
parsers do not follow an `nvim-treesitter` bump on their own. Both scripts accept `status` and
`--dry-run`. Track `plugins.json`, `plugins.lock`, and `treesitter.json` in Git.

Forks are developed in place. `link` replaces a plugin's checkout with a symlink to a clone of
your own, so the editor loads the work tree you edit and nothing has to be pushed to try it.

```sh
./plugins.py link nvim neo-tree.nvim ~/extern/neovim-plugins/neo-tree.nvim
./plugins.py unlink nvim neo-tree.nvim
```

Links are machine-local and stay out of `plugins.json`. `sync` leaves a linked clone alone,
`update` still takes the pin from the remote, so push before bumping the lock, and `unlink`
restores the pinned checkout on the next sync.

Each script's header comment is the reference for its manifest format, update workflow, and how it
handles removals, state, and failures. `--help` prints it.

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
