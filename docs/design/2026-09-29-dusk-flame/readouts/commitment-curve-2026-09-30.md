# Commitment curve, 30 September 2026 (research note, main 82ede8ea)

Asked by the owner: does the "correct build" win more, and is no build hard? This sweep turns the committed arm's commit factor (`--way-weights`, off-way 0.5) from 1.0 to 8.0 on seeds 13000–13199, V0 fresh and full. Figure: `commitment-curve-2026-09-30.png`. Research only; no gate or threshold changes.

# Commitment curve, V0, seeds 13000-13199, main 82ede8ea

Research run (AI-SDLC discovery), nothing committed. Instrument: `tools/balance_ways.py` with `tools/balance_pilot.gd` (pilot `p8-d0-v2`, guard 40 turns), shipped content (`content/full-content.json`, SHA-256 `b791034cf085...`, the S2 + L4 catalogue). Duskblade, vow 0, fresh and full pools, 200 paired seeds (13000-13199; the whole sweep cost about 30 s per level, so the 90-minute fallback was not needed). Commit factor swept over 1.0, 1.5, 2.0, 3.0, 5.0 and 8.0 with the off-way factor fixed at its default 0.5 (`--way-weights C/0.5`; the tool accepts any two positive numbers). Figure: `commitment-curve.png`.

## Table (way x level x cell)

| Cell | Way | Commit factor | Wins | n | Win rate | 95% CI (Wilson) |
|---|---|---:|---:|---:|---:|---|
| fresh | Shatter | 1.0 | 38 | 200 | 19.0% | 14.2-25.0% |
| fresh | Shatter | 1.5 | 51 | 200 | 25.5% | 20.0-32.0% |
| fresh | Shatter | 2.0 | 45 | 200 | 22.5% | 17.3-28.8% |
| fresh | Shatter | 3.0 | 51 | 200 | 25.5% | 20.0-32.0% |
| fresh | Shatter | 5.0 | 47 | 200 | 23.5% | 18.2-29.8% |
| fresh | Shatter | 8.0 | 47 | 200 | 23.5% | 18.2-29.8% |
| fresh | Lantern | 1.0 | 79 | 200 | 39.5% | 33.0-46.4% |
| fresh | Lantern | 1.5 | 91 | 200 | 45.5% | 38.7-52.4% |
| fresh | Lantern | 2.0 | 91 | 200 | 45.5% | 38.7-52.4% |
| fresh | Lantern | 3.0 | 65 | 200 | 32.5% | 26.4-39.3% |
| fresh | Lantern | 5.0 | 65 | 200 | 32.5% | 26.4-39.3% |
| fresh | Lantern | 8.0 | 65 | 200 | 32.5% | 26.4-39.3% |
| fresh | Edge | 1.0 | 39 | 200 | 19.5% | 14.6-25.5% |
| fresh | Edge | 1.5 | 33 | 200 | 16.5% | 12.0-22.3% |
| fresh | Edge | 2.0 | 32 | 200 | 16.0% | 11.6-21.7% |
| fresh | Edge | 3.0 | 20 | 200 | 10.0% | 6.6-14.9% |
| fresh | Edge | 5.0 | 20 | 200 | 10.0% | 6.6-14.9% |
| fresh | Edge | 8.0 | 21 | 200 | 10.5% | 7.0-15.5% |
| fresh | Adaptive (A) | n/a | 79 | 200 | 39.5% | 33.0-46.4% |
| fresh | Random (R) | n/a | 19 | 200 | 9.5% | 6.2-14.4% |
| full | Shatter | 1.0 | 113 | 200 | 56.5% | 49.6-63.2% |
| full | Shatter | 1.5 | 113 | 200 | 56.5% | 49.6-63.2% |
| full | Shatter | 2.0 | 96 | 200 | 48.0% | 41.2-54.9% |
| full | Shatter | 3.0 | 95 | 200 | 47.5% | 40.7-54.4% |
| full | Shatter | 5.0 | 89 | 200 | 44.5% | 37.8-51.4% |
| full | Shatter | 8.0 | 89 | 200 | 44.5% | 37.8-51.4% |
| full | Lantern | 1.0 | 110 | 200 | 55.0% | 48.1-61.7% |
| full | Lantern | 1.5 | 117 | 200 | 58.5% | 51.6-65.1% |
| full | Lantern | 2.0 | 119 | 200 | 59.5% | 52.6-66.1% |
| full | Lantern | 3.0 | 95 | 200 | 47.5% | 40.7-54.4% |
| full | Lantern | 5.0 | 91 | 200 | 45.5% | 38.7-52.4% |
| full | Lantern | 8.0 | 94 | 200 | 47.0% | 40.2-53.9% |
| full | Edge | 1.0 | 55 | 200 | 27.5% | 21.8-34.1% |
| full | Edge | 1.5 | 62 | 200 | 31.0% | 25.0-37.7% |
| full | Edge | 2.0 | 55 | 200 | 27.5% | 21.8-34.1% |
| full | Edge | 3.0 | 43 | 200 | 21.5% | 16.4-27.7% |
| full | Edge | 5.0 | 42 | 200 | 21.0% | 15.9-27.2% |
| full | Edge | 8.0 | 43 | 200 | 21.5% | 16.4-27.7% |
| full | Adaptive (A) | n/a | 110 | 200 | 55.0% | 48.1-61.7% |
| full | Random (R) | n/a | 44 | 200 | 22.0% | 16.8-28.2% |

Contrasts on the same seeds (paired, exact two-sided binomial p on seeds one level wins and the other loses):

