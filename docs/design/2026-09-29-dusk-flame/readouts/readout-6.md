# Readout 6: the lantern's upside, an Act-1 enemy scalar and a splash arm

> **Research readout (AI-SDLC discovery). No content changed and nothing shipped.** Every experiment ran on a scratch copy of the catalogue passed with `--content`, or on a simulator flag that exists only on the research branch `research/flame-readout-6`. `content/full-content.json` and the frozen `docs/balance/data/421-h39/full-content.json` are untouched. No PR, no CI run, nothing promoted into production truth.

**Date:** 2026-09-30. **Lock:** [the Flame design lock](../README.md), §5 (the lantern's quality and its fallback, enemy scalars) and §11 (the instrument, gates G1 to G7 and the calibration order). **Reads with:** [readout 3](readout-3.md) and [readout 5](readout-5.md), whose numbers stand beside every experiment below on the same seeds and cells.

**The question.** Readout 5 left G4 failing in every cell because no committed way is viable. G1 asks, in the full pool, 50% at V0 and 25% at V5 and, in the fresh pool, 40% at V0; the worst committed way won 6.0, 17.0, 0.0 and 2.0% at V0 fresh, V0 full, V5 fresh and V5 full. Neither the Kindling lift nor the Soot thresholds moved it, and survival through Act 1 was named as the bottleneck. The owner now decides the lock's §5 fallback. This readout measures the three cheapest levers against one control, on the seeds and cells of readouts 3 and 5: **E1**, a bigger lantern for a lit flame (inside the lock); **E2**, an Act-1 enemy scalar (the fallback); **E3**, a splash committed arm (an instrument question: is pure commitment the trap?). Two probes beyond the brief, **X1** and **X2**, answer the two questions the first results raised: whether any enemy scalar can reach G4, and whether a splash can keep its main path.

**Instrument.** `main` at `39961b1c` (readout 5 merged: pilot `p8-d0-v2`, the 40-turn guard, `balance_ways.py --content`) for E0, E1a, E1b, E2a and E2b on seeds 13200-13299; `d0d1ec56` on this branch for E3, X1, X2 and the whole confirmation band 13000-13199. `d0d1ec56` adds only the splash-arm flag, and `72d20002` lays the same flag again without moving the declarations an older balance note cites by line (appendix C); E0, E3 and X2 re-run at `72d20002` on 13200-13299 reproduce their reports run for run. **Content:** `content/full-content.json`, SHA-256 `0911660d88e7f793d92527f1487f4dfdf14a7fbd3ca3e5d8686e7b00ebaef280` (readout 5's), and the scratch catalogues below. **Engine:** Godot 4.7.2.stable.official.ed1daf0bf, headless, in an isolated user directory, at most four Godot processes at a time on a 10-core Apple Silicon Mac shared with other runs (wall time is not a benchmark).

## The answer in brief

- **No lever reaches G1 or G4 in any graded cell, on either seed band.** The nearest to G4 is E3 at V0 fresh, where R sits 15.3 pp under the worst committed way over 300 paired seeds, against the 25 pp the gate asks; the briefed changes to the game (E1 and E2) move G4's gap by at most 6 pp either way.
- **The Act-1 enemy scalar moves the deaths, not the outcome.** At x0.8, committed Edge's Act-1 deaths at V0 fresh fall from 84 to 13 of 300 runs, and its Act-2 and Act-3 deaths rise by 68; it wins 3 more. The worst committed way gains 0.3 to 3.0 pp. The adaptive and random arms gain most (A +12.7 pp at V0 full, R +7.0 pp at V0 fresh, both significant on paired seeds), so G3 and G4 get worse and G2 widens. It is the one briefed lever that passes a gate, G5 at V0 fresh (43.7%), through survival rather than reachability.
- **A whole-run scalar (X1, x0.8 in all three acts) shows the fallback's ceiling.** It passes G1 at V0 full (worst way 55.0%), but the random arm rises with the committed ones (59.3%), so G4 fails by 29 pp and R breaks its 35% ceiling; the adaptive arm wins 84% at V0. Scalars set every arm's level; at no strength measured do they open the gap G4 grades.
- **The lantern's upside is the only change to the game that lifts insisting decks without lifting A or R, and it is small.** E1b (a lit lantern's first Ember gain of the turn +2 instead of +1, its cap +4 instead of +2, a True flame's Art 2 cheaper instead of 1) adds 5.3 pp to the worst way at V0 full (Edge 40 wins gained against 23 lost on 300 paired seeds, p = 0.04; Lantern at V5 full 10 against 0), nothing to Shatter, and changes no G3 verdict. E1a alone gives about half of it.
- **Main path plus splash is not a main path for Shatter or Lantern.** At 2.0 / 1.0 (E3), and still at 3.0 / 1.0 (X2), their decks end Edge-dominant in 68-80% (Shatter) and 35-65% (Lantern) of runs at V0, read Steady in their own way by the end of Act 1 in 0-2% and 4-18%, and win far more (Shatter 87 wins gained against 19 lost at V0 fresh). Edge is 52-58% of the coloured glass the game offers and Shatter 12-21%: a deck that does not refuse other colours becomes an Edge deck.
- **What binds is what a pure deck of each way can do, not Act 1.** Lantern dies in Act 1 (97 of 300 runs at V0 full), Edge in Act 2 (132 of 300), and Shatter's decks often stay Kindling for want of glass (33-56% at the end of Act 1); mixtures (the adaptive arm, median purity 0.47-0.51) win 45% at V0 full where the pure ways win 16-40%.

The recommendation to the owner closes this readout.

## How it was run

```sh
# Scratch catalogues from the shipped file (appendix A), into the private scratch folder:
python3 make_catalogues.py content/full-content.json <scratch>/catalogues
# E0 (no --content), E1a, E1b, E2a, E2b and X1 (one catalogue each), on each seed band:
python3 -B tools/balance_ways.py --seeds 13200-13299 --jobs 4 --out-dir <a new, empty directory> [--content <catalogue>]
python3 -B tools/balance_ways.py --seeds 13000-13199 --jobs 4 --out-dir <a new, empty directory> [--content <catalogue>]
# E3 and X2, the splash arms, on the shipped catalogue (flag from d0d1ec56, appendix C):
python3 -B tools/balance_ways.py --seeds <band> --jobs 4 --way-weights 2.0/1.0 --out-dir <a new, empty directory>
python3 -B tools/balance_ways.py --seeds <band> --jobs 4 --way-weights 3.0/1.0 --out-dir <a new, empty directory>
```

Every Godot process ran with a temporary `override.cfg` in the worktree root (`config/use_custom_user_dir=true`, `config/custom_user_dir_name="glassvow-test-r6"`), removed before the commit.

- **Seeds and cells.** 13200-13299 (100 paired seeds, common random numbers across the five arms), the band of readout 3's sweep and readout 5's re-checks, for every table the brief asks for; then 13000-13199 (200 paired seeds), the band of readouts 1 to 5's standard runs, as a confirmation of every experiment. Both lie in the calibration band 13000-13399; the acceptance seeds 3000-5199 were not touched. Cells and arms as readouts 1 to 5: Duskblade at vows 0 and 5 with the shipping vow incentives, fresh and full pool; C_shatter, C_lantern and C_edge (committed), A (adaptive) and R (random build).
- **Cost.** 17 cell tables, 50,204 runs, 710 s of wall time: 25-42 s per experiment on 100 seeds and 49-66 s on 200. Nothing in the brief was skipped.

| Experiment | What changes against `main` | Catalogue SHA-256 |
|---|---|---|
| E0, the control | nothing | `0911660d88e7f793d92527f1487f4dfdf14a7fbd3ca3e5d8686e7b00ebaef280` |
| E1a | `aspects[0].flame.lantern.steadyFirstGain` 1 to 2 | `ccad0eef177e3fcf815558ee44df30d7127e66bb06d5294ec25be6c76158ea89` |
| E1b | `steadyFirstGain` 1 to 2, `steadyCap` 2 to 4, `trueArtCost` 1 to 2 | `d3b8adcb1882b85c453e3ff07ee36eb2232dea9b1a8c5068cc9f8ad5f382910d` |
| E2a | the nine Act-1 enemies: both ends of the HP range and each move's per-hit damage x0.9 | `b618f2d2649f8bc88d53bdc2d32fb1d68e94142bc11a12db05e0b33cb0e9cb36` |
| E2b | the same x0.8 | `029b4665005b26e1b9acf31bc8714337834823dcfd2212877b7fde8c37a71e25` |
| E3 | the committed arms weigh their own glass x2.0 and other coloured glass x1.0 (the shipped pilot: 3.0 and 0.5); A and R unchanged | the shipped file |
| X1, beyond the brief | E2b's x0.8 on all 27 enemies of the three acts a run plays | `1b79c59cfb0d46350331cfc3f530375ccdb88f78301536baeed7cfebe282c8a6` |
| X2, beyond the brief | the committed arms at 3.0 / 1.0: the commitment kept, the aversion to other colours removed | the shipped file |

**How enemy strength is defined, and what E2 scaled.** An enemy's strength lives in `enemies[id]`: an HP range (`hp`, rolled once per spawn), and moves whose `dmg` is the damage of each hit (`times` hits), beside Ward, statuses, heals, ramps and added wounds. Acts pick their fights from `encounters[act]` (weak, normal, elite, boss); the nine Act-1 enemies (sporeling, duskfang, gloomslime, ashAcolyte, waylayer, thornling, gravewarden, alphaFang, rootheart) appear in `encounters[0]` and in no later act, so scaling their definitions scales Act 1 and nothing else (the one variant built on them, the Pale Duskfang, is a quest spawn the simulator never meets). No per-act difficulty scalar exists. The runtime scalars are the vows (V1 multiplies HP by 1.12 after the roll, V2 adds 1 to every hit; V5 carries all five vows), the act's omen and an elite's affix, and a quest variant's `statMods` (`hpMult` and `dmgMult`, applied to the HP range's ends and to each move's `dmg`, rounded half away from zero). E2 applies exactly that variant rule in the catalogue copy: both HP ends and each move's `dmg`, rounded half away from zero, HP at least 1; hit counts, Ward, statuses (Strength, Ritual, Thorns, Poison, Weak, Frail, Vulnerable), wounds and Facets keep their values. At x0.9 the smallest hits do not move (4 stays 4, 5 x2 stays 5 x2); the HP of every enemy falls by about a tenth. Appendix B lists every field.

**Controls.**

- E0 reproduces readout 5 on both bands, every win count and every G5 minimum: on 13200-13299 the "leak 1, Art +1 (shipped)" row of its lantern re-check, on 13000-13199 its phase B baseline. So E0 is readout 5, and every "vs E0" below is a change against readout 5 on the same seeds.
- The splash flag is inert when unused: E0 re-run at `d0d1ec56` and again at `72d20002` gives the same 24 reports as at `39961b1c` (all 2,012 run rows identical; the manifests differ only in the commit and the driver hash), and the seed-1000 digests and the balance tests pass unchanged at both heads (appendix C). E3 and X2 re-run at `72d20002` match their `d0d1ec56` reports run for run.
- E3's and X2's A and R reports are identical to E0's on both bands (32 reports): the flag reaches the committed arms only.
- E2b and X1 play Act 1 identically: all 6,000 runs have the same Act-1 fights in both, so X1 differs from E2b from Act 2 on, as designed.
- G7 in every one of the 17 cell tables: 0 stalls, 0 errors, arm A's replay 3 of 3 identical.

**Measures beyond the grader's.** Steady by the end of Act 1 is G5's own count: a committed run counts when its own way reads Steady or True at the end of Act 1, over every run. Reach end of Act 1 counts the runs that beat the Act-1 boss. Soot at the end of Act 1 is a share of the runs that reach it; Soot at run end a share of all runs. Tiers read the deck whatever its dominant way. A death's act is the act of the lost run's last fight. The paired tests compare the same seeds under two configurations: the runs one wins and the other loses, both ways, with the exact two-sided binomial p on those discordant runs. Offered glass is the simulator's per-card offer counter (card rewards, shop stock and event picks), weighted by affinity.

## Results, seeds 13200-13299

100 paired seeds per arm. "vs E0" is the change in win rate on the same seeds. G5's full-pool verdict also needs True by the end of Act 2 at 40% or more; no row reaches it.

### V0, fresh pool

| Experiment | Arm | Wins | Win rate | Wilson 95% | vs E0 | Steady by end of Act 1 | Reach end of Act 1 | Soot at end of Act 1 | Soot at run end |
|---|---|---:|---:|---|---:|---:|---:|---:|---:|
| E0 control (main) | C_shatter | 14/100 | 14.0% | 8.5%-22.1% |  | 36.0% | 65/100 | 3.1% | 7.0% |
|  | C_lantern | 4/100 | 4.0% | 1.6%-9.8% |  | 26.0% | 47/100 | 8.5% | 5.0% |
|  | C_edge | 4/100 | 4.0% | 1.6%-9.8% |  | 55.0% | 66/100 | 0.0% | 0.0% |
|  | A | 40/100 | 40.0% | 30.9%-49.8% |  | - | 68/100 | 35.3% | 30.0% |
|  | R | 4/100 | 4.0% | 1.6%-9.8% |  | - | 58/100 | 25.9% | 31.0% |
| E1a first gain +2 | C_shatter | 11/100 | 11.0% | 6.3%-18.6% | -3.0 pp | 36.0% | 65/100 | 3.1% | 7.0% |
|  | C_lantern | 8/100 | 8.0% | 4.1%-15.0% | +4.0 pp | 26.0% | 48/100 | 8.3% | 4.0% |
|  | C_edge | 5/100 | 5.0% | 2.2%-11.2% | +1.0 pp | 63.0% | 73/100 | 0.0% | 0.0% |
|  | A | 41/100 | 41.0% | 31.9%-50.8% | +1.0 pp | - | 67/100 | 38.8% | 32.0% |
|  | R | 5/100 | 5.0% | 2.2%-11.2% | +1.0 pp | - | 57/100 | 21.1% | 26.0% |
| E1b first gain +2, cap +4, True Art -2 | C_shatter | 11/100 | 11.0% | 6.3%-18.6% | -3.0 pp | 36.0% | 65/100 | 3.1% | 7.0% |
|  | C_lantern | 8/100 | 8.0% | 4.1%-15.0% | +4.0 pp | 26.0% | 48/100 | 8.3% | 4.0% |
|  | C_edge | 6/100 | 6.0% | 2.8%-12.5% | +2.0 pp | 64.0% | 74/100 | 0.0% | 0.0% |
|  | A | 43/100 | 43.0% | 33.7%-52.8% | +3.0 pp | - | 68/100 | 38.2% | 32.0% |
|  | R | 5/100 | 5.0% | 2.2%-11.2% | +1.0 pp | - | 57/100 | 21.1% | 26.0% |
| E2a Act-1 enemies x0.9 | C_shatter | 16/100 | 16.0% | 10.1%-24.4% | +2.0 pp | 50.0% | 83/100 | 4.8% | 7.0% |
|  | C_lantern | 5/100 | 5.0% | 2.2%-11.2% | +1.0 pp | 38.0% | 78/100 | 3.8% | 6.0% |
|  | C_edge | 7/100 | 7.0% | 3.4%-13.7% | +3.0 pp | 71.0% | 85/100 | 0.0% | 0.0% |
|  | A | 49/100 | 49.0% | 39.4%-58.7% | +9.0 pp | - | 88/100 | 30.7% | 44.0% |
|  | R | 7/100 | 7.0% | 3.4%-13.7% | +3.0 pp | - | 77/100 | 20.8% | 33.0% |
| E2b Act-1 enemies x0.8 | C_shatter | 16/100 | 16.0% | 10.1%-24.4% | +2.0 pp | 60.0% | 96/100 | 5.2% | 4.0% |
|  | C_lantern | 7/100 | 7.0% | 3.4%-13.7% | +3.0 pp | 45.0% | 85/100 | 3.5% | 6.0% |
|  | C_edge | 8/100 | 8.0% | 4.1%-15.0% | +4.0 pp | 78.0% | 95/100 | 1.1% | 0.0% |
|  | A | 45/100 | 45.0% | 35.6%-54.8% | +5.0 pp | - | 92/100 | 39.1% | 38.0% |
|  | R | 14/100 | 14.0% | 8.5%-22.1% | +10.0 pp | - | 97/100 | 16.5% | 34.0% |
| E3 splash arms 2.0 / 1.0 | C_shatter | 29/100 | 29.0% | 21.0%-38.5% | +15.0 pp | 0.0% | 76/100 | 34.2% | 33.0% |
|  | C_lantern | 29/100 | 29.0% | 21.0%-38.5% | +25.0 pp | 4.0% | 58/100 | 31.0% | 41.0% |
|  | C_edge | 16/100 | 16.0% | 10.1%-24.4% | +12.0 pp | 40.0% | 68/100 | 7.4% | 6.0% |
|  | A | 40/100 | 40.0% | 30.9%-49.8% | +0.0 pp | - | 68/100 | 35.3% | 30.0% |
|  | R | 4/100 | 4.0% | 1.6%-9.8% | +0.0 pp | - | 58/100 | 25.9% | 31.0% |
| X1 all acts x0.8 (beyond the brief) | C_shatter | 57/100 | 57.0% | 47.2%-66.3% | +43.0 pp | 60.0% | 96/100 | 5.2% | 3.0% |
|  | C_lantern | 37/100 | 37.0% | 28.2%-46.8% | +33.0 pp | 45.0% | 85/100 | 3.5% | 5.0% |
|  | C_edge | 58/100 | 58.0% | 48.2%-67.2% | +54.0 pp | 78.0% | 95/100 | 1.1% | 0.0% |
|  | A | 80/100 | 80.0% | 71.1%-86.7% | +40.0 pp | - | 92/100 | 39.1% | 30.0% |
|  | R | 52/100 | 52.0% | 42.3%-61.5% | +48.0 pp | - | 97/100 | 16.5% | 32.0% |
| X2 commit 3.0 / 1.0 (beyond the brief) | C_shatter | 29/100 | 29.0% | 21.0%-38.5% | +15.0 pp | 0.0% | 76/100 | 34.2% | 32.0% |
|  | C_lantern | 9/100 | 9.0% | 4.8%-16.2% | +5.0 pp | 4.0% | 61/100 | 32.8% | 38.0% |
|  | C_edge | 16/100 | 16.0% | 10.1%-24.4% | +12.0 pp | 43.0% | 71/100 | 5.6% | 2.0% |
|  | A | 40/100 | 40.0% | 30.9%-49.8% | +0.0 pp | - | 68/100 | 35.3% | 30.0% |
|  | R | 4/100 | 4.0% | 1.6%-9.8% | +0.0 pp | - | 58/100 | 25.9% | 31.0% |

| Experiment | G1 viability | G2 parity | G3 skill | G4 random loses | G5 reachability |
|---|---|---|---|---|---|
| E0 control (main) | FAIL: worst C_lantern 4.0% | PASS: 10.0 pp (C_shatter - C_lantern) | FAIL: A 40.0% vs best 14.0% (+26.0 pp) | FAIL: R 4.0% vs worst 4.0% (+0.0 pp) | FAIL: Steady min 26.0% (C_lantern), True min 0.0% (C_lantern) |
| E1a first gain +2 | FAIL: worst C_edge 5.0% | PASS: 6.0 pp (C_shatter - C_edge) | FAIL: A 41.0% vs best 11.0% (+30.0 pp) | FAIL: R 5.0% vs worst 5.0% (+0.0 pp) | FAIL: Steady min 26.0% (C_lantern), True min 1.0% (C_lantern) |
| E1b first gain +2, cap +4, True Art -2 | FAIL: worst C_edge 6.0% | PASS: 5.0 pp (C_shatter - C_edge) | FAIL: A 43.0% vs best 11.0% (+32.0 pp) | FAIL: R 5.0% vs worst 6.0% (-1.0 pp) | FAIL: Steady min 26.0% (C_lantern), True min 1.0% (C_lantern) |
| E2a Act-1 enemies x0.9 | FAIL: worst C_lantern 5.0% | FAIL: 11.0 pp (C_shatter - C_lantern) | FAIL: A 49.0% vs best 16.0% (+33.0 pp) | FAIL: R 7.0% vs worst 5.0% (+2.0 pp) | FAIL: Steady min 38.0% (C_lantern), True min 2.0% (C_lantern) |
| E2b Act-1 enemies x0.8 | FAIL: worst C_lantern 7.0% | PASS: 9.0 pp (C_shatter - C_lantern) | FAIL: A 45.0% vs best 16.0% (+29.0 pp) | FAIL: R 14.0% vs worst 7.0% (+7.0 pp) | PASS: Steady min 45.0% (C_lantern), True min 1.0% (C_lantern) |
| E3 splash arms 2.0 / 1.0 | FAIL: worst C_edge 16.0% | FAIL: 13.0 pp (C_shatter - C_edge) | PASS: A 40.0% vs best 29.0% (+11.0 pp) | FAIL: R 4.0% vs worst 16.0% (-12.0 pp) | FAIL: Steady min 0.0% (C_shatter), True min 0.0% (C_shatter) |
| X1 all acts x0.8 (beyond the brief) | FAIL: worst C_lantern 37.0% | FAIL: 21.0 pp (C_edge - C_lantern) | FAIL: A 80.0% vs best 58.0% (+22.0 pp) | FAIL: R 52.0% vs worst 37.0% (+15.0 pp) | PASS: Steady min 45.0% (C_lantern), True min 3.0% (C_lantern) |
| X2 commit 3.0 / 1.0 (beyond the brief) | FAIL: worst C_lantern 9.0% | FAIL: 20.0 pp (C_shatter - C_lantern) | PASS: A 40.0% vs best 29.0% (+11.0 pp) | FAIL: R 4.0% vs worst 9.0% (-5.0 pp) | FAIL: Steady min 0.0% (C_shatter), True min 0.0% (C_shatter) |

### V0, full pool

| Experiment | Arm | Wins | Win rate | Wilson 95% | vs E0 | Steady by end of Act 1 | Reach end of Act 1 | Soot at end of Act 1 | Soot at run end |
|---|---|---:|---:|---|---:|---:|---:|---:|---:|
| E0 control (main) | C_shatter | 40/100 | 40.0% | 30.9%-49.8% |  | 29.0% | 78/100 | 3.8% | 5.0% |
|  | C_lantern | 21/100 | 21.0% | 14.2%-30.0% |  | 46.0% | 62/100 | 1.6% | 1.0% |
|  | C_edge | 14/100 | 14.0% | 8.5%-22.1% |  | 84.0% | 86/100 | 0.0% | 0.0% |
|  | A | 44/100 | 44.0% | 34.7%-53.8% |  | - | 81/100 | 24.7% | 21.0% |
|  | R | 22/100 | 22.0% | 15.0%-31.1% |  | - | 75/100 | 12.0% | 23.0% |
| E1a first gain +2 | C_shatter | 40/100 | 40.0% | 30.9%-49.8% | +0.0 pp | 30.0% | 79/100 | 3.8% | 6.0% |
|  | C_lantern | 21/100 | 21.0% | 14.2%-30.0% | +0.0 pp | 52.0% | 67/100 | 1.5% | 1.0% |
|  | C_edge | 24/100 | 24.0% | 16.7%-33.2% | +10.0 pp | 88.0% | 90/100 | 0.0% | 0.0% |
|  | A | 45/100 | 45.0% | 35.6%-54.8% | +1.0 pp | - | 82/100 | 24.4% | 21.0% |
|  | R | 19/100 | 19.0% | 12.5%-27.8% | -3.0 pp | - | 75/100 | 12.0% | 23.0% |
| E1b first gain +2, cap +4, True Art -2 | C_shatter | 40/100 | 40.0% | 30.9%-49.8% | +0.0 pp | 30.0% | 79/100 | 3.8% | 6.0% |
|  | C_lantern | 21/100 | 21.0% | 14.2%-30.0% | +0.0 pp | 52.0% | 67/100 | 1.5% | 1.0% |
|  | C_edge | 27/100 | 27.0% | 19.3%-36.4% | +13.0 pp | 87.0% | 89/100 | 0.0% | 0.0% |
|  | A | 45/100 | 45.0% | 35.6%-54.8% | +1.0 pp | - | 82/100 | 24.4% | 21.0% |
|  | R | 19/100 | 19.0% | 12.5%-27.8% | -3.0 pp | - | 75/100 | 12.0% | 23.0% |
| E2a Act-1 enemies x0.9 | C_shatter | 47/100 | 47.0% | 37.5%-56.7% | +7.0 pp | 43.0% | 94/100 | 4.3% | 7.0% |
|  | C_lantern | 16/100 | 16.0% | 10.1%-24.4% | -5.0 pp | 56.0% | 77/100 | 3.9% | 3.0% |
|  | C_edge | 18/100 | 18.0% | 11.7%-26.7% | +4.0 pp | 92.0% | 93/100 | 0.0% | 0.0% |
|  | A | 58/100 | 58.0% | 48.2%-67.2% | +14.0 pp | - | 96/100 | 33.3% | 20.0% |
|  | R | 24/100 | 24.0% | 16.7%-33.2% | +2.0 pp | - | 89/100 | 15.7% | 21.0% |
| E2b Act-1 enemies x0.8 | C_shatter | 48/100 | 48.0% | 38.5%-57.7% | +8.0 pp | 38.0% | 96/100 | 4.2% | 7.0% |
|  | C_lantern | 26/100 | 26.0% | 18.4%-35.4% | +5.0 pp | 64.0% | 91/100 | 2.2% | 2.0% |
|  | C_edge | 14/100 | 14.0% | 8.5%-22.1% | +0.0 pp | 95.0% | 98/100 | 0.0% | 0.0% |
|  | A | 53/100 | 53.0% | 43.3%-62.5% | +9.0 pp | - | 98/100 | 27.6% | 19.0% |
|  | R | 23/100 | 23.0% | 15.8%-32.2% | +1.0 pp | - | 97/100 | 23.7% | 21.0% |
| E3 splash arms 2.0 / 1.0 | C_shatter | 40/100 | 40.0% | 30.9%-49.8% | +0.0 pp | 2.0% | 82/100 | 28.0% | 36.0% |
|  | C_lantern | 40/100 | 40.0% | 30.9%-49.8% | +19.0 pp | 10.0% | 73/100 | 19.2% | 26.0% |
|  | C_edge | 19/100 | 19.0% | 12.5%-27.8% | +5.0 pp | 66.0% | 85/100 | 2.4% | 2.0% |
|  | A | 44/100 | 44.0% | 34.7%-53.8% | +0.0 pp | - | 81/100 | 24.7% | 21.0% |
|  | R | 22/100 | 22.0% | 15.0%-31.1% | +0.0 pp | - | 75/100 | 12.0% | 23.0% |
| X1 all acts x0.8 (beyond the brief) | C_shatter | 71/100 | 71.0% | 61.5%-79.0% | +31.0 pp | 38.0% | 96/100 | 4.2% | 10.0% |
|  | C_lantern | 61/100 | 61.0% | 51.2%-70.0% | +40.0 pp | 64.0% | 91/100 | 2.2% | 1.0% |
|  | C_edge | 59/100 | 59.0% | 49.2%-68.1% | +45.0 pp | 95.0% | 98/100 | 0.0% | 0.0% |
|  | A | 83/100 | 83.0% | 74.5%-89.1% | +39.0 pp | - | 98/100 | 27.6% | 18.0% |
|  | R | 61/100 | 61.0% | 51.2%-70.0% | +39.0 pp | - | 97/100 | 23.7% | 25.0% |
| X2 commit 3.0 / 1.0 (beyond the brief) | C_shatter | 42/100 | 42.0% | 32.8%-51.8% | +2.0 pp | 2.0% | 82/100 | 29.3% | 40.0% |
|  | C_lantern | 36/100 | 36.0% | 27.3%-45.8% | +15.0 pp | 18.0% | 75/100 | 12.0% | 15.0% |
|  | C_edge | 22/100 | 22.0% | 15.0%-31.1% | +8.0 pp | 65.0% | 84/100 | 1.2% | 2.0% |
|  | A | 44/100 | 44.0% | 34.7%-53.8% | +0.0 pp | - | 81/100 | 24.7% | 21.0% |
|  | R | 22/100 | 22.0% | 15.0%-31.1% | +0.0 pp | - | 75/100 | 12.0% | 23.0% |

| Experiment | G1 viability | G2 parity | G3 skill | G4 random loses | G5 reachability |
|---|---|---|---|---|---|
| E0 control (main) | FAIL: worst C_edge 14.0% | FAIL: 26.0 pp (C_shatter - C_edge) | PASS: A 44.0% vs best 40.0% (+4.0 pp) | FAIL: R 22.0% vs worst 14.0% (+8.0 pp) | FAIL: Steady min 29.0% (C_shatter), True min 1.0% (C_shatter) |
| E1a first gain +2 | FAIL: worst C_lantern 21.0% | FAIL: 19.0 pp (C_shatter - C_lantern) | PASS: A 45.0% vs best 40.0% (+5.0 pp) | FAIL: R 19.0% vs worst 21.0% (-2.0 pp) | FAIL: Steady min 30.0% (C_shatter), True min 1.0% (C_shatter) |
| E1b first gain +2, cap +4, True Art -2 | FAIL: worst C_lantern 21.0% | FAIL: 19.0 pp (C_shatter - C_lantern) | PASS: A 45.0% vs best 40.0% (+5.0 pp) | FAIL: R 19.0% vs worst 21.0% (-2.0 pp) | FAIL: Steady min 30.0% (C_shatter), True min 1.0% (C_shatter) |
| E2a Act-1 enemies x0.9 | FAIL: worst C_lantern 16.0% | FAIL: 31.0 pp (C_shatter - C_lantern) | PASS: A 58.0% vs best 47.0% (+11.0 pp) | FAIL: R 24.0% vs worst 16.0% (+8.0 pp) | FAIL: Steady min 43.0% (C_shatter), True min 1.0% (C_shatter) |
| E2b Act-1 enemies x0.8 | FAIL: worst C_edge 14.0% | FAIL: 34.0 pp (C_shatter - C_edge) | PASS: A 53.0% vs best 48.0% (+5.0 pp) | FAIL: R 23.0% vs worst 14.0% (+9.0 pp) | FAIL: Steady min 38.0% (C_shatter), True min 3.0% (C_shatter) |
| E3 splash arms 2.0 / 1.0 | FAIL: worst C_edge 19.0% | FAIL: 21.0 pp (C_shatter - C_edge) | PASS: A 44.0% vs best 40.0% (+4.0 pp) | FAIL: R 22.0% vs worst 19.0% (+3.0 pp) | FAIL: Steady min 2.0% (C_shatter), True min 0.0% (C_shatter) |
| X1 all acts x0.8 (beyond the brief) | PASS: worst C_edge 59.0% | FAIL: 12.0 pp (C_shatter - C_edge) | PASS: A 83.0% vs best 71.0% (+12.0 pp) | FAIL: R 61.0% vs worst 59.0% (+2.0 pp) | FAIL: Steady min 38.0% (C_shatter), True min 2.0% (C_shatter) |
| X2 commit 3.0 / 1.0 (beyond the brief) | FAIL: worst C_edge 22.0% | FAIL: 20.0 pp (C_shatter - C_edge) | PASS: A 44.0% vs best 42.0% (+2.0 pp) | FAIL: R 22.0% vs worst 22.0% (+0.0 pp) | FAIL: Steady min 2.0% (C_shatter), True min 0.0% (C_shatter) |

### V5, fresh pool

| Experiment | Arm | Wins | Win rate | Wilson 95% | vs E0 | Steady by end of Act 1 | Reach end of Act 1 | Soot at end of Act 1 | Soot at run end |
|---|---|---:|---:|---|---:|---:|---:|---:|---:|
| E0 control (main) | C_shatter | 0/100 | 0.0% | 0.0%-3.7% |  | 16.0% | 24/100 | 0.0% | 4.0% |
|  | C_lantern | 0/100 | 0.0% | 0.0%-3.7% |  | 5.0% | 10/100 | 10.0% | 13.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% |  | 17.0% | 22/100 | 0.0% | 1.0% |
|  | A | 5/100 | 5.0% | 2.2%-11.2% |  | - | 20/100 | 35.0% | 42.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% |  | - | 18/100 | 22.2% | 21.0% |
| E1a first gain +2 | C_shatter | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 22.0% | 30/100 | 0.0% | 4.0% |
|  | C_lantern | 1/100 | 1.0% | 0.2%-5.4% | +1.0 pp | 7.0% | 13/100 | 0.0% | 14.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 21.0% | 26/100 | 0.0% | 1.0% |
|  | A | 5/100 | 5.0% | 2.2%-11.2% | +0.0 pp | - | 20/100 | 35.0% | 42.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% | +0.0 pp | - | 17/100 | 23.5% | 21.0% |
| E1b first gain +2, cap +4, True Art -2 | C_shatter | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 22.0% | 30/100 | 0.0% | 4.0% |
|  | C_lantern | 1/100 | 1.0% | 0.2%-5.4% | +1.0 pp | 7.0% | 13/100 | 0.0% | 14.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 22.0% | 27/100 | 0.0% | 1.0% |
|  | A | 5/100 | 5.0% | 2.2%-11.2% | +0.0 pp | - | 20/100 | 35.0% | 42.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% | +0.0 pp | - | 17/100 | 23.5% | 21.0% |
| E2a Act-1 enemies x0.9 | C_shatter | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 29.0% | 42/100 | 0.0% | 2.0% |
|  | C_lantern | 2/100 | 2.0% | 0.6%-7.0% | +2.0 pp | 14.0% | 27/100 | 7.4% | 9.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 30.0% | 44/100 | 6.8% | 2.0% |
|  | A | 8/100 | 8.0% | 4.1%-15.0% | +3.0 pp | - | 46/100 | 39.1% | 46.0% |
|  | R | 0/100 | 0.0% | 0.0%-3.7% | -2.0 pp | - | 34/100 | 26.5% | 22.0% |
| E2b Act-1 enemies x0.8 | C_shatter | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 43.0% | 68/100 | 2.9% | 3.0% |
|  | C_lantern | 1/100 | 1.0% | 0.2%-5.4% | +1.0 pp | 20.0% | 59/100 | 10.2% | 12.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 55.0% | 81/100 | 4.9% | 1.0% |
|  | A | 10/100 | 10.0% | 5.5%-17.4% | +5.0 pp | - | 66/100 | 45.5% | 49.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% | +0.0 pp | - | 66/100 | 21.2% | 30.0% |
| E3 splash arms 2.0 / 1.0 | C_shatter | 3/100 | 3.0% | 1.0%-8.5% | +3.0 pp | 2.0% | 23/100 | 34.8% | 43.0% |
|  | C_lantern | 3/100 | 3.0% | 1.0%-8.5% | +3.0 pp | 2.0% | 16/100 | 18.8% | 39.0% |
|  | C_edge | 1/100 | 1.0% | 0.2%-5.4% | +1.0 pp | 5.0% | 21/100 | 19.0% | 15.0% |
|  | A | 5/100 | 5.0% | 2.2%-11.2% | +0.0 pp | - | 20/100 | 35.0% | 42.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% | +0.0 pp | - | 18/100 | 22.2% | 21.0% |
| X1 all acts x0.8 (beyond the brief) | C_shatter | 20/100 | 20.0% | 13.3%-28.9% | +20.0 pp | 43.0% | 68/100 | 2.9% | 3.0% |
|  | C_lantern | 10/100 | 10.0% | 5.5%-17.4% | +10.0 pp | 20.0% | 59/100 | 10.2% | 14.0% |
|  | C_edge | 19/100 | 19.0% | 12.5%-27.8% | +19.0 pp | 55.0% | 81/100 | 4.9% | 1.0% |
|  | A | 37/100 | 37.0% | 28.2%-46.8% | +32.0 pp | - | 66/100 | 45.5% | 44.0% |
|  | R | 14/100 | 14.0% | 8.5%-22.1% | +12.0 pp | - | 66/100 | 21.2% | 31.0% |
| X2 commit 3.0 / 1.0 (beyond the brief) | C_shatter | 3/100 | 3.0% | 1.0%-8.5% | +3.0 pp | 2.0% | 22/100 | 36.4% | 42.0% |
|  | C_lantern | 1/100 | 1.0% | 0.2%-5.4% | +1.0 pp | 2.0% | 16/100 | 18.8% | 36.0% |
|  | C_edge | 0/100 | 0.0% | 0.0%-3.7% | +0.0 pp | 9.0% | 24/100 | 8.3% | 13.0% |
|  | A | 5/100 | 5.0% | 2.2%-11.2% | +0.0 pp | - | 20/100 | 35.0% | 42.0% |
|  | R | 2/100 | 2.0% | 0.6%-7.0% | +0.0 pp | - | 18/100 | 22.2% | 21.0% |

| Experiment | G1 viability | G2 parity | G3 skill | G4 random loses | G5 reachability |
|---|---|---|---|---|---|
| E0 control (main) | n/a: worst C_shatter 0.0% | PASS: 0.0 pp (C_shatter - C_shatter) | PASS: A 5.0% vs best 0.0% (+5.0 pp) | FAIL: R 2.0% vs worst 0.0% (+2.0 pp) | n/a: Steady min 5.0% (C_lantern), True min 0.0% (C_lantern) |
| E1a first gain +2 | n/a: worst C_shatter 0.0% | PASS: 1.0 pp (C_lantern - C_shatter) | PASS: A 5.0% vs best 1.0% (+4.0 pp) | FAIL: R 2.0% vs worst 0.0% (+2.0 pp) | n/a: Steady min 7.0% (C_lantern), True min 0.0% (C_lantern) |
| E1b first gain +2, cap +4, True Art -2 | n/a: worst C_shatter 0.0% | PASS: 1.0 pp (C_lantern - C_shatter) | PASS: A 5.0% vs best 1.0% (+4.0 pp) | FAIL: R 2.0% vs worst 0.0% (+2.0 pp) | n/a: Steady min 7.0% (C_lantern), True min 0.0% (C_lantern) |
| E2a Act-1 enemies x0.9 | n/a: worst C_shatter 0.0% | PASS: 2.0 pp (C_lantern - C_shatter) | PASS: A 8.0% vs best 2.0% (+6.0 pp) | FAIL: R 0.0% vs worst 0.0% (+0.0 pp) | n/a: Steady min 14.0% (C_lantern), True min 0.0% (C_shatter) |
| E2b Act-1 enemies x0.8 | n/a: worst C_shatter 0.0% | PASS: 1.0 pp (C_lantern - C_shatter) | PASS: A 10.0% vs best 1.0% (+9.0 pp) | FAIL: R 2.0% vs worst 0.0% (+2.0 pp) | n/a: Steady min 20.0% (C_lantern), True min 0.0% (C_shatter) |
| E3 splash arms 2.0 / 1.0 | n/a: worst C_edge 1.0% | PASS: 2.0 pp (C_shatter - C_edge) | PASS: A 5.0% vs best 3.0% (+2.0 pp) | FAIL: R 2.0% vs worst 1.0% (+1.0 pp) | n/a: Steady min 2.0% (C_shatter), True min 0.0% (C_shatter) |
| X1 all acts x0.8 (beyond the brief) | n/a: worst C_lantern 10.0% | PASS: 10.0 pp (C_shatter - C_lantern) | FAIL: A 37.0% vs best 20.0% (+17.0 pp) | FAIL: R 14.0% vs worst 10.0% (+4.0 pp) | n/a: Steady min 20.0% (C_lantern), True min 1.0% (C_lantern) |
| X2 commit 3.0 / 1.0 (beyond the brief) | n/a: worst C_edge 0.0% | PASS: 3.0 pp (C_shatter - C_edge) | PASS: A 5.0% vs best 3.0% (+2.0 pp) | FAIL: R 2.0% vs worst 0.0% (+2.0 pp) | n/a: Steady min 2.0% (C_shatter), True min 0.0% (C_shatter) |

### V5, full pool

| Experiment | Arm | Wins | Win rate | Wilson 95% | vs E0 | Steady by end of Act 1 | Reach end of Act 1 | Soot at end of Act 1 | Soot at run end |
|---|---|---:|---:|---|---:|---:|---:|---:|---:|
| E0 control (main) | C_shatter | 11/100 | 11.0% | 6.3%-18.6% |  | 16.0% | 41/100 | 9.8% | 8.0% |
|  | C_lantern | 2/100 | 2.0% | 0.6%-7.0% |  | 22.0% | 33/100 | 6.1% | 1.0% |
|  | C_edge | 3/100 | 3.0% | 1.0%-8.5% |  | 56.0% | 57/100 | 0.0% | 1.0% |
|  | A | 19/100 | 19.0% | 12.5%-27.8% |  | - | 46/100 | 26.1% | 34.0% |
|  | R | 6/100 | 6.0% | 2.8%-12.5% |  | - | 34/100 | 17.6% | 16.0% |
| E1a first gain +2 | C_shatter | 11/100 | 11.0% | 6.3%-18.6% | +0.0 pp | 16.0% | 40/100 | 10.0% | 8.0% |
|  | C_lantern | 7/100 | 7.0% | 3.4%-13.7% | +5.0 pp | 21.0% | 32/100 | 6.2% | 1.0% |
|  | C_edge | 8/100 | 8.0% | 4.1%-15.0% | +5.0 pp | 58.0% | 59/100 | 0.0% | 1.0% |
|  | A | 19/100 | 19.0% | 12.5%-27.8% | +0.0 pp | - | 47/100 | 25.5% | 32.0% |
|  | R | 6/100 | 6.0% | 2.8%-12.5% | +0.0 pp | - | 37/100 | 16.2% | 16.0% |
| E1b first gain +2, cap +4, True Art -2 | C_shatter | 11/100 | 11.0% | 6.3%-18.6% | +0.0 pp | 16.0% | 40/100 | 10.0% | 8.0% |
|  | C_lantern | 7/100 | 7.0% | 3.4%-13.7% | +5.0 pp | 21.0% | 32/100 | 6.2% | 1.0% |
|  | C_edge | 8/100 | 8.0% | 4.1%-15.0% | +5.0 pp | 58.0% | 59/100 | 0.0% | 1.0% |
|  | A | 19/100 | 19.0% | 12.5%-27.8% | +0.0 pp | - | 47/100 | 25.5% | 32.0% |
|  | R | 6/100 | 6.0% | 2.8%-12.5% | +0.0 pp | - | 37/100 | 16.2% | 16.0% |
| E2a Act-1 enemies x0.9 | C_shatter | 18/100 | 18.0% | 11.7%-26.7% | +7.0 pp | 23.0% | 58/100 | 10.3% | 4.0% |
|  | C_lantern | 3/100 | 3.0% | 1.0%-8.5% | +1.0 pp | 31.0% | 40/100 | 2.5% | 8.0% |
|  | C_edge | 3/100 | 3.0% | 1.0%-8.5% | +0.0 pp | 68.0% | 70/100 | 0.0% | 0.0% |
|  | A | 21/100 | 21.0% | 14.2%-30.0% | +2.0 pp | - | 71/100 | 31.0% | 29.0% |
|  | R | 7/100 | 7.0% | 3.4%-13.7% | +1.0 pp | - | 56/100 | 17.9% | 24.0% |
| E2b Act-1 enemies x0.8 | C_shatter | 26/100 | 26.0% | 18.4%-35.4% | +15.0 pp | 28.0% | 80/100 | 10.0% | 13.0% |
|  | C_lantern | 11/100 | 11.0% | 6.3%-18.6% | +9.0 pp | 56.0% | 66/100 | 1.5% | 6.0% |
|  | C_edge | 4/100 | 4.0% | 1.6%-9.8% | +1.0 pp | 79.0% | 82/100 | 0.0% | 0.0% |
|  | A | 18/100 | 18.0% | 11.7%-26.7% | -1.0 pp | - | 78/100 | 35.9% | 34.0% |
|  | R | 9/100 | 9.0% | 4.8%-16.2% | +3.0 pp | - | 74/100 | 25.7% | 26.0% |
| E3 splash arms 2.0 / 1.0 | C_shatter | 15/100 | 15.0% | 9.3%-23.3% | +4.0 pp | 0.0% | 49/100 | 32.7% | 40.0% |
|  | C_lantern | 8/100 | 8.0% | 4.1%-15.0% | +6.0 pp | 5.0% | 32/100 | 28.1% | 28.0% |
|  | C_edge | 7/100 | 7.0% | 3.4%-13.7% | +4.0 pp | 35.0% | 48/100 | 0.0% | 1.0% |
|  | A | 19/100 | 19.0% | 12.5%-27.8% | +0.0 pp | - | 46/100 | 26.1% | 34.0% |
|  | R | 6/100 | 6.0% | 2.8%-12.5% | +0.0 pp | - | 34/100 | 17.6% | 16.0% |
| X1 all acts x0.8 (beyond the brief) | C_shatter | 37/100 | 37.0% | 28.2%-46.8% | +26.0 pp | 28.0% | 80/100 | 10.0% | 12.0% |
|  | C_lantern | 24/100 | 24.0% | 16.7%-33.2% | +22.0 pp | 56.0% | 66/100 | 1.5% | 6.0% |
|  | C_edge | 21/100 | 21.0% | 14.2%-30.0% | +18.0 pp | 79.0% | 82/100 | 0.0% | 0.0% |
|  | A | 46/100 | 46.0% | 36.6%-55.7% | +27.0 pp | - | 78/100 | 35.9% | 33.0% |
|  | R | 30/100 | 30.0% | 21.9%-39.6% | +24.0 pp | - | 74/100 | 25.7% | 27.0% |
| X2 commit 3.0 / 1.0 (beyond the brief) | C_shatter | 15/100 | 15.0% | 9.3%-23.3% | +4.0 pp | 0.0% | 50/100 | 32.0% | 41.0% |
|  | C_lantern | 11/100 | 11.0% | 6.3%-18.6% | +9.0 pp | 6.0% | 36/100 | 22.2% | 23.0% |
|  | C_edge | 4/100 | 4.0% | 1.6%-9.8% | +1.0 pp | 39.0% | 50/100 | 0.0% | 1.0% |
|  | A | 19/100 | 19.0% | 12.5%-27.8% | +0.0 pp | - | 46/100 | 26.1% | 34.0% |
|  | R | 6/100 | 6.0% | 2.8%-12.5% | +0.0 pp | - | 34/100 | 17.6% | 16.0% |

| Experiment | G1 viability | G2 parity | G3 skill | G4 random loses | G5 reachability |
|---|---|---|---|---|---|
| E0 control (main) | FAIL: worst C_lantern 2.0% | PASS: 9.0 pp (C_shatter - C_lantern) | PASS: A 19.0% vs best 11.0% (+8.0 pp) | FAIL: R 6.0% vs worst 2.0% (+4.0 pp) | FAIL: Steady min 16.0% (C_shatter), True min 0.0% (C_shatter) |
| E1a first gain +2 | FAIL: worst C_lantern 7.0% | PASS: 4.0 pp (C_shatter - C_lantern) | PASS: A 19.0% vs best 11.0% (+8.0 pp) | FAIL: R 6.0% vs worst 7.0% (-1.0 pp) | FAIL: Steady min 16.0% (C_shatter), True min 0.0% (C_shatter) |
| E1b first gain +2, cap +4, True Art -2 | FAIL: worst C_lantern 7.0% | PASS: 4.0 pp (C_shatter - C_lantern) | PASS: A 19.0% vs best 11.0% (+8.0 pp) | FAIL: R 6.0% vs worst 7.0% (-1.0 pp) | FAIL: Steady min 16.0% (C_shatter), True min 0.0% (C_shatter) |
| E2a Act-1 enemies x0.9 | FAIL: worst C_lantern 3.0% | FAIL: 15.0 pp (C_shatter - C_lantern) | PASS: A 21.0% vs best 18.0% (+3.0 pp) | FAIL: R 7.0% vs worst 3.0% (+4.0 pp) | FAIL: Steady min 23.0% (C_shatter), True min 0.0% (C_shatter) |
| E2b Act-1 enemies x0.8 | FAIL: worst C_edge 4.0% | FAIL: 22.0 pp (C_shatter - C_edge) | FAIL: A 18.0% vs best 26.0% (-8.0 pp) | FAIL: R 9.0% vs worst 4.0% (+5.0 pp) | FAIL: Steady min 28.0% (C_shatter), True min 0.0% (C_shatter) |
| E3 splash arms 2.0 / 1.0 | FAIL: worst C_edge 7.0% | PASS: 8.0 pp (C_shatter - C_edge) | PASS: A 19.0% vs best 15.0% (+4.0 pp) | FAIL: R 6.0% vs worst 7.0% (-1.0 pp) | FAIL: Steady min 0.0% (C_shatter), True min 0.0% (C_shatter) |
| X1 all acts x0.8 (beyond the brief) | FAIL: worst C_edge 21.0% | FAIL: 16.0 pp (C_shatter - C_edge) | PASS: A 46.0% vs best 37.0% (+9.0 pp) | FAIL: R 30.0% vs worst 21.0% (+9.0 pp) | FAIL: Steady min 28.0% (C_shatter), True min 0.0% (C_shatter) |
| X2 commit 3.0 / 1.0 (beyond the brief) | FAIL: worst C_edge 4.0% | FAIL: 11.0 pp (C_shatter - C_edge) | PASS: A 19.0% vs best 15.0% (+4.0 pp) | FAIL: R 6.0% vs worst 4.0% (+2.0 pp) | FAIL: Steady min 0.0% (C_shatter), True min 0.0% (C_shatter) |

## Side by side: the four numbers, seeds 13200-13299

Readout 3 is its step 3b on these seeds (the shipped lantern, the old pilot `p8-d0-v1`, from its Soot sweep table); readout 5 is the same catalogue at the fixed pilot (its lantern re-check). G1 is the worst committed way's win rate; G3 the adaptive arm minus the best committed way (band -3 to +15 pp); G4 the random arm minus the worst committed way (at most -25 pp, and R under 35% at V0 and 15% at V5); G5 the lowest Steady by the end of Act 1 among the committed ways (full pool 70%, fresh V0 40%). Rows below the brief's are marked.

### V0, fresh pool

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 1.0% | +19.0 pp | +4.0 pp | 25.0% | 5.0% | FAIL / FAIL / FAIL / FAIL |
| Readout 5 (fixed pilot) | 4.0% | +26.0 pp | +0.0 pp | 26.0% | 4.0% | FAIL / FAIL / FAIL / FAIL |
| E0 control (main) | 4.0% | +26.0 pp | +0.0 pp | 26.0% | 4.0% | FAIL / FAIL / FAIL / FAIL |
| E1a first gain +2 | 5.0% | +30.0 pp | +0.0 pp | 26.0% | 5.0% | FAIL / FAIL / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 6.0% | +32.0 pp | -1.0 pp | 26.0% | 5.0% | FAIL / FAIL / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 5.0% | +33.0 pp | +2.0 pp | 38.0% | 7.0% | FAIL / FAIL / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 7.0% | +29.0 pp | +7.0 pp | 45.0% | 14.0% | FAIL / FAIL / FAIL / PASS |
| E3 splash arms 2.0 / 1.0 | 16.0% | +11.0 pp | -12.0 pp | 0.0% | 4.0% | FAIL / PASS / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 37.0% | +22.0 pp | +15.0 pp | 45.0% | 52.0% | FAIL / FAIL / FAIL / PASS |
| X2 commit 3.0 / 1.0 (beyond the brief) | 9.0% | +11.0 pp | -5.0 pp | 0.0% | 4.0% | FAIL / PASS / FAIL / FAIL |

### V0, full pool

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 17.0% | +4.0 pp | +5.0 pp | 29.0% | 22.0% | FAIL / PASS / FAIL / FAIL |
| Readout 5 (fixed pilot) | 14.0% | +4.0 pp | +8.0 pp | 29.0% | 22.0% | FAIL / PASS / FAIL / FAIL |
| E0 control (main) | 14.0% | +4.0 pp | +8.0 pp | 29.0% | 22.0% | FAIL / PASS / FAIL / FAIL |
| E1a first gain +2 | 21.0% | +5.0 pp | -2.0 pp | 30.0% | 19.0% | FAIL / PASS / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 21.0% | +5.0 pp | -2.0 pp | 30.0% | 19.0% | FAIL / PASS / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 16.0% | +11.0 pp | +8.0 pp | 43.0% | 24.0% | FAIL / PASS / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 14.0% | +5.0 pp | +9.0 pp | 38.0% | 23.0% | FAIL / PASS / FAIL / FAIL |
| E3 splash arms 2.0 / 1.0 | 19.0% | +4.0 pp | +3.0 pp | 2.0% | 22.0% | FAIL / PASS / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 59.0% | +12.0 pp | +2.0 pp | 38.0% | 61.0% | PASS / PASS / FAIL / FAIL |
| X2 commit 3.0 / 1.0 (beyond the brief) | 22.0% | +2.0 pp | +0.0 pp | 2.0% | 22.0% | FAIL / PASS / FAIL / FAIL |

### V5, fresh pool

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 0.0% | +3.0 pp | +0.0 pp | 5.0% | 0.0% | n/a / PASS / FAIL / n/a |
| Readout 5 (fixed pilot) | 0.0% | +5.0 pp | +2.0 pp | 5.0% | 2.0% | n/a / PASS / FAIL / n/a |
| E0 control (main) | 0.0% | +5.0 pp | +2.0 pp | 5.0% | 2.0% | n/a / PASS / FAIL / n/a |
| E1a first gain +2 | 0.0% | +4.0 pp | +2.0 pp | 7.0% | 2.0% | n/a / PASS / FAIL / n/a |
| E1b first gain +2, cap +4, True Art -2 | 0.0% | +4.0 pp | +2.0 pp | 7.0% | 2.0% | n/a / PASS / FAIL / n/a |
| E2a Act-1 enemies x0.9 | 0.0% | +6.0 pp | +0.0 pp | 14.0% | 0.0% | n/a / PASS / FAIL / n/a |
| E2b Act-1 enemies x0.8 | 0.0% | +9.0 pp | +2.0 pp | 20.0% | 2.0% | n/a / PASS / FAIL / n/a |
| E3 splash arms 2.0 / 1.0 | 1.0% | +2.0 pp | +1.0 pp | 2.0% | 2.0% | n/a / PASS / FAIL / n/a |
| X1 all acts x0.8 (beyond the brief) | 10.0% | +17.0 pp | +4.0 pp | 20.0% | 14.0% | n/a / FAIL / FAIL / n/a |
| X2 commit 3.0 / 1.0 (beyond the brief) | 0.0% | +2.0 pp | +2.0 pp | 2.0% | 2.0% | n/a / PASS / FAIL / n/a |

### V5, full pool

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 2.0% | +6.0 pp | +3.0 pp | 16.0% | 5.0% | FAIL / PASS / FAIL / FAIL |
| Readout 5 (fixed pilot) | 2.0% | +8.0 pp | +4.0 pp | 16.0% | 6.0% | FAIL / PASS / FAIL / FAIL |
| E0 control (main) | 2.0% | +8.0 pp | +4.0 pp | 16.0% | 6.0% | FAIL / PASS / FAIL / FAIL |
| E1a first gain +2 | 7.0% | +8.0 pp | -1.0 pp | 16.0% | 6.0% | FAIL / PASS / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 7.0% | +8.0 pp | -1.0 pp | 16.0% | 6.0% | FAIL / PASS / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 3.0% | +3.0 pp | +4.0 pp | 23.0% | 7.0% | FAIL / PASS / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 4.0% | -8.0 pp | +5.0 pp | 28.0% | 9.0% | FAIL / FAIL / FAIL / FAIL |
| E3 splash arms 2.0 / 1.0 | 7.0% | +4.0 pp | -1.0 pp | 0.0% | 6.0% | FAIL / PASS / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 21.0% | +9.0 pp | +9.0 pp | 28.0% | 30.0% | FAIL / PASS / FAIL / FAIL |
| X2 commit 3.0 / 1.0 (beyond the brief) | 4.0% | +4.0 pp | +2.0 pp | 0.0% | 6.0% | FAIL / PASS / FAIL / FAIL |

## Confirmation, seeds 13000-13199

The same experiments on the standard seeds of readouts 1 to 5 (200 paired seeds); readout 3 is its step 3b and readout 5 its phase B baseline.

### V0, fresh pool, seeds 13000-13199

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 4.5% | +18.0 pp | -1.5 pp | 30.0% | 3.0% | FAIL / FAIL / FAIL / FAIL |
| Readout 5 (fixed pilot) | 6.0% | +27.0 pp | -0.5 pp | 32.0% | 5.5% | FAIL / FAIL / FAIL / FAIL |
| E0 control (main) | 6.0% | +27.0 pp | -0.5 pp | 32.0% | 5.5% | FAIL / FAIL / FAIL / FAIL |
| E1a first gain +2 | 6.0% | +25.0 pp | +0.5 pp | 31.5% | 6.5% | FAIL / FAIL / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 6.0% | +25.0 pp | +0.5 pp | 31.5% | 6.5% | FAIL / FAIL / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 6.0% | +32.0 pp | +1.5 pp | 34.5% | 7.5% | FAIL / FAIL / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 5.5% | +33.0 pp | +5.5 pp | 43.0% | 11.0% | FAIL / FAIL / FAIL / PASS |
| E3 splash arms 2.0 / 1.0 | 22.5% | +0.5 pp | -17.0 pp | 1.5% | 5.5% | FAIL / PASS / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 38.5% | +30.5 pp | -2.0 pp | 43.0% | 36.5% | FAIL / FAIL / FAIL / PASS |
| X2 commit 3.0 / 1.0 (beyond the brief) | 9.5% | +0.0 pp | -4.0 pp | 1.5% | 5.5% | FAIL / PASS / FAIL / FAIL |

### V0, full pool, seeds 13000-13199

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 15.0% | +3.0 pp | +0.0 pp | 29.0% | 15.0% | FAIL / PASS / FAIL / FAIL |
| Readout 5 (fixed pilot) | 17.0% | +6.0 pp | -2.5 pp | 29.0% | 14.5% | FAIL / PASS / FAIL / FAIL |
| E0 control (main) | 17.0% | +6.0 pp | -2.5 pp | 29.0% | 14.5% | FAIL / PASS / FAIL / FAIL |
| E1a first gain +2 | 16.5% | +7.5 pp | +0.0 pp | 28.0% | 16.5% | FAIL / PASS / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 19.0% | +7.0 pp | -2.5 pp | 28.0% | 16.5% | FAIL / PASS / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 18.0% | +7.5 pp | +3.0 pp | 26.5% | 21.0% | FAIL / PASS / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 20.0% | +13.5 pp | +2.0 pp | 32.0% | 22.0% | FAIL / PASS / FAIL / FAIL |
| E3 splash arms 2.0 / 1.0 | 24.5% | -4.0 pp | -10.0 pp | 1.5% | 14.5% | FAIL / FAIL / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 52.0% | +2.5 pp | +6.5 pp | 32.0% | 58.5% | PASS / PASS / FAIL / FAIL |
| X2 commit 3.0 / 1.0 (beyond the brief) | 23.5% | -5.5 pp | -9.0 pp | 1.5% | 14.5% | FAIL / FAIL / FAIL / FAIL |

### V5, fresh pool, seeds 13000-13199

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 0.0% | +2.0 pp | +0.5 pp | 6.0% | 0.5% | n/a / PASS / FAIL / n/a |
| Readout 5 (fixed pilot) | 0.0% | +4.5 pp | +0.5 pp | 7.0% | 0.5% | n/a / PASS / FAIL / n/a |
| E0 control (main) | 0.0% | +4.5 pp | +0.5 pp | 7.0% | 0.5% | n/a / PASS / FAIL / n/a |
| E1a first gain +2 | 0.0% | +4.0 pp | +0.5 pp | 8.0% | 0.5% | n/a / PASS / FAIL / n/a |
| E1b first gain +2, cap +4, True Art -2 | 0.0% | +4.0 pp | +0.5 pp | 8.0% | 0.5% | n/a / PASS / FAIL / n/a |
| E2a Act-1 enemies x0.9 | 0.5% | +7.5 pp | +0.5 pp | 13.5% | 1.0% | n/a / PASS / FAIL / n/a |
| E2b Act-1 enemies x0.8 | 0.5% | +8.5 pp | +1.0 pp | 24.0% | 1.5% | n/a / PASS / FAIL / n/a |
| E3 splash arms 2.0 / 1.0 | 1.0% | +1.0 pp | -0.5 pp | 1.0% | 0.5% | n/a / PASS / FAIL / n/a |
| X1 all acts x0.8 (beyond the brief) | 10.5% | +27.5 pp | +0.0 pp | 24.0% | 10.5% | n/a / FAIL / FAIL / n/a |
| X2 commit 3.0 / 1.0 (beyond the brief) | 0.0% | +1.0 pp | +0.5 pp | 1.0% | 0.5% | n/a / PASS / FAIL / n/a |

### V5, full pool, seeds 13000-13199

| Source | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, minimum | R | Verdicts G1 / G3 / G4 / G5 |
|---|---:|---:|---:|---:|---:|---|
| Readout 3 (step 3b, old pilot) | 2.5% | +2.5 pp | +0.0 pp | 13.0% | 2.5% | FAIL / PASS / FAIL / FAIL |
| Readout 5 (fixed pilot) | 2.0% | +4.0 pp | +1.0 pp | 13.5% | 3.0% | FAIL / PASS / FAIL / FAIL |
| E0 control (main) | 2.0% | +4.0 pp | +1.0 pp | 13.5% | 3.0% | FAIL / PASS / FAIL / FAIL |
| E1a first gain +2 | 4.0% | +3.0 pp | -1.0 pp | 14.0% | 3.0% | FAIL / PASS / FAIL / FAIL |
| E1b first gain +2, cap +4, True Art -2 | 3.5% | +3.0 pp | -0.5 pp | 14.0% | 3.0% | FAIL / PASS / FAIL / FAIL |
| E2a Act-1 enemies x0.9 | 3.5% | +10.0 pp | +3.5 pp | 20.0% | 7.0% | FAIL / PASS / FAIL / FAIL |
| E2b Act-1 enemies x0.8 | 4.5% | +2.0 pp | +4.5 pp | 31.0% | 9.0% | FAIL / PASS / FAIL / FAIL |
| E3 splash arms 2.0 / 1.0 | 5.5% | +2.5 pp | -2.5 pp | 1.0% | 3.0% | FAIL / PASS / FAIL / FAIL |
| X1 all acts x0.8 (beyond the brief) | 17.0% | +1.5 pp | +11.0 pp | 31.0% | 28.0% | FAIL / PASS / FAIL / FAIL |
| X2 commit 3.0 / 1.0 (beyond the brief) | 2.0% | +2.5 pp | +1.0 pp | 1.0% | 3.0% | FAIL / PASS / FAIL / FAIL |

### Pooled over 300 paired seeds

Both bands together, the numbers the recommendation uses (Wilson 95% on the worst committed way).

| Experiment | Cell | Worst committed (Wilson 95%) | A - best committed | R - worst committed | Steady by end of Act 1, minimum | R | A |
|---|---|---|---:|---:|---:|---:|---:|
| E0 control (main) | V0 fresh | 5.3% C_edge (3.3-8.5%) | +26.7 pp | -0.3 pp | 30.0% | 5.0% | 38.7% |
|  | V0 full | 16.0% C_edge (12.3-20.6%) | +5.3 pp | +1.0 pp | 29.0% | 17.0% | 45.3% |
|  | V5 fresh | 0.0% C_shatter (0.0-1.3%) | +4.7 pp | +1.0 pp | 6.3% | 1.0% | 5.0% |
|  | V5 full | 2.0% C_lantern (0.9-4.3%) | +5.3 pp | +2.0 pp | 14.3% | 4.0% | 17.3% |
| E1a first gain +2 | V0 fresh | 6.7% C_lantern (4.4-10.1%) | +27.3 pp | -0.7 pp | 29.7% | 6.0% | 37.3% |
|  | V0 full | 19.0% C_edge (15.0-23.8%) | +6.7 pp | -1.7 pp | 28.7% | 17.3% | 47.0% |
|  | V5 fresh | 0.0% C_shatter (0.0-1.3%) | +4.0 pp | +1.0 pp | 7.7% | 1.0% | 5.0% |
|  | V5 full | 5.0% C_lantern (3.1-8.1%) | +4.7 pp | -1.0 pp | 14.7% | 4.0% | 17.7% |
| E1b first gain +2, cap +4, True Art -2 | V0 fresh | 6.7% C_lantern (4.4-10.1%) | +28.3 pp | -0.7 pp | 29.7% | 6.0% | 38.0% |
|  | V0 full | 21.3% C_lantern (17.1-26.3%) | +6.3 pp | -4.0 pp | 28.7% | 17.3% | 46.7% |
|  | V5 fresh | 0.0% C_shatter (0.0-1.3%) | +4.0 pp | +1.0 pp | 7.7% | 1.0% | 5.0% |
|  | V5 full | 5.0% C_edge (3.1-8.1%) | +4.7 pp | -1.0 pp | 14.7% | 4.0% | 17.7% |
| E2a Act-1 enemies x0.9 | V0 fresh | 5.7% C_lantern (3.6-8.9%) | +32.3 pp | +1.7 pp | 35.7% | 7.3% | 46.0% |
|  | V0 full | 18.0% C_edge (14.1-22.7%) | +8.7 pp | +4.0 pp | 32.0% | 22.0% | 52.3% |
|  | V5 fresh | 0.3% C_shatter (0.1-1.9%) | +7.0 pp | +0.3 pp | 13.7% | 0.7% | 8.3% |
|  | V5 full | 3.3% C_edge (1.8-6.0%) | +7.7 pp | +3.7 pp | 21.0% | 7.0% | 23.7% |
| E2b Act-1 enemies x0.8 | V0 fresh | 6.3% C_edge (4.1-9.7%) | +31.7 pp | +5.7 pp | 43.7% | 12.0% | 47.3% |
|  | V0 full | 19.0% C_edge (15.0-23.8%) | +10.7 pp | +3.3 pp | 34.0% | 22.3% | 58.0% |
|  | V5 fresh | 0.3% C_edge (0.1-1.9%) | +8.7 pp | +1.3 pp | 22.7% | 1.7% | 10.0% |
|  | V5 full | 4.3% C_edge (2.5-7.3%) | -1.3 pp | +4.7 pp | 30.0% | 9.0% | 23.7% |
| E3 splash arms 2.0 / 1.0 | V0 fresh | 20.3% C_edge (16.2-25.2%) | +4.0 pp | -15.3 pp | 1.0% | 5.0% | 38.7% |
|  | V0 full | 22.7% C_edge (18.3-27.7%) | -1.3 pp | -5.7 pp | 1.7% | 17.0% | 45.3% |
|  | V5 fresh | 1.0% C_edge (0.3-2.9%) | +1.3 pp | +0.0 pp | 1.3% | 1.0% | 5.0% |
|  | V5 full | 6.0% C_edge (3.8-9.3%) | +3.0 pp | -2.0 pp | 0.7% | 4.0% | 17.3% |
| X1 all acts x0.8 (beyond the brief) | V0 fresh | 38.0% C_lantern (32.7-43.6%) | +28.0 pp | +3.7 pp | 43.7% | 41.7% | 83.7% |
|  | V0 full | 55.0% C_lantern (49.3-60.5%) | +5.7 pp | +4.3 pp | 34.0% | 59.3% | 83.7% |
|  | V5 fresh | 10.3% C_lantern (7.4-14.3%) | +24.0 pp | +1.3 pp | 22.7% | 11.7% | 43.3% |
|  | V5 full | 18.3% C_edge (14.4-23.1%) | +4.0 pp | +10.3 pp | 30.0% | 28.7% | 46.7% |
| X2 commit 3.0 / 1.0 (beyond the brief) | V0 fresh | 9.3% C_lantern (6.5-13.2%) | +3.7 pp | -4.3 pp | 1.0% | 5.0% | 38.7% |
|  | V0 full | 23.0% C_edge (18.6-28.1%) | -3.0 pp | -6.0 pp | 1.7% | 17.0% | 45.3% |
|  | V5 fresh | 0.3% C_lantern (0.1-1.9%) | +1.3 pp | +0.7 pp | 1.3% | 1.0% | 5.0% |
|  | V5 full | 2.7% C_edge (1.4-5.2%) | +3.0 pp | +1.3 pp | 0.7% | 4.0% | 17.3% |

**What is signal.** Paired sign tests on the 300 seeds, against E0:

- E1b: Edge at V0 full 40 wins gained against 23 lost (p = 0.04), Lantern at V5 full 10 against 0 (p = 0.002), Edge at V0 fresh 23 against 12 (p = 0.09); Shatter 10 against 17 at V0 fresh (p = 0.25), level elsewhere; A and R within 4 net in every cell (none significant). E1a: the same shape at about half the size (Edge at V0 full 31 against 22, p = 0.27; Lantern at V5 full 9 against 0, p = 0.004).
- E2b: A 87 against 49 at V0 full (p = 0.001) and 72 against 46 at V0 fresh (p = 0.02); R 32 against 11 at V0 fresh (p = 0.002) and 24 against 9 at V5 full (p = 0.01); Shatter 59 against 20 and Lantern 24 against 5 at V5 full (both p = 0.001 or less); Edge, the worst way at V0, 18 against 15 in the fresh pool and 42 against 33 in the full pool (neither significant).
- E3: Shatter 87 against 19 and Lantern 79 against 14 at V0 fresh, Lantern 85 against 28 at V0 full (all p < 0.001).

## Where the runs end

Deaths by act and wins, both bands pooled (300 runs per arm and cell).

| Cell | Arm | E0: Act 1 / 2 / 3 deaths, wins | E1B: Act 1 / 2 / 3 deaths, wins | E2A: Act 1 / 2 / 3 deaths, wins | E2B: Act 1 / 2 / 3 deaths, wins | X1: Act 1 / 2 / 3 deaths, wins | E3: Act 1 / 2 / 3 deaths, wins |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 105 / 107 / 52, 36 | 104 / 101 / 66, 29 | 59 / 124 / 76, 41 | 21 / 140 / 92, 47 | 21 / 27 / 85, 167 | 78 / 82 / 36, 104 |
| V0 fresh | C_lantern | 155 / 74 / 51, 20 | 152 / 83 / 45, 20 | 86 / 124 / 73, 17 | 37 / 165 / 72, 26 | 37 / 74 / 75, 114 | 114 / 63 / 38, 85 |
| V0 fresh | C_edge | 84 / 157 / 43, 16 | 67 / 153 / 53, 27 | 37 / 188 / 55, 20 | 13 / 199 / 69, 19 | 13 / 48 / 81, 158 | 69 / 94 / 76, 61 |
| V0 fresh | A | 92 / 56 / 36, 116 | 90 / 56 / 40, 114 | 29 / 74 / 59, 138 | 15 / 73 / 70, 142 | 15 / 15 / 19, 251 | 92 / 56 / 36, 116 |
| V0 fresh | R | 149 / 93 / 43, 15 | 149 / 92 / 41, 18 | 74 / 147 / 57, 22 | 26 / 165 / 73, 36 | 26 / 49 / 100, 125 | 149 / 93 / 43, 15 |
| V0 full | C_shatter | 60 / 76 / 44, 120 | 59 / 66 / 54, 121 | 29 / 82 / 58, 131 | 8 / 90 / 60, 142 | 8 / 25 / 33, 234 | 50 / 70 / 40, 140 |
| V0 full | C_lantern | 97 / 74 / 68, 61 | 89 / 94 / 53, 64 | 54 / 115 / 69, 62 | 21 / 143 / 70, 66 | 21 / 44 / 70, 165 | 74 / 63 / 45, 118 |
| V0 full | C_edge | 45 / 132 / 75, 48 | 31 / 145 / 59, 65 | 15 / 155 / 76, 54 | 3 / 151 / 89, 57 | 3 / 42 / 78, 177 | 46 / 107 / 79, 68 |
| V0 full | A | 43 / 65 / 56, 136 | 42 / 69 / 49, 140 | 22 / 63 / 58, 157 | 5 / 65 / 56, 174 | 5 / 16 / 28, 251 | 43 / 65 / 56, 136 |
| V0 full | R | 86 / 100 / 63, 51 | 79 / 105 / 64, 52 | 37 / 123 / 74, 66 | 9 / 138 / 86, 67 | 9 / 36 / 77, 178 | 86 / 100 / 63, 51 |
| V5 fresh | C_shatter | 232 / 57 / 11, 0 | 219 / 66 / 15, 0 | 176 / 103 / 20, 1 | 87 / 187 / 24, 2 | 87 / 89 / 66, 58 | 226 / 47 / 16, 11 |
| V5 fresh | C_lantern | 268 / 24 / 7, 1 | 263 / 24 / 10, 3 | 209 / 72 / 15, 4 | 118 / 154 / 24, 4 | 118 / 100 / 51, 31 | 258 / 24 / 12, 6 |
| V5 fresh | C_edge | 240 / 58 / 1, 1 | 225 / 72 / 2, 1 | 175 / 116 / 8, 1 | 68 / 210 / 21, 1 | 68 / 133 / 47, 52 | 237 / 45 / 15, 3 |
| V5 fresh | A | 232 / 30 / 23, 15 | 227 / 34 / 24, 15 | 153 / 82 / 40, 25 | 81 / 106 / 83, 30 | 81 / 37 / 52, 130 | 232 / 30 / 23, 15 |
| V5 fresh | R | 267 / 27 / 3, 3 | 265 / 27 / 5, 3 | 204 / 79 / 15, 2 | 110 / 157 / 28, 5 | 110 / 99 / 56, 35 | 267 / 27 / 3, 3 |
| V5 full | C_shatter | 179 / 64 / 21, 36 | 176 / 68 / 17, 39 | 125 / 97 / 30, 48 | 63 / 117 / 45, 75 | 63 / 62 / 47, 128 | 157 / 73 / 27, 43 |
| V5 full | C_lantern | 214 / 63 / 17, 6 | 210 / 64 / 10, 16 | 167 / 85 / 31, 17 | 95 / 153 / 27, 25 | 95 / 97 / 36, 72 | 209 / 40 / 23, 28 |
| V5 full | C_edge | 155 / 116 / 17, 12 | 132 / 133 / 20, 15 | 98 / 169 / 23, 10 | 47 / 216 / 24, 13 | 47 / 139 / 59, 55 | 155 / 96 / 31, 18 |
| V5 full | A | 159 / 66 / 23, 52 | 154 / 67 / 26, 53 | 101 / 93 / 35, 71 | 55 / 127 / 47, 71 | 55 / 67 / 38, 140 | 159 / 66 / 23, 52 |
| V5 full | R | 213 / 65 / 10, 12 | 205 / 70 / 13, 12 | 145 / 116 / 18, 21 | 86 / 144 / 43, 27 | 86 / 84 / 44, 86 | 213 / 65 / 10, 12 |

- **Act 1 is where committed runs end first, not what limits them.** At x0.8 (E2b) Act-1 deaths fall by 76-93% at V0 and 56-72% at V5, and most of the rescued runs die in Act 2 or Act 3. Net, at V0 fresh, committed Edge gains 3 wins for 71 fewer Act-1 deaths, Lantern 6 for 118 and Shatter 11 for 84, where the adaptive arm gains 26 for 77 and the random arm 21 for 123. At V0 full the adaptive arm gains 38 wins for 38 fewer Act-1 deaths, committed Shatter 22 for 52, Edge 9 for 42 and Lantern 5 for 76.
- **Each way has its own wall.** At V0 full with the shipped content, committed Lantern dies most in Act 1 (97 of 300), committed Edge in Act 2 (132 of 300, twice the adaptive arm's 65), and Shatter spreads its deaths (60, 76, 44) while winning most of the three (120 of 300). An Act-1 scalar meets only Lantern's wall, and Lantern's rescued runs die in Act 2.
- **The lantern's upside works where decks are lit and alive.** At V0 full E1b moves committed Edge from 45 Act-1 and 75 Act-3 deaths to 31 and 59 (its Act-2 deaths rise from 132 to 145), and from 48 wins to 65, and leaves Shatter's and R's distributions as they were.

## The splash arms: what the decks are

Seeds 13200-13299. Tiers at the end of Act 1 are of the runs that reach it and read the deck whatever its dominant way; "Edge dominant" is the share of all runs whose deck ends dominant in Edge.

| Cell | Experiment | Arm | Own way dominant, end of Act 1 | Median own-way share, end of Act 1 | Edge dominant, run end | End of Act 1: Soot / Kindling / Steady / True | Run end: Soot / Kindling / Steady / True |
|---|---|---|---:|---:|---:|---|---|
| V0 fresh | E0 | C_shatter | 98.5% | 0.60 | 2.0% | 3 / 42 / 55 / 0% (n=65) | 7 / 52 / 38 / 3% |
| V0 fresh | E0 | C_lantern | 85.1% | 0.60 | 1.0% | 9 / 34 / 57 / 0% (n=47) | 5 / 40 / 54 / 1% |
| V0 fresh | E0 | C_edge | 98.5% | 0.69 | 100.0% | 0 / 17 / 76 / 8% (n=66) | 0 / 4 / 60 / 36% |
| V0 fresh | E3 | C_shatter | 27.6% | 0.30 | 77.0% | 34 / 54 / 12 / 0% (n=76) | 33 / 59 / 7 / 1% |
| V0 fresh | E3 | C_lantern | 37.9% | 0.37 | 65.0% | 31 / 45 / 24 / 0% (n=58) | 41 / 43 / 13 / 3% |
| V0 fresh | E3 | C_edge | 95.6% | 0.63 | 98.0% | 7 / 34 / 59 / 0% (n=68) | 6 / 20 / 64 / 10% |
| V0 fresh | X2 | C_shatter | 26.3% | 0.30 | 77.0% | 34 / 54 / 12 / 0% (n=76) | 32 / 61 / 6 / 1% |
| V0 fresh | X2 | C_lantern | 36.1% | 0.36 | 61.0% | 33 / 46 / 21 / 0% (n=61) | 38 / 48 / 11 / 3% |
| V0 fresh | X2 | C_edge | 97.2% | 0.63 | 99.0% | 6 / 34 / 61 / 0% (n=71) | 2 / 16 / 69 / 13% |
| V0 full | E0 | C_shatter | 87.2% | 0.56 | 4.0% | 4 / 56 / 38 / 1% (n=78) | 5 / 51 / 44 / 0% |
| V0 full | E0 | C_lantern | 98.4% | 0.68 | 1.0% | 2 / 24 / 65 / 10% (n=62) | 1 / 9 / 63 / 27% |
| V0 full | E0 | C_edge | 100.0% | 0.77 | 100.0% | 0 / 2 / 70 / 28% (n=86) | 0 / 1 / 24 / 75% |
| V0 full | E3 | C_shatter | 17.1% | 0.29 | 80.0% | 28 / 54 / 18 / 0% (n=82) | 36 / 46 / 17 / 1% |
| V0 full | E3 | C_lantern | 60.3% | 0.43 | 42.0% | 19 / 62 / 19 / 0% (n=73) | 26 / 60 / 14 / 0% |
| V0 full | E3 | C_edge | 100.0% | 0.70 | 99.0% | 2 / 20 / 59 / 19% (n=85) | 2 / 11 / 59 / 28% |
| V0 full | X2 | C_shatter | 17.1% | 0.29 | 79.0% | 29 / 52 / 18 / 0% (n=82) | 40 / 41 / 18 / 1% |
| V0 full | X2 | C_lantern | 68.0% | 0.48 | 35.0% | 12 / 60 / 28 / 0% (n=75) | 15 / 66 / 19 / 0% |
| V0 full | X2 | C_edge | 100.0% | 0.72 | 99.0% | 1 / 21 / 58 / 19% (n=84) | 2 / 8 / 58 / 32% |
| V5 fresh | E0 | C_shatter | 100.0% | 0.67 | 2.0% | 0 / 33 / 67 / 0% (n=24) | 4 / 56 / 39 / 1% |
| V5 fresh | E0 | C_lantern | 90.0% | 0.62 | 4.0% | 10 / 40 / 50 / 0% (n=10) | 13 / 49 / 37 / 1% |
| V5 fresh | E0 | C_edge | 90.9% | 0.67 | 97.0% | 0 / 23 / 68 / 9% (n=22) | 1 / 15 / 70 / 14% |
| V5 fresh | E3 | C_shatter | 60.9% | 0.38 | 51.0% | 35 / 52 / 13 / 0% (n=23) | 43 / 48 / 9 / 0% |
| V5 fresh | E3 | C_lantern | 43.8% | 0.38 | 47.0% | 19 / 69 / 12 / 0% (n=16) | 39 / 50 / 11 / 0% |
| V5 fresh | E3 | C_edge | 81.0% | 0.53 | 88.0% | 19 / 57 / 24 / 0% (n=21) | 15 / 34 / 47 / 4% |
| V5 fresh | X2 | C_shatter | 63.6% | 0.38 | 52.0% | 36 / 50 / 14 / 0% (n=22) | 42 / 49 / 9 / 0% |
| V5 fresh | X2 | C_lantern | 43.8% | 0.38 | 50.0% | 19 / 69 / 12 / 0% (n=16) | 36 / 51 / 13 / 0% |
| V5 fresh | X2 | C_edge | 87.5% | 0.55 | 88.0% | 8 / 54 / 38 / 0% (n=24) | 13 / 25 / 55 / 7% |
| V5 full | E0 | C_shatter | 95.1% | 0.53 | 6.0% | 10 / 49 / 39 / 2% (n=41) | 8 / 61 / 31 / 0% |
| V5 full | E0 | C_lantern | 100.0% | 0.64 | 2.0% | 6 / 27 / 64 / 3% (n=33) | 1 / 20 / 67 / 12% |
| V5 full | E0 | C_edge | 100.0% | 0.76 | 99.0% | 0 / 2 / 79 / 19% (n=57) | 1 / 2 / 58 / 39% |
| V5 full | E3 | C_shatter | 26.5% | 0.30 | 67.0% | 33 / 47 / 18 / 2% (n=49) | 40 / 48 / 12 / 0% |
| V5 full | E3 | C_lantern | 65.6% | 0.44 | 46.0% | 28 / 50 / 22 / 0% (n=32) | 28 / 53 / 18 / 1% |
| V5 full | E3 | C_edge | 100.0% | 0.65 | 98.0% | 0 / 27 / 69 / 4% (n=48) | 1 / 25 / 67 / 7% |
| V5 full | X2 | C_shatter | 28.0% | 0.30 | 64.0% | 32 / 50 / 16 / 2% (n=50) | 41 / 48 / 11 / 0% |
| V5 full | X2 | C_lantern | 77.8% | 0.49 | 33.0% | 22 / 58 / 19 / 0% (n=36) | 23 / 48 / 25 / 4% |
| V5 full | X2 | C_edge | 100.0% | 0.67 | 98.0% | 0 / 22 / 72 / 6% (n=50) | 1 / 24 / 63 / 12% |

The same arms on 13000-13199: splash Shatter ends Edge-dominant in 68% (E3) and 68% (X2) of runs at V0 fresh and in 78% and 76% at V0 full, and reads Steady in Shatter by the end of Act 1 in 1.5% of runs in all four; splash Lantern ends Edge-dominant in 40-60% at V0 and reads Steady in Lantern in 7.0-10.0%.

**Why every splash turns Edge: supply.** The coloured glass offered per run, by way (E0, seeds 13000-13199, the two arms that do not steer by a way):

| Cell | Arm | Offered per run: shatter / lantern / edge | Shares of the offered coloured glass: shatter / lantern / edge |
|---|---|---|---|
| V0 fresh | A | 4.3 / 6.6 / 14.1 | 17 / 26 / 56% |
| V0 fresh | R | 2.8 / 4.7 / 10.3 | 16 / 26 / 58% |
| V0 full | A | 4.8 / 11.8 / 21.4 | 13 / 31 / 56% |
| V0 full | R | 3.5 / 9.5 / 16.8 | 12 / 32 / 57% |
| V5 fresh | A | 3.0 / 4.0 / 7.5 | 21 / 28 / 52% |
| V5 fresh | R | 2.2 / 3.1 / 6.6 | 18 / 26 / 56% |
| V5 full | A | 3.5 / 8.8 / 13.4 | 13 / 34 / 52% |
| V5 full | R | 2.4 / 6.1 / 9.9 | 13 / 33 / 54% |

A run meets 2 to 5 Shatter cards against 7 to 21 Edge cards. The committed pilot's 0.5 on other colours is what keeps a Shatter or Lantern deck in its way; remove it (X2) and the deck becomes what it is offered, whatever weight its own glass carries. Committed Shatter decks stay small instead: a median coloured mass of 6.0-7.5 at the end of Act 1 against Edge's 10.0-11.0 (both bands), and Kindling in 33-56% of the runs that reach the end of Act 1 (13200-13299).

## Reading the levers

### E1: the lantern's upside

- **What moved.** Win rates on 13200-13299 moved -3 to +13 pp for the committed arms (Edge at V0 full +10 and +13, Lantern and Edge at V5 full +5); on 13000-13199 -2.0 to +4.5 pp. Pooled, the worst way rises 5.3 to 6.7% at V0 fresh, 16.0 to 19.0% (E1a) and 21.3% (E1b) at V0 full, 2.0 to 5.0% at V5 full. A and R move within noise.
- **Gates.** No verdict changes in any cell on either band, G3 included (V0 fresh stays FAIL at +27 to +28 pp pooled, where it already failed). G4 moves the right way by 2.7 to 5.0 pp at V0 full and V5 full (pooled). Steady by the end of Act 1 rises only with survival (Edge at V0 fresh 55 to 63-64% on 13200-13299): no build decision reads the lantern.
- **Why so small.** Only a Steady or True deck feels it. Shatter's decks are Steady by the end of Act 1 in 29-36% of runs at V0, Lantern's die in Act 1 before the lantern matters, and the second knob of E1b (the cap) and its third (the True Art) matter only where True is common: Edge in the full pool, 28% True at the end of Act 1. That is where E1b beats E1a.

### E2: the Act-1 enemy scalar

- **What moved.** Act-1 deaths collapse; wins do not follow for the committed ways (see Where the runs end). Pooled, at x0.8, the worst way gains 0.3 to 3.0 pp, A 8.6 and 12.7 pp at V0 fresh and V0 full, and R 7.0 and 5.3 pp.
- **Gates.** G1 nowhere near. G2 widens at V0 full (13200-13299: 26 to 31 and 34 pp; 13000-13199: 23 to 27 pp at x0.8), because the runs the scalar rescues become wins for Shatter (22 for 52 fewer Act-1 deaths) far more than for Edge (9 for 42) or Lantern (5 for 76). G3 widens at V0 fresh (+26.7 to +31.7 pp pooled) and V0 full (+5.3 to +10.7 pp), and flips to FAIL at V5 full on 13200-13299 (committed Shatter 26% over A 18%). G4 gets worse in every cell (pooled: -0.3 to +5.7 pp at V0 fresh, +1.0 to +3.3 pp at V0 full, +2.0 to +4.7 pp at V5 full). G5 rises through survival and passes at V0 fresh at x0.8 (45.0% and 43.0%, 43.7% pooled): the one gate the fallback helps, through survival rather than the reachability readout 5 set that figure to grade.
- **Soot.** The adaptive arm reads Soot at the end of Act 1 in 25-46% of the runs that reach it, the random arm in 12-27%, as at E0 (13200-13299): the scalar changes who survives, not how anyone builds.

### E3 and X2: the splash arms

- **What moved.** The committed arms win far more (pooled worst way 20.3% at V0 fresh, 22.7% at V0 full, 6.0% at V5 full, against 5.3, 16.0 and 2.0%). G3 comes into band at V0 fresh (+4.0 pp pooled) but fails at V0 full on 13000-13199 (splash Shatter 50.0% over A 46.0%). G4 moves furthest of any lever (-15.3 pp at V0 fresh and -5.7 pp at V0 full, pooled), still short of -25.
- **What the decks are.** Splash Shatter is an Edge deck with a Shatter lean: Edge-dominant at run end in 68-80% of runs at V0, Steady in Shatter by the end of Act 1 in 0-2%, Soot at the end of Act 1 in 28-40%. Splash Lantern is half Edge (35-65%). Splash Edge stays Edge (86-100%) and gains 7 to 15 pp at V0 (pooled). X2 gives the same picture with the full commitment weight kept: the aversion, not the lean, holds a deck in its way.
- **The brief's question.** Main path plus splash does not reach viability (the worst splash arm meets no G1 floor in any cell; the nearest is 22.7% pooled against 50% at V0 full), and its decks do not read Steady by the end of Act 1, except Edge's: the one way whose supply can carry a splash. These Soot-leaning mixtures also out-win the pure Shatter and Lantern decks, so the Soot tier's tax does not outweigh a mixture's strength.

### X1: the scalar as a class

- Pooled, G1 passes at V0 full (55.0%, Wilson 49.3-60.5%) and fails elsewhere (38.0% against 40% at V0 fresh, 18.3% against 25% at V5 full). R reaches 41.7, 59.3 and 28.7% at V0 fresh, V0 full and V5 full, over G4's ceilings, and A 83.7% at V0 in both pools; G3 fails at V0 fresh (+28.0 pp) and V5 fresh (+24.0 pp).
- Across every scalar point measured (E2a, E2b and X1, four cells, pooled), R sits above the worst committed way, by 0.3 to 10.3 pp. A scalar changes the level of every arm; the gap G4 grades is set by how much better an insisting deck is than a scattered one, which no enemy number touches.

### The gates' arithmetic

With R where it is (17.0% at V0 full pooled), G4 would pass at V0 full once every committed way wins 42%; G1 asks 50%, above the adaptive arm's own 45.3%. Because G3 keeps A within 3 pp below the best committed way, G1's full-pool floor asks for a game in which the adaptive pilot wins at least 47% at V0. That part of G1 is a statement about difficulty, not about the flame.

## Appendix A: the catalogue script

`make_catalogues.py`, kept in the private scratch folder and reproduced here. It refuses any input but the shipped catalogue, checks that its JSON round trip reproduces the file byte for byte, and writes one copy per experiment.

```python
#!/usr/bin/env python3
"""Readout 6: write the scratch catalogues for E1a, E1b, E2a, E2b and X1.

Research only. Reads the shipped catalogue, never writes it, and writes one
copy per experiment into OUT_DIR with the same JSON layout (a round trip of the
shipped file reproduces it byte for byte, which is checked first).

E1 (the lantern's upside) sets keys under aspects[0].flame.lantern.
E2 (the Act-1 enemy scalar) scales every enemy of the Act-1 encounter table
(encounters[0], all tiers) the way the game's own variant statMods scale an
enemy (CombatRules._resolved_enemy): both ends of the HP range and each move's
per-hit `dmg`, rounded half away from zero, HP at least 1 and damage at least
0. Nothing else moves: hit counts, Ward, statuses (Strength, Ritual, Thorns,
Poison, Weak, Frail, Vulnerable), wounds, heals, ramps and Facets keep their
values. X1, beyond the brief, applies E2b's x0.8 to the enemies of all three
acts a run plays (encounters[0..2]).

Usage: python3 make_catalogues.py CONTENT_JSON OUT_DIR
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
import sys
from pathlib import Path

SHIPPED_SHA256 = "0911660d88e7f793d92527f1487f4dfdf14a7fbd3ca3e5d8686e7b00ebaef280"

LANTERN_POINTS = {
    "e1a": {"steadyFirstGain": 2},
    "e1b": {"steadyFirstGain": 2, "steadyCap": 4, "trueArtCost": 2},
}
# point -> (factor, acts scaled): E2 scales Act 1 only; X1 (beyond the brief)
# scales all three acts a run plays, to test the scalar as a class.
SCALAR_POINTS = {"e2a": (0.9, 1), "e2b": (0.8, 1), "x1": (0.8, 3)}


def dump(data: dict) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def round_half_away(value: float) -> int:
    """Godot's roundf for the non-negative values scaled here."""
    return int(math.floor(value + 0.5))


def act_enemies(data: dict, acts: int) -> list[str]:
    """The enemies of the first `acts` encounter tables, none shared with a later act."""
    ids: list[str] = []
    for row in data["encounters"][:acts]:
        for groups in row.values():
            for group in groups:
                for enemy_id in group:
                    if enemy_id not in ids:
                        ids.append(enemy_id)
    later = {enemy_id for row in data["encounters"][acts:] for groups in row.values()
             for group in groups for enemy_id in group}
    shared = sorted(set(ids) & later)
    if shared:
        raise SystemExit(f"scaled enemies also appear in a later act: {shared}")
    return ids


def scale_enemies(data: dict, factor: float, acts: int) -> list[tuple[str, str, str, str]]:
    changes: list[tuple[str, str, str, str]] = []
    for enemy_id in act_enemies(data, acts):
        enemy = data["enemies"][enemy_id]
        low, high = enemy["hp"]
        scaled = [max(1, round_half_away(low * factor)), max(1, round_half_away(high * factor))]
        changes.append((enemy_id, "hp", f"{low}-{high}", f"{scaled[0]}-{scaled[1]}"))
        enemy["hp"] = scaled
        for move_id, move in enemy["moves"].items():
            if "dmg" not in move:
                continue
            before = move["dmg"]
            move["dmg"] = max(0, round_half_away(before * factor))
            times = f" x{move['times']}" if "times" in move else ""
            changes.append((enemy_id, f"{move_id}.dmg", f"{before}{times}", f"{move['dmg']}{times}"))
    return changes


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    source, out_dir = Path(argv[1]), Path(argv[2])
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SHIPPED_SHA256:
        raise SystemExit(f"{source} is not the catalogue this readout was planned on")
    shipped = json.loads(raw)
    if dump(shipped).encode("utf-8") != raw:
        raise SystemExit("the JSON round trip does not reproduce the shipped file")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, knobs in LANTERN_POINTS.items():
        data = copy.deepcopy(shipped)
        data["aspects"][0]["flame"]["lantern"].update(knobs)
        text = dump(data)
        (out_dir / f"{name}.json").write_text(text, encoding="utf-8")
        print(f"{name}: aspects[0].flame.lantern {json.dumps(data['aspects'][0]['flame']['lantern'])} "
              f"sha256 {hashlib.sha256(text.encode('utf-8')).hexdigest()}")
    tables: dict[str, list[tuple[str, str, str, str]]] = {}
    for name, (factor, acts) in SCALAR_POINTS.items():
        data = copy.deepcopy(shipped)
        tables[name] = scale_enemies(data, factor, acts)
        text = dump(data)
        (out_dir / f"{name}.json").write_text(text, encoding="utf-8")
        print(f"{name}: the enemies of acts 1-{acts} x{factor}, {len(tables[name])} fields, "
              f"sha256 {hashlib.sha256(text.encode('utf-8')).hexdigest()}")
    print("\n| Enemy | Field | Shipped | x0.9 (E2a) | x0.8 (E2b) |\n|---|---|---|---|---|")
    for row_a, row_b in zip(tables["e2a"], tables["e2b"]):
        print(f"| {row_a[0]} | {row_a[1]} | {row_a[2]} | {row_a[3]} | {row_b[3]} |")
    print("\n| Enemy (acts 2 and 3, X1 only) | Field | Shipped | x0.8 (X1) |\n|---|---|---|---|")
    for row in tables["x1"][len(tables["e2b"]):]:
        print(f"| {row[0]} | {row[1]} | {row[2]} | {row[3]} |")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

## Appendix B: the fields E2 scaled

The nine Act-1 enemies, every field E2a and E2b changed (28 each). X1 applies the E2b rule to these and to the 18 enemies of acts 2 and 3 (drownedOne, voltEel, mirelurker, tidecaller, shellback, deepmaw, abyssalKnight, siren, leviathan; voidWisp, shade, starCultist, obsidianGolem, chaosHound, watcherEye, voidColossus, heraldOfEnd, sovereign): 85 fields in all, the full table printed by the script.

| Enemy | Field | Shipped | x0.9 (E2a) | x0.8 (E2b) |
|---|---|---|---|---|
| sporeling | hp | 13-17 | 12-15 | 10-14 |
| sporeling | spit.dmg | 4 | 4 | 3 |
| duskfang | hp | 26-30 | 23-27 | 21-24 |
| duskfang | bite.dmg | 7 | 6 | 6 |
| duskfang | rend.dmg | 4 x2 | 4 x2 | 3 x2 |
| gloomslime | hp | 30-34 | 27-31 | 24-27 |
| gloomslime | slam.dmg | 8 | 7 | 6 |
| gloomslime | ooze.dmg | 3 | 3 | 2 |
| gloomslime | harden.dmg | 4 | 4 | 3 |
| ashAcolyte | hp | 34-38 | 31-34 | 27-30 |
| ashAcolyte | scorch.dmg | 6 | 5 | 5 |
| waylayer | hp | 28-32 | 25-29 | 22-26 |
| waylayer | stab.dmg | 9 | 8 | 7 |
| waylayer | trick.dmg | 4 | 4 | 3 |
| thornling | hp | 18-22 | 16-20 | 14-18 |
| thornling | prick.dmg | 6 | 5 | 5 |
| thornling | burst.dmg | 10 | 9 | 8 |
| gravewarden | hp | 70-76 | 63-68 | 56-61 |
| gravewarden | crush.dmg | 12 | 11 | 10 |
| gravewarden | bulwark.dmg | 6 | 5 | 5 |
| alphaFang | hp | 64-70 | 58-63 | 51-56 |
| alphaFang | savage.dmg | 5 x2 | 5 x2 | 4 x2 |
| alphaFang | throat.dmg | 13 | 12 | 10 |
| rootheart | hp | 240-240 | 216-216 | 192-192 |
| rootheart | lash.dmg | 12 | 11 | 10 |
| rootheart | spores.dmg | 5 | 5 | 4 |
| rootheart | entangle.dmg | 7 | 6 | 6 |
| rootheart | slam.dmg | 22 | 20 | 18 |

## Appendix C: the splash-arm flag

Two commits on this branch and nowhere else: `d0d1ec56` adds the flag, and `72d20002` moves its GDScript below the declarations that `docs/balance/2026-08-13-tier1-grammar.md` cites by line, which `d0d1ec56` had shifted (`tools/check_anchors.py` reported six drifted anchors there and reports none at `72d20002`). The flag as it stands:

- `tools/balance_pilot.gd`: the committed arms' weights come from the policy's `wayCommit` and `wayOff` when it carries them, from `WAY_COMMIT` (3.0) and `WAY_OFF` (0.5) otherwise.
- `tools/balance_sim.gd`: `--wayCommit` and `--wayOff` (positive, only with `--way`) enter the policy only when given, so a run without them records the same policy and digest as on `main`.
- `tools/balance_ways.py`: `--way-weights COMMIT/OFF` passes them to the three committed arms only; the grader checks that the committed arms agree and prints the weights.
- `tests/test_balance_ways.py`: the weights reach the committed arms only, and malformed weights are refused.

Checks at `72d20002`, the first three also run at `d0d1ec56`: `python3 -B tests/test_balance_ways.py` (9 tests, OK); `tools/check_scripts.sh` on the two scripts (OK); `godot --headless -s res://tests/run_all.gd -- --tests=` `test_balance_sim`, `test_balance_arms`, `test_balance_pilot_cache`, `test_balance_pilot_play` and `test_balance_catalogue` (PASS, 5 tests, the seed-1000 digests unchanged); the simulator refuses `--wayCommit` without `--way` and a weight that is not a positive number; E0's 24 reports identical at all three heads; E3's and X2's identical at both flag heads.

## Recommendation for the owner

**Which lever reaches G1 or G4 with the least damage to G3?** None of the three reaches G1 or G4 in any graded cell, on 100 or on 300 seeds. Ranked by what they buy:

1. **E1b, the lantern's upside,** is the only change to the game that moves G4 the right way without changing a G3 verdict or lifting the random or adaptive arms: 3 to 5 pp at V0 full and V5 full, from the Steadiest ways (Edge, and Lantern in the full pool).
2. **E3, the splash arm,** moves G4 furthest (-15.3 pp at V0 fresh) and brings G3 into band there, but only by grading Edge mixtures under Shatter's and Lantern's names (their G5 falls to 0-2% and 4-18%). It is not a lever on the game.
3. **E2, the Act-1 scalar,** moves G4 the wrong way (+2 to +6 pp), widens G3 and G2, and passes only G5, through survival.
4. **X1, a whole-run scalar,** buys G1 at V0 full alone and breaks G4's ceiling (R 59%).

**What each costs in the game's feel.**

- **An easier Act 1 for everyone.** Every player meets a softer Ashen Woods whatever they build; the cliff moves to the Sunken City, where the rescued runs die; scattered and adaptive builds gain more than insisting ones (R +7 pp at V0 fresh, A +13 pp at V0 full). The three ways feel no different. It works against the lock's own promise that a player who scatters cannot win, and it touches only Lantern's wall.
- **A bigger reward for staying lit.** Felt only by a lit lantern, in the currency the player already watches: the turn's first Ember gain brings two extra instead of one, the lantern holds more, a True flame's Art costs less. The same for every way, so no set bonus, and it pays for exactly what the flame asks. The cost is a little power for lit decks, and nothing for Shatter, whose decks are rarely lit.
- **Redefining what "committed" means.** Nothing changes in the game; the certificate does. G1 would certify that leaning towards Shatter wins while the lantern shows those decks as Edge or Soot, so the ways the player can see would go uncertified. Its value is diagnostic: commitment to Shatter and Lantern is a trap because their glass is scarce.

**What I would ship first, and why.**

1. **E1b** (`steadyFirstGain` 2, `steadyCap` 4, `trueArtCost` 2) as the next point of calibration step 3, inside the lock. It is the only measured change that lifts insisting decks without lifting scattered or adaptive ones (paired, 300 seeds), it touches no enemy and no card, it is identical for every way, and it changes no G3 verdict. It is a down payment, not the answer: G4 at V0 full goes from +1.0 to -4.0 pp against -25.
2. **Do not take the enemy-scalar fallback as the flame's answer to G4.** An Act-1 scalar makes G3 and G4 worse and moves the deaths into Act 2; a whole-run scalar changes every arm's level and never the gap. If the game should be easier for its own sake (the adaptive pilot wins 45% at V0 full, under G1's 50% floor for each way), take that as a difficulty decision against a difficulty target, knowing the dial is steep: x0.8 across the run takes the adaptive pilot from 45% to 84%.
3. **Put the next round on supply and the walls, before any other number moves.** Shatter is 12-21% of the coloured glass on offer and its committed decks often stay Kindling; Lantern dies in Act 1; Edge dies in Act 2. These are three questions about the ways' content (the offer's colour balance, and why each pure deck falls where it does), not one scalar. The splash result says the first of them, supply, decides whether "one main path with a little help" can exist in this game at all.
