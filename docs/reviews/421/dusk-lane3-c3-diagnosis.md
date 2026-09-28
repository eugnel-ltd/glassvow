# Dusk lane 3 — C3 diagnosis and fix design (#421)

Owner: Ash (PM). Author: Claude (diagnosis and design only; no game code or content changed). Base: draft #568 head `3c5144e` (content = `582e2f7`, Rootheart 280). Inputs: the [exam 1 readout](../../balance/2026-09-28-421-dusk-lane3-exam.md) and its raw rows (read-only, outside Git), the #557 exam 1 rows for comparison, and fresh development probes (§5).
Tags: VERIFIED = measured on exam rows or probes, or read in code; INFERRED = reasoned from verified data; UNKNOWN = needs an exam. The probes are reduced in scale and only show direction; they are not acceptance evidence.

## 1. Answer

**Mostly an honest game signal.** Several tool properties add noise, but they do not explain the direction. Two content causes produce the miss:
- **At V5, the act-1 wall.** At 280 HP the Rootheart kills about half of optimised V5 runs before any boss relic is offered.
- **At V0, no fork is a competitive first boss relic for optimised play.** Hollow Crown is the best pick and is lane-neutral. The fullness rule made the Unbroken Crown the worst pick. Each fork appears in only half of the act-1 boss offers.

So CEM keeps chipping, and its islands leave the fork cells. The representative rule, argmax fitness, the modal-over-all-rows end cell and relic-blind drafting decide which cell each island lands in. A reading that removes those effects still misses C3 (§2, row 8).

**Recommended fix (§3):** make Crown of Cinders Ashwarden-only and lower the Rootheart from 280 to 260. It is two content fields. It keeps C1/C2 at dev and lifts V0 fork-lane retention. It does not demonstrate three viable V5 stays at probe scale, so C3 at V5 stays UNKNOWN.

## 2. Diagnosis

