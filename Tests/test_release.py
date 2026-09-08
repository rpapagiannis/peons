"""Exercise release preparation against disposable Git repositories."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "release.py"
BUILD = """<key>CFBundleShortVersionString</key><string>4.2.2</string>
<key>CFBundleVersion</key><string>9</string>
"""
CHANGELOG = "# Changelog\n\n## Unreleased\n\n- New behavior.\n\n## 4.2.2 (build 9)\n\n- Previous release.\n"


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="peons-release-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "origin.git"
        self.author = self.root / "author"
        self.runner = self.root / "runner"
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        self.run_command(self.root, "git", "init", "--bare", "--initial-branch=main", str(self.remote))
        self.run_command(self.root, "git", "clone", str(self.remote), str(self.author))
        self.git(self.author, "config", "user.name", "Release Test")
        self.git(self.author, "config", "user.email", "release@example.invalid")
        (self.author / "build.sh").write_text(BUILD)
        (self.author / "CHANGELOG.md").write_text(CHANGELOG)
        (self.author / "app.txt").write_text("original\n")
        self.commit("Previous release")
        self.git(self.author, "tag", "v4.2.2-9")
        (self.author / "app.txt").write_text("merged change\n")
        self.source = self.commit("Merged feature")
        self.git(self.author, "push", "origin", "main", "--tags")
        self.run_command(self.root, "git", "clone", str(self.remote), str(self.runner))

    def run_command(self, cwd, *args, succeeds=True):
        result = subprocess.run(args, cwd=cwd, env=self.env, text=True, capture_output=True)
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, cwd, *args):
        return self.run_command(cwd, "git", *args).stdout.strip()

    def commit(self, message):
        self.git(self.author, "add", ".")
        self.git(self.author, "commit", "-m", message)
        return self.git(self.author, "rev-parse", "HEAD")

    def release(self, *args):
        result = self.run_command(self.runner, sys.executable, str(SCRIPT), *args)
        return dict(line.split("=", 1) for line in result.stdout.splitlines())

    def prepare(self):
        return self.release("prepare", self.source)

    def push(self, plan):
        return self.release("push", self.source, plan["tag"], plan["commit"])

    def advance_main(self):
        (self.author / "app.txt").write_text("a later merge\n")
        newest = self.commit("Newer feature")
        self.git(self.author, "push", "origin", "main")
        return newest

    def test_prepares_metadata_without_publishing_then_pushes_both_refs(self):
        plan = self.prepare()
        self.assertEqual(plan["state"], "prepared")
        self.assertEqual(plan["tag"], "v4.2.2-10")
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), self.source)
        self.assertNotIn(plan["tag"], self.git(self.remote, "tag"))
        self.assertEqual(self.git(self.runner, "show", "HEAD:app.txt"), "merged change")
        self.assertIn("<string>10</string>", (self.runner / "build.sh").read_text())
        changelog = (self.runner / "CHANGELOG.md").read_text()
        self.assertIn("## Unreleased\n\n## 4.2.2 (build 10)\n\n- New behavior.", changelog)
        self.assertIn("## 4.2.2 (build 9)\n\n- Previous release.", changelog)
        self.assertEqual(self.push(plan), {"ready": "true"})
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), plan["commit"])
        self.assertEqual(self.git(self.remote, "rev-parse", plan["tag"]), plan["commit"])

    def test_retry_reuses_published_commit_and_tag(self):
        first = self.prepare()
        self.push(first)
        self.git(self.runner, "checkout", "--detach", self.source)
        retry = self.prepare()
        self.assertEqual(retry, dict(first, state="existing"))
        self.assertEqual(self.push(retry), {"ready": "true"})
        self.assertEqual(self.git(self.remote, "tag").splitlines(), ["v4.2.2-10", "v4.2.2-9"])

    def test_next_merge_advances_again_and_preserves_previous_notes(self):
        first = self.prepare()
        self.push(first)
        self.git(self.author, "pull", "--ff-only", "origin", "main")
        changelog = self.author / "CHANGELOG.md"
        changelog.write_text(changelog.read_text().replace("## Unreleased\n", "## Unreleased\n\n- Next change.\n"))
        (self.author / "app.txt").write_text("next feature\n")
        self.source = self.commit("Next merged feature")
        self.git(self.author, "push", "origin", "main")
        self.git(self.runner, "fetch", "origin")
        self.git(self.runner, "checkout", "--detach", self.source)
        second = self.prepare()
        self.assertEqual(second["tag"], "v4.2.2-11")
        notes = (self.runner / "CHANGELOG.md").read_text()
        self.assertIn("## 4.2.2 (build 11)\n\n- Next change.", notes)
        self.assertIn("## 4.2.2 (build 10)\n\n- New behavior.", notes)
        self.assertEqual(self.push(second), {"ready": "true"})

    def test_retry_after_another_merge_skips_the_old_release(self):
        first = self.prepare()
        self.push(first)
        self.git(self.author, "pull", "--ff-only", "origin", "main")
        self.advance_main()
        self.git(self.runner, "checkout", "--detach", self.source)
        self.assertEqual(self.prepare(), {"state": "skip"})

    def test_already_tagged_ci_commit_does_not_increment_again(self):
        # Use the current metadata's tag on the source to simulate a manual release.
        (self.author / "build.sh").write_text(BUILD.replace("<string>9</string>", "<string>10</string>"))
        self.source = self.commit("Manual release")
        self.git(self.author, "tag", "v4.2.2-10")
        self.git(self.author, "push", "origin", "main", "--tags")
        self.git(self.runner, "fetch", "origin")
        self.git(self.runner, "checkout", "--detach", self.source)
        plan = self.prepare()
        self.assertEqual(plan["state"], "existing")
        self.assertEqual(plan["commit"], self.source)
        self.assertEqual(self.push(plan), {"ready": "true"})

    def test_old_ci_run_skips_a_newer_main_commit(self):
        newest = self.advance_main()
        self.assertEqual(self.prepare(), {"state": "skip"})
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), newest)
        self.assertEqual((self.runner / "build.sh").read_text(), BUILD)

    def test_merge_during_packaging_prevents_tag_and_release(self):
        plan = self.prepare()
        newest = self.advance_main()
        self.assertEqual(self.push(plan), {"ready": "false"})
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), newest)
        self.assertNotIn(plan["tag"], self.git(self.remote, "tag"))

    def test_push_race_is_atomic(self):
        plan = self.prepare()
        # Move main after the helper's fetch, immediately before git push reaches the remote.
        newest = self.advance_main()
        self.git(self.remote, "update-ref", "refs/heads/main", self.source)
        hook = self.runner / ".git" / "hooks" / "pre-push"
        hook.write_text(f'#!/bin/sh\ngit --git-dir="{self.remote}" update-ref refs/heads/main {newest}\n')
        hook.chmod(0o755)
        self.assertEqual(self.push(plan), {"ready": "false"})
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), newest)
        self.assertNotIn(plan["tag"], self.git(self.remote, "tag"))

    def test_rejected_push_does_not_publish_a_tag(self):
        plan = self.prepare()
        hook = self.remote / "hooks" / "pre-receive"
        hook.write_text("#!/bin/sh\necho 'simulated branch protection' >&2\nexit 1\n")
        hook.chmod(0o755)
        self.run_command(self.runner, sys.executable, str(SCRIPT), "push", self.source,
                         plan["tag"], plan["commit"], succeeds=False)
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), self.source)
        self.assertNotIn(plan["tag"], self.git(self.remote, "tag"))

    def test_all_existing_tags_reserve_build_numbers(self):
        self.git(self.author, "tag", "v4.2.2-15")
        self.git(self.author, "push", "origin", "v4.2.2-15")
        self.assertEqual(self.prepare()["tag"], "v4.2.2-16")

    def test_new_marketing_version_keeps_build_numbers_increasing(self):
        (self.author / "build.sh").write_text(BUILD.replace("4.2.2", "4.3.0").replace("<string>9</string>", "<string>1</string>"))
        self.source = self.commit("New minor version")
        self.git(self.author, "push", "origin", "main")
        self.git(self.runner, "fetch", "origin")
        self.git(self.runner, "checkout", "--detach", self.source)
        self.assertEqual(self.prepare()["tag"], "v4.3.0-10")

    def test_newer_release_version_blocks_an_old_version(self):
        self.git(self.author, "tag", "v4.3.0-10")
        self.git(self.author, "push", "origin", "v4.3.0-10")
        self.run_command(self.runner, sys.executable, str(SCRIPT), "prepare", self.source, succeeds=False)
        self.assertEqual((self.runner / "build.sh").read_text(), BUILD)

    def test_missing_unreleased_heading_fails_before_editing_version(self):
        (self.author / "CHANGELOG.md").write_text("# Changelog\n")
        self.source = self.commit("Missing release notes heading")
        self.git(self.author, "push", "origin", "main")
        self.git(self.runner, "fetch", "origin")
        self.git(self.runner, "checkout", "--detach", self.source)
        self.run_command(self.runner, sys.executable, str(SCRIPT), "prepare", self.source, succeeds=False)
        self.assertEqual((self.runner / "build.sh").read_text(), BUILD)

    def test_dirty_checkout_is_rejected(self):
        (self.runner / "app.txt").write_text("untested modification")
        self.run_command(self.runner, sys.executable, str(SCRIPT), "prepare", self.source, succeeds=False)
        self.assertEqual(self.git(self.remote, "rev-parse", "main"), self.source)

    def test_cask_comparison_is_numeric_and_prevents_downgrades(self):
        cask = self.runner / "peons.rb"
        cask.write_text('cask "peons" do\n  version "4.2.2,9"\nend\n')
        self.release("check-cask", str(cask), "4.2.2", "10")
        self.release("check-cask", str(cask), "4.2.2", "9")
        self.release("check-cask", str(cask), "4.3.0", "1")
        self.run_command(self.runner, sys.executable, str(SCRIPT), "check-cask",
                         str(cask), "4.2.2", "8", succeeds=False)


if __name__ == "__main__":
    unittest.main()
