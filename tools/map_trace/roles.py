#!/usr/bin/env python3
"""Name the passes of a map stage frame and read them at the reference clock.

Input is a `frames.py` report (`<label>.passes.txt`) and, for the overlap and
near-reference figures, the `--json` it wrote beside it (`--frames`). The
dominant stage-frame shape is the command buffer with the most encoders among
the common shapes (at the rest cadence, stage and non-stage frames are equally
common). Godot's Metal driver labels no encoders, so passes are named by
structure:

  compute                         particles
  renders before the main pass    shadow 1, shadow 2, ...
  main 3D                         the render with the most vertex time
  the next --post3d renders       glow 1, ..., tonemap (the last)
  every render after those        2D 1, 2D 2, ... (the tilt-shift view, the
                                  display and HUD, any grain passes)

Where a blit falls varies between the Mac and the iPad, so the end of the 3D
chain is given, not guessed: the journey land's environment draws three glow
passes and the tonemap after its main pass (--post3d 4, the default; confirm a
new environment with --trace-kill=glow). A present pass the driver puts in a
command buffer of its own (about 1 ms at display resolution on the iPad, in
every build) is not part of the stage frame and is not counted.

The GPU clock moves between runs (DVFS), so every time is scaled to the
reference clock by a pass whose work the change under test leaves alone. The
default is the main 3D pass's fragment time, 4.091 ms at the reference: R2's
Journey view rendered every frame, iPad 8 at the Medium state
(docs/design/2026-10-02-map-living-land/r3/map-trace/attribution-r2.txt in the
trace spike). Use `--ref-ms` for another view (R2's fresh-run opening view:
5.24) and `--ref-pass` for another reference pass. A step that changes the 3D
scene must not scale by the main pass: use `--ref-pass tonemap --ref-ms 0.270`
(a full-screen pass at the stage's size, the same work in any view).

Passes do not scale alike with the clock, so the report also:
  - scales by a second pass (`--check-pass`, default the tonemap at 0.270 ms)
    and prints CLOCK DISAGREES when the two factors differ by more than 10%;
  - prints SHORT WINDOW below 120 stage frames (a recording cut short, or one
    read mostly across the recording-start hitch);
  - with `--frames`, reads the 2D composite raw from the frames whose own
    reference pass ran within 10% of the reference clock, which needs no
    scaling, and counts each group's GPU time with overlap once: vertex work
    of one pass runs beside fragment work of another, so V+F sums overstate.

The BUDGET LINE's gate figures are fragment sums (R2's 6.3 ms is one); the
occupied figures (V, F and C intervals merged) sit beside them.

Usage:
  python3 tools/map_trace/roles.py <passes.txt> [--frames <frames.json>]
          [--ref-pass "main 3D"] [--ref-ms 4.091] [--check-pass tonemap] [--check-ms 0.270]
          [--post3d 4] [--names "2D 1=tilt-shift view,2D 2=display+HUD"]
  python3 tools/map_trace/roles.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
import tempfile

REF_MS = 4.091
CHECK_PASS = "tonemap"
CHECK_MS = 0.270
MIN_FRAMES = 120
NEAR = 0.10
GROUP = re.compile(r"== (\d+) encoders: (\d+) command buffers, GPU busy median ([\d.]+) ms, p95 ([\d.]+)")
ENCODER = re.compile(r"\s+(.+?)\s+V\s+([\d.]+)\s+F\s+([\d.]+)\s+C\s+([\d.]+)\s+wall\s+([\d.]+)\s+cpu\s+([\d.]+)")


def parse(text: str) -> list[dict]:
    groups: list[dict] = []
    current = None
    for line in text.splitlines():
        m = GROUP.match(line)
        if m:
            current = {"n": int(m.group(1)), "cbs": int(m.group(2)), "busy": float(m.group(3)),
                       "p95": float(m.group(4)), "enc": []}
            groups.append(current)
            continue
        m = ENCODER.match(line)
        if m and current is not None:
            current["enc"].append({"label": m.group(1), "v": float(m.group(2)), "f": float(m.group(3)),
                                   "c": float(m.group(4)), "cpu": float(m.group(6))})
    return groups


def stage_frame(groups: list[dict]) -> dict:
    common = [g for g in groups if g["n"] > 6]
    if not common:
        raise SystemExit("roles: no stage frames in this report (an empty or truncated recording?)")
    top = max(g["cbs"] for g in common)
    return max((g for g in common if g["cbs"] >= 0.4 * top), key=lambda g: g["n"])


def roles(enc: list[dict], post3d: int = 4) -> list[str]:
    names = [""] * len(enc)
    renders = [i for i, e in enumerate(enc) if "Render" in e["label"]]
    for i, e in enumerate(enc):
        if "Compute" in e["label"]:
            names[i] = "particles"
        elif "Blit" in e["label"]:
            names[i] = "blit"
    main = max(renders, key=lambda i: enc[i]["v"])
    names[main] = "main 3D"
    for k, i in enumerate(i for i in renders if i < main):
        names[i] = "shadow %d" % (k + 1)
    after = [i for i in renders if i > main]
    post = after[:post3d]
    for k, i in enumerate(post):
        names[i] = "tonemap" if k == len(post) - 1 else "glow %d" % (k + 1)
    for k, i in enumerate(after[post3d:]):
        names[i] = "2D %d" % (k + 1)
    return names


def _union_ms(spans: list) -> float:
    total, cur = 0, None
    for s, e in sorted((s, e) for s, e, _ in spans):
        if cur is None or s > cur[1]:
            total += (cur[1] - cur[0]) if cur else 0
            cur = [s, e]
        else:
            cur[1] = max(cur[1], e)
    total += (cur[1] - cur[0]) if cur else 0
    return total / 1e6


def per_frame(frames: list[dict], names: list[str], ref_pass: str, ref_ms: float) -> dict:
    """Per stage frame: 2D and 3D occupancy, 2D fragment, and the frame's own clock factor."""
    out = {"two_d_occ": [], "three_d_occ": [], "two_d_f": [], "k": []}
    for f in frames:
        enc = f["encoders"]
        if len(enc) != len(names):
            continue
        two = [e for e, n in zip(enc, names) if n.startswith("2D ")]
        three = [e for e, n in zip(enc, names) if not n.startswith("2D ") and n != "blit"]
        ref = sum(e["f"] for e, n in zip(enc, names) if n == ref_pass) / 1e6
        if ref <= 0:
            continue
        out["two_d_occ"].append(_union_ms([s for e in two for s in e["spans"]]))
        out["three_d_occ"].append(_union_ms([s for e in three for s in e["spans"]]))
        out["two_d_f"].append(sum(e["f"] for e in two) / 1e6)
        out["k"].append(ref_ms / ref)
    return out


