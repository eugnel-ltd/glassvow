#!/usr/bin/env python3
"""Compose the pinned shared hosted builder with this independent RD proof.

Run only on the selected public compiler/render host, never in a live game
worktree. This command builds two engines; it is not a cheap local self-test.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

SOURCE = 'ed1daf0bf001b61586d9930840f2f1394092c079'
ARCHIVE_SHA = 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef'
RD_SOURCE_SHA = 'cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62'
MAC = 'macos-arm64-metal-v1'
LINUX = 'linux-x86_64-lavapipe-v1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args):
    profile = getattr(args, 'profile', LINUX)
    require(profile in (LINUX, MAC), 'unknown native component profile')
    metal = None
    if profile == MAC:
        # Qualify the same live host/job before any source download or compile.
        spec = importlib.util.spec_from_file_location('gv_staging_metal', Path(__file__).with_name('metal.py'))
        metal = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(metal)
        metal.verify_venue(args.venue_receipt, args.head)
    for name in ['work', 'output', 'builder', 'builder_manifest']:
        setattr(args, name, getattr(args, name).resolve())
    if args.source_archive is not None:
        args.source_archive = args.source_archive.resolve()
    require(not args.output.exists() and not args.work.exists(), 'proof/build directories must be new')
    args.output.mkdir(parents=True)
    args.work.mkdir(parents=True)
    here = Path(__file__).resolve().parent
    repo = here.parents[2]
    fixture = repo / 'tests/native/test_texture_upload_staging.py'
    patch = repo / 'tools/godot/patches/glassvow-660-compressed-upload-staging.patch'
    expected = json.loads(args.builder_manifest.read_text())
    require(set(expected) == {'build.py', 'verify.py', 'processes.py'}, 'unexpected shared builder manifest')
    for name, checksum in expected.items():
        require(digest(args.builder.parent / name) == checksum, 'shared builder dependency changed: ' + name)
    # Keep the shared builder's imports with its exact helper directory; our
    # verifier is loaded below under a distinct module name.
    sys.path.insert(0, str(args.builder.parent.resolve()))
    builder = load('gv_shared_native_builder', args.builder.resolve())
    require(builder.SOURCE_SHA == SOURCE and builder.SOURCE_ARCHIVE_SHA256 == ARCHIVE_SHA,
            'shared source pin differs from this accepted component contract')
    require(builder.FLAGS.count('disable_path_overrides=no') == 1,
            'portable --path/--script probes require explicit runtime-test path overrides')
    archive = args.source_archive
    if archive is None:
        archive = args.work / 'upstream.tar.gz'
        builder.download(archive)
    require(digest(archive) == ARCHIVE_SHA, 'source archive differs from sealed public source')
    rel = Path('servers/rendering/rendering_device.cpp')
    with tarfile.open(archive) as upstream:
        member = upstream.getmember('godot-' + SOURCE + '/' + rel.as_posix())
        require(member.isfile() and member.size < 1024 * 1024, 'unexpected native source member')
        source = upstream.extractfile(member).read()
    require(hashlib.sha256(source).hexdigest() == RD_SOURCE_SHA, 'native first-test source differs')
    report = {'status': 'running', 'source_commit': SOURCE, 'source_archive_sha256': ARCHIVE_SHA,
              'shared_builder_inputs': expected, 'fixture_sha256': digest(fixture),
              'production_patch_sha256': digest(patch), 'cpu': {}}
    report_path = args.output / 'component-result.json'
    try:
        for variant in ['baseline', 'candidate']:
            target = args.work / ('cpu-' + variant)
            path = target / rel
            path.parent.mkdir(parents=True)
            path.write_bytes(source)
            if variant == 'candidate':
                subprocess.run(['patch', '-f', '-N', '-F', '0', '-p1', '-i', str(patch)],
                               cwd=target, check=True, timeout=15)
            result_dir = args.output / ('cpu-' + variant)
            command = [sys.executable, str(fixture), '--source', str(path), '--build-dir', str(result_dir)]
            returncode = 0
            try:
                builder.run(command, args.work, args.output / (variant + '-cpu.log'), 100)
            except subprocess.CalledProcessError as error:
                returncode = error.returncode
            receipt = json.loads((result_dir / 'result.json').read_text())
            expected_exit = 1 if variant == 'baseline' else 0
            native_log = (result_dir / 'native.log').read_text()
            counts = re.search(r'Native reservation/copy checks=(\d+) failures=(\d+)', native_log)
            require(returncode == expected_exit and receipt['compile_exit'] == 0
                    and receipt['native_exit'] == expected_exit,
                    'native first regression did not produce genuine old-red/new-green')
            require(counts and int(counts[1]) > 0 and
                    (0 < int(counts[2]) < int(counts[1]) if variant == 'baseline' else int(counts[2]) == 0)
                    and 'AddressSanitizer' not in native_log and 'runtime error:' not in native_log,
                    'native first regression was incomplete or failed instrumentation/sanitizer')
            report['cpu'][variant] = receipt
        # The shared builder owns bounded process-group compiler cleanup. Its
        # optional doctest suite is explicitly absent; our immutable native CPU
        # fixture and the actual RD probe are the selected component proof.
        build_args = argparse.Namespace(patch=patch, observer=here / 'observer.py',
            test_suite='', splash=None, work=args.work / 'engines',
            output=args.output / 'build', source_archive=archive,
            source_archive_sha256=ARCHIVE_SHA)
        if metal:
            build_args.profile, build_args.head, build_args.venue_receipt = profile, args.head, args.venue_receipt
            build_args.baseline_patches, build_args.observer = [], here / 'metal_observer.py'
            load('gv_staging_mac_builder', here / 'mac_builder.py').build(build_args, builder)
        else:
            builder.build(build_args)
        inputs = json.loads((args.output / 'build/render-inputs.json').read_text())
        probe = load('gv_staging_probe', here / 'probe.py')
        commands = {}
        for variant in ['baseline', 'candidate']:
            if metal:
                commands[variant] = metal.run_probe(Path(inputs[variant]), args.output / ('rd-' + variant),
                    args.venue_receipt, args.head, probe.SCRIPT)
            else:
                probe.run(Path(inputs[variant]), args.output / ('rd-' + variant))
        verifier = load('gv_staging_verifier', here / 'verify.py')
        kwargs = {'profile': profile} if metal else {}
        native = verifier.compare(
            verifier.inspect(args.output / 'rd-baseline/native.log', 'baseline', **kwargs),
            verifier.inspect(args.output / 'rd-candidate/native.log', 'candidate', **kwargs), **kwargs)
        if metal:
            build = metal.read_json(args.output / 'build/build-manifest.json')
            native['provenance'] = metal.verify_provenance(build, commands, args.venue_receipt, args.head)
            require(build['source_head'] == args.head and build['patch_sha256'] == digest(patch)
                    and build['observer_sha256'] == digest(here / 'metal_observer.py')
                    and build['prerequisite_patches'] == [], 'allocator production/observer inputs differ')
            for variant in ['baseline', 'candidate']:
                item, command = build['builds'][variant], commands[variant]
                require(item['query_source_sha256'] == metal.capability.QUERY_SHA256
                        and item['observer_receipt']['observer_sha256'] == digest(here / 'observer.py')
                        and item['observer_receipt']['adapter_sha256'] == digest(here / 'metal_observer.py')
                        and item['observer_receipt']['variant'] == variant,
                        'actual native query/observer source binding differs')
                require(item['applied_patches'] == ([{'name': patch.name, 'sha256': digest(patch)}]
                        if variant == 'candidate' else []), 'allocator patch order differs')
                require(command['script_sha256'] == hashlib.sha256(probe.SCRIPT.encode()).hexdigest()
                        and command['commands'][-1]['log_sha256'] == native[variant]['log_sha256'],
                        'verified native log/script differs from the owned child')
        (args.output / 'native-rd-result.json').write_text(json.dumps(native, indent=2) + '\n')
        report['status'] = 'PASS'
        report['actual_rd_cases_per_variant'] = len(native['candidate']['cases'])
        report['profile'] = profile
        report['scope'] = native['scope']
    except BaseException as error:
        report['status'] = 'failed_or_inconclusive'
        report['error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--builder', type=Path, required=True)
    parser.add_argument('--builder-manifest', type=Path, required=True)
    parser.add_argument('--source-archive', type=Path)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--profile', choices=[LINUX, MAC], default=LINUX)
    parser.add_argument('--head')
    parser.add_argument('--venue-receipt', type=Path)
    run(parser.parse_args())


if __name__ == '__main__':
    main()
