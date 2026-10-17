# Stack the top (3/4 view) row of each clip sheet into one review image per character.
#   blender -b --factory-startup --python montage.py -- <rig_dir> <out.png>
import bpy, os, sys
import numpy as np

rig, out = sys.argv[sys.argv.index("--") + 1:][:2]
rows = []
for c in ("idle", "walk", "attack", "cast", "hurt", "death"):
    img = bpy.data.images.load(os.path.join(rig, f"clip-{c}.png"))
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, 4)[::-1]  # top-down
    top = px[: h // 2: 2, ::2]  # 3/4-view row, half size
    rows.append(top)
m = np.concatenate(rows)[::-1]
o = bpy.data.images.new("m", m.shape[1], m.shape[0], alpha=True)
o.pixels[:] = m.ravel()
o.filepath_raw, o.file_format = out, "PNG"
o.save()
print("MONTAGE", out, m.shape)
