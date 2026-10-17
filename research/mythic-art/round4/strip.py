"""Contact strip of generated sources for one candidate prefix (inspection only)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parent
prefix = sys.argv[1]
paths = sorted((ROOT/'sources').glob(prefix+'-*/generated.png'))
font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
im = Image.new('RGB', (630*3, 450*((len(paths)+2)//3)), '#171d25')
d = ImageDraw.Draw(im)
for i, p in enumerate(paths):
    s = Image.open(p).convert('RGB'); s.thumbnail((620, 413))
    x, y = (i%3)*630, (i//3)*450
    im.paste(s, (x, y+30)); d.text((x+4, y+6), f'{p.parent.name} {Image.open(p).size}', font=font, fill='white')
im.save(ROOT/f'{prefix}-strip.jpg', quality=88)
