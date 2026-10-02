# Readout 12: Shatter's reach and the Lantern's lean

> **Research readout (AI-SDLC discovery), promoted in one PR.** The PR ships two content levers. Quarry Maul (`heavyBlow`) and Fan of Glass (`cleave`) join Shatter's affinity table at 1.0 (`30f5df21`), and the flame's `trueMin` moves from 0.80 to 0.75 (`aa9bb39a`). `content/full-content.json` gains two affinity lines and changes one number; its SHA-256 is now `87c879c4b58ee41d05603a8ec0fd7f13fa64ba92e2a4a83257edeef6bfaa01db`. No card text, card number, rarity, pool entry, rider, lantern knob, enemy number, combat rule, tool, id or RNG draw moved. Affinity is not printed, and `trueMin` is not shown to the player, so no card face or string changes.
>
> **Head.** The final tables (V0 at 1,000 paired seeds, V5 at 2,000, and a second V5 full band of 2,000 for G3) ran at `641126abc9b63a135b04805c7f6d7254de5ffbca`, whose manifest every report names: the two content commits on readout 11's head, before this branch was rebased onto `main` (readout 11's squash, `f79b4d53`, and a TestFlight build bump). The rebase carried them to `30f5df21` and `aa9bb39a`; `git diff 641126ab aa9bb39a -- tools domain content` is empty. Later commits re-pin tests and add documents only.

Readout 11 made Edge's three stat powers clear glass and brought G6 to PASS. It left four costs and blockers. G5 failed in the full pool: committed Shatter reached Steady by the end of Act 1 in 51.1% of runs at V0 (34.5% at V5) and True by the end of Act 2 in 12.5% (3.1%). G2 sat at 13.2 pp at V0 fresh and 12.7 pp at V0 full. G3 at V5 full read −4.9 pp with an UNDECIDED interval. A_lit's own B2 at V0 fresh was 58.7% against 60%. The True tier and its payoff, the Art discount, were practically unseen in full-pool play. The orchestrator set this lane: diagnose first, measure at most three single-lever candidates that follow from the diagnosis, ship the survivors and decide G3 at V5 full with a paired grader. Global difficulty stays closed, and G1 and G4 remain instrument readings.

## The answer in brief

