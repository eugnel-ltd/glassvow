# Readout 5: the fixed pilot, the Kindling lift and G5

**Date:** 2026-09-29. **Lock:** [the Flame design lock](../README.md), §5, §8 and §11. An independent cross-model review of the merged Flame core found four defects in the simulator pilot's play that made [readout 4a](readout-4a.md)'s reading of Edge unusable for judging card strength. This readout fixes them (phase A), measures every gate again at the fixed pilot against [readout 3](readout-3.md) and readout 4a (phase B), runs the Kindling lift experiment (phase C) and sets G5's fresh-pool figure (phase D). Three additions from the orchestrator ride along: readout 3's Edge notes in phase A's tests, the simulator's turn guard (phase A), and a bounded experiment on the Soot thresholds (phase B).

**Instrument head:** `f081e01bbbde61a821b9d70437ae75705712d70f` on `feat/flame-calibration-readout-5`, based on `main` at `11c05c7f` (lock PR 4). The commit that adds this file changes nothing else. Phase B's baseline came out byte for byte the same at `5f61d36119e3de1b55b2257bf02641dcf40ddf3c`, where every sweep ran (the same instrument before the catalogue declared `kindlingLift: 1.0` and before the grader took G5's fresh-pool figure), and at `f081e01b`. **Content:** `content/full-content.json`, SHA-256 `0911660d88e7f793d92527f1487f4dfdf14a7fbd3ca3e5d8686e7b00ebaef280`; against readout 3's shipped catalogue (`962288c6a5a56207da5caa65f70fae71b83cd7d7bfdb9080170c12c0224b4f7d`) it adds only `aspects[0].flame.kindlingLift: 1.0`, which is inert. **Pilot:** `p8-d0-v2` (readouts 1 to 4a: `p8-d0-v1`). **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, on a 10-core Apple Silicon Mac shared with other runs (wall time is not a benchmark).

## How it was run

```sh
# Phase B baseline and phase C confirmation, seeds 13000-13199 (the default):
python3 -B tools/balance_ways.py --jobs 4 --out-dir <a new, empty directory> [--content <catalogue>]
# Sweeps (lantern re-check, Soot thresholds, Kindling lift), seeds 13200-13299:
python3 -B tools/balance_ways.py --seeds 13200-13299 --jobs 4 --content <catalogue> --out-dir <a new, empty directory>
# Phase A design probes only, seeds 12000-12199:
python3 -B tools/balance_ways.py --seeds 12000-12199 --jobs 4 --out-dir <a new, empty directory>
```

- **Seeds:** 13000-13199 (200 paired seeds, common random numbers across the five arms) for the baseline and the confirmation, as in readouts 1 to 4a; 13200-13299 (100 paired seeds) for every sweep, as in readout 3's sweep; both inside the calibration band 13000-13399. The development band 12000-12199 served only phase A's design probes. The acceptance seeds 3000-5199 were not touched.
- **Catalogues:** a sweep point is the shipped catalogue with the named keys under `aspects[0].flame` set, written by a JSON round trip that reproduces the shipped file byte for byte, and passed with `--content` (new in this PR). Each point's SHA-256 is in its table; readout 3's four Soot points came out with exactly the SHA-256 values readout 3 recorded.
- **Cells and arms:** as readouts 1 to 4a: Duskblade at vows 0 and 5 with the shipping vow incentives, fresh and full pool; C_shatter, C_lantern and C_edge (committed), A (adaptive) and R (random build). Every arm plays with the same pilot; they differ only in how they build.
- **Readout 3, reproduced:** `main`'s `tools/balance_pilot.gd`, `tools/balance_policy.gd` and `tools/balance_sim.gd` (at `11c05c7f`) in a working copy of `5f61d361` reproduce readout 3's step 3b, all 72 table rows byte for byte. That run is the paired reference behind every "vs readout 3" figure below, so those deltas are the pilot's (and the turn guard's) alone.
- **Controls for the lift:** on seeds 13000-13199 the baseline, the same with `kindlingLift: 1.0` in the catalogue, and the same with the lift's code removed gave 24 identical reports each (4,012 runs).
- **Soot share:** the share of an arm's runs whose deck reads Soot, at the end of Act 1 (of the runs that reach it) and at run end, from the saved reports.
- **Cost:** about 48 s per standard run (4,012 runs) and 25 s per sweep point (2,012 runs) with 4 jobs; 21 runs in all.

The rows read as in readout 1: G5 counts a committed run only when its own way is Steady or True at the end of Act 1 and True at the end of Act 2, over every run; G6 splits the adaptive arm's wins by their dominant way at run end.

## Phase A: the pilot's play policy

### The four defects, verified

Each counterexample is a row of `tests/test_balance_pilot_play.gd`, set up by hand against sporelings so that nothing but the rule decides it. All of them failed on the old pilot before any fix.

| # | Defect | Counterexample | Old pilot | Fixed pilot |
|---|---|---|---|---|
| 1 | A lethal turn gave every Ward card 10000 + Ward; Dimmed was not part of the lethal check | HP 22, 1 energy, a 28 blow coming, Ward and Dim the Glass in hand | Ward: takes 23 and dies | Dim the Glass on the striker: the blow is 21, 1 HP left |
| 2 | An aimed card took the lowest HP, unless Smolder or a Shatter decided | (a) Dim the Glass, an HP-5 foe growing and an HP-15 foe striking; (b) Tremor, an HP-10 foe and an HP-12 Cracked foe | (a) the grower; (b) the HP-10 foe, 9 damage, no kill | (a) the striker; (b) the Cracked foe, 3 hits of 7, a kill |
| 3 | Cleft and Totality were worth the generic special weight, Tremor Faultline's flat weight; an upgrade was worth nothing | build score at the default policy | Cleft 11.35 and Totality 12.50 (under the 14.10 decline), Tremor 14.56; upgrades +0 | Cleft 20.84, Totality 24.24, Tremor 15.84; upgrades +3, +4, +3 |
| 4 | The Art fired before the hand was read | 3 Embers, 1 energy, Ember Eye and Tremor in hand | Flare, then Tremor: 18; Ember Eye unpayable | Ember Eye, then Tremor on Cracked glass: 21; the Art waits |

The fixes, one rule for every arm:

- **Lethal turns.** Plays are ranked first by the HP they spare this enemy phase, forecast against detached twins of the foes: a play's Ward joins the block, the Dimmed or lost Fervor it deals changes that foe's blow, and a foe its preview kills does not strike while one it staggers skips its move. Ward and Dimmed count alike, as the review asked; kills and Staggers count too, because a lethal turn's best answer is often the kill.
- **Targets.** An aimed card weighs every foe: a kill, then a Stagger, then the blow its Dimmed or lost Fervor would spare, then the damage it deals, then the lowest HP. The two Smolder rules stay.
- **Specials.** Faultline and Tremor (`execute`), Cleft and Totality are worth their damage, every hit counted, and a rider that needs a Cracked target (the bonus per hit, Cleft's Cracked and Fervor, Totality's doubling of at least one stack) counts at `special.crackedShare` of its value: a new policy weight, 0.5, the pilot assuming its target Cracked half the time. The rest of the `p8-d0-v1` vector is unchanged, and the CEM's frozen sample origin does not sample the new weight. Faultline moves from 21.84 to 22.12 and its upgrade from +0 to +4; the `execute` weight now serves Honing Edge alone.
- **The Art.** Priced as the fight prices it (lock §5: a Soot lantern dearer, a True one cheaper), the Art waits when paying for it would leave a playable Ember-cost card unpaid whose build score beats the score of the Art's own effects; the card is played and the Art takes the Embers left.

