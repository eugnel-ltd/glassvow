"""Build round-four candidates from new independent plates; round-three alpha method."""
import json
from pathlib import Path
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent
SIZE = (2304, 1546)
WINDOW = (128, 86, 2176, 1460)
cv2.setNumThreads(2)


def source(name):
    return Image.open(ROOT/'sources'/name/'generated.png').convert('RGB')


def resample(image, size=None, matrix=None):
    """Resample premultiplied float colour; remove transparent RGB afterwards."""
    a = np.asarray(image.convert('RGBA'), dtype=np.float32)/255
    a[..., :3] *= a[..., 3:4]
    if size is not None:
        a = cv2.resize(a, size, interpolation=cv2.INTER_LANCZOS4)
    else:
        a = cv2.warpAffine(a, np.asarray(matrix, np.float32), image.size, flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT)
    a[..., 3] = np.clip(a[..., 3], 0, 1)
    a[..., :3] = np.minimum(np.maximum(a[..., :3], 0), a[..., 3:4])
    np.divide(a[..., :3], a[..., 3:4], out=a[..., :3], where=a[..., 3:4] > 1e-8)
    a = np.uint8(np.clip(np.rint(a*255), 0, 255))
    a[a[..., 3] == 0, :3] = 0
    return Image.fromarray(a)


def isolate(name, edge_running=False):
    image = source(name)
    a = np.asarray(image).astype(np.int16)
    r, g, blue = np.moveaxis(a, -1, 0)
    key = (np.minimum(r, blue)-g > 42) & (r > 110) & (blue > 100)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(np.uint8(~key)*255, 8)
    mask = np.zeros(key.shape, dtype=np.uint8)
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] > 250:
            mask[labels == label] = 255
    if not edge_running:
        assert not np.any(mask[0]) and not np.any(mask[-1]) and not np.any(mask[:, 0]) and not np.any(mask[:, -1]), f'{name}: source object touches frame'
    # Cut within the outer lead boundary, so the key never enters an edge pixel.
    mask = cv2.erode(mask, np.ones((3, 3), np.uint8), iterations=2)
    alpha = np.asarray(Image.fromarray(mask).filter(ImageFilter.GaussianBlur(.45)))
    rgba = np.asarray(image.convert('RGBA')).copy()
    # Despill a thin band beside every keyed region, including small enclosed holes.
    band = (cv2.dilate(np.uint8(key), np.ones((5, 5), np.uint8), iterations=3) > 0) & (mask > 0)
    px = rgba[..., :3].astype(np.int16)
    excess = np.clip(np.minimum(px[..., 0], px[..., 2])-px[..., 1], 0, None)*band
    px[..., 0] -= excess; px[..., 2] -= excess
    rgba[..., :3] = np.uint8(np.clip(px, 0, 255))
    rgba[..., 3] = alpha
    edge = (alpha > 0) & (cv2.erode(mask, np.ones((5, 5), np.uint8)) == 0)
    rgba[edge, :3] = (7, 11, 16)
    rgba[alpha == 0, :3] = 0
    result = Image.fromarray(rgba)
    bounds = result.getbbox()
    assert bounds and bounds[2]-bounds[0] > 50 and bounds[3]-bounds[1] > 20
    return (result if edge_running else result.crop(bounds)), {'source': name, 'source_size': image.size, 'source_bounds': bounds, 'matte': 'inner lead cut, despill, premultiplied resampling'}


def place(image, box):
    x, bottom, width, height = box
    scale = min(width/image.width, height/image.height)
    image = resample(image, size=(round(image.width*scale), round(image.height*scale)))
    result = Image.new('RGBA', SIZE)
    result.alpha_composite(image, (round(x+(width-image.width)/2), bottom-image.height))
    return result


