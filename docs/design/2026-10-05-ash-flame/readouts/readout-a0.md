# Readout A0: the Ashwarden's commit-blind baseline and its tagging screens

> **Research (AI-SDLC discovery), not a reading of record and not a balance change.** #544's plan of record, step A0. Every figure here is on development seeds or is a screen; none enters a verdict. No repository content moved: the catalogues are scratch copies of `content/full-content.json` (SHA-256 `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`) passed with `--content`, and the Ashwarden's way stats were added to `tools/balance_classes.json` in the scratch worktree only.
>
> **Heads.** Every report ran in one detached worktree with an isolated user directory (`override.cfg`: `config/use_custom_user_dir=true`, `config/custom_user_dir_name="glassvow-ash-a0"`, never committed), and every manifest names its commit. The greedy screens ran at `ad297334` (#690, #544 P6). The search player's screen and baseline ran at `3dcbe37b6f1f405dafbf05cbea3ed35ec6943768`, #690's branch after its two review fixes to `s2`: it credits a hand-size payoff only for a card held before the draw (at `ad297334` it credited one the line had only just drawn, a look at an undrawn card), and the draw's credit shares the Energy left. Between the two heads pilot `p9` changed by one comment line, so the greedy screens stand; no search-player row from `ad297334` is used here.

## The answer in brief

- **No candidate tagging fixes the Ashwarden's two walls, because neither is a tagging problem.** On 400 development seeds a cell, under the greedy pilot:
  - **Smolder starves in the entry pool.** It has one card there, Emberbite, so a committed Smolder deck reaches Steady by the end of Act 1 in 13–20% of the runs alive then and wins 12–15% at V0. In the full pool it has six cards and wins 42–43%.
  - **Endure is too strong, not too weak.** The committed Endure deck is the strongest arm in every cell of every candidate: 66–90% at V0 and 43–77% at V5. It has no kill condition of its own: it builds a wall of Ward (Anneal, Vitrify, Cathedral Glass, Mirrorlight) while the class's starter Smolder (four Ash Bites, Ashen Core, Ashfall) does the killing.
- **The exclusions of decision 9 alone lift the commit-blind arm hard in the entry pool**: arm A at V0 from 10.0% to 42.8% (155 seeds gained, 24 lost), chiefly because the pilot no longer builds Bellstrike, a Shatter card whose chips are dead for the Ashwarden, into its decks (2.5 copies a run). The lantern's quality then costs a scattered deck most of that back (28.2% with the preferred tagging).
- **The preferred candidate is `duos`**: plain draw is the Hand's verb, so Flicker is Hand glass and Glasstep and Refract, the Ward cards that draw, are Hand/Endure duos; Glazier's Poise is clear. Of the three it alone leaves no decided G6 failure at V0 in either pool, and it narrows the committed spread most (65.0 pp at V0 entry, 24.0 pp at V0 full, against 73–78 and 25–37). It meets the template's supply target for Hand and Endure in the entry pool, gives the Hand/Endure pair a duo in that pool, and leaves Smolder's supply where content leaves it.
- **The search player confirms both walls and keeps `duos`.** On the same 400 seeds under `s2`/`p9`, every arm wins far more than under the greedy pilot, and the order of the ways holds: committed Endure 93.5% and 85.5% at V0 `entry` and `full`, Hand 86.8% and 74.8%, Smolder 32.8% and 72.8%. In the full pool the spread falls to 12.7 pp (Endure − Smolder, +7.1 to +18.3: FAIL on point, UNDECIDED on interval) and A_lit's wins split Smolder 51%, Hand 35%, Endure 15% (G6 PASS on interval). In the entry pool Smolder still starves (Steady by the end of Act 1 in 13% of the runs alive then), so the spread there is a decided 60.8 pp. G3 fails everywhere: A_lit trails committed Endure by 26–40 pp.
- **The Ashwarden's engine is Smolder, whatever the way.** Under the search player, Smolder makes 61–77% of the kills in the won fights of every arm, the committed Endure deck's most of all (77% at V0 `entry`).
- **The commit-blind baseline on the bands of record** (today's content, no ways, `s2`/`p9`): arm A wins 27.0% and 58.7% at V0 `entry` and `full`, 3.5% and 26.9% at V5. A_lit plays as A, row for row.
- **The cross-class reading: +10.5 pp** (A_lit at V0 full, the Ashwarden 58.7% against the Duskblade's 48.2% on the same 1,000 seeds and instrument; paired 95% +6.1 to +14.8). It is under the +15 pp line, so no diagnosis is triggered. Arm A's gap is wider (+18.2 pp) because the Duskblade's A_lit has a flame to read and the Ashwarden's does not yet.

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
- **Wall time.** Greedy: 914 s for 38,460 runs on six jobs (today's content 55 s, exclusions 126 s, `verbs` 244 s, `draw` 170 s, `duos` 319 s), at a load average of 37 to 346. Search: 9,703 s for 22,824 runs on six jobs (the `duos` screen 3,569 s, the V0 baseline 3,064 s, the V5 baseline 3,070 s), at a load average of 236 to 620 on a host shared with three other lanes. No stall or error in any run; every replay identical (60 greedy and 18 search rows).

The search phase, at `3dcbe37b` in the same worktree (re-imported; the scratch `wayStats` carried over):

```sh
python3 -B tools/balance_readout.py run a0/s-duos --aspect ashwarden --content cands/ash-duos.json \
    --seeds 12000-12399 --cells v0-entry,v0-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run a0/base-v0 --aspect ashwarden --seeds 13000-13999 \
    --cells v0-entry,v0-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 -B tools/balance_readout.py run a0/base-v5 --aspect ashwarden --seeds 13000-14999 \
    --cells v5-entry,v5-full --play search --pilot p9 --search s2 --replay --jobs 6
python3 compare.py                                   # the search screen against the greedy one
python3 baseline.py a0/base-v0 a0/base-v5 p6/runs2/s2-v0   # the baseline and the cross-class reading
```

The Duskblade's side of the cross-class reading is #544 P6's re-run of readout 14 at the same commit (`p6/runs2/s2-v0`, `v0-full-A_lit.json`, 13000–13999), whose manifests name `3dcbe37b`, pilot `p9` and search `s2`; `baseline.py` refuses a pair whose commits or bots differ.

### The scratch catalogues

Each follows #544 decisions 1, 2, 8 and 9 and changes only the Ashwarden's row (`aspects[1]`); the writer asserts the Duskblade's row and every other key of the catalogue equal to today's.

| | `verbs` | `draw` | `duos` | Exclusions only |
|---|---|---|---|---|
| SHA-256 | `57718c08…` | `f8e76958…` | `4ff463d1…` | `e3245b66…` |
| Ways, flame, soot crown | yes | yes | yes | no |
| Exclusions of decision 9 | yes | yes | yes | yes |
| Flicker (quickSlash) | clear | Hand | Hand | — |
| Glasstep (sidestep), Refract (deflect) | clear | Hand | ½ Hand, ½ Endure | — |

Common to the three candidates: the ways in content order `smolder`, `hand`, `endure`; Smother ½ Smolder ½ Endure, First Spark Hand, Ash Bite clear; Smolder venomStrike, toxicMist, annihilate, catalyst, virulence, ashenChoir; Hand firstSpark, preparation, surge, phantomBlades, offering, tithe, nightSight, emberdance ½; Endure bulwark, fortify, ironSkin, bastion, aegis, regrowth, flawlessForm, leechBlade, devour, emberdance ½; Glazier's Poise (agility) clear in all three, by readout 11's rule for stat powers. Crowns crownOfCinders (Smolder), crownOfTithes (Hand), crownOfTheHearth (Endure); soot crown hollowCrown; capstones catalyst and virulence, phantomBlades and offering, bastion and flawlessForm; relic affinities as the lock's §6.1. Flame and lantern values: the Duskblade's shipped ones. Exclusions added: cards uppercut, quakeblow, oblivionStrike, limitBreak, resonantLance; relics shatterersCrown, bellOfEndings, prismCharm; Art beacon. The diff of `duos` against `content/full-content.json` is the lock's §6.1 and §6.3 as written, inserted after the Ashwarden's blurb, plus the three `excludes` lists.

## The commit-blind baseline

### On the bands of record, search player

Today's content (no ways, no exclusions), `s2`/`p9` at `3dcbe37b`, with Wilson 95% intervals. A_lit equals A in every row but the policy snapshot it records (the class declares no ways, so the lit lean never fires).

| Cell | Seeds | A (= A_lit) | R | A's deaths, Acts 1 / 2 / 3 | Stalls, errors |
|---|---|---|---|---|---|
| V0 entry | 13000–13999 | 27.0% (24.3–29.8) | 7.1% (5.7–8.9) | 63 / 365 / 302 | 0 |
| V0 full | 13000–13999 | 58.7% (55.6–61.7) | 24.2% (21.6–27.0) | 34 / 201 / 178 | 0 |
| V5 entry | 13000–14999 | 3.5% (2.7–4.3) | 0.2% (0.1–0.5) | 1,044 / 720 / 167 | 0 |
| V5 full | 13000–14999 | 26.9% (25.0–28.9) | 5.6% (4.7–6.7) | 517 / 699 / 246 | 0 |

The Ashwarden dies in Acts 2 and 3 at V0; the Duskblade's A_lit at V0 full dies most in Act 1 (207 / 148 / 163 deaths, against the Ashwarden's 34 / 201 / 178).

### The cross-class reading

A_lit at V0 full on 13000–13999, both classes under `s2`/`p9` at `3dcbe37b`, paired on seed (Newcombe's paired 95% interval):

| | Ashwarden | Duskblade | Gap | Paired 95% | Seeds: both win / Ashwarden only / Duskblade only / neither |
|---|---|---|---|---|---|
| A_lit | 58.7% (55.6–61.7) | 48.2% (45.1–51.3) | **+10.5 pp** | +6.1 to +14.8 | 279 / 308 / 203 / 210 |
| A | 58.7% | 40.5% (37.5–43.6) | +18.2 pp | +13.8 to +22.5 | |
| R | 24.2% (21.6–27.0) | 18.2% (15.9–20.7) | +6.0 pp | +2.5 to +9.5 | |

The graded reading is A_lit's: +10.5 pp, under the +15 pp line, so no diagnosis is required (#544 decision 5). Two cautions:

- **The interval's top end (+14.8) sits just under the line.** The reading is on today's content: no ways, no lantern, and none of decision 9's exclusions, which lift the greedy arm A at V0 full by 6.2 pp on development seeds (*The exclusions alone*, below). Step A2's reading of record will carry all three, so the gap must be read again there.
- **Arm A's gap (+18.2 pp) is not the graded figure**: the Duskblade's A_lit gains 7.7 pp over its A by reading a flame, and the Ashwarden has no flame to read yet.

### Development seeds, greedy pilot (sanity reference)

| Cell | A (= A_lit) | R | A's deaths, Acts 1 / 2 / 3 |
|---|---|---|---|
| V0 entry | 10.0% (7.4–13.3) | 0.2% (0.0–1.4) | 84 / 180 / 96 |
| V0 full | 31.8% (27.4–36.5) | 4.2% (2.7–6.7) | 56 / 156 / 61 |
| V5 entry | 0.8% (0.3–2.2) | 0.0% (0.0–1.0) | 291 / 93 / 13 |
| V5 full | 8.0% (5.7–11.1) | 0.8% (0.3–2.2) | 202 / 141 / 25 |

For scale, the search player's arm A on the bands of record (above) wins 27.0% and 58.7% at V0.

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

## The screens

### Greedy pilot, development seeds

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

### The search player's screen of `duos`

`s2`/`p9` at `3dcbe37b`, the same 400 seeds (12000–12399), V0 only (the screen's budget). Greedy → search per arm, with reach over survivors and the search player's deaths by act and feel:

| Cell | Arm | Greedy | Search | Steady by end of Act 1, of alive (greedy → search) | True by end of Act 2, of alive | Deaths A1 / A2 / A3 (search) | Expression / close calls (search) |
|---|---|---|---|---|---|---|---|
| V0 entry | C_smolder | 14.5% (11.4–18.3) | 32.8% (28.3–37.5) | 13 → 13% (of 372) | 1 → 0% (of 254) | 28 / 118 / 123 | 60.9% / 3.6% |
| V0 entry | C_hand | 59.2% (54.4–64.0) | 86.8% (83.1–89.7) | 89 → 81% (of 387) | 62 → 58% (of 381) | 13 / 6 / 34 | 86.5% / 1.3% |
| V0 entry | C_endure | 79.5% (75.3–83.2) | 93.5% (90.6–95.5) | 89 → 85% (of 392) | 61 → 54% (of 379) | 8 / 13 / 5 | 59.0% / 0.5% |
| V0 entry | A | 28.2% (24.1–32.9) | 49.8% (44.9–54.6) | - | - | 28 / 111 / 62 | 50.4% / 2.8% |
| V0 entry | A_lit | 36.8% (32.2–41.6) | 53.2% (48.4–58.1) | - | - | 24 / 102 / 61 | 55.7% / 2.7% |
| V0 entry | R | 5.8% (3.9–8.5) | 28.7% (24.5–33.4) | - | - | 87 / 135 / 63 | 57.7% / 2.8% |
| V0 full | C_smolder | 42.2% (37.5–47.1) | 72.8% (68.2–76.9) | 78 → 74% (of 389) | 70 → 70% (of 354) | 11 / 35 / 63 | 80.9% / 2.9% |
| V0 full | C_hand | 47.5% (42.7–52.4) | 74.8% (70.3–78.8) | 73 → 73% (of 384) | 38 → 39% (of 366) | 16 / 18 / 67 | 83.5% / 2.5% |
| V0 full | C_endure | 66.2% (61.5–70.7) | 85.5% (81.7–88.6) | 58 → 54% (of 386) | 23 → 20% (of 355) | 14 / 31 / 13 | 64.6% / 0.8% |
| V0 full | A | 29.5% (25.2–34.1) | 51.7% (46.9–56.6) | - | - | 32 / 99 / 62 | 61.0% / 3.9% |
| V0 full | A_lit | 41.0% (36.3–45.9) | 60.0% (55.1–64.7) | - | - | 28 / 81 / 51 | 66.9% / 3.0% |
| V0 full | R | 6.8% (4.7–9.6) | 32.5% (28.1–37.2) | - | - | 44 / 143 / 83 | 53.0% / 4.8% |

The gates as the Duskblade's lock reads them, `entry` in `fresh`'s place (G3 paired on common seeds):

| Gate | V0 entry | V0 full |
|---|---|---|
| G2 (graded) | C_endure − C_smolder +60.8 pp (+55.2 to +65.6): FAIL / FAIL | C_endure − C_smolder +12.7 pp (+7.1 to +18.3): FAIL / UNDECIDED |
| G3 (graded, A_lit; paired) | −40.3 pp (−45.4 to −34.9): FAIL / FAIL | −25.5 pp (−31.2 to −19.6): FAIL / FAIL |
| G3 floor (A; paired) | −43.8 pp: FAIL / FAIL | −33.8 pp: FAIL / FAIL |
| G5 (graded) | C_smolder FAIL (Steady 13% of runs alive, floor 40%); Hand and Endure PASS | C_endure FAIL (Steady 54%, floor 70%; True 20%, floor 40%), C_hand FAIL (True 39%); C_smolder PASS |
| G6 (graded, A_lit) | Smolder 0.5%, Hand 42.7%, Endure 56.8% of 213 wins: PASS on point, UNDECIDED on interval | Smolder 50.8%, Hand 34.6%, Endure 14.6% of 240 wins: PASS / PASS |
| G4 (reading) | R − C_smolder −4.0 pp (−10.3 to +2.4) | R − C_smolder −40.2 pp (−46.3 to −33.7) |
| B1 (graded) | every committed way PASS | every committed way PASS |
| G7 (graded) | 0 stalls, 0 errors; replay 3 / 3 | 0 stalls, 0 errors; replay 3 / 3 |

What the search player changes, way by way:

- **Smolder.** It gains most in the full pool (42.2% → 72.8%), where its six cards and two capstones are on offer; winning decks there hold 5.2 Emberbites, 2.2 Bellows, 1.7 Ashclouds, 1.2 Requiems and 1.2 Emberfangs. In the entry pool it gains (14.5% → 32.8%) but its reach does not move: the same 13% reach Steady by the end of Act 1, because winning decks still hold one kind of Smolder card (5.4 Emberbites). The supply wall is confirmed.
- **Hand.** It gains a great deal in the entry pool (59.2% → 86.8%) and plays its identity: winning decks hold 4.0 Phantom Blades, with 4.2 Tinders, 3.5 Struck Matches and 3.2 Flickers. The committed bot's ×3 brings the rare in through repeated offers and shops; an uncommitted deck meets it less (A_lit's winning decks hold 1.5 at V0 `entry`). Its full-pool True by the end of Act 2 (39%) stays short of G5's 40%.
- **Endure.** It stays the strongest committed way in both pools (93.5% and 85.5%), still on the starter's Smolder: in its won fights Smolder makes 77% of the kills at V0 `entry`, more than in the committed Smolder deck's own (67%). Every one of its 374 winning decks at V0 `entry` holds the Crown of the Hearth. Its full-pool reach is the weakest (True 20%): its glass is spread over more cards.
- **Every arm leans on Smolder.** In won fights Smolder makes 61–77% of the kills for every arm in both pools.
- **R wins far more** (28.7% and 32.5%): the class's starter carries a scattered deck. At V0 `entry` R is within 4.0 pp of committed Smolder (−10.3 to +2.4).

### Each way's gap list (`duos`)

| Way | Supply: entry / full | The wall | Kill condition |
|---|---|---|---|
| Smolder | 1 card (Emberbite), 5.5% of reward slots / 6 cards, 10.4% | Entry: dies in Acts 2–3 (search: 28 / 118 / 123 deaths by act) on one kind of card; it reaches Steady by the end of Act 1 in 13% of the runs alive then under both players and True almost never. Full: it reaches its tiers (74% and 70%) and wins 72.8% | Exists: Smolder itself, with the class's starter behind it |
| Hand | 6 cards (5 units), 21.9% / 10 cards (8.5), 23.1% | Late, in the full pool (search: 16 / 18 / 67), where its producers are diluted and True by the end of Act 2 is 39%; under the greedy pilot it wins 9–10% at V5 (not searched) | Only as a rare: Phantom Blades, under 3% of reward slots in the entry pool. The committed bot finds it (4.0 a winning deck at V0 `entry`); an uncommitted deck seldom does |
| Endure | 8 cards (7 units), 22.4% / 12 cards (10.5), 16.5% | None found: the strongest committed way in every cell under both players (search: 93.5% and 85.5% at V0). Its full-pool reach lags (True 20%) because its glass is spread over more cards | **None of its own.** Winning decks at V0 `entry` (search) hold 4.5 Cathedral Glass, 2.9 Vitrify, 2.7 Anneal, 1.7 Glasswall and 1.6 Mirrorlight, every Ash Bite and both Smothers, and all 374 hold the Crown of the Hearth; Smolder makes 77% of its kills. It wins through the starter's Smolder, which decision 1 does not accept as its kill condition |

## Decision (research)

**Preferred: `duos`.** Reasons, in order:

1. **Identity.** The Hand way is draw and hold (decision 1); its producers are the cards that draw. Flicker draws as it strikes, and Glasstep and Refract draw as they ward, so they are both the Hand's and the Endure's: the template's Hand/Endure duo, in the entry pool.
2. **Diversity.** It alone leaves no decided G6 failure at V0 in either pool. `verbs` puts 74% of A_lit's full-pool wins in Smolder (decided FAIL); `draw` puts 77% of its entry-pool wins in Hand (decided FAIL). At V5 `entry` every candidate fails G6 on Endure, the wall the tagging cannot reach.
3. **Spread.** It narrows the committed spread most: 65.0 pp at V0 entry and 24.0 at V0 full, against 73.0 and 25.2 (`draw`) and 78.0 and 37.2 (`verbs`). It does so by taking Endure down (79.5% against 87.0 and 90.2 at V0 entry), because the committed Endure bot now also takes the weaker Ward-and-draw duos; Smolder does not move.
4. **Scattering.** R stays near `verbs`' figures (5.8% and 6.8% at V0, against 6.0% and 5.8%); `draw` gives R 10.5% and 13.2%, because a random build that takes plain draw lights a Hand flame.

Its cost: A_lit is lowest under `duos` (36.8% and 41.0% at V0). Under the greedy pilot that is inside the G3 failure every candidate shares.

**Under the search player `duos` holds.** Its reasons are the ones the search screen can test, and they stand: no decided G6 failure at V0 (`entry` UNDECIDED, Endure 56.8%; `full` PASS on interval), the full-pool spread down to 12.7 pp (FAIL on point, UNDECIDED on interval), every way passing B1, and the Hand way playing its identity. What fails under the search player fails for reasons the tagging cannot reach: Smolder's entry supply (G2 at `entry`, G5 for C_smolder), Endure's strength (G3 everywhere, A_lit 26–40 pp behind it), and the Hand's and Endure's full-pool True (G5). The other two candidates were screened by the greedy pilot only, as planned; nothing in the search screen gives a reason to re-open them.

**What the screens say the content lane must do** (the lock's §6.7): Smolder needs three or four base-pool cards of its own (step A5a); the Hand needs a payoff below rare (A5b); Endure needs a payoff of its own colour (A5c), since today it wins through the starter's Smolder rather than a kill condition of its own. Greedy figures are no basis for reordering the steps: if a reading of record shows Endure leading G2 by a decided margin, its wall lane comes before any content that strengthens it, and the A5c payoff becomes a trade (the lock's §14).

## What the next reading should ask

1. **Ash readout A1 (step A2).** The cross-class gap with the ways, the lantern and the exclusions in place: today's +10.5 pp (+6.1 to +14.8) is on today's content, and the exclusions alone lift the greedy arm A at V0 full by 6.2 pp.
2. **Endure's lead on the bands of record.** If it holds by a decided margin in G2 there, the lock's lead-way rule (§14) puts its wall lane before step A5c.
3. **R's strength under the search player** (28.7% and 32.5% at V0 on development seeds): G4 is a reading, but its intent (scattering loses) is read from it; the readout of record says how much of it is the starter's Smolder.

## Appendix: the scripts

In the lane's scratch folder, not in the repository:

| Script | What it does |
|---|---|
| `make_cands.py` | Writes the three tagging catalogues and the exclusions-only catalogue as text edits to the Ashwarden's row, and asserts every other key byte-identical |
| `supply.py` | Each way's cards, mass and share of reward slots per pool |
| `screen.py` | Per cell: every arm's win rate, reach over survivors, own dominant at end, deaths by act, own mass, expression and close calls; G2, G3, G4, G5, G6, G1 and B1 as the Duskblade's lock reads them, `entry` in `fresh`'s place |
| `summary.py` | The cross-candidate greedy tables above |
| `search.sh` | Moves the worktree to the fixed head, re-imports, and runs the search screen and the two baselines |
| `compare.py` | The search screen against the greedy one, with the gates (G3 paired on common seeds) |
| `baseline.py` | The baseline table and the paired cross-class reading; refuses a pair whose commits or bots differ |
