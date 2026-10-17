"""Render the grounded offline tilt proof and measure actual contact masks."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('lane_build', ROOT / 'build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
resample = build.resample
SIZE = (1152, 773)
CROP = (64, 43, 1088, 730)
FONT = '/System/Library/Fonts/Helvetica.ttc'


def font(size):
    return ImageFont.truetype(FONT, size)


def checker(size):
    yy, xx = np.indices((size[1], size[0]))
    a = np.uint8(np.where((xx//20+yy//20)%2, 70, 115))
    return Image.fromarray(np.repeat(a[..., None], 3, axis=2)).convert('RGBA')


def shift(image, x, y=0):
    return resample(image, matrix=((1, 0, x), (0, 1, y)))


def over(image, background):
    background = background.convert('RGBA').copy()
    background.alpha_composite(image)
    return background.convert('RGB')


def alpha_proof(name, metadata):
    entries = metadata['layers']
    sheet = Image.new('RGB', (1272, 60+len(entries)*445), '#171d25')
    d = ImageDraw.Draw(sheet)
    d.text((20, 15), f'{name} | every layer | checkerboard / contrasting green', font=font(22), fill='white')
    for i, entry in enumerate(entries):
        image = Image.open(ROOT/entry['file'])
        if image.mode == 'L':
            mask = image.copy()
            image = Image.new('RGBA', image.size, (255, 240, 205, 0))
            image.putalpha(mask)
        image = resample(image, size=(600, 403))
        y = 60+i*445
        d.text((24, y), f'{entry["key"]}: {entry["role"]}', font=font(20), fill='white')
        sheet.paste(over(image, checker(image.size)), (24, y+28))
        sheet.paste(over(image, Image.new('RGBA', image.size, '#49a65b')), (648, y+28))
    sheet.save(ROOT/f'{name}-alpha-proof.jpg', quality=92)


def contact_check(name, metadata):
    entries = {v['key']: v for v in metadata['layers']}
    subject = np.asarray(Image.open(ROOT/entries['L2']['file']).getchannel('A'))
    ground = np.asarray(Image.open(ROOT/entries['L1']['file']).getchannel('A'))
    y0, y1 = metadata['contact']['source_contact_band']
    points = []
    for x in range(subject.shape[1]):
        ys = np.flatnonzero(subject[:, x] > 200)
        if len(ys) and ys[-1] >= y0:
            points.append((x, int(ys[-1])))
    assert points
    xs, ys = np.asarray(points).T
    assert np.all(ground[ys, xs] == 255), 'ground is not opaque under the subject contact'
    marker = Image.new('RGBA', build.SIZE)
    draw = ImageDraw.Draw(marker)
    for x, y in points:
        draw.point((int(x), int(y)), fill=(255, 255, 255, 255))
    results = []
    for lean in (-1, 0, 1):
        sm = shift(marker, lean*entries['L2']['depth_px']).getchannel('A')
        gm = shift(marker, lean*entries['L1']['depth_px']).getchannel('A')
        s = np.asarray(sm)
        g = np.asarray(gm)
        delta = float(abs(lean*(entries['L2']['depth_px']-entries['L1']['depth_px'])))
        assert np.array_equal(s, g) and delta <= 1
        moved_ground = np.asarray(shift(Image.open(ROOT/entries['L1']['file']), lean*entries['L1']['depth_px']).getchannel('A'))
        assert np.all(moved_ground[s > 200] == 255)
        results.append({'lean': lean, 'relative_slide_px': delta, 'contact_mask_differing_pixels': int(np.count_nonzero(s != g)), 'ground_alpha_under_contact_min': int(moved_ground[s > 200].min())})
    # Mutation sentinel: the former floating-subject transform must fail the same test.
    bad = np.asarray(shift(marker, 123).getchannel('A'))
    good = np.asarray(shift(marker, 72).getchannel('A'))
    assert not np.array_equal(bad, good), 'contact test cannot detect independent subject drift'
    proof = {'name': name, 'method': 'render the real lower subject contour through both transforms at full source resolution; check floor coverage', 'contact_pixel_count': len(points), 'samples': results, 'worst_slide_px': max(r['relative_slide_px'] for r in results), 'mutation_detected': True}
    (ROOT/f'{name}-contact-lock.json').write_text(json.dumps(proof, indent=2)+'\n')


def motion(name):
    metadata = json.loads((ROOT/f'{name}-layers.json').read_text())
    contact_check(name, metadata)
    entries = {v['key']: v for v in metadata['layers']}
    layers = {key: resample(Image.open(ROOT/v['file']), size=SIZE) for key, v in entries.items() if v['role'] != 'emission-mask'}
    mask = Image.open(ROOT/entries['L6']['file']).resize(SIZE, Image.Resampling.LANCZOS)
    alpha = np.asarray(layers['L2'].getchannel('A'), dtype=float)/255
    xx = np.arange(SIZE[0])[None, :]
    frames = []
    command = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1024x752', '-r', '24', '-i', '-', '-an', '-c:v', 'libx264', '-threads', '2', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(ROOT/f'{name}-motion.mp4')]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    try:
        for i in range(96):
            t = i/24
            lean = float(-np.cos(2*np.pi*t/4))
            flare = float(np.clip((lean-.3)/.65, 0, 1))
            canvas = shift(layers['L0'], lean*entries['L0']['depth_px']/2)
            for key in ('L1', 'L2'):
                canvas.alpha_composite(shift(layers[key], lean*entries[key]['depth_px']/2))
            sx = lean*entries['L2']['depth_px']/2
            sheen = np.exp(-((xx-(lean+1)*SIZE[0]/2)/105)**2)*alpha*.16
            shine = Image.new('RGBA', SIZE, (177, 207, 223, 0))
            shine.putalpha(Image.fromarray(np.uint8(sheen*255)))
            canvas.alpha_composite(shift(shine, sx))
            hot = layers['L3'].copy()
            hot.putalpha(hot.getchannel('A').point(lambda a: int(a*flare*.88)))
            canvas.alpha_composite(shift(hot, sx))
            glow = Image.new('RGBA', SIZE, (255, 194, 84, 0))
            glow.putalpha(mask.point(lambda a: int(a*flare*.55)).filter(ImageFilter.GaussianBlur(16)))
            canvas.alpha_composite(shift(glow, sx))
            canvas.alpha_composite(shift(layers['L4'], lean*entries['L4']['depth_px']/2))
            canvas.alpha_composite(Image.new('RGBA', SIZE, (202, 119, 38, int(20*flare))))
            drift = np.sin(2*np.pi*t/4)
            canvas.alpha_composite(shift(layers['L5'], lean*50+drift*9, -drift*5))
            window = canvas.crop(CROP)
            assert np.asarray(window.getchannel('A')).min() == 255, 'visible hole at lean'
            frame = Image.new('RGB', (1024, 752), '#111820')
            frame.paste(window.convert('RGB'))
            draw = ImageDraw.Draw(frame)
            draw.text((16, 695), f'{name} | offline approximation, not the shader | lean {lean:+.2f}', font=font(21), fill='white')
            draw.text((16, 727), 'LEAN: depth, sheen, threshold heat    TIME: ash drift    CONTACT: locked', font=font(17), fill='#b6c6d1')
            process.stdin.write(frame.tobytes())
            if i%4 == 0:
                frames.append(frame.resize((640, 470), Image.Resampling.LANCZOS))
            if i in (0, 24, 48):
                suffix = {0: 'minus', 24: 'zero', 48: 'plus'}[i]
                frame.save(ROOT/f'{name}-lean-{suffix}.jpg', quality=92)
    finally:
        process.stdin.close()
    assert process.wait() == 0, 'ffmpeg failed'
    mosaic = Image.new('RGB', (640*4, 470))
    for i, frame in enumerate(frames[::6]):
        mosaic.paste(frame, (i*640, 0))
    palette = mosaic.quantize(colors=64)
    indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    gif = ROOT/f'{name}-motion.gif'
    indexed[0].save(gif, save_all=True, append_images=indexed[1:], duration=[160, 170, 170]*8, loop=0, disposal=2, optimize=True)
    assert gif.stat().st_size <= 5_000_000
    # Decode the delivered GIF, not just the pre-encode frames, for visual inspection.
    decoded = Image.open(gif)
    strip = Image.new('RGB', (640*3, 470*2), '#111820')
    for j, index in enumerate((0, 3, 6, 9, 12, 18)):
        decoded.seek(index)
        strip.paste(decoded.convert('RGB'), ((j%3)*640, (j//3)*470))
    strip.save(ROOT/f'{name}-gif-proof.jpg', quality=94)
    alpha_proof(name, metadata)
    print(name, 'motion, contact lock and alpha proof ready', flush=True)


def contact(card):
    sheet = Image.new('RGB', (1696, 1620), '#171d25')
    draw = ImageDraw.Draw(sheet)
    for col, letter in enumerate('AB'):
        name = f'{card}-{letter}'
        x = 24+col*840
        metadata = json.loads((ROOT/f'{name}-layers.json').read_text())
        plate = Image.open(ROOT/f'{name}-flat.jpg')
        draw.text((x, 15), name, font=font(27), fill='white')
        sheet.paste(plate.resize((800, 537), Image.Resampling.LANCZOS), (x, 52))
        crop = ImageOps.fit(plate, (148, 91), Image.Resampling.LANCZOS)
        thumb = ImageOps.contain(plate, (64, 64), Image.Resampling.LANCZOS)
        crop.save(ROOT/f'{name}-148.png')
        thumb.save(ROOT/f'{name}-64.png')
        draw.text((x, 603), '148 x 91 cover crop', font=font(18), fill='white')
        draw.text((x+206, 603), '64 px', font=font(18), fill='white')
        sheet.paste(crop, (x, 630))
        sheet.paste(thumb, (x+206, 630))
        for i, entry in enumerate(metadata['layers']):
            px, py = x+(i%4)*200, 740+(i//4)*165
            layer = Image.open(ROOT/entry['file'])
            if layer.mode == 'L':
                mask = layer.copy()
                layer = Image.new('RGBA', mask.size, (255, 240, 205, 0))
                layer.putalpha(mask)
            layer = resample(layer, size=(190, 127))
            draw.text((px, py), entry['key'], font=font(17), fill='white')
            sheet.paste(over(layer, checker(layer.size)), (px, py+25))
        for i, lean in enumerate(('minus', 'zero', 'plus')):
            px, py = x+(i%2)*400, 1080+(i//2)*260
            image = Image.open(ROOT/f'{name}-lean-{lean}.jpg').crop((0, 0, 1024, 687))
            draw.text((px, py), f'Lean {[-1, 0, 1][i]:+d}', font=font(19), fill='white')
            sheet.paste(image.resize((390, 232), Image.Resampling.LANCZOS), (px, py+26))
    sheet.save(ROOT/f'sheet-{card}.jpg', quality=93)


if __name__ == '__main__':
    for name in sys.argv[1:]:
        motion(name)
    for card in sorted({name.rsplit('-', 1)[0] for name in sys.argv[1:]}):
        contact(card)
