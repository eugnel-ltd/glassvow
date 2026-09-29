# The flame on the lantern — shader spike (#577, step 1)

**Status:** spike for the owner's approval on device, 2026-09-29. Nothing in production reads it: no HUD, reward or shop wiring, no PR. Branch `spike/flame-shader-lab`. Author: Claude, for the presentation lane. Authority: the Flame lock ([`../README.md`](../README.md)) §6 and §9; the task is step 1 of issue #577.

**The question.** Can one material on the HUD's own lantern art say the Flame implicitly at HUD size — colour from the dominant way with a fringe at the tips, tier from stability and height, way from shape — without competing with the ember pips, and what does it cost the frame?

**The answer.** Yes, with one condition that belongs to the HUD lane: the ember numeral sits over the upper half of the lantern's glass and hides the top of every figure. Recommendation: the **leaded** look, the numeral moved off the glass, the budget treated as negligible on the Mac and re-measured on the floor devices in step 2. Details and the open questions are at the end.

## What is on the branch

| File | Role |
|---|---|
| `presentation/lab/lantern_flame.gdshader` | The material. It goes on the lantern art's TextureRect (the HUD's `ui/lantern`) and relights the art from inside: one quad, one pass, no new node. |
| `presentation/lab/lantern_flame.gd` | `LanternFlame`: takes an `EventTypes.FLAME` event exactly as the domain emits it (PR 2, #576), maps it to the shader's inputs, and moves every input over one second on an ease-in-out. A reading that lands mid-tween turns the flame from where it is; nothing snaps. |
| `presentation/lab/flame_lab.gd` | `FlameLab`: the production `HudBar`, untouched, at the chosen shape, with the flame on its lantern and its glow tinted; a large copy of the same lantern beside it for judging the figure; ten poses; keys; `--record` for stills and strips. |
| `application/main.gd` | The `--flame` lab route: one flag in the lab list and one `match` arm, the same pattern as `--hud`. No production scene changes. |
| `tools/bench_flame.gd` | The frame-time probe (below). |
| `contact_sheet.py`, `measure.py` | Capture every recording through `tools/shot.sh` and build every image in this folder; print the greyscale legibility numbers. |

`hud_bar.gd`, `domain/` and every production scene are untouched. The lab makes the two calls step 2 moves inside `HudBar` from outside the widget (the material on `_lantern_art`, the tint on `_lantern_glow`), and toggles the numeral for comparison.

## The inputs contract

| Uniform | Type | Meaning |
|---|---|---|
| `dominant_colour` | colour | The way's colour; Kindling's orange; Soot's dust. |
| `fringe_colour` | colour | The second way, drawn at the tips and the outer flanks and in the light round them. |
| `fringe_amount` | 0–1 | How much of it shows; 0 is no fringe. |
| `stability` | 0–1 | 0 Soot guttering, 1 True still. |
| `height` | 0–1 | The tier's height, as a share of the tallest flame the glass holds. |
| `shape_weights` | vec4 | The way: x Shatter, y Lantern, z Edge, w the plain flame. Weights, not an index, so a tween from one way to another morphs straight across and never passes through the third. |
| `look` | 0 / 1 | The spike's A/B: 0 leaded, 1 vector. Step 2 keeps one. |
| `clock` | seconds | Driven by `LanternFlame` rather than `TIME`, so a still is the same still every time it is taken. |

The tier needs no input of its own: the shader reads everything unsteady or holy from `stability`. The shiver and the lean scale with `1 − stability`; below 0.55 the flame's edge tears; below 0.34 it gasps (drops to half height for about half a second every three), dulls, and the glass fills with murk; below 0.3 ash rises through the glass; above 0.9 the halo arrives (the glass evens out, a faint nimbus ring stands round the flame's head, and an aura spills past the iron). The motes and the aura stay inside the lantern's own square, well clear of the ember pips.

`LanternFlame` maps the domain's reading like this. Presentation never computes purity.

| `tier` | stability | height | colour | figure | fringe |
|---|---|---|---|---|---|
| `SOOT` | 0.00 | 0.46 | dust-brown `#8a6e52` | plain | none |
| `KINDLING` | 0.40 | 0.55 | ember orange `#e8702a` | plain | none |
| `STEADY` | 0.85 | 0.80 | the dominant way's | the way's | the second way, when the event names one |
| `TRUE` | 1.00 | 1.00 | the dominant way's | the way's | never in practice: at purity 0.80 the second way is under `fringeMin` |

Kindling and Soot have declared no way (lock §4), so they burn plain whatever the shares say. A fringe shows from the lock's `fringeMin` (0.25) already at 55 % strength and reaches full strength at a share of 0.40, the most a Steady flame's second way can hold.