### What the fixes needed, and readout 3's Edge notes

Valuing the payoffs exposed an order the pilot never had: it now played Cleft and Tremor before Splinter Cut and Ember Eye, so the crack came after the hit (Cleft before Splinter Cut: 13 damage and no rider, against 17 and one more Cracked). Readout 3 had named the same gap, and that Dimmed had no combat term. Three rules close them, with no new weight:

- **Cracked before the hit.** The pilot's Eclipse Slash rule (a bonus for cracking glass that is not yet Cracked, more with an attack to follow; no Cracked-glass bonus for a card whose job is to crack) now holds for every card that cracks its target or every foe: Splinter Cut, War Cry and Ember Eye.
- **Fervor before the flurry.** A card that stokes Fervor now (Cleft on Cracked glass, Empower) takes the same follow-up bonus when an attack follows it.
- **Dimmed counts like Ward** outside a lethal turn too: the blow it spares is worth what the same Ward is worth. Against a 12 blow, Dim the Glass spares 3.

Readout 3's two fixed hands (3 energy, one durable foe) now play the best order: Quarry Maul (`heavyBlow`, readout 3's Heavy Blow), Splinter Cut and Strike deal 23 (the old order: 17), and Cleft, Tremor and Splinter Cut deal 44 (the old order: 38). Both are rows of the same test, as are the Art at a True lantern's price and Dimmed's worth. A mutation check that removed the Cracked, Fervor or Dimmed rule failed the matching rows.

### Development-band probes (design only, not calibration evidence)

