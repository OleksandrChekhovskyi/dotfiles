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
