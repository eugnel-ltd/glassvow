"""Display-side view of a Metal System Trace: how long each of the app's
frames stayed on screen (16.66 ms = on time; 33.3 ms = a repeated vsync), per
app frame its GPU busy time and span, the GPU performance states, and whether a
device condition held the GPU or the thermal state (`conditions`).

Usage: display.py <dir> <process-substring>
"""
import collections
import re
import statistics
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from xtable import rows  # noqa: E402


def main(d, proc):
    _, disp = rows(d + "/displayed-surfaces-interval.xml")
    shown = {}
    for r in disp:
        lab = r["event-label"][0] if r["event-label"] else ""
        if proc not in lab:
            continue
        m = re.search(r":Frame (\d+):", lab)
        if m:
            shown[int(m.group(1))] = (int(r["start"][1]), int(r["duration"][1]), r["cpu-to-display-latency"][0] if r["cpu-to-display-latency"] else "")
    _, gi = rows(d + "/metal-gpu-intervals.xml")
    per = collections.defaultdict(list)
    for r in gi:
        if not r["process"] or proc not in r["process"][0]:
            continue
        ch = r["channel-name"][0] if r["channel-name"] else None
        if ch not in ("Vertex", "Fragment", "Compute") or not r["frame-number"]:
            continue
        m = re.search(r"(\d+)", r["frame-number"][0])
        s = int(r["start"][1]); e = s + int(r["duration"][1])
        per[int(m.group(1))].append((s, e))
    def union(sp):
        tot = 0; cur = None
        for s, e in sorted(sp):
            if cur is None or s > cur[1]:
                if cur: tot += cur[1] - cur[0]
                cur = [s, e]
            else:
                cur[1] = max(cur[1], e)
        return tot + (cur[1] - cur[0] if cur else 0)
    durs = [v[1] / 1e6 for v in shown.values()]
    if durs:
        c = collections.Counter(round(x / 16.667) for x in durs)
        print("frames shown: %d; on-screen time in vsyncs: %s" % (len(durs), dict(sorted(c.items()))))
        lat = [float(v[2].split()[0]) for v in shown.values() if v[2].endswith("ms")]
        if lat:
            print("cpu-to-display latency ms: median %.1f p95 %.1f" % (statistics.median(lat), sorted(lat)[int(len(lat) * 0.95)]))
    busy = {f: union(sp) / 1e6 for f, sp in per.items()}
    span = {f: (max(e for _, e in sp) - min(s for s, _ in sp)) / 1e6 for f, sp in per.items()}
    if busy:
        b = sorted(busy.values())
        print("GPU busy per app frame ms: median %.2f p95 %.2f max %.2f (n=%d)" % (statistics.median(b), b[int(len(b) * 0.95)], b[-1], len(b)))
        sp = sorted(span.values())
        print("GPU first-to-last span per frame ms: median %.2f p95 %.2f max %.2f" % (statistics.median(sp), sp[int(len(sp) * 0.95)], sp[-1]))
    long = [f for f, v in shown.items() if v[1] > 25e6]
    for f in sorted(long)[:12]:
        prev = [busy.get(f - k) for k in (2, 1, 0)]
        print("  frame %d shown %.1f ms; GPU busy of frames f-2..f: %s" % (f, shown[f][1] / 1e6, ["%.1f" % x if x else "-" for x in prev]))
    try:
        _, ps = rows(d + "/gpu-performance-state-intervals.xml")
        acc = collections.Counter()
        for r in ps:
            acc[r["gpu-performance-state"][0]] += int(r["duration"][1])
        tot = sum(acc.values())
        print("GPU performance state share:", {k: "%.0f%%" % (100 * v / tot) for k, v in acc.items()},
              "labelled induced:", sorted({r["is-induced"][0] for r in ps}))
    except (FileNotFoundError, ET.ParseError):
        pass
    conditions(d)


def conditions(d):
    """Whether a device condition held the GPU or the thermal state: the
    consistent (induced) GPU performance state, the driver's desired state, and
    the thermal state's own induced flag."""
    try:
        _, info = rows(d + "/gpu-performance-state-info.xml")
        for r in info:
            print("GPU consistent state: available %s, enabled %s, sustained %s, state %s" % (
                r["consistent-state-available"][0], r["consistent-state-enabled"][0],
                r["consistent-state-sustained"][0], r["consistent-state"][1]))
        _, dev = rows(d + "/gpu-performance-device-state-intervals.xml")
        print("GPU desired states over the trace:", sorted({r["desired-state"][1] for r in dev}))
        _, th = rows(d + "/device-thermal-state-intervals.xml")
        print("thermal:", sorted({(r["thermal-state"][0], "induced " + r["is-induced"][0]) for r in th}))
    except (FileNotFoundError, ET.ParseError, KeyError, TypeError):
        print("device conditions: tables not exported")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
