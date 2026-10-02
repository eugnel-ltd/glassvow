# Readout 13: the instrument's fidelity and the Lantern's lean

> **Research readout (AI-SDLC discovery), promoted in one PR.** The PR ships three things. (1) An instrument change: the committed bot (pilot `p8-d0-v3`, `58651b00`) removes its two off-colour starter seeds first when a removal is offered, and its ×3 covers two copies of a card. (2) The orchestrator's ruling on G5: reachability is graded over the runs alive at the end of the act in question, with the all-runs figure beside it (`tools/balance_ways.py`; lock §11 amended). (3) One content lever: Hearthfall loses its amber rider, base and upgraded (`1190be25`); `content/full-content.json` loses two effects and two sentences, and its SHA-256 is now `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`. No id, number, rarity, pool entry, enemy number, save field, global knob or game RNG draw moved. From this readout on, the improved bot is the reading of record; readouts 1–12 stay as recorded.
>
> **Head.** The final tables (V0 at 1,000 paired seeds, V5 at 2,000, and G3's second V5 full band of 2,000) ran at `1190be25`, whose manifest every report names, before this branch was rebased onto `main` (readout 12's squash, `a140db83`, and a TestFlight build bump). The rebase carried the instrument commit `58651b00` to `b1d8add6` and the content commit `1190be25` to `95aa62dc`; `git diff 1190be25 95aa62dc -- tools domain content` is empty. Later commits re-pin tests, re-anchor two historical notes and add documents only.

Readout 12 made True reachable in the full pool and left the committed Lantern's fresh-pool lead a decided G2 FAIL (+17.9 pp). It also named two habits of the committed bot that no player has: it never removed its off-colour starter seeds, and it tripled every copy of a card in its colour. This lane fixes the instrument first and reads what that alone moves, paired on readout 12's own seeds; then diagnoses the Lantern's lean with the fixed bot, screens three single levers, and ships the one that survives. It is the last lane before the owner's acceptance verdict, so it ends with the complete §11 table.

## The answer in brief

- **The instrument alone** (readout 12's content and seeds, paired run for run): committed runs now remove their off-colour seeds (at V0, 80–86% end with at least one gone; before, none) and hoard less (Fan of Glass 2.42 → 1.77 a run at V0 full). True by the end of Act 2 among survivors rises from 26–77% to 52–94% at V0. The committed arms get stronger at V0 full (Shatter +6.4 pp, p < 0.001; the Lantern +3.6 pp, p = 0.04) and the Lantern weaker at V5 full (−3.0 pp, p = 0.001: the seeds it removes are its two best starter attacks and 75 gold). G3 at V0 full falls from PASS (−2.5 pp) to FAIL (−6.1 pp), because the best committed arm rose and A_lit builds as before; G2 at V0 full widens from 10.9 to 13.8 pp. The Lantern's fresh lead does not move (+0.7 pp, p = 0.71): it is not the bot's.
- **G5 over survivors.** On the orchestrator's ruling, G5 now counts the runs alive at the act's end; the all-runs figure is printed beside it. It passes on point and interval in every graded cell, the instrument's improvement included (V0 full Steady minimum 89.6% of survivors, True 87.6%; V5 full 92.6% and 82.3%).
- **Diagnosis.** The committed Lantern is the weakest way in Act 1 and the strongest after it: at V0 fresh it wins 72.5% of its runs alive at the end of Act 2, against 40–49%. Its engine turns Embers into free damage; Hearthfall (no Energy, 3 Embers, 12 damage) is played 27 times a run, and its own amber rider refunded a third of its cost. Its win gradient among Act 2 survivors (18% with no copy, 79% with three or more) is the steepest of any card. True does not carry the lead; Tinder and Cathedral Glass do not either.
- **Three candidates, one shipped.** H: Hearthfall loses its rider. T: Tinder loses its rider. F: Steady's first Ember gain of a turn yields +1, not +2. On 400 development seeds H took 8.2 pp off the Lantern at V0 fresh (p < 0.01) and moved no other committed way; T moved nothing; F cut every lit deck. **H ships.**
- **The final table.** Against the improved-bot baseline, H takes 4.8 pp off the committed Lantern at V0 fresh and 5.8 pp at V0 full (both p < 0.001), 1.4–1.6 pp at V5, and moves no other arm significantly. G2 at V0 full passes on point (9.7 pp, Shatter − Edge); G2 at V0 fresh goes from a decided FAIL (17.9 pp in readout 12) to 12.8 pp, UNDECIDED. G3 passes on point at V0 fresh (−1.6 pp), V0 full (−2.2 pp) and V5 fresh (−0.3 pp, PASS on interval too). G6 passes in every cell; G5 passes on point and interval in every graded cell; B1 and G7 hold.
- **G3 at V5 full** is −3.5 pp on 4,000 paired seeds with the improved bot (−5.0 to −2.0), FAIL on point and UNDECIDED, 0.5 pp outside its band (readout 12: −3.8 pp). Deciding it would need about 36,000 paired seeds per arm; this lane stops there.
- **What worsens against readout 12.** G6's floor (arm A) at V0 full fails on point (Edge 61.3% of A's wins); G3 at V5 full fails on point on the table's band (−3.5 pp, was −2.9); G3's floor at V5 full fails on interval; the committed Lantern at V5 loses 2.6 pp (fresh) and 4.6 pp (full) and is now the joint weakest way at V5 full. A_lit's B2 at V0 fresh stays a decided FAIL (59.2%). G1 and G4 fail as instrument readings.

## The question

Two of readout 12's open items were the instrument's, not the game's: the committed bot never removed its two off-colour starter seeds, and it tripled every copy of a card in its colour, so it hoarded cheap ones. Fixed, what does the instrument alone move, on the same seeds and content? Read with the fixed bot, where does the committed Lantern's fresh-pool lead come from, and can at most three single levers that follow from that bring G2 at V0 within 10 pp in both pools and G3 at V0 fresh back into range, without losing G5 full, G6 full, B1 or G7? Is G3 at V5 full decided once the improved bot plays the 4,000 paired seeds? And G5 is graded from this readout over the runs alive at the act's end (the orchestrator's ruling).

