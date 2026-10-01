# Readout 8: the bot round

> **Instrument reading (AI-SDLC discovery), promoted in one PR.** No balance knob, content value, domain rule or `port_fixtures/` golden moved. The PR adds a stronger combat player to the simulator (`tools/balance_search.gd`), per-fight feel data on the simulator's flame row, a feel table and 95%-interval verdicts in the cell-table grader (`tools/balance_ways.py`), and replaces the lock's human row with a bot round (§11, row B). Every number below comes from the shipped catalogue on `main` with the baseline hardship of #623 (`content/full-content.json`, SHA-256 `22f2662d9055b17e129e68f67125a858f3a4f54f545f789b9999d5756f22fd7b`; `hardship.mods`: enemy HP ×1.15, enemy damage +1, elite facets +1).
>
> **Head.** Every table ran at `d23db74b31c13549e6ed77446bc1435de3c93e06`, this PR's first commit (base `main` at `3466a885`), which every report's manifest names. Later commits add tests, the grader's `--vows` option and footer, and documents; none changes the simulator, the pilot or the search player (`git diff d23db74b..HEAD -- tools/*.gd` is empty).

The owner ruled on 1 October that bots play instead of people: "My input is important but should not stop the work. The human play sample is not sufficient." Then: the bot round runs in the headless simulator, at the lock's 200 paired seeds per cell at least and as many more as about an hour of wall time allows, every gate figure with its 95% interval, and a gate whose interval straddles its threshold is undecided. This readout builds the stronger player, runs the lock's §11 cell table for it and for the greedy pilot, and reads what the bots can say about each way's feel.

## The answer in brief

- **The search player is markedly stronger, and the gap is not even.** Paired over 1,000 seeds per arm, it wins more for every arm in every V0 cell (p < 0.001 each): at V0 full committed Shatter 26.0% to 38.0%, Lantern 21.2% to 37.1%, Edge 7.0% to 14.4%, A 27.2% to 38.2%, R 8.9% to 19.0%. The greedy pilot understates the Lantern most (+15.9 pp) and Edge least (+7.4 pp), so greedy readings bias parity (G2) as well as viability (G1).
- **G1–G7 with the search player.** G1 fails in every graded cell (the best committed way reaches 38.0% at V0 full against the 50% floor; the worst, Edge, 14.4%). G2 fails at V0 (Shatter − Edge +23.6 pp at V0 full, interval +19.8 to +27.3). G3 is undecided at V0 (A level with the best way, ±4 pp). G4 fails everywhere and more clearly than with greedy play: at V0 full the random build wins 19.0%, *more* than committed Edge (+4.6 pp, interval +1.3 to +7.9). G5 fails at V0 full and is undecided at V0 fresh. G6 fails at V0 full: 83.0% of the adaptive arm's 382 wins end Edge-led. G7 passes everywhere: no stall, no error, every replay identical, and no planned action was refused.
- **B, the bot round: not met, on Edge alone.** B1 (each committed way wins at V0: ≥ 20% full, ≥ 10% fresh): Shatter (38.0%, 13.0%) and the Lantern (37.1%, 23.3%) pass in both pools; Edge fails in both (14.4%, 5.7%). B2 (no way has no feel): Shatter and Edge pass in both pools; the Lantern is undecided in both, its close calls sitting on the 1% floor (1.1% full, 1.0% fresh) and its fresh-pool expression on the 60% line (59.9%, interval 59.2–60.7%).
- **Edge's wall is still Act 2, and Edge is strong only as a splash.** With the search player, 444 of committed Edge's 856 deaths at V0 full come in Act 2, as in readout 7, while the adaptive arm's wins are 83% Edge-led. Edge glass wins when it supports a deck and loses when it is the deck.
- **Feel proxies by way (search, V0 full):** turns per fight Shatter 3.38, Lantern 3.28, Edge 3.04; HP lost per fight 10.75, 11.91, 11.52; close calls 1.3%, 1.1%, 2.8%; expression 72.3%, 70.6%, 79.4%. Edge fights are the shortest, the most often close and the most visibly Edge; Lantern fights are the safest.
- **Instrument.** 1,000 paired seeds (13000–13999) per cell at V0 for both players and at V5 for greedy; the search player's V5 cells were cut to 400 seeds (13000–13399) to fit the hour (see [cost](#cost-and-the-seed-count)). 20,012 greedy and 14,012 search run rows. The greedy table took 144 s, the search table 52 minutes on a host shared with other sessions (load average above 200).

## The search player

