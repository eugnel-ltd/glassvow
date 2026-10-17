"""Make lean/contact and source inspection images without changing artwork."""
import importlib.util
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_preview', ROOT/'preview.py')
p = importlib.util.module_from_spec(s); s.loader.exec_module(p)
p.guard()
font = lambda n: ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',n)
specs=json.loads((ROOT/'build-spec.json').read_text())
for name in sys.argv[1:]:
    card=name.rsplit('-',1)[0]
    prefix=specs.get(name, specs[card]).get('source_prefix', name)
    sources=sorted(p for p in (ROOT/'sources').glob(prefix+'-*/generated.png') if prefix != name or '-relic-' not in p.parent.name)
    sheet=Image.new('RGB',(1280,470*((len(sources)+1)//2)),'#171d25')
    d=ImageDraw.Draw(sheet)
    for i,path in enumerate(sources):
        x,y=(i%2)*640,(i//2)*470
        d.text((x+12,y+8),path.parent.name,font=font(19),fill='white')
        image=Image.open(path); image.thumbnail((620,416),Image.Resampling.LANCZOS)
        sheet.paste(image,(x+10,y+40))
    sheet.save(ROOT/f'{name}-source-proof.jpg',quality=92)
    meta_path=ROOT/f'{name}-layers.json'
    if not meta_path.exists(): continue
    meta=json.loads(meta_path.read_text())
    contact=Image.open(ROOT/meta['contact_mask']).getbbox()
    cx0,cy0,cx1,cy1=contact
    box=(max(0,(cx0-160-128)//2),max(0,(cy0-120-86)//2),min(1024,(cx1+160-128)//2),min(687,(cy1+90-86)//2))
    proof=Image.new('RGB',(1536,900),'#171d25'); d=ImageDraw.Draw(proof)
    d.text((16,10),name+' | offline approximation, not the shader',font=font(23),fill='white')
    for i,lean in enumerate(('minus','zero','plus')):
        frame=Image.open(ROOT/f'{name}-lean-{lean}.jpg')
        proof.paste(frame.resize((512,376),Image.Resampling.LANCZOS),(i*512,55))
        region=frame.crop(box); region.thumbnail((500,390),Image.Resampling.LANCZOS)
        proof.paste(region,(i*512+6,470))
    proof.save(ROOT/f'{name}-contact-proof.jpg',quality=94)
print('Source and contact inspection sheets ready.')
