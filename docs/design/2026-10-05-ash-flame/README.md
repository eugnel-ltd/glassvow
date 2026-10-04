# The Flame — how the lantern reads the Ashwarden's three ways (design lock)

**Status:** LOCKED for implementation, 2026-10-05. Owner: James. Author: Claude (Opus 5.5), for the orchestrator, as step A1 of [#544](https://github.com/fol2/glassvow/issues/544)'s plan of record. Companion files: the Duskblade's lock [`../2026-09-29-dusk-flame/README.md`](../2026-09-29-dusk-flame/README.md) (the mechanism and the measurement contract this lock inherits), the class template [`../2026-09-29-dusk-flame/ways-template.md`](../2026-09-29-dusk-flame/ways-template.md), and this lock's first reading, [`readouts/readout-a0.md`](readouts/readout-a0.md) (development seeds, not of record).

**Verdict:** none yet. The Ashwarden's verdict is given on its reading of record at step A9 (§12), under [`docs/rc-bar.md`](../../rc-bar.md) P9's 1.1 scope.

**Authority.** This lock is the product definition of the Ashwarden's three ways and the Ashwarden's measurement contract for 1.1. It follows the Duskblade's lock's structure and inherits that lock's mechanism (its §4, §5, §7 and §8) and measurement contract (its §11) by reference; only what differs for the Ashwarden is written out. Precedence, highest first:

1. the owner's instructions;
2. #544's plan of record (4 October 2026, 13:20 BST), decisions 1–13, which bind this lock;
3. [`docs/rc-bar.md`](../../rc-bar.md) P9, which binds which gates are graded and how a verdict is given;
4. this lock;
5. the Duskblade's lock and the class template, where this lock is silent.

This lock changes no content, code or test. It edits no part of the Duskblade's lock; the Duskblade's 1.0 verdict and its record stand as written there.

**Activation and delegation.** On 4 October 2026 (12:25 BST) the owner activated the Ashwarden programme: "we have completed game balance for dusk, now we can do the same for ash … by doing ash, you solid the pipeline/workflow … make no mistake, pursue detail and perfection". Design calls are delegated to the orchestrator under the owner's delegation of 30 September 2026; the plan of record followed at 13:20 BST.

**Rulings carried forward** (each binds the Ashwarden from its first reading):

| Date | Ruling | Where |
|---|---|---|
| 29 Sep 2026 | Option C: the flame is a mirror plus lantern quality. No per-way boons; power comes from card synergy, capstones and crowns; everything implicit. The method is the template for later classes | Duskblade lock, header |
| 30 Sep 2026 | The game may be hard ("it is okay to be hard, this is roguelike"). G1 and G4 are readings. Global calibration is closed. At most three candidates per way per wall lane | Duskblade lock §11 |
| 1 Oct 2026 | The bots replace the human round: row B replaces H. Play reports are input, never a gate | Duskblade lock §11 |
| 2 Oct 2026 | G5 is graded over the runs alive at the act's end. The result is one verdict, ACCEPT or NOT ACCEPTED, on the design's intent, with the gates as its evidence | Duskblade lock §11; rc-bar P9 |
| 4 Oct 2026 | The 1.1 instrument is pilot `p9` and search player `s2` (readout 14, the orchestrator's ruling) | [#690](https://github.com/fol2/glassvow/pull/690) |

## 1. The vision in one paragraph

The Ashwarden's blurb already names its three ways: *"Smoke given a shape. Lets the Smolder do the killing [**Smolder**] and kindles its own hand to feed the lantern [**Hand**]. Slower, but it endures [**Endure**] — and everything it touches burns."* The law is the Duskblade's, unchanged: the lantern burns what you carry. A deck of one kind of glass burns clean, with one colour and a still flame; a mixed deck burns dusty. Nobody tells the player. There is no path chooser and no per-way boon. A Smolder deck lets a slow fire do its killing and wins by waiting; a Hand deck draws more than it can play, holds what it draws and is paid for every card it holds; an Endure deck outlasts the fight and closes it in its own colour. Most runs will be one way with a little of another, which the flame shows as a fringe.

## 2. The law, and what the player sees

The law and the complete list of player-facing surfaces are the Duskblade's (its lock §2). For the Ashwarden:

1. the flame in the lantern, in the Ashwarden's three colours and shapes (§8);
2. which crowns appear at an act boss (§7);
3. which cards tend to appear once the flame is lit (§7);
4. six short lines in the Ashwarden's register, each heard once per Vigil, and the Vigil's whispers (§9);
5. one sentence per Ashwarden colour in the codex entry "The Lantern", revealed after that colour has first been seen steady (§9);
6. a rider on some of a way's own glass, printed only on glass only the Ashwarden can meet, naming that way's flame colour and resolving only while the lantern burns it (§6.6).

Not present, by decision: as the Duskblade's.

## 3. Definitions

As the Duskblade's lock §3 (way, coloured and clear glass, affinity, mass, share, purity, fringe, tier). Three terms are the Ashwarden's:

- **Hand-size payoff**: a card whose effect reads how many cards are in hand when it resolves. Phantom Blades ("Deal 3 damage for each card in your hand") is the one in content today.
- **Way stat**: the run stat a way's play produces. It names the way's verb for the search player (a turn's way stat counts in its evaluation, as Shatter, Kindle and Cracked count for the Duskblade), labels the per-fight rates in every report, and drives the way's deed. Way stats live in `tools/balance_classes.json` (#544 P3).
- **Entry pool**: the pool state of a profile that has just unlocked the class: one run played and won, so the Lamplighter and emberglass reveals and the Ashwarden itself, and no pool wave or deed card. It stands where the Duskblade's lock reads `fresh`, because no Ashwarden player ever has a fresh Vigil. Card for card, the entry pool's cards are the fresh pool's.

## 4. The purity function

The same code: `domain/rules/flame.gd` reads `content.aspects[run.aspect].ways` and `.flame`, so the Ashwarden needs no rule of its own. Its constants start at the Duskblade's shipped values (#544 decision 8), and each is **CALIBRATE** only through a wall lane:

| Key | Value | Meaning |
|---|---|---|
| `minMass` | 5 | Three units of seed plus two picks before the flame can declare |
| `steadyMin` | 0.60 | Six in ten of the coloured glass is one way |
| `trueMin` | 0.75 | Three in four (the Duskblade's since its readout 12) |
| `sootMass` | 6 | Enough coloured glass to be judged scattered |
| `sootMax` | 0.45 | No way reaches even 45% |
| `fringeMin` | 0.25 | The second way shows from 25% |
| `likeWeight`, `fringeWeight`, `kindlingLift` | 1.5, 1.2, 1.0 | §7 |

Ways in content order: `smolder`, `hand`, `endure`, the blurb's order. A tie for the dominant way goes to the earlier one, as for the Duskblade.

**The starter deck** (#544 decision 2, unchanged): Ash Bite ×4 clear (the class's Strike), Defend ×3 clear, Smother ×2 at 0.5 Smolder and 0.5 Endure each, First Spark 1.0 Hand. The start reads N = 3, one third each, exactly as the Duskblade's does. Tagging Ash Bite Smolder would start the deck at N = 7 with Smolder at 71%: every Ashwarden lantern would be lit in Smolder's colour before the first pick.

Worked examples with the Ashwarden's starters (computed with the purity function on the affinity table of §6.1):

| Deck change | N | Shares (Smolder / Hand / Endure) | Tier |
|---|---|---|---|
| Start | 3 | 1/3 each | Kindling |
| + Emberbite, + Emberbite | 5 | 0.60 / 0.20 / 0.20 | Steady, ash-green, no fringe |
| + Glasswall | 6 | 0.50 / 0.17 / 0.33 | Kindling again: the pick dimmed it |
| + Ashcloud, + Requiem | 8 | 0.63 / 0.13 / 0.25 | Steady with a pearl (Endure) fringe |
| Remove Glasswall at the shop | 7 | 0.71 / 0.14 / 0.14 | Steady, fringe gone: removal read as steadying |
| From the start: + Emberbite, + Tinder, + Glasswall | 6 | 1/3 each | Soot |
| From the start: + Tinder, + Struck Match | 5 | 0.20 / 0.60 / 0.20 | Steady, candle-yellow |
| … then remove one Smother | 4 | 0.13 / 0.75 / 0.13 | **Kindling**: under `minMass` |

The last row is the Ashwarden's own lesson, and the Duskblade's lock has no row like it. Each Smother is a duo, half Smolder and half Endure, so a Hand deck that removes its off-colour seeds removes mass from two ways at once and can drop under five units, where the flame cannot declare at all. It steadies again with one more Hand card (Tinder: N = 5, Hand 0.80, True). The committed bot removes its off-colour seeds first, Smothers included (§10), so the readouts will show this; it is a property of the duo seed, not a defect.

When it is read, upgrades, relics: as the Duskblade's lock §4.

## 5. Tiers and the lantern's quality

The same code (`combat.gd`, `_set_lantern_quality`) and the Duskblade's shipped knobs (#544 decision 8):

| Tier | Lantern effect | Ashfall (cost 3) |
|---|---|---|
| Soot 塵 | Loses 1 Ember at the end of each of your turns (`sootLeak` 1); the Art costs 1 more (`sootArtCost` 1) | 4 Embers |
| Kindling 燃 | None | 3 |
| Steady 定 | Ember cap +4 (`steadyCap`); the first Ember gain of each turn yields +2 (`steadyFirstGain`) | 3 |
| True 真 | As Steady; the Art costs 2 less (`trueArtCost`), never below 1 | 1 |

The Ashwarden's Art is Ashfall: "Apply 6 Smolder to ALL enemies and gain 5 Ward." It speaks Smolder and Endure, while the Hand way feeds the lantern most, burning the surplus it draws (§6.5). The lantern's quality is still identical for every way, so it cannot decide which way wins; what a lit lantern buys differs by way, as it does for the Duskblade (Shatter rarely lit, Lantern often). The readouts watch it: if a lit Smolder or Endure lantern turns cheap Ashfalls into a way's lead, that way's wall lane names it.

## 6. The Ashwarden's three ways

| Way (en / zh) | Id | Flame (en / zh) | Colour | Shape | Verbs | Way stat | Deed |
|---|---|---|---|---|---|---|---|
| Smolder / 焚 | `smolder` | Banked Fire / 伏焰 | ash-green | round and low, banked | Smolder, the fire that leaps, Catalyst, Ashfall | `smolderKills` | Sermon of Ash (`ashSermon`) |
| Hand / 握 | `hand` | Palmfire / 掌焰 | candle-yellow | many tongues, like fingers | draw, hold, the hand-size payoff; Kindle as its release | `drawn` (new, §6.4) | new, on `drawn` (step A5b) |
| Endure / 立 | `endure` | Standfast / 立焰 | pearl | thin, tall and still | Ward, Poise, heal, outlast | `perfects` | The Glass Untouched (`untouched`) |
| Soot / 塵 | — | 塵焰 | dust-brown | guttering | none | — | — |

Ids are unique across classes (#544 decision 1); `lantern` is the Duskblade's and is never reused. The Soot look is the Duskblade's: Soot is a state of the lantern, not of a class, so a scattered deck looks the same in either hand. Every name in this table is **PROPOSED** (§9), for the owner's later ear.

Colour and shape: the three shapes are the flame shader's three existing way axes (`WAY_SHAPE`, `presentation/combat/lantern_flame.gd`), keyed by the Ashwarden's ids; the shape alone carries the way for a colour-blind player, and the colours are chosen to differ from each other, from Kindling's orange and Soot's brown, and from the Duskblade's blue-white, amber and violet. Ash-green is the Ashwarden's Smolder already: Smolder's damage numbers and Ashfall's glyph are drawn in that pale green today. Final hexes are the presentation lane's, approved on device (§8).

### 6.1 Affinity table (initial; the content PR is the source of truth)

This is readout A0's preferred candidate, `duos` ([`readouts/readout-a0.md`](readouts/readout-a0.md)). Weights are 1.0 unless marked ½.

**焚 Smolder**

| Card | Weight | Availability |
|---|---|---|
| smother (Smother) | ½ (+½ Endure) | starter (duo seed) |
| venomStrike (Emberbite) | 1.0 | base pool (common) |
| toxicMist (Ashcloud) | 1.0 | poolWave2 |
| annihilate (Requiem) | 1.0 | poolWave2 |
| catalyst (Bellows) | 1.0 | poolWave3 (capstone) |
| virulence (Emberfang) | 1.0 | poolFull (capstone) |
| ashenChoir (Ashen Choir) | 1.0 | deed Sermon of Ash |

Relics: crown crownOfCinders (interim, §6.7); smolderingCoal 1.0. Ashen Core is the class's starting relic and Ashfall its starting Art; neither carries affinity (relics never enter the mass, and no Art carries affinity).

**握 Hand**

| Card | Weight | Availability |
|---|---|---|
| firstSpark (First Spark) | 1.0 | starter (seed) |
| preparation (Tinder) | 1.0 | base pool (common) |
| quickSlash (Flicker) | 1.0 | base pool (common) |
| sidestep (Glasstep) | ½ (+½ Endure) | base pool (common; duo) |
| deflect (Refract) | ½ (+½ Endure) | base pool (common; duo) |
| surge (Struck Match) | 1.0 | base pool (uncommon) |
| phantomBlades (Phantom Blades) | 1.0 | base pool (rare; capstone, the payoff) |
| offering (Pyre Tithe) | 1.0 | poolWave3 (capstone) |
| tithe (Tithe of Panes) | 1.0 | deed The Lantern Fed |
| nightSight (Night Sight) | 1.0 | deed Walker of Unlit Ways |
| emberdance (Emberdance) | ½ (+½ Endure) | deed Fire Given Freely (duo) |

Relics: crown crownOfTithes; verdantBranch 1.0, travelersPack ½.

**立 Endure**

| Card | Weight | Availability |
|---|---|---|
| smother (Smother) | ½ | duo seed, see Smolder |
| sidestep (Glasstep), deflect (Refract) | ½ each | duos, see Hand |
| bulwark (Glasswall) | 1.0 | base pool (uncommon) |
| fortify (Mirrorlight) | 1.0 | base pool (uncommon) |
| ironSkin (Vitrify) | 1.0 | base pool (uncommon) |
| leechBlade (Thirsting Shard) | 1.0 | base pool (uncommon) |
| aegis (Cathedral Glass) | 1.0 | base pool (rare) |
| bastion (Anneal) | 1.0 | base pool (rare; capstone) |
| regrowth (Hearthglow) | 1.0 | poolWave2 |
| devour (Eat the Flame) | 1.0 | poolWave2 |
| flawlessForm (Flawless Form) | 1.0 | deed The Glass Untouched (capstone) |
| emberdance (Emberdance) | ½ | duo, see Hand |

Relics: crown crownOfTheHearth; basaltIdol 1.0, wardingCharm 1.0, gravebloom ½, silkFan ½, sunBlossom ½.

**Clear glass** (no affinity for the Ashwarden): ashBite and defend (starters); twinFangs, heavyBlow (Quarry Maul), cleave (Fan of Glass), lunge (Dimming Cut), guardedStrike (Warden's Edge), brace (Held Light), tempest, flurry, cripple (Gutter), warCry (Shatterhymn), empower (Inner Blaze), agility (Glazier's Poise); in the full pool also executioner (Faultline), momentum (Honing Edge), bloodRite, risingLitany, frenzy (Overglow), pyreheart, novaflare, shardstorm. Curses and quest cards are excluded from N.

Choices inside the binding decisions, and why:

- **Plain draw is the Hand's verb.** Flicker (an attack that draws) is Hand glass; Glasstep and Refract (Ward that draws) bridge Hand and Endure. The Duskblade's lock keeps plain draw clear because its Lantern's verb is the Kindle, not the draw; the Ashwarden's Hand way is draw and hold (decision 1), so its producers are draw cards. Of A0's three candidates it alone has no decided G6 failure at V0 in either pool, and it narrows the committed spread most (readout A0, greedy screens; the search screen is pending).
- **Glazier's Poise is clear glass.** Stat powers that any deck takes colour the adaptive lantern; the Duskblade's readout 11 cleared Inner Blaze, Overglow and Rising Litany for that reason, and the same holds here. Vitrify (Ward every turn) and Hearthglow (heal every turn) are Endure's verbs and stay coloured.
- **Thirsting Shard and Eat the Flame are Endure.** They are the damage that heals. Thirsting Shard is the leech card of #421's Bloodfire package, the one Ashwarden package besides the hand-size payoff that the #421 programme admitted (§15); Eat the Flame heals on the kill it makes. Until step A5c gives Endure a payoff of its own, they are the way's only attacks in its colour.
- **Pyre Tithe is Hand**, as the Hand's second capstone: it burns the hand into the lantern and draws three. It is the kindled hand of the blurb in one card (§6.5).
- **Gutter, Pyreheart and Novaflare are clear.** Gutter is a debuff, not Ward or heal; Pyreheart and Novaflare are the lantern's own glass, and the Ashwarden's lantern belongs to no way (§5).

### 6.2 Supply per pool

Count of cards carrying the way's affinity (mass in brackets), with the share of a normal card reward's slots that land on that way's glass while the flame is unlit (rarity cuts 60 / 32 / 8%, `rewards.gd` `_rarity_cuts`), against the template's targets (four to five in the entry pool, about ten in the full pool):

| Way | Entry pool | Full pool | Target | Gap |
|---|---|---|---|---|
| Smolder | **1** (1.0), 5.5% of slots | 6 (6.0), 10.4% | 4–5 / ~10 | **Entry: three to four cards short.** Full: four short |
| Hand | 6 (5.0), 21.9% | 10 (8.5), 23.1% | 4–5 / ~10 | Met |
| Endure | 8 (7.0), 22.4% | 12 (10.5), 16.5% | 4–5 / ~10 | Above target in entry |
| Pool size | 25 (11 / 11 / 3) | 45 (11 / 20 / 14) | | |

The entry pool holds only three rares once the Shatter-only glass leaves it (§6.3): Phantom Blades, Cathedral Glass and Anneal.

### 6.3 Exclusions (#544 decision 9)

Added to `aspects[1].excludes` (pool hygiene; nothing is deleted from content):

- **cards** uppercut (Ringing Blow), quakeblow (Quakeblow), oblivionStrike (Bellstrike), limitBreak (Annealing Rite), resonantLance (Resonant Lance): the Shatter-only glass. Chips and Shatter are the Duskblade's alone in `combat.gd`, so for the Ashwarden these are dead or half-dead;
- **relics** shatterersCrown, bellOfEndings, prismCharm: they pay on facets and Shatters;
- **arts** beacon: "Your attacks chip 1 extra facet this turn".

Kept from today's list: splinterCut, dimTheGlass, cleft, eclipseStep, tremor, totality, emberEye, spall, hearthfall; crownOfTheEclipse.

**Cracked and Dimmed glass stays** (warCry, executioner, lunge): Cracked and Dimmed work for the Ashwarden. These cards are clear glass for it, and their Duskblade riders print and resolve only for the Duskblade once step A4 lands (§6.6).

The exclusions alone change what an Ashwarden run meets, as the Duskblade's did, and readout A0 measures them alone, with no ways. Under the greedy pilot they lift the commit-blind arm most in the entry pool (10.0% to 42.8% at V0 on 400 development seeds; 155 seeds gained, 24 lost), chiefly because the pilot no longer builds Bellstrike, whose chips are dead for the Ashwarden, into its decks (2.5 copies a run before). The search player's figure is readout A0's to give; whatever it is, it moves the cross-class reading (§10) before any way exists.

### 6.4 Crowns, capstones, duos and deeds

| Way | Crown | Capstones | Deed (stat) |
|---|---|---|---|
| Smolder | crownOfCinders, interim | catalyst (Bellows), virulence (Emberfang) | `ashSermon` (`smolderKills`): unlocks Ashen Choir and Smoldering Coal |
| Hand | crownOfTithes | phantomBlades (Phantom Blades), offering (Pyre Tithe) | new, on `drawn` (step A5b) |
| Endure | crownOfTheHearth | bastion (Anneal), flawlessForm (Flawless Form) | `untouched` (`perfects`): unlocks Flawless Form (its other unlock, Prism Charm, is excluded for the Ashwarden) |
| Soot crown | hollowCrown | | |

- **Crowns.** The boss pool left to the Ashwarden after §6.3 holds four crowns: Crown of Cinders, Hollow Crown, Crown of Tithes and Crown of the Hearth. Hollow Crown is the soot crown, as for the Duskblade. Crown of the Hearth (heal for every Ember left at the fight's end) is the outlasting crown. Crown of Tithes (kindle twice a turn, each kindling grants 3 Ward) is the kindled hand's. Crown of Cinders (a lantern of 12 Embers that begins each fight holding 2) is Smolder's for now, because it pays in Ashfalls; Smolder's own crown is step A5a's, and Crown of Cinders then becomes its first alternate. The Duskblade's recognition is untouched: these crowns are the Duskblade's too, and each class's recognition reads only its own ways.
- **Duos.** Smolder/Endure: Smother. Hand/Endure: Glasstep and Refract in the entry pool, Emberdance in the full. **Smolder/Hand: none.** The template asks for one duo per pair; step A5 adds it.
- **Way stats.** `smolderKills` exists and is never written (#544 audit §3.6); step A3 writes it. `drawn`, the cards drawn by a card, relic, potion or Art beyond the turn's own deal, is new; step A3 adds it as an additive key of `run.stats`, so no save changes. `perfects` exists and is written. The Duskblade's way stats are not touched, so its search, its rates and its rows stay byte-identical; the invariance panel proves it.
- **Deeds.** Sermon of Ash cannot progress in the product today (`smolderKills` is never written); the simulator's full pool hides this by granting every deed's unlocks. The Glass Untouched is the Ashwarden's Endure deed as it stands. The Lantern Fed (Kindle 20 cards) teaches the Hand's producers, but its stat is the Duskblade Lantern's; the Hand's own deed, on `drawn`, comes with its payoff in step A5b.

### 6.5 The Hand way: the hand-size payoff is its identity

#544 decision 1 makes the hand-size payoff the Hand way's identity, with Preparation (Tinder) and Surge (Struck Match) as producers of one family. #421 found the hand-size payoff the one Ashwarden package that passed every gate it was put to (§15). So:

- **The payoff** is Phantom Blades today: one of the entry pool's three rares, so under 3% of a normal reward's slots. "Include or improve": step A5b adds at least one hand-size payoff at common or uncommon, Ashwarden-only, so the identity is met before the rare arrives.
- **The producers** are one family: every Hand card that draws (Tinder, Struck Match, Flicker, Glasstep, Refract, First Spark, Tithe of Panes, Night Sight), and Verdant Branch and the Traveller's Pack among relics.
- **Kindle and holding coexist.** They pull against each other (#544 audit §3.4): Kindle burns a card from hand for an Ember, and the payoff wants the card held. The Hand way draws more than it can play. What it cannot play it holds, and the payoff counts it. What it cannot hold, it burns, and the lantern takes it. So the Hand deck feeds the lantern from its surplus, never from the hand it means to keep, and the order within a turn (draw, then pay, then kindle from what is left) is the skill the way teaches. Pyre Tithe is the end of that line, the whole hand burned and three cards drawn. The bots play both since readout 14 (search `s2` credits the payoff and the draw; §10).
- **The hand's size** is the content field `handSize` (5 for both classes, wired by step A2, #544 decision 10). It is a class-level lever a wall lane may name; it is not a way lever, because it serves all three ways.

### 6.6 Lit glass for the Ashwarden, and the rider scope (#544 decision 3)

The Duskblade's lit glass carries over unchanged as a mechanism (its lock §6.4). Two rules are added:

1. **A rider is scoped to the run's class.** A `lit` rider prints, resolves and scores only where its way belongs to the run's class. Resolution is already safe: `combat.gd` compares the rider's way id with the lit way, and no Ashwarden way shares an id with the Duskblade's. Scoring is safe since readout 14 (pilot `p9` scores a rider its class cannot light at 0). Printing needs step A4: the rider sentence leaves the card's one text string for a key of its own, so Tinder, Struck Match, Tithe of Panes and Shatterhymn print their Duskblade riders only for the Duskblade. **The Duskblade's card faces render as before**, proved by captures at the reference shapes in en and zh-Hant.
2. **The Ashwarden's riders go on Ashwarden-only glass.** Smolder's glass is Ashwarden-only already (the Duskblade excludes all six cards), so step A4 may rider it. Hand's and Endure's glass in content is shared, so their riders wait for the Ashwarden-only cards of steps A5b and A5c.

Rider wording (**PROPOSED**; numbers are content, set against a readout as the Duskblade's were in its readout 9):

| Way | Rider (en / zh-Hant) |
|---|---|
| 焚 Smolder | Ash-green flame: apply 1 more Smolder. / 灰綠之火：再施加 1 層陰燃。 |
| 握 Hand | Candle-yellow flame: draw 1 card. / 明黃之火：抽 1 張牌。 |
| 立 Endure | Pearl flame: gain #3# Ward. / 珠光之火：獲得 #3# 點護光。 |

### 6.7 The content lane's gap list

From readout A0 (development seeds; the greedy pilot's screens now, the search player's when its instrument is settled):

| Way | Supply | The wall (where it dies) | Kill condition | The content lane |
|---|---|---|---|---|
| Smolder | Entry: one card (Emberbite); a committed Smolder deck reaches Steady by the end of Act 1 in 13–20% of runs alive then. Full: six cards, and Steady 78% | Act 2 in the entry pool, starved of its own glass; it wins the full pool | Exists: Smolder kills, with the class's starter (Ash Bite ×4, Ashen Core, Ashfall) behind it | **A5a:** three or four base-pool Smolder cards, Ashwarden-only; its own crown; Sermon of Ash progresses once A3 lands |
| Hand | Entry six cards with plain draw; the payoff is one rare | Acts 2–3 in the full pool, where the bigger pool dilutes its producers | Exists only as a rare (Phantom Blades) | **A5b:** a common or uncommon hand-size payoff; the Hand deed on `drawn`; a Smolder/Hand duo if A5a does not bring one |
| Endure | Above target in entry | Not found: the strongest committed way in every greedy cell (66–90% at V0) | **None of its own**: no Endure card turns Ward into damage. It wins by outlasting while the class's starter Smolder kills | **A5c:** a payoff in its own colour that closes a fight; then, if the search readings confirm the greedy ones, Endure's wall lane (A8) is the first one run |

The greedy pilot plays the board one card at a time and is far weaker than the search player (arm A at V0 full: 29.5–36.8% greedy on the three candidates; readout 14's development reading of today's content, without ways, gave the search player about 60%), so these walls are directions, not figures. Every figure the lock relies on is re-read under the search player before step A2's reading of record.

## 7. Recognition at the boss, and like calls to like

The same code (`rewards.gd`): recognition reads the run aspect's ways, crowns, `crownAlts` and `sootCrown`; like-calls-to-like reads its `flame`. `crownOf`: Smolder → crownOfCinders; Hand → crownOfTithes; Endure → crownOfTheHearth; Soot → hollowCrown. A held crown is never offered; a slot whose crown is held falls back to random draws in the fixed count, so the seed stream stays stable. The Ashwarden needs no rule of its own; step A2's content row switches it on, and the six flame tests that pin "the Ashwarden declares no ways" flip in that commit, deliberately (§12).

## 8. The flame on screen

As the Duskblade's lock §9, keyed by the Ashwarden's ids in `COLOUR` and `WAY_SHAPE` (`presentation/combat/lantern_flame.gd`): Smolder round and low, Hand in many tongues, Endure thin and tall; colours as §6. Accessibility as the Duskblade's: the tier from stability and height alone, the way from shape alone. Unknown ids already fall back to the Kindling or Soot colour, so step A2 can land before step A6 without a crash: an Ashwarden lantern shows a plain flame until its colours exist. The colours, shapes and the flame lab's Ashwarden readings are step A6, approved on device.

## 9. Lines

Six lines and three codex sentences in the Ashwarden's register (#544 decision 11), drafted through the story skill (`.claude/skills/glassvow-story/SKILL.md`). Every line here is **PROPOSED**, for the owner's later ear, as the Duskblade's codex sentences were. zh-Hant is the source; the English is a rewrite. Every character is one the bundled fonts already carry, and no line uses the seven banned vertical words. The register is the Duskblade's lines': the Keeper's warm tiredness and the road's whispers, never a mechanic word. Each line is selected for an Ashwarden run by an `aspect` condition in the line table (#544 decision 11; step A7); the Duskblade's six lines and three sentences are untouched.

| Moment | Speaker / surface | zh-Hant | en | Level |
|---|---|---|---|---|
| The lantern is lit (the Vigil's first Ashwarden setting-out) | Keeper, at the hearth | 它燒得慢，燒得久。 | It burns slow, and it burns long. | L1 |
| First Steady | whisper | 灰下的火，認得你了。 | Under the ash, the fire knows you now. | L1 |
| First True | whisper | 別的都燒成了灰，只剩一種火。 | Everything else has burned to ash. One fire is left. | L1 |
| First Soot | whisper | 煙多於火。 | More smoke than fire. | L1 |
| Vigil after a death in Soot | the Vigil's ledger | 你的火從來只有煙。 | Your fire was only ever smoke. | L1 |
| First Steady with a fringe | whisper | 煙裏有另一種顏色。 | There is another colour in the smoke. | L1 |

Codex: the help entry "The Lantern" gains one sentence per Ashwarden colour, each revealed after that colour has been seen Steady once (`codex.lantern.smolder`, `.hand`, `.endure`). Colour and shape are written together, so a colour-blind reader can still match each sentence to its flame.

| Colour | zh-Hant | en |
|---|---|---|
| Ash-green (Smolder) | 灰綠的火伏得低，在灰下燒得最久。 | An ash-green fire lies low, and lasts longest under the ash. |
| Candle-yellow (Hand) | 明黃的火分出許多火尖，像一隻手；手裏握着的越多，它燒得越亮。 | A candle-yellow fire parts into many tips, like a hand; the more the hand holds, the brighter it burns. |
| Pearl (Endure) | 珠光的火又直又靜，風來了也不倒。 | A pearl fire stands straight and still, and does not fall when the wind comes. |

**Why the lighting line is not the opening's.** The Duskblade's lighting line ("It burns what you carry") is the Keeper's at the opening scene, which every player hears on the first run, before the Ashwarden can be unlocked. The law is given once and is not repeated. The Ashwarden's lighting line is the Keeper's at the hearth on the Vigil's first Ashwarden setting-out: a remark on this lantern, not a second statement of the law.

**The story skill's passes, as drafted** (the fresh-context batch runs when step A7 promotes the copy):

- *Truth and matrix* (`00-truth.md` §3, §4, §8.6). Fire is will, ash is what burns out with nothing left to set; the lines say nothing else about them. The Keeper's line is literally true (this class is "slower, but it endures": the blurb's own words) and claims nothing the Keeper may not know. Smoke is only the blurb's image ("Smoke given a shape"); no line gives it a meaning the bible lacks.
- *Voice* (`02-cast.md`, the Keeper's four rules). It never lies, never urges departure, never speaks of the road in the first person; the line passes "true before, colder after".
- *Ladder and twist safety* (`00-truth.md` §5; `04-delivery.md`, the flame channel's ceiling of L1). Surface and post-twist readings:

| Line | Surface | Post-twist |
|---|---|---|
| 它燒得慢，燒得久。 | This lantern burns slowly and lasts | What burns is the walker's will (00 §3.2): a slow fire is a long dying, and the arrangement is served longest by a walker who lasts |
| 灰下的火，認得你了。 | The flame has taken your colour | The hearth's fire is the first fire's embers under the ash that drifted west (00 §2.2); every walker who carried it was you, so it knew you already (as row 459) |
| 別的都燒成了灰，只剩一種火。 | One kind of glass; one clean fire | Ash is will burned out (00 §8.6): the walker has spent everything but one fire, and the door wants one whole fire (00 §2.2, §2.6) |
| 煙多於火。 | A scattered deck burns poorly | A will spread thin gives off more than it burns; it lights nothing (as row 462) |
| 你的火從來只有煙。 | This run's flame never took | The walker went out before the fire took hold: a death in smoke, read at the hearth by the one who stayed |
| 煙裏有另一種顏色。 | A second way shows at the edge | The other colour is also you; there is no one else in the Queue (as row 460) |
| 灰綠的火伏得低，在灰下燒得最久。 | The Smolder fire is slow and patient | The fire that lasts longest under the ash is the hearth's own: it never left the hearth (00 §2.4) |
| 明黃的火…手裏握着的越多，它燒得越亮。 | The more a Hand deck holds, the stronger | The lantern burns what the walker carries: the more it holds, the more there is to burn |
| 珠光的火又直又靜，風來了也不倒。 | The Endure flame cannot be put out | The walkers die standing and do not lie down (row 1, L1) |

None rises above L1: the strongest is the pearl sentence, an image of standing that the shipped whisper "Your monument does not always lie down" already carries at L1.

- *Vocabulary and orthography* (`06-glossary.md`). 着 and 裏 throughout; no banned term; 灰 (ash) and 煙 (smoke) are the shipped blurb's words; the colour words (灰綠, 明黃, 珠光) are new and need glossary rows when step A7 lands them.

The lines' ledger rows (`docs/story/05-foreshadow-ledger.md`) are written by step A7, when the copy enters the line table, as the Duskblade's were by its lines PR.

## 10. The instrument

The Duskblade's lock §11 is the measurement contract, with the rulings and amendments recorded there and in `docs/rc-bar.md` P9. Only what differs for the Ashwarden is written here.

**Bots.** Pilot `p9` and search player `s2` (#544 P6, the 1.1 instrument; [#690](https://github.com/fol2/glassvow/pull/690), readout 14), named on every Ashwarden run with `--pilot p9 --search s2`; greedy screens name `--pilot p9`. The tools' default stays 1.0's (`p8-d0-v3`, `s1`) until 1.0 ships, so an Ashwarden run that does not name its bots cannot pass for one: the grader refuses a table that mixes them. *Note (2026-10-05):* #690's review found that `s2` at its first head credited a hand-size payoff for a card the line had only just drawn. It is fixed on #690's branch before merge; every Ashwarden figure of record is read with the bots #690 merges.

**Arms.** C_smolder, C_hand, C_endure, A, A_lit and R, on common seeds. The committed bot is the Duskblade's from its readout 13: ×3 (`WAY_COMMIT`) on its own glass for two copies of a card, ×0.5 on other coloured glass, and its off-colour starter seeds removed first. For the Ashwarden that means First Spark for C_smolder and C_endure, and both Smothers for C_hand (§4's last row). G3 and G6 read A_lit; A stays as the commit-blind floor; R is G4's control.

**Way stats** (`tools/balance_classes.json`): `smolder` → `smolderKills`, `hand` → `drawn`, `endure` → `perfects`. They are part of the instrument: the search player credits a turn's way stats as it credits Shatter, Kindle and Cracked for the Duskblade. So they are written before the first reading of record (step A3 lands before step A2's reading; §12).

**Cells.** Aspect 1 (the Ashwarden) × vows {0, 5} × pools {`entry`, `full`}. The `entry` pool takes `fresh`'s place wherever the Duskblade's lock grades `fresh`: G1 at V0 ≥ 40% (a reading); G5 at V0, Steady by the end of Act 1 ≥ 40% of runs alive then, True not graded; B1 at V0 ≥ 10%; V5 `entry` ungraded for G1 and G5, as V5 `fresh` is. The simulator's `entry` profile is `balance_sim.gd`'s `_apply_entry` (#544 P3).

**Seeds** (#544 decision 7). The Duskblade's bands, so every figure pairs with the Duskblade's on its seed: development 12000–12999, never in a verdict (screens on 12000–12399, 400 seeds an arm and cell); V0 cells on 13000–13999 (1,000 paired seeds); V5 cells on 13000–14999 (2,000); G3 at V5 full also on 15000–16999. **17000–18999 is the 1.1 holdout**: the CEM stress reads its Vow-5 ceiling there, once, on the final candidate. The acceptance band 3000–5199 keeps its 1.0 uses only; 1.0's holdout 5000–5199 is never read for 1.1.

**Gates and thresholds.** G1–G7 and row B, with the Duskblade's thresholds and its lock's amendments (G5's fresh-pool figure, read here on `entry`; G3 and G6 against A_lit; G5 over survivors; G3 paired on common seeds), graded on point and on the 95% interval by `tools/balance_ways.py` and `tools/balance_readout.py`. G1 and G4 are readings; G2, G3, G5, G6, G7 and B are graded (rc-bar P9). **The thresholds freeze after Ash readout A1** (step A2): that readout may record an amendment with its reason, as the Duskblade's readouts 5, 10 and 13 did, and from it on they are fixed for the exam (#544 decision 5).

**The cross-class reading** (#544 decision 5). A_lit's win rate for the Ashwarden minus the Duskblade's, at V0 full, on the same seeds and the same instrument, with Newcombe's paired interval on common seeds. It is reported in every Ashwarden readout of record and is not a gate. **Above +15 pp it triggers a diagnosis**: the readout says which arms and which acts carry the gap, and whether an Ashwarden lever (its content, its exclusions, its own flame values) or nothing should answer it. The Duskblade's figures never move to close it. Readout A0 takes the first reading on the commit-blind baseline.

**The exam.** On the final candidate (step A9): the complete cell table for both classes on the combined product, both on the 1.1 instrument; the CEM stress over both classes (`balance_cem.gd` `GRIDS` already holds both), training on 4200–4999 as 1.0's does (training fitness never enters a receipt) and reading its Vow-5 ceiling on the 1.1 holdout 17000–18999, used once; the save-lineage and internal-ID check; this lock's §11 invariants. An independent re-run from a clean checkout on another host must agree on every graded verdict in every graded cell (owner ruling, 27 September 2026; numbers need not match).

**The verdict** (rc-bar P9, the template §3). One verdict for the Ashwarden, ACCEPT or NOT ACCEPTED, on whether the design's intent holds: the three ways are viable and comparable; commitment is rewarded and reading the offers is not a trap; scattering loses; the tiers are reachable; adaptive play is diverse; every way can be won and has a feel; nothing is degenerate. It is given on one reading of record: a readout's complete §11 table, its content SHA-256 and its instrument. For every graded-gate figure short of its threshold it states why the gate's intent still holds or names a reservation that carries it; a reservation states its figures and the readout that will answer it. A G7 miss is always NOT ACCEPTED. The orchestrator gives it under the owner's delegation; this section records it as it happened, under a *Verdict* entry added at step A9, and P9 binds it.

**The Duskblade's fresh-pool Lantern lead is not this lock's.** It is the Duskblade's 1.1 requalification item (readout 14, the orchestrator's ruling, item 4): a Duskblade wall lane in the fresh pool, under the 1.1 instrument, landing only after the 1.0 release candidate is cut. Nothing in the Ashwarden's steps answers it or moves the Duskblade to answer it. The Duskblade's 1.1 verdict, given beside the Ashwarden's at step A9, waits for it.

## 11. Invariants

What must not change for the Duskblade (#544 audit §4.2):

- **Content and instrument identity.** The Duskblade's run rows stay byte-identical: every Ashwarden content commit proves it on the invariance panel (`tests/test_balance_invariance.gd`). 1.0's bots (`p8-d0-v3`, `s1`), the seed-1000 and seed-1001 digests and readout 13's table do not move. `content/full-content.json` itself is bound to the Duskblade's 1.0 verdict by SHA-256 (`e9c4d48f…`): rc-bar P9's *same content* rule asks the 1.0 release candidate to carry that exact file, and any Ashwarden content commit on `main` (decision 6) changes it. How the two meet is an open item (§14).
- **Rule 1.** Every new Ashwarden-only id (card, relic, potion, boon, Art, deed) enters the Duskblade's `excludes` in the same commit. Exclusions leave its draw counts and RNG stream unchanged (`rewards.gd`), so its rows stay byte-identical.
- **Rule 2.** No Ashwarden lane edits a card, relic, enemy, event, shop or global value the Duskblade can meet. Every lever is Ashwarden-only content, the Ashwarden's own `flame` values, its `excludes`, or riders on Ashwarden-only glass. A shared edit needs its own PR with a paired Duskblade re-read and a restated Duskblade verdict.
- **Rule 3.** Every tool change is a no-op for the Duskblade, shown by the invariance panel. The one exception is a deliberate instrument change, which re-reads the Duskblade.
- **Rule 4.** No save-schema change: new stats are additive keys of `run.stats`, which `run_state.gd` merges on load. Ids are only added. `port_fixtures/` move only in an explicit commit that says why.

And for the Ashwarden: `domain/` stays pure, presentation consumes events, and the Ashwarden stays `"deferred": true` until step A10.

## 12. Implementation map

One outcome per PR, in this order. Each PR carries its own tests and the narrow check that answers its question, and the full core gate once on its final candidate before push. Semantic or policy PRs take one exact-head review.

| # | Outcome | Surfaces | Proof |
|---|---|---|---|
| A2 | The Ashwarden's ways in content; **Ash readout A1** | `aspects[1]`: `ways` (§6.1, §6.4), `flame` (§4), `sootCrown`, `excludes` (§6.3); `handSize` wired in `combat.gd` (5 for both: neutral, #544 decision 10); the six flame test files that pin "no ways" flipped in that commit; a new `tests/test_ash_flame.gd` with §4's worked examples; `tests/test_balance_catalogue.gd` re-pinned; `deferred` stays true | Unit tests; **the Duskblade's invariance panel byte-identical**; Ash readout A1 of record on the bands of record under `p9`/`s2`, its complete §11 table for aspect 1, the cross-class reading, and the thresholds frozen |
| A3 | The way stats counted: `smolderKills` written when Smolder kills; `drawn` added (cards drawn beyond the turn's deal); the Ashwarden's `wayStats` in `tools/balance_classes.json`. **Lands before A2's reading** | `domain/rules/combat.gd`, `domain/state/run_state.gd`, `tools/balance_classes.json`, tests | Sermon of Ash progresses on a product-path test; a test counts `drawn`; the Duskblade's invariance panel and digests unchanged |
| A4 | Riders print, resolve and score only for their class; the Ashwarden's Smolder riders | card faces and locale (rider sentences as keys of their own), `tests/test_lit_riders.gd`, `tools/check_card_faces.gd`; riders on Smolder's Ashwarden-only glass | Rider tests per class; card-lab captures of every affected face in en and zh-Hant at the reference shapes, the Duskblade's unchanged; a screen, then a table |
| A5a | Smolder: three or four base-pool cards, Ashwarden-only; its own crown | content, locale, art ledger, card art | Each new id in the Duskblade's `excludes`; invariance; at most three candidates screened (400 seeds), then one table; locale and font coverage |
| A5b | Hand: a common or uncommon hand-size payoff; the Hand deed on `drawn`; the Smolder/Hand duo if A5a has none | as A5a | as A5a |
| A5c | Endure: a payoff of its own that closes a fight | as A5a | as A5a |
| A6 | The Ashwarden's flame on screen | `presentation/combat/lantern_flame.gd` (`COLOUR`, `WAY_SHAPE` for the three ids), `presentation/lab/flame_lab.gd`, `tests/test_lantern_flame.gd` | Visual inspection at the reference shapes and on device; the Duskblade's flame unchanged |
| A7 | The Ashwarden's lines and codex | `domain/rules/line_table.gd` (an `aspect` condition), `content/line-table.json`, locale, `docs/story/05-foreshadow-ledger.md`, `docs/story/06-glossary.md` | The story skill's batch lint; `test_stagecraft`; locale and font coverage; the Duskblade's lines unchanged |
| A8 | Wall lanes, only where a readout names a wall | Ashwarden content, `excludes` or `flame` only | Diagnose; at most three candidates per way per lane; ship the measured or drop them; at most two lanes per way (§14) |
| A9 | The combined-product reading and the verdicts | readouts | The Ashwarden's reading of record and its ACCEPT or NOT ACCEPTED; the Duskblade's 1.1 verdict beside it (once its fresh-pool item is answered, §10); the cross-class reading; the exam (§10) |
| A10 | Exposure in 1.1 (release lane) | `aspects[1].deferred` false; class-scope tests; the Vigil and Dawn promise `aspect2` again | `test_class_scope`; P9 for 1.1; device and feel |

A3 moves ahead of A2's reading because its stats are part of the instrument (§10): reading Ash readout A1 without them and its successors with them would change the instrument between the readout that freezes the thresholds and the next. A3 needs no ways in content and is a no-op for the Duskblade, so it can land first. A6 and A7 touch separate files and may run beside A3–A5.

## 13. Non-goals

Per-way boons; a path chooser or any explicit path UI; card or map sigils; tutorial text; any edit to Duskblade content or to anything the Duskblade can meet (§11, rule 2); enemy or shared-scalar retuning; global calibration; reopening #421's closed families (the Kindle/Branch ladder, Emberglass Memory, the normalised-payoff commitment grammar, the scalar substrate); the mythic set (#212); the Duskblade's fresh-pool Lantern lead (§10).

## 14. Fallback, time box and open items

**Fallback** (#544 decision 13; template §2 step 10). Each Ashwarden way has at most two wall lanes. A way that cannot reach B1 (the committed way wins at V0 with the search player: ≥ 20% full, ≥ 10% `entry`) and G2 by then ships as a fringe beside two clear ways, and the release notes to ourselves say so. Readout A0 puts the risk on Smolder in the entry pool (supply) and on Endure's power, not its weakness.

**Time box.** The roadmap's 1.1 Ashwarden lock date, Friday 19 December 2026, and 1.1 live in late January 2027 stand (`docs/release-roadmap.md` §3).

**Open items.**

- Readout A0's search-player screen and commit-blind baseline, once #690's fixed head is settled (readout A0, *Pending*).
- **P9's same-content rule and decision 6.** Ashwarden content landing on `main` (step A2 on) moves `content/full-content.json` away from the SHA-256 the Duskblade's 1.0 verdict binds, while the 1.0 release candidate is cut on 21 November. Either the release candidate is cut from a commit before step A2's content, or A2's content waits for the cut, or P9 reads *same content* as the Duskblade's run rows proved byte-identical. The choice is the orchestrator's; step A2 does not merge before it is made.
- Final rider sizes, card numbers, crown effects and the Hand deed's threshold, against their readouts.
- Flame hexes and shapes, approved on device (step A6).
- The colour words and every name in §6 and §9, for the owner's ear.
- Whether the Smolder way keeps Crown of Cinders as an alternate once its own crown lands.

## 15. History: #421's Ashwarden findings, as priors

Kept as #544 requires, with their scoped negatives. They were measured on pre-Flame content and a different instrument; they are priors for this lock, not evidence for it.

| Finding | Source | What it means here |
|---|---|---|
| #524 `SCOPE_INSUFFICIENT_AT_CAUSAL_MECHANISM_PACKAGE_GATE`: of ten package families and 192 matched contrasts, only `hand-size-payoff` on the Ashwarden passed every interaction, panel and real-economy gate | #421, 27 Aug 2026 | The hand-size payoff is the Hand way's identity (§6.5) |
| Hand-size reconciliation exact; Preparation, Surge and Phantom Blades byte-identical in the packet | v10 snapshot, 28 Aug | Preparation and Surge are producers of one Hand family |
| Hand-size plus Bloodfire (leech) support admitted; separation 27 hand-size-only, 28 Bloodfire-only | v10 snapshot | Bloodfire is the Endure way's provisional damage (§6.1) |
| The normalised-payoff commitment grammar closed at boundary 2 (Bloodfire 20 active preferred policies against a minimum of 32) | #421, Aug | Not reopened; the Flame replaces it |
| Hand-size activation sparse with no positive win effect under the full-run definition; poison-Catalyst frequent and positive, sensitivity under-covered | Dimmed-family report | The old bots could not play a hand-size way (fixed by `s2`/`p9`); Smolder is the class's default engine |
| EP4: Ashwarden planned 84% at V0 and 52% at V5; RandomBuild 29% and 10%; hand-size destinations reached 13–16.5%, poison-Catalyst 64.5–75.5%; Ashwarden lead over the Duskblade 12–12.5 pp | #421, 30 Aug | The Ashwarden has long been the stronger class: the reason for the cross-class reading (§10) |
| Closed families: the Kindle/Branch ladder (#525), Emberglass Memory, the scalar substrate | #421 | Never proposed again as Ashwarden levers (§13) |
