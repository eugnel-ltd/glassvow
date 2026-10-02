# Readout 11: the full pool

> **Research readout (AI-SDLC discovery), promoted in one PR.** The PR ships one content lever: Inner Blaze (`empower`), Overglow (`frenzy`) and Rising Litany (`risingLitany`) leave Edge's affinity table and become clear glass (`d4f6ed01`). Three lines leave `content/full-content.json`, whose SHA-256 is now `5a20ef2a3674fcdf713142587157c139cf7f57be8d5fa6e72fffba9fb88c2109`. No card text, number, rarity, pool entry, rider, lantern knob, enemy number, combat rule, tool, id or RNG draw moved. Affinity is not printed, so no card face changes.
>
> **Head.** The final tables (V0 at 1,000 paired seeds, V5 at 2,000) ran at `40b21611e57c5ff58c806c7cf1d88308329896a6`, whose manifest every report names. That head carries the content commit and two test-only commits (fixtures and re-pinned digests). Later commits add documents only, so `git diff 40b21611..HEAD -- tools domain content` is empty.

Readout 10 left G6 failing in the full pool: at V0 and at V5, 71–73% of the flame-aware adaptive arm's wins were Edge's. It also left G3 at V5 full 0.4 pp outside its band, and G5 failing in the full pool. The orchestrator set this lane four tasks. First, diagnose why the adaptive arm wins through Edge in the full pool and not in the fresh one. Then measure at most three single-lever candidates that follow from the diagnosis. Ship the one that brings G6 to PASS with the least damage to G2, G3, B1 and B2, or drop all three. Finally, report what happens to G5 in the full pool. G1 and G4 are instrument readings, not GO blockers (orchestrator decision of 30 September), and global difficulty stays closed.

## The answer in brief

- **Diagnosis.** Edge is 46–48% of the coloured glass that every arm is offered, in both pools, so offer share is not what changes between them. What changes is what a capable uncommitted player keeps. The full pool's Edge glass includes stat powers that any deck takes: a commit-blind player keeps Overglow 93% of the times it is offered, Inner Blaze 59% and Rising Litany 28%, and all three were Edge 1.0. The full pool's Lantern glass is left on the table (Pyre Tithe 1%, Novaflare 0%, Emberdance 3%), and Shatter gains only 2.5 coloured mass. So A_lit ends Edge-dominant in 69% of full-pool runs (57% fresh). Those runs win as often as Shatter's in the full pool (46.6% against 47.7%), whereas in the fresh pool they win 9 pp less, which is what kept fresh G6 passing.
- **Three candidates, one shipped.** C1: Edge's three stat powers become clear glass. C2: Shatter affinity goes on the four clear attacks that chip every enemy they hit, or chip when upgraded. C3: Edge's two commons go to half weight. On the development screen, only C1 and C3 bring G6 to PASS in both full cells. C3 does it by costing the adaptive arm itself 3.9 pp at V0 full (p = 0.01); C1 leaves that arm unchanged. C2 lifts committed Shatter's reach dramatically (Steady by the end of Act 1: 49.6% → 79.6%) but costs committed Shatter 7.3 pp of wins and leaves G6 failing. **C1 ships.**
- **G6 now passes everywhere on point.** Edge's share of A_lit's wins is now 58.6% at V0 full (was 71.3%; interval 54.0–63.0%, UNDECIDED) and 48.9% at V5 full (was 72.5%; 43.1–54.8%, PASS on interval). The fresh cells still pass: at V0, Edge is 38.0% (PASS / PASS); at V5 fresh the Lantern leads with 50.6% of 77 wins (PASS / UNDECIDED). The intervals do not overlap readout 10's in either full cell. The mechanism is the one diagnosed: A_lit's Edge-ending runs fall from 693 to 576 of 1,000 (V0 full) and from 1,290 to 936 of 2,000 (V5 full), and their win rates barely move.
- **The cost is the committed Lantern.** Free to take Inner Blaze and Overglow at full worth, committed Lantern gains in every cell: +5.7 pp at V0 fresh (p < 0.001), +3.0 at V0 full (p = 0.05), +2.4 at V5 fresh (p < 0.001) and +2.2 at V5 full (p = 0.002). No other arm moves significantly except committed Edge at V5 full (+2.1 pp, p = 0.01). A_lit moves by +2.6, +0.3, +0.4 and −0.6 pp.
- **G2 and G3 lose point verdicts; the one interval verdict that flips to FAIL is A_lit's B2 at V0 fresh.** G2 at V0 fresh goes from 8.0 to 13.2 pp (Lantern − Shatter). That move is real: it is the Lantern's gain. G2 at V0 full goes from 10.0 to 12.7 pp; that move is noise, since neither end arm moved significantly and the same cell read 15.8 pp on the development seeds before any change. Both cells are UNDECIDED on interval, as they were. G3 at V0 full goes from −2.0 to −3.3 pp (FAIL on point by 0.3 pp), and at V5 full from −3.4 to −4.9 pp. Neither move is significant: G3 V5 full is not back in range, and its interval stays UNDECIDED. G3 in the fresh cells keeps its point PASS but loses its interval PASS (UNDECIDED), because the committed Lantern now leads. Weighed on intervals, the lever removes two decided FAILs (G6 at V0 full and V5 full) and introduces one: A_lit's own B2 at V0 fresh, 58.7% (58.0–59.4%) against 60%.
- **G5 full improves and still fails.** Committed Shatter's Steady by the end of Act 1 rises from 46.3% to 51.1% at V0 full, and its True by the end of Act 2 from 8.7% to 12.5%. Both remain the cell's minimum, against 70% and 40%. Committed Edge's True by the end of Act 2 falls from 40.4% to 24.8%, because its decks lost three cards of mass. Fresh G5 still passes (minimum 48.4%, the Lantern).
- **B and G7.** B1 passes for every way in both pools. B2 is as before for committed Edge (PASS) and the Lantern (UNDECIDED). Committed Shatter in the fresh pool moves from UNDECIDED to PASS. A_lit's own feel row is PASS at V0 full (62.6%), but at V0 fresh it moves from UNDECIDED (59.6%) to FAIL (58.7%, 58.0–59.4%). G7: zero stalls and zero errors in 36,000 runs, and A's three-seed replay is identical in every cell.

