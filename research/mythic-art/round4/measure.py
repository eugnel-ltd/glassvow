"""Measure placed geometry for one card on a fine grid (inspection only)."""
import importlib.util, json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_build', ROOT/'build.py'); b = importlib.util.module_from_spec(s); s.loader.exec_module(b)
card, layer, box = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
name = f'{card}-A'
if layer == 'ground':
    g, _ = b.isolate(name+'-ground', True); g = b.resample(g, size=b.SIZE)
    a = np.asarray(g.getchannel('A'))
    rows = np.flatnonzero((a > 200).any(axis=1))
    print('ground first opaque row', rows[0], 'cols', np.flatnonzero(a[rows[0]] > 200)[[0, -1]])
    for y in map(int, sys.argv[4:]):
        cols = np.flatnonzero(a[y] > 254); print('row', y, 'opaque', cols[[0, -1]] if len(cols) else None)
    sys.exit()
img, _ = b.complete(name+'-'+layer, box)
x0, y0, x1, y1 = img.getbbox(); print('placed', (x0, y0, x1, y1))
import cv2
n, labels, stats, _ = cv2.connectedComponentsWithStats(np.uint8(np.asarray(img.getchannel('A')) > 200), 8)
for i in np.argsort(-stats[1:, cv2.CC_STAT_AREA])[:3]+1:
    c = max(cv2.findContours(np.uint8(labels == i), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)[0], key=cv2.contourArea)
    print('component', stats[i, cv2.CC_STAT_AREA], 'corners', cv2.approxPolyDP(c, .02*cv2.arcLength(c, True), True).reshape(-1, 2).tolist())
crop = img.crop((x0-20, y0-20, x1+20, y1+20)); k = 3
crop = crop.resize((crop.width*k, crop.height*k), Image.Resampling.NEAREST)
bg = Image.new('RGBA', crop.size, (40, 50, 60, 255)); bg.alpha_composite(crop)
d = ImageDraw.Draw(bg)
for gx in range((x0-20)//20*20, x1+40, 20):
    X = (gx-(x0-20))*k; d.line((X, 0, X, bg.height), fill=(255, 255, 0, 255) if gx % 100 == 0 else (90, 110, 120, 255))
    if gx % 100 == 0: d.text((X+2, 2), str(gx), fill=(255, 255, 0, 255))
for gy in range((y0-20)//20*20, y1+40, 20):
    Y = (gy-(y0-20))*k; d.line((0, Y, bg.width, Y), fill=(255, 255, 0, 255) if gy % 100 == 0 else (90, 110, 120, 255))
    if gy % 100 == 0: d.text((2, Y+2), str(gy), fill=(255, 255, 0, 255))
bg.convert('RGB').save(ROOT/f'{name}-{layer}-measure.jpg', quality=90)
