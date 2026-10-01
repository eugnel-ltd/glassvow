# Readout 9: lit glass, a payoff only a committed deck collects

> **Research readout (AI-SDLC discovery), promoted in one PR.** The candidates ran on scratch catalogues passed with `--content`; the PR ships one rule and the chosen catalogue. The rule (`4b8af8d6`): a card effect may carry `lit` with a way's id, and then it resolves only while the lantern burns that way's colour, Steady or True, as the fight began. The content (`082c4267`): eleven riders on the three ways' own glass, nothing else. `content/full-content.json` is byte for byte the measured "S1 + L1 + E3" catalogue, SHA-256 `0faf9a96462e168fd506255bc3b04a3174f8b357e3f3e09e3cb60ccac5def771`. No enemy number, hardship mod, vow mod, lantern knob, card number already printed, pool entry, affinity, id or RNG draw moved.
>
> **Head.** The final tables (V0 at 1,000 seeds, V5 at 2,000, the commitment curve and the purity sweep) ran at `082c42670eeeb2a6dcc51e19c57dc1213152b6af`, whose manifest every report names. The screening rounds ran before that commit with the same simulation code, the shipped one reproducing its round run for run (10,006 of 10,006 run rows identical at V0). Later commits add tests, test pins and documents only; `git diff 082c4267..HEAD -- tools domain content` is empty.

Readout 8 found that a capable player cannot carry Edge (14.4% at V0 full, 5.7% fresh), that the random build beat committed Edge, and that win rate did not rise with commitment for any way. The orchestrator kept the baseline hardship, made the search player the reading of record, and set this lane: give each way a payoff that only a committed deck collects, so that insisting on a way is rewarded and scattering is not; Edge first and deepest.

## The answer in brief

