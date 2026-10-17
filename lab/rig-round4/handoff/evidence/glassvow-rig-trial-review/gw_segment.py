"""Trial rigid segmentation of the fitted Gravewarden source by face rules; reports cut seams and islands."""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
NAMES = ['Torso', 'UpperArm.L', 'Gauntlet.L', 'UpperArm.R', 'Gauntlet.R', 'Leg.L', 'Foot.L', 'Leg.R', 'Foot.R']


def label(c):
    x, y, z = c[:, 0], c[:, 1], c[:, 2]
    ax = np.abs(x)
    lab = np.zeros(len(c), int)
    side = np.where(x > 0, 0, 1)
    gaunt = ((ax > 0.53) & (z < 1.10)) | (ax > 0.80)
    upper = ~gaunt & (ax > 0.50) & (z < 1.45)
    leg = ~gaunt & (z < 0.62) & (ax > 0.22) & (ax < 0.66)
    foot = leg & (z < 0.22)
    lab[upper] = 1 + 2 * side[upper]
    lab[gaunt] = 2 + 2 * side[gaunt]
    lab[leg] = 5 + 2 * side[leg]
    lab[foot] = 6 + 2 * side[foot]
    return lab


def report(p, f, lab):
    e = np.concatenate([f[:, [0, 1]], f[:, [1, 2]], f[:, [2, 0]]])
    owner = np.tile(np.arange(len(f)), 3)
    key = np.sort(e, 1)
    order = np.lexsort(key.T[::-1])
    key, owner = key[order], owner[order]
    same = np.all(key[1:] == key[:-1], 1)
    a, b = owner[:-1][same], owner[1:][same]
    cross = lab[a] != lab[b]
    print('faces per piece', {NAMES[k]: int((lab == k).sum()) for k in range(len(NAMES))})
    pairs = {}
    for i, j, k in zip(lab[a][cross], lab[b][cross], key[:-1][same][cross]):
        pairs.setdefault(tuple(sorted((NAMES[i], NAMES[j]))), []).append(p[k].mean(0))
    for k, v in sorted(pairs.items()):
        v = np.array(v)
        print('seam', k, len(v), 'min', np.round(v.min(0), 3), 'max', np.round(v.max(0), 3), 'mean', np.round(v.mean(0), 3))
    # islands per piece over face adjacency
    parent = np.arange(len(f))
    def find(q):
        while parent[q] != q:
            parent[q] = parent[parent[q]]; q = parent[q]
        return q
    for i, j in zip(a[~cross], b[~cross]):
        parent[find(i)] = find(j)
    roots = np.array([find(i) for i in range(len(f))])
    for k in range(len(NAMES)):
        r, cnt = np.unique(roots[lab == k], return_counts=True)
        print('islands', NAMES[k], sorted(cnt.tolist(), reverse=True)[:6])


if __name__ == '__main__':
    d = np.load(HERE / 'gravewarden-fit.npz')
    p, f = d['p'], d['f']
    lab = label(p[f].mean(1))
    report(p, f, lab)
    sys.path.insert(0, str(HERE))
    from explore import views
    views(HERE / 'gw-seg.png', p, f, lab)
