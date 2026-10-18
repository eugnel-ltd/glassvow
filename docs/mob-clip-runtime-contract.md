# 3D mob clip runtime contract

Status, 18 October 2026: source investigation for [#747](https://github.com/eugnel-ltd/glassvow/issues/747), under [#737](https://github.com/eugnel-ltd/glassvow/issues/737). There is no production skeletal mob playback contract yet. This record separates the existing asset interface from proposals that a future runtime must resolve; it approves no candidate or animation.

## Verified production path

Inspected production tree: `61d25e123e62481b99aca1d303796a803fffd457`.

- [`CombatScreen`](../presentation/combat/combat_screen.gd) creates `EnemyView` instances in `start_encounter`. Its event handlers call presentation methods, including `lunge`, `take_hit`, `stagger` and `mark_dead`; `_die` sequences the existing death effects.
- [`EnemyView`](../presentation/combat/enemy_view.gd) extends `Control`. `ART_DIRS` selects PNG paintings; `_build_stage` puts the painting on a lit quad in a `SubViewport`. Its 3D glass, procedural idle and fracture effects are not skeletal GLB clip playback.
- Searches of `application/` and `presentation/` found no `AnimationPlayer`, `AnimationTree`, `AnimationLibrary` or `Skeleton3D`, and no reference to the round-4 lab candidate paths. There is no discovered clip-name dispatch, loop configuration, transition graph or blend-time table for those candidates.

Consequently, existing procedural combat durations are not inherited blend times for a future skeletal player. The absence is a source observation at the inspected commit, not evidence that a candidate renders or moves correctly.

## Existing lab interface

Lab inputs are pinned to `6d02a484da4684e6845480b7b83aa597f22ec972` on `lab/rig-round4-handoff`. The branch is research material and must not merge into `main`.

| Input | What it establishes |
| --- | --- |
| [Lab README](https://github.com/eugnel-ltd/glassvow/blob/6d02a484da4684e6845480b7b83aa597f22ec972/lab/rig-round4/README.md) | Candidate identities, review status and measurement rules. Preview crossfades are diagnostic; no candidate is production-approved. |
| [`candidate_motions.py`](https://github.com/eugnel-ltd/glassvow/blob/6d02a484da4684e6845480b7b83aa597f22ec972/lab/rig-round4/pipeline/candidate_motions.py) | The six lower-case action names: `idle`, `walk`, `attack`, `cast`, `hurt`, `death`. |
| [`char_rig.py`](https://github.com/eugnel-ltd/glassvow/blob/6d02a484da4684e6845480b7b83aa597f22ec972/lab/rig-round4/pipeline/char_rig.py) | `clip` keys every bone so one action does not inherit the preceding pose; a looping action repeats its first pose at its last key. Initial authoring uses 30 FPS and exports actions to GLB. |
| [`ground_candidate.py`](https://github.com/eugnel-ltd/glassvow/blob/6d02a484da4684e6845480b7b83aa597f22ec972/lab/rig-round4/pipeline/ground_candidate.py) | Reads the same six actions and scales keyframe positions and scene FPS together for denser contact sampling. Frame count alone therefore does not specify playback duration. |

The lab compatibility target is to retain those six names, complete keyed poses and each selected candidate's exported duration and root/prop motion. Read seconds from the actual exported animation; do not impose a 30 FPS frame range on a densified export. Authored matching endpoints do not configure Godot loop flags. Neither the six names nor this investigation select blend times.

## Loop and transition decisions still open

No production loop flags were found. A minimal **proposal for the future playback delivery**, not an adopted runtime setting, is:

| Clips | Proposed playback |
| --- | --- |
| `idle`, `walk` | Repeat, after checking the raw end-to-start seam. |
| `attack`, `cast`, `hurt`, `death` | Play once. Return/hold/removal and interruption rules remain to be specified by the integration. |

The two transition boundaries requested by #747 are currently unresolved:

| Boundary | Evidence the lab can supply now | What is not decided |
| --- | --- | --- |
| `idle` → `walk` | Compare exported idle-end and walk-start world-space poses before any preview blend. Record the mismatch, including Gravewarden's shoulder mismatch from [#745](https://github.com/eugnel-ltd/glassvow/issues/745). Also check each proposed loop's own seam. | Runtime entry phase, blend curve and duration. A preview crossfade cannot clear a raw mismatch or prove the final transition. |
| Any live action → `death` | [#748](https://github.com/eugnel-ltd/glassvow/issues/748) already requires idle-last → death-first vertical continuity for floaters, and floor contact from first contact onward. Record that step on the exported candidate. | Which poses may interrupt `walk`, `attack`, `cast` or `hurt`; how those sampled poses enter death; blend duration; and the terminal hold/removal. Passing idle → death does not prove arbitrary interruptions. |

Until a playback implementation resolves these entries, lab reports may claim isolated clip and named endpoint results only. They must keep raw endpoint evidence separate from diagnostic blended previews. No guessed default blend or shortened clip may conceal a defect or change gameplay timing; commands and state remain owned by `GlassvowGame.apply`, with presentation consuming its events.

## Handoff

This closes the discovery question by recording the current absence and the smallest existing asset interface. The #737 repair lanes can verify names, exported durations, raw seams and the already-specified floater entry without waiting for invented runtime timings. A future skeletal integration must specify loop flags, transition/interruption policy and blend values, then verify those transitions in the actual player before claiming production readiness. Nothing here promotes a lab asset, changes the current actor, or supplies natural-motion acceptance.
