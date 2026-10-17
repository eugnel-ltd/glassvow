# Candidate motion sets for continuous robes and floating or swimming creatures.
import math


def robed(arm, helpers):
    clip, side = helpers["clip"], helpers["mirror"]
    x, y, z = helpers["X"], helpers["Y"], helpers["Z"]
    spec = helpers["spec"]
    handed = (lambda pose: pose) if spec.get("prop_hand", "LeftHand") == "LeftHand" else side
    rest = {}
    breathe = {"Hips": [(x, 1)], "loc": (0, 0, -.002)}
    step = {"Hips": [(y, 2)], "LeftUpperArm": [(x, 5)], "RightUpperArm": [(x, -5)]}
    cast = handed({"LeftUpperArm": [(x, -35)], "LeftLowerArm": [(x, -10)], "Hips": [(x, -4)]})
    wind = handed({"LeftUpperArm": [(x, 15)], "Hips": [(z, 8)]})
    hit = handed({"LeftUpperArm": [(x, -35)], "LeftLowerArm": [(x, -8)], "Hips": [(z, -8)], "loc": (0, -.035, 0)})
    hurt = {"Hips": [(x, -7)], "loc": (0, .025, 0)}
    sag = {"Hips": [(x, 16)], "loc": (0, 0, -.02)}
    down = {"Hips": [(x, 82)], "loc": (0, -.08, -.08)}
    if spec.get("held_pose"):
        breathe["Head"] = [(x, -2)]
        cast = {"Spine": [(x, -6)], "Head": [(x, -4)], "Hips": [(x, -2)]}
        wind = {"Spine": [(x, -4)], "Hips": [(z, 5)]}
        hit = {"Spine": [(x, 6)], "Head": [(x, 4)], "Hips": [(z, -5)], "loc": (0, -.035, 0)}
    return [clip(arm, "idle", [(1, rest), (30, breathe), (60, rest)]),
            clip(arm, "walk", [(1, step), (8, rest), (16, side(step)), (24, rest), (32, step)]),
            clip(arm, "attack", [(1, rest), (9, wind), (14, hit), (20, hit), (32, rest)]),
            clip(arm, "cast", [(1, rest), (10, cast), (22, cast), (32, rest)]),
            clip(arm, "hurt", [(1, rest), (5, hurt), (16, rest)]),
            clip(arm, "death", [(1, rest), (14, sag), (30, down), (40, down)])]


def drift(arm, helpers):
    clip, roles = helpers["clip"], helpers["ROLE"]
    x, y, z = helpers["X"], helpers["Y"], helpers["Z"]
    swim = helpers["spec"]["motion"] == "swim"
    result = []
    for name, end in (("idle", 60), ("walk", 32), ("attack", 32), ("cast", 32), ("hurt", 16), ("death", 40)):
        keys = []
        for index in range(9):
            fraction = index / 8
            phase = fraction * math.tau
            pulse = math.sin(math.pi * fraction) ** 2
            fall = min(1.0, fraction * 1.4) if name == "death" else 0.0
            amplitude = (10 if name == "walk" else 3) * (1 - fall)
            pose = {"loc": (0, -.14 * pulse if name == "attack" else 0,
                            .09 + .012 * math.sin(phase) - .08 * fall)}
            for bone, role in roles.items():
                if role == "root":
                    pose[bone] = [(y, 85 * fall + (2 * math.sin(phase) if not swim else 0))]
                elif role == "spine":
                    pose[bone] = [(z if swim else x, amplitude * .3 * math.sin(phase))]
                elif role == "head":
                    pose[bone] = [(x, 18 * pulse if name == "attack" else -12 * pulse if name == "cast" else -8 * pulse if name == "hurt" else 0)]
                elif role.startswith("tail") or role == "sway":
                    pose[bone] = [(z if swim else y, amplitude * math.sin(phase - (0.8 if role == "tail2" else 0)))]
                elif role.startswith("arm"):
                    sign = 1 if "L" in role else -1
                    pose[bone] = [(y, sign * (8 * math.sin(phase) + (20 * pulse if name == "cast" else 0)))]
            keys.append((round(1 + (end - 1) * fraction), pose))
        result.append(clip(arm, name, keys))
    return result