def report(text: str, ref_pass: str = "main 3D", ref_ms: float = REF_MS,
           aliases: dict[str, str] | None = None, post3d: int = 4,
           check_pass: str = CHECK_PASS, check_ms: float = CHECK_MS,
           frames: list[dict] | None = None) -> dict:
    group = stage_frame(parse(text))
    names = roles(group["enc"], post3d)
    ref = sum(e["f"] for e, n in zip(group["enc"], names) if n == ref_pass)
    check = sum(e["f"] for e, n in zip(group["enc"], names) if n == check_pass)
    k = ref_ms / ref if ref else 1.0
    k_check = check_ms / check if check else 0.0
    passes = []
    for e, n in zip(group["enc"], names):
        passes.append({"name": (aliases or {}).get(n, n), "role": n, "v": e["v"], "f": e["f"], "c": e["c"],
                       "v_ref": e["v"] * k, "f_ref": e["f"] * k, "c_ref": e["c"] * k})
    two_d = [p for p in passes if p["role"].startswith("2D ")]
    three_d = [p for p in passes if not p["role"].startswith("2D ") and p["role"] != "blit"]
    warnings = []
    if group["cbs"] < MIN_FRAMES:
        warnings.append("SHORT WINDOW: %d stage frames (fewer than %d); record again" % (group["cbs"], MIN_FRAMES))
    if not k_check or abs(k / k_check - 1.0) > NEAR:
        warnings.append("CLOCK DISAGREES: %s gives %.3f, %s gives %.3f" % (ref_pass, k, check_pass, k_check))
    r = {"frames": group["cbs"], "encoders": group["n"], "busy": group["busy"], "p95": group["p95"],
         "clock_factor": k, "check_factor": k_check, "ref": ref, "check": check, "passes": passes,
         "ref_pass": ref_pass, "check_pass": check_pass,
         "two_d_f_ref": sum(p["f_ref"] for p in two_d),
         "two_d_f_check": sum(p["f"] for p in two_d) * k_check,
         "three_d_f_ref": sum(p["f_ref"] for p in three_d),
         "busy_ref": group["busy"] * k, "warnings": warnings}
    if frames is not None:
        pf = per_frame(frames, names, ref_pass, ref_ms)
        near = [f for f, kf in zip(pf["two_d_f"], pf["k"]) if abs(kf - 1.0) <= NEAR]
        r["two_d_occ_ref"] = statistics.median(pf["two_d_occ"]) * k if pf["two_d_occ"] else 0.0
        r["three_d_occ_ref"] = statistics.median(pf["three_d_occ"]) * k if pf["three_d_occ"] else 0.0
        r["near_frames"] = len(near)
        r["near_two_d_f"] = statistics.median(near) if near else None
    return r


