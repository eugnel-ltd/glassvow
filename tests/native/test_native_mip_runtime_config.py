#!/usr/bin/env python3
"""Freeze the hosted probe's required native runtime-test configuration.

Source-only verifier regression: no compiler, engine, display, or GPU runs.
The real old failure is hosted job117733507995, bound in the repair packet.
"""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'mip_runtime_verify', ROOT / 'tools/godot/native_texture_mips/verify.py')
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)

RUNTIME = {'purpose': 'portable_component_proof', 'path_overrides': True,
           'scons_option': 'disable_path_overrides=no',
           'shipping_template_qualification': False}


def manifest():
    contract = json.loads((ROOT / 'tools/godot/native_texture_mips/contract.json').read_text())
    prerequisite = {'role': 'prerequisite', 'path': 'allocator.patch',
                    'sha256': contract['prerequisite_patch_sha256'], 'source_tree_sha256': 'a' * 64}
    production = {'role': 'production', 'path': 'mips.patch',
                  'sha256': contract['production_patch_sha256'], 'source_tree_sha256': 'b' * 64}
    common = {'unmodified_source_tree_sha256': '0' * 64,
              'instrumented_source_tree_sha256': 'c' * 64, 'binary_sha256': 'd' * 64}
    result = {'status': 'pass', 'source_sha': contract['source_pins'][0],
              'source_archive_sha256': 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef',
              'observer_sha256': 'e' * 64, 'patch_sha256': production['sha256'],
              'prerequisite_patches': [{'sha256': prerequisite['sha256']}],
              'flags': ['platform=linuxbsd', 'target=template_debug', 'disable_path_overrides=no'],
              'runtime_test_configuration': copy.deepcopy(RUNTIME),
              'builds': {
                  'baseline': {**common, 'applied_patches': [prerequisite],
                               'pre_observer_source_tree_sha256': 'a' * 64},
                  'candidate': {**common, 'applied_patches': [prerequisite, production],
                                'pre_observer_source_tree_sha256': 'b' * 64}}}
    return result, contract


class RuntimeConfigurationTests(unittest.TestCase):
    def test_explicit_test_configuration_accepts_same_variant_flags(self):
        value, contract = manifest()
        verify.validate_build(value, contract, 'e' * 64, value['patch_sha256'])

    def test_disabled_or_ambiguous_path_overrides_cannot_qualify_probe(self):
        for flags in ([], ['disable_path_overrides=yes'],
                      ['disable_path_overrides=no', 'disable_path_overrides=yes'],
                      ['disable_path_overrides=no', 'disable_path_overrides=no']):
            with self.subTest(flags=flags):
                value, contract = manifest()
                value['flags'] = flags
                with self.assertRaisesRegex(ValueError, 'runtime-test configuration'):
                    verify.validate_build(value, contract, 'e' * 64, value['patch_sha256'])

    def test_missing_or_shipping_qualification_cannot_qualify_probe(self):
        for declaration in (None, {}, {**RUNTIME, 'path_overrides': False},
                            {**RUNTIME, 'shipping_template_qualification': True}):
            with self.subTest(declaration=declaration):
                value, contract = manifest()
                value['runtime_test_configuration'] = declaration
                with self.assertRaisesRegex(ValueError, 'runtime-test configuration'):
                    verify.validate_build(value, contract, 'e' * 64, value['patch_sha256'])


if __name__ == '__main__':
    unittest.main()
