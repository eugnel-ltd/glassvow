# Per-character staged collapse settings for collapse.py. Angles in degrees about world axes
# (char_rig convention: +X bows an upright bone forward, -X swings a hanging limb forward,
# +Y leans the top toward the character's left (+x)). Positions in metres, armature space.
# Track keys: (frame, value, ease into this key): lin, in (gravity), out (impact), io.

UNLIT = {
    "length": 48,
    "chains": 8,
    "keep_feet": False,
    "shoe_radius": (0.045, 0.08),
    "prop_hand": "RightHand",
    "prop_mode": "hang",
    "prop_damping": 3.0,
    "substeps": 4,
    "floor": {"solid": 0.004, "cloth": 0.012, "prop": 0.012, "prop_centre": 0.12},
    "capsule": {"thigh": 0.085, "shin": 0.065, "torso": 0.15},
    "drape": {"hang": 0.75, "stiffness": 300.0, "damping": 24.0, "gravity": 0.0, "compress": 0.6,
              "lie": (25, 38), "lie_tilt": 8, "bell": 25, "flatten": (0.3, 0.55), "spread": (0.2, -0.25), "fold": 25},
    "motion": {
        # Pelvis: recoil, buckle (gravity ease-in), knee strike and rebound, then the topple about
        # the left knee (roll, below), a shoulder strike, a bounce and a settle.
        "hips_loc": [(1, [0, 0, 0], "lin"), (4, [0, .02, .008], "out"), (8, [.004, .014, -.03], "in"),
                     (13, [.03, -.02, -.2], "in"), (17, [.05, -.05, -.4], "in"), (19, [.055, -.06, -.445], "in"),
                     (21, [.055, -.06, -.432], "out"), (23, [.058, -.062, -.445], "io"),
                     (30, [.058, -.062, -.46], "lin"), (34, [.058, -.062, -.63], "in"),
                     (36, [.058, -.062, -.62], "out"), (39, [.058, -.062, -.635], "io"),
                     (48, [.058, -.062, -.64], "io")],
        "roll": {"start": 23, "axis": [0, 1, 0], "support": "LeftLowerLeg"},
        "fk": {
            # Hips carry the roll; the trunk leads the topple (each of Spine, Chest and UpperChest takes an
            # equal share of the curl) and settles so the head lies along the body, hood on the floor.
            "Hips": [(1, [0, 0, 0], "lin"), (4, [-4, 0, 0], "out"), (8, [2, 3, 1], "io"), (13, [7, 6, 4], "in"),
                     (19, [10, 9, 5], "in"), (23, [11, 11, 5], "io"), (27, [12, 22, 5], "in"),
                     (30, [11, 42, 5], "in"), (33, [10, 72, 5], "in"), (36, [10, 69, 5], "out"),
                     (40, [10, 72, 5], "io"), (48, [10, 72, 5], "io")],
            # From f6 the head and shoulders drop forward and sag to the left: the support loss reads
            # from the front while the knees buckle under the robe.
            "Spine": [(1, [0, 0, 0], "lin"), (4, [-3, 0, 0], "out"), (6, [0, 1, 0], "io"), (10, [5, 3, 0], "in"),
                      (14, [6, 3, 0], "io"), (18, [4, 2, 0], "io"), (22, [6, 3, 0], "io"), (26, [7, 8, -1], "io"),
                      (30, [8, 10, -2], "in"), (34, [7, 6, -2], "out"), (48, [6, 5, -2], "io")],
            "Chest": [(1, [0, 0, 0], "lin"), (5, [-4, 0, 0], "out"), (7, [1, 1, 0], "io"), (11, [6, 3, 0], "in"),
                      (15, [7, 3, 0], "io"), (19, [4, 2, 0], "io"), (23, [6, 3, 0], "io"), (27, [8, 9, -2], "io"),
                      (31, [8, 11, -3], "in"), (35, [7, 6, -3], "out"), (48, [6, 5, -3], "io")],
            "UpperChest": [(1, [0, 0, 0], "lin"), (5, [-3, 0, 0], "out"), (8, [2, 1, 0], "io"), (12, [6, 3, 0], "in"),
                           (16, [7, 3, 0], "io"), (20, [4, 2, 0], "io"), (24, [6, 3, 0], "io"), (28, [8, 9, -2], "io"),
                           (32, [8, 11, -3], "in"), (36, [7, 6, -3], "out"), (48, [6, 5, -3], "io")],
            "Neck": [(1, [0, 0, 0], "lin"), (5, [-4, 0, 0], "out"), (8, [5, 0, 0], "io"), (12, [8, -2, 0], "in"),
                     (20, [6, -3, 0], "io"), (27, [6, -6, 0], "io"), (32, [-8, 3, 8], "io"), (35, [-20, 12, 20], "in"),
                     (38, [-18, 10, 18], "out"), (48, [-20, 12, 20], "io")],
            "Head": [(1, [0, 0, 0], "lin"), (5, [-10, 0, 0], "out"), (8, [4, -1, 0], "io"), (12, [12, -3, 0], "in"),
                     (18, [8, -2, 0], "io"), (22, [10, 0, 0], "in"), (27, [10, -10, 0], "io"), (32, [-12, 3, 8], "io"),
                     (35, [-35, 22, 15], "in"), (38, [-31, 18, 13], "out"), (42, [-34, 21, 15], "io"), (48, [-35, 22, 15], "io")],
            "LeftShoulder": [(1, [0, 0, 0], "lin"), (6, [0, 2, 0], "io"), (10, [0, 6, 0], "in"), (20, [0, -4, 0], "io"),
                             (30, [0, 6, 0], "io"), (48, [0, 6, 0], "io")],
            "RightShoulder": [(1, [0, 0, 0], "lin"), (6, [0, -2, 0], "io"), (10, [0, -6, 0], "in"), (24, [0, -3, 0], "io"),
                              (48, [0, -3, 0], "io")],
            "LeftUpperArm": [(1, [0, 0, 0], "lin"), (5, [-8, -12, 0], "out"), (12, [-22, -18, 0], "io"),
                             (19, [-40, -30, 0], "io"), (48, [-40, -30, 0], "io")],
            "LeftLowerArm": [(1, [0, 0, 0], "lin"), (5, [-10, 0, 0], "out"), (12, [-20, 0, 0], "io"),
                             (19, [-12, 0, 0], "io"), (48, [-12, 0, 0], "io")],
            # The lantern arm swings out for balance (no early raise), stays low and folds in front of the chest.
            "RightUpperArm": [(1, [0, 0, 0], "lin"), (4, [-10, 4, 0], "out"), (9, [-6, 12, 0], "io"), (14, [-8, 14, 0], "io"),
                              (20, [-15, 15, 0], "io"), (26, [-28, 18, 0], "io"), (31, [-38, 22, 0], "io"),
                              (48, [-38, 22, 0], "io")],
            "RightLowerArm": [(1, [0, 0, 0], "lin"), (4, [-12, 0, 0], "out"), (12, [-20, 0, 0], "io"),
                              (26, [-38, 0, 0], "io"), (31, [-48, 0, 0], "io"), (48, [-48, 0, 0], "io")],
        },
        # Legs: 2-bone IK. The left knee gives first; the feet stay planted, then roll onto the toes and
        # slide back as the knees strike; after the strike the folded legs ride with the pelvis.
        "legs": {
            "Left": {"ankle": [(1, [.175, -.1, .108], "lin"), (7, [.175, -.1, .108], "lin"),
                               (17, [.19, .06, .15], "in"), (48, [.19, .06, .15], "lin")],
                     "point": [(1, [0], "lin"), (8, [0], "lin"), (17, [1], "io"), (48, [1], "lin")],
                     "ride": (21, 25), "min_ankle_z": .06, "pole": [.15, -1, 0],
                     "ik": [(1, [0], "lin"), (6, [1], "io")], "soft": .05},
            "Right": {"ankle": [(1, [-.187, -.087, .108], "lin"), (9, [-.187, -.087, .108], "lin"),
                                (19, [-.17, .05, .15], "in"), (48, [-.17, .05, .15], "lin")],
                      "point": [(1, [0], "lin"), (10, [0], "lin"), (19, [1], "io"), (48, [1], "lin")],
                      "ride": (21, 25), "min_ankle_z": .06, "pole": [-.15, -1, 0],
                      "ik": [(1, [0], "lin"), (6, [1], "io")], "soft": .05},
        },
        # Arms: the free left hand reaches for the floor out-left-front and plants (fixed world target);
        # the elbow gives as the shoulder comes down onto it. The lantern hand comes down in front of
        # the chest with a small bounce; it never passes over the head.
        "arms": {
            "Left": {"ik": [(1, [0], "lin"), (20, [0], "lin"), (26, [1], "io"), (48, [1], "lin")],
                     "target": [(1, [.78, -.34, .05], "lin"), (28, [.78, -.34, .05], "lin"), (34, [.72, -.72, .05], "out"),
                                (48, [.72, -.72, .05], "lin")],
                     "pole": [.25, .8, .55], "pole_world": True, "plant": True},
            "Right": {"ik": [(1, [0], "lin"), (26, [0], "lin"), (32, [1], "io"), (48, [1], "lin")],
                      "target": [(1, [.35, -.72, .35], "lin"), (26, [.35, -.72, .35], "lin"), (32, [.62, -.7, .16], "in"),
                                 (36, [.68, -.72, .09], "out"), (42, [.68, -.72, .07], "io"), (48, [.68, -.72, .07], "lin")],
                      "pole": [-.2, .4, -.8]},
        },
    },
}

