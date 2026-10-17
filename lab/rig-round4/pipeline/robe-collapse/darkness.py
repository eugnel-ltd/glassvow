# Unshaded darkness test: dark pixels (luminance < 30) on the figure, shaded against albedo-only captures.
#   python3 darkness.py <shaded-dir> <unshaded-dir>
import sys
import numpy as np
from PIL import Image
from pathlib import Path
lum = lambda x: .2126 * x[..., 0] + .7152 * x[..., 1] + .0722 * x[..., 2]
shaded, unshaded = map(Path, sys.argv[1:3])
rows = []
for f in sorted(shaded.glob("*/frame-*.png")):
    a = np.asarray(Image.open(f).convert("RGB")).astype(int)
    u = np.asarray(Image.open(unshaded / f.parent.name / f.name).convert("RGB")).astype(int)
    fig = ((u[..., 2] - u[..., 0]) < 12) | (np.abs(a - u).sum(2) > 6) | (lum(u) < 60)  # the background is blue-grey and lit
    ds, du = (lum(a) < 30) & fig, (lum(u) < 30) & fig
    rows.append((int(f.stem[-4:]), int(fig.sum()), int(ds.sum()), int(du.sum()), int((ds & ~du).sum())))
r = np.array(rows, dtype=float)
share = r[:, 4] / np.maximum(r[:, 1], 1)
print(f"{shaded.name}: figure px mean {r[:, 1].mean():.0f}; dark shaded {r[:, 2].sum() / r[:, 1].sum():.4f}, dark albedo {r[:, 3].sum() / r[:, 1].sum():.4f}, "
      f"dark only when shaded {r[:, 4].sum() / r[:, 1].sum():.4f} (worst frame {share.max():.4f} at {int(r[share.argmax(), 0])})")