The greedy pilot (`p8-d0-v2`) plays one best-scored card at a time. The search player (`tools/balance_search.gd`, version `s1`) is the same pilot off the board (routes, rewards, shops, removals, events, potions) and a stronger player on it.

- **Search.** Each turn, after the pilot's potions, it enumerates every legal line of plays, kindles and the Art, depth first, on a detached copy of the fight (`clone_run`, `clone_combat`), applying each action through the combat rules' own functions, the ones `GlassvowGame.apply` dispatches to (`play_card`, `kindle_from_hand`, `use_art`). Depth is bounded by the hand and pruned by legality (Energy, Embers, targets). Identical cards are tried once per position, transposed orders are searched once (a position key over hand, foes, hero, lantern and the way stats), and at most 2,000 lines are evaluated per plan. The kindle it may try is the pilot's own choice (the hand's worst-scored card), so a line never burns a card the pilot would keep.
- **Honest play.** A line ends at the action that draws a card or moves the run's RNG. The search therefore never reads an undrawn card; it plays the line, and re-plans once the draw has resolved. The enemy forecast is the pilot's own (`incoming_on`, the forecast `_incoming` already used), which copies the RNG state to forecast Smolder jumps without moving it. No other randomness enters: the run's seeded RNG is the only source, and a seeded run replays exactly.
- **One-turn evaluation.** A line is scored as the turn would end there: the HP the coming enemy phase would take, weighted by the policy's `blockNormal`, or `blockUrgent` when the turn opens facing at least half the hero's HP; damage dealt at the policy's `combat.loss`; 20 per kill and 15 per new Stagger; facet chips at the policy's `combat.chip`; half the catalogue worth of the Cracked, Dimmed and Smolder laid on living foes and of the hero's own buffs; Embers at the policy's `card.ember`; and 2 for each Shatter, Kindle and stack of Cracked, the three ways' verbs. A won fight scores above everything; a line that dies to the forecast blow below everything. The four constants (kill 20, Stagger 15, expression 2, setup share 0.5) were set before any run and checked once on development seeds 12000–12099 (arm A, V0 full): 33 wins against greedy's 20, and 1,784 fights won against 1,482. They were not tuned on the calibration seeds.
- **Never below the baseline.** The pilot's own turn is played on a further copy and scored the same way; the search plays it whenever no searched line scores higher, ties included. On development seeds about 70% of plans adopt it. A plan evaluates 82–102 lines on average.
- **Commitment-blind.** The evaluation reads no `way`. Every arm plays its fights alike, as the lock requires; only the build differs.

