# Dusk lane 3 — C3 diagnosis and fix design (#421)

Owner: Ash (PM). Author: Claude (diagnosis and design only; no game code or content changed). Base: draft #568 head `3c5144e` (content = `582e2f7`, Rootheart 280). Inputs: the [exam 1 readout](../../balance/2026-09-28-421-dusk-lane3-exam.md) and its raw rows (read-only, outside Git), the #557 exam 1 rows for comparison, and fresh development probes (§6).
Tags: VERIFIED = measured on exam rows or probes, or read in code; INFERRED = reasoned from verified data; UNKNOWN = needs an exam. Development probes are not acceptance evidence.

**Revision 2.** The owner put candidate A on hold after an independent review returned REQUEST CHANGES (four blockers, six nits). This revision fixes those points and adds two owner-specified probes on development seeds (§3): a fixed-policy frontier check around layer-1 policy 846, and a full-scale layer-2 rehearsal of A and B.

## 1. Answer

**Mostly an honest game signal.** Several tool properties add noise, but they do not explain the V0 direction. Two content causes produce the miss:
- **At V5, the act-1 wall.** At 280 HP the Rootheart ends 42–54% of each exam V5 island's holdout runs; at 240 HP (#557) it was 13–41% (VERIFIED). On 200 dev seeds, the best known V5 whole-policy win rate is 45–47%, and that frontier is shatter:fat. Layer-1 policy 846 wins 45.0%, and the exam's own best V5 policy (island 7) wins 46.5% (§3.1, VERIFIED). CEM reached that frontier in the shatter lane. The fork-lane V5 islands sit 10–18.5 pp below it on the same seeds (VERIFIED); part of that gap may come from where they start (row 7, INFERRED).
- **At V0, no fork is a competitive first boss relic for optimised play.** Hollow Crown is the best pick and is lane-neutral. The fullness rule made the Unbroken Crown the worst pick. Each fork appears in only half of the act-1 boss offers.

So CEM keeps chipping, and its islands leave the fork cells. The representative rule, argmax fitness, the modal-over-all-rows end cell and relic-blind drafting decide which cell each island lands in. A reading that removes those effects still misses C3 (§2, row 8).

**No probe shows C3 at either vow.** At probe scale, A's "4 V0 stays" were two replicate islands each of shatter:fat and attrition:fat. That is 2 distinct cells, and C3 needs 3. §3.2 gives the full-scale rehearsal count: A (P1 + R260) keeps 1 distinct cell at V0 and 1 at V5. B (P1) keeps 2 at V0, neither within 15 pp of its grid best, and 1 at V5 (VERIFIED on dev seeds).

**Decision:** **no variant qualifies, so lane 3 stops at the exam-1 MISS, with no C3 loosening.** The owner rule allows a variant only if it shows at least 3 distinct V0 stays and a credible V5 path, and prefers B over A if tied. Neither A nor B meets it (§3.2), so neither content field is implemented and no exam is spent (§5).

## 2. Diagnosis

