# Readout A2: Endure's first wall lane, Vitrify out of the Ashwarden's pool

> **A wall lane's reading of record (AI-SDLC discovery), not a verdict.** #544 A8, Endure's first lane: the diagnosis, three single-lever candidates screened on development seeds, and the one the orchestrator sent on, E1, read on the bands of record against Ash readout A1 under a ship rule registered before any result. E1 shipped in #710 (`3c8732ee`): Vitrify (`ironSkin`) is in `aspects[1].excludes.cards` and carries no affinity. `content/full-content.json` on `main` is `abb82590d4beafb6c20e76e131e998ade65ca7b3b84d255f2ba61cfecea924fd` (semantic `5adbd58a932bcf0d1098266152e08462e3987c1d318267b129aeb2343ba677d4`). This PR adds this readout and links it from the lock; no content, code, test or golden moves.
>
> **Head and content.** Every reading report ran at `5666c336` from a detached run worktree with `--content` set to catalogue `3da81813e078efdc5e0b4418b48f9c639ce69ef545d0a2fdc0b64bedb3c831e1`. The merged file differs from it by one line, `"ironSkin": 1.0,` in the Endure way's affinity, which the content PR dropped because an excluded card may carry none (`tests/test_flame.gd:213-216`). The line cannot reach an outcome: `offer_cards` filters exclusions out of card rewards, shops and events (the #710 review), so no Ashwarden run can be offered, hold or play Vitrify; in the reading's 60,000 Ashwarden runs none did; and a slice on the merged file (13000–13049, all four cells, every arm, the replays) reproduces the reading's rows, **1,212 of 1,212 identical**, only the manifests' content hashes differ. Between `5666c336` and `3c8732ee`, `git diff --stat -- domain 'tools/balance_*' tools/vow_incentives.gd content/content_db.gd content/line-table.json` is empty. The rows therefore describe `main`'s content.

Ash readout A1 left Endure leading G2 by a decided margin in every cell, and #544 decision 2 reopened (the starter as the class's engine). The orchestrator put Endure's wall lane first (lock §14). This readout settles the instrument confound A1 left open, names Endure's mechanism, screens three candidates, and reads the chosen one on A1's bands.

## The answer in brief

