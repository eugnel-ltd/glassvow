# Readout 1: the mirror, every lantern knob at zero

**Date:** 2026-09-29. **Lock:** [the Flame design lock](../README.md), section 11, calibration step 1: pool hygiene, the affinity table and the flame as a pure mirror. No Soot leak, no lantern quality, no recognition at the boss, no like-calls-to-like.

**Instrument head:** `4cdcbc7590a87c13acd0bb2bf07f9048f40b711e` on `feat/flame-pr2-domain-science` (lock PR 2). The commit that adds this file changes nothing else. **Content:** `content/full-content.json`, SHA-256 `0ae848bc5a57dcda8b1417ff21902e046e6210b8ce5a131fa7e1a44ec8f4dda2`. **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, on a 10-core Apple Silicon Mac.

## How it was run

```sh
python3 -B tools/balance_ways.py --jobs 6 --out-dir <a new, empty directory>
```

- **Seeds:** the default 13000-13199, 200 paired seeds, with common random numbers across the five arms. The development band 12000-12999 was used only for smoke runs; the acceptance seeds 3000-5199 were not touched.
- **Cells:** Duskblade at vows 0 and 5 with the shipping vow incentives, each under two pool states. **Fresh** is a new Vigil: no reveals (so no pool waves, and also no phials, omens or Lamplighter, which arrive with runs played) and no deed unlocks. **Full** is every reveal plus every deed's unlocks.
- **Arms:** C_shatter, C_lantern and C_edge are the committed pilot (build-side scores of its own way x3.0, other coloured glass x0.5, combat play unchanged); A is today's adaptive arm 1; R is today's random-build arm 2.
- **Cost:** 4,000 runs plus 12 replay runs, 34 s wall with 6 jobs.

How the rows are read:

- **Own way at end:** share of the arm's runs whose deck ends dominant in the arm's way.
- **G5:** a committed run counts only when its own way is Steady or True at the end of Act 1, and True at the end of Act 2. The denominator is every run: a run that died earlier did not get there.
- **G6:** the adaptive arm's wins, by their dominant way at run end.
- **G7:** stalls, errors and a replay of arm A's first three seeds in each cell. The CEM stress and the save-lineage check belong to the exam. H is the human round.

## Tables

