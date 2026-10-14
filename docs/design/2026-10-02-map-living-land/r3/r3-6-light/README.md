# R3.6: the light (issue #660)

## Pre-registered before the device batch (14 Oct 2026, 07:53 BST)

The batch is one interleaved batch on the iPad 8, QA app only: main
`22d0e856` against the branch's code-final head `5afc91b9`, two installs
each, in the order main, branch, main, branch.

- **Rest.** Every view (Journey, the river, Close, Whole act), at the cadence
  and live, every launch: no missed frame (25 ms) that the branch has and
  main does not, and no visible hitch.
- **No pass is added.** The grade is values on the passes that exist: the
  journey light and its environment, the floor's bake (drawn once per land),
  the stone's shader, and the tilt-shift's pass, which gains a few
  multiply-adds a stage texel and no fetch (the far haze and the near shade).
  GPU-time note: at the iPad's stage size this is of the order of a hundredth
  of a millisecond, so it is not traced separately; the rest holds at vsync
  are the gate.
- **Video memory.** No texture, no sampler and no buffer is added. The
  delta, paired against main within the same boot mode, is budgeted at
  **+2 MiB**. Over that, or on any memory warning or kill, the uploads are
  investigated; otherwise not.
- **Memory.** The app's peak physical footprint (an Activity Monitor
  recording per install) and every memory warning the OS sends (a probe row)
  are recorded, for both builds.

## What changed, and why

R3.5's review left the light and the palette as what still stood apart from
the owner's target at Journey; the tracker added the stone's value, the moss
and the cliff tops at Close. Measured first, by the frame's own statistics
(`tools/grade_stats.py.txt`; the target cropped to its land, a capture to its
safe frame), main at Journey on the pad is far darker and more saturated
than the target, not merely off in hue:

| | Target | Main | R3.6 |
|---|---|---|---|
| Luma, 10th / 50th / 90th percentile | 0.08 / 0.19 / 0.44 | 0.04 / 0.14 / 0.32 | 0.08 / 0.23 / 0.42 |
| Share of the frame darker than 0.08 | 10.9% | 25.4% | 9.4% |
| Mean saturation (HSV) | 0.48 | 0.81 | 0.66 |
| Mean RGB | 0.32, 0.21, 0.18 | 0.27, 0.14, 0.06 | 0.35, 0.23, 0.12 |
| Top third against bottom third, luma | 0.235 / 0.222 | 0.161 / 0.162 | 0.259 / 0.226 |

The phone and the desktop read alike (phone dark share 31.1% on main, 15.3%
on R3.6; desktop 30.4%, 12.5%). So the grade is, in order of what it moved:

- **The light** (`MapJourneyLandscape.light`): a stronger, paler key
  (`ffdcb0` at 2.0, was `ffd1a0` at 1.6), a neutral fill (`8f93a2` at 0.42,
  was a lavender `7d86a8` at 0.30), exposure 1.1, contrast 1.12 (was 1.2)
  and saturation 1.1 (was 1.18). A first try at saturation 0.85 met the
  target's mean saturation but turned the scarlet crowns salmon, so the
  saturation stays above 1 and the shadows are lifted instead. The floor's
  bake lights with the same function, so the ground and what stands on it
  move together (`test_map_floor.gd` now checks the bake's key and fill
  against the live light's, not a literal).
- **The lens's depth** (`map_tilt_shift.gdshader`): the target is brighter
  and hazier toward its top, the far land, and darker at its foot. The
  tilt-shift's pass already covers the journey frame at the stage's
  resolution, so it now mixes up to 20% of a warm haze into the frame's top
  edge (gone by 45% of the height) and shades the foot by up to 22% (from
  70% down). A few multiply-adds a texel, no fetch, no new pass. Whole act
  has no tilt-shift, so no haze; it is the overview.
- **The lamps' pools**: the target's lamps throw orange pools across the
  path, where main's barely showed under the old light. The pools are wider
  (5 m, was 4.2) and stronger (7, was 4.2) and a deeper orange.
- **The road**: main's road leaned cool, which under the new fill read
  grey-mauve; the target's paths are warm tan earth. `road_tint` and the
  road's saturation are warmed.
- **The stone and the moss** (`stone.gdshader`): the outcrops read pale and
  their moss a bright olive-yellow. The granite is a cool mid-grey (`stone_tint`
  0.5, 0.54, 0.6, was 0.8, 0.83, 0.88), the moss the target's deep green
  (0.6, 0.85, 0.45, was 1.15, 1.5, 0.6) and on less of the stone
  (`moss_rise` 0.62–0.92, was 0.5–0.8).
- **The cliff tops at Close**: the cliffs' strata took a third of the
  outcrops' moss, so their up-facing ledges showed the strata's tan. They now
  take most of it (`strata_moss` 0.8), so the ledges read as grown-over grey
  rock ([`frames/cliffs-close.jpg`](frames/cliffs-close.jpg)). The steps of
  the strata are geometry and still read as horizontal ledges; that is the
  cliff kit's form, not its colour.
- **The bridges**: the parapets (`PARAPET_TINT`) and the decks' setts
  (`deck_shade`) a little cooler and darker, toward the target's grey stone.

Considered and not kept: a rim light on the woodland's cards (Godot's `RIM`)
lifted every crown evenly, since the baked normals turn at every leaf, and
cost the wood its depth; a deeper crown occlusion (`occlusion_floor` 0.06)
changed nothing visible. Both were reverted. What still stands apart from
the target is mostly fidelity, not grade: the target's crowns are lit leaf by
leaf with sunlit tips, its paths glint wet, its waterfall throws mist, and
its arch stands face-on (the owner's call, R3.5).

**The art is a lane pick**, with the owner's re-pick open (art ledger,
R3.6). Every choice is a value, so a re-pick is a change of values.