The ways, drawn at the size of the whole glass because at HUD size the centre light is about twelve pixels wide on a pad and eight on a phone, with the numeral over its upper half:

| Way | Colour (proposal) | Figure |
|---|---|---|
| 碎 Shatter · 霜焰 Frostlight | `#8fd0ff`, the game's facet blue | A crown of five straight shards: one tall in the centre light, two a side leaning out across the iron so their points stand in the side lights. |
| 燼 Lantern · 熾焰 Hearthfire | `#f2c14e`, the lantern gold | A broad, blunt-topped hearth flame on a bed of fire that fills the foot of all three lights; the whole lantern fills with light. |
| 蝕 Edge · 蝕焰 Eclipse | `#9c2fa6`, violet-crimson | One thin blade in the centre light, the tallest of its tier, lighting a single column; the side lights are left dark. |

The glass away from the figure is kept deep and dim: a bright figure on dark glass is legible at eight pixels, a bright figure on bright glass is not.

**Two looks, one figure.** *Leaded*: the flame stands behind the glass, soft-edged, carried by the glass's own streaks and crossed by every lead line of the tracery. *Vector*: a cut-glass tongue set in the lights, three flat bands with a lead came of its own, laid over the thin lead of the tracery but never over the iron.

## Running it

```sh
godot --path . -- --flame                     # the bench; keys ←/→, 1–0, L look, F flame, N numeral, R art ready, Space hold, H help
tools/shot.sh --flame --pose=true-edge --look=vector --time=1.2 --shot=/tmp/flame.png
tools/shot.sh --flame --shape=phone-landscape --vp=2532x1170 \
    --record=/tmp/flame --poses=all --look=all --time=1.2
python3 docs/design/2026-09-29-dusk-flame/shader-spike/contact_sheet.py --capture --recordings /tmp/flame-spike
python3 docs/design/2026-09-29-dusk-flame/shader-spike/measure.py --recordings /tmp/flame-spike
```

`--from=POSE` starts the flame at one pose and catches it mid-tween to `--pose`; `--flame=off` is today's lantern; `--numeral=off` hides the ember count; `--inspect=off` hides the large lantern. Poses are FLAME events; four are the lock's own worked examples in §4 (the starter deck, Shatter at 0.60, Shatter 0.63 with an Edge fringe at 0.25, and two of each way).

## What each image shows

Every still is taken 1.2 s after its reading arrived, on a pinned clock, so every lantern on a sheet is caught at the same moment of its flicker. The HUD crops are the production HUD at the shape, at the device's pixel density, with the ember pips and the numeral in place and the lantern in its unlit state (dimmed, as for most of a turn). Sheets are labelled tier over way; each has the leaded look above the vector look.

| File | Shows |
|---|---|
| [`sheet-pad.png`](sheet-pad.png) | The HUD lantern at pad-landscape, 1180×820 at 2×. |
| [`sheet-desktop.png`](sheet-desktop.png) | The HUD lantern at desktop-landscape, 1458×820 at 2×. |
| [`sheet-mobile.png`](sheet-mobile.png) | The HUD lantern at phone-landscape, 844×390 at 3×: the hardest case, a 68-point lantern. |
| [`grey-mobile.png`](grey-mobile.png) | The same in greyscale: what is left without colour. |
| [`numeral-off-mobile.png`](numeral-off-mobile.png) | The phone HUD with the ember numeral hidden: what the flame says when nothing covers it. |
| [`sheet-design.png`](sheet-design.png) | The large lantern (same material, no numeral or pips): the figures themselves. |
| [`grey-design.png`](grey-design.png) | The same in greyscale. |
| [`today-kindling.png`](today-kindling.png) | Today's lantern beside Kindling in both looks. |
| [`strip-soot.png`](strip-soot.png) | Soot every ⅓ s for 1⅔ s, large and HUD, both looks: the gasps, the murk and the ash. |
| [`strip-tween.png`](strip-tween.png) | Kindling to Steady Shatter every 0.2 s: colour and figure turn together over the second; nothing snaps. |
| [`stability.gif`](stability.gif) | Two seconds of Soot, Kindling, Steady and True (Lantern) side by side, large over HUD. |

## Accessibility

Tier legible from stability and height alone, way from shape alone (lock §9). `measure.py` reads the recordings in luminance only, inside the box the panes stand in; on the HUD the numeral is masked out, because it is the brightest thing in the lantern and says nothing about the flame. "Height" and "width" are the lit figure's extent as a share of that box; "fill" is how solidly it fills the rectangle they make.

