#!/usr/bin/env python3
"""Nearest-sampling boundary controls; these do not claim native/GPU proof."""
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/godot/native_boot_upload'))
from verify import BACKGROUND, source_reference, verify_pixels


class NativeBootSourceOracleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self, alpha=False):
        x, y = np.meshgrid(np.arange(18), np.arange(14))
        channels = [(64 + (x * 17 + y * 11) % 180).astype(np.uint8),
                    (64 + (x * 7 + y * 19) % 180).astype(np.uint8),
                    (64 + (x * 13 + y * 3) % 180).astype(np.uint8)]
        if alpha:
            channels.append(np.array([64, 128, 192, 255], dtype=np.uint8)[(x + y) % 4])
        source = self.root / ('rgba.png' if alpha else 'rgb.png')
        Image.fromarray(np.stack(channels, axis=2)).save(source)
        case = {'source': str(source), 'size': [17, 13], 'filter': False, 'stretch': 5}
        # Exact rational centres for 18->17 and 14->13. Only the centre
        # column/row are integer boundaries: qx=9 and qy=7 respectively.
        xi = np.array([0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17])
        yi = np.array([0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13])
        rgba = np.asarray(Image.open(source).convert('RGBA'), dtype=float)

        def frame(left=False, upper=False):
            columns, rows = xi.copy(), yi.copy()
            if left:
                columns[8] = 8
            if upper:
                rows[6] = 6
            sampled = rgba[rows[:, None], columns[None, :]]
            opacity = sampled[:, :, 3:4] / 255
            return np.rint(sampled[:, :, :3] * opacity + np.asarray(BACKGROUND) * (1 - opacity)).astype(np.uint8)
        return case, frame

    def verify(self, pixels, case, other=None):
        before, after = self.root / 'before.png', self.root / 'after.png'
        Image.fromarray(pixels).save(before)
        Image.fromarray(pixels if other is None else other).save(after)
        return verify_pixels(before, after, case, 'gles3')

    def test_exact_boundary_allows_whole_adjacent_rgb_sample(self):
        case, frame = self.fixture()
        self.assertTrue(self.verify(frame(left=True), case)['pair_exact'])

    def test_two_exact_boundaries_preserve_rgba_blending(self):
        case, frame = self.fixture(alpha=True)
        self.assertTrue(self.verify(frame(left=True, upper=True), case)['pair_exact'])

    def test_nonboundary_adjacent_texel_is_rejected(self):
        case, frame = self.fixture()
        pixels = frame()
        pixels[4, 3] = pixels[4, 2]
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(pixels, case)

    def test_exact_boundary_cannot_accept_arbitrary_colour(self):
        case, frame = self.fixture()
        pixels = frame(left=True)
        pixels[4, 8] = (0, 0, 0)
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(pixels, case)

    def test_boundary_cannot_mix_channels_from_different_samples(self):
        case, frame = self.fixture()
        pixels, adjacent = frame(), frame(left=True)
        pixels[4, 8, 0] = adjacent[4, 8, 0]
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(pixels, case)

    def test_wrong_filter_is_rejected(self):
        case, frame = self.fixture()
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(frame(), dict(case, filter=True))

    def test_matching_shift_is_rejected(self):
        case, frame = self.fixture()
        with self.assertRaises(AssertionError):
            self.verify(np.roll(frame(), 1, axis=1), case)

    def test_matching_flip_is_rejected(self):
        case, frame = self.fixture()
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(frame()[::-1], case)

    def test_matching_blank_is_rejected(self):
        case, _ = self.fixture()
        with self.assertRaisesRegex(AssertionError, 'blank'):
            self.verify(np.full((13, 17, 3), BACKGROUND, dtype=np.uint8), case)

    def test_exact_pair_threshold_is_unchanged_at_boundary(self):
        case, frame = self.fixture()
        before, after = frame(), frame()
        after[4, 8, 0] += 1
        with self.assertRaisesRegex(AssertionError, 'pixels differ'):
            self.verify(before, case, other=after)

    def test_linear_reference_keeps_the_two_channel_threshold(self):
        case, _ = self.fixture()
        case['filter'] = True
        pixels = source_reference(case, 'gles3')
        self.verify(pixels, case)
        pixels[4, 8, 0] += 3
        with self.assertRaisesRegex(AssertionError, 'source oracle'):
            self.verify(pixels, case)


if __name__ == '__main__':
    unittest.main(verbosity=2)
