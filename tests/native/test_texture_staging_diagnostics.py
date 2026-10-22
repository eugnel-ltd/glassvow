#!/usr/bin/env python3
"""Synthetic failure-log controls; no engine, compiler or native proof."""
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] /
                       'tools/godot/native_texture_staging'))
import diagnostics


class StagingDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'component'
        self.root.mkdir()

    def output(self):
        stream = io.StringIO()
        diagnostics.emit(self.root, stream)
        return stream.getvalue()

    def test_both_missing_native_logs_are_explicit(self):
        output = self.output()
        for variant in ('baseline', 'candidate'):
            self.assertIn(variant + ': native.log unavailable', output)

    def test_only_bounded_generated_native_logs_are_printed(self):
        for variant in ('baseline', 'candidate'):
            directory = self.root / ('rd-' + variant)
            directory.mkdir()
            (directory / 'native.log').write_text('OLD OMITTED\n' + 'x' * 100000 +
                '\n::error::prefixed text\ntoken=synthetic-secret\nhttps://signed.invalid/example\nTAIL ERROR\n')
            (directory / 'command.json').write_text('COMMAND MUST NOT BE READ')
        (self.root / 'unrelated.log').write_text('UNRELATED MUST NOT BE READ')
        output = self.output()
        self.assertLess(len(output), 24000)
        self.assertEqual(output.count('TAIL ERROR'), 2)
        for text in ('OLD OMITTED', 'synthetic-secret', 'signed.invalid', 'COMMAND MUST NOT', 'UNRELATED MUST NOT'):
            self.assertNotIn(text, output)
        self.assertTrue(all(line.startswith('native-staging diagnostic | ') for line in output.splitlines()))

    def test_symlinked_log_directory_and_root_are_refused(self):
        outside = self.root.parent / 'outside'
        outside.mkdir()
        (outside / 'native.log').write_text('OUTSIDE MUST NOT BE READ')
        (self.root / 'rd-baseline').symlink_to(outside, target_is_directory=True)
        candidate = self.root / 'rd-candidate'
        candidate.mkdir()
        (candidate / 'native.log').symlink_to(outside / 'native.log')
        self.assertNotIn('OUTSIDE MUST NOT', self.output())
        alias = self.root.parent / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        stream = io.StringIO()
        diagnostics.emit(alias, stream)
        self.assertIn('Symlink evidence root refused', stream.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=2)
