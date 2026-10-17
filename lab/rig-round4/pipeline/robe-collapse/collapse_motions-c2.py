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
    "floor": {"solid": 0.004, "cloth": 0.012, "prop": 0.004, "prop_centre": 0.12},
    "capsule": {"thigh": 0.085, "shin": 0.065, "torso": 0.15},
    "drape": {"hang": 0.75, "stiffness": 300.0, "damping": 24.0, "gravity": 0.0, "compress": 0.6},
    "motion": {
        # Pelvis: recoil, buckle (gravity ease-in), knee strike and rebound, then the topple about
        # the left knee (roll, below), a shoulder strike, a bounce and a settle.
        "hips_loc": [(1, [0, 0, 0], "lin"), (4, [0, .02, .008], "out"), (8, [.004, .014, -.03], "in"),
                     (13, [.03, -.02, -.2], "in"), (17, [.05, -.05, -.4], "in"), (19, [.055, -.06, -.445], "in"),
                     (21, [.055, -.06, -.432], "out"), (23, [.058, -.062, -.445], "io"),
                     (30, [.058, -.062, -.46], "lin"), (34, [.058, -.062, -.63], "in"),
                     (36, [.058, -.062, -.6], "out"), (39, [.058, -.062, -.635], "io"),
                     (48, [.058, -.062, -.64], "io")],
        "roll": {"start": 23, "axis": [0, 1, 0], "support": "LeftLowerLeg"},
        "fk": {
            "Hips": [(1, [0, 0, 0], "lin"), (4, [-4, 0, 0], "out"), (8, [-2, 2, 1], "in"), (13, [6, 6, 4], "in"),
                     (19, [11, 10, 5], "in"), (23, [12, 12, 5], "io"), (27, [15, 26, 5], "in"),
                     (30, [12, 48, 5], "in"), (33, [10, 78, 5], "in"), (36, [10, 74, 5], "out"),
                     (40, [10, 77, 5], "io"), (48, [10, 77, 5], "io")],
            "Spine": [(1, [0, 0, 0], "lin"), (4, [-4, 0, 0], "out"), (10, [-7, -2, 0], "io"), (17, [3, 0, 0], "in"),
                      (21, [10, 3, 0], "io"), (26, [14, 6, -2], "io"), (31, [11, 6, -3], "in"), (35, [10, 3, -3], "out"),
                      (48, [10, 4, -3], "io")],
            "Chest": [(1, [0, 0, 0], "lin"), (5, [-6, 0, 0], "out"), (11, [-5, -2, 0], "io"), (18, [2, 0, 0], "in"),
                      (22, [10, 2, 0], "io"), (27, [14, 8, -3], "io"), (32, [10, 10, -4], "in"), (36, [9, 6, -4], "out"),
                      (48, [9, 7, -4], "io")],
            "UpperChest": [(1, [0, 0, 0], "lin"), (5, [-4, 0, 0], "out"), (12, [-3, -2, 0], "io"), (19, [0, 0, 0], "in"),
                           (23, [6, 0, 0], "io"), (28, [10, 6, -2], "io"), (33, [7, 8, -3], "in"), (37, [6, 4, -3], "out"),
                           (48, [6, 5, -3], "io")],
            "Neck": [(1, [0, 0, 0], "lin"), (5, [-5, 0, 0], "out"), (12, [-3, -2, 0], "io"), (20, [6, -2, 0], "io"),
                     (27, [10, -8, 0], "io"), (32, [8, -6, 0], "io"), (35, [8, 10, 0], "in"), (38, [8, 6, 0], "out"),
                     (48, [8, 8, 0], "io")],
            "Head": [(1, [0, 0, 0], "lin"), (5, [-13, 0, 0], "out"), (12, [-9, -2, 0], "io"), (18, [3, 0, 0], "io"),
                     (22, [14, 0, 0], "in"), (27, [14, -12, 0], "io"), (32, [12, -10, 4], "io"),
                     (35, [10, 20, 6], "in"), (38, [10, 14, 6], "out"), (42, [10, 18, 6], "io"), (48, [10, 17, 6], "io")],
            "LeftShoulder": [(1, [0, 0, 0], "lin"), (20, [0, -4, 0], "io"), (30, [0, 6, 0], "io"), (48, [0, 6, 0], "io")],
            "LeftUpperArm": [(1, [0, 0, 0], "lin"), (5, [-8, -12, 0], "out"), (12, [-22, -18, 0], "io"),
                             (19, [-40, -30, 0], "io"), (48, [-40, -30, 0], "io")],
            "LeftLowerArm": [(1, [0, 0, 0], "lin"), (5, [-10, 0, 0], "out"), (12, [-20, 0, 0], "io"),
                             (19, [-12, 0, 0], "io"), (48, [-12, 0, 0], "io")],
            "RightUpperArm": [(1, [0, 0, 0], "lin"), (4, [-25, 0, 0], "out"), (12, [-10, 8, 0], "io"),
                              (20, [-15, 15, 0], "io"), (26, [-45, 25, 0], "io"), (31, [-70, 30, 0], "io"),
                              (48, [-70, 30, 0], "io")],
            "RightLowerArm": [(1, [0, 0, 0], "lin"), (4, [-20, 0, 0], "out"), (12, [-30, 0, 0], "io"),
                              (26, [-20, 0, 0], "io"), (31, [-25, 0, 0], "io"), (48, [-25, 0, 0], "io")],
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
        # the elbow gives as the shoulder comes down onto it. The lantern arm swings over the top
        # and its hand lands in front of the chest with a small bounce.
        "arms": {
            "Left": {"ik": [(1, [0], "lin"), (20, [0], "lin"), (26, [1], "io"), (48, [1], "lin")],
                     "target": [(1, [.78, -.34, .05], "lin"), (28, [.78, -.34, .05], "lin"), (34, [.98, -.62, .05], "out"),
                                (48, [.98, -.62, .05], "lin")],
                     "pole": [.25, .8, .55], "pole_world": True, "plant": True},
            "Right": {"ik": [(1, [0], "lin"), (30, [0], "lin"), (35, [1], "in"), (48, [1], "lin")],
                      "target": [(1, [.6, -.8, .3], "lin"), (31, [.6, -.8, .3], "lin"), (35, [.72, -.9, .05], "in"),
                                 (38, [.72, -.9, .085], "out"), (42, [.72, -.9, .05], "io"), (48, [.72, -.9, .05], "lin")],
                      "pole": [-.2, .4, -.8]},
        },
    },
}

CONFIG = {"unlitSelf": UNLIT}
