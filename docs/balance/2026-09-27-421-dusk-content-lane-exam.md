# Dusk content lane (Unbroken Crown): amended P9 exam 1

**Final numeric outcome: MISS.** The crown creates a real second Dusk lane: smolder:fat is now within 10 pp of the top at both vows (V0 64.9% against 70.7%, V5 47.1% against 55.5%). There is still no third cell at either vow. C1a, C1b and C3 miss at V0 and V5, and C2 misses at V0 (random-build arm 2 reaches 44%, so the gap is 26.7 pp). C4 and the V5 ceiling pass. Design lock §7 says to stop if only two cells are in band. The single retry was already spent on the pre-exam dev gate (Smolder 2 → 3), so no knob remains. This is the only exam.

Candidate `935fa5d45c46dfda402535f2957af7ac8a14e9b1` (draft PR #557), content SHA `a9ad6c558cf05c35e1d326f9a45540f5b7d245b85005a64cd7808f734ffc4440`. Design lock: [dusk-content-lane-design-lock.md](../reviews/421/dusk-content-lane-design-lock.md). Acceptance: [amended P9, points 2 and 3](https://github.com/fol2/glassvow/issues/108#issuecomment-5850584190), Duskblade only, vows 0 and 5. [Packet](data/421-content-lane/raw-rows-manifest.json).

**Execution.** Host: Linux x86_64 VM, 8 vCPU, Godot `4.7.2.stable.official.ed1daf0bf` (the CI-pinned build), fresh detached worktree at the candidate. The procedure is #556's, unchanged: Phase A via `tools/balance_phase_a.py`; ten fixed 200-policy shards (root 215, seeds 3000–3039); fresh 200-seed controls (4000–4199); `tools/balance_landscape.py`; 12 Duskblade CEM islands (top six cells per grid with at least 20 policies, best in-cell representative, ties to the lower policy index; sampler root 215, CEM root 216, training 4200–4999, holdout 5000–5199); `tools/balance_cem_report.py`. Every sweep, control and CEM call uses `--stage=exam` with all flags after `--`. All Godot processes ran at `nice -n 10`. Layer 1 ran its 11 jobs at once and layer 2 its 12 islands at once, so no cores idled in a second wave. Each job is an independent process, so scheduling cannot change rows. Wall clock: Phase A 3 min, layer 1 43 min, layer 2 80 min. Raw rows stay outside the repository; the manifest lists their paths, sizes and SHA-256.

**Pre-exam dev gate (design lock §4): PASS.** The runner was rebuilt from the probe notes §1 and not committed: Dusk only, policy root 7421, policies 0–299, dev seeds 12000–12015, vows 0 and 5. Twins are the same policy, vow and seed on `e7a004d7`. A holder is a run that ends holding the crown. The rebuilt runner reproduces the first gate on `74ad72d` exactly (V0 354/751 against 375/751, −2.80 pp; V5 114/410 against 145/410, −7.56 pp). On the candidate (Smolder 3), V0 is 395/751 against 375/751 (**+2.66 pp**) and V5 is 137/410 against 145/410 (**−1.95 pp**). Both are at least −5 pp. [Dev gate](data/421-content-lane/dev-gate.json).

**Phase A: locked guard PASS.** Arm 2: Dusk V0 88/200 (44.0%), Dusk V5 30/200 (15.0%), Ash V0 42/200 (21.0%), Ash V5 12/200 (6.0%). All four are under 50% and Dusk V0 is under 45%. The legacy #204 holdout bands still report VETO (Dusk 71.0%/41.0%, Ash 72.0%/41.5%), as they did for #556. They are kept in the JSON and are not the lock's gate. Fresh exam controls reproduced all 3,200 Phase A control rows exactly.

**Exam 1: MISS**

Layer 1 contains 320,000 rows: win=70,580, loss=249,341, stall=79. Stalls stay in the denominators; no rows were discarded. Axes come from this exam: deck cuts 21/30, Dusk medians 0.963 shatters and 0.0 smolder kills per fight. Layer 2 contains twelve islands with 200 holdout rows each.

| Criterion | Threshold | Dusk V0 | Dusk V5 |
|---|---|---|---|
| #108.2 / C1a: within 10 pp of top | ≥3 cells | 2 (shatter:fat, smolder:fat) — MISS | 2 (shatter:fat, smolder:fat) — MISS |
| #108.2 / C1b: viable | ≥3 cells | 2 (floor 57.33%) — MISS | 2 (floor 35.26%) — MISS |
| #108.2 / C2: arm 2 | <50% | 44.00% — PASS | 15.00% — PASS |
| #108.2 / C2: arm-2 gap | ≥35 pp | 26.66 pp — MISS | 40.52 pp — PASS |
| #108.3 / C3: stayed viable | ≥3 islands | 0 — MISS | 1 (island 9) — MISS |
| #108.3 / C3: stayed islands close to best | all within 15 pp | no stayed-viable islands — MISS | 0/1 (gap 17.50 pp) — MISS |
| #108.3 / C4: end-cell ceiling gap | <15 pp | 11.50 pp — PASS | 6.00 pp — PASS |
| #108.3: V5 best holdout | <90% | 92.50% (not applicable) | 64.50% — PASS |

**Gaps from the top cell**, #556 exam 2 (`df9ab247`, no crown) against this exam:

| Vow | Cell | #556 exam 2: rate, gap | Crown exam 1: rate, gap |
|---|---|---:|---:|
| V0 | top shatter:fat | 72.90% | 70.66% |
| V0 | smolder:fat | 41.74%, 31.16 pp (n 860) | **64.86%, 5.80 pp** (n 7,744) |
| V0 | shatter:mid | 45.00%, 27.91 pp | 39.68%, 30.98 pp |
| V0 | attrition:fat | 41.02%, 31.88 pp | 37.02%, 33.64 pp |
| V0 | smolder:mid | 14.49%, 58.41 pp | 30.69%, 39.97 pp |
| V5 | top shatter:fat | 58.51% | 55.52% |
| V5 | smolder:fat | 14.77%, 43.75 pp (n 298) | **47.08%, 8.44 pp** (n 3,505) |
| V5 | attrition:fat | 15.24%, 43.28 pp | 14.31%, 41.21 pp |
| V5 | shatter:mid | 13.94%, 44.58 pp | 10.21%, 45.31 pp |
| V5 | smolder:mid | 1.51%, 57.00 pp | 10.21%, 45.31 pp |

**Crown holders (layer 1).** V0: 12,884 of 80,000 Dusk runs (16.1%) end holding the crown. They win 51.8%, against 33.3% for non-holders. 7,270 of them land in smolder:fat, which they win 66.9% of the time. V5: 6,332 of 80,000 (7.9%) hold it. They win 33.1%, against 10.4% for non-holders. 3,310 land in smolder:fat, which they win 49.1% of the time. The per-grid counts are in the manifest.

| Grid | Island | Start → end cell | Holdout | Generations | Stop |
|---|---:|---|---:|---:|---|
| duskblade:v0 | 0 | shatter:fat → smolder:fat | 185/200 (92.5%) | 14 | stall |
| duskblade:v0 | 1 | smolder:fat → shatter:fat | 126/200 (63.0%) | 8 | stall |
| duskblade:v0 | 2 | shatter:mid → smolder:fat | 145/200 (72.5%) | 20 | maxGen |
| duskblade:v0 | 3 | attrition:fat → shatter:fat | 150/200 (75.0%) | 15 | stall |
| duskblade:v0 | 4 | smolder:mid → shatter:mid | 162/200 (81.0%) | 20 | maxGen |
| duskblade:v0 | 5 | smolder:thin → shatter:mid | 150/200 (75.0%) | 9 | stall |
| duskblade:v5 | 6 | shatter:fat → smolder:fat | 66/200 (33.0%) | 20 | maxGen |
| duskblade:v5 | 7 | smolder:fat → shatter:mid | 129/200 (64.5%) | 16 | stall |
| duskblade:v5 | 8 | attrition:fat → shatter:thin | 73/200 (36.5%) | 7 | stall |
| duskblade:v5 | 9 | shatter:mid → shatter:mid | 94/200 (47.0%) | 18 | stall |
| duskblade:v5 | 10 | smolder:mid → shatter:mid | 120/200 (60.0%) | 14 | stall |
| duskblade:v5 | 11 | smolder:thin → shatter:fat | 117/200 (58.5%) | 20 | maxGen |

CEM `stop=stall` is the optimiser's plateau rule, not a simulation stall.

**Reading.** The lane works as designed: holders stop feeding shatter and win through Ward plus Smolder, and smolder:fat moves from omen noise into the 10 pp band at both vows. The third cell the lock flagged as the likeliest miss (§7) did not appear. shatter:mid and attrition:fat are slightly further behind than in #556, and smolder:mid is still 40–45 pp back. Crown islands also drift: CEM moves two V0 islands into smolder:fat and moves the smolder:fat starts out of it, so no island stays in its start cell at V0. At V0 the crown also lifts random builds (arm 2 36% → 44%), which breaks C2. Per lock §7 the remaining lever is the shatter bundle itself (Cracked 2 → 1), which is code and needs its own ruling.

**Reproducibility.** Owner ruling, 13:41 BST 2026-09-27 ([#421](https://github.com/fol2/glassvow/issues/421#issuecomment-5855915475)): an independent re-run passes if every criterion gets the same PASS/MISS verdict, on any host. This replaces lock §5's exact-match rule. The exam missed, so no re-run was scheduled. The PR stays draft and is not for merge.
