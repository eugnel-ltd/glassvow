#!/usr/bin/env python3
"""Delivery wiring controls only; no engine, download or native build."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/native-texture-mips.yml'


def mac_job():
    text = WORKFLOW.read_text()
    found = re.search(r'(?ms)^  paired-macos-metal-mips:\n(.*?)(?=^  [a-z][a-z0-9-]*:\n|\Z)', text)
    if found is None:
        raise AssertionError('maintained Vigil paired Mac job is absent')
    return found.group(1)


class MetalWorkflowTests(unittest.TestCase):
    def test_maintained_mac_job_screens_before_the_actual_vigil_pair(self):
        job = mac_job()
        self.assertIn('runs-on: macos-15', job)
        self.assertIn('actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065', job)
        self.assertIn("python-version: '3.12'", job)
        self.assertIn('architecture: arm64', job)
        self.assertLess(job.index('capability.py \\'), job.index('native_texture_mips/metal.py \\'))
        self.assertIn('--head "$VIGIL_HEAD"', job)
        self.assertIn('--venue-receipt "$RUNNER_TEMP/native-mips-metal-evidence/venue/result.json"', job)
        self.assertIn('--source-archive "$RUNNER_TEMP/native-mips-metal-source/upstream.tar.gz"', job)
        self.assertNotIn('--headless', job)
        self.assertNotIn('xvfb-run', job)

    def test_trigger_includes_every_owned_metal_control_and_shared_input(self):
        triggers = WORKFLOW.read_text().split('\njobs:', 1)[0]
        for name in ('test_native_mip_metal.py', 'test_native_mip_metal_delivery.py',
                     'test_native_mip_metal_controller.py', 'test_native_mip_metal_workflow.py'):
            with self.subTest(name=name): self.assertIn('tests/native/' + name, triggers)
        self.assertIn('tools/godot/native_texture_staging/**', triggers)
        self.assertIn('tools/godot/native_boot_upload/verify.py', triggers)

    def test_exact_sparse_sources_and_transitive_preflight_are_declared(self):
        job = mac_job()
        for pin in ('1aebd36a47ceee6d5d74328b79b852d1e0eb95db', 'a08e1ab8f9b5e1c8c0dd3e8c450db839f0a5acb6'):
            self.assertIn('ref: ' + pin, job)
        for path in ('/.github/workflows/native-texture-mips.yml', '/tests/native/',
                     '/tools/godot/native_texture_mips/', '/tools/godot/native_boot_upload/',
                     '/tools/godot/native_texture_staging/',
                     '/tools/godot/patches/glassvow-660-compressed-upload-staging.patch'):
            self.assertIn(path, job)
        self.assertIn('controller.inputs(', job)
        self.assertIn('controller.load_shared(', job)
        self.assertIn("-p 'test_*mip*.py'", job)
        self.assertIn('shared-runtime-head.txt', job)
        self.assertIn('shared-builder-head.txt', job)


if __name__ == '__main__':
    unittest.main()
