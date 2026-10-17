"""Local design preview: posed surface samples splatted per piece (fillers dark), from the front
three-quarter, the side and the back, with a ground line.
   python3 -I preview_local.py clip frame [frame ...]"""
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from explore import png, PALETTE  # noqa: E402
import round4_segments as seg  # noqa: E402
import gravewarden_round4_motion as mo  # noqa: E402

d = np.load(HERE / "gravewarden-fit.npz")
co, tris = d["p"], d["f"]
lab = np.load(HERE / "gravewarden-fit-labels.npy")
m = seg.measure(co, tris)
body = mo.Body(co, tris, lab, m)
rng = np.random.default_rng(1)
a, b = rng.random((2, len(tris), 6, 1))
flip = a + b > 1
a[flip], b[flip] = 1 - a[flip], 1 - b[flip]
P = co[tris]
dense = (P[:, None, 0] + a * (P[:, None, 1] - P[:, None, 0]) + b * (P[:, None, 2] - P[:, None, 0])).reshape(-1, 3)
view = mo.Body(co, tris, lab, m)
view.p = np.vstack([dense, body.p[body.ball]])
view.bone = np.concatenate([np.repeat(np.array(seg.PIECES)[lab], 6), body.bone[body.ball]])
view.ball = np.r_[np.zeros(len(dense), bool), np.ones(int(body.ball.sum()), bool)]
colour = {n: PALETTE[i % len(PALETTE)] for i, n in enumerate(seg.PIECES)}


def panel(q, name, px=95, size=300, width=400):
    if name == "front":
        yaw = np.radians(35)
        u = q[:, 0] * np.cos(yaw) - q[:, 1] * np.sin(yaw)
        depth = q[:, 0] * np.sin(yaw) + q[:, 1] * np.cos(yaw)
    elif name == "side":  # from +X, front to the left
        u, depth = q[:, 1], -q[:, 0]
    else:  # back
        u, depth = -q[:, 0], -q[:, 1]
    v = q[:, 2]
    img = np.full((size, width, 3), 50, np.uint8)
    gy = size - 20
    img[gy:, :] = 70
    o = np.argsort(-depth)
    x = (width * (.62 if name != "back" else .5) + u[o] * px).astype(int)  # room for the forward fall
    y = (gy - v[o] * px).astype(int)
    shade = np.clip(1 - (depth[o] - depth.min()) / max(np.ptp(depth), 1e-6) * .6, .35, 1)[:, None]
    col = np.array([colour.get(bn, [40, 40, 40]) for bn in view.bone[o]], float)
    col[view.ball[o]] = [25, 25, 25]
    ok = (x >= 0) & (x < width - 1) & (y >= 0) & (y < size - 1)
    for dx in (0, 1):
        for dy in (0, 1):
            img[y[ok] + dy, x[ok] + dx] = (col[ok] * shade[ok]).astype(np.uint8)
    return img


if __name__ == "__main__":
    name, frames = sys.argv[1], [int(f) for f in sys.argv[2:]]
    vol = mo.Volumes(body)
    clip = mo.death(body, vol) if name == "death" else mo.walk(body, vol) if name == "walk" else mo.clips(body)[name]
    rows = []
    for v in ("front", "side", "back"):
        rows.append(np.concatenate([panel(view.posed(clip.pose(f)), v) for f in frames], 1))
    png(HERE / f"local-{name}.png", np.concatenate(rows, 0))
    print(name, frames)