## The instrument

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-readout13", removed before each commit.
# 1. The improved bot's committed arms on readout 12's final bands and content (instrument commit 58651b00):
python3 -B chunked.py s/base-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --arms C_shatter,C_lantern,C_edge --play search
python3 -B chunked.py s/base-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --arms C_shatter,C_lantern,C_edge --play search
python3 -B instr.py s/base-v0 <readout 12 final-v0> v0-fresh,v0-full     # the paired before/after
python3 -B merge13.py s/basetab-v0 v0; python3 -B tools/balance_ways.py --from-dir s/basetab-v0 --seeds 13000-13999 --vows 0
# 2. Diagnosis on those reports:
python3 -B lean.py s/basetab-v0 v0-fresh,v0-full                          # the win chain, lit share, rider plays, gradients
# 3. The screen: head and three candidate catalogues (cand13.py), development seeds 12000-12399, V0 fresh and full,
#    the committed arms and A_lit:
zsh stage2.sh; python3 -B screen_grade.py screen base hearth tinder firstgain
# 4. The final tables at the content commit 1190be25 (readout 9's appendix B runner), and G3's second V5 full band:
python3 -B chunked.py s/final-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay
python3 -B chunked.py s/final-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay
python3 -B chunked.py s/ext-v5 --seeds 15000-16999 --cells v5-full --arms C_shatter,C_lantern,C_edge,A_lit --play search
# Grading: the lock's table, paired changes against the improved-bot baseline and readout 12, row B, paired G3:
python3 -B tools/balance_ways.py --from-dir s/final-v0 --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir s/final-v5 --seeds 13000-14999 --vows 5
python3 -B fulltable.py s/final-v0 s/final-v5 s/basetab-v0 s/basetab-v5 <readout 12 final-v0> <readout 12 final-v5>
python3 -B paired.py s/final-v0 s/basetab-v0 v0-fresh,v0-full; python3 -B g3paired.py s/final-v5 v5-fresh,v5-full
python3 -B merge.py s/g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/final-v5 s/ext-v5; python3 -B g3paired.py s/g3-4000 v5-full
```

- **Cells, arms, seeds.** The instrument's before/after and the final tables use readout 12's bands (V0 13000–13999, V5 13000–14999), so every row pairs with readout 12's report and with the improved-bot baseline on its seed. The screen used 400 development seeds (12000–12399). G3 at V5 full read readout 12's second band, 15000–16999, again.
- **The improved-bot baseline.** Its committed reports ran at `58651b00`. A, A_lit and R build exactly as before (they hold no way), so the baseline table takes their reports, and the replays, from readout 12; its rows are byte-identical on every seed (the paired tables show 1,000 and 2,000 identical runs). The grader wants one build identity, so `merge13.py` stamps scratch copies of the manifests with every source; this table is a scratch reading, not an exam table. The final tables ran at one commit, `1190be25`.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference of independent rates), G5 now over survivors; row B as readouts 8–12 compute it; paired tests that count the seeds one configuration wins and the other loses, with an exact two-sided binomial p; G3 on common seeds with Newcombe's paired interval (`g3paired.py`).
- **Budget and stop rule.** At most three candidates, each a single lever, screened together; a candidate survived if it moved the Lantern without a significant cost to another committed arm. Survivors went to the final table together.
- **Wall time.** The baseline's committed arms took 28 minutes at V0 and 29 at V5 on ten processes; the screen 14 minutes a configuration (four); the final V0 table 44 minutes, the V5 table 49 minutes and the second V5 full band 26 minutes.

## The instrument's fidelity

### What changed in the bot

Readout 12 named two habits of the committed pilot that no player shares. Both are fixed in `tools/balance_pilot.gd` (pilot `p8-d0-v3`, `58651b00`), for the committed arms only; `tools/balance_sim.gd` routes every removal and every offered card through the two new functions.

- **Removal takes the off-colour seeds first.** `removal_target` returns a committed bot's off-colour starter seed (the lowest scored of the two) while the deck holds one, else the worst card as before; `removal_worth` values that removal at the full `removalAppetite`, as a card worth nothing to the committed deck. The shop buys it out whatever its copies (the two-copy rule still governs every other removal); the Forgotten Shrine and the Mirror take it; an event's removal is scored with it. The lock's own worked example removes Eclipse Slash at the shop (§4).
- **The ×3 covers two copies.** `offer_card_score` is the score of a card offered to the deck (rewards, shop cards, event picks): once the deck holds two copies of a card of the bot's way, a further copy is weighed at its catalogue worth, as clear glass. The deck is counted when the bot looks before each build decision (`see_flame`) and as it buys in a shop. Cards already held keep their ×3, so removals and upgrades read as before. Fan of Glass (catalogue 9.6, under the 14.1 the pilot needs to take a card) was taken at 28.8 every time; a third copy is now declined unless nothing better is offered.

Arm A, A_lit and R are untouched: they hold no way, and their reports on every seed are byte-identical to readout 12's. A_lit was checked with the seed removal too (a scratch build in which A_lit, while lit, removed the seeds off its lit colour; not kept): it lost 2.7 pp at V0 full (40 seeds won, 67 lost; p = 0.01) and 0.5 pp at V0 fresh (p = 0.69). For a player who does not insist on a way, the two seeds are good cards (Eclipse Slash and Chisel score 24 and 20, above most commons), so the adaptive arms keep arm A's removal. No game RNG draw moves: the bots' own decisions change, so a committed run's deck, and everything that follows from it, differs from readout 12's on the same seed.

### Paired before and after: the instrument alone

Readout 12's final reports (content `87c879c4…`, head `641126ab`) against the improved bot on the same seeds and the same content. Paired change: seeds the new bot won and the old lost, against the reverse, with the exact two-sided binomial p. Steady and True are shown over all runs and, in brackets, over the runs alive at that act's end (G5's new denominator).

| Cell | Arm | Win, old → new (paired) | Steady by end of Act 1, old → new | True by end of Act 2, old → new | Runs ending with both / neither off-colour seed | Removals a run | Copies a run |
|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 19.8 → 21.0% (+1.2 pp, p = 0.50) | 73.8 (92.5) → 78.0 (95.4)% | 41.2 (77.4) → 49.7 (94.3)% | 100 / 0 → 14 / 60% | 1.17 → 1.61 | Fan of Glass 2.13 → 1.63, Quarry Maul 2.46 → 2.10 |
| V0 fresh | C_lantern | 37.7 → 38.4% (+0.7 pp, p = 0.71) | 45.5 (68.4) → 48.3 (74.4)% | 19.5 (37.4) → 33.3 (62.8)% | 100 / 0 → 20 / 53% | 1.00 → 1.50 | Tinder 2.64 → 2.49, Hearthfall 2.29 → 2.07 |
| V0 fresh | C_edge | 22.7 → 21.2% (−1.5 pp, p = 0.38) | 59.6 (73.7) → 66.0 (80.6)% | 11.1 (25.7) → 22.9 (52.4)% | 100 / 0 → 17 / 52% | 1.03 → 1.45 | Dim the Glass 2.86 → 2.69 |
| V0 full | C_shatter | 42.7 → 49.1% (**+6.4 pp, p < 0.001**) | 77.1 (87.8) → 80.4 (91.6)% | 51.7 (74.0) → 64.8 (88.4)% | 100 / 0 → 15 / 57% | 1.15 → 1.54 | Fan of Glass 2.42 → 1.77, Quarry Maul 2.76 → 2.23 |
| V0 full | C_lantern | 49.8 → 53.4% (**+3.6 pp, p = 0.04**) | 68.8 (87.0) → 69.7 (89.8)% | 47.9 (73.5) → 57.1 (88.4)% | 100 / 0 → 19 / 47% | 0.99 → 1.37 | Tinder 3.34 → 3.00, Hearthfall 2.67 → 2.30 |
| V0 full | C_edge | 38.9 → 39.6% (+0.7 pp, p = 0.74) | 83.4 (91.7) → 85.4 (92.7)% | 45.2 (72.2) → 56.1 (87.9)% | 100 / 0 → 20 / 42% | 0.98 → 1.28 | Dim the Glass 3.52 → 2.93 |
| V5 fresh | C_shatter | 1.7 → 1.1% (−0.6 pp, p = 0.18) | 30.3 (95.6) → 31.6 (97.8)% | 7.6 (79.6) → 8.6 (96.1)% | 100 / 0 → 35 / 26% | 0.53 → 0.96 | Fan of Glass 1.10 → 0.98 |
| V5 fresh | C_lantern | 6.5 → 5.2% (−1.2 pp, p = 0.06) | 17.8 (83.4) → 17.6 (87.5)% | 4.3 (37.0) → 7.2 (65.8)% | 100 / 0 → 40 / 20% | 0.48 → 0.86 | Hearthfall 1.13 → 1.02 |
| V5 fresh | C_edge | 2.4 → 1.5% (**−0.9 pp, p = 0.04**) | 22.3 (73.5) → 24.5 (79.4)% | 1.6 (20.5) → 2.5 (40.7)% | 100 / 0 → 39 / 21% | 0.53 → 0.87 | Dim the Glass 1.43 → 1.36 |
| V5 full | C_shatter | 15.9 → 16.9% (+1.1 pp, p = 0.26) | 48.0 (89.0) → 48.9 (92.7)% | 19.8 (64.7) → 26.2 (88.4)% | 100 / 0 → 34 / 34% | 0.69 → 1.10 | Fan of Glass 1.43 → 1.21 |
| V5 full | C_lantern | 16.8 → 13.8% (**−3.0 pp, p = 0.001**) | 39.2 (89.6) → 39.1 (93.1)% | 18.9 (69.7) → 20.7 (89.2)% | 100 / 0 → 42 / 23% | 0.60 → 0.87 | Hearthfall 1.54 → 1.31 |
| V5 full | C_edge | 12.3 → 12.2% (−0.1 pp, p = 1.00) | 52.6 (88.0) → 54.5 (92.6)% | 14.0 (55.1) → 19.9 (81.9)% | 100 / 0 → 37 / 24% | 0.61 → 0.91 | Dim the Glass 1.98 → 1.77 |

What the instrument change alone moved:

1. **True became what a committed player reaches.** Among runs alive at the end of Act 2, True rose from 26–77% to 52–94% at V0 and from 21–80% to 41–96% at V5. At V0, 80–86% of committed runs now end with at least one off-colour seed removed and 42–60% with both; at V5, where fewer live to a shop, 58–66% and 20–34%.
2. **The committed arms got stronger at V0 full** (Shatter +6.4 pp, p < 0.001; the Lantern +3.6 pp, p = 0.04), Shatter most because it no longer keeps a third and fourth Fan of Glass.
3. **At V5 the removal costs gold and a good card.** The committed Lantern loses 3.0 pp at V5 full (p = 0.001) and Edge 0.9 pp at V5 fresh (p = 0.04): the two seeds it removes are Chisel and Eclipse Slash, its two best starter attacks, and the 75 gold is a card or a relic at a vow where both are scarce.
4. **The gates it moved.** On readout 12's content, with A, A_lit and R unchanged: G2 at V0 full widens from 10.9 to 13.8 pp (the Lantern over Edge); G3 at V0 full moves from PASS (−2.5 pp) to FAIL (−6.1 pp), because the best committed arm rose and A_lit did not; G3 at V5 full moves from −2.9 to −3.1 pp (FAIL on point, interval UNDECIDED); G3 at V5 fresh gains an interval PASS (−1.3 pp, −2.6 to −0.0 paired); G2 at V0 fresh narrows from 17.9 to 17.4 pp (still a decided FAIL). G5 passes in every graded cell on its new denominator (next section).
5. **The Lantern's fresh lead does not move** (+0.7 pp, p = 0.71): it is not the bot's doing.

## Diagnosis: the Lantern's lean, read with the improved bot

All figures are from the improved bot's committed reports on readout 12's bands and content (V0 at 1,000 seeds, V5 at 2,000), with A, A_lit and R from readout 12 (they are unchanged). Wilson 95% intervals.

### Where the lead is made: a chain of three rates

A win is three things in a row: living to the end of Act 1, then to the end of Act 2, then winning Act 3.

| V0 fresh | Win | Alive at the end of Act 1 | Alive at the end of Act 2, of those | Win, of runs alive at the end of Act 2 |
|---|---|---|---|---|
| C_shatter | 21.0% (18.6–23.6) | 81.8% (79.3–84.1) | 64.4% (61.1–67.6) | 39.8% (35.8–44.1) |
| C_lantern | 38.4% (35.4–41.5) | **64.9%** (61.9–67.8) | **81.7%** (78.5–84.5) | **72.5%** (68.5–76.1) |
| C_edge | 21.2% (18.8–23.8) | 81.9% (79.4–84.2) | 53.4% (49.9–56.8) | 48.5% (43.9–53.2) |
| A_lit | 31.9% (29.1–34.9) | 69.3% (66.4–72.1) | 75.3% (72.0–78.4) | 61.1% (56.9–65.2) |

| V0 full | Win | Alive at the end of Act 1 | Alive at the end of Act 2, of those | Win, of runs alive at the end of Act 2 |
|---|---|---|---|---|
| C_shatter | 49.1% (46.0–52.2) | 87.8% (85.6–89.7) | 83.5% (80.9–85.8) | 67.0% (63.5–70.3) |
| C_lantern | 53.4% (50.3–56.5) | **77.6%** (74.9–80.1) | 83.2% (80.5–85.7) | **82.7%** (79.6–85.4) |
| C_edge | 39.6% (36.6–42.7) | 92.1% (90.3–93.6) | 69.3% (66.2–72.2) | 62.1% (58.2–65.8) |
| A_lit | 47.3% (44.2–50.4) | 77.7% (75.0–80.2) | 79.0% (76.0–81.7) | 77.0% (73.5–80.2) |

The committed Lantern is the weakest way in Act 1 (65% alive at V0 fresh, against 82%) and the strongest from then on: in the fresh pool it survives Act 2 more often (82% against 53–64%) and converts Act 3 far more often (72.5% against 40–49%). Its lead is made after its lantern is lit. In Act 2 and Act 3 it fights 84–96% of its fights lit amber, but only 46–65% True; Shatter fights 84–96% True and still converts 40%. True is not what carries it.

### What it plays

Per run at V0 fresh, the committed Lantern holds and plays:

| | Tinder | Struck Match | Hearthfall | Cathedral Glass | Embers gained / spent per fight |
|---|---|---|---|---|---|
| held at run end | 2.49 | 1.71 | 2.07 | 3.02 | |
| played a run | 18.0 | 13.3 | **27.1** | 8.6 | 12.8 / 8.8 (Shatter 9.2 / 4.5, Edge 8.7 / 5.4) |

Hearthfall is the most-played card in the arm's deck: no Energy, 3 Embers, 12 damage (16 upgraded), and readout 9's amber rider gave 1 Ember back, so under a lit flame it cost 2 Embers net. With Steady's +2 on the first Ember gain each turn and the riders on Tinder and Struck Match, a lit Lantern turns Embers into free damage every turn; the other ways spend about half as many Embers (on the Art). Among the committed Lantern's runs alive at the end of Act 2, the win rate climbs with Hearthfall copies: 2 of 11 runs with none, 9 of 25 with one, 89 of 133 (67%) with two, 284 of 361 (79%) with three or more. No other card shows a gradient like it (Tinder 70 / 62 / 68 / 75%; Cathedral Glass, held three times or more by 488 of 530 runs, 73%; Struck Match 43 / 68 / 68 / 81%). This is association, not cause; the screen tests it.

### Not the pool's rares, not True

- Cathedral Glass is held three or more times in 92% of the Lantern's Act 2 survivors, so its effect cannot be read off the reports, and readout 12's K3 (Cathedral Glass made clear glass) did not narrow G2. The fresh rare pool was not a candidate.
- A threshold or True-only rider would be a printed rule the lock forbids (§6.4: a rider names its colour, never a tier) and would not reach the lead: the Lantern converts Act 3 while True in only 65% of its fights.

### The diagnosis in five lines

1. The committed Lantern's fresh lead (+17.4 pp over Shatter with the improved bot) is not the bot's: the instrument change moved it by +0.7 pp (p = 0.71).
2. It is made after the lantern is lit: the weakest way in Act 1 (65% alive), it survives Act 2 82% of the time and wins 72.5% of its Act 3s, against 40–49%.
3. Its engine is Embers into free damage: 12.8 Embers gained a fight against 8.7–9.2 for the others, Hearthfall played 27 times a run.
4. Hearthfall's own amber rider closes the loop: the spend card refunds a third of its cost, and its win gradient (36% → 79% of Act 2 survivors from one copy to three or more) is the steepest of any card.
5. Not True (Lantern True in 46–65% of late fights against Shatter's 84–96%), not Cathedral Glass (readout 12's K3), not Tinder (its gradient is flat).

## The candidates

Three single levers, each following from a line of the diagnosis, each a minimal text edit of the content file (`cand13.py`):

| | Lever | From the diagnosis |
|---|---|---|
| H | Hearthfall loses its amber rider, base and upgraded ("Spend 3 Embers: deal 12 damage.") | lines 3–4: the rider refunds the Lantern's own spend card; the steepest win gradient of any card |
| T | Tinder loses its amber rider ("Draw 2 cards. Kindle.") | "fewer riders": the most-held rider card (2.5 a run), the other end of the engine (draw and Embers) |
| F | Steady and True's first Ember gain of each turn yields +1, not +2 (`steadyFirstGain` 2 → 1) | line 3, the Ember economy's late scaling: the Lantern gains 12.8 Embers a fight against 8.7–9.2. It is a §5 lantern knob, the same for every way |

Riders that resolve only at True, or only on the first play a turn, were not screened: the first prints a tier, which §6.4 forbids, and the diagnosis puts the lead in lit fights that are mostly not True; the second needs a new rule and a longer face on four cards for a lever the screen could test more cheaply as H or T.

### The screen: development seeds 12000–12399, V0, improved bot

400 seeds per arm and cell, the committed arms and A_lit, search player. Each arm's win rate, with its paired change against the head on the same seeds (pp, exact p). G5 is read over survivors.

| Cell | Candidate | C_shatter | C_lantern | C_edge | A_lit | G2 | G3 (A_lit − best) | G6 S / L / E of A_lit's wins |
|---|---|---|---|---|---|---|---|---|
| V0 fresh | head | 22.0% | 43.5% | 21.2% | 29.8% | 22.2 pp FAIL | −13.8 pp FAIL / FAIL | 31.1 / 33.6 / 35.3% PASS / PASS |
| V0 fresh | H | 21.2% (−0.8, p = 0.25) | **35.2% (−8.2, p < 0.01)** | 21.2% (+0.0, p = 1.00) | 29.0% (−0.8, p = 0.68) | 14.0 pp FAIL | −6.2 pp FAIL / UNDECIDED | 31.9 / 32.8 / 35.3% PASS / PASS |
| V0 fresh | T | 22.0% (+0.0, p = 1.00) | 42.2% (−1.2, p = 0.56) | 20.8% (−0.5, p = 0.50) | 30.5% (+0.8, p = 0.71) | 21.5 pp FAIL | −11.8 pp FAIL / FAIL | 30.3 / 32.0 / 37.7% PASS / PASS |
| V0 fresh | F | 20.5% (−1.5, p = 0.42) | 37.0% (−6.5, p = 0.01) | 18.2% (−3.0, p = 0.24) | 27.2% (−2.5, p = 0.13) | 18.8 pp FAIL | −9.7 pp FAIL / FAIL | 31.2 / 33.9 / 34.9% PASS / PASS |
| V0 full | head | 50.5% | 52.0% | 41.2% | 48.0% | 10.8 pp FAIL | −4.0 pp FAIL / UNDECIDED | 20.8 / 28.1 / 51.0% PASS / PASS |
| V0 full | H | 50.8% (+0.2, p = 1.00) | 48.2% (−3.8, p = 0.11) | 40.8% (−0.5, p = 0.50) | 44.5% (−3.5, p < 0.01) | 10.0 pp PASS | −6.2 pp FAIL / UNDECIDED | 22.5 / 23.6 / 53.9% PASS / UNDECIDED |
| V0 full | T | 50.5% (+0.0, p = 1.00) | 50.8% (−1.2, p = 0.58) | 41.0% (−0.2, p = 1.00) | 47.0% (−1.0, p = 0.52) | 9.7 pp PASS | −3.7 pp FAIL / UNDECIDED | 20.2 / 23.9 / 55.9% PASS / UNDECIDED |
| V0 full | F | 50.8% (+0.2, p = 1.00) | 47.5% (−4.5, p = 0.10) | 41.8% (+0.5, p = 0.91) | 44.8% (−3.2, p = 0.05) | 9.0 pp PASS | −6.0 pp FAIL / UNDECIDED | 21.8 / 27.9 / 50.3% PASS / PASS |

Reach on the screen, Shatter / Lantern / Edge, over the runs alive at the act's end:

| Cell | Candidate | Steady by end of Act 1 | True by end of Act 2 |
|---|---|---|---|
| V0 fresh | head | 95.6 / 79.1 / 81.8% | 91.3 / 63.9 / 56.9% |
| V0 fresh | H | 95.3 / 78.1 / 81.8% | 91.7 / 65.6 / 57.8% |
| V0 fresh | T | 95.6 / 79.6 / 81.3% | 91.7 / 65.9 / 56.2% |
| V0 fresh | F | 95.5 / 75.7 / 83.2% | 91.1 / 68.9 / 60.5% |
| V0 full | head | 89.5 / 91.7 / 92.4% | 87.2 / 90.2 / 85.4% |
| V0 full | H | 89.5 / 90.8 / 92.4% | 87.2 / 89.8 / 85.4% |
| V0 full | T | 89.3 / 91.8 / 92.4% | 86.9 / 90.2 / 85.4% |
| V0 full | F | 89.5 / 91.9 / 92.5% | 86.9 / 88.8 / 87.9% |

**The choice.**

- **H survives.** It is the only lever aimed at the Lantern that the Lantern alone pays for: −8.2 pp at V0 fresh (p < 0.01) and −3.8 pp at V0 full (p = 0.11), while Shatter and Edge move by under 1 pp (p ≥ 0.25). It halves G2 at V0 fresh on the screen (22.2 → 14.0 pp) and brings V0 full to 10.0 pp. Its cost is A_lit in the full pool (−3.5 pp, p < 0.01): the flame-aware arm plays the Lantern too, and keeps Hearthfall when its lantern burns amber. Reach does not move.
- **T is out.** It moves nothing measurable (the Lantern −1.2 pp at both cells, p ≥ 0.56). Tinder's Ember is not the engine.
- **F is out.** It cuts the Lantern almost as much in the fresh pool (−6.5 pp, p = 0.01) but takes every lit deck with it: Edge −3.0 pp and A_lit −2.5 pp in the fresh pool, A_lit −3.2 pp (p = 0.05) in the full. A shared knob cannot narrow a gap between ways it applies to equally.
- **H goes to the final table alone.**

## The cell table

### Win rates, search player

Each figure has its Wilson 95% interval, then its paired change against the improved-bot baseline on the same seeds (the lever alone) and against readout 12 (the instrument and the lever together).

| Cell | C_shatter | C_lantern | C_edge | A | **A_lit** | R |
|---|---|---|---|---|---|---|
| V0 fresh (N = 1,000) | 20.8% (18.4–23.4) [−0.2, p = 0.73; +1.0 vs r12] | 33.6% (30.7–36.6) [**−4.8, p < 0.001**; **−4.1, p = 0.02**] | 21.2% (18.8–23.8) [+0.0; −1.5, p = 0.38] | 24.1% (21.6–26.8) [+1.2, p = 0.14] | **32.0% (29.2–35.0)** [+0.1, p = 1.00] | 7.1% (5.7–8.9) [−0.2, p = 0.73] |
| V0 full (N = 1,000) | 49.3% (46.2–52.4) [+0.2, p = 0.69; **+6.6, p < 0.001** vs r12] | 47.6% (44.5–50.7) [**−5.8, p < 0.001**; −2.2, p = 0.23] | 39.6% (36.6–42.7) [+0.0; +0.7, p = 0.74] | 38.8% (35.8–41.9) [+0.7, p = 0.38] | **47.1% (44.0–50.2)** [−0.2, p = 0.88] | 17.6% (15.4–20.1) [−0.1, p = 1.00] |
| V5 fresh (N = 2,000) | 1.2% (0.8–1.8) [+0.1; −0.5, p = 0.23] | 3.8% (3.0–4.7) [**−1.4, p = 0.01**; **−2.6, p < 0.001**] | 1.5% (1.0–2.1) [−0.1; **−0.9, p = 0.02**] | 2.0% (1.5–2.7) [+0.0] | **3.5% (2.8–4.5)** [−0.3, p = 0.25] | 0.4% (0.2–0.9) [+0.1] |
| V5 full (N = 2,000) | 17.3% (15.7–19.0) [+0.3, p = 0.02; +1.4, p = 0.13] | 12.2% (10.8–13.7) [**−1.6, p = 0.03**; **−4.6, p < 0.001**] | 12.2% (10.9–13.8) [+0.0; −0.1, p = 1.00] | 11.8% (10.4–13.2) [+0.1] | **13.8% (12.4–15.4)** [−0.1, p = 1.00] | 3.9% (3.1–4.8) [−0.1] |

The lever moves the committed Lantern and nothing else that matters: every other arm's change against the baseline is within 1.2 pp (A at V0 fresh, p = 0.14). Arm A and A_lit move a little because they too take Hearthfall, and value it slightly less without its rider (arm A now holds 0.51 a run at V0 fresh, from 0.65).

### Committed reach (G5)

Steady by the end of Act 1 and True by the end of Act 2: over the runs alive at that act's end (G5's denominator from this readout), with the all-runs figure beside it. The minimum of each graded row is in bold.

| Cell | | Shatter | Lantern | Edge |
|---|---|---|---|---|
| V0 fresh | Steady, Act 1 | 95.4% of 818 (78.0% of all) | **74.3% of 630** (46.8%) | 80.7% of 818 (66.0%) |
| V0 fresh | True, Act 2 (not graded) | 94.1% of 528 (49.7%) | 65.4% of 483 (31.6%) | 52.6% of 435 (22.9%) |
| V0 full | Steady, Act 1 | 91.6% of 879 (80.5%) | **89.6% of 759** (68.0%) | 92.7% of 921 (85.4%) |
| V0 full | True, Act 2 | 88.4% of 732 (64.7%) | **87.6% of 615** (53.9%) | 87.8% of 638 (56.0%) |
| V5 fresh | Steady, Act 1 (not graded) | 97.8% of 643 (31.4%) | 87.4% of 365 (16.0%) | 79.1% of 617 (24.4%) |
| V5 full | Steady, Act 1 | 92.7% of 1,055 (48.9%) | **92.6% of 780** (36.1%) | 92.6% of 1,177 (54.5%) |
| V5 full | True, Act 2 | 88.2% of 595 (26.2%) | 88.7% of 416 (18.4%) | **82.3% of 485** (20.0%) |

Over every run, as readouts 1–12 graded it, V0 full would still fail by 2 pp on Steady (68.0%, the Lantern, which dies in Act 1 in 24% of runs) while True passes (53.9% minimum), and V5 full would fail on survival (Steady minimum 36.1%).

### The complete §11 table

Every gate in every cell, point and 95% interval. "Instrument alone" is the improved-bot baseline on readout 12's content (the bot fixed, no lever); "Readout 12" is readout 12's own reports re-graded by this readout's grader, so its G5 is read over survivors too (readout 12 recorded G5 over every run: V0 full FAIL / UNDECIDED, V5 full FAIL / FAIL). **Bold** marks a verdict that differs from readout 12's. G1 and G4 remain instrument readings (owner ruling of 30 September); the A rows are the commit-blind floor.

| Cell | Gate | Measured | Point | 95% interval | Interval | Instrument alone (point / interval) | Readout 12 (point / interval) |
|---|---|---|---|---|---|---|---|
| V0 fresh | G1 | worst C_shatter 20.8% | FAIL | worst C_shatter 20.8% (18.4–23.4%, n=1000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V0 fresh | G2 | 12.8 pp (C_lantern − C_shatter) | FAIL | C_lantern − C_shatter +12.8 pp (+8.9 to +16.6, n=1000+1000) | **UNDECIDED** | FAIL / FAIL | FAIL / FAIL |
| V0 fresh | G3 | A_lit 32.0% vs best 33.6% (−1.6 pp) | **PASS** | A_lit − C_lantern -1.6 pp (-5.7 to +2.5, n=1000+1000) | UNDECIDED | FAIL / UNDECIDED | FAIL / UNDECIDED |
| V0 fresh | G4 | R 7.1% vs worst 20.8% (−13.7 pp) | FAIL | R − C_shatter -13.7 pp (-16.7 to -10.7, n=1000+1000); R 7.1% (5.7–8.9%, n=1000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V0 fresh | G5 | Steady by end of Act 1 min 74.3% of runs alive (C_lantern; all runs 46.8%); True by end of Act 2 min 52.6% of runs alive (C_edge; all runs 22.9%) | PASS | Steady min C_lantern 74.3% (70.7–77.5%, n=630 alive) | PASS | PASS / PASS | PASS / PASS |
| V0 fresh | G6 | shatter 31.6%, lantern 29.4%, edge 39.1% of 320 A_lit wins | PASS | lead edge 39.1% (33.9–44.5%, n=320 A_lit wins) | PASS | PASS / PASS | PASS / PASS |
| V0 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS | PASS / PASS |
| V0 fresh | G3 floor (A) | A 24.1% vs best 33.6% (−9.5 pp) | FAIL | A − C_lantern -9.5 pp (-13.4 to -5.5, n=1000+1000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V0 fresh | G6 floor (A) | shatter 44.8%, lantern 21.2%, edge 34.0% of 241 A wins | PASS | lead shatter 44.8% (38.7–51.1%, n=241 A wins) | PASS | PASS / PASS | PASS / PASS |
| V0 full | G1 | worst C_edge 39.6% | FAIL | worst C_edge 39.6% (36.6–42.7%, n=1000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V0 full | G2 | 9.7 pp (C_shatter − C_edge) | **PASS** | C_shatter − C_edge +9.7 pp (+5.3 to +14.0, n=1000+1000) | UNDECIDED | FAIL / UNDECIDED | FAIL / UNDECIDED |
| V0 full | G3 | A_lit 47.1% vs best 49.3% (−2.2 pp) | PASS | A_lit − C_shatter -2.2 pp (-6.6 to +2.2, n=1000+1000) | UNDECIDED | FAIL / UNDECIDED | PASS / UNDECIDED |
| V0 full | G4 | R 17.6% vs worst 39.6% (−22.0 pp) | FAIL | R − C_edge -22.0 pp (-25.8 to -18.1, n=1000+1000); R 17.6% (15.4–20.1%, n=1000) | **UNDECIDED** | FAIL / UNDECIDED | FAIL / FAIL |
| V0 full | G5 | Steady by end of Act 1 min 89.6% of runs alive (C_lantern; all runs 68.0%); True by end of Act 2 min 87.6% of runs alive (C_lantern; all runs 53.9%) | PASS | Steady min C_lantern 89.6% (87.2–91.6%, n=759 alive); True min C_lantern 87.6% (84.8–90.0%, n=615 alive) | PASS | PASS / PASS | PASS / PASS |
| V0 full | G6 | shatter 24.0%, lantern 19.1%, edge 56.9% of 471 A_lit wins | PASS | lead edge 56.9% (52.4–61.3%, n=471 A_lit wins) | UNDECIDED | PASS / UNDECIDED | PASS / UNDECIDED |
| V0 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS | PASS / PASS |
| V0 full | G3 floor (A) | A 38.8% vs best 49.3% (−10.5 pp) | FAIL | A − C_shatter -10.5 pp (-14.8 to -6.2, n=1000+1000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V0 full | G6 floor (A) | shatter 21.6%, lantern 17.0%, edge 61.3% of 388 A wins | **FAIL** | lead edge 61.3% (56.4–66.1%, n=388 A wins) | UNDECIDED | PASS / UNDECIDED | PASS / UNDECIDED |
| V5 fresh | G1 | worst C_shatter 1.2% | n/a | worst C_shatter 1.2% (0.8–1.8%, n=2000) | n/a | n/a / n/a | n/a / n/a |
| V5 fresh | G2 | 2.6 pp (C_lantern − C_shatter) | PASS | C_lantern − C_shatter +2.6 pp (+1.6 to +3.6, n=2000+2000) | PASS | PASS / PASS | PASS / PASS |
| V5 fresh | G3 | A_lit 3.5% vs best 3.8% (−0.2 pp) | PASS | A_lit − C_lantern -0.3 pp (-1.4 to +0.9, n=2000+2000) | **PASS** | PASS / PASS | PASS / UNDECIDED |
| V5 fresh | G4 | R 0.4% vs worst 1.2% (−0.8 pp) | FAIL | R − C_shatter -0.8 pp (-1.4 to -0.2, n=2000+2000); R 0.4% (0.2–0.9%, n=2000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V5 fresh | G5 | Steady by end of Act 1 min 79.1% of runs alive (C_edge; all runs 24.4%); True by end of Act 2 min 40.2% of runs alive (C_edge; all runs 2.5%) | n/a | Steady min C_edge 79.1% (75.7–82.1%, n=617 alive) | n/a | n/a / n/a | n/a / n/a |
| V5 fresh | G6 | shatter 39.4%, lantern 39.4%, edge 21.1% of 71 A_lit wins | PASS | lead shatter 39.4% (28.9–51.1%, n=71 A_lit wins) | PASS | PASS / PASS | PASS / PASS |
| V5 fresh | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS | PASS / PASS |
| V5 fresh | G3 floor (A) | A 2.0% vs best 3.8% (−1.8 pp) | **PASS** | A − C_lantern -1.8 pp (-2.9 to -0.8, n=2000+2000) | **PASS** | FAIL / UNDECIDED | FAIL / FAIL |
| V5 fresh | G6 floor (A) | shatter 57.5%, lantern 35.0%, edge 7.5% of 40 A wins | PASS | lead shatter 57.5% (42.2–71.5%, n=40 A wins) | UNDECIDED | PASS / UNDECIDED | PASS / UNDECIDED |
| V5 full | G1 | worst C_lantern 12.2% | FAIL | worst C_lantern 12.2% (10.8–13.7%, n=2000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V5 full | G2 | 5.1 pp (C_shatter − C_lantern) | PASS | C_shatter − C_lantern +5.1 pp (+2.9 to +7.3, n=2000+2000) | PASS | PASS / PASS | PASS / PASS |
| V5 full | G3 | A_lit 13.8% vs best 17.3% (−3.5 pp) | **FAIL** | A_lit − C_shatter -3.5 pp (-5.7 to -1.3, n=2000+2000) | UNDECIDED | FAIL / UNDECIDED | PASS / UNDECIDED |
| V5 full | G4 | R 3.9% vs worst 12.2% (−8.3 pp) | FAIL | R − C_lantern -8.3 pp (-10.0 to -6.7, n=2000+2000); R 3.9% (3.1–4.8%, n=2000) | FAIL | FAIL / FAIL | FAIL / FAIL |
| V5 full | G5 | Steady by end of Act 1 min 92.6% of runs alive (C_lantern; all runs 36.1%); True by end of Act 2 min 82.3% of runs alive (C_edge; all runs 20.0%) | PASS | Steady min C_lantern 92.6% (90.5–94.2%, n=780 alive); True min C_edge 82.3% (78.6–85.4%, n=485 alive) | PASS | PASS / PASS | PASS / PASS |
| V5 full | G6 | shatter 33.0%, lantern 20.3%, edge 46.7% of 276 A_lit wins | PASS | lead edge 46.7% (40.9–52.6%, n=276 A_lit wins) | PASS | PASS / PASS | PASS / PASS |
| V5 full | G7 | 0 stalls, 0 errors; replay 3/3 identical | PASS | counts (no interval) | PASS | PASS / PASS | PASS / PASS |
| V5 full | G3 floor (A) | A 11.8% vs best 17.3% (−5.5 pp) | FAIL | A − C_shatter -5.5 pp (-7.7 to -3.4, n=2000+2000) | **FAIL** | FAIL / FAIL | FAIL / UNDECIDED |
| V5 full | G6 floor (A) | shatter 31.1%, lantern 19.1%, edge 49.8% of 235 A wins | PASS | lead edge 49.8% (43.4–56.1%, n=235 A wins) | PASS | PASS / PASS | PASS / PASS |

G7 covers zero stalls and zero errors in all 36,000 runs of the final tables and the 8,000 of the second V5 full band, and arm A's three-seed replay, identical in every cell. No save field, id or RNG draw changed.

### G3 at V5 full, on 4,000 common seeds

The improved bot played readout 12's two V5 full bands again with the shipped content: 13000–14999 in the table and 15000–16999 for the four arms G3 reads. The best committed arm is now Shatter in both bands. `g3paired.py` reads A_lit's win minus Shatter's on each common seed, with Newcombe's interval for a difference of paired proportions.

| V5 full | Best committed | A_lit − best (point) | Paired 95% interval | Verdict (point / interval) |
|---|---|---|---|---|
| seeds 13000–14999 (the table) | C_shatter 17.3% | −3.5 pp | −5.6 to −1.4 | FAIL / UNDECIDED |
| seeds 15000–16999 | C_shatter 16.1% | −3.5 pp | −5.5 to −1.4 | FAIL / UNDECIDED |
| both, 4,000 seeds | C_shatter 16.7% | **−3.5 pp** | **−5.0 to −2.0** | **FAIL / UNDECIDED** |

On 4,000 common seeds A_lit wins 13.2% and committed Shatter 16.7% (the Lantern 12.3%, Edge 11.9%). Readout 12's reading on the same seeds with the old bot was −3.8 pp (−5.3 to −2.3) against the Lantern; the best arm changed and the gap barely moved. The estimate sits 0.5 pp outside the −3 pp band and the interval's half-width is 1.5 pp, so it is still undecided. Deciding it would need the half-width under 0.5 pp: about 36,000 paired seeds per arm (the half-width shrinks with the square root of the seeds, and the arms' outcomes on a seed are barely correlated, φ = 0.11). This lane stops there, as asked. The honest reading is unchanged: at vow 5 in the full pool the skilled adaptive player is 3–4 pp behind the best committed way, on the gate's edge.

### Row B, the bot round (V0, search player)

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 | Instrument alone: B1 / B2 | Readout 12: B2 |
|---|---|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 20.8% (18.4–23.4) | PASS | 80.7% (80.2–81.3) | 1.1% (1.0–1.3) | UNDECIDED | PASS / UNDECIDED | UNDECIDED |
| V0 fresh | C_lantern | 33.6% (30.7–36.6) | PASS | 62.2% (61.5–62.9) | 1.0% (0.9–1.2) | UNDECIDED | PASS / UNDECIDED | UNDECIDED |
| V0 fresh | C_edge | 21.2% (18.8–23.8) | PASS | 69.3% (68.6–69.9) | 1.8% (1.6–2.0) | PASS | PASS / PASS | PASS |
| V0 fresh | A_lit | 32.0% (29.2–35.0) | PASS | 59.2% (58.5–59.9) | 1.4% (1.2–1.5) | FAIL | PASS / FAIL | FAIL |
| V0 full | C_shatter | 49.3% (46.2–52.4) | PASS | 82.7% (82.2–83.2) | 1.0% (0.9–1.1) | UNDECIDED | PASS / UNDECIDED | UNDECIDED |
| V0 full | C_lantern | 47.6% (44.5–50.7) | PASS | 72.6% (71.9–73.2) | 1.1% (0.9–1.2) | UNDECIDED | PASS / UNDECIDED | UNDECIDED |
| V0 full | C_edge | 39.6% (36.6–42.7) | PASS | 82.6% (82.1–83.1) | 1.5% (1.4–1.7) | PASS | PASS / PASS | PASS |
| V0 full | A_lit | 47.1% (44.0–50.2) | PASS | 63.2% (62.6–63.9) | 1.2% (1.1–1.4) | PASS | PASS / PASS | PASS |

B1 passes for every way in both pools. B2's UNDECIDED rows sit on the close-call floor (1.0–1.1%, intervals touching 1%), as in readout 12. A_lit's own feel at V0 fresh is 59.2% (58.5–59.9%) against 60%: a decided FAIL by 0.1 pp at the interval's top, unchanged by the bot (A_lit builds as before) and by the lever (+0.1 pp).

## Decision

**Ship the improved bot, G5 over survivors, and H.** With all three, at V0 the committed ways sit within 10 pp of each other in the full pool on point (9.7 pp, Shatter over Edge) and within 12.8 pp in the fresh pool, where the gap was a decided 17.9 pp; G3 passes on point in three cells of four and A_lit is within 1.6–2.2 pp of the best committed way at V0; G5 passes on point and interval in every graded cell; G6 passes on point in every cell; B1 and G7 hold.

Targets this lane did not reach:

- **G2 at V0 fresh** is 12.8 pp (+8.9 to +16.6), UNDECIDED: the lever took 4.8 pp off the Lantern's lead (p < 0.001), not the 7.4 pp the target needed. Even without its rider, Hearthfall still carries the Lantern's late game (its Act 2 survivors win 76% with three or more copies, 18% with none); its Act 3 conversion falls only from 72.5% to 69.6%.
- **G3 at V5 full** stays a FAIL on point (−3.5 pp on the table's band and on 4,000 paired seeds, −5.0 to −2.0, UNDECIDED; about 36,000 paired seeds would decide it).
- **A_lit's B2 at V0 fresh** stays a decided FAIL at 59.2%.

Every verdict that worsens against readout 12's reports, and why:

- **G6 floor at V0 full: PASS → FAIL on point** (UNDECIDED on interval). Arm A, the commit-blind floor, wins 61.3% of its runs in Edge's colour (56.4–66.1%); readout 12: 59.1%. A holds fewer Hearthfalls (0.55 a run at V0 full, from 0.66) and wins less often in amber (17.0% of its wins, from 19.4%). A_lit's own G6, the gate of record since readout 10, passes (Edge 56.9%).
- **G3 at V5 full: PASS → FAIL on point** on the table's band (−3.5 pp; readout 12's −2.9 pp). The instrument alone made it −3.1 pp: the improved bot raised committed Shatter to 17.3% while A_lit, which builds as before, stayed at 13.8%. Readout 12's own 4,000-seed reading of this cell was already −3.8 pp, FAIL on point.
- **G3 floor at V5 full: UNDECIDED → FAIL on interval** (A − best −5.5 pp, −7.7 to −3.4): the same rise of committed Shatter, read against arm A.
- **The committed Lantern at V5** loses 2.6 pp fresh and 4.6 pp full against readout 12 (both p < 0.001): 1.2–3.0 pp from the bot's seed removal (gold and two good attacks at a vow where both are scarce) and 1.4–1.6 pp from the lever. It is now the joint worst committed way at V5 full (12.2%, with Edge), so G1 there reads the Lantern; G1 fails there either way.
- **Committed Edge at V5 fresh** loses 0.9 pp against readout 12 (p = 0.02), the bot's removal again; G1 is not graded at V5 fresh.

Verdicts that improve against readout 12: G2 at V0 full (FAIL → PASS on point), G2 at V0 fresh (decided FAIL → UNDECIDED), G3 at V0 fresh (FAIL → PASS on point), G3 at V5 fresh (interval UNDECIDED → PASS), G3 floor at V5 fresh (FAIL → PASS, point and interval), G4 at V0 full (interval FAIL → UNDECIDED: R − worst −22.0 pp, −25.8 to −18.1), and G5 in both full cells (FAIL as recorded → PASS / PASS over survivors). G3 at V0 full stays PASS on point (−2.2 pp; −2.5 pp in readout 12).

## Does the design's intent hold? A plain reading

Read with a bot that plays the committed ways as a player would, the three ways are viable and, in the full pool, comparable: at V0 Shatter, the Lantern and Edge win 49%, 48% and 40% of their runs and the spread is under 10 pp, while in a new player's fresh pool the Lantern still leads the other two by about 13 pp (34% against 21%), the one gap this programme has narrowed but not closed. Commitment is rewarded without being a trap: insisting on a way is the strongest play, but a player who reads the offers and the lantern comes within 2 pp of the best way at vow 0 (3.5 pp at vow 5's full pool, on the gate's edge), and about 8 pp ahead of one who reads only the offers. Scattering loses clearly, by 13–22 pp at vow 0, though not by the 25 pp the lock asked for, which stays an instrument reading. The tiers are reachable: a committed deck that is still alive is Steady by the end of Act 1 in 74–98% of runs and True by the end of Act 2 in 53–94% (40–96% at vow 5). Adaptive play is diverse: the flame-reading player's wins spread over all three colours in every cell, Edge leading the full pool at 47–57%. Nothing is degenerate: no stalls, no errors, identical replays. The verdicts that worsened are the commit-blind floor's G6 at V0 full, G3 at V5 full on point and its floor's interval, and the Lantern's win rate at vow 5, where it is now the joint weakest way.

## Tests and pins

- **New tests.** `test_balance_arms.gd`: per way, a committed bot's removal targets its lower-scored off-colour seed, worth the full appetite, at the shop (a single copy bought out), the shrine and an event's score, and falls back to the worst card once the seeds are gone; the two-copy cap holds on offers and not on cards held; off-colour glass keeps ×0.5 at any count; arm A counts nothing. `test_balance_adaptive_lit.gd`: lit A_lit keeps arm A's removal. `test_balance_ways.py`: G5 reads the runs alive at the act's end, and the gate row and cell table print the all-runs figure beside it.
- **Pins.** `test_balance_sim` pins the pilot version (`p8-d0-v3`). `test_balance_catalogue` re-pins the live file SHA (`e9c4d48f…`) and the semantic SHA (`5429a44a…`), moved only by Hearthfall's two effects and two sentences. The seed-1000 digest (`bb86394a…`) and the unlit check's seed-1001 digest (`7b8a17cc…`) do not move: those runs never hold a lit Hearthfall. Seed 1001's knobs-at-one run still differs from its zero-knob run, so the unlit check stays non-vacuous with a seed whose deck lights.
- **Unchanged and passing.** `test_lit_riders` lists the shipped riders and loses Hearthfall's line, keeping every assertion; Hearthfall still lights the Lantern's test decks (its affinity is unchanged). `test_way_walls` (Hearthfall's cost, damage and discard) passes as it was. The #490 tier-1 registry passes against the frozen snapshots in `docs/balance/data/`, which are untouched. No `port_fixtures/` golden moved.
- **Card faces.** Hearthfall's English and zh-Hant faces lose their last sentence ("Amber flame: gain 1 Ember." / 「金黃之火：獲得 1 點餘燼。」); the rest of the face is unchanged, so its rules text is shorter than it was on every face. This lane runs headless only, so the card-lab capture of the two faces (`tools/shot.sh --cards=hearthfall`) was not taken; see the PR.
- **Anchors.** The pilot's new lines moved six cited line numbers in two historical balance notes; `check_anchors.py --fix` re-anchored them, and the two "in `choose_shop`" citations of the shop-removal numerator now name its new line in `tools/balance_pilot.gd`.

## What the next readout should ask

1. **The fresh Lantern** still leads by 12.8 pp at V0. Hearthfall without its rider is still the Lantern's late-game payoff; a second lever on it (its Ember cost or damage) or on the fresh pool's commons is the next candidate, read against A_lit at V0 full, which the screen suggested could pay (−3.5 pp on 400 seeds) though the final table did not (−0.2 pp).
2. **G3 at V5 full** sits at its threshold under both bots (−3.8 pp with the old bot, −3.5 pp with the new, on 4,000 paired seeds; about 36,000 per arm would decide it, or the lock can adopt a paired grader with an equivalence margin).
3. **The adaptive arms' removal.** A_lit that removed the seeds off its lit colour lost 2.7 pp at V0 full. Whether a smarter adaptive removal (off-colour seeds only once True is in reach) helps is an instrument question, not a balance one.
4. **G6's floor at V0 full** now fails on point (Edge 61.3% of arm A's wins); arm A is the commit-blind floor, and A_lit's G6 passes.
5. **A_lit's B2 at V0 fresh** (59.2%) is a decided FAIL by a fraction of a point and has not moved in four readouts.

## Appendix: the scripts

All scripts are in the lane's private scratch folder, as in readouts 9–12.

| Script | What it does |
|---|---|
| `chunked.py` | Readout 9's appendix B runner, pointed at this worktree. |
| `instr.py` | The instrument's paired before/after per committed arm: win, reach over all and over survivors, seeds held, removals and copies. |
| `merge13.py` | The improved-bot baseline table in scratch: the committed arms from `58651b00`, A, A_lit, R and the replays from readout 12. |
| `lean.py` | The win chain by act, lit and True shares of fights, rider-card holdings and plays, Ember rates, and win by copies among Act 2 survivors. |
| `cand13.py`, `stage2.sh`, `screen_grade.py` | Write the three candidate catalogues; run and grade the screen (G5 over survivors). |
| `final.sh`, `fulltable.py`, `tidy.py` | Run the final tables; print the complete §11 table with two reference tables and row B. |
| `paired.py`, `rowb.py`, `g3paired.py`, `merge.py` | Paired changes between two tables; row B; G3 on common seeds; two bands joined. |
