# Readout 4a: the Edge way's content in place

**Date:** 2026-09-29. **Lock:** [the Flame design lock](../README.md), §6.2 and §12 row 6 (lock PR 6). The first reading with the Edge way's seven cards, the Crown of the Eclipse and the deed Fault in the Glass in content. Everything else is as [readout 2](readout-2.md) measured it: recognition at the boss and like-calls-to-like (lock PR 3) on top of the mirror, every lantern knob still at zero (no Soot leak, no lantern quality). Readout 2 is the latest readout on `main` at the time of this run, so every delta below is against it, on the same paired seeds. Its note that "Edge declares no crown yet" no longer holds: the Edge way's crown now takes its slot at the boss like the others.

**Instrument head:** `cde9e41bac1c8497af214ecb03712804c847141d` on `feat/flame-pr6-edge-content` (lock PR 6), rebased onto `main` at `2b682d56` (after lock PRs 3 and 7). The commit that adds this file changes nothing else. The same tables came out byte for byte at `24252ada`, the same commits on `759e1688` (`2b682d56` changes one test file only). **Content:** `content/full-content.json`, SHA-256 `6d54d0d572683aeb4a36a1bcf40aa4ab04d6bd75fff1c471674a42962b060186`; against readout 2's content it adds only the Edge way's ids (31 added paths, no changed value). **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, on a 10-core Apple Silicon Mac shared with other test runs (wall time is not a benchmark).

## How it was run

```sh
python3 -B tools/balance_ways.py --jobs 6 --out-dir <a new, empty directory>
```

- **Seeds:** the default 13000-13199, the same 200 paired seeds as readouts 1 and 2, with common random numbers across the five arms. The development band 12000-12199 served the probe at the end of this file; the acceptance seeds 3000-5199 were not touched.
- **Cells and arms:** as readout 2. The fresh pool now holds the four base-pool Edge cards (Splinter Cut, Dim the Glass, Cleft, Eclipse Step); the full pool adds Tremor (wave 2), Ember Eye (wave 3 and the deed) and Totality (the deed); the boss pool holds the Crown of the Eclipse, which recognition places for an Edge flame, and like-calls-to-like now also leans towards the new Edge glass once an Edge flame is Steady.
- **Cost:** 4,000 runs plus 12 replay runs, 26 s wall with 6 jobs.

The rows read as in readout 1: own way at end is the share of the arm's runs whose deck ends dominant in the arm's way; G5 counts a committed run only when its own way is Steady or True at the end of Act 1 and True at the end of Act 2, over every run; G6 splits the adaptive arm's wins by their dominant way at run end.

## Tables