- **The payoff is lit glass.** A rider printed on a way's own glass, naming its flame's colour as the codex does, that resolves only while the lantern burns that colour Steady or True. The flame already tells committed decks from the rest: in readout 8's own runs a committed deck fights 54–78% of its fights in its own colour at V0, the adaptive arm 12–17% and the random arm 11–13% in any colour (most of it Edge's). A rider on that gate reaches a committed deck and almost no one else.
- **Edge: shipped, E3.** "Blood-moon flame: gain 3 Ward." on Eclipse Slash, Splinter Cut, Dim the Glass and Shatterhymn. Edge's wall was attrition; its Ward now comes from its own glass, and only when the deck is Edge. Committed Edge at V0: **full 14.4% → 37.3% (34.4–40.3%, N = 1,000), fresh 5.7% → 21.1% (18.7–23.7%)**. Its Act-2 deaths fall from 444 to 303. Row B1 is met for Edge in both pools, decisively.
- **Shatter: shipped, S1.** "Frost-white flame: chip 1 more Facet." on Chisel, Spall and Quakeblow. V0 full 38.0% → 47.3% (44.2–50.4%), fresh 13.0% → 20.8% (18.4–23.4%).
- **Lantern: shipped, L1.** "Amber flame: gain 1 Ember." on Tinder, Struck Match, Hearthfall and Tithe of Panes. V0 full 37.1% → 44.8% (41.7–47.9%), fresh 23.3% → 28.8% (26.1–31.7%).
- **Scattering is not rewarded.** Paired on the same 1,000 seeds, the random arm moves −0.6 pp at V0 full (50 seeds gained, 56 lost, p = 0.63) and +1.4 pp fresh (p = 0.07); the adaptive arm +1.8 pp (p = 0.35) and +1.7 pp (p = 0.30). The random build now sits 18.9 pp under the worst committed way at V0 full (interval −22.7 to −15.0), where it sat 4.6 pp *above* committed Edge.
- **G2 parity within 10 pp at V0, on the point estimates in both cells** (fresh: Lantern − Shatter 8.0 pp; full: Shatter − Edge 10.0 pp); both intervals straddle the line (UNDECIDED). At V5 (2,000 seeds) G2 passes in the fresh pool and is 8.1 pp, undecided, in the full pool.
- **What it costs.** G3 now fails on its point estimates: the adaptive arm sits 5.6 pp (fresh) and 7.3 pp (full) under the best committed way, where readout 8 had it level. That is the brief's aim seen from G3's side: insisting now beats the commit-blind adaptive bot. Row B2 turns undecided for Shatter as well as the Lantern: stronger decks have fewer close calls, and Shatter's fall onto the 1% floor.
- **The commitment curve still falls, and the reason is now visible.** Re-run on 1,000 seeds with the greedy pilot, the curve's slope is negative for every way before and after (Shatter and the Lantern flatten, Edge steepens). Its axis trades a way's glass against *clear* glass, not against the other ways' glass: from commit 1.0 to 3.0 every committed arm gives up Regrowth, Iron Skin, Deflect, Blood Rite and Agility for more of its own cards, while the share of fights its lantern is lit barely moves (Edge 73% to 79%). Readout 9's riders reward purity, the axis the curve holds fixed. On the purity axis (the other ways' glass avoided ever harder, own glass valued as clear) insisting now pays the Lantern in both pools and Shatter by 16.9 pp in the full pool, and no longer costs Edge, which it cost 7.7 pp (fresh) and 14.8 pp (full) on `main`; see [the curve](#the-commitment-curve).
- **Instrument.** Search player, the lock's cell table, 1,000 paired seeds (13000–13999) at V0, 2,000 (13000–14999) at V5. A search run costs about 2.0 s of CPU at V0 and 1.15 s at V5: 34 minutes for the V0 table and 38 minutes for the V5 table on ten processes. Four V0 search tables (three screening rounds and the shipped table, which reproduced its round), one V5 table and a 2,400-run spot check: 62,430 search run rows. Greedy screens, curves and sweeps: 380,228 run rows.

## The rule

A card effect may carry `"lit": "<way id>"`. `CombatState.lit_way` is set once, where the lantern's quality is set (`CombatRules._set_lantern_quality`), from the same flame reading: the dominant way when the tier is Steady or True, else empty. `CombatRules.effect_lit` gates each effect in `play_card` and in `preview_play`, so what the pilot, the search player and the HUD preview is what resolves. `ContentDB.validate` rejects a `lit` naming no way. Combat state is not saved: no save field, id or RNG draw changes. It is one content field, because the payoff cannot be expressed in content without it: no existing effect reads the flame.

The rider names the colour and nothing else, in the codex's own words (`codex.lantern.*`: frost-white 霜白, amber 金黃, blood-moon 血月). It names no tier and no way. The lock README gains [§6.4](../README.md#64-lit-glass-readout-9) and a sixth player-facing surface in §2.

Why the gate is selective (readout 8's V0 runs, share of fights fought in each colour, Steady or True, at the fight's start):

| Cell | Arm | Shatter colour | Lantern colour | Edge colour | Soot |
|---|---|---:|---:|---:|---:|
| V0 fresh | C_shatter | 57.8% | 0.0% | 0.1% | 0.8% |
| V0 fresh | C_lantern | 0.0% | 58.5% | 0.0% | 1.6% |
| V0 fresh | C_edge | 0.0% | 0.0% | 68.0% | 0.3% |
| V0 fresh | A | 1.1% | 1.8% | 9.0% | 32.8% |
| V0 fresh | R | 3.3% | 1.5% | 6.5% | 16.2% |
| V0 full | C_shatter | 53.4% | 0.0% | 0.1% | 1.7% |
| V0 full | C_lantern | 0.0% | 74.1% | 0.0% | 0.4% |
| V0 full | C_edge | 0.0% | 0.0% | 77.9% | 0.1% |
| V0 full | A | 0.4% | 1.4% | 14.7% | 26.7% |
| V0 full | R | 1.0% | 2.6% | 9.8% | 21.2% |

True alone would be more selective still, and too rare to pay: committed decks reach True in 6–31% of fights at V0 full and 9–11% fresh.

## How it was run

```sh
# Isolated user directory for every Godot process: override.cfg in the worktree root with
#   config/use_custom_user_dir=true and config/custom_user_dir_name="glassvow-true-tier", removed before each commit.
# Candidate catalogues from the shipped file (appendix A), into the private scratch folder:
python3 make_candidates.py content/full-content.json <scratch>/cat e1a e1b e1c e2 s1 l1
python3 make_candidates.py content/full-content.json <scratch>/cat s1+l1+e3 s1+l1+e5 s1+l1+e6
# Greedy screens (cheap sweeps), V0, 1,000 paired seeds:
python3 -B tools/balance_ways.py --seeds 13000-13999 --vows 0 --jobs 10 --content <catalogue> --out-dir <dir>
# Search rounds and the final tables: the grader's own simulator commands, split into 50-seed
# chunks so ten processes stay busy, merged into the grader's report layout (appendix B):
python3 -B chunked.py <dir> --seeds 13000-13999 --play search --replay [--content <catalogue>]
python3 -B chunked.py <dir> --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay
# Grading (the shipped tables):
python3 -B tools/balance_ways.py --from-dir <final-v0> --seeds 13000-13999 --vows 0
python3 -B tools/balance_ways.py --from-dir <final-v5> --seeds 13000-14999 --vows 5
# The commitment curve of 30 September, re-run at 1,000 seeds (appendix C), and the purity sweep:
curve.sh main <main's content>; curve.sh final; purity.sh main <main's content>; purity.sh final
```

- **Cells, arms, seeds.** The lock's §11 table: Duskblade, vows 0 and 5 with the shipping incentives, fresh and full pools, C_shatter, C_lantern, C_edge, A and R, paired seeds. V0 on 13000–13999, readout 8's band, so every "before" figure is readout 8's own report and every change is paired run for run. V5 on 13000–14999: readout 8 ran V5 on 13000–13399, so the V5 "before" is its 400 seeds and the paired change is read on those; 14000–14999 is a band no readout, development, CEM or acceptance range uses.
- **Measures.** The grader's G1–G7 on point and on 95% interval (Wilson for a rate, Newcombe's hybrid score interval for a difference), and row B as readout 8 computes it. Paired tests count the seeds one configuration wins and the other loses, exact two-sided binomial p.
- **Budget and the stop rule.** At most three candidates per way measured with the search player: Edge used three (E3, E5, E6), Shatter and the Lantern one each. The greedy pilot was used only to screen (six catalogues, 2–3 minutes each) and for the commitment curve, as the brief allows. A way ships a candidate only if it meets the brief's targets for that way: Edge ≥ 20% at V0 full and ≥ 10% fresh on the interval; Shatter and the Lantern not lower than readout 8 by more than their interval; and the catalogue as a whole keeps the random arm under the worst committed way at V0 full. Among candidates that meet them, G2 parity at V0 chooses, then the adaptive arm's share of the gain (G6).
- **The noise floor between rounds.** The three search rounds share S1 and L1, yet committed Shatter and Lantern moved by up to 3.1 pp between rounds (Lantern fresh 28.8%, 28.9%, 31.9%). A rider changes the pilot's card scores, so a deck that never lights Edge still picks, kindles and removes differently and its run diverges. Differences of that size between candidates are not read as effects.

