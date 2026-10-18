#!/usr/bin/env python3
"""Pinned native CLI/build contract; no compiler or engine is executed.

Both source pins' main/main.cpp SHA256 is
1831257f5c8eb0707d278f04b21b1e4b3ba863f8dca5cab36022d4b19e36b8c1.
Without OVERRIDE_PATH_ENABLED, lines1044-1056 reset cwd to the executable,
1769-1785 reject --path, and4322-4333 discard --script. Cwd alone is no fix.
The unchanged boot/staging/mip probes need path/script overrides for their
isolated portable projects; this is a runtime-test build, not shipping proof.
"""
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/godot/native_boot_upload"))
import build


class CompilerBoundaryObserved(BaseException):
    pass


class PortableRuntimeConfigurationTests(unittest.TestCase):
    def test_native_probe_required_override_is_explicit_once(self):
        self.assertEqual(build.FLAGS.count("disable_path_overrides=no"), 1,
                         "isolated template projects/scripts require native path override support")
        self.assertIn("target=template_debug", build.FLAGS)

    def test_written_build_manifest_distinguishes_runtime_test_from_shipping(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            args = SimpleNamespace(work=root / "engines", output=root / "evidence",
                patch=ROOT / "tools/godot/patches/glassvow-661-native-boot-upload-cap.patch",
                observer=ROOT / "tools/godot/native_boot_upload/observer.py",
                test_suite="GlassvowBootUpload", splash=None, source_archive=None,
                source_archive_sha256=build.SOURCE_ARCHIVE_SHA256)
            with patch.object(build.subprocess, "check_output", side_effect=CompilerBoundaryObserved):
                with self.assertRaises(CompilerBoundaryObserved):
                    build.build(args)
            report = json.loads((args.output / "build-manifest.json").read_text())
            self.assertEqual(report["flags"].count("disable_path_overrides=no"), 1)
            self.assertEqual(report.get("runtime_test_configuration"), {
                "purpose": "portable_component_proof", "path_overrides": True,
                "scons_option": "disable_path_overrides=no", "shipping_template_qualification": False})


if __name__ == "__main__":
    unittest.main(verbosity=2)