### V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 17/200 | 8.5% | 5.4%-13.2% | 92.0% | 24.0% | 1.0% | 0 | 0 |
| C_lantern | 9/200 | 4.5% | 2.4%-8.3% | 91.5% | 23.5% | 1.5% | 0 | 0 |
| C_edge | 4/200 | 2.0% | 0.8%-5.0% | 99.0% | 44.0% | 0.5% | 0 | 0 |
| A | 65/200 | 32.5% | 26.4%-39.3% | - | - | - | 0 | 0 |
| R | 7/200 | 3.5% | 1.7%-7.0% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.06 | 2.63 | 4.86 | 3.00 | 6.09 |
| C_lantern | 0.90 | 2.77 | 6.35 | 3.03 | 7.71 |
| C_edge | 0.83 | 2.60 | 4.25 | 4.37 | 5.56 |
| A | 1.03 | 2.57 | 5.54 | 4.08 | 6.93 |
| R | 0.93 | 2.42 | 4.66 | 3.56 | 5.90 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 2.0% | >= 40.0% | FAIL |
| G2 parity: the ways are comparable | 6.5 pp (C_shatter - C_edge) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 32.5% vs best 8.5% (+24.0 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 3.5% vs worst 2.0% (+1.5 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 15.4%, lantern 18.5%, edge 66.2% of 65 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V0, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 77/200 | 38.5% | 32.0%-45.4% | 91.0% | 26.5% | 2.0% | 0 | 0 |
| C_lantern | 25/200 | 12.5% | 8.6%-17.8% | 99.0% | 46.0% | 6.5% | 0 | 0 |
| C_edge | 17/200 | 8.5% | 5.4%-13.2% | 100.0% | 71.0% | 10.0% | 0 | 0 |
| A | 78/200 | 39.0% | 32.5%-45.9% | - | - | - | 0 | 0 |
| R | 30/200 | 15.0% | 10.7%-20.6% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.46 | 2.45 | 5.83 | 3.77 | 6.96 |
| C_lantern | 1.06 | 2.59 | 7.95 | 4.00 | 9.19 |
| C_edge | 0.87 | 2.24 | 4.37 | 4.62 | 5.49 |
| A | 1.18 | 2.39 | 6.37 | 5.14 | 7.69 |
| R | 1.06 | 2.31 | 5.40 | 4.11 | 6.46 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 8.5% | >= 50.0% | FAIL |
| G2 parity: the ways are comparable | 30.0 pp (C_shatter - C_edge) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 39.0% vs best 38.5% (+0.5 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 15.0% vs worst 8.5% (+6.5 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 1.3%, lantern 17.9%, edge 80.8% of 78 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 0/200 | 0.0% | 0.0%-1.9% | 91.0% | 8.0% | 0.0% | 0 | 0 |
| C_lantern | 0/200 | 0.0% | 0.0%-1.9% | 74.5% | 4.0% | 0.0% | 0 | 0 |
| C_edge | 0/200 | 0.0% | 0.0%-1.9% | 98.0% | 5.5% | 0.0% | 0 | 0 |
| A | 10/200 | 5.0% | 2.7%-9.0% | - | - | - | 0 | 0 |
| R | 2/200 | 1.0% | 0.3%-3.6% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 0.83 | 2.58 | 4.43 | 2.56 | 5.69 |
| C_lantern | 0.82 | 2.73 | 5.40 | 2.72 | 6.77 |
| C_edge | 0.80 | 2.61 | 4.27 | 3.77 | 5.60 |
| A | 0.86 | 2.63 | 5.04 | 3.18 | 6.38 |
| R | 0.87 | 2.45 | 4.45 | 3.26 | 5.80 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_shatter 0.0% | no threshold for this cell | n/a |
| G2 parity: the ways are comparable | 0.0 pp (C_shatter - C_shatter) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 5.0% vs best 0.0% (+5.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 1.0% vs worst 0.0% (+1.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 50.0%, lantern 0.0%, edge 50.0% of 10 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 24/200 | 12.0% | 8.2%-17.2% | 87.5% | 12.0% | 0.0% | 0 | 0 |
| C_lantern | 4/200 | 2.0% | 0.8%-5.0% | 97.5% | 16.5% | 1.5% | 0 | 0 |
| C_edge | 3/200 | 1.5% | 0.5%-4.3% | 100.0% | 34.5% | 1.5% | 0 | 0 |
| A | 34/200 | 17.0% | 12.4%-22.8% | - | - | - | 0 | 0 |
| R | 9/200 | 4.5% | 2.4%-8.3% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.23 | 2.45 | 5.48 | 3.37 | 6.58 |
| C_lantern | 0.97 | 2.52 | 6.90 | 3.60 | 8.20 |
| C_edge | 0.87 | 2.26 | 4.47 | 4.31 | 5.59 |
| A | 1.06 | 2.34 | 5.74 | 4.11 | 7.09 |
| R | 1.00 | 2.26 | 5.14 | 3.66 | 6.34 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 1.5% | >= 25.0% | FAIL |
| G2 parity: the ways are comparable | 10.5 pp (C_shatter - C_edge) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 17.0% vs best 12.0% (+5.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 4.5% vs worst 1.5% (+3.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 17.6%, lantern 17.6%, edge 64.7% of 34 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

## Delta against readout 2

Same seeds, same instrument; only the Edge content differs. Win rate per arm:

| Cell | Arm | Readout 2 | Readout 4a | Delta |
|---|---|---:|---:|---:|
| V0, fresh | C_shatter | 16/200 (8.0%) | 17/200 (8.5%) | +0.5 pp |
| V0, fresh | C_lantern | 3/200 (1.5%) | 9/200 (4.5%) | +3.0 pp |
| V0, fresh | C_edge | 23/200 (11.5%) | 4/200 (2.0%) | -9.5 pp |
| V0, fresh | A | 76/200 (38.0%) | 65/200 (32.5%) | -5.5 pp |
| V0, fresh | R | 8/200 (4.0%) | 7/200 (3.5%) | -0.5 pp |
| V0, full | C_shatter | 59/200 (29.5%) | 77/200 (38.5%) | +9.0 pp |
| V0, full | C_lantern | 33/200 (16.5%) | 25/200 (12.5%) | -4.0 pp |
| V0, full | C_edge | 46/200 (23.0%) | 17/200 (8.5%) | -14.5 pp |
| V0, full | A | 100/200 (50.0%) | 78/200 (39.0%) | -11.0 pp |
| V0, full | R | 39/200 (19.5%) | 30/200 (15.0%) | -4.5 pp |
| V5, fresh | C_shatter | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | C_lantern | 1/200 (0.5%) | 0/200 (0.0%) | -0.5 pp |
| V5, fresh | C_edge | 1/200 (0.5%) | 0/200 (0.0%) | -0.5 pp |
| V5, fresh | A | 12/200 (6.0%) | 10/200 (5.0%) | -1.0 pp |
| V5, fresh | R | 0/200 (0.0%) | 2/200 (1.0%) | +1.0 pp |
| V5, full | C_shatter | 23/200 (11.5%) | 24/200 (12.0%) | +0.5 pp |
| V5, full | C_lantern | 16/200 (8.0%) | 4/200 (2.0%) | -6.0 pp |
| V5, full | C_edge | 9/200 (4.5%) | 3/200 (1.5%) | -3.0 pp |
| V5, full | A | 37/200 (18.5%) | 34/200 (17.0%) | -1.5 pp |
| V5, full | R | 10/200 (5.0%) | 9/200 (4.5%) | -0.5 pp |

The flame for the committed arms (Steady by the end of Act 1, True by the end of Act 2, own way at the end):

| Cell | Arm | Steady by end of Act 1 | True by end of Act 2 | Own way at end |
|---|---|---|---|---|
| V0, fresh | C_shatter | 32.5% -> 24.0% | 1.0% -> 1.0% | 92.5% -> 92.0% |
| V0, fresh | C_lantern | 31.5% -> 23.5% | 5.5% -> 1.5% | 92.5% -> 91.5% |
| V0, fresh | C_edge | 14.0% -> 44.0% | 0.5% -> 0.5% | 94.5% -> 99.0% |
| V0, full | C_shatter | 31.0% -> 26.5% | 1.0% -> 2.0% | 95.0% -> 91.0% |
| V0, full | C_lantern | 54.5% -> 46.0% | 18.0% -> 6.5% | 98.5% -> 99.0% |
| V0, full | C_edge | 59.0% -> 71.0% | 8.5% -> 10.0% | 98.5% -> 100.0% |
| V5, fresh | C_shatter | 11.0% -> 8.0% | 0.0% -> 0.0% | 93.0% -> 91.0% |
| V5, fresh | C_lantern | 6.0% -> 4.0% | 0.5% -> 0.0% | 81.5% -> 74.5% |
| V5, fresh | C_edge | 0.5% -> 5.5% | 0.0% -> 0.0% | 76.0% -> 98.0% |
| V5, full | C_shatter | 19.0% -> 12.0% | 0.5% -> 0.0% | 94.5% -> 87.5% |
| V5, full | C_lantern | 16.5% -> 16.5% | 6.0% -> 1.5% | 98.5% -> 97.5% |
| V5, full | C_edge | 28.5% -> 34.5% | 2.5% -> 1.5% | 97.0% -> 100.0% |

Gates, readout 2 against readout 4a:

| Cell | Gate | Readout 2 | Readout 4a |
|---|---|---|---|
| V0, fresh | G1 | FAIL: worst C_lantern 1.5% | FAIL: worst C_edge 2.0% |
| V0, fresh | G2 | PASS: 10.0 pp (C_edge - C_lantern) | PASS: 6.5 pp (C_shatter - C_edge) |
| V0, fresh | G3 | FAIL: A 38.0% vs best 11.5% (+26.5 pp) | FAIL: A 32.5% vs best 8.5% (+24.0 pp) |
| V0, fresh | G4 | FAIL: R 4.0% vs worst 1.5% (+2.5 pp) | FAIL: R 3.5% vs worst 2.0% (+1.5 pp) |
| V0, fresh | G5 | FAIL: Steady by end of Act 1 min 14.0% (C_edge); True by end of Act 2 min 0.5% (C_edge) | FAIL: Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) |
| V0, fresh | G6 | PASS: shatter 46.1%, lantern 43.4%, edge 10.5% of 76 A wins | FAIL: shatter 15.4%, lantern 18.5%, edge 66.2% of 65 A wins |
| V0, fresh | G7 | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V0, full | G1 | FAIL: worst C_lantern 16.5% | FAIL: worst C_edge 8.5% |
| V0, full | G2 | FAIL: 13.0 pp (C_shatter - C_lantern) | FAIL: 30.0 pp (C_shatter - C_edge) |
| V0, full | G3 | FAIL: A 50.0% vs best 29.5% (+20.5 pp) | PASS: A 39.0% vs best 38.5% (+0.5 pp) |
| V0, full | G4 | FAIL: R 19.5% vs worst 16.5% (+3.0 pp) | FAIL: R 15.0% vs worst 8.5% (+6.5 pp) |
| V0, full | G5 | FAIL: Steady by end of Act 1 min 31.0% (C_shatter); True by end of Act 2 min 1.0% (C_shatter) | FAIL: Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) |
| V0, full | G6 | PASS: shatter 19.0%, lantern 55.0%, edge 26.0% of 100 A wins | FAIL: shatter 1.3%, lantern 17.9%, edge 80.8% of 78 A wins |
| V0, full | G7 | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V5, fresh | G1 | n/a: worst C_shatter 0.0% | n/a: worst C_shatter 0.0% |
| V5, fresh | G2 | PASS: 0.5 pp (C_lantern - C_shatter) | PASS: 0.0 pp (C_shatter - C_shatter) |
| V5, fresh | G3 | PASS: A 6.0% vs best 0.5% (+5.5 pp) | PASS: A 5.0% vs best 0.0% (+5.0 pp) |
| V5, fresh | G4 | FAIL: R 0.0% vs worst 0.0% (+0.0 pp) | FAIL: R 1.0% vs worst 0.0% (+1.0 pp) |
| V5, fresh | G5 | FAIL: Steady by end of Act 1 min 0.5% (C_edge); True by end of Act 2 min 0.0% (C_shatter) | FAIL: Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) |
| V5, fresh | G6 | PASS: shatter 50.0%, lantern 50.0%, edge 0.0% of 12 A wins | PASS: shatter 50.0%, lantern 0.0%, edge 50.0% of 10 A wins |
| V5, fresh | G7 | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V5, full | G1 | FAIL: worst C_edge 4.5% | FAIL: worst C_edge 1.5% |
| V5, full | G2 | PASS: 7.0 pp (C_shatter - C_edge) | FAIL: 10.5 pp (C_shatter - C_edge) |
| V5, full | G3 | PASS: A 18.5% vs best 11.5% (+7.0 pp) | PASS: A 17.0% vs best 12.0% (+5.0 pp) |
| V5, full | G4 | FAIL: R 5.0% vs worst 4.5% (+0.5 pp) | FAIL: R 4.5% vs worst 1.5% (+3.0 pp) |
| V5, full | G5 | FAIL: Steady by end of Act 1 min 16.5% (C_lantern); True by end of Act 2 min 0.5% (C_shatter) | FAIL: Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) |
| V5, full | G6 | PASS: shatter 45.9%, lantern 29.7%, edge 24.3% of 37 A wins | FAIL: shatter 17.6%, lantern 17.6%, edge 64.7% of 34 A wins |
| V5, full | G7 | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |

## What the reading says

- **Edge is now the weakest committed way (G1, G2).** This is the number the content lane asked for. C_edge wins 2.0% at V0 fresh, 8.5% at V0 full and 1.5% at V5 full (floors 40%, 50% and 25%), down 9.5, 14.5 and 3.0 pp from readout 2 on the same seeds. In readout 2 it was the best committed way at V0 fresh and second at V0 full; it is now last in both, and still last at V5 full. The V0 full parity spread widens from 13.0 to 30.0 pp, and V5 full turns from PASS (7.0 pp) to FAIL (10.5 pp). G1 fails in every graded cell, as it did in readout 2.
- **The flame does light for Edge.** Committed Edge runs are Steady by the end of Act 1 in 44.0% at V0 fresh (was 14.0%) and 71.0% at V0 full (was 59.0%): the only committed way over G5's 70% line in any cell. True by the end of Act 2 barely moves (8.5% to 10.0% at V0 full). More Edge glass steadies the flame; it does not yet win fights.
- **Why the Edge deck gets weaker.** The simulator's per-card telemetry (offered, drawn, played) points at dilution, which recognition and like-calls-to-like now amplify: a Steady Edge flame is offered more of the new Edge glass. Dim the Glass is taken about twice per run by both C_edge and A (up to 2.6 per C_edge run at V0 full), because the pilot's build score puts it level with Preparation at the top of the commons, yet it is played on only 27-38% of the turns it is in hand. Eclipse Step is played on 14-20% (only when an unblocked blow is coming). The committed pilot scores its own glass ×3 and so takes the new Edge commons over stronger clear glass.
- **The adaptive arm follows the new glass (G6).** A's wins are now 66-81% Edge-dominant at V0 (readout 2: 11-26%), and A loses 5.5 pp at V0 fresh and 11.0 pp at V0 full. G6, which passed in all four cells in readout 2, now fails in three; it passes at V5 fresh, where A wins only 10 runs.
- **G3 moves only because A falls.** At V0 full it turns to PASS (+0.5 pp over the best committed way, was +20.5) because A drops to 39.0% and C_shatter rises to 38.5%, not because commitment got better; at V0 fresh A is still 24.0 pp above the best committed way.
- **Instrument limits to keep in mind.** The adaptive pilot declines Cleft and Totality (a new special gets the generic special weight, which leaves both below its decline threshold) and never takes the Crown of the Eclipse even when recognition offers it (an unnamed boss relic gets the boss-rarity default, below the named crowns). A's Edge is therefore Splinter Cut, Dim the Glass and Ember Eye. The committed pilot, with its ×3, takes all of it: with recognition, every C_edge run that reached a boss relic choice at V0 full took the crown (146 runs), and 11.6% of them won. The pilot spends Embers on the Art before it looks at Ember Eye.
- **The guards hold (G7).** No stalls, no errors, and every replay identical in all four cells.

## Development-band probe (not calibration evidence)

A bounded discovery run on seeds 12000-12199 asked whether one number explains the drop: is it Dim the Glass's cost of 1 (the lock sketches no cost; this PR chose the conservative 1)? Four catalogues, each run through `tools/balance_ways.py` at `24252ada` (this PR on `759e1688`; the later rebase changed no instrument or content file) with the simulator's `--content` option pointing at a scratch copy; nothing below is shipped. `base` is main's content (readout 2's), `shipped` this readout's, `dim0` makes Dim the Glass cost 0 (upgraded: 3 Dimmed) and `nodim` leaves it out of every pool.

| Cell | Row | base | shipped | dim0 | nodim |
|---|---|---:|---:|---:|---:|
| V0, fresh | C_edge win rate | 13.0% | 1.0% | 8.5% | 4.0% |
| V0, fresh | A win rate | 35.0% | 32.5% | 46.5% | 31.0% |
| V0, fresh | A wins that end Edge | 5.7% of 70 | 52.3% of 65 | 63.4% of 93 | 40.3% of 62 |
| V0, full | C_edge win rate | 20.0% | 10.0% | 16.5% | 9.0% |
| V0, full | A win rate | 45.5% | 42.0% | 54.5% | 38.5% |
| V0, full | A wins that end Edge | 33.0% of 91 | 77.4% of 84 | 95.4% of 109 | 62.3% of 77 |
| V5, fresh | C_edge win rate | 0.0% | 0.5% | 0.5% | 0.0% |
| V5, fresh | A win rate | 5.5% | 3.5% | 13.5% | 5.5% |
| V5, fresh | A wins that end Edge | 0.0% of 11 | 14.3% of 7 | 55.6% of 27 | 0.0% of 11 |
| V5, full | C_edge win rate | 5.0% | 2.0% | 3.5% | 1.5% |
| V5, full | A win rate | 20.5% | 9.5% | 20.5% | 17.5% |
| V5, full | A wins that end Edge | 26.8% of 41 | 68.4% of 19 | 75.6% of 41 | 60.0% of 35 |

- At cost 0, Dim the Glass recovers only part of the loss (C_edge 8.5% and 16.5% at V0 fresh and full, against 13.0% and 20.0% without the Edge content), while it lifts the adaptive arm by 8.0 to 11.5 pp at V0 and V5 fresh and makes 63-95% of A's wins Edge-dominant at V0: a common that strong would decide the adaptive arm's way rather than widen its choices.
- Without Dim the Glass, C_edge stays far below its pre-content rate (4.0% and 9.0% at V0, against 13.0% and 20.0%), so the dilution is broader than one card.
- So no single cost change here fixes Edge without a new imbalance. The content ships as sketched, and the numbers stay open for the lock's §14 item ("final wording and numbers ... against readout 4"), after the Soot leak and lantern quality have been calibrated.

G7 here covers stalls, errors and a replay of arm A's first 3 seeds per cell. The CEM stress and the save-lineage check belong to the exam; H is the human round.
