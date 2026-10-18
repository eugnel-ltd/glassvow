#!/usr/bin/env python3
"""Qualify signed-IPA Xcode metadata and prove the upload boundary offline."""

from __future__ import annotations

import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "scripts/ios_release_qualification.py"
APP_INFO = "Payload/glassvow.app/Info.plist"


def write_ipa(path: Path, metadata: object, *, binary: bool = False,
              extra: tuple[tuple[str, bytes], ...] = ()) -> None:
    raw = plistlib.dumps(metadata, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML)
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(APP_INFO, raw)
        for name, data in extra:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore", UserWarning)
                archive.writestr(name, data)


class QualificationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.scratch = tempfile.TemporaryDirectory(prefix="glassvow-ipa-qualification-")
        self.addCleanup(self.scratch.cleanup)
        self.ipa = Path(self.scratch.name) / "candidate.ipa"

    def check(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, "-B", str(CHECKER), str(self.ipa)],
                              capture_output=True, text=True, check=False)

    def test_documented_release_accepts_xml_and_binary_plists(self) -> None:
        for binary in (False, True):
            with self.subTest(binary=binary):
                write_ipa(self.ipa, {"DTXcodeBuild": "27A266a"}, binary=binary)
                result = self.check()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("27A266a", result.stdout)

    def test_missing_wrong_type_unknown_and_beta_builds_fail_closed(self) -> None:
        for metadata in ({}, {"DTXcodeBuild": ""}, {"DTXcodeBuild": 27},
                         {"DTXcodeBuild": "27A266a\n"},
                         {"DTXcodeBuild": "27A9999"},
                         {"DTXcodeBuild": "27A-beta"}, ["27A266a"]):
            with self.subTest(metadata=metadata):
                write_ipa(self.ipa, metadata)
                self.assertEqual(self.check().returncode, 1)

    def test_missing_malformed_and_ambiguous_app_plists_fail_closed(self) -> None:
        release = plistlib.dumps({"DTXcodeBuild": "27A266a"})
        fixtures = (
            (),
            ((APP_INFO, b"not a plist"),),
            ((APP_INFO, release), ("Payload/second.app/Info.plist", release)),
            ((APP_INFO, release), (APP_INFO, release)),
        )
        for entries in fixtures:
            with self.subTest(entries=[name for name, _ in entries]):
                with zipfile.ZipFile(self.ipa, "w") as archive:
                    for name, data in entries:
                        with warnings.catch_warnings():
                            warnings.simplefilter("ignore", UserWarning)
                            archive.writestr(name, data)
                self.assertEqual(self.check().returncode, 1)
        self.ipa.write_bytes(b"not a zip")
        self.assertEqual(self.check().returncode, 1)
        self.ipa.unlink()
        self.assertEqual(self.check().returncode, 1)

    def test_embedded_framework_plist_is_not_the_app_identity(self) -> None:
        write_ipa(self.ipa, {"DTXcodeBuild": "27A266a"}, extra=(
            ("Payload/glassvow.app/Frameworks/engine.framework/Info.plist", b"unrelated"),))
        self.assertEqual(self.check().returncode, 0)


class ReleaseBoundaryTests(unittest.TestCase):
    """Run the maintained release script; every build/provider command is a stub."""

    def setUp(self) -> None:
        self.scratch = tempfile.TemporaryDirectory(prefix="glassvow-upload-boundary-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copyfile(ROOT / "scripts/ios_release.sh", scripts / "ios_release.sh")
        if CHECKER.exists():
            shutil.copyfile(CHECKER, scripts / CHECKER.name)
        tools = self.root / "tools"
        (tools / "godot").mkdir(parents=True)
        (tools / "godot/bake_export.sh").write_text("#!/bin/sh\nexit 1\n")
        (tools / "godot/bake_export.sh").chmod(0o755)
        (tools / "payload_report.py").write_text("print('offline payload stub')\n")
        (self.root / "export_presets.cfg").write_text(
            '[preset.0]\nname="iOS"\n[preset.0.options]\napplication/version="21"\n')
        self.ipa = self.root / "fixture.ipa"
        self.uploads = self.root / "uploads.txt"
        key = self.root / "test-key.p8"
        key.write_text("offline fixture only\n")
        developer = self.root / "Developer"
        developer.mkdir()
        bindir = self.root / "bin"
        bindir.mkdir()
        programs = {
            "git": """case "$1" in
rev-parse) printf '%s\\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
status) exit 0 ;;
*) exit 91 ;;
esac
""",
            "godot": """mkdir -p build/ios/glassvow.xcframework/ios-arm64
printf '%s\\n' 'Godot Engine v4.7.2.stable' > build/ios/glassvow.xcframework/ios-arm64/libgodot.a
""",
            "xcodebuild": """case " $* " in
*' -exportArchive '*) mkdir -p build/ios/export; cp "$GLASSVOW_TEST_IPA" build/ios/export/glassvow.ipa; echo 'EXPORT SUCCEEDED' ;;
*) mkdir -p build/ios/glassvow.xcarchive/Products/Applications/glassvow.app
printf '%s\\n' 'Godot Engine v4.7.2.stable' > build/ios/glassvow.xcarchive/Products/Applications/glassvow.app/glassvow
echo 'ARCHIVE SUCCEEDED' ;;
esac
""",
            "asc": """if [ "$1 $2" = 'builds upload' ]; then
printf '%s\\n' upload >> "$GLASSVOW_TEST_UPLOADS"
exit 23
fi
exit 92
""",
            "sentry-cli": "exit 0\n",
            "stat": "wc -c < \"$3\"\n",
            "python3": 'if [ "$1" = -c ]; then exit 0; fi\nexec "' + sys.executable + '" "$@"\n',
        }
        for name, body in programs.items():
            executable = bindir / name
            executable.write_text("#!/bin/sh\nset -eu\n" + body)
            executable.chmod(0o755)
        self.env = os.environ | {
            "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
            "DEVELOPER_DIR": str(developer),
            "ASC_KEY_ID": "offline-fixture", "ASC_ISSUER_ID": "offline-fixture",
            "ASC_PRIVATE_KEY_PATH": str(key),
            "GLASSVOW_TEST_IPA": str(self.ipa),
            "GLASSVOW_TEST_UPLOADS": str(self.uploads),
        }

    def release(self, *options: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(self.root / "scripts/ios_release.sh"), "21", "a" * 40,
             "--no-device", *options], cwd=self.root, env=self.env,
            capture_output=True, text=True, check=False, timeout=20)

    def test_unqualified_ipa_never_reaches_upload(self) -> None:
        for metadata in ({}, {"DTXcodeBuild": "27A-beta"}):
            with self.subTest(metadata=metadata):
                write_ipa(self.ipa, metadata)
                result = self.release()
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.uploads.exists(), result.stdout + result.stderr)
                self.assertIn("qualification", result.stderr.lower())

    def test_qualified_ipa_reaches_existing_upload_command(self) -> None:
        write_ipa(self.ipa, {"DTXcodeBuild": "27A266a"}, binary=True)
        result = self.release()
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertEqual(self.uploads.read_text(), "upload\n")

    def test_no_upload_keeps_local_artifact_flow(self) -> None:
        write_ipa(self.ipa, {"DTXcodeBuild": "27A-beta"})
        result = self.release("--no-upload")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.uploads.exists())


if __name__ == "__main__":
    unittest.main()
