#!/usr/bin/env python3
"""Synthetic capability-contract/rejection controls, never GPU success proof.

The real stock engine is not launched or downloaded by these tests. Two inert
Python children exercise the maintained subprocess output/timeout cleanup.
"""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "tools/godot/native_texture_staging/capability.py"
capability = None
if PATH.exists():
    spec = importlib.util.spec_from_file_location("gv_staging_capability", PATH)
    capability = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(capability)

FORMATS = [("ETC2_RGB8", 146), ("ETC2_RGBA8", 150), ("EAC_RG11", 154),
           ("ASTC_4x4_UNORM", 156), ("RGBA8", 36), ("RG8_LA8", 15)]
VERSION = "4.7.2.stable.official.ed1daf0bf"
MAC = {"system": "Darwin", "uname_machine": "arm64", "python_machine": "arm64",
       "translated": False}
LINUX = {"system": "Linux", "uname_machine": "x86_64", "python_machine": "x86_64",
         "translated": False}


def log(profile="macos-arm64-metal-v1", records=None, device=None):
    metal = profile == "macos-arm64-metal-v1"
    device = device or {"schema": 1, "vendor": "Apple" if metal else "Unknown",
        "name": "Apple Synthetic Test GPU" if metal else "llvmpipe (synthetic)",
        "os": "macOS" if metal else "Linux", "arm64": metal, "x86_64": not metal}
    records = records if records is not None else [
        {"format": name, "format_id": value, "usage": 193, "supported": True}
        for name, value in FORMATS]
    startup = ("Metal 3.2 - Forward Mobile - Using Device #0: Apple - Apple Synthetic Test GPU"
        if metal else "Vulkan 1.4.318 - Forward Mobile - Using Device #0: Unknown - llvmpipe (synthetic)")
    return "\n".join([startup, "GV_TEXTURE_CAPABILITY_DEVICE " + json.dumps(device),
        *["GV_TEXTURE_CAPABILITY_FORMAT " + json.dumps(row) for row in records],
        "GV_TEXTURE_CAPABILITY_DONE 6", ""])


class CapabilityContractTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(capability,
            "maintained stock capability preflight is missing before the expensive paired build")

    def assess(self, text=None, host=None, version=VERSION, code=0,
               profile="macos-arm64-metal-v1"):
        return capability.assess(profile, host or MAC, version,
                                  log(profile) if text is None else text, code)

    def rejected(self, result):
        self.assertEqual(result["status"], "INCONCLUSIVE")
        self.assertEqual(result["component_status"], "NOT_RUN")
        self.assertTrue(result["errors"])

    def test_complete_typed_capture_is_capability_only(self):
        for profile, host in [("macos-arm64-metal-v1", MAC), ("linux-x86_64-lavapipe-v1", LINUX)]:
            result = self.assess(profile=profile, host=host)
            self.assertEqual(result["status"], "CAPABILITY_SUPPORTED")
            self.assertEqual(result["component_status"], "NOT_RUN")
            self.assertEqual([(x["format"], x["format_id"]) for x in result["formats"]], FORMATS)
            self.assertTrue(all(type(x["supported"]) is bool and x["usage"] == 193 for x in result["formats"]))

    def test_wrong_architecture_rosetta_and_os_are_unqualified(self):
        for key, value in [("uname_machine", "x86_64"), ("python_machine", "x86_64"),
                           ("translated", True), ("system", "Linux")]:
            host = dict(MAC, **{key: value})
            self.rejected(self.assess(host=host))

    def test_wrong_backend_missing_startup_or_blank_device_are_unqualified(self):
        for text in [log().replace("Metal 3.2", "Vulkan 1.4"),
                     "\n".join(log().splitlines()[1:]),
                     log().replace('"vendor": "Apple"', '"vendor": ""'),
                     log() + "OpenGL API 4.5 - Compatibility\n"]:
            self.rejected(self.assess(text))

    def test_unsupported_missing_duplicate_wrong_id_and_wrong_usage_are_unqualified(self):
        good = [{"format": name, "format_id": value, "usage": 193, "supported": True}
                for name, value in FORMATS]
        unsupported = copy.deepcopy(good)
        unsupported[0]["supported"] = False
        self.rejected(self.assess(log(records=unsupported)))
        self.assertEqual(len(self.assess(log(records=unsupported))["formats"]), 6)
        for records in [good[:-1], good + [good[0]],
                        [dict(good[0], format_id=147)] + good[1:],
                        [dict(good[0], usage=1)] + good[1:],
                        [dict(good[0], supported=1)] + good[1:]]:
            self.rejected(self.assess(log(records=records)))

    def test_bad_version_diagnostics_nonzero_and_ambiguous_protocol_are_unqualified(self):
        self.rejected(self.assess(version="4.7.1.stable.official"))
        self.rejected(self.assess(version="4.7.2.dev.custom_build"))
        self.rejected(self.assess(code=2))
        for extra in ["ERROR: native failure\n", "SCRIPT ERROR: invalid call\n",
                      "Parse Error: invalid script\n", "GV_TEXTURE_CAPABILITY_DONE 6\n",
                      "GV_TEXTURE_CAPABILITY_FORMAT {bad-json}\n"]:
            self.rejected(self.assess(log() + extra))

    def test_archive_hash_and_size_are_checked_before_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "synthetic.zip"
            archive.write_bytes(b"synthetic-pinned-archive")
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            result = capability.verify_archive(archive, archive.stat().st_size, checksum)
            self.assertEqual(result["sha256"], checksum)
            for size, sha in [(archive.stat().st_size + 1, checksum),
                              (archive.stat().st_size, "0" * 64)]:
                with self.assertRaises(ValueError):
                    capability.verify_archive(archive, size, sha)

    def test_owned_child_timeout_and_log_limit_stop_and_reap(self):
        with tempfile.TemporaryDirectory() as temporary:
            for source, seconds, limit in [
                    ("import time; time.sleep(10)", 0.1, 4096),
                    ("import sys,time; print('x'*100000,flush=True); time.sleep(10)", 5, 1024)]:
                result = capability.run_process([sys.executable, "-c", source],
                    Path(temporary), os.environ.copy(), seconds, limit)
                self.assertTrue(result["timed_out"] or result["output_limit"])
                self.assertTrue(result["reaped"])
                self.assertLessEqual(len(result["output"].encode()), limit)
                with self.assertRaises(ProcessLookupError):
                    os.kill(result["pid"], 0)

    def test_script_queries_only_bound_device_names_and_six_required_formats(self):
        source = capability.SCRIPT
        self.assertIn("get_device_vendor_name()", source)
        self.assertIn("get_device_name()", source)
        self.assertNotIn("get_device_type()", source)
        self.assertNotIn("get_device_api_version()", source)
        self.assertNotIn("texture_create(", source)
        self.assertNotIn("texture_get_data(", source)
        self.assertNotIn("class_name ", source)
        self.assertIn("texture_is_format_supported_for_usage", source)

    def test_linux_library_and_receipt_changes_fail_before_native_child(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            library = root / "libvulkan_lvp.so"
            library.write_bytes(b"synthetic-driver")
            icd = root / "lvp.json"
            icd.write_text(json.dumps({"ICD": {"library_path": str(library)}}))
            binding = capability.linux_binding(icd, {})
            result = self.assess(profile="linux-x86_64-lavapipe-v1", host=LINUX)
            result["linux_driver"] = binding
            receipt = root / "result.json"
            receipt.write_text(json.dumps(result))
            capability.verify_linux_binding(receipt, icd, {})
            library.write_bytes(b"changed-driver")
            with self.assertRaises(ValueError):
                capability.verify_linux_binding(receipt, icd, {})
            library.write_bytes(b"synthetic-driver")
            with self.assertRaises(ValueError):
                capability.linux_binding(icd, {"LD_LIBRARY_PATH": "/wrong"})
            result["status"] = "INCONCLUSIVE"
            receipt.write_text(json.dumps(result))
            with self.assertRaises(ValueError):
                capability.verify_linux_binding(receipt, icd, {})

    def test_existing_workflow_keeps_stock_check_before_compilation(self):
        source = (ROOT / ".github/workflows/native-texture-staging.yml").read_text()
        self.assertIn("macos-15", source)
        self.assertIn("macos-arm64-metal-v1", source)
        self.assertLess(source.index("--profile linux-x86_64-lavapipe-v1"),
                        source.index("- name: Compile native controls"))
        self.assertIn("test_texture_staging_capability.py", source)
        self.assertIn("GLASSVOW_STAGING_CAPABILITY_RECEIPT", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