def render(r: dict) -> str:
    out = ["stage frames %d, %d encoders, GPU busy median %.2f ms (p95 %.2f); clock factor %.3f"
           " (%s %.3f ms); by %s %.3f"
           % (r["frames"], r["encoders"], r["busy"], r["p95"], r["clock_factor"], r["ref_pass"], r["ref"],
              r["check_pass"], r["check_factor"])]
    out += ["WARNING " + w for w in r["warnings"]]
    for p in r["passes"]:
        if p["role"] == "blit":
            continue
        out.append("  %-22s V %6.3f F %6.3f C %6.3f | at the reference clock V %6.3f F %6.3f C %6.3f"
                   % (p["name"], p["v"], p["f"], p["c"], p["v_ref"], p["f_ref"], p["c_ref"]))
    line = ("BUDGET LINE at the reference clock: 2D composite %.2f ms fragment; 3D chain %.2f ms fragment;"
            " GPU busy %.2f ms" % (r["two_d_f_ref"], r["three_d_f_ref"], r["busy_ref"]))
    if "two_d_occ_ref" in r:
        line += ("; occupied with overlap counted once: 2D %.2f ms, 3D %.2f ms"
                 % (r["two_d_occ_ref"], r["three_d_occ_ref"]))
    out.append(line)
    out.append("CROSS-CHECK: scaled by %s the 2D composite fragment reads %.2f ms"
               % (r["check_pass"], r["two_d_f_check"]))
    if "near_frames" in r:
        out.append("NEAR THE REFERENCE CLOCK (%s within %d%%): %d frames%s"
                   % (r["ref_pass"], int(NEAR * 100), r["near_frames"],
                      ", raw 2D composite fragment median %.2f ms" % r["near_two_d_f"]
                      if r["near_two_d_f"] is not None else ""))
    return "\n".join(out)


SAMPLE = """command buffers: 30
== 1 encoders: 20 command buffers, GPU busy median 0.072 ms, p95 1.137 ms
  [0] Render Command 0     V  0.000  F  0.000  C  0.007  wall  0.072  cpu  0.125
== 12 encoders: 10 command buffers, GPU busy median 9.000 ms, p95 10.000 ms
  [0] Blit Command 0       V  0.000  F  0.000  C  0.005  wall  0.005  cpu  0.060
  [1] Compute Command 1    V  0.000  F  0.000  C  0.200  wall  0.213  cpu  0.055
  [2] Blit Command 2       V  0.000  F  0.000  C  0.003  wall  0.003  cpu  0.025
  [3] Render Command 3     V  0.020  F  0.300  C  0.000  wall  0.401  cpu  0.070
  [4] Render Command 4     V  0.200  F  0.200  C  0.000  wall  0.472  cpu  0.395
  [5] Render Command 5     V  2.000  F  8.000  C  0.000  wall  6.042  cpu  0.862
  [6] Render Command 6     V  0.010  F  0.200  C  0.000  wall  4.180  cpu  0.072
  [7] Render Command 7     V  0.010  F  0.540  C  0.000  wall  4.394  cpu  0.048
  [8] Blit Command 8       V  0.000  F  0.000  C  0.003  wall  0.003  cpu  0.034
  [9] Render Command 9     V  0.100  F  0.500  C  0.000  wall  7.376  cpu  0.485
  [10] Render Command 10   V  0.100  F  1.400  C  0.000  wall  7.157  cpu  0.042
  [11] Blit Command 11     V  0.000  F  0.000  C  0.009  wall  0.009  cpu  0.024
"""