- **Diagnosis.** Shatter's reach was its supply. It had one common (Spall) against two to two and a half for the other ways, and 0.083 Shatter affinity per drawn card in the full pool against 0.159–0.194. A third of its living runs ended Act 1 one or two picks short of Steady. True was gated by the two off-colour starter seeds: every committed run in every cell kept both, because the bot's shop removal needs two copies of a card and its shrine removes a Strike or a Defend. At 0.80 a deck carrying them needs eight of its own pieces, which Shatter's offer rate never reaches by the end of Act 2. At V5, G5 is bounded by survival: only 42–59% of committed runs live to the end of Act 1. The committed Lantern's fresh lead is Act 3 conversion (67% of its Act 2 survivors win, against 45–53%), carried by its Ember engine and three Cathedral Glass a run; no single non-rider card carries it.
- **Three candidates, two shipped.** K1: Quarry Maul and Fan of Glass become Shatter glass. K2: `trueMin` 0.80 → 0.75. K3: Cathedral Glass becomes clear glass. On the development screen K1 took Shatter's Steady by the end of Act 1 from 54% to 81% and K2 took the Lantern's and Edge's True by the end of Act 2 from 26–30% to 47%. K3 narrowed nothing and broke fresh G5. **K1 and K2 ship together.**
- **G5 full: True passes, Steady misses by 1.2 pp.** At V0 full, True by the end of Act 2 is 51.7% (Shatter), 47.9% (Lantern) and 45.2% (Edge), all over 40% (readout 11's minimum: 12.5%). Steady by the end of Act 1 is 77.1%, 68.8% and 83.4%: Shatter clears 70%, and the Lantern misses on point (65.9–71.6%, UNDECIDED) because 21% of its runs die in Act 1. At V5 full G5 still fails (Steady minimum 39.2%, True minimum 14.0%), and cannot pass over all runs: among survivors, Steady is 88–90% for every way.
- **G3.** At V0 full it comes back into range on point: −2.5 pp (was −3.3). At V5 full the table's band reads −2.9 pp (was −4.9), a point PASS. Read on 4,000 common seeds with a paired interval, V5 full is −3.8 pp (−5.3 to −2.3): a FAIL on point by 0.8 pp whose interval is UNDECIDED. Its first band reads −2.9 pp and its second −4.6 pp. The cell sits on its threshold; about 14,000 paired seeds per arm would be needed to decide it.
- **What worsens.** G2 at V0 fresh goes from +13.2 to +17.9 pp and its interval from UNDECIDED to **FAIL** (the committed Lantern +3.2 pp, p = 0.05). G3 at V0 fresh goes from PASS to **FAIL** on point (−5.8 pp; interval UNDECIDED). Committed Shatter's B2 at V0 fresh goes from PASS to **UNDECIDED** (close calls 1.0%, 0.9–1.1%). Committed Shatter loses 6.2 pp at V0 full (p = 0.003) and 2.8 pp at V5 full (p = 0.008): the committed pilot ×3s the two attacks and keeps 2.4 Fan of Glass a run. G1 at V0 fresh (Shatter 21.3% → 19.8%) and G4 in both fresh cells (V0 −14.4 → −12.5 pp, V5 −1.6 → −1.4 pp) move further from their thresholds; G1 and G4 move towards theirs in both full cells. G2 at V0 full narrows from 12.7 to 10.9 pp, still FAIL on point, because committed Shatter, the old top, fell under the Lantern and Edge rose 2.7 pp (p = 0.06).
- **What holds.** G6 passes on point in every cell and gains an interval PASS at V5 fresh. G5 fresh, B1 and G7 pass (zero stalls and errors in 44,012 runs; replays identical). A_lit and A do not move significantly in any cell. A_lit's own B2 at V0 fresh is 59.1% (58.4–59.8%), still a decided FAIL against 60%.

## The question

Why does a committed deck reach Steady late (Shatter) and True rarely (every way) in the full pool, and what carries the committed Lantern's lead in the fresh pool? Can at most three single levers that follow from those answers bring G5 full to ≥ 70% Steady by the end of Act 1 and ≥ 40% True by the end of Act 2 for every way, and G2 at V0 under 10 pp in both pools, without losing G6, B1, G7 or the fresh pool's G5 and G6? Is G3 at V5 full a PASS or a FAIL once the arms are compared seed by seed?

## The instrument

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-readout12", removed before each commit.
# Diagnosis, on readout 11's own final reports (no simulation):
python3 -B diag12.py <readout 11 final-v0> v0-fresh,v0-full     # offers, survival, act-end own/off mass, picks short, removal economy
python3 -B cf_seeds.py <readout 11 final-v0> v0-fresh,v0-full   # static re-read of reach at other seed weights and trueMin
python3 -B pools.py                                             # coloured mass and per-draw affinity on offer, by pool and rarity
python3 -B take.py <dir> <cell> <cards>; python3 -B lead.py <new> <old> <cell> <arm>; python3 -B cond.py <dir> <cell> <arm> <cards>
# The screen: the head and three candidate catalogues (make_candidates.py), development seeds 12000-12599,
# V0 fresh and V0 full, arms C_shatter, C_lantern, C_edge and A_lit. The V0 full base is readout 11's own
# screen of this content (same file SHA, same driver), cut to the same 600 seeds:
screen.sh; python3 -B screen_grade.py screen base k1 k2 k3
# The final tables (readout 9, appendix B runner), and G3's second V5 full band:
python3 -B chunked.py s/final-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay
python3 -B chunked.py s/final-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay
python3 -B chunked.py s/ext-v5 --seeds 15000-16999 --cells v5-full --arms C_shatter,C_lantern,C_edge,A_lit --play search
# Grading, the paired change against readout 11's reports on the same seeds, row B, and paired G3:
python3 -B tools/balance_ways.py --from-dir s/final-v0 --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir s/final-v5 --seeds 13000-14999 --vows 5
python3 -B paired.py s/final-v0 <readout 11 final-v0> v0-fresh,v0-full; python3 -B rowb.py s/final-v0
python3 -B g3paired.py s/final-v5 v5-fresh,v5-full; python3 -B merge.py s/g3-4000 v5-full <arms> s/final-v5 s/ext-v5
```

- **Cells, arms, seeds.** The screen used 600 development seeds (12000–12599) in V0 fresh and V0 full with the four arms G2, G3, G5 and G6 read. The final tables used the lock's §11 table on readout 11's bands (V0 13000–13999, V5 13000–14999), so every change is paired run for run against readout 11's reports. G3 at V5 full read a second band, 15000–16999, outside the acceptance, development and calibration bands.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference of independent rates), row B as readouts 8–11 compute it, and paired tests that count the seeds one configuration wins and the other loses, with an exact two-sided binomial p.
- **The paired G3 grader (`g3paired.py`).** It reads G3 as A_lit's win minus the best committed arm's win on each common seed, with Newcombe's (1998, method 10) hybrid score interval for a difference of paired proportions. The best committed arm is the cell's highest win rate, as the grader picks it; the verdict uses the same band (−3 to +15 pp). It is a scratch script, not a change to `tools/balance_ways.py`.
- **Budget and stop rule.** At most three candidates, each a single lever, screened together; a candidate survived if it moved its target without a significant cost to another arm's win rate in the screen. Survivors went to the final table together and are read as they fell.
- **Wall time.** Each candidate's screen took 19 minutes on ten processes (2 cells × 4 arms × 600 seeds); the base's fresh cell took 8. The final V0 table took 43 minutes, the V5 table 48 minutes and the second V5 full band 27 minutes.

## Diagnosis

All figures are from readout 11's final reports (V0 at 1,000 seeds, V5 at 2,000). Wilson 95% intervals.

### Coloured mass on offer

Coloured mass offerable to the Duskblade, by pool and rarity, and the expected affinity per card drawn for a normal fight's reward (rarity cuts 60 / 32 / 8%):

| Pool | Way | Common | Uncommon | Rare | Total | Per draw |
|---|---|---:|---:|---:|---:|---:|
| fresh | Shatter | 1.0 | 1.0 | 1.0 | 3.0 | 0.086 |
| fresh | Lantern | 2.0 | 1.5 | 0.5 | 4.0 | 0.130 |
| fresh | Edge | 2.5 | 3.0 | 0.0 | 5.5 | 0.176 |
| full | Shatter | 1.0 | 2.0 | 2.5 | 5.5 | 0.083 |
| full | Lantern | 2.0 | 3.5 | 5.0 | 10.5 | 0.159 |
| full | Edge | 2.5 | 5.5 | 2.0 | 10.0 | 0.194 |

Pools do not change by act, so the per-draw rate is the same in every act; what changes by act is how many draws a run has seen and, once lit, like-calls-to-like (§8). The simulator counts offers per run, not per act. A committed arm was offered, per run, 9.1 of its own coloured mass at V0 full if Shatter, 17.3 if the Lantern and 19.5 if Edge. Shatter's own commons were one card, Spall; a committed Shatter player already keeps 85% of the Shatter glass it is offered (Spall 3.03 held of 3.55 offered, Quakeblow and Bellstrike more than offered through shops). Its reach was the supply, not its appetite.

### Where committed decks sit on the purity curve

Steady needs own ≥ 1.5 × off-colour mass (purity 0.60), True needs own ≥ 4 × off (0.80), both with mass ≥ 5. At V0 full, among runs alive at the act's end:

| Arm | Alive, end of Act 1 / 2 | Own / off, end of Act 1 | Picks short of Steady, Act 1: 0 / 1 / 2 / 3+ | Own / off, end of Act 2 | Picks short of True, Act 2: 0 / 1–2 / 3–4 / 5+ |
|---|---|---|---|---|---|
| C_shatter | 84.2% / 69.0% | 4.36 / 2.59 | 61 / 17 / 11 / 11% | 8.44 / 3.48 | 18 / 12 / 15 / 55% |
| C_lantern | 78.7% / 63.6% | 6.32 / 2.51 | 89 / 6 / 3 / 3% | 12.49 / 3.23 | 52 / 17 / 11 / 21% |
| C_edge | 90.9% / 60.6% | 7.01 / 2.68 | 92 / 5 / 2 / 1% | 13.35 / 3.69 | 41 / 19 / 15 / 25% |

Shatter's Act 1 deck carries two fewer of its own pieces than the other ways' with the same off-colour mass. A third of its living runs are one or two picks short of Steady. Over all runs, Steady by the end of Act 1 was 51.1% (48.0–54.2) for Shatter, 69.8% (66.9–72.6) for the Lantern and 83.9% (81.5–86.0) for Edge.

### Why True is reached so rarely

- **Not deck dilution.** Clear glass never enters the purity (§4), so a deck full of Strikes and clear powers is as pure as its coloured glass.
- **The removal economy, in the bot.** Every committed run in all four cells ended holding both off-colour starter seeds (100.0% of 1,000 or 2,000 runs per arm and cell). The pilot's shop removal needs at least two copies of its worst card, so a single seed is never bought out; the shrine removes the lowest-scoring card, a Strike or a Defend. So a committed deck always carries at least 2.0 off-colour mass, and True at 0.80 needs eight of its own pieces with no other off-colour pick at all. Re-read statically with the two seeds gone, True by the end of Act 2 at V0 full would be Shatter 47.9%, Lantern 59.3% and Edge 55.5% (against 12.5%, 33.0% and 24.8%). This is the instrument, not the game: the lock's own worked example removes Eclipse Slash at the shop (§4), and a human committed player would. It is reported, not changed.
- **The threshold at the observed offer rates.** With the seeds held, committed Shatter's own mass by the end of Act 2 averaged 8.44 against 3.48 off; True needs 13.9. Only 18% of its living runs were within reach; 55% were five or more picks short. At Shatter's offer rate (9.1 own mass across a whole run, about six by the end of Act 2) True by Act 2 is out of reach for most runs at 0.80 whatever the player does except remove the seeds. Static re-reads of the end-of-Act-2 decks, behaviour unchanged:

| V0 full, True by end of Act 2 | Shatter | Lantern | Edge |
|---|---:|---:|---:|
| trueMin 0.80 (readout 11) | 12.5% | 33.0% | 24.8% |
| trueMin 0.75 | 26.4% | 50.4% | 45.4% |
| trueMin 0.70 | 38.5% | 58.1% | 55.1% |
| seeds held at 0.5 weight (minMass 5) | 28.1% | 49.1% | 43.7% |
| off-colour seeds removed | 47.9% | 59.3% | 55.5% |

Halving the seeds' weight reaches about what 0.75 does for True, but costs Shatter 6 pp of Steady by the end of Act 1 because its decks fall under `minMass`. 0.75 leaves Steady untouched.

- **Survival bounds G5 at V5.** G5 counts every run, and a run that dies before an act's end has not reached anything. At V5 full only 49.2% of committed Shatter runs, 42.1% of the Lantern's and 59.0% of Edge's survive Act 1, and 24–31% survive Act 2. Steady by the end of Act 1 ≥ 70% and True by the end of Act 2 ≥ 40% over all runs are therefore unreachable at V5 by any lever that does not raise survival, and survival is the closed global difficulty. Among survivors, V5 full Steady by the end of Act 1 was already 70.1% (Shatter), 89.4% (Lantern) and 89.1% (Edge).

### What carries the committed Lantern's fresh lead

- **Act 3 conversion.** At V0 fresh, the committed Lantern survives Act 2 about as often as the others (51.5% against Shatter's 47.9% and Edge's 42.2%), but wins 67.0% of those runs, against Shatter's 44.5% and Edge's 52.8%. Its lead is in the third act, where its Ember engine pays.
- **What it carries.** Per run at V0 fresh: Tinder 2.71, Hearthfall 2.26 and Struck Match 1.81 copies (the readout 9 riders' commons), and Cathedral Glass 3.19 copies, offered 3.08 times a run because the fresh pool's rare slot holds only four cards. Readout 11's +5.7 pp came with Inner Blaze: 0.10 copies a run before, 1.00 after.
- **No single card.** Among runs alive at the end of Act 2, 479 of 515 hold three or more Cathedral Glass, so its effect cannot be separated in the reports; the rider commons rise with win rate (Hearthfall: 44% with one copy, 71% with three), but they are readout 9's riders, which this lane leaves alone. The screen tested the only lead card outside the riders (candidate K3).

### The diagnosis in five lines

1. Shatter's reach is its supply: one Shatter common against two to two and a half for the others, 0.083 Shatter affinity per drawn card against 0.159–0.194, and a committed player who already keeps 85% of it. A third of its living runs end Act 1 one or two picks short of Steady.
2. True is gated by two off-colour seeds the bot never removes: at 0.80 a committed deck needs eight of its own pieces before True can light, which Shatter's offer rate never reaches by the end of Act 2 and the others reach in half their living runs.
3. A threshold of 0.75 needs six; statically it lifts True by the end of Act 2 by 14–21 pp at V0 full without moving Steady.
4. At V5, G5 is bounded by survival (42–59% alive at the end of Act 1), so its 70% / 40% floors cannot be met over all runs; among survivors Steady already passes.
5. The committed Lantern's fresh lead is Act 3 conversion through its Ember engine (the riders' commons) and three Cathedral Glass a run; no single non-rider card carries it.

## The candidates

| | Lever | From the diagnosis |
|---|---|---|
| K1 | Quarry Maul (`heavyBlow`) and Fan of Glass (`cleave`) join Shatter at 1.0 | line 1: Shatter's common mass goes from 1.0 to 3.0 (per-draw 0.083 → 0.169 in the full pool). Both are attacks whose chip is the point (Quarry Maul chips when upgraded; Fan of Glass chips every enemy it bloods), and a commit-blind deck keeps them rarely (A: 13% and 5% of offers), so A_lit should not hoard them as it did readout 11's C2 |
| K2 | `trueMin` 0.80 → 0.75 | lines 2–3: True at three in four |
| K3 | Cathedral Glass (`aegis`) leaves the Lantern and becomes clear glass | line 5: the one fresh-lead card that is not a rider; a defensive rare every deck takes (A keeps 63% of offers), which the committed Lantern ×3s into three copies a run |

### The screen: development seeds 12000–12599, V0

Each arm's win rate, with its paired change against the head on the same seeds (pp, exact p).

| Cell | Candidate | C_shatter | C_lantern | C_edge | A_lit | G2 | G3 (A_lit − best) | G6 S / L / E of A_lit's wins |
|---|---|---|---|---|---|---|---|---|
| V0 fresh | head | 20.0% | 33.5% | 19.8% | 32.8% | 13.7 pp FAIL | −0.7 pp PASS / UNDECIDED | 21.8 / 38.6 / 39.6% PASS / PASS |
| V0 fresh | K1 | 21.7% (+1.7, p = 0.49) | 35.0% (+1.5, p = 0.48) | 21.3% (+1.5, p = 0.36) | 29.7% (−3.2, p = 0.02) | 13.7 pp FAIL | −5.3 pp FAIL / UNDECIDED | 27.0 / 38.8 / 34.3% PASS / PASS |
| V0 fresh | K2 | 20.0% (+0.0, p = 1.00) | 34.5% (+1.0, p = 0.33) | 20.0% (+0.2, p = 1.00) | 33.3% (+0.5, p = 0.61) | 14.5 pp FAIL | −1.2 pp PASS / UNDECIDED | 21.0 / 38.5 / 40.5% PASS / PASS |
| V0 fresh | K3 | 24.8% (+4.8, p < 0.01) | 36.2% (+2.7, p = 0.21) | 22.8% (+3.0, p = 0.16) | 30.0% (−2.8, p = 0.14) | 13.3 pp FAIL | −6.2 pp FAIL / UNDECIDED | 25.6 / 22.2 / 52.2% PASS / UNDECIDED |
| V0 full | head | 49.2% | 45.8% | 35.0% | 44.2% | 14.2 pp FAIL | −5.0 pp FAIL / UNDECIDED | 16.6 / 30.9 / 52.5% PASS / PASS |
| V0 full | K1 | 45.2% (−4.0, p = 0.15) | 47.0% (+1.2, p = 0.58) | 37.0% (+2.0, p = 0.24) | 42.8% (−1.3, p = 0.35) | 10.0 pp PASS | −4.2 pp FAIL / UNDECIDED | 23.0 / 26.5 / 50.6% PASS / PASS |
| V0 full | K2 | 49.5% (+0.3, p = 0.79) | 47.8% (+2.0, p = 0.19) | 36.2% (+1.2, p = 0.36) | 45.8% (+1.7, p = 0.05) | 13.3 pp FAIL | −3.7 pp FAIL / UNDECIDED | 16.0 / 29.8 / 54.2% PASS / PASS |
| V0 full | K3 | 50.8% (+1.7, p = 0.23) | 45.5% (−0.3, p = 0.93) | 34.3% (−0.7, p = 0.52) | 44.0% (−0.2, p = 1.00) | 16.5 pp FAIL | −6.8 pp FAIL / UNDECIDED | 18.2 / 27.3 / 54.5% PASS / UNDECIDED |

Committed reach on the screen, Shatter / Lantern / Edge:

| Cell | Candidate | Steady by end of Act 1 | True by end of Act 2 |
|---|---|---|---|
| V0 fresh | head | 52.5 / 45.8 / 57.8% | 13.7 / 8.3 / 3.5% |
| V0 fresh | K1 | **75.2** / 46.2 / 58.0% | 31.2 / 6.7 / 3.5% |
| V0 fresh | K2 | 52.5 / 45.2 / 57.8% | 22.8 / 19.0 / 12.7% |
| V0 fresh | K3 | 56.3 / **37.7** / 67.8% | 15.7 / 6.0 / 13.0% |
| V0 full | head | 54.0 / 67.2 / 83.8% | 10.3 / 30.3 / 26.2% |
| V0 full | K1 | **80.8** / 67.3 / 82.0% | **34.5** / 26.3 / 22.2% |
| V0 full | K2 | 54.3 / 67.5 / 84.3% | 26.8 / **47.0 / 46.7%** |
| V0 full | K3 | 55.0 / 67.3 / 85.0% | 11.3 / 28.0 / 27.2% |

**The choice.**

- **K1 survives.** It is the only candidate that moves Shatter's reach: Steady by the end of Act 1 from 54% to 81% at V0 full, True by the end of Act 2 from 10% to 35%. A_lit does not hoard the two cards (0.38 Quarry Maul and 0.19 Fan of Glass a run at V0 full), and G6 stays PASS in both cells. It brings G2 at V0 full to 10.0 pp. Its costs are A_lit at V0 fresh (−3.2 pp, p = 0.02) and committed Shatter at V0 full (−4.0 pp, p = 0.15): the committed pilot values the two attacks at ×3 and keeps 2.5 Fan of Glass a run.
- **K2 survives.** It doubles True for the Lantern and Edge at V0 full (30% → 47%) and moves no arm's win rate significantly. It cannot lift Shatter's True alone (27%), because Shatter's problem is supply; with K1 it should.
- **K3 is out.** It does not narrow G2 at V0 fresh (13.3 pp): Cathedral Glass at ×1 lifts every committed way, Shatter most (+4.8 pp, p < 0.01). It drops the committed Lantern's Steady by the end of Act 1 at V0 fresh to 37.7%, under fresh G5's 40%, and makes G6 UNDECIDED in both cells. The Lantern's fresh lead is not this card.
- **K1 and K2 go to the final table together.** They act on different terms of the same reach (supply and threshold), and neither screen moved a win rate against the other's target.

## The cell table

### Win rates, search player

Each figure has its Wilson 95% interval, with the paired change against readout 11 on the same seeds in brackets.

| Cell | C_shatter | C_lantern | C_edge | A | **A_lit** | R |
|---|---|---|---|---|---|---|
| V0 fresh (N = 1,000) | 19.8% (17.4–22.4) [−1.5, p = 0.40] | 37.7% (34.7–40.7) [**+3.2, p = 0.05**] | 22.7% (20.2–25.4) [+0.4, p = 0.82] | 22.9% (20.4–25.6) [−0.8, p = 0.37] | **31.9% (29.1–34.9)** [−0.5, p = 0.71] | 7.3% (5.8–9.1) [+0.4, p = 0.67] |
| V0 full (N = 1,000) | 42.7% (39.7–45.8) [**−6.2, p = 0.003**] | 49.8% (46.7–52.9) [+2.0, p = 0.20] | 38.9% (35.9–42.0) [+2.7, p = 0.06] | 38.1% (35.1–41.2) [−0.6, p = 0.47] | **47.3% (44.2–50.4)** [+1.7, p = 0.14] | 17.7% (15.5–20.2) [−0.2, p = 0.92] |
| V5 fresh (N = 2,000) | 1.7% (1.2–2.4) [−0.3, p = 0.47] | 6.5% (5.5–7.6) [−0.1, p = 1.00] | 2.4% (1.8–3.2) [+0.5, p = 0.10] | 2.0% (1.5–2.7) [+0.1, p = 0.63] | **3.9% (3.1–4.8)** [+0.1, p = 1.00] | 0.4% (0.2–0.7) [+0.0] |
| V5 full (N = 2,000) | 15.9% (14.4–17.6) [**−2.8, p = 0.008**] | 16.8% (15.2–18.5) [**+3.2, p < 0.001**] | 12.3% (10.9–13.8) [+0.5, p = 0.48] | 11.7% (10.4–13.2) [+0.1, p = 0.86] | **13.9% (12.4–15.4)** [+0.1, p = 1.00] | 4.0% (3.2–4.9) [−0.3, p = 0.25] |

### Committed reach (G5)

Steady by the end of Act 1 and True by the end of Act 2, over every run, with the share among runs alive at that act's end in brackets. The minimum of each row is in bold.

| Cell | | Shatter | Lantern | Edge |
|---|---|---|---|---|
| V0 fresh | Steady, Act 1 | 73.8% (92.5%) | **45.5%** (68.4%) | 59.6% (73.7%) |
| V0 fresh | True, Act 2 | 41.2% (77.4%) | 19.5% (37.4%) | **11.1%** (25.7%) |
| V0 full | Steady, Act 1 | 77.1% (87.8%) | **68.8%** (87.0%) | 83.4% (91.7%) |
| V0 full | True, Act 2 | 51.7% (74.0%) | 47.9% (73.5%) | **45.2%** (72.2%) |
| V5 full | Steady, Act 1 | 48.0% (89.0%) | **39.2%** (89.6%) | 52.6% (88.0%) |
| V5 full | True, Act 2 | 19.8% (64.7%) | 18.9% (69.7%) | **14.0%** (55.1%) |

Readout 11's V0 full rows were Steady 51.1 / 69.8 / 83.9% and True 12.5 / 33.0 / 24.8%. Committed Shatter now holds 2.8 Quarry Maul and 2.4 Fan of Glass a run at V0 full and is offered 17.6 of its own coloured mass a run (9.1 before). A_lit keeps 0.41 and 0.24 of them a run, A 0.35 and 0.12.

### Gates before (readout 11) and after

Point / 95% interval. **Bold** marks a verdict that moves.

| Cell | Gate | Readout 11 | Readout 12 |
|---|---|---|---|
| V0 fresh | G1 | FAIL / FAIL (Shatter 21.3%) | FAIL / FAIL (Shatter 19.8%) |
| V0 fresh | G2 | FAIL / UNDECIDED (+13.2 pp, L − S) | FAIL / **FAIL** (+17.9 pp, L − S; +14.0 to +21.7) |
| V0 fresh | G3 | PASS / UNDECIDED (−2.1 pp) | **FAIL** / UNDECIDED (A_lit − C_lantern −5.8 pp; −9.9 to −1.6; paired −9.9 to −1.7) |
| V0 fresh | G4 | FAIL / FAIL (−14.4 pp) | FAIL / FAIL (−12.5 pp) |
| V0 fresh | G5 | PASS / PASS (Steady min Lantern 48.4%) | PASS / PASS (Steady min Lantern 45.5%, 42.4–48.6) |
| V0 fresh | G6 | PASS / PASS (Edge 38.0% of 324) | PASS / PASS (Edge 36.7% of 319, 31.6–42.1; Shatter 30.7%, Lantern 32.6%) |
| V0 fresh | G7 | PASS | PASS |
| V0 full | G1 | FAIL / FAIL (Edge 36.2%) | FAIL / FAIL (Edge 38.9%) |
| V0 full | G2 | FAIL / UNDECIDED (+12.7 pp, S − E) | FAIL / UNDECIDED (+10.9 pp, L − E; +6.6 to +15.2) |
| V0 full | G3 | FAIL / UNDECIDED (−3.3 pp) | **PASS** / UNDECIDED (A_lit − C_lantern −2.5 pp; −6.9 to +1.9; paired −6.7 to +1.7) |
| V0 full | G4 | FAIL / FAIL (−18.3 pp) | FAIL / FAIL (−21.2 pp) |
| V0 full | G5 | FAIL / FAIL (Steady min Shatter 51.1%, True min Shatter 12.5%) | FAIL / **UNDECIDED** (Steady min Lantern 68.8%, 65.9–71.6; True min Edge 45.2%, 42.1–48.3) |
| V0 full | G6 | PASS / UNDECIDED (Edge 58.6% of 456) | PASS / UNDECIDED (Edge 55.4% of 473, 50.9–59.8; Shatter 22.6%, Lantern 22.0%) |
| V0 full | G7 | PASS | PASS |
| V5 fresh | G2 | PASS / PASS (+4.6 pp) | PASS / PASS (+4.8 pp, L − S; +3.6 to +6.0) |
| V5 fresh | G3 | PASS / UNDECIDED (−2.6 pp) | PASS / UNDECIDED (−2.6 pp; −3.9 to −1.2; paired −3.9 to −1.3) |
| V5 fresh | G4 | FAIL / FAIL (−1.6 pp) | FAIL / FAIL (−1.4 pp) |
| V5 fresh | G6 | PASS / UNDECIDED (Lantern 50.6% of 77) | PASS / **PASS** (Lantern 48.7% of 78, 37.9–59.6; Shatter 29.5%, Edge 21.8%) |
| V5 fresh | G7 | PASS | PASS |
| V5 full | G1 | FAIL / FAIL (Edge 11.8%) | FAIL / FAIL (Edge 12.3%) |
| V5 full | G2 | PASS / PASS (+6.9 pp, S − E) | PASS / PASS (+4.5 pp, L − E; +2.3 to +6.7) |
| V5 full | G3 | FAIL / UNDECIDED (−4.9 pp) | **PASS** / UNDECIDED (A_lit − C_lantern −2.9 pp; −5.2 to −0.7; paired −5.1 to −0.8; 4,000 seeds: −3.8 pp, FAIL on point, paired −5.3 to −2.3, UNDECIDED) |
| V5 full | G4 | FAIL / FAIL (−7.5 pp) | FAIL / FAIL (−8.3 pp) |
| V5 full | G5 | FAIL / FAIL (Steady min Shatter 34.5%, True min Shatter 3.1%) | FAIL / FAIL (Steady min Lantern 39.2%, True min Edge 14.0%) |
| V5 full | G6 | PASS / PASS (Edge 48.9% of 276) | PASS / PASS (Edge 45.1% of 277, 39.4–51.0; Shatter 29.6%, Lantern 25.3%) |
| V5 full | G7 | PASS | PASS |

G7 covers zero stalls and zero errors in all 36,012 runs of the final tables and the 8,000 of the second V5 full band, and A's three-seed replay, identical in every cell. No save field, id or RNG draw changed: affinity and the flame's constants are content that is never saved, and `trueMin` enters only the tier's comparison. As in readout 11, the grader prints V5 fresh's G3 point as −2.5 pp from the rates' exact fractions and its interval centre as −2.6 pp.

### G3 at V5 full, on common seeds

The grader's interval treats the arms as independent samples. `g3paired.py` reads the same difference seed by seed. Pairing narrows it only a little here: the correlation between A_lit's and the Lantern's outcomes on a seed is 0.10, so the paired interval at 2,000 seeds (−5.1 to −0.8 pp) is barely tighter than Newcombe's independent one (−5.2 to −0.7). A second band of 2,000 seeds at the same head was therefore run for the four arms G3 reads.

| V5 full | Best committed | A_lit − best (point) | Paired 95% interval | Verdict (point / interval) |
|---|---|---|---|---|
| seeds 13000–14999 (the table) | C_lantern 16.8% | −2.9 pp | −5.1 to −0.8 | PASS / UNDECIDED |
| seeds 15000–16999 | C_lantern 17.9% | −4.6 pp | −6.7 to −2.5 | FAIL / UNDECIDED |
| both, 4,000 seeds | C_lantern 17.4% | **−3.8 pp** | **−5.3 to −2.3** | **FAIL / UNDECIDED** |

On 4,000 common seeds A_lit wins 13.6% and the committed Lantern 17.4% (the next best way, Shatter, 16.6%). The best estimate sits 0.8 pp outside the band, and the interval runs from −5.3 to −2.3 pp, so neither PASS nor FAIL is decided. Deciding it would need the interval's half-width (1.5 pp at 4,000 seeds) under 0.8 pp, about 14,000 paired seeds per arm. The honest reading is that G3 at V5 full sits on its threshold: the skilled adaptive player is 3–4 pp behind the best committed way, and no seed count this lane could afford can say on which side of −3 pp. Readout 11's −4.9 pp on the first band is −2.9 pp with this PR's content; the committed Lantern's rise (+3.2 pp, p < 0.001) is why the gap did not close further.

### Row B, the bot round (V0, search player)

| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 (readout 11) |
|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 19.8% (17.4–22.4) | PASS | 79.1% (78.5–79.7) | 1.0% (0.9–1.1) | **UNDECIDED** (PASS) |
| V0 fresh | C_lantern | 37.7% (34.7–40.7) | PASS | 60.4% (59.7–61.1) | 1.0% (0.9–1.2) | UNDECIDED (UNDECIDED) |
| V0 fresh | C_edge | 22.7% (20.2–25.4) | PASS | 68.9% (68.3–69.6) | 1.8% (1.6–2.0) | PASS (PASS) |
| V0 fresh | A_lit | 31.9% (29.1–34.9) | PASS | 59.1% (58.4–59.8) | 1.4% (1.2–1.6) | FAIL (FAIL) |
| V0 full | C_shatter | 42.7% (39.7–45.8) | PASS | 81.6% (81.0–82.1) | 1.0% (0.9–1.2) | UNDECIDED (UNDECIDED) |
| V0 full | C_lantern | 49.8% (46.7–52.9) | PASS | 71.6% (71.0–72.2) | 0.9% (0.8–1.1) | UNDECIDED (UNDECIDED) |
| V0 full | C_edge | 38.9% (35.9–42.0) | PASS | 82.1% (81.6–82.6) | 1.4% (1.2–1.6) | PASS (PASS) |
| V0 full | A_lit | 47.3% (44.2–50.4) | PASS | 63.4% (62.8–64.1) | 1.2% (1.1–1.4) | PASS (PASS) |

Committed Shatter's fresh row moves from PASS to UNDECIDED on close calls (1.0%, interval 0.9–1.1% against the 1% floor) while its expression rises from 71.7% to 79.1%. A_lit's own feel row at V0 fresh is 59.1% (58.4–59.8%) against 60%: 0.4 pp above readout 11's and still a decided FAIL.

## Decision

**Ship K1 and K2.** Together they make the True tier and its payoff common for every committed way in the full pool: True by the end of Act 2 at V0 full is now 45–52% for every way (readout 11: 12.5–33.0%), and Shatter reaches Steady by the end of Act 1 in 77.1% of runs (51.1%). G3 comes back into range on its point at V0 full (−2.5 pp, was −3.3) and on the table's band at V5 full (−2.9 pp, was −4.9); on 4,000 paired seeds V5 full reads −3.8 pp, UNDECIDED. G6 keeps its PASS in every cell and gains an interval PASS at V5 fresh. B1 and G7 hold. A_lit and A do not move in any cell (largest change +1.7 pp, p = 0.14).

Every verdict that worsens, and what it costs:

- **G2 at V0 fresh: the interval moves from UNDECIDED to FAIL** (+17.9 pp, +14.0 to +21.7). The committed Lantern gains 3.2 pp (p = 0.05) and committed Shatter loses 1.5 pp (p = 0.40). The Lantern's fresh lead was this cell's problem before the lane; it is now decided against the 10 pp limit.
- **G3 at V0 fresh: the point moves from PASS to FAIL** (−5.8 pp; interval UNDECIDED). A_lit did not move (−0.5 pp, p = 0.71); the best committed arm, the Lantern, rose.
- **B2 for committed Shatter at V0 fresh: PASS to UNDECIDED**, on close calls at 1.0% (0.9–1.1%).
- **Committed Shatter's win rate falls** at V0 full (−6.2 pp, p = 0.003) and V5 full (−2.8 pp, p = 0.008). The committed pilot values Quarry Maul and Fan of Glass ×3 and keeps 2.4 Fan of Glass a run, as readout 11's C2 found for its four attacks. That fall, more than Edge's rise at the bottom (+2.7 pp, p = 0.06), is why G2 at V0 full narrows from 12.7 to 10.9 pp.
- **G5 at V0 fresh** stays PASS, but its minimum falls from 48.4% to 45.5% (the Lantern, which no longer keeps Quarry Maul at its clear-glass worth).
- **G1** at V0 fresh (Shatter 21.3% → 19.8%) and **G4** at V0 fresh (R − worst −14.4 → −12.5 pp) and V5 fresh (−1.6 → −1.4 pp) stay FAIL and move further from their thresholds. In the full cells both move towards theirs (G1 V0 Edge 36.2% → 38.9%; G4 V0 −18.3 → −21.2 pp, V5 −7.5 → −8.3 pp) and still fail.

The design reading supports both levers. Fan of Glass and Quarry Maul speak Shatter's verb: they exist to chip, the first every enemy at once, the second once it is tempered. Shatter was the only way whose commons were a single card. True was meant to be the committed deck's reward. At 0.80 a deck could earn it by the end of Act 2 only by removing its starting seeds, which the game never asks for and the bot never does. At three in four, a committed deck that carries its two off-colour seeds lights True with six of its own pieces and no other stray glass.

**What this lane did not reach.**

- **G5 full Steady.** At V0 full the committed Lantern reaches Steady by the end of Act 1 in 68.8% of runs (65.9–71.6%), 1.2 pp short on point. 87.0% of its runs alive at the end of Act 1 are Steady; the gap is its Act 1 survival (79.1%). At V5 full the floors are out of reach by construction, since only 44–60% of committed runs survive Act 1. Among survivors, V5 full Steady is 88–90% for every way, and True among Act 2 survivors is 55–70%.
- **G2 at V0.** Fresh is now a decided FAIL (+17.9 pp, the Lantern); full is +10.9 pp on point.
- **A_lit's B2 at V0 fresh** stays a decided FAIL at 59.1%.

## Tests and pins

- **Pins** (`0ad45f30`). `test_balance_catalogue` re-pins the live file SHA (`87c879c4…`) and the semantic SHA (`a5c79971…`); both move only because of the two affinity lines and the one constant. In `test_balance_sim`, seed 1000's digest (`bb86394a…`) does not move: that run replays unchanged. The unlit check's seed 1001 does move. Its deck takes Fan of Glass, now Shatter glass, which changes its flame from its fifth fight; its zero-knob digest is now `7b8a17cc…`, and its knobs-at-one run still differs from it, so the check stays non-vacuous.
- **Unchanged and passing.** Every flame, arm, stagecraft and pilot test passes with its decks and assertions as they were. The §4 worked examples read the same tiers (their 5/7 deck is Steady under either threshold). `test_balance_ways.py` and the #490 tier-1 registry pass; the frozen snapshots in `docs/balance/data/` are untouched. No `port_fixtures/` golden moved.

## What the next readout should ask

1. **The Lantern's fresh lead** is now the largest gap in the table (G2 V0 fresh +17.9 pp, decided). The diagnosis puts it in Act 3 conversion through the Ember engine, whose commons carry readout 9's riders, and in three Cathedral Glass a run from a four-card rare slot. A lever there touches the riders or the fresh rare pool, both outside this lane's scope.
2. **The committed pilot's ×3** over-reads ordinary attacks once they carry a way's affinity (Fan of Glass 2.4 copies a run). Whether the committed arm's `commit` should scale with affinity weight or card worth is an instrument question for the lock: it is what costs committed Shatter 6.2 pp at V0 full.
3. **The removal economy in the bot.** No committed run removes its off-colour seeds, because shop removal needs two copies of the worst card. A pilot that removes off-colour glass first, as §4's worked example does, would measure True as a player reaches it.
4. **G5 at V5** counts runs that died before the act's end. The lock should decide whether reachability is read over every run or over runs alive at the act's end; over survivors, V5 full already passes Steady for every way.
5. **G3 at V5 full** is −3.8 pp on 4,000 paired seeds (−5.3 to −2.3), 0.8 pp outside its band. The lock should either fund about 14,000 paired seeds for the exam's reading of this cell or adopt a paired grader with an equivalence margin; no content lever can be told apart from noise there.

## Appendix: the scripts

All scripts are in the lane's private scratch folder, as in readouts 9–11.

| Script | What it does |
|---|---|
| `chunked.py` | Readout 9's appendix B runner, pointed at this worktree. |
| `diag12.py` | Offers own and off, survival by act, act-end own and off mass, picks short of Steady and True, the removal economy and threshold re-reads. |
| `cf_seeds.py` | Static re-read of reach with the starter seeds at another weight or another `trueMin`. |
| `pools.py` | Coloured mass and per-draw affinity on offer, per rarity and pool state. |
| `take.py`, `lead.py`, `cond.py` | Held over offered per card and arm; per-card association with winning against an older report; win rate among Act 2 survivors by copies held. |
| `make_candidates.py` | Writes the candidate catalogues as text edits to the content file. |
| `screen.sh`, `screen_grade.py` | Run and grade the screen. |
| `paired.py`, `rowb.py` | Paired changes against readout 11; row B. |
| `g3paired.py`, `merge.py` | G3 on common seeds with Newcombe's paired interval; the two V5 full bands joined. |
