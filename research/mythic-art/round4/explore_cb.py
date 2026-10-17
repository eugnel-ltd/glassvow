"""Compare Clean Break relic layouts: relic box, seam and sword placement (inspection only)."""
import importlib.util, sys, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageOps
ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_build', ROOT/'build.py')
b = importlib.util.module_from_spec(s); s.loader.exec_module(b)
prefix = sys.argv[1]
layouts = json.loads(sys.argv[2])
back = ImageOps.fit(b.source(prefix+'-back'), b.SIZE, Image.Resampling.LANCZOS).convert('RGBA')
ground, _ = b.isolate(prefix+'-ground', True); ground = b.resample(ground, size=b.SIZE)
pane_src, _ = b.isolate(prefix+'-pane'); blade_src, _ = b.isolate(prefix+'-blade')
print('pane src', pane_src.size, 'blade src', blade_src.size)
sheet = Image.new('RGB', (1024*len(layouts), 700), '#171d25')
for i, L in enumerate(layouts):
    c = back.copy(); c.alpha_composite(ground)
    pane = b.place(pane_src, L['pane']); c.alpha_composite(pane)
    blade, _ = b.complete(prefix+'-blade', L['blade'], L.get('rotate', 0))
    c.alpha_composite(b.lifted_shadow(blade))
    d = ImageDraw.Draw(c)
    d.line(L['seam'], fill=(240, 252, 255, 255), width=8)
    print(i, 'pane', pane.getbbox(), 'blade', blade.getbbox())
    w = c.crop(b.WINDOW).convert('RGB').resize((1024, 687))
    sheet.paste(w, (i*1024, 0))
sheet.save(ROOT/f'{prefix}-explore.jpg', quality=88)