| Pose (leaded) | Large: L / height / width / fill | HUD 3×: L / height / width / fill |
|---|---|---|
| Kindling | 34 / 0.37 / 0.20 / 0.41 | 23 / 0.33 / 0.19 / 0.42 |
| Steady Shatter | 52 / 0.59 / 0.72 / 0.14 | 35 / 0.48 / 0.72 / 0.17 |
| Steady Lantern | 67 / 0.53 / 0.74 / 0.37 | 47 / 0.46 / 0.76 / 0.42 |
| Steady Edge | 32 / 0.57 / 0.16 / 0.38 | 20 / 0.46 / 0.15 / 0.45 |
| True Shatter | 71 / 0.83 / 0.76 / 0.25 | 47 / 0.72 / 0.78 / 0.26 |
| True Lantern | 85 / 0.78 / 0.75 / 0.40 | 57 / 0.72 / 0.76 / 0.36 |
| True Edge | 40 / 0.71 / 0.16 / 0.39 | 25 / 0.46 / 0.15 / 0.54 |
| Soot | 31 / no pixel reaches flame brightness | 20 / none |

Frame-to-frame motion (median mean absolute change in luminance over two seconds, large / HUD): Soot 0.38 / 0.23 (p95 1.16 / 0.80), Kindling 0.21 / 0.15, Steady 0.12 / 0.10, True 0.05 / 0.06. The vector look orders the same way.

- **Tier, without colour.** The figure stands taller Kindling (0.33–0.37) → Steady (0.46–0.59) → True (0.71–0.83); within each way True is brighter than Steady; the motion falls Soot → Kindling → Steady → True at both sizes. Soot is the dullest glass, never reaches flame brightness and moves the most; True also carries the halo. Edge's eclipse is dark by design, so its brightness sits below Kindling's and its height does the work. One weak spot: on the HUD the numeral caps Edge's visible height, so Steady Edge and True Edge differ there by brightness (20 → 25) and the halo only.
- **Way, without colour.** Width separates Edge (0.15–0.16) from Shatter and Lantern (0.72–0.78); fill separates Shatter's crown of shards (0.14–0.26) from Lantern's hearth (0.36–0.42). Both hold on the phone HUD with the numeral masked.
- **Colour, for those who have it.** Simulated colour-vision deficiency (Machado 2009, full severity) leaves the three ways at least ΔE 36.6 apart (Shatter–Edge, deuteranopia). The closest pair on the whole palette is Hearthfire against Kindling: ΔE 41.9, 17.9 deuteranopia, 26.6 protanopia. That is why Kindling is a deeper `#e8702a` rather than the art's amber (at `#ff8f3a` it was 8.5 under deuteranopia), and why the two are also told apart by figure and tier. The Eclipse hex was chosen from five candidates on the same test.

## Frame time