def _sample_frames(group: dict, scale: float, overlap_ns: int) -> dict:
    """One command buffer laid out pass after pass at `scale` times the sample's
    times; the second 2D pass's vertex work starts `overlap_ns` early, beside
    the first 2D pass's fragment work."""
    t, enc = 0, []
    for e in group["enc"]:
        spans = []
        for ch, ms in (("Vertex", e["v"]), ("Fragment", e["f"]), ("Compute", e["c"])):
            if ms > 0:
                d = int(ms * scale * 1e6)
                spans.append([t, t + d, ch])
                t += d
        enc.append({"label": e["label"], "v": int(e["v"] * scale * 1e6), "f": int(e["f"] * scale * 1e6),
                    "c": int(e["c"] * scale * 1e6), "spans": spans})
    second_2d = enc[10]["spans"]
    second_2d[0] = [second_2d[0][0] - overlap_ns, second_2d[0][1] - overlap_ns, "Vertex"]
    return {"cb": 1, "start": 0, "busy": t, "encoders": enc}


def self_test() -> int:
    r = report(SAMPLE, ref_ms=4.0, aliases={"2D 1": "tilt-shift view"}, post3d=2, check_ms=0.27)
    names = [p["name"] for p in r["passes"]]
    expect = ["blit", "particles", "blit", "shadow 1", "shadow 2", "main 3D", "glow 1", "tonemap", "blit",
              "tilt-shift view", "2D 2", "blit"]
    assert names == expect, names
    assert abs(r["clock_factor"] - 0.5) < 1e-9, r["clock_factor"]
    assert abs(r["two_d_f_ref"] - 0.95) < 1e-9, r["two_d_f_ref"]
    assert abs(r["busy_ref"] - 4.5) < 1e-9, r["busy_ref"]
    assert any(w.startswith("SHORT WINDOW") for w in r["warnings"]), r["warnings"]
    assert not any(w.startswith("CLOCK DISAGREES") for w in r["warnings"]), r["warnings"]
    off = report(SAMPLE, ref_ms=4.0, post3d=2, check_ms=0.40)
    assert any(w.startswith("CLOCK DISAGREES") for w in off["warnings"]), off["warnings"]
    group = stage_frame(parse(SAMPLE))
    # Two frames at the sample's clock (factor 0.5 to the reference) and one at
    # the reference clock itself: only that one is near the reference.
    frames = [_sample_frames(group, 1.0, 50_000), _sample_frames(group, 1.0, 50_000),
              _sample_frames(group, 0.5, 0)]
    r = report(SAMPLE, ref_ms=4.0, post3d=2, check_ms=0.27, frames=frames)
    assert r["near_frames"] == 1 and abs(r["near_two_d_f"] - 0.95) < 1e-6, r
    # V+F of the 2D passes is 2.1 ms at the sample's clock; the 50 us of the
    # second's vertex work beside the first's fragment work counts once, so
    # 2.05 ms (the median frame), times the factor 0.5.
    assert abs(r["two_d_occ_ref"] - 1.025) < 1e-6, r["two_d_occ_ref"]
    text = render(r)
    assert "BUDGET LINE" in text and "CROSS-CHECK" in text and "NEAR THE REFERENCE CLOCK" in text
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(SAMPLE)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as sidecar:
        json.dump(frames, sidecar)
    assert main([handle.name, "--ref-ms", "4.0", "--post3d", "2", "--frames", sidecar.name]) == 0
    print("roles self-test OK")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("passes")
    parser.add_argument("--frames", default="", help="the frames.py --json sidecar")
    parser.add_argument("--ref-pass", default="main 3D")
    parser.add_argument("--ref-ms", type=float, default=REF_MS)
    parser.add_argument("--check-pass", default=CHECK_PASS)
    parser.add_argument("--check-ms", type=float, default=CHECK_MS)
    parser.add_argument("--post3d", type=int, default=4, help="renders after the main pass that are 3D")
    parser.add_argument("--names", default="", help='aliases, "2D 1=tilt-shift view,2D 2=display+HUD"')
    args = parser.parse_args(argv)
    aliases = dict(part.split("=", 1) for part in args.names.split(",") if "=" in part)
    frames = None
    if args.frames:
        with open(args.frames) as handle:
            frames = json.load(handle)
    with open(args.passes) as handle:
        print(render(report(handle.read(), args.ref_pass, args.ref_ms, aliases, args.post3d,
                            args.check_pass, args.check_ms, frames)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
