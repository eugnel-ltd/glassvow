# R3.5: the set pieces (issue #660)

## Pre-registered before the device batch (14 Oct 2026, 04:45 BST)

The batch is one interleaved batch on the iPad 8, QA app only: main
`774c5932` against the branch's code-final head `4a95dbd5`, two installs
each, in the order main, branch, main, branch.

- **Rest.** Every view (Journey, the river, Close, Whole act), at the cadence
  and live, every launch: no missed frame (25 ms) that the branch has and
  main does not, and no visible hitch.
- **Video memory.** The new pieces add no texture and no sampler: one small
  mesh (the pier, 304 triangles, drawn as one more batched kind), more banner
  instances and a parapet mesh about 1.2 times main's. Their delta, paired
  against main within the same boot mode (each Journey hold classed by its
  build's own cluster), is budgeted at **+2 MiB**. Over that, or on any
  memory warning or kill, the uploads are investigated; otherwise not.
- **Memory.** The app's peak physical footprint in each boot launch (an
  Activity Monitor recording) and every memory warning the OS sends (a probe
  row) are recorded, for both builds.

## What changed, and why these pieces

The R3 plan weights ruins and props at 8. Of the set pieces in the owner's
target, the bridges close the most visible gap at Journey: a bridge over the
gorge is in the Journey frame at seed 1 and at most seeds, and the target's
reads at a glance as masonry lit by a rhythm of flames and hung with red
banners. Main's bridge was a pale flat deck with a row of rounded pale
stones and two small flags. So R3.5 dresses the bridges, and nothing else:

- **Crenellated parapets.** A continuous wall along each raised side, with
  merlons every other 0.43 m, in the masonry's coursed stone
  (`bridge_geometry.gd`, `bridge_stone.gdshader`'s new `tint`). Every face is
  flat: main's stones shared their corners' normals, which rounded them into
  pale pills under the key. The wall is built a merlon's length a piece with
  no hidden undersides, so the live caster carries about 1.2 times main's
  triangles (3,760 against 3,108 at seed 1; 2,650–3,170 at seeds 717, 2, 3).
- **Flame piers.** A squat coursed pier with an open flame in a bronze dish
  (`bridge-pier.glb`, 304 triangles, a lane pick), a pair at both ends of
  every stretch of deck raised over the river and evenly between, at most
  3.6 m apart, and only where the spot is the deck's edge (where two decks
  fork, one road's edge lies on the other's walking lane). The flame is the
  lamps' flipbook card, and each pier's light pool is painted like a
  lantern's. 41–46 piers a land at seeds 717 and 1–3.
- **Banners.** R2's cloth, 1.35 times its size, hung against the parapet's
  outer face halfway between the piers on the camera's side (9–15 a land).
- **Setts.** The decks' stones 1.9 times as many to the metre as the ground's
  flags, with deeper joints and darker stone (`terrain_paint.gdshader`;
  no new sampler).

All of it is placed last, as the banners were, so every other kit placement
is main's (the gateway, the 22–26 road lanterns and every ruin, rock and
plant: the kit's digest is identical at seeds 717 and 1–3), and so are the
layout digests. The woodland keeps its cards off every structure's foot, so
a pier at a bridgehead moves at most two of about 3,900 cards a land
(seed 1: none; seeds 2, 3 and 717: one or two).

**The art is a lane pick**, with the owner's re-pick open (art ledger, R3.5).
The pier's first build carried the gateway's amber lantern box; it read as a
road lamp and outweighed the pier at Close, and the target's piers burn open
flames, so the open flame was kept.

**Considered and not done: the gateway arch facing the camera.** The target's
centre is a ruined arch seen face-on over a road. Main's arch stands over a
road that crosses the screen, so the fixed camera sees it edge-on, a ladder
of voussoirs. A probe of the gateway's site rule at seeds 717 and 1–3 found no
site within 70° of the camera's line: every road that runs up the screen
leads to a waystone within the arch's projected body, which the kit's
projected-reserve rule keeps clear. A face-on arch needs either a straight
leg of about 9 m running up the screen, which these layouts do not have, or
the owner's leave for the arch to stand in front of a waystone's base (the
pin itself is an overlay and stays on top). That is the owner's call, not
this step's.

**Not done here** (non-goals): R3.6's light and grade, Acts II–IV, the
waterfall, torrent and mist, the river's Reduce Motion, the cold-open bisect.

## Stills, looked at

Mac, the A12 Metal condition, seed 1, two steps in, lean unless named; main
`774c5932` left, the branch right:

