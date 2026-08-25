# #421 finalist acceptance exam — 2026-08-25

Issue: [#421](https://github.com/fol2/glassvow/issues/421). Protocol: [strategy landscape](2026-08-14-strategy-landscape.md). This is the single unchanged #215/#216 acceptance exam authorised after [#458](https://github.com/fol2/glassvow/issues/458) handed over the ordered finalists `c029`, then `s009`.

## Result

**FAIL.** `s009` passes C2 on all four grids and both Vow-5 ceilings, but fails C1a, C1b, and C3 on all four grids. Dusk V5 also fails C4 by 0.5 percentage points. Per the #421 hard stop, there is no third finalist, adaptive rerun, or further acceptance-seed spend without a new bounded Tier-1 decision.

Issue #421 stays open and continues to block [#108](https://github.com/fol2/glassvow/issues/108) P9.

## Candidate order and Phase A

Each candidate was applied as one complete numeric plus hydrated English and Traditional Chinese packet from `finalists.json`. The locale edits were explicitly brought into scope by the #458 handover.

1. `c029`, commit `d6de8b234d3765b5cf47f9ae1a55891c088dd1a2`, content SHA `0760afb566b6a747450fc33b701124edf60cb8877a9bdd1f89330fa1d347260f`: **VETO**. Its Vow-5 Ash−Dusk holdout gap was +21.5 pp, above the H39 20 pp cap. It was reverted before any landscape run.
2. `s009`, commit `b30b290813d88109c5b9bc34354babefdc406f8d`, content SHA `5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448`: identity-split campaign **GO**. All four arm-2 cells were below 50%; Ash−Dusk was +15.0 pp at Vow 0 and +13.5 pp at Vow 5.

The Phase-A driver still records a VETO against the superseded pre-identity #204 bands. This readout does not claim #204 PASS; it follows the signed H10/H11 exception.

| Grid | `s009` arm 2 | `s009` holdout |
|---|---:|---:|
| Dusk V0 | 50/200 (25.0%) | 131/200 (65.5%) |
| Dusk V5 | 16/200 (8.0%) | 75/200 (37.5%) |
| Ash V0 | 58/200 (29.0%) | 161/200 (80.5%) |
| Ash V5 | 16/200 (8.0%) | 102/200 (51.0%) |

Phase-A holdout and arm 2 had zero stalls/errors. The controls retained eight arm-3 Dusk stalls as non-wins and had zero errors.

## Immutable exam identity

- Commit: `b30b290813d88109c5b9bc34354babefdc406f8d`
- Published remote pin: `work/421-s009-exam`
- Content SHA-256: `5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448`
- Godot: `4.7.2-stable (official)`
- Layer 1: root 215, policies 0–1999, seeds 3000–3039, shipping mix
- Layer 2: root 216, 24 islands, training from seed 4200, published holdout seeds 5000–5199 only

All ten Layer-1 shards and all 24 Layer-2 manifests bind to that exact identity. The Layer-2 parent session exited 0; every island has one manifest, exactly 200 holdout rows, and one final row.

## Layer 1 — C1a/C1b FAIL; C2 PASS

The merged 320,000 rows contain 85,819 wins, 233,968 losses, 213 stalls counted as non-wins, and zero errors.

| Grid | Top cell / rate | Within 10 pp | Floor / viable | Arm 2 / gap | C1a | C1b | C2 |
|---|---|---:|---:|---:|---|---|---|
| Dusk V0 | shatter:fat 78.58% | 1 | 51.79% / 1 | 25.0% / +53.58 pp | **FAIL** | **FAIL** | PASS |
| Dusk V5 | shatter:fat 69.46% | 1 | 38.73% / 1 | 8.0% / +61.46 pp | **FAIL** | **FAIL** | PASS |
| Ash V0 | smolder:fat 74.26% | 2 | 51.63% / 2 | 29.0% / +45.26 pp | **FAIL** | **FAIL** | PASS |
| Ash V5 | smolder:fat 57.81% | 2 | 32.91% / 2 | 8.0% / +49.81 pp | **FAIL** | **FAIL** | PASS |

C1a needs at least three cells within 10 pp; C1b needs at least four viable cells. Both observed count vectors are `1 / 1 / 2 / 2`. The measured mechanism is still concentration in fat decks: Dusk collapses to shatter-fat, while Ash has only smolder-fat and attrition-fat near or above the floor. Lowering arm 2 clears C2 but does not create strategy breadth.

## Layer 2 — C3 FAIL; Dusk V5 C4 FAIL

The 4,800 holdout rows contain 3,251 wins, 1,544 losses, five stalls counted as non-wins, and zero errors. The stalls are all Dusk V5: islands 6 (1), 8 (1), 9 (2), and 11 (1). Nineteen islands stopped on the frozen stall rule and five at `maxGen=20`.

| Grid | Stayed viable | Close to best | Best holdout | C3 | End-cell ceilings / C4 | Vow-5 ceiling |
|---|---:|---:|---:|---|---|---|
| Dusk V0 | 2 | 1 | 82.5% | **FAIL** | shatter-fat 82.5%, shatter-mid 81.5% / PASS | n/a |
| Dusk V5 | 0 | 0 | 47.5% | **FAIL** | shatter-fat 47.5%, shatter-thin 32.0% / **FAIL** | PASS |
| Ash V0 | 0 | 0 | 93.0% | **FAIL** | smolder-mid 93.0%, smolder-fat 91.0% / PASS | n/a |
| Ash V5 | 0 | 0 | 77.0% | **FAIL** | smolder-mid 77.0%, smolder-fat 70.0%, attrition-thin 54.0% / PASS | PASS |

C3 needs at least four islands to stay viable and three of those within 15 pp of the grid best. Dusk V0 reaches only `2 / 1`; the other three grids are `0 / 0`. Optimisation again abandons almost every seeded non-dominant start cell.

Dusk V5's best two end-cell ceilings differ by 15.5 pp; C4 requires less than 15 pp, so it fails by 0.5 pp. Vow-5 maxima are 47.5% Dusk and 77.0% Ash, both below the fail-closed 90% ceiling.

## Raw evidence and replay key

Raw NDJSON remains untracked under `/private/tmp/glassvow-421-s009-landscape.HML9Pn/`; Phase A remains under `/private/tmp/glassvow-421-s009-phase-a.K8djq9/`. These hashes bind the local evidence used for this readout:

| Evidence | SHA-256 |
|---|---|
| Phase-A report | `072f205fdc0af4e4608bd53ecc2916de119c0d0210f827db55bd583e80663994` |
| Layer-1 controls | `fc48e2bfd3d8594076afab33ab76f9233d3760f694ffc9879eb191132e986f51` |
| Layer-1 analysis | `5fb108e2e10b5b535e9ba374a1a4c2039e5986a8c70ffdeeadeb718fb2959bb0` |
| Layer-2 seed map | `6fd3f09faca312cb755e4f2d7d227d9c3ee19312422977904a09f3766eeccb93` |
| Layer-2 analysis | `ee681bc3ec298b767962c86348f54cf2a87d4eaaea26106c22fff488aba35307` |
| Sorted Layer-1 shard hash manifest | `916b6c8a4b80d7e89e59018c451e48cb73467f2c58fcadbbecca7af9741a63c9` |
| Sorted Layer-2 island hash manifest | `5247099a91d90efb0f555dd1dfb626377c897ea4e16b459003e5d01beebc7593` |

The two manifest hashes are `shasum -a 256` over the sorted per-file `shasum -a 256` output, including the absolute scratch paths shown above. Replay also requires the row's aspect, vow, seed, resolved policy, and policy index; Layer 1 uses sampler root 215 and Layer 2 uses CEM root 216.

This negative result describes the frozen policy grammar and seeds only. It does not claim that no degenerate strategy exists, that Tier-2 lookahead was searched, or where human players sit.