**Tests** (`tests/test_balance_search.gd`): over an Act-1 normal fight, elite and boss on three seeds, planning leaves the live fight byte for byte unchanged; every planned action is legal live; and a copy that plays the planned line ends exactly where the live fight ends. A seeded search run replays, outcome digest and flame rows alike. On 60 fixed fights (an Act-1 normal fight, elite and boss on each of seeds 12000–12019, both players from identical starts) the search wins at least as many fights and loses no more HP: 40 won and 1,934 HP lost against greedy's 40 and 1,992. A mutant that inverts the damage term fails this guard (20 won, 2,941 HP lost). A mutant that inverts the HP term does not (40 won, 1,940 HP lost): in Act-1 fights with the starter deck the HP term rarely decides a line, so the guard is a floor on play strength, not a test of every weight. The 1,000-seed comparison below is the strength reading.

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root,
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-bots", removed before each commit.
# Greedy pilot, the full table:
python3 -B tools/balance_ways.py --seeds 13000-13999 --jobs 10 --out-dir <dir>/r8-greedy
# Search player, V0 cells (launched as the full table; its V5 jobs were stopped, see below):
python3 -B tools/balance_ways.py --seeds 13000-13999 --jobs 10 --play search --out-dir <dir>/r8-search
# Search player, V5 cells at 400 seeds. Run before --vows existed, by a wrapper over the grader's own
# jobs() filtered to vow 5 (12 jobs at once); the equivalent command on this PR's head is:
python3 -B tools/balance_ways.py --seeds 13000-13399 --vows 5 --jobs 12 --play search --out-dir <dir>/r8-search-v5
# Grading:
python3 -B tools/balance_ways.py --from-dir <dir>/r8-search --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir <dir>/r8-search-v5 --seeds 13000-13399 --vows 5
```

- **Cells, arms, seeds.** The lock's §11 table: Duskblade (aspect 0), vows 0 and 5 with the shipping incentives, fresh and full pools, five arms (C_shatter, C_lantern and C_edge committed; A adaptive; R random build), paired seeds across arms. 1,000 seeds, 13000–13999: the lock's calibration band 13000–13399 extended by 13400–13999, which no earlier readout, the development band (12000–12999), the CEM bands or the acceptance band (3000–5199) uses. The search player's V5 cells use 13000–13399.
- **The greedy table on 400 seeds.** For the V5 comparison the greedy V5 reports are trimmed to seeds 13000–13399; each run depends only on its seed, so a trimmed report is the 400-seed run.
- **Measures.** The grader's own G1–G7 (readout 7 states them). Each gate is graded twice: on the point estimate, as readouts 1–7 did, and on its 95% interval, Wilson for a rate and Newcombe's hybrid score interval (built from two Wilson intervals) for a difference between arms. A gate passes on its interval when every part clears its threshold, fails when any part is beyond it, and is otherwise UNDECIDED. The difference interval treats the arms as independent; the seeds are paired, so the true interval is narrower and an UNDECIDED is conservative.
- **Feel proxies**, per arm, from the per-fight rows the simulator now writes on the flame row (outside the outcome digest): turns and HP lost per fight; **close calls**, the share of won fights the hero leaves under 20% of max HP; **way expression**, the share of fights whose coloured plays (each play weighted by the card's affinity, the purity function's own table) favour the arm's way, its committed way for C arms and the flame's dominant way at the fight's start for A and R (a tie or no coloured play expresses nothing); and deaths by act (the act of a lost run's last fight).
- **Paired tests** count the seeds one player wins and the other loses, with the exact two-sided binomial p.

### Cost and the seed count

| Player | Cost per run, one process alone | Under this run's load | Table |
|---|---|---|---|
| Greedy | 47–52 ms | 7 ms of wall per run over 10 jobs | 1,000 seeds, every cell: 144 s |
| Search | 1.4–1.7 s (V0 full, 6 processes) | 1.2 s (V0 fresh, R) to 3.1 s (V0 full, Shatter) per run per job | V0 at 1,000 seeds and V5 at 400: 52 min |

The search table launched at 1,000 seeds per cell. Twenty minutes in, its first job had finished at 1.2 s per run, which put the whole table at 90–100 minutes on this host. To fit the hour, its V5 jobs were stopped before they ran (one had begun and was discarded) and the V5 cells were run at 400 seeds beside the V0 jobs. V0 holds G1's 50% and 40% floors and both B criteria, so it kept the full 1,000.

## Search against greedy, paired

| Cell | Arm | N | Greedy | Search | Lift | Gained / lost, p |
|---|---|---:|---:|---:|---:|---|
| V0 fresh | C_shatter | 1000 | 4.5% | 13.0% | +8.5 pp | 123 / 38, p < 0.001 |
| V0 fresh | C_lantern | 1000 | 13.7% | 23.3% | +9.6 pp | 188 / 92, p < 0.001 |
| V0 fresh | C_edge | 1000 | 1.8% | 5.7% | +3.9 pp | 53 / 14, p < 0.001 |
| V0 fresh | A | 1000 | 10.3% | 21.5% | +11.2 pp | 185 / 73, p < 0.001 |
| V0 fresh | R | 1000 | 1.1% | 5.5% | +4.4 pp | 55 / 11, p < 0.001 |
| V0 full | C_shatter | 1000 | 26.0% | 38.0% | +12.0 pp | 260 / 140, p < 0.001 |
| V0 full | C_lantern | 1000 | 21.2% | 37.1% | +15.9 pp | 262 / 103, p < 0.001 |
| V0 full | C_edge | 1000 | 7.0% | 14.4% | +7.4 pp | 131 / 57, p < 0.001 |
| V0 full | A | 1000 | 27.2% | 38.2% | +11.0 pp | 256 / 146, p < 0.001 |
| V0 full | R | 1000 | 8.9% | 19.0% | +10.1 pp | 158 / 57, p < 0.001 |
| V5 fresh | C_shatter | 400 | 0.2% | 0.0% | -0.2 pp | 0 / 1, p = 1.000 |
| V5 fresh | C_lantern | 400 | 1.0% | 3.0% | +2.0 pp | 10 / 2, p = 0.039 |
| V5 fresh | C_edge | 400 | 0.0% | 0.2% | +0.2 pp | 1 / 0, p = 1.000 |
| V5 fresh | A | 400 | 0.5% | 1.2% | +0.8 pp | 5 / 2, p = 0.453 |
| V5 fresh | R | 400 | 0.0% | 0.2% | +0.2 pp | 1 / 0, p = 1.000 |
| V5 full | C_shatter | 400 | 5.8% | 12.2% | +6.5 pp | 42 / 16, p < 0.001 |
| V5 full | C_lantern | 400 | 5.5% | 10.2% | +4.8 pp | 36 / 17, p = 0.013 |
| V5 full | C_edge | 400 | 0.5% | 2.5% | +2.0 pp | 9 / 1, p = 0.021 |
| V5 full | A | 400 | 6.0% | 10.8% | +4.8 pp | 40 / 21, p = 0.020 |
| V5 full | R | 400 | 2.5% | 5.2% | +2.8 pp | 17 / 6, p = 0.035 |

The baseline hardship is visible against readout 7: its shipped catalogue gave the greedy pilot 47.5% for committed Shatter and for the Lantern at V0 full on 13000–13199. The content has changed since only by #623's hardship block, and greedy now wins 26.0% and 21.2%.

## G1–G7, both players

Verdicts as point / 95% interval. N is the seeds per arm.

| Cell | Player | N | G1 | G2 | G3 | G4 | G5 | G6 | G7 |
|---|---|---:|---|---|---|---|---|---|---|
| V0 fresh | greedy | 1000 | FAIL / FAIL | FAIL / UNDECIDED | FAIL / UNDECIDED | FAIL / FAIL | FAIL / FAIL | PASS / UNDECIDED | PASS / PASS |
| V0 fresh | search | 1000 | FAIL / FAIL | FAIL / FAIL | PASS / UNDECIDED | FAIL / FAIL | PASS / UNDECIDED | FAIL / UNDECIDED | PASS / PASS |
| V0 full | greedy | 1000 | FAIL / FAIL | FAIL / FAIL | PASS / PASS | FAIL / FAIL | FAIL / FAIL | FAIL / FAIL | PASS / PASS |
| V0 full | search | 1000 | FAIL / FAIL | FAIL / FAIL | PASS / UNDECIDED | FAIL / FAIL | FAIL / FAIL | FAIL / FAIL | PASS / PASS |
| V5 fresh | greedy | 400 | n/a / n/a | PASS / PASS | PASS / PASS | FAIL / FAIL | n/a / n/a | FAIL / UNDECIDED | PASS / PASS |
| V5 fresh | search | 400 | n/a / n/a | PASS / PASS | PASS / UNDECIDED | FAIL / FAIL | n/a / n/a | FAIL / UNDECIDED | PASS / PASS |
| V5 full | greedy | 400 | FAIL / FAIL | PASS / PASS | PASS / UNDECIDED | FAIL / FAIL | FAIL / FAIL | FAIL / FAIL | PASS / PASS |
| V5 full | search | 400 | FAIL / FAIL | PASS / UNDECIDED | PASS / UNDECIDED | FAIL / FAIL | FAIL / FAIL | FAIL / FAIL | PASS / PASS |

The greedy table's V5 cells on all 1,000 seeds give the same verdicts as on 400, except G6 at V5 fresh (PASS / UNDECIDED on 6 A wins) and G3 at V5 full (PASS / PASS).

### The figures behind them

| Cell | Player | Gate | Measured (95% interval, N) | 95% verdict |
|---|---|---|---|---|
| V0 fresh | greedy | G1 | worst C_edge 1.8% (1.1%-2.8%, n=1000) | FAIL |
| V0 fresh | greedy | G2 | C_lantern - C_edge +11.9 pp (+9.7 to +14.3, n=1000+1000) | UNDECIDED |
| V0 fresh | greedy | G3 | A - C_lantern -3.4 pp (-6.3 to -0.5, n=1000+1000) | UNDECIDED |
| V0 fresh | greedy | G4 | R - C_edge -0.7 pp (-1.8 to +0.4, n=1000+1000); R 1.1% (0.6%-2.0%, n=1000) | FAIL |
| V0 fresh | greedy | G5 | Steady min C_edge 35.0% (32.1%-38.0%, n=1000) | FAIL |
| V0 fresh | greedy | G6 | lead edge 53.4% (43.8%-62.7%, n=103 A wins) | UNDECIDED |
| V0 fresh | greedy | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V0 fresh | search | G1 | worst C_edge 5.7% (4.4%-7.3%, n=1000) | FAIL |
| V0 fresh | search | G2 | C_lantern - C_edge +17.6 pp (+14.6 to +20.6, n=1000+1000) | FAIL |
| V0 fresh | search | G3 | A - C_lantern -1.8 pp (-5.4 to +1.9, n=1000+1000) | UNDECIDED |
| V0 fresh | search | G4 | R - C_edge -0.2 pp (-2.2 to +1.8, n=1000+1000); R 5.5% (4.2%-7.1%, n=1000) | FAIL |
| V0 fresh | search | G5 | Steady min C_lantern 42.7% (39.7%-45.8%, n=1000) | UNDECIDED |
| V0 fresh | search | G6 | lead edge 60.9% (54.3%-67.2%, n=215 A wins) | UNDECIDED |
| V0 fresh | search | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V0 full | greedy | G1 | worst C_edge 7.0% (5.6%-8.8%, n=1000) | FAIL |
| V0 full | greedy | G2 | C_shatter - C_edge +19.0 pp (+15.8 to +22.1, n=1000+1000) | FAIL |
| V0 full | greedy | G3 | A - C_shatter +1.2 pp (-2.7 to +5.1, n=1000+1000) | PASS |
| V0 full | greedy | G4 | R - C_edge +1.9 pp (-0.5 to +4.3, n=1000+1000); R 8.9% (7.3%-10.8%, n=1000) | FAIL |
| V0 full | greedy | G5 | Steady min C_shatter 41.6% (38.6%-44.7%); True min C_shatter 5.2% (4.0%-6.8%), n=1000 | FAIL |
| V0 full | greedy | G6 | lead edge 78.3% (73.0%-82.8%, n=272 A wins) | FAIL |
| V0 full | greedy | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V0 full | search | G1 | worst C_edge 14.4% (12.4%-16.7%, n=1000) | FAIL |
| V0 full | search | G2 | C_shatter - C_edge +23.6 pp (+19.8 to +27.3, n=1000+1000) | FAIL |
| V0 full | search | G3 | A - C_shatter +0.2 pp (-4.1 to +4.4, n=1000+1000) | UNDECIDED |
| V0 full | search | G4 | R - C_edge +4.6 pp (+1.3 to +7.9, n=1000+1000); R 19.0% (16.7%-21.5%, n=1000) | FAIL |
| V0 full | search | G5 | Steady min C_shatter 45.7% (42.6%-48.8%); True min C_shatter 7.0% (5.6%-8.8%), n=1000 | FAIL |
| V0 full | search | G6 | lead edge 83.0% (78.9%-86.4%, n=382 A wins) | FAIL |
| V0 full | search | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V5 fresh | greedy | G1 | worst C_edge 0.0% (0.0%-1.0%, n=400), not graded | n/a |
| V5 fresh | greedy | G2 | C_lantern - C_edge +1.0 pp (-0.1 to +2.5, n=400+400) | PASS |
| V5 fresh | greedy | G3 | A - C_lantern -0.5 pp (-2.1 to +0.9, n=400+400) | PASS |
| V5 fresh | greedy | G4 | R - C_edge +0.0 pp (-1.0 to +1.0, n=400+400); R 0.0% (0.0%-1.0%, n=400) | FAIL |
| V5 fresh | greedy | G5 | Steady min C_edge 2.8% (1.5%-4.9%, n=400), not graded | n/a |
| V5 fresh | greedy | G6 | lead lantern 100.0% (34.2%-100.0%, n=2 A wins) | UNDECIDED |
| V5 fresh | greedy | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V5 fresh | search | G1 | worst C_shatter 0.0% (0.0%-1.0%, n=400), not graded | n/a |
| V5 fresh | search | G2 | C_lantern - C_shatter +3.0 pp (+1.4 to +5.2, n=400+400) | PASS |
| V5 fresh | search | G3 | A - C_lantern -1.7 pp (-4.0 to +0.3, n=400+400) | UNDECIDED |
| V5 fresh | search | G4 | R - C_shatter +0.2 pp (-0.7 to +1.4, n=400+400); R 0.2% (0.0%-1.4%, n=400) | FAIL |
| V5 fresh | search | G5 | Steady min C_edge 12.5% (9.6%-16.1%, n=400), not graded | n/a |
| V5 fresh | search | G6 | lead shatter 80.0% (37.6%-96.4%, n=5 A wins) | UNDECIDED |
| V5 fresh | search | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V5 full | greedy | G1 | worst C_edge 0.5% (0.1%-1.8%, n=400) | FAIL |
| V5 full | greedy | G2 | C_shatter - C_edge +5.3 pp (+3.0 to +8.0, n=400+400) | PASS |
| V5 full | greedy | G3 | A - C_shatter +0.2 pp (-3.1 to +3.6, n=400+400) | UNDECIDED |
| V5 full | greedy | G4 | R - C_edge +2.0 pp (+0.3 to +4.1, n=400+400); R 2.5% (1.4%-4.5%, n=400) | FAIL |
| V5 full | greedy | G5 | Steady min C_shatter 16.2% (13.0%-20.2%); True min C_shatter 0.2% (0.0%-1.4%), n=400 | FAIL |
| V5 full | greedy | G6 | lead edge 87.5% (69.0%-95.7%, n=24 A wins) | FAIL |
| V5 full | greedy | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |
| V5 full | search | G1 | worst C_edge 2.5% (1.4%-4.5%, n=400) | FAIL |
| V5 full | search | G2 | C_shatter - C_edge +9.8 pp (+6.2 to +13.5, n=400+400) | UNDECIDED |
| V5 full | search | G3 | A - C_shatter -1.5 pp (-6.0 to +3.0, n=400+400) | UNDECIDED |
| V5 full | search | G4 | R - C_edge +2.7 pp (+0.0 to +5.6, n=400+400); R 5.2% (3.5%-7.9%, n=400) | FAIL |
| V5 full | search | G5 | Steady min C_shatter 24.2% (20.3%-28.7%); True min C_shatter 0.5% (0.1%-1.8%), n=400 | FAIL |
| V5 full | search | G6 | lead edge 76.7% (62.3%-86.8%, n=43 A wins) | FAIL |
| V5 full | search | G7 | 0 stalls, 0 errors, replay 3/3 | PASS |

G1 is judged on every committed arm (each must clear the floor on its interval) and shown for the worst; G2 on every pair of committed arms and shown for the widest. G5 counts a run that dies before an act ends as not reaching that act's tier, which is why a stronger player lifts it (42.7% against 35.0% at V0 fresh). The CEM stress and the save-lineage check of G7 belong to the exam and were not run here.

## Feel

Per arm, both players. Close calls are a share of won fights; expression a share of all fights.

| Cell | Player | Arm | Turns / fight | HP lost / fight | Close calls | Expression | Deaths Act 1 / 2 / 3 | Wins |
|---|---|---|---:|---:|---:|---:|---|---:|
| V0 fresh | greedy | C_shatter | 3.41 | 11.78 | 2.8% | 65.0% | 555 / 255 / 145 | 45/1000 |
| V0 fresh | greedy | C_lantern | 3.57 | 11.01 | 1.9% | 61.1% | 548 / 160 / 155 | 137/1000 |
| V0 fresh | greedy | C_edge | 3.25 | 12.54 | 3.5% | 70.0% | 572 / 369 / 41 | 18/1000 |
| V0 fresh | greedy | A | 3.49 | 11.06 | 2.4% | 48.1% | 555 / 192 / 150 | 103/1000 |
| V0 fresh | greedy | R | 3.28 | 12.06 | 3.2% | 46.5% | 764 / 162 / 63 | 11/1000 |
| V0 fresh | search | C_shatter | 3.25 | 10.53 | 1.6% | 70.5% | 369 / 275 / 226 | 130/1000 |
| V0 fresh | search | C_lantern | 3.45 | 10.70 | 1.0% | 59.9% | 405 / 179 / 183 | 233/1000 |
| V0 fresh | search | C_edge | 3.15 | 11.65 | 2.8% | 66.9% | 395 / 421 / 127 | 57/1000 |
| V0 fresh | search | A | 3.36 | 9.98 | 1.7% | 48.4% | 415 / 176 / 194 | 215/1000 |
| V0 fresh | search | R | 3.21 | 11.24 | 2.0% | 47.2% | 626 / 189 / 130 | 55/1000 |
| V0 full | greedy | C_shatter | 3.47 | 12.26 | 2.2% | 68.9% | 323 / 272 / 145 | 260/1000 |
| V0 full | greedy | C_lantern | 3.37 | 12.86 | 1.8% | 69.9% | 383 / 208 / 197 | 212/1000 |
| V0 full | greedy | C_edge | 3.08 | 12.88 | 4.1% | 81.2% | 326 / 473 / 131 | 70/1000 |
| V0 full | greedy | A | 3.43 | 12.47 | 2.3% | 54.4% | 352 / 233 / 143 | 272/1000 |
| V0 full | greedy | R | 3.25 | 12.03 | 3.1% | 49.7% | 511 / 263 / 137 | 89/1000 |
| V0 full | search | C_shatter | 3.38 | 10.75 | 1.3% | 72.3% | 201 / 219 / 200 | 380/1000 |
| V0 full | search | C_lantern | 3.28 | 11.91 | 1.1% | 70.6% | 254 / 179 / 196 | 371/1000 |
| V0 full | search | C_edge | 3.04 | 11.52 | 2.8% | 79.4% | 197 / 444 / 215 | 144/1000 |
| V0 full | search | A | 3.38 | 11.37 | 1.5% | 53.6% | 269 / 196 / 153 | 382/1000 |
| V0 full | search | R | 3.17 | 10.67 | 2.2% | 49.8% | 382 / 275 / 153 | 190/1000 |
| V5 fresh | greedy | C_shatter | 3.28 | 13.37 | 5.4% | 56.3% | 367 / 27 / 5 | 1/400 |
| V5 fresh | greedy | C_lantern | 3.48 | 13.23 | 5.0% | 40.9% | 368 / 19 / 9 | 4/400 |
| V5 fresh | greedy | C_edge | 3.24 | 13.62 | 5.8% | 59.0% | 382 / 18 / 0 | 0/400 |
| V5 fresh | greedy | A | 3.42 | 13.18 | 5.3% | 46.2% | 368 / 24 / 6 | 2/400 |
| V5 fresh | greedy | R | 3.13 | 12.78 | 6.2% | 44.1% | 377 / 20 / 3 | 0/400 |
| V5 fresh | search | C_shatter | 3.20 | 12.43 | 2.1% | 61.8% | 325 / 54 / 21 | 0/400 |
| V5 fresh | search | C_lantern | 3.48 | 12.69 | 2.2% | 43.4% | 335 / 31 / 22 | 12/400 |
| V5 fresh | search | C_edge | 3.16 | 12.82 | 3.9% | 56.6% | 332 / 64 / 3 | 1/400 |
| V5 fresh | search | A | 3.33 | 12.12 | 3.0% | 46.5% | 335 / 32 / 28 | 5/400 |
| V5 fresh | search | R | 3.13 | 12.57 | 3.8% | 44.6% | 363 / 29 / 7 | 1/400 |
| V5 full | greedy | C_shatter | 3.39 | 14.20 | 3.6% | 58.5% | 294 / 72 / 11 | 23/400 |
| V5 full | greedy | C_lantern | 3.43 | 14.49 | 3.1% | 60.3% | 292 / 54 / 32 | 22/400 |
| V5 full | greedy | C_edge | 3.09 | 14.01 | 5.2% | 72.8% | 297 / 91 / 10 | 2/400 |
| V5 full | greedy | A | 3.43 | 14.61 | 4.6% | 49.3% | 295 / 63 / 18 | 24/400 |
| V5 full | greedy | R | 3.20 | 13.40 | 5.0% | 46.5% | 327 / 57 / 6 | 10/400 |
| V5 full | search | C_shatter | 3.34 | 12.57 | 2.3% | 65.0% | 243 / 84 / 24 | 49/400 |
| V5 full | search | C_lantern | 3.32 | 13.63 | 2.1% | 60.5% | 255 / 65 / 39 | 41/400 |
| V5 full | search | C_edge | 3.04 | 12.97 | 3.7% | 72.7% | 221 / 140 / 29 | 10/400 |
| V5 full | search | A | 3.39 | 13.25 | 2.5% | 50.3% | 243 / 77 / 37 | 43/400 |
| V5 full | search | R | 3.18 | 12.46 | 3.0% | 46.7% | 289 / 71 / 19 | 21/400 |

**What the proxies say.** Expression separates the arms as it should: at V0 committed decks favour their way in 60–81% of fights, the adaptive and random arms in 46–54%, so the proxy reads commitment and not noise. Edge is the most visible way (79.4% at V0 full), the Lantern the least, and the Lantern's fresh-pool decks barely show their way at V5 (43.4%), where its glass is thinnest. A better player has fewer close calls in every arm (it ends fights with more HP), so close calls are a property of the player as well as of the way, and B reads them for the search player only. The Lantern's fights are the safest (1.0–1.1% close at V0 with search, the floor of B2); Edge's the shortest (3.04 turns) and the closest (2.8%).

## The bot round (B)

The lock's new row B (README §11) asks two things of the search player at V0. The thresholds were written into the lock before the search table was graded (the greedy table was known).

**Why these thresholds.** B1 translates the human row it replaces: a group of three or four players, each winning with every way at least once at V0, is about ten attempts per way across the group. A way that a capable player wins one run in five gives that group a win with it 89% of the time (1 − 0.8¹⁰); one in ten, 65%. The full pool asks the first, the fresh pool, a new player's, the second, as G1 sets the fresh floor under the full one. B2 names a way that "has no feel" two ways: its fights do not look like it, or they carry no stakes. Expression ≥ 60% is ten points above an uncommitted deck (the adaptive arm sits at 48–54%), so a committed way's own glass is what the player does in most fights. Close calls between 1% and 10% of won fights: under 1%, a way never brings the player near the edge; over 10%, one won fight in ten ends near death and the way reads as attrition rather than mastery. The greedy pilot sat at 1.8–4.1% at V0.

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 |
|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 13.0% (11.1%-15.2%, n=1000) | PASS | 70.5% (69.8%-71.2%, n=16754) | 1.6% (1.4%-1.8%, n=15884) | PASS |
| V0 fresh | C_lantern | 23.3% (20.8%-26.0%, n=1000) | PASS | 59.9% (59.2%-60.7%, n=17003) | 1.0% (0.9%-1.2%, n=16236) | UNDECIDED |
| V0 fresh | C_edge | 5.7% (4.4%-7.3%, n=1000) | FAIL | 66.9% (66.2%-67.7%, n=14733) | 2.8% (2.5%-3.1%, n=13790) | PASS |
| V0 full | C_shatter | 38.0% (35.0%-41.0%, n=1000) | PASS | 72.3% (71.6%-72.9%, n=20250) | 1.3% (1.2%-1.5%, n=19630) | PASS |
| V0 full | C_lantern | 37.1% (34.2%-40.1%, n=1000) | PASS | 70.6% (70.0%-71.3%, n=19569) | 1.1% (1.0%-1.3%, n=18940) | UNDECIDED |
| V0 full | C_edge | 14.4% (12.4%-16.7%, n=1000) | FAIL | 79.4% (78.8%-80.0%, n=17728) | 2.8% (2.6%-3.1%, n=16872) | PASS |

**B is not met.** Edge fails B1 in both pools; nothing else fails. The Lantern's B2 is undecided in both pools, on the edge of "no stakes" rather than "no expression" at V0 full; at V0 fresh both of its proxies sit on their lines. Fights within a run are not independent, so the expression and close-call intervals are narrower than they should be; their verdicts are read as indicative.

## What the reading suggests

For the orchestrator; nothing here was turned.

1. **Read viability with the search player from now on, and keep the greedy pilot as the fast baseline.** The greedy pilot understates every way and unevenly (Lantern +15.9 pp, Shatter +12.0, Edge +7.4 at V0 full), so greedy readings of G1 and G2 misstate both levels and parity. The search costs about 30 times as much per run; greedy remains right for sweeps and for comparison with readouts 1–7.
2. **Edge is the one way a capable player cannot carry, and the fix must reward commitment, not supply.** Committed Edge fails B1 in both pools and dies in Act 2 (444 of 856 deaths at V0 full), the wall readout 7 named; yet 83% of the adaptive arm's wins at V0 full end Edge-led. Readout 7's Edge cards (E1–E3) were taken by the adaptive arm too and raised that share. The content lane's next Edge candidate should pay only a committed deck: staying power that scales with Cracked already laid, or with a Steady or True Edge lantern, rather than another Edge common.
3. **G4 now fails decisively, and the owner's 12:46 law is broken at V0 full.** With competent play the random build wins 19.0% at V0 full, more than committed Edge. The owner has ruled G4 a reading; the lock's sentence "random, non-path decks must not still win" is not true of this build for a capable player. If that sentence stands, the Soot tier (§5) is the lever the lock names; if it does not, the lock should say so.
4. **The baseline hardship moved G1 out of reach.** The best committed way with the search player reaches 38.0% at V0 full against the 50% floor (greedy: 26.0%; readout 7, before #623: 47.5% for Shatter and for the Lantern). The owner has ruled the game may be hard and G1 a reading. If G1's floors are still meant as targets, they should be re-signed against the search player, or the hardship revisited; if not, the lock's G1 thresholds describe a different game and could be marked as such.
5. **Watch the Lantern's stakes.** Its fights are the safest of the three, its close calls on B2's floor, and its fresh-pool decks show their way least. That is a feel question bots can point at but not settle; James's play reports are the input here (never the gate).
6. **The V5 cells need more seeds than an hour gives.** At 400 seeds V5 fresh holds at most 12 wins per arm, and G6 is undecided in both V5 cells for lack of A wins. A V5 reading worth grading needs about 2,000 seeds per cell with the search player: by the single-process cost, under an hour on an unloaded 10-core host, which this shared host was not.