## The question

Why does A_lit win through Edge in the full pool but not in the fresh one? Can one lever that follows from that answer bring G6 to PASS at V0 full and V5 full, and G3 at V5 full back into range, without breaking G2, G5 fresh, B1, B2 or G7?

## The instrument

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-readout11", removed before each commit.
# Reproduction check: main (af6b24ea) replays readout 10's rows (V0 full, A_lit and C_shatter, seeds 13000-13049):
python3 -B chunked.py s/repro --seeds 13000-13049 --cells v0-full --arms A_lit,C_shatter --play search --chunk 25 --jobs 4
# Diagnosis, on readout 10's own final reports (no simulation):
python3 -B diag.py <readout 10 final-v0> v0-fresh,v0-full      # offers by way, A_lit by end-dominant and first-lit way, committed reach
python3 -B take.py <readout 10 final-v0> v0-full <cards>        # held at end / offered, per arm
python3 -B static_cf.py <readout 10 final-v0> v0-full A_lit     # G6 re-read with one card's affinity changed (a screen)
python3 -B pools.py                                             # per-way coloured mass in the fresh and full offer pools
# The screen: main and the three candidate catalogues (make_candidates.py), development seeds 12000-12999,
# the two full-pool cells, arms C_shatter, C_lantern, C_edge and A_lit:
screen.sh; python3 -B screen_grade.py screen
# The final tables, the grader's own simulator commands in 50-seed chunks on ten processes (readout 9, appendix B):
python3 -B chunked.py s/final-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay
python3 -B chunked.py s/final-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay
# Grading, and the paired change against readout 10's reports on the same seeds:
python3 -B tools/balance_ways.py --from-dir s/final-v0 --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir s/final-v5 --seeds 13000-14999 --vows 5
python3 -B paired.py s/final-v0 <readout 10 final-v0> v0-fresh,v0-full; python3 -B rowb.py s/final-v0
```

- **Cells, arms, seeds.** The screen used the development band 12000–12999 (1,000 paired seeds) in V0 full and V5 full, the cells where G6 failed, with the four arms G2, G3, G5 and G6 read. The final tables used the lock's §11 table: Duskblade, vows 0 and 5 with the shipping incentives, fresh and full pools, all six arms on common seeds. V0 used 13000–13999 and V5 13000–14999, readout 10's bands, so every change is paired run for run against readout 10's own reports.
- **Measures.** These are the grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference), and row B as readouts 8–10 compute it. Paired tests count the seeds one configuration wins and the other loses, with an exact two-sided binomial p.
- **Budget and the stop rule.** At most three candidates, each a single lever. Each was screened on the two failing cells. A candidate went to the final table only if it brought G6 to PASS on point in both full cells. Among those, the one with the least damage to G3 and G2 shipped, and the shipped one had to move G6 beyond its interval. Its final table was read as it fell.
- **No new instrument knobs.** The diagnosis reads fields the simulator's run rows already carry (`packageEvents`' `<card>Offered` counters, `deckIds`, the per-fight flame rows). No tool, policy constant or grader threshold changed, so `docs/balance/` gains nothing.
- **Wall time.** Each screen configuration took 28–30 minutes on ten processes (4 × 8,000 run rows). The final V0 table took 41 minutes and the V5 table 46 (36,012 run rows). A first start of the final tables was stopped and re-run because test-only commits landed mid-run and the chunk manifests would not have merged under one head; nothing it produced was kept.

## Diagnosis

All figures are from readout 10's final reports, which main reproduces run for run (100 of 100 rows checked). Wilson 95% intervals.

### Offers: Edge is half the coloured glass in both pools

Affinity-weighted card offers per run, from rewards, events and shops. R does not steer by the flame, so it shows the raw offer stream.

| Cell | Arm | Shatter | Lantern | Edge |
|---|---|---|---|---|
| V0 fresh | R | 4.59 (22.9%) | 6.17 (30.8%) | 9.26 (46.3%) |
| V0 fresh | A_lit | 6.59 (23.2%) | 8.64 (30.5%) | 13.11 (46.3%) |
| V0 full | R | 5.64 (17.9%) | 11.01 (34.9%) | 14.89 (47.2%) |
| V0 full | A_lit | 7.12 (17.9%) | 13.50 (33.9%) | 19.19 (48.2%) |

In content, the coloured mass offerable to the Duskblade is Shatter 3.0, Lantern 4.0 and Edge 6.5 in the fresh pool, and Shatter 5.5, Lantern 10.5 and Edge 13.0 in the full pool. Shatter is the thin way: 5.5 at full unlock against the lock's "roughly ten coloured cards" (§6.2), and its share falls from 23% to 18% when the pool fills.

### What an uncommitted player keeps

Held at run end over offered, for the commit-blind arm A at V0 full:

| Way | Cards kept by A (held / offered) |
|---|---|
| Edge | Overglow 93%, Shatterhymn 92%, Dim the Glass 77%, Inner Blaze 59%, Faultline 48%, Totality 35%, Rising Litany 28% |
| Shatter | Quakeblow 87%, Bellstrike 113% (shop duplicates), Ringing Blow 61%, Annealing Rite 54%, Spall 37% |
| Lantern | Struck Match 75%, Tinder 70%, Tithe of Panes 36%, Eat the Flame 26%, Pyreheart 18%, Emberdance 3%, Pyre Tithe 1%, Novaflare 0% |

A_lit's coloured mass at run end is Shatter 4.22, Lantern 5.03 and Edge 11.35 in the full pool, against 4.86, 4.88 and 8.52 in the fresh pool. The full pool adds about 2.8 Edge to its deck, mostly Overglow (0.88 copies a run), Faultline, Totality, Tremor and Rising Litany. It adds about 1.3 Shatter and almost no Lantern.

### A_lit's runs by the way they end in (G6's descriptor)

| Cell | End dominant | Runs | Win rate (95%) |
|---|---|---:|---|
| V0 fresh | Shatter | 192 | 34.4% (28.0–41.3) |
| V0 fresh | Lantern | 243 | 35.4% (29.6–41.6) |
| V0 fresh | Edge | 565 | 25.8% (22.4–29.6) |
| V0 full | Shatter | 128 | 47.7% (39.2–56.3) |
| V0 full | Lantern | 179 | 38.5% (31.7–45.8) |
| V0 full | Edge | 693 | 46.6% (42.9–50.3) |
| V5 full | Shatter | 333 | 11.7% (8.7–15.6) |
| V5 full | Lantern | 377 | 10.6% (7.9–14.1) |
| V5 full | Edge | 1,290 | 16.1% (14.2–18.2) |

In the fresh pool, Edge's frequency is offset by a lower win rate; in the full pool it is not. Of A_lit's 323 Edge wins at V0 full, 146 come from decks that end at Kindling or Soot with an Edge plurality. Nearly half of Edge's lead is drift, not a lit flame.

### Where A_lit's lantern first lights

| Cell | First fight begun Steady or True | Runs | Win rate (95%) |
|---|---|---:|---|
| V0 full | Shatter | 60 | 73.3% (61.0–82.9) |
| V0 full | Lantern | 92 | 51.1% (41.0–61.1) |
| V0 full | Edge | 360 | 50.8% (45.7–56.0) |
| V0 full | never | 488 | 36.7% (32.5–41.0) |
| V5 full | Shatter | 107 | 27.1% (19.6–36.2) |
| V5 full | Lantern | 133 | 21.8% (15.6–29.6) |
| V5 full | Edge | 579 | 17.3% (14.4–20.6) |
| V5 full | never | 1,181 | 10.9% (9.3–12.8) |

When A_lit lights, it lights Edge 70% of the time. Lighting Shatter is its best outcome and its rarest, though the 73% figure is band-dependent: the development seeds read 48% (n = 52).

### Committed reach in the full pool

At V0 full, the share of runs whose own way is Steady or True at the end of Act 1, and True at the end of Act 2, is Shatter 46.3% and 8.7%, Lantern 65.9% and 26.5%, and Edge 86.8% and 40.4%. At the end of Act 1, committed Shatter's mean mass is 7.18 at a 0.592 own share, one pick short of Steady. The Lantern's is 9.06 at 0.697 and Edge's 10.34 at 0.742. Shatter's reach is its scarcity.

### The diagnosis in five lines

1. Edge is 46–48% of the coloured glass every arm is offered, in both pools; that is not what changes between them.
2. What changes is what an uncommitted player keeps. The full pool's Edge glass includes stat powers any deck takes (Overglow 93%, Inner Blaze 59%), while its Lantern glass is left on the table (Pyre Tithe 1%, Novaflare 0%) and Shatter gains only 2.5 coloured mass.
3. So A_lit ends Edge-dominant in 69% of full-pool runs (57% fresh), and those runs now win as often as Shatter's (46.6% against 47.7%), where in the fresh pool they won 9 pp less. G6 follows.
4. Lighting Shatter is the adaptive deck's best outcome and its rarest (6% of runs): Shatter has 5.5 coloured mass on offer against Edge's 13.
5. G5 full fails on the same scarcity: committed Shatter ends Act 1 one pick short of Steady.

A static screen re-read A_lit's end decks with a single card's affinity changed, ignoring any change in behaviour. No single card moves G6 at V0 full below 59% (Dim the Glass cleared: 59.2%; every other card: 64% or more). The lever has to be a class of glass, not a card.

## The candidates

Each candidate is one lever, written as a scratch catalogue whose diff against main is the lever alone.

| | Lever | From the diagnosis | Static G6, V0 / V5 full |
|---|---|---|---|
| C1 | Inner Blaze, Overglow and Rising Litany become clear glass | line 2: Edge's stat powers are kept by every deck and colour it blood-moon. Every other stat power in the Duskblade's offers (Glazier's Poise, Vitrify, Hearthglow, Anneal, Night Sight) is already clear; Pyreheart, which pays the Lantern's own verb, stays coloured | 63.6% / 57.1% |
| C2 | Shatter 1.0 on Fan of Glass, Hailglass, Shardstorm (each chips every enemy it hits) and Quarry Maul (chips when upgraded) | lines 4–5: Shatter is the thin way; this brings it to 9.5 coloured mass in the full pool, the lock's "roughly ten" | 69.5% / 69.7% |
| C3 | Dim the Glass and Splinter Cut at 0.5 Edge | line 3: Edge's two commons carry the early drift (A_lit holds 2.3 Dim the Glass a run) | 62.3% / 63.4% |

### The screen: development seeds 12000–12999, the full-pool cells

Each arm's win rate, with its paired change against main on the same seeds (pp, exact p).

| Cell | Candidate | C_shatter | C_lantern | C_edge | A_lit | G2 | G3 (A_lit − best) | G6 S / L / E of A_lit's wins |
|---|---|---|---|---|---|---|---|---|
| V0 full | main | 48.8% | 43.4% | 33.0% | 44.3% | 15.8 pp FAIL | −4.5 pp FAIL / UNDECIDED | 11.3 / 23.5 / 65.2% of 443, FAIL / FAIL |
| V0 full | C1 | 50.9% (+2.1, p = 0.18) | 47.2% (+3.8, p = 0.01) | 35.4% (+2.4, p = 0.19) | 43.0% (−1.3, p = 0.39) | 15.5 pp FAIL | −7.9 pp FAIL / FAIL | 16.7 / 31.4 / 51.9% of 430, **PASS / PASS** |
| V0 full | C2 | 41.5% (−7.3, p < 0.01) | 48.8% (+5.4, p < 0.01) | 34.6% (+1.6, p = 0.24) | 44.0% (−0.3, p = 0.85) | 14.2 pp FAIL | −4.8 pp FAIL / UNDECIDED | 17.3 / 20.5 / 62.3% of 440, FAIL / UNDECIDED |
| V0 full | C3 | 48.8% (+0.0, p = 1.00) | 43.9% (+0.5, p = 0.40) | 32.8% (−0.2, p = 0.94) | 40.4% (−3.9, p = 0.01) | 16.0 pp FAIL | −8.4 pp FAIL / FAIL | 16.8 / 33.7 / 49.5% of 404, **PASS / PASS** |
| V5 full | main | 15.9% | 12.3% | 9.9% | 16.4% | 6.0 pp PASS | +0.5 pp PASS / PASS | 16.5 / 18.3 / 65.2% of 164, FAIL / UNDECIDED |
| V5 full | C1 | 16.1% (+0.2, p = 0.93) | 15.2% (+2.9, p = 0.01) | 12.8% (+2.9, p = 0.02) | 14.9% (−1.5, p = 0.18) | 3.3 pp PASS | −1.2 pp PASS / UNDECIDED | 25.5 / 28.9 / 45.6% of 149, **PASS / PASS** |
| V5 full | C2 | 13.0% (−2.9, p = 0.04) | 14.0% (+1.7, p = 0.06) | 10.6% (+0.7, p = 0.37) | 17.1% (+0.7, p = 0.40) | 3.4 pp PASS | +3.1 pp PASS / PASS | 19.3 / 17.5 / 63.2% of 171, FAIL / UNDECIDED |
| V5 full | C3 | 16.1% (+0.2, p = 0.82) | 13.0% (+0.7, p = 0.02) | 9.5% (−0.4, p = 0.68) | 14.2% (−2.2, p < 0.01) | 6.6 pp PASS | −1.9 pp PASS / UNDECIDED | 26.8 / 21.8 / 51.4% of 142, **PASS / PASS** |

Committed reach on the screen: Steady by the end of Act 1 and True by the end of Act 2, Shatter / Lantern / Edge.

| Cell | Candidate | Steady, Act 1 | True, Act 2 |
|---|---|---|---|
| V0 full | main | 49.6 / 64.2 / 87.6% | 7.9 / 27.2 / 38.1% |
| V0 full | C1 | 55.4 / 67.0 / 84.5% | 11.1 / 31.0 / 27.6% |
| V0 full | C2 | **79.6** / 64.8 / 88.4% | **36.3** / 24.8 / 36.3% |
| V0 full | C3 | 51.3 / 64.8 / 81.2% | 8.2 / 29.1 / 27.1% |
| V5 full | main | 29.0 / 34.5 / 52.6% | 2.5 / 8.5 / 9.5% |
| V5 full | C1 | 33.9 / 37.7 / 50.0% | 4.1 / 11.3 / 7.2% |
| V5 full | C2 | 47.0 / 35.3 / 53.5% | 10.6 / 8.5 / 8.8% |
| V5 full | C3 | 29.5 / 35.4 / 47.3% | 2.7 / 9.5 / 6.6% |

**The choice.**

- **C2 is out.** It fails G6 in both cells. It is also the screen's clearest lesson for G5: Shatter's reach is its glass count. With four more cards, committed Shatter reaches Steady by the end of Act 1 in 80% of runs and True by the end of Act 2 in 36%. But it then values those four ordinary attacks at ×3 and wins 7.3 pp less.
- **C1 against C3.** Both pass G6 in both cells, on point and interval. The difference is in G3: C3 costs A_lit 3.9 pp at V0 full (p = 0.01) and 2.2 pp at V5 full (p < 0.01), so it makes the skilled player worse. C1 leaves A_lit within noise, and its G3 damage comes from the committed Lantern rising (+3.8 and +2.9 pp, p ≤ 0.01). On the screen, C1's G3 is −7.9 / −1.2 pp against C3's −8.4 / −1.9. G2 is a wash at V0 (15.5 against 16.0 pp, main 15.8) and favours C1 at V5 (3.3 against 6.6 pp). **C1 goes to the final table.**
- **Noise.** The same main content reads G2 15.8 pp and G3 −4.5 pp at V0 full on the development seeds, and 10.0 pp and −2.0 pp on readout 10's seeds. Point verdicts on G2 and G3 at V0 full are within band-to-band noise at 1,000 seeds.

## The cell table

### Win rates, search player

Each figure has its Wilson 95% interval, with the paired change against readout 10 on the same seeds in brackets.

| Cell | C_shatter | C_lantern | C_edge | A | **A_lit** | R |
|---|---|---|---|---|---|---|
| V0 fresh (N = 1,000) | 21.3% (18.9–23.9) [+0.5, p = 0.77] | 34.5% (31.6–37.5) [**+5.7, p < 0.001**] | 22.3% (19.8–25.0) [+1.2, p = 0.43] | 23.7% (21.2–26.4) [+0.5, p = 0.70] | **32.4% (29.6–35.4)** [+2.6, p = 0.05] | 6.9% (5.5–8.6) [+0.0] |
| V0 full (N = 1,000) | 48.9% (45.8–52.0) [+1.6, p = 0.37] | 47.8% (44.7–50.9) [**+3.0, p = 0.05**] | 36.2% (33.3–39.2) [−1.1, p = 0.56] | 38.7% (35.7–41.8) [−1.3, p = 0.36] | **45.6% (42.5–48.7)** [+0.3, p = 0.89] | 17.9% (15.6–20.4) [−0.5, p = 0.64] |
| V5 fresh (N = 2,000) | 2.1% (1.5–2.8) [+0.6, p = 0.14] | 6.5% (5.5–7.7) [**+2.4, p < 0.001**] | 1.9% (1.4–2.6) [−0.7, p = 0.10] | 1.8% (1.3–2.5) [+0.2, p = 0.38] | **3.9% (3.1–4.8)** [+0.4, p = 0.39] | 0.4% (0.2–0.7) [−0.1] |
| V5 full (N = 2,000) | 18.6% (17.0–20.4) [+0.9, p = 0.31] | 13.6% (12.1–15.1) [**+2.2, p = 0.002**] | 11.8% (10.5–13.3) [**+2.1, p = 0.01**] | 11.6% (10.3–13.1) [−0.9, p = 0.17] | **13.8% (12.4–15.4)** [−0.6, p = 0.51] | 4.3% (3.5–5.3) [−0.2, p = 0.53] |

### Gates before (readout 10) and after

Point / 95% interval.

| Cell | Gate | Readout 10 | Readout 11 |
|---|---|---|---|
| V0 fresh | G1 | FAIL / FAIL (Shatter 20.8%) | FAIL / FAIL (Shatter 21.3%) |
| V0 fresh | G2 | PASS / UNDECIDED (+8.0 pp, L − S) | **FAIL** / UNDECIDED (+13.2 pp, L − S; +9.3 to +17.1) |
| V0 fresh | G3 | PASS / PASS (A_lit − C_lantern +1.0 pp) | PASS / **UNDECIDED** (−2.1 pp; −6.2 to +2.0) |
| V0 fresh | G4 | FAIL / FAIL (−13.9 pp) | FAIL / FAIL (−14.4 pp) |
| V0 fresh | G5 | PASS / PASS (Steady min Lantern 43.3%) | PASS / PASS (Steady min Lantern 48.4%, 45.3–51.5) |
| V0 fresh | G6 | PASS / PASS (Edge 49.0% of 298) | PASS / PASS (Edge 38.0% of 324, 32.8–43.4; Shatter 28.1%, Lantern 34.0%) |
| V0 fresh | G7 | PASS | PASS |
| V0 full | G1 | FAIL / FAIL (Edge 37.3%) | FAIL / FAIL (Edge 36.2%) |
| V0 full | G2 | PASS / UNDECIDED (+10.0 pp, S − E) | **FAIL** / UNDECIDED (+12.7 pp, S − E; +8.4 to +17.0) |
| V0 full | G3 | PASS / UNDECIDED (−2.0 pp) | **FAIL** / UNDECIDED (A_lit − C_shatter −3.3 pp; −7.7 to +1.1) |
| V0 full | G4 | FAIL / FAIL (−18.9 pp) | FAIL / FAIL (−18.3 pp) |
| V0 full | G5 | FAIL / FAIL (Steady min Shatter 46.3%, True min 8.7%) | FAIL / FAIL (Steady min Shatter 51.1%, True min Shatter 12.5%) |
| V0 full | G6 | FAIL / FAIL (Edge 71.3% of 453) | **PASS / UNDECIDED** (Edge 58.6% of 456, 54.0–63.0; Shatter 18.6%, Lantern 22.8%) |
| V0 full | G7 | PASS | PASS |
| V5 fresh | G2 | PASS / PASS (+2.6 pp) | PASS / PASS (+4.6 pp, L − E; +3.4 to +5.9) |
| V5 fresh | G3 | PASS / PASS (−0.6 pp) | PASS / **UNDECIDED** (−2.6 pp; −4.0 to −1.3) |
| V5 fresh | G4 | FAIL / FAIL | FAIL / FAIL (−1.6 pp) |
| V5 fresh | G6 | PASS / PASS (Lantern and Edge 40.6% of 69) | PASS / **UNDECIDED** (Lantern 50.6% of 77, 39.7–61.5; Shatter 26.0%, Edge 23.4%) |
| V5 fresh | G7 | PASS | PASS |
| V5 full | G1 | FAIL / FAIL (Edge 9.7%) | FAIL / FAIL (Edge 11.8%) |
| V5 full | G2 | PASS / UNDECIDED (+8.1 pp) | PASS / **PASS** (+6.9 pp, S − E; +4.6 to +9.1) |
| V5 full | G3 | FAIL / UNDECIDED (−3.4 pp) | FAIL / UNDECIDED (A_lit − C_shatter −4.9 pp; −7.1 to −2.6) |
| V5 full | G4 | FAIL / FAIL (−5.2 pp) | FAIL / FAIL (−7.5 pp) |
| V5 full | G5 | FAIL / FAIL (Steady min Shatter 28.6%, True min 1.6%) | FAIL / FAIL (Steady min Shatter 34.5%, True min Shatter 3.1%) |
| V5 full | G6 | FAIL / FAIL (Edge 72.5% of 287) | **PASS / PASS** (Edge 48.9% of 276, 43.1–54.8; Shatter 26.1%, Lantern 25.0%) |
| V5 full | G7 | PASS | PASS |

G7 here covers zero stalls and zero errors in all 36,012 runs and A's three-seed replay, identical in every cell. The save lineage and internal ids are untouched: no save field, id or RNG draw changed, and affinity is derived content that is never saved.

The grader prints V5 fresh's G3 point as −2.6 pp from the rates' exact fractions and its interval centre as −2.7 pp. Both are 77 − 130 wins of 2,000.

### G3 and G6 on A, the floor

| Cell | G3 floor (A − best) | G6 floor (A's wins) |
|---|---|---|
| V0 fresh | FAIL / FAIL (−10.8 pp) | PASS / PASS (Shatter 35.9% of 237) |
| V0 full | FAIL / FAIL (−10.2 pp) | FAIL / UNDECIDED (Edge 63.6% of 387; was 79.0%) |
| V5 fresh | FAIL / FAIL (−4.7 pp) | PASS / PASS (Shatter 40.5% of 37) |
| V5 full | FAIL / FAIL (−7.0 pp) | PASS / UNDECIDED (Edge 53.4% of 232; was 82.4%) |

### Why G6 moved

A_lit's runs by the way they end in:

| Cell | | Shatter runs (win rate) | Lantern runs (win rate) | Edge runs (win rate) |
|---|---|---|---|---|
| V0 full | readout 10 | 128 (47.7%) | 179 (38.5%) | 693 (46.6%) |
| V0 full | readout 11 | 178 (47.8%) | 246 (42.3%) | 576 (46.4%) |
| V5 full | readout 10 | 333 (11.7%) | 377 (10.6%) | 1,290 (16.1%) |
| V5 full | readout 11 | 534 (13.5%) | 530 (13.0%) | 936 (14.4%) |

Its first lit colour at V0 full is now Edge in 282 runs (was 360), the Lantern in 107 (was 92) and Shatter in 70 (was 60). The share of its fights fought in blood-moon falls from 30.9% to 23.8%, and in any colour from 43.1% to 38.8%: the arm lights a little less often, and much less of what it lights is Edge.

### Row B, the bot round (V0, search player)

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 (readout 10) |
|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 21.3% (18.9–23.9) | PASS | 71.7% (71.0–72.3) | 1.2% (1.0–1.4) | **PASS** (UNDECIDED) |
| V0 fresh | C_lantern | 34.5% (31.6–37.5) | PASS | 61.7% (61.0–62.4) | 1.0% (0.9–1.2) | UNDECIDED (UNDECIDED) |
| V0 fresh | C_edge | 22.3% (19.8–25.0) | PASS | 69.0% (68.4–69.7) | 1.9% (1.7–2.1) | PASS (PASS) |
| V0 fresh | A_lit | 32.4% (29.6–35.4) | PASS | 58.7% (58.0–59.4) | 1.4% (1.2–1.6) | **FAIL** (UNDECIDED) |
| V0 full | C_shatter | 48.9% (45.8–52.0) | PASS | 73.2% (72.6–73.7) | 1.0% (0.9–1.1) | UNDECIDED (UNDECIDED) |
| V0 full | C_lantern | 47.8% (44.7–50.9) | PASS | 72.0% (71.4–72.6) | 1.0% (0.9–1.1) | UNDECIDED (UNDECIDED) |
| V0 full | C_edge | 36.2% (33.3–39.2) | PASS | 82.1% (81.6–82.6) | 1.5% (1.4–1.7) | PASS (PASS) |
| V0 full | A_lit | 45.6% (42.5–48.7) | PASS | 62.6% (61.9–63.2) | 1.2% (1.0–1.4) | PASS (PASS) |

The committed arms' UNDECIDED rows are close calls whose interval reaches below 1%, as in readouts 9 and 10. A_lit's expression is still diluted by its unlit fights, which are now a little more numerous in the fresh pool.

## Decision

**Ship C1.** It is the only candidate that brings G6 to PASS in both full cells without making the skilled player worse. The move is far outside the interval noise: at V0 full, Edge's share falls from 67.0–75.3% to 54.0–63.0%; at V5 full, from 67.0–77.3% to 43.1–54.8%. It removes two decided FAILs, and every verdict it costs is a point verdict whose interval was or remains UNDECIDED:

- G2 at V0 fresh: a real cost. The committed Lantern gains 5.7 pp, because a Lantern deck may now hold Inner Blaze and Overglow without dimming its flame.
- G2 at V0 full and G3 at V0 full: within noise. No arm at either end moved significantly, and the development seeds read the same cell 15.8 pp and −4.5 pp before any change.
- G3 in the fresh cells: these lose their interval PASS but keep their point PASS.
- A_lit's own B2 row at V0 fresh: moves from UNDECIDED to FAIL, by 0.9 pp of expression.

The design reading supports the lever. Clear glass is fuel, never noise (§3), and every other stat power in the Duskblade's offers was already clear. A blood-moon flame should come from Cracked and Dimmed glass and the precise cut, not from an energy power that every deck takes. Edge keeps its own verbs: Cleft and Faultline still pay in Fervor and Cracked, and the Eclipse crown, Totality and the four blood-moon riders are unchanged. Committed Edge does not lose: −1.1 pp at V0 full (p = 0.56) and +2.1 pp at V5 full (p = 0.01).

**What this lane did not reach.**

- G3 at V5 full is not back in range. It reads −4.9 pp; neither A_lit (−0.6 pp, p = 0.51) nor committed Shatter (+0.9 pp, p = 0.31) moved significantly, and the development seeds read the same cell at +0.5 pp on main. At 2,000 seeds the cell sits within about ±3 pp of the threshold across seed bands.
- G5 full improves for Shatter (+4.8 pp Steady, +3.8 pp True at V0) and still fails.
- G1 and G4 are unchanged in kind.

## Tests and pins

- **Fixtures** (`33b7b78d`). `test_flame_like`, `test_flame_recognition`, `test_balance_arms` and `test_stagecraft` built Edge decks with Inner Blaze and Overglow. They now use Cleft and Totality (both Edge 1.0), so every deck reads the same dominant way, tier and fringe as before. No assertion or expected value changed.
- **Pins** (`40b21611`). `test_balance_catalogue` re-pins the live file SHA (`5a20ef2a…`) and the semantic SHA (`685e2cdc…`); both move only because three affinity lines left. `test_balance_sim` re-pins seed 1000 (`bb86394a…`). On main, that run's deck held two Overglows, Rising Litany and Inner Blaze, and fought six of its eight fights Steady in blood-moon. It now stays Kindling and dies in fight 6. A Kindling run meets no lantern quality, so its knobs-at-zero and knobs-at-one runs would be identical and the unlit check would be vacuous. That check now reads seed 1001 (`UNLIT_SEED`), which fights Steady and Soot; its zero-knob digest is `5960861…`, and its knobs-at-one run differs from it.
- **Unchanged.** `test_balance_ways.py` and the #490 tier-1 registry are unchanged and pass. The registry replays the frozen H39 catalogue and the locale snapshots in `docs/balance/data/`, which were not touched. No `port_fixtures/` golden moved.

## What the next readout should ask

1. **Shatter's glass count.** C2 showed that committed Shatter's reach (G5) is its scarcity: four more Shatter cards took Steady by the end of Act 1 from 50% to 80%. The four used were the wrong cards, ordinary attacks the committed arm then over-valued. The question is whether one or two Shatter cards worth taking, in the full pool, can carry G5 full without costing committed Shatter its wins. This is content (cards, copy, art), not affinity.
2. **The Lantern's full-pool glass is left on the table.** A commit-blind player keeps Pyre Tithe, Novaflare and Emberdance 0–3% of the times they are offered. With C1, the committed Lantern is now the fresh pool's best way by 12 pp. Whether the Lantern's rare glass needs to be worth taking to an uncommitted deck, or whether the pilot under-values Embers, is the open question behind G2 fresh and G3 fresh.
3. **Seeds for the knife-edge cells.** G2 at V0 full and G3 at V0 full and V5 full move by 3–6 pp between seed bands on the same content. Deciding them needs about 4,000 seeds per arm or a paired grader that reads the arms' difference on common seeds, rather than Newcombe's independent interval. That is an instrument question for the lock before the exam.

## Appendix: the scripts

All scripts are in the lane's private scratch folder, as in readouts 9 and 10.

| Script | What it does |
|---|---|
| `chunked.py` | Readout 9's appendix B runner, pointed at this worktree. |
| `diag.py` | Offers by way from the `<card>Offered` counters; the adaptive arms by end-dominant and first-lit way; committed reach by act. |
| `take.py` | Held at end over offered, per card and arm. |
| `static_cf.py` | G6 re-read from end decks with changed affinity. |
| `pools.py` | Coloured mass per rarity and pool state, from content. |
| `make_candidates.py` | Writes the three candidate catalogues as text edits to the affinity block. |
| `screen.sh`, `screen_grade.py` | Run and grade the screen. |
| `paired.py` | Paired changes and byte-identical row counts against readout 10. |
| `analyse.py`, `rowb.py` | Readout 10's colour-share and row B scripts, with A_lit's row added to row B. |
