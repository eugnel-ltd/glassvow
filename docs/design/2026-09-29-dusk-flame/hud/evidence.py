#!/usr/bin/env python3
"""Captures, sheets and measurements for the flame on the HUD (#577, lock PR 5).

Every capture goes through ``tools/shot.sh`` against the production code: the
flame lab hosts the production ``HudBar`` and lights it through
``HudBar.show_flame``; the reward lab builds the production ``RewardScreen``;
the stall is the real route, opened by a Development Scenario. Record into a
scratch folder outside the repository, then build the images next to this file:

    python3 docs/design/2026-09-29-dusk-flame/hud/evidence.py \
        --capture --recordings /tmp/flame-hud

Without ``--capture`` the images are rebuilt from recordings already on disk.
``--measure`` prints the parity, legibility and motion numbers the README
quotes. The numeral comparison needs two scratch edits of
``HudBar.LANTERN_COUNT_BOX`` and is captured by hand (see the README).
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps, ImageStat

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FONT_TC = ROOT / "assets/fonts/NotoSerifTC-Regular.woff2"
FONT_TITLE = ROOT / "assets/fonts/Cinzel-700.woff2"

# id, tier label, way label: the flame lab's POSES, in its order.
POSES = [
    ("kindling", "Kindling 燃", "the starter deck"),
    ("steady-shatter", "Steady 定", "Shatter 霜焰"),
    ("steady-lantern", "Steady 定", "Lantern 熾焰"),
    ("steady-edge", "Steady 定", "Edge 蝕焰"),
    ("true-shatter", "True 真", "Shatter 霜焰"),
    ("true-lantern", "True 真", "Lantern 熾焰"),
    ("true-edge", "True 真", "Edge 蝕焰"),
    ("shatter-edge-fringe", "Steady 定", "Shatter + Edge fringe"),
    ("lantern-shatter-fringe", "Steady 定", "Lantern + Shatter fringe"),
    ("soot", "Soot 塵", "scattered"),
]
# name, --shape, --vp (the stage at its device density), density note.
SHAPES = [
    ("pad", "pad-landscape", "2360x1640", "1180×820 stage at 2× (iPad)"),
    ("desktop", "desktop-landscape", "2916x1640", "1458×820 stage at 2× (Retina Mac)"),
    ("phone", "phone-landscape", "2532x1170", "844×390 stage at 3× (iPhone)"),
]
PHONE = ["--shape=phone-landscape", "--vp=2532x1170"]
STILL_AT = "1.2"
MOTION_TIERS = ["soot", "kindling", "steady-lantern", "true-lantern"]
FRAMES, STEP = 60, 1.0 / 30.0
TWEEN_FROM, TWEEN_TO, TWEEN_FRAMES, TWEEN_STEP = "kindling", "steady-shatter", 11, 0.1
# The stall as the real route opens it: the Scenario catalogue's own seed and
# shop node, with two Shatter cards so the deck reads Steady Shatter (lock §4:
# the starter's one card of each way plus uppercut and quakeblow is 3/1/1).
STALL = {"id": "custom", "revision": 1, "seed": 18501, "shape": "phone-landscape",
         "locale": "en", "overrides": {"act": 0, "node": "9,3", "gold": 999,
                                       "add_cards": ["uppercut", "quakeblow"]}}
# A real fight on the catalogue's combat-normal waystone with the same deck, so
# the combat HUD's lantern is lit by the domain's own startCombat reading.
FIGHT = {"id": "custom", "revision": 1, "seed": 18501, "shape": "phone-landscape",
         "locale": "en", "overrides": {"act": 0, "node": "1,2", "kind": "monster",
                                       "enemies": ["sporeling", "duskfang"],
                                       "add_cards": ["uppercut", "quakeblow"]}}
# Numeral placements compared once (README): folder suffix and label.
NUMERALS = [("glass", "over the glass (before)"), ("foot", "beneath the foot (chosen)"),
            ("beside", "beside the lantern")]
NUMERAL_POSES = ["kindling", "steady-edge", "true-shatter"]

CELL, LABEL_H, TITLE_H, PAD = 190, 34, 44, 12
# The lab's HUD crop: the 104 box and the numeral's box under it (to 122),
# grown by a tenth of the width at the sides and the top and a fiftieth at the
# foot: (122 + 10.4 + 2.08) / (104 + 20.8).
HUD_ASPECT = 1.078
BG, FG, DIM = (10, 12, 22), (226, 222, 210), (150, 158, 184)
MAX_EDGE = 1024
# The panes' box in the art's UV (the shader's PANES), and the art's share of
# the HUD crop: the crop is the lantern's 104 box grown to its numeral, plus
# the lab's 10 % margin, so the art sits in its top part.
PANES = (0.31, 0.43, 0.69, 0.795)
# A pixel of flame rather than of lit glass (Rec. 601 luminance): the spike's
# threshold for the HUD, which dims a lantern that cannot be spent to about 0.82.
LIT = 125


def font(path: Path, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(str(path), size)
    except OSError:
        return ImageFont.load_default()


def shot(*args: str) -> None:
    cmd = [str(ROOT / "tools/shot.sh"), *args]
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT, stdout=subprocess.DEVNULL, timeout=300)


def record(out: Path, *args: str) -> None:
    out.mkdir(parents=True, exist_ok=True)
    shot("--flame", f"--record={out}", *args)


def jobs(rec: Path) -> dict:
    """Every recording by name, so one can be taken again on its own."""
    out = {}
    for name, shape, vp, _ in SHAPES:
        out[name] = lambda n=name, s=shape, v=vp: record(
            rec / n, f"--shape={s}", f"--vp={v}", "--poses=all", f"--time={STILL_AT}")
    out["phone-today"] = lambda: record(rec / "phone-today", *PHONE, "--poses=kindling",
                                        f"--time={STILL_AT}", "--flame=off")
    out["phone-cycle"] = lambda: record(rec / "phone-cycle", *PHONE, "--poses=kindling",
                                        "--time=0", f"--frames={FRAMES}", f"--step={STEP:.4f}")
    out["phone-motion"] = lambda: record(rec / "phone-motion", *PHONE,
                                         f"--poses={','.join(MOTION_TIERS)}", "--time=0",
                                         f"--frames={FRAMES}", f"--step={STEP:.4f}")
    out["phone-tween"] = lambda: record(rec / "phone-tween", *PHONE, f"--from={TWEEN_FROM}",
                                        f"--poses={TWEEN_TO}", "--time=0",
                                        f"--frames={TWEEN_FRAMES}", f"--step={TWEEN_STEP}")
    out["reward"] = lambda: shot("--reward", "--concept=rows", "--case=full", *PHONE,
                                 "--pose=steady-shatter", f"--shot={rec / 'reward-phone.png'}")
    out["reward-offering"] = lambda: shot(
        "--reward", "--concept=rows", "--case=full", *PHONE, "--pose=steady-shatter",
        "--pick", f"--shot={rec / 'reward-offering-phone.png'}")
    out["shop"] = lambda: shot(f"--scenario={json.dumps(STALL, separators=(',', ':'))}",
                               *PHONE, "--settle=1.5", f"--shot={rec / 'shop-phone.png'}")
    out["fight"] = lambda: shot(f"--scenario={json.dumps(FIGHT, separators=(',', ':'))}",
                                *PHONE, "--settle=2", f"--shot={rec / 'fight-phone.png'}")
    # The pad HUD whole, so the count under the lantern is seen beside the
    # energy orb it sits above.
    out["pad-frame"] = lambda: shot("--flame", "--shape=pad-landscape", "--vp=2360x1640",
                                    "--pose=true-lantern", f"--time={STILL_AT}",
                                    "--inspect=off", f"--shot={rec / 'hud-pad.png'}")
    return out


def capture(rec: Path, only: list[str]) -> None:
    for name, job in jobs(rec).items():
        if not only or name in only:
            job()


def capture_numeral(rec: Path, placement: str) -> None:
    """One placement of the count, recorded with LANTERN_COUNT_BOX as edited."""
    record(rec / f"numeral-{placement}", *PHONE, f"--poses={','.join(NUMERAL_POSES)}",
           f"--time={STILL_AT}")


# ---------------------------------------------------------------- images

def fit(im: Image.Image, width: int, height: int) -> Image.Image:
    im = im.copy()
    im.thumbnail((width, height), Image.LANCZOS)
    cell = Image.new("RGB", (width, height), BG)
    cell.paste(im, ((width - im.width) // 2, (height - im.height) // 2))
    return cell


def glass(im: Image.Image) -> Image.Image:
    """The large lantern's lights, with a little hood and foot."""
    w, h = im.size
    return im.crop((int(w * 0.27), int(h * 0.37), int(w * 0.73), int(h * 0.86)))


