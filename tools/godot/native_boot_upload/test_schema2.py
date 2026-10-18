#!/usr/bin/env python3
"""Schema2 evidence-parser regressions. These are not engine/GPU proof."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from verify import PREFIX, screen_rect, verify_uploads


class FullTextureTransferVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = self.root / "source.png"
        Image.new("RGB", (2360, 1640)).save(source)
        self.case = {"source": str(source), "size": [1180, 820], "filter": True, "stretch": 1}

    def records(self, renderer="rd", baseline=False, pitch_step=1):
        bpp = 4 if renderer == "rd" else 3
        pitch = ((2360 * bpp + pitch_step - 1) // pitch_step) * pitch_step
        records = [dict(event="begin", renderer=renderer, source_width=2360, source_height=1640,
                        source_format="RGB8", source_bytes=11611200, window_width=1180,
                        window_height=820, filter=True, stretch=1),
                   dict(event="texture", texture_id=19, width=2360, height=1640, depth=1,
                        layers=1, mipmaps=1, bytes_per_pixel=bpp, logical_bytes=2360 * 1640 * bpp,
                        initial_data_bytes=2360 * 1640 * bpp if baseline else 0,
                        format_code=36 if renderer == "rd" else 32849,
                        api="texture_create" if renderer == "rd" else "glTexImage2D")]
        heights = [1640] if baseline else [410] * 4
        row = 0
        for index, height in enumerate(heights):
            if renderer == "rd":
                records.append(dict(event="staging", index=index, request_bytes=pitch * height,
                                    allocated_bytes=pitch * height, offset=0, alignment=4,
                                    buffer_capacity=16777216 if baseline else 4194304,
                                    api="transfer_worker" if baseline else "frame_staging"))
            api = ("rd_initialize_copy" if baseline else "rd_update_copy") if renderer == "rd" else (
                    "glTexImage2D" if baseline else "glTexSubImage2D")
            records.append(dict(event="transfer", index=index, texture_id=19, x=0, y=row, z=0,
                                width=2360, height=height, depth=1, mipmap=0, layer=0,
                                source_offset=row * 2360 * bpp, source_bytes=2360 * height * bpp,
                                row_pitch=pitch, row_pitch_step=pitch_step, buffer_offset=0,
                                staging_index=index if renderer == "rd" else -1, api=api))
            row += height
        left, top, width, height = screen_rect((2360, 1640), self.case["size"], 1)
        destination = [left / 1180, top / 820, width / 1180, height / 820]
        if renderer == "gles3":
            destination[1], destination[3] = 1 - destination[1], -destination[3]
        records += [dict(event="draw", texture_id=19, source_uv=[0, 0, 1, 1], destination=destination),
                    dict(event="present", textures=1, transfers=len(heights), draws=1, clears=1, presents=1),
                    dict(event="hold")]
        return [dict(record, schema=2) for record in records]

    def verify(self, records, renderer="rd", variant="candidate"):
        log = self.root / "native.log"
        log.write_text("".join(PREFIX + json.dumps(record) + "\n" for record in records))
        return verify_uploads(log, self.case, renderer, variant)

    def changed_event(self, records, event, occurrence=0, **changes):
        records = copy.deepcopy(records)
        candidates = [record for record in records if record["event"] == event]
        candidates[occurrence].update(changes)
        return records

    def test_real_rd_four_transfers_preserve_full_allocation(self):
        result = self.verify(self.records())
        self.assertEqual(result["texture"]["logical_bytes"], 15481600)
        self.assertEqual(result["maximum_transfer_or_reservation_bytes"], 3870400)
        self.assertEqual(result["total_source_transfer_bytes"], 15481600)

    def test_real_gles_four_transfers_preserve_full_allocation(self):
        result = self.verify(self.records("gles3"), "gles3")
        self.assertEqual(result["texture"]["logical_bytes"], 11611200)
        self.assertEqual(result["maximum_transfer_or_reservation_bytes"], 2902800)

    def test_both_native_oversized_baselines_remain_meaningful_controls(self):
        for renderer in ("rd", "gles3"):
            result = self.verify(self.records(renderer, baseline=True), renderer, "baseline")
            self.assertEqual(result["cap_result"], "expected_baseline_failure")

    def test_actual_aligned_pitch_is_used(self):
        result = self.verify(self.records(pitch_step=256))
        self.assertEqual(result["maximum_transfer_or_reservation_bytes"], 3883520)

    def test_four_draws_do_not_pass_the_new_causal_contract(self):
        with self.assertRaisesRegex(AssertionError, "one full quad"):
            self.verify(self.changed_event(self.records(), "present", draws=4))

    def test_sliced_gpu_allocation_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "full-size texture"):
            self.verify(self.changed_event(self.records(), "texture", height=410))

    def test_extra_texture_is_rejected(self):
        records = self.records()
        records.insert(2, dict(records[1], texture_id=20))
        with self.assertRaisesRegex(AssertionError, "exactly one texture"):
            self.verify(records)

    def test_full_initial_upload_cannot_hide_behind_bounded_copies(self):
        with self.assertRaisesRegex(AssertionError, "initial-data"):
            self.verify(self.changed_event(self.records(), "texture", initial_data_bytes=15481600))

    def test_row_gap_and_overlap_and_gutter_are_rejected(self):
        for changed_y in (409, 411):
            with self.assertRaisesRegex(AssertionError, "gaps/overlap/gutters"):
                self.verify(self.changed_event(self.records(), "transfer", occurrence=1, y=changed_y))

    def test_shifted_source_pointer_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "source pointer"):
            self.verify(self.changed_event(self.records(), "transfer", occurrence=1, source_offset=0))

    def test_missing_last_native_copy_is_rejected(self):
        records = self.records()
        records = [record for record in records if not
                   (record["event"] in ("transfer", "staging") and record["index"] == 3)]
        with self.assertRaises(AssertionError):
            self.verify(records)

    def test_unbounded_actual_staging_request_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "actual staging request"):
            self.verify(self.changed_event(self.records(), "staging", request_bytes=15481600))

    def test_native_reservation_larger_than_cap_is_rejected(self):
        records = self.changed_event(self.records(), "staging", allocated_bytes=4194305, buffer_capacity=8388608)
        with self.assertRaisesRegex(AssertionError, "exceeds 4 MiB"):
            self.verify(records)

    def test_wrong_row_pitch_and_allocation_offset_are_rejected(self):
        with self.assertRaisesRegex(AssertionError, "row pitch"):
            self.verify(self.changed_event(self.records(), "transfer", row_pitch=9441))
        with self.assertRaisesRegex(AssertionError, "different staging offset"):
            self.verify(self.changed_event(self.records(), "transfer", buffer_offset=4))

    def test_copy_to_another_texture_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "texture identity"):
            self.verify(self.changed_event(self.records(), "transfer", texture_id=20))

    def test_changed_full_quad_uv_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "full UV quad"):
            self.verify(self.changed_event(self.records(), "draw", source_uv=[0, .1, 1, .8]))

    def test_changed_destination_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "quad geometry"):
            self.verify(self.changed_event(self.records(), "draw", destination=[.1, 0, 1, 1]))

    def test_frozen_schema1_and_pixels_remain_exact(self):
        here = Path(__file__).resolve().parent
        frozen_prefix = (here / "verify.py").read_bytes()[:8245]
        self.assertEqual(hashlib.sha256(frozen_prefix).hexdigest(),
                         "3ebc04a65feb3b60830df8783803bc94aa6e094065945833354b35cae27eebe7")
        expected = "9f73c1e974ce85c75dc00659fd2e7a2fae3da32d92da42fa8a8801366ec3d03c"
        self.assertEqual(hashlib.sha256((here / "test_harness.py").read_bytes()).hexdigest(), expected)


if __name__ == "__main__":
    unittest.main(verbosity=2)
