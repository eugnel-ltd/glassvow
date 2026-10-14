# R3.4: the water (issue #660)

## Pre-registered before the device batch (14 Oct 2026, 00:40 BST)

The batch is one interleaved batch on the iPad 8, QA app only: main
`97890cad` against the branch's code-final head `74c2c62c`, two installs
each, in the order main, branch, main, branch.

- **Rest.** Every view (Journey, the river, Close, Whole act), at the cadence
  and live, every launch: no missed frame (25 ms), and no visible hitch.
- **Video memory.** The water adds no texture and no sampler. Its own delta,
  paired against main within the same boot mode (each Journey hold classed
  high or low by its build's own cluster), is budgeted at **+2 MiB**. Over
  that, or on any memory warning or kill, the staging uploads are
  investigated (the orchestrator's ruling of 14 Oct); otherwise they are not.
- **Memory.** The app's peak physical footprint in each boot launch (an
  Activity Monitor recording across it) and every memory warning the OS
  sends (a probe row) are recorded, for both builds.

## What changed

Act I's river now reads as water in its gorge. Both river shaders draw one
water from `presentation/map/landscape/river_water.gdshaderinc`:

- **Depth.** The open channel is dark and deep (`deep_tint`), lighter only
  over the shallows (`shallow_tint`), where a wet stone tint shows through on
  the lean river and the real bed on the desktop's.
- **Banks.** The gorge's walls shade the water at their feet, and white water
  breaks as lace where the river meets the cliffs' feet and the shallows,
  carried downstream. No beige rim is left between the water and the cliffs.
- **Foam in the open.** Sparse, faint flecks drift with the current; each
  pier keeps its ring and tail, whiter than before.
- **Reflections, cheap.** The warm sky shows only at a grazing angle and
  along slick current lines; there is no screen read on the lean river.
- **The swell.** The ripple normal is halved, so the waves read as moving
  water, not as stripes across the river.

The water adds no texture and no sampler. The lean river binds the
bathymetry alone and reads neither the screen nor the depth;
`tests/test_map_river.gd` holds both shaders' sampler slots (mutation-proved:
an extra screen sampler and an extra anisotropic sampler on the lean river
each fail it).

**The art is a lane pick**, as R3.1 b–R3.3 were; the owner may re-pick. The
palette is the include's five uniforms, so a re-pick is a change of values.

