"""Per-frame, per-encoder GPU attribution from a Metal System Trace export.

Inputs: a directory holding metal-gpu-intervals.xml and
metal-application-encoders-list.xml (and optionally the counters), exported
by `xctrace export`. Output: per encoder index (the encoder's position in its
command buffer), the median vertex, fragment and compute time, CPU encode time,
grouped by frame structure; and per-frame GPU busy time.

Starting a recording hitches the app and leaves the GPU governor low for a
while, so the first `--skip-s` seconds of the app's GPU work (default 1.5) are
left out; the `window` line says how much was read. `--json <path>` also
writes every command buffer read, with each encoder's V/F/C intervals, for
`roles.py` to count overlapping work once.

Usage: frames.py <dir> [process-substring] [--skip-s 1.5] [--json <path>]
"""
import argparse
import collections
import re
import json
import statistics
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from xtable import rows  # noqa: E402


def ns(cell):
    return int(cell[1]) if cell else 0


def load(d, pid_filter=None, skip_ns=0):
    _, gi = rows(d + "/metal-gpu-intervals.xml")
    _, el = rows(d + "/metal-application-encoders-list.xml")
    enc = {}
    for r in el:
        if r["event-type"] and r["event-type"][0] != "Encoding":
            continue
        eid = r["encoder-id"][0] if r["encoder-id"] else None
        if eid is None:
            continue
        idx = r["encoder-label-indexed"][0] if r["encoder-label-indexed"] else ""
        e = enc.setdefault(eid, {"cb": r["cmdbuffer-id"][0], "label": idx, "cpu_ns": 0,
                                  "frame": r["frame-number"][0] if r["frame-number"] else None,
                                  "thread": r["thread"][0] if r["thread"] else None,
                                  "cpu_start": ns(r["start"])})
        e["cpu_ns"] += ns(r["duration"])
    gpu = collections.defaultdict(lambda: {"Vertex": 0, "Fragment": 0, "Compute": 0, "spans": []})
    mine = [r for r in gi if not pid_filter or (r["process"] and pid_filter in r["process"][0])]
    first = min((ns(r["start"]) for r in mine), default=0)
    for r in mine:
        if ns(r["start"]) < first + skip_ns:
            continue
        eid = r["encoder-id"][0] if r["encoder-id"] else None
        ch = r["channel-name"][0] if r["channel-name"] else None
        if eid is None or ch not in ("Vertex", "Fragment", "Compute"):
            continue
        s, dur = ns(r["start"]), ns(r["duration"])
        g = gpu[eid]
        g[ch] += dur
        g["spans"].append((s, s + dur, ch))
        g["cb"] = r["cmdbuffer-id"][0]
    return enc, gpu


def union(spans):
    tot = 0
    cur = None
    for s, e in sorted(spans):
        if cur is None or s > cur[1]:
            if cur:
                tot += cur[1] - cur[0]
            cur = [s, e]
        else:
            cur[1] = max(cur[1], e)
    if cur:
        tot += cur[1] - cur[0]
    return tot


def _index(label):
    m = re.match(r"\[(\d+)\]", label or "")
    return int(m.group(1)) if m else 10**6


def frames(enc, gpu):
    by_cb = collections.defaultdict(list)
    for eid, g in gpu.items():
        cb = g.get("cb")
        e = enc.get(eid, {})
        by_cb[cb].append((eid, g, e))
    out = []
    for cb, items in by_cb.items():
        items.sort(key=lambda x: (_index(x[2].get("label", "")), min(s for s, _, _ in x[1]["spans"])))
        spans = [sp for _, g, _ in items for sp in g["spans"]]
        start = min(s for s, _, _ in spans)
        end = max(e for _, e, _ in spans)
        out.append({"cb": cb, "start": start, "end": end, "busy": union([(s, e) for s, e, _ in spans]),
                    "encoders": [{"label": e.get("label", "?"), "v": g["Vertex"], "f": g["Fragment"],
                                  "c": g["Compute"], "cpu": e.get("cpu_ns", 0),
                                  "wall": max(x for _, x, _ in g["spans"]) - min(s for s, _, _ in g["spans"]),
                                  "spans": g["spans"]}
                                 for eid, g, e in items]})
    out.sort(key=lambda f: f["start"])
    return out


def summarise(fs):
    groups = collections.defaultdict(list)
    for f in fs:
        sig = len(f["encoders"])
        groups[sig].append(f)
    res = {}
    for sig, g in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        rowsout = []
        for i in range(sig):
            col = [f["encoders"][i] for f in g]
            med = lambda k: statistics.median(c[k] for c in col) / 1e6
            label = collections.Counter(c["label"] for c in col).most_common(1)[0][0]
            rowsout.append({"i": i, "label": label, "v_ms": round(med("v"), 3), "f_ms": round(med("f"), 3),
                            "c_ms": round(med("c"), 3), "wall_ms": round(med("wall"), 3), "cpu_ms": round(med("cpu"), 3)})
        busy = [f["busy"] / 1e6 for f in g]
        res[sig] = {"frames": len(g), "busy_ms_median": round(statistics.median(busy), 3),
                    "busy_ms_p95": round(sorted(busy)[int(len(busy) * 0.95)], 3), "encoders": rowsout}
    return res


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("dir")
    parser.add_argument("process", nargs="?", default=None)
    parser.add_argument("--skip-s", type=float, default=1.5)
    parser.add_argument("--json", default="")
    args = parser.parse_args()
    enc, gpu = load(args.dir, args.process, int(args.skip_s * 1e9))
    fs = frames(enc, gpu)
    res = summarise(fs)
    if args.json:
        with open(args.json, "w") as handle:
            json.dump([{"cb": f["cb"], "start": f["start"], "busy": f["busy"],
                        "encoders": [{"label": e["label"], "v": e["v"], "f": e["f"], "c": e["c"],
                                      "spans": e["spans"]} for e in f["encoders"]]} for f in fs], handle)
    span = (fs[-1]["end"] - fs[0]["start"]) / 1e9 if fs else 0.0
    print("window: %.2f s read after skipping %.1f s" % (span, args.skip_s))
    print("command buffers:", len(fs))
    for sig, g in res.items():
        print("== %d encoders: %d command buffers, GPU busy median %.3f ms, p95 %.3f ms" % (sig, g["frames"], g["busy_ms_median"], g["busy_ms_p95"]))
        for e in g["encoders"]:
            print("  %-24s V %6.3f  F %6.3f  C %6.3f  wall %6.3f  cpu %6.3f" % (e["label"], e["v_ms"], e["f_ms"], e["c_ms"], e["wall_ms"], e["cpu_ms"]))
