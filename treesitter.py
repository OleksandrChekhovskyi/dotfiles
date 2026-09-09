#!/usr/bin/env python3
"""Build pinned Tree-sitter parsers and queries for Neovim (Python 3.11+, Unix).

Requires Neovim, the tree-sitter CLI, curl, and tar. treesitter.json names the languages to
build, the install directory, and the nvim-treesitter checkout to read. That checkout supplies
both the grammar revisions and the query files, so plugins.lock pins them transitively; run a
sync after bumping nvim-treesitter, since parsers do not follow it on their own.

Add or remove a language by editing "languages" and running sync. Languages named by an entry's
"requires" are pulled in automatically to supply the query sets that others inherit, such as
ecma for typescript. Grammars without a pinned revision are refused, as are install options
this script does not implement, so a change upstream fails loudly instead of quietly producing
parsers that differ between machines.

This script owns parser/, parser-info/, and queries/ under the install directory. Every sync
stages all three and swaps them in, so anything the manifest does not name is dropped, and
unchanged parsers are carried over rather than rebuilt. Builds run in parallel and are
all-or-nothing: a failure aborts before the swap. Queries are copied rather than symlinked into
the checkout, so replacing nvim-treesitter cannot leave queries and parsers on different
revisions.

--force rebuilds everything; to rebuild one language, delete its parser-info/LANGUAGE.revision
stamp and sync. The Neovim config only calls vim.treesitter.start.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any

from plugins import expand_target, process_lock, read_json

ROOT = Path(__file__).resolve().parent
LANGUAGE = re.compile(r"[a-z][a-z0-9_]*\Z")
SEGMENT = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
INSTALL_INFO = {"url", "revision", "branch", "location", "generate", "generate_from_json"}
DIRECTORIES = ("parser", "parser-info", "queries")

# nvim-treesitter stores the grammar table as a Lua literal; let Neovim read it and
# report the parser ABI it accepts in the same pass.
DUMP = """
local ok, parsers = pcall(dofile, arg[1])
if not ok then
  io.stderr:write(tostring(parsers))
  os.exit(1)
