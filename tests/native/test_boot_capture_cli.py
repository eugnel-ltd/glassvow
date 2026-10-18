#!/usr/bin/env python3
"""Command contract from the pinned native parser; no engine is executed.

Both ed1daf0bf001b61586d9930840f2f1394092c079 and
83dec14d549108e1f314f57c1ce7e932c65370dd have main/main.cpp SHA256
1831257f5c8eb0707d278f04b21b1e4b3ba863f8dca5cab36022d4b19e36b8c1.
Lines 1438-1451 require 'x' and parse W/H using get_slicec('x', ...).
Lines 1481-1494 require ',' and parse X/Y using get_slicec(',', ...).
The subprocess boundary below observes the worker's real constructed argv.
"""
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2] /
                       "tools/godot/native_boot_upload"))
import capture


class CommandObserved(BaseException):
    """Stop before launching any native process."""


class NativeCaptureCommandTests(unittest.TestCase):
    def command(self, renderer):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            splash = root / "source.png"
            Image.new("RGB", (2, 2), (31, 83, 179)).save(splash)
            spec = {"binary": "/not-executed/godot", "renderer": renderer,
                    "output": str(root / "capture"), "case": {
                        "source": str(splash), "size": [1180, 820],
                        "filter": True, "stretch": 1}}
            observed = []

            def intercept(argv, **kwargs):
                observed.extend(argv)
                raise CommandObserved()

            with patch.object(capture.subprocess, "Popen", side_effect=intercept):
                with self.assertRaises(CommandObserved):
                    capture.capture_worker(spec)
            return observed

    def test_resolution_obeys_pinned_native_parser(self):
        for renderer in ("gles3", "rd"):
            with self.subTest(renderer=renderer):
                argv = self.command(renderer)
                value = argv[argv.index("--resolution") + 1]
                self.assertIsNotNone(re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", value),
                                     "Godot requires --resolution <W>x<H>")
                self.assertEqual([int(part) for part in value.split("x")], [1180, 820])

    def test_position_retains_its_distinct_comma_delimiter(self):
        argv = self.command("gles3")
        self.assertEqual(argv[argv.index("--position") + 1], "0,0")


if __name__ == "__main__":
    unittest.main(verbosity=2)
