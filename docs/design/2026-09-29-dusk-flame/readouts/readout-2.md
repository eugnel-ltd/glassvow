# Readout 2: recognition at the boss and like-calls-to-like

**Date:** 2026-09-29. **Lock:** [the Flame design lock](../README.md), section 11, calibration step 4: recognition at the boss (section 7) and like-calls-to-like (section 8), on top of step 1. The implementation map (section 12) delivers this step in lock PR 3, ahead of the Soot leak and the lantern quality (steps 2 and 3, PR 4), so every lantern knob is still at zero. The only baseline is [readout 1](readout-1.md).

**Instrument head:** `50ffd0629c8ac7a7f3a662c18b7abd725ccd0727` on `feat/flame-pr3-recognition-steering` (lock PR 3). The commit that adds this file changes nothing else. **Content:** `content/full-content.json`, SHA-256 `dc2d1200d5102fd74d3d1e37556fb30044e5b4933de150f5e8d0f7bb79243bc8`; it differs from readout 1's only by `aspects[0].flame.likeWeight` 1.5 and `fringeWeight` 1.2. **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, on a 10-core Apple Silicon Mac.

## How it was run

```sh
python3 -B tools/balance_ways.py --jobs 6 --out-dir <a new, empty directory>
```

- **Seeds, cells and arms:** exactly readout 1's. The default 13000-13199, 200 paired seeds with common random numbers across the five arms; Duskblade at vows 0 and 5 with the shipping vow incentives, each under the fresh and the full pool; C_shatter, C_lantern and C_edge (the committed pilot), A (adaptive, arm 1) and R (random build, arm 2). No development or acceptance seed was used.
- **What changed since readout 1:** at each act boss the flame's crowns take their slots (slot 1 the dominant way's crown when Steady or True, Hollow Crown when Soot; slot 2 the fringe way's crown when Steady or True), and once the flame is Steady or True, card rewards and the shop's cards and relics draw glass of the dominant way at 1.5 and of the fringe way at 1.2. The number of draws per offer, the pilots, combat and the purity function are unchanged. Edge declares no crown yet (lock PR 6), so an Edge flame's slot keeps its draw.
- **Gate arithmetic, checked before this run** against the lock's section 11: every threshold; G1's floor per cell (none at V5 fresh); G2 and G3 per cell against the best and worst committed arm; G4's gap and ceiling; G5 over every run of the arm (a run that died earlier counts as not reached) and only in the arm's own way, read after each act's boss and its card reward; G6 over all of A's wins, a winner with no dominant way included. Nothing needed fixing.
- **Cost:** 4,000 runs plus 12 replay runs, 32 s wall with 6 jobs.

The rows are read as in readout 1.

## Tables

