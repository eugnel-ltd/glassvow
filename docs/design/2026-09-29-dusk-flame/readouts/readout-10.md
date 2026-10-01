# Readout 10: a flame-aware adaptive arm

> **Research readout (AI-SDLC discovery), promoted in one PR.** The PR ships an instrument, not a balance change: a sixth arm, A_lit, in the simulator's pilot (`74635ae3`), and the grader reading G3 and G6 against it with A kept as their floor (`475c1f81`). No content, locale, `port_fixtures/` golden, rider, lantern knob, enemy number, combat rule or RNG draw moved; `content/full-content.json` is readout 9's, SHA-256 `0faf9a96462e168fd506255bc3b04a3174f8b357e3f3e09e3cb60ccac5def771`.
>
> **Head.** The final tables (V0 at 1,000 paired seeds, V5 at 2,000) ran at `475c1f81455a058897cafac176ed09664f0ec323`, whose manifest every report names. The screen ran before that commit with the same code (its chosen variant reproduces at the head run for run, 800 of 800 rows). Later commits add documents only; `git diff 475c1f81..HEAD -- tools domain content tests` is empty.

Readout 9 gave each way a payoff that only a committed deck collects. G3 then failed on its point estimates (the adaptive arm 5.6 pp under the best committed way at V0 fresh, 7.3 pp at V0 full), because arm A reads the reward offers and never its own lantern. A player who sees the lantern burn blood-moon and reads "Blood-moon flame: gain 3 Ward" on a card leans into it. The orchestrator ruled that G3, G6 and B2 are read against a flame-aware adaptive arm from now on, the commit-blind A staying in the table as a floor, and set this lane: build that arm, run the lock's cell table with it, and say what it brings. Nothing in the game was to be tuned.

## The answer in brief

- **The arm.** A_lit is arm A until its lantern burns a way's colour, Steady or True. From then on, until the flame dims, its build choices (rewards, shops, events, rests, removals) value that way's glass ×2.0 (`litLean`), other coloured glass ×0.5 (`litOff`), and riders in that colour (§6.4) at full worth instead of the pilot's `crackedShare`. At Kindling or Soot it scores exactly as A does. It plays its fights as every arm does, with readout 8's search player.
- **It plays better than A everywhere, and only by keeping its flame lit.** Paired on the same seeds: **V0 fresh +6.6 pp** (23.2% → 29.8%; 122 seeds gained, 56 lost, p < 0.001), **V0 full +5.3 pp** (40.0% → 45.3%; 131 / 78, p < 0.001), V5 fresh +1.9 pp (1.6% → 3.5%; 48 / 11, p < 0.001), V5 full +1.9 pp (12.5% → 14.3%; 100 / 63, p = 0.005). Its decks light about as often as A's (467 against 448 of 1,000 runs at V0 fresh fight at least once in a colour), but they stay lit: 37.7% of its fights are fought in a colour against A's 11.9% (fresh), 43.1% against 16.7% (full).
- **G3 comes into range in three of the four cells.** Against the best committed way, A_lit sits at **+1.0 pp at V0 fresh** (PASS on point and interval), **−2.0 pp at V0 full** (PASS on point, UNDECIDED on interval, −6.4 to +2.4), −0.6 pp at V5 fresh (PASS / PASS), and **−3.4 pp at V5 full**, a point FAIL by 0.4 pp whose interval (−5.7 to −1.1) is UNDECIDED. A, the floor, fails three of the four on point as in readout 9.
- **G6 is unchanged in kind.** A_lit passes it in both fresh cells (Edge 49.0% of its V0 wins) and fails it in both full cells, where Edge leads its wins at 71.3% (V0) and 72.5% (V5), lower than A's 79.0% and 82.4% but far over 60%. The flame A_lit holds is mostly blood-moon: at V0, Edge is 23–31% of its fights, Shatter and the Lantern 5–9% each.
- **B2 on A_lit.** Its coloured plays favour the colour the fight began in 59.6% of the time at V0 fresh (58.9–60.3%, UNDECIDED against 60%) and 65.3% at V0 full (PASS), against A's 49.9% and 53.9% (FAIL); its close calls, 1.3% and 1.1%, are inside 1–10%. The committed arms' B2 is readout 9's, unchanged.
- **One knob does the work.** On the development seeds, leaning into the lit way's glass without avoiding the other ways' (`litOff` 1.0) moved A_lit by 0.8–2.0 pp (p ≥ 0.37); avoiding the other ways' glass (0.5 or 0.25) moved it 4.0–5.2 pp at any `litLean` from 1.0 to 2.0. It is readout 9's purity axis, seen from the adaptive side: the riders reward a deck that stays one colour, and the arm earns them by not diluting its flame.
- **A is byte for byte unchanged.** Every run row of C_shatter, C_lantern, C_edge, A and R in this PR's tables is identical to readout 9's own reports on the same seeds (1,000 of 1,000 per arm at V0, 2,000 of 2,000 at V5), and the seed-1000 digests in `tests/test_balance_sim.gd` did not move.

