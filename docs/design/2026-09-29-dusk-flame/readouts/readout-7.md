# Readout 7: each way's own wall

> **Research readout (AI-SDLC discovery), promoted in one PR.** Every candidate ran on a scratch copy of the catalogue passed with `--content`, kept in a private scratch folder; no candidate touched `content/full-content.json` until the winners were chosen. The frozen data under `docs/balance/data` is untouched. The PR that carries this readout ships the two winners (Spall, and Hearthfall at 12 damage) and nothing else: `content/full-content.json` is now byte for byte the "S2 + L4" catalogue of [the Lantern's third candidate](#the-lanterns-third-candidate-l4) (SHA-256 `b791034cf085be0df5a3afc57d68aa63c365dd1bfd7d117fca705f45aa75d19a`, on the merge base below). The "S2 + L3" catalogue measured first was `fa2f5a45…` on the experiments' base and `a605d3be…` on the merge base. No enemy scalar, Soot knob, lantern knob, splash policy or gate figure moved.
>
> **Two bases.** The experiments ran on `main` at `e0c77bec`. While the PR was prepared, `main` gained #599, which takes the Ashwarden's potion, boon, Art and deed out of the Duskblade's offers and so changes its full pool. Every candidate was run again on that merge base (`40c4708f`; `main` has since gained only #601, a documentation change, and #603, the iOS build pins), where the "S2 + L3" file is `a605d3be162f99fe9e837d748519e032128b92634496a63dc294c13ef36e1e6b`, byte for byte what the catalogue script writes from that base's file, and the shipped "S2 + L4" file is that one with Hearthfall's damage turned from 16 to 12. All three decisions hold there; [the re-check](#re-check-on-the-merge-base-after-599) gives those numbers, which are the ones this PR merges into.

Readout 6 found that no global lever reaches G1 or G4 and that the block is each way's own wall: Lantern decks die in Act 1, Edge decks in Act 2, and Shatter decks idle at Kindling for want of glass. The owner ruled on 30 September that the game may be hard, that calibration by global knobs is over and that G1 and G4 are instrument readings, not GO blockers. This readout is the one lane left: for each way, name the wall in content terms, try at most three content changes that keep the way's identity, and ship what lifts that way or drop it.

## The answer in brief

- **Shatter: shipped, Spall (S2).** The wall is supply: no pool held a Shatter common, so a run was offered 12-21% Shatter glass and a committed Shatter deck read Steady by the end of Act 1 in 28-34% of runs at V0. One common of its own (Spall 璃屑: 1 Energy, deal 5, chip 1 extra Facet) lifts committed Shatter by 7.5 pp at V0 full (40.5% to 48.0%) and 12.5 pp at V0 fresh, doubles its Steady by the end of Act 1 (28.0% to 57.0% at V0 full, 34.0% to 55.0% at V0 fresh) and does not move G6. The 6-damage version (S1) did the same, so the lift is supply, not power; the weaker card ships.
- **Lantern: shipped, Hearthfall at 12 damage (L4).** The wall is the payoff: in a fresh pool the Lantern's glass draws, kindles and makes Embers, and the only thing Embers bought was the Flare (9 to every foe, once a turn). A common attack that adds damage (L1) was held 2.1-2.4 times a deck and won nothing. A common that turns Embers into one blow did: at 1 Energy (L2) +3.5 pp at V0 full, short of the rule; at 0 Energy (L3, Hearthfall 爐火墜: spend 3 Embers, deal 16) +36.5 pp at V0 full (21.5% to 58.0%) and +41.0 pp at V0 fresh. It overshot: the Lantern went from the worst committed way to the best, past the adaptive arm. The third candidate (L4) turns one number, Hearthfall's damage 16 to 12 (upgraded 21 to 16), still 0 Energy: on the merge base, with Spall, the committed Lantern wins 47.5% at V0 full, level with Shatter's 47.5% and under the adaptive arm's 55.0%, a lift of 20.0 pp on main. L4 ships.
- **Edge: dropped.** The wall is attrition: committed Edge decks carry the least Ward (25 per deck at V0 full against 41-53 for the other arms), enter the Act-2 boss lower and lose it in 6 turns, where the adaptive arm's lost fights last 8; 99 of Edge's 162 deaths at V0 full are in Act 2. Three candidates (Eclipse Step's Ward, Eclipse Step at common, and that plus Dim the Glass at uncommon and a harder-hitting Totality) lifted committed Edge by 0.5, 1.0 and 4.0 pp at V0 full, and every one raised the leading way's share of the adaptive arm's wins by 2.6-7.7 pp: an Edge card strong enough to matter is taken by the adaptive arm's Edge decks too. None meets the stop rule, so nothing for Edge ships. On the merge base E2 and E3 lift Edge by 6.5 and 7.5 pp at V0 full, over the line, but raise the leading way's share of A's wins by 3.9 and 4.5 pp, so the verdict holds.
- **What the two cards cost together** (Spall and Hearthfall at 12, on the merge base). Seeds 13000-13199 at V0 full: Shatter 34.0% to 47.5%, Lantern 27.5% to 47.5%, Edge 21.0% to 21.5%, A 56.0% to 55.0%, R 17.5% to 22.0%. Over 300 paired seeds: Shatter 35.0% to 48.3%, Lantern 26.7% to 52.0%, Edge 22.3% to 21.0% (49 wins gained against 53 lost, p = 0.77), A 52.3% to 52.3%, R 17.7% to 24.3% (51 against 31, p = 0.04). G2 still widens, since Edge stays where it was while the other two rise (13.0 to 26.0 pp at V0 full; it passes in one cell instead of three, and fails only on Edge: Shatter and the Lantern are level). G3 at V0 full passes (+7.5 pp, where main fails at +22.0 pp). G4 moves the wrong way. G5 and G6 improve (both pass at V0 fresh, where main fails both). On the sweep band alone the Lantern still leads at V0 full (61% against Shatter's 50% and A's 47%). On the experiments' base the first pair (with Hearthfall at 16) also cost Edge 6.7 pp at V0 full (34 against 54, p = 0.04), because two non-Edge commons thin an offer that was 56-58% Edge; on the merge base that cost is not measurable.
- **Instrument.** 16 cell tables on the experiments' base (54,192 run rows, 408 s of wall time) and 12 on the merge base (347 s with the post-rebase re-runs), plus two for L4 (44 s). G7 holds in every table (0 stalls, 0 errors, arm A's replay 3 of 3 identical) but one cell: E2 on the merge base, V0 full, where one committed Lantern run (seed 13119) reached the 40-turn guard; E2 does not ship. The shipped content, re-run at the branch head, reproduces its scratch reports run for run on both seed bands (48 reports, 6,024 run rows).

The reading and what the owner may want to turn next close the readout.

## The walls, named

At `main` (the E1b lantern, #593), seeds 13000-13199, before any candidate:

| Way | Where committed runs end at V0 full (Act 1 / 2 / 3 deaths, wins of 200) | At V0 fresh | The wall in content terms |
|---|---|---|---|
| Shatter | 38 / 43 / 38, 81 | 69 / 66 / 47, 18 | **Supply.** Its glass in a fresh pool is one uncommon (Ringing Blow) and one rare (Bellstrike); no pool holds a Shatter common, and 60% of a normal reward's draws are commons. A run is offered 4.4-4.6 Shatter cards against 14.3-21.2 Edge (arm A, V0). Committed Shatter reads Steady by the end of Act 1 in 34.0% (fresh) and 28.0% (full) of runs, so its lantern and its crown rarely light. |
| Lantern | 56 / 62 / 39, 43 | 100 / 55 / 33, 12 | **Payoff.** 96 of its 100 Act-1 deaths at V0 fresh are the Rootheart. Its fresh-pool glass (Tinder, Struck Match, Gutter and Cathedral Glass at half weight) draws, kindles and makes Embers; the Embers buy only the Flare, 9 to every foe once a turn. Its decks hold the fewest attacks of any arm (10.7-10.9 against 12.4-16.8). |
| Edge | 20 / 99 / 43, 38 | 41 / 102 / 36, 21 | **Attrition.** Its glass is offence and utility; its only Ward is Eclipse Step, offered 1.2-1.8 times a run. Committed Edge decks hold 25 Ward at V0 full (Shatter 41, A 45, Lantern 53), end Act 1 on less HP when they later die to the Leviathan (31 against 37 for those that beat it), and lose that fight in 6.0 turns, where A's lost fights last 8.0. 56 of its 99 Act-2 deaths are the Leviathan and 37 are Act-2 normal fights (A: 15). |

## How it was run

```sh
# Candidate catalogues from the shipped file (appendix A), into the private scratch folder:
python3 make_candidates.py content/full-content.json <scratch>/cat s1 l1 e1   # round 1
python3 make_candidates.py content/full-content.json <scratch>/cat s2 l2 e2   # round 2
python3 make_candidates.py content/full-content.json <scratch>/cat l3 e3      # round 3
python3 make_candidates.py content/full-content.json <scratch>/cat s2+l3      # the winners together
# Each candidate, and the control (no --content), on the standard seeds:
python3 -B tools/balance_ways.py --seeds 13000-13199 --jobs 9 --out-dir <a new, empty directory> [--content <catalogue>]
# Confirmation of the control, the two winners and the shipped pair on the sweep seeds:
python3 -B tools/balance_ways.py --seeds 13200-13299 --jobs 9 --out-dir <a new, empty directory> [--content <catalogue>]
```

Every Godot process ran with a temporary `override.cfg` in the worktree root (`config/use_custom_user_dir=true`, `config/custom_user_dir_name="glassvow-test-walls"`), removed before the commit.

- **Instrument, cells and seeds.** `tools/balance_ways.py` with `tools/balance_pilot.gd` (pilot `p8-d0-v2`, turn guard 40), unchanged. Duskblade at vows 0 and 5 with the shipping vow incentives, fresh and full pool; C_shatter, C_lantern and C_edge (committed), A (adaptive) and R (random build). Standard seeds 13000-13199 (200 paired) for every candidate against the control, as the brief asks; sweep seeds 13200-13299 (100 paired) to confirm the winners and the shipped pair. The acceptance seeds 3000-5199 were not touched; `--way-weights` was not used.
- **Heads.** The candidates ran at `e0c77bec` (main with #593). `main` then moved to `aba2cd1b` (#594, #596): presentation, docs and one presentation test, no change to `content/`, `domain/` or `tools/`. The shipped content, re-run on both bands at the branch's content head (`c170a5bc` on `aba2cd1b`, and again after the branch was rebased onto `ca9c0ae6`, #597, which moves a map registry and adds an export-path check), reproduces the scratch "S2 + L3" reports run for run each time (24 reports and 4,012 run rows on 13000-13199; 24 and 2,012 on 13200-13299). The branch was then rebased onto `40c4708f` (#599), which changes the Duskblade's full pool; every candidate was run again there, in [the re-check](#re-check-on-the-merge-base-after-599), from the rebased branch with each catalogue passed by `--content` (the reports name commit `480785de`, whose documentation commits were later reworded; its content, domain and tools are this PR's).
- **Controls.** The control on 13000-13199 reproduces readout 6's E1b confirmation rows (worst committed way 19.0% at V0 full, G3 +7.0 pp, G4 -2.5 pp); main is E1b.
- **Budget.** At most three candidates per way; nine were used (Shatter needed two; the Lantern's third, L4, came after the owner's review of L3), run in three rounds of one per way, each round designed from the last one's deaths and decks. No candidate was re-tuned after its run: the shipped cards are the measured ones.
- **The stop rule, as briefed.** A way ships a candidate only if it lifts that way's committed win rate by at least 5 pp in the full pool without lowering G6; otherwise the way is dropped. "The full pool" is read at V0, the cell whose G1 floor (50%) the gate grades; V5 full is reported beside it.
- **When G6 counts as lowered.** G6 is the dominant way of the adaptive arm's winning decks. It counts as lowered when, pooled over the four cells, the leading way's share of A's wins rises by more than 2.0 pp, or when a cell with at least 30 A wins turns its G6 verdict from PASS to FAIL. The rule was fixed after round 1 had run and before round 2; it is applied to all eight candidates, and on the experiments' base no verdict depends on the 2.0 pp line (the Edge candidates rise by 2.6, 7.7 and 5.1 pp; every other candidate falls or moves by 0.2 pp or less). On the merge base the verdicts for E2 and E3 rest on this rule, at 3.9 and 4.5 pp; any line under 3.9 pp gives the same verdict.
- **Cost.** 16 cell tables (11 on 13000-13199, 5 on 13200-13299), 54,192 run rows, 408 s of wall time; 28-32 s per table on 200 seeds.
- **Measures.** The grader's own: G1 the worst committed way's win rate; G3 A minus the best committed way (band -3 to +15 pp); G4 R minus the worst committed way (at most -25 pp, and R under 35% at V0 and 15% at V5); G5 the lowest Steady by the end of Act 1 among the committed ways (full pool also needs True by the end of Act 2 at 40%; no row reaches it); G6 A's wins by the dominant way of the deck at run end (no way over 60%, two at 20% or more). The verdict column is recomputed from the saved reports and agrees with the grader's printed verdicts in all 16 tables. A death's act is the act of the lost run's last fight. Paired tests count the seeds one configuration wins and the other loses, with the exact two-sided binomial p.

## The candidates

| Candidate | Way | What changes against `main` | Catalogue SHA-256 |
|---|---|---|---|
| S1 | Shatter | New common attack **Spall**: 1 Energy, deal 6, chip 1 extra Facet (upgraded 9). Shatter glass at 1.0; Duskblade only | `297e1350ed93dedeaa2187c06615a2dfcd34c6bf8de57f68c244e6a413783083` |
| S2 | Shatter | S1 with Spall at 5 damage (upgraded 8): is the lift supply or power? | `14ea52546e1744c600140f22dc781ed2c9c9cf8e0530c923ac708bd945d3e52f` |
| L1 | Lantern | New common attack **Cinder Cut**: 1 Energy, deal 6, gain 1 Ember (upgraded 9). Lantern glass at 1.0 | `bce971c8d98a806d0a222f370c4095601730858e36f09ab66cb5148ede21602e` |
| L2 | Lantern | New common attack **Hearthfall**: 1 Energy and 3 Embers, deal 16 (upgraded 21). Lantern glass at 1.0; the Ember price is Ember Eye's `emberCost` | `d0ff795288b7d27c00e792fd6ddd1af9a5f6f8db50f52d922c545a2d2bb278e9` |
| L3 | Lantern | L2 at 0 Energy: the Embers alone pay | `b92450b06eabe1e4126f72a6fc1b84e3141f43f3621585b238a661da4bd6bd8d` |
| E1 | Edge | Eclipse Step's Ward 5 to 8 (upgraded 8 to 11) | `298939a449fb4838a7a8958637972a8a0afe1d0560362a73f438e1301df41508` |
| E2 | Edge | Eclipse Step uncommon to common, Ward 5 to 7 (upgraded 8 to 10) | `f2a0860e47ad5598d2ea938ecefa9b23c41a0c389c0d5690bed343c4002bd24b` |
| E3 | Edge | E2, plus Dim the Glass common to uncommon (the way's common supply keeps its size) and Totality 14 to 20 damage (upgraded 18 to 26) | `c67aa28ed0f200e20bcae9e6c3e90e96b12a121a85d088b980a6eea5df09ca3f` |
| L4 | Lantern | L3 with Hearthfall at 12 damage (upgraded 16): measured with S2, on the merge base only (see [its section](#the-lanterns-third-candidate-l4)) | `b791034cf085be0df5a3afc57d68aa63c365dd1bfd7d117fca705f45aa75d19a` (S2 + L4, the shipped catalogue) |
| S2 + L3 | both | The two first winners together: the catalogue first proposed | `fa2f5a45fc2321437ec6afc9b5408e1840f6e1c12c1679fda33257e42823cb77` |

Every new card is Duskblade glass only: the Ashwarden excludes it through its own `excludes`, as it does the Edge way's. No candidate adds a rule, a status, a special or a knob, or steers an offer: new commons join the common pool, where the lock's like-calls-to-like weighting treats them as it treats every other card of their way.

## The stop rule, candidate by candidate

Seeds 13000-13199, each candidate against the control on the same seeds. "Own way" is the committed arm of the candidate's way.

| Candidate | Way | Own way, V0 full: wins (vs control) | Paired gained / lost, p | Own way, V5 full | Own way, V0 fresh | G6 pooled: leading way's share of A's wins (control 81.0% edge) | A cell (>= 30 A wins) turns G6 PASS to FAIL | Meets the stop rule |
|---|---|---:|---|---:|---:|---:|---|---|
| S1 Spall, 6 damage | Shatter | 94/200 47.0% (+6.5 pp) | 50 / 37, p = 0.20 | 16.5% (+2.5 pp) | 21.5% (+12.5 pp) | 81.1% edge (+0.2 pp) | none | yes |
| S2 Spall, 5 damage | Shatter | 96/200 48.0% (+7.5 pp) | 51 / 36, p = 0.13 | 17.0% (+3.0 pp) | 21.5% (+12.5 pp) | 80.5% edge (-0.5 pp) | none | yes |
| L1 Cinder Cut | Lantern | 42/200 21.0% (-0.5 pp) | 29 / 30, p = 1.00 | 7.0% (+2.5 pp) | 5.0% (-1.0 pp) | 77.5% edge (-3.4 pp) | none | no |
| L2 Hearthfall, 1 Energy | Lantern | 50/200 25.0% (+3.5 pp) | 35 / 28, p = 0.45 | 6.5% (+2.0 pp) | 11.0% (+5.0 pp) | 66.8% edge (-14.1 pp) | none | no |
| L3 Hearthfall, 0 Energy | Lantern | 116/200 58.0% (+36.5 pp) | 85 / 12, p = 0.00 | 20.0% (+15.5 pp) | 47.0% (+41.0 pp) | 67.5% edge (-13.5 pp) | none | yes |
| E1 Eclipse Step Ward 8 | Edge | 39/200 19.5% (+0.5 pp) | 5 / 4, p = 1.00 | 3.0% (-0.5 pp) | 12.5% (+2.0 pp) | 83.6% edge (+2.6 pp) | none | no |
| E2 Eclipse Step common, Ward 7 | Edge | 40/200 20.0% (+1.0 pp) | 34 / 32, p = 0.90 | 1.5% (-2.0 pp) | 9.5% (-1.0 pp) | 88.6% edge (+7.7 pp) | none | no |
| E3 E2 + Dim the Glass uncommon + Totality 20 | Edge | 46/200 23.0% (+4.0 pp) | 32 / 24, p = 0.35 | 7.0% (+3.5 pp) | 15.5% (+5.0 pp) | 86.0% edge (+5.1 pp) | none | no |

**What the rounds showed.**

- **Shatter.** S1 answered the question at once, and S2 checked it: the same lift at 5 damage as at 6 (43 wins against 43 at V0 fresh, 96 against 94 at V0 full), so it comes from supply (the flame lit, its crown and like-calls-to-like reached) rather than from a better card. In the shipped catalogue committed Shatter holds 2.7-3.4 Spalls a deck at V0 and plays them 12-23 times a run. Spall is the weaker card, so it ships as S2. The committed Shatter deck now dies less in Act 1 (38 to 20 at V0 full, 69 to 54 at V0 fresh). R gains too at V0 full (+8.0 pp, 34 against 18, p = 0.04), as it does with S1: a sound common lifts whoever draws it.
- **Lantern.** L1's Cinder Cut was held 2.1-2.4 times a deck and changed nothing: damage alone is not the Lantern's wall. L2's Hearthfall was played 16-20 times a run by committed Lantern and 3-5 times by A, and moved the Act-1 boss (Rootheart won in 127 of 200 fights at V0 fresh, against 100 of 196); the deaths moved to Acts 2 and 3. L3 frees the Energy: the pilot plays it whenever the lantern holds 3 Embers, which a Steady lantern reaches every turn (the turn's kindle plus the Steady first-gain bonus), so a lit Lantern hits for 16 each turn on top of its hand. It is a lit lantern's card: in the shipped catalogue at V0, committed Lantern plays it 28-35 times a run, A 6-8 and R 3-5.
- **Edge.** E1's Ward reached few decks (Eclipse Step held 0.7 times a deck at V0 full). E2 put it at common: committed Edge held 2.3 a deck, its Ward rose from 25 to 34 and its Act-2 deaths fell from 99 to 81, but its Act-3 deaths rose from 43 to 61, for 2 more wins; the adaptive arm took it too (1.6 a deck) and its Edge share of wins rose to 96% at V0 full. E3 added a harder capstone and kept the way's common supply the same size: +4.0 pp at V0 full (46 against 38 wins; 32 gained against 24 lost, p = 0.35), under the line, with G6 still rising. The Edge deck is weaker than the adaptive arm's Edge-led decks at every stage past Act 1 (Act-2 boss won 59% against 81%, Act-3 boss 54% against 81%), and each single change moved its deaths from one act to the next.

## Results, seeds 13000-13199

200 paired seeds per arm. Win rates by arm, then the four numbers of readout 6 and G6 (A's wins by the dominant way of the deck at run end, in percent, and how many A wins there are). Verdicts are the grader's; G1 and G5 are not graded at V5 fresh.

### V0, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 9.0% | 6.0% | 10.5% | 35.5% | 6.5% | 6.0% Lantern | +25.0 pp | +0.5 pp | 31.5% | 15 / 8 / 76% of 71 | FAIL / FAIL / FAIL / FAIL / FAIL |
| S1 Spall, 6 damage | 21.5% | 5.5% | 9.5% | 34.0% | 6.5% | 5.5% Lantern | +12.5 pp | +1.0 pp | 26.5% | 24 / 9 / 68% of 68 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 21.5% | 5.0% | 10.0% | 32.5% | 7.0% | 5.0% Lantern | +11.0 pp | +2.0 pp | 26.5% | 25 / 11 / 65% of 65 | FAIL / PASS / FAIL / FAIL / FAIL |
| L1 Cinder Cut | 10.0% | 5.0% | 9.0% | 33.0% | 6.5% | 5.0% Lantern | +23.0 pp | +1.5 pp | 35.0% | 18 / 15 / 67% of 66 | FAIL / FAIL / FAIL / FAIL / FAIL |
| L2 Hearthfall, 1 Energy | 8.5% | 11.0% | 9.0% | 33.5% | 8.5% | 8.5% Shatter | +22.5 pp | +0.0 pp | 34.0% | 18 / 24 / 58% of 67 | FAIL / FAIL / FAIL / FAIL / PASS |
| L3 Hearthfall, 0 Energy | 12.5% | 47.0% | 10.0% | 41.0% | 9.5% | 10.0% Edge | -6.0 pp | -0.5 pp | 34.0% | 18 / 30 / 51% of 82 | FAIL / FAIL / FAIL / FAIL / PASS |
| E1 Eclipse Step Ward 8 | 9.0% | 6.0% | 12.5% | 37.5% | 7.5% | 6.0% Lantern | +25.0 pp | +1.5 pp | 31.5% | 15 / 4 / 81% of 75 | FAIL / FAIL / FAIL / FAIL / FAIL |
| E2 Eclipse Step common, Ward 7 | 12.0% | 7.0% | 9.5% | 43.0% | 8.0% | 7.0% Lantern | +31.0 pp | +1.0 pp | 26.0% | 12 / 8 / 80% of 86 | FAIL / FAIL / FAIL / FAIL / FAIL |
| E3 E2 + Dim the Glass uncommon + Totality 20 | 10.0% | 7.0% | 15.5% | 40.5% | 7.5% | 7.0% Lantern | +25.0 pp | +0.5 pp | 31.0% | 11 / 5 / 84% of 81 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 25.0% | 43.0% | 9.5% | 44.0% | 9.5% | 9.5% Edge | +1.0 pp | +0.0 pp | 54.5% | 27 / 22 / 51% of 88 | FAIL / PASS / FAIL / PASS / PASS |

### V0, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 40.5% | 21.5% | 19.0% | 47.5% | 16.5% | 19.0% Edge | +7.0 pp | -2.5 pp | 28.0% | 6 / 3 / 91% of 95 | FAIL / PASS / FAIL / FAIL / FAIL |
| S1 Spall, 6 damage | 47.0% | 21.0% | 20.0% | 48.5% | 24.5% | 20.0% Edge | +1.5 pp | +4.5 pp | 51.5% | 2 / 7 / 91% of 97 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 48.0% | 21.5% | 20.0% | 47.5% | 24.5% | 20.0% Edge | -0.5 pp | +4.5 pp | 51.5% | 2 / 4 / 94% of 95 | FAIL / PASS / FAIL / FAIL / FAIL |
| L1 Cinder Cut | 36.5% | 21.0% | 19.5% | 48.5% | 22.5% | 19.5% Edge | +12.0 pp | +3.0 pp | 33.0% | 3 / 9 / 88% of 97 | FAIL / PASS / FAIL / FAIL / FAIL |
| L2 Hearthfall, 1 Energy | 35.5% | 25.0% | 20.0% | 45.5% | 20.0% | 20.0% Edge | +10.0 pp | +0.0 pp | 31.5% | 0 / 23 / 77% of 91 | FAIL / PASS / FAIL / FAIL / FAIL |
| L3 Hearthfall, 0 Energy | 39.0% | 58.0% | 18.5% | 57.5% | 27.0% | 18.5% Edge | -0.5 pp | +8.5 pp | 31.5% | 0 / 21 / 79% of 115 | FAIL / PASS / FAIL / FAIL / FAIL |
| E1 Eclipse Step Ward 8 | 40.0% | 21.5% | 19.5% | 53.5% | 18.0% | 19.5% Edge | +13.5 pp | -1.5 pp | 28.0% | 6 / 3 / 92% of 107 | FAIL / PASS / FAIL / FAIL / FAIL |
| E2 Eclipse Step common, Ward 7 | 34.5% | 18.5% | 20.0% | 48.0% | 22.5% | 18.5% Lantern | +13.5 pp | +4.0 pp | 27.5% | 1 / 3 / 96% of 96 | FAIL / PASS / FAIL / FAIL / FAIL |
| E3 E2 + Dim the Glass uncommon + Totality 20 | 39.5% | 20.0% | 23.0% | 50.5% | 19.0% | 20.0% Lantern | +11.0 pp | -1.0 pp | 27.5% | 4 / 5 / 91% of 101 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 45.5% | 60.0% | 14.5% | 52.5% | 21.5% | 14.5% Edge | -7.5 pp | +7.0 pp | 58.0% | 8 / 22 / 70% of 105 | FAIL / FAIL / FAIL / FAIL / FAIL |

### V5, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.5% | 5.0% | 0.5% | 0.0% Shatter | +4.0 pp | +0.5 pp | 8.0% | 20 / 40 / 40% of 10 | n/a / PASS / FAIL / n/a / PASS |
| S1 Spall, 6 damage | 2.5% | 0.0% | 0.5% | 8.0% | 0.0% | 0.0% Lantern | +5.5 pp | +0.0 pp | 8.0% | 25 / 12 / 62% of 16 | n/a / PASS / FAIL / n/a / FAIL |
| S2 Spall, 5 damage | 2.0% | 0.0% | 0.5% | 9.0% | 0.0% | 0.0% Lantern | +7.0 pp | +0.0 pp | 8.0% | 28 / 11 / 61% of 18 | n/a / PASS / FAIL / n/a / FAIL |
| L1 Cinder Cut | 1.0% | 0.0% | 0.5% | 7.5% | 0.5% | 0.0% Lantern | +6.5 pp | +0.5 pp | 12.5% | 13 / 33 / 53% of 15 | n/a / PASS / FAIL / n/a / PASS |
| L2 Hearthfall, 1 Energy | 1.0% | 2.0% | 0.5% | 6.5% | 0.5% | 0.5% Edge | +4.5 pp | +0.0 pp | 14.0% | 23 / 31 / 46% of 13 | n/a / PASS / FAIL / n/a / PASS |
| L3 Hearthfall, 0 Energy | 1.0% | 6.0% | 0.5% | 8.5% | 1.0% | 0.5% Edge | +2.5 pp | +0.5 pp | 18.5% | 0 / 53 / 47% of 17 | n/a / PASS / FAIL / n/a / PASS |
| E1 Eclipse Step Ward 8 | 0.0% | 1.0% | 0.5% | 4.5% | 0.5% | 0.0% Shatter | +3.5 pp | +0.5 pp | 8.0% | 33 / 22 / 44% of 9 | n/a / PASS / FAIL / n/a / PASS |
| E2 Eclipse Step common, Ward 7 | 0.0% | 0.5% | 0.0% | 4.5% | 0.5% | 0.0% Shatter | +4.0 pp | +0.5 pp | 5.5% | 22 / 0 / 78% of 9 | n/a / PASS / FAIL / n/a / FAIL |
| E3 E2 + Dim the Glass uncommon + Totality 20 | 0.0% | 1.0% | 0.0% | 4.0% | 1.0% | 0.0% Shatter | +3.0 pp | +1.0 pp | 8.0% | 25 / 25 / 50% of 8 | n/a / PASS / FAIL / n/a / PASS |
| Shipped: S2 + L3 | 2.5% | 9.0% | 0.5% | 6.5% | 1.0% | 0.5% Edge | -2.5 pp | +0.5 pp | 15.0% | 46 / 38 / 15% of 13 | n/a / PASS / FAIL / n/a / PASS |

### V5, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 14.0% | 4.5% | 3.5% | 17.0% | 3.0% | 3.5% Edge | +3.0 pp | -0.5 pp | 14.0% | 12 / 12 / 76% of 34 | FAIL / PASS / FAIL / FAIL / FAIL |
| S1 Spall, 6 damage | 16.5% | 4.5% | 3.0% | 15.5% | 5.0% | 3.0% Edge | -1.0 pp | +2.0 pp | 20.5% | 0 / 10 / 90% of 31 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 17.0% | 4.0% | 3.0% | 16.0% | 5.0% | 3.0% Edge | -1.0 pp | +2.0 pp | 20.0% | 3 / 12 / 84% of 32 | FAIL / PASS / FAIL / FAIL / FAIL |
| L1 Cinder Cut | 14.5% | 7.0% | 3.0% | 15.5% | 4.5% | 3.0% Edge | +1.0 pp | +1.5 pp | 17.5% | 0 / 19 / 81% of 31 | FAIL / PASS / FAIL / FAIL / FAIL |
| L2 Hearthfall, 1 Energy | 14.0% | 6.5% | 3.0% | 14.0% | 4.5% | 3.0% Edge | +0.0 pp | +1.5 pp | 17.5% | 0 / 36 / 64% of 28 | FAIL / PASS / FAIL / FAIL / FAIL |
| L3 Hearthfall, 0 Energy | 14.5% | 20.0% | 3.0% | 14.5% | 6.0% | 3.0% Edge | -5.5 pp | +3.0 pp | 17.0% | 0 / 21 / 79% of 29 | FAIL / FAIL / FAIL / FAIL / FAIL |
| E1 Eclipse Step Ward 8 | 14.5% | 4.0% | 3.0% | 17.0% | 2.5% | 3.0% Edge | +2.5 pp | -0.5 pp | 14.0% | 15 / 12 / 74% of 34 | FAIL / PASS / FAIL / FAIL / FAIL |
| E2 Eclipse Step common, Ward 7 | 9.5% | 6.5% | 1.5% | 14.5% | 7.5% | 1.5% Edge | +5.0 pp | +6.0 pp | 14.5% | 7 / 0 / 93% of 29 | FAIL / PASS / FAIL / FAIL / FAIL |
| E3 E2 + Dim the Glass uncommon + Totality 20 | 14.0% | 6.0% | 7.0% | 19.5% | 2.5% | 6.0% Lantern | +5.5 pp | -3.5 pp | 12.5% | 10 / 5 / 85% of 39 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 19.5% | 15.0% | 3.5% | 19.0% | 6.0% | 3.5% Edge | -0.5 pp | +2.5 pp | 33.5% | 11 / 18 / 71% of 38 | FAIL / PASS / FAIL / FAIL / FAIL |

## Confirmation, seeds 13200-13299

The control, the two winners and the shipped pair on the sweep seeds of readouts 3 to 6 (100 paired seeds).

### V0, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 11.0% | 8.0% | 6.0% | 43.0% | 5.0% | 6.0% Edge | +32.0 pp | -1.0 pp | 26.0% | 12 / 9 / 79% of 43 | FAIL / FAIL / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 18.0% | 5.0% | 8.0% | 35.0% | 9.0% | 5.0% Lantern | +17.0 pp | +4.0 pp | 22.0% | 14 / 3 / 83% of 35 | FAIL / FAIL / FAIL / FAIL / FAIL |
| L3 Hearthfall, 0 Energy | 15.0% | 49.0% | 8.0% | 45.0% | 12.0% | 8.0% Edge | -4.0 pp | +4.0 pp | 33.0% | 4 / 29 / 67% of 45 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 17.0% | 40.0% | 11.0% | 38.0% | 14.0% | 11.0% Edge | -2.0 pp | +3.0 pp | 52.0% | 16 / 37 / 47% of 38 | FAIL / PASS / FAIL / PASS / PASS |

### V0, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 40.0% | 21.0% | 27.0% | 45.0% | 19.0% | 21.0% Lantern | +5.0 pp | -2.0 pp | 30.0% | 0 / 13 / 87% of 45 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 45.0% | 24.0% | 18.0% | 42.0% | 22.0% | 18.0% Edge | -3.0 pp | +4.0 pp | 54.0% | 5 / 12 / 83% of 42 | FAIL / PASS / FAIL / FAIL / FAIL |
| L3 Hearthfall, 0 Energy | 37.0% | 65.0% | 18.0% | 50.0% | 25.0% | 18.0% Edge | -15.0 pp | +7.0 pp | 27.0% | 2 / 20 / 78% of 50 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 51.0% | 61.0% | 16.0% | 52.0% | 32.0% | 16.0% Edge | -9.0 pp | +16.0 pp | 48.0% | 4 / 23 / 73% of 52 | FAIL / FAIL / FAIL / FAIL / FAIL |

### V5, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.0% | 5.0% | 2.0% | 0.0% Shatter | +4.0 pp | +2.0 pp | 7.0% | 60 / 20 / 20% of 5 | n/a / PASS / FAIL / n/a / PASS |
| S2 Spall, 5 damage | 2.0% | 0.0% | 0.0% | 6.0% | 0.0% | 0.0% Lantern | +4.0 pp | +0.0 pp | 7.0% | 67 / 17 / 17% of 6 | n/a / PASS / FAIL / n/a / FAIL |
| L3 Hearthfall, 0 Energy | 1.0% | 15.0% | 1.0% | 9.0% | 0.0% | 1.0% Shatter | -6.0 pp | -1.0 pp | 19.0% | 22 / 44 / 33% of 9 | n/a / FAIL / FAIL / n/a / PASS |
| Shipped: S2 + L3 | 2.0% | 8.0% | 1.0% | 8.0% | 2.0% | 1.0% Edge | +0.0 pp | +1.0 pp | 22.0% | 25 / 25 / 50% of 8 | n/a / PASS / FAIL / n/a / PASS |

### V5, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 11.0% | 7.0% | 8.0% | 19.0% | 6.0% | 7.0% Lantern | +8.0 pp | -1.0 pp | 16.0% | 5 / 5 / 89% of 19 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 Spall, 5 damage | 16.0% | 5.0% | 6.0% | 11.0% | 7.0% | 5.0% Lantern | -5.0 pp | +2.0 pp | 26.0% | 9 / 18 / 73% of 11 | FAIL / FAIL / FAIL / FAIL / FAIL |
| L3 Hearthfall, 0 Energy | 14.0% | 31.0% | 6.0% | 12.0% | 5.0% | 6.0% Edge | -19.0 pp | -1.0 pp | 20.0% | 8 / 8 / 83% of 12 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 18.0% | 22.0% | 2.0% | 13.0% | 7.0% | 2.0% Edge | -9.0 pp | +5.0 pp | 36.0% | 8 / 23 / 69% of 13 | FAIL / FAIL / FAIL / FAIL / FAIL |

## Pooled over 300 paired seeds

Both bands together (Wilson 95% on the worst committed way). The control is main; it matches readout 6's pooled E1b rows.

| Catalogue | Cell | Shatter | Lantern | Edge | A | R | G1 worst committed (Wilson 95%) | G3 | G4 | G5 min |
|---|---|---:|---:|---:|---:|---:|---|---:|---:|---:|
| Control (main) | V0 fresh | 9.7% | 6.7% | 9.0% | 38.0% | 6.0% | 6.7% Lantern (4.4%-10.1%) | +28.3 pp | -0.7 pp | 29.7% |
| Control (main) | V0 full | 40.3% | 21.3% | 21.7% | 46.7% | 17.3% | 21.3% Lantern (17.1%-26.3%) | +6.3 pp | -4.0 pp | 28.7% |
| Control (main) | V5 fresh | 0.0% | 1.0% | 0.3% | 5.0% | 1.0% | 0.0% Shatter (0.0%-1.3%) | +4.0 pp | +1.0 pp | 7.7% |
| Control (main) | V5 full | 13.0% | 5.3% | 5.0% | 17.7% | 4.0% | 5.0% Edge (3.1%-8.1%) | +4.7 pp | -1.0 pp | 14.7% |
| S2 Spall, 5 damage | V0 fresh | 20.3% | 5.0% | 9.3% | 33.3% | 7.7% | 5.0% Lantern (3.1%-8.1%) | +13.0 pp | +2.7 pp | 25.0% |
| S2 Spall, 5 damage | V0 full | 47.0% | 22.3% | 19.3% | 45.7% | 23.7% | 19.3% Edge (15.3%-24.2%) | -1.3 pp | +4.3 pp | 52.3% |
| S2 Spall, 5 damage | V5 fresh | 2.0% | 0.0% | 0.3% | 8.0% | 0.0% | 0.0% Lantern (0.0%-1.3%) | +6.0 pp | +0.0 pp | 7.7% |
| S2 Spall, 5 damage | V5 full | 16.7% | 4.3% | 4.0% | 14.3% | 5.7% | 4.0% Edge (2.3%-6.9%) | -2.3 pp | +1.7 pp | 22.0% |
| L3 Hearthfall, 0 Energy | V0 fresh | 13.3% | 47.7% | 9.3% | 42.3% | 10.3% | 9.3% Edge (6.5%-13.2%) | -5.3 pp | +1.0 pp | 33.7% |
| L3 Hearthfall, 0 Energy | V0 full | 38.3% | 60.3% | 18.3% | 55.0% | 26.3% | 18.3% Edge (14.4%-23.1%) | -5.3 pp | +8.0 pp | 30.0% |
| L3 Hearthfall, 0 Energy | V5 fresh | 1.0% | 9.0% | 0.7% | 8.7% | 0.7% | 0.7% Edge (0.2%-2.4%) | -0.3 pp | +0.0 pp | 18.7% |
| L3 Hearthfall, 0 Energy | V5 full | 14.3% | 23.7% | 4.0% | 13.7% | 5.7% | 4.0% Edge (2.3%-6.9%) | -10.0 pp | +1.7 pp | 18.0% |
| Shipped: S2 + L3 | V0 fresh | 22.3% | 42.0% | 10.0% | 42.0% | 11.0% | 10.0% Edge (7.1%-13.9%) | +0.0 pp | +1.0 pp | 54.3% |
| Shipped: S2 + L3 | V0 full | 47.3% | 60.3% | 15.0% | 52.3% | 25.0% | 15.0% Edge (11.4%-19.5%) | -8.0 pp | +10.0 pp | 54.7% |
| Shipped: S2 + L3 | V5 fresh | 2.3% | 8.7% | 0.7% | 7.0% | 1.3% | 0.7% Edge (0.2%-2.4%) | -1.7 pp | +0.7 pp | 18.0% |
| Shipped: S2 + L3 | V5 full | 19.0% | 17.3% | 3.0% | 17.0% | 6.3% | 3.0% Edge (1.6%-5.6%) | -2.0 pp | +3.3 pp | 34.3% |

Paired over the 300 seeds at V0 full, shipped against main: committed Lantern 148 wins gained against 31 lost (p < 0.001), Shatter 78 against 57 (p = 0.08), Edge 34 against 54 (p = 0.04); A 71 against 54 (p = 0.15); R 60 against 37 (p = 0.03).

## Re-check on the merge base (after #599)

#599 removes the Ashwarden's venom phial, Venom Pouch, the Ashfall Art and the deed Sermon of Ash from the Duskblade's offers, so the full pool changes and the fresh pool does not (every fresh-pool row below equals its row above). Each candidate was rebuilt by the same script from the merge base's file (`361c5e1ee764c2a755e860af02041a1d5982e8aef0c8ba86b6b6eae867f558a0`) and run on 13000-13199 against that base; the control and the shipped pair were also run on 13200-13299. The stop rule and the G6 rule are the ones above.

| Candidate | Way | Own way, V0 full: wins (vs control) | Paired gained / lost, p | Own way, V5 full | Own way, V0 fresh | G6 pooled: leading way's share of A's wins (control 83.3% edge) | A cell (>= 30 A wins) turns G6 PASS to FAIL | Meets the stop rule |
|---|---|---:|---|---:|---:|---:|---|---|
| S1 Spall, 6 damage | Shatter | 102/200 51.0% (+17.0 pp) | 61 / 27, p = 0.00 | 19.0% (+6.5 pp) | 21.5% (+12.5 pp) | 78.4% edge (-4.8 pp) | none | yes |
| S2 Spall, 5 damage | Shatter | 99/200 49.5% (+15.5 pp) | 61 / 30, p = 0.00 | 20.0% (+7.5 pp) | 21.5% (+12.5 pp) | 78.6% edge (-4.7 pp) | none | yes |
| L1 Cinder Cut | Lantern | 39/200 19.5% (-8.0 pp) | 26 / 42, p = 0.07 | 4.0% (-2.0 pp) | 5.0% (-1.0 pp) | 77.8% edge (-5.5 pp) | none | no |
| L2 Hearthfall, 1 Energy | Lantern | 51/200 25.5% (-2.0 pp) | 39 / 43, p = 0.74 | 6.5% (+0.5 pp) | 11.0% (+5.0 pp) | 69.4% edge (-13.9 pp) | none | no |
| L3 Hearthfall, 0 Energy | Lantern | 119/200 59.5% (+32.0 pp) | 91 / 27, p = 0.00 | 24.5% (+18.5 pp) | 47.0% (+41.0 pp) | 67.2% edge (-16.1 pp) | none | yes |
| L4 Hearthfall at 12, with S2 | Lantern | 95/200 47.5% (+20.0 pp) | 72 / 32, p < 0.001 | 14.5% (+8.5 pp) | 32.5% (+26.5 pp) | 68.6% edge (-14.7 pp) | none | yes |
| E1 Eclipse Step Ward 8 | Edge | 50/200 25.0% (+4.0 pp) | 13 / 5, p = 0.10 | 4.5% (-0.5 pp) | 12.5% (+2.0 pp) | 86.0% edge (+2.7 pp) | none | no |
| E2 Eclipse Step common, Ward 7 | Edge | 55/200 27.5% (+6.5 pp) | 41 / 28, p = 0.15 | 2.5% (-2.5 pp) | 9.5% (-1.0 pp) | 87.2% edge (+3.9 pp) | none | no |
| E3 E2 + Dim the Glass uncommon + Totality 20 | Edge | 57/200 28.5% (+7.5 pp) | 44 / 29, p = 0.10 | 5.0% (+0.0 pp) | 15.5% (+5.0 pp) | 87.8% edge (+4.5 pp) | none | no |

Shatter and the Lantern each meet the rule again with the same candidates. Edge's E2 and E3 now clear the 5 pp line, but each raises the adaptive arm's Edge share of wins by more than the G6 rule allows, as on the first base; E1 still does not clear it. The decisions are unchanged.

#### V0, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 9.0% | 6.0% | 10.5% | 35.5% | 6.5% | 6.0% Lantern | +25.0 pp | +0.5 pp | 31.5% | 15 / 8 / 76% of 71 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 25.0% | 43.0% | 9.5% | 44.0% | 9.5% | 9.5% Edge | +1.0 pp | +0.0 pp | 54.5% | 27 / 22 / 51% of 88 | FAIL / PASS / FAIL / PASS / PASS |

#### V0, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 34.0% | 27.5% | 21.0% | 56.0% | 17.5% | 21.0% Edge | +22.0 pp | -3.5 pp | 26.0% | 4 / 7 / 89% of 112 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 49.5% | 61.5% | 22.0% | 52.5% | 23.0% | 22.0% Edge | -9.0 pp | +1.0 pp | 58.5% | 2 / 20 / 78% of 105 | FAIL / FAIL / FAIL / FAIL / FAIL |

#### V5, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.5% | 5.0% | 0.5% | 0.0% Shatter | +4.0 pp | +0.5 pp | 8.0% | 20 / 40 / 40% of 10 | n/a / PASS / FAIL / n/a / PASS |
| Shipped: S2 + L3 | 2.5% | 9.0% | 0.5% | 6.5% | 1.0% | 0.5% Edge | -2.5 pp | +0.5 pp | 15.0% | 46 / 38 / 15% of 13 | n/a / PASS / FAIL / n/a / PASS |

#### V5, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 12.5% | 6.0% | 5.0% | 17.0% | 5.0% | 5.0% Edge | +4.5 pp | +0.0 pp | 13.0% | 0 / 9 / 91% of 34 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 16.0% | 21.5% | 3.0% | 23.5% | 7.0% | 3.0% Edge | +2.0 pp | +4.0 pp | 32.5% | 9 / 13 / 79% of 47 | FAIL / PASS / FAIL / FAIL / FAIL |

#### V0, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 11.0% | 8.0% | 6.0% | 43.0% | 5.0% | 6.0% Edge | +32.0 pp | -1.0 pp | 26.0% | 12 / 9 / 79% of 43 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 17.0% | 40.0% | 11.0% | 38.0% | 14.0% | 11.0% Edge | -2.0 pp | +3.0 pp | 52.0% | 16 / 37 / 47% of 38 | FAIL / PASS / FAIL / PASS / PASS |

#### V0, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 37.0% | 25.0% | 25.0% | 45.0% | 18.0% | 25.0% Lantern | +8.0 pp | -7.0 pp | 29.0% | 0 / 11 / 89% of 45 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 50.0% | 65.0% | 20.0% | 50.0% | 29.0% | 20.0% Edge | -15.0 pp | +9.0 pp | 51.0% | 6 / 22 / 72% of 50 | FAIL / FAIL / FAIL / FAIL / FAIL |

#### V5, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.0% | 5.0% | 2.0% | 0.0% Shatter | +4.0 pp | +2.0 pp | 7.0% | 60 / 20 / 20% of 5 | n/a / PASS / FAIL / n/a / PASS |
| Shipped: S2 + L3 | 2.0% | 8.0% | 1.0% | 8.0% | 2.0% | 1.0% Edge | +0.0 pp | +1.0 pp | 22.0% | 25 / 25 / 50% of 8 | n/a / PASS / FAIL / n/a / PASS |

#### V5, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 15.0% | 5.0% | 4.0% | 14.0% | 4.0% | 4.0% Edge | -1.0 pp | +0.0 pp | 17.0% | 0 / 14 / 86% of 14 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L3 | 23.0% | 24.0% | 3.0% | 20.0% | 4.0% | 3.0% Edge | -4.0 pp | +1.0 pp | 34.0% | 0 / 20 / 80% of 20 | FAIL / FAIL / FAIL / FAIL / FAIL |

Pooled over 300 paired seeds on the merge base, shipped against the base at V0 full: committed Shatter 35.0% to 49.7% (90 gained, 46 lost, p < 0.001), Lantern 26.7% to 62.7% (138 against 30, p < 0.001), Edge 22.3% to 21.3% (50 against 53, p = 0.84), A 52.3% to 51.7% (71 against 73), R 17.7% to 25.0% (54 against 32, p = 0.02). At V5 full: Shatter 13.3% to 18.3%, Lantern 5.7% to 22.3%, Edge 4.7% to 3.0%, A 16.0% to 22.3%, R 4.7% to 6.0%.

## The Lantern's third candidate (L4)

L3 lifted the Lantern past the adaptive arm and 12 pp past Shatter at V0 full. The owner's target for the one remaining Lantern candidate: the committed Lantern within about 8 pp of Shatter at V0 full and under the adaptive arm, still at least 5 pp above main. Three single numbers were on offer: an Ember cost of 4, damage of 12-13 at 0 Energy, or 1 Energy with the 3-Ember cost and more damage. The evidence picked damage. L2 showed the Energy cost is a cliff (1 Energy took the lift from +32.0 to -2.0 pp on the merge base), and a 4-Ember cost moves the play rate against a Steady lantern's income of 3 Embers a turn, so it would interact with the Flare's own 3-Ember price; at 0 Energy the play rate is fixed by that income and the damage scales the payoff alone. L4 is the PR head's catalogue with Hearthfall at 12 (upgraded 16), 0 Energy and 3 Embers, run with Spall on the merge base on 13000-13199 and confirmed on 13200-13299.

It lands: the committed Lantern wins 47.5% at V0 full, level with Shatter (47.5%) and 7.5 pp under the adaptive arm (55.0%), 20.0 pp above main's 27.5% (72 seeds gained against 32 lost). G3 at V0 full passes (+7.5 pp). The sweep band is less kind: there the Lantern still wins 61% at V0 full against Shatter's 50% and A's 47%. Over both bands (300 paired seeds) the Lantern is 52.0%, Shatter 48.3% and A 52.3%: level with the adaptive arm rather than under it. G6 pooled over the four cells is 68.6% Edge (main 83.3%, L3 65.6%); G2 at V0 full on 13000-13199 is 26.0 pp, all of it Edge's gap (L3 39.5 pp, main 13.0 pp).

#### V0, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 9.0% | 6.0% | 10.5% | 35.5% | 6.5% | 6.0% Lantern | +25.0 pp | +0.5 pp | 31.5% | 15 / 8 / 76% of 71 | FAIL / FAIL / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 25.0% | 43.0% | 9.5% | 44.0% | 9.5% | 9.5% Edge | +1.0 pp | +0.0 pp | 54.5% | 27 / 22 / 51% of 88 | FAIL / PASS / FAIL / PASS / PASS |
| Shipped: S2 + L4 | 25.5% | 32.5% | 10.0% | 39.5% | 9.5% | 10.0% Edge | +7.0 pp | -0.5 pp | 52.5% | 29 / 13 / 58% of 79 | FAIL / PASS / FAIL / PASS / PASS |

#### V0, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 34.0% | 27.5% | 21.0% | 56.0% | 17.5% | 21.0% Edge | +22.0 pp | -3.5 pp | 26.0% | 4 / 7 / 89% of 112 | FAIL / FAIL / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 49.5% | 61.5% | 22.0% | 52.5% | 23.0% | 22.0% Edge | -9.0 pp | +1.0 pp | 58.5% | 2 / 20 / 78% of 105 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L4 | 47.5% | 47.5% | 21.5% | 55.0% | 22.0% | 21.5% Edge | +7.5 pp | +0.5 pp | 59.5% | 5 / 18 / 77% of 110 | FAIL / PASS / FAIL / FAIL / FAIL |

#### V5, fresh pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.5% | 5.0% | 0.5% | 0.0% Shatter | +4.0 pp | +0.5 pp | 8.0% | 20 / 40 / 40% of 10 | n/a / PASS / FAIL / n/a / PASS |
| S2 + L3 (Hearthfall 16) | 2.5% | 9.0% | 0.5% | 6.5% | 1.0% | 0.5% Edge | -2.5 pp | +0.5 pp | 15.0% | 46 / 38 / 15% of 13 | n/a / PASS / FAIL / n/a / PASS |
| Shipped: S2 + L4 | 1.5% | 4.5% | 0.5% | 4.5% | 0.0% | 0.5% Edge | +0.0 pp | -0.5 pp | 15.0% | 33 / 56 / 11% of 9 | n/a / PASS / FAIL / n/a / PASS |

#### V5, full pool, seeds 13000-13199

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 12.5% | 6.0% | 5.0% | 17.0% | 5.0% | 5.0% Edge | +4.5 pp | +0.0 pp | 13.0% | 0 / 9 / 91% of 34 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 16.0% | 21.5% | 3.0% | 23.5% | 7.0% | 3.0% Edge | +2.0 pp | +4.0 pp | 32.5% | 9 / 13 / 79% of 47 | FAIL / PASS / FAIL / FAIL / FAIL |
| Shipped: S2 + L4 | 15.5% | 14.5% | 3.5% | 19.0% | 7.0% | 3.5% Edge | +3.5 pp | +3.5 pp | 32.5% | 13 / 8 / 79% of 38 | FAIL / PASS / FAIL / FAIL / FAIL |

#### V0, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 11.0% | 8.0% | 6.0% | 43.0% | 5.0% | 6.0% Edge | +32.0 pp | -1.0 pp | 26.0% | 12 / 9 / 79% of 43 | FAIL / FAIL / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 17.0% | 40.0% | 11.0% | 38.0% | 14.0% | 11.0% Edge | -2.0 pp | +3.0 pp | 52.0% | 16 / 37 / 47% of 38 | FAIL / PASS / FAIL / PASS / PASS |
| Shipped: S2 + L4 | 17.0% | 30.0% | 9.0% | 29.0% | 13.0% | 9.0% Edge | -1.0 pp | +4.0 pp | 49.0% | 24 / 17 / 59% of 29 | FAIL / PASS / FAIL / PASS / PASS |

#### V0, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 37.0% | 25.0% | 25.0% | 45.0% | 18.0% | 25.0% Lantern | +8.0 pp | -7.0 pp | 29.0% | 0 / 11 / 89% of 45 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 50.0% | 65.0% | 20.0% | 50.0% | 29.0% | 20.0% Edge | -15.0 pp | +9.0 pp | 51.0% | 6 / 22 / 72% of 50 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L4 | 50.0% | 61.0% | 20.0% | 47.0% | 29.0% | 20.0% Edge | -14.0 pp | +9.0 pp | 50.0% | 4 / 6 / 89% of 47 | FAIL / FAIL / FAIL / FAIL / FAIL |

#### V5, fresh pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 0.0% | 1.0% | 0.0% | 5.0% | 2.0% | 0.0% Shatter | +4.0 pp | +2.0 pp | 7.0% | 60 / 20 / 20% of 5 | n/a / PASS / FAIL / n/a / PASS |
| S2 + L3 (Hearthfall 16) | 2.0% | 8.0% | 1.0% | 8.0% | 2.0% | 1.0% Edge | +0.0 pp | +1.0 pp | 22.0% | 25 / 25 / 50% of 8 | n/a / PASS / FAIL / n/a / PASS |
| Shipped: S2 + L4 | 3.0% | 9.0% | 1.0% | 7.0% | 2.0% | 1.0% Edge | -2.0 pp | +1.0 pp | 19.0% | 14 / 14 / 71% of 7 | n/a / PASS / FAIL / n/a / FAIL |

#### V5, full pool, seeds 13200-13299

| Catalogue | Shatter | Lantern | Edge | A | R | G1 worst committed | G3 A - best committed | G4 R - worst committed | G5 Steady by end of Act 1, min | G6 A's wins: Shatter / Lantern / Edge | Verdicts G1 / G3 / G4 / G5 / G6 |
|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---|
| Control (main) | 15.0% | 5.0% | 4.0% | 14.0% | 4.0% | 4.0% Edge | -1.0 pp | +0.0 pp | 17.0% | 0 / 14 / 86% of 14 | FAIL / PASS / FAIL / FAIL / FAIL |
| S2 + L3 (Hearthfall 16) | 23.0% | 24.0% | 3.0% | 20.0% | 4.0% | 3.0% Edge | -4.0 pp | +1.0 pp | 34.0% | 0 / 20 / 80% of 20 | FAIL / FAIL / FAIL / FAIL / FAIL |
| Shipped: S2 + L4 | 25.0% | 18.0% | 3.0% | 16.0% | 3.0% | 3.0% Edge | -9.0 pp | +0.0 pp | 33.0% | 6 / 6 / 88% of 16 | FAIL / FAIL / FAIL / FAIL / FAIL |

Over 300 paired seeds on the merge base, S2 + L4 against the base: at V0 full committed Shatter 35.0% to 48.3% (89 gained, 49 lost), Lantern 26.7% to 52.0% (119 against 43), Edge 22.3% to 21.0% (49 against 53, p = 0.77), A 52.3% to 52.3% (65 against 65), R 17.7% to 24.3% (51 against 31, p = 0.04); at V5 full Shatter 13.3% to 18.7%, Lantern 5.7% to 15.7%, Edge 4.7% to 3.3%, A 16.0% to 18.0%, R 4.7% to 5.7%. G7 holds in all eight cells of both L4 tables.

## Where the runs end

Deaths by act and wins, seeds 13000-13199 (200 runs per arm and cell).

| Cell | Arm | Control (main): Act 1 / 2 / 3 deaths, wins | S2 Spall, 5 damage: Act 1 / 2 / 3 deaths, wins | L3 Hearthfall, 0 Energy: Act 1 / 2 / 3 deaths, wins | Shipped: S2 + L3: Act 1 / 2 / 3 deaths, wins |
|---|---|---|---|---|---|
| V0 fresh | C_shatter | 69 / 66 / 47, 18 | 54 / 51 / 52, 43 | 73 / 59 / 43, 25 | 53 / 42 / 55, 50 |
| V0 fresh | C_lantern | 100 / 55 / 33, 12 | 105 / 53 / 32, 10 | 44 / 20 / 42, 94 | 46 / 33 / 35, 86 |
| V0 fresh | C_edge | 41 / 102 / 36, 21 | 50 / 88 / 42, 20 | 51 / 86 / 43, 20 | 51 / 87 / 43, 19 |
| V0 fresh | A | 58 / 39 / 32, 71 | 46 / 44 / 45, 65 | 46 / 32 / 40, 82 | 55 / 29 / 28, 88 |
| V0 fresh | R | 106 / 55 / 26, 13 | 93 / 56 / 37, 14 | 91 / 52 / 38, 19 | 89 / 55 / 37, 19 |
| V0 full | C_shatter | 38 / 43 / 38, 81 | 20 / 44 / 40, 96 | 40 / 47 / 35, 78 | 31 / 32 / 46, 91 |
| V0 full | C_lantern | 56 / 62 / 39, 43 | 66 / 58 / 33, 43 | 29 / 20 / 35, 116 | 25 / 14 / 41, 120 |
| V0 full | C_edge | 20 / 99 / 43, 38 | 19 / 80 / 61, 40 | 19 / 80 / 64, 37 | 29 / 75 / 67, 29 |
| V0 full | A | 24 / 46 / 35, 95 | 27 / 49 / 29, 95 | 22 / 31 / 32, 115 | 33 / 31 / 31, 105 |
| V0 full | R | 54 / 69 / 44, 33 | 60 / 51 / 40, 49 | 55 / 52 / 39, 54 | 51 / 63 / 43, 43 |
| V5 fresh | C_shatter | 149 / 41 / 10, 0 | 137 / 45 / 14, 4 | 145 / 45 / 8, 2 | 137 / 40 / 18, 5 |
| V5 fresh | C_lantern | 176 / 16 / 6, 2 | 172 / 18 / 10, 0 | 134 / 31 / 23, 12 | 148 / 26 / 8, 18 |
| V5 fresh | C_edge | 152 / 46 / 1, 1 | 148 / 46 / 5, 1 | 145 / 48 / 6, 1 | 154 / 42 / 3, 1 |
| V5 fresh | A | 147 / 24 / 19, 10 | 140 / 21 / 21, 18 | 131 / 23 / 29, 17 | 134 / 32 / 21, 13 |
| V5 fresh | R | 182 / 13 / 4, 1 | 166 / 27 / 7, 0 | 167 / 24 / 7, 2 | 168 / 25 / 5, 2 |
| V5 full | C_shatter | 116 / 41 / 15, 28 | 98 / 47 / 21, 34 | 110 / 48 / 13, 29 | 91 / 55 / 15, 39 |
| V5 full | C_lantern | 142 / 41 / 8, 9 | 141 / 36 / 15, 8 | 101 / 34 / 25, 40 | 101 / 39 / 30, 30 |
| V5 full | C_edge | 91 / 87 / 15, 7 | 93 / 91 / 10, 6 | 96 / 88 / 10, 6 | 89 / 96 / 8, 7 |
| V5 full | A | 101 / 45 / 20, 34 | 107 / 42 / 19, 32 | 100 / 51 / 20, 29 | 96 / 47 / 19, 38 |
| V5 full | R | 142 / 46 / 6, 6 | 137 / 45 / 8, 10 | 135 / 42 / 11, 12 | 131 / 43 / 14, 12 |

## The offer's colours

The coloured glass offered per run, by way (the simulator's per-card offer counter over card rewards, shop stock and event picks, weighted by affinity), seeds 13000-13199, for the two arms that do not steer by a way:

| Cell | Arm | Main: Shatter / Lantern / Edge offered per run (shares) | Shipped: Shatter / Lantern / Edge offered per run (shares) |
|---|---|---|---|
| V0 fresh | A | 4.4 / 6.6 / 14.3 (17 / 26 / 56%) | 7.1 / 8.8 / 12.7 (25 / 31 / 44%) |
| V0 fresh | R | 2.8 / 4.7 / 10.3 (16 / 27 / 58%) | 5.4 / 7.1 / 10.6 (23 / 31 / 46%) |
| V0 full | A | 4.6 / 11.6 / 21.2 (12 / 31 / 57%) | 7.9 / 14.5 / 19.2 (19 / 35 / 46%) |
| V0 full | R | 3.7 / 9.6 / 16.9 (12 / 32 / 56%) | 6.2 / 12.2 / 16.1 (18 / 35 / 47%) |
| V5 fresh | A | 3.1 / 4.1 / 7.7 (21 / 28 / 52%) | 4.8 / 5.7 / 7.8 (26 / 31 / 42%) |
| V5 fresh | R | 2.3 / 3.2 / 6.6 (19 / 26 / 55%) | 3.7 / 4.3 / 6.5 (25 / 30 / 45%) |
| V5 full | A | 3.5 / 8.9 / 13.7 (14 / 34 / 52%) | 5.3 / 10.4 / 13.1 (18 / 36 / 45%) |
| V5 full | R | 2.5 / 6.3 / 10.2 (13 / 33 / 54%) | 4.1 / 8.4 / 10.4 (18 / 37 / 46%) |

Shatter's share rises from 12-21% to 18-26% and the Lantern's from 26-34% to 30-37%; Edge's falls from 52-58% to 42-47%. The adaptive arm follows the offer, which is why G6 improves, and the committed Edge pilot sees fewer Edge cards, which is most of why it is weaker.

## Reading

Each way's wall was a different thing, and content reached two of them. Shatter lacked glass, not strength: one common of its own (Spall) lights its flame twice as often by the end of Act 1 and lifts it 7.5 pp in the full pool and 12.5 pp in the fresh one, whatever the card's damage. The Lantern lacked a payoff: its glass made Embers that only the once-a-turn Flare could spend, and a common that spends them on one heavy blow at no Energy (Hearthfall) lifts it, with the adaptive and random arms, whose lanterns are rarely lit, playing it a quarter as often or less. At 16 damage it took the Lantern from the worst way to the best; at 12 it sits level with Shatter at V0 full on the merge base (47.5% each) and under the adaptive arm on the standard seeds, though level with it over 300. Edge lacked staying power, and no single Edge card found it without also feeding the adaptive arm's Edge decks, which already win 91% of its victories at V0 full; three tries moved its deaths from one act to the next and the best of them lifted it 4.0 pp, so Edge ships nothing. On the experiments' base the two cards cost Edge about 7 pp at V0 full, because two new commons that are not Edge thin an offer that was 56% Edge; on the merge base, after #599, Edge holds level (22.3% to 21.3%). With Hearthfall at 12, G2 still widens, but only because Edge stays behind two ways that rose (26.0 pp at V0 full, where Shatter and the Lantern are level), G3 passes at V0 full, and R rises about 4-7 pp, while G5 and G6, the gates that read whether the flame's ways are reachable and whether different runs are different, improve: Steady by the end of Act 1 rises in every cell, and the leading way's share of A's wins falls in every cell with at least 30 of them. The game is now harder for an insisting Edge player than for any other, with Shatter and the Lantern as two ways of like strength; that is now the owner's to feel, not the pilot's to settle.

**Shipped:** Shatter, S2 (Spall 璃屑, common attack, 1 Energy: deal 5, chip 1 extra Facet; upgraded 8). Lantern, L4 (Hearthfall 爐火墜, common attack, 0 Energy and 3 Embers: deal 12; upgraded 16). L3, the same card at 16 (21), was measured and not shipped: it overshot.

**Dropped:** Edge. E1 +0.5 pp, E2 +1.0 pp, E3 +4.0 pp at V0 full, each under the 5 pp line, and each raised the leading way's share of A's wins (by 2.6, 7.7 and 5.1 pp pooled); on the merge base E1 +4.0, E2 +6.5 and E3 +7.5 pp, with that share up 2.7, 3.9 and 4.5 pp.

**If the owner wants to turn something after playing,** there is one number per card and no knob: Hearthfall's damage (16 is L3, the overshoot; 12 is L4) or its Energy (1 is L2, no lift); Spall is already the weaker of the two measured. Nothing here re-tunes an enemy, the lantern, the Soot tier, the splash policy or a gate.

## Appendix A: the catalogue script

`make_candidates.py`, kept in the private scratch folder and reproduced here. It refuses any input but the shipped catalogue, checks that its JSON round trip reproduces the file byte for byte, and writes one copy per candidate; `a+b` applies both candidates to one copy.

```python
#!/usr/bin/env python3
"""Readout 7: write the scratch catalogues for each way's wall candidates.

Research only. Reads the shipped catalogue, never writes it, and writes one copy
per candidate into OUT_DIR with the same JSON layout (the round trip of the
shipped file is checked first). Usage: make_candidates.py CONTENT_JSON OUT_DIR [NAME ...]
"""
from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path

SHIPPED_SHA256 = "d3b8adcb1882b85c453e3ff07ee36eb2232dea9b1a8c5068cc9f8ad5f382910d"


def dump(data: dict) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def way(data: dict, way_id: str) -> dict:
    return next(w for w in data["aspects"][0]["ways"] if w["id"] == way_id)


def add_card(data: dict, card_id: str, card: dict, way_id: str, weight: float = 1.0,
             pool: str | None = None) -> None:
    """A Duskblade-only card: its pool entry, its affinity, and the Ashwarden's exclusion."""
    assert card_id not in data["cards"], card_id
    data["cards"][card_id] = card
    data["cardPools"][pool or card["rarity"]].append(card_id)
    way(data, way_id)["affinity"][card_id] = weight
    data["aspects"][1]["excludes"]["cards"].append(card_id)


# ---------------------------------------------------------------- Shatter
SPALL = {"type": "attack", "rarity": "common", "cost": 1, "target": "enemy", "chip": 1, "vfx": "pierce",
         "effects": [{"kind": "dmg", "n": 6}],
         "up": {"effects": [{"kind": "dmg", "n": 9}], "text": "Deal @9@ damage. Chip 1 extra Facet."},
         "name": "Spall", "text": "Deal @6@ damage. Chip 1 extra Facet."}


def s1(data: dict) -> None:
    """Shatter's supply: one common of its own (a Chisel for the reward screen)."""
    add_card(data, "spall", copy.deepcopy(SPALL), "shatter")


# ---------------------------------------------------------------- Lantern
EMBERCUT = {"type": "attack", "rarity": "common", "cost": 1, "target": "enemy", "vfx": "fire",
            "effects": [{"kind": "dmg", "n": 6}, {"kind": "ember", "n": 1}],
            "up": {"effects": [{"kind": "dmg", "n": 9}, {"kind": "ember", "n": 1}],
                   "text": "Deal @9@ damage. Gain 1 Ember."},
            "name": "Cinder Cut", "text": "Deal @6@ damage. Gain 1 Ember."}


def l1(data: dict) -> None:
    """Lantern's Act-1 damage: one common attack that feeds the lantern."""
    add_card(data, "cinderCut", copy.deepcopy(EMBERCUT), "lantern")


# ---------------------------------------------------------------- Edge
def e1(data: dict) -> None:
    """Edge's defence: Eclipse Step's Ward 5 -> 8 (upgraded 8 -> 11)."""
    card = data["cards"]["eclipseStep"]
    card["effects"][0]["n"] = 8
    card["up"]["effects"][0]["n"] = 11
    card["text"] = card["text"].replace("#5#", "#8#")
    card["up"]["text"] = card["up"]["text"].replace("#8#", "#11#")


def s2(data: dict) -> None:
    """S1 with Spall at 5 damage (upgraded 8): is the lift supply or power?"""
    card = copy.deepcopy(SPALL)
    card["effects"][0]["n"] = 5
    card["up"]["effects"][0]["n"] = 8
    card["text"] = "Deal @5@ damage. Chip 1 extra Facet."
    card["up"]["text"] = "Deal @8@ damage. Chip 1 extra Facet."
    add_card(data, "spall", card, "shatter")


HEARTHFALL = {"type": "attack", "rarity": "common", "cost": 1, "emberCost": 3, "target": "enemy", "vfx": "fire",
              "effects": [{"kind": "dmg", "n": 16}],
              "up": {"effects": [{"kind": "dmg", "n": 21}], "text": "Spend 3 Embers: deal @21@ damage."},
              "name": "Hearthfall", "text": "Spend 3 Embers: deal @16@ damage."}


def l2(data: dict) -> None:
    """Lantern's payoff in Act 1: a common blow paid in Embers (the Flare in card form)."""
    add_card(data, "hearthfall", copy.deepcopy(HEARTHFALL), "lantern")


def e2(data: dict) -> None:
    """Edge's defence within reach: Eclipse Step common, Ward 5 -> 7 (upgraded 8 -> 10)."""
    card = data["cards"]["eclipseStep"]
    card["rarity"] = "common"
    card["effects"][0]["n"] = 7
    card["up"]["effects"][0]["n"] = 10
    card["text"] = card["text"].replace("#5#", "#7#")
    card["up"]["text"] = card["up"]["text"].replace("#8#", "#10#")
    data["cardPools"]["uncommon"].remove("eclipseStep")
    data["cardPools"]["common"].append("eclipseStep")


def l3(data: dict) -> None:
    """L2 with Hearthfall at no Energy: the lantern's Embers alone pay for the blow."""
    card = copy.deepcopy(HEARTHFALL)
    card["cost"] = 0
    add_card(data, "hearthfall", card, "lantern")


def e3(data: dict) -> None:
    """Edge's defence at common, its utility at uncommon, and a capstone that finishes.

    Eclipse Step common with Ward 7 (upgraded 10); Dim the Glass uncommon, so the
    way's common supply keeps its size; Totality 14 -> 20 damage (upgraded 18 -> 26).
    """
    e2(data)
    data["cards"]["dimTheGlass"]["rarity"] = "uncommon"
    data["cardPools"]["common"].remove("dimTheGlass")
    data["cardPools"]["uncommon"].append("dimTheGlass")
    card = data["cards"]["totality"]
    card["effects"][0]["n"] = 20
    card["up"]["effects"][0]["n"] = 26
    card["text"] = card["text"].replace("@14@", "@20@")
    card["up"]["text"] = card["up"]["text"].replace("@18@", "@26@")


CANDIDATES = {"s1": s1, "l1": l1, "e1": e1, "s2": s2, "l2": l2, "e2": e2, "l3": l3, "e3": e3}


def main(argv: list[str]) -> int:
    source, out_dir = Path(argv[1]), Path(argv[2])
    names = argv[3:] or list(CANDIDATES)
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SHIPPED_SHA256:
        raise SystemExit("not the shipped catalogue")
    shipped = json.loads(raw)
    if dump(shipped).encode() != raw:
        raise SystemExit("round trip does not reproduce the shipped file")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in names:
        data = copy.deepcopy(shipped)
        for step in name.split("+"):
            CANDIDATES[step](data)
        text = dump(data).encode()
        path = out_dir / f"{name}.json"
        path.write_bytes(text)
        print(name, hashlib.sha256(text).hexdigest(), path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```
