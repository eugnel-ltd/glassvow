#!/usr/bin/env python3
"""Synthetic transport controls only; these do not establish native rendering."""
import base64
import hashlib
import io
import json
from pathlib import Path
import random
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2] /
                       "tools/godot/native_boot_upload"))
import contact_sheets as transport


class ContactSheetTransportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "render"
        self.root.mkdir()
        # The report deliberately reverses order; cases.json owns stable rows.
        self.cases = [{"name": name, "size": [64, 48], "source": "/MUST-NOT-BE-READ"}
                      for name in ("synthetic-blue", "synthetic-red")]
        self.report = {"status": "pass", "cases": [],
                       "live_negative_control": {"expected_rejection": "synthetic wrong source"}}
        for renderer in ("gles3", "rd"):
            for case, color in zip(self.cases, ((31, 83, 179), (197, 61, 43))):
                pixels = {"pair_exact": True, "source_oracle_max_channel_error": 0}
                for variant in ("baseline", "candidate"):
                    directory = Path(renderer) / case["name"] / variant
                    pixels[variant + "_sha256"] = self.capture(directory, color)
                self.report["cases"].insert(0, {"renderer": renderer, "case": case["name"],
                                               "pixels": pixels})
        self.capture(Path("negative-corrupt-source"), (233, 47, 191))
        self.save()

    def capture(self, directory, color):
        directory = self.root / directory
        directory.mkdir(parents=True)
        path = directory / "boot.png"
        Image.new("RGB", (64, 48), color).save(path)
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        (directory / "capture.json").write_text(json.dumps({
            "captured_while_native_hold": True, "screenshot_sha256": sha}))
        return sha

    def save(self):
        (self.root / "cases.json").write_text(json.dumps(self.cases))
        (self.root / "render-report.json").write_text(json.dumps(self.report))

    def test_both_sheets_roundtrip_with_every_actual_pair_in_stable_order(self):
        (self.root / "command.json").write_text("DO NOT READ UNRELATED COMMANDS")
        stream = io.StringIO()
        transport.emit(self.root, stream)
        blocks, active = [], None
        total = 0
        for line in stream.getvalue().splitlines():
            if line.startswith(transport.PREFIX + "BEGIN "):
                self.assertIsNone(active)
                active = [json.loads(line.split(" ", 1)[1]), []]
            elif line.startswith(transport.PREFIX + "DATA "):
                _, filename, number, chunk = line.split()
                self.assertEqual(filename, active[0]["filename"])
                self.assertEqual(number, f"{len(active[1]):04d}/{active[0]['chunks']:04d}")
                self.assertLessEqual(len(chunk), transport.CHUNK_SIZE)
                active[1].append(chunk)
            elif line.startswith(transport.PREFIX + "END "):
                _, filename, sha = line.split()
                metadata, chunks = active
                self.assertEqual((filename, sha), (metadata["filename"], metadata["sha256"]))
                self.assertEqual(len(chunks), metadata["chunks"])
                encoded = "".join(chunks)
                data = base64.b64decode(encoded, validate=True)
                self.assertEqual((len(data), hashlib.sha256(data).hexdigest()), (metadata["bytes"], sha))
                self.assertLessEqual(len(data), transport.MAX_JPEG_BYTES)
                self.assertEqual(data, (self.root / "contact-sheets" / filename).read_bytes())
                total += len(encoded)
                with Image.open(io.BytesIO(data)) as image:
                    self.assertEqual(image.format, "JPEG")
                    # A real input pixel remains visible at the first tile's center.
                    actual = image.getpixel((transport.PADDING + transport.THUMBNAIL[0] // 2,
                        transport.HEADER_HEIGHT + transport.LABEL_HEIGHT + transport.THUMBNAIL[1] // 2))
                    self.assertLess(max(abs(a - b) for a, b in zip(actual, (31, 83, 179))), 12)
                blocks.append(metadata)
                active = None
            else:
                self.fail("unexpected stdout outside the strict transport protocol")
        self.assertIsNone(active)
        self.assertEqual([item["renderer"] for item in blocks], ["gles3", "rd"])
        self.assertLessEqual(total, transport.MAX_BASE64_BYTES)
        manifests = json.loads((self.root / "contact-sheets/manifest.json").read_text())
        for metadata in blocks:
            self.assertEqual(metadata["case_names"][:2],
                             [case["name"] for case in self.cases])
            self.assertEqual(metadata["pairs"], 2)
            self.assertEqual(len(metadata["case_names"]), 3 if metadata["renderer"] == "gles3" else 2)
            manifest = next(item for item in manifests if item["renderer"] == metadata["renderer"])
            for row in manifest["inputs"]:
                self.assertEqual([image["variant"] for image in row["images"]], ["baseline", "candidate"])

    def test_running_or_failed_report_cannot_emit(self):
        for status in ("running", "failed_or_inconclusive"):
            self.report["status"] = status
            self.save()
            with self.assertRaisesRegex(ValueError, "successful render report"):
                transport.emit(self.root)
        self.assertFalse((self.root / "contact-sheets").exists())

    def test_incomplete_pair_matrix_and_negative_control_are_rejected(self):
        original = json.loads(json.dumps(self.report))
        self.report["cases"].pop()
        self.save()
        with self.assertRaisesRegex(ValueError, "incomplete pair matrix"):
            transport.prepare(self.root)
        self.report["cases"].append(self.report["cases"][0])
        self.save()
        with self.assertRaisesRegex(ValueError, "missing/duplicate"):
            transport.prepare(self.root)
        self.report = original
        self.report.pop("live_negative_control")
        self.save()
        with self.assertRaisesRegex(ValueError, "negative control missing"):
            transport.prepare(self.root)

    def test_missing_capture_is_rejected(self):
        (self.root / "gles3/synthetic-blue/baseline/boot.png").unlink()
        with self.assertRaisesRegex(ValueError, "missing/outside"):
            transport.prepare(self.root)

    def test_symlinked_file_and_parent_are_rejected(self):
        path = self.root / "gles3/synthetic-blue/baseline/boot.png"
        original = path.read_bytes()
        path.unlink()
        outside = self.root.parent / "outside.png"
        outside.write_bytes(original)
        path.symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "symlink"):
            transport.prepare(self.root)
        path.unlink()
        actual_parent = path.parent.with_name("baseline-real")
        path.parent.rename(actual_parent)
        path.parent.symlink_to(actual_parent, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            transport.prepare(self.root)
        root_alias = self.root.parent / "root-alias"
        root_alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            transport.prepare(root_alias)

    def test_traversal_case_is_rejected(self):
        self.cases[0]["name"] = "../outside"
        self.save()
        with self.assertRaisesRegex(ValueError, "invalid case name"):
            transport.prepare(self.root)

    def test_capture_and_report_hashes_are_required(self):
        path = self.root / "gles3/synthetic-blue/baseline/boot.png"
        path.write_bytes(path.read_bytes() + b"tamper")
        with self.assertRaisesRegex(ValueError, "metadata SHA differs"):
            transport.prepare(self.root)
        metadata = path.parent / "capture.json"
        data = json.loads(metadata.read_text())
        data["screenshot_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        metadata.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "report screenshot SHA differs"):
            transport.prepare(self.root)

    def test_native_hold_and_oracle_cannot_be_omitted(self):
        self.report["cases"][0]["pixels"]["pair_exact"] = False
        self.save()
        with self.assertRaisesRegex(ValueError, "pair/oracle"):
            transport.prepare(self.root)
        self.report["cases"][0]["pixels"]["pair_exact"] = True
        self.save()
        metadata = self.root / "gles3/synthetic-blue/baseline/capture.json"
        value = json.loads(metadata.read_text())
        value["captured_while_native_hold"] = False
        metadata.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, "native hold proof"):
            transport.prepare(self.root)

    def test_full_17_pair_high_entropy_matrix_fits_the_transport_caps(self):
        self.root = self.root.parent / "full-matrix"
        self.root.mkdir()
        size = list(transport.THUMBNAIL)
        pixels = random.Random(660).randbytes(size[0] * size[1] * 3)
        buffer = io.BytesIO()
        Image.frombytes("RGB", size, pixels).save(buffer, format="PNG")
        png = buffer.getvalue()
        sha = hashlib.sha256(png).hexdigest()
        self.cases = [{"name": f"synthetic-{index:02d}", "size": size} for index in range(17)]
        self.report["cases"] = []
        for renderer in ("gles3", "rd"):
            for case in self.cases:
                for variant in ("baseline", "candidate"):
                    directory = self.root / renderer / case["name"] / variant
                    directory.mkdir(parents=True)
                    (directory / "boot.png").write_bytes(png)
                    (directory / "capture.json").write_text(json.dumps({
                        "captured_while_native_hold": True, "screenshot_sha256": sha}))
                self.report["cases"].append({"renderer": renderer, "case": case["name"], "pixels": {
                    "pair_exact": True, "source_oracle_max_channel_error": 0,
                    "baseline_sha256": sha, "candidate_sha256": sha}})
        self.capture(Path("negative-corrupt-source"), (233, 47, 191))
        # The negative capture must retain the same actual fixture dimensions.
        directory = self.root / "negative-corrupt-source"
        (directory / "boot.png").write_bytes(png)
        (directory / "capture.json").write_text(json.dumps({
            "captured_while_native_hold": True, "screenshot_sha256": sha}))
        self.save()
        _, sheets = transport.prepare(self.root)
        self.assertEqual([item[0]["pairs"] for item in sheets], [17, 17])
        self.assertTrue(all(len(data) <= transport.MAX_JPEG_BYTES for _, data, _ in sheets))
        self.assertLessEqual(sum(len(encoded) for _, _, encoded in sheets), transport.MAX_BASE64_BYTES)

    def test_per_image_and_total_caps_fail_before_any_output(self):
        for field, value, message in (("MAX_JPEG_BYTES", 1, "JPEG exceeds"),
                                       ("MAX_BASE64_BYTES", 1, "base64 exceeds")):
            stream = io.StringIO()
            with patch.object(transport, field, value):
                with self.assertRaisesRegex(ValueError, message):
                    transport.emit(self.root, stream)
            self.assertEqual(stream.getvalue(), "")
            self.assertFalse((self.root / "contact-sheets").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
