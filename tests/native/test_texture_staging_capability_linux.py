#!/usr/bin/env python3
"""Synthetic Linux venue/source-identity refusals, never driver/GPU evidence."""
import json
from pathlib import Path
import tempfile
import unittest

import test_texture_staging_capability as contract


class LinuxCapabilityTests(unittest.TestCase):
    def test_software_profile_refuses_a_different_actual_vulkan_device(self):
        text = contract.log('linux-x86_64-lavapipe-v1').replace(
            'llvmpipe (synthetic)', 'Different physical GPU')
        result = contract.capability.assess('linux-x86_64-lavapipe-v1',
            contract.LINUX, contract.VERSION, text, 0)
        self.assertEqual(result['status'], 'INCONCLUSIVE',
            'software-driver profile accepted another actual Vulkan device')

    def test_production_receipt_requires_exact_source_query_version_and_host_boot(self):
        helper = contract.capability
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            library, icd, receipt = root / 'driver.so', root / 'lvp.json', root / 'result.json'
            library.write_bytes(b'synthetic-driver-not-loaded')
            icd.write_text(json.dumps({'ICD': {'library_path': str(library)}}))
            data = helper.assess(helper.LINUX, contract.LINUX, contract.VERSION,
                contract.log(helper.LINUX), 0)
            data.update(head='a' * 40, version=contract.VERSION,
                query_source_sha256=helper.QUERY_SHA256, linux_driver=helper.linux_binding(icd, {}))
            env = {'GLASSVOW_STAGING_SOURCE_HEAD': 'a' * 40}
            receipt.write_text(json.dumps(data))
            helper.verify_linux_binding(receipt, icd, env)
            for key, wrong in [('head', 'b' * 40), ('version', 'custom_build'),
                               ('query_source_sha256', '0' * 64),
                               ('linux_driver', dict(data['linux_driver'], host_boot_sha256='0' * 64))]:
                receipt.write_text(json.dumps(dict(data, **{key: wrong})))
                with self.assertRaises(ValueError):
                    helper.verify_linux_binding(receipt, icd, env)


if __name__ == '__main__':
    unittest.main(verbosity=2)
