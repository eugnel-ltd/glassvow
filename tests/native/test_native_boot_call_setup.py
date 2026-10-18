#!/usr/bin/env python3
"""Exercise the real wrapper's Git application in hosted and detached layouts.

Only downstream compiler/fixture invocations are replaced. The small source
and patch here test setup, not native calls, capacity, rendering or GPU proof.
"""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "native_boot_call_setup", ROOT / "tools/godot/native_boot_upload/native_calls.py")
NATIVE_CALLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE_CALLS)
RD = "servers/rendering/rendering_device.cpp"
SETTINGS = "core/config/project_settings.cpp"
ORIGINAL = "Error RenderingDevice::texture_update() { return OK; }\n"
BOOT = "Error RenderingDevice::texture_update_boot_image() { return OK; }\n"
HELPER = "Error RenderingDevice::_texture_update() { return OK; }\n"
PATCH = ("diff --git a/" + RD + " b/" + RD + "\n--- a/" + RD +
         "\n+++ b/" + RD + "\n@@ -1 +1,3 @@\n " + ORIGINAL +
         "+" + BOOT + "+" + HELPER)
REAL_RUN = subprocess.run


class NativeBootCallSetupTests(unittest.TestCase):
    def exercise(self, nested):
        with tempfile.TemporaryDirectory(prefix="boot-call-setup-") as temporary:
            home = Path(temporary)
            checkout = home / "checkout"
            checkout.mkdir()
            REAL_RUN(["git", "init", "--quiet", str(checkout)], check=True,
                     capture_output=True, timeout=10)
            tool = checkout / "tools/godot/native_boot_upload/native_calls.py"
            tool.parent.mkdir(parents=True)
            patch_file = checkout / "tools/godot/patches/glassvow-661-native-boot-upload-cap.patch"
            patch_file.parent.mkdir(parents=True)
            patch_file.write_text(PATCH)
            inputs = {RD: ORIGINAL, SETTINGS: 'GLOBAL_DEF(PropertyInfo(Variant::INT, '
                      '"rendering/rendering_device/staging_buffer/block_size_kb", '
                      'PROPERTY_HINT_RANGE, "4,8192,1"), 256);\n'}
            sources = home / "sources" / NATIVE_CALLS.PIN
            for relative, text in inputs.items():
                destination = sources / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_text(text)
            outer_source = checkout / RD
            outer_source.parent.mkdir(parents=True)
            outer_source.write_text(ORIGINAL)
            tool.with_name("source-manifest.json").write_text(json.dumps({
                "pins": {NATIVE_CALLS.PIN: {
                    relative: hashlib.sha256(text.encode()).hexdigest()
                    for relative, text in inputs.items()}},
                "fixture_files": {NATIVE_CALLS.PIN: {}}}))
            output = (checkout / "work/native-boot-evidence/native-calls" if nested
                      else home / "detached-evidence")
            dispatched = []

            def dispatch(command, **kwargs):
                if command[0] == "git":
                    return REAL_RUN(command, **kwargs)
                fixture = Path(command[1]).name
                if fixture == "run_gles_fixture.py":
                    return subprocess.CompletedProcess(command, 0)
                self.assertEqual(fixture, "run_fixture.py")
                source = Path(command[command.index("--source") + 1])
                baseline = Path(command[command.index("--baseline-source") + 1])
                self.assertEqual(source.read_text(), ORIGINAL + BOOT + HELPER,
                                 "hosted nested output must dispatch the patched RD boot methods")
                self.assertEqual(baseline.read_text(), ORIGINAL)
                self.assertNotIn("--mode", command, "keep the real fixture's all-mode default")
                Path(command[command.index("--output") + 1]).write_text(json.dumps({
                    "boot_cases": 0, "rejections": 0, "normal_cases": 0}))
                dispatched.append(source)
                return subprocess.CompletedProcess(command, 0, stdout="setup-only fixture boundary\n")

            args = SimpleNamespace(output=output, offline_sources=sources.parent)
            with patch.object(NATIVE_CALLS, "__file__", str(tool)), \
                    patch.object(NATIVE_CALLS.subprocess, "run", side_effect=dispatch), \
                    contextlib.redirect_stdout(io.StringIO()):
                NATIVE_CALLS.run(args)
            self.assertEqual(len(dispatched), 1)
            self.assertEqual(outer_source.read_text(), ORIGINAL,
                             "candidate preparation must not alter the enclosing checkout")
            self.assertEqual((output / "original" / RD).read_text(), ORIGINAL)
            self.assertEqual((output / "candidate" / RD).read_text(), ORIGINAL + BOOT + HELPER)

    def test_hosted_nested_output_dispatches_patched_rd_methods(self):
        self.exercise(nested=True)

    def test_detached_output_dispatches_the_same_patched_rd_methods(self):
        self.exercise(nested=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