**Not done here** (non-goals): the target's waterfall and torrent under the
bridge (the owner's eye only), R3.5's set pieces, R3.6's light and grade,
Acts II–IV.

## Stills, looked at

Mac, the A12 Metal condition, seed 1, two steps in, lean unless named; main
`97890cad` left, the branch right:

- [Act I, pad, Journey](frames/act1-pad.jpg)
- [Act I, phone, Journey](frames/act1-phone.jpg)
- [Act I, desktop, Journey](frames/act1-desktop.jpg), and
  [the desktop's full shader](frames/act1-desktop-full.jpg)
- [the ravine at Close](frames/river-close.jpg)
- [Whole act](frames/act1-whole.jpg)
- [the iPad 8 itself, Journey](frames/ipad8-journey.jpg) (batch W1's
  screenshots)
- [against the owner's target](frames/against-target.jpg)

Against the target: the target's gorge holds a torrent and a waterfall, bright
white water and mist, which this step does not attempt. What R3.4 brings to
it is a river that reads as water at all three shapes: dark in its channel,
white at the cliffs' feet, moving downstream. Main's was a flat, pale teal
ribbon with a beige rim, brighter than the gorge round it.

## Gates

**The A12 Metal condition** (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1
--rendering-driver metal --rendering-method mobile`), at pad, phone and
desktop, en and zh-Hant lean and en full, plus the ravine at Close and Whole
act: **no "Error compiling shader"**, no script error and no other error, on
main and on the branch.

**Reduce Motion** at Close, two frames 1.5 s apart: 24,365 pixels change on
the branch and 12,785 on main, and every one of them is the river's water on
both (the water moves under Reduce Motion on main too). The branch changes
more because its foam drifts where main's water was nearly uniform.

**iPad 8** (QA app only, under the shared lock; main `97890cad` against the
branch `74c2c62c`, interleaved; the Mac's load ran 49–355 from ks2's CI
during the batches, which runs nothing on the iPad):

- **W1**, the pre-registered batch: two installs each (main, branch, main,
  branch); per install a boot launch with 600-frame rests at the cadence and
  live at Journey, the river, Close and Whole act, and two short Journey
  holds.
- **W1 was ambiguous on one point**, so **W2** repeated its boot launches and
  one short hold per install: the branch's first boot after its install
  dropped one frame (44.6 ms) in a Whole act rest, and main's did not.
- **W3 and W4** re-ran the boot launch for the footprint only (below), with
  their rests counted too.

| | Main | Branch |
|---|---|---|
| Rest holds, W1–W4 (frames) | 86 (48,360) | 54 (29,160) |
| Missed frames over 25 ms | **1** (42.5 ms, W2's first boot, Whole act) | **2** (44.6 ms, W1's first boot, Whole act; 43.7 ms, W2's first boot, Journey) |
| A hold's median frame; its p95, at worst | 16.57–17.07 ms; 19.87 | 16.50–17.06 ms; 19.84 |
| Memory warnings | 0 | 0 |
| Peak physical footprint, boot and every rest (Activity Monitor, 140 s from 3 s after launch) | 597.4 MiB (its boot read the middle mode, 298.0) | 604.9 and 605.9 MiB (both boots read the high mode, 306.0) |

- **Rest.** Every rest holds vsync on both builds. The single dropped frames
  come only in the first boot after an install, on main as on the branch,
  never in the same view twice; they are not the water's. Nothing a player
  would see as a hitch.
- **Video memory.** Journey holds at the cadence fall in three boot modes on
  both builds, 8 MiB apart: high 306.0, middle 298.0 and low 290–292.
  - High: main 306.0 (7 of 13), the branch 306.0–306.1 (8 of 12): **+0.0
    to +0.1 MiB**.
  - Middle: main 298.0–298.1 (4), the branch 298.0 (3): **+0.0**.
  - Low: main 290.1 and 292.2 (2), the branch 292.2 (1): **+0.0**.

  The water's own paired delta is **+0.1 MiB at most**, inside the
  pre-registered +2 MiB, and no memory warning or kill came. So the staging
  uploads were not investigated (the orchestrator's ruling).
- **The footprint.** Main's and the branch's peaks differ by 7.5–8.5 MiB,
  which is the step between the two boot modes they read (298 against 306),
  not the water. No memory warning came in any launch.
- **How the footprint was read.** An Activity Monitor recording started
  before a launch ends when the launch drops devicectl's tunnel ("Device
  disconnected"), so W1's four recordings and W2's three hold one sample
  each. W3 and W4 launch first and record after, as `mt_trace` does, and
  retry a launch whose recording was cut short; a recording that missed its
  save (W3's main) was re-run in W4. The three full recordings are the rows
  above.

**Method and rows.** The scripts are in [`tools/`](tools/) (the captures use
R3.3's `look.gd`, [`../r3-3-stone/tools/look.gd.txt`](../r3-3-stone/tools/look.gd.txt),
unchanged); every launch's summary and the batch logs are in
[`device/`](device/), the three full footprint readings in
[`device/footprint.txt`](device/footprint.txt), and the Mac's A12 and Reduce
Motion runs in [`mac/a12-and-reduce-motion.txt`](mac/a12-and-reduce-motion.txt).
The measuring builds carried one scratch addition to the probe's QA copy (never
committed): a row for every `NOTIFICATION_OS_MEMORY_WARNING`.

## Core gate

Run once on the code-final candidate (`74c2c62c`, at `f537e04d`), Mac,
14 Oct, from 02:22, load 18 at the start:

| Command | Exit | Last verdict line |
|---|---|---|
| `godot --version` | 0 | 4.7.2.stable.official.ed1daf0bf |
| `tools/check_imports.sh` | 0 | asset import OK |
| `tools/check_scripts.sh` | 0 | scripts OK (511 checked) |
| `godot --headless -s res://tests/run_all.gd` | 0 | PASS (165 tests) |

Every further check `tools/ci_scope.py` selects for the PR's diff, at the docs head, 14 Oct from 02:58:

| Command | Exit | Last verdict line |
|---|---|---|
| `python3 -B tests/test_ci_scope.py` | 0 | OK |
| `python3 tools/check_store_dev_exclusion.py` | 0 | store-dev-exclusion OK |
| `tools/test_check_store_dev_exclusion.sh` | 0 | check_store_dev_exclusion regression tests OK (12 cases) |
| `python3 -B tools/check_export_paths.py --self-test` | 0 | export-paths self-test OK (10 cases) |
| `python3 -B tools/check_export_paths.py` | 0 | export-paths OK |
| `godot --headless -s res://tests/run_all.gd -- --tests=res://tests/test_release_identity.gd,res://tests/test_sentry_release.gd` | 0 | PASS (2 tests) |
| `python3 -B tools/check_anchors.py` | 0 | anchors OK |
| `python3 -B tools/check_benchmark_freeze.py` | 0 | benchmark citations frozen (592 in 52 file(s)) |
| `python3 -B tools/build_site.py --check` | 0 | site is current: 7 files; the zh-Hant heading face covers all 54 display characters |
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
