# #682 Part 2 (B9): the first map open and the fight load build no pipeline

Part 1 (#712) left the iPad 8's first map open at 181–192 ms and the fight's load
frame at 399–412 ms after a fresh install. Part 2 makes the title's warm and every
use share their pipelines, so that neither frame, nor the first card play,
creates one. What is left in those frames is CPU work with no pipeline in it: a
non-shader floor, moved to #713 (not waived).

## The census (Mac, A12 condition, cold nonces)

A diagnostic editor (`tools/diag-pipeline-log-v3.patch.txt`, lane only: each
pipeline's ShaderData, key parts and vertex format) named every pipeline the
first map open and the fight load submit on `origin/main` 3e734010, and why it
was not served by the title's warm (`data/census-main.txt`, `tools/census2.py.txt`):

| Where | Submitted | Another Shader made from the same string (the warm's twin) | A key never built | Built, then freed | First made there |
|---|---|---|---|---|---|
| First map open | 59 | 1 (the iris) | 47 (the map's glow pass is a target format of its own; the land never drawn with the map's light; the back card's face on its 2D target) | 6 (the floor bake's soft key switches) | 5 (the pilgrim's ground blob, the waylight tracer, the clip-children canvas shader) |
| Fight load | 26 | 13 (body, shadow, ward, reseam, grain; all four draw pipelines) | 13 (two omni lights against the warm's one; the glow pass's format; a nine-patch and a Polygon2D on the default canvas material) | 0 | 0 |
| First card play | 2 | – | 2 (the ward, stood but never drawn) | – | – |

**The hypothesis** (Shader instances made from strings at use, whose pipelines
the warm's instances cannot serve) was right for half of the fight load and
wrong for the map open, where the land's own materials had never been drawn with
the map's keys.

## The fix

- `presentation/stage/shared_shaders.gd`: one Shader per code string for the
  process. The warm, EnemyView, CombatScreen, TransitionLayer and RewardStage
  wear it; materials stay per use; code and parameters are unchanged.
- `presentation/ui/path_warm.gd`, after the floor bake has ended (the #712 review:
  tied to its completion): an empty view of the map's stage
  (`MapScene.stage_view`) lit as Act I's journey, so its glow pass's format is
  required before anything else is built; frame 0's targets again, a frame each;
  Act I's kept land lent to that view (`MapScene.lend_journey`), a frame unseen,
  then, once its pipelines have compiled, a frame drawn whole from above, and a
  wait for that draw's compiles; a waylight tracer stand-in; a nine-patch, a
  Polygon2D and the hidden back card drawn once. The foe stage has two omni
  lights, as EnemyView's, and draws the ward at frame 0 with the body and shadow.
- The lent land stands still (its scripts and particles paused) and comes back as
  it was kept; a map binding meanwhile takes it back first.

## Mac proof (final head 4c3605ca)

- 0 pipelines submitted in the first map open, the fight load and its next 13
  frames, and the first card play (`data/census-final.txt`); 0 "Error compiling
  shader".
- Pictures: title, map, fight and turns at the pad and phone shapes, candidate
  against main, within main's own run-to-run band (animated content only).
- `check_floor_bake` 16/16 in every run; `check_card_rest` the same lines as main
  and frames within main's band (its COMPILE line fails on main too: a `--map`
  boot runs no title warm).
- Tests and mutations (`data/mutations.txt`): `test_shared_shaders` (one Shader
  per code, every use site wears it, no other script makes one) and
  `test_path_warm` (the bake gate, two omni lights, the frame-0 ward, the land
  lent and given back, the final compile wait); 10 of 10 mutations caught.

## The device reads (iPad 8, QA app, fresh installs, never-compiled nonces)

**Amendment before any data:** the registered F* came from the `--map` fight
launch, which never shows the title, so no title-time warm could reach it. The
read was amended to route mode (title, Back to the Road, the map, then the bench
fight in one fresh launch); the `--map` launch's F* stays as a diagnostic.

**Read 1** (`data/read1-report.txt`, P = 287a4303): no pipeline in M's worst
frame or F*'s three frames in any P install (A: 58 and 26). Rulings: 1, pipelines
met; 2, M and F* a non-shader floor, moved to #713; 3, W failed (the ward's first
4x MSAA pipeline built cold in a title frame, 250–264 ms) and binds; 4, settings'
first opening to explain; 5, VRAM to explain; 6, the first card play's rows;
7, the zsh capture count (0 counted down to two sets) fixed.

**Confirmation 1** (`data/confirm1-report.txt`, P′ = 4c3605ca): every bar passed
but settings. Its row was then found to be a probe artefact: the first room's tap
was issued in the frame that also ran the title row's own user-cache listing,
90–96 ms of a 95–100 ms frame on the Mac (the game's own settings work: 2.3–2.5
ms in both arms). Superseded; the listing now runs two frames earlier.

**The re-run confirmation** (`data/confirm2-report.txt`, A = 3e734010, P′ =
4c3605ca, three installs each, the corrected probe):

| Bar | P′ | A | |
|---|---|---|---|
| W ≤ 100 ms | 35.9–38.3 | 38.6–68.1 | PASS |
| Z ≤ A's median + 1 s | median 6,131 ms | median 6,120 ms | PASS |
| Rejected baked files | 0 | 0 | PASS |
| Pipelines in M's worst frame, F*'s three frames, the first card play | none | all three | PASS |
| Settings' first opening ≤ A's worst + 3 ms (30.7) | 27.1–29.4 | 19.8–27.7 | PASS |
| Back to the Road < 1 s | 677–682 ms | 715–731 ms | PASS |
| T within budget | ≤ 16.8 | ≤ 20.5 | PASS |
| M ≤ A's worst | 164.0–165.6 | 178.7–196.1 | PASS |
| F* ≤ A's worst | 272.4–282.1 | 299.0–326.9 | PASS |

Diagnostics: F*-map (the `--map` launch) P′ 343–356 ms, A 335–672 ms. The
remaining M and F* time is CPU: the map screen, its land and its HUD (about 65,
52 and 10 ms of M), and the combat screen's build and its encounter (about 113
and 77 ms of F*); F*[1]'s ~100 ms is almost all before processing, in both arms.

**VRAM** (Metal's video figure is the device's whole allocated size): P′ is
+18–26 MiB at the title's rest (371.7–379.8 against 353.5) and equal at the first
open (368.1–376.2 against 376.0–376.1) and at the fight (651.1–659.2 against
659.1). It is A's own first-open allocation made early (the pipelines and render
resources the warm builds), not a leak: no view outlives the warm. Accepted.

**The first card play:** P′ 74.5–83.1 ms with 0 pipelines; A 328–413 ms, 253–337
ms of it draw, with a draw and a specialisation pipeline.

**Follow-ups for #713:** the warm ends 13.4–14.0 s after frame 0 (A's at
11.1–12.1). An early tap (the title left 6 s after frame 0, confirmation 1's A4
and P4) keeps none of Part 2's gain (M 251 against 257 ms, F* 317 against 347,
pipelines in both): the warm's order and length.