Seeds 12000-12199, 200 paired seeds, win rates. The first block ran on `main` at `4b63cb33` (before the lantern's quality), the second on `11c05c7f`, both with the 30-turn guard; the fixed pilot's working copies, not commits.

| Pilot | Cell | C_shatter | C_lantern | C_edge | A | R |
|---|---|---:|---:|---:|---:|---:|
| old | V0 fresh | 6.0% | 3.5% | 1.0% | 32.5% | 4.0% |
| old | V0 full | 36.5% | 15.5% | 10.0% | 42.0% | 15.5% |
| old | V5 fresh | 0.0% | 0.0% | 0.5% | 3.5% | 0.0% |
| old | V5 full | 13.5% | 3.5% | 2.0% | 9.5% | 5.5% |
| the four fixes | V0 fresh | 5.0% | 7.0% | 1.0% | 40.5% | 6.5% |
| the four fixes | V0 full | 37.0% | 17.5% | 10.0% | 48.0% | 16.5% |
| the four fixes | V5 fresh | 0.5% | 0.5% | 0.0% | 5.5% | 0.0% |
| the four fixes | V5 full | 15.0% | 3.5% | 2.0% | 13.0% | 6.5% |
| + Cracked before the hit | V0 fresh | 4.0% | 8.0% | 2.0% | 40.0% | 6.0% |
| + Cracked before the hit | V0 full | 37.5% | 15.5% | 14.0% | 49.5% | 17.5% |
| + Cracked before the hit | V5 fresh | 0.0% | 0.5% | 0.0% | 7.5% | 0.0% |
| + Cracked before the hit | V5 full | 14.5% | 4.5% | 2.5% | 14.5% | 4.5% |
| without Fervor and Dimmed (on `11c05c7f`) | V0 fresh | 10.5% | 9.0% | 6.0% | 35.0% | 6.5% |
| without Fervor and Dimmed | V0 full | 38.0% | 25.0% | 12.5% | 49.5% | 15.5% |
| without Fervor and Dimmed | V5 fresh | 1.0% | 0.0% | 0.0% | 5.5% | 0.0% |
| without Fervor and Dimmed | V5 full | 14.0% | 4.0% | 2.5% | 15.5% | 4.0% |
| with Fervor and Dimmed | V0 fresh | 12.0% | 7.5% | 7.5% | 41.0% | 7.0% |
| with Fervor and Dimmed | V0 full | 40.5% | 23.5% | 15.5% | 44.5% | 19.0% |
| with Fervor and Dimmed | V5 fresh | 1.0% | 0.0% | 0.0% | 4.5% | 0.0% |
| with Fervor and Dimmed | V5 full | 14.0% | 3.5% | 3.5% | 14.5% | 5.0% |

The four fixes lift the adaptive arm 2.0 to 8.0 pp; Cracked before the hit adds 4.0 pp to C_edge at V0 full; the Fervor and Dimmed rules move every arm within the noise of 200 seeds (about ±5 to 7 pp at these rates). The rules stay because the unit rows decide them.

### What else changed in the instrument

- `Pilot.VERSION` is `p8-d0-v2`, and each run row records `special.crackedShare` with the rest of the policy.
- The seed-1000 digests are re-pinned in their own commit: the shipped lantern `1e665d9f…` (was `c4ddff97…`), every lantern knob at zero `f6d521a4…` (was `ecd4edc1…`, the old game with the old pilot; it is now the old game with the fixed pilot).
- The simulator's turn guard is 40 turns, not 30 (`TURN_GUARD`, its own commit): readout 3's one G7 failure was a won 32-turn fight cut off at 30. A fight still running at turn 40 is a stall and a G7 failure. The seed-1000 digests do not move with it.
- `tools/balance_ways.py --content FILE` runs the readout on a scratch catalogue.

## Phase B: the baseline at the fixed pilot

Seeds 13000-13199, the shipped lantern (readout 3's choice). "vs readout 3" is the change in win rate on the same seeds and catalogue, and the bracket after Steady by the end of Act 1 its change; both are the pilot's (and the turn guard's) alone. G5 at V5 fresh is n/a under the amended G5 row (phase D); readout 3 printed FAIL there under the row it had.

### V0, fresh pool

| Arm | Wins | Win rate | Wilson 95% | vs readout 3 | Steady by end of Act 1 | True by end of Act 2 | Soot at end of Act 1 | Soot at run end | Embers spent / gained per fight |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| C_shatter | 22/200 | 11.0% | 7.4%-16.1% | +0.5 pp | 34.0% (+1.5) | 3.5% | 2.3% | 6.5% | 5.42 / 6.82 |
| C_lantern | 16/200 | 8.0% | 5.0%-12.6% | +3.5 pp | 32.0% (+2.0) | 3.5% | 7.1% | 7.5% | 6.99 / 8.96 |
| C_edge | 12/200 | 6.0% | 3.5%-10.2% | -2.0 pp | 64.0% (+6.5) | 4.5% | 2.0% | 0.5% | 5.45 / 6.96 |
| A | 76/200 | 38.0% | 31.6%-44.9% | +9.5 pp | - | - | 39.3% | 44.0% | 5.17 / 7.21 |
| R | 11/200 | 5.5% | 3.1%-9.6% | +2.5 pp | - | - | 20.4% | 25.0% | 4.66 / 6.19 |

| Gate | Measured | Verdict | Readout 3 |
|---|---|---|---|
| G1 viability | worst C_edge 6.0% | FAIL | FAIL: worst C_lantern 4.5% |
| G2 parity | 5.0 pp (C_shatter - C_edge) | PASS | PASS: 6.0 pp (C_shatter - C_lantern) |
| G3 skill | A 38.0% vs best 11.0% (+27.0 pp) | FAIL | FAIL: A 28.5% vs best 10.5% (+18.0 pp) |
| G4 random loses | R 5.5% vs worst 6.0% (-0.5 pp) | FAIL | FAIL: R 3.0% vs worst 4.5% (-1.5 pp) |
| G5 reachability | Steady by end of Act 1 min 32.0% (C_lantern); True by end of Act 2 min 3.5% (C_shatter) | FAIL | FAIL: Steady by end of Act 1 min 30.0% (C_lantern); True by end of Act 2 min 2.0% (C_lantern) |
| G6 diversity | shatter 15.8%, lantern 9.2%, edge 75.0% of 76 A wins | FAIL | FAIL: shatter 12.3%, lantern 22.8%, edge 64.9% of 57 A wins |
| G7 guards | 0 stalls, 0 errors; replay 3/3 identical | PASS | PASS: 0 stalls, 0 errors; replay 3/3 identical |

### V0, full pool

| Arm | Wins | Win rate | Wilson 95% | vs readout 3 | Steady by end of Act 1 | True by end of Act 2 | Soot at end of Act 1 | Soot at run end | Embers spent / gained per fight |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| C_shatter | 80/200 | 40.0% | 33.5%-46.9% | -1.0 pp | 29.0% (+0.0) | 1.5% | 3.7% | 9.5% | 6.34 / 7.81 |
| C_lantern | 40/200 | 20.0% | 15.0%-26.1% | -0.5 pp | 53.5% (+0.5) | 12.5% | 4.3% | 2.0% | 9.04 / 11.14 |
| C_edge | 34/200 | 17.0% | 12.4%-22.8% | +2.0 pp | 82.5% (+0.0) | 28.0% | 0.0% | 0.0% | 5.57 / 6.98 |
| A | 92/200 | 46.0% | 39.2%-52.9% | +2.0 pp | - | - | 28.4% | 23.5% | 6.31 / 8.13 |
| R | 29/200 | 14.5% | 10.3%-20.0% | -0.5 pp | - | - | 25.2% | 23.5% | 5.59 / 6.93 |

| Gate | Measured | Verdict | Readout 3 |
|---|---|---|---|
| G1 viability | worst C_edge 17.0% | FAIL | FAIL: worst C_edge 15.0% |
| G2 parity | 23.0 pp (C_shatter - C_edge) | FAIL | FAIL: 26.0 pp (C_shatter - C_edge) |
| G3 skill | A 46.0% vs best 40.0% (+6.0 pp) | PASS | PASS: A 44.0% vs best 41.0% (+3.0 pp) |
| G4 random loses | R 14.5% vs worst 17.0% (-2.5 pp) | FAIL | FAIL: R 15.0% vs worst 15.0% (+0.0 pp) |
| G5 reachability | Steady by end of Act 1 min 29.0% (C_shatter); True by end of Act 2 min 1.5% (C_shatter) | FAIL | FAIL: Steady by end of Act 1 min 29.0% (C_shatter); True by end of Act 2 min 1.5% (C_shatter) |
| G6 diversity | shatter 6.5%, lantern 5.4%, edge 88.0% of 92 A wins | FAIL | FAIL: shatter 2.3%, lantern 17.0%, edge 80.7% of 88 A wins |
| G7 guards | 0 stalls, 0 errors; replay 3/3 identical | PASS | FAIL: 1 stalls, 0 errors; replay 3/3 identical |

### V5, fresh pool

| Arm | Wins | Win rate | Wilson 95% | vs readout 3 | Steady by end of Act 1 | True by end of Act 2 | Soot at end of Act 1 | Soot at run end | Embers spent / gained per fight |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| C_shatter | 0/200 | 0.0% | 0.0%-1.9% | -1.0 pp | 14.5% (+0.5) | 0.5% | 2.3% | 3.5% | 4.94 / 6.32 |
| C_lantern | 1/200 | 0.5% | 0.1%-2.8% | +0.5 pp | 7.0% (+1.0) | 0.0% | 9.1% | 13.0% | 5.76 / 7.36 |
| C_edge | 1/200 | 0.5% | 0.1%-2.8% | +0.5 pp | 12.5% (+0.0) | 0.0% | 0.0% | 2.0% | 5.27 / 6.67 |
| A | 10/200 | 5.0% | 2.7%-9.0% | +2.0 pp | - | - | 39.6% | 46.0% | 4.80 / 6.68 |
| R | 1/200 | 0.5% | 0.1%-2.8% | +0.0 pp | - | - | 13.3% | 16.0% | 4.58 / 6.06 |

| Gate | Measured | Verdict | Readout 3 |
|---|---|---|---|
| G1 viability | worst C_shatter 0.0% | n/a | n/a: worst C_lantern 0.0% |
| G2 parity | 0.5 pp (C_lantern - C_shatter) | PASS | PASS: 1.0 pp (C_shatter - C_lantern) |
| G3 skill | A 5.0% vs best 0.5% (+4.5 pp) | PASS | PASS: A 3.0% vs best 1.0% (+2.0 pp) |
| G4 random loses | R 0.5% vs worst 0.0% (+0.5 pp) | FAIL | FAIL: R 0.5% vs worst 0.0% (+0.5 pp) |
| G5 reachability | Steady by end of Act 1 min 7.0% (C_lantern); True by end of Act 2 min 0.0% (C_lantern) | n/a | FAIL (under the row it had): Steady by end of Act 1 min 6.0% (C_lantern); True by end of Act 2 min 0.0% (C_shatter) |
| G6 diversity | shatter 20.0%, lantern 40.0%, edge 40.0% of 10 A wins | PASS | FAIL: shatter 100.0%, lantern 0.0%, edge 0.0% of 6 A wins |
| G7 guards | 0 stalls, 0 errors; replay 3/3 identical | PASS | PASS: 0 stalls, 0 errors; replay 3/3 identical |

### V5, full pool

| Arm | Wins | Win rate | Wilson 95% | vs readout 3 | Steady by end of Act 1 | True by end of Act 2 | Soot at end of Act 1 | Soot at run end | Embers spent / gained per fight |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| C_shatter | 25/200 | 12.5% | 8.6%-17.8% | +1.0 pp | 13.5% (+0.5) | 0.0% | 7.5% | 8.5% | 5.76 / 7.08 |
| C_lantern | 4/200 | 2.0% | 0.8%-5.0% | -2.0 pp | 20.5% (+0.5) | 2.5% | 0.0% | 3.5% | 7.68 / 9.51 |
| C_edge | 9/200 | 4.5% | 2.4%-8.3% | +2.0 pp | 42.5% (-3.0) | 4.0% | 0.0% | 0.0% | 5.52 / 6.84 |
| A | 33/200 | 16.5% | 12.0%-22.3% | +2.5 pp | - | - | 26.3% | 26.5% | 5.61 / 7.39 |
| R | 6/200 | 3.0% | 1.4%-6.4% | +0.5 pp | - | - | 24.5% | 25.5% | 5.16 / 6.64 |

| Gate | Measured | Verdict | Readout 3 |
|---|---|---|---|
| G1 viability | worst C_lantern 2.0% | FAIL | FAIL: worst C_edge 2.5% |
| G2 parity | 10.5 pp (C_shatter - C_lantern) | FAIL | PASS: 9.0 pp (C_shatter - C_edge) |
| G3 skill | A 16.5% vs best 12.5% (+4.0 pp) | PASS | PASS: A 14.0% vs best 11.5% (+2.5 pp) |
| G4 random loses | R 3.0% vs worst 2.0% (+1.0 pp) | FAIL | FAIL: R 2.5% vs worst 2.5% (+0.0 pp) |
| G5 reachability | Steady by end of Act 1 min 13.5% (C_shatter); True by end of Act 2 min 0.0% (C_shatter) | FAIL | FAIL: Steady by end of Act 1 min 13.0% (C_shatter); True by end of Act 2 min 0.5% (C_shatter) |
| G6 diversity | shatter 12.1%, lantern 12.1%, edge 75.8% of 33 A wins | FAIL | FAIL: shatter 10.7%, lantern 3.6%, edge 85.7% of 28 A wins |
| G7 guards | 0 stalls, 0 errors; replay 3/3 identical | PASS | PASS: 0 stalls, 0 errors; replay 3/3 identical |

G7 here covers stalls, errors and a replay of arm A's first 3 seeds per cell. The CEM stress and the save-lineage check belong to the exam; H is the human round.

### Against readouts 4a and 3

Win rates on the same seeds. Readout 4a to readout 3 is the lantern's quality (readout 3's own finding); readout 3 to readout 5 is the pilot.

| Cell | Arm | Readout 4a | Readout 3 | Readout 5 | Pilot (3 to 5) | Since 4a |
|---|---|---:|---:|---:|---:|---:|
| V0, fresh | C_shatter | 8.5% | 10.5% | 11.0% | +0.5 pp | +2.5 pp |
| V0, fresh | C_lantern | 4.5% | 4.5% | 8.0% | +3.5 pp | +3.5 pp |
| V0, fresh | C_edge | 2.0% | 8.0% | 6.0% | -2.0 pp | +4.0 pp |
| V0, fresh | A | 32.5% | 28.5% | 38.0% | +9.5 pp | +5.5 pp |
| V0, fresh | R | 3.5% | 3.0% | 5.5% | +2.5 pp | +2.0 pp |
| V0, full | C_shatter | 38.5% | 41.0% | 40.0% | -1.0 pp | +1.5 pp |
| V0, full | C_lantern | 12.5% | 20.5% | 20.0% | -0.5 pp | +7.5 pp |
| V0, full | C_edge | 8.5% | 15.0% | 17.0% | +2.0 pp | +8.5 pp |
| V0, full | A | 39.0% | 44.0% | 46.0% | +2.0 pp | +7.0 pp |
| V0, full | R | 15.0% | 15.0% | 14.5% | -0.5 pp | -0.5 pp |
| V5, fresh | C_shatter | 0.0% | 1.0% | 0.0% | -1.0 pp | +0.0 pp |
| V5, fresh | C_lantern | 0.0% | 0.0% | 0.5% | +0.5 pp | +0.5 pp |
| V5, fresh | C_edge | 0.0% | 0.0% | 0.5% | +0.5 pp | +0.5 pp |
| V5, fresh | A | 5.0% | 3.0% | 5.0% | +2.0 pp | +0.0 pp |
| V5, fresh | R | 1.0% | 0.5% | 0.5% | +0.0 pp | -0.5 pp |
| V5, full | C_shatter | 12.0% | 11.5% | 12.5% | +1.0 pp | +0.5 pp |
| V5, full | C_lantern | 2.0% | 4.0% | 2.0% | -2.0 pp | +0.0 pp |
| V5, full | C_edge | 1.5% | 2.5% | 4.5% | +2.0 pp | +3.0 pp |
| V5, full | A | 17.0% | 14.0% | 16.5% | +2.5 pp | -0.5 pp |
| V5, full | R | 4.5% | 2.5% | 3.0% | +0.5 pp | -1.5 pp |

Per-gate gaps, readout 4a to readout 3 to readout 5 (pp):

| Cell | G1 worst committed | G2 spread | G3 A - best | G4 R - worst | R | G5 Steady min | G5 True min |
|---|---:|---:|---:|---:|---:|---:|---:|
| V0, fresh | 2.0 / 4.5 / 6.0 | 6.5 / 6.0 / 5.0 | +24.0 / +18.0 / +27.0 | +1.5 / -1.5 / -0.5 | 3.5 / 3.0 / 5.5 | 23.5 / 30.0 / 32.0 | 0.5 / 2.0 / 3.5 |
| V0, full | 8.5 / 15.0 / 17.0 | 30.0 / 26.0 / 23.0 | +0.5 / +3.0 / +6.0 | +6.5 / +0.0 / -2.5 | 15.0 / 15.0 / 14.5 | 26.5 / 29.0 / 29.0 | 2.0 / 1.5 / 1.5 |
| V5, fresh | 0.0 / 0.0 / 0.0 | 0.0 / 1.0 / 0.5 | +5.0 / +2.0 / +4.5 | +1.0 / +0.5 / +0.5 | 1.0 / 0.5 / 0.5 | 4.0 / 6.0 / 7.0 | 0.0 / 0.0 / 0.0 |
| V5, full | 1.5 / 2.5 / 2.0 | 10.5 / 9.0 / 10.5 | +5.0 / +2.5 / +4.0 | +3.0 / +0.0 / +1.0 | 4.5 / 2.5 / 3.0 | 12.0 / 13.0 / 13.5 | 0.0 / 0.5 / 0.0 |

What the pilot moved:

- **The adaptive arm most** (+9.5 pp at V0 fresh, +2.0 to +2.5 pp elsewhere). It now keeps the Edge payoffs it used to decline and plays them in order (table below), so G3 at V0 fresh widens from +18.0 to +27.0 pp over the best committed way and G6 stays Edge-dominated (75-88% of A's wins at V0 and V5 full).
- **The committed arms and R within noise:** -2.0 to +3.5 pp and -0.5 to +2.5 pp. The 95% Wilson half-widths at these rates are 1 to 7 pp.
- **Verdicts:** G7 at V0 full turns to PASS (readout 3's stall is gone: under the fixed pilot that run, C_lantern seed 13043, dies to the Sovereign at turn 19); G6 at V5 fresh turns to PASS on 10 A wins; G2 at V5 full turns to FAIL (9.0 to 10.5 pp, C_lantern -2.0 pp). Nothing else changes.

The Edge cards under the two pilots (played per draw, and copies held at run end per run):

| Cell | Arm | Card | Played per draw | Held per run |
|---|---|---|---:|---:|
| V0, fresh | C_edge | Cleft | 66.9% to 79.7% | 0.88 to 1.24 |
| V0, fresh | C_edge | Splinter Cut | 77.8% to 56.3% | 2.08 to 2.02 |
| V0, fresh | C_edge | Dim the Glass | 28.3% to 28.8% | 2.46 to 2.79 |
| V0, full | C_edge | Cleft | 69.6% to 85.3% | 0.61 to 1.00 |
| V0, full | C_edge | Totality | 72.5% to 77.9% | 0.28 to 0.52 |
| V0, full | C_edge | Ember Eye | 65.5% to 81.6% | 0.79 to 0.85 |
| V0, full | C_edge | Splinter Cut | 80.8% to 63.3% | 2.44 to 2.31 |
| V0, full | C_edge | Dim the Glass | 36.9% to 37.4% | 3.08 to 3.10 |
| V0, full | A | Cleft | 69.0% to 84.7% | 0.04 to 0.57 |
| V0, full | A | Totality | 75.0% to 71.6% | 0.01 to 0.36 |
| V5, full | C_edge | Cleft | 71.2% to 86.7% | 0.45 to 0.64 |
| V5, full | C_edge | Ember Eye | 67.6% to 76.4% | 0.67 to 0.72 |

Cleft and Ember Eye are played far more often and the adaptive arm now holds Cleft and Totality; Splinter Cut is played less because it now waits on glass that is already Cracked; Dim the Glass is played at the same rate, its fixed build score (24.7) still outweighing the few points the blow it spares adds.

### G4 afresh

G4 fails in every cell at the fixed pilot: R minus the worst committed way is -0.5, -2.5, +0.5 and +1.0 pp, where the gate asks for -25 pp. Scattering already loses in absolute terms (R 5.5% and 14.5% at V0, under the 35% ceiling; 0.5% and 3.0% at V5, under 15%); what fails is the gap, because no committed way is viable (G1's worst: 6.0, 17.0, 0.0 and 2.0%). With R where it is, G4 would pass at V0 fresh (5.5 <= 40 - 25) and V0 full (14.5 <= 50 - 25) once each way met its G1 floor, and at V5 full only once the worst way reached 28%. So G4 is now a viability question as much as a Soot question. The Soot tier still catches the adaptive arm more than the random one (at the end of Act 1: A 26-40% Soot, R 13-25%).

### The Soot thresholds

The orchestrator's bounded experiment: `sootMass` 5, then `sootMass` 5 with `sootMax` 0.50, on seeds 13200-13299, against the shipped 6 and 0.45 on the same seeds.

| Point | Content SHA-256 | Cell | C_shatter | C_lantern | C_edge | A | R | G1 | G2 | G3 (A - best) | G4 (R - worst) |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|---|
| 6, 0.45 (shipped) | `962288c6a5a5...` | V0 fresh | 14.0% | 4.0% | 4.0% | 40.0% | 4.0% | FAIL | PASS | FAIL +26.0 pp | FAIL +0.0 pp |
| 6, 0.45 (shipped) | | V0 full | 40.0% | 21.0% | 14.0% | 44.0% | 22.0% | FAIL | FAIL | PASS +4.0 pp | FAIL +8.0 pp |
| 6, 0.45 (shipped) | | V5 fresh | 0.0% | 0.0% | 0.0% | 5.0% | 2.0% | n/a | PASS | PASS +5.0 pp | FAIL +2.0 pp |
| 6, 0.45 (shipped) | | V5 full | 11.0% | 2.0% | 3.0% | 19.0% | 6.0% | FAIL | PASS | PASS +8.0 pp | FAIL +4.0 pp |
| 5, 0.45 | `fc15ee962f20...` | V0 fresh | 11.0% | 4.0% | 4.0% | 38.0% | 5.0% | FAIL | PASS | FAIL +27.0 pp | FAIL +1.0 pp |
| 5, 0.45 | | V0 full | 41.0% | 21.0% | 15.0% | 45.0% | 22.0% | FAIL | FAIL | PASS +4.0 pp | FAIL +7.0 pp |
| 5, 0.45 | | V5 fresh | 0.0% | 0.0% | 0.0% | 6.0% | 2.0% | n/a | PASS | PASS +6.0 pp | FAIL +2.0 pp |
| 5, 0.45 | | V5 full | 11.0% | 1.0% | 3.0% | 18.0% | 6.0% | FAIL | PASS | PASS +7.0 pp | FAIL +5.0 pp |
| 5, 0.50 | `9ce2a68d54ba...` | V0 fresh | 12.0% | 2.0% | 4.0% | 30.0% | 6.0% | FAIL | PASS | FAIL +18.0 pp | FAIL +4.0 pp |
| 5, 0.50 | | V0 full | 42.0% | 21.0% | 15.0% | 43.0% | 21.0% | FAIL | FAIL | PASS +1.0 pp | FAIL +6.0 pp |
| 5, 0.50 | | V5 fresh | 0.0% | 0.0% | 0.0% | 3.0% | 1.0% | n/a | PASS | PASS +3.0 pp | FAIL +1.0 pp |
| 5, 0.50 | | V5 full | 11.0% | 1.0% | 3.0% | 16.0% | 5.0% | FAIL | PASS | PASS +5.0 pp | FAIL +4.0 pp |

Soot at the end of Act 1, of the runs that reach it (V0 fresh / V0 full / V5 fresh / V5 full):

| Arm | 6, 0.45 | 5, 0.45 | 5, 0.50 |
|---|---|---|---|
| C_shatter | 3 / 4 / 0 / 10% | 3 / 12 / 0 / 5% | 6 / 13 / 0 / 12% |
| C_lantern | 9 / 2 / 10 / 6% | 9 / 2 / 10 / 6% | 14 / 5 / 11 / 6% |
| C_edge | 0 / 0 / 0 / 0% | 0 / 0 / 0 / 0% | 2 / 0 / 10 / 0% |
| A | 35 / 25 / 35 / 26% | 37 / 21 / 30 / 27% | 58 / 39 / 45 / 50% |
| R | 26 / 12 / 22 / 18% | 37 / 16 / 27 / 22% | 45 / 35 / 47 / 33% |

- `sootMass` 5 moves the random arm into Soot a little (+4 to +11 pp) and G4 not at all (R minus the worst committed way: +1.0, +7.0, +2.0 and +5.0 pp). With `sootMax` 0.50 as well, R is Soot in a third to a half of its runs, but so is the adaptive arm, and A pays for it (-10.0 pp at V0 fresh) while R does not (+2.0 pp); G4 stays between +1.0 and +6.0 pp.
- The start deck never reads Soot at any `sootMass`: its coloured mass is 3, under `minMass` 5, and the tier function reads Kindling below `minMass` before it looks at Soot. The committed arms' Act-1 decks do read Soot more often: `sootMass` 5 alone triples C_shatter's share at V0 full (4 to 12%), and `sootMax` 0.50 raises every committed way's share in at least one cell.
- **Kept: `sootMass` 6, `sootMax` 0.45.** Neither the fixed pilot nor the Soot thresholds reach G4.

### Fights over 30 turns

Across the baseline's 57,841 fights none ran past turn 30 (the longest ended at turn 30), so the 40-turn guard changed no outcome on these seeds and no fight hit it. Readout 3's one stall does not recur because the fixed pilot plays that run differently.

### The lantern knobs, re-checked

Readout 3's sweep points at the fixed pilot, seeds 13200-13299: every lantern knob at zero (readout 4a's lantern), then `sootLeak` and `sootArtCost` in {1, 2} with the Steady and True values of step 3b.

| Point | Content SHA-256 | Cell | C_shatter | C_lantern | C_edge | A | R | G1 | G2 | G3 (A - best) | G4 (R - worst) | G5 Steady / True min |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|---|---|
| zero | `8a54f23c76dc...` | V0 fresh | 13.0% | 2.0% | 1.0% | 43.0% | 8.0% | FAIL | FAIL | FAIL +30.0 pp | FAIL +7.0 pp | 22.0% / 0.0% |
| zero | | V0 full | 37.0% | 13.0% | 12.0% | 44.0% | 22.0% | FAIL | FAIL | PASS +7.0 pp | FAIL +10.0 pp | 24.0% / 0.0% |
| zero | | V5 fresh | 0.0% | 1.0% | 0.0% | 5.0% | 0.0% | n/a | PASS | PASS +4.0 pp | FAIL +0.0 pp | 1.0% / 0.0% |
| zero | | V5 full | 11.0% | 1.0% | 2.0% | 13.0% | 8.0% | FAIL | PASS | PASS +2.0 pp | FAIL +7.0 pp | 11.0% / 0.0% |
| leak 1, Art +1 (shipped) | `962288c6a5a5...` | V0 fresh | 14.0% | 4.0% | 4.0% | 40.0% | 4.0% | FAIL | PASS | FAIL +26.0 pp | FAIL +0.0 pp | 26.0% / 0.0% |
| leak 1, Art +1 (shipped) | | V0 full | 40.0% | 21.0% | 14.0% | 44.0% | 22.0% | FAIL | FAIL | PASS +4.0 pp | FAIL +8.0 pp | 29.0% / 1.0% |
| leak 1, Art +1 (shipped) | | V5 fresh | 0.0% | 0.0% | 0.0% | 5.0% | 2.0% | n/a | PASS | PASS +5.0 pp | FAIL +2.0 pp | 5.0% / 0.0% |
| leak 1, Art +1 (shipped) | | V5 full | 11.0% | 2.0% | 3.0% | 19.0% | 6.0% | FAIL | PASS | PASS +8.0 pp | FAIL +4.0 pp | 16.0% / 0.0% |
| leak 1, Art +2 | `e5941b57b13c...` | V0 fresh | 14.0% | 4.0% | 4.0% | 40.0% | 5.0% | FAIL | PASS | FAIL +26.0 pp | FAIL +1.0 pp | 26.0% / 0.0% |
| leak 1, Art +2 | | V0 full | 38.0% | 21.0% | 14.0% | 45.0% | 22.0% | FAIL | FAIL | PASS +7.0 pp | FAIL +8.0 pp | 29.0% / 1.0% |
| leak 1, Art +2 | | V5 fresh | 0.0% | 0.0% | 0.0% | 1.0% | 1.0% | n/a | PASS | PASS +1.0 pp | FAIL +1.0 pp | 5.0% / 0.0% |
| leak 1, Art +2 | | V5 full | 12.0% | 2.0% | 3.0% | 21.0% | 7.0% | FAIL | PASS | PASS +9.0 pp | FAIL +5.0 pp | 16.0% / 0.0% |
| leak 2, Art +1 | `12ae3d777458...` | V0 fresh | 14.0% | 5.0% | 4.0% | 35.0% | 4.0% | FAIL | PASS | FAIL +21.0 pp | FAIL +0.0 pp | 26.0% / 0.0% |
| leak 2, Art +1 | | V0 full | 38.0% | 21.0% | 14.0% | 44.0% | 24.0% | FAIL | FAIL | PASS +6.0 pp | FAIL +10.0 pp | 29.0% / 1.0% |
| leak 2, Art +1 | | V5 fresh | 0.0% | 0.0% | 0.0% | 2.0% | 2.0% | n/a | PASS | PASS +2.0 pp | FAIL +2.0 pp | 5.0% / 0.0% |
| leak 2, Art +1 | | V5 full | 10.0% | 2.0% | 3.0% | 18.0% | 6.0% | FAIL | PASS | PASS +8.0 pp | FAIL +4.0 pp | 16.0% / 0.0% |
| leak 2, Art +2 | `d68a55983f5a...` | V0 fresh | 13.0% | 4.0% | 4.0% | 39.0% | 4.0% | FAIL | PASS | FAIL +26.0 pp | FAIL +0.0 pp | 26.0% / 0.0% |
| leak 2, Art +2 | | V0 full | 38.0% | 21.0% | 14.0% | 47.0% | 24.0% | FAIL | FAIL | PASS +9.0 pp | FAIL +10.0 pp | 29.0% / 1.0% |
| leak 2, Art +2 | | V5 fresh | 0.0% | 0.0% | 0.0% | 3.0% | 1.0% | n/a | PASS | PASS +3.0 pp | FAIL +1.0 pp | 5.0% / 0.0% |
| leak 2, Art +2 | | V5 full | 11.0% | 2.0% | 3.0% | 22.0% | 8.0% | FAIL | PASS | PASS +11.0 pp | FAIL +6.0 pp | 16.0% / 0.0% |

No point reaches G4 in any cell. In the full-pool cells, where readout 3 made its choice, the shipped point is still the closest (V0: +8.0 pp, tied with leak 1, Art +2; V5: +4.0 pp, tied with leak 2, Art +1), and no point changes a G3 verdict. **The fixed pilot does not change which point reaches G4 with the least damage to G3, so readout 3's choice stands** and no sweep on the calibration seeds was needed to change it.

## Phase C: the Kindling lift

**The hypothesis** (readouts 1 and 2): the committed ways cannot reach Steady by the end of Act 1 often enough in a fresh pool because the base pool holds only three to five cards per way and the flame leans nowhere while it is Kindling.

**The knob.** `aspects[0].flame.kindlingLift`: while the flame is Kindling, card rewards and the shop's cards weigh every entry with at least 0.5 affinity to any way by the knob, once whatever its colours (a duo is lifted once, never squared), so coloured glass of every colour comes more often and no way above another. The shop's relics, a Soot flame and a lit flame ignore it. Each offer makes the same draws whatever the value, so the run's cursor, prices, gold, potions and rarity rolls never move with it (the card reward already draws on its detached chain). At 1 it is no lean at all: the seed-1000 digests and every existing test are unchanged, and the controls above gave identical reports. `tests/test_flame_kindling.gd` measures the lift at 1.5 on catalogue copies: shatter, lantern and edge glass draw 1.51 to 1.55 times as often as clear glass, duo glass 1.56, relics 0.99.

**The sweep**, seeds 13200-13299, all arms, all four cells; the fresh cells first:

| Point | Content SHA-256 | Cell | C_shatter | C_lantern | C_edge | A | R | Steady by end of Act 1: C_shatter / C_lantern / C_edge | G1 | G3 (A - best) | G4 (R - worst) |
|---|---|---|---:|---:|---:|---:|---:|---|---|---|---|
| 1.0 (shipped) | `962288c6a5a5...` | V0 fresh | 14.0% | 4.0% | 4.0% | 40.0% | 4.0% | 36 / 26 / 55% | FAIL | FAIL +26.0 pp | FAIL +0.0 pp |
| 1.0 (shipped) | | V5 fresh | 0.0% | 0.0% | 0.0% | 5.0% | 2.0% | 16 / 5 / 17% | n/a | PASS +5.0 pp | FAIL +2.0 pp |
| 1.25 | `d790b9f64861...` | V0 fresh | 15.0% | 4.0% | 2.0% | 31.0% | 5.0% | 37 / 20 / 60% | FAIL | FAIL +16.0 pp | FAIL +3.0 pp |
| 1.25 | | V5 fresh | 0.0% | 0.0% | 0.0% | 6.0% | 1.0% | 13 / 5 / 19% | n/a | PASS +6.0 pp | FAIL +1.0 pp |
| 1.5 | `e85c1971be54...` | V0 fresh | 11.0% | 5.0% | 1.0% | 32.0% | 7.0% | 37 / 27 / 59% | FAIL | FAIL +21.0 pp | FAIL +6.0 pp |
| 1.5 | | V5 fresh | 0.0% | 0.0% | 1.0% | 5.0% | 0.0% | 16 / 6 / 19% | n/a | PASS +4.0 pp | FAIL +0.0 pp |
| 1.0 (shipped) | | V0 full | 40.0% | 21.0% | 14.0% | 44.0% | 22.0% | 29 / 46 / 84% | FAIL | PASS +4.0 pp | FAIL +8.0 pp |
| 1.0 (shipped) | | V5 full | 11.0% | 2.0% | 3.0% | 19.0% | 6.0% | 16 / 22 / 56% | FAIL | PASS +8.0 pp | FAIL +4.0 pp |
| 1.25 | | V0 full | 31.0% | 14.0% | 11.0% | 51.0% | 23.0% | 36 / 47 / 81% | FAIL | FAIL +20.0 pp | FAIL +12.0 pp |
| 1.25 | | V5 full | 10.0% | 5.0% | 3.0% | 14.0% | 5.0% | 17 / 18 / 52% | FAIL | PASS +4.0 pp | FAIL +2.0 pp |
| 1.5 | | V0 full | 39.0% | 21.0% | 11.0% | 39.0% | 16.0% | 24 / 46 / 81% | FAIL | PASS +0.0 pp | FAIL +5.0 pp |
| 1.5 | | V5 full | 14.0% | 5.0% | 4.0% | 20.0% | 7.0% | 15 / 22 / 50% | FAIL | PASS +6.0 pp | FAIL +3.0 pp |

In the fresh cells the committed arms' Steady by the end of Act 1 moves -6 to +5 pp at 1.25 and 0 to +4 pp at 1.5, against the +10 pp the experiment needs. 1.5 is the better point and was confirmed on the standard seeds.

**The confirmation**, seeds 13000-13199, `kindlingLift` 1.5 against the baseline:

| Cell | C_shatter | C_lantern | C_edge | A | R | Steady by end of Act 1: C_shatter / C_lantern / C_edge | G1 | G3 (A - best) | G4 (R - worst) |
|---|---:|---:|---:|---:|---:|---|---|---|---|
| V0 fresh, 1.0 | 11.0% | 8.0% | 6.0% | 38.0% | 5.5% | 34.0 / 32.0 / 64.0% | FAIL | FAIL +27.0 pp | FAIL -0.5 pp |
| V0 fresh, 1.5 | 12.5% | 8.0% | 5.5% | 39.5% | 6.0% | 37.5 / 35.0 / 69.5% | FAIL | FAIL +27.0 pp | FAIL +0.5 pp |
| V0 full, 1.0 | 40.0% | 20.0% | 17.0% | 46.0% | 14.5% | 29.0 / 53.5 / 82.5% | FAIL | PASS +6.0 pp | FAIL -2.5 pp |
| V0 full, 1.5 | 37.5% | 21.0% | 19.5% | 44.0% | 21.5% | 27.0 / 60.0 / 86.0% | FAIL | PASS +6.5 pp | FAIL +2.0 pp |
| V5 fresh, 1.0 | 0.0% | 0.5% | 0.5% | 5.0% | 0.5% | 14.5 / 7.0 / 12.5% | n/a | PASS +4.5 pp | FAIL +0.5 pp |
| V5 fresh, 1.5 | 0.0% | 0.5% | 0.0% | 9.0% | 0.0% | 18.0 / 5.5 / 17.5% | n/a | PASS +8.5 pp | FAIL +0.0 pp |
| V5 full, 1.0 | 12.5% | 2.0% | 4.5% | 16.5% | 3.0% | 13.5 / 20.5 / 42.5% | FAIL | PASS +4.0 pp | FAIL +1.0 pp |
| V5 full, 1.5 | 11.5% | 4.0% | 2.0% | 9.5% | 5.0% | 18.0 / 21.0 / 44.5% | FAIL | PASS -2.0 pp | FAIL +3.0 pp |

The content SHA-256 of the 1.5 catalogue is `e85c1971be54d4a21c9b006559285668336b7eca9d835d8195ad17abd7b1cf28`. Fresh-pool Steady by the end of Act 1 rises +3.5, +3.0 and +5.5 pp at V0 and +3.5, -1.5 and +5.0 pp at V5: short of +10 pp for every committed way in both cells. The random arm gains 7.0 pp at V0 full (G4's gap from -2.5 to +2.0 pp) and the adaptive arm loses 7.0 pp at V5 full (to 2.0 pp under the best committed way). Only the full pool's Steady rises more (C_lantern +6.5 pp, C_edge +3.5 pp at V0 full), where G5 already asks for 70%.

**Why it does not work:** G5 counts every run, so it multiplies survival by reachability, and the lift only touches the second. At the baseline, among the committed runs that reach the end of Act 1 in the fresh pool, 52% (Shatter), 65% (Lantern) and 85% (Edge) are already Steady or True there, while only 65%, 49% and 75% of runs get there at V0 (22%, 11% and 19% at V5). A lift of 1.25 to 1.5 moves the median coloured mass of those decks by at most half a card. Supply is not the binding constraint; survival is.

| Cell | Arm | Reach end of Act 1 | Steady or True there | Steady by end of Act 1 (G5) | Reach end of Act 2 | True there | True by end of Act 2 (G5) |
|---|---|---:|---:|---:|---:|---:|---:|
| V0 fresh | C_shatter | 130/200 (65%) | 52% | 34.0% | 59/200 (30%) | 12% | 3.5% |
| V0 fresh | C_lantern | 98/200 (49%) | 65% | 32.0% | 52/200 (26%) | 13% | 3.5% |
| V0 fresh | C_edge | 150/200 (75%) | 85% | 64.0% | 42/200 (21%) | 21% | 4.5% |
| V0 full | C_shatter | 162/200 (81%) | 36% | 29.0% | 110/200 (55%) | 3% | 1.5% |
| V0 full | C_lantern | 141/200 (70%) | 76% | 53.5% | 88/200 (44%) | 28% | 12.5% |
| V0 full | C_edge | 169/200 (84%) | 98% | 82.5% | 87/200 (44%) | 64% | 28.0% |
| V5 fresh | C_shatter | 44/200 (22%) | 66% | 14.5% | 8/200 (4%) | 12% | 0.5% |
| V5 fresh | C_lantern | 22/200 (11%) | 64% | 7.0% | 6/200 (3%) | 0% | 0.0% |
| V5 fresh | C_edge | 38/200 (19%) | 66% | 12.5% | 1/200 (0%) | 0% | 0.0% |
| V5 full | C_shatter | 80/200 (40%) | 34% | 13.5% | 42/200 (21%) | 0% | 0.0% |
| V5 full | C_lantern | 53/200 (26%) | 77% | 20.5% | 18/200 (9%) | 28% | 2.5% |
| V5 full | C_edge | 88/200 (44%) | 97% | 42.5% | 20/200 (10%) | 40% | 4.0% |

**Shipped at 1.0.** The knob is in content at 1.0 and the mechanism stays, tested, for a later reading; the lock's §8 is unchanged (the sentence it would have gained, "Kindling lifts all coloured glass evenly; it never leans toward a way", waits for a value that earns it).

## Phase D: G5 and Edge

### G5's fresh-pool figure

The lock's §11 G5 row now reads: full pool, 70% Steady by the end of Act 1 and 40% True by the end of Act 2 (unchanged); fresh pool, V0 40% Steady by the end of Act 1, True not graded (readout 5). `tools/balance_ways.py` grades exactly that, n/a at V5 fresh as G1 is.

- **40%, from the data.** The weakest committed way's reachability in a fresh pool is Shatter's: 52% of its runs that reach the end of Act 1 are Steady there. A way that met its G1 floor would reach the end of Act 1 in about 80% of runs (Shatter does in the full pool, winning 40%). 0.8 x 52% is 42%, rounded down to 40%. The threshold then fails a way for reachability, not again for the deaths G1 already counts. At the fixed pilot Edge passes it (64.0%), and Shatter (34.0%) and Lantern (32.0%) miss it mainly through survival (65% and 49% reach the end of Act 1).
- **True is not graded in the fresh pool.** With three to five coloured cards per way, True by the end of Act 2 is rare even for the runs that get there (12-21%), and the lift did not change that.
- **V0 only.** A fresh Vigil cannot play vow 5 (vows unlock through play), which is why G1 has no fresh-pool floor at V5; G5 follows it.
- **The full-pool figure stays.** The data do not argue for moving it: Edge's full-pool reachability (98% Steady, 64% True of the runs that get there) would pass both figures at viable survival. Shatter's 36% (its full-pool decks mostly stay Kindling, with five Shatter cards and a duo in the pool) and Lantern's 28% True are content questions, not threshold ones.

### Edge at the fixed pilot

- **Viability:** C_edge wins 6.0% at V0 fresh, 17.0% at V0 full and 4.5% at V5 full, under G1's 40%, 50% and 25%, as is every committed way.
- **Weakest way?** At V0 fresh by 2.0 pp (Lantern 8.0%), at V0 full by 3.0 pp (Lantern 20.0%); at V5 fresh it is level with Lantern and above Shatter, and at V5 full it is above Lantern (4.5 against 2.0%). The condition for proposing Edge card numbers, weakest by more than 5 pp in every cell, is not met, so no numbers are proposed and Edge content is unchanged.
- **Since readout 4a:** 2.0 to 6.0% at V0 fresh, 8.5 to 17.0% at V0 full, 1.5 to 4.5% at V5 full. The lantern's quality gave most of it (readout 3); the fixed pilot, which now plays Edge's payoffs in order, added -2.0 to +2.0 pp. What remains is parity with Shatter (23.0 pp at V0 full), which Lantern shares (20.0 pp), not an Edge outlier.

## Decisions taken for the owner

- The four fixes as the review proposed them, with kills and Staggers counted beside Ward and Dimmed in a lethal turn.
- A Cracked-only rider counts at a new policy weight, `special.crackedShare` 0.5, not a constant in code; Faultline shares Tremor's rule, and the `execute` weight serves Honing Edge alone.
- Readout 3's Edge notes are fixed, not only tested: Cracked before the hit for every card that cracks, Fervor before the flurry, and Dimmed counts like Ward outside lethal turns, all with the pilot's existing weights.
- Pilot version `p8-d0-v2`; the seed-1000 digests re-pinned in their own commit.
- The simulator's turn guard is 40 turns (the orchestrator's decision), in its own commit.
- `tools/balance_ways.py --content` for sweeps, so no sweep edits the working copy.
- The lantern knobs stay at readout 3's values; the Soot thresholds stay at 6 and 0.45.
- The Kindling lift ships at 1.0: cards only (relics carry affinity but are not glass), a duo lifted once, Soot and lit flames untouched; the mechanism stays.
- G5's fresh-pool figure is V0 40% Steady by the end of Act 1, True not graded; the full-pool figure stays; the grader follows the lock.
- No Edge card numbers are proposed.

## What stays open

- **G1 and G4:** neither the fixed pilot nor the Soot thresholds reach G4, and no committed way is viable. The enemy-scalar question of the lock's §5 fallback goes to the owner with readouts 3 and 5 side by side; G4's gap would close at V0 if the ways met their G1 floors with R where it is.
- **G3 at V0 fresh (+27.0 pp) and G6 (Edge takes 75-88% of the adaptive arm's wins in three cells):** the adaptive pilot now reads the Edge payoffs well, and Edge's fresh-pool glass is the densest.
- **G5 in the full pool:** Shatter's decks stay Kindling (36% Steady of the runs that reach the end of Act 1) and nobody reaches 40% True; a content question.
- **The pilot's remaining limits:** Novaflare and Emberdance read the lantern after the Art has spent it; Resonant Lance's upgrade is still worth nothing (its special keeps a flat weight); Dim the Glass's fixed build score still decides how often it is played.
- **The exam:** the CEM stress, the historical holdout and the save-lineage check belong to the final candidate; H is the human round.
