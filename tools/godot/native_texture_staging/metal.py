#!/usr/bin/env python3
"""Explicit desktop Metal proof identity and isolated launches; no shipping claim."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import uuid

SPEC = importlib.util.spec_from_file_location('gv_metal_capability', Path(__file__).with_name('capability.py'))
capability = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(capability)
MAC = capability.MAC
SOURCE = 'ed1daf0bf001b61586d9930840f2f1394092c079'
ARCHIVE = 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef'
FLAGS = ['platform=macos', 'target=template_debug', 'arch=arm64', 'optimize=speed',
         'debug_symbols=no', 'tests=yes', 'disable_path_overrides=no', 'metal=yes',
         'vulkan=no', 'opengl3=no', 'accesskit=no', 'generate_bundle=no', 'disable_3d=yes',
         'modules_enabled_by_default=no', 'module_gdscript_enabled=yes',
         'module_glslang_enabled=yes', 'module_text_server_fb_enabled=yes', '-j2']


def require(value, message):
    if not value:
        raise ValueError(message)


def read_json(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 131072,
            'bounded owned JSON receipt missing')
    value = json.loads(path.read_text())
    require(isinstance(value, dict), 'receipt object required')
    return value


def verify_venue(receipt, head):
    data = read_json(Path(receipt))
    require(re.fullmatch('[0-9a-f]{40}', head or '') and data.get('head') == head, 'venue source head differs')
    require(data.get('profile') == MAC and data.get('status') == 'CAPABILITY_SUPPORTED'
            and data.get('component_status') == 'NOT_RUN' and data.get('errors') == [],
            'same-job Metal venue is unqualified')
    require(data.get('version') == capability.VERSION and data.get('query_source_sha256') == capability.QUERY_SHA256,
            'stock version/query source differs')
    # Reuse the maintained strict protocol validator, without inventing a result.
    text = '\n'.join([data.get('backend_startup', ''),
        'GV_TEXTURE_CAPABILITY_DEVICE ' + json.dumps(data.get('device')),
        *['GV_TEXTURE_CAPABILITY_FORMAT ' + json.dumps(r) for r in data.get('formats', [])],
        'GV_TEXTURE_CAPABILITY_DONE 6'])
    checked = capability.assess(MAC, data.get('host', {}), data['version'], text, 0)
    require(checked['status'] == 'CAPABILITY_SUPPORTED', 'stock Metal device/format/usage receipt differs')
    current = capability.mac_host_binding()
    require(data.get('mac_host_binding') == current, 'Mac host boot or workflow job differs')
    require(all(current.get('job', {}).get(k) for k in
                ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'GITHUB_JOB', 'RUNNER_NAME')),
            'hosted job identity is absent')
    return data


def custom_version(value):
    require(re.fullmatch(r'4\.7\.2\.stable\.custom_build(?:\.[0-9a-f]+)?', value or ''),
            'native binary version is not pinned stable 4.7.2 custom build')
    return value


def backend(text, device):
    lines = [line for line in text.splitlines()
             if re.match(r'^Metal [0-9][^\r\n]*Using Device #[0-9]+: ', line)]
    require(len(lines) == 1 and all(device[k] in lines[0] for k in ('vendor', 'name')),
            'actual native Metal backend/device differs')
    require(not re.search(r'(?m)^(?:Vulkan |OpenGL |OpenGL API |Direct3D )', text), 'native renderer fallback observed')
    return lines[0]


def run_probe(binary, output, receipt, head, script):
    """Identity query then original upload script; both on the same fresh project."""
    binary, output, receipt = Path(binary).resolve(), Path(output).resolve(), Path(receipt).resolve()
    venue = verify_venue(receipt, head)
    require(binary.is_file() and not output.exists(), 'fresh native binary/probe output required')
    output.mkdir(parents=True)
    project = output / 'project'
    project.mkdir()
    user_dir = 'glassvow-native-component-' + uuid.uuid4().hex
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native Staging Probe"\n'
        'boot_splash/show_image=false\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + user_dir +
        '"\n[rendering]\nrenderer/rendering_method="mobile"\n')
    (project / '.godot').mkdir()
    cache = project / '.godot/global_script_class_cache.cfg'
    cache.write_text('list=[]\n')
    identity, native = project / 'native-profile.gd', project / 'probe.gd'
    identity.write_text(capability.SCRIPT)
    native.write_text(script)
    env = os.environ.copy()
    for suffix in ('DATA', 'CACHE', 'CONFIG', 'STATE'):
        folder = output / ('xdg-' + suffix.lower())
        folder.mkdir()
        env['XDG_' + suffix + '_HOME'] = str(folder)
    metadata = {'profile': MAC, 'source_head': head, 'host_binding': venue['mac_host_binding'],
        'venue_receipt_sha256': capability.digest(receipt), 'binary_sha256': capability.digest(binary),
        'script_sha256': hashlib.sha256(script.encode()).hexdigest(),
        'identity_script_sha256': capability.digest(identity), 'cache_sha256': capability.digest(cache),
        'project_sha256': capability.digest(project / 'project.godot'), 'user_dir': user_dir,
        'commands': [], 'status': 'running', 'coverage': {'forced_256_gpu_row_padding': 'NOT_RUN',
        'forced_512_offset_alignment': 'required; actual component verifier must prove it'}}
    try:
        def execute(command, name, seconds=116, limit=1048576):
            result = capability.run_process(command, project, env, seconds, limit=limit)
            path = output / name
            path.write_text(result['output'])
            metadata['commands'].append(dict({k: v for k, v in result.items() if k != 'output'},
                log=name, log_sha256=capability.digest(path)))
            require(result['exit'] == 0 and result['reaped'] and not result['timed_out']
                    and not result['output_limit'], 'bounded native process failed: ' + name)
            # Component-native ERROR semantics belong to the mandatory strict
            # component verifier (Vigil has an intentional atomic rejection).
            # Identity/version queries have no legitimate native error path.
            forbidden = r'(?m)^\s*(?:SCRIPT ERROR|Parse Error):' if name == 'native.log' else r'(?m)^\s*(?:ERROR|SCRIPT ERROR|Parse Error):'
            require(not re.search(forbidden, result['output']),
                    'native diagnostics invalidate ' + name)
            return result
        version = execute([str(binary), '--version'], 'version.log', 15)['output'].strip()
        metadata['version'] = custom_version(version)
        argv = [str(binary), '--display-driver', 'macos', '--rendering-driver', 'metal',
                '--rendering-method', 'mobile', '--audio-driver', 'Dummy', '--path', str(project), '--script']
        query = execute(argv + [str(identity)], 'native-profile.log')
        observed = capability.assess(MAC, venue['host'], version, query['output'], query['exit'], expected_version=version)
        require(observed['status'] == 'CAPABILITY_SUPPORTED', 'native format/device identity query failed')
        device = observed['device']
        require(all(device[k] == venue['device'][k] for k in ('vendor', 'name')), 'native device differs from stock venue')
        require(device.get('display') == 'macos' and Path(device.get('user_data_dir', '')).name == user_dir,
                'actual macOS userdata isolation differs')
        engine = device.get('engine', {})
        require((engine.get('major'), engine.get('minor'), engine.get('patch'), engine.get('status'), engine.get('build'))
                == (4, 7, 2, 'stable', 'custom_build'), 'actual native engine identity differs')
        metadata['native_profile'], metadata['profile_exit'] = observed, query['exit']
        require(observed['backend_startup'] == venue['backend_startup'], 'native Metal API/backend profile differs')
        require(capability.digest(project / 'project.godot') == metadata['project_sha256'], 'probe settings changed')
        result = execute(argv + [str(native)], 'native.log')
        metadata['native_backend_startup'] = backend(result['output'], device)
        require(metadata['native_backend_startup'] == observed['backend_startup'], 'component Metal API/backend changed')
        require(capability.mac_host_binding() == metadata['host_binding'], 'native host/job changed')
        require(capability.digest(binary) == metadata['binary_sha256'], 'native binary changed')
        metadata['native_exit'], metadata['status'] = result['exit'], 'pass'
        return metadata
    except BaseException as error:
        metadata['status'], metadata['error'] = 'failed_or_inconclusive', type(error).__name__ + ': ' + str(error)
        raise
    finally:
        capability.write_result(output / 'command.json', metadata)


def verify_provenance(build, commands, receipt, head, expected_scripts=None):
    venue = verify_venue(receipt, head)
    require(build.get('status') == 'pass' and build.get('profile') == MAC and build.get('source_sha') == SOURCE
            and build.get('source_archive_sha256') == ARCHIVE and build.get('flags') == FLAGS,
            'native build source/platform profile differs')
    require(build.get('venue_receipt_sha256') == capability.digest(Path(receipt))
            and build.get('host_binding') == venue['mac_host_binding'], 'native build venue/host binding differs')
    require(set(commands) == {'baseline', 'candidate'} and set(build.get('builds', {})) == set(commands),
            'paired native variants are incomplete')
    if expected_scripts is not None:
        require(set(expected_scripts) == set(commands) and all(re.fullmatch('[0-9a-f]{64}', v)
                for v in expected_scripts.values()), 'explicit paired script identities required')
    scripts, users, trees = set(), set(), set()
    for variant, command in commands.items():
        binary = build['builds'][variant]
        require(command.get('status') == 'pass' and command.get('profile') == MAC and command.get('source_head') == head
                and command.get('host_binding') == venue['mac_host_binding'] and command.get('native_exit') == 0
                and command.get('profile_exit') == 0, 'native process/profile binding is incomplete')
        require(command.get('venue_receipt_sha256') == build['venue_receipt_sha256']
                and command.get('binary_sha256') == binary.get('binary_sha256')
                and command.get('version') == binary.get('version') and binary.get('architecture') == 'arm64',
                'fresh native binary identity differs')
        custom_version(command['version'])
        native = command.get('native_profile', {})
        require(native.get('status') == 'CAPABILITY_SUPPORTED' and native.get('component_status') == 'NOT_RUN'
                and all(native.get('device', {}).get(k) == venue['device'][k] for k in ('vendor', 'name')),
                'native actual device/query identity differs')
        require(command.get('cache_sha256') == hashlib.sha256(b'list=[]\n').hexdigest(), 'global class cache differs')
        scripts.add(command.get('script_sha256'))
        if expected_scripts is not None:
            require(command.get('script_sha256') == expected_scripts[variant], 'variant script identity differs')
        users.add(command.get('user_dir'))
        trees.add(binary.get('unmodified_source_tree_sha256'))
    require((expected_scripts is not None or len(scripts) == 1) and None not in scripts and len(users) == 2 and None not in users
            and len(trees) == 1 and None not in trees, 'paired script/isolation/source identity differs')
    return {'profile': MAC, 'device': venue['device'], 'host_binding': venue['mac_host_binding'],
            'venue_receipt_sha256': build['venue_receipt_sha256'], 'shipping_template_qualification': False,
            'forced_256_gpu_row_padding': 'NOT_RUN', 'scope': 'Desktop arm64 Metal component only'}
