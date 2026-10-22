#!/usr/bin/env python3
"""A bad same-host receipt must stop the real wrapper before Popen.

Synthetic ICD/library files and an intercepted launch only; no Vulkan library
is loaded and no native child is executed. Original probe SCRIPT stays frozen.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "gv_staging_binding_probe", ROOT / "tools/godot/native_texture_staging/probe.py")
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class NativeChildStarted(BaseException):
    pass


class CapabilityBindingTests(unittest.TestCase):
    def rejected_before_child(self, change):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            library = root / "libvulkan_lvp.so"
            library.write_bytes(b"synthetic-driver")
            icd = root / "lvp.json"
            icd.write_text(json.dumps({"ICD": {"library_path": str(library)}}))
            receipt = root / "result.json"
            data = {"schema": 1, "profile": "linux-x86_64-lavapipe-v1",
                "status": "CAPABILITY_SUPPORTED", "component_status": "NOT_RUN", "errors": [],
                "formats": [{"format": name, "format_id": value, "usage": 193, "supported": True}
                    for name, value in [("ETC2_RGB8", 146), ("ETC2_RGBA8", 150), ("EAC_RG11", 154),
                                        ("ASTC_4x4_UNORM", 156), ("RGBA8", 36), ("RG8_LA8", 15)]],
                "linux_driver": {"icd_path": str(icd),
                    "icd_sha256": hashlib.sha256(icd.read_bytes()).hexdigest(),
                    "library_path": str(library), "library_bytes": library.stat().st_size,
                    "library_sha256": hashlib.sha256(library.read_bytes()).hexdigest()}}
            change(data, library, icd)
            receipt.write_text(json.dumps(data))
            with patch.dict(os.environ, {"GLASSVOW_STAGING_CAPABILITY_RECEIPT": str(receipt)}), \
                    patch.object(probe.Path, "glob", return_value=[icd]), \
                    patch.object(probe.subprocess, "Popen", side_effect=NativeChildStarted) as child:
                try:
                    probe.run(root / "unexecuted-native-template", root / "evidence")
                except ValueError:
                    self.assertEqual(child.call_count, 0)
                except NativeChildStarted:
                    self.fail("unqualified/changed same-host capability receipt reached a native child")
                else:
                    self.fail("unqualified/changed same-host capability receipt was silently accepted")

    def test_unqualified_receipt_stops_before_native_variant(self):
        self.rejected_before_child(lambda data, _lib, _icd: data.update(status="INCONCLUSIVE"))

    def test_changed_library_bytes_stop_before_native_variant(self):
        self.rejected_before_child(lambda _data, library, _icd: library.write_bytes(b"changed"))

    def test_changed_icd_bytes_stop_before_native_variant(self):
        self.rejected_before_child(lambda _data, _lib, icd: icd.write_text("{}\n"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
