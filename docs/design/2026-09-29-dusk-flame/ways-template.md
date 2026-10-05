# The Ways of a Class — design template

**Status:** active template, 2026-09-29. Owner: James. Derived from the Duskblade lock in [`README.md`](README.md). Use it for every class: the Ashwarden in 1.1, and any later aspect.

*Brought up to date on 2026-10-04* under [#544](https://github.com/fol2/glassvow/issues/544)'s plan of record (step P4), with what the Duskblade programme learned and what #544 decided: §3. The text of 29 September is kept; where a dated note or §3 differs from it, the note and §3 are current.

A class has three **ways**: three strategic languages a player discovers by playing, never chooses from a menu. The only gauge is the lantern's flame. Power comes from the cards' own synergy, one capstone per way and one crown per way. The flame changes only the lantern's quality, identically for every way, so it can never decide which way wins.

## 1. Content schema

Everything below is content data. No way, colour or threshold lives in code.

```json
{
  "aspects": [
    {
      "id": "<aspect id>",
      "ways": [
        {
          "id": "<way id>",
          "name": "<en name>",
          "nameZh": "<zh-Hant name>",
          "flame": { "colour": "#rrggbb", "shape": "tongues | round | tall" },
          "crown": "<boss relic id>",
          "crownAlts": ["<boss relic id>", "..."],
          "capstones": ["<rare card id>", "..."],
          "deed": "<deed id>",
          "affinity": { "<card id>": 1.0, "<duo card id>": 0.5 },
          "relics": { "<relic id>": 1.0, "<duo relic id>": 0.5 }
        }
      ],
      "flame": {
        "minMass": 5, "steadyMin": 0.60, "trueMin": 0.80,
        "sootMass": 6, "sootMax": 0.45, "fringeMin": 0.25,
        "likeWeight": 1.5, "fringeWeight": 1.2,
        "lantern": {
          "sootLeak": 1, "sootArtCost": 1,
          "steadyCap": 4, "steadyFirstGain": 2, "trueArtCost": 2
        }
      },
      "sootCrown": "<boss relic id>",
      "excludes": { "cards": ["..."], "relics": ["..."] }
    }
  ]
}
```

Rules of the schema:

- Affinity weights are 0.5 or 1.0. A card with two 0.5 entries is a **duo** card and bridges two ways.
- A card absent from every way is **clear glass**: fuel, never noise. Ward, plain draw and plain damage are usually clear.
- `excludes` lists the other classes' language that would be dead glass here. Nothing is deleted from content.
- `flame` constants are per aspect so a class can feel different, but start from the Duskblade values.
- The purity function, tiers, recognition at the boss and like-calls-to-like are the same code for every aspect (`domain/rules/flame.gd`, `rewards.gd`).
- `flame.lantern` is the lantern's quality (lock §5), read from the flame at combat start: Soot loses `sootLeak` Embers at the end of each of the player's turns and adds `sootArtCost` to the Art's price; Steady and True add `steadyCap` to the Ember cap and `steadyFirstGain` to each turn's first Ember gain; True also takes `trueArtCost` off the Art, never below 1. Every knob is a whole number of at least 0, and a missing knob is 0, the plain lantern. The same code serves every aspect (`domain/rules/combat.gd`). *Implementation note (lock PR 4, 2026-09-29): these names replace the per-tier `soot`, `steady` and `true` blocks first sketched here.* *Calibration note (readout 6, 2026-09-30): the example shows Duskblade's shipped values, the ones a new class starts from; the lock's initial Steady and True values were `steadyCap` 2, `steadyFirstGain` 1 and `trueArtCost` 1.*

*Implementation note (2026-10-04): the schema as built differs from the sketch above.*

- *A way's content row carries `id`, `affinity`, `relics`, `crown`, `crownAlts` and `capstones`. Its flame colour and shape are not content: they live in presentation, keyed by way id (`COLOUR` and `WAY_SHAPE` in `presentation/combat/lantern_flame.gd`). So "no colour lives in code" does not hold; ways and thresholds are still content. A way's names, en and zh-Hant, are set in the class's lock through the story skill (#544 decision 1). Deeds are content rows of their own, not a field of the way.*
- *`flame` also carries `kindlingLift` ([readout 5](readouts/readout-5.md); at 1.0 it is no lean). The Duskblade's `trueMin` has been 0.75 since [readout 12](readouts/readout-12.md), not the 0.80 shown.*
- *`excludes` covers `cards`, `relics`, `potions`, `boons`, `arts` and `deeds` (#543). A class that is not yet exposed carries `"deferred": true`.*
- *A per-way `stat`, naming the run stat the way produces, lives in `tools/balance_classes.json` (`wayStats`, #544 P3, #687), not in content, so `content/full-content.json` stays as the 1.0 verdict binds it.*

## 2. Design checklist

Work through it in order. Each step has a stop rule.

1. **Three verbs.** Read the class blurb. It should already name three things the class does. If it names one, the class is not ready for ways; write the blurb first. Duskblade: strikes, shatters, fuel.
2. **Seeds in the starter deck.** The starter deck carries exactly one card of each way. Everything else in it is clear glass. If a way has no seed, add one and remove a Strike. *Note (2026-10-04):* what counts is one seed's affinity per way, so the start reads one third per way. Two duo cards between two ways meet it: the Ashwarden's two Smothers, a Smolder/Endure duo, beside First Spark (#544 decision 2).
3. **Affinity table.** Tag every card in the class's reachable pool: 1.0, 0.5 or clear. Count coloured cards per way under a **fresh** pool (no deeds, no waves) and a **full** pool. Target: four to five fresh, about ten full, per way. *(2026-10-04: a class that unlocks later counts its `entry` pool in place of `fresh`; §3.)*
4. **Exclusions.** List the other classes' dead glass for this class.
5. **Crowns and capstones.** One boss crown per way, one soot crown for the class, at least one rare capstone per way, and at least one duo card for each pair of ways. Where one is missing, that is the content lane's list.
6. **Deeds.** One deed per way, driven by a stat the way produces, unlocking that way's depth. Add the stat to `run.stats` if it does not exist.
7. **Flame.** Three colours and three shapes, distinct at a glance and under colour-blindness. A soot look for the class.
8. **Lines.** Six lines: the lighting line, first Steady, first True, first Soot, the Vigil whisper after a Soot death, first fringe. In the class's register. No mechanic words. Three codex sentences, one per colour, revealed after first Steady in that colour.
9. **Readout.** Committed arms for each way plus adaptive plus random, both pool states, both gated vows, paired seeds. Gates G1–G7 and the human round H as in the Duskblade lock §11. Calibrate lantern knobs in the lock's order. *Superseded in part:* the bot round B replaced H on 2026-10-01; G1 and G4 became readings, and global calibration closed, on 2026-09-30, so a class starts from the Duskblade's shipped knobs and moves only through wall lanes; the arms gained A_lit with [readout 10](readouts/readout-10.md). §3 has the whole contract.
10. **Fallback.** If a third way cannot reach G1 and G2 within the time box, ship two clear ways and let the third be a fringe. Say so in the release notes to yourself, not to the player. *Amended 2026-10-04:* G1 is a reading, so the test is row B's first part (B1: the committed way wins at V0 with the search player) and G2. #544 gives each Ashwarden way at most two wall lanes to reach them (decision 13). The Duskblade never took this fallback: its three ways were accepted on 2 October 2026 (lock §11, *Verdict*).

## 3. What a class inherits (2026-10-04)

The Duskblade programme ran thirteen readouts between 29 September and 2 October 2026 and ended in an ACCEPT (lock §11, *Verdict*). These rules come from it and from #544's plan of record (4 October 2026). They bind every class from its first readout. A rule decided but not yet built says so.

**The instrument comes first.**

- **Bots that can play the class.** A class's ways must be playable by the bots before any reading of it counts. If the search player cannot play a way's verbs, the bots learn them first, with probe tests (#544 decision 4). For the Ashwarden that is the Hand way's draw and hold: search player `s2` and pilot `p9` (#544 P6, [readout 14](readouts/readout-14.md)), named on every run with `--pilot p9 --search s2`; the tools' default stays 1.0's `p8-d0-v3` and `s1`. A new instrument re-reads the classes already shipped: under `s2` the Duskblade is requalified for 1.1, and readout 13 stays 1.0's reading of record.
- **The committed bot** ([readout 13](readouts/readout-13.md), pilot `p8-d0-v3`). A committed arm removes its off-colour starter seeds first whenever a removal is offered. Its ×`commit` (3.0) covers two copies of a card; a further copy is weighed as clear glass. Other coloured glass weighs ×0.5. Readouts 1–12 used an earlier bot that kept its seeds and tripled every copy.
- **The arms.** `C_<way>` for each way, A, A_lit and R, on common seeds. G3 and G6 are read against A_lit, and B2 reads A_lit's feel beside the committed arms' ([readout 10](readouts/readout-10.md)); A stays in the table as the commit-blind floor.
- **G5 over survivors and G3 paired, in the tool from the start.** G5 counts the runs alive at the act's end, with the all-runs figure beside it (orchestrator ruling, 2 October 2026). G3 is graded paired on common seeds. A class's tool grades both this way from its first readout (#544 decision 5). G5 over survivors is in `tools/balance_ways.py`; the paired G3 grader comes with the readout runner (#544 P2, #684). The tools read the class's ways from content since #544 P3 (#687).

**The gates and the verdict.**

- **Row B replaces H** (owner ruling, 1 October 2026). The search player plays the cell table, at least 200 paired seeds a cell, every figure on its 95% interval. B1: every committed way wins at V0 (at least 20% in the full pool, 10% in the fresh pool, or in the `entry` pool of a class that unlocks later). B2: every way has a feel. James's play reports are input, never a gate.
- **G1 and G4 are readings** (owner ruling, 30 September 2026: "it is okay to be hard, this is roguelike"). They are reported in every graded cell with their intervals. Their thresholds never decide the verdict, but the verdict still reads their intent: each way wins; scattering loses. G2, G3, G5, G6, G7 and B are graded ([`docs/rc-bar.md`](../../rc-bar.md) P9).
- **Thresholds** start at the Duskblade's, with the lock's amendments, and freeze after the class's first readout (#544 decision 5). The gap between classes (the new class's A_lit minus the Duskblade's, V0 full) is reported, not gated; above +15 pp it triggers a diagnosis.
- **The verdict** (owner ruling, 2 October 2026; `docs/rc-bar.md` P9). Each class gets one verdict, ACCEPT or NOT ACCEPTED, on whether the design's intent holds: the three ways are viable and comparable; commitment is rewarded and reading the offers is not a trap; scattering loses; the tiers are reachable; adaptive play is diverse; every way can be won and has a feel; nothing is degenerate. The gate figures are its evidence; it is not a count of passes. It is given on one reading of record: a readout's complete §11 table, its content SHA-256 and its instrument. For every graded-gate figure short of its threshold it states why the gate's intent still holds or names a reservation that carries it; a reservation states its figures and the readout that will answer it. A G7 miss is always NOT ACCEPTED. The class's lock §11 records the verdict as it happened, and P9 binds it. The Duskblade's is the worked example.

**How a class lands.**

- **Inert at zero, byte for byte.** A new rule lands with its knobs at zero, or its content absent, and replays the game it joins byte for byte before any knob turns. The lantern's quality at zero reproduced readout 4a's tables byte for byte in [readout 3](readouts/readout-3.md). A new class lands on `main` dormant behind `"deferred": true`, and every id only it uses enters the other classes' `excludes` in the same commit, so their draws and RNG streams stay byte-identical (#544 decision 6). The invariance test that proves it for the Duskblade is `tests/test_balance_invariance.gd` (#544 P3, #687).
- **Global calibration is closed** (owner ruling, 30 September 2026). No class moves global knobs, enemy numbers or shared scalars to pass a gate. A class starts from the Duskblade's shipped flame and lantern values (#544 decision 8) and moves only through its ways' wall lanes.
- **At most three candidates per way per wall lane** (30 September 2026, [readout 7](readouts/readout-7.md); carried by #544). A wall lane diagnoses first, measures at most three single-lever candidates per way that follow from the diagnosis, and ships the measured ones or drops them. No candidate is re-tuned after its run.
- **Way ids are unique across classes** (#544 decision 1). An id names one way of one class. `lantern` is the Duskblade's and is never reused. Colours, riders and recognition key off the id.
- **Colours live in presentation, keyed by way id** (§1's implementation note). The class's lock names its colours and shapes; they are approved on device.
- **Riders are scoped to the run's class** (#544 decision 3). A lit rider prints, resolves and scores only where its way belongs to the run's class, and the Duskblade's card faces render as before. Decided, not built: #544 step A4. Today a Duskblade rider still prints on shared cards an Ashwarden run can reach.
- **A class that unlocks later reads an `entry` pool** (#544 decision 5): the pool state of the profile at which the class unlocks, in place of `fresh`, beside `full`, at V0 and V5. The simulator has read it since #544 P3 (#687: `--pool=entry`).

**Seeds** (#544 decision 7). A class reads on the Duskblade's bands, so its figures pair with the Duskblade's: development 12000–12999, never in a verdict; V0 cells on 13000–13999; V5 cells on 13000–14999, with G3 at V5 full also on 15000–16999; the acceptance band 3000–5199 for the exam. **17000–18999 is reserved as the 1.1 holdout.**

## 4. Ashwarden sketch (the first draft; superseded by the Ashwarden's lock)

*Locked on 2026-10-05:* the Ashwarden's ways are defined by its own lock, [`../2026-10-05-ash-flame/README.md`](../2026-10-05-ash-flame/README.md) (#544 step A1): ids, names, affinity table, crowns, deeds, lines and the measurement contract. Where this sketch and the lock differ, the lock is current. The main differences: the proposed zh way names are 焚 Smolder, 握 Hand and 立 Endure (燼 is the Duskblade's Lantern and 燃 the Kindling tier); Smother is a ½ Smolder, ½ Endure duo and Ash Bite is clear; plain draw is Hand glass; Thirsting Shard and Eat the Flame are Endure; Pyreheart is clear.

*Decided on 2026-10-04 by #544's plan of record; the sketch below is kept as the first draft.* The ways are Smolder (the fire does the killing), Hand (draw and hold; the hand-size payoff is this way's identity, and Preparation and Surge are producers within it, not ways of their own) and Endure (outlast, with a kill condition of its own) (decision 1). The starter deck is unchanged: Ash Bite is clear glass, the class's Strike; Smother is a Smolder/Endure duo; First Spark is Hand (decision 2). The Ashwarden's exclusions are the Shatter-only cards and relics and Beacon; Cracked and Dimmed cards stay as clear glass without their riders (decision 9). The names, en and zh-Hant, come through the story skill in the Ash lock (#544 step A1).

The blurb: *"Smoke given a shape. Lets the Smolder do the killing and kindles its own hand to feed the lantern. Slower, but it endures."* Three verbs are already there.

| Way | Working name | Verbs | Existing glass |
|---|---|---|---|
| 燼 Smolder | Ashsmoke | Smolder, Emberfang, Catalyst, the fire that leaps | venomStrike, toxicMist, annihilate, catalyst, virulence, ashenChoir; ashenCore, smolderingCoal; Ashfall |
| 燃 Hand | Kindled Hand | Kindle, draw, hand size, feed the lantern | preparation, surge, offering, tithe, pyreheart, emberdance; verdantBranch, crownOfTithes; the hand-size payoff of #544 |
| 忍 Endure | Ashen Wall | Ward, Poise, heal, regen, outlast | bulwark, fortify, ironSkin, regrowth, bastion, flawlessForm, aegis; gravebloom, sunBlossom, wardingCharm, basaltIdol |

Starter deck check: ashBite ×4 (Smolder), smother ×2 (Endure?), firstSpark (Hand). Confirm smother's affinity when the class is designed. Excludes for the Ashwarden: the Duskblade's Chip and Shatter glass (chisel is a starter, so this is about uppercut, quakeblow, oblivionStrike, limitBreak, resonantLance and shatterersCrown, bellOfEndings, prismCharm), since Shatter is Duskblade-only in `combat.gd`.

Nothing here is a decision. It shows the template producing a first draft in minutes, which is the point of having one.
