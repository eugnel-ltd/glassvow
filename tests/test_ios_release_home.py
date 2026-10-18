#!/usr/bin/env python3
"""Exercise editor HOME boundaries through the actual release shell, offline."""
from __future__ import annotations

import contextlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SHA = "a" * 40

# Every build/provider command is synthetic. The maintained shell chooses their
# environment and order; the stubs record that boundary without invoking Godot.
STUB = r'''
import json, os
from pathlib import Path
import shutil, sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path.cwd()
home = Path(os.environ["HOME"])

def event(kind, **extra):
    row = {"kind": kind, "home": str(home), "args": args,
           "developer": os.environ["DEVELOPER_DIR"],
           "key": os.environ["ASC_PRIVATE_KEY_PATH"]}
    row.update(extra)
    with open(os.environ["GLASSVOW_TEST_EVENTS"], "a") as file:
        file.write(json.dumps(row) + "\n")

if name == "git":
    if args[0] == "rev-parse":
        print("a" * 40)
    elif args[0] != "status":
        sys.exit(91)
elif name == "python3":
    if args[0] != "-c":
        os.execv(sys.executable, [sys.executable, *args])
elif name == "bake_export.sh" and args[0] == "--enabled":
    sys.exit(0 if os.environ["GLASSVOW_TEST_BAKED"] == "1" else 1)
elif name in ("godot", "bake_export.sh"):
    preset = (root / "export_presets.cfg").read_text()
    prefix = 'custom_template/release="'
    template = Path(next(line[len(prefix):-1] for line in preset.splitlines()
                         if line.startswith(prefix)))
    marker = home / "editor-recovery-marker"
    event("editor", baked=name == "bake_export.sh", stale_before=marker.exists(),
          template=str(template), template_exists=template.is_file())
    home.mkdir(parents=True, exist_ok=True)
    marker.write_text("synthetic editor state\n")
    if os.environ["GLASSVOW_TEST_EXPORT_FAIL"] == "1":
        sys.exit(17)
    binary = root / "build/ios/glassvow.xcframework/ios-arm64/libgodot.a"
    binary.parent.mkdir(parents=True, exist_ok=True)
    binary.write_text("Godot Engine v4.7.2.stable\n")
elif name == "xcodebuild":
    if "-exportArchive" in args:
        event("sign")
        destination = root / "build/ios/export"
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(os.environ["GLASSVOW_TEST_IPA"], destination / "glassvow.ipa")
        print("EXPORT SUCCEEDED")
    else:
        event("archive")
        binary = root / "build/ios/glassvow.xcarchive/Products/Applications/glassvow.app/glassvow"
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_text("Godot Engine v4.7.2.stable\n")
        print("ARCHIVE SUCCEEDED")
elif name == "asc":
    event("upload")
    if args[:2] != ["builds", "upload"]:
        sys.exit(92)
    sys.exit(23)  # A sentinel stops before polling or any attachment helper.
elif name == "sentry-cli":
    event("sentry-preflight")
elif name == "stat":
    print(Path(args[-1]).stat().st_size)
else:
    sys.exit(93)
'''


class Fixture:
    def __init__(self, scratch: Path, baked: bool) -> None:
        self.root = scratch / "release tree"
        self.root.mkdir()
        self.owner = scratch / "owner profile"
        self.owner.mkdir()
        (self.owner / "player-save-sentinel").write_bytes(b"preserve this profile\n")
        self.template = self.owner / "Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip"
        self.template.parent.mkdir(parents=True)
        with zipfile.ZipFile(self.template, "w") as archive:
            archive.writestr("GLASSVOW-TEMPLATE-NOTE.txt", "offline template fixture\n")
        self.key = self.owner / "signing key.p8"
        self.key.write_text("synthetic fixture only\n")
        self.original_profile = self.profile_files()
        self.editor_home = self.root / "build/ios/export-home"
        self.events_file = scratch / "events.jsonl"
        developer = scratch / "Xcode developer"
        developer.mkdir()
        self.developer = developer
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copyfile(ROOT / "scripts/ios_release.sh", scripts / "ios_release.sh")
        # Preserve the separate qualification guard when this test is integrated
        # with that outcome; the fixture IPA has documented release metadata.
        qualification = ROOT / "scripts/ios_release_qualification.py"
        if qualification.is_file():
            shutil.copyfile(qualification, scripts / qualification.name)
        tools = self.root / "tools"
        (tools / "godot").mkdir(parents=True)
        (tools / "payload_report.py").write_text("print('offline payload fixture')\n")
        (self.root / "export_presets.cfg").write_text(
            '[preset.0]\nname="iOS"\n[preset.0.options]\napplication/version="21"\n'
            f'custom_template/release="{self.template}"\n')
        self.ipa = scratch / "fixture.ipa"
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/glassvow.app/Info.plist",
                             plistlib.dumps({"DTXcodeBuild": "27A266a"}))
        bindir = scratch / "fake commands"
        bindir.mkdir()
        for name in ("git", "godot", "xcodebuild", "asc", "sentry-cli", "stat", "python3"):
            self.write_stub(bindir / name)
        self.write_stub(tools / "godot/bake_export.sh")
        self.env = {
            "PATH": str(bindir) + os.pathsep + os.defpath,
            "HOME": str(self.owner), "LANG": "C.UTF-8",
            "DEVELOPER_DIR": str(developer),
            "GLASSVOW_BAKE_EDITOR": str(bindir / "godot"),
            "ASC_KEY_ID": "offline-fixture", "ASC_ISSUER_ID": "offline-fixture",
            "ASC_PRIVATE_KEY_PATH": str(self.key),
            "GLASSVOW_TEST_BAKED": "1" if baked else "0",
            "GLASSVOW_TEST_EXPORT_FAIL": "0",
            "GLASSVOW_TEST_EVENTS": str(self.events_file),
            "GLASSVOW_TEST_IPA": str(self.ipa),
        }

    @staticmethod
    def write_stub(path: Path) -> None:
        path.write_text("#!" + sys.executable + "\n" + STUB)
        path.chmod(0o755)

    def profile_files(self) -> dict[str, bytes]:
        return {str(path.relative_to(self.owner)): path.read_bytes()
                for path in self.owner.rglob("*") if path.is_file()}

    def events(self) -> list[dict]:
        return [json.loads(line) for line in self.events_file.read_text().splitlines()]

    def release(self, *, upload: bool = False, fail_export: bool = False) -> subprocess.CompletedProcess:
        command = ["bash", str(self.root / "scripts/ios_release.sh"), "21", SHA, "--no-device"]
        if not upload:
            command.append("--no-upload")
        env = self.env | {"GLASSVOW_TEST_EXPORT_FAIL": "1" if fail_export else "0"}
        return subprocess.run(command, cwd=self.root, env=env, text=True,
                              capture_output=True, check=False, timeout=20)