| Cell | Way | 1.0 to 5.0: gained / lost, paired p | 1.0 to 3.0 | Slope, pp per doubling (OLS on log2 factor, levels 1.0-8.0) | Best level |
|---|---|---|---|---:|---|
| fresh | Shatter | +4.5 pp: 33 / 24, p = 0.29 | +6.5 pp: 35 / 22, p = 0.11 | +0.9 | 1.5 (25.5%) |
| fresh | Lantern | -7.0 pp: 25 / 39, p = 0.10 | -7.0 pp: 25 / 39, p = 0.10 | -4.2 | 1.5 (45.5%) |
| fresh | Edge | -9.5 pp: 17 / 36, p = 0.01 | -9.5 pp: 17 / 36, p = 0.01 | -3.3 | 1.0 (19.5%) |
| full | Shatter | -12.0 pp: 20 / 44, p = 0.00 | -9.0 pp: 26 / 44, p = 0.04 | -4.5 | 1.0 (56.5%) |
| full | Lantern | -9.5 pp: 37 / 56, p = 0.06 | -7.5 pp: 37 / 52, p = 0.14 | -4.4 | 2.0 (59.5%) |
| full | Edge | -6.5 pp: 26 / 39, p = 0.14 | -6.0 pp: 26 / 38, p = 0.17 | -3.1 | 1.5 (31.0%) |

## Reading

1. The hypothesis fails: win rate does not rise with commitment for any way; the fitted slope is negative for Lantern (-4.2 pp per doubling of the commit factor fresh, -4.4 full), Edge (-3.3 fresh, -3.1 full) and Shatter at V0 full (-4.5, with 1.0 to 5.0 costing 12.0 pp, paired p < 0.01), and Shatter at V0 fresh is the only curve with a positive slope (+0.9, 1.0 to 3.0 +6.5 pp but p = 0.11), so Edge is not the flat way but declines as much as the others (fresh, 1.0 to 5.0: -9.5 pp, p = 0.01).
2. The shape is a low hump then a step down and a plateau: Lantern peaks at 1.5-2.0 (45.5% fresh, 59.5% full) and drops 12-13 pp between 2.0 and 3.0, every curve is flat from 5.0 to 8.0 (outcomes identical on 178-200 of 200 seeds between 3.0 and 5.0, 193-200 between 5.0 and 8.0), so "all-in" is reached by about 5.0 and the pilot's default of 3.0 already sits on the plateau.
3. Against the random arm (9.5% fresh, 22.0% full), Shatter and Lantern stay above it at every level in both cells, while Edge is 5-10 pp above random at 1.0-2.0 and falls onto it from 3.0 up (10.0% against 9.5% fresh; 21.5% against 22.0% full).
4. No curve reaches adaptive by commitment: a committed arm at 1.0/1.0 (no preference at all, extra run) reproduces arm A run for run (39.5% fresh, 55.0% full), so A is the zero-commitment point of every curve, the only nominal excesses are Lantern at 1.5-2.0 (45.5% fresh, 58.5-59.5% full) and Shatter at 1.0-1.5 full (56.5%), all inside the overlap of the 95% bands, and at the pilot default 3.0 the committed ways sit 7.0-7.5 pp (Lantern fresh, Shatter and Lantern full) to 33.5 pp (Edge full) below A.
5. What the pilot cannot tell: it plays Lantern better than Shatter and Edge, so the ordering between ways (Lantern on top, Edge at the bottom) is biased by pilot skill and should not be read as balance, whereas each slope compares one way with itself on the same seeds and is not; it also cannot say whether a human who commits harder plays the way better, since here the factor only rescales offer scores and never changes combat play.

## Caveats

- The control reproduces readout 7 exactly at 3.0/0.5 (V0 full: Shatter 47.5, Lantern 47.5, Edge 21.5, A 55.0, R 22.0). A and R do not depend on the factor; the sweep asserts their per-seed outcomes are identical across all six levels.
- Level "1.0" is not zero preference, because the off-way factor stays 0.5 and other-way glass is still halved. The 1.0/1.0 run is the true null.
- Adjacent levels agree on 131-200 of 200 seeds, so a 3 pp wiggle between neighbours (for example Edge full 27.5, 31.0, 27.5) is noise; read the shape, not single points.
- One seed band (13000-13199), the pilot's policy only, and the shipped catalogue (Spall and Hearthfall at 12). The V5 cells were computed by the tool but not analysed.

## Commands (all from the worktree root, `override.cfg` uncommitted and removed afterwards)

```sh
# override.cfg keeps the real save untouched
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="glassvow-test-curve"\n' > override.cfg
godot --headless --import            # the fresh worktree had no import cache
# sweep.sh runs, in order 3.0 1.0 1.5 2.0 5.0 8.0 (3.0 is the control):
python3 -B tools/balance_ways.py --seeds 13000-13199 --jobs 9 --way-weights C/0.5 --out-dir <scratch>/runs/cC > <scratch>/runs/cC.md
# extra null point:
python3 -B tools/balance_ways.py --seeds 13000-13199 --jobs 9 --way-weights 1.0/1.0 --out-dir <scratch>/runs/n1.0-1.0
# table and figure:
python3 analyse.py 82ede8ea          # writes table.md, contrasts.md, commitment-curve.png
python3 agree.py                      # saturation check (seed agreement between levels)
```

`<scratch>` is `/private/tmp/claude-501/-Users-jamesto-Coding-glassvow/b76db86a-b79e-49a2-b973-bc87e903afff/scratchpad/agent-curve`. The raw per-level reports are under `runs/`.