## The arm

| | A | A_lit |
|---|---|---|
| Build at Kindling or Soot | the pilot's card and relic scores | the same scores |
| Build while the lantern burns a way's colour, Steady or True | the same scores | that way's glass ×2.0, other coloured glass ×0.5, clear glass ×1; that colour's riders at full worth |
| Relics, routes, potions | the pilot's | the pilot's (unchanged) |
| Fights | search player | search player (unchanged) |

**What it reads.** `Pilot.see_flame` reads `Flame.read(content, run)` before each build decision: on taking a fight's rewards, on entering a rest, event, shop or treasure, and again after an event choice's own effects (they can change the deck). The lit way is the reading's `dominant` when its `tier` is Steady or True, exactly as `CombatRules._set_lantern_quality` sets the way whose riders resolve, so what the arm leans on is what the next fight will light. Within one shop it plans its basket on the flame it walked in with.

**What a player sees.** The flame's colour and steadiness (§2, surface 1) and the colour a rider names (surface 6) are on screen. Card affinity is not printed (§2 rules out sigils); the arm reads it as the flame's visible answer to each pick (§4: "the pick dimmed it, visibly"), which a player learns within a run or two and the committed arms already assume. It reads nothing else: no hidden purity number, no tier constants, no future offers.

**The two knobs** live in the pilot as `LIT_LEAN` = 2.0 and `LIT_OFF` = 0.5 and reach the policy as `litLean` and `litOff` only for `--build=lit` (the grader's arm `A_lit`); the default policy carries neither, so every other arm's policy snapshot and build scores are untouched. The rider's full worth replaces the share for that colour only; a rider of another way keeps `crackedShare`, as A counts every rider. They mirror the committed arms' structure (`WAY_COMMIT` = 3.0, `WAY_OFF` = 0.5) at a lower lean, because the screen found the lean itself near idle.

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-adaptive-lit", removed before each commit.
# The screen (appendix A): A once, then A_lit at six (litLean, litOff) points, development seeds 12000-12399, V0:
screen.sh
# The final tables, the grader's own simulator commands in 50-seed chunks on ten processes (readout 9, appendix B):
python3 -B chunked.py <dir> --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay
python3 -B chunked.py <dir> --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay
# Grading:
python3 -B tools/balance_ways.py --from-dir <final-v0> --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir <final-v5> --seeds 13000-14999 --vows 5
# Paired changes, colour shares, A_lit's feel, and the run-for-run comparison with readout 9's reports:
python3 -B analyse.py <final-v0> v0-fresh,v0-full --base <readout 9's final-v0>
python3 -B analyse.py <final-v5> v5-fresh,v5-full --base <readout 9's final-v5>
```

- **Cells, arms, seeds.** The lock's §11 table: Duskblade, vows 0 and 5 with the shipping incentives, fresh and full pools, the six arms C_shatter, C_lantern, C_edge, A, A_lit and R on common seeds. V0 on 13000–13999 and V5 on 13000–14999, readout 9's bands, so every unchanged arm is readout 9's own figure and A_lit pairs with A run for run.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference), G3 and G6 now on A_lit with A's rows below them; row B as readout 9 computes it, plus A_lit's feel row graded on B2's thresholds. Paired tests count the seeds one arm wins and the other loses, exact two-sided binomial p.
- **Budget and the stop rule.** One screen of at most six knob points on the development band (never the reporting band), each 400 paired seeds per V0 cell with the search player; the point with the highest V0 win rate pooled over both pools ships, a point within 1 pp of it counting as equal only if it is simpler. Then one final table, read as it falls: the brief forbids tuning anything else to bring G3 into range.
- **Wall time.** About 160 s per screen point; 46 minutes for the V0 table and 46 for the V5 table on ten processes; 36,012 search run rows in the final tables (six arms, plus A's replays), 5,600 in the screen and 800 in the reproduction check.

## The screen

Development seeds 12000–12399, V0, search player, A_lit against A on the same 400 seeds per cell.

| `litLean` / `litOff` | Cell | A_lit | A | Paired change (gained / lost, p) | Fights in a colour, A_lit / A | A_lit wins by way S / L / E |
|---|---|---:|---:|---|---|---|
| 1.5 / 1.0 | fresh | 26.2% | 25.2% | +1.0 pp (24 / 20, p = 0.65) | 17.0% / 11.6% | 19 / 20 / 66 |
| 1.5 / 1.0 | full | 41.0% | 39.8% | +1.2 pp (26 / 21, p = 0.56) | 26.5% / 16.2% | 20 / 30 / 114 |
| 2.0 / 1.0 | fresh | 26.0% | 25.2% | +0.8 pp (25 / 22, p = 0.77) | 19.1% / 11.6% | 18 / 22 / 64 |
| 2.0 / 1.0 | full | 41.8% | 39.8% | +2.0 pp (34 / 26, p = 0.37) | 29.5% / 16.2% | 19 / 31 / 117 |
| 1.0 / 0.5 | fresh | 29.2% | 25.2% | +4.0 pp (42 / 26, p = 0.07) | 34.2% / 11.6% | 20 / 30 / 67 |
| 1.0 / 0.5 | full | 45.0% | 39.8% | +5.2 pp (51 / 30, p = 0.03) | 41.4% / 16.2% | 20 / 40 / 120 |
| **2.0 / 0.5 (ships)** | fresh | 30.2% | 25.2% | +5.0 pp (45 / 25, p = 0.02) | 35.3% / 11.6% | 23 / 32 / 66 |
| **2.0 / 0.5 (ships)** | full | 44.5% | 39.8% | +4.8 pp (49 / 30, p = 0.04) | 42.1% / 16.2% | 21 / 43 / 114 |
| 3.0 / 0.5 | fresh | 29.8% | 25.2% | +4.5 pp (43 / 25, p = 0.04) | 35.4% / 11.6% | 23 / 30 / 66 |
| 3.0 / 0.5 | full | 41.8% | 39.8% | +2.0 pp (48 / 40, p = 0.46) | 41.7% / 16.2% | 21 / 39 / 107 |
| 2.0 / 0.25 | fresh | 30.0% | 25.2% | +4.8 pp (39 / 20, p = 0.02) | 40.5% / 11.6% | 19 / 31 / 70 |
| 2.0 / 0.25 | full | 44.0% | 39.8% | +4.2 pp (50 / 33, p = 0.08) | 45.2% / 16.2% | 21 / 44 / 111 |

Pooled over both pools, 2.0 / 0.5 wins 37.4%, 1.0 / 0.5 37.1%, 2.0 / 0.25 37.0%, 3.0 / 0.5 35.8%, and the two points without `litOff` 33.6–33.9% (A 32.5%). The three best are within 0.4 pp of each other, well inside the noise; 2.0 / 0.5 ships as the highest, and it is the arm the brief describes (the lit way's glass valued more, not merely the others' less). The reading that matters is the split by knob: `litOff` carries the gain, `litLean` does not, and a very high lean (3.0) starts to cost in the full pool, as the commitment curve of readout 9 cost the committed arms their clear sustain glass.

## The cell table

### Win rates, search player

| Cell | C_shatter | C_lantern | C_edge | A | **A_lit** | R |
|---|---|---|---|---|---|---|
| V0 fresh (N = 1,000) | 20.8% (18.4–23.4) | 28.8% (26.1–31.7) | 21.1% (18.7–23.7) | 23.2% (20.7–25.9) | **29.8% (27.0–32.7)** | 6.9% (5.5–8.6) |
| V0 full (N = 1,000) | 47.3% (44.2–50.4) | 44.8% (41.7–47.9) | 37.3% (34.4–40.3) | 40.0% (37.0–43.1) | **45.3% (42.2–48.4)** | 18.4% (16.1–20.9) |
| V5 fresh (N = 2,000) | 1.5% (1.1–2.1) | 4.1% (3.3–5.1) | 2.5% (1.9–3.3) | 1.6% (1.1–2.2) | **3.5% (2.7–4.3)** | 0.4% (0.2–0.8) |
| V5 full (N = 2,000) | 17.8% (16.1–19.5) | 11.3% (10.0–12.8) | 9.7% (8.5–11.1) | 12.5% (11.1–14.0) | **14.3% (12.9–16.0)** | 4.5% (3.7–5.6) |

Wilson 95% intervals. Every committed, A and R figure is readout 9's: the run rows are identical.

### A_lit against A, paired

| Cell | A | A_lit | Change | Seeds gained / lost | p |
|---|---:|---:|---:|---|---:|
| V0 fresh | 23.2% | 29.8% | **+6.6 pp** | 122 / 56 | < 0.001 |
| V0 full | 40.0% | 45.3% | **+5.3 pp** | 131 / 78 | < 0.001 |
| V5 fresh | 1.6% | 3.5% | +1.9 pp | 48 / 11 | < 0.001 |
| V5 full | 12.5% | 14.3% | +1.9 pp | 100 / 63 | 0.005 |

Where the gain comes from (V0, deaths in Act 1 / 2 / 3): fresh A 371 / 184 / 213, A_lit 300 / 190 / 212; full A 277 / 173 / 150, A_lit 217 / 163 / 167. A_lit survives Act 1 more often and dies about as often after it; its HP lost per fight falls from 9.63 to 9.16 (fresh) and from 11.12 to 10.46 (full).

### G3 and G6, read against A_lit, with A as the floor

Point / 95% interval.

| Cell | G3 on A_lit | G3 floor, A | G6 on A_lit | G6 floor, A |
|---|---|---|---|---|
| V0 fresh | **PASS / PASS** (A_lit − C_lantern +1.0 pp, −3.0 to +5.0) | FAIL / UNDECIDED (−5.6 pp, −9.4 to −1.8) | **PASS / PASS** (Edge 49.0%, 43.4–54.6%, of 298; Shatter 22.1%, Lantern 28.9%) | PASS / PASS (Edge 50.4% of 232) |
| V0 full | **PASS / UNDECIDED** (A_lit − C_shatter −2.0 pp, −6.4 to +2.4) | FAIL / UNDECIDED (−7.3 pp, −11.6 to −3.0) | FAIL / FAIL (Edge 71.3%, 67.0–75.3%, of 453; Shatter 13.5%, Lantern 15.2%) | FAIL / FAIL (Edge 79.0% of 400) |
| V5 fresh | **PASS / PASS** (A_lit − C_lantern −0.6 pp, −1.8 to +0.5) | PASS / UNDECIDED (−2.5 pp, −3.6 to −1.5) | **PASS / PASS** (Lantern and Edge 40.6% each of 69, 29.8–52.4%; Shatter 18.8%) | PASS / UNDECIDED (Edge 40.6% of 32) |
| V5 full | FAIL / UNDECIDED (A_lit − C_shatter −3.4 pp, −5.7 to −1.1) | FAIL / FAIL (−5.2 pp, −7.5 to −3.0) | FAIL / FAIL (Edge 72.5%, 67.0–77.3%, of 287; Shatter 13.6%, Lantern 13.9%) | FAIL / FAIL (Edge 82.4% of 250) |

The grader prints V5 fresh's point difference as −0.7 pp from the rates' exact fractions and its interval centre as −0.6 pp; both are 69 − 82 wins of 2,000.

**What A_lit does not bring.** At V5 in the full pool A_lit is still 3.4 pp under committed Shatter, 0.4 pp outside G3's lower bound on the point estimate, and its interval cannot decide. G6 fails in both full-pool cells on A_lit as on A: the adaptive wins that the full pool adds are Edge's. G3's upper bound is never near (A_lit is at most 1.0 pp over the best committed way), so "commitment is no trap" holds without strain.

### G1, G2, G4, G5, G7: unchanged

They read only the committed and random arms (and G7 A's replay), whose rows are readout 9's; their verdicts are readout 9's. V0 fresh: G1 FAIL / FAIL (worst Shatter 20.8%), G2 PASS / UNDECIDED (+8.0 pp), G4 FAIL / FAIL (R − Shatter −13.9 pp), G5 PASS / PASS (Steady min Lantern 43.3%), G7 PASS. V0 full: G1 FAIL / FAIL (Edge 37.3%), G2 PASS / UNDECIDED (+10.0 pp), G4 FAIL / FAIL (−18.9 pp), G5 FAIL / FAIL (Steady min Shatter 46.3%, True min 8.7%), G7 PASS. V5 fresh: G1 n/a, G2 PASS / PASS (+2.6 pp), G4 FAIL / FAIL, G7 PASS. V5 full: G1 FAIL / FAIL (Edge 9.7%), G2 PASS / UNDECIDED (+8.1 pp), G4 FAIL / FAIL (−5.2 pp), G5 FAIL / FAIL, G7 PASS. Zero stalls and zero errors in all 36,012 runs; A's three-seed replay is identical in every cell.

### Share of fights fought in each colour

Steady or True at the fight's start (the readout-9 table, on this PR's runs). "Any" is the sum of the three colours.

| Cell | Arm | Shatter colour | Lantern colour | Edge colour | Any | of which True | Soot |
|---|---|---:|---:|---:|---:|---:|---:|
| V0 fresh | C_shatter | 57.8% | 0.0% | 0.3% | 58.0% | 9.8% | 1.6% |
| V0 fresh | C_lantern | 0.0% | 57.2% | 0.1% | 57.3% | 8.7% | 2.5% |
| V0 fresh | C_edge | 0.0% | 0.0% | 73.3% | 73.4% | 11.3% | 0.3% |
| V0 fresh | A | 1.1% | 1.8% | 9.1% | 11.9% | 0.1% | 32.7% |
| V0 fresh | **A_lit** | **5.9%** | **8.5%** | **23.3%** | **37.7%** | 7.1% | 23.2% |
| V0 fresh | R | 3.3% | 1.2% | 8.4% | 12.9% | 0.2% | 15.6% |
| V0 full | C_shatter | 52.0% | 0.0% | 0.3% | 52.3% | 6.5% | 2.7% |
| V0 full | C_lantern | 0.0% | 73.1% | 0.0% | 73.1% | 23.6% | 0.6% |
| V0 full | C_edge | 0.0% | 0.0% | 81.5% | 81.5% | 38.3% | 0.1% |
| V0 full | A | 0.8% | 1.2% | 14.7% | 16.7% | 0.2% | 28.2% |
| V0 full | **A_lit** | **5.3%** | **6.9%** | **30.9%** | **43.1%** | 16.4% | 19.8% |
| V0 full | R | 1.0% | 2.3% | 11.2% | 14.5% | 0.2% | 20.9% |
| V5 fresh | A | 3.1% | 1.8% | 5.6% | 10.5% | 0.0% | 24.0% |
| V5 fresh | **A_lit** | **9.1%** | **5.8%** | **13.7%** | **28.6%** | 3.0% | 19.1% |
| V5 full | A | 0.9% | 1.2% | 11.8% | 13.8% | 0.1% | 26.4% |
| V5 full | **A_lit** | **4.5%** | **5.3%** | **23.3%** | **33.1%** | 7.8% | 20.7% |

A_lit fights in a colour about three times as often as A, and the colour is Edge's more often than the other two together (1.6 times at V0 fresh, 2.5 times at V0 full). At V0 it reaches its first lit fight in about as many runs as A (467 against 448 of 1,000 fresh, 512 against 493 full); the difference is that it stays there. It also leaves Soot behind: about 30% fewer of its fights are fought in a guttering lantern.

### Row B, the bot round (V0, search player)

The committed arms' rows are readout 9's (B1 PASS for every way in both pools; B2 PASS for Edge, UNDECIDED for Shatter and the Lantern). The adaptive arms' feel rows, graded on B2's thresholds, expression measured against the colour each fight began in:

| Cell | Arm | Expression (95%) | Close calls (95%) | B2 |
|---|---|---|---|---|
| V0 fresh | A | 49.9% (49.1–50.6%, n = 17,459) | 1.5% (1.3–1.7%, n = 16,691) | FAIL |
| V0 fresh | **A_lit** | 59.6% (58.9–60.3%, n = 18,738) | 1.3% (1.1–1.5%, n = 18,036) | **UNDECIDED** |
| V0 full | A | 53.9% (53.2–54.6%, n = 19,156) | 1.2% (1.1–1.4%, n = 18,556) | FAIL |
| V0 full | **A_lit** | 65.3% (64.6–65.9%, n = 20,275) | 1.1% (1.0–1.3%, n = 19,728) | **PASS** |

In the fights A_lit begins in a colour, its plays favour that colour 84–92% of the time (V0, every way and pool): it plays like a committed deck once lit. The overall figure is diluted by its unlit fights.

## Tests and pins

- `tests/test_balance_adaptive_lit.gd` (new): A_lit sees the lit way at Steady and none at Kindling or Soot; offered an Edge card and a clear twin of equal catalogue score, the clear one first, A and A_lit at Kindling and Soot take the first, A_lit at Steady Edge takes the Edge card; under Steady Edge other coloured glass scales by `litOff` and clear glass not at all; Splinter Cut's lit Ward counts in full under Edge and at `crackedShare` under Shatter; at Kindling and Soot every build score is A's; arm A and a committed arm never see the flame and the default policy carries no `litLean`; `--build=lit` carries both knobs, refuses a committed way, and its run replays. Two mutations were each caught (dropping the lean; dropping the full-worth rider).
- `tests/test_balance_ways.py`: the fixture carries A_lit; a new case moves A_lit alone and checks G3 and G6 follow it while the floor rows follow A, on point and interval, and that a missing A_lit seed fails closed.
- No pin moved. `tests/test_balance_sim.gd`'s seed-1000 digests, `test_balance_pilot_play`, `test_balance_pilot_cache`, `test_balance_arms`, `test_balance_search` and `test_lit_riders` pass unchanged, and the unchanged arms' 30,000 run rows reproduce readout 9's byte for byte.

## What the reading suggests

For the orchestrator; nothing here was turned.

1. **G3 is the brief's question, answered.** With an adaptive player that reads its own flame, insisting is rewarded and reading the offers is not punished: A_lit sits within 3 pp of the best committed way in three cells and 3.4 pp under it at V5 full. If the lock wants that cell decided, it needs more seeds or a stronger adaptive build, not content.
2. **The lean that pays is purity.** A_lit gains from avoiding the other ways' glass once lit, not from valuing its own more. That is the same finding as readout 9's purity sweep, now from the adaptive side, and it is what a player is taught by the flame dimming when they pick against it.
3. **G6 in the full pool is about Edge, not the arm.** A_lit's lit fights at V0 are Edge's two times in three or more (62% fresh, 72% full); the full pool's adaptive wins are Edge's 71–73% of the time with A_lit and 79–82% with A. The adaptive player finds and keeps the blood-moon flame more easily than the other two. Whether that is an offer-rate question (the starter Eclipse Slash plus the full pool's Edge glass) or a payoff question is for the next balance lane.
4. **B2 on A_lit is at the line in the fresh pool.** 59.6% expression against 60%: the arm's unlit fights pull its figure down. If B2 is to grade the adaptive arm, the lock may want it read on its lit fights, where it is 84–92%.

## Appendix A: the screen

`screen.sh` (private scratch folder) runs A once, then for each (`litLean`, `litOff`) point rewrites the pilot's `LIT_LEAN` and `LIT_OFF` constants in the worktree (never committed), runs arm A_lit alone through `chunked.py` (readout 9, appendix B) on seeds 12000–12399 in both V0 cells with the search player, and restores the pilot. The shipped point, 2.0 / 0.5, is the pilot's committed constants; re-run at the head on the same seeds it reproduces the screen's rows (800 of 800). `analyse.py` (same folder) computes the paired changes, colour shares, A_lit's feel by starting colour, and the run-for-run comparison with readout 9's reports.