## The candidates

### Greedy screens, V0, 1,000 paired seeds

Each against readout 8's greedy reports on the same seeds; own way first, then A and R. The screens chose the design and the card faces; none of these catalogues ships.

| Screen | What changes against `main` | Own way fresh / full | A fresh / full | R fresh / full | Verdict |
|---|---|---|---|---|---|
| E1a | Lit Ward +3 on Eclipse Slash, Splinter Cut, Dim the Glass, Cleft | +6.3 / +11.3 pp | +1.0 / +3.2 | +0.4 / +1.2 | the design works; Cleft's face has no room (below) |
| E1b | Lit Ward +3 on nine Edge cards | +10.8 / +23.8 | +1.8 / +5.8 | +0.5 / +1.6 | too many faces have no room |
| E1c | E1a at +5 Ward | +13.3 / +26.2 | +2.5 / +6.6 | +0.8 / +1.0 | as E1a |
| E2 | Board state, no tier: "gain 2 Ward for each Cracked on it" on Eclipse Slash, Splinter Cut, Cleft, Faultline | +21.2 / +27.4 | **+23.1 / +25.7** | **+6.9 / +17.4** | rejected: everyone collects it |
| S1 (four cards) | Lit chip +1 on Chisel, Spall, Ringing Blow, Quakeblow | +9.2 / +16.0 | +2.0 / −0.1 | +0.2 / +0.6 | the design works; Ringing Blow's face has no room |
| L1 | Lit Ember +1 on Tinder, Struck Match, Hearthfall, Tithe | +8.7 / +9.9 | +3.1 / +0.0 | −0.1 / +0.0 | ships as screened |

**Why board state alone fails.** E2 is the brief's first design space (strength from the Cracked already on the board) without a tier gate, and it pays everyone: Eclipse Slash is a starter, every Stagger cracks the glass it breaks, and the adaptive arm lays as much Cracked per fight as committed Edge (6.1 against 5.6 at V0 full in readout 8). The flame is the only reading in the game that tells an Edge deck from a deck with some Edge in it.

**Card faces.** A card's rules text has four lines of room (13 px Alegreya on the 132 px column, `card_view.gd`); no card today uses more. Every rider phrasing was measured headless with the card view's own wrap (`RulesText._wrap`) in both catalogues. "If your lantern burns blood-moon, gain 3 Ward." overran Cleft, Faultline, Tremor, Eclipse Step and Ringing Blow; the shipped form, "Blood-moon flame: gain 3 Ward.", fits on every card that carries it, in both languages (the longest, zh-Hant Shatterhymn, Spall and Quakeblow, at four lines). Cleft and Ringing Blow carry no rider for that reason.

### Search rounds, V0, 1,000 paired seeds

Each round is one catalogue with S1 (three cards) and L1, and one Edge candidate. Win rates with Wilson 95%; the change is paired against readout 8 on the same seeds.

| Round | Edge candidate | Cell | C_shatter | C_lantern | C_edge | A | R | G2 widest | A's wins led by Edge |
|---|---|---|---|---|---|---|---|---|---|
| readout 8 | none | fresh | 13.0% (11.1–15.2) | 23.3% (20.8–26.0) | 5.7% (4.4–7.3) | 21.5% (19.1–24.2) | 5.5% (4.2–7.1) | L − E 17.6 pp | 60.9% of 215 |
| readout 8 | none | full | 38.0% (35.0–41.0) | 37.1% (34.2–40.1) | 14.4% (12.4–16.7) | 38.2% (35.2–41.3) | 19.0% (16.7–21.5) | S − E 23.6 pp | 83.0% of 382 |
| **R1 (shipped)** | **E3: lit Ward +3 on Eclipse Slash, Splinter Cut, Dim the Glass, Shatterhymn** | fresh | 20.8% (18.4–23.4) | 28.8% (26.1–31.7) | 21.1% (18.7–23.7) | 23.2% (20.7–25.9) | 6.9% (5.5–8.6) | L − S 8.0 pp | 50.4% of 232 |
| **R1 (shipped)** | | full | 47.3% (44.2–50.4) | 44.8% (41.7–47.9) | 37.3% (34.4–40.3) | 40.0% (37.0–43.1) | 18.4% (16.1–20.9) | S − E 10.0 pp | 79.0% of 400 |
| R2 | E5: E3 and Dimming Cut, Inner Blaze, Totality, all +3 | fresh | 20.8% (18.4–23.4) | 28.9% (26.2–31.8) | 32.2% (29.4–35.2) | 26.6% (24.0–29.4) | 7.2% (5.8–9.0) | E − S 11.4 pp | 63.2% of 266 |
| R2 | | full | 47.3% (44.2–50.4) | 45.0% (41.9–48.1) | 48.5% (45.4–51.6) | 40.7% (37.7–43.8) | 19.2% (16.9–21.8) | E − L 3.5 pp | 82.6% of 407 |
| R3 | E6: E5's seven cards at +2 | fresh | 21.9% (19.4–24.6) | 31.9% (29.1–34.9) | 19.8% (17.4–22.4) | 26.1% (23.5–28.9) | 6.8% (5.4–8.5) | L − E 12.1 pp | 60.2% of 261 |
| R3 | | full | 48.4% (45.3–51.5) | 46.8% (43.7–49.9) | 40.4% (37.4–43.5) | 38.5% (35.5–41.6) | 18.9% (16.6–21.4) | S − E 8.0 pp | 77.4% of 385 |

