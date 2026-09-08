#!/usr/bin/env python3
"""Reconcile named groups of pinned Git repositories (Python 3.11+, Unix)."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Iterator
import uuid

ROOT = Path(__file__).resolve().parent
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*\Z")
SHA = re.compile(r"[0-9a-f]{40}\Z")


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected an object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            json.dump(value, file, indent=2, sort_keys=True)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def git(*args: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        ["git", *args], cwd=cwd, text=True, capture_output=True,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or f"git failed: {args}")
    return result.stdout.strip()


def expand_target(value: str) -> Path:
    # Never evaluate shell expressions.
    if not isinstance(value, str):
        raise ValueError("target must be a string")
    value = value.replace("${XDG_DATA_HOME}",
                          os.environ.get("XDG_DATA_HOME") or "~/.local/share")
    if "$" in value:
        raise ValueError(f"unsupported target variable: {value}")
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise ValueError(f"target must be absolute: {value}")
    return path.resolve()


def manifest(path: Path) -> dict[str, Any]:
    data = read_json(path)
    if set(data) != {"groups"} or not isinstance(data["groups"], dict):
        raise ValueError("manifest must contain a groups object")
    groups = data["groups"]
    targets: list[Path] = []
    for group, spec in groups.items():
        if (not NAME.fullmatch(group) or not isinstance(spec, dict)
                or not {"target", "repos"} <= spec.keys()
                or set(spec) - {"target", "repos", "helptags"}):
            raise ValueError(f"invalid group: {group}")
        if not isinstance(spec.get("helptags", False), bool):
            raise ValueError(f"{group}: helptags must be a boolean")
        target = expand_target(spec["target"])
        if target == Path.home().resolve() or target == Path("/"):
            raise ValueError(f"unsafe target: {target}")
        if any(target == old or target in old.parents or old in target.parents for old in targets):
            raise ValueError("group targets must not overlap")
        targets.append(target)
        if not isinstance(spec["repos"], dict):
            raise ValueError(f"{group}: repos must be an object")
        for name, repo in spec["repos"].items():
            if (not NAME.fullmatch(name) or not isinstance(repo, dict)
                    or set(repo) != {"url", "ref"}):
                raise ValueError(f"invalid repository: {group}/{name}")
            if any(not isinstance(v, str) or not v or v.startswith("-") for v in repo.values()):
                raise ValueError(f"invalid URL/ref: {group}/{name}")
            git("check-ref-format", repo["ref"])
            if not repo["ref"].startswith(("refs/heads/", "refs/tags/")):
                raise ValueError(f"{name}: use a full refs/heads/... or refs/tags/... ref")
    return groups


@contextmanager
def process_lock(path: Path) -> Iterator[None]:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as file:
        try:
            fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError("another plugin operation is running") from None
        yield


def inspect(path: Path, owner: dict[str, str]) -> tuple[str, bool]:
    if path.is_symlink() or not (path / ".git").is_dir():
        raise ValueError(f"not a managed Git checkout: {path}")
    if git("remote", "get-url", "origin", cwd=path) != owner["url"]:
        raise ValueError(f"origin changed: {path}")
    head = git("rev-parse", "HEAD", cwd=path)
    # Ignored build artifacts survive replacement in quarantine too.
    dirty = bool(git("status", "--porcelain", "--untracked-files=all", cwd=path))
    return head, dirty


def quarantine(path: Path, state_dir: Path) -> None:
    trash = state_dir / "trash"
    trash.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = trash / f"{stamp}-{uuid.uuid4().hex[:8]}-{path.name}"
    shutil.move(str(path), str(destination))
    print(f"quarantine {path} -> {destination}")


def helptags(path: Path) -> None:
    doc = path / "doc"
    if not doc.is_dir():
        return
    result = subprocess.run(
        ["vim", "-u", "NONE", "-i", "NONE", "-n", "-es",
         "-c", "execute 'helptags ' . fnameescape($DOTFILES_PLUGIN_DOC)", "-c", "qa!"],
        env={**os.environ, "DOTFILES_PLUGIN_DOC": str(doc)}, capture_output=True, text=True,
    )
    if result.returncode:
        raise ValueError(f"helptags failed: {doc}: {result.stderr.strip()}")
    with (path / ".git/info/exclude").open("a") as file:
        file.write("\n/doc/tags\n/doc/tags-??\n")


def checkout(parent: Path, repo: dict[str, str], commit: str | None) -> tuple[Path, str]:
    parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".plugins-", dir=parent))
    try:
        git("init", "--quiet", str(staging))
        git("remote", "add", "origin", repo["url"], cwd=staging)
        git("fetch", "--quiet", "--depth=1", "origin", commit or repo["ref"], cwd=staging)
        resolved = git("rev-parse", "FETCH_HEAD^{commit}", cwd=staging)
        if commit and resolved != commit:
            raise ValueError(f"requested {commit}, fetched {resolved}")
        git("-c", "core.hooksPath=/dev/null", "checkout", "--quiet", "--detach", resolved,
            cwd=staging)
        if (staging / ".gitmodules").exists():
            raise ValueError("submodules are not supported")
        return staging, resolved
    except BaseException:
        shutil.rmtree(staging)
        raise


def reconcile(args: argparse.Namespace, state_dir: Path) -> None:
    groups = manifest(args.manifest)
    lock = read_json(args.lockfile)
    state_path = state_dir / "installed.json"
    state = read_json(state_path)
    for group, record in state.items():
        if (not NAME.fullmatch(group) or not isinstance(record, dict)
                or set(record) != {"target", "repos"}
                or not isinstance(record["repos"], dict)):
            raise ValueError(f"invalid ownership record: {group}")
        if str(expand_target(record["target"])) != record["target"]:
            raise ValueError(f"ownership target changed: {group}")
        for name, owner in record["repos"].items():
            if (not NAME.fullmatch(name) or not isinstance(owner, dict)
                    or set(owner) != {"url", "commit"}
                    or not isinstance(owner["url"], str)
                    or not isinstance(owner["commit"], str)
                    or not SHA.fullmatch(owner["commit"])):
                raise ValueError(f"invalid ownership record: {group}/{name}")
    for group, pins in lock.items():
        if not NAME.fullmatch(group) or not isinstance(pins, dict):
            raise ValueError(f"invalid lock group: {group}")
        for name, pin in pins.items():
            if (not NAME.fullmatch(name) or not isinstance(pin, dict)
                    or set(pin) != {"url", "ref", "commit"}
                    or any(not isinstance(value, str) for value in pin.values())
                    or not SHA.fullmatch(pin["commit"])):
                raise ValueError(f"invalid lock entry: {group}/{name}")
    selected = sorted(set(groups) | set(state) | set(lock)) if args.all else [args.group]
    if args.all == bool(args.group):
        raise ValueError("specify either a group or --all")
    if args.name and (args.command != "update" or args.all):
        raise ValueError("a repository name requires update GROUP NAME")

    for group in selected:
        if group not in groups and group not in state:
            if group not in lock:
                raise ValueError(f"unknown group: {group}")
            print(f"{group}: remove stale lock entries (no local installation)")
            if args.command != "status" and not args.dry_run:
                del lock[group]
                write_json(args.lockfile, lock)
            continue
        previous = state.get(group, {})
        spec = groups.get(group, {"target": previous.get("target"), "repos": {}})
        target = expand_target(spec["target"])
        if previous and previous["target"] != str(target):
            raise ValueError(f"{group}: target changed; empty and sync the old group first")
        owners = previous.get("repos", {})
        repos = spec["repos"]
        pins = lock.get(group, {})
        if args.name and args.name not in repos:
            raise ValueError(f"unknown repository: {group}/{args.name}")
        if target.exists():
            unknown = {p.name for p in target.iterdir()} - owners.keys()
            if unknown:
                raise ValueError(f"{target}: unowned paths: {', '.join(sorted(unknown))}")
        observations = {}
        for name, owner in owners.items():
            path = target / name
            if path.exists() or path.is_symlink():
                observations[name] = inspect(path, owner)

        # Validate the whole group before network access or filesystem changes.
        for name, repo in repos.items():
            updating = args.command == "update" and (not args.name or args.name == name)
            pin = pins.get(name, {})
            valid = (pin.get("url") == repo["url"] and pin.get("ref") == repo["ref"]
                     and bool(SHA.fullmatch(pin.get("commit", ""))))
            if not updating and not valid and args.command != "status":
                raise ValueError(f"{group}/{name}: missing/stale lock; run update {group} {name}")
            if name in observations:
                head, dirty = observations[name]
                if args.command != "status" and (dirty or head != owners[name]["commit"]):
                    raise ValueError(f"{group}/{name}: local changes; refusing to replace checkout")
            current = observations.get(name)
            status = "missing" if current is None else (
                "dirty" if current[1] else "ok" if valid and current[0] == pin["commit"]
                else "mismatched")
            print(f"{group}/{name}: {'update' if updating else status}")
        for name in sorted(owners.keys() - repos.keys()):
            dirty = observations.get(name, ("", False))[1]
            print(f"{group}/{name}: remove{' (local files preserved)' if dirty else ''}")
        if args.command == "status" or args.dry_run:
            continue

        prepared: dict[str, tuple[Path, str]] = {}
        new_pins = {}
        try:
            for name, repo in repos.items():
                updating = args.command == "update" and (not args.name or args.name == name)
                commit = None if updating else pins[name]["commit"]
                if (updating or name not in observations or observations[name][0] != commit
                        or owners[name]["url"] != repo["url"]):
                    staging, commit = checkout(target.parent, repo, commit)
                    if (name in observations and observations[name][0] == commit
                            and owners[name]["url"] == repo["url"]):
                        shutil.rmtree(staging)
                        new_pins[name] = {**repo, "commit": commit}
                        continue
                    prepared[name] = staging, commit
                    if spec.get("helptags", False):
                        helptags(staging)
                new_pins[name] = {**repo, "commit": commit}
            target.mkdir(parents=True, exist_ok=True)
            state[group] = {"target": str(target), "repos": owners}
            for name in sorted(owners.keys() - repos.keys()):
                path = target / name
                if path.exists():
                    quarantine(path, state_dir)
                del owners[name]
                write_json(state_path, state)
            for name, (staging, commit) in prepared.items():
                path = target / name
                if path.exists():
                    quarantine(path, state_dir)
                # Record ownership before activation, so an interrupted run can recover.
                owners[name] = {"url": repos[name]["url"], "commit": commit}
                write_json(state_path, state)
                staging.rename(path)
                print(f"install {group}/{name} {commit}")
            if not repos:
                state.pop(group, None)
                lock.pop(group, None)
            else:
                lock[group] = new_pins
            write_json(state_path, state)
            write_json(args.lockfile, lock)
        finally:
            for staging, _ in prepared.values():
                if staging.exists():
                    shutil.rmtree(staging)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=ROOT / "plugins.json")
    parser.add_argument("--lockfile", type=Path, default=ROOT / "plugins.lock")
    parser.add_argument("--state-dir", type=Path, default=Path(
        os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state"
    ) / "dotfiles/plugins")
    parser.add_argument("command", choices=("sync", "update", "status", "gc"))
    parser.add_argument("group", nargs="?")
    parser.add_argument("name", nargs="?")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        with process_lock(args.state_dir / "operation.lock"):
            if args.command == "gc":
                if args.group or args.name or args.all:
                    raise ValueError("gc takes no group or repository")
                trash = args.state_dir / "trash"
                entries = sorted(trash.iterdir()) if trash.exists() else []
                for entry in entries:
                    print(f"delete {entry}")
                if entries and not args.dry_run:
                    if input("Permanently delete these quarantined checkouts? [y/N] ") == "y":
                        for entry in entries:
                            if entry.is_symlink() or entry.is_file():
                                entry.unlink()
                            else:
                                shutil.rmtree(entry)
            else:
                reconcile(args, args.state_dir)
        return 0
    except (ValueError, OSError, TypeError, KeyError, EOFError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
