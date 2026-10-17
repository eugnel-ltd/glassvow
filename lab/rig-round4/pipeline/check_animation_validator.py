# Prove the isolated Godot validator accepts motion and rejects static or unrigged GLBs.
import json
from pathlib import Path
import struct
import subprocess

lane = Path(__file__).resolve().parent.parent
source = lane / "chars/duskblade/rig/duskblade.glb"
raw = lane / "mobs/mirelurker/tripo/body-a.glb"
mutant = lane / "smoke/duskblade-static.glb"
data = bytearray(source.read_bytes())
size, kind = struct.unpack_from("<I4s", data, 12)
assert kind == b"JSON"
document = json.loads(data[20:20 + size])
binary = 20 + size + 8
assert struct.unpack_from("<I4s", data, 20 + size)[1] == b"BIN\x00"
for animation in document["animations"]:
    for sampler in animation["samplers"]:
        assert sampler.get("interpolation", "LINEAR") in ("LINEAR", "STEP")
        accessor = document["accessors"][sampler["output"]]
        assert accessor["componentType"] == 5126 and "sparse" not in accessor
        width = {"VEC3": 12, "VEC4": 16}[accessor["type"]]
        view = document["bufferViews"][accessor["bufferView"]]
        offset = binary + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width)
        first = data[offset:offset + width]
        for index in range(accessor["count"]):
            start = offset + index * stride
            data[start:start + width] = first
mutant.write_bytes(data)

project = lane / "pipeline/godot-inspect"
for label, path, expected in (("animated hero", source, 0), ("unrigged model", raw, 1),
                              ("static animation tracks", mutant, 1)):
    result = subprocess.run(["godot", "--headless", "--path", str(project), "--script",
                             str(lane / "pipeline/godot_check.gd"), "--", str(path)],
                            capture_output=True, text=True, timeout=60, cwd=project)
    output = result.stdout + result.stderr
    (project / (label.replace(" ", "-") + ".log")).write_text(output)
    assert result.returncode == expected, (label, result.returncode, output)
    assert "SCRIPT ERROR" not in output and "ERROR:" not in output, output
    assert ("GD PASS" if expected == 0 else "GD FAIL") in output, output
    print("PASS", label, "returned", result.returncode)
