#!/usr/bin/env python3
"""Name the passes of a map stage frame and read them at the reference clock.

Input is a `frames.py` report (`<label>.passes.txt`). The dominant stage-frame
shape is the command buffer with the most encoders among the common shapes
(at the rest cadence, stage and non-stage frames are equally common). Godot's
Metal driver labels no encoders, so passes are named by structure:

  compute                         particles
  renders before the main pass    shadow 1, shadow 2, ...
  main 3D                         the render with the most vertex time
  renders after it, up to a blit  glow 1, ..., tonemap (the last)
  renders after that blit         2D 1, 2D 2, ... (the stage's display, the
                                  tilt-shift view, the HUD, any grain passes)

The GPU clock moves between runs (DVFS), so every time is scaled to the
reference clock by a pass whose work the change under test leaves alone. The
default is the main 3D pass's fragment time, 4.091 ms at the reference: R2's
Journey view rendered every frame, iPad 8 at the Medium state
(docs/design/2026-10-02-map-living-land/r3/map-trace/attribution-r2.txt in the
trace spike). Use `--ref-ms` for another view (R2's fresh-run opening view:
5.24) and `--ref-pass` for another reference pass.

Usage:
  python3 tools/map_trace/roles.py <passes.txt> [--ref-pass main] [--ref-ms 4.091]
          [--names "2D 1=tilt-shift view,2D 2=display+HUD"]
  python3 tools/map_trace/roles.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile

REF_MS = 4.091
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
    top = max(g["cbs"] for g in common)
    return max((g for g in common if g["cbs"] >= 0.4 * top), key=lambda g: g["n"])


def roles(enc: list[dict]) -> list[str]:
    names = [""] * len(enc)
    renders = [i for i, e in enumerate(enc) if "Render" in e["label"]]
    blits = [i for i, e in enumerate(enc) if "Blit" in e["label"]]
    for i, e in enumerate(enc):
        if "Compute" in e["label"]:
            names[i] = "particles"
        elif "Blit" in e["label"]:
            names[i] = "blit"
    main = max(renders, key=lambda i: enc[i]["v"])
    names[main] = "main 3D"
    for k, i in enumerate(i for i in renders if i < main):
        names[i] = "shadow %d" % (k + 1)
    end = next((b for b in blits if b > main), len(enc))
    post = [i for i in renders if main < i < end]
    for k, i in enumerate(post):
        names[i] = "tonemap" if k == len(post) - 1 else "glow %d" % (k + 1)
    for k, i in enumerate(i for i in renders if i > end):
        names[i] = "2D %d" % (k + 1)
    return names


def report(text: str, ref_pass: str = "main 3D", ref_ms: float = REF_MS,
           aliases: dict[str, str] | None = None) -> dict:
    group = stage_frame(parse(text))
    names = roles(group["enc"])
    ref = sum(e["f"] for e, n in zip(group["enc"], names) if n == ref_pass)
    k = ref_ms / ref if ref else 1.0
    passes = []
    for e, n in zip(group["enc"], names):
        passes.append({"name": (aliases or {}).get(n, n), "role": n, "v": e["v"], "f": e["f"], "c": e["c"],
                       "v_ref": e["v"] * k, "f_ref": e["f"] * k, "c_ref": e["c"] * k})
    two_d = [p for p in passes if p["role"].startswith("2D ")]
    three_d = [p for p in passes if not p["role"].startswith("2D ") and p["role"] != "blit"]
    return {"frames": group["cbs"], "encoders": group["n"], "busy": group["busy"], "p95": group["p95"],
            "clock_factor": k, "ref": ref, "passes": passes,
            "two_d_ref": sum(p["v_ref"] + p["f_ref"] for p in two_d),
            "two_d_f_ref": sum(p["f_ref"] for p in two_d),
            "three_d_ref": sum(p["v_ref"] + p["f_ref"] + p["c_ref"] for p in three_d),
            "busy_ref": group["busy"] * k}


def render(r: dict) -> str:
    out = ["stage frames %d, %d encoders, GPU busy median %.2f ms (p95 %.2f); clock factor %.3f"
           " (reference pass %.3f ms)" % (r["frames"], r["encoders"], r["busy"], r["p95"], r["clock_factor"], r["ref"])]
    for p in r["passes"]:
        if p["role"] == "blit":
            continue
        out.append("  %-22s V %6.3f F %6.3f C %6.3f | at the reference clock V %6.3f F %6.3f C %6.3f"
                   % (p["name"], p["v"], p["f"], p["c"], p["v_ref"], p["f_ref"], p["c_ref"]))
    out.append("BUDGET LINE at the reference clock: 2D composite %.2f ms (fragment %.2f); 3D chain %.2f ms;"
               " GPU busy %.2f ms" % (r["two_d_ref"], r["two_d_f_ref"], r["three_d_ref"], r["busy_ref"]))
    return "\n".join(out)


SAMPLE = """command buffers: 30
== 1 encoders: 20 command buffers, GPU busy median 0.072 ms, p95 1.137 ms
  [0] Render Command 0     V  0.000  F  0.000  C  0.007  wall  0.072  cpu  0.125
