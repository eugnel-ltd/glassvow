# Tile images into a grid on grey, each fitted into a square cell.
#   blender -b --factory-startup --python grid.py -- <out.png> <cols> <cell_px> img1 img2 ...
import bpy, sys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out, cols, cell, paths = args[0], int(args[1]), int(args[2]), args[3:]
rows = (len(paths) + cols - 1) // cols
G = np.full((rows * cell, cols * cell, 4), (.55, .55, .55, 1.0))
for i, p in enumerate(paths):
    img = bpy.data.images.load(p)
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)[::-1]
    s = max(w, h) / cell
    ys = (np.arange(int(h / s)) * s).astype(int)
    xs = (np.arange(int(w / s)) * s).astype(int)
    small = px[ys][:, xs]
    a = small[..., 3:4]
    r, c = divmod(i, cols)
    y0, x0 = r * cell + (cell - small.shape[0]) // 2, c * cell + (cell - small.shape[1]) // 2
    tile = G[y0:y0 + small.shape[0], x0:x0 + small.shape[1]]
    tile[..., :3] = small[..., :3] * a + tile[..., :3] * (1 - a)
o = bpy.data.images.new("g", G.shape[1], G.shape[0], alpha=True)
o.pixels[:] = G[::-1].ravel()
o.filepath_raw, o.file_format = out, "PNG"
o.save()
print("GRID", out, G.shape)
