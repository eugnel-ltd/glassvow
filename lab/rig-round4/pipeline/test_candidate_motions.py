# Run with: python3 -I test_candidate_motions.py
from pathlib import Path
import runpy

module = runpy.run_path(str(Path(__file__).with_name("candidate_motions.py")))
expected = {"idle", "walk", "attack", "cast", "hurt", "death"}
for mode in ("robe", "held", "float", "swim"):
    captured = {}
    def clip(arm, name, keys):
        assert name not in captured
        assert keys[0][0] == 1 and keys[-1][0] > 1
        assert len({frame for frame, _ in keys}) == len(keys)
        assert any(pose != keys[0][1] for _, pose in keys[1:]), (mode, name)
        if name in ("idle", "walk"):
            first, last = keys[0][1], keys[-1][1]
            for bone in first:
                if bone == "loc":
                    assert all(abs(a - b) < 1e-8 for a, b in zip(first[bone], last[bone]))
                else:
                    assert all(axis == end_axis and abs(angle - end_angle) < 1e-8
                               for (axis, angle), (end_axis, end_angle) in zip(first[bone], last[bone]))
        captured[name] = keys
        return name
    helpers = {"clip": clip, "mirror": lambda pose: {**pose, "mirrored": True},
               "X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1),
               "ROLE": {"Hips": "root", "Spine": "spine", "Head": "head", "Tail": "tail", "Tip": "tail2"},
               "spec": {"motion": mode, "prop_hand": "LeftHand", "held_pose": mode == "held"}}
    result = module["robed" if mode in ("robe", "held") else "drift"](None, helpers)
    assert set(result) == expected and set(captured) == expected
    if mode == "held":
        for name in ("attack", "cast"):
            assert any("Spine" in pose and "Head" in pose for _, pose in captured[name])
            assert all(not any("Arm" in bone for bone in pose) for _, pose in captured[name])
    print("PASS", mode, "six distinct clips; loops close")
