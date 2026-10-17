"""Validate candidate dimensions, media, contact lock and new world sources."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import math
from PIL import Image

ROOT = Path(__file__).resolve().parent
results = []
source_hashes, layer_hashes = {}, {}
for name in sys.argv[1:]:
    card = name.rsplit('-', 1)[0]
    meta = json.loads((ROOT/f'{name}-layers.json').read_text())
    checks = json.loads((ROOT/f'{name}-checks.json').read_text())
    contact = json.loads((ROOT/f'{name}-contact-lock.json').read_text())
    mp4 = ROOT/f'{name}-motion.mp4'
    probe = json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=codec_name,width,height,r_frame_rate,nb_frames:format=duration','-of','json',str(mp4)]))
    stream = probe['streams'][0]
    assert stream['codec_name'] == 'h264' and stream['width'] == 1024
    assert abs(float(probe['format']['duration'])-4) < .05 and stream['nb_frames'] == '96'
    subprocess.run(['ffmpeg','-v','error','-xerror','-threads','2','-i',str(mp4),'-f','null','-'],check=True)
    gif = ROOT/f'{name}-motion.gif'
    with Image.open(gif) as im:
        assert im.width == 640 and gif.stat().st_size <= 5_000_000
        duration = 0
        for i in range(im.n_frames):
            im.seek(i); im.load(); duration += im.info.get('duration',0)
        assert im.n_frames == 24 and duration == 4000
        gif_info = dict(size=im.size, frames=im.n_frames, duration_ms=duration, bytes=gif.stat().st_size)
    assert Image.open(ROOT/f'{name}-flat.jpg').size == (2048,1374)
    for entry in meta['layers']:
        image = Image.open(ROOT/entry['file'])
        assert image.size == (2304,1546)
        assert image.mode == ('RGB' if entry['role']=='back' else 'L' if entry['role']=='emission-mask' else 'RGBA')
        bound = abs(entry['depth_px'])
        if meta['card']=='unbowed' and entry['role'] in ('back','front'):
            angle = math.radians(meta['world_tilt_degrees'])
            px, py = meta['pivot']
            x0,y0,x1,y1 = entry['bounds']
            rotational = max(abs((x-px)*(math.cos(angle)-1)+(y-py)*math.sin(angle)) for x in (x0,x1) for y in (y0,y1))
            bound += rotational
        elif entry['role']=='particles':
            bound += 12
        elif entry['role']=='double':
            bound += entry['lag_px']
        elif entry['role']=='shard':
            bound += 34
        elif entry['role']=='ground' and meta['ground_method']=='shear ground':
            bound = 90
        elif entry['role']=='door-shadow':
            bound += .16*110
        assert bound <= 123, f'{name}/{entry["key"]}: total horizontal travel {bound:.2f}'
        if entry['role'] in ('back','ground','front'):
            key = name+'/'+entry['role']
            source_path = ROOT/'sources'/entry['source']/'generated.png'
            source_hashes[key] = hashlib.sha256(source_path.read_bytes()).hexdigest()
            layer_hashes[key] = hashlib.sha256((ROOT/entry['file']).read_bytes()).hexdigest()
    assert contact['worst_slide_px'] <= 1
    assert sum(c['key_spill_pixels'] for c in checks) == 0
    newest = max((ROOT/e['file']).stat().st_mtime for e in meta['layers'])
    for suffix in ('flat.jpg','motion.mp4','motion.gif','lean-minus.jpg','lean-zero.jpg','lean-plus.jpg','alpha-proof.jpg','gif-proof.jpg','148.png','64.png'):
        assert (ROOT/f'{name}-{suffix}').stat().st_mtime >= newest, f'stale {name}-{suffix}'
    assert (ROOT/f'sheet-{name}.jpg').stat().st_mtime >= newest
    for suffix in ('lean-minus.jpg','lean-zero.jpg','lean-plus.jpg','alpha-proof.jpg','gif-proof.jpg','148.png','64.png'):
        assert (ROOT/f'{name}-{suffix}').exists()
    assert (ROOT/f'sheet-{name}.jpg').exists()
    results.append(dict(name=name, textures=meta['texture_count'], ground_method=meta['ground_method'], contact_slide_px=contact['worst_slide_px'], spill_pixels=0, mp4=probe, gif=gif_info, review_limits='Offline samples only; no Godot shader or device performance claim'))
assert len(set(source_hashes.values())) == len(source_hashes), 'shared source plate'
assert len(set(layer_hashes.values())) == len(layer_hashes), 'shared world layer'
earlier = {hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.parent.glob('mythic-art*/sources/*/generated.png') if ROOT not in p.parents}
# The superseded workbench Clean Break A stays as history; nothing may reuse it.
superseded = {hashlib.sha256((ROOT/'sources'/f'cleanBreak-A-{k}'/'generated.png').read_bytes()).hexdigest() for k in ('back', 'ground', 'front', 'subject')}
assert not superseded & set(source_hashes.values()), 'world source reused from the superseded Clean Break A'
earlier |= superseded
assert not earlier & set(source_hashes.values()), 'world source reused from an earlier round'
ledger = [json.loads(line) for line in (ROOT/'generation-count.jsonl').read_text().splitlines()]
assert len(ledger) <= 67 and sum(r.get('stage') == '4b' for r in ledger) <= 40
free = shutil.disk_usage(ROOT).free/2**30
assert free >= 50
result = dict(candidates=results, generation_calls=len(ledger), stage_4b_calls=sum(r.get('stage') == '4b' for r in ledger), completed_calls=sum(r['status']=='complete' for r in ledger), unique_world_sources=len(source_hashes), unique_world_layers=len(layer_hashes), earlier_round_sources_compared=len(earlier), earlier_round_matches=0, source_sha256=source_hashes, layer_sha256=layer_hashes, free_gib=round(free,2), visual_verdict='Recorded separately after direct image inspection')
(ROOT/'acceptance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('source_sha256','layer_sha256','candidates')},indent=2))
print('Candidates:', ', '.join(r['name'] for r in results))
