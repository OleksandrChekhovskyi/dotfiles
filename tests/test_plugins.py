"""Offline integration tests using disposable Git remotes and installation roots."""

from __future__ import annotations

import fcntl
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "plugins.py"


class PluginsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.remote = self.root / "remote"
        self.remote.mkdir()
        self.git("init", "-b", "main")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        self.first = self.commit("first")
        self.target = self.root / "vim/start"
        self.state = self.root / "state"
        self.lock = self.root / "plugins.lock"
        self.manifest = self.root / "plugins.json"
        self.groups = {
            "vim": {
                "target": str(self.target),
                "repos": {"sample": {"url": str(self.remote), "ref": "refs/heads/main"}},
            }
        }
        self.save_manifest()

    def git(self, *args: str, cwd: Path | None = None) -> str:
        return subprocess.check_output(
            ["git", *args], cwd=cwd or self.remote, text=True, stderr=subprocess.DEVNULL,
        ).strip()

    def commit(self, text: str) -> str:
        (self.remote / "file").write_text(text)
        self.git("add", "file")
        self.git("commit", "-m", text)
        return self.git("rev-parse", "HEAD")

    def save_manifest(self) -> None:
        self.manifest.write_text(json.dumps({"groups": self.groups}))

    def run_tool(self, *args: str, ok: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--manifest", str(self.manifest),
             "--lockfile", str(self.lock), "--state-dir", str(self.state), *args],
            text=True, capture_output=True,
            env={**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull},
        )
        self.assertEqual(result.returncode, 0 if ok else 1, result.stdout + result.stderr)
        return result

    def install(self) -> None:
        self.run_tool("update", "vim")

    def clone(self) -> Path:
        path = self.root / "clone"
        self.git("clone", str(self.remote), str(path), cwd=self.root)
        return path

    def test_sync_requires_lock_and_dry_run_does_not_install(self) -> None:
        self.assertIn("missing/stale lock", self.run_tool("sync", "vim", ok=False).stderr)
        self.run_tool("update", "vim", "--dry-run")
        self.assertFalse(self.lock.exists())
        self.assertFalse(self.target.exists())

    def test_pinned_sync_and_explicit_update(self) -> None:
        self.install()
        old_lock = self.lock.read_bytes()
        second = self.commit("second")
        self.run_tool("sync", "vim")
        self.assertEqual(self.lock.read_bytes(), old_lock)
        self.assertEqual((self.target / "sample/file").read_text(), "first")
        self.run_tool("update", "vim", "sample")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.target / "sample"), second)
        self.assertIn("ok", self.run_tool("status", "--all").stdout)
        self.assertEqual(len(list((self.state / "trash").iterdir())), 1)

    def test_restore_missing_checkout_from_lock_without_remote_branch(self) -> None:
        self.install()
        (self.target / "sample").rename(self.root / "saved")
        self.git("branch", "-m", "renamed")
        self.run_tool("sync", "vim")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.target / "sample"), self.first)

    def test_dirty_update_refused_but_removal_preserves_everything(self) -> None:
        self.install()
        (self.target / "sample/file").write_text("local edits")
        (self.target / "sample/untracked").write_text("keep me")
        self.assertIn("local changes", self.run_tool("update", "vim", ok=False).stderr)
        self.groups["vim"]["repos"] = {}
        self.save_manifest()
        self.run_tool("sync", "vim", "--dry-run")
        self.assertTrue((self.target / "sample").exists())
        self.run_tool("sync", "vim")
        self.assertFalse((self.target / "sample").exists())
        removed, = (self.state / "trash").iterdir()
        self.assertEqual((removed / "file").read_text(), "local edits")
        self.assertEqual((removed / "untracked").read_text(), "keep me")
        self.assertEqual(json.loads(self.lock.read_text()), {})
        self.run_tool("gc", "--dry-run")
        self.assertTrue(removed.exists())

    def test_deleted_group_cleanup(self) -> None:
        self.install()
        self.groups.clear()
        self.save_manifest()
        self.run_tool("sync", "--all")
        self.assertFalse((self.target / "sample").exists())
        self.assertEqual(json.loads((self.state / "installed.json").read_text()), {})

    def test_unknown_contents_and_changed_origin_refused(self) -> None:
        self.install()
        unknown = self.target / "manual"
        unknown.mkdir()
        self.assertIn("unowned", self.run_tool("sync", "vim", ok=False).stderr)
        unknown.rmdir()
        self.git("remote", "set-url", "origin", "/unexpected", cwd=self.target / "sample")
        self.assertIn("origin changed", self.run_tool("sync", "vim", ok=False).stderr)

    def test_target_change_refused(self) -> None:
        self.install()
        self.groups["vim"]["target"] = str(self.root / "elsewhere")
        self.save_manifest()
        self.assertIn("target changed", self.run_tool("sync", "vim", ok=False).stderr)
        self.assertTrue((self.target / "sample").exists())

    def test_failed_fetch_leaves_install_and_lock_unchanged(self) -> None:
        self.install()
        before = self.lock.read_bytes()
        self.groups["vim"]["repos"]["broken"] = {
            "url": str(self.root / "nonexistent"), "ref": "refs/heads/main",
        }
        self.save_manifest()
        self.run_tool("update", "vim", ok=False)
        self.assertEqual(self.lock.read_bytes(), before)
        self.assertEqual((self.target / "sample/file").read_text(), "first")
        self.assertFalse(list(self.target.parent.glob(".plugins-*")))

    def test_groups_are_independent(self) -> None:
        self.groups["nvim"] = {
            "target": str(self.root / "nvim/start"),
            "repos": self.groups["vim"]["repos"].copy(),
        }
        self.save_manifest()
        self.run_tool("update", "--all")
        second = self.commit("second")
        self.run_tool("update", "nvim")
        pins = json.loads(self.lock.read_text())
        self.assertEqual(pins["vim"]["sample"]["commit"], self.first)
        self.assertEqual(pins["nvim"]["sample"]["commit"], second)
        self.groups["vim"]["repos"] = {}
        self.save_manifest()
        self.run_tool("sync", "vim")
        self.assertTrue((self.root / "nvim/start/sample").exists())

    def test_process_lock(self) -> None:
        self.state.mkdir()
        with (self.state / "operation.lock").open("w") as file:
            fcntl.flock(file, fcntl.LOCK_EX)
            result = self.run_tool("update", "vim", ok=False)
            self.assertIn("another plugin operation", result.stderr)

    def test_invalid_names_and_overlapping_targets(self) -> None:
        self.groups["vim"]["repos"]["../escape"] = self.groups["vim"]["repos"]["sample"]
        self.save_manifest()
        self.run_tool("update", "vim", ok=False)
        del self.groups["vim"]["repos"]["../escape"]
        self.groups["nvim"] = {"target": str(self.target / "nested"), "repos": {}}
        self.save_manifest()
        self.assertIn("overlap", self.run_tool("update", "vim", ok=False).stderr)

    def test_unchanged_update_does_not_replace_checkout(self) -> None:
        self.install()
        inode = (self.target / "sample").stat().st_ino
        self.run_tool("update", "vim")
        self.assertEqual((self.target / "sample").stat().st_ino, inode)
        self.assertFalse((self.state / "trash").exists())

    def test_manifest_url_change_replaces_origin_even_at_same_commit(self) -> None:
        self.install()
        other = self.root / "other-remote"
        self.git("clone", "--bare", str(self.remote), str(other))
        self.groups["vim"]["repos"]["sample"]["url"] = str(other)
        self.save_manifest()
        self.run_tool("sync", "vim", ok=False)
        self.run_tool("update", "vim")
        self.assertEqual(
            self.git("remote", "get-url", "origin", cwd=self.target / "sample"), str(other),
        )

    def test_stale_lock_group_without_installation_is_pruned(self) -> None:
        self.install()
        # Simulate another machine receiving a manifest with the group removed.
        self.state = self.root / "new-machine-state"
        self.groups.clear()
        self.save_manifest()
        self.run_tool("sync", "--all")
        self.assertEqual(json.loads(self.lock.read_text()), {})
        self.assertTrue((self.target / "sample").exists())

    def test_malformed_manifest_and_state_fail_cleanly(self) -> None:
        self.groups["vim"] = []
        self.save_manifest()
        self.assertNotIn("Traceback", self.run_tool("sync", "vim", ok=False).stderr)
        self.groups.clear()
        self.save_manifest()
        (self.state / "installed.json").write_text(json.dumps({"../escape": {}}))
        self.assertIn("invalid ownership", self.run_tool("sync", "--all", ok=False).stderr)

    @unittest.skipUnless(shutil.which("vim"), "Vim is not installed")
    def test_helptags_are_generated_without_dirtying_checkout(self) -> None:
        doc = self.remote / "doc"
        doc.mkdir()
        (doc / "sample.txt").write_text("*sample-plugin* A test plugin\n")
        self.git("add", "doc")
        self.git("commit", "-m", "documentation")
        self.groups["vim"]["helptags"] = True
        self.save_manifest()
        self.install()
        self.assertIn("sample-plugin", (self.target / "sample/doc/tags").read_text())
        self.assertIn("ok", self.run_tool("status", "vim").stdout)
        self.run_tool("sync", "vim")

    def test_checkout_carries_the_manifest_ref(self) -> None:
        self.install()
        checkout = self.target / "sample"
        self.assertEqual(self.git("rev-parse", "refs/heads/main", cwd=checkout), self.first)
        second = self.commit("second")
        self.git("tag", "-a", "v1", "-m", "release")
        self.groups["vim"]["repos"]["sample"]["ref"] = "refs/tags/v1"
        self.save_manifest()
        self.run_tool("update", "vim")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=checkout), second)
        self.assertEqual(self.git("describe", "--tags", "--exact-match", cwd=checkout), "v1")
        # The recreated ref must not make the checkout look modified.
        self.assertIn("ok", self.run_tool("status", "vim").stdout)

    def test_sync_keeps_a_linked_clone_and_its_pin(self) -> None:
        self.install()
        clone = self.clone()
        self.run_tool("link", "vim", "sample", str(clone))
        self.assertTrue((self.target / "sample").is_symlink())
        (clone / "file").write_text("work in progress")
        (clone / "untracked").write_text("keep me")
        output = self.run_tool("sync", "vim").stdout
        self.assertIn("linked", output)
        self.assertIn("dirty", output)
        self.assertEqual((clone / "file").read_text(), "work in progress")
        self.assertEqual((clone / "untracked").read_text(), "keep me")
        self.assertEqual(json.loads(self.lock.read_text())["vim"]["sample"]["commit"], self.first)
        # The checkout the link replaced is recoverable.
        replaced, = (self.state / "trash").iterdir()
        self.assertEqual((replaced / "file").read_text(), "first")

    def test_update_pins_the_remote_and_reports_a_diverged_clone(self) -> None:
        self.install()
        clone = self.clone()
        self.run_tool("link", "vim", "sample", str(clone))
        second = self.commit("second")
        output = self.run_tool("update", "vim").stdout
        self.assertEqual(json.loads(self.lock.read_text())["vim"]["sample"]["commit"], second)
        self.assertIn("not at the pinned commit", output)
        self.assertTrue((self.target / "sample").is_symlink())
        self.git("pull", "--ff-only", cwd=clone)
        self.assertNotIn("not at the pinned commit", self.run_tool("sync", "vim").stdout)

    def test_unlink_restores_the_pinned_checkout(self) -> None:
        self.install()
        clone = self.clone()
        self.run_tool("link", "vim", "sample", str(clone))
        self.run_tool("unlink", "vim", "sample")
        self.assertFalse((self.target / "sample").exists())
        self.run_tool("sync", "vim")
        self.assertEqual((self.target / "sample/file").read_text(), "first")
        self.assertEqual((clone / "file").read_text(), "first")
        self.assertEqual(json.loads((self.state / "links.json").read_text()), {})

    def test_removing_a_linked_repository_from_the_manifest_unlinks_it(self) -> None:
        self.install()
        clone = self.clone()
        self.run_tool("link", "vim", "sample", str(clone))
        self.groups["vim"]["repos"] = {}
        self.save_manifest()
        self.run_tool("sync", "vim", "--dry-run")
        self.assertTrue((self.target / "sample").is_symlink())
        self.run_tool("sync", "vim")
        self.assertFalse((self.target / "sample").is_symlink())
        self.assertEqual((clone / "file").read_text(), "first")
        self.assertEqual(json.loads((self.state / "links.json").read_text()), {})

    def test_link_requires_a_matching_clone_outside_the_target(self) -> None:
        self.install()
        missing = self.run_tool("link", "vim", "sample", str(self.root / "absent"), ok=False)
        self.assertIn("not a Git checkout", missing.stderr)
        inside = self.run_tool("link", "vim", "sample", str(self.target / "nested"), ok=False)
        self.assertIn("must live outside", inside.stderr)
        clone = self.clone()
        self.git("remote", "set-url", "origin", "/unexpected", cwd=clone)
        foreign = self.run_tool("link", "vim", "sample", str(clone), ok=False)
        self.assertIn("origin changed", foreign.stderr)
        self.assertFalse((self.target / "sample").is_symlink())

    def test_annotated_tag(self) -> None:
        self.git("tag", "-a", "v1", "-m", "release")
        self.groups["vim"]["repos"]["sample"]["ref"] = "refs/tags/v1"
        self.save_manifest()
        self.install()
        self.assertEqual(json.loads(self.lock.read_text())["vim"]["sample"]["commit"], self.first)


if __name__ == "__main__":
    unittest.main()