| # | Finding | Evidence | Tag |
|---|---|---|---|
| 1 | V5 ceilings come from the act-1 wall. | Exam V5 islands lose 42–54% of holdout runs to the Rootheart; at 240 HP (#557) it was 13–41%. Pooled, 49.2% of V5 holdout runs beat it (#557: 74.2%), and 51.1% of those win (#557: 67.3%). Layer-1 Rootheart deaths at V5: 57.7% (#557: 48.5%). | VERIFIED |
| 2 | 45–52% is not a CEM target, and CEM reached the V5 whole-policy frontier in the shatter lane. | A layer-1 cell rate is conditional on ending in that cell, so fat cells hold survivors. A CEM ceiling is a whole-policy win rate. On the same 200 dev seeds, policy 846 wins 45.0% and exam island 7's final policy 46.5% at V5. Each exam figure was a tail draw: 846's 62.5% came from 40 exam seeds, and island 7's 38.5% was its exam holdout. The next four layer-1 V5 policies win 19.5–37.5% there. Four small perturbations of 846 win 27.5–39.5% (§3.1). | VERIFIED numbers; INFERRED reading |
| 3 | V5 end cells record where islands die. | 38.9% of V5 holdout rows (467 of 1,200) are thin-deck act-1 deaths, and 50.8% are act-1 deaths at any deck size. So the modal row (`tools/balance_cem_report.py:33`) is a thin cell even when the winners stay. Island 8's wins are modal attrition:fat (27 of 47), but its rows are modal shatter:thin (42 of 200). | VERIFIED |
| 4 | At V0 the optimiser leaves the forks for a measurable reason. | Pooled exam holdout, act-1 survivors, win rate by first boss relic: Hollow Crown 84% (n 511), Tithes 70% (43), other crowns 66–69%, Unbroken Crown 50% (70). In #557 the crown was 83% (133). Hollow Crown ranks first in 10 of 12 final policies. Forcing the start-lane relic to the top of each exam V0 final policy lowers its win rate on 5 of 6 islands over 200 dev seeds (island 4: 43.5% → 28.0%). | VERIFIED |
| 5 | Fullness is what sank the crown for tuned play. | Optimised decks are lean. Island 0 holds the crown in 60% of its runs, yet 72 of its 200 rows end in smolder:mid (29 or fewer cards), where the crown pays only 2 + 2. | VERIFIED rows; INFERRED cause |
| 6 | Offer arithmetic caps any fork island. | A fork appears in 3 of 6 boss offers. Forcing the start-lane relic to the top of the exam's own final policies (200 dev seeds) makes it the first boss pick in only 36–46.5% of V0 runs and 19–32% of V5 runs across all six islands per vow. On the fat-cell islands alone, the ranges are 42–46.5% and 26–32%. | VERIFIED |
| 7 | Tool properties add noise. | **Representatives:** the rule (`tools/balance_exam.py:115` (in select_islands)) takes the best in-cell rate. All 12 exam representatives are 100% on 1–5 in-cell runs. They place only 1–5 of their 40 layer-1 runs in the start cell, and the V5 ones win 2.5–10% overall. Policy 63 represents two V5 cells. On dev rows the same rule picks policy indices 0–112. At V5, the shatter island still reached the frontier from such a start. The fork islands 6 and 8 replay at 35.0% and 28.0% on dev seeds, while the best fork-leaning layer-1 policy found (1132, modal attrition:fat) wins 36.5%.<br>**Fitness:** the returned policy is the single best candidate on 40 fresh seeds (`tools/balance_cem.gd:100` (in _initialize), `tools/balance_cem.gd:109` (in _initialize)). Best-train fitness is 0.73–0.93 at V0 (holdout 0.54–0.71) and 0.33–0.65 at V5 (holdout 0.18–0.39). The stall rule reads the monotone best-ever (`tools/balance_cem.gd:120` (in _initialize)). Final sigma is 0.13–0.21, well above the 0.02 floor.<br>**Holdout draw:** island 2's exact policy ties attrition:fat and shatter:fat at 64 rows each on 200 dev seeds; on the exam seeds it was 44 against 82.<br>**Grammar:** card and relic scores ignore the relics held (`tools/balance_pilot.gd:330` (in card_score), `tools/balance_pilot.gd:337` (in card_score)). Fork holders still carry 3.2–3.6 chip cards per deck, against 3.8 for others. `cardDecline` is one global threshold. | VERIFIED existence. INFERRED: noise, not direction, at V0 and for the V5 shatter island. For the V5 fork islands, the start may cost up to about 8.5 pp (INFERRED). |
| 8 | Not a rules artefact alone. | Reading end cells from wins only would give V0 1 and V5 2 (islands 8 and 10, 23.5% and 21.0%). Both are below the V5 floor of 31.61%, so C3 would still miss. | VERIFIED |

Rules changes James could weigh: a representative with a minimum number of in-cell runs, end cells taken from wins, or holdout run on the CEM mean. They are described here only. This note does not recommend them, and the decision below does not loosen C3.

## 3. Follow-up probes (owner HOLD on candidate A)

### 3.1 Policy 846 frontier check

Fixed-policy replay on dev seeds 13000–13199 (200 seeds). Cells use the exam-1 axes (cuts 20/29, Dusk shatter median 0.889). "Neighbours" are the next four exam layer-1 V5 policies (1132, 1822, 342; 569 wins a four-way tie at 35% on lower index). The perturbations multiply every magnitude weight of 846 by exp(N(0, s)) and move each threshold by N(0, t × its CEM range): p1 and p2 use s 0.1, t 0.05; p3 and p4 use s 0.2, t 0.10 (Python RNG seed 846).

| Policy | Layer-1 V5 (#568 / #557 exam, 40 seeds) | V5 at 280 | V5 at 260 | V5 P1 | V5 P1 + 260 | V5 Rootheart deaths (280) | V5 modal cell (280) | V0 at 280 · P1 + 260 |
|---|---|---:|---:|---:|---:|---:|---|---|
| **846** | 62.5 / 65.0 | **45.0** | 50.5 | 45.0 | 50.0 | 37.5 | shatter:fat (70) | 72.0 · 74.0 |
| 1132 | 40.0 / 50.0 | 36.5 | 39.5 | 39.0 | 43.0 | 38.0 | attrition:fat (45) | 66.5 · 71.0 |
| 1822 | 40.0 / 22.5 | 19.5 | 19.5 | 22.0 | 21.0 | 53.5 | shatter:thin (53) | 41.0 · 46.5 |
| 342 | 37.5 / 40.0 | 37.5 | 42.0 | 37.5 | 47.5 | 33.0 | shatter:fat (79) | 73.5 · 82.5 |
| 569 | 35.0 / 47.5 | 33.5 | 33.0 | 35.0 | 36.0 | 44.5 | shatter:fat (69) | 71.5 · 76.5 |
| 846 p1 / p2 (small) | — | 39.5 / 39.0 | 46.0 / 39.5 | 41.5 / 35.0 | 46.5 / 40.5 | 38.0 / 43.0 | shatter:fat | 65.0 / 73.0 · 73.5 / 79.0 |
| 846 p3 / p4 (larger) | — | 27.5 / 38.5 | 32.0 / 43.0 | 31.5 / 40.0 | 37.5 / 40.5 | 47.5 / 45.0 | shatter:thin | 63.5 / 71.0 · 65.5 / 76.0 |
| Exam island 7 final (CEM) | exam holdout 38.5 | **46.5** | 46.5 | — | — | — | — | — |
| Exam islands 6 / 8 final (CEM) | exam holdout 26.0 / 23.5 | 35.0 / 28.0 | 39.5 / 29.0 | — | — | — | — | — |

A 200-seed rate has a 95% interval of about ±7 pp (846 at 280: 38.3–51.9%). Replaying 846 from its JSON dictionary gives identical rows to regenerating it from the sampler (800 of 800 V5 rows; validation).

- **Does 846 hold ≥45% at V5? Yes, exactly at the bar:** 90/200 at 280 HP (VERIFIED). Its layer-1 62.5% was a high draw. Its V5 winners end in shatter:fat (62 of 90) or attrition:fat (23).
- **Did CEM reach the frontier?** In the shatter lane, yes: exam island 7's final policy (46.5%) matches 846 on identical seeds (VERIFIED). 846 is a narrow peak rather than a plateau: every perturbation and every neighbour is lower (VERIFIED). At 280 HP, no fork-leaning policy measured here reaches 45% at V5 (VERIFIED for these nine policies). With P1 + 260, perturbation p1 (modal attrition:fat) reaches 46.5%. So V5 ceilings are content-limited in the shatter lane; fork-lane V5 ceilings may be a few points optimiser-limited (row 7, INFERRED).
- **C3 risk (INFERRED).** A stayed shatter island near 46% sets the V5 grid best, so every other stayed island must reach about 31%. That is roughly the exam floor (31.6%), and exam fork islands replay at 28–35%.
**What R260 and P1 do to fixed policies.** Paired: same policy and seed, 9 policies × 200 seeds; ± is one standard error (VERIFIED).

| Vow | 280 → 260 | P1 → P1 + 260 | 280 → P1 | 280 → P1 + 260 |
|---|---|---|---|---|
| V0 | +2.4 pp (±0.9) | +1.9 pp (±0.8) | +3.3 pp (±1.1) | +5.3 pp (±1.1) |
| V5 | **+3.2 pp** (±0.8) | **+4.0 pp** (±0.8) | +1.1 pp (±1.0) | +5.1 pp (±1.1) |

R260 lifts V5 fixed-policy wins by 3–4 pp for strong policies; P1 alone lifts them by about 1 pp. A fixed-policy lift is not a CEM ceiling; §3.2 measures that.

### 3.2 Full-scale layer-2 rehearsal (A vs B)

Setup (VERIFIED):
- **CEM:** the shipped `tools/balance_cem.gd` at exam defaults (popSize 60, elite 15, maxGen 20, seedCount 40), with six islands per grid.
- **Seeds:** all development. Training 14000–14799, holdout 13000–13199, sampler root 7421, CEM root 7422 (the same for both variants).
- **Islands:** the shipped `select_islands` rule, run on each variant's dev layer 1 (root 7421, policies 0–299 × seeds 12000–12015; exam-1 cuts 20/29; each variant's own Dusk medians, shatter 0.875).
- **Floors:** (dev layer-1 top + dev arm 2) / 2.
- **Judge:** the shipped `tools/balance_cem_report.py`.

The representatives are again 100% on 1–8 in-cell runs.

| Grid | Floor (top · arm 2) | Stays at or above the floor: distinct cells | Grid best | Mean holdout | C3 | C4 |
|---|---|---|---:|---:|---|---|
| A V0 | 50.5 (69.2 · 31.9) | **1**: attrition:fat | 79.0 | 69.5 | MISS | PASS |
| A V5 | 34.6 (57.7 · 11.5) | **1**: attrition:fat | 49.0 | 38.1 | MISS | PASS |
| B V0 | 50.5 (69.4 · 31.5) | **2**: shatter:fat, attrition:fat; 0 within 15 pp of best | 82.5 | 68.2 | MISS | PASS |
| B V5 | 33.8 (56.7 · 10.9) | **1**: shatter:fat | 42.0 | 32.6 | MISS | PASS |

Per island, start cell → end cell · holdout % (island number):

| Vow | Start cell | A: P1 + R260 | B: P1 |
|---|---|---|---|
| V0 | smolder:fat | → attrition:fat · 47.0 (1) | → attrition:fat · 67.0 (0) |
| V0 | shatter:fat | → attrition:fat · 69.5 (0) | **stays** · 55.5 (1) |
| V0 | attrition:fat | **stays** · 77.0 (2) | **stays** · 57.0 (2) |
| V0 | smolder:mid | → shatter:fat · 70.0 (4) | → shatter:fat · 69.0 (3) |
| V0 | shatter:mid | → attrition:fat · 79.0 (3) | → attrition:fat · 82.5 (4) |
| V0 | attrition:mid | → shatter:mid · 74.5 (5) | → shatter:mid · 78.0 (5) |
| V5 | smolder:fat | → shatter:fat · 47.0 (6) | → shatter:thin · 37.0 (7) |
| V5 | shatter:fat | → shatter:thin · 32.0 (8) | **stays** · 36.0 (8) |
| V5 | attrition:fat | **stays** · 36.5 (7) | → attrition:mid · 22.0 (6) |
| V5 | smolder:mid | → shatter:thin · 22.5 (9) | → shatter:thin · 17.0 (9) |
| V5 | shatter:mid | → shatter:fat · 49.0 (10) | → shatter:fat · 41.5 (10) |
| V5 | attrition:mid | → shatter:fat · 41.5 (11) | → shatter:fat · 42.0 (11) |

- **Neither variant shows three distinct V0 stays** (VERIFIED). A keeps one cell. B keeps two, at 55.5% and 57.0%, but both are more than 15 pp below B's own best island (82.5%, a shatter:mid island that drifted to attrition:fat). So B would miss C3 on closeness as well as on count.
- **The smolder lane never holds.** All eight smolder islands drift: fat and mid, both vows, both variants. So did all 16 V0 smolder:fat islands at probe scale (VERIFIED). A third V0 cell would need a smolder island or a mid island, and the mid islands drift to attrition:fat, shatter:fat or shatter:mid.
- **No credible V5 path.** Each variant keeps one V5 cell. R260 does raise V5 ceilings: A's V5 islands average 38.1% (best 49.0%), B's 32.6% (best 42.0%) (VERIFIED at six islands each, with different representatives). That fits the 3–4 pp fixed-policy lift in §3.1 (INFERRED), but it does not add a stay.
- **Robust to the reading rules** (VERIFIED). Taking end cells from wins only, or using #557's cuts 21/30, adds no V0 stay in either variant. Under 21/30, B's only V5 stay (island 8) becomes shatter:thin.
- **Against exam 1** (V0 1 stay, V5 0), the rehearsal moves each count by at most one. On this evidence either variant would give a third C3 miss (INFERRED).

**Phase A range.** The dev arm 2 is taken from the dev gate (800 seeds per vow). The offsets are every known dev-to-Phase-A offset on the same exam seeds: V0 +1.6 pp (base 30.4 → 32.0) and +3.1 pp (`85deaec` 34.4 → 37.5); V5 +0.4 pp and −1.5 pp. The bracketed V5 figure applies the worst V0 offset (+3.1).

| Variant | V0 dev arm 2 | V0 Phase A estimate | Against 35.0% | V5 dev arm 2 | V5 Phase A estimate | Against 20.0% |
|---|---:|---|---|---:|---|---|
| A: P1 + R260 | 31.9 | 33.5–35.0 | at the ceiling on the `85deaec` offset | 11.5 | 10.0–11.9 (14.6) | clear |
| B: P1 | 31.5 | 33.1–34.6 | 0.4 pp under on the `85deaec` offset | 10.9 | 9.4–11.3 (14.0) | clear |

A single 200-seed Phase A draw varies by about ±6.6 pp at V0 (INFERRED), so either variant could miss Phase A as well.

## 4. Candidates priced (probe scale, revision 1)

- **Dev gate:** as in lock §5. Root 7421, policies 0–299 × seeds 12000–12015; arm 2 on 800 seeds per vow; cuts 21/30; each variant's own median; paired against `e0388dfa` twins.
- **Mini-CEM:** the three fat-cell islands × two RNG replicates per vow, so each fat cell has 2 replicate islands. "Stay" means the end cell equals the start cell and the holdout is at or above the dev floor ((top + arm 2) / 2). The number in brackets counts the distinct cells among those stays, which is what C3 counts. Stays below the floor are noted separately.

| Variant | Change | V0: top three · arm 2 · gap | V5: top three · arm 2 · gap | V0 replicate stays (distinct cells) | V5 replicate stays (distinct cells) | V5 mean holdout |
|---|---|---|---|---|---|---:|
| base | — | 72.4 · 68.1 · 64.4 · 30.4 · 42.0 | 60.6 · 56.7 · 56.6 · 11.1 · 49.5 | 2 (2) of 6 | 0 of 6 (1 below floor) | 0.15 |
| A: P1 + R260 | Crown of Cinders Ashwarden-only; Rootheart 260 | 71.1 · 69.8 · 67.2 · 31.9 · 39.2 | 59.0 · 57.7 · 54.5 · 11.5 · 47.5 | 4 (2) of 6 | 1 (1) of 6 | 0.24 |
| B: P1 | Crown of Cinders Ashwarden-only | 71.7 · 69.8 · 63.6 · 31.5 · 40.2 | 60.5 · 57.8 · 54.2 · 10.9 · 49.6 | 3 (2) of 6 | 0 of 6 (4 below floor, 2 cells) | 0.24 |
| R240 | knob 1 reverted | 70.7 · 68.4 · 64.8 · 34.4 · 36.3 | 56.5 · 51.5 · 50.9 · 14.5 · 42.0 | 1 (1) of 6 | 2 (2) of 6 (3 counting below floor) | 0.28 |
| P | P1 + Crown of the Hearth Ashwarden-only | 73.3 · 67.8 · 67.6 · **37.1** · 36.2 | 62.2 · 61.2 · 53.5 · 12.1 · 50.0 | 0 of 6 | 1 (1) of 6 | 0.19 |
| H20 | Hollow Crown −20 max HP | 70.2 · 63.4 · 63.0 · 28.1 · 42.1 | 55.9 · 52.8 · 52.4 · 10.2 · 45.7 | 1 (1) of 6 | 0 of 6 | 0.10 |
| HX | Hollow Crown Ashwarden-only | 67.1 · 58.4 · **54.7** (C1a: 2 cells) | 58.2 · 56.2 · **45.1** (C1a: 2 cells) | — | — | — |
| P1 + C26 / CF | crown full at 26 cards / flat 3 + 3 | arm 2 33.8 / 35.8; gap 38.6 / 37.1 | PASS / PASS | smolder islands 0/2 / 0/2 | — | — |

Dev gate only (no mini-CEM); these were priced in revision 1 but left out of its table:

| Variant | Change | V0: top three · arm 2 · gap · verdict | V5: top three · arm 2 · gap · verdict |
|---|---|---|---|
| HXR260 | HX + Rootheart 260 | 63.6 · 58.3 · 55.7 · 27.8 · 35.8 · PASS | 56.5 · 55.9 · 46.8 · 9.5 · 47.0 · PASS (shatter 9.7 pp behind) |
| HXR240 | HX + Rootheart 240 | 64.0 · 61.0 · 55.0 · 28.1 · 35.9 · PASS | 56.0 · 55.3 · 43.0 · 10.4 · 45.6 · FAIL (C1a: 2 cells) |
| PR260 | P + Rootheart 260 | 70.1 · 69.6 · 68.7 · **38.4** · 31.7 · FAIL (gap) | 62.7 · 60.4 · 54.1 · 13.8 · 48.9 · PASS |
| PR240 | P + Rootheart 240 | 72.8 · 69.9 · 69.1 · **36.8** · 36.1 · PASS | 59.9 · 58.3 · 53.7 · 15.1 · 44.8 · PASS |
| P1R260C26 | A + crown full at 26 cards | 71.1 · 70.4 · 67.4 · **34.2** · 36.8 · PASS | 57.9 · 57.4 · 54.6 · 11.5 · 46.4 · PASS |
| P1R260CF | A + flat crown 3 + 3 | 71.0 · 70.8 · 67.5 · **36.4** · 34.6 · FAIL (gap) | 58.2 · 54.6 · 54.6 · 12.6 · 45.6 · PASS |

**What the tables show (probe scale):**
- **P1 is the only single change that raised fork-lane retention without costing C1 or C2** (VERIFIED at probe scale). Each fork's act-1 offer rises from 3/6 to 3/5, and the chance of seeing at least one fork from 80% to 90% (INFERRED arithmetic). Ashwarden's pool is unchanged, because the aspect filter keeps untagged and matching relics (`domain/rules/rewards.gd:71` (in relic_pool)).
- **P over-corrects.** With both Ember crowns gone, all six V0 islands end in a fork cell, none in its own. Arm 2 also rises 6.7 pp, because random builds now see Hollow Crown more often. Their Hollow-first runs win 61% on base and 73% under P. PR240, PR260 and P1R260CF put arm 2 at or above 36.4%, and P1R260C26 at 34.2%. On the exam offsets (§3.2), all four carry a high Phase A risk.
- **Hollow Crown levers fail.** A heavier penalty does not change CEM's ranking: under H20, Hollow Crown is still the top-weighted boss relic in 6 of 12 islands. Removing the relic for Dusk (HX) costs the shatter lane C1a at 280 HP. With R260 it passes the dev gate at both vows, but narrowly (V0 gap 35.8 pp; V5 shatter:fat 9.7 pp behind the top).
- **Rootheart relief is the V5 lever with fixed-policy evidence.** It adds 3–4 pp at V5 (§3.1). The probe-scale mini-CEM could not separate A from B at V5: B also lifted the mean V5 holdout from 0.15 to 0.24 (raw 0.237 against A's 0.242). At full scale (§3.2), A's V5 islands average 38.1% against B's 32.6%, but A still keeps only one V5 cell. R240 nearly doubles the V5 mean holdout, but exam Phase A at 240 HP was 37.5%, above the lock's 35.0% ceiling.
- **Relaxing the crown** costs 2–4 pp of arm 2 and still leaves V0 smolder:fat islands drifting.

## 5. Decision, risks and what an exam would have to confirm

**Decision: stop. No variant qualifies under the owner rule, and C3 is not loosened** (VERIFIED against §3.2). Revision 1 proposed candidate A: `"aspect": "ashwarden"` on `relics.crownOfCinders` and `enemies.rootheart.hp` = `[260, 260]` in `content/full-content.json`; B is the first field alone. That recommendation is withdrawn. No content change, exam or rules change is proposed.

What the evidence leaves for any future lane (INFERRED; not a proposal):
- **V0:** the blocker is the smolder lane. No smolder island has held at full or probe scale. Hollow Crown still out-competes the forks for tuned play (§2, rows 4–6).
- **V5:** Rootheart relief is the only lever with evidence. It gives +3–4 pp at fixed policy and +5.5 pp on the mean CEM holdout, but it creates no stays. Its Phase A cost sits at the V0 ceiling.
- **Rules:** the rules options in §2 stay described only.

If the owner nevertheless examined a variant, the exam would have to confirm:
- C3 at both vows with the exam's own representatives;
- Phase A Dusk V0 at or below 35.0% and V5 at or below 20.0%;
- C1a/C1b with the new shatter median (0.875 at dev, against 0.889);
- C4 and the V5 ceiling.

The rehearsal predicts a C3 miss at both vows (INFERRED). A Phase A miss would leave no knob, so the lane would stop again.

**Risks for any variant:**
- **Phase A.** Two dev-to-Phase-A offsets have been measured on the same exam seeds: +1.6 pp on base (30.4 → 32.0) and +3.1 pp on `85deaec` (34.4 → 37.5). At V5 they were +0.4 and −1.5. A 200-seed draw varies by about ±6.6 pp. Knob 1, the lever that fixed Phase A last time, is spent. If a variant misses Phase A, the lock gives no knob, so the lane stops and the owner decides.
- **Ashwarden.** The Rootheart is Ash's act-1 boss too, so 260 returns part of what knob 1 took from Ash's arm 1 (A only). Ash's relic pool is unchanged.
- **Dusk loses a boss option.** Crown of Cinders is Dusk's weakest first pick in layer 1: 35.4% at V0 and 19.6% at V5.
- **Saves still load.** Held relics are checked only by ID (`domain/state/run_state.gd:265` (in from_save_dict)), so a Dusk save that holds Crown of Cinders loads (VERIFIED read).
- **Tests and fixtures (UNKNOWN; not checked).** Any content change must update the live content pins, `tests/test_balance_catalogue.gd:4` (LIVE_FILE) and `tests/test_balance_catalogue.gd:5` (LIVE_SEMANTIC). Dusk boss offers would draw from five relics, so seeded Dusk runs diverge after the first boss. `tests/test_balance_sim.gd` digests and any Dusk golden that passes a boss may then need an explicit update.

## 6. Reproduction

**Host and wall time.** Linux x86_64 VM, 8 vCPU, Godot `4.7.2.stable.official`. Every process ran at `nice -n 10`, at most 6 at once, on 2026-09-28. Revision 1 used about 69 minutes of probe wall time; revision 2 used about 2 h 20 min: the 846 replay 3.7 min, the rehearsal 2 h 16 min for 24 islands, and a layer-1 scan of the exam rows in Python.

**Seeds.** No exam seeds (3000–5399) and no `--stage=exam` anywhere.
- Dev gate and rehearsal layer 1: lock §5 seeds (policy runs 12000–12015, arm 2 12100–12899).
- Oracle replay and 846 replay: 13000–13199.
- Mini-CEM: training 14000–14159, holdout 13000–13099, sampler root 7421, CEM root 7422.
- Rehearsal CEM: training 14000–14799 (20 generations × 40 seeds), holdout 13000–13199, sampler root 7421, CEM root 7422.

**Runners** (untracked and deleted afterwards; this prose is the only record):
- `tools/_probe421.gd`: the lane-3 dev-gate runner (lane-3 probe notes §1). It writes Dusk rows only, for policies from sampler root 7421 at vows 0 and 5, and arm-2 controls.
- A roughly 40-line replay script. It runs fixed policies through `BalanceSim.simulate` on given seeds with `--content`, and refuses the exam band. Each item is either a policy dictionary or a sampler (root, index) pair.
  - **Oracle replay (revision 1):** each exam-1 island's final `policy` (from its layer-2 `final` row), as-is and "forced". Forced sets `relics.<start-lane relic>` to 1000 (Unbroken Crown for smolder, Tithes for attrition, Shatterer's Crown for shatter), so the relic tops every boss offer where it appears.
  - **846 replay (revision 2):** policies 846, 1132, 1822, 342 and 569 regenerated from sampler root 215; 846's perturbations are dictionaries built from its exam layer-1 `policy`.
- The mini-CEM is the shipped `tools/balance_cem.gd`, run with `--popSize=30 --elite=8 --maxGen=8 --seedCount=20 --trainSeed0=14000 --holdoutSeed0=13000 --holdoutCount=100 --samplerRoot=7421 --rootSeed=7422 --content=<variant>`.
- The rehearsal is the shipped `tools/balance_cem.gd` at its defaults (popSize 60, elite 15, maxGen 20, seedCount 40), with `--trainSeed0=14000 --holdoutSeed0=13000 --holdoutCount=200 --samplerRoot=7421 --rootSeed=7422 --content=<variant>`. Islands 0–5 are V0 and 6–11 are V5, per variant. It was judged by the shipped `tools/balance_cem_report.py` against a dev layer-1 analysis.

**Representatives.**
- Mini-CEM: the exam rule applied to each variant's own dev rows, fat cells only, cuts 20/29.
- Rehearsal: the shipped `select_islands` (`tools/balance_exam.py:85` (select_islands)) applied to each variant's dev-gate rows (root 7421, policies 0–299, seeds 12000–12015, Dusk only). It used cuts 20/29 (exam 1), each variant's own Dusk medians, and arm 2 from the dev gate.

**Variants.** Content copies with only the listed fields changed. A is P1R260 and B is P1. Each was checked by a semantic JSON diff against `582e2f7` content.

**Data.** [`data/dusk-lane3-c3-probes.json`](data/dusk-lane3-c3-probes.json) holds the variant SHA-256s, dev-gate cells, per-island results, representatives, oracle replays and the exam-island anatomy. Revision 2 adds `probe846` and `rehearsal`.
