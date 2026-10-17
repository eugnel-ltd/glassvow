# Print the compact verify and batch summary for one round-three candidate.
import json, sys
from pathlib import Path
out = Path(f'/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab/mobs/{sys.argv[1]}Self/rig-round3-held-articulated')
w = json.loads((out / 'weights.json').read_text())
print('held', w['held_vertices'], 'feathered', w['feathered_vertices'])
batch = {row['clip']: row for row in json.loads((out / 'reimport-deformation.json').read_text())}
d = json.loads((out / 'reimport-articulation.json').read_text())
print('passed', d['passed'], 'held imported', d['held_vertices_imported'], 'rest error', d['rest_coordinate_max_error_m'])
for c in d['clips']:
    j = c['max_joint_rotation_degrees']
    print(f"{c['clip']:6s} fail {c['failed']} batch-stretched {batch[c['clip']]['max_stretched_edges']} "
          f"contact {c['max_two_hand_contact_error_m']*1000:.3f}mm rigid {c['max_held_rigid_residual_m']*1000:.3f}mm "
          f"stretch {c['max_edge_stretch_ratio']:.2f} at {c['worst_stretch']['edge_centre_fraction_of_height']} f{c['worst_stretch']['frame']} "
          f"upper L/R {j['LeftUpperArm']:.0f}/{j['RightUpperArm']:.0f} lower {j['LeftLowerArm']:.0f}/{j['RightLowerArm']:.0f} "
          f"hand {j['LeftHand']:.0f}/{j['RightHand']:.0f} disabled-arm {c['arm_disabled_max_displacement_m']:.3f}m/{c['arm_disabled_vertices_over_1mm']}v "
          f"path {[round(v, 3) for v in c['held_path_min_m']]}..{[round(v, 3) for v in c['held_path_max_m']]}")
