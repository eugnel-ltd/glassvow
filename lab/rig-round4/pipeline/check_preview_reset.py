# Engine only: exercise the actual renderer and camera-sampling sequence.
import os
from pathlib import Path
import shutil
import subprocess

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
source = (pipeline / "godot_preview.gd").read_text()
# End after checking the first idle pose; no frame sequence is needed for this control.
needle = "\t\t\t\tvar image := root.get_texture().get_image()"
assert source.count(needle) == 1
source = source.replace(needle, '\t\t\t\tprint("RESET CONTROL PASS")\n\t\t\t\tquit(0)\n\t\t\t\treturn\n' + needle)
needle = '\t\t\t\t\tvar actual := _posed_bounds(actor)'
assert source.count(needle) == 1
corrupt = source.replace(needle, '\t\t\t\t\tskeleton.set_bone_pose_position(0, Vector3(0, 1, 0))\n' + needle)
for label, code, expected in (("consistent-pose", source, 0),
                              ("corrupt-pose", corrupt, 1)):
    script = lane / "smoke" / f"preview-{label}.gd"
    script.write_text(code)
    output = pipeline / f"preview-control-{label}"
    assert not output.exists(), "Inspect existing control output before running again"
    result = subprocess.run(["godot", "--path", str(pipeline / "godot-inspect"),
                             "--resolution", "640x640", "--position", "1500,60",
                             "--script", str(script), "--", str(output),
                             str(lane / "chars/duskblade/rig/duskblade.glb")],
                            capture_output=True, text=True, timeout=60)
    text = result.stdout + result.stderr
    (pipeline / f"preview-control-{label}.log").write_text(text)
    assert result.returncode == expected, (label, result.returncode, text)
    assert "SCRIPT ERROR" not in text and "ERROR:" not in text, text
    print("PASS", label, "returned", result.returncode, flush=True)