### V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 13/200 | 6.5% | 3.8%-10.8% | 93.0% | 33.0% | 1.5% | 0 | 0 |
| C_lantern | 8/200 | 4.0% | 2.0%-7.7% | 92.5% | 23.0% | 0.5% | 0 | 0 |
| C_edge | 15/200 | 7.5% | 4.6%-12.0% | 94.5% | 11.5% | 0.5% | 0 | 0 |
| A | 70/200 | 35.0% | 28.7%-41.8% | - | - | - | 0 | 0 |
| R | 6/200 | 3.0% | 1.4%-6.4% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.06 | 2.72 | 4.95 | 2.99 | 6.23 |
| C_lantern | 0.91 | 2.79 | 6.29 | 2.95 | 7.69 |
| C_edge | 0.92 | 2.69 | 4.53 | 3.83 | 5.86 |
| A | 1.08 | 2.59 | 5.76 | 3.69 | 7.21 |
| R | 0.90 | 2.46 | 4.63 | 3.28 | 5.91 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 4.0% | >= 40.0% | FAIL |
| G2 parity: the ways are comparable | 3.5 pp (C_edge - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 35.0% vs best 7.5% (+27.5 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 3.0% vs worst 4.0% (-1.0 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 11.5% (C_edge); True by end of Act 2 min 0.5% (C_lantern) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 44.3%, lantern 44.3%, edge 11.4% of 70 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V0, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 71/200 | 35.5% | 29.2%-42.3% | 95.0% | 29.0% | 1.5% | 0 | 0 |
| C_lantern | 39/200 | 19.5% | 14.6%-25.5% | 98.5% | 56.0% | 17.0% | 0 | 0 |
| C_edge | 46/200 | 23.0% | 17.7%-29.3% | 98.5% | 53.5% | 4.5% | 0 | 0 |
| A | 98/200 | 49.0% | 42.2%-55.9% | - | - | - | 0 | 0 |
| R | 41/200 | 20.5% | 15.5%-26.6% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.45 | 2.47 | 5.85 | 3.65 | 6.98 |
| C_lantern | 1.06 | 2.66 | 8.19 | 3.42 | 9.60 |
| C_edge | 1.01 | 2.24 | 4.60 | 3.93 | 5.72 |
| A | 1.25 | 2.32 | 6.32 | 4.24 | 7.89 |
| R | 1.05 | 2.28 | 5.44 | 3.62 | 6.51 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 19.5% | >= 50.0% | FAIL |
| G2 parity: the ways are comparable | 16.0 pp (C_shatter - C_lantern) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 49.0% vs best 35.5% (+13.5 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 20.5% vs worst 19.5% (+1.0 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 29.0% (C_shatter); True by end of Act 2 min 1.5% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 18.4%, lantern 60.2%, edge 21.4% of 98 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 1/200 | 0.5% | 0.1%-2.8% | 92.5% | 12.0% | 0.0% | 0 | 0 |
| C_lantern | 0/200 | 0.0% | 0.0%-1.9% | 82.0% | 5.5% | 0.5% | 0 | 0 |
| C_edge | 0/200 | 0.0% | 0.0%-1.9% | 75.5% | 1.0% | 0.0% | 0 | 0 |
| A | 11/200 | 5.5% | 3.1%-9.6% | - | - | - | 0 | 0 |
| R | 0/200 | 0.0% | 0.0%-1.9% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 0.85 | 2.59 | 4.44 | 2.53 | 5.74 |
| C_lantern | 0.85 | 2.78 | 5.63 | 2.73 | 7.09 |
| C_edge | 0.80 | 2.62 | 4.37 | 3.17 | 5.65 |
| A | 0.86 | 2.65 | 5.16 | 3.08 | 6.52 |
| R | 0.84 | 2.43 | 4.49 | 2.96 | 5.79 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 0.0% | no threshold for this cell | n/a |
| G2 parity: the ways are comparable | 0.5 pp (C_shatter - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 5.5% vs best 0.5% (+5.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 0.0% vs worst 0.0% (+0.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 1.0% (C_edge); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 72.7%, lantern 27.3%, edge 0.0% of 11 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### V5, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 19/200 | 9.5% | 6.2%-14.4% | 94.5% | 17.0% | 0.0% | 0 | 0 |
| C_lantern | 8/200 | 4.0% | 2.0%-7.7% | 98.5% | 16.5% | 2.5% | 0 | 0 |
| C_edge | 15/200 | 7.5% | 4.6%-12.0% | 97.0% | 27.5% | 0.0% | 0 | 0 |
| A | 35/200 | 17.5% | 12.9%-23.4% | - | - | - | 0 | 0 |
| R | 12/200 | 6.0% | 3.5%-10.2% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.22 | 2.44 | 5.43 | 3.27 | 6.56 |
| C_lantern | 0.97 | 2.43 | 6.59 | 3.01 | 8.04 |
| C_edge | 0.92 | 2.25 | 4.50 | 3.40 | 5.62 |
| A | 1.10 | 2.34 | 5.86 | 3.64 | 7.17 |
| R | 0.99 | 2.26 | 5.11 | 3.43 | 6.27 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 4.0% | >= 25.0% | FAIL |
| G2 parity: the ways are comparable | 5.5 pp (C_shatter - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 17.5% vs best 9.5% (+8.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 6.0% vs worst 4.0% (+2.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 16.5% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 40.0%, lantern 31.4%, edge 28.6% of 35 A wins | no way > 60%, >= 2 ways >= 20% | PASS |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

G7 here covers stalls, errors and a replay of arm A's first 3 seeds per cell. The CEM stress and the save-lineage check belong to the exam; H is the human round.

## What the first reading says

No gate was expected to pass at this step, and the reading is a baseline, not a verdict.

- **No committed way is viable yet (G1).** The committed ways win 4.0-35.5% at V0 (floors: 40% fresh, 50% full) and 4.0-9.5% at V5 full (floor: 25%). Lantern is the weakest committed way in every cell (tied with Edge at 0.0% at V5 fresh).
- **Reading the offers beats insisting (G3).** The adaptive arm beats the best committed way in every cell: by 27.5 pp at V0 fresh (over the +15 pp ceiling), 13.5 pp at V0 full, 5.0 pp at V5 fresh and 8.0 pp at V5 full.
- **Scattering is not yet punished (G4).** R sits between 1.0 pp below and 2.0 pp above the worst committed way in every cell; the gate asks for 25 pp below.
- **Insisting does not yet steady the flame (G5).** The committed pilots hold their way (75.5-98.5% end dominant in it), but only 1.0-56.0% of their runs are Steady by the end of Act 1 and at most 17.0% True by the end of Act 2.
- **The fresh pool is the hard cell.** Committed ways win 4.0-7.5% at V0 fresh against 19.5-35.5% in the full pool; the adaptive arm falls from 49.0% to 35.0%.
- **Adaptive diversity (G6)** holds at V0 fresh and V5 full. It fails at V0 full, where Lantern takes 60.2% of A's wins, and at V5 fresh, where Shatter takes 8 of A's 11 wins.
- **The descriptors separate the ways.** Per fight at V0 full, the Shatter arm shatters most (1.45, against 1.01-1.06 for the other committed arms), the Lantern arm gains and spends the most Embers (9.60 and 8.19), and the Edge arm applies the most Cracked of the committed arms (3.93).
- **The instrument holds (G7).** No stalls, no errors, and every replay identical in all four cells.

The lock's calibration order continues from this baseline: the Soot leak, then Steady and True lantern quality, then recognition at the boss and like-calls-to-like.
