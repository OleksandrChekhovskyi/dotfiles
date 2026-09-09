"""Offline tests using a stub nvim-treesitter checkout and a disposable install root."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "treesitter.py"

# Mirrors the shape treesitter.py reads: a grammar entry, a query-only entry pulled in
# through "requires", and entries that must be rejected.
PARSERS = """
return {
  alpha = {
    install_info = { url = 'https://example.invalid/tree-sitter-alpha', revision = 'aaaa' },
    requires = { 'shared' },
  },
  shared = {},
  branchy = { install_info = { url = 'https://example.invalid/x', branch = 'main' } },
  exotic = { install_info = { url = 'https://example.invalid/x', revision = 'a', path = '/p' } },
}
"""


@unittest.skipIf(shutil.which("nvim") is None, "nvim is required to read the grammar table")
class TreesitterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.install = self.root / "site"
        self.source = self.root / "source"
        self.state = self.root / "state"
        table = self.source / "lua/nvim-treesitter/parsers.lua"
        table.parent.mkdir(parents=True)
        table.write_text(PARSERS)
        for language in ("alpha", "shared"):
            queries = self.source / "runtime/queries" / language
            queries.mkdir(parents=True)
            (queries / "highlights.scm").write_text(f"; {language}\n")

    def manifest(self, languages: list[str]) -> Path:
        path = self.root / "treesitter.json"
        path.write_text(json.dumps({
            "install_dir": str(self.install),
            "source": str(self.source),
            "languages": languages,
        }))
        return path

    def install_language(self, language: str, revision: str | None) -> None:
        for name in ("parser", "parser-info", "queries"):
            (self.install / name).mkdir(parents=True, exist_ok=True)
        if revision is not None:
            (self.install / "parser" / f"{language}.so").write_bytes(b"\x7fELF")
            (self.install / "parser-info" / f"{language}.revision").write_text(revision)
        (self.install / "queries" / language).mkdir(exist_ok=True)

    def run_script(self, *args: str, manifest: Path | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--manifest",
             str(manifest or self.manifest(["alpha"])), "--state-dir", str(self.state), *args],
            text=True, capture_output=True, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )

    def test_status_reports_ok_without_touching_the_network(self) -> None:
        self.install_language("alpha", "aaaa")
        self.install_language("shared", None)
        result = self.run_script("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("alpha: ok", result.stdout)
        self.assertIn("shared: ok", result.stdout)

    def test_missing_parser_is_scheduled_for_a_build(self) -> None:
        self.install_language("shared", None)
        result = self.run_script("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("alpha: build", result.stdout)

    def test_stale_revision_is_scheduled_for_a_build(self) -> None:
        self.install_language("alpha", "old")
        self.install_language("shared", None)
        self.assertIn("alpha: build", self.run_script("status").stdout)

    def test_query_symlinks_are_replaced_with_directories(self) -> None:
        self.install_language("alpha", "aaaa")
        self.install_language("shared", None)
        linked = self.install / "queries/alpha"
        shutil.rmtree(linked)
        linked.symlink_to(self.source / "runtime/queries/alpha")
        self.assertIn("alpha: queries", self.run_script("status").stdout)
        result = self.run_script("sync")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(linked.is_dir())
        self.assertFalse(linked.is_symlink())
        self.assertEqual((linked / "highlights.scm").read_text(), "; alpha\n")

    def test_unpinned_languages_are_removed(self) -> None:
        self.install_language("alpha", "aaaa")
        self.install_language("shared", None)
        self.install_language("stale", "bbbb")
        result = self.run_script("sync")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stale: remove", result.stdout)
        self.assertFalse((self.install / "parser/stale.so").exists())
        self.assertFalse((self.install / "parser-info/stale.revision").exists())
        self.assertFalse((self.install / "queries/stale").exists())
        # Pinned languages survive the directory replacement.
        self.assertTrue((self.install / "parser/alpha.so").is_file())
        self.assertEqual((self.install / "parser-info/alpha.revision").read_text(), "aaaa")
        self.assertTrue((self.install / "queries/shared").is_dir())

    def test_dry_run_changes_nothing(self) -> None:
        self.install_language("alpha", "aaaa")
        self.install_language("shared", None)
        self.install_language("stale", "bbbb")
        result = self.run_script("sync", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stale: remove", result.stdout)
        self.assertTrue((self.install / "parser/stale.so").exists())

    def test_branch_pins_are_refused(self) -> None:
        result = self.run_script("status", manifest=self.manifest(["branchy"]))
        self.assertEqual(result.returncode, 1)
        self.assertIn("no pinned revision", result.stderr)

    def test_unsupported_install_info_is_refused(self) -> None:
        result = self.run_script("status", manifest=self.manifest(["exotic"]))
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsupported install info: path", result.stderr)

    def test_unknown_language_is_refused(self) -> None:
        result = self.run_script("status", manifest=self.manifest(["nope"]))
        self.assertEqual(result.returncode, 1)
        self.assertIn("unknown language: nope", result.stderr)

    def test_duplicate_languages_are_refused(self) -> None:
        result = self.run_script("status", manifest=self.manifest(["alpha", "alpha"]))
        self.assertEqual(result.returncode, 1)
        self.assertIn("unique", result.stderr)

    def test_unsafe_install_dir_is_refused(self) -> None:
        path = self.root / "unsafe.json"
        path.write_text(json.dumps({
            "install_dir": str(Path.home()), "source": str(self.source), "languages": ["alpha"],
        }))
        result = self.run_script("status", manifest=path)
        self.assertEqual(result.returncode, 1)
        self.assertIn("unsafe install_dir", result.stderr)

    def test_unknown_manifest_keys_are_refused(self) -> None:
        path = self.root / "extra.json"
        path.write_text(json.dumps({
            "install_dir": str(self.install), "source": str(self.source),
            "languages": ["alpha"], "extra": True,
        }))
        result = self.run_script("status", manifest=path)
        self.assertEqual(result.returncode, 1)
        self.assertIn("manifest must contain", result.stderr)


if __name__ == "__main__":
    unittest.main()