def cell_h(kind: str) -> int:
    """A HUD crop is the lantern's box and its numeral under it: taller than wide."""
    return int(CELL * HUD_ASPECT) if kind == "hud" else CELL


def tile(path: Path, kind: str, width: int, height: int = 0) -> Image.Image:
    im = Image.open(path).convert("RGB")
    return fit(glass(im) if kind == "big" else im, width, height or width)


def sheet(rec: Path, kind: str, title: str, note: str) -> Image.Image:
    """Ten poses, five across."""
    cols = 5
    tall = cell_h(kind)
    width = PAD * 2 + cols * CELL
    out = Image.new("RGB", (width, TITLE_H + 2 * (tall + LABEL_H) + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), title, font=font(FONT_TITLE, 20), fill=FG)
    draw.text((width - PAD, 16), note, font=font(FONT_TC, 14), fill=DIM, anchor="ra")
    small = font(FONT_TC, 13)
    for i, (pose, tier, way) in enumerate(POSES):
        x = PAD + (i % cols) * CELL
        y = TITLE_H + (i // cols) * (tall + LABEL_H)
        out.paste(tile(rec / f"{pose}_000_{kind}.png", kind, CELL, tall), (x, y))
        draw.text((x + 4, y + tall + 2), tier, font=small, fill=FG)
        draw.text((x + 4, y + tall + 17), way, font=small, fill=DIM)
    return out


def strip(folder: Path, stem: str, picks: list[int], title: str, side: int = 148) -> Image.Image:
    """The HUD lantern and the large one over a run of frames."""
    label_w = 110
    rows = (("HUD, phone", "hud"), ("large", "big"))
    heights = [int(side * cell_h(kind) / CELL) for _, kind in rows]
    out = Image.new("RGB", (PAD + label_w + side * len(picks) + PAD,
                            TITLE_H + sum(heights) + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), title, font=font(FONT_TITLE, 18), fill=FG)
    small = font(FONT_TC, 13)
    y = TITLE_H
    for (label, kind), tall in zip(rows, heights):
        draw.text((PAD, y + tall // 2 - 8), label, font=small, fill=DIM)
        for c, k in enumerate(picks):
            out.paste(tile(folder / f"{stem}_{k:03d}_{kind}.png", kind, side, tall),
                      (PAD + label_w + c * side, y))
        y += tall
    return out


def parity(rec: Path) -> tuple[Image.Image, dict]:
    """Today's lantern beside Kindling on the phone HUD, and their difference."""
    today = Image.open(rec / "phone-today" / "kindling_000_hud.png").convert("RGB")
    kindling = Image.open(rec / "phone" / "kindling_000_hud.png").convert("RGB")
    diff = ImageChops.difference(today, kindling)
    stats = diff_stats(diff)
    cycle = [Image.open(rec / "phone-cycle" / f"kindling_{k:03d}_hud.png").convert("RGB")
             for k in range(FRAMES)]
    over_time = [diff_stats(ImageChops.difference(today, f)) for f in cycle]
    stats["cycle_max"] = max(s["max"] for s in over_time)
    stats["cycle_mean_worst"] = max(s["mean"] for s in over_time)
    stats["cycle_frac_over_4"] = max(s["frac_over_4"] for s in over_time)
    side = 300
    tall = int(side * HUD_ASPECT)
    cols = [("today (flame off)", today), ("Kindling", kindling),
            ("difference × 16", diff.point(lambda v: min(255, v * 16)))]
    out = Image.new("RGB", (PAD * 2 + side * len(cols), TITLE_H + tall + LABEL_H + 40), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), "Today's lantern and Kindling · phone, 844×390 at 3×",
              font=font(FONT_TITLE, 18), fill=FG)
    for c, (label, im) in enumerate(cols):
        x = PAD + c * side
        out.paste(fit(im, side, tall), (x, TITLE_H))
        draw.text((x + 4, TITLE_H + tall + 6), label, font=font(FONT_TC, 14), fill=DIM)
    draw.text((PAD, TITLE_H + tall + LABEL_H + 2),
              f"still at {STILL_AT} s: mean {stats['mean']:.2f}, max {stats['max']} of 255;"
              f"  over two seconds of flicker: max {stats['cycle_max']},"
              f" worst mean {stats['cycle_mean_worst']:.2f}",
              font=font(FONT_TC, 14), fill=FG)
    return out, stats


def diff_stats(diff: Image.Image) -> dict:
    peak = sorted(max(p) for p in diff.getdata())
    n = len(peak)
    return {"mean": sum(ImageStat.Stat(diff).mean) / 3.0, "max": peak[-1],
            "p99": peak[int(n * 0.99)], "frac_over_4": sum(1 for v in peak if v > 4) / n}


def numerals(rec: Path) -> Image.Image:
    """The count's three placements, three readings each, phone HUD."""
    side = 200
    label_w = 190
    out = Image.new("RGB", (PAD + label_w + side * len(NUMERAL_POSES) + PAD,
                            TITLE_H + LABEL_H + side * len(NUMERALS) + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), "Where the ember count sits · phone, 844×390 at 3×",
              font=font(FONT_TITLE, 18), fill=FG)
    small = font(FONT_TC, 13)
    for c, pose in enumerate(NUMERAL_POSES):
        label = next(f"{t} · {w}" for p, t, w in POSES if p == pose)
        draw.text((PAD + label_w + c * side + 4, TITLE_H), label, font=small, fill=DIM)
    for r, (placement, label) in enumerate(NUMERALS):
        y = TITLE_H + LABEL_H + r * side
        draw.text((PAD, y + side // 2 - 8), label, font=small, fill=FG)
        for c, pose in enumerate(NUMERAL_POSES):
            path = rec / f"numeral-{placement}" / f"{pose}_000_hud.png"
            out.paste(tile(path, "hud", side, side), (PAD + label_w + c * side, y))
    return out


def screen(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    im.thumbnail((MAX_EDGE, MAX_EDGE), Image.LANCZOS)
    return im


def build(rec: Path) -> None:
    for name, _, _, note in SHAPES:
        s = sheet(rec / name, "hud", f"The flame on the HUD · {name}", note)
        s.save(HERE / f"sheet-{name}.png", optimize=True)
        if name == "phone":
            ImageOps.grayscale(s).save(HERE / "grey-phone.png", optimize=True)
    figures = sheet(rec / "pad", "big", "The figures, large",
                    "the lab's inspection lantern, same material")
    figures.save(HERE / "figures.png", optimize=True)
    ImageOps.grayscale(figures).save(HERE / "grey-figures.png", optimize=True)
    image, _ = parity(rec)
    image.save(HERE / "parity.png", optimize=True)
    strip(rec / "phone-tween", TWEEN_TO, [0, 2, 4, 6, 8, 10],
          "Kindling to Steady Shatter · every 0.2 s").save(HERE / "tween.png", optimize=True)
    strip(rec / "phone-motion", "soot", [0, 10, 20, 30, 40, 50],
          "Soot gutters · every 1/3 s").save(HERE / "soot.png", optimize=True)
    screen(rec / "reward-phone.png").save(HERE / "reward-phone.png", optimize=True)
    screen(rec / "reward-offering-phone.png").save(HERE / "reward-offering-phone.png",
                                                   optimize=True)
    screen(rec / "shop-phone.png").save(HERE / "shop-phone.png", optimize=True)
    screen(rec / "fight-phone.png").save(HERE / "fight-phone.png", optimize=True)
    screen(rec / "hud-pad.png").save(HERE / "hud-pad.png", optimize=True)
    if all((rec / f"numeral-{p}").is_dir() for p, _ in NUMERALS):
        numerals(rec).save(HERE / "numerals.png", optimize=True)


# ---------------------------------------------------------------- numbers

def panes(im: Image.Image) -> Image.Image:
    """The panes' box inside a HUD crop, found from the crop's own geometry:
    the art is the lantern box less its 5/104 inset, at the top of the crop."""
    w, h = im.size
    box = w / 1.2  # the lantern box, before the lab's 10 % margin each side
    margin = (w - box) / 2.0
    art = box * 94.0 / 104.0
    x0 = margin + (box - art) / 2.0
    y0 = margin + (box - art) / 2.0
    return im.crop((int(x0 + art * PANES[0]), int(y0 + art * PANES[1]),
                    int(x0 + art * PANES[2]), int(y0 + art * PANES[3])))


def figure(box: Image.Image) -> tuple[float, float, float, float, float]:
    """Mean luminance; the p95 of it (how bright the brightest glass burns);
    the lit figure's height from the foot of the box and its widest extent, both
    as shares of the box; and how solidly it fills the rectangle they make."""
    w, h = box.size
    px = box.load()
    top, widest, count = h, 0, 0
    for y in range(h):
        xs = [x for x in range(w) if px[x, y] >= LIT]
        if xs:
            top = min(top, y)
            widest = max(widest, xs[-1] - xs[0] + 1)
            count += len(xs)
    fill = count / ((h - top) * widest) if count else 0.0
    values = sorted(box.getdata())
    return (ImageStat.Stat(box).mean[0], values[int(len(values) * 0.95)],
            (h - top) / h if count else 0.0, widest / w, fill)


def measure(rec: Path) -> None:
    _, stats = parity(rec)
    print("parity, phone HUD crop, today against Kindling (levels of 255):")
    print(f"  still at {STILL_AT} s: mean {stats['mean']:.3f}  p99 {stats['p99']}  max {stats['max']}")
    print(f"  over {FRAMES} frames of flicker: max {stats['cycle_max']}  worst mean"
          f" {stats['cycle_mean_worst']:.3f}  worst share of pixels over 4:"
          f" {stats['cycle_frac_over_4']:.4f}")
    print("\nlegibility, phone HUD, luminance only, inside the panes' box:")
    print(f"{'pose':24s} {'mean L':>7s} {'p95 L':>6s} {'height':>7s} {'width':>6s} {'fill':>5s}")
    for pose, _, _ in POSES:
        im = Image.open(rec / "phone" / f"{pose}_000_hud.png").convert("L")
        mean, p95, height, width, fill = figure(panes(im))
        print(f"{pose:24s} {mean:7.1f} {p95:6.0f} {height:7.2f} {width:6.2f} {fill:5.2f}")
    print("\nmotion, phone HUD: median and p95 of the mean absolute frame-to-frame change (L)")
    for pose in MOTION_TIERS:
        diffs = []
        prev = None
        for k in range(FRAMES):
            box = panes(Image.open(rec / "phone-motion" / f"{pose}_{k:03d}_hud.png").convert("L"))
            if prev is not None:
                diffs.append(ImageStat.Stat(ImageChops.difference(box, prev)).mean[0])
            prev = box
        diffs.sort()
        print(f"  {pose:16s} median {diffs[len(diffs) // 2]:5.2f}  p95 {diffs[int(len(diffs) * 0.95)]:5.2f}")


# ---------------------------------------------------------------- frame time

# name, flame lab arguments. Off is the HUD as it ships without the Flame (the
# lantern never hears a reading); Kindling is the painted path; True Lantern is
# the relit path at its fullest (the hearth fills all three lights, the halo).
BENCHES = [
    ("off", ["--flame=off"]),
    ("kindling", ["--flame=on", "--pose=kindling"]),
    ("true-lantern", ["--flame=on", "--pose=true-lantern"]),
    ("off +100", ["--flame=off", "--stress=100"]),
    ("true-lantern +100", ["--flame=on", "--pose=true-lantern", "--stress=100"]),
]


def bench(runs: int, driver: str) -> None:
    """`tools/bench_flame.gd` at the phone shape at 3×, every configuration once
    per round and the rounds interleaved, so drift on a shared machine lands on
    all of them alike. Prints the median over runs of each run's median and p95."""
    results: dict[str, list[dict]] = {name: [] for name, _ in BENCHES}
    render = ["--rendering-driver", "vulkan", "--rendering-method", "mobile"] \
        if driver == "vulkan" else []
    for _ in range(runs):
        for name, args in BENCHES:
            cmd = ["godot", "--path", str(ROOT), *render, "-s", "res://tools/bench_flame.gd",
                   "--", "--shape=phone-landscape", "--scale=3", "--inspect=off", *args]
            out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=300)
            line = next((ln for ln in out.stdout.splitlines() if ln.startswith("BENCH ")), "")
            if not line:
                raise SystemExit(f"bench {name} printed no BENCH line:\n{out.stderr[-2000:]}")
            results[name].append(json.loads(line[len("BENCH "):]))
    print(f"frame time, phone 844×390 at 3×, {driver}, median of {runs} interleaved runs (ms)")
    print(f"{'configuration':20s} {'gpu med':>8s} {'gpu p95':>8s} {'cpu render':>10s}"
          f" {'cpu setup':>9s} {'frame med':>9s} {'frame p95':>9s}")
    for name, _ in BENCHES:
        rows = results[name]

        def mid(key: str) -> float:
            values = sorted(float(r[key]) for r in rows)
            return values[len(values) // 2]
        print(f"{name:20s} {mid('gpu_med'):8.3f} {mid('gpu_p95'):8.3f} {mid('cpu_med'):10.3f}"
              f" {mid('setup_med'):9.3f} {mid('wall_med'):9.2f} {mid('wall_p95'):9.2f}")
    print("adapter:", results[BENCHES[0][0]][0].get("adapter", "?"))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--recordings", type=Path, help="scratch folder for the recordings")
    ap.add_argument("--capture", action="store_true", help="record everything first")
    ap.add_argument("--only", default="", help="with --capture: comma-separated recordings")
    ap.add_argument("--numeral", choices=[p for p, _ in NUMERALS],
                    help="record one numeral placement (after editing LANTERN_COUNT_BOX)")
    ap.add_argument("--measure", action="store_true", help="print the README's numbers")
    ap.add_argument("--no-build", action="store_true", help="skip rebuilding the images")
    ap.add_argument("--bench", type=int, default=0, metavar="RUNS",
                    help="run the frame-time probe RUNS rounds and print the table")
    ap.add_argument("--driver", choices=["vulkan", "metal"], default="vulkan",
                    help="with --bench: Vulkan (MoltenVK) has a GPU timer; Metal reads zero")
    args = ap.parse_args()
    if args.bench:
        bench(args.bench, args.driver)
        return
    if args.recordings is None:
        ap.error("--recordings is required unless --bench is given")
    if args.numeral:
        capture_numeral(args.recordings, args.numeral)
        return
    if args.capture:
        capture(args.recordings, [n for n in args.only.split(",") if n])
    if not args.no_build:
        build(args.recordings)
    if args.measure:
        measure(args.recordings)


if __name__ == "__main__":
    main()
