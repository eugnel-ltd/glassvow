#!/usr/bin/env python3
"""Inspect the actual generated probe fixture before any native child starts.

Pinned project_settings.cpp SHA7de9335773ee4498d7559300d06f14717e715909db92b62b52dd44887e19cc94
loads res://.godot/global_script_class_cache.cfg and its root list (1446-1480).
A non-tools binary cannot recreate this file and reports a native ERROR when
it is absent. An empty list is correct only for this class_name-free fixture.
No native process, compiler, renderer, hardware query or provider is used here.
"""
import importlib.util
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "gv_staging_fixture_probe", ROOT / "tools/godot/native_texture_staging/probe.py")
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class NativeChildBoundaryObserved(BaseException):
    pass


class StandaloneStagingFixtureTests(unittest.TestCase):
    def inspect_before_child(self, inspect):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest = root / "synthetic-lvp.json"
            manifest.write_text("{}\n")
            binary = root / "unexecuted-native-template"
            output = root / "evidence"

            def boundary(command, **_kwargs):
                project = Path(command[command.index("--path") + 1])
                script = Path(command[command.index("--script") + 1])
                self.assertEqual(project, output / "project")
                self.assertEqual(script, project / "probe.gd")
                self.assertTrue((project / "project.godot").is_file())
                inspect(project, script)
                raise NativeChildBoundaryObserved()

            # Only the deterministic ICD selection and launch boundary are
            # substituted; the actual fixture builder and writes run unchanged.
            with patch.object(probe.Path, "glob", return_value=[manifest]), \
                    patch.object(probe.subprocess, "Popen", side_effect=boundary) as launch:
                with self.assertRaises(NativeChildBoundaryObserved):
                    probe.run(binary, output)
                self.assertEqual(launch.call_count, 1)

    def test_native_launch_has_a_valid_empty_root_global_class_list(self):
        def inspect(project, _script):
            cache = project / ".godot/global_script_class_cache.cfg"
            self.assertTrue(cache.is_file(),
                            "non-tools probe needs a readable global class cache before launch")
            # Both are valid ConfigFile encodings of an empty root Array.
            # No section, class path or extra statement may mask a dependency.
            self.assertRegex(cache.read_text(),
                r"\A\s*list\s*=\s*(?:\[\s*\]|Array\[Dictionary\]\(\[\s*\]\))\s*\Z")

        self.inspect_before_child(inspect)

    def test_empty_cache_matches_the_actual_no_global_class_fixture(self):
        def inspect(project, script):
            self.assertIsNone(re.search(r"(?m)^\s*class_name\b", script.read_text()))
            self.assertEqual(script.read_text(), probe.SCRIPT)
            self.assertNotIn("[autoload]", (project / "project.godot").read_text())

        self.inspect_before_child(inspect)


if __name__ == "__main__":
    unittest.main(verbosity=2)
