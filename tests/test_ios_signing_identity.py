#!/usr/bin/env python3
"""Pin the EUGNEL iOS signing identity without invoking Godot or Apple."""
from __future__ import annotations

from pathlib import Path
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
OLD_TEAM = "V45S7" "U2LZB"
TEAM = "GPABDG7FX9"
IOS_BUNDLE = "uk.eugnel.glassvow"
ANDROID_PACKAGE = "io.fol2.glassvow"
DIST_SHA1 = "E9424DE51C7A973A15E62BB4F5BCA2D228578935"
DEV_SHA1 = "B4331E019A5948B169B10B581668BB6B89C06DEC"
DIST_PROFILE = "b7e59e22-1ebc-47d7-843e-27e99d5cbb4b"
DEV_PROFILE = "0b2a6f42-cadf-4b3e-8de8-7fd41d072ddb"
DIST_PROFILE_NAME = "Glassvow App Store EUGNEL"
DEV_PROFILE_NAME = "Glassvow Development EUGNEL"
APP_ID_RESOURCE = "JW83GQ7SJ6"
HISTORICAL_PREFIXES = ("docs/reviews/", "docs/design/")
LIVE_SIGNING_PATHS = (
    "export_presets.cfg",
    "product.yaml",
    "docs/rc-bar.md",
    "docs/release-signing.md",
    "scripts/ios_export_options.plist",
    "scripts/ios_export_options_development.plist",
    "scripts/ios_release.sh",
    "scripts/store_signing_wizard.sh",
    "tests/test_release_identity.gd",
)


def git_files() -> list[str]:
    import subprocess
    listed = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [path.decode() for path in listed.split(b"\0") if path]


def preset_options(text: str, want: str) -> dict[str, str]:
    current_name = ""
    current_opts: dict[str, str] = {}
    in_options = False
    for line in text.splitlines():
        if line.startswith("[preset.") and line.endswith(".options]"):
            in_options = True
            continue
        if line.startswith("[preset.") and line.endswith("]"):
            if current_name == want:
                return current_opts
            in_options = False
            current_name = ""
            current_opts = {}
            continue
        if not in_options:
            if line.startswith("name="):
                current_name = line[5:].strip().strip('"')
                current_opts = {}
            continue
        if current_name != want or line.startswith(";") or not line.strip():
            continue
        key, _, raw = line.partition("=")
        current_opts[key] = raw.strip().strip('"')
    if current_name == want:
        return current_opts
    return {}


class SigningIdentityTests(unittest.TestCase):
    def test_live_files_drop_the_personal_team(self) -> None:
        remaining = []
        for path in git_files():
            if path.startswith(HISTORICAL_PREFIXES):
                continue
            text = (ROOT / path).read_text(encoding="utf-8", errors="replace")
            if OLD_TEAM in text:
                remaining.append(path)
        self.assertEqual([], remaining)

    def test_named_live_paths_use_the_eugnel_team(self) -> None:
        for path in LIVE_SIGNING_PATHS:
            text = (ROOT / path).read_text(encoding="utf-8")
            self.assertIn(TEAM, text, path)
            self.assertNotIn(OLD_TEAM, text, path)

    def test_ios_presets_and_android_packages(self) -> None:
        presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        for name in ("iOS", "iOS Dev Review"):
            opts = preset_options(presets, name)
            self.assertEqual(TEAM, opts.get("application/app_store_team_id"), name)
            self.assertEqual(IOS_BUNDLE, opts.get("application/bundle_identifier"), name)
        for name in ("Android (Play AAB)", "Android Dev Review"):
            opts = preset_options(presets, name)
            self.assertEqual(ANDROID_PACKAGE, opts.get("package/unique_name"), name)
        macos = preset_options(presets, "macOS")
        self.assertEqual(ANDROID_PACKAGE, macos.get("application/bundle_identifier"))

    def test_export_plists_select_certificates_by_sha1(self) -> None:
        store = plistlib.loads((ROOT / "scripts/ios_export_options.plist").read_bytes())
        development = plistlib.loads(
            (ROOT / "scripts/ios_export_options_development.plist").read_bytes())
        self.assertEqual("app-store-connect", store["method"])
        self.assertEqual("manual", store["signingStyle"])
        self.assertEqual(TEAM, store["teamID"])
        self.assertEqual(DIST_SHA1, store["signingCertificate"])
        self.assertEqual({IOS_BUNDLE: DIST_PROFILE}, store["provisioningProfiles"])
        self.assertIs(store["manageAppVersionAndBuildNumber"], False)
        self.assertIs(store["uploadSymbols"], True)
        self.assertEqual("development", development["method"])
        self.assertEqual("manual", development["signingStyle"])
        self.assertEqual(TEAM, development["teamID"])
        self.assertEqual(DEV_SHA1, development["signingCertificate"])
        self.assertEqual({IOS_BUNDLE: DEV_PROFILE}, development["provisioningProfiles"])
        docs = (ROOT / "docs/release-signing.md").read_text(encoding="utf-8")
        for needle in (DIST_PROFILE, DEV_PROFILE, DIST_PROFILE_NAME, DEV_PROFILE_NAME,
                       APP_ID_RESOURCE):
            self.assertIn(needle, docs)

    def test_release_script_uses_dedicated_keychain_and_asc_file(self) -> None:
        text = (ROOT / "scripts/ios_release.sh").read_text(encoding="utf-8")
        self.assertIn("unlock-build-keychain.sh", text)
        self.assertIn("~/.config/eugnel-build/keys/asc.env", text)
        self.assertIn("AuthKey_9PBA26ZNT6.p8", text)
        self.assertNotIn("login.keychain", text)
        self.assertNotIn("6803851427", text)
        self.assertIn('ASC_APP_ID="${ASC_APP_ID:-}"', text)
        self.assertNotRegex(text, r"ASC_ISSUER_ID=\$\{ASC_ISSUER_ID:-.+\}")
        self.assertIsNone(re.search(
            r"ASC_ISSUER_ID=.?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-", text))

    def test_product_manifest_ios_bundle_and_pending_store_id(self) -> None:
        text = (ROOT / "product.yaml").read_text(encoding="utf-8")
        self.assertIn("bundle_id: uk.eugnel.glassvow", text)
        self.assertIn("package: io.fol2.glassvow", text)
        self.assertRegex(text, r"store_ids:\n\s+ios: null")


if __name__ == "__main__":
    unittest.main()
