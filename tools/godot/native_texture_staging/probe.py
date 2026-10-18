#!/usr/bin/env python3
"""Run actual RD uploads/readback in a fresh X11 software-Vulkan process."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys


SCRIPT = r'''
extends SceneTree

const CASES: Array[Dictionary] = [
    {"id": "etc2-rgb-odd", "format": "ETC2_RGB8", "w": 17, "h": 13, "depth": 1, "layers": 2},
    {"id": "etc2-rgba-wood", "format": "ETC2_RGBA8", "w": 2048, "h": 1024, "depth": 1, "layers": 2},
    {"id": "eac-rg11-normal", "format": "ETC2_RG11", "w": 1024, "h": 768, "depth": 1, "layers": 1},
    {"id": "astc4-material", "format": "ASTC_4x4", "w": 1024, "h": 1024, "depth": 1, "layers": 1},
    {"id": "astc4-padded", "format": "ASTC_4x4", "w": 53, "h": 31, "depth": 1, "layers": 2},
    {"id": "rgba8-depth-padded", "format": "RGBA8", "w": 23, "h": 17, "depth": 3, "layers": 1},
    {"id": "la8-control", "format": "LA8", "w": 3, "h": 17, "depth": 1, "layers": 2},
]

func _initialize() -> void:
    call_deferred("_run_probe")

func _format(name: String) -> RenderingDevice.DataFormat:
    match name:
        "ETC2_RGB8": return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8_UNORM_BLOCK
        "ETC2_RGBA8": return RenderingDevice.DATA_FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK
        "ETC2_RG11": return RenderingDevice.DATA_FORMAT_EAC_R11G11_UNORM_BLOCK
        "ASTC_4x4": return RenderingDevice.DATA_FORMAT_ASTC_4x4_UNORM_BLOCK
        "RGBA8": return RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
        "LA8": return RenderingDevice.DATA_FORMAT_R8G8_UNORM
    return RenderingDevice.DATA_FORMAT_MAX

func _blocks(name: String) -> Vector3i:
    match name:
        "ETC2_RGB8": return Vector3i(4, 8, 2)
        "ETC2_RGBA8", "ETC2_RG11", "ASTC_4x4": return Vector3i(4, 16, 2)
        "LA8": return Vector3i(1, 2, 0)
    return Vector3i(1, 4, 0)

func _mips(w: int, h: int, d: int) -> int:
    var count: int = 1
    while w > 1 or h > 1 or d > 1:
        w = maxi(1, w >> 1)
        h = maxi(1, h >> 1)
        d = maxi(1, d >> 1)
        count += 1
    return count

func _payload(w: int, h: int, d: int, mips: int, info: Vector3i, layer: int) -> PackedByteArray:
    var total: int = 0
    var marks: PackedInt64Array = []
    for mip: int in range(mips):
        var bw: int = (w + info.x - 1) >> info.z
        var bh: int = (h + info.x - 1) >> info.z
        marks.append(total)
        total += bw * bh * info.y * d
        w = maxi(1, w >> 1)
        h = maxi(1, h >> 1)
        d = maxi(1, d >> 1)
    var data: PackedByteArray = PackedByteArray()
    data.resize(total)
    data.fill(0)
    # Distinct mip/layer bytes reveal incorrect offsets. These are transport
    # blocks, not an image-quality fixture or a compressed decoder test.
    for index: int in range(marks.size()):
        data[int(marks[index])] = (index * 17 + layer * 31 + 7) % 251
    data[total - 1] = (layer * 29 + 13) % 251
    return data

func _hash(data: PackedByteArray) -> String:
    var context: HashingContext = HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(data)
    return context.finish().hex_encode()

func _run_probe() -> void:
    var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
    if rd == null:
        push_error("Native staging probe requires an actual RenderingDevice")
        quit(2)
        return
    var checked: int = 0
    for item: Dictionary in CASES:
        var case_id: String = str(item["id"])
        var name: String = str(item["format"])
        var w: int = int(item["w"])
        var h: int = int(item["h"])
        var depth: int = int(item["depth"])
        var layers: int = int(item["layers"])
        var mips: int = _mips(w, h, depth)
        var flags: int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
        if not rd.texture_is_format_supported_for_usage(_format(name), flags):
            push_error("Native staging format unavailable: " + name)
            quit(2)
            return
        var description: RDTextureFormat = RDTextureFormat.new()
        description.format = _format(name)
        description.width = w
        description.height = h
        description.depth = depth
        description.array_layers = layers
        description.mipmaps = mips
        description.usage_bits = flags
        if depth > 1:
            description.texture_type = RenderingDevice.TEXTURE_TYPE_3D
        elif layers > 1:
            description.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
        else:
            description.texture_type = RenderingDevice.TEXTURE_TYPE_2D
        var sources: Array[PackedByteArray] = []
        for layer: int in range(layers):
            sources.append(_payload(w, h, depth, mips, _blocks(name), layer))
        OS.set_environment("GLASSVOW_STAGING_CASE", case_id)
        var texture: RID = rd.texture_create(description, RDTextureView.new(), sources)
        OS.unset_environment("GLASSVOW_STAGING_CASE")
        if not texture.is_valid():
            push_error("Native staging texture creation failed: " + case_id)
            quit(2)
            return
        for layer: int in range(layers):
            var actual: PackedByteArray = rd.texture_get_data(texture, layer)
            var equal: bool = actual == sources[layer]
            print("GV_STAGING_READBACK ", JSON.stringify({"case": case_id, "format": name,
                "layer": layer, "width": w, "height": h, "depth": depth, "mips": mips,
                "source_bytes": sources[layer].size(), "actual_bytes": actual.size(),
                "source_sha256": _hash(sources[layer]), "actual_sha256": _hash(actual), "equal": equal}))
            if not equal:
                push_error("Native staging byte readback mismatch: " + case_id)
                rd.free_rid(texture)
                quit(1)
                return
            checked += 1
        rd.free_rid(texture)
    print("GV_STAGING_DONE ", checked)
    rd.free()
    quit(0)
'''


def run(binary, output):
    output.mkdir(parents=True, exist_ok=False)
    project = output / 'project'
    project.mkdir()
    (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Native Staging Probe"\nboot_splash/show_image=false\n[rendering]\nrenderer/rendering_method="mobile"\n')
    script = project / 'probe.gd'
    script.write_text(SCRIPT)
    env = dict(os.environ, LIBGL_ALWAYS_SOFTWARE='1', GALLIUM_DRIVER='llvmpipe')
    manifests = list(Path('/usr/share/vulkan/icd.d').glob('*lvp*.json'))
    if len(manifests) != 1:
        raise RuntimeError('required software-Vulkan ICD is unavailable or ambiguous')
    manifest = manifests[0]
    env['VK_DRIVER_FILES'] = str(manifest.resolve())
    for suffix in ['DATA', 'CACHE', 'CONFIG', 'STATE']:
        path = output / ('xdg-' + suffix.lower())
        path.mkdir()
        env['XDG_' + suffix + '_HOME'] = str(path.resolve())
    command = ['xvfb-run', '--auto-servernum', '--server-args',
        '-screen 0 640x480x24 -nolisten tcp', str(binary.resolve()), '--path',
        str(project.resolve()), '--display-driver', 'x11', '--rendering-driver',
        'vulkan', '--rendering-method', 'mobile', '--audio-driver', 'Dummy',
        '--script', str(script.resolve())]
    (output / 'command.json').write_text(json.dumps({'argv': command,
        'vulkan_icd': str(manifest.resolve()),
        'vulkan_icd_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
        'environment_names': ['DISPLAY', 'LIBGL_ALWAYS_SOFTWARE', 'GALLIUM_DRIVER',
            'VK_DRIVER_FILES', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME']}, indent=2) + '\n')
    with (output / 'native.log').open('wb') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
            env=env, start_new_session=True)
        try:
            code = process.wait(timeout=120)
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
    text = (output / 'native.log').read_text(errors='replace')
    if code != 0 or 'SCRIPT ERROR' in text or 'Parse Error' in text:
        raise RuntimeError(f'actual native probe failed/inconclusive, exit {code}; see native.log')
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    return run(args.binary, args.output)


if __name__ == '__main__':
    sys.exit(main())
