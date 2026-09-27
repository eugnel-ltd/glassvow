# Duskblade breadth retune — amended P9 exam

**Final numeric outcome: MISS in both exams.** C1a/C1b remain one cell at both vows; C3 retention fails in both exams. The single HP 68 → 72 iteration improves V0 reachable-cell gaps and brings both C4 gaps below 15 pp, but does not satisfy amended P9. The authorised two-exam limit is reached; stop without further tuning.

This is the numeric Duskblade-only readout for vows 0 and 5 under [the design lock](../reviews/421/duskblade-breadth-retune-design-lock.md) and [amended P9, points 2 and 3](https://github.com/fol2/glassvow/issues/108#issuecomment-5850584190). The independent clean rerun is operator-owned; human feel sign-off is separate. Neither is claimed complete here.

**Implementation and compatibility.** Refract Ward is 8/11, Emberheart heals 6, and the first candidate starts Duskblade at 68 HP. Removal remains **75**: a regression wrote a v2 open shop quoted at 75, loaded it under the proposed 55-gold catalogue, and attempted actual shop resumption. Resumption rejected the checkpoint. Change 4 was dropped without a migration; the same regression passes at 75. Ashwarden-specific content, identity rules, vows, roots and port fixtures are unchanged.

C1b and C3 counts are three throughout the readouts and development deficit formulas. C3 requires every stayed-viable island within 15 pp of the grid best; the V5 ceiling is strictly below 90%. Historical s009 reconstruction uses committed H39 bytes and still yields `5b3504f133a7e180f20426a8f28c5f2685c9d00d4e3c93c39a432a1a859ea448`. Historical Tier-1 locale centres and the F0 replay test also use committed H39 inputs.

**Execution.** Godot `4.7.2.stable.official.ed1daf0bf`; all Godot processes use `nice -n 10`, with no more than six concurrent on this desktop. Each exam uses ten fixed 200-policy shards (root 215, seeds 3000–3039), fresh 200-seed controls (4000–4199), then 12 Duskblade CEM islands (sampler root 215, CEM root 216, training 4200–4999, holdout 5000–5199). Every sweep, control and CEM invocation uses `--stage=exam`; all flags follow `--`. Islands follow the 2026-08-14 rule: top six cells per grid with at least 20 policies; best in-cell representative, ties to lower policy index. Raw rows remain outside the repository; committed manifests include their paths, sizes and SHA-256 hashes.

**Reproduction band (design-lock §4 wording).** same SHA + same seeds ⇒ 0.0 pp expected on every cell and ceiling; a difference larger than the Wilson half-width (1.0 pp on any layer-1 cell with ≥ 4,000 runs, 5.0 pp on any n=200 holdout ceiling) is a reproduction failure, not variance. Compare balance cells and ceilings; recorded execution durations are host-dependent.

**Validation.** The first candidate passed local imports, the complete script sweep, all 73 Godot tests, and selected balance/locale-text checks. [Candidate-1 CI](https://github.com/fol2/glassvow/actions/runs/36280827980) passed, including font coverage. Local FontTools was unavailable; no package was installed on the desktop. Subsequent candidate/final-head gate receipts are recorded in the PR. The PR remains draft; no merge is authorised.

**Exam 1: MISS**

Candidate `8bfa08c0f987d0f836ba03fe0e4202a470dd572d`. Content SHA `667125b7ddb929d0bcc4297fb8ef8eab24e98f5dc252edd74999c0faa4dbf413`. [Packet](data/421-retune/exam-1/raw-rows-manifest.json).

Layer 1 contains 320,000 rows: win=66,804, loss=253,128, stall=68. Stalls remain in the denominators; no rows were discarded. Layer 2 contains twelve islands with 200 holdout rows each: loss=1,053, stall=1, win=1,346.

| Criterion | Threshold | Dusk V0 | Dusk V5 |
|---|---|---|---|
| #108.2 / C1a: within 10 pp | ≥3 cells | 1 — MISS | 1 — MISS |
| #108.2 / C1b: viable | ≥3 cells | 1 (floor 49.61%) — MISS | 1 (floor 34.01%) — MISS |
| #108.2 / C2: arm 2 | <50% | 28.00% — PASS | 11.00% — PASS |
| #108.2 / C2: arm-2 gap | ≥35 pp | 43.22 pp — PASS | 46.03 pp — PASS |
| #108.3 / C3: stayed viable | ≥3 islands | 0 — MISS | 2 — MISS |
| #108.3 / C3: stayed islands close to best | all within 15 pp | no stayed-viable islands — MISS | 0/2 (max gap 18.00 pp) — MISS |
| #108.3 / C4: end-cell ceiling gap | <15 pp | 8.00 pp — PASS | 15.50 pp — MISS |
| #108.3: V5 best holdout | <90% | 87.00% (not applicable) | 57.00% — PASS |

| Vow | Reachable cell | s009 top − cell | Retune top − cell |
|---|---|---:|---:|
| V0 | shatter:mid | 31.32 pp | 29.37 pp |
| V0 | attrition:fat | 32.05 pp | 33.52 pp |
| V5 | shatter:mid | 51.72 pp | 44.33 pp |
| V5 | attrition:fat | 45.15 pp | 43.08 pp |

| Grid | Island | Start → end cell | Holdout | Generations | Stop |
|---|---:|---|---:|---:|---|
| duskblade:v0 | 0 | shatter:fat → shatter:mid | 135/200 (67.5%) | 15 | stall |
| duskblade:v0 | 1 | shatter:mid → shatter:fat | 150/200 (75.0%) | 20 | maxGen |
| duskblade:v0 | 2 | smolder:fat → shatter:fat | 174/200 (87.0%) | 18 | stall |
| duskblade:v0 | 3 | attrition:fat → shatter:fat | 132/200 (66.0%) | 17 | stall |
| duskblade:v0 | 4 | smolder:mid → shatter:mid | 158/200 (79.0%) | 20 | maxGen |
| duskblade:v0 | 5 | shatter:thin → shatter:fat | 134/200 (67.0%) | 13 | stall |
| duskblade:v5 | 6 | shatter:fat → shatter:fat | 78/200 (39.0%) | 17 | stall |
| duskblade:v5 | 7 | smolder:fat → shatter:fat | 38/200 (19.0%) | 14 | stall |
| duskblade:v5 | 8 | attrition:fat → shatter:fat | 83/200 (41.5%) | 20 | maxGen |
| duskblade:v5 | 9 | shatter:mid → shatter:mid | 79/200 (39.5%) | 20 | stall |
| duskblade:v5 | 10 | smolder:mid → shatter:fat | 71/200 (35.5%) | 13 | stall |
| duskblade:v5 | 11 | shatter:thin → shatter:mid | 114/200 (57.0%) | 20 | maxGen |

CEM `stop=stall` denotes the unchanged optimiser plateau rule, not a simulation stall. The s009 gap columns are historical comparisons, not a controlled estimate of the isolated retune effect.

**Exam 2: MISS**

Candidate `df9ab247b7700ed2e7d413753af091b75e3778d3`. Content SHA `8934031593228e450d3670d24da01aa4717480bd01ea4392e359d69a6f474248`. [Packet](data/421-retune/exam-2/raw-rows-manifest.json).

Layer 1 contains 320,000 rows: win=71,077, loss=248,842, stall=81. Stalls remain in the denominators; no rows were discarded. Layer 2 contains twelve islands with 200 holdout rows each: loss=994, win=1,406.

| Criterion | Threshold | Dusk V0 | Dusk V5 |
|---|---|---|---|
| #108.2 / C1a: within 10 pp | ≥3 cells | 1 — MISS | 1 — MISS |
| #108.2 / C1b: viable | ≥3 cells | 1 (floor 54.45%) — MISS | 1 (floor 35.26%) — MISS |
| #108.2 / C2: arm 2 | <50% | 36.00% — PASS | 12.00% — PASS |
| #108.2 / C2: arm-2 gap | ≥35 pp | 36.90 pp — PASS | 46.51 pp — PASS |
| #108.3 / C3: stayed viable | ≥3 islands | 1 — MISS | 0 — MISS |
| #108.3 / C3: stayed islands close to best | all within 15 pp | 1/1 (max gap 6.00 pp) — PASS | no stayed-viable islands — MISS |
| #108.3 / C4: end-cell ceiling gap | <15 pp | 6.00 pp — PASS | 9.00 pp — PASS |
| #108.3: V5 best holdout | <90% | 90.50% (not applicable) | 58.00% — PASS |

| Vow | Reachable cell | s009 top − cell | Retune top − cell |
|---|---|---:|---:|
| V0 | shatter:mid | 31.32 pp | 27.91 pp |
| V0 | attrition:fat | 32.05 pp | 31.88 pp |
| V5 | shatter:mid | 51.72 pp | 44.58 pp |
| V5 | attrition:fat | 45.15 pp | 43.28 pp |

| Grid | Island | Start → end cell | Holdout | Generations | Stop |
|---|---:|---|---:|---:|---|
| duskblade:v0 | 0 | shatter:fat → shatter:fat | 169/200 (84.5%) | 19 | stall |
| duskblade:v0 | 1 | shatter:mid → shatter:fat | 115/200 (57.5%) | 13 | stall |
| duskblade:v0 | 2 | smolder:fat → shatter:fat | 117/200 (58.5%) | 6 | stall |
| duskblade:v0 | 3 | attrition:fat → shatter:fat | 166/200 (83.0%) | 13 | stall |
| duskblade:v0 | 4 | smolder:mid → shatter:mid | 181/200 (90.5%) | 12 | stall |
| duskblade:v0 | 5 | shatter:thin → shatter:mid | 141/200 (70.5%) | 16 | stall |
| duskblade:v5 | 6 | shatter:fat → shatter:mid | 116/200 (58.0%) | 14 | stall |
| duskblade:v5 | 7 | attrition:fat → shatter:fat | 84/200 (42.0%) | 17 | stall |
| duskblade:v5 | 8 | smolder:fat → shatter:fat | 98/200 (49.0%) | 20 | maxGen |
| duskblade:v5 | 9 | shatter:mid → attrition:thin | 40/200 (20.0%) | 19 | stall |
| duskblade:v5 | 10 | smolder:mid → shatter:mid | 70/200 (35.0%) | 20 | stall |
| duskblade:v5 | 11 | shatter:thin → shatter:mid | 109/200 (54.5%) | 19 | stall |

CEM `stop=stall` denotes the unchanged optimiser plateau rule, not a simulation stall. The s009 gap columns are historical comparisons, not a controlled estimate of the isolated retune effect.

**The single authorised §6 iteration.** Exam 1 missed both layers. The dominant shared deficit was V5: shatter:mid and attrition:fat remained 44.33 and 43.08 pp below the top, against V0 gaps of 29.37 and 33.52 pp. The selected branch is “all non-top V5 cells lagging together”: Dusk max HP **68 → 72**, in both `player.maxHp` and `aspects[0].maxHp`. No additional knob was applied. Exam 1 C2 gaps exceeded 40 pp, so the arm-2 pullback branch was not selected; the “layer 2 fails while layer 1 passes” branch does not apply because layer 1 also missed. Phase A and a paired mini-landscape with frozen #215 axes and development seeds ≥9000 preceded the second full exam. Both authorised exams are complete; no further content adjustment was made.

The paired development mini-screen used `balance_f0.py` sweep/aggregation primitives with fixed #215 axes, root 3454, 128 policies × 8 seeds (9200–9207) and 32-seed controls (9100–9131, arms 1 and 2). [Full mini-screen](data/421-retune/iteration-2-mini-analysis.json). V5 within-10/viable proxies moved from 1/1 to 2/2; V0 moved from 1/3 to 1/2. These unfiltered development proxies are not acceptance: V0’s top is an incidental Smolder cell with only 1/1 run in each version, and the 32-seed V5 arm-2 gap is below 35 pp in both versions (24.89 → 22.37 pp). The locked 200-seed Phase A guard passes; no additional knob or extra iteration is introduced. The full second exam provides the final numeric decision.

**Phase A.** The lane guard is all four arm-2 rates below 50%, plus Dusk V0 below 45%. The script also reports its legacy #204 holdout bands; those are retained in the phase-a JSON and are not substituted for the design lock’s stated gate. Candidate 1: Dusk V0/V5 28%/11%, Ash V0/V5 21%/6%, so 68 HP was retained. Its legacy #204 result was VETO (Dusk 73.5%/36.5%, Ash 72%/41.5%). One arm-3 Dusk V0 stall at seed 4060 was preserved; fresh exam controls reproduced all Phase A raw rows exactly.

Candidate 2 (72 HP): arm-2 duskblade V0 72/200 (36.0%), duskblade V5 24/200 (12.0%), ashwarden V0 42/200 (21.0%), ashwarden V5 12/200 (6.0%). The locked Phase A guard passes, so 72 HP is retained. The legacy #204 holdout bands still emit VETO (Dusk 76.5%/44.5%, Ash 72%/41.5%); no guard was weakened.

The 72-HP candidate also passed local imports, the complete script sweep, all 73 Godot tests, selected balance and locale-text checks, doc anchors and the reference freeze. Font coverage remains covered by the existing PR CI; no desktop packages are installed.

[Candidate-2 CI](https://github.com/fol2/glassvow/actions/runs/36293987457) passed, including font coverage. Fresh second-exam controls reproduced every Phase A2 raw row exactly. Both exams’ manifests report Godot `4.7.2-stable (official)`, and all 24 island ceilings were checked against their raw holdout wins divided by 200.
