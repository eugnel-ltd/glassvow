# Readout 14: the 1.1 instrument's requalification of the Duskblade

> **The 1.1 instrument's requalification reading (AI-SDLC discovery), not a verdict and not a balance change.** #544's plan of record, step P6 (decision 4, "instrument first"): the bots learn the Ashwarden's Hand way, as search player `s2` and pilot `p9`, and the Duskblade is re-read under them as its 1.1 requalification. **Readout 13 stays 1.0's reading of record**, played by pilot `p8-d0-v3` and search player `s1`, which stay selectable, byte-identical and the tools' default. **No content changed**: `content/full-content.json` is readout 13's, SHA-256 `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`. No domain rule, id, rider, lantern knob, enemy number, save field, RNG draw or `port_fixtures/` golden moved. The readout itself gives no verdict: it ends with what the orchestrator must decide, and the orchestrator's ruling follows as its last section.
>
> **Head.** Every figure is from reports run at `3dcbe37b`, the head after the review's fix round, in a detached worktree; every report's manifest names it, with pilot `p9` and search `s2` (the Ashwarden's `s1` panel names `p8-d0-v3` and `s1`). Later commits change documents only: `git diff --stat 3dcbe37b HEAD -- domain content 'tools/balance_*'` is empty, so no balance tool, domain or content path differs from the reports' head. The first candidate's reports (`516be99f`) are superseded; the note at the end of *How it was run* counts the rows that changed.

The Duskblade's verdict of record was given on readout 13, played by bots that could not play a hand-size way: the search player ended every line at a draw and scored nothing for it, and the pilot valued the one hand-size payoff, Phantom Blades, at a flat weight. The Ashwarden's Hand way makes that payoff a way's identity, so the bots learn it before any Ashwarden reading counts (#544 decision 4). The change is class-neutral, so the Duskblade is read again under the new bots, on readout 13's seeds and content, as its 1.1 requalification (`docs/rc-bar.md` P9, *Scope per shipped class*).

## The answer in brief

- **The bots.** Search `s2` scores a line that ends at a draw as a turn that continues: it credits the hand-size payoff that a card held before the draw pays from the bigger hand, and half the expected worth of the cards drawn, read from the pile they came from and paid from the Energy left. Pilot `p9` values Phantom Blades by the hand its deck deals and scores 0 for a rider its class cannot light. On four Ashwarden probes checked by hand, `s2`/`p9` finds all four lines and `s1`/`p8-d0-v3` misses the three that turn on the payoff or on the draw's worth; `s2` credits no payoff the draw itself deals. `s2` costs what `s1` does: 27.9 against 28.5 ms a turn for the Duskblade, run side by side.
- **The instrument alone moves the Duskblade little.** Paired run for run against readout 13's reports, no arm moves significantly in any of the four cells (24 arm-cell pairs, every p ≥ 0.07). The largest moves are the committed Lantern at V5 full (+1.6 pp, p = 0.08) and A at V0 full (+1.7 pp, p = 0.32). Only the committed Lantern at V5 full is under 0.05, on G3's second band (+1.9 pp, p = 0.03) and on its 4,000 common seeds (+1.8 pp, p = 0.004); neither survives a correction for the 28 paired tests. The decks hold fewer Phantom Blades (at V0 fresh, committed Shatter 0.92 → 0.56 a run, Edge 0.92 → 0.44): `p9` values it at about 12 in a Duskblade deck, against the flat 14.4.
- **One graded figure changes class against readout 13, for the better.** G3 at V5 full moves from FAIL on point (−3.5 pp on 4,000 common seeds) to **PASS on point** (−2.6 pp, −4.1 to −1.1, UNDECIDED). G2 at V0 fresh reads 13.5 pp (the Lantern over Shatter and Edge, tied at 20.2%; +9.6 to +17.3), FAIL on point and UNDECIDED on interval: the class of readout 13's 12.8 pp, the 1.0 verdict's one reservation. On common seeds it moved by +0.7 pp (−3.1 to +4.5). A_lit's own feel at V0 fresh stays a decided FAIL (58.6%).
- **What holds.** G2 at V0 full (9.9 pp, PASS on point) and at V5, G3 at V0 (−1.5 and −2.3 pp) and V5 fresh, G5 in every graded cell on point and interval, G6 for A_lit in every cell, G7 (no stall or error in 44,012 runs; every replay identical), B1 for every committed way in both pools.
- **Against the first candidate.** Readout 14 was first drafted on the reports of `516be99f`, whose `s2` could credit a payoff the draw itself dealt and counted every drawn card against the whole Energy left. Its figures put G2 at V0 fresh at a decided 16.8 pp and G3 at V0 fresh at −5.1 pp. With the fix round's two changes, both return to readout 13's class; 30.6% of the V0 rows and 16.2% of the V5 rows changed.
- **The Ashwarden (development seeds, not of record).** Under `s2`/`p9` its commit-blind arm wins more in all four cells, +1.5 to +5.5 pp, pooled 103 seeds gained and 74 lost (p = 0.035).

## The question

Can the bots play the Ashwarden's verbs, above all the hand-size payoff, on fights whose best line is known? And with only the instrument changed, what does the Duskblade's complete §11 table read on readout 13's seeds and content: which arms move, and which figures of the graded gates and readings change class?

## The instrument

### What changed in the bots

Two new bots, chosen per run: `tools/balance_sim.gd` takes `--pilot` and `--search`, writes both into every report's manifest (`pilot`, `search.version`), and refuses an unknown one or a search player named for greedy play. The readout runner and the grader pass both to every simulator command they launch, and the grader refuses a table whose reports name more than one pair. Unnamed, the bots are 1.0's: pilot `p8-d0-v3` and search `s1`.

**Search `s2`** (`tools/balance_search.gd`). A line still ends at the action that draws or rolls the RNG, and the search still never reads a card it has not drawn. What changes is how such a line is scored. `s1` scores it as if the turn ended there, so a draw is worth nothing and every card still in hand is worth nothing; the player re-plans once the draw resolves, so that is not the turn's end. `s2` scores it as the turn's end here, plus two credits (`_continued`):

- **The hand-size payoff.** If a card the player held before the drawing action reads the hand's size (Phantom Blades: 3 damage, 4 upgraded, for each card left in hand once it is played), `s2` plays it on a copy of the position and keeps the better of the two scores. The hand's size after a draw is known; its new cards are not, and the payoff reads only the size. A payoff the draw itself dealt is never credited: the copy's RNG deals exactly what the live draw will, so crediting it would plan with a card the player has not seen. The cards held before are matched by instance (`_note_draws` records their uids), so a drawn copy of a held card stays unseen.
- **The draw.** Half (the evaluation's setup share, 0.5) of the expected worth of the cards the action drew. Each is a card of the multiset it came from: the draw pile before the action (all of it, if the action drew more), then the discard pile that was shuffled in. A card is worth the pilot's catalogue score, never below 0 (it need not be played), and 0 when the Energy and Embers left after the payoff cannot pay for it. The Energy left is shared: when the drawn cards' expected Energy cost exceeds it, their worth is scaled down to the share it pays for (`_draw_worth`).

Everything else is `s1`'s: the line cap (2,000), the evaluation's weights, the greedy turn as a floor, and the one kindle it tries.

**The review's fix round.** The independent review of the first candidate (#690) found that `s2` credited a payoff from every card in hand after the draw, the drawn ones included, and that no probe needed the draw credit itself. Both are fixed: the payoff is credited only from cards held before the draw, and the draw credit, once a probe needed it, was found to count every drawn card against the whole Energy left; it now shares the Energy. Every figure below is from the fixed head; the note at the end of *How it was run* counts the rows that changed against the first candidate's reports.

**Pilot `p9`** (`tools/balance_pilot.gd`). Two scores change; everything else is `p8-d0-v3`'s, the committed bot's seed removal and its two-copy cap included.

- **A hand-size payoff is valued by the hand the deck deals.** `p8-d0-v3` scores Phantom Blades at the flat `leech` weight (14.4). `p9` scores it at 3 for each card beside it in the hand the deck is expected to deal: the turn's five cards, plus what each draw card in the deck adds (its draws less itself), each dealt at the rate five cards of the deck are, within the cap of 10 (`expected_hand`). With the Ashwarden's starter that is 5, so 12; three Tinders in a 13-card deck make it 6.15, so 15.5. The bot reads it before every build decision, as it reads its flame (`see_flame`).
- **A rider its class cannot light scores 0** (#544 decision 3, the instrument's side). `p8-d0-v3` counts every `lit` rider at `crackedShare` (0.5) unless the score assumes its colour lit. `p9` counts a rider of a way the run's class does not have at 0: it can never resolve. For the Duskblade every rider names one of its ways, so this changes nothing there; for the Ashwarden, which declares no ways yet, Tinder's, Struck Match's and Tithe of Panes' amber Ember stops counting.

**Considered and not built.** The audit suggested trying several kindle candidates rather than the pilot's one. On 40 development seeds per class (V0 full, arm A), three candidates took 1.6–2.1 times `s1`'s time per turn, for a change in wins within noise (Duskblade 11 of 40 with one candidate or three; Ashwarden 19 against 20). The evaluation charges nothing for the card a kindle burns from the rest of the fight, so a wider choice of what to burn is not a more honest one. `s2` keeps `s1`'s kindle.

### The probes

`tests/test_balance_bots_hand.gd` plays one turn from four fixed Ashwarden positions whose best line can be checked by hand, as the simulator plays it (potions, then the search's plans and re-plans), under the 1.1 bots and under 1.0's. The hero has 30 HP; one Sporeling stands opposite; the draw pile is six Defends unless stated, so what a draw brings is known.

| Probe | Position | Best line, by hand | `s2` / `p9` | `s1` / `p8-d0-v3` |
|---|---|---|---|---|
| Draw, then Phantom Blades with the bigger hand | Energy 3; hand Tinder, Phantom Blades, three Defends; the Sporeling at 15 HP, its blow 40 | Tinder (draw 2), then Phantom Blades with five cards beside it: 15 damage, the fight won. Phantom Blades first deals 12 | Tinder, Phantom Blades: won | three Defends, Tinder, a kindle: the Sporeling untouched |
| A Struck Match line into the payoff | Energy 0; hand Struck Match, Phantom Blades, three Defends; the Sporeling at 12 HP, its blow 40 | Struck Match (1 Energy, draw 1), then Phantom Blades with four beside it: 12, the fight won | Struck Match, Phantom Blades: won | Struck Match, a Defend, a kindle: untouched |
| Stack Smolder, then Bellows | Energy 3; hand Bellows, Ashbite, three Defends; the Sporeling at 500 HP with 3 Smolder and no blow | Ashbite (5 Smolder), then Bellows (doubles it): 10. Bellows first: 8 | Ashbite, Bellows: 10 Smolder | Ashbite, Bellows: 10 Smolder |
| The draw's worth, no payoff | Energy 2; hand Ashbite, Tinder, three Defends; the Sporeling at 500 HP, no blow; the draw pile six Emberbites (1 Energy: 4 damage, 4 Smolder) | Tinder first: two Emberbites, both paid, 8 damage and 8 Smolder. Ashbite first spends the Energy (6 damage, 2 Smolder) and leaves the Emberbites unpaid | a kindle, Tinder, two Emberbites: 8 damage, 8 Smolder | Ashbite, Tinder, a kindle: 6 damage, 2 Smolder |

`s1` misses both payoff probes and the draw's worth, the blind spot being fixed: a line that plays the draw first ends at the draw and scores nothing for it, and the greedy turn it falls back to blocks first against a lethal blow, or plays Ashbite first because it scores it above Tinder. Both find the Smolder line, which needs no draw: the guard that `s2` keeps what `s1` already played. The fourth probe is built so that the draw credit alone decides it. The review suggested a known Defend and a pile of Strikes with no threat; there the greedy turn already plays Tinder first (it values a draw at 10 a card and a Defend with no blow at nothing), so 1.0's bots find it too, and the probe could not tell them apart.

**Honest play.** A fifth check plans one turn in which Tinder would deal Phantom Blades from the top of the pile, and Phantom Blades would then kill the Sporeling (3 × 5 = 15, its 15 HP). `s2` must credit no line the win: the player has not seen the card. Its best line scores under the win value.

**Mutants** (each file backed up and copied back, never `git checkout --`):

- `s2` without the payoff credit (`_continued` never keeps the paid position): both payoff probes fail for `s2`.
- `s2` crediting a payoff from any card in hand, the first candidate's behaviour: the honest-play check fails (the Tinder line is credited the win, 1,000,030).
- `_note_draws` a no-op: the draw's-worth probe fails, and so do both payoff probes (nothing is known to have been held).
- `s2` without the draw credit (`_draw_worth` returns 0): the draw's-worth probe and the draw-worth check fail.
- `s2` counting every drawn card against the whole Energy left, the first candidate's draw credit: the draw's-worth probe fails (it spends an Energy on a Defend before Tinder) and so does the draw-worth check (11.62 against 4.65 for two Strikes from a pile of two and one card of a Defend and an Ashbite, with 1 Energy left).
- `p9` with the flat payoff weight: the payoff check fails (20.36 in every deck against 17.99 with the starter and 21.45 with three Tinders).
- `p9` scoring a foreign rider at `crackedShare`: the rider check fails (Tinder 25.75 for the Ashwarden under both pilots, against 24.66 under `p9`).

The file also checks the simulator's flags (unnamed bots are 1.0's; `--pilot p9 --search s2` reach the manifest; an unknown bot, or `--search s2` with greedy play, is refused).

### The default stays 1.0's

The tools' default stays pilot `p8-d0-v3` and search `s1`, 1.0's instrument of record. The 1.0 release candidate's independent re-run is the one pending run that P9 binds to these tools. Every command recorded in readouts 8–13 and in readout 13's reproduction still plays 1.0's instrument as written, and every test that runs the bots unnamed (`test_balance_sim`, `test_balance_search`, the arms' tests) still plays 1.0's. The re-run still names its bots: `docs/rc-bar.md` P9 now requires `--pilot p8-d0-v3 --search s1`, whatever the default. Every Ashwarden reading names `--pilot p9 --search s2`. Every simulator command the runner and the grader launch names its pilot (and, under `--play search`, its search player), every report's manifest names both, the grader prints them in its header and refuses a table that mixes them, so a run without the 1.1 bots cannot pass for one.

### Cost

The search budget is `s1`'s: at most 2,000 lines a plan.

| Comparison | `s1` | `s2` |
|---|---|---|
| 40 development seeds per class, V0 full, arm A, the two run side by side at `3dcbe37b` | Duskblade 28.5 ms a turn; Ashwarden 23.8 ms | Duskblade 27.9 ms; Ashwarden 28.9 ms |
| The V0 table, 13000–13999, 12,006 runs (`s1`: #544 P2's re-run of readout 13, eight jobs; `s2`: six jobs) | 3.55 s a run per process, 5,364 s of wall | 3.76 s, 7,608 s |
| The V5 table, 13000–14999, 24,006 runs | 1.62 s, 4,885 s | 2.11 s, 8,453 s |
| Three kindle candidates (considered, not built; first candidate, side by side) | | Duskblade 45.6 ms a turn; Ashwarden 52.4 ms |

The table runs were on the same shared host under heavy and different loads (this reading's load average ran from 160 to above 900), so they say only that the two cost about the same; the side-by-side runs are the measure. Readout 13 measured 1.7–1.8 s a run on a lightly loaded host.

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   [application] config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-balance-p6", never committed.
# The tables, from a detached worktree at 3dcbe37b (no commit during the run, so every chunk names one commit):
python3 -B tools/balance_readout.py run s/s2-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run s/s2-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run s/s2-ext-v5 --seeds 15000-16999 --cells v5-full --arms C_shatter,C_lantern,C_edge,A_lit --play search --pilot p9 --search s2 --jobs 6
python3 -B tools/balance_readout.py join s/s2-g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/s2-v5 s/s2-ext-v5
# The Ashwarden's development reading, under both instruments:
python3 -B tools/balance_readout.py run s/ash-s1 --aspect ashwarden --seeds 12000-12199 --cells v0-entry,v0-full,v5-entry,v5-full --play search --pilot p8-d0-v3 --search s1 --jobs 6
python3 -B tools/balance_readout.py run s/ash-s2 --aspect ashwarden --seeds 12000-12199 --cells v0-entry,v0-full,v5-entry,v5-full --play search --pilot p9 --search s2 --jobs 6
# Grading against readout 13's own reports (r13/final-v0, final-v5, ext-v5 and g3-4000: #544 P2's archive copies,
# which P2's re-run matched row for row):
python3 -B tools/balance_readout.py paired s/s2-v0 r13/final-v0 v0-fresh,v0-full      # and s2-v5, s2-ext-v5, s2-g3-4000
python3 -B tools/balance_readout.py table s/s2-v0 s/s2-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999 \
    --ref r13/final-v0 r13/final-v5 --tidy
python3 -B tools/balance_readout.py g3 s/s2-v5 v5-fresh,v5-full; python3 -B tools/balance_readout.py g3 s/s2-g3-4000 v5-full
python3 -B tools/balance_readout.py rowb s/s2-v0 --ref r13/final-v0
python3 -B tools/balance_ways.py --from-dir s/s2-v0 --seeds 13000-13999 --vows 0   # and s2-v5 at --vows 5
python3 -B instr14.py s/s2-v0 r13/final-v0 v0-fresh,v0-full; python3 -B gapchange.py ...; python3 -B ash14.py s/ash-s2 s/ash-s1
python3 -B rowdiff.py s/s2-v0 <first candidate>/s2-v0                                  # and the other tables
```

- **Cells, arms, seeds.** Readout 13's: the Duskblade, V0 on 13000–13999 (1,000 paired seeds a cell) and V5 on 13000–14999 (2,000), fresh and full pools, the six arms C_shatter, C_lantern, C_edge, A, A_lit and R, with arm A's three-seed replay per cell; G3 at V5 full also on 15000–16999, so on 4,000 common seeds. Every run pairs with readout 13's run on its seed.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference of independent rates), G5 over the runs alive at the act's end; paired changes, the seeds one instrument wins and the other loses, with the exact two-sided binomial p; G3 on common seeds with Newcombe's paired interval; row B as readouts 8–13 compute it. How a gap moved between the instruments is read per seed, (a − b) under `s2` less (a − b) under `s1`, with a normal 95% interval.
- **Budget and stop rule.** One reading, no candidates, nothing tuned: the instrument was fixed, its tools committed and gated, before the first run.
- **Wall time.** 20,539 s (5 h 42 min, 23:13 on 4 October to 04:55 UTC on 5 October 2026) for 48,812 runs on six jobs: the Ashwarden 1,205 s and 725 s, V0 7,608 s, V5 8,453 s, the second band 2,516 s.
- **Rows changed against the first candidate's reports** (`516be99f`, the same commands and seeds). Whole run rows on the same seed: V0 3,679 of 12,006 (30.6%; the committed Lantern 462 and 576 of 1,000, Shatter 92 and 132); V5 3,896 of 24,006 (16.2%); the second band 1,504 of 8,000 (18.8%, the Lantern 781); the Ashwarden's `s2` panel 1,056 of 2,400 (44.0%). The Ashwarden's `s1` panel is identical, 2,400 of 2,400: 1.0's bots did not move. Changed rows are those where a draw ended a searched line, or a held payoff met a reshuffled hand, at least once; each such change sends the rest of the run down another branch.

## The instrument alone, paired against readout 13

Readout 13's reports against `s2`/`p9` on the same seeds and content. Win: readout 13 → this reading, with the paired change (seeds gained / lost, exact p). Steady and True are over all runs and, in brackets, over the runs alive at that act's end (G5's denominator). Phantom Blades held at run end and played a run; draw cards (Tinder, Struck Match, First Spark, Flicker, Glasstep, Refract, Tithe of Panes, Dim the Glass, Pyre Tithe) played a run; turns and HP lost a fight.

| Cell | Arm | Win, r13 → r14 (paired) | Steady by end of Act 1 (of alive) | True by end of Act 2 (of alive) | Phantom Blades held / played | Draw cards played | Turns / HP lost a fight |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 20.8 → 20.2% (−0.6 pp, p = 0.63; 51 / 57) | 78.0 (95.4) → 79.1 (96.0)% | 49.7 (94.1) → 49.5 (94.8)% | 0.92 / 4.49 → 0.56 / 2.72 | 11.0 → 11.5 | 3.18 / 9.54 → 3.17 / 9.52 |
| V0 fresh | C_lantern | 33.6 → 33.7% (+0.1 pp, p = 1.00; 133 / 132) | 46.8 (74.3) → 47.8 (74.3)% | 31.6 (65.4) → 32.8 (65.6)% | 0.65 / 5.52 → 0.59 / 5.22 | 58.1 → 60.6 | 3.51 / 10.62 → 3.51 / 10.70 |
| V0 fresh | C_edge | 21.2 → 20.2% (−1.0 pp, p = 0.48; 77 / 87) | 66.0 (80.7) → 65.7 (81.1)% | 22.9 (52.6) → 21.5 (52.8)% | 0.92 / 5.26 → 0.44 / 2.62 | 17.9 → 18.4 | 3.40 / 10.37 → 3.41 / 10.42 |
| V0 fresh | A | 24.1 → 25.6% (+1.5 pp, p = 0.35; 120 / 105) | - | - | 0.55 / 3.41 → 0.37 / 2.19 | 34.4 → 35.7 | 3.38 / 9.68 → 3.37 / 9.60 |
| V0 fresh | A_lit | 32.0 → 32.2% (+0.2 pp, p = 0.95; 127 / 125) | - | - | 0.69 / 4.25 → 0.42 / 2.57 | 36.4 → 37.1 | 3.35 / 9.17 → 3.36 / 9.24 |
| V0 fresh | R | 7.1 → 7.4% (+0.3 pp, p = 0.80; 32 / 29) | - | - | 0.47 / 2.96 → 0.46 / 2.96 | 17.4 → 18.1 | 3.21 / 11.07 → 3.20 / 11.04 |
| V0 full | C_shatter | 49.3 → 50.5% (+1.2 pp, p = 0.40; 90 / 78) | 80.5 (91.6) → 81.5 (91.6)% | 64.7 (88.4) → 66.2 (89.5)% | 0.29 / 1.69 → 0.22 / 1.40 | 16.1 → 16.8 | 3.24 / 9.04 → 3.24 / 9.12 |
| V0 full | C_lantern | 47.6 → 47.9% (+0.3 pp, p = 0.91; 156 / 153) | 68.0 (89.6) → 67.5 (89.4)% | 53.9 (87.6) → 55.0 (88.7)% | 0.17 / 1.73 → 0.17 / 1.66 | 76.1 → 77.2 | 3.30 / 12.17 → 3.30 / 12.07 |
| V0 full | C_edge | 39.6 → 40.6% (+1.0 pp, p = 0.54; 114 / 104) | 85.4 (92.7) → 85.6 (92.8)% | 56.0 (87.8) → 57.1 (87.8)% | 0.22 / 1.45 → 0.16 / 1.12 | 24.5 → 24.9 | 3.24 / 10.03 → 3.23 / 9.90 |
| V0 full | A | 38.8 → 40.5% (+1.7 pp, p = 0.32; 138 / 121) | - | - | 0.20 / 1.46 → 0.13 / 1.00 | 45.7 → 48.4 | 3.44 / 11.29 → 3.42 / 11.23 |
| V0 full | A_lit | 47.1 → 48.2% (+1.1 pp, p = 0.55; 143 / 132) | - | - | 0.20 / 1.43 → 0.14 / 1.04 | 44.4 → 47.0 | 3.35 / 10.49 → 3.33 / 10.36 |
| V0 full | R | 17.6 → 18.2% (+0.6 pp, p = 0.66; 69 / 63) | - | - | 0.25 / 1.84 → 0.24 / 1.90 | 25.7 → 26.8 | 3.18 / 10.61 → 3.17 / 10.60 |
| V5 fresh | C_shatter | 1.2 → 1.4% (+0.2 pp, p = 0.54; 14 / 10) | 31.4 (97.8) → 30.3 (97.9)% | 8.6 (95.6) → 7.6 (94.4)% | 0.80 / 3.17 → 0.56 / 2.22 | 6.8 → 7.1 | 3.15 / 11.72 → 3.16 / 11.71 |
| V5 fresh | C_lantern | 3.8 → 4.3% (+0.5 pp, p = 0.36; 65 / 54) | 16.0 (87.4) → 16.2 (89.0)% | 6.1 (63.9) → 6.6 (68.6)% | 0.69 / 4.29 → 0.59 / 3.83 | 22.7 → 23.8 | 3.45 / 12.78 → 3.47 / 12.83 |
| V5 fresh | C_edge | 1.5 → 1.1% (−0.4 pp, p = 0.24; 14 / 22) | 24.4 (79.1) → 24.1 (78.7)% | 2.5 (40.2) → 1.8 (40.2)% | 0.75 / 3.66 → 0.47 / 2.42 | 10.0 → 10.5 | 3.33 / 12.28 → 3.35 / 12.34 |
| V5 fresh | A | 2.0 → 2.4% (+0.4 pp, p = 0.37; 35 / 27) | - | - | 0.57 / 2.63 → 0.34 / 1.56 | 15.8 → 16.0 | 3.36 / 12.09 → 3.36 / 12.10 |
| V5 fresh | A_lit | 3.5 → 3.9% (+0.4 pp, p = 0.52; 47 / 40) | - | - | 0.65 / 3.13 → 0.41 / 1.92 | 16.1 → 16.5 | 3.35 / 11.78 → 3.36 / 11.77 |
| V5 fresh | R | 0.4 → 0.3% (−0.1 pp, p = 0.58; 5 / 8) | - | - | 0.45 / 2.10 → 0.46 / 2.12 | 10.9 → 11.1 | 3.14 / 12.49 → 3.14 / 12.53 |
| V5 full | C_shatter | 17.3 → 16.7% (−0.7 pp, p = 0.35; 76 / 89) | 48.9 (92.7) → 49.5 (93.1)% | 26.2 (88.2) → 26.3 (86.9)% | 0.28 / 1.67 → 0.22 / 1.34 | 10.7 → 11.2 | 3.29 / 11.49 → 3.30 / 11.55 |
| V5 full | C_lantern | 12.2 → 13.8% (+1.6 pp, p = 0.08; 168 / 136) | 36.1 (92.6) → 38.3 (93.9)% | 18.4 (88.7) → 20.3 (89.1)% | 0.21 / 1.75 → 0.18 / 1.66 | 35.3 → 38.0 | 3.33 / 14.35 → 3.34 / 14.22 |
| V5 full | C_edge | 12.2 → 11.8% (−0.4 pp, p = 0.58; 75 / 83) | 54.5 (92.6) → 54.2 (91.9)% | 20.0 (82.3) → 19.4 (79.5)% | 0.21 / 1.11 → 0.16 / 0.89 | 16.1 → 16.5 | 3.28 / 12.25 → 3.27 / 12.25 |
| V5 full | A | 11.8 → 11.3% (−0.4 pp, p = 0.59; 105 / 114) | - | - | 0.20 / 1.30 → 0.10 / 0.63 | 23.3 → 24.3 | 3.44 / 13.16 → 3.43 / 13.17 |
| V5 full | A_lit | 13.8 → 14.5% (+0.8 pp, p = 0.35; 121 / 106) | - | - | 0.20 / 1.27 → 0.12 / 0.72 | 23.3 → 25.0 | 3.41 / 12.65 → 3.42 / 12.65 |
| V5 full | R | 3.9 → 4.7% (+0.8 pp, p = 0.08; 46 / 30) | - | - | 0.22 / 1.35 → 0.22 / 1.30 | 14.9 → 15.9 | 3.19 / 12.60 → 3.19 / 12.56 |

G3's second band at V5 full, 15000–16999, paired the same way: C_shatter +0.9 pp (99 / 81, p = 0.20), **C_lantern +1.9 pp (160 / 122, p = 0.03)**, C_edge +0.9 pp (97 / 79, p = 0.20), A_lit +1.2 pp (126 / 101, p = 0.11). On the 4,000 seeds together: C_shatter +0.1 pp (175 / 170, p = 0.83), **C_lantern +1.8 pp (328 / 258, p = 0.004)**, C_edge +0.2 pp (p = 0.62), A_lit +1.0 pp (247 / 207, p = 0.07).

What the instrument alone moved:

1. **Little, and nowhere significantly in the table.** All 24 arm-cell pairs of the table have p ≥ 0.07; the largest is the committed Lantern at V5 full, +1.6 pp (p = 0.08). Between 5% and 51% of each arm's runs are byte-identical to readout 13's (at V0 full the Lantern 54 of 1,000, at V5 fresh Shatter 1,028 of 2,000): wherever no draw ends a line and no Phantom Blades is offered, `s2`/`p9` plays as `s1`/`p8-d0-v3` does.
2. **One arm moves on the longer band.** The committed Lantern at V5 full gains 1.8 pp on 4,000 seeds (p = 0.004): +1.6 pp (p = 0.08) on the table's band, +1.9 pp (p = 0.03) on the second. With 28 paired tests, a correction for them (0.05 / 28 ≈ 0.0018) leaves none significant.
3. **Fewer Phantom Blades.** Every arm but R holds fewer at run end, most in the fresh pool (committed Shatter 0.92 → 0.56, Edge 0.92 → 0.44, A 0.55 → 0.37 at V0 fresh): a Duskblade deck draws few extra cards, so `p9` values the payoff at about 12 instead of 14.4. R builds at random and holds the same.
4. **A few more draws played, the same fights.** Draw cards played a run rise by 0.2–2.7 (the Lantern and the adaptive arms most), as `s2` no longer leaves a draw for last. Turns and HP lost a fight move by 0.13 at most.
5. **Reach hardly moves.** Over survivors, Steady by the end of Act 1 and True by the end of Act 2 move by 1.3 pp at most in the graded cells, except Edge's True at V5 full (82.3 → 79.5% of the survivors, G5's minimum there, still PASS on point and interval) and, in the ungraded V5 fresh cell, the Lantern's True (63.9 → 68.6%).

## The complete §11 table under `s2`

### Win rates, search player `s2`, pilot `p9`

Wilson 95% intervals. Readout 13's figure is in brackets.

| Cell | C_shatter | C_lantern | C_edge | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 fresh | 20.2% (17.8–22.8) [20.8%] | 33.7% (30.8–36.7) [33.6%] | 20.2% (17.8–22.8) [21.2%] | 25.6% (23.0–28.4) [24.1%] | 32.2% (29.4–35.2) [32.0%] | 7.4% (5.9–9.2) [7.1%] |
| V0 full | 50.5% (47.4–53.6) [49.3%] | 47.9% (44.8–51.0) [47.6%] | 40.6% (37.6–43.7) [39.6%] | 40.5% (37.5–43.6) [38.8%] | 48.2% (45.1–51.3) [47.1%] | 18.2% (15.9–20.7) [17.6%] |
| V5 fresh | 1.4% (1.0–2.0) [1.2%] | 4.3% (3.5–5.3) [3.8%] | 1.1% (0.7–1.6) [1.5%] | 2.4% (1.8–3.2) [2.0%] | 3.9% (3.1–4.8) [3.5%] | 0.3% (0.1–0.7) [0.4%] |
| V5 full | 16.7% (15.1–18.3) [17.3%] | 13.8% (12.4–15.4) [12.2%] | 11.8% (10.5–13.3) [12.2%] | 11.3% (10.0–12.8) [11.8%] | 14.5% (13.1–16.2) [13.8%] | 4.7% (3.8–5.7) [3.9%] |

### The gates

Every gate in every cell, point and 95% interval, against readout 13's verdicts. **Bold** marks a verdict that differs from readout 13's. G1 and G4 are readings (owner ruling of 30 September); the floor rows are arm A's, reported. The intervals here are the grader's, for a difference of two independent rates (Newcombe's hybrid score interval); the G3 table below also gives G3 paired on common seeds, which is narrower where the arms' outcomes on a seed correlate. All figures are rounded to one decimal of a point.

| Cell | Gate | Measured | Point | 95% interval | Interval | Readout 13 (point / interval) |
|---|---|---|---|---|---|---|
| V0 fresh | G1 | worst C_shatter 20.2% | FAIL | worst C_shatter 20.2% (17.8–22.8%, n=1000) | FAIL | FAIL / FAIL |
| V0 fresh | G2 | 13.5 pp (C_lantern − C_shatter) | FAIL | C_lantern − C_shatter +13.5 pp (+9.6 to +17.3, n=1000+1000) | UNDECIDED | FAIL / UNDECIDED |
| V0 fresh | G3 | A_lit 32.2% vs best 33.7% (−1.5 pp) | PASS | A_lit − C_lantern −1.5 pp (−5.6 to +2.6, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 fresh | G4 | R 7.4% vs worst 20.2% (−12.8 pp) | FAIL | R − C_shatter −12.8 pp (−15.8 to −9.8, n=1000+1000); R 7.4% (5.9–9.2%, n=1000) | FAIL | FAIL / FAIL |
| V0 fresh | G5 | Steady by end of Act 1 min 74.3% of runs alive (C_lantern; all runs 47.8%); True by end of Act 2 min 52.8% of runs alive (C_edge; all runs 21.5%) | PASS | Steady min C_lantern 74.3% (70.8–77.6%, n=643 alive) | PASS | PASS / PASS |
| V0 fresh | G6 | shatter 28.9%, lantern 31.1%, edge 40.1% of 322 A_lit wins | PASS | lead edge 40.1% (34.9–45.5%, n=322 A_lit wins) | PASS | PASS / PASS |
| V0 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 fresh | G3 floor (A) | A 25.6% vs best 33.7% (−8.1 pp) | FAIL | A − C_lantern −8.1 pp (−12.1 to −4.1, n=1000+1000) | FAIL | FAIL / FAIL |
| V0 fresh | G6 floor (A) | shatter 37.9%, lantern 22.3%, edge 39.8% of 256 A wins | PASS | lead edge 39.8% (34.0–45.9%, n=256 A wins) | PASS | PASS / PASS |
| V0 full | G1 | worst C_edge 40.6% | FAIL | worst C_edge 40.6% (37.6–43.7%, n=1000) | FAIL | FAIL / FAIL |
| V0 full | G2 | 9.9 pp (C_shatter − C_edge) | PASS | C_shatter − C_edge +9.9 pp (+5.5 to +14.2, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G3 | A_lit 48.2% vs best 50.5% (−2.3 pp) | PASS | A_lit − C_shatter −2.3 pp (−6.7 to +2.1, n=1000+1000) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G4 | R 18.2% vs worst 40.6% (−22.4 pp) | FAIL | R − C_edge −22.4 pp (−26.2 to −18.5, n=1000+1000); R 18.2% (15.9–20.7%, n=1000) | UNDECIDED | FAIL / UNDECIDED |
| V0 full | G5 | Steady by end of Act 1 min 89.4% of runs alive (C_lantern; all runs 67.5%); True by end of Act 2 min 87.8% of runs alive (C_edge; all runs 57.1%) | PASS | Steady min C_lantern 89.4% (87.0–91.4%, n=755 alive); True min C_edge 87.8% (85.1–90.1%, n=650 alive) | PASS | PASS / PASS |
| V0 full | G6 | shatter 22.2%, lantern 20.7%, edge 57.1% of 482 A_lit wins | PASS | lead edge 57.1% (52.6–61.4%, n=482 A_lit wins) | UNDECIDED | PASS / UNDECIDED |
| V0 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V0 full | G3 floor (A) | A 40.5% vs best 50.5% (−10.0 pp) | FAIL | A − C_shatter −10.0 pp (−14.3 to −5.6, n=1000+1000) | FAIL | FAIL / FAIL |
| V0 full | G6 floor (A) | shatter 20.2%, lantern 19.0%, edge 60.7% of 405 A wins | FAIL | lead edge 60.7% (55.9–65.4%, n=405 A wins) | UNDECIDED | FAIL / UNDECIDED |
| V5 fresh | G1 | worst C_edge 1.1% | n/a | worst C_edge 1.1% (0.7–1.6%, n=2000) | n/a | n/a / n/a |
| V5 fresh | G2 | 3.3 pp (C_lantern − C_edge) | PASS | C_lantern − C_edge +3.3 pp (+2.3 to +4.3, n=2000+2000) | PASS | PASS / PASS |
| V5 fresh | G3 | A_lit 3.9% vs best 4.3% (−0.4 pp) | PASS | A_lit − C_lantern −0.4 pp (−1.7 to +0.8, n=2000+2000) | PASS | PASS / PASS |
| V5 fresh | G4 | R 0.3% vs worst 1.1% (−0.8 pp) | FAIL | R − C_edge −0.8 pp (−1.3 to −0.2, n=2000+2000); R 0.3% (0.1–0.7%, n=2000) | FAIL | FAIL / FAIL |
| V5 fresh | G5 | Steady by end of Act 1 min 78.7% of runs alive (C_edge; all runs 24.1%); True by end of Act 2 min 40.2% of runs alive (C_edge; all runs 1.8%) | n/a | Steady min C_edge 78.7% (75.3–81.7%, n=614 alive) | n/a | n/a / n/a |
| V5 fresh | G6 | shatter 43.6%, lantern 30.8%, edge 25.6% of 78 A_lit wins | PASS | lead shatter 43.6% (33.1–54.6%, n=78 A_lit wins) | PASS | PASS / PASS |
| V5 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V5 fresh | G3 floor (A) | A 2.4% vs best 4.3% (−1.9 pp) | PASS | A − C_lantern −1.9 pp (−3.1 to −0.8, n=2000+2000) | **UNDECIDED** | PASS / PASS |
| V5 fresh | G6 floor (A) | shatter 62.5%, lantern 22.9%, edge 14.6% of 48 A wins | **FAIL** | lead shatter 62.5% (48.4–74.8%, n=48 A wins) | UNDECIDED | PASS / UNDECIDED |
| V5 full | G1 | worst C_edge 11.8% | FAIL | worst C_edge 11.8% (10.5–13.3%, n=2000) | FAIL | FAIL / FAIL |
| V5 full | G2 | 4.8 pp (C_shatter − C_edge) | PASS | C_shatter − C_edge +4.8 pp (+2.6 to +7.0, n=2000+2000) | PASS | PASS / PASS |
| V5 full | G3 | A_lit 14.5% vs best 16.7% (−2.1 pp) | **PASS** | A_lit − C_shatter −2.1 pp (−4.3 to +0.2, n=2000+2000) | UNDECIDED | FAIL / UNDECIDED |
| V5 full | G4 | R 4.7% vs worst 11.8% (−7.2 pp) | FAIL | R − C_edge −7.2 pp (−8.9 to −5.5, n=2000+2000); R 4.7% (3.8–5.7%, n=2000) | FAIL | FAIL / FAIL |
| V5 full | G5 | Steady by end of Act 1 min 91.9% of runs alive (C_edge; all runs 54.2%); True by end of Act 2 min 79.5% of runs alive (C_edge; all runs 19.4%) | PASS | Steady min C_edge 91.9% (90.3–93.4%, n=1180 alive); True min C_edge 79.5% (75.7–82.9%, n=488 alive) | PASS | PASS / PASS |
| V5 full | G6 | shatter 29.2%, lantern 20.6%, edge 50.2% of 291 A_lit wins | PASS | lead edge 50.2% (44.5–55.9%, n=291 A_lit wins) | PASS | PASS / PASS |
| V5 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS |
| V5 full | G3 floor (A) | A 11.3% vs best 16.7% (−5.3 pp) | FAIL | A − C_shatter −5.4 pp (−7.5 to −3.2, n=2000+2000) | FAIL | FAIL / FAIL |
| V5 full | G6 floor (A) | shatter 29.6%, lantern 17.7%, edge 52.7% of 226 A wins | PASS | lead edge 52.7% (46.2–59.1%, n=226 A wins) | PASS | PASS / PASS |

G7 covers zero stalls and zero errors in all 36,012 runs of the tables and the 8,000 of the second band, and arm A's three-seed replay, identical in every cell.

### G3 at V5 full, on 4,000 common seeds

A_lit minus the best committed arm on each common seed, with Newcombe's interval for a difference of paired proportions (`balance_readout.py g3`). On the table's band the grader's independent interval above reads −4.3 to +0.2 for the same −2.1 pp (−4.35 to +0.15 unrounded); paired, it is −4.26 to +0.07.

| V5 full | Best committed | A_lit − best (point) | Paired 95% interval | Verdict (point / interval) | Readout 13 (paired) |
|---|---|---|---|---|---|
| seeds 13000–14999 (the table) | C_shatter 16.7% | −2.1 pp | −4.3 to +0.1 | PASS / UNDECIDED | −3.5 pp (−5.6 to −1.4), FAIL / UNDECIDED |
| seeds 15000–16999 | C_shatter 17.0% | −3.1 pp | −5.2 to −1.0 | FAIL / UNDECIDED | −3.5 pp (−5.5 to −1.4), FAIL / UNDECIDED |
| both, 4,000 seeds | C_shatter 16.8% | **−2.6 pp** | **−4.1 to −1.1** | **PASS / UNDECIDED** | −3.5 pp (−5.0 to −2.0), FAIL / UNDECIDED |

On the 4,000 seeds A_lit wins 14.2% (readout 13: 13.2%), committed Shatter 16.8% (16.7%), the Lantern 14.1% (12.3%), Edge 12.1% (11.9%). Shatter stays the best committed way; A_lit and the Lantern gain about 1 and 1.8 pp. Paired on seed, the gap moved by +0.9 pp (−0.5 to +2.2): the change is within noise, and the point estimate sits 0.4 pp inside the −3 pp line instead of 0.5 pp outside it.

### Row B, the bot round (V0, `s2`)

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 | Readout 13: B1 / B2 |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 20.2% (17.8–22.8) | PASS | 81.0% (80.5–81.6) | 1.2% (1.1–1.4) | PASS | PASS / UNDECIDED |
| V0 fresh | C_lantern | 33.7% (30.8–36.7) | PASS | 63.1% (62.4–63.8) | 1.1% (0.9–1.3) | UNDECIDED | PASS / UNDECIDED |
| V0 fresh | C_edge | 20.2% (17.8–22.8) | PASS | 69.4% (68.7–70.1) | 1.8% (1.6–2.0) | PASS | PASS / PASS |
| V0 fresh | A_lit | 32.2% (29.4–35.2) | PASS | 58.6% (57.9–59.4) | 1.3% (1.1–1.4) | FAIL | PASS / FAIL |
| V0 full | C_shatter | 50.5% (47.4–53.6) | PASS | 82.9% (82.4–83.3) | 1.0% (0.9–1.2) | UNDECIDED | PASS / UNDECIDED |
| V0 full | C_lantern | 47.9% (44.8–51.0) | PASS | 72.8% (72.2–73.4) | 1.0% (0.9–1.2) | UNDECIDED | PASS / UNDECIDED |
| V0 full | C_edge | 40.6% (37.6–43.7) | PASS | 82.6% (82.1–83.1) | 1.4% (1.3–1.6) | PASS | PASS / PASS |
| V0 full | A_lit | 48.2% (45.1–51.3) | PASS | 63.5% (62.8–64.1) | 1.3% (1.1–1.4) | PASS | PASS / PASS |

B1 passes for every way in both pools, as in readout 13. B2 at V0 fresh moves from UNDECIDED to PASS for committed Shatter (its close calls, 1.2%, now clear the 1% floor on interval); the Lantern stays UNDECIDED on the floor (1.1%, 0.9–1.3), and the full pool's Shatter and Lantern stay UNDECIDED (1.0% each). A_lit's own feel at V0 fresh is 58.6% (57.9–59.4%) against 60%: a decided FAIL, as in readout 13 (59.2%).

## Every graded gate and reading, under P9's definition

`docs/rc-bar.md` P9: G2, G3, G5, G6, G7 and B are graded; G1 and G4 are readings; a figure is *short of its threshold* when it is FAIL on point or FAIL on interval.

**Graded figures short of their thresholds under `s2`:**

| Cell | Gate | Figure | Point / interval | Readout 13 |
|---|---|---|---|---|
| V0 fresh | G2 | C_lantern − C_shatter 13.5 pp (+9.6 to +17.3); Shatter and Edge tie at 20.2% | FAIL / UNDECIDED | 12.8 pp (C_lantern − C_shatter, +8.9 to +16.6): FAIL / UNDECIDED, the 1.0 verdict's reservation |
| V0 fresh | B2, A_lit's own feel | 58.6% (57.9–59.4%) against 60% | FAIL | 59.2%: FAIL |
| V5 full, 15000–16999 only | G3 | −3.1 pp (paired −5.2 to −1.0) | FAIL / UNDECIDED | −3.5 pp: FAIL / UNDECIDED |

No longer short: **G3 at V5 full**, on the table's band (−2.1 pp) and on the 4,000 seeds of record (−2.6 pp, −4.1 to −1.1), PASS on point and UNDECIDED on interval; readout 13 had it FAIL on point on both. Every other graded figure passes on point: G2 at V0 full (9.9 pp, UNDECIDED on interval, as before), G2 at V5 (3.3 and 4.8 pp, PASS / PASS), G3 at V0 fresh (−1.5 pp) and V0 full (−2.3 pp), both UNDECIDED on interval as before, and V5 fresh (−0.4 pp, PASS / PASS), G5 everywhere (PASS / PASS), G6 for A_lit everywhere (V0 full 57.1%, UNDECIDED on interval as before), G7, B1, and every committed way's B2 (PASS or UNDECIDED).

**Readings (never graded):** G1 fails in every graded cell, as in readout 13 (worst committed way 20.2% V0 fresh, 40.6% V0 full, 11.8% V5 full). G4 fails on point in every cell, with readout 13's interval verdicts (at V0 full R 18.2% against Edge's 40.6%, −22.4 pp, UNDECIDED on interval as before). The floors: arm A's G3 floor fails as before except at V5 fresh, where it still passes on point but its interval moves from PASS to UNDECIDED (−1.9 pp, −3.1 to −0.8); its G6 floor fails on point at V0 full (Edge 60.7% of A's wins, as before) and now also at V5 fresh (Shatter 62.5% of 48 wins; PASS in readout 13), both UNDECIDED on interval.

## The Ashwarden, development reading (not of record)

The Ashwarden declares no ways yet, so it has only the commit-blind arms. A, A_lit and R ran under both instruments on the development band, 200 paired seeds a cell (12000–12199), V0 and V5, in the `entry` pool (the Vigil at which the class unlocks) and the `full` pool. With no ways, A_lit has no colour to lean on and plays as A, row for row. The `s1` column is P3's instrument (pilot `p8-d0-v3`, search `s1`; its code paths are unchanged here, so these are the figures P3's tools give), run beside `s2` on the same seeds and head. Development seeds never enter a verdict; these figures say what the instrument does to the Ashwarden, not how strong the Ashwarden is.

| Cell | Arm | `s1` / `p8-d0-v3` | `s2` / `p9` | Paired change (gained / lost) | Deaths in Act 1 / 2 / 3 | Phantom Blades held / played a run | Draw cards played a run |
|---|---|---|---|---|---|---|---|
| V0 entry | A (= A_lit) | 25.5% (20.0–32.0) | 28.0% (22.2–34.6) | +2.5 pp (35 / 30, p = 0.62) | 12 / 71 / 66 → 6 / 69 / 69 | 0.80 / 4.71 → 0.69 / 4.13 | 57.0 → 58.2 |
| V0 entry | R | 6.0% (3.5–10.2) | 8.5% (5.4–13.2) | +2.5 pp (15 / 10, p = 0.42) | 48 / 105 / 35 → 42 / 108 / 33 | 0.71 / 4.92 → 0.70 / 5.29 | 29.3 → 34.7 |
| V0 full | A (= A_lit) | 55.5% (48.6–62.2) | 61.0% (54.1–67.5) | +5.5 pp (36 / 25, p = 0.20) | 7 / 42 / 40 → 9 / 38 / 31 | 0.28 / 1.49 → 0.22 / 1.14 | 58.0 → 57.8 |
| V0 full | R | 24.5% (19.1–30.9) | 24.0% (18.6–30.4) | −0.5 pp (22 / 23, p = 1.00) | 20 / 95 / 36 → 19 / 90 / 43 | 0.28 / 2.23 → 0.28 / 2.10 | 36.5 → 41.5 |
| V5 entry | A (= A_lit) | 1.5% (0.5–4.3) | 3.0% (1.4–6.4) | +1.5 pp (5 / 2, p = 0.45) | 103 / 69 / 25 → 99 / 72 / 23 | 0.80 / 3.21 → 0.64 / 2.66 | 26.3 → 28.0 |
| V5 entry | R | 1.0% (0.3–3.6) | 0.5% (0.1–2.8) | −0.5 pp (0 / 1, p = 1.00) | 157 / 37 / 4 → 155 / 39 / 5 | 0.67 / 3.34 → 0.60 / 3.04 | 15.8 → 16.9 |
| V5 full | A (= A_lit) | 21.0% (15.9–27.2) | 26.0% (20.4–32.5) | +5.0 pp (27 / 17, p = 0.17) | 48 / 75 / 35 → 50 / 76 / 22 | 0.28 / 1.44 → 0.25 / 1.11 | 36.1 → 36.8 |
| V5 full | R | 2.5% (1.1–5.7) | 6.0% (3.5–10.2) | +3.5 pp (10 / 3, p = 0.09) | 103 / 77 / 15 → 98 / 72 / 18 | 0.30 / 1.64 → 0.29 / 1.78 | 21.0 → 23.5 |

- **The 1.1 instrument plays the Ashwarden better.** Arm A gains in all four cells (+1.5 to +5.5 pp); no cell is significant on 200 seeds, but over the four cells A gains 103 seeds and loses 74 (exact two-sided p = 0.035). R gains 47 and loses 37 (p = 0.33). The decks hold fewer Phantom Blades than before, so the gain does not come from building towards the payoff; this table cannot split it between `s2` and `p9`.
- **`p9` takes Phantom Blades less often.** Valued by the hand an Ashwarden deck deals (about five cards, so 12 damage) instead of the flat 14.4, it is held 0.64–0.69 times a run in the `entry` pool against 0.80, and played less. With no Hand way to build towards and few draw cards, the honest worth of the payoff is lower than the flat weight was. Once the Ash lock gives the Hand way its producers, `p9` values the payoff by the deck that holds them.
- **Where the Ashwarden dies hardly moves**: in Acts 2 and 3 at V0, in Act 1 in the V5 `entry` pool and Act 2 in the V5 `full` pool.
- **Not comparable with the audit's figures.** The audit's development readings (arm A at V0 full 54%, fresh 31%, 100 seeds) ran before P3, when the search player credited the Duskblade's way verbs to every class. P3 removed that, so they no longer apply; this table is the Ashwarden's development baseline under both instruments.

## Tests and pins

- **New: `tests/test_balance_bots_hand.gd`.** The four probes, each stating whether `s1` finds it; the honest-play check (no credit for a payoff the draw deals); the draw credit's expected worth (multiset, reshuffle, unpayable cards 0, the Energy shared); `p9`'s Phantom Blades against `p8-d0-v3`'s (starter deck, three Tinders, `p8-d0-v3` unmoved by the deck); a foreign rider at 0 under `p9`, unchanged for the Duskblade; the simulator's flags and manifest. Seven mutants fail it (above).
- **`tests/test_balance_invariance.gd`.** Its 72 pins for `s1`/`p8-d0-v3` are unchanged and pass, now with the bots named explicitly. **48 pins** (`PINS_1_1`) for `p9`/`s2` beside them: every arm and cell on seed 12000, greedy and search. One of them, `v0-full/C_shatter/search/12000`, was re-pinned in the fix round's own commit: the Energy-shared draw credit moves it (the honest-payoff fix alone moves none). 21 of the 24 greedy `p9` rows equal `p8-d0-v3`'s (no Phantom Blades decision on those seeds). The panel leaves 1.0's bots selected for the tests after it (the first full-suite gate caught `test_balance_pilot_cache` reading `p9` scores). It adds about 27 s.
- **`tests/test_balance_ways.py`** (26 tests): every simulator command names its pilot, and under `--play search` its search player; an unknown bot or a search player for greedy play is refused; the grader names the bots in its result and header and refuses reports that differ in either. **`tests/test_balance_readout.py`** (57): the runner's chunks name 1.0's bots unless told otherwise, and 1.1's when told.
- **Unchanged and passing:** `test_balance_search` (the copy check, replay and the 60-fight floor against greedy play `s1`, the default), `test_balance_sim` (pins `Pilot.VERSION == "p8-d0-v3"`, the default), `test_balance_arms`, `test_balance_adaptive_lit`, `test_balance_pilot_play`, `test_balance_pilot_cache`, the seed-1000 and seed-1001 digests.
- **Anchors.** Nine citations of the pilot and simulator in two historical balance notes moved with the new lines: six re-anchored by `check_anchors.py --fix`, three re-pointed by hand to the lines they name (the shop's removal numerator in `choose_shop`, the simulator's reading of its arguments).
- **`docs/rc-bar.md` P9** names the 1.0 re-run's bots explicitly; the class template points the Ashwarden's readings at `--pilot p9 --search s2`.

## What the orchestrator must decide

The orchestrator restates the Duskblade's verdict for 1.1 on this reading; this readout gives none. The figures it turns on, from the fixed head:

1. **G2 at V0 fresh** is 13.5 pp (the Lantern over Shatter and Edge, tied at 20.2%; +9.6 to +17.3): FAIL on point and UNDECIDED on interval, the class of readout 13's 12.8 pp (the Lantern over Shatter, +8.9 to +16.6), the 1.0 verdict's one reservation. On common seeds the Lantern − Shatter gap moved by +0.7 pp (−3.1 to +4.5) and the Lantern − Edge gap by +1.1 pp (−3.0 to +5.2).
2. **G3 at V0 fresh** is −1.5 pp (paired −5.4 to +2.4): PASS on point, UNDECIDED, as in readout 13 (−1.6 pp).
3. **G3 at V5 full is no longer short on point.** −2.6 pp on 4,000 common seeds (−4.1 to −1.1), PASS on point and UNDECIDED, against readout 13's −3.5 pp, FAIL on point (a figure P9 records against the 1.0 verdict). The 15000–16999 band alone stays FAIL on point (−3.1 pp).
4. **A_lit's B2 at V0 fresh** stays a decided FAIL (58.6%; readout 13 59.2%), short as P9 already records.
5. **Classes that changed but are not graded:** arm A's G3 floor at V5 fresh (interval PASS → UNDECIDED) and its G6 floor at V5 fresh (PASS → FAIL on point, on 48 wins). B2 at V0 fresh for committed Shatter improves from UNDECIDED to PASS.
6. **The one arm under 0.05:** the committed Lantern at V5 full, +1.8 pp on 4,000 seeds (p = 0.004) and +1.9 pp on the second band (p = 0.03); none of the 28 paired tests survives a correction for them.
7. **The ruling below was given on the first candidate's figures.** Against them, three of the figures it cites change class: G2 at V0 fresh (a decided FAIL at 16.8 pp, the Lantern over Edge, +12.9 to +20.6) is now UNDECIDED on interval at 13.5 pp; the Lantern over Shatter (15.9 pp, +12.0 to +19.7, decided above 10 pp) is now 13.5 pp (+9.6 to +17.3), UNDECIDED; G3 at V0 fresh (−5.1 pp, FAIL on point) now passes on point at −1.5 pp. G3 at V5 full on 4,000 seeds (−2.6 pp), A_lit's B2 (58.6%, from 58.5%) and the Bonferroni line (none survives) keep their class. The orchestrator restated the ruling on these figures on 5 October 2026 (below).
8. **The default bots.** This PR keeps 1.0's (`p8-d0-v3`, `s1`) as the tools' default until 1.0 ships, and names 1.1's on every Ashwarden run. Moving the default is a two-constant change once the 1.0 re-run is done.

## The orchestrator's ruling (4 October 2026, restated 5 October 2026)

Given under the owner's delegation of design calls (30 September 2026) and #544's plan of record, decision 4.

**How the ruling changed.** The first ruling (4 October) was given on the first candidate's `s2`. Independent review then found that its payoff credit could use a card the line had only just drawn. The fix round also found that the draw credit priced each drawn card against the whole of the Energy left. Both were fixed (`5ff8c1b1`, `3dcbe37b`), and every table here was played again at `3dcbe37b`. On the fixed instrument, G2 at V0 fresh is no longer a decided FAIL, so the first ruling's items 3 and 4 lost their ground. The ruling below replaces them.

**1.0's instrument is unchanged.** Before ruling, the orchestrator ran readout 13's own commands at this branch with the bots unnamed, on seeds 13000–13099 in all four cells: 2,400 runs and arm A's 12 replay rows. All 2,412 rows and every chunk summary equal #544 P2's reproduction of readout 13. Every manifest names pilot `p8-d0-v3` and search player `s1`. Apart from its commit, each manifest matches the reproduction's, except `driverSha256`, the digest of the simulator file, which this branch changes. The fix commits leave 1.0's bots untouched: the 72 invariance pins pass, and the Ashwarden's `s1` panel is row-for-row identical before and after them.

1. **The 1.1 instrument is accepted.**
   - Pilot `p9` and search player `s2`, at `3dcbe37b`, are the instrument for every Ashwarden reading and for the Duskblade's 1.1 requalification.
   - They play what 1.0's bots cannot: four probes, of which `s1` misses three, with every mutant caught.
   - They plan only with cards already seen, and they price drawn cards against the Energy actually left. The Energy-sharing change is accepted: it corrects an overstatement in the draw credit, and it is honest play's other half.
   - On the Duskblade the instrument alone moves no table arm beyond chance. The smallest p-values (0.027 and 0.004, both at V5 full) do not survive a correction for the 28 paired tests (0.05 / 28 ≈ 0.0018).
   - The tools' default stays 1.0's until 1.0 ships.
2. **The 1.0 verdict stands unchanged.** It was given on readout 13 under 1.0's instrument, which P9 binds. Readout 14 is a new reading, not the independent re-run. It answers the 1.0 reservation's question: the fresh-pool Lantern lead persists under the better player, and it is of the size readout 13 saw.
   - The pair the reservation named, the Lantern over Shatter, reads 13.5 pp (+9.6 to +17.3), against readout 13's 12.8 pp (+8.9 to +16.6).
   - Both are FAIL on point and UNDECIDED on interval.
   - Nothing else here bears against the verdict. G3 at V5 full, short in readout 13, passes on point here (−2.6 pp on 4,000 common seeds).
3. **Interim reading for 1.1** (on 1.0's content; not a verdict). The 1.1 verdict, ACCEPT or NOT ACCEPTED, is given on the combined product at step A9. Read on 1.0's content under the 1.1 instrument, the Duskblade's design intent holds with the same one reservation as 1.0.
   - **G2 at V0 fresh** (Lantern 33.7% over Shatter and Edge, tied at 20.2%): 13.5 pp, FAIL on point and UNDECIDED on interval. This is the class readout 13's reservation had. Comparability holds in every other graded cell: G2 at V0 full and at V5 passes on point.
   - **A_lit's B2 at V0 fresh** (58.6%, a decided FAIL against 60%): as in 1.0, row B's feel test is the committed ways', and no committed way fails it. Shatter and Edge PASS. The Lantern is UNDECIDED: its close calls are 1.1% (0.9–1.3%), which is not short.
   - **G3 at V5 full on 15000–16999 alone** (−3.1 pp): G3's figure there is read on the 4,000 common seeds, −2.6 pp, which passes on point.
   - G3 at V0 fresh passes on point (−1.5 pp). G5, G6, B1 and G7 hold in every graded cell: no stall or error in 44,012 runs, and every replay identical.
4. **The fresh-pool Lantern lead stays the Duskblade's one reservation, carried into 1.1.** It does not block the 1.1 requalification. The verdict at A9 restates it with the combined product's figures.
   - A Duskblade fresh-pool wall lane is optional research. It may run at any time under the 1.1 instrument and the wall rule.
   - Any change it proposes lands only after the 1.0 release candidate is cut, because the Duskblade's 1.0 figures must not move (#544 decision 6).

## Appendix: the scripts

The tables come from the repository's runner and graders (`tools/balance_readout.py`, `tools/balance_ways.py`). Four short scripts in the lane's scratch folder read the merged reports:

| Script | What it does |
|---|---|
| `instr14.py` | The instrument-alone table: per arm and cell, win before and after with the paired change, reach over all runs and over survivors, Phantom Blades held and played, draw cards played, turns and HP lost a fight. |
| `gapchange.py` | How a gate's gap moved between two instruments on common seeds: per seed (a − b) new less (a − b) old, its mean and 95% interval. |
| `ash14.py` | The Ashwarden's development table under two instruments, paired on seed. |
| `rowdiff.py` | Rows that differ between two run directories, report by report, on common seeds. |