@contextlib.contextmanager
def fixture(baked: bool):
    with tempfile.TemporaryDirectory(prefix="glassvow editor home ") as scratch:
        yield Fixture(Path(scratch), baked)


class EditorHomeTests(unittest.TestCase):
    def assert_editor_isolated(self, case: Fixture, editor: dict, baked: bool) -> None:
        self.assertEqual(str(case.editor_home), editor["home"])
        self.assertEqual(baked, editor["baked"])
        self.assertEqual(str(case.template), editor["template"])
        self.assertTrue(editor["template_exists"])
        self.assertEqual(case.original_profile, case.profile_files())

    def assert_owner_environment(self, case: Fixture, event: dict) -> None:
        self.assertEqual(str(case.owner), event["home"])
        self.assertEqual(str(case.developer), event["developer"])
        self.assertEqual(str(case.key), event["key"])

    def test_both_export_branches_isolate_home_and_keep_archive_signing_environment(self) -> None:
        for baked in (False, True):
            with self.subTest(baked=baked), fixture(baked) as case:
                result = case.release()
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                events = case.events()
                self.assertEqual(["editor", "archive", "sign"], [e["kind"] for e in events])
                self.assert_editor_isolated(case, events[0], baked)
                for event in events[1:]:
                    self.assert_owner_environment(case, event)
                self.assertIn("offline template fixture", result.stdout)

    def test_failed_export_stops_later_steps_and_next_attempt_cleans_only_build_state(self) -> None:
        for baked in (False, True):
            with self.subTest(baked=baked), fixture(baked) as case:
                logs = case.root / "build/ios/logs"
                logs.mkdir(parents=True)
                kept = logs / "retained.log"
                kept.write_text("keep previous evidence\n")
                failed = case.release(fail_export=True)
                self.assertEqual(17, failed.returncode, failed.stdout + failed.stderr)
                events = case.events()
                self.assertEqual(["editor"], [e["kind"] for e in events])
                self.assert_editor_isolated(case, events[0], baked)
                self.assertTrue((case.editor_home / "editor-recovery-marker").is_file())
                recovered = case.release()
                self.assertEqual(0, recovered.returncode, recovered.stdout + recovered.stderr)
                editors = [e for e in case.events() if e["kind"] == "editor"]
                self.assertEqual(2, len(editors))
                self.assertFalse(editors[-1]["stale_before"])
                self.assert_editor_isolated(case, editors[-1], baked)
                self.assertEqual("keep previous evidence\n", kept.read_text())

    def test_upload_boundary_retains_owner_home_after_either_export(self) -> None:
        for baked in (False, True):
            with self.subTest(baked=baked), fixture(baked) as case:
                result = case.release(upload=True)
                self.assertEqual(23, result.returncode, result.stdout + result.stderr)
                events = case.events()
                self.assertEqual(["sentry-preflight", "editor", "archive", "sign", "upload"],
                                 [e["kind"] for e in events])
                self.assert_editor_isolated(case, events[1], baked)
                for event in events:
                    if event["kind"] != "editor":
                        self.assert_owner_environment(case, event)


if __name__ == "__main__":
    unittest.main()