## The identity checks

IB3 (the clean release editor's bake of the identity scene) failed on the device
before any tile: its `qa_identity.gd` preloads `tools/shader_bake_manifest.gd`,
which the presets exclude since #712. IB4, the same build with the manifest
shipped: K 74 baked files loaded, 0 game shaders compiled, 0 rejected, and all 48
tiles byte-identical to IU's cached launch and to IB2 (`data/ib4-compare.txt`):
PASS.

## The `project.godot` incident

During the Mac work a background analysis loop of the lane's, believed finished,
ran four routes alongside other runs (15:52–16:31, against the one-batch rule).
Its last run, stretched by a load of about 870 and ended by its 500 s timeout,
finished at 16:31:37, the second the candidate worktree's `project.godot` was
rewritten to 17 lines. A full test run in progress then failed two tests that
read the file. It was restored with `git checkout`, the overlapping runs' timings
were discarded, and the full suite passed again (163). No commit carried it.

## Not reached

#709's Night Stall: the eight surface pipelines its resting-stage rebuild
compiles beyond main's first hover lie outside the paths this census covers
(the title, the map open, the fight load and the first card play); unidentified.

## Reproduce

`tools/` holds the lane's scripts as `.txt`: the probe (`qa_shader_probe.gd.txt`,
armed by `arm.py.txt`), the Mac census and timing (`mac_pck.zsh.txt`,
`mac_route.zsh.txt`, `census2.py.txt`, `split_report.py.txt`), the pictures
(`shots_compare.py.txt`), the IPAs and the device holds (`build_ipa.zsh.txt`,
`batch.zsh.txt`, `hold.zsh.txt`, `hold3.zsh.txt`, `ib4_after.zsh.txt`), the
reports (`report.py.txt`, `ib3_compare.py.txt`) and the mutations
(`mutate.py.txt`). They need the lane's nonce tool and the patched editors of
Part 1.