- [Act I, pad, Journey](frames/act1-pad.jpg), and [in zh-Hant](frames/act1-pad-zh.jpg)
- [Act I, phone, Journey](frames/act1-phone.jpg)
- [Act I, desktop, Journey](frames/act1-desktop.jpg), and
  [the desktop's full profile](frames/act1-desktop-full.jpg)
- [the bridges at Close](frames/bridges-close.jpg)
- [Whole act](frames/act1-whole.jpg)
- [against the owner's target](frames/against-target.jpg)

Against the target: the bridge now reads as the target's does, a coursed
masonry deck between crenellated parapets, flames on squat piers at each end
and a red banner over the water. What is still apart is the light and the
palette (the target's cooler grey stone and its haze are R3.6's), the
target's tree emblem on the banners, and the arch's bow under the deck.

## Gates

**The A12 Metal condition** (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1
--rendering-driver metal --rendering-method mobile`), at pad, phone and
desktop, en and zh-Hant lean and en full, plus the bridges at Close and
Whole act: **no "Error compiling shader"**, no script error and no other
error, on main and on the branch ([`mac/a12-and-reduce-motion.txt`](mac/a12-and-reduce-motion.txt)).
The pier draws with the kit's existing stone and bronze materials, the
parapet with `bridge_stone.gdshader` (no sampler) and the decks with the
same paint shader and its same two samplers, so no material gains a sampler.

**Reduce Motion** at Close, two frames 1.5 s apart: on the measured branch
(`4a95dbd5`, on `774c5932`) 23,365 pixels change against main's 24,371, every
one of them the river's water, which main still moved then. After the rebase
onto #719 (the river holds still under Reduce Motion), **0 pixels change**:
the piers' flames and the banners hold still with everything else.

**The token gate** (`tools/map_token_gate.gd`, #679), Act I, seeds 717 and
1–3, phone and pad: **0 failed** in all eight runs, worst margin 1.017
([`mac/token-gate.txt`](mac/token-gate.txt)).

**iPad 8** (QA app only, under the shared lock; main `774c5932` against the
branch `4a95dbd5`, interleaved main, branch, main, branch; every launch's
summary and the batch logs are in [`device/`](device/)):

- **B1**, the pre-registered batch: per install, boot launches with 600-frame
  rests at the cadence and live at Journey, the river, Close and Whole act,
  each followed by an Activity Monitor recording (retried with a fresh
  launch when the device cut it short, up to three), and a short Journey hold.
- **B1 was ambiguous on two points**, so **B2** repeated the rests without
  recordings (two boot launches per install) and retried main's footprint:
  the branch's second launch after its second install dropped one frame
  (63.5 ms) in a live Close rest, and one of main's launches held about
  30 Hz through Close and Whole act (1,808 frames over 25 ms) while a
  recording ran.

| | Main | Branch |
|---|---|---|
| Rest holds, B1 (frames) | 48 (28,800) | 40 (24,000) |
| Missed frames over 25 ms, B1 | 1,808, all in one launch held near 30 Hz under a recording (ctl1-l3) | **1** (63.5 ms, dev2-l2, Close live) |
| Rest holds, B2 (frames) | 64 (38,400) | 32 (19,200) |
| Missed frames over 25 ms, B2 | **0** (worst 24.6 ms) | **0** (worst 22.0 ms) |
| Journey, stage primitives and draws | 86,882, 78 | 92,768, 80 |
| Journey, live shadow primitives (budget 15k) | 4,118 | 4,770 |
| Memory warnings | 0 | 0 |
| Peak physical footprint (Activity Monitor, 140 s from 3 s after launch) | 596.6 MiB | 591.8 and 596.9 MiB |

- **Rest.** Every rest in B2 holds vsync on both builds, at every view, at
  the cadence and live. B1's single dropped frame on the branch did not come
  again in 32 more branch rests; main's 30 Hz launch is main's. Nothing a
  player would see as a hitch.
- **Video memory.** Journey holds at the cadence fall in boot modes 2–8 MiB
  apart (284, 290, 292, 298 and 306 MiB; main also read 276.2 once, in its
  30 Hz launch, and 294.6 once). Paired within the same mode:
  - 298 MiB: main 298.1 (5 holds), the branch 298.1 (4): **+0.0 MiB**.
  - 290 MiB: main 290.0–290.1 (3), the branch 290.1 (1): **+0.0 to +0.1**.
  - 292 MiB: main 292.1 (3), the branch 292.2 (1): **+0.1**.

  The new pieces' paired delta is **+0.1 MiB at most**, inside the
  pre-registered +2 MiB, and no memory warning or kill came, so the uploads
  were not investigated. One thing to note: the branch's Journey holds read
  the 306 MiB mode in 5 of 11, main's in none of 16 today (in R3.4's batch,
  main read it in 7 of 13). The peak footprints are equal (above), so the
  mode is the renderer's staging step, not a player-visible cost; it is
  recorded here, not chased.
- **How the footprint was read.** As in R3.4, a launch drops devicectl's
  tunnel, so most recordings were cut short; the three that ran their whole
  140 s are the rows above ([`device/footprint.txt`](device/footprint.txt)).

**Payload** (`payload_report.py`, iOS): **+13 KB** (the pier's imported
scene); 283.1 MiB in all, budget 400.

**Method.** The scripts are in [`tools/`](tools/) (the captures use R3.3's
`look.gd`, [`../r3-3-stone/tools/look.gd.txt`](../r3-3-stone/tools/look.gd.txt),
unchanged). The measuring builds carried one scratch addition to the probe's
QA copy (never committed): a row for every `NOTIFICATION_OS_MEMORY_WARNING`.

## Core gate

The measured build is `4a95dbd5` on main `774c5932`. Main then took #719 (the
river's Reduce Motion) and #720 (the reward screen), neither touching this
change's files; the branch was rebased onto `0ce8b226` without conflict, and
the core gate was run again on the rebased head (code `5f2500a5`), 14 Oct
from 06:21, load 8 at the start: `godot --version` 4.7.2.stable.official.ed1daf0bf;
`tools/check_imports.sh` asset import OK; `tools/check_scripts.sh` scripts OK
(513 checked); `godot --headless -s res://tests/run_all.gd` exit 0,
**PASS (166 tests)**; anchors OK.

Before the rebase, on the code-final candidate (`4a95dbd5`, at `8e85e209`),
Mac, 14 Oct, from 04:53, load 7 at the start:

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
| `python3 -B tools/check_anchors.py` (docs head) | 0 | anchors OK (R3.3's README re-anchored to `kit.gd`'s moved functions: ten by `--fix`, two by hand to the same decision lines) |
| `python3 -B tools/check_benchmark_freeze.py` (docs head) | 0 | benchmark citations frozen (592 in 52 file(s)) |
| `python3 -B tools/build_site.py --check` (docs head) | 0 | site is current: 7 files; the zh-Hant heading face covers all 54 display characters |
