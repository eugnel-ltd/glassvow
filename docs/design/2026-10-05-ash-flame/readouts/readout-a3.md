# Readout A3: Endure's second wall lane, Thirsting Shard becomes clear glass

> **A wall lane's reading of record (AI-SDLC discovery), not a verdict.** #544 A8, Endure's second and last lane: the V5 diagnosis, three candidates screened on development seeds, and the one the orchestrator sent on, E5, read on the bands of record against [Ash readout A2](readout-a2.md) under a ship rule registered before any of its data. E5 ships in this PR: `leechBlade` (Thirsting Shard) leaves the Endure way's affinity and is clear glass for the Ashwarden; it stays in the pool. `content/full-content.json` becomes `3eea14297900c7f240fa0be9108279e7dc859b1cb29788e7a3cfc54d5b55aaf5` (semantic `0aff175e300170675c3b76ad7ee0503360a514e065e8630d55f994f07857c88f`).
>
> **Head and content.** Every reading report ran at `3e734010` from a detached run worktree with `--content` set to E5's catalogue, `3eea1429…`. The committed file is byte-identical to it, so no equivalence slice is needed. Between `3e734010` and this PR's base `1161c30b`, `git diff --stat -- content domain tools` is empty. The rows therefore describe the content this PR commits.

Ash readout A2 shipped E1 (Vitrify excluded) and left Endure leading at V5 by a decided +39.2 pp (`entry`) and +25.5 pp (`full`) over the next way, while level at V0 (+3.8 / +4.2). Lock §14 allows each way two wall lanes; this is Endure's second.

## The answer in brief

- **E5 ships.** Every registered condition holds: Endure − next way **−9.6 pp** at V0 `entry` and **−2.0** at V0 `full`; at V5 **+22.3** and **+18.0** (A2 +39.2 and +25.5), C_endure decidedly down in both V5 cells; G7 PASS in every cell; the Duskblade byte-identical; Smolder at V0 `entry` **+12.2 pp**, decided better.
- **The V5 mechanism.** V5 is an attrition vow, and Endure is the one way that heals. It meets the Act 2 and Act 3 bosses at 89–95% HP; the others arrive at 66–75%. Crown of the Hearth is the largest source, and it is out of a wall lane's reach.
- **G2 at V0 `full` passes on point and on interval** (4.8 pp, PASS / PASS): the first G2 cell to pass on interval.
- **Costs and reservations.** The V5 remainder (+22.3 / +18.0), chiefly the Hearth, is a reservation and a question for A5c. G6 at V0 `entry` worsens (Hand 80.8% of A_lit's wins), A2's reservation for A5a. Endure's expression (B2) and its full-pool reach (G5) fall at V0. V0 `entry` sits near the line (−9.6, paired interval to −12.8).
- **Endure's wall lanes are closed** (lock §12, §14).

## The question

Under the frozen instrument and on A2's bands: does taking Thirsting Shard out of Endure's colour cut Endure's V5 lead over the next way, by at least 10 pp in one V5 cell, while Endure stays within 10 pp of the next way at V0, without moving the Duskblade, breaking G7, or costing Smolder's entry pool more than 5 pp?

## The lane, Phase A (development seeds, not of record)

Every Phase A figure is on 12000–12399 (400 seeds an arm and cell), `p9`/`s3`, paired on seed against a new baseline on `main`'s E1 content (`base2`, `3e734010`, `abb82590…`), whose V0 rows reproduce lane 1's E1 screen exactly (3,200 of 3,200 rows identical).

| Cell | C_smolder | C_hand | C_endure | A_lit | Endure − next way |
|---|---|---|---|---|---|
| V0 entry | 30.8% | 83.0% | 84.8% | 49.0% | +1.8 |
| V0 full | 68.5% | 75.8% | 80.5% | 60.0% | +4.8 |
| V5 entry | 12.5% | 32.5% | 73.2% | 28.2% | +40.8 |
| V5 full | 34.5% | 35.8% | 63.0% | 36.0% | +27.3 |

### The V5 mechanism

From A2's own V5 rows and a telemetry probe on 12000–12199 (V5, four arms; 1,600 of 1,600 rows identical to `base2`'s once the telemetry is dropped):