end
io.write(vim.json.encode({ abi = vim.treesitter.language_version, parsers = parsers }))
"""


def run(command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    result = subprocess.run(
        command, cwd=cwd, text=True, capture_output=True,
        env={**os.environ, **(env or {})} if env else None,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ValueError(f"{command[0]} failed: {detail}")


def manifest(path: Path) -> tuple[Path, Path, list[str]]:
    data = read_json(path)
    if set(data) != {"install_dir", "source", "languages"}:
        raise ValueError("manifest must contain install_dir, source, and languages")
    languages = data["languages"]
    if not isinstance(languages, list) or not languages:
        raise ValueError("languages must be a non-empty list")
    if any(not isinstance(name, str) or not LANGUAGE.fullmatch(name) for name in languages):
        raise ValueError("languages must be lowercase parser names")
    if len(set(languages)) != len(languages):
        raise ValueError("languages must be unique")
    install_dir = expand_target(data["install_dir"])
    source = expand_target(data["source"])
    if install_dir in (Path.home().resolve(), Path("/")):
        raise ValueError(f"unsafe install_dir: {install_dir}")
    # The checkout normally sits under install_dir, which is fine; it just must not
    # sit inside one of the directories this script replaces wholesale.
    if any(source == install_dir / name or install_dir / name in source.parents
           for name in DIRECTORIES):
        raise ValueError(f"source must not live inside {', '.join(DIRECTORIES)}")
    return install_dir, source, sorted(languages)


def parser_table(source: Path) -> tuple[int, dict[str, Any]]:
    table = source / "lua/nvim-treesitter/parsers.lua"
    if not table.is_file():
        raise ValueError(f"missing grammar table: {table}")
    with tempfile.NamedTemporaryFile("w", suffix=".lua") as script:
        script.write(DUMP)
        script.flush()
        result = subprocess.run(
            ["nvim", "--clean", "--headless", "-l", script.name, str(table)],
            text=True, capture_output=True,
        )
    if result.returncode:
        raise ValueError(f"could not read {table}: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    return data["abi"], data["parsers"]


def install_info(language: str, entry: dict[str, Any]) -> dict[str, Any] | None:
    """Validate one grammar entry, or return None for query-only pseudo-languages."""
    info = entry.get("install_info")
    if info is None:
        return None
    if not isinstance(info, dict):
        raise ValueError(f"{language}: invalid install info")
    unknown = set(info) - INSTALL_INFO
    if unknown:
        raise ValueError(f"{language}: unsupported install info: {', '.join(sorted(unknown))}")
    url = info.get("url")
    if not isinstance(url, str) or not url.startswith("https://"):
        raise ValueError(f"{language}: install info must carry an https URL")
    revision = info.get("revision")
    if not isinstance(revision, str) or not SEGMENT.fullmatch(revision):
        # Entries pinned to a branch instead of a commit would rebuild differently
        # over time, which defeats the point of building from a locked checkout.
        raise ValueError(f"{language}: no pinned revision")
    location = info.get("location")
    if location is not None:
        if not isinstance(location, str) or not location:
            raise ValueError(f"{language}: invalid location")
        if any(not SEGMENT.fullmatch(part) for part in location.split("/")):
            raise ValueError(f"{language}: invalid location: {location}")
    for key in ("generate", "generate_from_json"):
        if key in info and not isinstance(info[key], bool):
            raise ValueError(f"{language}: {key} must be a boolean")
    return info


def resolve(languages: list[str], parsers: dict[str, Any]) -> dict[str, dict[str, Any] | None]:
    """Expand the manifest over `requires`, which pulls in inherited query sets."""
    selected: dict[str, dict[str, Any] | None] = {}
    pending = list(languages)
    while pending:
        language = pending.pop(0)
        if language in selected:
            continue
        if language not in parsers:
            raise ValueError(f"unknown language: {language}")
        entry = parsers[language]
        # Lua encodes an empty table as a JSON array; query-only entries can be empty.
        if entry == []:
            entry = {}
        if not isinstance(entry, dict):
            raise ValueError(f"{language}: invalid grammar entry")
        selected[language] = install_info(language, entry)
        requires = entry.get("requires", [])
        if not isinstance(requires, list):
            raise ValueError(f"{language}: invalid requires")
        pending.extend(requires)
    return {name: selected[name] for name in sorted(selected)}


def installed_revision(install_dir: Path, language: str) -> str | None:
    try:
        return (install_dir / "parser-info" / f"{language}.revision").read_text().strip()
    except OSError:
        return None


def survey(install_dir: Path) -> dict[str, set[str]]:
    found = {}
    for name in DIRECTORIES:
        directory = install_dir / name
        found[name] = {path.name for path in directory.iterdir()} if directory.is_dir() else set()
    return found


def plan(install_dir: Path, source: Path, selected: dict[str, dict[str, Any] | None],
         force: bool) -> tuple[dict[str, str], list[str]]:
    """Return an action per selected language plus the stale names to drop."""
    found = survey(install_dir)
    actions = {}
    for language, info in selected.items():
        queries = (source / "runtime/queries" / language).is_dir()
        # Query directories installed by nvim-treesitter are symlinks into its
        # checkout; replacing them with copies is part of the work.
        fresh = install_dir / "queries" / language
        queries_ok = not queries or (fresh.is_dir() and not fresh.is_symlink())
        if info is None:
            actions[language] = "queries" if force or not queries_ok else "ok"
            continue
        parser_ok = (installed_revision(install_dir, language) == info["revision"]
                     and (install_dir / "parser" / f"{language}.so").is_file())
        if force or not parser_ok:
            actions[language] = "build"
        else:
            actions[language] = "ok" if queries_ok else "queries"
    stale = {name.removesuffix(".so") for name in found["parser"] if name.endswith(".so")}
    stale |= {name.removesuffix(".revision")
              for name in found["parser-info"] if name.endswith(".revision")}
    stale |= found["queries"]
    return actions, sorted(stale - selected.keys())


def download(info: dict[str, Any], cache: Path) -> Path:
    url = info["url"].removesuffix(".git")
    tarball = cache / "grammar.tar.gz"
    run(["curl", "--silent", "--fail", "--show-error", "--retry", "3", "--location",
         f"{url}/archive/{info['revision']}.tar.gz", "--output", str(tarball)])
    extracted = cache / "extracted"
    extracted.mkdir()
    run(["tar", "-xzf", str(tarball), "-C", str(extracted)])
    # Archive names embed the revision, and tags lose their "v" prefix; the tarball
    # holds exactly one top-level directory, so read it rather than guess it.
    children = [path for path in extracted.iterdir() if path.is_dir()]
    if len(children) != 1:
        raise ValueError(f"unexpected archive layout: {url}")
    return children[0]


def build(language: str, info: dict[str, Any], abi: int, staging: Path) -> None:
    with tempfile.TemporaryDirectory(prefix=f"treesitter-{language}-") as name:
        grammar = download(info, Path(name))
        if info.get("location"):
            grammar = grammar / info["location"]
        if info.get("generate"):
            source = "src/grammar.json" if info.get("generate_from_json", True) else None
            run(["tree-sitter", "generate", "--abi", str(abi), *filter(None, [source])],
                cwd=grammar, env={"TREE_SITTER_JS_RUNTIME": "native"})
        run(["tree-sitter", "build", "-o", "parser.so"], cwd=grammar)
        parser = staging / "parser" / f"{language}.so"
        shutil.copyfile(grammar / "parser.so", parser)
        parser.chmod(0o755)
    # Match the format nvim-treesitter reads, so :checkhealth stays accurate.
    (staging / "parser-info" / f"{language}.revision").write_text(info["revision"])


def assemble(install_dir: Path, source: Path, selected: dict[str, dict[str, Any] | None],
             actions: dict[str, str], abi: int, staging: Path, jobs: int) -> None:
    for name in DIRECTORIES:
        (staging / name).mkdir()
    pending = {}
    for language, info in selected.items():
        queries = source / "runtime/queries" / language
        if queries.is_dir():
            shutil.copytree(queries, staging / "queries" / language)
        if info is None:
            continue
        if actions[language] == "build":
            pending[language] = info
            continue
        # Unchanged parsers are carried over so the swap below can replace the whole
        # tree at once without rebuilding everything.
        shutil.copyfile(install_dir / "parser" / f"{language}.so",
                        staging / "parser" / f"{language}.so")
        (staging / "parser" / f"{language}.so").chmod(0o755)
        (staging / "parser-info" / f"{language}.revision").write_text(info["revision"])
    if not pending:
        return
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = {pool.submit(build, language, info, abi, staging): language
                   for language, info in pending.items()}
        for future in concurrent.futures.as_completed(futures):
            language = futures[future]
            try:
                future.result()
            except (ValueError, OSError) as error:
                failures.append(f"{language}: {error}")
            else:
                print(f"built {language} {pending[language]['revision']}")
    if failures:
        raise ValueError("\n".join(["could not build all parsers", *sorted(failures)]))


def swap(install_dir: Path, staging: Path) -> None:
    """Replace the three directories with the staged tree, keeping each rename atomic."""
    discarded = Path(tempfile.mkdtemp(prefix=".treesitter-old-", dir=install_dir))
    try:
        for name in DIRECTORIES:
            current = install_dir / name
            if current.exists() or current.is_symlink():
                current.rename(discarded / name)
            (staging / name).rename(current)
    finally:
        shutil.rmtree(discarded, ignore_errors=True)


def sync(args: argparse.Namespace) -> None:
    install_dir, source, languages = manifest(args.manifest)
    abi, parsers = parser_table(source)
    selected = resolve(languages, parsers)
    actions, stale = plan(install_dir, source, selected, args.force)
    for language, action in actions.items():
        print(f"{language}: {action}")
    for language in stale:
        print(f"{language}: remove")
    if args.command == "status" or args.dry_run:
        return
    if all(action == "ok" for action in actions.values()) and not stale:
        return
    install_dir.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".treesitter-new-", dir=install_dir))
    try:
        assemble(install_dir, source, selected, actions, abi, staging, args.jobs)
        swap(install_dir, staging)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    print(f"installed {len(selected)} languages into {install_dir}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", type=Path, default=ROOT / "treesitter.json")
    parser.add_argument("--state-dir", type=Path, default=Path(
        os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state"
    ) / "dotfiles/treesitter")
    parser.add_argument("command", choices=("sync", "status"))
    parser.add_argument("--force", action="store_true", help="rebuild every parser")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--jobs", type=int, default=min(8, os.cpu_count() or 1))
    args = parser.parse_args()
    if args.jobs < 1:
        print("error: jobs must be positive", file=sys.stderr)
        return 1
    try:
        with process_lock(args.state_dir / "operation.lock"):
            sync(args)
        return 0
    except (ValueError, OSError, TypeError, KeyError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
