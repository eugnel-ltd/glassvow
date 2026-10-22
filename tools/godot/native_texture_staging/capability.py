#!/usr/bin/env python3
"""Bounded stock-engine venue screen; CAPABILITY_SUPPORTED is never component PASS.

Trigger: before an expensive native pair, or the first macos-15 venue check.
Cost: <=360s total, <=180s/192MiB download, <=120s query-only engine. Failure,
unsupported or ambiguous observations are durable INCONCLUSIVE, with no retry.
Remove/narrow this screen only when equivalent same-host capability evidence
already precedes the pair. Allocation/copy/readback/native gates stay required.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import time
import urllib.request
import uuid
import zipfile

VERSION = '4.7.2.stable.official.ed1daf0bf'
MAC = 'macos-arm64-metal-v1'
LINUX = 'linux-x86_64-lavapipe-v1'
FORMATS = [('ETC2_RGB8', 146), ('ETC2_RGBA8', 150), ('EAC_RG11', 154),
           ('ASTC_4x4_UNORM', 156), ('RGBA8', 36), ('RG8_LA8', 15)]
ARCHIVES = {
    MAC: ('Godot_v4.7.2-stable_macos.universal.zip', 170622178,
          'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e',
          'Godot.app/Contents/MacOS/Godot'),
    LINUX: ('Godot_v4.7.2-stable_linux.x86_64.zip', 77860424,
            'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4',
            'Godot_v4.7.2-stable_linux.x86_64'),
}
QUERY_SHA256 = 'beecc87040c9fa5e5ae139a485730acf71392bcca69c39c3d31f6b1b4e3d44fb'
OVERRIDES = ('LD_LIBRARY_PATH', 'LD_PRELOAD', 'DYLD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES',
             'VK_ICD_FILENAMES', 'VK_ADD_DRIVER_FILES', 'VK_LAYER_PATH', 'VK_INSTANCE_LAYERS',
             'VK_LOADER_DRIVERS_SELECT', 'VK_LOADER_DRIVERS_DISABLE', 'VK_LAYER_SETTINGS_PATH',
             'VK_LOADER_LAYERS_ENABLE', 'VK_LOADER_LAYERS_DISABLE', 'VK_LOADER_LAYERS_ALLOW')
METAL_OVERRIDES = OVERRIDES + ('VK_DRIVER_FILES', 'GODOT_MTL_FORCE_BARRIERS', 'GODOT_MTL_TARGET_VERSION',
                             'OSXCROSS_ROOT', 'CCACHE')
SCRIPT = r'''
extends SceneTree
const FORMATS: Array[Dictionary] = [
    {"format":"ETC2_RGB8","id":RenderingDevice.DATA_FORMAT_ETC2_R8G8B8_UNORM_BLOCK},
    {"format":"ETC2_RGBA8","id":RenderingDevice.DATA_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK},
    {"format":"EAC_RG11","id":RenderingDevice.DATA_FORMAT_EAC_R11G11_UNORM_BLOCK},
    {"format":"ASTC_4x4_UNORM","id":RenderingDevice.DATA_FORMAT_ASTC_4x4_UNORM_BLOCK},
    {"format":"RGBA8","id":RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM},
    {"format":"RG8_LA8","id":RenderingDevice.DATA_FORMAT_R8G8_UNORM},
]
func _initialize() -> void:
    call_deferred("_query")
func _format(name: String) -> RenderingDevice.DataFormat:
    match name:
        "ETC2_RGB8": return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8_UNORM_BLOCK
        "ETC2_RGBA8": return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK
        "EAC_RG11": return RenderingDevice.DATA_FORMAT_EAC_R11G11_UNORM_BLOCK
        "ASTC_4x4_UNORM": return RenderingDevice.DATA_FORMAT_ASTC_4x4_UNORM_BLOCK
        "RGBA8": return RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
        "RG8_LA8": return RenderingDevice.DATA_FORMAT_R8G8_UNORM
    return RenderingDevice.DATA_FORMAT_MAX
func _query() -> void:
    var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
    if rd == null:
        push_error("A real local RenderingDevice is required")
        quit(2)
        return
    print("GV_TEXTURE_CAPABILITY_DEVICE ",JSON.stringify({"schema":1,
        "vendor":rd.get_device_vendor_name(),"name":rd.get_device_name(),
        "os":OS.get_name(),"display":DisplayServer.get_name(),
        "arm64":OS.has_feature("arm64"),"x86_64":OS.has_feature("x86_64"),
        "user_data_dir":OS.get_user_data_dir(),"engine":Engine.get_version_info()}))
    for item: Dictionary in FORMATS:
        var supported: bool = rd.texture_is_format_supported_for_usage(_format(str(item["format"])),193)
        print("GV_TEXTURE_CAPABILITY_FORMAT ",JSON.stringify({"format":item["format"],
            "format_id":item["id"],"usage":193,"supported":supported}))
    print("GV_TEXTURE_CAPABILITY_DONE 6")
    rd.free()
    quit(0)
'''


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(data)
    return value.hexdigest()


def write_result(path, data):
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(data, indent=2) + '\n')
    temporary.replace(path)


def assess(profile, host, version, text, code, expected_version=VERSION):
    result = {'schema': 1, 'profile': profile, 'status': 'INCONCLUSIVE',
              'component_status': 'NOT_RUN', 'errors': [], 'formats': []}
    try:
        require(profile in ARCHIVES, 'unknown profile')
        metal = profile == MAC
        expected = ('Darwin', 'arm64') if metal else ('Linux', 'x86_64')
        require((host.get('system'), host.get('uname_machine')) == expected and
                host.get('python_machine') == expected[1] and host.get('translated') is False,
                'wrong host architecture/OS or translated execution')
        require(version.strip() == expected_version, 'unsupported engine version')
        require(code == 0, 'native process failed or timed out')
        require(not re.search(r'(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):', text),
                'native/script diagnostics invalidate capability')
        devices, done, protocol = [], [], []
        for line in text.splitlines():
            if line.startswith('GV_TEXTURE_CAPABILITY_DEVICE '):
                devices.append(json.loads(line.split(' ', 1)[1]))
                protocol.append('DEVICE')
            elif line.startswith('GV_TEXTURE_CAPABILITY_FORMAT '):
                result['formats'].append(json.loads(line.split(' ', 1)[1]))
                protocol.append('FORMAT')
            elif line.startswith('GV_TEXTURE_CAPABILITY_DONE '):
                done.append(line)
                protocol.append('DONE')
            elif line.startswith('GV_TEXTURE_CAPABILITY_'):
                raise ValueError('unknown capability protocol record')
        require(len(devices) == 1 and done == ['GV_TEXTURE_CAPABILITY_DONE 6'], 'ambiguous/incomplete protocol')
        require(protocol == ['DEVICE'] + ['FORMAT'] * 6 + ['DONE'], 'capability protocol order differs')
        device = devices[0]
        result['device'] = device
        require(type(device.get('schema')) is int and device['schema'] == 1
                and device.get('os') == ('macOS' if metal else 'Linux')
                and device.get('arm64') is metal and device.get('x86_64') is (not metal),
                'native device architecture/OS differs')
        require(all(isinstance(device.get(key), str) and device[key].strip()
                    for key in ('vendor', 'name')), 'missing bound device vendor/name')
        require(metal or device['name'].lower().startswith('llvmpipe ('),
                'Linux software-driver profile observed another physical device')
        prefix = 'Metal' if metal else 'Vulkan'
        startup = [line for line in text.splitlines()
                   if re.match(r'^' + prefix + r' [0-9][^\r\n]*Using Device #[0-9]+: ', line)]
        require(len(startup) == 1 and all(device[k] in startup[0] for k in ('vendor', 'name')),
                'actual backend API/device startup receipt absent or ambiguous')
        forbidden = r'(?m)^(?:Vulkan |OpenGL |OpenGL API |Direct3D )' if metal else r'(?m)^(?:Metal |OpenGL |OpenGL API |Direct3D )'
        require(not re.search(forbidden, text), 'wrong backend/fallback observed')
        result['backend_startup'] = startup[0]
        require([(r.get('format'), r.get('format_id')) for r in result['formats']] == FORMATS,
                'missing/duplicate/wrong exact physical format')
        require(all(type(r.get('format_id')) is int and type(r.get('usage')) is int
                    and r['usage'] == 193 and type(r.get('supported')) is bool
                    for r in result['formats']), 'wrong capability types/usage')
        require(all(r['supported'] for r in result['formats']), 'required physical usage is unsupported')
        result['status'] = 'CAPABILITY_SUPPORTED'
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        result['errors'].append(str(error))
    return result


def run_process(command, cwd, env, seconds, limit=262144):
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    data, timed_out, output_limit = bytearray(), False, False
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    end = time.monotonic() + seconds
    try:
        while selector.get_map():
            remaining = end - time.monotonic()
            if remaining <= 0:
                timed_out = True
                break
            for key, _ in selector.select(min(remaining, 0.2)):
                chunk = os.read(key.fd, 16384)
                if not chunk:
                    selector.unregister(key.fileobj)
                else:
                    available = max(0, limit - len(data))
                    data.extend(chunk[:available])
                    if len(chunk) > available:
                        output_limit = True
            if len(data) >= limit:
                output_limit = True
                break
        if not timed_out and not output_limit:
            process.wait(timeout=max(0.01, end - time.monotonic()))
    except subprocess.TimeoutExpired:
        timed_out = True
    finally:
        selector.close()
        process.stdout.close()
        # The leader can exit while a descendant still owns its stdout pipe.
        # Clean this owned session even after the leader has already exited.
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=2)
    return {'command': command, 'pid': process.pid, 'exit': process.returncode,
            'timed_out': timed_out, 'output_limit': output_limit, 'reaped': True,
            'output': bytes(data).decode(errors='replace')}


def verify_archive(path, size, checksum):
    require(path.stat().st_size == size and size <= 192 * 1024**2, 'stock archive size differs')
    actual = digest(path)
    require(actual == checksum, 'stock archive SHA256 differs')
    return {'bytes': size, 'sha256': actual}


def linux_binding(icd, env):
    require(not any(env.get(key) for key in OVERRIDES), 'loader environment override is not qualified')
    try:
        icd = icd.resolve(strict=True)
        require(not env.get('VK_DRIVER_FILES') or env['VK_DRIVER_FILES'] == str(icd),
                'configured ICD differs')
        require(icd.stat().st_size < 65536, 'ICD JSON exceeds bound')
        library = Path(json.loads(icd.read_text())['ICD']['library_path'])
        # Do not guess a dynamic loader's search path for bare/relative names.
        require(library.is_absolute(), 'ICD library path must be absolute')
        library = library.resolve(strict=True)
        require(library.is_file(), 'ICD shared library missing')
        boot = Path('/proc/sys/kernel/random/boot_id')
        host = boot.read_bytes() if boot.exists() else repr(os.uname()).encode()
        return {'icd_path': str(icd), 'icd_sha256': digest(icd), 'library_path': str(library),
                'library_sha256': digest(library), 'library_bytes': library.stat().st_size,
                'host_boot_sha256': hashlib.sha256(host).hexdigest()}
    except (OSError, KeyError, TypeError) as error:
        raise ValueError('ICD/library identity unavailable: ' + str(error)) from error


def verify_linux_binding(receipt, icd, env):
    require(receipt.is_file() and receipt.stat().st_size <= 131072, 'bounded capability receipt absent')
    result = json.loads(receipt.read_text())
    require(result.get('status') == 'CAPABILITY_SUPPORTED' and result.get('profile') == LINUX
            and result.get('component_status') == 'NOT_RUN' and result.get('errors') == [],
            'capability receipt is unqualified')
    require(result.get('formats') == [{'format': n, 'format_id': i, 'usage': 193, 'supported': True}
                                    for n, i in FORMATS], 'capability receipt format/usage differs')
    require(all(type(r.get('format_id')) is int and type(r.get('usage')) is int
                and r.get('supported') is True for r in result['formats']), 'receipt format types differ')
    current = linux_binding(icd, env)
    require(result.get('linux_driver') == current, 'same-host ICD/shared-library identity changed')
    expected = env.get('GLASSVOW_STAGING_SOURCE_HEAD')
    require(not expected or result.get('head') == expected, 'capability source head differs')
    require(not expected or (result.get('query_source_sha256') == QUERY_SHA256 and
                            result.get('version') == VERSION), 'stock query/source version differs')
    return {'receipt_sha256': digest(receipt), 'driver': current,
            'resource_screen_only': True, 'actual_native_queries_readbacks_still_required': True}


def verify_native_backend(receipt, text):
    """Link actual native Vulkan startup to the stock device; no query substitution."""
    result = json.loads(receipt.read_text())
    devices = [line for line in text.splitlines()
               if re.match(r'^Vulkan [0-9][^\r\n]*Using Device #[0-9]+: ', line)]
    require(len(devices) == 1 and all(result['device'][k] in devices[0] for k in ('vendor', 'name')),
            'native Vulkan device differs from resource screen')
    require(not re.search(r'(?m)^(?:Metal |OpenGL |OpenGL API |Direct3D )', text),
            'native backend differs from resource screen')
    return devices[0]


def mac_host_binding():
    """Same boot and hosted job, not a reusable cross-VM capability token."""
    require(platform.system() == 'Darwin' and platform.machine() == 'arm64'
            and os.uname().machine == 'arm64', 'native arm64 macOS host required')
    require(not any(os.environ.get(k) for k in METAL_OVERRIDES), 'Metal environment override is unqualified')
    record = run_process(['/usr/sbin/sysctl', '-n', 'kern.boottime'], Path.cwd(),
                         os.environ.copy(), 10, 4096)
    require(record['exit'] == 0 and record['reaped'] and not record['timed_out']
            and not record['output_limit'], 'bounded host boot query failed')
    marker = re.search(r'sec\s*=\s*(\d+),\s*usec\s*=\s*(\d+)', record['output'])
    require(marker is not None, 'host boot marker absent')
    value = os.uname().nodename + ':' + ':'.join(marker.groups())
    return {'system': 'Darwin', 'machine': 'arm64',
            'boot_sha256': hashlib.sha256(value.encode()).hexdigest(),
            'job': {key: os.environ.get(key) for key in ('GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT',
                'GITHUB_JOB', 'RUNNER_NAME', 'ImageOS', 'ImageVersion')}}


def main_run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    result = {'schema': 1, 'head': args.head, 'profile': args.profile, 'status': 'INCONCLUSIVE',
              'component_status': 'NOT_RUN', 'errors': [], 'formats': [], 'commands': [],
              'phase': 'setup',
              'scope': 'Necessary physical-format capability only; no allocation/copy/readback/device acceptance',
              'query_source_sha256': QUERY_SHA256, 'helper_sha256': digest(Path(__file__)),
              'script_sha256': hashlib.sha256(SCRIPT.encode()).hexdigest()}
    # Leave 30s for typed-result persistence/runner teardown before the 6m step cap.
    end = time.monotonic() + 330
    previous = signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('capability wall-time budget expired')))
    signal.alarm(330)
    def command(argv, seconds=10, cwd=None, env=None):
        record = run_process(argv, cwd or args.work, env or os.environ.copy(),
                             min(seconds, max(0.01, end - time.monotonic())))
        log = args.output / ('command-%02d.log' % len(result['commands']))
        log.write_text(record['output'])
        result['commands'].append(dict({k: v for k, v in record.items() if k != 'output'},
                                       log=log.name, log_sha256=digest(log)))
        require(record['exit'] == 0 and not record['timed_out'] and not record['output_limit'],
                'bounded command failed: ' + argv[0])
        return record['output'].strip()
    try:
        args.work.mkdir(parents=True, exist_ok=False)
        require(not any(os.environ.get(k) for k in OVERRIDES), 'loader environment is unqualified')
        repo = Path(__file__).resolve().parents[3]
        require(re.fullmatch('[0-9a-f]{40}', args.head), 'exact head is required')
        require(command(['git', '-C', str(repo), 'rev-parse', 'HEAD']) == args.head, 'checkout head differs')
        metal = args.profile == MAC
        host = {'system': platform.system(), 'uname_machine': command(['uname', '-m']),
                'python_machine': platform.machine(), 'translated': False,
                'translation_basis': 'Native uname and interpreter architecture must both match profile',
                'runner_image': {k: os.environ.get(k) for k in ('ImageOS', 'ImageVersion', 'RUNNER_OS', 'RUNNER_ARCH')},
                'disk_free': shutil.disk_usage(args.work).free}
        result['host'] = host
        require((host['system'], host['uname_machine'], host['python_machine']) ==
                (('Darwin', 'arm64', 'arm64') if metal else ('Linux', 'x86_64', 'x86_64')), 'wrong host architecture/OS')
        if metal:
            result['mac_host_binding'] = mac_host_binding()
            host['os_version'] = command(['sw_vers', '-productVersion'])
            host['xcode'] = command(['xcodebuild', '-version'])
            host['sdk'] = command(['xcrun', '--sdk', 'macosx', '--show-sdk-version'])
            host['clang'] = command(['xcrun', 'clang', '--version'])
            host['memory_bytes'] = command(['sysctl', '-n', 'hw.memsize'])
        else:
            host['os_version'] = command(['uname', '-sr'])
            host['memory'] = Path('/proc/meminfo').read_text().splitlines()[:3]
        name, size, checksum, executable = ARCHIVES[args.profile]
        result['stock_archive_expected'] = {'name': name, 'bytes': size, 'sha256': checksum}
        archive = args.work / name
        result['phase'] = 'download'
        deadline = min(end, time.monotonic() + 180)
        url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/' + name
        signal.setitimer(signal.ITIMER_REAL, max(0.001, deadline - time.monotonic()))
        try:
            with urllib.request.urlopen(url, timeout=15) as response, archive.open('xb') as target:
                count = 0
                while True:
                    require(time.monotonic() < deadline, '180s download cap')
                    data = response.read(65536)
                    if not data:
                        break
                    count += len(data)
                    require(count <= min(size, 192 * 1024**2), '192MiB/exact stock size download cap')
                    target.write(data)
        finally:
            signal.setitimer(signal.ITIMER_REAL, max(0.001, end - time.monotonic()))
        result['phase'] = 'archive_verify_and_extract'
        result['archive'] = verify_archive(archive, size, checksum)
        expanded = args.work / 'stock'
        expanded.mkdir()
        with zipfile.ZipFile(archive) as source:
            require(len(source.infolist()) < 10000 and sum(x.file_size for x in source.infolist()) < 1024**3,
                    'stock extraction exceeds bound')
            for item in source.infolist():
                path = Path(item.filename)
                require(not path.is_absolute() and '..' not in path.parts and '\\' not in item.filename
                        and not stat.S_ISLNK(item.external_attr >> 16), 'unsafe stock archive member')
                require(time.monotonic() < end, 'total cap during extraction')
                source.extract(item, expanded)
        binary = expanded / executable
        require(binary.is_file(), 'stock executable absent')
        binary.chmod(0o755)
        result['binary'] = {'path': str(binary), 'sha256': digest(binary)}
        if metal:
            result['binary']['architectures'] = command(['lipo', '-archs', str(binary)])
            require('arm64' in result['binary']['architectures'].split(), 'stock executable lacks arm64')
        version = command([str(binary), '--version'], 15)
        (args.output / 'version.log').write_text(version + '\n')
        result['version'] = version
        require(version == VERSION, 'unsupported stock engine version')
        project = args.work / 'project'
        project.mkdir()
        user_dir = 'glassvow-native-capability-' + uuid.uuid4().hex
        settings = ('config_version=5\n[application]\nconfig/name="Native Capability Probe"\n'
                    'boot_splash/show_image=false\nconfig/use_custom_user_dir=true\n'
                    'config/custom_user_dir_name="' + user_dir + '"\n[rendering]\nrenderer/rendering_method="mobile"\n')
        (project / 'project.godot').write_text(settings)
        (project / '.godot').mkdir()
        (project / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
        script = project / 'capability.gd'
        script.write_text(SCRIPT)
        result['project_sha256'] = digest(project / 'project.godot')
        result['cache_sha256'] = digest(project / '.godot/global_script_class_cache.cfg')
        env = os.environ.copy()
        for suffix in ('DATA', 'CACHE', 'CONFIG', 'STATE'):
            folder = args.work / ('xdg-' + suffix.lower())
            folder.mkdir()
            env['XDG_' + suffix + '_HOME'] = str(folder)
        if metal:
            argv = [str(binary), '--display-driver', 'macos', '--rendering-driver', 'metal']
        else:
            manifests = list(Path('/usr/share/vulkan/icd.d').glob('*lvp*.json'))
            require(len(manifests) == 1, 'lavapipe ICD is absent or ambiguous')
            result['linux_driver'] = linux_binding(manifests[0], env)
            env.update(VK_DRIVER_FILES=result['linux_driver']['icd_path'], LIBGL_ALWAYS_SOFTWARE='1', GALLIUM_DRIVER='llvmpipe')
            argv = ['xvfb-run', '--auto-servernum', '--server-args', '-screen 0 640x480x24 -nolisten tcp',
                    str(binary), '--display-driver', 'x11', '--rendering-driver', 'vulkan']
        argv += ['--path', str(project), '--rendering-method', 'mobile', '--audio-driver', 'Dummy', '--script', str(script)]
        result['phase'] = 'stock_query'
        capture = run_process(argv, project, env, min(116, max(0.01, end - time.monotonic() - 4)))
        (args.output / 'native.log').write_text(capture['output'])
        result['commands'].append(dict({k: v for k, v in capture.items() if k != 'output'},
            log='native.log', log_sha256=digest(args.output / 'native.log')))
        assessed = assess(args.profile, host, version, capture['output'], capture['exit'])
        result.update(assessed)
        require(not capture['timed_out'] and not capture['output_limit'], 'native timeout/output cap')
        if result['status'] == 'CAPABILITY_SUPPORTED':
            require(Path(result['device'].get('user_data_dir', '')).name == user_dir, 'private engine userdata ownership differs')
        if not metal:
            require(result['linux_driver'] == linux_binding(manifests[0], env), 'driver identity changed during stock query')
        else:
            require(result['mac_host_binding'] == mac_host_binding(), 'Mac host/job changed during stock query')
        result['phase'] = 'complete'
    except Exception as error:
        result['status'] = 'INCONCLUSIVE'
        result['errors'].append(type(error).__name__ + ': ' + str(error))
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, previous)
        write_result(args.output / 'result.json', result)
    print(json.dumps({'status': result['status'], 'component_status': 'NOT_RUN', 'errors': result['errors']}))
    return 0 if result['status'] == 'CAPABILITY_SUPPORTED' else 2


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=[MAC, LINUX], required=True)
    parser.add_argument('--head', required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    raise SystemExit(main_run(parser.parse_args()))
