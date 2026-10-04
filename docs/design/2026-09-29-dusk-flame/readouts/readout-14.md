# Readout 14: the 1.1 instrument's requalification of the Duskblade

> **The 1.1 instrument's requalification reading (AI-SDLC discovery), not a verdict and not a balance change.** #544's plan of record, step P6 (decision 4, "instrument first"): the bots learn the Ashwarden's Hand way, as search player `s2` and pilot `p9`, and the Duskblade is re-read under them as its 1.1 requalification. **Readout 13 stays 1.0's reading of record**, played by pilot `p8-d0-v3` and search player `s1`, which stay selectable, byte-identical and the tools' default. **No content changed**: `content/full-content.json` is readout 13's, SHA-256 `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`. No domain rule, id, rider, lantern knob, enemy number, save field, RNG draw or `port_fixtures/` golden moved. The readout itself gives no verdict: it ends with what the orchestrator must decide, and the orchestrator's ruling follows as its last section.
>
> **Head.** Every report ran at `516be99f`, in a detached worktree, and every report's manifest names it, with pilot `p9` and search `s2` (the Ashwarden's `s1` panel names `p8-d0-v3` and `s1`). The branch was then rebased onto `main` (`94303de9`, #544 P3's squash), which carried `516be99f` to `cd5908f9`; `git diff 516be99f HEAD -- tools domain content` is empty. Later commits fix a test's order dependence and add documents only.

The Duskblade's verdict of record was given on readout 13, played by bots that could not play a hand-size way: the search player ended every line at a draw and scored nothing for it, and the pilot valued the one hand-size payoff, Phantom Blades, at a flat weight. The Ashwarden's Hand way makes that payoff a way's identity, so the bots learn it before any Ashwarden reading counts (#544 decision 4). The change is class-neutral, so the Duskblade is read again under the new bots, on readout 13's seeds and content, as its 1.1 requalification (`docs/rc-bar.md` P9, *Scope per shipped class*).

## The answer in brief

- **The bots.** Search `s2` scores a line that ends at a draw as a turn that continues: it credits the hand-size payoff the bigger hand pays and half the expected worth of the cards drawn, read from the pile they came from. Pilot `p9` values Phantom Blades by the hand its deck deals and scores 0 for a rider its class cannot light. On three Ashwarden probes checked by hand, `s2`/`p9` finds all three lines and `s1`/`p8-d0-v3` misses the two that turn on the payoff. `s2` costs what `s1` does: 3.52 against 3.55 s a run at V0 on the same seeds.
- **The instrument alone moves the Duskblade little.** Paired run for run against readout 13's reports, no arm moves significantly in any of the four cells (24 arm-cell pairs, every p ≥ 0.07). The largest moves are the committed Lantern at V0 fresh (+2.5 pp, p = 0.16) and V0 full (−2.1 pp, p = 0.28). The only significant move is the committed Lantern at V5 full on G3's 4,000 common seeds: +1.7 pp (p = 0.01), coming from the second band. The decks hold fewer Phantom Blades (at V0 fresh, committed Shatter 0.92 → 0.56 a run, Edge 0.92 → 0.44): `p9` values it at about 12 in a Duskblade deck, against the flat 14.4.
- **Three graded figures change class against readout 13.** G2 at V0 fresh widens from 12.8 pp (Lantern − Shatter; FAIL on point, UNDECIDED on interval) to 16.8 pp (Lantern − Edge, +12.9 to +20.6): **a decided FAIL**. G3 at V0 fresh moves from PASS on point (−1.6 pp) to **FAIL on point** (−5.1 pp; paired −9.0 to −1.2, UNDECIDED). G3 at V5 full moves the other way, from FAIL on point (−3.5 pp on 4,000 common seeds) to **PASS on point** (−2.6 pp, −4.1 to −1.1, UNDECIDED). On common seeds the three gaps moved by +4.4 pp (+0.2 to +8.6), −3.5 pp (−8.1 to +1.1) and +0.9 pp (−0.5 to +2.3).
- **What holds.** G2 at V0 full (9.7 pp, PASS on point), G5 in every graded cell on point and interval, G6 for A_lit in every cell, G7 (no stall or error in 44,012 runs; every replay identical), B1 for every committed way in both pools. B2's committed rows at V0 fresh move from UNDECIDED to PASS. A_lit's own feel at V0 fresh stays a decided FAIL (58.5%).
- **The Ashwarden (development seeds, not of record).** Under `s2`/`p9` its commit-blind arm wins more in all four cells, +2.0 to +7.0 pp, pooled 109 seeds gained and 72 lost (p = 0.007).

## The question

Can the bots play the Ashwarden's verbs, above all the hand-size payoff, on fights whose best line is known? And with only the instrument changed, what does the Duskblade's complete §11 table read on readout 13's seeds and content: which arms move, and which figures of the graded gates and readings change class?

## The instrument

### What changed in the bots

Two new bots, chosen per run: `tools/balance_sim.gd` takes `--pilot` and `--search`, writes both into every report's manifest (`pilot`, `search.version`), and refuses an unknown one or a search player named for greedy play. The readout runner and the grader pass both to every simulator command they launch, and the grader refuses a table whose reports name more than one pair. Unnamed, the bots are 1.0's: pilot `p8-d0-v3` and search `s1`.

**Search `s2`** (`tools/balance_search.gd`). A line still ends at the action that draws or rolls the RNG, and the search still never reads a card it has not drawn. What changes is how such a line is scored. `s1` scores it as if the turn ended there, so a draw is worth nothing and every card still in hand is worth nothing; the player re-plans once the draw resolves, so that is not the turn's end. `s2` scores it as the turn's end here, plus two credits (`_continued`):

- **The hand-size payoff.** If a card in hand reads the hand's size (Phantom Blades: 3 damage, 4 upgraded, for each card left in hand once it is played), `s2` plays it on a copy of the position and keeps the better of the two scores. The hand's size after a draw is known; its new cards are not, and the payoff reads only the size.
- **The draw.** Half (the evaluation's setup share, 0.5) of the expected worth of the cards the action drew. Each is a card of the multiset it came from: the draw pile before the action (all of it, if the action drew more), then the discard pile that was shuffled in. A card is worth the pilot's catalogue score, never below 0 (it need not be played), and 0 when the Energy and Embers left after the payoff cannot pay for it.

Everything else is `s1`'s: the line cap (2,000), the evaluation's weights, the greedy turn as a floor, and the one kindle it tries.

**Pilot `p9`** (`tools/balance_pilot.gd`). Two scores change; everything else is `p8-d0-v3`'s, the committed bot's seed removal and its two-copy cap included.

- **A hand-size payoff is valued by the hand the deck deals.** `p8-d0-v3` scores Phantom Blades at the flat `leech` weight (14.4). `p9` scores it at 3 for each card beside it in the hand the deck is expected to deal: the turn's five cards, plus what each draw card in the deck adds (its draws less itself), each dealt at the rate five cards of the deck are, within the cap of 10 (`expected_hand`). With the Ashwarden's starter that is 5, so 12; three Tinders in a 13-card deck make it 6.15, so 15.5. The bot reads it before every build decision, as it reads its flame (`see_flame`).
- **A rider its class cannot light scores 0** (#544 decision 3, the instrument's side). `p8-d0-v3` counts every `lit` rider at `crackedShare` (0.5) unless the score assumes its colour lit. `p9` counts a rider of a way the run's class does not have at 0: it can never resolve. For the Duskblade every rider names one of its ways, so this changes nothing there; for the Ashwarden, which declares no ways yet, Tinder's, Struck Match's and Tithe of Panes' amber Ember stops counting.

**Considered and not built.** The audit suggested trying several kindle candidates rather than the pilot's one. On 40 development seeds per class (V0 full, arm A), three candidates took 1.6–2.1 times `s1`'s time per turn, for a change in wins within noise (Duskblade 11 of 40 with one candidate or three; Ashwarden 19 against 20). The evaluation charges nothing for the card a kindle burns from the rest of the fight, so a wider choice of what to burn is not a more honest one. `s2` keeps `s1`'s kindle.

### The probes

`tests/test_balance_bots_hand.gd` plays one turn from three fixed Ashwarden positions whose best line can be checked by hand, as the simulator plays it (potions, then the search's plans and re-plans), under the 1.1 bots and under 1.0's. The hero has 30 HP; one Sporeling stands opposite; the draw pile is six Defends, so what a draw brings is known.

| Probe | Position | Best line, by hand | `s2` / `p9` | `s1` / `p8-d0-v3` |
|---|---|---|---|---|
| Draw, then Phantom Blades with the bigger hand | Energy 3; hand Tinder, Phantom Blades, three Defends; the Sporeling at 15 HP, its blow 40 | Tinder (draw 2), then Phantom Blades with five cards beside it: 15 damage, the fight won. Phantom Blades first deals 12 | Tinder, Phantom Blades: won | three Defends, Tinder, a kindle: the Sporeling untouched |
| A Struck Match line into the payoff | Energy 0; hand Struck Match, Phantom Blades, three Defends; the Sporeling at 12 HP, its blow 40 | Struck Match (1 Energy, draw 1), then Phantom Blades with four beside it: 12, the fight won | Struck Match, Phantom Blades: won | Struck Match, a Defend, a kindle: untouched |
| Stack Smolder, then Bellows | Energy 3; hand Bellows, Ashbite, three Defends; the Sporeling at 500 HP with 3 Smolder and no blow | Ashbite (5 Smolder), then Bellows (doubles it): 10. Bellows first: 8 | Ashbite, Bellows: 10 Smolder | Ashbite, Bellows: 10 Smolder |

`s1` misses both payoff probes, the blind spot being fixed: a line that plays the draw first ends at the draw and scores nothing for it, and the greedy turn it falls back to blocks first against a lethal blow. Both find the Smolder line, which needs no draw: the guard that `s2` keeps what `s1` already played.

**Mutants** (each file backed up and copied back, never `git checkout --`):

- `s2` without the payoff credit (`_continued` never keeps the paid position): both payoff probes fail for `s2`.
- `s2` without the draw credit (`_draw_worth` returns 0): the draw-worth check fails (0 against 11.62 for two Strikes from a pile of two and one card of a Defend and an Ashbite, with 1 Energy left, the Ashbite counting 0).
- `p9` with the flat payoff weight: the payoff check fails (20.36 in every deck against 17.99 with the starter and 21.45 with three Tinders).
- `p9` scoring a foreign rider at `crackedShare`: the rider check fails (Tinder 25.75 for the Ashwarden under both pilots, against 24.66 under `p9`).

The file also checks the simulator's flags (unnamed bots are 1.0's; `--pilot p9 --search s2` reach the manifest; an unknown bot, or `--search s2` with greedy play, is refused).

### The default stays 1.0's

The tools' default stays pilot `p8-d0-v3` and search `s1`, 1.0's instrument of record. The 1.0 release candidate's independent re-run is the one pending run that P9 binds to these tools. Every command recorded in readouts 8–13 and in readout 13's reproduction still plays 1.0's instrument as written, and every test that runs the bots unnamed (`test_balance_sim`, `test_balance_search`, the arms' tests) still plays 1.0's. The re-run still names its bots: `docs/rc-bar.md` P9 now requires `--pilot p8-d0-v3 --search s1`, whatever the default. Every Ashwarden reading names `--pilot p9 --search s2`. Every simulator command the runner and the grader launch names its pilot (and, under `--play search`, its search player), every report's manifest names both, the grader prints them in its header and refuses a table that mixes them, so a run without the 1.1 bots cannot pass for one.

### Cost

The search budget is `s1`'s: at most 2,000 lines a plan.

| Comparison | `s1` | `s2` |
|---|---|---|
| 40 development seeds per class, V0 full, arm A, both run at the same time | Duskblade 28.9 ms a turn; Ashwarden 25.0 ms | Duskblade 28.2 ms; Ashwarden 27.9 ms |
| The V0 table, 13000–13999, 12,006 runs, eight jobs (`s1`: #544 P2's re-run of readout 13) | 3.55 s a run per process, 5,364 s of wall | 3.52 s, 5,326 s |
| The V5 table, 13000–14999, 24,006 runs | 1.62 s, 4,885 s | 1.66 s, 5,022 s |
| Three kindle candidates (considered, not built) | | Duskblade 45.6 ms a turn; Ashwarden 52.4 ms |

The table runs were on the same shared host on the same day under heavy but different loads (this reading's load average ran from 65 to above 700), so they say only that the two cost about the same. Readout 13 measured 1.7–1.8 s a run on a lightly loaded host.

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-balance-p6", never committed.
# The tables, from a detached worktree at 516be99f (no commit during the run, so every chunk names one commit):
python3 -B tools/balance_readout.py run s/s2-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --pilot p9 --search s2 --replay --jobs 8
python3 -B tools/balance_readout.py run s/s2-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --pilot p9 --search s2 --replay --jobs 8
python3 -B tools/balance_readout.py run s/s2-ext-v5 --seeds 15000-16999 --cells v5-full --arms C_shatter,C_lantern,C_edge,A_lit --play search --pilot p9 --search s2 --jobs 8
python3 -B tools/balance_readout.py join s/s2-g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/s2-v5 s/s2-ext-v5
# The Ashwarden's development reading, under both instruments:
python3 -B tools/balance_readout.py run s/ash-s1 --aspect ashwarden --seeds 12000-12199 --cells v0-entry,v0-full,v5-entry,v5-full --play search --pilot p8-d0-v3 --search s1 --jobs 8
python3 -B tools/balance_readout.py run s/ash-s2 --aspect ashwarden --seeds 12000-12199 --cells v0-entry,v0-full,v5-entry,v5-full --play search --pilot p9 --search s2 --jobs 8
# Grading against readout 13's own reports (r13/final-v0, final-v5, ext-v5 and g3-4000: #544 P2's archive copies,
# which P2's re-run matched row for row):
python3 -B tools/balance_readout.py paired s/s2-v0 r13/final-v0 v0-fresh,v0-full      # and s2-v5, s2-ext-v5, s2-g3-4000
python3 -B tools/balance_readout.py table s/s2-v0 s/s2-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999 \
    --ref r13/final-v0 r13/final-v5 --tidy
python3 -B tools/balance_readout.py g3 s/s2-v5 v5-fresh,v5-full; python3 -B tools/balance_readout.py g3 s/s2-g3-4000 v5-full
python3 -B tools/balance_readout.py rowb s/s2-v0 --ref r13/final-v0
python3 -B tools/balance_ways.py --from-dir s/s2-v0 --seeds 13000-13999 --vows 0   # and s2-v5 at --vows 5
python3 -B instr14.py s/s2-v0 r13/final-v0 v0-fresh,v0-full; python3 -B gapchange.py ...; python3 -B ash14.py s/ash-s2 s/ash-s1
```

- **Cells, arms, seeds.** Readout 13's: the Duskblade, V0 on 13000–13999 (1,000 paired seeds a cell) and V5 on 13000–14999 (2,000), fresh and full pools, the six arms C_shatter, C_lantern, C_edge, A, A_lit and R, with arm A's three-seed replay per cell; G3 at V5 full also on 15000–16999, so on 4,000 common seeds. Every run pairs with readout 13's run on its seed.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference of independent rates), G5 over the runs alive at the act's end; paired changes, the seeds one instrument wins and the other loses, with the exact two-sided binomial p; G3 on common seeds with Newcombe's paired interval; row B as readouts 8–13 compute it. How a gap moved between the instruments is read per seed, (a − b) under `s2` less (a − b) under `s1`, with a normal 95% interval.
- **Budget and stop rule.** One reading, no candidates, nothing tuned: the instrument was fixed, its tools committed and gated, before the first run.
- **Wall time.** 13,319 s (3 h 42 min, 18:17 to 21:59 UTC on 4 October 2026) for 48,812 runs on eight jobs: the Ashwarden 403 s and 540 s, V0 5,326 s, V5 5,022 s, the second band 2,028 s.

## The instrument alone, paired against readout 13

Readout 13's reports against `s2`/`p9` on the same seeds and content. Win: readout 13 → this reading, with the paired change (seeds gained / lost, exact p). Steady and True are over all runs and, in brackets, over the runs alive at that act's end (G5's denominator). Phantom Blades held at run end and played a run; draw cards (Tinder, Struck Match, First Spark, Flicker, Glasstep, Refract, Tithe of Panes, Dim the Glass, Pyre Tithe) played a run; turns and HP lost a fight.

| Cell | Arm | Win, r13 → r14 (paired) | Steady by end of Act 1 (of alive) | True by end of Act 2 (of alive) | Phantom Blades held / played | Draw cards played | Turns / HP lost a fight |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 20.8 → 20.2% (−0.6 pp, p = 0.63; 51 / 57) | 78.0 (95.4) → 79.1 (96.0)% | 49.7 (94.1) → 49.7 (94.7)% | 0.92 / 4.49 → 0.56 / 2.78 | 11.0 → 11.6 | 3.18 / 9.54 → 3.17 / 9.52 |
| V0 fresh | C_lantern | 33.6 → 36.1% (+2.5 pp, p = 0.16; 159 / 134) | 46.8 (74.3) → 48.8 (74.5)% | 31.6 (65.4) → 32.7 (63.6)% | 0.65 / 5.52 → 0.61 / 5.55 | 58.1 → 61.5 | 3.51 / 10.62 → 3.50 / 10.59 |
| V0 fresh | C_edge | 21.2 → 19.3% (−1.9 pp, p = 0.16; 74 / 93) | 66.0 (80.7) → 65.7 (81.2)% | 22.9 (52.6) → 21.7 (54.1)% | 0.92 / 5.26 → 0.44 / 2.62 | 17.9 → 18.4 | 3.40 / 10.37 → 3.41 / 10.42 |
| V0 fresh | A | 24.1 → 26.0% (+1.9 pp, p = 0.26; 135 / 116) | - | - | 0.55 / 3.41 → 0.37 / 2.25 | 34.4 → 36.1 | 3.38 / 9.68 → 3.38 / 9.57 |
| V0 fresh | A_lit | 32.0 → 31.0% (−1.0 pp, p = 0.58; 129 / 139) | - | - | 0.69 / 4.25 → 0.43 / 2.70 | 36.4 → 37.4 | 3.35 / 9.17 → 3.35 / 9.21 |
| V0 fresh | R | 7.1 → 7.3% (+0.2 pp, p = 0.90; 32 / 30) | - | - | 0.47 / 2.96 → 0.46 / 3.06 | 17.4 → 17.9 | 3.21 / 11.07 → 3.20 / 11.03 |
| V0 full | C_shatter | 49.3 → 49.7% (+0.4 pp, p = 0.82; 89 / 85) | 80.5 (91.6) → 81.7 (91.8)% | 64.7 (88.4) → 65.5 (88.9)% | 0.29 / 1.69 → 0.22 / 1.43 | 16.1 → 16.8 | 3.24 / 9.04 → 3.24 / 9.12 |
| V0 full | C_lantern | 47.6 → 45.5% (−2.1 pp, p = 0.28; 160 / 181) | 68.0 (89.6) → 66.6 (89.2)% | 53.9 (87.6) → 55.2 (89.9)% | 0.17 / 1.73 → 0.16 / 1.62 | 76.1 → 76.2 | 3.30 / 12.17 → 3.29 / 12.02 |
| V0 full | C_edge | 39.6 → 40.0% (+0.4 pp, p = 0.84; 109 / 105) | 85.4 (92.7) → 85.7 (92.8)% | 56.0 (87.8) → 57.1 (88.0)% | 0.22 / 1.45 → 0.16 / 1.14 | 24.5 → 24.9 | 3.24 / 10.03 → 3.23 / 9.89 |
| V0 full | A | 38.8 → 40.6% (+1.8 pp, p = 0.30; 143 / 125) | - | - | 0.20 / 1.46 → 0.13 / 1.05 | 45.7 → 48.3 | 3.44 / 11.29 → 3.43 / 11.28 |
| V0 full | A_lit | 47.1 → 47.7% (+0.6 pp, p = 0.76; 138 / 132) | - | - | 0.20 / 1.43 → 0.14 / 1.12 | 44.4 → 46.1 | 3.35 / 10.49 → 3.33 / 10.40 |
| V0 full | R | 17.6 → 19.9% (+2.3 pp, p = 0.07; 84 / 61) | - | - | 0.25 / 1.84 → 0.24 / 1.93 | 25.7 → 27.1 | 3.18 / 10.61 → 3.17 / 10.47 |
| V5 fresh | C_shatter | 1.2 → 1.2% (+0.1 pp, p = 1.00; 12 / 11) | 31.4 (97.8) → 30.2 (98.1)% | 8.6 (95.6) → 7.5 (94.3)% | 0.80 / 3.17 → 0.56 / 2.22 | 6.8 → 7.0 | 3.15 / 11.72 → 3.16 / 11.71 |
| V5 fresh | C_lantern | 3.8 → 3.6% (−0.2 pp, p = 0.78; 55 / 59) | 16.0 (87.4) → 15.9 (89.1)% | 6.1 (63.9) → 6.5 (71.7)% | 0.69 / 4.29 → 0.59 / 3.81 | 22.7 → 23.4 | 3.45 / 12.78 → 3.45 / 12.81 |
| V5 fresh | C_edge | 1.5 → 0.9% (−0.5 pp, p = 0.12; 12 / 22) | 24.4 (79.1) → 24.2 (78.7)% | 2.5 (40.2) → 2.0 (44.9)% | 0.75 / 3.66 → 0.48 / 2.43 | 10.0 → 10.5 | 3.33 / 12.28 → 3.35 / 12.35 |
| V5 fresh | A | 2.0 → 2.2% (+0.2 pp, p = 0.60; 32 / 27) | - | - | 0.57 / 2.63 → 0.34 / 1.59 | 15.8 → 16.1 | 3.36 / 12.09 → 3.36 / 12.08 |
| V5 fresh | A_lit | 3.5 → 3.8% (+0.2 pp, p = 0.67; 46 / 41) | - | - | 0.65 / 3.13 → 0.41 / 1.96 | 16.1 → 16.6 | 3.35 / 11.78 → 3.36 / 11.76 |
| V5 fresh | R | 0.4 → 0.4% (−0.1 pp, p = 0.79; 6 / 8) | - | - | 0.45 / 2.10 → 0.45 / 2.13 | 10.9 → 11.1 | 3.14 / 12.49 → 3.13 / 12.51 |
| V5 full | C_shatter | 17.3 → 16.7% (−0.7 pp, p = 0.36; 80 / 93) | 48.9 (92.7) → 49.3 (93.0)% | 26.2 (88.2) → 26.5 (87.3)% | 0.28 / 1.67 → 0.22 / 1.38 | 10.7 → 11.2 | 3.29 / 11.49 → 3.30 / 11.54 |
| V5 full | C_lantern | 12.2 → 13.4% (+1.1 pp, p = 0.21; 164 / 141) | 36.1 (92.6) → 37.7 (94.0)% | 18.4 (88.7) → 20.2 (88.2)% | 0.21 / 1.75 → 0.19 / 1.79 | 35.3 → 37.9 | 3.33 / 14.35 → 3.34 / 14.29 |
| V5 full | C_edge | 12.2 → 11.8% (−0.4 pp, p = 0.53; 78 / 87) | 54.5 (92.6) → 54.4 (92.1)% | 20.0 (82.3) → 19.4 (79.0)% | 0.21 / 1.11 → 0.17 / 0.92 | 16.1 → 16.5 | 3.28 / 12.25 → 3.27 / 12.23 |
| V5 full | A | 11.8 → 10.7% (−1.1 pp, p = 0.18; 103 / 124) | - | - | 0.20 / 1.30 → 0.10 / 0.63 | 23.3 → 24.3 | 3.44 / 13.16 → 3.43 / 13.16 |
| V5 full | A_lit | 13.8 → 14.5% (+0.8 pp, p = 0.37; 128 / 113) | - | - | 0.20 / 1.27 → 0.12 / 0.73 | 23.3 → 25.3 | 3.41 / 12.65 → 3.42 / 12.65 |
| V5 full | R | 3.9 → 4.7% (+0.9 pp, p = 0.07; 47 / 30) | - | - | 0.22 / 1.35 → 0.22 / 1.34 | 14.9 → 15.7 | 3.19 / 12.60 → 3.19 / 12.57 |

G3's second band at V5 full, 15000–16999, paired the same way: C_shatter +0.9 pp (101 / 83, p = 0.21), **C_lantern +2.1 pp (170 / 127, p = 0.01)**, C_edge +1.1 pp (101 / 78, p = 0.10), A_lit +1.3 pp (130 / 104, p = 0.10). On the 4,000 seeds together: C_shatter +0.1 pp (p = 0.83), **C_lantern +1.7 pp (334 / 268, p = 0.01)**, C_edge +0.4 pp (p = 0.48), A_lit +1.0 pp (258 / 217, p = 0.07).

What the instrument alone moved:

1. **Little, and nowhere significantly in the table.** All 24 arm-cell pairs of the table have p ≥ 0.07; the largest is the committed Lantern at V0 fresh, +2.5 pp (p = 0.16). Between 4% and 50% of each arm's runs are byte-identical to readout 13's (at V0 full the Lantern 42 of 1,000, at V5 fresh Shatter 991 of 2,000): wherever no draw ends a line and no Phantom Blades is offered, `s2`/`p9` plays as `s1`/`p8-d0-v3` does.
2. **One arm moves on the longer band.** The committed Lantern at V5 full gains 1.7 pp on 4,000 seeds (p = 0.01): +1.1 pp (p = 0.21) on the table's band, +2.1 pp (p = 0.01) on the second. With 28 paired tests this is the only one under 0.05.
3. **Fewer Phantom Blades.** Every arm but R holds fewer at run end, most in the fresh pool (committed Shatter 0.92 → 0.56, Edge 0.92 → 0.44, A 0.55 → 0.37 at V0 fresh): a Duskblade deck draws few extra cards, so `p9` values the payoff at about 12 instead of 14.4. R builds at random and holds the same.
4. **A few more draws played, the same fights.** Draw cards played a run rise by 0.1–3.4 (the Lantern most, with Tinder and Struck Match), as `s2` no longer leaves a draw for last. Turns and HP lost a fight move by 0.15 at most.
5. **Reach hardly moves.** Over survivors, Steady by the end of Act 1 and True by the end of Act 2 move by 2.3 pp at most, except Edge's True at V5 full (82.3 → 79.0% of 491, G5's minimum there, still PASS on point and interval) and, in the ungraded V5 fresh cell, the Lantern's True (63.9 → 71.7% of 180) and Edge's (40.2 → 44.9% of 89).

## The complete §11 table under `s2`

### Win rates, search player `s2`, pilot `p9`

Wilson 95% intervals. Readout 13's figure is in brackets.

| Cell | C_shatter | C_lantern | C_edge | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 fresh | 20.2% (17.8–22.8) [20.8%] | 36.1% (33.2–39.1) [33.6%] | 19.3% (17.0–21.9) [21.2%] | 26.0% (23.4–28.8) [24.1%] | 31.0% (28.2–33.9) [32.0%] | 7.3% (5.8–9.1) [7.1%] |
| V0 full | 49.7% (46.6–52.8) [49.3%] | 45.5% (42.4–48.6) [47.6%] | 40.0% (37.0–43.1) [39.6%] | 40.6% (37.6–43.7) [38.8%] | 47.7% (44.6–50.8) [47.1%] | 19.9% (17.5–22.5) [17.6%] |
| V5 fresh | 1.2% (0.8–1.8) [1.2%] | 3.6% (2.9–4.5) [3.8%] | 0.9% (0.6–1.5) [1.5%] | 2.2% (1.7–3.0) [2.0%] | 3.8% (3.0–4.7) [3.5%] | 0.4% (0.2–0.7) [0.4%] |
| V5 full | 16.7% (15.1–18.3) [17.3%] | 13.4% (11.9–14.9) [12.2%] | 11.8% (10.5–13.3) [12.2%] | 10.7% (9.4–12.1) [11.8%] | 14.5% (13.1–16.2) [13.8%] | 4.7% (3.9–5.7) [3.9%] |

### The gates

Every gate in every cell, point and 95% interval, against readout 13's verdicts. **Bold** marks a verdict that differs from readout 13's. G1 and G4 are readings (owner ruling of 30 September); the floor rows are arm A's, reported.

| Cell | Gate | Measured | Point | 95% interval | Interval | Readout 13 (point / interval) |
|---|---|---|---|---|---|---|
| V0 fresh | G1 | worst C_edge 19.3% | FAIL | worst C_edge 19.3% (17.0–21.9%, n=1000) | FAIL | FAIL / FAIL |
| V0 fresh | G2 | 16.8 pp (C_lantern − C_edge) | FAIL | C_lantern − C_edge +16.8 pp (+12.9 to +20.6, n=1000+1000) | **FAIL** | FAIL / UNDECIDED |
| V0 fresh | G3 | A_lit 31.0% vs best 36.1% (−5.1 pp) | **FAIL** | A_lit − C_lantern -5.1 pp (-9.2 to -1.0, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 fresh | G4 | R 7.3% vs worst 19.3% (−12.0 pp) | FAIL | R − C_edge -12.0 pp (-14.9 to -9.1, n=1000+1000); R 7.3% (5.8–9.1%, n=1000) | FAIL | FAIL / FAIL |
| V0 fresh | G5 | Steady by end of Act 1 min 74.5% of runs alive (C_lantern; all runs 48.8%); True by end of Act 2 min 54.1% of runs alive (C_edge; all runs 21.7%) | PASS | Steady min C_lantern 74.5% (71.0–77.7%, n=655 alive) | PASS | PASS / PASS |
| V0 fresh | G6 | shatter 30.0%, lantern 28.1%, edge 41.9% of 310 A_lit wins | PASS | lead edge 41.9% (36.6–47.5%, n=310 A_lit wins) | PASS | PASS / PASS |
| V0 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 fresh | G3 floor (A) | A 26.0% vs best 36.1% (−10.1 pp) | FAIL | A − C_lantern -10.1 pp (-14.1 to -6.1, n=1000+1000) | FAIL | FAIL / FAIL |
| V0 fresh | G6 floor (A) | shatter 36.9%, lantern 18.8%, edge 44.2% of 260 A wins | PASS | lead edge 44.2% (38.3–50.3%, n=260 A wins) | PASS | PASS / PASS |
| V0 full | G1 | worst C_edge 40.0% | FAIL | worst C_edge 40.0% (37.0–43.1%, n=1000) | FAIL | FAIL / FAIL |
| V0 full | G2 | 9.7 pp (C_shatter − C_edge) | PASS | C_shatter − C_edge +9.7 pp (+5.3 to +14.0, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G3 | A_lit 47.7% vs best 49.7% (−2.0 pp) | PASS | A_lit − C_shatter -2.0 pp (-6.4 to +2.4, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G4 | R 19.9% vs worst 40.0% (−20.1 pp) | FAIL | R − C_edge -20.1 pp (-24.0 to -16.1, n=1000+1000); R 19.9% (17.5–22.5%, n=1000) | **FAIL** | FAIL / UNDECIDED |
| V0 full | G5 | Steady by end of Act 1 min 89.2% of runs alive (C_lantern; all runs 66.6%); True by end of Act 2 min 88.0% of runs alive (C_edge; all runs 57.1%) | PASS | Steady min C_lantern 89.2% (86.7–91.2%, n=747 alive); True min C_edge 88.0% (85.3–90.3%, n=649 alive) | PASS | PASS / PASS |
| V0 full | G6 | shatter 21.8%, lantern 21.0%, edge 57.2% of 477 A_lit wins | PASS | lead edge 57.2% (52.8–61.6%, n=477 A_lit wins) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 full | G3 floor (A) | A 40.6% vs best 49.7% (−9.1 pp) | FAIL | A − C_shatter -9.1 pp (-13.4 to -4.7, n=1000+1000) | FAIL | FAIL / FAIL |
| V0 full | G6 floor (A) | shatter 20.7%, lantern 20.0%, edge 59.4% of 406 A wins | **PASS** | lead edge 59.4% (54.5–64.0%, n=406 A wins) | UNDECIDED | FAIL / UNDECIDED |
| V5 fresh | G1 | worst C_edge 0.9% | n/a | worst C_edge 0.9% (0.6–1.5%, n=2000) | n/a | n/a / n/a |
| V5 fresh | G2 | 2.6 pp (C_lantern − C_edge) | PASS | C_lantern − C_edge +2.6 pp (+1.7 to +3.6, n=2000+2000) | PASS | PASS / PASS |
| V5 fresh | G3 | A_lit 3.8% vs best 3.6% (+0.2 pp) | PASS | A_lit − C_lantern +0.2 pp (-1.0 to +1.4, n=2000+2000) | PASS | PASS / PASS |
| V5 fresh | G4 | R 0.4% vs worst 0.9% (−0.6 pp) | FAIL | R − C_edge -0.6 pp (-1.2 to -0.1, n=2000+2000); R 0.4% (0.2–0.7%, n=2000) | FAIL | FAIL / FAIL |
| V5 fresh | G5 | Steady by end of Act 1 min 78.7% of runs alive (C_edge; all runs 24.2%); True by end of Act 2 min 44.9% of runs alive (C_edge; all runs 2.0%) | n/a | Steady min C_edge 78.7% (75.3–81.8%, n=616 alive) | n/a | n/a / n/a |
| V5 fresh | G6 | shatter 46.1%, lantern 30.3%, edge 23.7% of 76 A_lit wins | PASS | lead shatter 46.1% (35.3–57.2%, n=76 A_lit wins) | PASS | PASS / PASS |
| V5 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V5 fresh | G3 floor (A) | A 2.2% vs best 3.6% (−1.4 pp) | PASS | A − C_lantern -1.3 pp (-2.4 to -0.3, n=2000+2000) | PASS | PASS / PASS |
| V5 fresh | G6 floor (A) | shatter 66.7%, lantern 22.2%, edge 11.1% of 45 A wins | **FAIL** | lead shatter 66.7% (52.1–78.6%, n=45 A wins) | UNDECIDED | PASS / UNDECIDED |
| V5 full | G1 | worst C_edge 11.8% | FAIL | worst C_edge 11.8% (10.5–13.3%, n=2000) | FAIL | FAIL / FAIL |
| V5 full | G2 | 4.9 pp (C_shatter − C_edge) | PASS | C_shatter − C_edge +4.9 pp (+2.7 to +7.0, n=2000+2000) | PASS | PASS / PASS |
| V5 full | G3 | A_lit 14.5% vs best 16.7% (−2.1 pp) | **PASS** | A_lit − C_shatter -2.1 pp (-4.3 to +0.2, n=2000+2000) | UNDECIDED | FAIL / UNDECIDED |
| V5 full | G4 | R 4.7% vs worst 11.8% (−7.1 pp) | FAIL | R − C_edge -7.1 pp (-8.8 to -5.4, n=2000+2000); R 4.7% (3.9–5.7%, n=2000) | FAIL | FAIL / FAIL |
| V5 full | G5 | Steady by end of Act 1 min 92.1% of runs alive (C_edge; all runs 54.4%); True by end of Act 2 min 79.0% of runs alive (C_edge; all runs 19.4%) | PASS | Steady min C_edge 92.1% (90.4–93.5%, n=1183 alive); True min C_edge 79.0% (75.2–82.4%, n=491 alive) | PASS | PASS / PASS |
| V5 full | G6 | shatter 29.6%, lantern 21.6%, edge 48.8% of 291 A_lit wins | PASS | lead edge 48.8% (43.1–54.5%, n=291 A_lit wins) | PASS | PASS / PASS |
| V5 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V5 full | G3 floor (A) | A 10.7% vs best 16.7% (−5.9 pp) | FAIL | A − C_shatter -6.0 pp (-8.1 to -3.8, n=2000+2000) | FAIL | FAIL / FAIL |
| V5 full | G6 floor (A) | shatter 29.9%, lantern 21.0%, edge 49.1% of 214 A wins | PASS | lead edge 49.1% (42.4–55.7%, n=214 A wins) | PASS | PASS / PASS |

G7 covers zero stalls and zero errors in all 36,012 runs of the tables and the 8,000 of the second band, and arm A's three-seed replay, identical in every cell.

### G3 at V5 full, on 4,000 common seeds

| V5 full | Best committed | A_lit − best (point) | Paired 95% interval | Verdict (point / interval) | Readout 13 |
|---|---|---|---|---|---|
| seeds 13000–14999 (the table) | C_shatter 16.7% | −2.1 pp | −4.3 to +0.1 | PASS / UNDECIDED | −3.5 pp (−5.6 to −1.4), FAIL / UNDECIDED |
| seeds 15000–16999 | C_shatter 17.0% | −3.0 pp (−3.05) | −5.2 to −0.9 | FAIL / UNDECIDED | −3.5 pp (−5.5 to −1.4), FAIL / UNDECIDED |
| both, 4,000 seeds | C_shatter 16.8% | **−2.6 pp** | **−4.1 to −1.1** | **PASS / UNDECIDED** | −3.5 pp (−5.0 to −2.0), FAIL / UNDECIDED |

On the 4,000 seeds A_lit wins 14.2% (readout 13: 13.2%), committed Shatter 16.8% (16.7%), the Lantern 14.0% (12.3%), Edge 12.2% (11.9%). Shatter stays the best committed way; A_lit and the Lantern gain about 1 and 1.7 pp. Paired on seed, the gap moved by +0.9 pp (−0.5 to +2.3): the change is within noise, and the point estimate sits 0.4 pp inside the −3 pp line instead of 0.5 pp outside it.

### Row B, the bot round (V0, `s2`)

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 | Readout 13: B1 / B2 |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 20.2% (17.8–22.8) | PASS | 81.1% (80.5–81.6) | 1.2% (1.1–1.4) | PASS | PASS / UNDECIDED |
| V0 fresh | C_lantern | 36.1% (33.2–39.1) | PASS | 63.8% (63.1–64.5) | 1.1% (1.0–1.3) | PASS | PASS / UNDECIDED |
| V0 fresh | C_edge | 19.3% (17.0–21.9) | PASS | 69.4% (68.8–70.1) | 1.8% (1.6–2.0) | PASS | PASS / PASS |
| V0 fresh | A_lit | 31.0% (28.2–33.9) | PASS | 58.5% (57.8–59.2) | 1.2% (1.0–1.4) | FAIL | PASS / FAIL |
| V0 full | C_shatter | 49.7% (46.6–52.8) | PASS | 82.8% (82.3–83.3) | 1.1% (0.9–1.2) | UNDECIDED | PASS / UNDECIDED |
| V0 full | C_lantern | 45.5% (42.4–48.6) | PASS | 72.9% (72.3–73.5) | 0.9% (0.8–1.0) | UNDECIDED | PASS / UNDECIDED |
| V0 full | C_edge | 40.0% (37.0–43.1) | PASS | 82.6% (82.0–83.1) | 1.4% (1.3–1.6) | PASS | PASS / PASS |
| V0 full | A_lit | 47.7% (44.6–50.8) | PASS | 63.3% (62.7–64.0) | 1.3% (1.2–1.5) | PASS | PASS / PASS |

B1 passes for every way in both pools, as in readout 13. B2 at V0 fresh moves from UNDECIDED to PASS for committed Shatter and the Lantern (their close calls, 1.2% and 1.1%, now clear the 1% floor on interval); the full pool's Shatter and Lantern stay UNDECIDED on the floor (1.1%, 0.9%). A_lit's own feel at V0 fresh is 58.5% (57.8–59.2%) against 60%: a decided FAIL, as in readout 13 (59.2%).

## Every graded gate and reading, under P9's definition

`docs/rc-bar.md` P9: G2, G3, G5, G6, G7 and B are graded; G1 and G4 are readings; a figure is *short of its threshold* when it is FAIL on point or FAIL on interval.

**Graded figures short of their thresholds under `s2`:**

| Cell | Gate | Figure | Point / interval | Readout 13 |
|---|---|---|---|---|
| V0 fresh | G2 | C_lantern − C_edge 16.8 pp (+12.9 to +20.6) | FAIL / **FAIL** | 12.8 pp (C_lantern − C_shatter, +8.9 to +16.6): FAIL / UNDECIDED, the 1.0 verdict's reservation |
| V0 fresh | G3 | A_lit − C_lantern −5.1 pp (paired −9.0 to −1.2) | **FAIL** / UNDECIDED | −1.6 pp: PASS / UNDECIDED |
| V0 fresh | B2, A_lit's own feel | 58.5% (57.8–59.2%) against 60% | FAIL | 59.2%: FAIL |
| V5 full, 15000–16999 only | G3 | −3.05 pp (−5.2 to −0.9) | FAIL / UNDECIDED | −3.5 pp: FAIL / UNDECIDED |

No longer short: **G3 at V5 full**, on the table's band (−2.1 pp) and on the 4,000 seeds of record (−2.6 pp, −4.1 to −1.1), PASS on point and UNDECIDED on interval; readout 13 had it FAIL on point on both. Every other graded figure passes on point: G2 at V0 full (9.7 pp, UNDECIDED on interval, as before), G2 at V5 (2.6 and 4.9 pp, PASS / PASS), G3 at V0 full (−2.0 pp) and V5 fresh (+0.2 pp, PASS / PASS), G5 everywhere (PASS / PASS), G6 for A_lit everywhere (V0 full 57.2%, UNDECIDED on interval as before), G7, B1, and every committed way's B2 (PASS or UNDECIDED).

**Readings (never graded):** G1 fails in every graded cell, as in readout 13 (worst committed way 19.3% V0 fresh, 40.0% V0 full, 11.8% V5 full). G4 fails in every cell; at V0 full its interval moves from UNDECIDED to FAIL (R 19.9% against Edge's 40.0%, −20.1 pp, −24.0 to −16.1). The floors: arm A's G3 floor fails as before except at V5 fresh (PASS / PASS, as before); its G6 floor moves from FAIL to PASS on point at V0 full (Edge 59.4% of A's wins) and from PASS to FAIL on point at V5 fresh (Shatter 66.7% of 45 wins), both UNDECIDED on interval.

## The Ashwarden, development reading (not of record)

The Ashwarden declares no ways yet, so it has only the commit-blind arms. A, A_lit and R ran under both instruments on the development band, 200 paired seeds a cell (12000–12199), V0 and V5, in the `entry` pool (the Vigil at which the class unlocks) and the `full` pool. With no ways, A_lit has no colour to lean on and plays as A, row for row. The `s1` column is P3's instrument (pilot `p8-d0-v3`, search `s1`; its code paths are unchanged here, so these are the figures P3's tools give), run beside `s2` on the same seeds and head. Development seeds never enter a verdict; these figures say what the instrument does to the Ashwarden, not how strong the Ashwarden is.

| Cell | Arm | `s1` / `p8-d0-v3` | `s2` / `p9` | Paired change (gained / lost) | Deaths in Act 1 / 2 / 3 | Phantom Blades held / played a run | Draw cards played a run |
|---|---|---|---|---|---|---|---|
| V0 entry | A (= A_lit) | 25.5% (20.0–32.0) | 28.5% (22.7–35.1) | +3.0 pp (36 / 30, p = 0.54) | 12 / 71 / 66 → 7 / 69 / 67 | 0.80 / 4.71 → 0.65 / 4.14 | 57.0 → 57.9 |
| V0 entry | R | 6.0% (3.5–10.2) | 8.5% (5.4–13.2) | +2.5 pp (14 / 9, p = 0.40) | 48 / 105 / 35 → 44 / 114 / 25 | 0.71 / 4.92 → 0.68 / 5.37 | 29.3 → 34.0 |
| V0 full | A (= A_lit) | 55.5% (48.6–62.2) | 62.0% (55.1–68.4) | +6.5 pp (38 / 25, p = 0.13) | 7 / 42 / 40 → 9 / 37 / 30 | 0.28 / 1.49 → 0.24 / 1.21 | 58.0 → 58.0 |
| V0 full | R | 24.5% (19.1–30.9) | 26.0% (20.4–32.5) | +1.5 pp (22 / 19, p = 0.76) | 20 / 95 / 36 → 20 / 92 / 36 | 0.28 / 2.23 → 0.28 / 2.23 | 36.5 → 41.5 |
| V5 entry | A (= A_lit) | 1.5% (0.5–4.3) | 3.5% (1.7–7.0) | +2.0 pp (6 / 2, p = 0.29) | 103 / 69 / 25 → 96 / 77 / 20 | 0.80 / 3.21 → 0.62 / 2.68 | 26.3 → 27.4 |
| V5 entry | R | 1.0% (0.3–3.6) | 0.5% (0.1–2.8) | −0.5 pp (0 / 1, p = 1.00) | 157 / 37 / 4 → 151 / 42 / 6 | 0.67 / 3.34 → 0.60 / 3.36 | 15.8 → 17.4 |
| V5 full | A (= A_lit) | 21.0% (15.9–27.2) | 28.0% (22.2–34.6) | +7.0 pp (29 / 15, p = 0.05) | 48 / 75 / 35 → 51 / 72 / 21 | 0.28 / 1.44 → 0.24 / 1.25 | 36.1 → 37.8 |
| V5 full | R | 2.5% (1.1–5.7) | 5.5% (3.1–9.6) | +3.0 pp (9 / 3, p = 0.15) | 103 / 77 / 15 → 98 / 71 / 20 | 0.30 / 1.64 → 0.28 / 1.63 | 21.0 → 23.6 |

- **The 1.1 instrument plays the Ashwarden better.** Arm A gains in all four cells (+2.0 to +7.0 pp); no cell is significant on 200 seeds, but over the four cells A gains 109 seeds and loses 72 (exact two-sided p = 0.007). R gains 45 and loses 32 (p = 0.17). The decks hold fewer Phantom Blades than before, so the gain does not come from building towards the payoff; this table cannot split it between `s2` and `p9`.
- **`p9` takes Phantom Blades less often.** Valued by the hand an Ashwarden deck deals (about five cards, so 12 damage) instead of the flat 14.4, it is held 0.62–0.65 times a run in the `entry` pool against 0.80, and played less. With no Hand way to build towards and few draw cards, the honest worth of the payoff is lower than the flat weight was. Once the Ash lock gives the Hand way its producers, `p9` values the payoff by the deck that holds them.
- **Where the Ashwarden dies hardly moves**: in Acts 2 and 3 at V0, in Act 1 in the V5 `entry` pool and Act 2 in the V5 `full` pool.
- **Not comparable with the audit's figures.** The audit's development readings (arm A at V0 full 54%, fresh 31%, 100 seeds) ran before P3, when the search player credited the Duskblade's way verbs to every class. P3 removed that, so they no longer apply; this table is the Ashwarden's development baseline under both instruments.

## Tests and pins

- **New: `tests/test_balance_bots_hand.gd`.** The three probes; the draw credit's expected worth (multiset, reshuffle, unpayable cards 0); `p9`'s Phantom Blades against `p8-d0-v3`'s (starter deck, three Tinders, `p8-d0-v3` unmoved by the deck); a foreign rider at 0 under `p9`, unchanged for the Duskblade; the simulator's flags and manifest. Four mutants fail it (above).
- **`tests/test_balance_invariance.gd`.** Its 72 pins for `s1`/`p8-d0-v3` are unchanged and pass, now with the bots named explicitly. **48 new pins** (`PINS_1_1`) for `p9`/`s2` beside them: every arm and cell on seed 12000, greedy and search. 21 of the 24 greedy `p9` rows equal `p8-d0-v3`'s (no Phantom Blades decision on those seeds); 9 of the 24 search rows equal `s1`'s. The panel leaves 1.0's bots selected for the tests after it (the first full-suite gate caught `test_balance_pilot_cache` reading `p9` scores). It adds about 27 s.
- **`tests/test_balance_ways.py`** (26 tests): every simulator command names its pilot, and under `--play search` its search player; an unknown bot or a search player for greedy play is refused; the grader names the bots in its result and header and refuses reports that differ in either. **`tests/test_balance_readout.py`** (57): the runner's chunks name 1.0's bots unless told otherwise, and 1.1's when told.
- **Unchanged and passing:** `test_balance_search` (the copy check, replay and the 60-fight floor against greedy play `s1`, the default), `test_balance_sim` (pins `Pilot.VERSION == "p8-d0-v3"`, the default), `test_balance_arms`, `test_balance_adaptive_lit`, `test_balance_pilot_play`, `test_balance_pilot_cache`, the seed-1000 and seed-1001 digests.
- **Anchors.** Nine citations of the pilot and simulator in two historical balance notes moved with the new lines: six re-anchored by `check_anchors.py --fix`, three re-pointed by hand to the lines they name (the shop's removal numerator in `choose_shop`, the simulator's reading of its arguments).
- **`docs/rc-bar.md` P9** names the 1.0 re-run's bots explicitly; the class template points the Ashwarden's readings at `--pilot p9 --search s2`.

## What the orchestrator must decide

The orchestrator restates the Duskblade's verdict for 1.1 on this reading; this readout gives none. The figures it turns on:

1. **G2 at V0 fresh is now a decided FAIL.** 16.8 pp (Lantern − Edge, +12.9 to +20.6) against readout 13's 12.8 pp (Lantern − Shatter, +8.9 to +16.6, UNDECIDED), the 1.0 verdict's one reservation (the fresh-pool Lantern lead). The worst way changed from Shatter to Edge. On common seeds the Lantern − Edge gap widened by 4.4 pp (+0.2 to +8.6), made of two moves neither significant alone: the Lantern +2.5 pp (p = 0.16) and Edge −1.9 pp (p = 0.16).
2. **G3 at V0 fresh is now short on point.** A_lit 31.0% against the committed Lantern's 36.1%: −5.1 pp (paired −9.0 to −1.2), FAIL on point and UNDECIDED, where readout 13 read −1.6 pp, PASS on point. The gap moved by −3.5 pp (−8.1 to +1.1), not significant on its own; most of it is the Lantern's +2.5 pp.
3. **G3 at V5 full is no longer short on point.** −2.6 pp on 4,000 common seeds (−4.1 to −1.1), PASS on point and UNDECIDED, against readout 13's −3.5 pp, FAIL on point (a figure P9 records against the 1.0 verdict). The 15000–16999 band alone stays FAIL on point (−3.05 pp).
4. **A_lit's B2 at V0 fresh** stays a decided FAIL (58.5%; readout 13 59.2%), short as P9 already records.
5. **Classes that changed but are not graded:** G4 at V0 full (interval UNDECIDED → FAIL); arm A's G6 floor at V0 full (FAIL → PASS on point) and at V5 fresh (PASS → FAIL on point, on 45 wins). B2 at V0 fresh for committed Shatter and the Lantern improves from UNDECIDED to PASS.
6. **The one significant arm move:** the committed Lantern at V5 full, +1.7 pp on 4,000 seeds (p = 0.01), the only p under 0.05 of 28 paired tests.
7. **The default bots.** This PR keeps 1.0's (`p8-d0-v3`, `s1`) as the tools' default until 1.0 ships, and names 1.1's on every Ashwarden run. Moving the default is a two-constant change once the 1.0 re-run is done.

## The orchestrator's ruling (4 October 2026)

Given under the owner's delegation of design calls (30 September 2026) and #544's plan of record, decision 4. Before ruling, the orchestrator ran readout 13's own commands at this branch's head with the bots unnamed, on seeds 13000–13099 in all four cells (2,400 runs and arm A's 12 replay rows). All 2,412 rows equal #544 P2's reproduction of readout 13 row for row, and so does every chunk's summary. Every manifest names pilot `p8-d0-v3` and search player `s1`. Apart from its commit, each matches the reproduction's, with one exception: `driverSha256`, the digest of the simulator file, which this branch changes. 1.0's instrument and the tools' default are unchanged.

1. **The 1.1 instrument is accepted.** Pilot `p9` and search player `s2` are the instrument for every Ashwarden reading and for the Duskblade's 1.1 requalification. They play the hand-size payoff that 1.0's bots cannot (the two payoff probes, with every mutant caught), they cost what `s1` does, and on the Duskblade the instrument alone moves no arm of the table beyond chance. Every one of the table's 24 pairs has p ≥ 0.07. The Lantern at V5 full is the only arm under 0.05 (exact p = 0.015 on the second band, 0.008 on the 4,000 common seeds). Neither survives a correction for the 28 paired tests (0.05 / 28 ≈ 0.0018). The tools' default stays 1.0's until 1.0 ships.
2. **The 1.0 verdict stands unchanged.** It was given on readout 13 under 1.0's instrument, which P9 binds; readout 14 is a new reading, not the independent re-run. It does answer the 1.0 reservation's question, whether the fresh-pool Lantern lead is real: it is. The pair the reservation named, the Lantern over Shatter, reads 15.9 pp under `s2`, inside readout 13's own interval for it (+8.9 to +16.6 pp), so a lead of this size was within what the ACCEPT was given on. Nothing else in readout 14 bears against that verdict: G3 at V5 full, short in readout 13, passes on point here.
3. **On 1.0's content the Duskblade does not yet requalify for 1.1.** G2's intent, three ways that are viable and comparable, fails at V0 fresh under the 1.1 instrument. The Lantern leads Edge by 16.8 pp, and the interval (+12.9 to +20.6 pp) lies wholly above the 10 pp threshold. Readout 13's 12.8 pp could be carried as a reservation because its interval still reached the threshold; a decided gap cannot. The other figures short under `s2` keep their intent:
   - **G3 at V0 fresh** (−5.1 pp): A_lit beats every arm but the Lantern (31.0% against 26.0, 20.2, 19.3 and 7.3%). Reading the offers is not a trap; the shortfall is the same fresh-pool Lantern lead, and it is answered with it.
   - **A_lit's B2 at V0 fresh** (58.5%): as in 1.0, row B's feel test is the committed ways', and all three pass it at V0 fresh.
   - **G3 at V5 full on 15000–16999 alone** (−3.05 pp): G3's figure there is read on the 4,000 common seeds, −2.6 pp, which passes on point.

   G5, G6, B1 and G7 hold in every graded cell (no stall or error in 44,012 runs; every replay identical).
4. **The fresh-pool Lantern lead is the requalification's one open item.** A Duskblade wall lane in the fresh pool answers it, under the 1.1 instrument and the wall rule (diagnose, then at most three candidates; ship the measured ones or drop them). The lane may run as research at any time. Its change lands only after the 1.0 release candidate is cut, because the Duskblade's 1.0 figures must not move (#544 decision 6). The Duskblade's 1.1 verdict, given on the combined product (step A9), needs this item answered.

## Appendix: the scripts

The tables come from the repository's runner and graders (`tools/balance_readout.py`, `tools/balance_ways.py`). Three short scripts in the lane's scratch folder read the merged reports:

| Script | What it does |
|---|---|
| `instr14.py` | The instrument-alone table: per arm and cell, win before and after with the paired change, reach over all runs and over survivors, Phantom Blades held and played, draw cards played, turns and HP lost a fight. |
| `gapchange.py` | How a gate's gap moved between two instruments on common seeds: per seed (a − b) new less (a − b) old, its mean and 95% interval. |
| `ash14.py` | The Ashwarden's development table under two instruments, paired on seed. |
