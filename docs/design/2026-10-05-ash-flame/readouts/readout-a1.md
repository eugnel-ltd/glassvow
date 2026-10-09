# Readout A1: the Ashwarden's reading of record

> **The Ashwarden's first reading of record (AI-SDLC discovery), not a verdict and not a balance change.** #544's plan of record, step A2, part 2: the lock's §10 instrument on the bands of record, on the Ashwarden's ways as #702 merged them. The thresholds freeze on it (lock §10), with no amendment. **No content changed**: `content/full-content.json` is `main`'s, SHA-256 `4376691e1a8efc772c9fd9ef9957f4dd7235adaac1823887707c990fdf71ea4d` (semantic `9f72ef7a8cda0df01ba4efbe190dd19103d39114a59fb01b300259df107204f2`), the same at #702's merge `eda4f869` and at `711302a5`. This PR adds the readout and edits documents and the usage text of two balance tools. No domain rule, id, rider, lantern knob, enemy number, save field, RNG draw or `port_fixtures/` golden moved. The readout gives no verdict, because verdicts are step A9's. It ends with the questions the reading raises.
>
> **Head.** Every report ran at `faa9834720d1d35c7ed0c2bcabd2dc13e80f63f0` (#705), in a detached run worktree, and every manifest names it, with pilot `p9` and search player `s3`. That commit is the content as merged: `git diff --stat eda4f869 faa98347 -- tools content domain` is empty, and between `faa98347` and `711302a5` only `tools/benchmark-citations.txt` differs. At this PR's head, `git diff --stat faa98347 HEAD -- domain content 'tools/balance_*'` lists `tools/balance_readout.py` and `tools/balance_ways.py`. Those are this PR's own docstring and usage-text edits, which name `s3`; no code a report depends on moved. A first attempt at these batches, launched on 5 October 2026 at `eda4f869`, died with the host's reboot that afternoon. None of its rows survives or is used here: every chunk below was run on 9 October.

Readout A0 screened the Ashwarden's tagging on development seeds and left four questions to the reading of record: whether Endure leads the ways by a decided margin, whether Smolder starves in the entry pool, whether the class's starter is its engine whatever the way, and how far the Ashwarden sits above the Duskblade (+10.5 pp on content with no ways). #702 put the ways, the lantern and the exclusions in content. This readout reads the Ashwarden's complete §11 table on the bands of record under `p9`/`s3`, takes the cross-class reading again with both classes under `s3`, and freezes the thresholds.

## The answer in brief

- **Endure leads every cell by a decided margin.** Committed Endure wins 94.6% and 85.6% at V0 (`entry`, `full`) and 85.9% and 69.5% at V5. G2 fails on point and interval in all four cells: +59.0, +17.0, +75.4 and +38.2 pp, every interval clear of the 10 pp line. Over the next-best way its lead is decided above 10 pp at V5; at V0 it is above 10 pp on point (+10.3 and +11.9 pp over Hand) and UNDECIDED on interval. Under the lock's §14 Endure is the lead way.
- **Smolder starves in the entry pool, as readout A0 found.** It wins 35.6% at V0 `entry` and 10.4% at V5 `entry`, and reaches Steady by the end of Act 1 in 13.5% of the runs alive then (G5's floor is 40%). In the full pool it is healthy: 68.6% at V0, Steady 74.0% and True 70.5% of the runs alive.
- **Hand wins at V0 and falls away at V5.** It wins 84.3% and 73.7% at V0 but 29.8% and 31.2% at V5, and its full-pool True reach (33.9% and 32.3% of the runs alive) is short of 40%. Its winning decks at V0 `entry` hold 4.1 Phantom Blades.
- **G3 fails everywhere.** A_lit trails committed Endure by 22.8 to 46.8 pp, paired, in every cell; on G3's 4,000 seeds at V5 full it is −34.3 pp (−36.3 to −32.3).
- **G6 passes at V0 and fails at V5.** A_lit's wins split across ways at V0 (`entry`: Endure 54.4%, Hand 42.9%; `full`: Smolder 53.3%, Hand 36.1%), PASS on point and interval. At V5 one way takes them: Endure 81.9% at V5 `entry`, Smolder 68.4% at V5 `full`, both decided FAILs.
- **Row B.** B1 passes for every committed way and A_lit in both pools. B2 fails at V0 `entry` for committed Smolder (expression 59.1%), committed Endure (close calls 0.43%: its fights are almost never close) and A_lit (expression 59.0%). At V0 `full` committed Endure's close calls (0.91%) fail on point and are UNDECIDED on interval. Clustered by run, the two expression figures become UNDECIDED; Endure's close calls at V0 `entry` stay a decided FAIL.
- **G7 holds.** No stall and no error in 45,012 runs; arm A's replay is identical in all four cells.
- **The cross-class reading is +13.4 pp** (A_lit at V0 full: the Ashwarden 62.8%, the Duskblade 49.4%; Newcombe's paired 95% interval +9.1 to +17.6; exact p = 1.4 × 10⁻⁹). It is under the +15 pp line on point, but its interval reaches above it. Act 1 carries most of it: the Duskblade's A_lit dies there in 20.3% of runs, the Ashwarden's in 6.4%.
- **The starter is the class's engine, more than readout A0 saw.** Smolder makes 78–88% of the kills in won fights, in every arm and cell (A0: 61–77% on development seeds under `s2`). The committed Hand and Endure decks, which hold 1.1–2.7 copies of Smolder's own glass in 40–43 cards, take 78–87% of their kills by it.
- **The walls.** Smolder dies in Acts 2 and 3 of the entry pool. Hand dies in Act 3, and at V5 in every act. Endure loses at most 7.8% of the runs alive in any act at V0, and at V5 `full` dies most in Act 1 (17.0%). Act bosses take 63–87% of every arm's deaths.
- **Thresholds:** frozen as the lock's §10 sets them. No amendment is proposed.

## The question

On the Ashwarden's ways as merged, under the 1.1 instrument and on the bands of record: what does the complete §11 table read for aspect 1, gate by gate on point and on interval? Which way leads G2, and by a decided margin? What share of each arm's kills in won fights does Smolder make? Where does each way die? And how far does the Ashwarden's A_lit sit from the Duskblade's at V0 full on the same seeds, commit and instrument?

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the run worktree's root with
#   [application] config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-ash-a1-run", never committed.
git worktree add --detach <durable>/ash-a1-run faa9834720d1d35c7ed0c2bcabd2dc13e80f63f0
godot --headless --import                                  # once; content SHA-256 checked as main's
# The four batches, one at a time, from a driver script (nice -n 10) that logs each batch's start and end:
python3 -B tools/balance_readout.py run a1/v0 --aspect ashwarden --seeds 13000-13999 --cells v0-entry,v0-full \
    --replay --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a1/v5 --aspect ashwarden --seeds 13000-14999 --cells v5-entry,v5-full \
    --replay --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a1/ext-v5 --aspect ashwarden --seeds 15000-16999 --cells v5-full \
    --arms C_smolder,C_hand,C_endure,A_lit --play search --pilot p9 --search s3 --jobs 4
python3 -B tools/balance_readout.py run a1/dusk-v0 --aspect duskblade --seeds 13000-13999 --cells v0-full \
    --arms A_lit --play search --pilot p9 --search s3 --jobs 4
# Grading, from the same root:
python3 -B tools/balance_readout.py table --aspect ashwarden a1/v0 a1/v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999
python3 -B tools/balance_readout.py join a1/g3-4000 v5-full C_smolder,C_hand,C_endure,A_lit a1/v5 a1/ext-v5
python3 -B tools/balance_readout.py g3 --aspect ashwarden a1/g3-4000 v5-full
python3 -B tools/balance_readout.py g3 --aspect ashwarden a1/v5 v5-entry,v5-full   # and a1/v0 v0-entry,v0-full; a1/ext-v5 v5-full
python3 -B tools/balance_readout.py rowb --aspect ashwarden a1/v0
python3 -B tools/balance_ways.py --aspect ashwarden --from-dir a1/v0 --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --aspect ashwarden --from-dir a1/v5 --seeds 13000-14999 --vows 5
python3 -B tools/balance_readout.py paired --aspect ashwarden a1/v0 a1/dusk-v0 v0-full --arms A_lit
# Scratch scripts (appendix):
python3 -B crossclass.py . a1/v0 a1/dusk-v0; python3 -B crossclass_acts.py a1/v0/v0-full-A_lit.json a1/dusk-v0/v0-full-A_lit.json
python3 -B killshare.py a1/v0 v0-entry v0-full        # and a1/v5 v5-entry,v5-full; a1/g3-4000 v5-full
python3 -B validate_killshare.py killshare.py a1/v0 a1/v5 a1/ext-v5
python3 -B g5_ways.py . a1/v0 0; python3 -B rowb_point.py . a1/v0; python3 -B rowb_cluster.py . a1/v0
python3 -B lead_and_guards.py . a1/v0 a1/v5 a1/ext-v5 a1/g3-4000 a1/dusk-v0
python3 -B walls.py a1/v0 v0-entry v0-full; python3 -B smolder_decks.py a1/v0 v0-entry v0-full   # and a1/v5
```

- **Cells, arms, seeds.** The Ashwarden (aspect 1), V0 on 13000–13999 (1,000 paired seeds a cell) and V5 on 13000–14999 (2,000), pools `entry` and `full`. The six arms are C_smolder, C_hand, C_endure, A, A_lit and R, with arm A's three-seed replay in each cell. G3 at V5 full also ran on 15000–16999, so it is read on 4,000 common seeds. The Duskblade's A_lit ran at V0 full on 13000–13999 for the cross-class reading. Every run pairs with every other arm's on its seed. Nothing read 17000–18999, the 1.1 holdout.
- **Measures.** The graders' G1–G7 and row B, each on point and on 95% interval: Wilson for a rate, Newcombe's hybrid score interval for a difference of independent rates. The `entry` pool is graded at `fresh`'s thresholds (lock §10), and G5 over the runs alive at the act's end. G3 is graded paired on common seeds (Newcombe's paired interval). The cross-class reading uses Newcombe's paired interval (`balance_readout_stats.paired_difference`) with the exact two-sided McNemar p. Smolder's share of kills is defined under *The starter as the class's engine*. A wall is where a way dies: the act of a lost run's last fight, as a share of the runs alive at that act's start, with the kind of fight.
- **Budget and stop rule.** One reading, no candidates, nothing tuned. The content (as merged), the instrument and the batches' commands were fixed before the first run. Each batch ran alone at `--jobs 4`, because the host is shared with another project's self-hosted CI.
- **Wall time.** 23,875 s (6 h 38 min), 00:16 to 06:54 BST on 9 October 2026. That covers 45,012 runs on four jobs under `nice -n 10`. The load averages logged at each batch's start and end ran from 4.8 to 47.4, with 140–163 GB free.

| Batch | Runs | Window (BST) | Wall time | Chunks | Seconds a run per process |
|---|---:|---|---:|---:|---:|
| V0 | 12,006 | 00:16–02:24 | 7,724 s | 242 of 242 | 2.57 |
| V5 | 24,006 | 02:24–05:25 | 10,847 s | 482 of 482 | 1.81 |
| G3's second band | 8,000 | 05:25–06:43 | 4,652 s | 160 of 160 | 2.33 |
| The Duskblade's A_lit | 1,000 | 06:43–06:54 | 652 s | 20 of 20 | 2.61 |

Seconds a run per process is wall time × jobs ÷ runs. Readout 14 read 3.76 s for its V0 table and 2.11 s for its V5 table, under `s2` on six jobs at a load average of 160 to above 900.

## The complete §11 table

### Win rates, search player `s3`, pilot `p9`

Wilson 95% intervals.

| Cell | C_smolder | C_hand | C_endure | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 entry | 35.6% (32.7–38.6) | 84.3% (81.9–86.4) | 94.6% (93.0–95.8) | 49.0% (45.9–52.1) | 55.3% (52.2–58.4) | 26.3% (23.7–29.1) |
| V0 full | 68.6% (65.7–71.4) | 73.7% (70.9–76.3) | 85.6% (83.3–87.6) | 52.4% (49.3–55.5) | 62.8% (59.8–65.7) | 28.7% (26.0–31.6) |
| V5 entry | 10.4% (9.2–11.9) | 29.8% (27.8–31.8) | 85.9% (84.3–87.4) | 26.3% (24.4–28.3) | 39.1% (37.0–41.3) | 5.5% (4.6–6.6) |
| V5 full | 37.3% (35.2–39.4) | 31.2% (29.3–33.3) | 69.5% (67.4–71.4) | 25.6% (23.7–27.6) | 35.3% (33.2–37.4) | 7.9% (6.8–9.2) |

On G3's 4,000 seeds at V5 full: C_smolder 37.8% (36.3–39.3), C_hand 30.8% (29.4–32.2), C_endure 69.6% (68.2–71.0), A_lit 35.3% (33.8–36.8).

### The committed ways' reach

Steady by the end of Act 1 and True by the end of Act 2, over all runs and, in brackets, over the runs alive at that act's end (G5's denominator); the share of runs whose flame reads the arm's own way at run end.

| Cell | Arm | Own way at end | Steady by end of Act 1 | True by end of Act 2 |
|---|---|---:|---|---|
| V0 entry | C_smolder | 56.8% | 12.6% (13.5% of 930) | 0.1% (0.2% of 636) |
| V0 entry | C_hand | 99.8% | 78.4% (81.0% of 968) | 52.0% (55.1% of 944) |
| V0 entry | C_endure | 99.9% | 84.8% (86.1% of 985) | 53.0% (55.4% of 957) |
| V0 full | C_smolder | 99.3% | 72.6% (74.0% of 981) | 61.8% (70.5% of 877) |
| V0 full | C_hand | 99.8% | 66.5% (68.5% of 971) | 31.0% (33.9% of 914) |
| V0 full | C_endure | 98.2% | 54.9% (57.4% of 956) | 17.3% (19.6% of 881) |
| V5 entry | C_smolder | 47.6% | 4.2% (7.6% of 1,108) | 0.0% (0.0% of 448) |
| V5 entry | C_hand | 98.7% | 67.2% (89.4% of 1,503) | 34.6% (61.7% of 1,121) |
| V5 entry | C_endure | 99.7% | 89.8% (96.9% of 1,853) | 72.2% (82.2% of 1,757) |
| V5 full | C_smolder | 97.8% | 66.3% (79.6% of 1,668) | 39.6% (69.9% of 1,131) |
| V5 full | C_hand | 98.7% | 56.4% (72.6% of 1,554) | 17.3% (32.3% of 1,073) |
| V5 full | C_endure | 96.8% | 59.4% (71.6% of 1,660) | 22.9% (31.4% of 1,454) |

### The feel, V0

Per fight, from `balance_ways.py`: turns, HP lost, close calls (won fights ending under 20% HP), way expression, and each committed arm's own way stat (`smolderKills`, `drawn`, `perfects`; lock §10).

| Cell | Arm | Turns | HP lost | Close calls | Expression | Own way stat a fight |
|---|---|---:|---:|---:|---:|---:|
| V0 entry | C_smolder | 3.34 | 10.69 | 3.2% | 59.1% | 1.11 Smolder kills |
| V0 entry | C_hand | 3.19 | 8.15 | 1.3% | 88.6% | 8.52 drawn |
| V0 entry | C_endure | 3.76 | 9.51 | 0.4% | 62.9% | 0.32 perfects |
| V0 entry | A_lit | 3.56 | 10.63 | 2.3% | 59.0% | |
| V0 full | C_smolder | 2.73 | 9.99 | 2.9% | 78.7% | 1.22 Smolder kills |
| V0 full | C_hand | 3.14 | 9.49 | 2.5% | 86.7% | 11.37 drawn |
| V0 full | C_endure | 3.60 | 11.97 | 0.9% | 65.6% | 0.23 perfects |
| V0 full | A_lit | 3.10 | 12.74 | 2.6% | 69.2% | |

### The gates

Every gate in every cell, on point and on the 95% interval, as the graders print them. G1 and G4 are readings; the floor rows are arm A's, reported. The intervals here are the grader's for a difference of independent rates; the G3 table below gives G3 paired on common seeds, its graded form. The last column is readout A0's search screen where it graded the gate: V0 only, 400 development seeds (12000–12399), a scratch catalogue (`duos`) and `s2`. It is context, not a reference reading of record. **Bold** marks an interval verdict the screen left UNDECIDED and this reading decides.

| Cell | Gate | Measured | Point | 95% interval | Interval | Readout A0's screen |
|---|---|---|---|---|---|---|
| V0 entry | G1 | worst C_smolder 35.6% | FAIL | worst C_smolder 35.6% (32.7–38.6%, n=1000) | FAIL | - |
| V0 entry | G2 | 59.0 pp (C_endure − C_smolder) | FAIL | C_endure − C_smolder +59.0 pp (+55.6 to +62.2, n=1000+1000) | FAIL | +60.8 pp: FAIL / FAIL |
| V0 entry | G3 | A_lit 55.3% vs best 94.6% (−39.3 pp) | FAIL | A_lit − C_endure −39.3 pp (−42.6 to −35.9, n=1000+1000) | FAIL | −40.3 pp (paired): FAIL / FAIL |
| V0 entry | G4 | R 26.3% vs worst 35.6% (−9.3 pp) | FAIL | R − C_smolder −9.3 pp (−13.3 to −5.3, n=1000+1000); R 26.3% (23.7–29.1%, n=1000) | FAIL | −4.0 pp (−10.3 to +2.4) |
| V0 entry | G5 | Steady by end of Act 1 min 13.5% of runs alive (C_smolder; all runs 12.6%); True not graded | FAIL | Steady min C_smolder 13.5% (11.5–15.9%, n=930 alive) | FAIL | C_smolder 13%: FAIL |
| V0 entry | G6 | smolder 2.7%, hand 42.9%, endure 54.4% of 553 A_lit wins | PASS | lead endure 54.4% (50.3–58.5%, n=553 A_lit wins) | **PASS** | Endure 56.8%: PASS / UNDECIDED |
| V0 entry | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 entry | G3 floor (A) | A 49.0% vs best 94.6% (−45.6 pp) | FAIL | A − C_endure −45.6 pp (−48.9 to −42.1, n=1000+1000) | FAIL | −43.8 pp: FAIL / FAIL |
| V0 entry | G6 floor (A) | smolder 0.8%, hand 39.0%, endure 60.2% of 490 A wins | FAIL | lead endure 60.2% (55.8–64.4%, n=490 A wins) | UNDECIDED | - |
| V0 full | G1 | worst C_smolder 68.6% | PASS | worst C_smolder 68.6% (65.7–71.4%, n=1000) | PASS | - |
| V0 full | G2 | 17.0 pp (C_endure − C_smolder) | FAIL | C_endure − C_smolder +17.0 pp (+13.4 to +20.6, n=1000+1000) | **FAIL** | +12.7 pp: FAIL / UNDECIDED |
| V0 full | G3 | A_lit 62.8% vs best 85.6% (−22.8 pp) | FAIL | A_lit − C_endure −22.8 pp (−26.5 to −19.1, n=1000+1000) | FAIL | −25.5 pp (paired): FAIL / FAIL |
| V0 full | G4 | R 28.7% vs worst 68.6% (−39.9 pp) | PASS | R − C_smolder −39.9 pp (−43.8 to −35.8, n=1000+1000); R 28.7% (26.0–31.6%, n=1000) | PASS | −40.2 pp |
| V0 full | G5 | Steady by end of Act 1 min 57.4% of runs alive (C_endure; all runs 54.9%); True by end of Act 2 min 19.6% of runs alive (C_endure; all runs 17.3%) | FAIL | Steady min C_endure 57.4% (54.3–60.5%, n=956 alive); True min C_endure 19.6% (17.1–22.4%, n=881 alive) | FAIL | C_endure (Steady 54%, True 20%) and C_hand (True 39%): FAIL |
| V0 full | G6 | smolder 53.3%, hand 36.1%, endure 10.5% of 628 A_lit wins | PASS | lead smolder 53.3% (49.4–57.2%, n=628 A_lit wins) | PASS | Smolder 50.8%: PASS / PASS |
| V0 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 full | G3 floor (A) | A 52.4% vs best 85.6% (−33.2 pp) | FAIL | A − C_endure −33.2 pp (−36.9 to −29.3, n=1000+1000) | FAIL | −33.8 pp: FAIL / FAIL |
| V0 full | G6 floor (A) | smolder 55.3%, hand 35.5%, endure 9.2% of 524 A wins | PASS | lead smolder 55.3% (51.1–59.5%, n=524 A wins) | PASS | - |
| V5 entry | G1 | worst C_smolder 10.4% | n/a | worst C_smolder 10.4% (9.2–11.9%, n=2000) | n/a | |
| V5 entry | G2 | 75.4 pp (C_endure − C_smolder) | FAIL | C_endure − C_smolder +75.4 pp (+73.3 to +77.4, n=2000+2000) | FAIL | |
| V5 entry | G3 | A_lit 39.1% vs best 85.9% (−46.8 pp) | FAIL | A_lit − C_endure −46.8 pp (−49.3 to −44.1, n=2000+2000) | FAIL | |
| V5 entry | G4 | R 5.5% vs worst 10.4% (−5.0 pp) | FAIL | R − C_smolder −4.9 pp (−6.6 to −3.3, n=2000+2000); R 5.5% (4.6–6.6%, n=2000) | FAIL | |
| V5 entry | G5 | Steady by end of Act 1 min 7.6% of runs alive (C_smolder; all runs 4.2%); True by end of Act 2 min 0.0% of runs alive (C_smolder; all runs 0.0%) | n/a | Steady min C_smolder 7.6% (6.2–9.3%, n=1108 alive) | n/a | |
| V5 entry | G6 | smolder 0.1%, hand 18.0%, endure 81.9% of 783 A_lit wins | FAIL | lead endure 81.9% (79.0–84.4%, n=783 A_lit wins) | FAIL | |
| V5 entry | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | |
| V5 entry | G3 floor (A) | A 26.3% vs best 85.9% (−59.6 pp) | FAIL | A − C_endure −59.6 pp (−62.0 to −57.1, n=2000+2000) | FAIL | |
| V5 entry | G6 floor (A) | smolder 0.2%, hand 11.6%, endure 88.2% of 526 A wins | FAIL | lead endure 88.2% (85.2–90.7%, n=526 A wins) | FAIL | |
| V5 full | G1 | worst C_hand 31.2% | PASS | worst C_hand 31.2% (29.3–33.3%, n=2000) | PASS | |
| V5 full | G2 | 38.2 pp (C_endure − C_hand) | FAIL | C_endure − C_hand +38.2 pp (+35.3 to +41.0, n=2000+2000) | FAIL | |
| V5 full | G3 | A_lit 35.3% vs best 69.5% (−34.2 pp) | FAIL | A_lit − C_endure −34.2 pp (−37.0 to −31.2, n=2000+2000) | FAIL | |
| V5 full | G4 | R 7.9% vs worst 31.2% (−23.4 pp) | FAIL | R − C_hand −23.3 pp (−25.7 to −21.0, n=2000+2000); R 7.9% (6.8–9.2%, n=2000) | UNDECIDED | |
| V5 full | G5 | Steady by end of Act 1 min 71.6% of runs alive (C_endure; all runs 59.4%); True by end of Act 2 min 31.4% of runs alive (C_endure; all runs 22.9%) | FAIL | Steady min C_endure 71.6% (69.3–73.7%, n=1660 alive); True min C_endure 31.4% (29.1–33.9%, n=1454 alive) | FAIL | |
| V5 full | G6 | smolder 68.4%, hand 14.6%, endure 17.0% of 706 A_lit wins | FAIL | lead smolder 68.4% (64.9–71.7%, n=706 A_lit wins) | FAIL | |
| V5 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | |
| V5 full | G3 floor (A) | A 25.6% vs best 69.5% (−43.9 pp) | FAIL | A − C_endure −43.9 pp (−46.6 to −41.0, n=2000+2000) | FAIL | |
| V5 full | G6 floor (A) | smolder 68.9%, hand 15.4%, endure 15.6% of 512 A wins | FAIL | lead smolder 68.9% (64.8–72.8%, n=512 A wins) | FAIL | |

G7 covers no stall and no error in all 45,012 runs (the tables' 36,012, the second band's 8,000 and the Duskblade's 1,000), and arm A's three-seed replay, identical in every cell. Every one of the 37 reports, the 4,000-seed join included, names `faa98347`, content `4376691e…`, pilot `p9` and search `s3`.

**G5 for each committed way.** The grader prints only the minimum. Over the runs alive, with each figure's verdict on point and interval:

| Cell | Way | Steady by end of Act 1 | True by end of Act 2 |
|---|---|---|---|
| V0 entry (Steady ≥ 40%; True not graded) | C_smolder | 13.5% (11.5–15.9): FAIL / FAIL | 0.2% (0.0–0.9) |
| | C_hand | 81.0% (78.4–83.3): PASS / PASS | 55.1% (51.9–58.2) |
| | C_endure | 86.1% (83.8–88.1): PASS / PASS | 55.4% (52.2–58.5) |
| V0 full (≥ 70% and ≥ 40%) | C_smolder | 74.0% (71.2–76.7): PASS / PASS | 70.5% (67.4–73.4): PASS / PASS |
| | C_hand | 68.5% (65.5–71.3): FAIL / UNDECIDED | 33.9% (30.9–37.0): FAIL / FAIL |
| | C_endure | 57.4% (54.3–60.5): FAIL / FAIL | 19.6% (17.1–22.4): FAIL / FAIL |
| V5 full (≥ 70% and ≥ 40%) | C_smolder | 79.6% (77.6–81.4): PASS / PASS | 69.9% (67.2–72.5): PASS / PASS |
| | C_hand | 72.6% (70.3–74.7): PASS / PASS | 32.3% (29.6–35.2): FAIL / FAIL |
| | C_endure | 71.6% (69.3–73.7): PASS / UNDECIDED | 31.4% (29.1–33.9): FAIL / FAIL |

### G3 on common seeds

A_lit minus the best committed arm on each common seed, with Newcombe's interval for a difference of paired proportions (`balance_readout.py g3`). The best committed arm is Endure in every cell.

| Cell | Best committed | A_lit − best (point) | Paired 95% interval | Verdict (point / interval) | Both / only A_lit / only best / neither |
|---|---|---|---|---|---|
| V0 entry | C_endure 94.6% | −39.3 pp | −42.6 to −35.9 | FAIL / FAIL | 528 / 25 / 418 / 29 |
| V0 full | C_endure 85.6% | −22.8 pp | −26.3 to −19.2 | FAIL / FAIL | 553 / 75 / 303 / 69 |
| V5 entry | C_endure 85.9% | −46.8 pp | −49.2 to −44.2 | FAIL / FAIL | 706 / 77 / 1,012 / 205 |
| V5 full, 13000–14999 (the table) | C_endure 69.5% | −34.2 pp | −36.9 to −31.3 | FAIL / FAIL | 522 / 184 / 867 / 427 |
| V5 full, 15000–16999 | C_endure 69.8% | −34.5 pp | −37.3 to −31.7 | FAIL / FAIL | 523 / 182 / 872 / 423 |
| **V5 full, both, 4,000 seeds** | C_endure 69.6% | **−34.3 pp** | **−36.3 to −32.3** | **FAIL / FAIL** | 1,045 / 366 / 1,739 / 850 |

### Row B, the bot round (V0, `s3`)

The grader's interval verdicts, the point verdicts against the same floors (B1: a committed way wins ≥ 10% at `entry` and ≥ 20% at `full`; B2: expression ≥ 60% and close calls within 1–10% of won fights), and B2's figures again with a run-clustered bootstrap interval (2,000 resamples of whole runs). The grader's Wilson intervals count fights as independent, but a run's fights share its deck (runbook §5, *Clustering*).

| Cell | Arm | Win rate (95%) | B1 (point / interval) | Expression (Wilson; clustered) | Close calls (Wilson; clustered) | B2 (point / interval) | B2 interval, clustered |
|---|---|---|---|---|---|---|---|
| V0 entry | C_smolder | 35.6% (32.7–38.6) | PASS / PASS | 59.1% (58.4–59.8; 57.5–60.7) | 3.2% (3.0–3.5; 2.9–3.5) | FAIL / FAIL | UNDECIDED |
| V0 entry | C_hand | 84.3% (81.9–86.4) | PASS / PASS | 88.6% (88.2–89.0; 88.0–89.2) | 1.3% (1.2–1.5; 1.1–1.5) | PASS / PASS | PASS |
| V0 entry | C_endure | 94.6% (93.0–95.8) | PASS / PASS | 62.9% (62.3–63.5; 61.9–63.9) | 0.43% (0.36–0.52; 0.32–0.56) | FAIL / FAIL | FAIL |
| V0 entry | A_lit | 55.3% (52.2–58.4) | PASS / PASS | 59.0% (58.3–59.6; 57.5–60.5) | 2.3% (2.1–2.5; 2.0–2.5) | FAIL / FAIL | UNDECIDED |
| V0 full | C_smolder | 68.6% (65.7–71.4) | PASS / PASS | 78.7% (78.1–79.2; 77.8–79.5) | 2.9% (2.7–3.1; 2.6–3.1) | PASS / PASS | PASS |
| V0 full | C_hand | 73.7% (70.9–76.3) | PASS / PASS | 86.7% (86.3–87.1; 86.0–87.4) | 2.5% (2.3–2.7; 2.3–2.8) | PASS / PASS | PASS |
| V0 full | C_endure | 85.6% (83.3–87.6) | PASS / PASS | 65.6% (65.0–66.2; 64.4–66.8) | 0.91% (0.80–1.04; 0.76–1.10) | FAIL / UNDECIDED | UNDECIDED |
| V0 full | A_lit | 62.8% (59.8–65.7) | PASS / PASS | 69.2% (68.6–69.8; 68.0–70.4) | 2.6% (2.4–2.8; 2.3–2.9) | PASS / PASS | PASS |

B1 passes for every committed way in both pools. Committed Endure fails B2 on the floor of close calls: 109 of its 25,180 won fights at V0 `entry` end under 20% HP, a decided FAIL however it is counted. Committed Smolder's and A_lit's expression at V0 `entry` sit about a point under 60%: decided FAILs under the grader's interval, UNDECIDED when whole runs are resampled.

## The cross-class reading

A_lit at V0 full on 13000–13999, both classes at `faa98347` under `p9`/`s3` (lock §10, #544 decision 5). The manifests agree on commit, content, bots, player and Godot version. The interval is Newcombe's paired interval and the p is the exact two-sided McNemar test (`balance_readout_stats`); the repository's `paired` command gives the same gap and seed counts.

| | Ashwarden | Duskblade | Gap | Paired 95% | Seeds: both win / Ashwarden only / Duskblade only / neither | Exact p |
|---|---|---|---|---|---|---|
| A_lit, V0 full | 62.8% (59.8–65.7) | 49.4% (46.3–52.5) | **+13.4 pp** | **+9.1 to +17.6** | 317 / 311 / 177 / 195 | 1.4 × 10⁻⁹ |
| Readout A0 (no ways, no lantern, no exclusions; `s2`) | 58.7% | 48.2% | +10.5 pp | +6.1 to +14.8 | 279 / 308 / 203 / 210 | |

The gap is under the +15 pp line on point, so by the reading readout A0 applied (its point, +10.5 pp, "under the +15 pp line") no diagnosis is triggered. Its interval's top end, +17.6 pp, lies above the line, so this reading cannot rule out a true gap beyond it. Which reading of "above +15 pp" the lock means is a question for the orchestrator (below). The figures a diagnosis would start from, by act, paired on seed:

| Act | Ashwarden A_lit: deaths (of runs alive) | Duskblade A_lit: deaths (of runs alive) | Seeds the Ashwarden wins where the Duskblade dies here | Seeds the Duskblade wins where the Ashwarden dies here | Net |
|---|---|---|---:|---:|---:|
| 1 | 64 (6.4% of 1,000) | 203 (20.3% of 1,000) | 126 | 32 | +94 |
| 2 | 198 (21.2% of 936) | 143 (17.9% of 797) | 91 | 93 | −2 |
| 3 | 110 (14.9% of 738) | 160 (24.5% of 654) | 94 | 52 | +42 |

- **Act 1 carries most of the gap.** 94 of the 134 seeds the gap is made of (311 − 177) come from Act 1, where the Duskblade's A_lit dies three times as often. Act 3 adds 42; Act 2 is level. Act bosses take 89% of the Duskblade's A_lit deaths and 66% of the Ashwarden's.
- **Which arms.** Only A_lit is read for the Duskblade under `s3` (the contract's fourth batch). Readout 14's Duskblade table at V0 full, under `s2` on 1.0's content, puts every Duskblade arm below the Ashwarden's here: committed 40.6–50.5% against 68.6–85.6%, A 40.5% against 52.4%, R 18.2% against 28.7%. `s3` moves the Duskblade little (in #544 P6b's sample, no arm's paired change was significant), so this comparison is indicative, not graded.
- **What moved since readout A0.** The Ashwarden's A_lit rose from 58.7% to 62.8% with the ways, the lantern and the exclusions in content, and the Duskblade's from 48.2% (`s2`) to 49.4% (`s3`). This reading cannot split the Ashwarden's rise between its content and `s3`.

## The starter as the class's engine

Smolder's share of the kills in each arm's won fights (lock §14, open item), by `killshare.py`: over the fights a run won, the Smolder kills of the fight row (the enemy phase's lethal Smolder ticks, the blows #544 A3 counts as `smolderKills`) over the enemies the fight opened with.

| Cell | C_smolder | C_hand | C_endure | A | A_lit | R |
|---|---:|---:|---:|---:|---:|---:|
| V0 entry | 79.2% | 77.9% | 86.8% | 78.0% | 78.7% | 79.0% |
| V0 full | 85.6% | 83.6% | 84.9% | 84.3% | 84.4% | 80.3% |
| V5 entry | 82.0% | 79.0% | 87.1% | 81.2% | 82.5% | 80.6% |
| V5 full | 88.0% | 85.6% | 85.5% | 85.7% | 86.0% | 82.1% |
| V5 full, 4,000 seeds | 88.1% | 85.4% | 85.5% | | 86.1% | |

Readout A0 measured 61–77% on development seeds under `s2` (C_endure 77.2%, C_smolder 67.3% at V0 `entry`). The reading of record shows the same, and more so: **Smolder makes 78–88% of the kills in won fights, in every arm and every cell.** The ways' own decks show where it comes from. Mean copies in winning decks at run end:

| Cell | Arm | Ash Bite | Smother | Smolder's own glass (Emberbite, Ashcloud, Requiem, Bellows, Emberfang, Ashen Choir) | Deck |
|---|---|---:|---:|---:|---:|
| V0 entry | C_smolder | 4.00 | 2.20 | 5.22 | 33.0 |
| V0 entry | C_hand | 4.00 | 0.21 | 1.45 | 40.6 |
| V0 entry | C_endure | 4.00 | 2.03 | 1.52 | 40.8 |
| V0 full | C_smolder | 4.00 | 2.07 | 12.99 | 36.5 |
| V0 full | C_hand | 4.00 | 0.39 | 2.26 | 40.9 |
| V0 full | C_endure | 4.00 | 2.04 | 2.37 | 40.4 |
| V5 entry | C_hand | 4.00 | 0.13 | 1.35 | 42.5 |
| V5 entry | C_endure | 4.00 | 2.02 | 1.12 | 42.6 |
| V5 full | C_hand | 4.00 | 0.32 | 2.72 | 42.6 |
| V5 full | C_endure | 4.00 | 2.03 | 2.45 | 42.2 |

A committed Hand deck has removed its Smothers and holds 1.4–2.7 cards of Smolder's glass in 41–43, yet Smolder makes 78–86% of its kills. A committed Endure deck holds 1.1–2.5 such cards and takes 85–87% of its kills by Smolder, more than committed Smolder takes at V0 `entry` (79.2%). The kills come from the class's starter (four Ash Bites, Ashen Core, Ashfall) whatever the way. Part of the rise from readout A0 may be the instrument: `s3` credits a Smolder tick that kills before the enemy acts, `s2` did not, and this reading cannot split the two.

**How `killshare.py` was validated.** It was recovered from the 5 October session's transcript. Readout A0's rows, on which its first owner checked it, lived in a scratch folder the 5 October reboot wiped, so the check against A0's 61–77% could not be repeated. It was validated instead on this reading's own 44,000 Ashwarden runs (`validate_killshare.py`):

1. **The numerator against the domain's own count.** The fight row's `smolderKills` is the simulator's re-count of the combat event queue (`_fight` in `tools/balance_sim.gd`). `combat.gd` counts the same blows into `run.stats.smolderKills` (#544 A3), which every row reports as a per-fight rate. In every one of the 44,000 runs, the fight rows' sum equals rate × fights exactly.
2. **The denominator.** No enemy joins a fight after it starts (`combat.gd` adds enemies only when combat starts), and a fight is won when its last enemy dies (`_on_enemy_death`). The one exception, a finale boss taken to its handoff at 1 HP, is the Eternal Keeper, who appears in none of these runs. So every enemy a won fight opened with died once, and in none of 824,329 won fights does Smolder have more kills than the fight had enemies. The share is exact, not the upper bound the script's docstring allows for summons.
3. **An independent re-implementation** of the share, written from the definition, equals `killshare.py`'s figures in every report.

One defect was found and worked around: the script's default cell detection strips the cell name to its vow (`v0`) and prints nothing, so every command names its cells.

## The lead way

The lock's §14: a way that leads G2 by a decided margin in a reading of record gets its wall lane (A8) before any content PR that strengthens it, and A5c's Endure payoff is then designed as a trade.

| Cell | Endure − worst way (G2) | Paired 95% | Endure − next way | Paired 95% |
|---|---|---|---|---|
| V0 entry | +59.0 pp (Smolder) | +55.7 to +62.1 | +10.3 pp (Hand) | +7.7 to +12.9 |
| V0 full | +17.0 pp (Smolder) | +13.4 to +20.6 | +11.9 pp (Hand) | +8.4 to +15.4 |
| V5 entry | +75.4 pp (Smolder) | +73.3 to +77.4 | +56.1 pp (Hand) | +53.6 to +58.5 |
| V5 full, 4,000 seeds | +38.8 pp (Hand) | +36.8 to +40.8 | +31.8 pp (Smolder) | +29.7 to +33.8 |

**Endure leads G2 by a decided margin in every cell**, the reading readout A0 gave the phrase: G2's spread, Endure over the worst way, is a decided FAIL in all four cells. Over the next-best way, its lead is decided above 10 pp at V5; at V0 it is above 10 pp on point and UNDECIDED on interval. No other way leads any cell.

## The walls

Where each arm dies: deaths by the act of the lost run's last fight, as a share of the runs alive at that act's start, and the share of all deaths that came in a boss, an elite or a normal fight.

| Cell | Arm | Win | Deaths, Acts 1 / 2 / 3 | Of runs alive, Acts 1 / 2 / 3 | Boss / elite / normal |
|---|---|---:|---|---|---|
| V0 entry | C_smolder | 35.6% | 70 / 294 / 280 | 7.0 / 31.6 / 44.0% | 78 / 15 / 7% |
| V0 entry | C_hand | 84.3% | 32 / 24 / 101 | 3.2 / 2.5 / 10.7% | 84 / 12 / 4% |
| V0 entry | C_endure | 94.6% | 15 / 28 / 11 | 1.5 / 2.8 / 1.1% | 87 / 11 / 2% |
| V0 entry | A | 49.0% | 123 / 234 / 153 | 12.3 / 26.7 / 23.8% | 81 / 11 / 8% |
| V0 entry | A_lit | 55.3% | 113 / 200 / 134 | 11.3 / 22.5 / 19.5% | 84 / 8 / 8% |
| V0 entry | R | 26.3% | 220 / 364 / 153 | 22.0 / 46.7 / 36.8% | 83 / 8 / 9% |
| V0 full | C_smolder | 68.6% | 19 / 104 / 191 | 1.9 / 10.6 / 21.8% | 64 / 27 / 9% |
| V0 full | C_hand | 73.7% | 29 / 57 / 177 | 2.9 / 5.9 / 19.4% | 71 / 22 / 6% |
| V0 full | C_endure | 85.6% | 44 / 75 / 25 | 4.4 / 7.8 / 2.8% | 78 / 8 / 14% |
| V0 full | A | 52.4% | 77 / 258 / 141 | 7.7 / 28.0 / 21.2% | 65 / 12 / 23% |
| V0 full | A_lit | 62.8% | 64 / 198 / 110 | 6.4 / 21.2 / 14.9% | 66 / 12 / 22% |
| V0 full | R | 28.7% | 171 / 369 / 173 | 17.1 / 44.5 / 37.6% | 75 / 11 / 14% |
| V5 entry | C_smolder | 10.4% | 892 / 660 / 239 | 44.6 / 59.6 / 53.3% | 83 / 7 / 10% |
| V5 entry | C_hand | 29.8% | 497 / 382 / 525 | 24.9 / 25.4 / 46.8% | 86 / 10 / 4% |
| V5 entry | C_endure | 85.9% | 147 / 96 / 39 | 7.3 / 5.2 / 2.2% | 85 / 11 / 4% |
| V5 entry | A | 26.3% | 802 / 517 / 155 | 40.1 / 43.2 / 22.8% | 82 / 7 / 11% |
| V5 entry | A_lit | 39.1% | 672 / 419 / 126 | 33.6 / 31.6 / 13.9% | 83 / 6 / 11% |
| V5 entry | R | 5.5% | 1,233 / 517 / 140 | 61.6 / 67.4 / 56.0% | 84 / 8 / 8% |
| V5 full | C_smolder | 37.3% | 332 / 537 / 385 | 16.6 / 32.2 / 34.0% | 68 / 14 / 18% |
| V5 full | C_hand | 31.2% | 446 / 481 / 448 | 22.3 / 31.0 / 41.8% | 76 / 12 / 13% |
| V5 full | C_endure | 69.5% | 340 / 206 / 65 | 17.0 / 12.4 / 4.5% | 74 / 9 / 17% |
| V5 full | A | 25.6% | 624 / 672 / 192 | 31.2 / 48.8 / 27.3% | 63 / 9 / 27% |
| V5 full | A_lit | 35.3% | 565 / 566 / 163 | 28.2 / 39.4 / 18.8% | 66 / 8 / 26% |
| V5 full | R | 7.9% | 1,011 / 656 / 175 | 50.5 / 66.3 / 52.6% | 70 / 10 / 20% |

By way:

- **Smolder.** In the entry pool it dies in Acts 2 and 3: at V0 31.6% and 44.0% of the runs alive, at V5 from Act 1 on. It reaches Steady by the end of Act 1 in 13.5% of the runs alive at V0 `entry`, with Emberbite its only card in that pool, and its flame reads its own way at run end in 56.8% of runs. In the full pool it dies late, in Act 3 (21.8% of the runs alive at V0).
- **Hand.** It dies in Act 3: 10.7% and 19.4% of the runs alive at V0, 46.8% and 41.8% at V5. At V5 it also loses 22–31% of the runs alive in each of Acts 1 and 2.
- **Endure.** It has no wall at V0: at most 7.8% of the runs alive die in any act. At V5 `full` it dies most in Act 1 (17.0%), and less in each act after.
- **Every way's wall is a boss.** Act bosses take 63–87% of the deaths of every arm in every cell.

## The thresholds

**Frozen**, as the lock's §10 sets them: the Duskblade's thresholds and its lock's amendments, the `entry` pool at `fresh`'s, G1 and G4 readings. No amendment is proposed. Every graded figure short of its threshold is one of the walls the lock's §6.7 and §14 named before this reading: Smolder's entry supply, Endure's power and its full-pool reach, and the Hand's full-pool reach. Each is a question for the content and wall lanes (A5, A8), not for a threshold. Two questions of measure, not of threshold, are left to the orchestrator below: how the cross-class trigger reads an interval that straddles +15 pp, and B2's clustered intervals.

## Every graded gate and reading, under P9's definition

`docs/rc-bar.md` P9: G2, G3, G5, G6, G7 and B are graded; G1 and G4 are readings; a figure is *short of its threshold* when it is FAIL on point or FAIL on interval.

**Graded figures short of their thresholds:**

| Cell | Gate | Figure | Point / interval |
|---|---|---|---|
| V0 entry | G2 | C_endure − C_smolder +59.0 pp (+55.6 to +62.2) | FAIL / FAIL |
| V0 full | G2 | C_endure − C_smolder +17.0 pp (+13.4 to +20.6) | FAIL / FAIL |
| V5 entry | G2 | C_endure − C_smolder +75.4 pp (+73.3 to +77.4) | FAIL / FAIL |
| V5 full | G2 | C_endure − C_hand +38.2 pp (+35.3 to +41.0) | FAIL / FAIL |
| V0 entry | G3 | −39.3 pp (paired −42.6 to −35.9) | FAIL / FAIL |
| V0 full | G3 | −22.8 pp (paired −26.3 to −19.2) | FAIL / FAIL |
| V5 entry | G3 | −46.8 pp (paired −49.2 to −44.2) | FAIL / FAIL |
| V5 full, 4,000 seeds | G3 | −34.3 pp (paired −36.3 to −32.3) | FAIL / FAIL |
| V0 entry | G5 | C_smolder Steady 13.5% of runs alive (11.5–15.9) | FAIL / FAIL |
| V0 full | G5 | C_endure Steady 57.4% (54.3–60.5) and True 19.6% (17.1–22.4); C_hand Steady 68.5% (65.5–71.3) and True 33.9% (30.9–37.0) | FAIL / FAIL, except C_hand's Steady FAIL / UNDECIDED |
| V5 full | G5 | C_hand True 32.3% (29.6–35.2); C_endure True 31.4% (29.1–33.9) | FAIL / FAIL |
| V5 entry | G6 | Endure 81.9% of A_lit's wins (79.0–84.4) | FAIL / FAIL |
| V5 full | G6 | Smolder 68.4% of A_lit's wins (64.9–71.7) | FAIL / FAIL |
| V0 entry | B2 | C_smolder expression 59.1% (58.4–59.8; clustered 57.5–60.7) | FAIL / FAIL (clustered UNDECIDED) |
| V0 entry | B2 | C_endure close calls 0.43% (0.36–0.52; clustered 0.32–0.56) | FAIL / FAIL |
| V0 entry | B2 | A_lit expression 59.0% (58.3–59.6; clustered 57.5–60.5) | FAIL / FAIL (clustered UNDECIDED) |
| V0 full | B2 | C_endure close calls 0.91% (0.80–1.04) | FAIL / UNDECIDED |

**Not short:** G6 at V0 in both pools (PASS / PASS); G7 in every cell; B1 for every committed way and A_lit in both pools; B2 for committed Hand in both pools and for committed Smolder and A_lit at V0 `full`; G5 for committed Smolder in both full-pool cells, and Steady for committed Hand and Endure at V0 `entry` and V5 `full` (Endure's at V5 `full` UNDECIDED on interval).

**Readings (never graded):** G1 fails at V0 `entry` (C_smolder 35.6%, FAIL / FAIL) and passes at V0 `full` (68.6%) and V5 `full` (C_hand 31.2%), both PASS / PASS. G4 fails at V0 `entry` (R 26.3%, 9.3 pp under committed Smolder: FAIL / FAIL) and V5 `entry` (FAIL / FAIL), fails on point at V5 `full` (−23.4 pp, UNDECIDED), and passes at V0 `full` (−39.9 pp, PASS / PASS). The floors: arm A's G3 floor fails everywhere; its G6 floor fails at V0 `entry` (Endure 60.2%, UNDECIDED) and at V5, and passes at V0 `full`.

## What the orchestrator must decide

The readout gives no verdict. The reading raises these questions:

1. **The lead way.** Endure leads G2 by a decided margin in every cell. Under the lock's §14 its wall lane (A8) comes before any content PR that strengthens it, and A5c's payoff becomes a trade. Does the order of §12 change accordingly?
2. **The starter as the engine.** Smolder makes 78–88% of the kills in every arm's won fights, more than readout A0's 61–77%, and the committed Hand and Endure decks take 78–87% of theirs by it. The lock's §14 says the orchestrator then reopens #544 decision 2 (the starter unchanged) before A8.
3. **The cross-class trigger.** +13.4 pp is under the +15 pp line on point, but its paired interval (+9.1 to +17.6) reaches above it. Readout A0 read the trigger on the point. If the trigger reads the interval, a diagnosis is owed: Act 1 carries 94 of the gap's 134 net seeds. Which reading does the lock's §10 intend?
4. **Smolder's entry pool.** 35.6% at V0 `entry`, Steady by the end of Act 1 in 13.5% of the runs alive, and 10.4% at V5 `entry`: the supply wall readout A0 named, unchanged on the bands of record. It is A5a's.
5. **The Hand at V5.** 84.3% and 73.7% at V0, but 29.8% and 31.2% at V5, and its full-pool True reach 33.9% and 32.3%. Is this a wall the A5b payoff answers, or a second one?
6. **G6 at V5.** One way takes A_lit's wins at each V5 cell: Endure 81.9% in the entry pool, Smolder 68.4% in the full pool. Both are decided FAILs.
7. **B2 and clustering.** Committed Smolder's and A_lit's expression at V0 `entry` (59.1% and 59.0%) are decided FAILs under the grader and UNDECIDED clustered by run; the runbook asks for the clustered reading before such a figure is called decided. Committed Endure's close calls (0.43%) fail however they are counted: its fights are almost never close.
8. **The commit-blind arms' crowns.** Every winning run of arms A and A_lit at V0 holds the Hollow Crown and the Crown of the Hearth, whatever its flame reads at run end (the Duskblade's A_lit: the Hollow Crown in 89% of its wins, its crowns split). The pilot's relic weights, the same in every manifest of both classes, put the Hollow Crown first of all relics (129.5) and the Crown of the Hearth above the other two way crowns (61.1, against 58.0 and 53.5). Does that shape A_lit's G3 and G6 figures enough to matter before A9?
9. **R's strength.** At V0 `entry` R wins 26.3%, 9.3 pp under committed Smolder, and its won fights take 79% of their kills by Smolder. G4 is a reading, but its intent, that scattering loses, is read from it.

## What the next readout should ask

1. **A8, Endure's wall lane**, first by the lead-way rule: what makes committed Endure win 85–95% at V0, and does a trade bring it within 10 pp of the next way without moving the Duskblade?
2. **A5a, Smolder's entry supply**: does three or four base-pool Smolder cards lift its Steady by the end of Act 1 at V0 `entry` over 40%?
3. **The starter**, if decision 2 is reopened: how much of every way's kill share moves when the starter's Smolder does?
4. **The cross-class reading** at A9, on the combined product with both classes under `s3`, and with every Duskblade arm beside the Ashwarden's if a diagnosis is owed.

## Tests and pins

No test or pin moved: this PR changes documents, plus the usage text and one docstring in `tools/balance_ways.py` and `tools/balance_readout.py` (they name `s3`). Every `tests/test_balance_*.py`, run as a script, passes at this PR's head; `tests/test_balance_exam.py`, which CI does not run, passes with an `override.cfg` written for the run and removed after (runbook §12). No Godot code changed, so the Godot gate is not inherited.

## Appendix: the scripts

The tables and gates come from the repository's runner and graders (`tools/balance_readout.py`, `tools/balance_ways.py`). Ten short scripts in the lane's durable scratch folder read the merged reports; none writes to them. The raw rows (1.1 GB, the 4,000-seed join included), the driver and its status log stay outside the repository, in the lane's durable storage.

| Script | What it does |
|---|---|
| `killshare.py` | Smolder's share of the kills in each arm's won fights. Recovered from the 5 October session; name the cells, since its default detection prints nothing |
| `validate_killshare.py` | The three checks above: fight rows against the domain's `smolderKills`, kills against enemies, and an independent re-implementation |
| `crossclass.py` | The cross-class reading: Newcombe's paired interval and the exact p through `balance_readout_stats`; refuses a pair whose commit, content or bots differ |
| `crossclass_acts.py` | The cross-class gap by act, paired on seed |
| `lead_and_guards.py` | Endure's lead over each other way, independent and paired; G7's counts and every manifest's commit, content and bots |
| `g5_ways.py` | G5 for each committed way, on point and interval |
| `rowb_point.py` | Row B's point verdicts beside the grader's interval verdicts |
| `rowb_cluster.py` | B2's figures with a run-clustered bootstrap interval |
| `walls.py` | Deaths by act, as a share of the runs alive, and by kind of fight |
| `smolder_decks.py` | The starter's and Smolder's own glass in winning decks |
