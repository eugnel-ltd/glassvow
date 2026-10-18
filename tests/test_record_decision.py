#!/usr/bin/env python3
"""Reject ambiguous or unterminated owner-decision documents without changes."""
from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/record_decision.sh'


class RecordDecisionDocumentTests(unittest.TestCase):
    def assert_rejected_unchanged(self, original: bytes) -> None:
        with tempfile.TemporaryDirectory(prefix='glassvow-decision-document-') as tmp:
            path = Path(tmp) / 'owner-decisions.md'
            path.write_bytes(original)
            result = subprocess.run(
                ['sh', str(SCRIPT), 'A supplied decision', 'Keep the stated rule.',
                 '"Keep the stated rule."', 'delivery', str(path)],
                cwd=tmp, text=True, capture_output=True, check=False)
            self.assertEqual(1, result.returncode, result.stderr)
            self.assertEqual(original, path.read_bytes(),
                             'rejected owner decisions must remain byte-for-byte intact')

    def test_duplicate_decisions_headings_are_rejected_unchanged(self) -> None:
        self.assert_rejected_unchanged(
            b'# Owner decisions\n\n## Decisions\n\n'
            b'## 2026-10-01: Existing decision\n- Decision: Keep the old rule.\n\n'
            b'## Decisions\n')

    def test_missing_final_newline_is_rejected_unchanged(self) -> None:
        self.assert_rejected_unchanged(
            b'# Owner decisions\n\n## Decisions\n\n'
            b'## 2026-10-01: Existing decision\n- Decision: Keep the old rule.')


if __name__ == '__main__':
    unittest.main()