Paired against readout 8 (gained / lost seeds, p):

| Round | Cell | C_shatter | C_lantern | C_edge | A | R |
|---|---|---|---|---|---|---|
| R1 (shipped) | fresh | +7.8 pp: 153 / 75, p < 0.001 | +5.5 pp: 158 / 103, p = 0.001 | +15.4 pp: 178 / 24, p < 0.001 | +1.7 pp: 125 / 108, p = 0.30 | +1.4 pp: 32 / 18, p = 0.07 |
| R1 (shipped) | full | +9.3 pp: 195 / 102, p < 0.001 | +7.7 pp: 201 / 124, p < 0.001 | +22.9 pp: 271 / 42, p < 0.001 | +1.8 pp: 173 / 155, p = 0.35 | −0.6 pp: 50 / 56, p = 0.63 |
| R2 | fresh | +7.8 pp | +5.6 pp | +26.5 pp: 286 / 21 | **+5.1 pp: 153 / 102, p = 0.002** | +1.7 pp: 35 / 18, p = 0.03 |
| R2 | full | +9.3 pp | +7.9 pp | +34.1 pp: 373 / 32 | +2.5 pp: 180 / 155, p = 0.19 | +0.2 pp |
| R3 | fresh | +8.9 pp | +8.6 pp | +14.1 pp: 165 / 24 | **+4.6 pp: 128 / 82, p = 0.002** | +1.3 pp |
| R3 | full | +10.4 pp | +9.7 pp | +26.0 pp: 294 / 34 | +0.3 pp | −0.1 pp |

### The choice, way by way

- **Edge: E3 ships.** All three meet Edge's targets with room. E3 is the only one that keeps G2 within 10 pp on the point estimates in both V0 cells (8.0 and 10.0 pp), the only one under which the adaptive arm does not gain measurably (+1.7 and +1.8 pp, p ≥ 0.30), and the one that lowers the Edge share of the adaptive arm's wins furthest in the fresh pool (60.9% → 50.4%, where G6 passes for the first time; full 83.0% → 79.0%; E6 gives 60.2% and 77.4%, E5 63.2% and 82.6%). E5 closes the full-pool gap best (3.5 pp, its interval inside 10 pp) but makes Edge the strongest way in the fresh pool, 11.4 pp over Shatter, and the adaptive arm collects 5.1 pp of it there; E6, the same seven cards at 2 Ward, is no better than E3 in the fresh pool and still pays the adaptive arm 4.6 pp. E3 is also the smallest change: four faces.
- **Shatter: S1 ships.** One candidate, and it meets the targets: +7.8 pp fresh and +9.3 pp full, the adaptive and random arms unmoved. In the fresh pool, where Quakeblow is still locked, the rider rides on Chisel and Spall alone.
- **Lantern: L1 ships.** One candidate: +5.5 pp fresh and +7.7 pp full, the adaptive and random arms unmoved. When the rider's Ember is the turn's first catch, a Steady lantern adds its first-gain bonus to it (§5), so it arrives as three; that is the lantern's rule as written, not a new one.

## Before and after

### G1–G7 at V0, search player, 1,000 paired seeds