`tools/bench_flame.gd` hosts the flame lab at phone-landscape at 3× (a 2532×1170 window, iPhone density) with the large lantern hidden, so the HUD lantern is the only flame. Vsync off; 240 frames and 3 s of warm-up, then 1,200 frames; median and p95 of each run; five fresh processes per configuration, interleaved. `--stress=100` adds a hundred more HUD-sized lanterns, all plain or all burning, so the flame's own cost stands clear of the noise. Metal's per-viewport GPU timer reads zero on this machine (the repository's own finding), so the GPU column is the same build on Vulkan (MoltenVK) with `--rendering-method mobile`; three Metal runs per configuration give the production driver's CPU figures.

```sh
godot --path . --rendering-driver vulkan --rendering-method mobile -s res://tools/bench_flame.gd -- \
    --shape=phone-landscape --scale=3 --flame=on --inspect=off --stress=100
```

Each run prints one `BENCH` line; the table takes the median of the five runs' medians and p95s, in the order off, on, off with stress, on with stress, repeated. MacBook Pro (MacBookPro18,2), Apple M1 Max, 32-core GPU, macOS 27.0, Godot 4.7.2 official. The machine was shared with other agents' headless test suites (load average about 20), which the CPU columns feel and the GPU timestamps largely do not.

| Phone 844×390 at 3× | GPU median (p95), ms | CPU render, ms | CPU setup, ms | Whole frame median (p95), ms |
|---|---|---|---|---|
| Flame off (today's lantern) | 0.368 (0.467) | 0.061 | 0.010 | 8.29 (9.74) |
| Flame on | 0.435 (0.491) | 0.059 | 0.016 | 8.35 (9.87) |
| + 100 plain lanterns | 0.473 (0.586) | 0.070 | 0.010 | 8.33 (9.97) |
| + 100 burning lanterns | 1.631 (1.723) | 0.070 | 0.017 | 8.34 (10.40) |
| Metal: flame off / on | not available | 0.051 / 0.052 | 0.008 / 0.014 | 8.11 / 8.17 |

- **The HUD flame costs about 0.07 ms of GPU and 0.006 ms of CPU setup per frame** at iPhone density on this Mac: under half a per cent of a 16.7 ms frame. Most of it is fixed (one more material, its uniforms each frame); each further burning lantern adds about 0.012 ms (the hundred cost 1.16 ms), about 0.34 ns per pixel.
- **The whole frame does not move.** Its median stays at the 120 Hz presentation interval (8.3 ms) with or without the flame, even with a hundred of them; the p95 moves within the shared machine's noise.
- **For the floor devices** this is a ceiling to test, not a clearance: a phone GPU is several times slower than this one, and the lowest Android tier may be an order of magnitude slower. Two levers exist and were deliberately not pulled before visual approval: the shader does its full work over the whole art square although the flame lives in the panes' box (about 14 % of it; only True's aura needs the rest), and `clock` dirties the material every frame where `TIME` would not.

## Recommendation

1. **The leaded look.** It keeps the art's tracery over the flame, so the flame is inside the lantern as the lock and the brief require; it reads as light through stained glass rather than an emblem laid on it; and on the phone HUD its figures measure as separable as the vector look's (the vector Shatter even loses its side points below flame brightness at 3×). Keep the vector look's hard edge in reserve if, on device, Shatter and Lantern do not separate on a phone.
2. **Move the ember numeral off the glass.** It covers the upper half of the centre light at every shape: the top of every figure, Edge's height and most of the fringe. `numeral-off-mobile.png` is what the flame says without it. Where it goes (the lantern's foot, a small plate beside it) is a HUD layout call for James; the flame does not depend on it.
3. **The proposed hexes**, for approval on device: Frostlight `#8fd0ff`, Hearthfire `#f2c14e`, Eclipse `#9c2fa6`, Kindling `#e8702a`, Soot `#8a6e52`.
4. **Step 2 wiring**, once approved: move the shader and `LanternFlame` next to `HudBar`, keep one look, give `HudBar` a `set_flame(event)` that owns the two calls the lab makes from outside, forward `EventTypes.FLAME` from the combat screen (apply the combat-start reading instantly on a freshly built HUD, tween every later one), then the reward and shop lanterns. Measure on the floor devices before and after, as #577's acceptance requires.

## Open questions

1. **The numeral** (above): move it, and where?
2. **Kindling is darker than today's lantern** (`today-kindling.png`). Every run starts there, so the default HUD lantern dims: the lantern is lit by commitment, which fits the lock's "a player who scatters never lights the lantern", but it is a change of feel at the start of every run. One constant raises it if the start should look like today.
3. **Kindling and Soot burn plain** and ignore any fringe in the event: they have declared no way. Should Kindling hint at the leading way instead?
4. **Fringe strength:** 55 % at the lock's threshold (0.25), full at 0.40. At the threshold it is visible on the large lantern and faint on the phone HUD.
5. **Halo against the art-ready beacon.** Both are light round the lantern; the halo is steady, the beacon pulses the lantern and its glow. Confirm on device they do not read as one signal.
6. **Soot's ash** reads on the large lantern; on the HUD a fleck is one or two device pixels. At HUD size Soot is carried by the murk, the dullness and the gasps.
7. **The Web build** was not exported. The shader renders identically on the Compatibility renderer natively (OpenGL through Metal), which is the Web's renderer, but a Web export was not run.
8. **Seeing it on a device.** The lab has no entry in the dev front door's browser catalogue, which is the organiser's registry; one entry would put it on the iPad through Interactive Web. Until then it runs with `godot --path . -- --flame`.

## Evidence

On the branch, with the new scripts staged, Godot 4.7.2 official:

| Check | Result |
|---|---|
| `tools/check_scripts.sh` | scripts OK (279 checked) |
| `tools/check_imports.sh` | asset import OK |
| `python3 tools/check_anchors.py` | anchors OK, after re-anchoring the one citation of `_capture_and_quit` that the two-line lab route moved |
| `python3 tools/check_benchmark_freeze.py` | frozen, 601 citations in 54 files; no new web citation |
| `tests/test_dev_boot_profile.gd` (filtered runner) | PASS: it reads every flag `Main._ready` parses, so it now covers `--flame` |
| Compatibility renderer (OpenGL through Metal) | the lab renders both looks identically to Forward Mobile |

The full suite was not run: the change is lab files, a probe, the lab route and documents, and no production path reaches them. Every image here was taken with `tools/shot.sh` through `application/main.gd`; whole frames at each shape were looked at before any crop was trusted.
