"""Full-resolution crop of the composed objects with a fine grid, for exact focal coordinates."""
import importlib.util, json, sys
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_build', ROOT/'build.py'); b = importlib.util.module_from_spec(s); s.loader.exec_module(b)
name, x0, y0, x1, y1 = sys.argv[1], *map(int, sys.argv[2:6])
spec = json.loads((ROOT/'build-spec.json').read_text())[name]
canvas = Image.new('RGBA', b.SIZE, (40, 40, 40, 255))
for obj in spec['physical']:
    canvas.alpha_composite(b.complete(name+'-'+obj['source'], obj['box'], obj.get('rotate', 0))[0])
crop = canvas.crop((x0, y0, x1, y1)).convert('RGB'); d = ImageDraw.Draw(crop)
for x in range(x0 - x0 % 50 + 50, x1, 50): d.line((x-x0, 0, x-x0, y1-y0), fill=(0, 255, 120) if x % 100 == 0 else (0, 110, 60)); x % 100 == 0 and d.text((x-x0+2, 2), str(x), fill='white')
for y in range(y0 - y0 % 50 + 50, y1, 50): d.line((0, y-y0, x1-x0, y-y0), fill=(0, 255, 120) if y % 100 == 0 else (0, 110, 60)); y % 100 == 0 and d.text((2, y-y0+2), str(y), fill='white')
crop.save(ROOT/f'{name}-zoom-grid.jpg', quality=92)