### V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 16/200 | 8.0% | 5.0%-12.6% | 92.5% | 32.5% | 1.0% | 0 | 0 |
| C_lantern | 3/200 | 1.5% | 0.5%-4.3% | 92.5% | 31.5% | 5.5% | 0 | 0 |
| C_edge | 23/200 | 11.5% | 7.8%-16.7% | 94.5% | 14.0% | 0.5% | 0 | 0 |
| A | 76/200 | 38.0% | 31.6%-44.9% | - | - | - | 0 | 0 |
| R | 8/200 | 4.0% | 2.0%-7.7% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.06 | 2.72 | 4.96 | 2.99 | 6.23 |
| C_lantern | 0.92 | 2.81 | 6.56 | 2.97 | 7.99 |
| C_edge | 0.92 | 2.65 | 4.49 | 3.84 | 5.82 |
| A | 1.07 | 2.57 | 5.73 | 3.73 | 7.21 |
| R | 0.91 | 2.45 | 4.67 | 3.30 | 5.92 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 1.5% | >= 40.0% | FAIL |
| G2 parity: the ways are comparable | 10.0 pp (C_edge - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 38.0% vs best 11.5% (+26.5 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 4.0% vs worst 1.5% (+2.5 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 14.0% (C_edge); True by end of Act 2 min 0.5% (C_edge) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 46.1%, lantern 43.4%, edge 10.5% of 76 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V0, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 59/200 | 29.5% | 23.6%-36.2% | 95.0% | 31.0% | 1.0% | 0 | 0 |
| C_lantern | 33/200 | 16.5% | 12.0%-22.3% | 98.5% | 54.5% | 18.0% | 0 | 0 |
| C_edge | 46/200 | 23.0% | 17.7%-29.3% | 98.5% | 59.0% | 8.5% | 0 | 0 |
| A | 100/200 | 50.0% | 43.1%-56.9% | - | - | - | 0 | 0 |
| R | 39/200 | 19.5% | 14.6%-25.5% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.45 | 2.45 | 5.78 | 3.65 | 6.94 |
| C_lantern | 1.06 | 2.60 | 8.40 | 3.40 | 9.83 |
| C_edge | 1.01 | 2.20 | 4.52 | 3.93 | 5.67 |
| A | 1.24 | 2.30 | 6.30 | 4.21 | 7.86 |
| R | 1.06 | 2.29 | 5.45 | 3.64 | 6.52 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 16.5% | >= 50.0% | FAIL |
| G2 parity: the ways are comparable | 13.0 pp (C_shatter - C_lantern) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 50.0% vs best 29.5% (+20.5 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 19.5% vs worst 16.5% (+3.0 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 31.0% (C_shatter); True by end of Act 2 min 1.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 19.0%, lantern 55.0%, edge 26.0% of 100 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 0/200 | 0.0% | 0.0%-1.9% | 93.0% | 11.0% | 0.0% | 0 | 0 |
| C_lantern | 1/200 | 0.5% | 0.1%-2.8% | 81.5% | 6.0% | 0.5% | 0 | 0 |
| C_edge | 1/200 | 0.5% | 0.1%-2.8% | 76.0% | 0.5% | 0.0% | 0 | 0 |
| A | 12/200 | 6.0% | 3.5%-10.2% | - | - | - | 0 | 0 |
| R | 0/200 | 0.0% | 0.0%-1.9% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 0.85 | 2.59 | 4.44 | 2.53 | 5.73 |
| C_lantern | 0.85 | 2.80 | 5.72 | 2.74 | 7.17 |
| C_edge | 0.80 | 2.62 | 4.36 | 3.17 | 5.64 |
| A | 0.87 | 2.65 | 5.19 | 3.10 | 6.56 |
| R | 0.85 | 2.43 | 4.49 | 2.96 | 5.79 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_shatter 0.0% | no threshold for this cell | n/a |
| G2 parity: the ways are comparable | 0.5 pp (C_lantern - C_shatter) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 6.0% vs best 0.5% (+5.5 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 0.0% vs worst 0.0% (+0.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 0.5% (C_edge); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 50.0%, lantern 50.0%, edge 0.0% of 12 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 23/200 | 11.5% | 7.8%-16.7% | 94.5% | 19.0% | 0.5% | 0 | 0 |
| C_lantern | 16/200 | 8.0% | 5.0%-12.6% | 98.5% | 16.5% | 6.0% | 0 | 0 |
| C_edge | 9/200 | 4.5% | 2.4%-8.3% | 97.0% | 28.5% | 2.5% | 0 | 0 |
| A | 37/200 | 18.5% | 13.7%-24.5% | - | - | - | 0 | 0 |
| R | 10/200 | 5.0% | 2.7%-9.0% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.24 | 2.44 | 5.45 | 3.30 | 6.59 |
| C_lantern | 0.97 | 2.38 | 6.80 | 3.05 | 8.32 |
| C_edge | 0.90 | 2.24 | 4.45 | 3.35 | 5.55 |
| A | 1.08 | 2.32 | 5.83 | 3.62 | 7.13 |
| R | 0.99 | 2.26 | 5.10 | 3.42 | 6.27 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 4.5% | >= 25.0% | FAIL |
| G2 parity: the ways are comparable | 7.0 pp (C_shatter - C_edge) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 18.5% vs best 11.5% (+7.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 5.0% vs worst 4.5% (+0.5 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 16.5% (C_lantern); True by end of Act 2 min 0.5% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 45.9%, lantern 29.7%, edge 24.3% of 37 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |


G7 here covers stalls, errors and a replay of arm A's first 3 seeds per cell. The CEM stress and the save-lineage check belong to the exam; H is the human round.

## Against readout 1

Win rates, readout 1 to readout 2 (percentage-point change in brackets):

| Cell | C_shatter | C_lantern | C_edge | A | R |
|---|---:|---:|---:|---:|---:|
| V0 fresh | 6.5 to 8.0 (+1.5) | 4.0 to 1.5 (-2.5) | 7.5 to 11.5 (+4.0) | 35.0 to 38.0 (+3.0) | 3.0 to 4.0 (+1.0) |
| V0 full | 35.5 to 29.5 (-6.0) | 19.5 to 16.5 (-3.0) | 23.0 to 23.0 (0.0) | 49.0 to 50.0 (+1.0) | 20.5 to 19.5 (-1.0) |
| V5 fresh | 0.5 to 0.0 (-0.5) | 0.0 to 0.5 (+0.5) | 0.0 to 0.5 (+0.5) | 5.5 to 6.0 (+0.5) | 0.0 to 0.0 (0.0) |
| V5 full | 9.5 to 11.5 (+2.0) | 4.0 to 8.0 (+4.0) | 7.5 to 4.5 (-3.0) | 17.5 to 18.5 (+1.0) | 6.0 to 5.0 (-1.0) |

Gates, readout 1 to readout 2:

| Gate | V0 fresh | V0 full | V5 fresh | V5 full |
|---|---|---|---|---|
| G1 viability | FAIL to FAIL: worst 4.0% to 1.5% (C_lantern) | FAIL to FAIL: worst 19.5% to 16.5% (C_lantern) | n/a | FAIL to FAIL: worst 4.0% (C_lantern) to 4.5% (C_edge) |
| G2 parity | PASS to PASS: 3.5 to 10.0 pp, on the limit | FAIL to FAIL: 16.0 to 13.0 pp | PASS to PASS: 0.5 to 0.5 pp | PASS to PASS: 5.5 to 7.0 pp |
| G3 skill | FAIL to FAIL: +27.5 to +26.5 pp | PASS to FAIL: +13.5 to +20.5 pp | PASS to PASS: +5.0 to +5.5 pp | PASS to PASS: +8.0 to +7.0 pp |
| G4 random loses | FAIL to FAIL: R minus worst -1.0 to +2.5 pp | FAIL to FAIL: +1.0 to +3.0 pp | FAIL to FAIL: 0.0 to 0.0 pp | FAIL to FAIL: +2.0 to +0.5 pp |
| G5 reachability | FAIL to FAIL: Steady min 11.5% to 14.0%, True min 0.5% to 0.5% | FAIL to FAIL: 29.0% to 31.0%, 1.5% to 1.0% | FAIL to FAIL: 1.0% to 0.5%, 0.0% to 0.0% | FAIL to FAIL: 16.5% to 16.5%, 0.0% to 0.5% |
| G6 diversity | PASS to PASS: top way 44.3% to 46.1% | FAIL to PASS: lantern 60.2% to 55.0% | FAIL to PASS: shatter 72.7% to 50.0% (11 to 12 wins) | PASS to PASS: top way 40.0% to 45.9% |
| G7 guards | PASS to PASS | PASS to PASS | PASS to PASS | PASS to PASS |

## What the second reading says

- **Verdicts.** G1, G4 and G5 still fail in every graded cell and G7 still passes. G6 turns to PASS at V0 full and V5 fresh; G3 turns to FAIL at V0 full; G2 at V0 fresh now sits exactly on its 10 pp limit.
- **The moves are small.** No arm moves by more than 6.0 pp, and the 95% Wilson half-widths at these rates run from about 1 to 7 pp, so most single moves are within the noise of 200 seeds. The largest, C_shatter at V0 full (-6.0 pp), is what turns G3 there: A's lead over the best committed arm grows from +13.5 to +20.5 pp while A itself moves +1.0 pp.
- **Scattering is untouched.** R moves by 1.0 pp or less in every cell, and G4 fails as before. The lock gives that gate to the Soot leak and the lantern quality.
- **The flame moves more than the win rate.** True by the end of Act 2 rises for the Lantern and Edge arms (C_lantern 0.5% to 5.5% at V0 fresh and 2.5% to 6.0% at V5 full; C_edge 4.5% to 8.5% at V0 full and 0.0% to 2.5% at V5 full), and Steady by the end of Act 1 rises for C_lantern at V0 fresh (23.0% to 31.5%) and C_edge at V0 full (53.5% to 59.0%). Steady by the end of Act 1 is read before the first boss relic, so only like-calls-to-like can move it. No committed arm comes near G5's 70% and 40%.
- **Adaptive diversity improves where it failed.** Lantern's share of A's wins at V0 full falls from 60.2% to 55.0%; at V5 fresh, A's 12 wins split 6 to 6 between Shatter and Lantern, against 8 to 3 of 11, a small sample.
- **The instrument holds (G7).** No stalls, no errors, and every replay identical in all four cells.

The lock's calibration continues with the Soot leak and the Steady and True lantern quality (PR 4, readout 3).