# Unobsidian: a slower knee buckle, then a sharper shoulder roll and a late free-hand catch.
# Build weights from its own geometry. The staff stays rigid and rotates about its hand grip.
from copy import deepcopy
UNOBSIDIAN = deepcopy(UNLIT)
UNOBSIDIAN["length"] = 56
UNOBSIDIAN["sleeve_ownership"] = (.08, .4)
UNOBSIDIAN["prop_mode"] = "staff"
UNOBSIDIAN["floor"]["prop"] = .035
motion = UNOBSIDIAN["motion"]
def later(f):
    return round(1 + (f - 1) * 55 / 47)
for key in ("hips_loc",):
    motion[key] = [(later(f), v, e) for f, v, e in motion[key]]
for bone, keys in motion["fk"].items():
    motion["fk"][bone] = [(later(f), v, e) for f, v, e in keys]
for side in motion["legs"].values():
    for key in ("ankle", "point", "ik"):
        side[key] = [(later(f), v, e) for f, v, e in side[key]]
    side["ride"] = tuple(later(f) for f in side["ride"])
for side in motion["arms"].values():
    for key in ("ik", "target"):
        side[key] = [(later(f), v, e) for f, v, e in side[key]]
motion["roll"]["start"] = later(motion["roll"]["start"])
motion["fk"]["Hips"] = [(f, [v[0], v[1] * 1.08, v[2] - 8 * min(max((f - 25) / 15, 0), 1)], e) for f, v, e in motion["fk"]["Hips"]]
UNOBSIDIAN["drape"]["lie"] = (29, 44)
motion["arms"]["Left"]["target"] = [(f, [.69, -.55, .05] if f >= 40 else v, e) for f, v, e in motion["arms"]["Left"]["target"]]
# The long staff needs a raised wrist while the body settles; keep its grip above the staff's thickness.
motion["arms"]["Right"]["target"] = [(f, [v[0], v[1], max(v[2], .30)] if f >= 31 else v, e) for f, v, e in motion["arms"]["Right"]["target"]]
CONFIG = {"unobsidianSelf": UNOBSIDIAN}