def complete(name, box, rotate=0):
    image, proof = isolate(name)
    if rotate:
        # Rotate on a padded square so no part of the object leaves the canvas.
        side = int(np.hypot(*image.size))+4
        padded = Image.new('RGBA', (side, side))
        padded.alpha_composite(image, ((side-image.width)//2, (side-image.height)//2))
        image = resample(padded, matrix=cv2.getRotationMatrix2D((side/2, side/2), rotate, 1))
        image = image.crop(image.getbbox())
        proof['rotation_degrees'] = rotate
    return place(image, box), proof


def lifted_shadow(image, offset=(18, 24)):
    # Soft cast shadow under an object held just above its support.
    shade = Image.new('RGBA', SIZE, (3, 6, 14, 0))
    shade.putalpha(image.getchannel('A').filter(ImageFilter.GaussianBlur(14)).point(lambda v: round(v*.5)))
    shade = resample(shade, matrix=((1, 0, offset[0]), (0, 1, offset[1])))
    shade.alpha_composite(image)
    return shade


def masked(image, mask):
    a = np.asarray(image).copy()
    a[..., 3] = np.uint8(a[..., 3].astype(float)*np.asarray(mask)/255)
    a[a[..., 3] == 0, :3] = 0
    return Image.fromarray(a)


def largest(image):
    _, labels, stats, _ = cv2.connectedComponentsWithStats(np.uint8(np.asarray(image.getchannel('A')) > 0), 8)
    return Image.fromarray(np.uint8(labels == 1+np.argmax(stats[1:, cv2.CC_STAT_AREA]))*255)


def contact_mask(image, band=85, whole=False):
    a = np.asarray(image.getchannel('A'))
    result = np.zeros_like(a)
    if whole:
        result[cv2.erode(np.uint8(a > 200), np.ones((9, 9), np.uint8)) > 0] = 255
    else:
        bottom = image.getbbox()[3]
        for x in range(a.shape[1]):
            ys = np.flatnonzero(a[:, x] > 200)
            if len(ys) and ys[-1] >= bottom-band:
                result[ys[-1], x] = 255
    assert result.any()
    return Image.fromarray(result)


def contact_shadow(image, whole=False, band=85):
    mask = contact_mask(image, band=band, whole=whole)
    a = cv2.dilate(np.asarray(mask), np.ones((15, 27), np.uint8))
    alpha = Image.fromarray(a).filter(ImageFilter.GaussianBlur(6))
    shade = Image.new('RGBA', SIZE, (2, 4, 8, 0))
    shade.putalpha(alpha.point(lambda v: round(v*.85)))
    return shade


def emission(image, warm=False):
    a = np.asarray(image, dtype=float)
    r, g, blue = np.moveaxis(a[..., :3], -1, 0)
    intensity = np.clip(np.minimum((r-blue-20)/100, (g-blue-4)/85), 0, 1) if warm else np.clip((a[..., :3].max(axis=2)-125)/130, 0, 1)
    return Image.fromarray(np.uint8(intensity*a[..., 3]))


def save_entry(name, key, role, image, depth, effect, **extra):
    suffix = 'jpg' if role == 'back' else 'png'
    path = ROOT/f'{name}-{key}.{suffix}'
    if suffix == 'jpg':
        image.convert('RGB').save(path, quality=90)
    elif image.mode == 'L':
        image.save(path)
    else:
        a = np.asarray(image).copy()
        a[a[..., 3] == 0, :3] = 0
        Image.fromarray(a).save(path, compress_level=6)
    return dict(key=key, file=path.name, role=role, depth_px=depth, effect=effect, bounds=image.getbbox(), **extra)


def build(card):
    import os, shutil, time
    while True:
        free = shutil.disk_usage(ROOT).free/2**30
        assert free >= 50, f'STOP: free disk {free:.2f} GiB below 50 GiB'
        if os.getloadavg()[0] <= 50:
            break
        time.sleep(30)
    name = card if card.endswith(('-A', '-B')) else card+'-A'
    card = name.rsplit('-', 1)[0]
    specs = json.loads((ROOT/'build-spec.json').read_text())
    spec = specs[name] if name in specs else specs[card]
    prefix = spec.get('source_prefix', name)
    back = ImageOps.fit(source(prefix+'-back'), SIZE, Image.Resampling.LANCZOS).convert('RGBA')
    if 'back_gain' in spec:
        # Darken the surround so the card's one focal light carries the small-size read.
        a = np.asarray(back).copy()
        a[..., :3] = np.uint8(a[..., :3].astype(float)*spec['back_gain'])
        back = Image.fromarray(a)
    ground, gp = isolate(prefix+'-ground', True)
    ground = resample(ground, size=SIZE)
    if any(k in spec for k in ('ground_dy', 'ground_dx', 'ground_sy')):
        # Fit the support plane beneath every foot, including feet farther from the camera.
        ground = resample(ground, matrix=((1, 0, spec.get('ground_dx', 0)), (0, spec.get('ground_sy', 1), spec.get('ground_dy', 0))))
    front, fp = isolate(prefix+'-front', True)
    front = resample(front, size=SIZE)
    if 'front_dy' in spec:
        front = resample(front, matrix=((1, 0, 0), (0, 1, spec['front_dy'])))
    if 'front_gain' in spec:
        a = np.asarray(front).copy()
        a[..., :3] = np.uint8(a[..., :3].astype(float)*spec['front_gain'])
        front = Image.fromarray(a)
    physical = []
    for item in spec['physical']:
        image, proof = complete(prefix+'-'+item['source'], item['box'], item.get('rotate', 0))
        if 'ash_gain' in item:
            # Darken the cold ash skin so the one warm fissure carries the small-size read.
            px = np.asarray(image).astype(float)
            cold = np.asarray(emission(image, True), dtype=float) < 40
            px[cold, :3] *= item['ash_gain']
            image = Image.fromarray(np.uint8(px))
        if item.get('ember_glow'):
            # A small warm glow under the ash, held close to the fissure; no flame tongue.
            glow = Image.new('RGBA', SIZE, (255, 146, 46, 0))
            glow.putalpha(emission(image, True).filter(ImageFilter.GaussianBlur(28)).point(lambda v: min(120, v*3)))
            glow.alpha_composite(image)
            image = glow
        physical.append((item, image, proof))
    contact = np.zeros((SIZE[1], SIZE[0]), dtype=np.uint8)
    for item, image, _ in physical:
        if item.get('lifted'):
            continue
        if card == 'cleanBreak' and 'source_prefix' not in spec:
            image = masked(image, largest(image))  # only the pane rests on the support; the blade has lifted
        band = spec.get('contact_band', 85)
        contact = np.maximum(contact, np.asarray(contact_mask(image, band=band, whole=card == 'cleanBreak')))
        ground.alpha_composite(contact_shadow(image, whole=card == 'cleanBreak', band=band))
    assert np.all(np.asarray(ground.getchannel('A'))[contact > 200] == 255), f'{card}: incomplete ground under contact'
    Image.fromarray(contact).save(ROOT/f'{name}-contact-mask.png')
    images = []
    def add(role, image, depth, effect, **extra):
        images.append((role, image, depth, effect, extra))
    bd, gd, fd = spec['depths']
    add('back', back, bd, 'lean: complete distant world', source=prefix+'-back', source_size=source(prefix+'-back').size)
    if card == 'knownRoad':
        steps = Image.new('RGBA', SIZE)
        d = ImageDraw.Draw(steps)
        vx, vy = spec['horizon']
        if name.endswith('-B'):
            # Sole drawn on the ground plane, then projected through the road's own vanishing point.
            # Ground X is in pixels at the window's bottom row; depth z is 1 there and grows away from the viewer.
            sole = [(0, 0), (.22, .03), (.32, .12), (.3, .28), (.24, .42), (.34, .58), (.42, .72), (.42, .84), (.34, .93), (.18, .97), (0, 1), (-.16, .99), (-.26, .9), (-.3, .72), (-.26, .6), (-.12, .46), (-.1, .32), (-.2, .18), (-.2, .07)]
            centre, near = spec['road_bottom_x']-vx, 1450-vy
            for i in range(10):
                side = (-1)**i
                heel = 1.15+i*.25
                pts = []
                for w, l in sole:
                    z = heel+l*.34
                    pts.append((vx+(centre+side*38+side*w*58)/z, vy+near/z))
                d.polygon(pts, fill=(255, 216, 128, 150))
        else:
            for i in range(7):
                t = (i+1.5)/10
                y = vy+int((1450-vy)*t)
                # Prints follow the road's centre line from the vanishing point to the near edge.
                x = vx+round((spec.get('road_bottom_x', vx)-vx)*t+((-1)**i)*(6+t*60))
                w, l = 6+int(t*26), 4+int(t*22)
                d.ellipse((x-w, y-l, x+w, y+l), fill=(246, 222, 150, 150))
                d.ellipse((x-w*.6, y+l+3, x+w*.6, y+l+3+int(l*.9)), fill=(246, 222, 150, 120))
        # Each print gives off a faint light of its own.
        glow = Image.new('RGBA', SIZE, (246, 222, 150, 0))
        glow.putalpha(steps.getchannel('A').filter(ImageFilter.GaussianBlur(10)).point(lambda v: round(v*.7)))
        ground.alpha_composite(glow); ground.alpha_composite(steps)
    add('ground', ground, gd, 'lean: shared contact support; contour occlusion', **gp)
    emit = Image.new('L', SIZE)
    focal = Image.new('RGBA', SIZE)
    for _, image, _ in physical:
        focal.alpha_composite(image)
    if card == 'bankedFire':
        ash_path = ROOT/'sources'/f'{prefix}-ash'/'generated.png'
        if ash_path.exists():
            ash, proof = complete(prefix+'-ash', [270, 1040, 1740, 870])
            add('ash-band', ash, 12, 'lean: hard diagonal ash behind the sheltered stone', **proof)
        add('subject', focal, gd, 'lean: stone and banked coal share the ash support')
        emit = emission(focal, True)
        hot = Image.new('RGBA', SIZE, (255, 246, 215, 0))
        hot.putalpha(emit)
        add('hot-core', hot, gd, 'lean: white-hot fissure reveal past +0.3')
    elif card == 'silvering':
        add('subject', physical[0][1], gd, 'lean: complete mirror and integral feet')
        double, proof = complete(prefix+'-'+spec.get('double_source', 'double'), spec['double_box'])
        # The reflected body is wholly inside the glass, including at maximum shear.
        mirror_alpha = np.asarray(physical[0][1].getchannel('A'))
        reflected = np.asarray(double.getchannel('A')) > 200
        assert np.all(mirror_alpha[reflected] == 255), 'reflection extends outside mirror silhouette'
        for travel in (-30, 30):
            shifted = resample(double, matrix=((1, 0, travel), (0, 1, 0)))
            assert np.all(mirror_alpha[np.asarray(shifted.getchannel('A')) > 200] == 255), 'lag leaves mirror silhouette'
        add('double', double, gd, 'lean: opposite upper-body shear; time: half-breath lag', lag_px=30, foot_y=double.getbbox()[3], **proof)
        add('subject', physical[1][1], gd, 'lean: back-facing walker with lowered blade and planted feet')
        emit = double.getchannel('A').point(lambda a: round(a*.15))
    elif card == 'unbrokenFlame':
        cx, cy = spec['rose_centre']
        a = np.asarray(focal)
        yy, xx = np.indices(a.shape[:2])
        dx, dy = xx-cx, yy-cy
        radius = np.hypot(dx, dy)
        angle = np.arctan2(dy, dx)
        core_mask = Image.new('L', SIZE)
        ImageDraw.Draw(core_mask).polygon([tuple(p) for p in spec['flame_outline']], fill=255)
        # A petal's hull may close over a notch round the flame; the flame itself never leaves with a petal.
        flame_keep = cv2.dilate(np.asarray(core_mask), np.ones((15, 15), np.uint8)) > 0
        panes = []
        if spec.get('petal_components'):
            # Whole glass pieces, assigned by centroid, so a petal's points outside its wedge travel with it.
            bright = np.uint8((radius > spec['core_radius']) & (radius < spec['rose_radius']) & (a[..., :3].max(axis=2) > 90) & (a[..., 3] > 200))*255
            pieces, piece_labels, _, centroids = cv2.connectedComponentsWithStats(cv2.morphologyEx(bright, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)), 8)
            piece_angle = np.arctan2(centroids[:, 1]-cy, centroids[:, 0]-cx)
        for i in range(6):
            theta = -np.pi/2+i*np.pi/3
            delta = np.abs((angle-theta+np.pi)%(2*np.pi)-np.pi)
            mask = np.uint8((delta < np.pi/6-.035) & (radius > spec['core_radius']) & (radius < spec['rose_radius']) & (a[..., :3].max(axis=2) > 90) & (a[..., 3] > 200))*255
            if spec.get('petal_components'):
                own = np.flatnonzero(np.abs((piece_angle-theta+np.pi)%(2*np.pi)-np.pi) < np.pi/6)
                own = own[own > 0]
                mask = np.uint8(np.isin(piece_labels, own))*255
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
            n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
            assert n > 1, f'empty petal {i+1}'
            mask = np.uint8(labels == 1+np.argmax(stats[1:, cv2.CC_STAT_AREA]))*255
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            cv2.drawContours(mask, [cv2.convexHull(max(contours, key=cv2.contourArea))], -1, 255, cv2.FILLED)
            mask[flame_keep] = 0
            panes.append(Image.fromarray(mask))
        # Complete cold backing beneath the six independently moving panes.
        housing = a.copy()
        union = np.maximum.reduce([np.asarray(v) for v in panes])
        chamber = cv2.dilate(union, np.ones((13, 13), np.uint8))
        cold = np.asarray(back)[..., :3].astype(float)*.25+np.array([3, 2, 4])
        housing[chamber > 0, :3] = cold[chamber > 0].astype(np.uint8)
        add('subject', Image.fromarray(housing), gd, 'lean: complete grounded lantern housing and cold chamber')
        # Converged light fills the emptied chamber, brightest at the core.
        t = np.clip(1-radius/spec['rose_radius'], 0, 1)[..., None]**.5
        rgb = np.array([255, 188, 78])*(1-t)+np.array([255, 252, 238])*t
        radiance = np.asarray(Image.fromarray(chamber).filter(ImageFilter.GaussianBlur(6)), dtype=float)
        light = np.dstack([rgb, radiance]).astype(np.uint8)
        add('chamber-light', masked(Image.fromarray(light), Image.fromarray(chamber)), gd, 'lean: amber-to-white-gold light fills the chamber as the six panes converge')
        for i, mask in enumerate(panes):
            add('shard', masked(focal, mask), gd, 'lean: six petals converge 34 px into one flame', petal=i+1, centre=[cx, cy])
        add('flame-core', masked(focal, core_mask), gd, 'lean: one white-gold flame strengthens as petals converge')
        emit = emission(focal)
        Image.fromarray(np.uint8(sum((np.asarray(v) > 0).astype(np.uint8)*(i+1) for i, v in enumerate(panes)))).save(ROOT/f'{name}-petal-index.png')
    elif card == 'unbowed':
        add('subject', focal, gd, 'lean: figure and level boot line never rotate')
        emit = emission(focal, True)
    elif card == 'knownRoad':
        x0, y0, x1, y1 = spec['aperture']
        aperture = Image.new('L', SIZE)
        d = ImageDraw.Draw(aperture)
        w = x1-x0
        d.rectangle((x0, y0+w/2, x1, y1), fill=255)
        d.ellipse((x0, y0, x1, y0+w), fill=255)
        # The generated leaf is a complete dark plate; its source pixels form the moving leaf.
        leaf = masked(focal, aperture)
        body = masked(focal, Image.fromarray(255-np.asarray(aperture)))
        # Backlight: full light in the opening, a soft halo round the frame on the horizon.
        halo = np.asarray(aperture.filter(ImageFilter.GaussianBlur(70)), dtype=float)
        glow = np.maximum(np.asarray(aperture), np.minimum(halo*5, 255)*.8)
        light = Image.new('RGBA', SIZE, (247, 232, 180, 0)); light.putalpha(Image.fromarray(np.uint8(glow)))
        add('light-slit', light, gd, 'lean: pale-gold backlight; slit widens behind door leaf')
        shadow = Image.new('RGBA', SIZE)
        ImageDraw.Draw(shadow).polygon([(x0, y1), (x1, y1), (x1+30, y1+110), (x0-15, y1+110)], fill=(1, 3, 9, 130))
        add('door-shadow', shadow, gd, 'lean: shadow swings about the threshold', pivot_y=y1)
        add('door-leaf', leaf, gd, 'lean: simple leaf opens about its left hinge', hinge_x=x0)
        add('subject', body, gd, 'lean: small fixed arch and threshold')
        emit = aperture
    elif card == 'cleanBreak':
        x0, y0, x1, y1 = spec['seam']
        yy, xx = np.indices((SIZE[1], SIZE[0]))
        length = np.hypot(x1-x0, y1-y0)
        signed = ((x1-x0)*(yy-y0)-(y1-y0)*(xx-x0))/length
        pane_image = physical[0][1] if 'source_prefix' in spec else focal
        pane = pane_image.getchannel('A') if 'source_prefix' in spec else largest(focal)
        # Pale ice frost leaves room for the blue-white light in the cut.
        frost = np.asarray(pane_image).copy()
        frost[..., :3] = np.uint8(frost[..., :3]*np.array(spec.get('frost_gain', [.74, .82, .93])))
        panes = Image.fromarray(frost) if 'source_prefix' in spec else masked(Image.fromarray(frost), pane)
        blade = lifted_shadow(physical[1][1], tuple(spec.get('blade_shadow', (18, 24)))) if 'source_prefix' in spec else masked(focal, Image.fromarray(255-np.asarray(pane)))
        add('half-left', masked(panes, Image.fromarray(np.uint8(signed >= 0)*255)), gd, 'lean: lower relic half on its support')
        # The upper half keeps a fixed hairline offset on the same support.
        nx, ny = -(y1-y0)/length, (x1-x0)/length
        second = masked(panes, Image.fromarray(np.uint8(signed < 0)*255))
        second = resample(second, matrix=((1, 0, -3*nx), (0, 1, -3*ny)))
        add('half-right', second, gd, 'lean: upper relic half, fixed 3 px offset on the support')
        along = ((xx-x0)*(x1-x0)+(yy-y0)*(y1-y0))/length
        gap = np.clip((2.5-np.abs(signed+1.5))/1.5, 0, 1)
        gap[(along < 0) | (along > length)] = 0
        gap = np.uint8(np.minimum(gap*255, np.asarray(pane)))
        # A broad band so the cut still reads as one bright line at 64 px.
        light = Image.new('RGBA', SIZE, (232, 248, 255, 0))
        light.putalpha(Image.fromarray(gap).filter(ImageFilter.GaussianBlur(16)).point(lambda v: min(245, v*16)))
        light = masked(light, pane)
        core = Image.new('RGBA', SIZE, (255, 255, 255, 0)); core.putalpha(Image.fromarray(gap))
        light.alpha_composite(core)
        if 'source_prefix' in spec:
            # Relic seam: a white-hot core and a cold bloom pour up through the cut, held inside the relic.
            hot = np.clip((3.6-np.abs(signed+1.5))/1.6, 0, 1)
            hot[(along < 0) | (along > length)] = 0
            hot = Image.fromarray(np.uint8(np.minimum(hot*255, np.asarray(pane))))
            # Glow only inside the relic's lit glass, never over its dark outer lead.
            inner = Image.fromarray(cv2.erode(np.asarray(pane), np.ones((3, 3), np.uint8), iterations=spec.get('glow_inset', 18))).filter(ImageFilter.GaussianBlur(6))
            def glow(colour, radius, gain, cap):
                layer = Image.new('RGBA', SIZE, colour+(0,))
                layer.putalpha(hot.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(cap, round(v*gain))))
                return masked(layer, inner)
            light = glow((182, 222, 255), 80, 30, 150)
            light.alpha_composite(glow((214, 240, 255), 26, 14, 235))
            light.alpha_composite(glow((244, 252, 255), 7, 4, 255))
            core = Image.new('RGBA', SIZE, (255, 255, 255, 0)); core.putalpha(hot)
            light.alpha_composite(core)
            # Frost motes and prismatic glints: constant colour per layer, blur only the alpha (no dark rims).
            rng = np.random.default_rng(sum(map(ord, name)))
            ux, uy = (x1-x0)/length, (y1-y0)/length
            pane_a = np.asarray(pane)
            colours = [(240, 252, 255), (168, 236, 255), (196, 255, 232), (205, 214, 255)]
            dots = [Image.new('L', SIZE) for _ in colours]
            draws = [ImageDraw.Draw(m) for m in dots]
            for k in range(80):
                s_ = rng.uniform(.04, .96)*length
                off = rng.normal(0, 10 if k < 36 else 44)
                px, py = x0+ux*s_+nx*off, y0+uy*s_+ny*off
                if not (0 <= int(py) < SIZE[1] and 0 <= int(px) < SIZE[0]) or pane_a[int(py), int(px)] < 255:
                    continue
                r = rng.uniform(3, 7) if k < 36 else rng.uniform(1.8, 3.6)
                c = k % 4 if k < 36 else 0
                draws[c].ellipse((px-r, py-r*.8, px+r, py+r*.8), fill=int(rng.uniform(170, 240)))
            for colour, m in zip(colours, dots):
                layer = Image.new('RGBA', SIZE, colour+(0,)); layer.putalpha(m.filter(ImageFilter.GaussianBlur(1.3)))
                light.alpha_composite(layer)
        add('seam', light, gd, 'lean: cold blue-white light in the gap, absent at negative lean', full_from=0 if 'source_prefix' in spec else .25)
        # The lifted sword is drawn over the light it has just left.
        add('blade', blade, gd, 'lean: blade edge has already left the cut')
        emit = Image.fromarray(gap)
    add('front', front, fd, 'lean: unique near-edge occluder', **fp)
    particles = Image.new('RGBA', SIZE)
    d = ImageDraw.Draw(particles)
    rng = np.random.default_rng(sum(map(ord, name)))
    for _ in range({'cleanBreak': 6, 'unbowed': 40}.get(card, 24)):
        x, y = int(rng.integers(260, 2044)), int(rng.integers(180, 1366))
        colour = (180, 182, 185, 80) if card == 'unbowed' else (168, 186, 202, 42)
        if card in ('bankedFire', 'unbowed'):
            # Streaks follow the card's ash: Unbowed B sweeps the opposite diagonal.
            d.line((x, y, x+45, y+(-20 if name == 'unbowed-B' else 22)), fill=colour, width=2)
        else:
            d.ellipse((x, y, x+4, y+3), fill=colour)
    add('particles', particles, spec['particle_depth'], 'lean: depth; time: sparse four-second loop')
    add('emission-mask', emit, gd, 'non-drawn input for the focal reveal')
    entries = [save_entry(name, f'L{i}', role, image, depth, effect, **extra) for i, (role, image, depth, effect, extra) in enumerate(images)]
    meta = dict(name=name, card=card, canvas=SIZE, window=WINDOW, flat_size=[2048, 1374], texture_count=len(entries), layers=entries, draw_order=[e['key'] for e in entries if e['role'] != 'emission-mask'], ground_method='shear ground' if card == 'knownRoad' else 'flat ground', contact_mask=f'{name}-contact-mask.png', contact={'ground_depth_px': gd, 'subject_depth_px': gd}, max_shift_px=123, world_tilt_degrees=2.5 if card == 'unbowed' else 0, pivot=spec.get('pivot', [1400, 1280]), **{k: spec[k] for k in ('horizon',) if k in spec})
    (ROOT/f'{name}-layers.json').write_text(json.dumps(meta, indent=2)+'\n')
    checks = []
    for e in entries:
        im = Image.open(ROOT/e['file'])
        assert im.size == SIZE
        if im.mode == 'RGBA':
            a = np.asarray(im).astype(int)
            semi = (a[..., 3] > 0) & (a[..., 3] < 255)
            spill = (np.minimum(a[..., 0], a[..., 2])-a[..., 1] > 40) & semi
            assert not spill.any(), f'{name}/{e["key"]}: {spill.sum()} spill pixels'
            assert not a[a[..., 3] == 0, :3].any()
            checks.append(dict(layer=e['key'], role=e['role'], key_spill_pixels=int(spill.sum()), semitransparent_pixels=int(semi.sum())))
    (ROOT/f'{name}-checks.json').write_text(json.dumps(checks, indent=2)+'\n')
    print(name, 'built; alpha gate passed', flush=True)


if __name__ == '__main__':
    for card in sys.argv[1:]:
        build(card)
