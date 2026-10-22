#!/usr/bin/env python3
"""Refuse an App Store IPA unless its Xcode build has release provenance."""

from __future__ import annotations

import argparse
from pathlib import Path
import plistlib
import re
import sys
from xml.parsers.expat import ExpatError
import zipfile

# Release provenance: docs/release-signing.md, toolchain table; confirmed in
# docs/design/2026-10-11-first-use-shaders/proof/part1/README.md.
# A letter suffix is not a beta test: the qualified release ends in "a".
# 27A9275 (Xcode 27.1): Apple Developer Releases lists it as the final release
# on 2026-10-15 (the same build number as the 2026-10-05 RC).
QUALIFIED_XCODE_BUILDS = {"27A266a": "Xcode 27.0", "27A9275": "Xcode 27.1"}
APP_INFO = re.compile(r"Payload/[^/]+\.app/Info\.plist\Z")


class _DuplicateKeyError(Exception):
    """Keep duplicate-key diagnostics through the binary parser's error wrapper."""


class _UniqueKeys(dict):
    """Preserve ambiguity as an error in both plistlib parser formats."""

    def __setitem__(self, key: object, value: object) -> None:
        if key in self:
            raise _DuplicateKeyError("duplicate Info.plist dictionary key")
        super().__setitem__(key, value)


def qualify(ipa: Path) -> tuple[str, str]:
    with zipfile.ZipFile(ipa) as archive:
        entries = [item for item in archive.infolist() if APP_INFO.fullmatch(item.filename)]
        if len(entries) != 1 or entries[0].is_dir():
            raise ValueError("expected exactly one top-level app Info.plist")
        metadata = plistlib.loads(archive.read(entries[0]), dict_type=_UniqueKeys)
    if not isinstance(metadata, dict):
        raise ValueError("app Info.plist must be a dictionary")
    build = metadata.get("DTXcodeBuild")
    if not isinstance(build, str) or not build:
        raise ValueError("DTXcodeBuild must be a nonempty string")
    if build not in QUALIFIED_XCODE_BUILDS:
        raise ValueError("DTXcodeBuild has no recorded release qualification; "
                         "see docs/release-signing.md, IPA Xcode qualification")
    return build, QUALIFIED_XCODE_BUILDS[build]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    try:
        build, release = qualify(args.ipa)
    except (OSError, zipfile.BadZipFile, plistlib.InvalidFileException,
            ExpatError, ValueError, RuntimeError, _DuplicateKeyError) as error:
        print(f"ios_release: IPA Xcode qualification failed: {error}", file=sys.stderr)
        return 1
    print(f"Qualified DTXcodeBuild: {build} ({release})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
