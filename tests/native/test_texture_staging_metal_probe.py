#!/usr/bin/env python3
"""Interception controls for the real Mac probe setup; no binary is executed."""
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import test_texture_staging_metal as contract
from metal_staging_fixtures import graph


class MetalProbeTests(unittest.TestCase):
    def exercise(self, changed_device=False):
        metal = contract.load('metal')
        self.assertIsNotNone(metal, 'direct Metal probe and native identity binding are missing')
        script = contract.load('probe').SCRIPT
        calls = []
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary, receipt, output = root / 'unexecuted-native', root / 'venue.json', root / 'proof'
            binary.write_bytes(b'synthetic-native-never-executed')
            receipt.write_text(json.dumps(contract.venue()))

            def intercepted(command, cwd, env, seconds, **_kwargs):
                calls.append(command)
                record = dict(command=command, pid=12345, exit=0, timed_out=False,
                    output_limit=False, reaped=True)
                if '--version' in command:
                    return dict(record, output='4.7.2.stable.custom_build\n')
                self.assertEqual(command[0], str(binary))
                self.assertEqual(command[command.index('--display-driver') + 1], 'macos')
                self.assertEqual(command[command.index('--rendering-driver') + 1], 'metal')
                self.assertNotIn('--headless', command)
                self.assertNotIn('xvfb-run', command)
                self.assertFalse(env.get('VK_DRIVER_FILES'))
                project = Path(command[command.index('--path') + 1])
                source = Path(command[command.index('--script') + 1])
                config = (project / 'project.godot').read_text()
                match = re.search(r'config/custom_user_dir_name="([^"]+)"', config)
                self.assertIsNotNone(match, 'XDG alone does not isolate macOS userdata')
                self.assertIn('config/use_custom_user_dir=true', config)
                self.assertEqual((project / '.godot/global_script_class_cache.cfg').read_text(), 'list=[]\n')
                for suffix in ['DATA', 'CACHE', 'CONFIG', 'STATE']:
                    self.assertTrue(Path(env['XDG_' + suffix + '_HOME']).is_relative_to(output))
                if source.read_text() == script:
                    self.assertFalse(changed_device, 'mismatched native device reached the unchanged upload script')
                    return dict(record, output=graph('candidate'))
                self.assertEqual(source.read_text(), metal.capability.SCRIPT)
                data = contract.venue()
                device = dict(data['device'], user_data_dir='/synthetic/private/' + match[1],
                    engine=dict(major=4, minor=7, patch=2, status='stable', build='custom_build'))
                startup = data['backend_startup']
                if changed_device:
                    device['name'] = 'Different synthetic GPU'
                    startup = startup.replace('Apple Synthetic Test GPU', device['name'])
                text = '\n'.join([startup, 'GV_TEXTURE_CAPABILITY_DEVICE ' + json.dumps(device),
                    *['GV_TEXTURE_CAPABILITY_FORMAT ' + json.dumps(row) for row in data['formats']],
                    'GV_TEXTURE_CAPABILITY_DONE 6', ''])
                return dict(record, output=text)

            with patch.object(metal.capability, 'mac_host_binding', return_value=contract.HOST), \
                    patch.object(metal.capability, 'run_process', side_effect=intercepted):
                if changed_device:
                    with self.assertRaises(ValueError):
                        metal.run_probe(binary, output, receipt, contract.HEAD, script)
                    self.assertEqual(len(calls), 2)
                else:
                    metal.run_probe(binary, output, receipt, contract.HEAD, script)
                    self.assertEqual(len(calls), 3)
                    data = json.loads((output / 'command.json').read_text())
                    self.assertEqual(data['profile'], contract.MAC)
                    self.assertEqual(data['binary_sha256'], hashlib.sha256(binary.read_bytes()).hexdigest())
                    self.assertEqual(data['script_sha256'], hashlib.sha256(script.encode()).hexdigest())
                    self.assertEqual(data['host_binding'], contract.HOST)
                    self.assertEqual(data['native_exit'], 0)
                    self.assertEqual(data['native_profile']['device']['name'], 'Apple Synthetic Test GPU')

    def test_native_identity_and_userdata_precede_the_frozen_real_upload_script(self):
        self.exercise()

    def test_changed_native_device_stops_before_upload_not_after_a_fake_pass(self):
        self.exercise(changed_device=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
