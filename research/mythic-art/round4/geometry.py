"""Place generated objects over their own world, with a canvas grid, before fixing the build boxes."""
import importlib.util
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont, ImageOps
ROOT=Path(__file__).resolve().parent
s=importlib.util.spec_from_file_location('lane_build',ROOT/'build.py')
b=importlib.util.module_from_spec(s); s.loader.exec_module(b)
specs=json.loads((ROOT/'build-spec.json').read_text())
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
for name in sys.argv[1:]:
    card=name.rsplit('-',1)[0]
    spec=specs.get(name, specs[card])
    prefix=spec.get('source_prefix', name)
    canvas=ImageOps.fit(b.source(prefix+'-back'),b.SIZE,Image.Resampling.LANCZOS).convert('RGBA')
    ground,_=b.isolate(prefix+'-ground',True)
    ground=b.resample(ground,size=b.SIZE)
    if any(k in spec for k in ('ground_dy','ground_dx','ground_sy')):
        ground=b.resample(ground,matrix=((1,0,spec.get('ground_dx',0)),(0,spec.get('ground_sy',1),spec.get('ground_dy',0))))
    canvas.alpha_composite(ground)
    for obj in spec['physical']:
        image,proof=b.complete(prefix+'-'+obj['source'],obj['box'],obj.get('rotate',0))
        canvas.alpha_composite(image)
        print(name,obj['source'],'placed',image.getbbox(),'source',proof['source_size'],proof['source_bounds'])
    if card=='silvering' and 'double_box' in spec:
        image,_=b.complete(prefix+'-'+spec.get('double_source','double'),spec['double_box'])
        canvas.alpha_composite(image)
        print(name,'double placed',image.getbbox())
    canvas=canvas.convert('RGB').resize((1152,773))
    d=ImageDraw.Draw(canvas)
    d.rectangle((64,43,1088,730),outline=(255,80,80))
    for x in range(0,2304,200):
        d.line((x//2,0,x//2,773),fill=(85,105,112)); d.text((x//2+3,5),str(x),font=font,fill='white')
    for y in range(200,1546,200):
        d.line((0,y//2,1152,y//2),fill=(85,105,112)); d.text((5,y//2+3),str(y),font=font,fill='white')
    canvas.save(ROOT/f'{name}-geometry.jpg',quality=94)