## Canopy cover, re-measured with the stone in place

The R3 research's flat-magenta count (the wood's cards drawn flat magenta,
counted in the safe frame; the ruins' stone cards not counted;
`tools/magenta.gdshader.txt`, now reading the atlas's array):

| View | R3.1b (before the stone) | Now |
|---|---|---|
| Pad, Journey | 45.4% | 43.3% (main 43.6%) |
| Phone, Journey | 44.3% | 42.8% |
| Whole act | 43.9% | 42.9% |

The grade changes no geometry, so the count is the land's, whichever build;
the 0.3 points between main and R3.6 at the pad are most likely the haze
shifting a few edge pixels across the count's colour threshold. Against
the 45% gate the cover is now 1.7–2.2 points short at every view: R3.3's
outcrops and cliffs and R3.5's piers stand where cards stood. The target's
frame is 85–90% "something" off the road (canopy, rock or cover); the stone
was not counted here. Raising the canopy is a planting question (groves and
glades, R3.1b's follow-up), not this step's.

The red share by R3.1b's colour mask, pad Journey: 16.1% on R3.6 (main
16.4%), inside the target's band of 6.3–16.3% for the first time (R3.1b's
recorded exception was 16.7%).

## Stills, looked at

Mac, the A12 Metal condition, seed 1, two steps in, lean unless named; main
`22d0e856` left, R3.6 right:

