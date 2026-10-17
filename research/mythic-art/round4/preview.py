"""Offline candidate previews; adapted from the round-three streaming renderer."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
s = importlib.util.spec_from_file_location('lane_build', ROOT/'build.py')
b = importlib.util.module_from_spec(s); s.loader.exec_module(b)
s = importlib.util.spec_from_file_location('lane_helpers', ROOT/'preview_helpers.py')
h = importlib.util.module_from_spec(s); s.loader.exec_module(h)
LABEL = 'offline approximation, not the shader'


def guard():
    while True:
        free = shutil.disk_usage(ROOT).free/2**30
        assert free >= 50, f'STOP: free disk {free:.2f} GiB below 50 GiB'
        load = os.getloadavg()[0]
        if load <= 50:
            return
        print(f'WAIT: load {load:.2f}; free {free:.2f} GiB', flush=True)
        time.sleep(30)


def opacity(image, amount):
    out = image.copy()
    out.putalpha(out.getchannel('A').point(lambda a: round(a*max(0, min(1, amount)))))
    return out


def row_shift(image, offsets):
    a = np.asarray(image.convert('RGBA'), dtype=np.float32)/255
    a[..., :3] *= a[..., 3:4]
    yy, xx = np.indices(a.shape[:2], dtype=np.float32)
    out = cv2.remap(a, xx-offsets[:, None].astype(np.float32), yy, cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    out[..., 3] = np.clip(out[..., 3], 0, 1)
    out[..., :3] = np.minimum(np.maximum(out[..., :3], 0), out[..., 3:4])
    np.divide(out[..., :3], out[..., 3:4], out=out[..., :3], where=out[..., 3:4] > 1e-8)
    out = np.uint8(np.clip(np.rint(out*255), 0, 255))
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(out)


def ground_move(image, meta, lean, scale=1):
    depth = meta['contact']['ground_depth_px']
    if meta['ground_method'] == 'flat ground':
        return h.shift(image, lean*depth*scale)
    horizon = meta['horizon'][1]*scale
    rows = np.arange(image.height)
    depths = depth*scale+(90-depth)*scale*np.clip((rows-horizon)/(1460*scale-horizon), 0, 1)
    return row_shift(image, lean*depths)


def contact_check(meta):
    name = meta['name']
    marker = Image.new('RGBA', b.SIZE, (255, 255, 255, 0))
    marker.putalpha(Image.open(ROOT/meta['contact_mask']))
    ground_entry = next(e for e in meta['layers'] if e['role'] == 'ground')
    ground = Image.open(ROOT/ground_entry['file'])
    results = []
    for lean in (-1, 0, 1):
        sm = np.asarray(h.shift(marker, lean*meta['contact']['subject_depth_px']).getchannel('A'))
        gm = np.asarray(ground_move(marker, meta, lean).getchannel('A'))
        ga = np.asarray(ground_move(ground, meta, lean).getchannel('A'))
        assert np.array_equal(sm, gm), 'subject moves relative to contact ground'
        assert np.all(ga[sm > 200] == 255), 'incomplete ground under transformed contact'
        results.append(dict(lean=lean, relative_slide_px=0, contact_mask_differing_pixels=int(np.count_nonzero(sm != gm)), ground_alpha_under_contact_min=int(ga[sm > 200].min())))
    assert not np.array_equal(np.asarray(h.shift(marker, 123)), np.asarray(h.shift(marker, meta['contact']['subject_depth_px'])))
    result = dict(name=name, method='warp real contact mask through subject and support transforms at full resolution', samples=results, worst_slide_px=0, contact_pixel_count=int(np.count_nonzero(np.asarray(marker.getchannel('A')))), mutation_detected=True)
    (ROOT/f'{name}-contact-lock.json').write_text(json.dumps(result, indent=2)+'\n')


def renderer(meta, scale=.5):
    size = (round(2304*scale), round(1546*scale))
    crop = tuple(round(v*scale) for v in b.WINDOW)
    entries = meta['layers']
    images = {e['key']: b.resample(Image.open(ROOT/e['file']), size=size) for e in entries if e['role'] != 'emission-mask'}
    card = meta['card']
    xx = np.arange(size[0])[None, :]
    def render(lean, t, neutral=False):
        canvas = Image.new('RGBA', size)
        flare = float(np.clip((lean-.3)/.65, 0, 1))
        for e in entries:
            role = e['role']
            if role == 'emission-mask':
                continue
            image = images[e['key']]
            sx = lean*e['depth_px']*scale
            if role == 'ground':
                moving = ground_move(image, meta, lean, scale)
            elif card == 'unbowed' and role in ('back', 'front'):
                pivot = tuple(float(v)*scale for v in meta['pivot'])
                matrix = cv2.getRotationMatrix2D(pivot, lean*meta['world_tilt_degrees'], 1)
                matrix[0, 2] += sx
                moving = b.resample(image, matrix=matrix)
            elif role == 'double':
                lag = lean if neutral else -np.cos(2*np.pi*(t-.16)/4)
                rows = np.arange(size[1])
                offsets = sx-lag*e['lag_px']*scale*np.clip((e['foot_y']*scale-rows)/(600*scale), 0, 1)
                moving = opacity(row_shift(image, offsets), .7+.15*abs(lean))
            elif role == 'shard':
                amount = max(0, lean)
                theta = (e['petal']-1)*np.pi/3-np.pi/2
                # Each pane's colour runs into the core: tint to white-gold, keep the glass texture.
                k = float(np.clip((amount-.15)/.7, 0, 1))
                a = np.asarray(image, dtype=float)
                gold = np.array([255, 232, 168])*(.92+.08*a[..., :3].mean(axis=2, keepdims=True)/255)
                a[..., :3] = a[..., :3]*(1-.85*k)+gold*.85*k
                a[..., 3] *= 1-.6*k
                moving = h.shift(Image.fromarray(np.uint8(a)), sx-34*scale*amount*np.cos(theta), -34*scale*amount*np.sin(theta))
            elif role == 'chamber-light':
                moving = opacity(h.shift(image, sx), np.clip((max(0, lean)-.25)/.6, 0, 1))
            elif role == 'flame-core':
                moving = h.shift(image, sx)
                glow = Image.new('RGBA', size, (255, 245, 210, 0))
                glow.putalpha(image.getchannel('A').filter(ImageFilter.GaussianBlur(18*scale)))
                moving.alpha_composite(opacity(h.shift(glow, sx), max(0, lean)*.7))
            elif role == 'hot-core':
                moving = opacity(h.shift(image, sx), flare*.9)
                glow = Image.new('RGBA', size, (255, 190, 70, 0))
                glow.putalpha(image.getchannel('A').filter(ImageFilter.GaussianBlur(24*scale)))
                moving.alpha_composite(opacity(h.shift(glow, sx), flare*.6))
            elif role == 'light-slit':
                moving = h.shift(image, sx)
            elif role == 'door-leaf':
                hinge = e['hinge_x']*scale
                shrink = .86-.2*max(0, lean)
                moving = b.resample(image, matrix=((shrink, 0, hinge*(1-shrink)+sx), (0, 1, 0)))
            elif role == 'door-shadow':
                pivot = e['pivot_y']*scale
                shear = lean*.16
                moving = b.resample(image, matrix=((1, shear, sx-shear*pivot), (0, 1, 0)))
            elif role == 'seam':
                moving = h.shift(opacity(image, np.clip((lean+1)/(1+e.get('full_from', .25)), 0, 1)), sx)
            elif role == 'particles':
                drift = 0 if neutral else np.sin(2*np.pi*t/4)
                moving = h.shift(image, sx+drift*12*scale, -drift*6*scale)
            else:
                moving = h.shift(image, sx)
            canvas.alpha_composite(moving)
            if role in ('subject', 'half-right', 'blade') and not neutral:
                alpha = np.asarray(image.getchannel('A'), dtype=float)/255
                sheen = np.exp(-((xx-(lean+1)*size[0]/2)/(150*scale))**2)*alpha*.11
                shine = Image.new('RGBA', size, (177, 207, 223, 0))
                shine.putalpha(Image.fromarray(np.uint8(sheen*255)))
                canvas.alpha_composite(h.shift(shine, sx))
        if card == 'bankedFire':
            canvas.alpha_composite(Image.new('RGBA', size, (202, 119, 38, int(19*flare))))
        window = canvas.crop(crop)
        assert np.asarray(window.getchannel('A')).min() == 255, 'hole in visible sweep'
        return window.convert('RGB')
    return render


def motion(card):
    guard()
    name = card if card.endswith(('-A', '-B')) else card+'-A'
    card = name.rsplit('-', 1)[0]
    meta = json.loads((ROOT/f'{name}-layers.json').read_text())
    contact_check(meta)
    flat = renderer(meta, 1)(0, 1, True)
    flat.save(ROOT/f'{name}-flat.jpg', quality=90)
    render = renderer(meta)
    pending = ROOT/f'{name}-motion.pending.mp4'
    process = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1024x752', '-r', '24', '-i', '-', '-an', '-c:v', 'libx264', '-threads', '2', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(pending)], stdin=subprocess.PIPE)
    frames = []
    try:
        for i in range(96):
            guard()
            t = i/24
            lean = float(-np.cos(2*np.pi*t/4))
            window = render(lean, t)
            frame = Image.new('RGB', (1024, 752), '#111820'); frame.paste(window)
            d = ImageDraw.Draw(frame)
            d.text((16, 695), f'{name} | {LABEL} | lean {lean:+.2f}', font=h.font(21), fill='white')
            d.text((16, 727), 'LEAN: depth, focal sheen, card effect   TIME: sparse drift'+(', copy lag' if card == 'silvering' else ''), font=h.font(16), fill='#b6c6d1')
            process.stdin.write(frame.tobytes())
            if i%4 == 0:
                frames.append(frame.resize((640, 470), Image.Resampling.LANCZOS))
            if i in (0, 24, 48):
                suffix = {0:'minus', 24:'zero', 48:'plus'}[i]
                frame.save(ROOT/f'{name}-lean-{suffix}.jpg', quality=92)
    finally:
        process.stdin.close()
    assert process.wait() == 0, 'ffmpeg failed'
    probe = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=nb_frames:format=duration', '-of', 'json', str(pending)]))
    assert probe['streams'][0]['nb_frames'] == '96' and abs(float(probe['format']['duration'])-4) < .01
    subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-threads', '2', '-i', str(pending), '-f', 'null', '-'], check=True)
    mosaic = Image.new('RGB', (2560, 470))
    for i, f in enumerate(frames[::6]): mosaic.paste(f, (i*640, 0))
    # Give rare saturated focal colours a fair share of the GIF palette.
    pixels = np.asarray(mosaic).reshape(-1, 3)
    hsv = cv2.cvtColor(pixels.reshape(470, 2560, 3), cv2.COLOR_RGB2HSV).reshape(-1, 3)
    colour_groups = []
    for hue in range(0, 180, 15):
        selected = pixels[(hsv[:, 0] >= hue) & (hsv[:, 0] < hue+15) & (hsv[:, 1] > 90) & (hsv[:, 2] > 90)]
        if len(selected):
            colour_groups.append(selected[np.linspace(0, len(selected)-1, 16000).astype(int)])
    palette_sample = Image.new('RGB', (3200, 470)); palette_sample.paste(mosaic)
    if colour_groups:
        colours = np.concatenate(colour_groups)
        colours = colours[np.arange(640*470)%len(colours)].reshape(470,640,3)
        palette_sample.paste(Image.fromarray(colours), (2560,0))
    gif = ROOT/f'{name}-motion.pending.gif'
    for count in (128, 96, 80, 64):
        palette = palette_sample.quantize(colors=count)
        indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
        indexed[0].save(gif, save_all=True, append_images=indexed[1:], duration=[160,170,170]*8, loop=0, disposal=2, optimize=True)
        if gif.stat().st_size <= 5_000_000:
            break
    assert gif.stat().st_size <= 5_000_000
    with Image.open(gif) as decoded:
        duration = 0
        for i in range(decoded.n_frames):
            decoded.seek(i); decoded.load(); duration += decoded.info['duration']
        assert decoded.n_frames == 24 and duration == 4000
    guard()
    pending.replace(ROOT/f'{name}-motion.mp4'); gif.replace(ROOT/f'{name}-motion.gif')
    decoded = Image.open(ROOT/f'{name}-motion.gif')
    strip = Image.new('RGB', (1920, 940), '#111820')
    for j, i in enumerate((0,3,6,9,12,18)):
        decoded.seek(i); strip.paste(decoded.convert('RGB'), ((j%3)*640, (j//3)*470))
    strip.save(ROOT/f'{name}-gif-proof.jpg', quality=93)
    h.alpha_proof(name, meta)
    sheet(card, meta)
    print(name, 'motion, contact and media checks passed', flush=True)


def sheet(card, meta):
    name = meta['name']
    rows = (len(meta['layers'])+5)//6
    image = Image.new('RGB', (2096, 1880+rows*250), '#171d25')
    d = ImageDraw.Draw(image)
    d.text((24, 14), f'{name} | {LABEL}', font=h.font(28), fill='white')
    flat = Image.open(ROOT/f'{name}-flat.jpg')
    image.paste(flat, (24, 58))
    crop = ImageOps.fit(flat, (148,91), Image.Resampling.LANCZOS)
    small = ImageOps.contain(flat, (64,64), Image.Resampling.LANCZOS)
    crop.save(ROOT/f'{name}-148.png'); small.save(ROOT/f'{name}-64.png')
    d.text((24,1447), 'Native 148 x 91 / 64 px', font=h.font(20), fill='white')
    image.paste(crop, (24,1478)); image.paste(small, (210,1478))
    for i, e in enumerate(meta['layers']):
        x, y = 24+(i%6)*344, 1600+(i//6)*250
        layer = Image.open(ROOT/e['file'])
        if layer.mode == 'L':
            mask = layer.copy(); layer = Image.new('RGBA', layer.size, (220,240,255,0)); layer.putalpha(mask)
        layer = b.resample(layer, size=(326,219))
        d.text((x,y), f'{e["key"]} {e["role"]} {e["depth_px"]:+d} px', font=h.font(16), fill='white')
        image.paste(h.over(layer, h.checker(layer.size)), (x,y+25))
    y = 1600+rows*250
    for i, lean in enumerate(('minus','zero','plus')):
        x = 24+i*688
        frame = Image.open(ROOT/f'{name}-lean-{lean}.jpg')
        image.paste(frame.resize((672,494), Image.Resampling.LANCZOS), (x,y))
    # Expand once so the complete lean strip is retained.
    if y+494 > image.height:
        enlarged = Image.new('RGB', (2096,y+518), '#171d25'); enlarged.paste(image)
        for i, lean in enumerate(('minus','zero','plus')):
            frame = Image.open(ROOT/f'{name}-lean-{lean}.jpg')
            enlarged.paste(frame.resize((672,494), Image.Resampling.LANCZOS), (24+i*688,y))
        image = enlarged
    image.save(ROOT/f'sheet-{name}.jpg', quality=92)
    if name.endswith('-A'):
        image.save(ROOT/f'sheet-{card}.jpg', quality=92)


if __name__ == '__main__':
    for card in sys.argv[1:]: motion(card)
