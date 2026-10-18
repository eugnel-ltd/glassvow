#!/usr/bin/env python3
"""Source-only runtime-test builder contract; no native binary is executed.

Pinned main/main.cpp SHA1831257f5c8eb0707d278f04b21b1e4b3ba863f8dca5cab36022d4b19e36b8c1
rejects --path without OVERRIDE_PATH_ENABLED (1769-1785), resets cwd to the
executable directory (1044-1056), and clears --script (4322-4333). The existing
probe uses both CLI overrides; merely changing cwd is unsupported.
"""
import argparse
import ast
import hashlib
from pathlib import Path
import re
import unittest

BUILDER = None
ROOT = Path(__file__).resolve().parents[2]


class StagingRuntimeBuilderTests(unittest.TestCase):
    def test_actual_builder_flags_support_the_existing_native_probe(self):
        module = ast.parse(BUILDER.read_text())
        flags = next(ast.literal_eval(node.value) for node in module.body
                     if isinstance(node, ast.Assign) and any(
                         isinstance(target, ast.Name) and target.id == "FLAGS" for target in node.targets))
        self.assertEqual(flags.count("disable_path_overrides=no"), 1,
                         "native --path/--script require an explicitly supported runtime-test build")
        self.assertIn("target=template_debug", flags)

    def test_workflow_binds_the_actual_shared_builder_bytes(self):
        text = (ROOT / ".github/workflows/native-texture-staging.yml").read_text()
        matches = re.findall(r'"build\.py":\s*"([0-9a-f]{64})"', text)
        self.assertEqual(matches, [hashlib.sha256(BUILDER.read_bytes()).hexdigest()])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--builder", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    BUILDER = args.builder
    unittest.main(argv=[__file__, *remaining], verbosity=2)
