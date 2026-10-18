#!/usr/bin/env python3
"""Owned inert-child cleanup and actual wrapper receipt-link controls; no GPU."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location('gv_safety_' + name,
        ROOT / 'tools/godot/native_texture_staging' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class LaunchBoundary(BaseException):
    pass


class CapabilitySafetyTests(unittest.TestCase):
    def test_exited_parent_cannot_leave_owned_pipe_descendant_after_timeout(self):
        helper = load('capability')
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            pid_file = folder / 'owned-child.pid'
            child = 'import time; time.sleep(20)'
            parent = ('import subprocess,sys; from pathlib import Path; '
                'p=subprocess.Popen([sys.executable,"-c",' + repr(child) + ']); '
                'Path(' + repr(str(pid_file)) + ').write_text(str(p.pid))')
            descendant = None
            try:
                result = helper.run_process([sys.executable, '-c', parent], folder,
                    os.environ.copy(), 1.0, 4096)
                self.assertTrue(result['timed_out'])
                descendant = int(pid_file.read_text())
                # A terminated orphan may remain a zombie until the host init
                # reaps it; it must not remain running or sleeping.
                def running():
                    stat = Path('/proc') / str(descendant) / 'stat'
                    if stat.exists():
                        return stat.read_text().rsplit(')', 1)[1].split()[0] != 'Z'
                    try:
                        os.kill(descendant, 0)
                        return True
                    except ProcessLookupError:
                        return False
                deadline = time.monotonic() + 1
                while running() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertFalse(running(),
                    'timed-out owned process group left its pipe descendant alive')
            finally:
                if descendant is not None:
                    try:
                        os.kill(descendant, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_qualified_receipt_reaches_real_wrapper_boundary_and_is_recorded(self):
        helper, probe = load('capability'), load('probe')
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            library, icd, receipt = folder / 'driver.so', folder / 'lvp.json', folder / 'result.json'
            library.write_bytes(b'synthetic-library-not-loaded')
            icd.write_text(json.dumps({'ICD': {'library_path': str(library)}}))
            result = {'schema': 1, 'profile': helper.LINUX, 'status': 'CAPABILITY_SUPPORTED',
                'component_status': 'NOT_RUN', 'errors': [], 'linux_driver': helper.linux_binding(icd, {}),
                'formats': [{'format': name, 'format_id': value, 'usage': 193, 'supported': True}
                            for name, value in helper.FORMATS]}
            receipt.write_text(json.dumps(result))
            output = folder / 'evidence'
            with patch.dict(os.environ, {'GLASSVOW_STAGING_CAPABILITY_RECEIPT': str(receipt)}), \
                    patch.object(probe.Path, 'glob', return_value=[icd]), \
                    patch.object(probe.subprocess, 'Popen', side_effect=LaunchBoundary):
                with self.assertRaises(LaunchBoundary):
                    probe.run(folder / 'unexecuted-native', output)
            metadata = json.loads((output / 'command.json').read_text())
            self.assertIn('stock_capability_binding', metadata,
                'qualified stock receipt was omitted from actual wrapper command metadata')
            self.assertTrue(metadata['stock_capability_binding']['resource_screen_only'])
            self.assertEqual(metadata['stock_capability_binding']['driver'], result['linux_driver'])

    def test_backend_link_and_ambiguous_driver_controls(self):
        helper = load('capability')
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            receipt, icd = folder / 'result.json', folder / 'lvp.json'
            receipt.write_text(json.dumps({'device': {'vendor': 'Unknown', 'name': 'synthetic GPU'}}))
            startup = 'Vulkan 1.4.318 - Forward Mobile - Using Device #0: Unknown - synthetic GPU\n'
            self.assertEqual(helper.verify_native_backend(receipt, startup), startup.strip())
            for wrong in [startup.replace('synthetic GPU', 'different GPU'), startup + startup,
                          startup + 'OpenGL API 4.5 - Compatibility\n', '']:
                with self.assertRaises(ValueError):
                    helper.verify_native_backend(receipt, wrong)
            icd.write_text(json.dumps({'ICD': {'library_path': 'bare-driver.so'}}))
            with self.assertRaises(ValueError):
                helper.linux_binding(icd, {})
            icd.write_text('{}')
            with self.assertRaises(ValueError):
                helper.linux_binding(icd, {})


if __name__ == '__main__':
    unittest.main(verbosity=2)
