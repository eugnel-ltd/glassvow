# Readout 3: the Soot leak and the lantern's quality

**Date:** 2026-09-29. **Lock:** [the Flame design lock](../README.md), §5 (tiers and the lantern's quality, Option C) and §11, calibration steps 2 and 3, delivered by lock PR 4 (§12 row 4): first the Soot leak, then the Steady and True lantern quality, then the small Soot sweep the orchestrator's contract allows when the full-pool cells miss G4. Everything else is as [readout 4a](readout-4a.md) measured it (recognition at the boss, like-calls-to-like and the Edge way's content in place). Readout 4a is the latest readout on `main`, so every delta below is against it, on the same paired seeds.

**Instrument heads** (branch `feat/flame-pr4-lantern-quality`):

- `665a127c75c9f85718c2ac46ca0cad50bb1cc71e`: the lantern's quality in the combat rules, every knob at zero. Content SHA-256 `8a54f23c76dcab2a666e317805a3471256a63cd9df509149a3f0ddd9b12d1b80`. Its readout reproduces readout 4a's tables byte for byte in all four cells (the same 4,000 runs and 12 replays), so the new code is inert at zero.
- `9d0a6704827a8b32747d52ad8bfbc8a151966ff6`: step 3a, the Soot leak. Content SHA-256 `38f933e592d52d851c32c6628f278ae1affa04c8d8d1dfa65f77e9657fd3f58c`.
- `a2d41beca7001fdfbb9016ec8aed8995d9ab0f7e`: step 3b, the Soot leak plus the Steady and True quality at the lock's values. Content SHA-256 `962288c6a5a56207da5caa65f70fae71b83cd7d7bfdb9080170c12c0224b4f7d`. These are the shipped values.
- The sweep ran at `a2d41bec` with the knobs edited in the working copy of `content/full-content.json` for each point, never committed; each point's content SHA-256 is in its table row below.

The branch was rebased onto `main` at `4b63cb33` (lock PR 5, presentation only) after the first runs; every table below came out byte for byte the same at the pre-rebase heads `1a13282d`, `3c6207de` and `f0ed6c22` and at the rebased heads above, sweep included. The commit that adds this file changes nothing else. **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, on a 10-core Apple Silicon Mac shared with other test runs (wall time is not a benchmark).

## What the lantern's quality is

The flame read at combat start sets the lantern's quality for the whole fight, in the combat rules; the knobs live in content at `aspects[0].flame.lantern`, each a whole number of at least 0:

| Tier | Effect | Knobs |
|---|---|---|
| Soot | At the end of each of the player's turns the lantern loses `sootLeak` Embers. The Art costs `sootArtCost` more. | `sootLeak`, `sootArtCost` |
| Kindling | None: the plain lantern. | |
| Steady | The Ember cap is `steadyCap` higher. The first Ember gain of each turn yields `steadyFirstGain` more. | `steadyCap`, `steadyFirstGain` |
| True | As Steady, and the Art costs `trueArtCost` less, never below 1. | `trueArtCost` |

The effect is the same for all three ways, and the Ashwarden, who has no ways, always reads Kindling. The tier is derived from the deck at combat start and never saved; a deck that changes mid-fight changes nothing until the next combat start.

Where the lock left a rule open, the conservative reading was taken:

- The leak lands as the player's turn ends, after the hand's burn and hex damage and after Metallicize and Regen, before the hand is discarded and before any foe acts. Leaked Embers are lost, not spent: `run.stats.embersSpent` and the deed Fire Given Freely do not count them, and the lantern never goes below 0.
- The Art's price moves for whichever Art the run carries (Flare unless the Lamplighter swapped it). True's floor of 1 never raises an Art that costs less.
- The Steady cap bonus is added after the start-of-combat relics, so it stacks on the Crown of Cinders: a Steady or True lantern with the crown holds 14 Embers.
- "The first Ember gain of each turn" is the first gain with a positive amount while that turn's number stands; the foes' phase belongs to the player turn it follows. The bonus joins the gain before the Hollow Lamplighter's tithe and before the cap, so a full lantern wastes it. `run.stats.embersGained` counts only what the lantern actually caught.

## How it was run

```sh
# Steps 3a and 3b, each at its head, on the default seeds 13000-13199:
python3 -B tools/balance_ways.py --jobs 6 --out-dir <a new, empty directory>
# The sweep, at a2d41bec, with aspects[0].flame.lantern set for each point:
python3 -B tools/balance_ways.py --seeds 13200-13299 --jobs 6 --out-dir <a new, empty directory>
```

- **Seeds:** 13000-13199 (200 paired seeds, common random numbers across the five arms) for steps 3a and 3b, as in readouts 1, 2 and 4a; 13200-13299 (100 paired seeds) for the sweep, as the contract sets it, with the zero-knob configuration run on the same seeds as its paired reference. Both bands sit in the calibration band 13000-13399. The acceptance seeds 3000-5199 were not touched.
- **Cells and arms:** as readout 4a: Duskblade at vows 0 and 5 with the shipping vow incentives, fresh and full pool; C_shatter, C_lantern and C_edge (committed), A (adaptive) and R (random build).
- **Cost:** 4,012 runs in 26-27 s per step; 2,012 runs in 15 s per sweep point.

The rows read as in readout 1: own way at end is the share of the arm's runs whose deck ends dominant in the arm's way; G5 counts a committed run only when its own way is Steady or True at the end of Act 1 and True at the end of Act 2, over every run; G6 splits the adaptive arm's wins by their dominant way at run end.

## Step 3a: the Soot leak

`sootLeak` 1, `sootArtCost` 1; Steady and True at 0. Head `9d0a6704`.

### Step 3a, V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 17/200 | 8.5% | 5.4%-13.2% | 91.0% | 24.0% | 1.0% | 0 | 0 |
| C_lantern | 8/200 | 4.0% | 2.0%-7.7% | 90.0% | 23.5% | 1.5% | 0 | 0 |
| C_edge | 4/200 | 2.0% | 0.8%-5.0% | 99.0% | 44.0% | 0.5% | 0 | 0 |
| A | 59/200 | 29.5% | 23.6%-36.2% | - | - | - | 0 | 0 |
| R | 7/200 | 3.5% | 1.7%-7.0% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.06 | 2.63 | 4.80 | 3.01 | 6.10 |
| C_lantern | 0.91 | 2.77 | 6.26 | 3.03 | 7.71 |
| C_edge | 0.83 | 2.60 | 4.23 | 4.37 | 5.56 |
| A | 1.03 | 2.61 | 4.96 | 4.11 | 6.95 |
| R | 0.95 | 2.45 | 4.44 | 3.59 | 5.95 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 2.0% | >= 40.0% | FAIL |
| G2 parity: the ways are comparable | 6.5 pp (C_shatter - C_edge) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 29.5% vs best 8.5% (+21.0 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 3.5% vs worst 2.0% (+1.5 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 11.9%, lantern 22.0%, edge 66.1% of 59 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3a, V0, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 75/200 | 37.5% | 31.1%-44.4% | 93.0% | 26.5% | 2.0% | 0 | 0 |
| C_lantern | 24/200 | 12.0% | 8.2%-17.2% | 98.5% | 46.0% | 6.5% | 0 | 0 |
| C_edge | 17/200 | 8.5% | 5.4%-13.2% | 100.0% | 71.0% | 10.0% | 0 | 0 |
| A | 85/200 | 42.5% | 35.9%-49.4% | - | - | - | 0 | 0 |
| R | 27/200 | 13.5% | 9.4%-18.9% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.46 | 2.45 | 5.73 | 3.77 | 6.96 |
| C_lantern | 1.06 | 2.58 | 7.93 | 3.98 | 9.19 |
| C_edge | 0.87 | 2.24 | 4.37 | 4.62 | 5.49 |
| A | 1.23 | 2.42 | 6.02 | 5.21 | 7.84 |
| R | 1.07 | 2.34 | 5.20 | 4.13 | 6.52 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 8.5% | >= 50.0% | FAIL |
| G2 parity: the ways are comparable | 29.0 pp (C_shatter - C_edge) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 42.5% vs best 37.5% (+5.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 13.5% vs worst 8.5% (+5.0 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 2.4%, lantern 18.8%, edge 78.8% of 85 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3a, V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 0/200 | 0.0% | 0.0%-1.9% | 91.5% | 8.0% | 0.0% | 0 | 0 |
| C_lantern | 0/200 | 0.0% | 0.0%-1.9% | 73.5% | 4.0% | 0.0% | 0 | 0 |
| C_edge | 0/200 | 0.0% | 0.0%-1.9% | 97.0% | 5.5% | 0.0% | 0 | 0 |
| A | 5/200 | 2.5% | 1.1%-5.7% | - | - | - | 0 | 0 |
| R | 1/200 | 0.5% | 0.1%-2.8% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 0.84 | 2.58 | 4.39 | 2.56 | 5.70 |
| C_lantern | 0.82 | 2.73 | 5.26 | 2.73 | 6.76 |
| C_edge | 0.80 | 2.61 | 4.25 | 3.75 | 5.60 |
| A | 0.86 | 2.67 | 4.54 | 3.20 | 6.44 |
| R | 0.88 | 2.46 | 4.30 | 3.26 | 5.81 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_shatter 0.0% | no threshold for this cell | n/a |
| G2 parity: the ways are comparable | 0.0 pp (C_shatter - C_shatter) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 2.5% vs best 0.0% (+2.5 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 0.5% vs worst 0.0% (+0.5 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 100.0%, lantern 0.0%, edge 0.0% of 5 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3a, V5, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 23/200 | 11.5% | 7.8%-16.7% | 86.0% | 12.0% | 0.0% | 0 | 0 |
| C_lantern | 4/200 | 2.0% | 0.8%-5.0% | 97.0% | 16.5% | 1.5% | 0 | 0 |
| C_edge | 3/200 | 1.5% | 0.5%-4.3% | 100.0% | 34.5% | 1.5% | 0 | 0 |
| A | 25/200 | 12.5% | 8.6%-17.8% | - | - | - | 0 | 0 |
| R | 6/200 | 3.0% | 1.4%-6.4% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.24 | 2.46 | 5.42 | 3.39 | 6.63 |
| C_lantern | 0.97 | 2.52 | 6.86 | 3.59 | 8.19 |
| C_edge | 0.87 | 2.26 | 4.46 | 4.31 | 5.58 |
| A | 1.06 | 2.34 | 5.22 | 4.09 | 7.08 |
| R | 1.01 | 2.29 | 4.99 | 3.68 | 6.42 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 1.5% | >= 25.0% | FAIL |
| G2 parity: the ways are comparable | 10.0 pp (C_shatter - C_edge) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 12.5% vs best 11.5% (+1.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 3.0% vs worst 1.5% (+1.5 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 12.0%, lantern 4.0%, edge 84.0% of 25 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3a against readout 4a

| Cell | Arm | Readout 4a | Step 3a | Delta |
|---|---|---:|---:|---:|
| V0, fresh | C_shatter | 17/200 (8.5%) | 17/200 (8.5%) | +0.0 pp |
| V0, fresh | C_lantern | 9/200 (4.5%) | 8/200 (4.0%) | -0.5 pp |
| V0, fresh | C_edge | 4/200 (2.0%) | 4/200 (2.0%) | +0.0 pp |
| V0, fresh | A | 65/200 (32.5%) | 59/200 (29.5%) | -3.0 pp |
| V0, fresh | R | 7/200 (3.5%) | 7/200 (3.5%) | +0.0 pp |
| V0, full | C_shatter | 77/200 (38.5%) | 75/200 (37.5%) | -1.0 pp |
| V0, full | C_lantern | 25/200 (12.5%) | 24/200 (12.0%) | -0.5 pp |
| V0, full | C_edge | 17/200 (8.5%) | 17/200 (8.5%) | +0.0 pp |
| V0, full | A | 78/200 (39.0%) | 85/200 (42.5%) | +3.5 pp |
| V0, full | R | 30/200 (15.0%) | 27/200 (13.5%) | -1.5 pp |
| V5, fresh | C_shatter | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | C_lantern | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | C_edge | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | A | 10/200 (5.0%) | 5/200 (2.5%) | -2.5 pp |
| V5, fresh | R | 2/200 (1.0%) | 1/200 (0.5%) | -0.5 pp |
| V5, full | C_shatter | 24/200 (12.0%) | 23/200 (11.5%) | -0.5 pp |
| V5, full | C_lantern | 4/200 (2.0%) | 4/200 (2.0%) | +0.0 pp |
| V5, full | C_edge | 3/200 (1.5%) | 3/200 (1.5%) | +0.0 pp |
| V5, full | A | 34/200 (17.0%) | 25/200 (12.5%) | -4.5 pp |
| V5, full | R | 9/200 (4.5%) | 6/200 (3.0%) | -1.5 pp |

| Cell | Arm | Steady by end of Act 1 | True by end of Act 2 | Own way at end |
|---|---|---|---|---|
| V0, fresh | C_shatter | 24.0% -> 24.0% | 1.0% -> 1.0% | 92.0% -> 91.0% |
| V0, fresh | C_lantern | 23.5% -> 23.5% | 1.5% -> 1.5% | 91.5% -> 90.0% |
| V0, fresh | C_edge | 44.0% -> 44.0% | 0.5% -> 0.5% | 99.0% -> 99.0% |
| V0, full | C_shatter | 26.5% -> 26.5% | 2.0% -> 2.0% | 91.0% -> 93.0% |
| V0, full | C_lantern | 46.0% -> 46.0% | 6.5% -> 6.5% | 99.0% -> 98.5% |
| V0, full | C_edge | 71.0% -> 71.0% | 10.0% -> 10.0% | 100.0% -> 100.0% |
| V5, fresh | C_shatter | 8.0% -> 8.0% | 0.0% -> 0.0% | 91.0% -> 91.5% |
| V5, fresh | C_lantern | 4.0% -> 4.0% | 0.0% -> 0.0% | 74.5% -> 73.5% |
| V5, fresh | C_edge | 5.5% -> 5.5% | 0.0% -> 0.0% | 98.0% -> 97.0% |
| V5, full | C_shatter | 12.0% -> 12.0% | 0.0% -> 0.0% | 87.5% -> 86.0% |
| V5, full | C_lantern | 16.5% -> 16.5% | 1.5% -> 1.5% | 97.5% -> 97.0% |
| V5, full | C_edge | 34.5% -> 34.5% | 1.5% -> 1.5% | 100.0% -> 100.0% |

| Cell | Gate | Readout 4a | Step 3a |
|---|---|---|---|
| V0, fresh | G1 viability | FAIL: worst C_edge 2.0% | FAIL: worst C_edge 2.0% |
| V0, fresh | G2 parity | PASS: 6.5 pp (C_shatter - C_edge) | PASS: 6.5 pp (C_shatter - C_edge) |
| V0, fresh | G3 skill | FAIL: A 32.5% vs best 8.5% (+24.0 pp) | FAIL: A 29.5% vs best 8.5% (+21.0 pp) |
| V0, fresh | G4 random loses | FAIL: R 3.5% vs worst 2.0% (+1.5 pp) | FAIL: R 3.5% vs worst 2.0% (+1.5 pp) |
| V0, fresh | G5 reachability | FAIL: Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) | FAIL: Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) |
| V0, fresh | G6 diversity | FAIL: shatter 15.4%, lantern 18.5%, edge 66.2% of 65 A wins | FAIL: shatter 11.9%, lantern 22.0%, edge 66.1% of 59 A wins |
| V0, fresh | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V0, full | G1 viability | FAIL: worst C_edge 8.5% | FAIL: worst C_edge 8.5% |
| V0, full | G2 parity | FAIL: 30.0 pp (C_shatter - C_edge) | FAIL: 29.0 pp (C_shatter - C_edge) |
| V0, full | G3 skill | PASS: A 39.0% vs best 38.5% (+0.5 pp) | PASS: A 42.5% vs best 37.5% (+5.0 pp) |
| V0, full | G4 random loses | FAIL: R 15.0% vs worst 8.5% (+6.5 pp) | FAIL: R 13.5% vs worst 8.5% (+5.0 pp) |
| V0, full | G5 reachability | FAIL: Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) | FAIL: Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) |
| V0, full | G6 diversity | FAIL: shatter 1.3%, lantern 17.9%, edge 80.8% of 78 A wins | FAIL: shatter 2.4%, lantern 18.8%, edge 78.8% of 85 A wins |
| V0, full | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V5, fresh | G1 viability | n/a: worst C_shatter 0.0% | n/a: worst C_shatter 0.0% |
| V5, fresh | G2 parity | PASS: 0.0 pp (C_shatter - C_shatter) | PASS: 0.0 pp (C_shatter - C_shatter) |
| V5, fresh | G3 skill | PASS: A 5.0% vs best 0.0% (+5.0 pp) | PASS: A 2.5% vs best 0.0% (+2.5 pp) |
| V5, fresh | G4 random loses | FAIL: R 1.0% vs worst 0.0% (+1.0 pp) | FAIL: R 0.5% vs worst 0.0% (+0.5 pp) |
| V5, fresh | G5 reachability | FAIL: Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | FAIL: Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) |
| V5, fresh | G6 diversity | PASS: shatter 50.0%, lantern 0.0%, edge 50.0% of 10 A wins | FAIL: shatter 100.0%, lantern 0.0%, edge 0.0% of 5 A wins |
| V5, fresh | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V5, full | G1 viability | FAIL: worst C_edge 1.5% | FAIL: worst C_edge 1.5% |
| V5, full | G2 parity | FAIL: 10.5 pp (C_shatter - C_edge) | PASS: 10.0 pp (C_shatter - C_edge) |
| V5, full | G3 skill | PASS: A 17.0% vs best 12.0% (+5.0 pp) | PASS: A 12.5% vs best 11.5% (+1.0 pp) |
| V5, full | G4 random loses | FAIL: R 4.5% vs worst 1.5% (+3.0 pp) | FAIL: R 3.0% vs worst 1.5% (+1.5 pp) |
| V5, full | G5 reachability | FAIL: Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) | FAIL: Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) |
| V5, full | G6 diversity | FAIL: shatter 17.6%, lantern 17.6%, edge 64.7% of 34 A wins | FAIL: shatter 12.0%, lantern 4.0%, edge 84.0% of 25 A wins |
| V5, full | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |

Per-gate gaps (Readout 4a -> Step 3a; pp):

| Cell | G1 worst committed | G2 spread | G3 A - best | G4 R - worst | R | G5 Steady min | G5 True min |
|---|---:|---:|---:|---:|---:|---:|---:|
| V0, fresh | 2.0 -> 2.0 | 6.5 -> 6.5 | +24.0 -> +21.0 | +1.5 -> +1.5 | 3.5 -> 3.5 | 23.5 -> 23.5 | 0.5 -> 0.5 |
| V0, full | 8.5 -> 8.5 | 30.0 -> 29.0 | +0.5 -> +5.0 | +6.5 -> +5.0 | 15.0 -> 13.5 | 26.5 -> 26.5 | 2.0 -> 2.0 |
| V5, fresh | 0.0 -> 0.0 | 0.0 -> 0.0 | +5.0 -> +2.5 | +1.0 -> +0.5 | 1.0 -> 0.5 | 4.0 -> 4.0 | 0.0 -> 0.0 |
| V5, full | 1.5 -> 1.5 | 10.5 -> 10.0 | +5.0 -> +1.0 | +3.0 -> +1.5 | 4.5 -> 3.0 | 12.0 -> 12.0 | 0.0 -> 0.0 |

## Step 3b: the Soot leak and the Steady and True quality

`sootLeak` 1, `sootArtCost` 1, `steadyCap` 2, `steadyFirstGain` 1, `trueArtCost` 1: the lock's §5 initial values. Head `a2d41bec`. This step moves the seed-1000 digest pinned in `tests/test_balance_sim.gd`, re-pinned in the step's own commit: that run's Edge deck reads True by its tenth fight, the one it lost with the plain lantern, and with the lantern's quality it survives it and wins after 29 fights. With every knob at zero the same run still replays main's old digest, which the test also checks.

### Step 3b, V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 21/200 | 10.5% | 7.0%-15.5% | 91.0% | 32.5% | 2.5% | 0 | 0 |
| C_lantern | 9/200 | 4.5% | 2.4%-8.3% | 89.5% | 30.0% | 2.0% | 0 | 0 |
| C_edge | 16/200 | 8.0% | 5.0%-12.6% | 99.0% | 57.5% | 4.0% | 0 | 0 |
| A | 57/200 | 28.5% | 22.7%-35.1% | - | - | - | 0 | 0 |
| R | 6/200 | 3.0% | 1.4%-6.4% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.07 | 2.59 | 5.43 | 3.00 | 6.83 |
| C_lantern | 0.88 | 2.73 | 6.91 | 2.96 | 8.86 |
| C_edge | 0.77 | 2.49 | 5.68 | 4.23 | 7.23 |
| A | 1.03 | 2.60 | 5.21 | 4.08 | 7.28 |
| R | 0.94 | 2.45 | 4.67 | 3.62 | 6.19 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 4.5% | >= 40.0% | FAIL |
| G2 parity: the ways are comparable | 6.0 pp (C_shatter - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 28.5% vs best 10.5% (+18.0 pp) | -3 pp to +15 pp | FAIL |
| G4 random loses: scattering cannot win | R 3.0% vs worst 4.5% (-1.5 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 30.0% (C_lantern); True by end of Act 2 min 2.0% (C_lantern) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 12.3%, lantern 22.8%, edge 64.9% of 57 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3b, V0, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 82/200 | 41.0% | 34.4%-47.9% | 92.5% | 29.0% | 1.5% | 0 | 0 |
| C_lantern | 41/200 | 20.5% | 15.5%-26.6% | 98.5% | 53.0% | 12.0% | 1 | 0 |
| C_edge | 30/200 | 15.0% | 10.7%-20.6% | 100.0% | 82.5% | 21.5% | 0 | 0 |
| A | 88/200 | 44.0% | 37.3%-50.9% | - | - | - | 0 | 0 |
| R | 30/200 | 15.0% | 10.7%-20.6% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.45 | 2.42 | 6.31 | 3.74 | 7.77 |
| C_lantern | 1.03 | 2.52 | 9.03 | 4.06 | 11.12 |
| C_edge | 0.80 | 2.10 | 5.66 | 4.60 | 7.07 |
| A | 1.20 | 2.39 | 6.39 | 5.14 | 8.27 |
| R | 1.05 | 2.33 | 5.56 | 4.12 | 6.93 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 15.0% | >= 50.0% | FAIL |
| G2 parity: the ways are comparable | 26.0 pp (C_shatter - C_edge) | <= 10.0 pp | FAIL |
| G3 skill: reading offers pays, commitment is no trap | A 44.0% vs best 41.0% (+3.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 15.0% vs worst 15.0% (+0.0 pp) | R <= worst - 25 pp and R < 35.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 29.0% (C_shatter); True by end of Act 2 min 1.5% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 2.3%, lantern 17.0%, edge 80.7% of 88 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 1 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | FAIL |

### Step 3b, V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 2/200 | 1.0% | 0.3%-3.6% | 91.5% | 14.0% | 0.0% | 0 | 0 |
| C_lantern | 0/200 | 0.0% | 0.0%-1.9% | 73.0% | 6.0% | 0.0% | 0 | 0 |
| C_edge | 0/200 | 0.0% | 0.0%-1.9% | 97.0% | 12.5% | 0.5% | 0 | 0 |
| A | 6/200 | 3.0% | 1.4%-6.4% | - | - | - | 0 | 0 |
| R | 1/200 | 0.5% | 0.1%-2.8% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 0.85 | 2.55 | 4.94 | 2.55 | 6.33 |
| C_lantern | 0.80 | 2.72 | 5.68 | 2.66 | 7.30 |
| C_edge | 0.75 | 2.51 | 5.32 | 3.60 | 6.74 |
| A | 0.86 | 2.65 | 4.74 | 3.17 | 6.68 |
| R | 0.87 | 2.44 | 4.54 | 3.23 | 6.06 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_lantern 0.0% | no threshold for this cell | n/a |
| G2 parity: the ways are comparable | 1.0 pp (C_shatter - C_lantern) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 3.0% vs best 1.0% (+2.0 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 0.5% vs worst 0.0% (+0.5 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 6.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 100.0%, lantern 0.0%, edge 0.0% of 6 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3b, V5, full pool

| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 | True by end of Act 2 | Stalls | Errors |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| C_shatter | 23/200 | 11.5% | 7.8%-16.7% | 86.5% | 13.0% | 0.5% | 0 | 0 |
| C_lantern | 8/200 | 4.0% | 2.0%-7.7% | 97.0% | 20.0% | 3.5% | 0 | 0 |
| C_edge | 5/200 | 2.5% | 1.1%-5.7% | 100.0% | 45.5% | 4.5% | 0 | 0 |
| A | 28/200 | 14.0% | 9.9%-19.5% | - | - | - | 0 | 0 |
| R | 5/200 | 2.5% | 1.1%-5.7% | - | - | - | 0 | 0 |

| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |
|---|---:|---:|---:|---:|---:|
| C_shatter | 1.22 | 2.44 | 5.78 | 3.34 | 7.11 |
| C_lantern | 0.94 | 2.47 | 7.60 | 3.56 | 9.46 |
| C_edge | 0.80 | 2.16 | 5.59 | 4.23 | 6.92 |
| A | 1.07 | 2.32 | 5.46 | 4.13 | 7.39 |
| R | 1.00 | 2.29 | 5.24 | 3.69 | 6.72 |

| Gate | Measured | Threshold | Verdict |
|---|---|---|---|
| G1 viability: each committed way wins | worst C_edge 2.5% | >= 25.0% | FAIL |
| G2 parity: the ways are comparable | 9.0 pp (C_shatter - C_edge) | <= 10.0 pp | PASS |
| G3 skill: reading offers pays, commitment is no trap | A 14.0% vs best 11.5% (+2.5 pp) | -3 pp to +15 pp | PASS |
| G4 random loses: scattering cannot win | R 2.5% vs worst 2.5% (+0.0 pp) | R <= worst - 25 pp and R < 15.0% | FAIL |
| G5 reachability: insisting gets there | Steady by end of Act 1 min 13.0% (C_shatter); True by end of Act 2 min 0.5% (C_shatter) | >= 70% and >= 40% for every committed way | FAIL |
| G6 diversity: different adaptive runs are different | shatter 10.7%, lantern 3.6%, edge 85.7% of 28 A wins | no way > 60%, >= 2 ways >= 20% | FAIL |
| G7 guards: nothing stalls, errors or replays differently | 0 stalls, 0 errors; replay 3/3 identical | zero, zero, all identical | PASS |

### Step 3b against readout 4a

| Cell | Arm | Readout 4a | Step 3b | Delta |
|---|---|---:|---:|---:|
| V0, fresh | C_shatter | 17/200 (8.5%) | 21/200 (10.5%) | +2.0 pp |
| V0, fresh | C_lantern | 9/200 (4.5%) | 9/200 (4.5%) | +0.0 pp |
| V0, fresh | C_edge | 4/200 (2.0%) | 16/200 (8.0%) | +6.0 pp |
| V0, fresh | A | 65/200 (32.5%) | 57/200 (28.5%) | -4.0 pp |
| V0, fresh | R | 7/200 (3.5%) | 6/200 (3.0%) | -0.5 pp |
| V0, full | C_shatter | 77/200 (38.5%) | 82/200 (41.0%) | +2.5 pp |
| V0, full | C_lantern | 25/200 (12.5%) | 41/200 (20.5%) | +8.0 pp |
| V0, full | C_edge | 17/200 (8.5%) | 30/200 (15.0%) | +6.5 pp |
| V0, full | A | 78/200 (39.0%) | 88/200 (44.0%) | +5.0 pp |
| V0, full | R | 30/200 (15.0%) | 30/200 (15.0%) | +0.0 pp |
| V5, fresh | C_shatter | 0/200 (0.0%) | 2/200 (1.0%) | +1.0 pp |
| V5, fresh | C_lantern | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | C_edge | 0/200 (0.0%) | 0/200 (0.0%) | +0.0 pp |
| V5, fresh | A | 10/200 (5.0%) | 6/200 (3.0%) | -2.0 pp |
| V5, fresh | R | 2/200 (1.0%) | 1/200 (0.5%) | -0.5 pp |
| V5, full | C_shatter | 24/200 (12.0%) | 23/200 (11.5%) | -0.5 pp |
| V5, full | C_lantern | 4/200 (2.0%) | 8/200 (4.0%) | +2.0 pp |
| V5, full | C_edge | 3/200 (1.5%) | 5/200 (2.5%) | +1.0 pp |
| V5, full | A | 34/200 (17.0%) | 28/200 (14.0%) | -3.0 pp |
| V5, full | R | 9/200 (4.5%) | 5/200 (2.5%) | -2.0 pp |

| Cell | Arm | Steady by end of Act 1 | True by end of Act 2 | Own way at end |
|---|---|---|---|---|
| V0, fresh | C_shatter | 24.0% -> 32.5% | 1.0% -> 2.5% | 92.0% -> 91.0% |
| V0, fresh | C_lantern | 23.5% -> 30.0% | 1.5% -> 2.0% | 91.5% -> 89.5% |
| V0, fresh | C_edge | 44.0% -> 57.5% | 0.5% -> 4.0% | 99.0% -> 99.0% |
| V0, full | C_shatter | 26.5% -> 29.0% | 2.0% -> 1.5% | 91.0% -> 92.5% |
| V0, full | C_lantern | 46.0% -> 53.0% | 6.5% -> 12.0% | 99.0% -> 98.5% |
| V0, full | C_edge | 71.0% -> 82.5% | 10.0% -> 21.5% | 100.0% -> 100.0% |
| V5, fresh | C_shatter | 8.0% -> 14.0% | 0.0% -> 0.0% | 91.0% -> 91.5% |
| V5, fresh | C_lantern | 4.0% -> 6.0% | 0.0% -> 0.0% | 74.5% -> 73.0% |
| V5, fresh | C_edge | 5.5% -> 12.5% | 0.0% -> 0.5% | 98.0% -> 97.0% |
| V5, full | C_shatter | 12.0% -> 13.0% | 0.0% -> 0.5% | 87.5% -> 86.5% |
| V5, full | C_lantern | 16.5% -> 20.0% | 1.5% -> 3.5% | 97.5% -> 97.0% |
| V5, full | C_edge | 34.5% -> 45.5% | 1.5% -> 4.5% | 100.0% -> 100.0% |

| Cell | Gate | Readout 4a | Step 3b |
|---|---|---|---|
| V0, fresh | G1 viability | FAIL: worst C_edge 2.0% | FAIL: worst C_lantern 4.5% |
| V0, fresh | G2 parity | PASS: 6.5 pp (C_shatter - C_edge) | PASS: 6.0 pp (C_shatter - C_lantern) |
| V0, fresh | G3 skill | FAIL: A 32.5% vs best 8.5% (+24.0 pp) | FAIL: A 28.5% vs best 10.5% (+18.0 pp) |
| V0, fresh | G4 random loses | FAIL: R 3.5% vs worst 2.0% (+1.5 pp) | FAIL: R 3.0% vs worst 4.5% (-1.5 pp) |
| V0, fresh | G5 reachability | FAIL: Steady by end of Act 1 min 23.5% (C_lantern); True by end of Act 2 min 0.5% (C_edge) | FAIL: Steady by end of Act 1 min 30.0% (C_lantern); True by end of Act 2 min 2.0% (C_lantern) |
| V0, fresh | G6 diversity | FAIL: shatter 15.4%, lantern 18.5%, edge 66.2% of 65 A wins | FAIL: shatter 12.3%, lantern 22.8%, edge 64.9% of 57 A wins |
| V0, fresh | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V0, full | G1 viability | FAIL: worst C_edge 8.5% | FAIL: worst C_edge 15.0% |
| V0, full | G2 parity | FAIL: 30.0 pp (C_shatter - C_edge) | FAIL: 26.0 pp (C_shatter - C_edge) |
| V0, full | G3 skill | PASS: A 39.0% vs best 38.5% (+0.5 pp) | PASS: A 44.0% vs best 41.0% (+3.0 pp) |
| V0, full | G4 random loses | FAIL: R 15.0% vs worst 8.5% (+6.5 pp) | FAIL: R 15.0% vs worst 15.0% (+0.0 pp) |
| V0, full | G5 reachability | FAIL: Steady by end of Act 1 min 26.5% (C_shatter); True by end of Act 2 min 2.0% (C_shatter) | FAIL: Steady by end of Act 1 min 29.0% (C_shatter); True by end of Act 2 min 1.5% (C_shatter) |
| V0, full | G6 diversity | FAIL: shatter 1.3%, lantern 17.9%, edge 80.8% of 78 A wins | FAIL: shatter 2.3%, lantern 17.0%, edge 80.7% of 88 A wins |
| V0, full | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | FAIL: 1 stalls, 0 errors; replay 3/3 identical |
| V5, fresh | G1 viability | n/a: worst C_shatter 0.0% | n/a: worst C_lantern 0.0% |
| V5, fresh | G2 parity | PASS: 0.0 pp (C_shatter - C_shatter) | PASS: 1.0 pp (C_shatter - C_lantern) |
| V5, fresh | G3 skill | PASS: A 5.0% vs best 0.0% (+5.0 pp) | PASS: A 3.0% vs best 1.0% (+2.0 pp) |
| V5, fresh | G4 random loses | FAIL: R 1.0% vs worst 0.0% (+1.0 pp) | FAIL: R 0.5% vs worst 0.0% (+0.5 pp) |
| V5, fresh | G5 reachability | FAIL: Steady by end of Act 1 min 4.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) | FAIL: Steady by end of Act 1 min 6.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) |
| V5, fresh | G6 diversity | PASS: shatter 50.0%, lantern 0.0%, edge 50.0% of 10 A wins | FAIL: shatter 100.0%, lantern 0.0%, edge 0.0% of 6 A wins |
| V5, fresh | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |
| V5, full | G1 viability | FAIL: worst C_edge 1.5% | FAIL: worst C_edge 2.5% |
| V5, full | G2 parity | FAIL: 10.5 pp (C_shatter - C_edge) | PASS: 9.0 pp (C_shatter - C_edge) |
| V5, full | G3 skill | PASS: A 17.0% vs best 12.0% (+5.0 pp) | PASS: A 14.0% vs best 11.5% (+2.5 pp) |
| V5, full | G4 random loses | FAIL: R 4.5% vs worst 1.5% (+3.0 pp) | FAIL: R 2.5% vs worst 2.5% (+0.0 pp) |
| V5, full | G5 reachability | FAIL: Steady by end of Act 1 min 12.0% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) | FAIL: Steady by end of Act 1 min 13.0% (C_shatter); True by end of Act 2 min 0.5% (C_shatter) |
| V5, full | G6 diversity | FAIL: shatter 17.6%, lantern 17.6%, edge 64.7% of 34 A wins | FAIL: shatter 10.7%, lantern 3.6%, edge 85.7% of 28 A wins |
| V5, full | G7 guards | PASS: 0 stalls, 0 errors; replay 3/3 identical | PASS: 0 stalls, 0 errors; replay 3/3 identical |

Per-gate gaps (Readout 4a -> Step 3b; pp):

| Cell | G1 worst committed | G2 spread | G3 A - best | G4 R - worst | R | G5 Steady min | G5 True min |
|---|---:|---:|---:|---:|---:|---:|---:|
| V0, fresh | 2.0 -> 4.5 | 6.5 -> 6.0 | +24.0 -> +18.0 | +1.5 -> -1.5 | 3.5 -> 3.0 | 23.5 -> 30.0 | 0.5 -> 2.0 |
| V0, full | 8.5 -> 15.0 | 30.0 -> 26.0 | +0.5 -> +3.0 | +6.5 -> +0.0 | 15.0 -> 15.0 | 26.5 -> 29.0 | 2.0 -> 1.5 |
| V5, fresh | 0.0 -> 0.0 | 0.0 -> 1.0 | +5.0 -> +2.0 | +1.0 -> +0.5 | 1.0 -> 0.5 | 4.0 -> 6.0 | 0.0 -> 0.0 |
| V5, full | 1.5 -> 2.5 | 10.5 -> 9.0 | +5.0 -> +2.5 | +3.0 -> +0.0 | 4.5 -> 2.5 | 12.0 -> 13.0 | 0.0 -> 0.5 |

### The stall in step 3b

G7 fails in the V0 full cell on one stall: the committed Lantern arm on seed 13043. With the plain lantern (readout 4a and step 3a) that run dies to the Act 1 boss in its ninth fight. With the Steady and True quality it reaches the final boss, the 650-HP Sovereign, with a True Lantern deck (eight Tinder, two Emberdance, four Ember Eye) and the Crown of Cinders, so a 14-Ember lantern. The simulator stops a fight at turn 30 and calls it a stall; at that point the hero has 63 of 64 HP and the Sovereign 21 of 650. A scratch replay of the simulator's run loop (not shipped) reproduces the run fight for fight and, with the guard lifted, the hero wins at turn 32 with 17 HP. So it is a long fight against a boss that stacks Ward and Fervor, not a deadlock; G7 counts it by definition, and the verdict stands. None of the five sweep configurations stalls on seeds 13200-13299.

## Step 3c: the Soot sweep

Step 3b does not reach G4 in either full-pool cell (R minus the worst committed way is 0.0 pp at V0 and at V5, where G4 needs at most -25 pp), so the contract's sweep ran: `sootLeak` in {1, 2} by `sootArtCost` in {1, 2}, each with the Steady and True values of step 3b, on 100 paired seeds. The first row is the zero-knob configuration (readout 4a's) on the same seeds, for reference.

| Point | Content SHA-256 |
|---|---|
| zero (readout 4a's configuration) | `8a54f23c76dcab2a666e317805a3471256a63cd9df509149a3f0ddd9b12d1b80` |
| leak 1, Art +1 (step 3b) | `962288c6a5a56207da5caa65f70fae71b83cd7d7bfdb9080170c12c0224b4f7d` |
| leak 1, Art +2 | `e5941b57b13c2dbec0f3f8152292af66fc3fe921543cd4b0173388a50c163a79` |
| leak 2, Art +1 | `12ae3d777458e7f763f6034f3ef618192634387efb9bf34b16a65769b56c9ddb` |
| leak 2, Art +2 | `d68a55983f5a009fb32ab814650fccfd65aca27838081d6d4860d39dc746d71a` |

| Point | Cell | C_shatter | C_lantern | C_edge | A | R | G1 | G2 | G3 (A - best) | G4 (R - worst) | G5 Steady / True min |
|---|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| zero (readout 4a's configuration) | V0, fresh | 7.0% | 2.0% | 0.0% | 34.0% | 6.0% | FAIL | PASS 7.0 pp | FAIL +27.0 pp | FAIL +6.0 pp | 21.0% / 0.0% |
| zero (readout 4a's configuration) | V0, full | 33.0% | 10.0% | 8.0% | 37.0% | 18.0% | FAIL | FAIL 25.0 pp | PASS +4.0 pp | FAIL +10.0 pp | 26.0% / 1.0% |
| zero (readout 4a's configuration) | V5, fresh | 0.0% | 0.0% | 0.0% | 5.0% | 1.0% | n/a | PASS 0.0 pp | PASS +5.0 pp | FAIL +1.0 pp | 1.0% / 0.0% |
| zero (readout 4a's configuration) | V5, full | 10.0% | 0.0% | 2.0% | 12.0% | 4.0% | FAIL | PASS 10.0 pp | PASS +2.0 pp | FAIL +4.0 pp | 11.0% / 0.0% |
| leak 1, Art +1 (step 3b) | V0, fresh | 9.0% | 2.0% | 1.0% | 28.0% | 5.0% | FAIL | PASS 8.0 pp | FAIL +19.0 pp | FAIL +4.0 pp | 25.0% / 0.0% |
| leak 1, Art +1 (step 3b) | V0, full | 36.0% | 23.0% | 17.0% | 40.0% | 22.0% | FAIL | FAIL 19.0 pp | PASS +4.0 pp | FAIL +5.0 pp | 29.0% / 0.0% |
| leak 1, Art +1 (step 3b) | V5, fresh | 0.0% | 0.0% | 0.0% | 3.0% | 0.0% | n/a | PASS 0.0 pp | PASS +3.0 pp | FAIL +0.0 pp | 5.0% / 0.0% |
| leak 1, Art +1 (step 3b) | V5, full | 7.0% | 2.0% | 3.0% | 13.0% | 5.0% | FAIL | PASS 5.0 pp | PASS +6.0 pp | FAIL +3.0 pp | 16.0% / 0.0% |
| leak 1, Art +2 | V0, fresh | 9.0% | 2.0% | 1.0% | 31.0% | 2.0% | FAIL | PASS 8.0 pp | FAIL +22.0 pp | FAIL +1.0 pp | 25.0% / 0.0% |
| leak 1, Art +2 | V0, full | 36.0% | 23.0% | 17.0% | 41.0% | 24.0% | FAIL | FAIL 19.0 pp | PASS +5.0 pp | FAIL +7.0 pp | 29.0% / 0.0% |
| leak 1, Art +2 | V5, fresh | 0.0% | 0.0% | 0.0% | 2.0% | 0.0% | n/a | PASS 0.0 pp | PASS +2.0 pp | FAIL +0.0 pp | 5.0% / 0.0% |
| leak 1, Art +2 | V5, full | 8.0% | 2.0% | 3.0% | 9.0% | 5.0% | FAIL | PASS 6.0 pp | PASS +1.0 pp | FAIL +3.0 pp | 16.0% / 0.0% |
| leak 2, Art +1 | V0, fresh | 9.0% | 2.0% | 1.0% | 27.0% | 3.0% | FAIL | PASS 8.0 pp | FAIL +18.0 pp | FAIL +2.0 pp | 25.0% / 0.0% |
| leak 2, Art +1 | V0, full | 35.0% | 23.0% | 17.0% | 40.0% | 24.0% | FAIL | FAIL 18.0 pp | PASS +5.0 pp | FAIL +7.0 pp | 29.0% / 0.0% |
| leak 2, Art +1 | V5, fresh | 0.0% | 0.0% | 0.0% | 2.0% | 0.0% | n/a | PASS 0.0 pp | PASS +2.0 pp | FAIL +0.0 pp | 5.0% / 0.0% |
| leak 2, Art +1 | V5, full | 8.0% | 2.0% | 3.0% | 12.0% | 4.0% | FAIL | PASS 6.0 pp | PASS +4.0 pp | FAIL +2.0 pp | 16.0% / 0.0% |
| leak 2, Art +2 | V0, fresh | 9.0% | 2.0% | 1.0% | 29.0% | 3.0% | FAIL | PASS 8.0 pp | FAIL +20.0 pp | FAIL +2.0 pp | 25.0% / 0.0% |
| leak 2, Art +2 | V0, full | 36.0% | 23.0% | 17.0% | 41.0% | 25.0% | FAIL | FAIL 19.0 pp | PASS +5.0 pp | FAIL +8.0 pp | 29.0% / 0.0% |
| leak 2, Art +2 | V5, fresh | 0.0% | 0.0% | 0.0% | 3.0% | 0.0% | n/a | PASS 0.0 pp | PASS +3.0 pp | FAIL +0.0 pp | 5.0% / 0.0% |
| leak 2, Art +2 | V5, full | 8.0% | 2.0% | 3.0% | 13.0% | 4.0% | FAIL | PASS 6.0 pp | PASS +5.0 pp | FAIL +2.0 pp | 16.0% / 0.0% |

No point reaches G4 in a full-pool cell: R stays 5.0 to 8.0 pp above the worst committed way at V0 and 2.0 to 3.0 pp above it at V5. A harsher Soot barely moves R, because R is rarely Soot (below). Every point keeps G7 clean. The lock's values (leak 1, Art +1) are the closest of the four at V0 full and within 1 pp of the closest at V5 full, so there is no other point to confirm on the standard seeds; step 3b above is that confirmation.

## The choice

**Shipped: `sootLeak` 1, `sootArtCost` 1, `steadyCap` 2, `steadyFirstGain` 1, `trueArtCost` 1, the lock's initial values (step 3b).** No step and no sweep point reaches G4, so, as the contract directs, the lock's initial values stay and the enemy-scalar question of the lock's §5 fallback goes to the owner. Among what was measured, step 3b is the closest to G4 with the least damage to G3:

- **G4:** step 3b closes 3.0 to 6.5 pp of readout 4a's gap in the full-pool cells (V0: +6.5 to 0.0 pp; V5: +3.0 to 0.0 pp), against 1.5 pp for the Soot leak alone. Everywhere it leaves R between 1.5 pp below and 0.5 pp above the worst committed way; G4 asks for 25 pp below.
- **G3:** no verdict changes. It fails only at V0 fresh, as in readout 4a, and moves 6.0 pp towards the band (A +24.0 to +18.0 pp over the best committed way; the ceiling is +15). Elsewhere A stays within -3 to +15 pp of the best committed way (+3.0, +2.0 and +2.5 pp).
- **G1 and G2:** the committed ways gain (C_edge +6.0 and +6.5 pp at V0, C_lantern +8.0 pp at V0 full), the worst committed way rises at V0 (2.0 to 4.5%, 8.5 to 15.0%) and V5 full (1.5 to 2.5%), and the V0 full spread narrows from 30.0 to 26.0 pp; V5 full parity turns to PASS (10.5 to 9.0 pp). G1 still fails everywhere it is graded, far below its floors.
- **G7:** the one long fight above is the cost, and it is on the record.

## What the third reading says

- **Scattering still wins as often as the weakest insisting (G4).** The lantern's quality moves the committed arms up and R hardly at all (-2.0 to 0.0 pp at step 3b), and that is still 25 pp short in every cell.
- **The Soot tier catches the adaptive pilot, not the random one.** The pilots' deck building never reads the lantern, so who fights at Soot is decided by how each arm builds. At the end of Act 1 in step 3b, A is Soot in 32-43% of its runs; R is Soot in 8-30% and lit (Steady or True) about as often, 13-29%. The random build takes fewer cards and more clear glass, so its coloured mass stays small (a median of 6.2 to 7.2, under the Soot mass of 6 in about a quarter of its runs), while the adaptive pilot collects the best coloured glass of all three ways (a median mass of 10.0 at a median purity of 0.47 to 0.50). The leak and the dearer Art therefore tax reading the offers more than scattering (the Soot leak alone, step 3a: A loses 2.5 to 4.5 pp in three cells, R at most 1.5 pp), and the Steady bonus reaches R in the runs where its random glass happens to line up.
- **Insisting is still not rewarded enough (G1, G3).** A beats the best committed way at V0 fresh by 18.0 pp; no committed way reaches its G1 floor in any graded cell.
- **G5 moves only through survival.** Steady by the end of Act 1 (minimum over the committed ways) goes from 23.5, 26.5, 4.0 and 12.0% in readout 4a to the same in step 3a and to 30.0, 29.0, 6.0 and 13.0% in step 3b; True by the end of Act 2 from 0.5, 2.0, 0.0 and 0.0% to 2.0, 1.5, 0.0 and 0.5%. No build decision reads the lantern's quality, so the rise is survival and selection: G5 counts every run, more runs now live to the end of Act 1, and more of those that do are the lit ones (C_shatter at V0 fresh: 108 of 200 reach it in readout 4a and 44% of them are Steady; 123 and 53% in step 3b). G5 stays far from 70% and 40%; its calibration is a separate task.
- **Adaptive diversity (G6)** fails in every cell at both steps. A's wins at V0 stay Edge-dominated (64.9% and 80.7% at step 3b), and at V5 fresh A wins only 5 and 6 runs, all Shatter.
- **The lantern shows in the Ember rates.** In step 3b the committed arms catch 0.7 to 1.9 more Embers per fight at V0 and spend more, the Art firing more often; A spends fewer at V0 fresh (5.54 to 5.21), where its Art costs 4.

## Who fights at which tier

Step 3b, the shipped values. The first column reads the deck at run end, the second at the end of Act 1 among the runs that reach it (n).

| Cell | Arm | End tier Soot / Kindling / Steady / True | End of Act 1 Soot / Kindling / Steady / True (of runs reaching it) |
|---|---|---|---|
| V0, fresh | C_shatter | 6% / 50% / 38% / 4% | 2% / 46% / 53% / 0% (n=123) |
| V0, fresh | C_lantern | 8% / 38% / 48% / 7% | 7% / 29% / 60% / 3% (n=96) |
| V0, fresh | C_edge | 1% / 5% / 59% / 35% | 3% / 11% / 79% / 7% (n=134) |
| V0, fresh | A | 45% / 44% / 10% / 0% | 41% / 50% / 9% / 0% (n=129) |
| V0, fresh | R | 21% / 66% / 12% / 0% | 24% / 64% / 12% / 1% (n=85) |
| V0, full | C_shatter | 7% / 46% / 44% / 3% | 5% / 57% / 37% / 1% (n=164) |
| V0, full | C_lantern | 2% / 15% / 55% / 28% | 4% / 18% / 66% / 11% (n=137) |
| V0, full | C_edge | 0% / 2% / 29% / 70% | 0% / 3% / 66% / 31% (n=170) |
| V0, full | A | 34% / 42% / 23% / 1% | 32% / 46% / 22% / 1% (n=158) |
| V0, full | R | 24% / 54% / 22% / 2% | 22% / 49% / 29% / 0% (n=131) |
| V5, fresh | C_shatter | 4% / 52% / 42% / 1% | 2% / 28% / 68% / 2% (n=40) |
| V5, fresh | C_lantern | 14% / 56% / 30% / 0% | 6% / 28% / 67% / 0% (n=18) |
| V5, fresh | C_edge | 2% / 21% / 66% / 10% | 3% / 26% / 63% / 9% (n=35) |
| V5, fresh | A | 48% / 40% / 12% / 0% | 43% / 50% / 7% / 0% (n=42) |
| V5, fresh | R | 18% / 66% / 16% / 0% | 8% / 75% / 17% / 0% (n=12) |
| V5, full | C_shatter | 8% / 58% / 32% / 1% | 10% / 57% / 33% / 0% (n=79) |
| V5, full | C_lantern | 3% / 26% / 60% / 10% | 0% / 20% / 70% / 10% (n=50) |
| V5, full | C_edge | 0% / 6% / 65% / 30% | 0% / 3% / 87% / 10% (n=94) |
| V5, full | A | 38% / 50% / 12% / 0% | 33% / 51% / 16% / 0% (n=88) |
| V5, full | R | 23% / 58% / 19% / 0% | 30% / 54% / 16% / 0% (n=50) |

Readout 4a's runs split the same way (Soot at the end of Act 1: A 34-53%, R 23-50%, the 50% on 14 runs), so this is how the pilots build, not an effect of the lantern. The same profile, read at the end of Act 1 in step 3b:

| Cell | Arm | Runs reaching the end of Act 1 | Median coloured mass | Median purity | Mass under 6 |
|---|---|---:|---:|---:|---:|
| V0, fresh | A | 129 | 10.0 | 0.47 | 2% |
| V0, fresh | R | 85 | 6.5 | 0.50 | 29% |
| V0, full | A | 158 | 10.0 | 0.50 | 1% |
| V0, full | R | 131 | 7.0 | 0.50 | 24% |
| V5, fresh | A | 42 | 10.0 | 0.47 | 0% |
| V5, fresh | R | 12 | 6.2 | 0.50 | 25% |
| V5, full | A | 88 | 10.0 | 0.47 | 0% |
| V5, full | R | 50 | 7.2 | 0.47 | 22% |

## Edge: the cards or the instrument?

Readout 4a found the committed Edge arm weaker after the Edge content landed (2.0, 8.5 and 1.5% at V0 fresh, V0 full and V5 full) with Dim the Glass drawn often but played on only 27-38% of its draws. The lantern's quality lifts C_edge to 8.0, 15.0 and 2.5% but does not change that picture: C_edge is still the weakest committed way at V0 full and V5 full, and the play pattern is the same (readout 4a, then step 3b):

| Cell | Arm | Dim the Glass held at run end, per run | Dim the Glass played per draw | Splinter Cut played per draw |
|---|---|---:|---:|---:|
| V0, fresh | C_edge | 2.02 -> 2.46 | 27.2% -> 28.3% | 79.4% -> 77.8% |
| V0, fresh | A | 1.71 -> 1.65 | 29.0% -> 27.3% | 77.3% -> 73.6% |
| V0, full | C_edge | 2.61 -> 3.08 | 38.5% -> 36.9% | 82.2% -> 80.8% |
| V0, full | A | 2.15 -> 2.18 | 36.6% -> 37.8% | 78.6% -> 79.3% |
| V5, fresh | C_edge | 1.15 -> 1.32 | 32.9% -> 32.2% | 79.5% -> 78.6% |
| V5, fresh | A | 0.90 -> 0.78 | 32.3% -> 30.8% | 71.1% -> 71.5% |
| V5, full | C_edge | 1.23 -> 1.45 | 40.5% -> 39.5% | 81.6% -> 83.1% |
| V5, full | A | 1.05 -> 1.02 | 41.6% -> 44.1% | 80.8% -> 81.9% |

C_edge holds more Dim the Glass at run end only because its runs last longer and keep taking it.

What the pilot's combat play (`tools/balance_pilot.gd`, policy `p8-d0-v1`) values, from its code:

- **Cracked before attacking** is scripted for Eclipse Slash alone: +51.7 when its target is not yet Cracked, and +34.7 more when another attack is in hand. Any other attack gains +18.1 against a foe already Cracked, which rewards following Cracked but not creating it. Splinter Cut, Eclipse Step and Ember Eye compete on their static card score plus the preview of the moment (damage and Ward). That preview counts Tremor's bonus only when the foe is already Cracked, and leaves out what Cleft and Totality add after the hit (Cleft's extra Cracked and Fervor, Totality's doubled Cracked).
- **Dimmed** has no combat term at all: Dim the Glass carries its static card score (24.7, level with Tinder and above Splinter Cut's 19.1) whatever the foe intends, and nothing prices the damage it prevents. When the foe's blow would be lethal, Ward-granting cards come first. The play loop takes every affordable card that advances the fight until the energy runs out, so an unplayed Dim the Glass is one whose turn's energy went to cards the pilot scored higher.

A discovery probe (not calibration evidence, not shipped) played fixed three-card hands with 3 energy against one durable sporeling, the pilot's order against the best of all orders:

| Hand | Pilot's order | Damage | Best order | Damage |
|---|---|---:|---|---:|
| Heavy Blow, Splinter Cut, Strike | Heavy Blow, Splinter Cut | 17 | Splinter Cut, Heavy Blow | 23 |
| Cleft, Tremor, Splinter Cut | Splinter Cut, Tremor, Cleft | 38 | Splinter Cut, Cleft, Tremor | 44 |
| Strike, Splinter Cut, Cleft | Splinter Cut, Cleft, Strike | 27 | the same | 27 |
| Strike, Splinter Cut, Tremor | Splinter Cut, Tremor, Strike | 35 | Splinter Cut, Strike, Tremor | 35 |
| Strike, Strike, Splinter Cut | Splinter Cut, Strike, Strike | 23 | the same | 23 |
| Eclipse Slash, Strike, Cleft | Eclipse Slash, Cleft | 19 | the same | 19 |

In each hand holding Dim the Glass, the pilot played it first. So the committed Edge pilot builds decks whose value depends on order (Cracked before the big hit, Cleft's Fervor before a multi-hit) that its combat play performs only for Eclipse Slash, and it spends energy on Dimmed by static rank rather than by the blow it would soften. Edge's weakness in these readouts is therefore confounded with the instrument. A pilot that prices Cracked before the hit and Dimmed against an incoming blow, or a measure of Edge by hand, would separate the two before the cards change.

G7 here covers stalls, errors and a replay of arm A's first 3 seeds per cell. The CEM stress and the save-lineage check belong to the exam; H is the human round.
