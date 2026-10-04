# Readout A0: the Ashwarden's commit-blind baseline and its tagging screens

> **Research (AI-SDLC discovery), not a reading of record and not a balance change.** #544's plan of record, step A0. Every figure here is on development seeds or is a screen; none enters a verdict. No repository content moved: the catalogues are scratch copies of `content/full-content.json` (SHA-256 `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`) passed with `--content`, and the Ashwarden's way stats were added to `tools/balance_classes.json` in the scratch worktree only.
>
> **Head.** Every report ran in a detached worktree at `ad297334` (#690, #544 P6, pilot `p9`), with an isolated user directory (`override.cfg`: `config/use_custom_user_dir=true`, `config/custom_user_dir_name="glassvow-ash-a0"`, never committed), and every manifest names that commit. *Instrument note (5 October 2026):* #690's review found that search player `s2` at `ad297334` credits a hand-size payoff for a card the line has only just drawn, a look at a card not yet drawn. It is being fixed on #690's branch. The greedy pilot plays no search, and pilot `p9` is unchanged by the fix, so this readout's greedy screens stand; its search-player sections are **pending** the fixed head (*Pending*, below).

## The answer in brief

- **No candidate tagging fixes the Ashwarden's two walls, because neither is a tagging problem.** On 400 development seeds a cell, under the greedy pilot:
  - **Smolder starves in the entry pool.** It has one card there, Emberbite, so a committed Smolder deck reaches Steady by the end of Act 1 in 13–20% of the runs alive then and wins 12–15% at V0. In the full pool it has six cards and wins 42–43%.
  - **Endure is too strong, not too weak.** The committed Endure deck is the strongest arm in every cell of every candidate: 66–90% at V0 and 43–77% at V5. It has no kill condition of its own: it builds a wall of Ward (Anneal, Vitrify, Cathedral Glass, Mirrorlight) while the class's starter Smolder (four Ash Bites, Ashen Core, Ashfall) does the killing.
- **The exclusions of decision 9 alone lift the commit-blind arm hard in the entry pool**: arm A at V0 from 10.0% to 42.8% (155 seeds gained, 24 lost), chiefly because the pilot no longer builds Bellstrike, a Shatter card whose chips are dead for the Ashwarden, into its decks (2.5 copies a run). The lantern's quality then costs a scattered deck most of that back (28.2% with the preferred tagging).
- **The preferred candidate is `duos`**: plain draw is the Hand's verb, so Flicker is Hand glass and Glasstep and Refract, the Ward cards that draw, are Hand/Endure duos; Glazier's Poise is clear. Of the three it alone leaves no decided G6 failure at V0 in either pool, and it narrows the committed spread most (65.0 pp at V0 entry, 24.0 pp at V0 full, against 73–78 and 25–37). It meets the template's supply target for Hand and Endure in the entry pool, gives the Hand/Endure pair a duo in that pool, and leaves Smolder's supply where content leaves it.
- **Pending:** the search player's screen of `duos` and the commit-blind baseline on the bands of record with the cross-class reading, under the fixed `s2`.

## The question

1. What does the Ashwarden's commit-blind play read on the bands of record under the 1.1 instrument, and how far does it sit from the Duskblade's on the same seeds (the cross-class reading)?
2. Which tagging of today's content should the lock adopt, and what does each way lack: its supply per pool, where it dies, and whether it has a kill condition?

## The instrument

```sh
# Isolated user directory first: override.cfg in the worktree root (three lines, [application] header).
git worktree add --detach <scratch>/wt-a0 ad297334270d5e6f37c064839a344f9546a13809
godot --headless --import                          # once, 11 s
# Scratch catalogues (Ashwarden row only; the Duskblade's row byte-identical, asserted):
python3 make_cands.py content/full-content.json cands   # verbs, draw, duos; plus the exclusions-only catalogue
# tools/balance_classes.json, scratch only:
#   "ashwarden": {"wayStats": {"smolder": "smolderKills", "hand": "drawn", "endure": "perfects"}}
# Greedy screens, development seeds 12000-12399, every cell, six arms (three for today's content):
python3 -B tools/balance_readout.py run a0/g-base  --aspect ashwarden --seeds 12000-12399 \
    --cells v0-entry,v0-full,v5-entry,v5-full --play greedy --pilot p9 --replay --jobs 6
python3 -B tools/balance_readout.py run a0/g-excl  --aspect ashwarden --content cands/ash-excl.json  ...   # same flags
python3 -B tools/balance_readout.py run a0/g-verbs --aspect ashwarden --content cands/ash-verbs.json ...
python3 -B tools/balance_readout.py run a0/g-draw  --aspect ashwarden --content cands/ash-draw.json  ...
python3 -B tools/balance_readout.py run a0/g-duos  --aspect ashwarden --content cands/ash-duos.json  ...
python3 screen.py a0/g-<name> cands/ash-<name>.json 12000-12399 v0-entry,v0-full,v5-entry,v5-full
python3 summary.py
```

- **Bots.** Greedy play takes no search player, so the screens name `--pilot p9` alone; the runner refuses `--search s2` without `--play search`. Every search run names `--pilot p9 --search s2`.
- **Cells, arms, seeds.** The Ashwarden, V0 and V5, pools `entry` and `full`; C_smolder, C_hand, C_endure, A, A_lit and R on a scratch catalogue, A, A_lit and R on today's content (it declares no ways, so A_lit plays as A, row for row); 400 paired seeds, 12000–12399, with arm A's three-seed replay per cell.
- **Measures.** Win rate with its Wilson 95% interval; each committed way's Steady by the end of Act 1 and True by the end of Act 2 over the runs alive then (G5's denominator); A_lit's wins by the way its flame reads at run end (G6); the committed spread (G2); deaths by act (the wall); own-colour mass at run end; paired changes as seeds gained and lost, with the exact two-sided binomial p. The `entry` pool is read as the Duskblade's lock reads `fresh`.
- **Budget and stop rule.** Three tagging candidates, one exclusions-only diagnostic, greedy first; then one search screen of the preferred candidate on 400 seeds at V0, and the baseline on the bands of record. No candidate re-tuned after its run.
- **Wall time.** 914 s for 38,460 greedy runs on six jobs (today's content 55 s, exclusions 126 s, `verbs` 244 s, `draw` 170 s, `duos` 319 s), on a host shared with other lanes at a load average of 37 to 346. No stall or error; every replay identical (60 rows).

### The scratch catalogues

Each follows #544 decisions 1, 2, 8 and 9 and changes only the Ashwarden's row (`aspects[1]`); a test asserts the Duskblade's row and every other key byte-identical.

| | `verbs` | `draw` | `duos` | Exclusions only |
|---|---|---|---|---|
| SHA-256 | `57718c08…` | `f8e76958…` | `4ff463d1…` | `e3245b66…` |
| Ways, flame, soot crown | yes | yes | yes | no |
| Exclusions of decision 9 | yes | yes | yes | yes |
| Flicker (quickSlash) | clear | Hand | Hand | — |
| Glasstep (sidestep), Refract (deflect) | clear | Hand | ½ Hand, ½ Endure | — |

Common to the three candidates: the ways in content order `smolder`, `hand`, `endure`; Smother ½ Smolder ½ Endure, First Spark Hand, Ash Bite clear; Smolder venomStrike, toxicMist, annihilate, catalyst, virulence, ashenChoir; Hand firstSpark, preparation, surge, phantomBlades, offering, tithe, nightSight, emberdance ½; Endure bulwark, fortify, ironSkin, bastion, aegis, regrowth, flawlessForm, leechBlade, devour, emberdance ½; Glazier's Poise (agility) clear in all three, by readout 11's rule for stat powers. Crowns crownOfCinders (Smolder), crownOfTithes (Hand), crownOfTheHearth (Endure); soot crown hollowCrown; capstones catalyst and virulence, phantomBlades and offering, bastion and flawlessForm; relic affinities as the lock's §6.1. Flame and lantern values: the Duskblade's shipped ones. Exclusions added: cards uppercut, quakeblow, oblivionStrike, limitBreak, resonantLance; relics shatterersCrown, bellOfEndings, prismCharm; Art beacon. The diff of `duos` against `content/full-content.json` is the lock's §6.1 and §6.3 as written, inserted after the Ashwarden's blurb, plus the three `excludes` lists.

## The commit-blind baseline

### On the bands of record, search player: pending

Arms A, A_lit and R, cells V0 (13000–13999) and V5 (13000–14999) × `entry` and `full`, `--play search --pilot p9 --search s2 --replay`, and the cross-class reading against readout 14's Duskblade reports on the same seeds: **pending the fixed `s2`** (*Pending*).

### Development seeds, greedy pilot (sanity reference)

| Cell | A (= A_lit) | R | A's deaths, Acts 1 / 2 / 3 |
|---|---|---|---|
| V0 entry | 10.0% (7.4–13.3) | 0.2% (0.0–1.4) | 84 / 180 / 96 |
| V0 full | 31.8% (27.4–36.5) | 4.2% (2.7–6.7) | 56 / 156 / 61 |
| V5 entry | 0.8% (0.3–2.2) | 0.0% (0.0–1.0) | 291 / 93 / 13 |
| V5 full | 8.0% (5.7–11.1) | 0.8% (0.3–2.2) | 202 / 141 / 25 |

For scale, readout 14's development reading under `s2` at `ad297334` (seeds 12000–12199, stale for the lock) gave arm A 28.5% and 62.0% at V0 `entry` and `full`.

### The exclusions alone

Decision 9's exclusions with no ways, against today's content, paired on seed; the last column adds the ways, the flame and the lantern (`duos`).

| Cell | Arm | Today's content | Exclusions alone | Paired change (gained / lost, exact p) | `duos` |
|---|---|---|---|---|---|
| V0 entry | A | 10.0% (7.4–13.3) | 42.8% (38.0–47.6) | 155 / 24, p < 10⁻²³ | 28.2% (24.1–32.9) |
| V0 entry | R | 0.2% (0.0–1.4) | 1.0% (0.4–2.5) | 4 / 1, p = 0.38 | 5.8% (3.9–8.5) |
| V0 full | A | 31.8% (27.4–36.5) | 38.0% (33.4–42.8) | 93 / 68, p = 0.058 | 29.5% (25.2–34.1) |
| V0 full | R | 4.2% (2.7–6.7) | 11.0% (8.3–14.4) | 39 / 12, p = 0.0002 | 6.8% (4.7–9.6) |
| V5 entry | A | 0.8% (0.3–2.2) | 7.2% (5.1–10.2) | 29 / 3, p < 10⁻⁵ | 11.2% (8.5–14.7) |
| V5 entry | R | 0.0% (0.0–1.0) | 0.2% (0.0–1.4) | 1 / 0, p = 1 | 1.0% (0.4–2.5) |
| V5 full | A | 8.0% (5.7–11.1) | 14.0% (10.9–17.7) | 45 / 21, p = 0.004 | 9.0% (6.6–12.2) |
| V5 full | R | 0.8% (0.3–2.2) | 2.2% (1.2–4.2) | 9 / 3, p = 0.15 | 1.5% (0.7–3.2) |

- **Why the entry pool moves most.** On today's content the pilot builds 2.5 Bellstrikes a run into arm A's deck at V0 `entry` (0.66 in the full pool): a cost-3 attack whose two chips are dead for the Ashwarden, valued by a pilot weight fitted before the Flame. With it and Ringing Blow gone, the entry pool's three rares are Phantom Blades, Cathedral Glass and Anneal. No Shatterer's Crown, Bell of Endings or Prism Charm was held in the entry pool; in the full pool Bell of Endings and Prism Charm were held in 58 and 54 runs.
- **What the flame does to the commit-blind arm.** Once the ways exist, a commit-blind deck burns Soot at run end in 57% of runs at V0 `entry` (65% in the full pool) and pays the Soot leak and the dearer Art: arm A falls from 42.8% to 28.2%, and from 38.0% to 29.5%. That is the design: scattering costs.
- **For the cross-class reading.** Whatever the search player's baseline reads, step A2's content carries these exclusions, so the Ashwarden's first reading of record starts from a stronger entry pool than today's.

## The screens (greedy pilot, development seeds)

Win rate with its Wilson 95% interval, 400 seeds an arm and cell:

| Candidate | Cell | C_smolder | C_hand | C_endure | A | A_lit | R |
|---|---|---|---|---|---|---|---|
| verbs | V0 entry | 12.2 (9.4–15.8) | 56.5 (51.6–61.3) | 90.2 (86.9–92.8) | 24.5 (20.5–28.9) | 39.0 (34.3–43.9) | 6.0 (4.1–8.8) |
| verbs | V0 full | 42.5 (37.7–47.4) | 36.2 (31.7–41.1) | 73.5 (69.0–77.6) | 36.8 (32.2–41.6) | 48.8 (43.9–53.6) | 5.8 (3.9–8.5) |
| verbs | V5 entry | 2.0 (1.0–3.9) | 8.2 (5.9–11.4) | 76.5 (72.1–80.4) | 12.8 (9.8–16.4) | 26.8 (22.6–31.3) | 1.0 (0.4–2.5) |
| verbs | V5 full | 13.2 (10.3–16.9) | 6.8 (4.7–9.6) | 56.8 (51.9–61.5) | 14.2 (11.2–18.0) | 24.8 (20.8–29.2) | 1.2 (0.5–2.9) |
| draw | V0 entry | 14.0 (10.9–17.7) | 69.0 (64.3–73.3) | 87.0 (83.3–89.9) | 29.2 (25.0–33.9) | 47.5 (42.7–52.4) | 10.5 (7.9–13.9) |
| draw | V0 full | 42.8 (38.0–47.6) | 55.5 (50.6–60.3) | 68.0 (63.3–72.4) | 33.2 (28.8–38.0) | 49.0 (44.1–53.9) | 13.2 (10.3–16.9) |
| draw | V5 entry | 3.5 (2.1–5.8) | 15.8 (12.5–19.6) | 71.2 (66.6–75.5) | 8.5 (6.1–11.6) | 20.5 (16.8–24.7) | 0.8 (0.3–2.2) |
| draw | V5 full | 16.0 (12.7–19.9) | 17.8 (14.3–21.8) | 50.2 (45.4–55.1) | 9.5 (7.0–12.8) | 23.0 (19.1–27.4) | 2.2 (1.2–4.2) |
| **duos** | V0 entry | 14.5 (11.4–18.3) | 59.2 (54.4–64.0) | 79.5 (75.3–83.2) | 28.2 (24.1–32.9) | 36.8 (32.2–41.6) | 5.8 (3.9–8.5) |
| **duos** | V0 full | 42.2 (37.5–47.1) | 47.5 (42.7–52.4) | 66.2 (61.5–70.7) | 29.5 (25.2–34.1) | 41.0 (36.3–45.9) | 6.8 (4.7–9.6) |
| **duos** | V5 entry | 2.0 (1.0–3.9) | 9.8 (7.2–13.1) | 68.8 (64.0–73.1) | 11.2 (8.5–14.7) | 23.5 (19.6–27.9) | 1.0 (0.4–2.5) |
| **duos** | V5 full | 15.5 (12.3–19.4) | 9.2 (6.8–12.5) | 42.8 (38.0–47.6) | 9.0 (6.6–12.2) | 20.8 (17.1–25.0) | 1.5 (0.7–3.2) |

Reach (G5, over the runs alive at the act's end), A_lit's wins by way (G6), the committed spread (G2):

| Candidate | Cell | Steady by end of Act 1 (S / H / E) | True by end of Act 2 (S / H / E) | A_lit's wins (S / H / E) | G2 spread | G6 on interval |
|---|---|---|---|---|---|---|
| verbs | V0 entry | 20 / 85 / 95% | 1 / 78 / 92% | 5 / 31 / 64% of 156 | 78.0 pp (Endure − Smolder) | UNDECIDED |
| verbs | V0 full | 78 / 66 / 72% | 83 / 55 / 62% | 74 / 9 / 17% of 195 | 37.2 pp (Endure − Hand) | FAIL |
| verbs | V5 entry | 14 / 93 / 99% | 0 / 78 / 99% | 0 / 13 / 87% of 107 | 74.5 pp | FAIL |
| verbs | V5 full | 87 / 75 / 83% | 88 / 49 / 72% | 72 / 6 / 22% of 99 | 50.0 pp | FAIL |
| draw | V0 entry | 13 / 97 / 92% | 1 / 96 / 77% | 1 / 77 / 22% of 190 | 73.0 pp | FAIL |
| draw | V0 full | 79 / 95 / 63% | 71 / 90 / 43% | 40 / 52 / 9% of 196 | 25.2 pp | PASS |
| draw | V5 entry | 7 / 98 / 97% | 0 / 95 / 93% | 0 / 29 / 71% of 82 | 67.8 pp | FAIL |
| draw | V5 full | 89 / 94 / 82% | 77 / 80 / 58% | 55 / 35 / 10% of 92 | 34.2 pp | UNDECIDED |
| **duos** | V0 entry | 13 / 89 / 89% | 1 / 62 / 61% | 1 / 46 / 53% of 147 | 65.0 pp (Endure − Smolder) | UNDECIDED |
| **duos** | V0 full | 78 / 73 / 58% | 70 / 38 / 23% | 54 / 34 / 12% of 164 | 24.0 pp (Endure − Smolder) | UNDECIDED |
| **duos** | V5 entry | 7 / 95 / 99% | 0 / 71 / 84% | 1 / 12 / 87% of 94 | 66.8 pp | FAIL |
| **duos** | V5 full | 89 / 80 / 73% | 76 / 50 / 42% | 66 / 13 / 20% of 83 | 33.5 pp (Endure − Hand) | UNDECIDED |

G3 fails on point and interval in every cell of every candidate (A_lit 19–51 pp behind committed Endure), and G2 fails in every cell: both are Endure's lead, not a tagging effect. G7: no stall or error in 38,460 runs; every replay identical.

### Each way's gap list (`duos`)

| Way | Supply: entry / full | The wall | Kill condition |
|---|---|---|---|
| Smolder | 1 card (Emberbite), 5.5% of reward slots / 6 cards, 10.4% | Entry: dies in Act 2 (V0: 102 / 185 / 55 deaths by act), its deck holding 4.3 units of its own glass at run end; it reaches Steady by the end of Act 1 in 13% of the runs alive then and True almost never. Full: it reaches its tiers (78% and 70%) and wins 42% | Exists: Smolder itself, with the class's starter behind it |
| Hand | 6 cards (5 units), 21.9% / 10 cards (8.5), 23.1% | Late: Acts 2–3 in the full pool (43 / 71 / 96), where its producers are diluted and True by the end of Act 2 falls to 38%; at V5 it wins 9–10% | Only as a rare: Phantom Blades, under 3% of reward slots in the entry pool |
| Endure | 8 cards (7 units), 22.4% / 12 cards (10.5), 16.5% | None found: the strongest arm everywhere (79.5% and 66.2% at V0; 68.8% and 42.8% at V5). In the full pool its tiers lag (Steady 58%, True 23%) because its glass is spread over more cards | **None of its own.** Winning C_endure decks at V0 `entry` hold 4.5 Cathedral Glass, 3.0 Vitrify, 2.7 Anneal, 1.7 Mirrorlight and 1.8 Glasswall a run, with every Ash Bite and both Smothers, and all 318 hold the Crown of the Hearth: they outlast while the starter's Smolder kills |

## Decision (research)

**Preferred: `duos`.** Reasons, in order:

1. **Identity.** The Hand way is draw and hold (decision 1); its producers are the cards that draw. Flicker draws as it strikes, and Glasstep and Refract draw as they ward, so they are both the Hand's and the Endure's: the template's Hand/Endure duo, in the entry pool.
2. **Diversity.** It alone leaves no decided G6 failure at V0 in either pool. `verbs` puts 74% of A_lit's full-pool wins in Smolder (decided FAIL); `draw` puts 77% of its entry-pool wins in Hand (decided FAIL). At V5 `entry` every candidate fails G6 on Endure, the wall the tagging cannot reach.
3. **Spread.** It narrows the committed spread most: 65.0 pp at V0 entry and 24.0 at V0 full, against 73.0 and 25.2 (`draw`) and 78.0 and 37.2 (`verbs`). It does so by taking Endure down (79.5% against 87.0 and 90.2 at V0 entry), because the committed Endure bot now also takes the weaker Ward-and-draw duos; Smolder does not move.
4. **Scattering.** R stays near `verbs`' figures (5.8% and 6.8% at V0, against 6.0% and 5.8%); `draw` gives R 10.5% and 13.2%, because a random build that takes plain draw lights a Hand flame.

Its cost: A_lit is lowest under `duos` (36.8% and 41.0% at V0). Under the greedy pilot that is inside the G3 failure every candidate shares; the search screen will say whether it holds.

**What the screens say the content lane must do** (the lock's §6.7): Smolder needs three or four base-pool cards of its own (step A5a); the Hand needs a payoff below rare (A5b); Endure needs a payoff of its own colour (A5c), and, if the search screen confirms its lead, Endure's power is the first wall lane (A8).

## Pending

When #690's fixed head is settled, in a detached worktree there (re-imported; the same isolated user directory):

```sh
python3 -B tools/balance_readout.py run a0/s-duos --aspect ashwarden --content cands/ash-duos.json \
    --seeds 12000-12399 --cells v0-entry,v0-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run a0/base-v0 --aspect ashwarden --seeds 13000-13999 \
    --cells v0-entry,v0-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run a0/base-v5 --aspect ashwarden --seeds 13000-14999 \
    --cells v5-entry,v5-full --play search --pilot p9 --search s2 --replay --jobs 6
```

The cross-class reading pairs `base-v0`'s A_lit at V0 full with the Duskblade's A_lit on the same seeds under the same instrument. If the fixed `s2` changes the Duskblade's readout 14 reports, the Duskblade's side is re-read on 13000–13999 for this reading.

## Appendix: the scripts

In the lane's scratch folder, not in the repository:

| Script | What it does |
|---|---|
| `make_cands.py` | Writes the three tagging catalogues and the exclusions-only catalogue as text edits to the Ashwarden's row, and asserts every other key byte-identical |
| `supply.py` | Each way's cards, mass and share of reward slots per pool |
| `screen.py` | Per cell: every arm's win rate, reach over survivors, own dominant at end, deaths by act, own mass, expression and close calls; G2, G3, G4, G5, G6, G1 and B1 as the Duskblade's lock reads them, `entry` in `fresh`'s place |
| `summary.py` | The cross-candidate tables above |
