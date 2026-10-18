#!/usr/bin/env python3
"""Additive Metal pair using immutable shared archive/process helpers; no activation."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys

SPEC = importlib.util.spec_from_file_location('gv_mac_builder_profile', Path(__file__).with_name('metal.py'))
metal = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(metal)
FLAGS = metal.FLAGS


def select_binary(tree):
    binaries = [p for p in (Path(tree) / 'bin').glob('godot.macos.template_debug.arm64*')
                if p.is_file() and not p.is_symlink() and os.access(p, os.X_OK)
                and not p.name.endswith(('.debugsymbols', '.dylib'))]
    metal.require(len(binaries) == 1, 'one new arm64 Mach-O executable is required')
    return binaries[0]


def query_hash(source):
    text = source.read_text()
    start = text.index('bool RenderingDevice::texture_is_format_supported_for_usage(')
    end = text.index('\n}', start) + 2
    return hashlib.sha256(text[start:end].encode()).hexdigest()


def build(args, shared):
    venue = metal.verify_venue(args.venue_receipt, args.head)
    metal.require(args.profile == metal.MAC and shared.SOURCE_SHA == metal.SOURCE
                  and shared.SOURCE_ARCHIVE_SHA256 == metal.ARCHIVE, 'Mac source/profile differs')
    metal.require(not args.work.exists() and not args.output.exists(), 'new Mac build/evidence paths required')
    args.work.mkdir(parents=True)
    args.output.mkdir(parents=True)
    archive = Path(args.source_archive)
    metal.require(metal.capability.digest(archive) == metal.ARCHIVE
                  and args.source_archive_sha256 == metal.ARCHIVE, 'sealed source archive differs')
    prerequisites = [Path(p).resolve() for p in getattr(args, 'baseline_patches', [])]
    patch, observer = args.patch.resolve(), args.observer.resolve()
    report = {'schema': 1, 'status': 'running', 'profile': metal.MAC,
        'source_sha': metal.SOURCE, 'source_archive_sha256': metal.ARCHIVE, 'source_head': args.head,
        'flags': FLAGS, 'host_binding': venue['mac_host_binding'],
        'venue_receipt_sha256': metal.capability.digest(Path(args.venue_receipt)),
        'patch_sha256': metal.capability.digest(patch), 'observer_sha256': metal.capability.digest(observer),
        'prerequisite_patches': [dict(name=p.name, sha256=metal.capability.digest(p)) for p in prerequisites],
        'runtime_test_configuration': {'purpose': 'desktop_metal_component_proof', 'path_overrides': True,
            'scons_option': 'disable_path_overrides=no', 'shipping_template_qualification': False},
        'scope': 'Desktop macOS arm64 Metal component; no iOS/A12/shipping qualification',
        'python_version': sys.version, 'disk_free_bytes': shutil.disk_usage(args.work).free,
        'native_tests': {'status': 'NOT RUN', 'reason': 'separate frozen CPU/native component protocol required'},
        'builds': {}, 'toolchain_commands': []}
    report_path = args.output / 'build-manifest.json'
    try:
        def observe(name, command):
            record = metal.capability.run_process(command, args.work, os.environ.copy(), 15)
            log = args.output / (name + '.log')
            log.write_text(record['output'])
            report['toolchain_commands'].append(dict({k: v for k, v in record.items() if k != 'output'},
                log=log.name, log_sha256=metal.capability.digest(log)))
            metal.require(record['exit'] == 0 and record['reaped'] and not record['timed_out']
                          and not record['output_limit'], 'bounded Mac toolchain query failed: ' + name)
            return record['output'].strip()
        clang = Path(observe('clang-path', ['xcrun', '--find', 'clang']))
        clangxx = Path(observe('clangxx-path', ['xcrun', '--find', 'clang++']))
        sdk = Path(observe('sdk-path', ['xcrun', '--sdk', 'macosx', '--show-sdk-path']))
        toolchain = {'clang_path': str(clang), 'clang_sha256': metal.capability.digest(clang),
            'clangxx_path': str(clangxx), 'clangxx_sha256': metal.capability.digest(clangxx),
            'clang_version': observe('clang-version', [str(clang), '--version']),
            'sdk_path': str(sdk), 'sdk_version': observe('sdk-version', ['xcrun', '--sdk', 'macosx', '--show-sdk-version']),
            'xcode': observe('xcode-version', ['xcodebuild', '-version'])}
        report['toolchain'] = toolchain
        metal.require(sdk.is_dir() and clang.is_file() and clangxx.is_file(), 'selected native SDK/compiler missing')
        metal.require(clang.parent == clangxx.parent, 'selected clang and clang++ executable directories differ')
        metal.require(all(toolchain[k] == venue['host'].get(v) for k, v in
                          [('clang_version', 'clang'), ('sdk_version', 'sdk'), ('xcode', 'xcode')]),
                      'stock venue and native selected compiler/SDK differ')
        report['scons_version'] = observe('scons-version', [sys.executable, '-m', 'SCons', '--version'])
        env = dict(os.environ, PATH=str(clang.parent) + os.pathsep + os.environ.get('PATH', ''))
        original_hash = None
        for variant in ('baseline', 'candidate'):
            metal.require(metal.capability.mac_host_binding() == report['host_binding'], 'build host/job changed')
            tree = shared.extract(archive, args.work / variant)
            version_source = (tree / 'version.py').read_text()
            for field, expected in [('major', '4'), ('minor', '7'), ('patch', '2')]:
                metal.require(re.search(rf'^{field}\s*=\s*{expected}\s*$', version_source, re.M), 'source version differs')
            metal.require(re.search(r'^status\s*=\s*["\']stable["\']\s*$', version_source, re.M), 'source is not stable')
            unmodified = shared.tree_digest(tree)
            metal.require(original_hash is None or original_hash == unmodified, 'paired fresh sources differ')
            original_hash = unmodified
            item = {'unmodified_source_tree_sha256': unmodified, 'version_py_sha256': metal.capability.digest(tree / 'version.py'),
                    'applied_patches': []}
            report['builds'][variant] = item
            for index, applied in enumerate(prerequisites + ([patch] if variant == 'candidate' else [])):
                shared.run_logged(['patch', '-f', '-N', '-F', '0', '-p1', '-i', str(applied)],
                    args.output / f'{variant}-apply-{index}.log', 30, cwd=tree, env=env)
                item['applied_patches'].append(dict(name=applied.name, sha256=metal.capability.digest(applied)))
            item['pre_observer_source_tree_sha256'] = shared.tree_digest(tree)
            shared.run_logged([sys.executable, str(observer), '--source-dir', str(tree.resolve())],
                args.output / f'{variant}-instrument.log', 30, cwd=tree, env=env)
            item['observer_receipt'] = json.loads((args.output / f'{variant}-instrument.log').read_text())
            item['query_source_sha256'] = query_hash(tree / 'servers/rendering/rendering_device.cpp')
            metal.require(item['query_source_sha256'] == metal.capability.QUERY_SHA256, 'native physical format query changed')
            item['instrumented_source_tree_sha256'] = shared.tree_digest(tree)
            command = [sys.executable, '-m', 'SCons', *FLAGS, 'MACOS_SDK_PATH=' + str(sdk)]
            item['command'] = command
            shared.write_json(report_path, report)
            shared.run_logged(command, args.output / f'{variant}-build.log', 1800, cwd=tree, env=env)
            binary = select_binary(tree).resolve()
            architecture = observe(variant + '-architecture', ['lipo', '-archs', str(binary)])
            metal.require(architecture == 'arm64', 'new native binary is not exactly Mach-O arm64')
            version = metal.custom_version(observe(variant + '-version', [str(binary), '--version']))
            metal.require(metal.capability.digest(clang) == toolchain['clang_sha256']
                          and metal.capability.digest(clangxx) == toolchain['clangxx_sha256'], 'compiler bytes changed')
            item.update(binary=str(binary), binary_sha256=metal.capability.digest(binary),
                        architecture=architecture, version=version)
            shared.write_json(report_path, report)
        report['status'] = 'pass'
        shared.write_json(args.output / 'render-inputs.json',
                          {name: report['builds'][name]['binary'] for name in ('baseline', 'candidate')})
    except BaseException as error:
        report['status'], report['error'] = 'failed_or_inconclusive', type(error).__name__ + ': ' + str(error)
        raise
    finally:
        shared.write_json(report_path, report)
