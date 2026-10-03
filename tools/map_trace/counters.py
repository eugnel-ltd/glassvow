"""Attribute Metal GPU counter samples to encoders of the dominant frame shape.

Usage: counters.py <dir> <process-substring>
<dir> holds metal-gpu-intervals.xml, metal-application-encoders-list.xml,
gpu-counter-info.xml and gpu-counter-value.xml from `xctrace export`.
Each counter sample is assigned to the encoder whose Fragment interval
contains it (else its Vertex interval, else Compute); per encoder index of
the dominant command-buffer shape, the mean of each counter is printed, plus
the mean over all GPU-busy samples.
"""
import bisect
import collections
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import frames as F  # noqa: E402
from xtable import rows  # noqa: E402


def counter_values(path):
    ids = {}
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag != "row":
            continue
        vals = []
        for cell in el:
            if cell.get("ref") is not None:
                vals.append(ids[cell.get("ref")])
            else:
                t = (cell.text or "").strip()
                if cell.get("id") is not None:
                    ids[cell.get("id")] = t
                vals.append(t)
        el.clear()
        if len(vals) >= 3:
            yield int(vals[0]), int(vals[1]), float(vals[2])


def main(d, pid):
    _, info = rows(d + "/gpu-counter-info.xml")
    names = {int(r["counter-id"][1]): r["name"][0] for r in info}
    enc, gpu = F.load(d, pid)
    fs = F.frames(enc, gpu)
    shapes = collections.Counter(len(f["encoders"]) for f in fs)
    dominant = max(shapes, key=lambda k: (k * shapes[k] if shapes[k] > 5 else 0))
    # Intervals per channel with the encoder index they belong to.
    ivals = {"Fragment": [], "Vertex": [], "Compute": []}
    by_cb = collections.defaultdict(list)
    for eid, g in gpu.items():
        by_cb[g.get("cb")].append((eid, g))
    for cb, items in by_cb.items():
        if len(items) != dominant:
            continue
        items.sort(key=lambda x: (F._index(enc.get(x[0], {}).get("label", "")), min(s for s, _, _ in x[1]["spans"])))
        for i, (eid, g) in enumerate(items):
            for s, e, ch in g["spans"]:
                ivals[ch].append((s, e, i))
    starts = {}
    for ch in ivals:
        ivals[ch].sort()
        starts[ch] = [s for s, _, _ in ivals[ch]]

    def where(ts):
        for ch in ("Fragment", "Vertex", "Compute"):
            k = bisect.bisect_right(starts[ch], ts) - 1
            # Scan back a little: intervals can nest.
            for j in range(k, max(k - 6, -1), -1):
                s, e, i = ivals[ch][j]
                if s <= ts <= e:
                    return ch, i
        return None, None

    acc = collections.defaultdict(lambda: collections.defaultdict(list))
    for ts, cid, v in counter_values(d + "/gpu-counter-value.xml"):
        ch, i = where(ts)
        if i is None:
            continue
        acc[(i, ch)][cid].append(v)
        acc[("all", "busy")][cid].append(v)
    keys = sorted(names)
    print("dominant shape: %d encoders, %d command buffers" % (dominant, shapes[dominant]))
    for key in sorted(acc, key=lambda k: (str(k[0]).zfill(3), k[1])):
        n = max(len(v) for v in acc[key].values())
        parts = []
        for cid in keys:
            vs = acc[key].get(cid)
            if vs:
                m = sum(vs) / len(vs)
                if m >= 1.0 or "Bandwidth" in names[cid]:
                    parts.append("%s %.1f" % (names[cid], m))
        print("enc %-4s %-8s samples %6d | %s" % (key[0], key[1], n, "; ".join(parts)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