Point / 95% interval, before (readout 8) → after (this PR's head).

| Cell | Gate | Before | After |
|---|---|---|---|
| V0 fresh | G1 | FAIL / FAIL (worst Edge 5.7%) | FAIL / FAIL (worst Shatter 20.8%, 18.4–23.4%) |
| V0 fresh | G2 | FAIL / FAIL (L − E +17.6 pp, +14.6 to +20.6) | **PASS / UNDECIDED** (L − S +8.0 pp, +4.2 to +11.8) |
| V0 fresh | G3 | PASS / UNDECIDED (A − L −1.8 pp) | FAIL / UNDECIDED (A − L −5.6 pp, −9.4 to −1.8) |
| V0 fresh | G4 | FAIL / FAIL (R − E −0.2 pp) | FAIL / FAIL (R − S −13.9 pp, −16.9 to −10.9; R 6.9%) |
| V0 fresh | G5 | PASS / UNDECIDED (Steady min 42.7%) | **PASS / PASS** (Steady min Lantern 43.3%, 40.3–46.4%) |
| V0 fresh | G6 | FAIL / UNDECIDED (Edge 60.9% of 215 A wins) | **PASS / PASS** (Edge 50.4%, 44.0–56.8%, of 232) |
| V0 fresh | G7 | PASS / PASS | PASS / PASS (0 stalls, 0 errors, replay 3/3) |
| V0 full | G1 | FAIL / FAIL (worst Edge 14.4%) | FAIL / FAIL (worst Edge 37.3%, 34.4–40.3%) |
| V0 full | G2 | FAIL / FAIL (S − E +23.6 pp, +19.8 to +27.3) | **PASS / UNDECIDED** (S − E +10.0 pp, +5.7 to +14.3) |
| V0 full | G3 | PASS / UNDECIDED (A − S +0.2 pp) | FAIL / UNDECIDED (A − S −7.3 pp, −11.6 to −3.0) |
| V0 full | G4 | FAIL / FAIL (R − E **+4.6 pp**, +1.3 to +7.9) | FAIL / FAIL (R − E −18.9 pp, −22.7 to −15.0; R 18.4%) |
| V0 full | G5 | FAIL / FAIL (Steady min Shatter 45.7%, True min 7.0%) | FAIL / FAIL (Steady min Shatter 46.3%, True min 8.7%) |
| V0 full | G6 | FAIL / FAIL (Edge 83.0% of 382) | FAIL / FAIL (Edge 79.0%, 74.7–82.7%, of 400) |
| V0 full | G7 | PASS / PASS | PASS / PASS |

### G1–G7 at V5, search player

Before: readout 8, 400 seeds (13000–13399). After: 2,000 seeds (13000–14999). The paired change is on the 400 seeds both share.

| Cell | Arm | Before (400) | After (2,000) | Paired change on 13000–13399 |
|---|---|---|---|---|
| V5 fresh | C_shatter | 0.0% (0.0–1.0) | 1.5% (1.1–2.1) | +0.8 pp: 3 / 0, p = 0.25 |
| V5 fresh | C_lantern | 3.0% (1.7–5.2) | 4.1% (3.3–5.1) | +0.5 pp: 9 / 7, p = 0.80 |
| V5 fresh | C_edge | 0.2% (0.0–1.4) | 2.5% (1.9–3.3) | +3.2 pp: 13 / 0, p < 0.001 |
| V5 fresh | A | 1.2% (0.5–2.9) | 1.6% (1.1–2.2) | +0.5 pp: 4 / 2, p = 0.69 |
| V5 fresh | R | 0.2% (0.0–1.4) | 0.4% (0.2–0.8) | +0.0 pp: 1 / 1 |
| V5 full | C_shatter | 12.2% (9.4–15.8) | 17.8% (16.1–19.5) | +6.0 pp: 40 / 16, p = 0.002 |
| V5 full | C_lantern | 10.2% (7.6–13.6) | 11.3% (10.0–12.8) | +2.2 pp: 25 / 16, p = 0.21 |
| V5 full | C_edge | 2.5% (1.4–4.5) | 9.7% (8.5–11.1) | +9.2 pp: 42 / 5, p < 0.001 |
| V5 full | A | 10.8% (8.1–14.2) | 12.5% (11.1–14.0) | +4.2 pp: 39 / 22, p = 0.04 |
| V5 full | R | 5.2% (3.5–7.9) | 4.5% (3.7–5.6) | +1.8 pp: 8 / 1, p = 0.04 |

| Cell | Gate | Before (400 seeds) | After (2,000 seeds) |
|---|---|---|---|
| V5 fresh | G1 | n/a | n/a (worst Shatter 1.5%) |
| V5 fresh | G2 | PASS / PASS (+3.0 pp) | PASS / PASS (L − S +2.6 pp, +1.6 to +3.7) |
| V5 fresh | G3 | PASS / UNDECIDED (−1.7 pp) | PASS / UNDECIDED (A − L −2.5 pp, −3.6 to −1.5) |
| V5 fresh | G4 | FAIL / FAIL | FAIL / FAIL (R − S −1.1 pp; R 0.4%) |
| V5 fresh | G6 | FAIL / UNDECIDED (5 A wins) | PASS / UNDECIDED (Edge 40.6% of 32 A wins) |
| V5 fresh | G7 | PASS / PASS | PASS / PASS |
| V5 full | G1 | FAIL / FAIL (worst Edge 2.5%) | FAIL / FAIL (worst Edge 9.7%, 8.5–11.1%) |
| V5 full | G2 | PASS / UNDECIDED (S − E +9.8 pp) | PASS / UNDECIDED (S − E +8.1 pp, +5.9 to +10.2) |
| V5 full | G3 | PASS / UNDECIDED (−1.5 pp) | FAIL / FAIL (A − S −5.2 pp, −7.5 to −3.0) |
| V5 full | G4 | FAIL / FAIL (R − E +2.7 pp) | FAIL / FAIL (R − E −5.2 pp, −6.8 to −3.6; R 4.5%) |
| V5 full | G5 | FAIL / FAIL | FAIL / FAIL (Steady min Shatter 28.6%, True min 1.6%) |
| V5 full | G6 | FAIL / FAIL (Edge 76.7% of 43) | FAIL / FAIL (Edge 82.4% of 250) |
| V5 full | G7 | PASS / PASS | PASS / PASS |

At V5 the payoff still orders the ways the right way round (every committed way above the random arm in both pools), but the hardship and the vows hold everything low; Edge in particular stays under 10% in the full pool.

### Row B, the bot round (V0, search player)

| Cell | Arm | Win rate before → after (95%, N = 1,000) | B1 | Expression after | Close calls after | B2 before → after |
|---|---|---|---|---|---|---|
| V0 fresh | C_shatter | 13.0% → 20.8% (18.4–23.4%) | PASS | 71.6% (70.9–72.2%) | 1.1% (1.0–1.3%) | PASS → UNDECIDED |
| V0 fresh | C_lantern | 23.3% → 28.8% (26.1–31.7%) | PASS | 60.1% (59.4–60.8%) | 0.9% (0.8–1.1%) | UNDECIDED → UNDECIDED |
| V0 fresh | C_edge | 5.7% → 21.1% (18.7–23.7%) | **FAIL → PASS** | 70.8% (70.2–71.5%) | 1.9% (1.7–2.1%) | PASS → PASS |
| V0 full | C_shatter | 38.0% → 47.3% (44.2–50.4%) | PASS | 72.3% (71.7–72.9%) | 1.1% (1.0–1.2%) | PASS → UNDECIDED |
| V0 full | C_lantern | 37.1% → 44.8% (41.7–47.9%) | PASS | 71.1% (70.4–71.7%) | 0.9% (0.8–1.1%) | UNDECIDED → UNDECIDED |
| V0 full | C_edge | 14.4% → 37.3% (34.4–40.3%) | **FAIL → PASS** | 82.3% (81.8–82.9%) | 1.6% (1.4–1.8%) | PASS → PASS |

**B1 is met for every way in both pools.** B2 is not: the riders make each way safer, and Shatter's close calls fall onto the 1% floor beside the Lantern's. Expression rises for Edge (79.4% → 82.3% at V0 full) and holds for the others.

### Feel and where decks die (V0, search)

| Cell | Arm | HP lost per fight before → after | Deaths Act 1 / 2 / 3 before → after |
|---|---|---|---|
| V0 fresh | C_shatter | 10.53 → 9.78 | 369 / 275 / 226 → 321 / 204 / 267 |
| V0 fresh | C_lantern | 10.70 → 10.28 | 405 / 179 / 183 → 378 / 172 / 162 |
| V0 fresh | C_edge | 11.65 → 10.32 | 395 / 421 / 127 → 192 / 422 / 175 |
| V0 full | C_shatter | 10.75 → 10.01 | 201 / 219 / 200 → 162 / 146 / 219 |
| V0 full | C_lantern | 11.91 → 11.41 | 254 / 179 / 196 → 238 / 159 / 155 |
| V0 full | C_edge | 11.52 → 10.19 | 197 / 444 / 215 → 89 / 303 / 235 |

Edge's Act-2 wall is lower, not gone: 303 of its 627 deaths at V0 full are still in Act 2, 422 of 789 in the fresh pool.

## The commitment curve

The 30 September sweep (`commitment-curve-2026-09-30.md`) re-run with its own method on 1,000 paired seeds instead of 200: the greedy pilot, V0, the committed arms' own-glass factor over 1.0–8.0 with the off-way factor at 0.5, and the 1.0/1.0 null point, on `main`'s content and on the shipped content. The shipped sweep ran at this PR's content commit. `main`'s sweep ran on `main`'s content before the code commit, with this PR's rule already in the tree; a catalogue without `lit` plays exactly as on `main` (spot checks against readout 8's reports: 10 of 10 search runs and 20 of 20 greedy runs identical).

Figure: [`readout-9-commitment-curve.png`](readout-9-commitment-curve.png).

| Cell | Way | `main`: 1.0 / 1.5 / 2.0 / 3.0 / 5.0 / 8.0 | Shipped: 1.0 / 1.5 / 2.0 / 3.0 / 5.0 / 8.0 | Slope, pp per doubling, `main` → shipped | Shipped, 1.0 to 3.0 (gained / lost, p) |
|---|---|---|---|---|---|
| fresh | Shatter | 4.4 / 7.6 / 4.9 / 4.5 / 4.2 / 4.2% | 11.0 / 12.7 / 9.1 / 10.4 / 9.8 / 9.8% | −0.5 → −0.6 | −0.6 pp: 63 / 69, p = 0.66 |
| fresh | Lantern | 14.8 / 22.0 / 23.7 / 13.7 / 13.7 / 13.7% | 20.3 / 27.4 / 29.2 / 22.2 / 22.2 / 22.2% | −2.0 → −0.7 | +1.9 pp: 120 / 101, p = 0.23 |
| fresh | Edge | 2.0 / 2.4 / 3.0 / 1.8 / 1.7 / 1.7% | 11.0 / 13.6 / 13.7 / 7.1 / 7.2 / 7.0% | −0.2 → −2.2 | −3.9 pp: 53 / 92, p = 0.002 |
| full | Shatter | 27.5 / 27.6 / 26.3 / 26.0 / 22.2 / 22.2% | 37.6 / 40.8 / 34.8 / 36.4 / 35.5 / 35.5% | −2.1 → −1.1 | −1.2 pp: 137 / 149, p = 0.52 |
| full | Lantern | 35.5 / 31.4 / 29.9 / 21.2 / 21.2 / 20.3% | 38.2 / 35.4 / 34.8 / 29.7 / 29.3 / 28.8% | −5.4 → −3.3 | −8.5 pp: 136 / 221, p < 0.001 |
| full | Edge | 13.2 / 9.2 / 8.2 / 7.0 / 7.0 / 6.9% | 31.4 / 28.7 / 27.9 / 18.5 / 19.3 / 18.8% | −1.8 → −4.7 | −12.9 pp: 103 / 232, p < 0.001 |

N = 1,000 per point (Wilson half-widths 0.8–3.1 pp). The adaptive and random arms are identical at every level, as the method asserts: `main` 10.3% and 1.1% fresh, 27.2% and 8.9% full; shipped 14.6% and 1.2%, 30.4% and 10.8%. The shipped curve at 3.0 and at 1.0 reproduces the first screening round's run for run (10,006 of 10,006 rows each).

**The curve does not rise for any way, before or after.** The riders lift every level of every curve (Edge's whole curve by 11–20 pp in the full pool), flatten Shatter's and the Lantern's slopes, and steepen Edge's, because they pay most where the deck still holds its sustain. The curve's axis is the reason. Its factor scales a way's own glass against everything else in the build score while the off-way factor holds the other ways' glass at half, so the purity of the deck barely moves along it: from 1.0 to 3.0, committed Edge's fights in a lit lantern go from 72.7% to 79.0% and Shatter's from 45.1% to 53.6%, while every committed arm gives up Regrowth (−0.3 to −0.7 a deck), Iron Skin, Deflect, Blood Rite and Agility for more of its own glass (Edge: Dimming Cut +0.9, Splinter Cut +0.4, Honing Edge and Tremor +0.3 each). The curve is reading clear sustain against own glass, and the riders, which pay for purity, do not change that trade. A payoff that made the curve rise would have to make each way's own glass worth more than Regrowth at every count, which is a payoff on quantity rather than on commitment.

**The purity axis.** The question the brief asks, "is insisting rewarded", is about the other ways' glass. The same greedy pilot, the committed arms valuing their own glass as clear glass (commit 1.0) and the other ways' glass ever less: off-way 1.0 (which is arm A), 0.5, 0.25 and 0.1, V0, 1,000 paired seeds.

| Cell | Way | `main`: off-way 1.0 / 0.5 / 0.25 / 0.1 | 1.0 to 0.1 | Shipped: off-way 1.0 / 0.5 / 0.25 / 0.1 | 1.0 to 0.1 |
|---|---|---|---|---|---|
| fresh | Shatter | 10.3 / 4.4 / 4.2 / 3.8% | −6.5 pp: 33 / 98, p < 0.001 | 14.6 / 11.0 / 12.9 / 12.0% | −2.6 pp: 97 / 123, p = 0.09 |
| fresh | Lantern | 10.3 / 14.8 / 21.7 / 19.0% | +8.7 pp: 164 / 77, p < 0.001 | 14.6 / 20.3 / 27.5 / 21.2% | +6.6 pp: 178 / 112, p < 0.001 |
| fresh | Edge | 10.3 / 2.0 / 2.4 / 2.6% | −7.7 pp: 23 / 100, p < 0.001 | 14.6 / 11.0 / 16.7 / 17.1% | +2.5 pp: 140 / 115, p = 0.13 |
| full | Shatter | 27.2 / 27.5 / 29.2 / 29.2% | +2.0 pp: 202 / 182, p = 0.33 | 30.4 / 37.6 / 44.7 / 47.3% | **+16.9 pp: 319 / 150, p < 0.001** |
| full | Lantern | 27.2 / 35.5 / 37.8 / 34.1% | +6.9 pp: 233 / 164, p = 0.001 | 30.4 / 38.2 / 41.2 / 39.3% | +8.9 pp: 261 / 172, p < 0.001 |
| full | Edge | 27.2 / 13.2 / 12.4 / 12.4% | **−14.8 pp: 76 / 224, p < 0.001** | 30.4 / 31.4 / 30.4 / 30.7% | +0.3 pp: 191 / 188, p = 0.92 |

On `main`, keeping a deck pure cost Edge 7.7 pp (fresh) and 14.8 pp (full) and Shatter 6.5 pp in the fresh pool: the flame punished insisting on its two thinner ways. Shipped, purity pays the Lantern in both pools and Shatter by 16.9 pp in the full pool, and no longer costs Edge or fresh Shatter anything measurable. That is the brief's "insisting is rewarded" on the axis the flame reads, with the greedy pilot; for Edge it is "no longer punished", not yet "rewarded".

**Search check.** Because the greedy pilot reads the Lantern best and Edge worst, the shipped catalogue's committed arms were also run with the search player at commit 1.0 (off-way 0.5) on 13000–13399 (before the content commit, same code). Against the shipped table at 3.0 on the same 400 seeds: Edge +15.0 pp at 1.0 at V0 full (116 / 56, p < 0.001), the Lantern +5.8 pp (p = 0.06), Shatter +2.8 pp (p = 0.37); fresh within 4 pp either way (p ≥ 0.13). The stronger player agrees with the greedy one: the commit factor's upper range costs the arms their clear sustain glass.

## Copy

| Way | en | zh-Hant | Cards |
|---|---|---|---|
| Shatter | Frost-white flame: chip 1 more Facet. | 霜白之火：再琢擊 1 格璃面。 | Chisel 璃鑿, Spall 璃屑, Quakeblow 震地擊 |
| Lantern | Amber flame: gain 1 Ember. | 金黃之火：獲得 1 點餘燼。 | Tinder 火絨, Struck Match 燃火柴, Hearthfall 爐火墜, Tithe of Panes 璃片什一 |
| Edge | Blood-moon flame: gain 3 Ward. | 血月之火：獲得 3 點護光。 | Eclipse Slash 蝕月斬, Splinter Cut 裂痕斬, Dim the Glass 暗琉, Shatterhymn 碎裂聖詠 |

The rider follows the card's own text on the card and on its upgrade, after "Kindle." where the card kindles. Glossary terms only (璃面, 琢擊, 餘燼, 護光); the colour words are the codex's. No card art changes.

## Tests and pins

- `tests/test_lit_riders.gd` (new): the lit way follows the deck as the fight begins (none at Kindling or Soot, the way at Steady or True); every `lit` effect in the catalogue is one of the eleven shipped riders, on the card and on its upgrade, on the way's own glass; each rider, played in its own colour, in another way's colour and in none, adds exactly its Ward, chip or Ember in its own colour and nothing anywhere else; the preview counts a lit Ward only in its colour; `ContentDB.validate` rejects a rider lit by no way; both catalogues carry the flame's words; the search player's copy of a fight keeps the lit way.
- Pins moved only for this content, each in its own commit: `tests/test_balance_catalogue.gd` (the live file and semantic SHA-256 of `content/full-content.json`) and `tests/test_balance_sim.gd` (the seed-1000 digest and its every-knob-at-zero digest: the run is the same deck and the same loss in fight 8, but it fights six of its eight fights in a blood-moon lantern and holds Eclipse Slash and Shatterhymn, whose Ward changes its HP). `test_balance_pilot_play`, `test_i2_combat_chrome_locale`, the locale hydration censuses and every other test pass unchanged: no locale leaf is added. No `port_fixtures/` golden changes: the slice catalogue carries no rider.

## What the reading suggests

For the orchestrator; nothing here was turned.

1. **G3 and the brief now pull apart.** The brief asks that insisting be rewarded; G3's lower bound asks that the commit-blind adaptive bot lose no more than 3 pp to the best committed way. With a payoff only committed decks collect, the second cannot hold unless the adaptive bot also reads its flame. Either G3's lower bound is re-read as "the adaptive arm is not punished" (it is not: +1.7 and +1.8 pp, unmoved), or the adaptive arm gains a rule that follows its flame once lit, which would be a new instrument, not a balance change.
2. **The commitment curve measures the wrong axis for this question.** Its commit factor trades a way's glass against clear glass; the lock's commitment, and the flame, are about the other ways' glass. The pilot's committed arm at 3.0 already sits on the falling side of the own-versus-clear trade for every way, at both players' strength. If the curve is to stay a target, the purity sweep above is the reading that answers "is insisting rewarded"; and the committed arm's 3.0 could be re-examined, since 1.0/0.5 wins more for every way in the full pool, with both players.
3. **Edge is carried; it is not yet level at V5.** Committed Edge clears both B1 floors with 17 and 11 pp to spare at V0, but at V5 it is the weakest way in the full pool (9.7%). Its Act-2 deaths fell by a third in the full pool, not at all in the fresh pool, and remain its largest.
4. **B2 is a feel question again.** Shatter's close calls joined the Lantern's on the 1% floor; the riders make committed decks safer. James's play reports are the input here.
5. **G4 is still far.** The random build sits 18.9 pp under the worst committed way at V0 full, against the lock's 25 pp. Its 18.4% is unchanged: the riders took nothing from scattered decks, they gave to committed ones. Closing the rest is the Soot tier's job (§5), which this lane did not touch.

## Appendix A: the candidate catalogues

`make_candidates.py` (private scratch folder) appends one effect to a card and to its upgrade, and one sentence to its English text; every candidate is built from the shipped file at `d5b1eed2`.

| Candidate | Riders | Catalogue SHA-256 |
|---|---|---|
| S1 + L1 + E3 (shipped) | Shatter chip +1: chisel, spall, quakeblow. Lantern Ember +1: preparation, surge, hearthfall, tithe. Edge Ward +3: eclipseSlash, splinterCut, dimTheGlass, warCry | `0faf9a96462e168fd506255bc3b04a3174f8b357e3f3e09e3cb60ccac5def771` |
| S1 + L1 + E5 | as above, Edge Ward +3 also on lunge, empower, totality | `84ab436f03c10be79080e66b08115856cdc3f060eac9edfba99c7febfaaff13d` |
| S1 + L1 + E6 | as E5 at Ward +2 | `329c55e4a9a5660fdf639f8ccd67c9f6120db59ef26cf16b0d8e62ea7efbb181` |

## Appendix B: the chunked runner

`chunked.py` (private scratch folder) builds each job with the grader's own `sim_command`, splits the seed range into 50-seed chunks so ten processes stay busy, and merges each cell and arm's chunks into one report in seed order with one manifest (it refuses chunks whose manifests differ in anything but their seed range). The merged directories grade with `balance_ways.py --from-dir` unchanged. The first screening round straddled the code commit (its chunks name the base and the code commit) and was merged with that difference allowed; its catalogue, re-run at the content commit as the shipped table, reproduced it run for run.

## Appendix C: the commitment-curve sweep

`curve.sh` runs `balance_ways.py --seeds 13000-13999 --vows 0 --jobs 10 --way-weights C/0.5` for C in 3.0, 1.0, 1.5, 2.0, 5.0 and 8.0, and `--way-weights 1.0/1.0`; `purity.sh` runs `--way-weights 1.0/0.25` and `1.0/0.1`; `analyse_curve.py` is the 30 September `analyse.py` generalised to several sweeps and 1,000 seeds.
