# Check completed Studio jobs without reading credentials or changing the queue.
# Engine only: python3 -I check_raw_assets.py jobs-mobs-2to4c.txt
import json
from pathlib import Path
import struct
import sys
import uuid

lane = Path(__file__).resolve().parent.parent
jobs = Path(sys.argv[1]).read_text().splitlines()
complete, pending = [], []
for line in jobs:
    if not line.strip():
        continue
    name, part, target = line.split()
    folder = lane / "mobs" / name / "tripo"
    result_path = folder / (part + "-a.json")
    if not result_path.exists() or not result_path.stat().st_size:
        pending.append(name + "/" + part)
        continue
    result = json.loads(result_path.read_text())
    assert result.get("ok") is True, (name, part, "Studio result failed")
    assert result["driver"] == "chrome-for-testing-headed", (name, part, "Unexpected driver")
    assert result["slider_faces"] == int(target) == result["faces"], (name, part, "Face setting mismatch")
    assert result["privacy"] == "private" and result["textured"] is True, (name, part, "Setting mismatch")
    uuid.UUID(result["task_id"])
    model = folder / (part + "-a.glb")
    assert Path(result["glb_path"]) == model, (name, part, "Output path mismatch")
    raw = model.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", raw)
    assert (magic, version, length) == (b"glTF", 2, len(raw)), (name, part, "Invalid GLB header")
    json_length, chunk_type = struct.unpack_from("<II", raw, 12)
    assert chunk_type == 0x4E4F534A and 20 + json_length <= len(raw), (name, part, "Invalid JSON chunk")
    gltf = json.loads(raw[20:20 + json_length])
    assert gltf["asset"]["version"] == "2.0" and gltf.get("meshes"), (name, part, "Missing mesh")
    triangles = 0
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4, (name, part, "Unexpected primitive mode")
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            triangles += gltf["accessors"][accessor]["count"] // 3
    complete.append({"name": name, "part": part, "bytes": len(raw), "triangles": triangles,
                     "target_faces": int(target), "task_id": result["task_id"]})
report = {"complete": complete, "pending": pending}
(lane / "pipeline" / "raw-assets-check.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS", len(complete), "completed GLBs: headers, meshes, task records and selected settings")
print("Pending", len(pending), ", ".join(pending))
