#!/usr/bin/env python3
"""Independent actual-capacity fixtures for the revised RD parser contract."""
import copy
import unittest

from test_schema2 import FullTextureTransferVerifierTests


class FrameCapacityTests(FullTextureTransferVerifierTests):
    # Only these new tests are selected below; the prior 18-test proposal stays
    # frozen separately and its existing cases keep their original semantics.
    def adaptive_records(self):
        records = self.records(pitch_step=256)
        prefix, suffix = copy.deepcopy(records[:2]), copy.deepcopy(records[-3:])
        staging = copy.deepcopy(records[2])
        transfer = copy.deepcopy(records[3])
        capacity, pitch, width, height = 256 * 1024, 9472, 2360, 1640
        max_rows = capacity // pitch
        count = (height + max_rows - 1) // max_rows
        for index in range(count):
            first, end = index * height // count, (index + 1) * height // count
            prefix.append(dict(staging, index=index, request_bytes=pitch * (end - first),
                               allocated_bytes=pitch * (end - first), buffer_capacity=capacity))
            prefix.append(dict(transfer, index=index, y=first, height=end - first,
                               source_offset=first * width * 4, source_bytes=width * (end - first) * 4,
                               staging_index=index))
        suffix[1]["transfers"] = count
        return prefix + suffix

    def test_actual_256k_capacity_rejects_the_original_four_band_proposal(self):
        records = self.records(pitch_step=256)
        for record in records:
            if record["event"] == "staging":
                record["buffer_capacity"] = 256 * 1024
        with self.assertRaisesRegex(AssertionError, "exceeds actual buffer capacity"):
            self.verify(records)

    def test_actual_256k_capacity_accepts_61_balanced_native_transfers(self):
        result = self.verify(self.adaptive_records())
        self.assertEqual(len(result["transfers"]), 61)
        self.assertLessEqual(result["maximum_transfer_or_reservation_bytes"], 256 * 1024)
        self.assertEqual({transfer["height"] for transfer in result["transfers"]}, {26, 27})


if __name__ == "__main__":
    suite = unittest.TestSuite(FrameCapacityTests(name) for name in (
        "test_actual_256k_capacity_rejects_the_original_four_band_proposal",
        "test_actual_256k_capacity_accepts_61_balanced_native_transfers"))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(not result.wasSuccessful())