== 14 encoders: 10 command buffers, GPU busy median 9.000 ms, p95 10.000 ms
  [0] Blit Command 0       V  0.000  F  0.000  C  0.005  wall  0.005  cpu  0.060
  [1] Compute Command 1    V  0.000  F  0.000  C  0.200  wall  0.213  cpu  0.055
  [2] Blit Command 2       V  0.000  F  0.000  C  0.003  wall  0.003  cpu  0.025
  [3] Render Command 3     V  0.020  F  0.300  C  0.000  wall  0.401  cpu  0.070
  [4] Render Command 4     V  0.200  F  0.200  C  0.000  wall  0.472  cpu  0.395
  [5] Render Command 5     V  2.000  F  8.000  C  0.000  wall  6.042  cpu  0.862
  [6] Render Command 6     V  0.010  F  0.200  C  0.000  wall  4.180  cpu  0.072
  [7] Render Command 7     V  0.010  F  0.300  C  0.000  wall  4.394  cpu  0.048
  [8] Blit Command 8       V  0.000  F  0.000  C  0.003  wall  0.003  cpu  0.034
  [9] Render Command 9     V  0.100  F  0.500  C  0.000  wall  7.376  cpu  0.485
  [10] Render Command 10   V  0.100  F  1.400  C  0.000  wall  7.157  cpu  0.042
  [11] Blit Command 11     V  0.000  F  0.000  C  0.009  wall  0.009  cpu  0.024
"""


def self_test() -> int:
    r = report(SAMPLE, ref_ms=4.0, aliases={"2D 1": "tilt-shift view"})
    names = [p["name"] for p in r["passes"]]
    expect = ["blit", "particles", "blit", "shadow 1", "shadow 2", "main 3D", "glow 1", "tonemap", "blit",
              "tilt-shift view", "2D 2", "blit"]
    assert names == expect, names
    assert abs(r["clock_factor"] - 0.5) < 1e-9, r["clock_factor"]
    assert abs(r["two_d_ref"] - 1.05) < 1e-9, r["two_d_ref"]
    assert abs(r["two_d_f_ref"] - 0.95) < 1e-9, r["two_d_f_ref"]
    assert abs(r["busy_ref"] - 4.5) < 1e-9, r["busy_ref"]
    assert "BUDGET LINE" in render(r)
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        handle.write(SAMPLE)
    assert main([handle.name, "--ref-ms", "4.0"]) == 0
    print("roles self-test OK")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--self-test"]:
        return self_test()
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("passes")
    parser.add_argument("--ref-pass", default="main 3D")
    parser.add_argument("--ref-ms", type=float, default=REF_MS)
    parser.add_argument("--names", default="", help='aliases, "2D 1=tilt-shift view,2D 2=display+HUD"')
    args = parser.parse_args(argv)
    aliases = dict(part.split("=", 1) for part in args.names.split(",") if "=" in part)
    with open(args.passes) as handle:
        print(render(report(handle.read(), args.ref_pass, args.ref_ms, aliases)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
