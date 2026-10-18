#!/usr/bin/env python3
"""Duplicate plist dictionary keys must not qualify an IPA or reach upload."""

from __future__ import annotations

from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

import test_ios_release_qualification as original


def duplicate_xml(first: str) -> bytes:
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<plist version="1.0"><dict>'
            f'<key>DTXcodeBuild</key><string>{first}</string>'
            f'<key>DTXcodeBuild</key><string>27A266a</string>'
            f'</dict></plist>').encode()


def duplicate_binary(first: str) -> bytes:
    # Four binary-plist objects: a two-entry dictionary whose key references
    # both point to DTXcodeBuild, then that key and its two string values.
    # Construct the wire bytes: a normal Python dict cannot retain duplicates.
    objects = [b"\xd2\x01\x01\x02\x03"]
    for value in ("DTXcodeBuild", first, "27A266a"):
        raw = value.encode("ascii")
        assert len(raw) < 15
        objects.append(bytes([0x50 | len(raw)]) + raw)
    body = b"bplist00"
    offsets = []
    for obj in objects:
        offsets.append(len(body))
        body += obj
    table_offset = len(body)
    trailer = b"\x00" * 6 + b"\x01\x01" + struct.pack(">QQQ", len(objects), 0, table_offset)
    return body + bytes(offsets) + trailer


def write_raw_ipa(path: Path, data: bytes) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(original.APP_INFO, data)


class DuplicateMetadataTests(unittest.TestCase):
    def test_raw_fixtures_preserve_the_last_wins_failure_mode(self) -> None:
        for encode in (duplicate_xml, duplicate_binary):
            with self.subTest(format=encode.__name__):
                self.assertEqual(plistlib.loads(encode("27A-beta")),
                                 {"DTXcodeBuild": "27A266a"})

    def test_conflicting_and_identical_duplicate_keys_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="glassvow-duplicate-plist-") as scratch:
            ipa = Path(scratch) / "duplicate.ipa"
            for encode in (duplicate_xml, duplicate_binary):
                for first in ("27A-beta", "27A266a"):
                    with self.subTest(format=encode.__name__, first=first):
                        write_raw_ipa(ipa, encode(first))
                        result = subprocess.run(
                            [sys.executable, "-B", str(original.CHECKER), str(ipa)],
                            capture_output=True, text=True, check=False)
                        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                        self.assertIn("duplicate", result.stderr.lower())

    def test_conflicting_duplicates_never_reach_the_release_upload(self) -> None:
        for encode in (duplicate_xml, duplicate_binary):
            with self.subTest(format=encode.__name__):
                case = original.ReleaseBoundaryTests()
                case.setUp()
                try:
                    write_raw_ipa(case.ipa, encode("27A-beta"))
                    result = case.release()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(case.uploads.exists(), result.stdout + result.stderr)
                    self.assertIn("duplicate", result.stderr.lower())
                finally:
                    case.doCleanups()


if __name__ == "__main__":
    unittest.main()
