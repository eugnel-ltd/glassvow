#!/usr/bin/env python3
"""Fail-closed adapter composition; no engine or GPU is represented here."""
import unittest
from unittest.mock import patch

import test_texture_staging_metal as contract


class MetalObserverTests(unittest.TestCase):
    def test_request_traits_do_not_match_the_more_indented_copy_guard(self):
        adapter = contract.load('metal_observer')
        # These two guards actually coexist in the original observer output.
        source = ('\t\t\t\tif (gv_staging_forced) {\n\t\t\t\t\tpitch_step = MAX(pitch_step, 256u);\n\t\t\t\t}\n'
            'gv_staging_forced ? MAX(uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), 256u) : uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP))\n'
            '\t\t\tif (!gv_staging_case.is_empty()) {\n'
            '\t\t\t\tprint_line(vformat("GV_STAGING_REQUEST representative"));\n\t\t\t}\n'
            '\t\t\t\t\tif (!gv_staging_case.is_empty()) {\n'
            '\t\t\t\t\t\tprint_line(vformat("GV_STAGING_COPY representative"));\n\t\t\t\t\t}\n'
            'required_align = MAX(required_align, 512u);\n')
        with patch.object(adapter.observer, 'instrument', return_value=source):
            actual = adapter.instrument('uninstrumented input owned by original observer')
        self.assertEqual(actual.count('GV_STAGING_METAL_TRAITS '), 1)
        self.assertLess(actual.index('GV_STAGING_METAL_TRAITS '), actual.index('GV_STAGING_REQUEST '))
        self.assertNotIn('pitch_step = MAX(pitch_step, 256u)', actual)
        self.assertIn('required_align = MAX(required_align, 512u);', actual)
        self.assertIn('GV_STAGING_COPY representative', actual)
        with patch.object(adapter.observer, 'instrument', return_value=source.replace('GV_STAGING_REQUEST', 'WRONG')):
            # Exact request-site binding must reject a source that only has a copy guard.
            with self.assertRaises(ValueError):
                adapter.instrument('unknown output')


if __name__ == '__main__':
    unittest.main(verbosity=2)
