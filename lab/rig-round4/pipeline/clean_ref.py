# Tripo input: binarise alpha at 128 and paint transparent pixels white (no grey fringe to model).
#   blender -b --factory-startup --python clean_ref.py -- in.png [in2.png ...]   writes <in>-clean.png
import bpy, sys
import numpy as np

for path in sys.argv[sys.argv.index("--") + 1:]:
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    solid = px[..., 3] >= .5
    px[..., 3] = solid
    px[~solid, :3] = 1.0
    out = path[:-4] + "-clean.png"
    o = bpy.data.images.new("c", w, h, alpha=True)
    o.pixels = px.ravel()
    o.filepath_raw, o.file_format = out, "PNG"
    o.save()
    print("CLEAN", out, w, h, f"solid {solid.mean():.2f}")
