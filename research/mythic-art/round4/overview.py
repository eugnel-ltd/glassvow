"""Full-size side-by-side set, native thumbnail strip and compact view; adds the B row once every B flat exists."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import importlib.util
ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_preview', ROOT/'preview.py')
p = importlib.util.module_from_spec(s); s.loader.exec_module(p)
p.guard()
CARDS = ['bankedFire','silvering','unbrokenFlame','unbowed','knownRoad','cleanBreak']
LETTERS = 'AB' if all((ROOT/f'{c}-B-flat.jpg').exists() for c in CARDS) else 'A'
font = lambda n: ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',n)
full = Image.new('RGB',(6*2080+32,1810*len(LETTERS)),'#171d25')
d = ImageDraw.Draw(full)
small = Image.new('RGB',(6*176+24,64+190*len(LETTERS)),'#171d25')
sd = ImageDraw.Draw(small)
compact = Image.new('RGB',(1632,840*len(LETTERS)),'#171d25')
cd = ImageDraw.Draw(compact)
for r, letter in enumerate(LETTERS):
    for i,card in enumerate(CARDS):
        name = f'{card}-{letter}'
        x, y = 24+i*2080, r*1810
        d.text((x,y+14),name+' | offline approximation, not the shader',font=font(26),fill='white')
        full.paste(Image.open(ROOT/f'{name}-flat.jpg'),(x,y+60))
        d.text((x,y+1450),'Native 64 px read / 148 x 91 crop',font=font(22),fill='white')
        full.paste(Image.open(ROOT/f'{name}-64.png'),(x,y+1490))
        full.paste(Image.open(ROOT/f'{name}-148.png'),(x+100,y+1490))
        for j,lean in enumerate(('minus','zero','plus')):
            frame=Image.open(ROOT/f'{name}-lean-{lean}.jpg')
            frame.thumbnail((300,221),Image.Resampling.LANCZOS)
            full.paste(frame,(x+400+j*320,y+1490))
        sx, sy = 16+i*176, r*190
        sd.text((sx,sy+8),name,font=font(16),fill='white')
        small.paste(Image.open(ROOT/f'{name}-64.png'),(sx,sy+40))
        small.paste(Image.open(ROOT/f'{name}-148.png'),(sx,sy+114))
        cx, cy = 16+(i%3)*544, r*840+12+(i//3)*420
        cd.text((cx,cy),name,font=font(23),fill='white')
        image=Image.open(ROOT/f'{name}-flat.jpg'); image.thumbnail((520,349),Image.Resampling.LANCZOS)
        compact.paste(image,(cx,cy+36))
        compact.paste(Image.open(ROOT/f'{name}-64.png'),(cx+450,cy+373))
full.save(ROOT/'set-overview.jpg',quality=88)
sd.text((16,small.height-27),'offline approximation, not the shader',font=font(16),fill='white')
cd.text((16,compact.height-27),'offline approximation, not the shader',font=font(18),fill='white')
small.save(ROOT/'set-small.png')
compact.save(ROOT/'set-compact.jpg',quality=94)
print(f'Overview ready for {LETTERS}.')
