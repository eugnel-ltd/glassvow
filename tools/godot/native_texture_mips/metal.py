#!/usr/bin/env python3
"""Thin Vigil delivery controller using the maintained shared Metal venue/pair.

Native execution belongs to the maintained hosted component job. Source tests
mock that boundary; desktop Metal is never iOS/A12 or template qualification.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_shared():
    directory = HERE.parent / 'native_texture_staging'
    boot = HERE.parent / 'native_boot_upload'
    sys.path.insert(0, str(boot))
    return (load('gv_vigil_mac_pair', directory / 'mac_builder.py'),
            load('gv_vigil_metal_support', directory / 'metal.py'),
            load('gv_vigil_portable_helpers', boot / 'build.py'))


def inputs():
    contract = json.loads((HERE / 'metal-contract.json').read_text())
    original = json.loads((HERE / 'contract.json').read_text())
    for path, expected in contract['protected_files'].items():
        require(digest(ROOT / path) == expected, 'protected original differs: ' + path)
    require(digest(ROOT / 'tests/native/test_native_mip_metal.py') ==
            contract['first_metal_fixture_sha256'], 'first Metal regression differs')
    probe = load('gv_vigil_frozen_metal_probe', HERE / 'probe.py')
    require(hashlib.sha256(probe.SCRIPT.encode()).hexdigest() ==
            contract['embedded_probe_script_sha256'], 'frozen probe SCRIPT differs')
    shared_paths = ['native_texture_staging/mac_builder.py', 'native_texture_staging/metal.py',
                    'native_texture_staging/capability.py', 'native_boot_upload/build.py',
                    'native_boot_upload/processes.py']
    identity = {'contract_sha256': digest(HERE / 'metal-contract.json'),
        'original_contract_sha256': digest(HERE / 'contract.json'),
        'observer_sha256': digest(HERE / 'metal_observer.py'),
        'protected_files': contract['protected_files'],
        'shared_helper_sha256': {path: digest(HERE.parent / path) for path in shared_paths},
        'script_sha256': {variant: hashlib.sha256(probe.script_for(variant).encode()).hexdigest()
                          for variant in ('baseline', 'candidate')}}
    return contract, original, probe, identity


def validate_build(build, contract, original, identity):
    require(build.get('status') == 'pass', 'paired compiler proof missing')
    require(build.get('profile') == contract['profile'] and build.get('source_sha') == original['source_pins'][0]
            and build.get('source_archive_sha256') ==
                'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef',
            'Mac compiler source/profile differs')
    require(build.get('observer_sha256') == identity['observer_sha256'], 'Mac observer differs')
    require(build.get('patch_sha256') == original['production_patch_sha256'], 'Vigil production patch differs')
    require([item.get('sha256') for item in build.get('prerequisite_patches', [])] ==
            [original['prerequisite_patch_sha256']], 'baseline must have only the allocator prerequisite')
    require(build.get('runtime_test_configuration') == {
        'purpose': 'desktop_metal_component_proof', 'path_overrides': True,
        'scons_option': 'disable_path_overrides=no', 'shipping_template_qualification': False},
        'desktop runtime-test configuration differs')
    require(set(build.get('builds', {})) == {'baseline', 'candidate'}, 'paired compiler variants missing')
    baseline, candidate = (build['builds'][variant] for variant in ('baseline', 'candidate'))
    before, after = baseline['applied_patches'], candidate['applied_patches']
    require(len(before) == 1 and len(after) == 2 and before == after[:1]
            and before[0]['sha256'] == original['prerequisite_patch_sha256']
            and after[1]['sha256'] == original['production_patch_sha256'], 'ordered allocator-only baseline differs')
    require(baseline['unmodified_source_tree_sha256'] == candidate['unmodified_source_tree_sha256'],
            'fresh source trees differ')
    for variant, item in build['builds'].items():
        observed = item['observer_receipt']
        require(observed['variant'] == variant and observed['profile'] == contract['profile']
                and observed['observer_sha256'] == identity['observer_sha256']
                and observed['original_observer_sha256'] ==
                    contract['protected_files']['tools/godot/native_texture_mips/observer.py'],
                'actual Metal observer receipt differs')
        require(observed['source_before_sha256'] == original[
            'allocator_baseline_rd_sha256' if variant == 'baseline' else 'candidate_rd_sha256'],
            'actual observed production source differs')
        require(observed['source_after_sha256'] == contract['instrumented_rd_sha256'][variant]
                and observed['metal_sources'] == contract['metal_sources'], 'actual Metal source hooks differ')
        for field in ('unmodified_source_tree_sha256', 'pre_observer_source_tree_sha256',
                      'instrumented_source_tree_sha256', 'binary_sha256'):
            require(isinstance(item.get(field), str) and len(item[field]) == 64, 'compiler identity missing')


def run(args):
    contract, original, probe, identity = inputs()
    require(digest(args.prerequisite_patch) == original['prerequisite_patch_sha256'],
            'allocator prerequisite bytes differ')
    builder, support, shared = load_shared()
    support.verify_venue(args.venue_receipt, args.head)
    build_args = argparse.Namespace(profile=contract['profile'], head=args.head,
        venue_receipt=args.venue_receipt, baseline_patches=[args.prerequisite_patch],
        patch=HERE.parent / 'patches/glassvow-660-bounded-mip-upload.patch',
        observer=HERE / 'metal_observer.py', work=args.work, output=args.output,
        source_archive=args.source_archive, source_archive_sha256=support.ARCHIVE)
    status = {'status': 'running', 'head': args.head, 'scope': 'desktop Metal component only'}
    try:
        builder.build(build_args, shared)
        build = support.read_json(args.output / 'build-manifest.json')
        validate_build(build, contract, original, identity)
        require(build.get('flags') == support.FLAGS and build.get('source_head') == args.head,
                'Mac compiler flags/head differ')
        commands, observations = {}, {}
        verify = load('gv_vigil_metal_verify', HERE / 'verify.py')
        for variant in ('baseline', 'candidate'):
            directory = args.output / (variant + '-rd')
            commands[variant] = support.run_probe(Path(build['builds'][variant]['binary']),
                directory, args.venue_receipt, args.head, probe.script_for(variant))
            require(commands[variant] == support.read_json(directory / 'command.json'), 'saved process receipt differs')
            require(commands[variant]['script_sha256'] == identity['script_sha256'][variant], 'variant SCRIPT differs')
            log = directory / 'native.log'
            require(log.is_file() and not log.is_symlink() and log.stat().st_size <= 1048576,
                    'bounded actual native log missing')
            records = [item for item in commands[variant]['commands'] if item.get('log') == 'native.log']
            require(len(records) == 1 and records[0].get('log_sha256') == digest(log),
                    'actual component log differs from process receipt')
            observations[variant] = verify.inspect_metal(log.read_text(), variant)
        provenance = support.verify_provenance(build, commands, args.venue_receipt, args.head,
                                               expected_scripts=identity['script_sha256'])
        require(inputs()[3] == identity, 'component/helper inputs changed during execution')
        proof = verify.compare_metal(observations['baseline'], observations['candidate'])
        proof.update(head=args.head, provenance=provenance,
            build_manifest_sha256=digest(args.output / 'build-manifest.json'), component_inputs=identity)
        shared.write_json(args.output / 'actual-rd-proof.json', proof)
        status['status'] = proof['status']
        return 0 if proof['status'] == 'PASS' else 2
    except BaseException as error:
        status.update(status='failed_or_inconclusive', error=type(error).__name__ + ': ' + str(error))
        raise
    finally:
        if args.output.is_dir():
            shared.write_json(args.output / 'component-inputs.json', identity)
            shared.write_json(args.output / 'component-run.json', status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True)
    parser.add_argument('--venue-receipt', type=Path, required=True)
    parser.add_argument('--prerequisite-patch', type=Path, required=True)
    parser.add_argument('--source-archive', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    return run(parser.parse_args())


if __name__ == '__main__':
    raise SystemExit(main())