- [Act I, pad, Journey](frames/act1-pad.jpg), and [in zh-Hant](frames/act1-pad-zh.jpg)
- [Act I, phone, Journey](frames/act1-phone.jpg)
- [Act I, desktop, Journey](frames/act1-desktop.jpg), and
  [the desktop's full profile](frames/act1-desktop-full.jpg)
- [Close over the river](frames/act1-close.jpg), and [the cliffs at Close](frames/cliffs-close.jpg)
- [Whole act](frames/act1-whole.jpg)
- [against the owner's target](frames/against-target.jpg)

## Gates

**The A12 Metal condition** (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1
--rendering-driver metal --rendering-method mobile`), at pad, phone and
desktop, en and zh-Hant lean and en full, plus Close over the river and
Whole act: **no "Error compiling shader"**, no script error and no other
error, on main and on the branch ([`mac/a12-and-reduce-motion.txt`](mac/a12-and-reduce-motion.txt)).
No material gains a sampler: the tilt-shift's new uniforms are numbers, and
the stone, floor, paint and bridge shaders change only their default values.

**Reduce Motion** at Close, two frames 1.5 s apart, the drifting air hidden:
**0 pixels change** on the branch (and on main); with motion on, 187,626
change on the branch against main's 141,623 (most likely the brighter grade lifting the
same motion over the 6-level threshold in more pixels).

**The token gate** (`tools/map_token_gate.gd`, #679), Act I, seeds 717 and
1–3, phone and pad: **0 failed** in all eight runs, worst margin 1.015
([`mac/token-gate.txt`](mac/token-gate.txt)).

**iPad 8** (QA app only, under the shared lock; main `22d0e856` against the
branch `5afc91b9`, interleaved main, branch, main, branch; every launch's
summary and the batch logs are in [`device/`](device/)):

- **Batch 1**, as pre-registered: per install, two boot launches with
  600-frame rests at the cadence and live at Journey, the river, Close and
  Whole act, an Activity Monitor recording (retried once with a fresh launch
  when the device cut it short), and a short Journey hold.
- **Batch 1 was ambiguous on two points**, so **batch 2** repeated the rests
  without recordings (two boot launches per install) and retried the
  branch's footprint: the branch dropped one frame (43.7 ms) in a river rest
  at the cadence while a recording ran (dev1-l2), and none of the branch's
  recordings ran its whole time.

| | Main | Branch |
|---|---|---|
| Rest holds, batch 1 (600 frames each, and 2 short Journey holds) | 64 | 64 |
| Missed frames over 25 ms, batch 1 | **0** (worst 22.0 ms) | **1** (43.7 ms, dev1-l2, the river at the cadence, under a recording) |
| Rest holds, batch 2 | 32 | 56 |
| Missed frames over 25 ms, batch 2 | **0** (worst 22.6 ms) | **0** (worst 23.0 ms) |
| Memory warnings | 0 | 0 |
| Peak physical footprint (Activity Monitor, 140 s from 3 s after launch) | 610.3 MiB | 603.0 and 592.5 MiB |

- **Rest.** Every rest in batch 2 holds vsync on both builds, at every view,
  at the cadence and live. Batch 1's single dropped frame on the branch came
  under a recording and did not come again in 56 more branch rests. Nothing
  a player would see as a hitch.
- **Video memory.** Journey holds at the cadence fall in boot modes 6–8 MiB
  apart (284, 292, 298 and 306 MiB), as in R3.4 and R3.5. Paired within the
  same mode, across both batches:
  - 306 MiB: main 306.1 (10 holds; one 306.6), the branch 306.0–306.1 (7): **+0.0 MiB**.
  - 298 MiB: main 298.1 (2), the branch 298.0–298.1 (8): **+0.0**.
  - 292 MiB: main 292.2 (1), the branch 292.2 (1): **+0.0**.

  The delta is **+0.0 MiB**, inside the pre-registered +2 MiB, with no
  memory warning or kill, so the uploads were not investigated.
- **How the footprint was read.** As in R3.4 and R3.5, a launch drops
  devicectl's tunnel, so most recordings were cut short; the three that ran
  their whole 140 s are the rows above ([`device/footprint.txt`](device/footprint.txt)).

**Payload:** no asset changes; nothing is added to the export.

**Method.** The scripts are in [`tools/`](tools/) (`look.gd` is R3.3's,
with the flat-magenta count reading the atlas's array). The measuring
builds carried one scratch addition to the probe's QA copy (never
committed): a row for every `NOTIFICATION_OS_MEMORY_WARNING`.

## Core gate

On the code-final candidate `5afc91b9` (on main `22d0e856`), Mac, 14 Oct,
from 07:52, load 5 at the start:

| Command | Exit | Last verdict line |
|---|---|---|
| `godot --version` | 0 | 4.7.2.stable.official.ed1daf0bf |
| `tools/check_imports.sh` | 0 | asset import OK |
| `tools/check_scripts.sh` | 0 | scripts OK (513 checked) |
| `godot --headless -s res://tests/run_all.gd` | 0 | PASS (166 tests) |

Every further check `tools/ci_scope.py` selects for the PR's diff, at the
same head unless named:

| Command | Exit | Last verdict line |
|---|---|---|
| `python3 -B tests/test_ci_scope.py` | 0 | OK |
| `python3 -B tools/check_export_paths.py --self-test` | 0 | export-paths self-test OK (10 cases) |
| `python3 -B tools/check_export_paths.py` | 0 | export-paths OK |
| `python3 -B tools/check_map_assets.py --self-test` | 0 | self-test OK (all injected gates failed; GPU silhouette uses _silhouette_noise) |
| `python3 -B tools/check_map_assets.py` | 0 | map assets OK (48 payload files; runtime landscape and retained asset library) |
| `python3 -B tools/check_map_quality_v2.py --self-test` | 0 | self-test OK (12 fail-closed mutation fixtures) |
| `python3 -B tools/check_map_quality_v2.py` | 0 | map quality v2 OK schema=1 contract=2.0.0 hard=18 soft=12 provisional=25 digest=4b54927afa7459be4b8b1bedc88fd8d653b8d9ba4ef8b79a53dce1282ecb0b5f |
| `python3 -B tests/test_performance_budget.py` | 0 | OK |
| `godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=20` | 0 | map profiles OK (4 acts, 125978 candidate transforms; complete-layout proof is separate) |
| `godot --headless -s res://tests/choice_scroll_reachability.gd` | 0 | PASS choice scroll reachability (844x390) |
| `godot --headless -s res://tests/boss_relic_choice_containment.gd` | 0 | PASS boss relic choice containment (1180x820 en+zh-Hant) |
| `godot --headless -s res://tests/dawn_phone_containment.gd` | 0 | PASS dawn containment (en + zh-Hant, pad-landscape) |
| `godot --headless -s res://tests/measure_hud_location.gd` | 0 | MEASURE OK (0 clipped) |
| `godot --headless -s res://tests/event_phone_containment.gd` | 0 | PASS event containment (2024 rects, en + zh-Hant, 11 events, 3 shapes) |
| `python3 -B tools/check_anchors.py` (docs head) | 0 | anchors OK (R3.3's README re-anchored by hand to `stone.gdshader`'s `fragment`, moved one line by a comment) |
| `python3 -B tools/check_benchmark_freeze.py` (docs head) | 0 | benchmark citations frozen (592 in 52 file(s)) |
| `python3 -B tools/build_site.py --check` (docs head) | 0 | site is current: 7 files; the zh-Hant heading face covers all 54 display characters |

## Open points

1. **Canopy cover** is 42.8–43.3% against the 45% gate with the stone in
   place (above); raising it is a planting step, not a grade.
2. **The cliffs' steps** still read as horizontal ledges at Close; they are
   now grey and grown over, not tan. Breaking the steps up is the cliff
   kit's form.
3. **Whole act has no haze**, since it has no tilt-shift pass; giving it one
   would add a pass at Whole act, which this step avoided.