| # | Finding | Evidence | Tag |
|---|---|---|---|
| 1 | V5 ceilings come from the act-1 wall. | Exam V5 islands lose 42–54% of holdout runs to the Rootheart; at 240 HP (#557) it was 13–41%. Pooled, 49.2% of V5 holdout runs beat it (#557: 74.2%), and 51.1% of those win (#557: 67.3%). Layer-1 Rootheart deaths at V5: 57.7% (#557: 48.5%). | VERIFIED |
| 2 | 45–52% is not a CEM target. | A layer-1 cell rate is conditional on ending in that cell, so fat cells hold survivors. A CEM ceiling is a whole-policy win rate. The best layer-1 V5 policies win 40, 40, 37.5 and 35% over 40 seeds (plus one outlier at 62.5%). CEM's 38.5% is already at the policy frontier. | VERIFIED numbers; INFERRED reading |
| 3 | V5 end cells record where islands die. | About half of the V5 holdout rows are thin-deck act-1 deaths, so the modal row (`tools/balance_cem_report.py:33`) is a thin cell even when the winners stay. Island 8's wins are modal attrition:fat (27 of 47), but its rows are modal shatter:thin (42 of 200). | VERIFIED |
| 4 | At V0 the optimiser rationally leaves the forks. | Pooled exam holdout, act-1 survivors, win rate by first boss relic: Hollow Crown 84% (n 511), Tithes 70% (43), other crowns 66–69%, Unbroken Crown 50% (70). In #557 the crown was 83% (133). Hollow Crown ranks first in 10 of 12 final policies. | VERIFIED |
| 5 | Fullness is what sank the crown for tuned play. | Optimised decks are lean. Island 0 holds the crown in 60% of its runs, yet 72 of its 200 rows end in smolder:mid (29 or fewer cards), where the crown pays only 2 + 2. | VERIFIED rows; INFERRED cause |
| 6 | Offer arithmetic caps any fork island. | A fork appears in 3 of 6 boss offers. Forcing the start-lane relic to the top of the exam's own final policies (200 dev seeds) makes it the first boss pick in only 42–47% of V0 runs and 26–32% of V5 runs. | VERIFIED |
| 7 | Tool properties add noise. | **Representatives:** the rule (`tools/balance_exam.py:115` (in select_islands)) takes the best in-cell rate. All 12 exam representatives are 100% on 1–5 in-cell runs. They place only 1–5 of their 40 layer-1 runs in the start cell, and the V5 ones win 2.5–10% overall. Policy 63 represents two V5 cells. On dev rows the same rule picks policy indices 0–10.<br>**Fitness:** the returned policy is the single best candidate on 40 fresh seeds (`tools/balance_cem.gd:100` (in _initialize), `tools/balance_cem.gd:109` (in _initialize)). Best-train fitness is 0.73–0.93 at V0 (holdout 0.54–0.71) and 0.33–0.65 at V5 (holdout 0.18–0.39). The stall rule reads the monotone best-ever (`tools/balance_cem.gd:120` (in _initialize)). Final sigma is 0.13–0.21, well above the 0.02 floor.<br>**Holdout draw:** island 2's exact policy ties attrition:fat and shatter:fat at 64 rows each on 200 dev seeds; on the exam seeds it was 44 against 82.<br>**Grammar:** card and relic scores ignore the relics held (`tools/balance_pilot.gd:330` (in card_score), `tools/balance_pilot.gd:337` (in card_score)). Fork holders still carry 3.2–3.6 chip cards per deck, against 3.8 for others. `cardDecline` is one global threshold. | VERIFIED existence; INFERRED as noise, not direction |
| 8 | Not a rules artefact alone. | Reading end cells from wins only would give V0 1 and V5 2 (islands 8 and 10, 23.5% and 21.0%). Both are below the V5 floor of 31.61%, so C3 would still miss. | VERIFIED |

Rules changes James could weigh: a representative with a minimum number of in-cell runs, end cells taken from wins, or holdout run on the CEM mean. They are described here only. This note does not recommend them.

## 3. Candidates priced

- **Dev gate:** as in lock §5. Root 7421, policies 0–299 × seeds 12000–12015; arm 2 on 800 seeds per vow; cuts 21/30; each variant's own median; paired against `e0388dfa` twins.
- **Mini-CEM:** the three fat-cell islands × two RNG replicates per vow. "Stay" means the end cell equals the start cell and the holdout is at or above the dev floor ((top + arm 2) / 2). The number in brackets counts stays below the floor too.

| Variant | Change | V0: top three · arm 2 · gap | V5: top three · arm 2 · gap | V0 stays | V5 stays | V5 mean holdout |
|---|---|---|---|---|---|---:|
| base | — | 72.4 · 68.1 · 64.4 · 30.4 · 42.0 | 60.6 · 56.7 · 56.6 · 11.1 · 49.5 | 2 (2) | 0 (1) | 0.15 |
| **A: P1 + R260** | Crown of Cinders Ashwarden-only; Rootheart 260 | **71.1 · 69.8 · 67.2 · 31.9 · 39.2** | **59.0 · 57.7 · 54.5 · 11.5 · 47.5** | **4 (4)** | **1 (1)** | **0.24** |
| B: P1 | Crown of Cinders Ashwarden-only | 71.7 · 69.8 · 63.6 · 31.5 · 40.2 | 60.5 · 57.8 · 54.2 · 10.9 · 49.6 | 3 (3) | 0 (4) | 0.24 |
| R240 | knob 1 reverted | 70.7 · 68.4 · 64.8 · 34.4 · 36.3 | 56.5 · 51.5 · 50.9 · 14.5 · 42.0 | 1 (1) | 2 (3) | 0.28 |
| P | P1 + Crown of the Hearth Ashwarden-only | 73.3 · 67.8 · 67.6 · **37.1** · 36.2 | 62.2 · 61.2 · 53.5 · 12.1 · 50.0 | 0 (0) | 1 (1) | 0.19 |
| H20 | Hollow Crown −20 max HP | 70.2 · 63.4 · 63.0 · 28.1 · 42.1 | 55.9 · 52.8 · 52.4 · 10.2 · 45.7 | 1 (1) | 0 (0) | 0.10 |
| HX | Hollow Crown Ashwarden-only | 67.1 · 58.4 · **54.7** (C1a: 2 cells) | 58.2 · 56.2 · **45.1** (C1a: 2 cells) | — | — | — |
| P1 + C26 / CF | crown full at 26 cards / flat 3 + 3 | arm 2 33.8 / 35.8; gap 38.6 / 37.1 | PASS / PASS | smolder islands 0/2 / 0/2 | — | — |

**What the table shows:**
- **P1 is the only single change that raised fork-lane retention without costing C1 or C2** (VERIFIED at probe scale). Each fork's act-1 offer rises from 3/6 to 3/5, and the chance of seeing at least one fork from 80% to 90% (INFERRED arithmetic). Ashwarden's pool is unchanged, because the aspect filter keeps untagged and matching relics (`domain/rules/rewards.gd:71` (in relic_pool)).
- **P over-corrects.** With both Ember crowns gone, all six V0 islands end in a fork cell, none in its own. Arm 2 also rises 6.7 pp, because random builds now see Hollow Crown more often. Their Hollow-first runs win 61% on base and 73% under P.
- **Hollow Crown levers fail.** A heavier penalty does not change CEM's ranking: under H20, Hollow Crown is still the top-weighted boss relic in 6 of 12 islands. Removing the relic for Dusk removes the shatter lane.
- **Rootheart relief is the only V5 lever with evidence.** R240 nearly doubles the V5 mean holdout, but exam Phase A at 240 HP was 37.5%, above the lock's 35.0% ceiling. R260 is the C2-safe half step.
- **Relaxing the crown** costs 2–4 pp of arm 2 and still leaves V0 smolder:fat islands drifting.

## 4. Recommendation, risks and what an exam must confirm

**Candidate A** changes `content/full-content.json` only. No code, ID, save or locale change.
- Add `"aspect": "ashwarden"` to `relics.crownOfCinders`.
- Set `enemies.rootheart.hp` to `[260, 260]`.

Probe price:
- **Dev gate: PASS at both vows.** Paired holders: Tithes +5.6 / +6.3 pp, crown +3.8 / +2.7 pp.
- **Mini-CEM:** V0 4/6 islands stay viable (shatter:fat 0.70, 0.70; attrition:fat 0.56, 0.60). V5 1/6 (smolder:fat 0.37).
- **Fallback B:** P1 alone, if the owner wants to keep Rootheart at 280.

**Not fixed (VERIFIED in probes):**
- V0 smolder:fat islands drift in every variant (0/16).
- V5 ceilings sit near the floor.

In an exam, V0 can probably count on shatter:fat and attrition:fat staying. A third stay needs the smolder:fat island or a mid island, which no probe showed (INFERRED). V5 C3 is UNKNOWN. If C3 misses again, the next lever is crown strength against C2 arm 2 (CF: +4.3 pp).

**Risks:**
- **Phase A.** Dev arm 2 is 31.9% against 30.4% on base. On base, exam Phase A came out 1.6 pp above dev, which suggests about 33.5% here against the 35.0% ceiling. A 200-seed draw varies by ±6.6 pp (INFERRED).
- **Ashwarden.** The Rootheart is Ash's act-1 boss too, so 260 returns part of what knob 1 took from Ash's arm 1. Ash's relic pool is unchanged.
- **Dusk loses a boss option.** Crown of Cinders is Dusk's weakest first pick in layer 1: 35.4% at V0 and 19.6% at V5.
- **Saves still load.** Held relics are checked only by ID (`domain/state/run_state.gd:265` (in from_save_dict)), so a Dusk save that holds Crown of Cinders loads (VERIFIED read).
- **Tests and fixtures.** Dusk boss offers now draw from five relics, so seeded Dusk runs diverge after the first boss. `tests/test_balance_sim.gd` digests and any Dusk golden that passes a boss need an explicit update (INFERRED; not checked).
- **Probe scale.** The mini-CEM uses 30 policies, 8 generations, 20 seeds, 100 holdout seeds and dev representatives. At V5 its ceilings run at about 0.6× the exam's (base 0.15 against 0.25). With six islands per grid, a stay count is ±1.2.

**An exam must confirm:**
- C3 at both vows, with the exam's own representatives, including whether V5 stayed islands clear the floor;
- Phase A Dusk V0 at or below 35.0% and V5 at or below 20.0%;
- C1a/C1b with the new shatter median (0.875 at dev, against 0.889);
- C4 and the V5 ceiling.

## 5. Reproduction

**Host and wall time.** Linux x86_64 VM, 8 vCPU, Godot `4.7.2.stable.official`. Every process ran at `nice -n 10`, at most 6 at once, 2026-09-28, about 69 minutes of probe wall time.

**Seeds.** No exam seeds (3000–5399) and no `--stage=exam`.
- Dev gate: lock §5 seeds.
- Oracle replay: 13000–13199.
- Mini-CEM: training 14000–14159, holdout 13000–13099, sampler root 7421, CEM root 7422.

**Runners** (untracked and deleted afterwards):
- `tools/_probe421.gd`: the lane-3 dev-gate runner (lane-3 probe notes §1).
- A roughly 40-line replay script: runs fixed policies through `BalanceSim.simulate` on given seeds with `--content`, and refuses the exam band.
- The mini-CEM is the shipped `tools/balance_cem.gd`, run with `--popSize=30 --elite=8 --maxGen=8 --seedCount=20 --trainSeed0=14000 --holdoutSeed0=13000 --holdoutCount=100 --samplerRoot=7421 --rootSeed=7422 --content=<variant>`.

**Representatives.** The exam rule applied to each variant's own dev rows, fat cells only, with cuts 20/29.

**Variants.** Content copies with only the listed fields changed.

**Data.** Variant SHA-256s, dev-gate cells, per-island results, representatives, oracle replays and the exam-island anatomy are in [`data/dusk-lane3-c3-probes.json`](data/dusk-lane3-c3-probes.json).