- **E1 ships.** Every registered condition holds: Endure − next way **+3.8 pp** at V0 `entry` and **+4.2 pp** at V0 `full` (A1: +10.3 and +11.9); G7 PASS in every cell; the Duskblade byte-identical; Smolder at V0 `entry` −0.6 pp against A1, not decided.
- **The confound is the instrument.** Under `s2` on A1's content and seeds, Smolder makes 61.5–77.6% of the kills in won fights, readout A0's 61–77%; under `s3`, 77.9–86.8%. Win rates and G2's order do not move. From now on the damage share stands beside the kill share (the ruling, 11 October).
- **The mechanism.** Ashfall at any lit lantern is the class's kill condition (47% / 38% of committed Endure's damage at V0 `entry` / `full`; its own glass 3–4%). Endure's lead is survival that grows with the length of a fight, at the long bosses.
- **G2 at V0 `full` passes on point** (9.3 pp, UNDECIDED; A1 17.0, FAIL/FAIL). V0 `entry` stays Smolder's wall (53.0 pp).
- **Costs.** G6 at V0 `entry` is a decided FAIL (Hand 69.9% of A_lit's wins): **a reservation tied to A5a**. The commit-blind arms lose at V0 `entry` (A −10.0, A_lit −7.5 pp). Endure's Act 1 boss losses roughly double.
- **Endure still leads at V5** (+39.2 and +25.5 pp over the next way): the case for its second lane.

The next section was written at 17:45 BST on 11 October 2026, after the first batch had started (17:28) and before any result was read, and is published unchanged. Its clause "byte-identical to the file the content PR commits" did not hold: the committed file drops one unreachable line (head note).

## Pre-registration (the orchestrator, 11 October 2026; written before any result)

**The lever.** E1: `ironSkin` (Vitrify) in `aspects[1].excludes.cards`; content SHA-256 `3da81813e078efdc5e0b4418b48f9c639ce69ef545d0a2fdc0b64bedb3c831e1` (semantic `bd6040d8a1c13e1f7ee2d70c10abbe7c7936bf42622e653fe9e9cab971c64450`), byte-identical to the file the content PR commits.

**The instrument.** `p9`/`s3`, `--jobs 4`, A1's bands and method: V0 `entry` and V0 `full` on 13000–13999; V5 `entry` and V5 `full` on 13000–14999; G3's V5 `full` extension on 15000–16999; the Duskblade's A_lit at V0 `full` on 13000–13999, run again for the cross-class reading. Every figure paired run for run against readout A1's rows.

**E1 ships as A8's first Endure lane only if all of these hold:**
1. Endure − next way ≤ 10 pp on point, at V0 `entry` and at V0 `full`;
2. G7 passes in every cell;
3. the Duskblade's invariance panel is byte-identical;
4. Smolder at V0 `entry`, paired against A1, is not decidedly worse by more than 5 pp on point. A decided drop of at most 5 pp on point ships, recorded as a cost for A5a to recover; a decided drop of more than 5 pp does not ship, and Endure's second lane (§14 allows two) starts instead.

**Reported, not blocking:** G2 in every cell and Endure − next way at V5; G6 at V0 `entry` (a decided FAIL is expected as A_lit's wins swing to Hand, recorded as a reservation tied to A5a's Smolder entry wall); G3, G5 and row B (Endure's close calls); the cross-class reading; Endure's Act 1 boss losses; damage shares beside kill shares.

If rule 1 fails, E1 does not ship, and the readout says what the second lane should try.

## The question

Under the frozen instrument and on A1's bands: does excluding Vitrify bring committed Endure within 10 pp of the next way at V0, in both pools, without moving the Duskblade, breaking G7, or costing Smolder's entry pool more than 5 pp?

## How it was run

```sh
# Isolation: override.cfg in every worktree, [application] config/use_custom_user_dir=true and
#   config/custom_user_dir_name="glassvow-ash-a8", never committed. Batches one at a time under
#   nohup caffeinate -i, nice -n 10, --jobs 4, behind a load (<= 50) and disk (>= 62 GB) guard.
git worktree add --detach <lane>/run 5666c336; godot --headless --import
C=<lane>/cands/E1-no-vitrify.json            # sha 3da81813...
python3 -B tools/balance_readout.py run e1-v0 --aspect ashwarden --seeds 13000-13999 --cells v0-entry,v0-full \
    --replay --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run e1-v5 --aspect ashwarden --seeds 13000-14999 --cells v5-entry,v5-full \
    --replay --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run e1-ext-v5 --aspect ashwarden --seeds 15000-16999 --cells v5-full \
    --arms C_smolder,C_hand,C_endure,A_lit --content $C --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run e1-dusk-v0 --aspect duskblade --seeds 13000-13999 --cells v0-full \
    --arms A_lit --content $C --play search --pilot p9 --search s3 --jobs 4
# The merged file's equivalence slice, and the cut of the reading's chunks it is compared with:
python3 -B tools/balance_readout.py run e1b-slice --aspect ashwarden --seeds 13000-13049 \
    --cells v0-entry,v0-full,v5-entry,v5-full --replay --content <lane>/cands/E1b-no-vitrify.json --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py merge e1-slice-cut; python3 -B tools/balance_readout.py compare e1b-slice e1-slice-cut
# Grading, A1's commands, A1's rows (ash-a1-data) as the reference:
python3 -B tools/balance_readout.py table --aspect ashwarden --content $C e1-v0 e1-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999 --ref a1/v0 a1/v5
python3 -B tools/balance_readout.py join e1-g3-4000 v5-full C_smolder,C_hand,C_endure,A_lit e1-v5 e1-ext-v5
python3 -B tools/balance_readout.py g3 --aspect ashwarden --content $C e1-g3-4000 v5-full   # and e1-v0, e1-v5
python3 -B tools/balance_readout.py rowb --aspect ashwarden --content $C e1-v0 --ref a1/v0
python3 -B tools/balance_readout.py paired --aspect ashwarden --content $C e1-v0 a1/v0 v0-entry,v0-full   # and V5
python3 -B screen.py tools e1-v0 a1/v0 v0-entry v0-full    # scratch: paired G2, Endure − next, G3, G6, kill share, Act 1 boss
# The Duskblade's invariance panel at the candidate's commit, and before the push on the final tree:
godot --headless -s res://tests/run_all.gd -- --tests=res://tests/test_balance_invariance.gd
```

- **Cells, arms, seeds.** A1's: the Ashwarden at V0 on 13000–13999 and V5 on 13000–14999, pools `entry` and `full`, the six arms with arm A's three-seed replay; G3 at V5 `full` joined with 15000–16999 for 4,000 common seeds; the Duskblade's A_lit at V0 `full`. Every run pairs with A1's on its seed. Nothing read 17000–18999.
- **Measures.** A1's graders and intervals; the paired change is Newcombe's paired interval with the exact McNemar p.
- **Budget and stop rule.** One candidate, one reading, the ship rule above; nothing re-tuned after the run.
- **Wall time.** 23,933 s (6 h 39 min) for the four batches, 17:28 on 11 October to 00:15 on 12 October, 61,012 runs (V0 6,849 s; V5 11,444 s; G3's band 4,884 s; the Duskblade 756 s), load average 3.9 to 144 at the batches' ends (the shared host's peak, during V5); the slice 843 s.

## The lane, Phase A (development seeds, not of record)

### The confound: Smolder's kill share rose with the instrument

`s2` (`p9`) on A1's content and seeds, paired with A1's `s3` rows:

| Cell | Arm | Win, `s3` (A1) | Win, `s2` | Paired change (p) | Smolder's kill share, `s3` → `s2` |
|---|---|---:|---:|---|---|
| V0 entry | C_smolder | 35.6% | 35.1% | −0.5 pp (0.82) | 79.2% → 68.0% |
| | C_hand | 84.3% | 83.3% | −1.0 (0.55) | 77.9% → 61.5% |
| | C_endure | 94.6% | 94.6% | 0.0 (1.00) | 86.8% → 77.6% |
| | A_lit | 55.3% | 57.0% | +1.7 (0.40) | 78.7% → 66.7% |
| V0 full | C_smolder | 68.6% | 66.7% | −1.9 (0.25) | 85.6% → 77.4% |
| | C_hand | 73.7% | 75.1% | +1.4 (0.46) | 83.6% → 71.0% |
| | C_endure | 85.6% | 84.6% | −1.0 (0.47) | 84.9% → 74.5% |
| | A_lit | 62.8% | 60.4% | −2.4 (0.16) | 84.4% → 73.9% |

Under `s2` the share reads readout A0's 61–77%; an `s3` baseline on A0's own seeds (12000–12399) reads 77.6–86.3%. `s3`'s credit for a lethal tick changes who lands the last blow, not who wins: G2's order (Endure > Hand > Smolder) holds in both cells under both players. **Ruling (11 October): the rise is the instrument; the damage share stands beside the kill share wherever "the starter as the engine" is read.**

### The mechanism, on A1's own fights

Scratch telemetry on A1's seeds 13000–13199 (V0, four arms; every row identical to A1's once the telemetry is dropped):

- **Ashfall at any lit lantern is the class's kill condition.** Kindling one card at Steady or True (1 Ember, plus the first-gain bonus of 2) pays for Ashfall every turn: 0.96–1.00 casts a turn, against 0.33–0.45 at Kindling. It makes 47% / 38% of committed Endure's damage (51% / 42% of its kills); with Ash Bite, Ashen Core and Smother the class's kit makes 82% / 74%; Endure's own glass, 3–4%. Every lit way casts alike (Act 3 boss: Endure 0.98 a turn, Hand 0.99).
- **Endure's lead is survival that grows with the length of a fight.** At the Sovereign (650 HP, 12 turns for Endure) it blocks 90% of 13.5 incoming a turn against Hand's 76% of 12.8, from Cathedral Glass's 6.0 and Vitrify's 5.8 Ward a turn beside Ashfall's 4.9, and Thirsting Shard heals 15 HP a fight (Hearthglow 34 in the full pool): it loses 0.6% / 1.7% of its Act 3 boss fights, Hand 9.0% / 13.3%. Anneal, Mirrorlight and Glasswall are drawn about once a fight and played 0.02–0.06 times: kindle fuel.

### The screens

Three single-lever candidates, 400 seeds an arm and cell (12000–12399), `p9`/`s3`, paired with the unchanged content; the Duskblade's invariance panel passed at each candidate's commit.

| Candidate | Lever | C_endure (V0 entry / V0 full / V5 full) | What else | Ruling |
|---|---|---|---|---|
| E1 | `ironSkin` in `excludes.cards` | −10.8 / −6.2 / −9.5 pp, decided | Endure − next +1.8 / +4.8; G2 V0 full 12.0 (FAIL / UNDECIDED); C_smolder V0 entry −7.0 (p 0.037, uncorrected); G6 V0 entry Hand 69.4% | Read on the bands of record |
| E2 | `flame.lantern.trueArtCost` 2 → 1 | −0.2 / −0.2 / −0.5 pp | Nothing moves (every arm ±2 pp, near-identical rows): a dearer True Ashfall leaves Ashfall every turn | **Dropped, null** |
| E3 | Smother 1.0 Smolder (was the Smolder/Endure duo) | −18.0 / −14.2 / −29.8 pp, decided | G2 V0 full 2.0 PASS/PASS; but A_lit V0 full +14.5 (cross-class gap ≈ +28), G6 V0 full Smolder 78.3% FAIL, Endure's Act 1 boss losses ×3–6, Smolder's entry unmoved | **Not adopted; a finding for A5a** |

The ruling on E3 (11 October): the Smother duo seed is the strongest lever on Endure, but it leans the whole class towards Smolder; decision 2 stays reopened and no starter change is made now.

## The reading of record

### The ship rule

| Condition | Result | Held |
|---|---|---|
| 1. Endure − next way ≤ 10 pp on point, V0 `entry` and `full` | +3.8 pp (paired +0.8 to +6.8); +4.2 pp (+0.5 to +7.9) | yes |
| 2. G7 PASS in every cell | 0 stalls, 0 errors in 60,000 Ashwarden and 1,000 Duskblade runs; arm A's replay identical in every cell | yes |
| 3. The Duskblade byte-identical | The panel (168 pins) PASS at the candidate's commit and on #710's final tree; its A_lit at V0 `full` identical to A1's, 1,000 of 1,000 rows | yes |
| 4. Smolder at V0 `entry` not decidedly worse by more than 5 pp | −0.6 pp (−4.6 to +3.4), p = 0.81: not decided | yes |

**E1 ships** as A8's first Endure lane (#710, `3c8732ee`).

### Win rates (Wilson 95%), and the paired change against A1

| Cell | C_smolder | C_hand | C_endure | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 entry | 35.0% (32.1–38.0) | 84.2% (81.8–86.3) | 88.0% (85.8–89.9) | 39.0% (36.0–42.1) | 47.8% (44.7–50.9) | 25.3% (22.7–28.1) |
| change | −0.6 | −0.1 | **−6.6** | **−10.0** | **−7.5** | −1.0 |
| V0 full | 68.4% (65.5–71.2) | 73.5% (70.7–76.1) | 77.7% (75.0–80.2) | 54.2% (51.1–57.3) | 62.8% (59.8–65.7) | 26.8% (24.1–29.6) |
| change | −0.2 | −0.2 | **−7.9** | +1.8 | 0.0 | −1.9 |
| V5 entry | 8.8% (7.7–10.2) | 33.1% (31.0–35.1) | 72.2% (70.2–74.2) | 15.2% (13.7–16.9) | 29.6% (27.7–31.7) | 5.3% (4.4–6.4) |
| change | −1.6 | **+3.2** | **−13.7** | | **−9.5** | |
| V5 full | 38.3% (36.2–40.5) | 29.3% (27.4–31.4) | 63.8% (61.7–65.9) | 26.1% (24.2–28.0) | 34.5% (32.5–36.7) | 6.1% (5.1–7.2) |
| change | +1.0 | −1.9 | **−5.7** | | −0.8 | |

Bold: decided at 95% (paired). V5 changes for A and R are not listed: the comparison script paired the four arms the G2/G3/G6 figures read.

### Gates against A1 (point / interval)

| Cell | G2 | Endure − next way | G3 (paired) | G6 (A_lit's wins) |
|---|---|---|---|---|
| V0 entry | 53.0 pp FAIL / FAIL (A1 59.0) | +3.8 (A1 +10.3) | −40.2 FAIL / FAIL (A1 −39.3) | **Hand 69.9% (65.6–73.8) FAIL / FAIL** (A1 Endure 54.4%, PASS) |
| V0 full | **9.3 pp PASS / UNDECIDED** (A1 17.0 FAIL / FAIL) | +4.2 (A1 +11.9) | −14.9 FAIL / FAIL (A1 −22.8) | Smolder 56.8% PASS / UNDECIDED |
| V5 entry | 63.4 FAIL / FAIL (A1 75.4) | +39.2 (A1 +56.1) | −42.6 FAIL / FAIL (A1 −46.8) | Endure 63.7% FAIL / UNDECIDED (A1 81.9% FAIL / FAIL) |
| V5 full | 34.5 FAIL / FAIL (A1 38.2) | +25.5 (A1 +32.1) | −27.7 on 4,000 seeds (−29.7 to −25.6) FAIL / FAIL (A1 −34.3) | Smolder 70.3% FAIL / FAIL |

- **G5.** Committed Endure at V0 `full`: Steady by the end of Act 1 51.5% of the runs alive, True by the end of Act 2 12.4% (A1 57.4% and 19.6%). Smolder at V0 `entry`: Steady 12.5% (A1 13.5%).
- **Row B, committed Endure.** V0 `entry`: close calls 0.7% (0.6–0.8; A1 0.43%), expression 53.2% (A1 62.9%), B2 FAIL. V0 `full`: close calls 1.1% (1.0–1.3), expression 61.0%, B2 UNDECIDED (A1 FAIL / UNDECIDED). B1 passes for every arm.
- **The cross-class reading.** A_lit at V0 `full`: the Ashwarden 62.8%, the Duskblade 49.4%: **+13.4 pp** (paired +9.1 to +17.6), exact p 1.7 × 10⁻⁹, unchanged from A1.
- **Endure's Act 1 boss (Rootheart) losses.** 1.4 → 3.2% (V0 `entry`), 4.0 → 6.5% (V0 `full`), 6.8 → 11.3% (V5 `entry`), 15.4 → 18.5% (V5 `full`).
- **Kill share** within 1 pp of A1 for every arm (Endure 85.8% and 84.0% at V0). The damage shares were probed on A1's fights (above), not again on E1's.

### The reservations and costs E1 carries

1. **G6 at V0 `entry`** (Hand 69.9% of A_lit's wins, a decided FAIL, as registered): with Vitrify gone, Endure's flame lights less often and A_lit's wins swing to Hand; Smolder still takes 2.5%. **A reservation tied to A5a**: a Smolder way that can win the entry pool is what gives A_lit a third colour there.
2. **The commit-blind arms at V0 `entry`** (A −10.0, A_lit −7.5 pp): they took Vitrify too. A_lit at V0 `full` is unchanged, so the cross-class gap is too.
3. **Endure's Act 1 boss losses** roughly double, and its full-pool reach falls (G5, above).
4. **Endure's expression at V0 `entry`** falls to 53.2% (B2).

## Every graded gate and reading, under P9's definition

Short of threshold after E1: G2 in all four cells but V0 `full` on point; G3 in all four cells; G5 at V0 `entry` (Smolder) and V0 / V5 `full` (Endure, Hand); G6 at V0 `entry` (new) and V5 `full`, and at V5 `entry` on point; B2 for committed Endure at V0 `entry` (expression 53.2%, close calls 0.7%). No longer short: G2 at V0 `full` on point (UNDECIDED on interval); B2 for committed Smolder at V0 `entry` (expression 59.6%, UNDECIDED) and A_lit (63.9%, PASS); committed Endure's close calls at V0 `full` (1.1%, UNDECIDED). G7 passes everywhere. G1 and G4 are readings.

## What the next readouts should ask

1. **A8, Endure's second lane** (lock §14 allows two; at most three candidates): Endure still leads at V5 by +39.2 pp (`entry`) and +25.5 pp (`full`). The diagnosis's other survival sources (Cathedral Glass's Ward, Thirsting Shard's healing at the long bosses) are where to look; E3's finding says the duo seed is the strongest lever, but as a class-wide lean.
2. **A5a, Smolder's entry wall**: Smolder wins 35.0% at V0 `entry` and reaches Steady by the end of Act 1 in 12.5% of the runs alive. It carries G2 at V0 `entry` and the G6 reservation above.
3. **G3**: A_lit trails the best committed arm by 14.9–42.6 pp in every cell.

## Tests and pins

No test or pin moves in this PR. #710 re-pinned `tests/test_balance_catalogue.gd` (`3da81813…` was never committed; `4376691e…` → `abb82590…`) and `tests/test_ash_flame.gd`. The lock's §6.2 was re-derived from the merged catalogue with `supply.py`, which reproduces the pre-A8 figures exactly; every figure the lock prints is correct, so nothing in it is corrected here. This PR only links this readout from the lock's 11 October row.

## Appendix: the scripts

Scratch, in the lane's durable folder (`.claude/worktrees/ash-a8/scripts`); none writes to a report.

| Script | What it does |
|---|---|
| `batch.sh`, `queue1.sh`, `queue2.sh`, `queue3.sh` | The drivers: one batch at a time, `nice -n 10`, the load and disk guards, a status log |
| `screen.py` | A candidate or reading against a base on the same seeds: paired change per arm, G2 as the grader reads it, Endure − next way, G3 paired, G6, kill share, Act 1 boss losses |
| `confound_rows.py` | `s2` rows against A1's `s3` rows: identical rows, outcome flips, kill tallies |
| `balance_sim_diag.gd.txt` | The telemetry probe's copy of `balance_sim.gd` (a `fights[].diag` per fight: Ward, heals, damage and kills by source); never committed |
| `diag_probe.py` | Reads the probe: Ashfall casts, incoming and blocked damage, Ward and heals by source, damage and kills by source |
| `endure_rows.py`, `tiers_rows.py`, `sovereign_rows.py`, `endure_vs.py` | A1's rows: fights, decks and relics; tiers and boss outcomes by act; Act 3 boss losses by deck; where the other ways die on Endure's wins |
| `build_candidates.py` | E1–E3 as minimal text edits of the Ashwarden's row, each checked by parsing against the source |
| `supply.py` | The lock's §6.2 supply table from a catalogue |
| `killshare.py` | A1's validated kill-share script (copy) |