- **Where the lead is made.** From V0 to V5, every way's Act 1 boss losses rise alike (`full`: Endure 6.5 → 18.5%, Hand 2.9 → 20.3%). At the Act 2 and Act 3 bosses, Endure's barely move (8.1 → 9.9% and 4.5 → 3.6% of meetings lost); the other ways' about triple (Hand at the Act 3 boss 13.6 → 35.7%).
- **HP on reaching the boss.** Endure meets the Act 2 and Act 3 bosses at 89–95% of its HP; Hand at 71–75%, Smolder at 66–73%. The runs that lose a boss went in at 42–54 HP. At the end of Act 2 Endure holds 61–62 HP, the others 28–32.
- **What heals Endure,** per run alive in Acts 2–3: at V5 `entry`, Crown of the Hearth's heal after won fights (3 HP for each Ember left) 164 HP and Thirsting Shard 61 HP, against Hand's 33 and 3; Cathedral Glass's Ward 420 (Hand 85). At V5 `full`, Hearthglow's heal each turn 121 HP, the Hearth 80, Thirsting Shard 33, Cathedral Glass's Ward 166. Endure's mitigation a turn is close to Hand's (78% of incoming blocked against 76%); the difference is healing.
- **Damage and kills.** Ashfall makes 50% / 39% of committed Endure's damage at V5 `entry` / `full` and the starter kit with it 85% / 73%; Endure's own glass 4–5%. Kill shares are within about 1 pp of the base in every screen.
- **The mechanism.** V5 is an attrition vow: campfires heal 20%, not 30%; enemy attacks deal +1; enemy HP +12%; a Hex from the start. Endure is the one way that heals between and within fights, so it meets the late bosses near full while the other ways arrive about 10 pp lower than at V0, and V5's bosses kill from there.
- **Out of reach.** Crown of the Hearth is the largest source, but it is a shared relic the Duskblade can meet (§11, rule 2), and its heal is keyed on its id. The lantern's lit cap (`flame.lantern.steadyCap`) bounds the bank it heals from, but a static estimate on the probe's fights moves only 4–9% of its heal, so no cap candidate was screened.

### The screens

Three candidates, each one lever against `main` on a research branch; the Duskblade's invariance panel passed at each candidate's commit (`460f8be2`, `a2add4b2`, `c6cd8522`). A candidate whose C_endure paired interval included 0 in both V5 cells would have skipped V0; none did.

| Candidate | Lever | Endure − next way (V0 entry / V0 full / V5 entry / V5 full) | What else | Ruling |
|---|---|---|---|---|
| base2 | | +1.8 / +4.8 / +40.8 / +27.3 | | |
| E4 | `aegis` (Cathedral Glass) leaves Endure's affinity; clear glass, still in the pool | −12.5 / −2.0 / +9.3 / +20.2 | C_smolder V0 entry +21.5; A_lit V0 entry +13.5 (decided); G6 Hand 91.2% at V0 entry, 78.8% at V5 entry | **Dropped**, part (b): Endure 12.5 pp below the next way at V0 `entry`. **A finding for A5a**: the ×0.5 off-colour weight on Cathedral Glass costs Smolder's entry pool |
| E5 | `leechBlade` (Thirsting Shard) leaves Endure's affinity; clear glass, still in the pool | −9.0 / −2.7 / +23.3 / +18.8 | C_smolder V0 entry +13.5 (decided); A_lit V0 full +1.0; G2 V0 full 2.7 PASS / PASS | **Read on the bands of record** |
| E6 | `regrowth` (Hearthglow) leaves Endure's affinity, `momentum` (Honing Edge) joins it (full-pool uncommons) | +1.8 / −8.0 / +40.8 / +8.2 | Entry cells identical to the base (both cards pool-gated); A_lit V0 full +5.0 (decided) | **Dropped**, part (a): the V5 `entry` lead does not move |

The recommendation rule, registered before any screen: (a) Endure − next way at V5 falls on point in both cells, by ≥ 10 pp in at least one, with C_endure decidedly down in at least one V5 cell; (b) Endure − next way at V0 stays within −10 to +10 pp on point in both cells; (c) Smolder at V0 `entry` is not decidedly worse by more than 5 pp; (d) the panel passes. Only E5 met all four.

The next section was copied verbatim from the orchestrator's ruling into the lane's draft at 22:21 BST on 12 October 2026; the reading's first batch started at 22:23:42. The ruling's heading gives 22:35, a nominal time: the file was written before 22:21. It is published unchanged.

## Pre-registration (the orchestrator, 12 October 2026; written before any result)

