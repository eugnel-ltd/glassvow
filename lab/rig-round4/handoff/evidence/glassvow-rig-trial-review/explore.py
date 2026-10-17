"""Local read-only exploration of fitted Tripo meshes: projections coloured by a trial label."""
import json, struct, sys, zlib
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from read_glb import load

HERE = Path(__file__).parent


def fitted(name, height):
    doc, acc = load(HERE / 'src' / f'{name}.glb')
    out_p, out_f = [], []
    base = 0
    for node in doc['nodes']:
        if 'mesh' not in node:
            continue
        m = np.eye(4)
        if 'matrix' in node:
            m = np.array(node['matrix']).reshape(4, 4).T
        else:
            t = node.get('translation', [0, 0, 0]); s = node.get('scale', [1, 1, 1])
            x, y, z, w = node.get('rotation', [0, 0, 0, 1])
            r = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
            m[:3, :3] = r * s; m[:3, 3] = t
        for prim in doc['meshes'][node['mesh']]['primitives']:
            p = acc(prim['attributes']['POSITION']).astype(float)
            p = p @ m[:3, :3].T + m[:3, 3]
            out_p.append(p); out_f.append(acc(prim['indices']).reshape(-1, 3).astype(int) + base); base += len(p)
    p = np.concatenate(out_p)[:, [0, 2, 1]] * [1, -1, 1]
    f = np.concatenate(out_f)
    lo, hi = p.min(0), p.max(0)
    s = height / (hi[2] - lo[2])
    p = (p - [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]]) * s
    # merge by position like the Blender importer's merge_vertices
    key, inv = np.unique(np.round(p, 6), axis=0, return_inverse=True)
    return key, inv.ravel()[f]


def png(path, img):
    h, w, _ = img.shape
    raw = b''.join(b'\x00' + img[y].tobytes() for y in range(h))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))


PALETTE = np.array([[200, 200, 200], [230, 80, 80], [80, 200, 90], [80, 120, 240], [240, 200, 60], [200, 90, 220], [70, 210, 210], [250, 140, 40], [140, 90, 50], [255, 255, 255], [120, 120, 255], [255, 120, 180], [100, 160, 60], [160, 60, 60]], np.uint8)


def views(path, p, f, lab, grid=0.1, px=200):
    """Front (x,z from -y), side (-y,z from +x), top (x,y from +z), back; face centroids splatted with depth."""
    c = p[f].mean(1)
    span = p.max(0) - p.min(0)
    S = int(px * max(span) + 20)
    panels = []
    zc = p[:, 2].max() / 2
    for u, v, d, off in ((c[:, 0], c[:, 2], c[:, 1], zc), (-c[:, 1], c[:, 2], -c[:, 0], zc), (c[:, 0], -c[:, 1], -c[:, 2], 0), (-c[:, 0], c[:, 2], -c[:, 1], zc)):
        img = np.full((S, S, 3), 60, np.uint8)
        # grid lines every `grid` m
        for g in np.arange(-3, 3, grid):
            k = int(S / 2 + g * px)
            if 0 <= k < S:
                img[:, k] = 80; img[k, :] = 80
        order = np.argsort(-d)  # far first, near overwrite
        x = (S / 2 + u[order] * px).astype(int); y = (S / 2 - (v[order] - off) * px).astype(int)
        col = PALETTE[lab[order] % len(PALETTE)]
        shade = np.clip(1 - (d[order] - d.min()) / max(np.ptp(d), 1e-6) * .5, .4, 1)[:, None]
        for dx in (0, 1):
            for dy in (0, 1):
                ok = (x + dx >= 0) & (x + dx < S) & (y + dy >= 0) & (y + dy < S)
                img[y[ok] + dy, x[ok] + dx] = (col[ok] * shade[ok]).astype(np.uint8)
        panels.append(img)
    png(path, np.concatenate(panels, 1))


if __name__ == '__main__':
    name, height = sys.argv[1], float(sys.argv[2])
    p, f = fitted(name, height)
    print(name, 'verts', len(p), 'tris', len(f), 'extent', np.round(p.max(0) - p.min(0), 3), 'min', np.round(p.min(0), 3))
    # connected components
    parent = np.arange(len(p))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for a, b, cc in f:
        ra = find(a); parent[find(b)] = ra; parent[find(cc)] = ra
    roots = np.array([find(i) for i in range(len(p))])
    u, cnt = np.unique(roots, return_counts=True)
    print('islands', len(u), sorted(cnt)[-8:])
    np.savez(HERE / f'{name}-fit.npz', p=p, f=f)
    views(HERE / f'{name}-z.png', p, f, (p[f].mean(1)[:, 2] * 5).astype(int))
