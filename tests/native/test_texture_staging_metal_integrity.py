#!/usr/bin/env python3
"""Profile replays and backend overrides: synthetic controls, never GPU proof."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import test_texture_staging_metal as contract


class MetalIntegrityTests(unittest.TestCase):
    def test_native_metal_target_override_cannot_reuse_a_stock_host_identity(self):
        capability = contract.load('capability')
        record = dict(exit=0, reaped=True, timed_out=False, output_limit=False,
                      output='{ sec = 1234, usec = 5 }\n')
        with patch.object(capability.platform, 'system', return_value='Darwin'), \
                patch.object(capability.platform, 'machine', return_value='arm64'), \
                patch.object(capability.os, 'uname', return_value=SimpleNamespace(machine='arm64', nodename='synthetic')), \
                patch.object(capability, 'run_process', return_value=record), \
                patch.dict(os.environ, {}, clear=True):
            self.assertEqual(capability.mac_host_binding()['machine'], 'arm64')
            with patch.dict(os.environ, {'GODOT_MTL_TARGET_VERSION': '3.1'}):
                with self.assertRaises(ValueError):
                    capability.mac_host_binding()

    def test_distinct_variant_scripts_require_exact_explicit_hashes(self):
        metal = contract.load('metal')
        with tempfile.TemporaryDirectory() as temporary:
            receipt = Path(temporary) / 'venue.json'
            receipt.write_text(json.dumps(contract.venue()))
            venue_sha = hashlib.sha256(receipt.read_bytes()).hexdigest()
            build = dict(status='pass', profile=contract.MAC, source_sha=metal.SOURCE,
                source_archive_sha256=metal.ARCHIVE, flags=metal.FLAGS, host_binding=contract.HOST,
                venue_receipt_sha256=venue_sha, builds={})
            commands, expected = {}, {}
            for index, variant in enumerate(('baseline', 'candidate')):
                script = hashlib.sha256(('independent-frozen-script-' + variant).encode()).hexdigest()
                expected[variant] = script
                build['builds'][variant] = dict(binary_sha256=str(index) * 64, version='4.7.2.stable.custom_build',
                    architecture='arm64', unmodified_source_tree_sha256='a' * 64)
                commands[variant] = dict(status='pass', profile=contract.MAC, source_head=contract.HEAD,
                    host_binding=contract.HOST, native_exit=0, profile_exit=0, venue_receipt_sha256=venue_sha,
                    binary_sha256=str(index) * 64, version='4.7.2.stable.custom_build',
                    native_profile=dict(status='CAPABILITY_SUPPORTED', component_status='NOT_RUN',
                        device=contract.venue()['device']), cache_sha256=hashlib.sha256(b'list=[]\n').hexdigest(),
                    script_sha256=script, user_dir='independent-' + variant)
            with patch.object(metal.capability, 'mac_host_binding', return_value=contract.HOST):
                with self.assertRaises(ValueError):
                    metal.verify_provenance(build, commands, receipt, contract.HEAD)
                result = metal.verify_provenance(build, commands, receipt, contract.HEAD, expected_scripts=expected)
                self.assertFalse(result['shipping_template_qualification'])
                broken = copy.deepcopy(commands)
                broken['candidate']['script_sha256'] = expected['baseline']
                with self.assertRaises(ValueError):
                    metal.verify_provenance(build, broken, receipt, contract.HEAD, expected_scripts=expected)
                broken = copy.deepcopy(commands)
                broken['candidate']['host_binding'] = dict(contract.HOST, boot_sha256='b' * 64)
                with self.assertRaises(ValueError):
                    metal.verify_provenance(build, broken, receipt, contract.HEAD, expected_scripts=expected)

    def test_summary_does_not_follow_evidence_symlinks(self):
        diagnostics = contract.load('diagnostics')
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            outside = root / 'outside'
            outside.mkdir()
            (outside / 'result.json').write_text(json.dumps(contract.venue()))
            evidence = root / 'evidence'
            evidence.mkdir()
            (evidence / 'venue').symlink_to(outside, target_is_directory=True)
            stream = io.StringIO()
            diagnostics.emit_summary(evidence, stream)
            self.assertNotIn('Apple Synthetic Test GPU', stream.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=2)
