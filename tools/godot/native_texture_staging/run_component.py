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
                subprocess.run(['patch', '--batch', '--fuzz=0', '-p1', '--input', str(patch)],
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
        builder.build(argparse.Namespace(patch=patch, observer=here / 'observer.py',
            test_suite='', splash=None, work=args.work / 'engines',
            output=args.output / 'build', source_archive=archive,
            source_archive_sha256=ARCHIVE_SHA))
        inputs = json.loads((args.output / 'build/render-inputs.json').read_text())
        probe = load('gv_staging_probe', here / 'probe.py')
        for variant in ['baseline', 'candidate']:
            probe.run(Path(inputs[variant]), args.output / ('rd-' + variant))
        verifier = load('gv_staging_verifier', here / 'verify.py')
        native = verifier.compare(
            verifier.inspect(args.output / 'rd-baseline/native.log', 'baseline'),
            verifier.inspect(args.output / 'rd-candidate/native.log', 'candidate'))
        (args.output / 'native-rd-result.json').write_text(json.dumps(native, indent=2) + '\n')
        report['status'] = 'PASS'
        report['actual_rd_cases_per_variant'] = len(native['candidate']['cases'])
        report['scope'] = 'Linux software-Vulkan RD component; runtime/template pins unchanged; no Metal/iOS qualification claim'
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
    run(parser.parse_args())


if __name__ == '__main__':
    main()