**The reading of record (Ash readout A3), registered now, before any of its data:**
- **Instrument:**
  - `--pilot p9 --search s3`, from `$L/run2` (detached at `3e734010`), with `--content` set to E5's catalogue (`cands2/E5-leech-clear.json`, `3eea1429…`).
  - The content PR commits that file's Ashwarden content. If the committed file is not byte-identical to the one read, rc-bar P9's equivalence slice and comparer are run, as A2 did (`e1b-slice`), and reported.
- **Bands:**
  - V0 on 13000–13999 and V5 on 13000–14999, cells `entry` and `full`, the six arms, `--replay`;
  - G3's V5 `full` band on 15000–16999 (C_smolder, C_hand, C_endure, A_lit), joined for 4,000 common seeds;
  - the Duskblade's A_lit at V0 `full` on 13000–13999.
- **Pairing:** every run pairs on seed with A2's rows (`$L/rows/e1-v0`, `e1-v5`, `e1-ext-v5`, `e1-dusk-v0`).
- **Never run:** 12000–12999 and 17000–18999.
- **Ship rule (all five must hold):**
  1. At V0, Endure − next way is between −10 and +10 pp on point, in both `entry` and `full`.
  2. At V5, Endure − next way is lower on point than A2's reading of record (+39.2 `entry`, +25.5 `full`) in both cells, and lower by at least 10 pp in at least one. C_endure's paired change against A2 must also be decided down (its paired 95% interval excludes 0) in at least one V5 cell.
  3. G7 passes in every cell: 0 stalls, 0 errors, and arm A's replay is identical.
  4. The Duskblade is byte-identical: the invariance panel passes at the candidate's commit and on the delivery's final tree, and its A_lit at V0 `full` matches A2's 1,000 rows.
  5. Smolder at V0 `entry` is not decidedly worse than A2 by more than 5 pp (A2's wording and reading).
- **Reported, not conditions:**
  - every graded gate (G2, G3, G5, G6, row B), and G1 and G4 as readings;
  - the Act 1 boss losses and the kill share by arm;
  - G6 at V0 `entry` (Hand 77.7% in the screen against 69.4%). It is carried as A2's reservation, tied to A5a.
- **The cross-class reading:** reported as §10 says. If it reads above +15 pp on point, or its interval does not exclude +15, the readout gives §10's diagnosis from the rows it already has.
- **The V5 remainder** (about +19 to +23 pp in the screen) is a reservation. The readout names its sources (chiefly the Hearth) and records it as a question for A5c. It is not a lever for this lane.
- **If the rule fails:** no content change ships, Endure's lanes are closed, and I rule on what the readout records.
- **Re-tune nothing after the run.**
- **Runs:** one batch at a time, `--jobs 4`, `nice -n 10`, behind the load (≤ 50) and disk (≥ 62 GB) guards, under `nohup caffeinate -i` with a driver log. Budget: about 7 hours.

## How it was run

```sh
# Isolation: override.cfg in every worktree, [application] config/use_custom_user_dir=true and
#   config/custom_user_dir_name="glassvow-ash-a8", never committed. Batches one at a time under
#   nohup caffeinate -i, nice -n 10, --jobs 4, behind a load (<= 50) and disk (>= 62 GB) guard.
git worktree add --detach <lane>/run2 3e734010; godot --headless --import
C=<lane>/cands2/E5-leech-clear.json          # sha 3eea1429...
python3 -B tools/balance_readout.py run a3-v0 --aspect ashwarden --seeds 13000-13999 --cells v0-entry,v0-full \
    --replay --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a3-v5 --aspect ashwarden --seeds 13000-14999 --cells v5-entry,v5-full \
    --replay --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a3-ext-v5 --aspect ashwarden --seeds 15000-16999 --cells v5-full \
    --arms C_smolder,C_hand,C_endure,A_lit --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a3-dusk-v0 --aspect duskblade --seeds 13000-13999 --cells v0-full \
    --arms A_lit --content $C --play search --pilot p9 --search s3 --jobs 4
# Grading, A2's commands, A2's rows (e1-*) as the reference:
python3 -B tools/balance_readout.py table --aspect ashwarden --content $C a3-v0 a3-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999 --ref e1-v0 e1-v5
python3 -B tools/balance_readout.py join a3-g3-4000 v5-full C_smolder,C_hand,C_endure,A_lit a3-v5 a3-ext-v5
python3 -B tools/balance_readout.py g3 --aspect ashwarden --content $C a3-g3-4000 v5-full
python3 -B tools/balance_readout.py paired --aspect ashwarden --content $C a3-v0 e1-v0 v0-entry,v0-full --arms A,R   # and V5
python3 -B tools/balance_readout.py compare a3-dusk-v0 e1-dusk-v0
python3 -B screen.py tools a3-v0 e1-v0 v0-entry v0-full    # scratch: paired arms, G2, Endure − next, G3, G6, kill share, Act 1 boss; and V5
python3 -B crossclass.py tools a3-v0/v0-full-A_lit.json a3-dusk-v0/v0-full-A_lit.json
# The Duskblade's invariance panel at the candidate's commit (a2add4b2), and on this PR's final tree:
godot --headless -s res://tests/run_all.gd -- --tests=res://tests/test_balance_invariance.gd
```

- **Cells, arms, seeds.** A2's: the Ashwarden at V0 on 13000–13999 and V5 on 13000–14999, pools `entry` and `full`, the six arms with arm A's three-seed replay; G3 at V5 `full` joined with 15000–16999 for 4,000 common seeds; the Duskblade's A_lit at V0 `full`. Every run pairs with A2's on its seed. Nothing read 12000–12999 or 17000–18999.
- **Measures.** A2's graders and intervals; the paired change is Newcombe's paired interval with the exact McNemar p.
- **Budget and stop rule.** One candidate, one reading, the ship rule above; nothing re-tuned after the run.
- **Wall time.** 31,713 s (8 h 49 min) for the four batches, 22:23 on 12 October to 09:33 on 13 October, 45,000 runs (V0 9,349 s; V5 13,671 s; G3's band 7,606 s; the Duskblade 1,087 s), load average 24 to 230 at the batches' ends on the shared host, with a disk wait between the V5 batch and G3's band. Phase A (baselines, probe, panels, six screens): 21,765 s.

## The reading of record

### The ship rule

| Condition | Result | Held |
|---|---|---|
| 1. At V0, Endure − next way between −10 and +10 pp on point, `entry` and `full` | −9.6 pp (paired −12.8 to −6.4); −2.0 pp (−5.8 to +1.8) | yes |
| 2. At V5, Endure − next way lower than A2's in both cells, by ≥ 10 pp in one; C_endure decidedly down in one V5 cell | +22.3 (A2 +39.2: −16.9); +18.0 (A2 +25.5: −7.5); C_endure −8.4 (−10.6 to −6.2) and −7.4 (−9.1 to −5.7) | yes |
| 3. G7 in every cell | 0 stalls, 0 errors in 44,000 Ashwarden and 1,000 Duskblade runs; arm A's replay identical in every cell | yes |
| 4. The Duskblade byte-identical | The panel PASS at the candidate's commit and on this PR's final tree; its A_lit at V0 `full` identical to A2's, 1,000 of 1,000 rows | yes |
| 5. Smolder at V0 `entry` not decidedly worse than A2 by more than 5 pp | +12.2 pp (+8.6 to +15.7), p 5.6 × 10⁻¹¹: decidedly better | yes |

**E5 ships** as A8's second and last Endure lane.

### Win rates (Wilson 95%), and the paired change against A2

| Cell | C_smolder | C_hand | C_endure | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 entry | 47.2% (44.1–50.3) | 88.9% (86.8–90.7) | 79.3% (76.7–81.7) | 41.3% (38.3–44.4) | 50.4% (47.3–53.5) | 33.0% (30.2–36.0) |
| change | **+12.2** | **+4.7** | **−8.7** | +2.3 | **+2.6** | **+7.7** |
| V0 full | 69.8% (66.9–72.6) | 74.6% (71.8–77.2) | 72.6% (69.8–75.3) | 55.1% (52.0–58.2) | 63.5% (60.5–66.4) | 28.3% (25.6–31.2) |
| change | +1.4 | +1.1 | **−5.1** | +0.9 | +0.7 | +1.5 |
| V5 entry | 14.0% (12.5–15.5) | 41.5% (39.4–43.7) | 63.8% (61.7–65.9) | 15.0% (13.6–16.7) | 27.8% (25.8–29.8) | 7.6% (6.6–8.9) |
| change | **+5.1** | **+8.5** | **−8.4** | −0.2 | **−1.9** | **+2.3** |
| V5 full | 38.4% (36.3–40.6) | 32.3% (30.3–34.4) | 56.4% (54.2–58.6) | 26.0% (24.1–28.0) | 34.6% (32.6–36.8) | 7.2% (6.1–8.4) |
| change | +0.1 | **+2.9** | **−7.4** | −0.1 | +0.1 | **+1.1** |

Win rates and their intervals come from the grader (`balance_readout.py table`); the paired changes come from the paired comparison against A2. Bold: decided at 95% (paired; for A and R, the exact McNemar p below 0.05).

### Gates against A2 (point / interval)

| Cell | G2 | Endure − next way | G3 (paired) | G6 (A_lit's wins) |
|---|---|---|---|---|
| V0 entry | 41.7 pp FAIL / FAIL (A2 53.0) | −9.6 (A2 +3.8) | −38.5 FAIL / FAIL (A2 −40.2) | **Hand 80.8% (77.1–84.0) FAIL / FAIL** (A2 69.9%) |
| V0 full | **4.8 pp PASS / PASS** (A2 9.3 PASS / UNDECIDED) | −2.0 (A2 +4.2) | −11.1 FAIL / FAIL (A2 −14.9) | Smolder 57.3% PASS / UNDECIDED |
| V5 entry | 49.9 FAIL / FAIL (A2 63.4) | +22.3 (A2 +39.2) | −36.1 FAIL / FAIL (A2 −42.6) | **Endure 53.3% (49.2–57.4) PASS / PASS** (A2 63.7% FAIL / UNDECIDED) |
| V5 full | 24.1 FAIL / FAIL (A2 34.4) | +18.0 (A2 +25.5) | −20.5 on 4,000 seeds (−22.5 to −18.4) FAIL / FAIL (A2 −27.7) | Smolder 71.7% FAIL / FAIL |

- **G1 and G4 (readings).** G1 passes at V0 `entry` for the first time (worst way Smolder 47.2%; A2 FAIL), at V0 `full` and at V5 `full`; G4 fails at V0 `entry` and V5 `entry`, passes at V0 `full`, and at V5 `full` is PASS / UNDECIDED.
- **G5.** Committed Endure at V0 `full`: Steady by the end of Act 1 42.2% of the runs alive, True by the end of Act 2 8.4% (A2 51.5% and 12.4%). Smolder at V0 `entry`: Steady 12.7% (A2 12.5%).
- **Row B.** B1 passes for every arm. Committed Endure: V0 `entry` expression 40.8%, close calls 1.1%, B2 FAIL (A2 53.2%, FAIL); V0 `full` expression 56.0%, close calls 1.3%, B2 FAIL (A2 UNDECIDED). Committed Smolder at V0 `entry` B2 FAIL (expression 59.0%; A2 UNDECIDED); Hand UNDECIDED (A2 PASS) at V0 `entry`; Smolder, Hand and A_lit PASS at V0 `full`, A_lit PASS at V0 `entry`.
- **Endure's Act 1 boss (Rootheart) losses.** 3.2 → 5.5% (V0 `entry`), 6.5 → 7.9% (V0 `full`), 11.3 → 16.1% (V5 `entry`), 18.5 → 21.6% (V5 `full`).
- **Kill share** within about 1 pp of A2 for every arm (Endure 86.0% and 84.0% at V0). The lever moves who survives, not who deals the damage, so no damage-share probe was taken on the reading.

### The cross-class reading

A_lit at V0 `full`: the Ashwarden 63.5%, the Duskblade 49.4%: **+14.1 pp** (paired +9.8 to +18.3), exact p 2 × 10⁻¹⁰ (A2 +13.4; the Duskblade's rows are identical, and the Ashwarden's A_lit change, +0.7, is not decided). Under +15 on point; its interval does not exclude +15, so §10's diagnosis is owed. From the reading's rows:

- **The arms and acts.** The gap sits at the Act 1 boss: the Duskblade's A_lit loses 20.0% of its runs at Rootheart, the Ashwarden's 5.5%. Then at the Act 3 boss: 20.8% of meetings lost against 9.2%. In Act 2 the Ashwarden loses more in normal fights (7.0% of runs against 1.5%), and the boss is level (12.1% against 12.2%).
- **The lever.** This is the class baseline that readout A1 diagnosed, the starter and Ashfall that carry every Ashwarden arm, not an Endure lever: E5 moves it by +0.7, not decided. No Ashwarden lever is proposed here; the Duskblade's figures never move to close it.

## The reservations and costs E5 carries

1. **The V5 remainder.** Endure still leads by +22.3 pp (`entry`) and +18.0 pp (`full`), and still ends Act 2 at 57–60 HP against 28–36 for the other ways. Its sources, from the Phase A probe: chiefly Crown of the Hearth's heal after won fights, then Cathedral Glass (5.5 copies a committed run at V5 `entry`) and, in the full pool, Hearthglow. E5 took Thirsting Shard's share: committed Endure's copies fell from 2.1 to 0.9 (`entry`) and 1.2 to 0.5 (`full`). **A reservation, and a question for A5c**: a payoff that replaces the Hearth's healing rather than adds to it. It is not a lever for a wall lane: the Hearth is shared with the Duskblade and keyed on its id.
2. **G6 at V0 `entry`** (Hand 80.8% of A_lit's wins, A2 69.9%): A2's reservation, larger, still tied to A5a.
3. **Endure's expression and reach at V0.** B2 expression 40.8% (`entry`) and 56.0% (`full`); Steady by the end of Act 1 42.2% at V0 `full`.
4. **V0 `entry` sits near the line.** Endure − next way −9.6 pp, paired interval to −12.8.

## Every graded gate and reading, under P9's definition

Short of threshold after E5: G2 in V0 `entry` and both V5 cells; G3 in all four cells; G5 at V0 `entry` (Smolder) and V0 / V5 `full` (Endure); G6 at V0 `entry` and V5 `full`; B2 for committed Endure at V0 `entry` and `full` and for committed Smolder at V0 `entry`. No longer short: G2 at V0 `full`, now PASS on interval; G6 at V5 `entry`, now PASS / PASS. G7 passes everywhere. G1 and G4 are readings.

## What the next readouts should ask

1. **A5c, Endure's payoff, and the Hearth.** Endure's V5 lead (+22.3 / +18.0) is healing, chiefly Crown of the Hearth. A5c's payoff is designed as a trade that replaces the Hearth's part in Endure's survival, not an addition (lock §14). Endure's wall lanes are closed.
2. **A5a, Smolder's entry wall, and G6 at V0 `entry`.** Smolder wins 47.2% at V0 `entry` and reaches Steady by the end of Act 1 in 12.7% of the runs alive; G6 there is Hand 80.8%. E4's finding bears on it: Cathedral Glass shared lifts Smolder's entry pool by +21.5 pp in the screen, so the off-colour weight on Endure's rare is part of Smolder's wall.
3. **G3**: A_lit trails the best committed arm by 11.1–38.5 pp in every cell.

## Tests and pins

This PR re-pins `tests/test_balance_catalogue.gd` (`abb82590…` / `5adbd58a…` → `3eea1429…` / `0aff175e…`) and `tests/test_ash_flame.gd` (Endure's affinity without `leechBlade`; its two recognition rows that used it as Endure glass use Anneal instead, keeping their masses, tiers and crowns). The lock's §6.1 and §6.2 were re-derived from the committed catalogue with `supply.py`.

## Appendix: the scripts

Scratch, in the lane's durable folder (`.claude/worktrees/ash-a8/scripts`); none writes to a report. A2's scripts (`screen.py`, `diag_probe.py`, `supply.py`) were reused.

| Script | What it does |
|---|---|
| `batch2.sh`, `queue-base2.sh`, `queue-diag2.sh`, `queue-cand2.sh`, `queue-cand2-v0.sh`, `queue-a3.sh` | The drivers: one batch at a time, `nice -n 10`, the load and disk guards, a status log; the live-batch guard matches only a running `balance_readout.py run` |
| `build_candidates2.py` | E4–E6 as minimal text edits of the Endure way's affinity, each checked by parsing against the source |
| `v5_skip.py` | The registered stop rule: a candidate whose C_endure interval includes 0 in both V5 cells skips V0 |
| `balance_sim_diag2.gd.txt` | The telemetry probe's copy of `balance_sim.gd` (A2's probe plus `fights[].hpStart`); never committed |
| `probe_hp.py`, `hearth_cap.py` | Read the probe: HP on reaching each boss, heals by source and act; the Hearth's heal under a lower lantern cap |
| `v5_ways.py`, `v5_crowns.py`, `v5_deck.py`, `hearth_split.py` | Rows by way: deaths by act and boss, HP at each act's end; crowns held and Endure glass; run-end decks; A_lit split by its first crown |
| `crossclass.py` | The cross-class reading from two A_lit reports on common seeds (reproduces A2's +13.4 on A2's rows) |
