# The Flame — how the lantern reads Duskblade's three ways (design lock)

**Status:** LOCKED for implementation, 2026-09-29. Owner: James. Author: Claude (Fable 5.1), from the owner conversation of 2026-09-29 (session `game-balance-pickup`). Companion files: [`ways-template.md`](ways-template.md) (the reusable class template) and [`../../release-roadmap.md`](../../release-roadmap.md) (sequencing and dates).

**Verdict:** ACCEPT, with one reservation (2 October 2026), confirmed by the owner on 4 October 2026. For 1.1, read on 1.0's content under the 1.1 instrument, the Duskblade's intent holds with the same one reservation (readout 14, ruling restated 5 October 2026). This is an interim reading, not a verdict; the 1.1 verdict is given at step A9 on the combined product. The record is §11, *Verdict*.

**Authority.** This lock is the product definition of "three strategies" for Duskblade and the measurement contract that replaces the #421 landscape gates (C1–C4) for plurality. It does not edit `docs/rc-bar.md`; #549 carries the P9 wording change. It reopens no closed research. `docs/balance/p9-strategy-diversity-system.md` becomes a historical record when #549 lands; it is not rewritten.

**Owner decisions recorded, 2026-09-29 (London time):**

| Time | Decision |
|---|---|
| 12:46 | The path is never chosen from a menu. It is discovered. The only gauge is the lantern's flame: colour and stability. No hints; a few lines that "might mean something". Random, non-path decks must not still win. |
| 12:46 | Steering may exist but stays implicit; the dialogue engine may carry an intro line, never an explanation. |
| 12:46 | Ash-language cards leave Duskblade's offers. Delegated; no further approval needed. |
| 13:14 | Purity is read from the deck, not from recent play. Soot severity is calibrated by the readout, not decided up front. The flame shows a fringe of the second colour. |
| 14:08 | Option C: the flame is a mirror plus lantern quality. No per-way boons (the D3 set-bonus trap). Power comes from card synergy, capstone cards and crowns. Everything implicit. The method is the template for Ashwarden and later classes. |

## 1. The vision in one paragraph

Diablo II's Sorceress has three trees. Players are free to choose, they find their routes, and most builds are one main path with a little help from another. Glassvow expresses the same thing through cards, where the player does not control what is offered. So the deterministic layer that D2 gives through skill points is replaced by a **mirror**: the Duskblade's lantern burns whatever glass the hero carries. One kind of glass burns clean, with one colour and a still flame. Mixed glass burns dusty and unsteady. The player is never told this. They watch the flame change after a pick, and they discover it. Crowns arrive at the act boss that match the flame. The game feeds like glass to a lit flame. A player who insists on a way through bad luck gets there more slowly; a player who scatters never lights the lantern and cannot win. That is the whole design, and it is the language the game already speaks: Chip, Shatter, Kindle, Ember, Cracked.

## 2. The law, and what the player sees

**The lantern burns what you carry.** That sentence is the only rule the player is ever given, once, by the Keeper.

Player-facing surfaces, complete list:

1. the flame in the lantern (colour, fringe, stability, height);
2. which crowns appear at an act boss;
3. which cards tend to appear once the flame is lit;
4. six short lines, each heard once, and the Vigil's whispers;
5. one sentence per colour in the codex entry "The Lantern", revealed after that colour has first been seen steady;
6. a rider on some of a way's own glass that names that way's flame colour, as the codex names it ("Blood-moon flame: gain 3 Ward."), and resolves only while the lantern burns that colour ([§6.4](#64-lit-glass-readout-9), readout 9).

Not present, by decision: a path chooser, path names on cards, sigils on cards or map nodes, tooltip explanations of purity, per-way stat bonuses, tutorial text.

## 3. Definitions

- **Way** (道): one of a class's three strategic languages. Duskblade's are 碎 Shatter, 燼 Lantern, 蝕 Edge (§6).
- **Coloured glass**: a card that carries affinity to at least one way. **Clear glass**: a card with no affinity (Strike, Defend, Ward, plain draw). Clear glass is fuel, never noise.
- **Affinity**: per aspect, a weight in {0.5, 1.0} from a card to a way. A card may split 0.5/0.5 between two ways (a duo card). Weights are content data, not code.
- **Mass** (N): the sum of affinity over the coloured cards in the deck. **Share**: a way's affinity divided by N. **Purity**: the dominant share. **Fringe**: the second share, shown only when it is large enough to matter.
- **Tier**: Soot 塵, Kindling 燃, Steady 定, True 真. A function of mass and purity only.

## 4. The purity function

Deterministic, derived from `RunState.deck` and content only. Nothing is saved. The same function serves the game, the HUD and the simulator.

```text
coloured  = deck cards with an affinity entry for run.aspect
            (starters included; curses, wounds, burns, hexes and quest pages excluded)
A[w]      = sum of affinity[card][w] over coloured cards, for each way w
N         = sum of A[w]
share[w]  = A[w] / N                           (0 when N = 0)
dominant  = the way with the largest share (ties: the earlier way in content order)
second    = the next largest
purity    = share[dominant]
fringe    = second if share[second] >= fringeMin else none

tier:
  N < minMass                              -> KINDLING   (nothing declared yet)
  purity >= trueMin                        -> TRUE
  purity >= steadyMin                      -> STEADY
  N >= sootMass and purity < sootMax       -> SOOT       (genuinely scattered)
  otherwise                                -> KINDLING
```

Initial constants (content, per aspect; every one is **CALIBRATE**):

| Key | Value | Meaning |
|---|---|---|
| `minMass` | 5 | The starter deck's three seeds plus two picks before the flame can declare |
| `steadyMin` | 0.60 | Six in ten of the coloured glass is one way |
| `trueMin` | 0.75 ([readout 12](readouts/readout-12.md); initially 0.80) | Three in four |
| `sootMass` | 6 | Enough coloured glass to be judged scattered |
| `sootMax` | 0.45 | No way reaches even 45% |
| `fringeMin` | 0.25 | The second way shows at the flame's tip from 25% |

Worked examples with Duskblade's starters (chisel 1 shatter, eclipseSlash 1 edge, firstSpark 1 lantern; everything else clear):

| Deck change | N | Shares | Tier |
|---|---|---|---|
| Start | 3 | 1/3 each | Kindling |
| + Uppercut, + Quakeblow | 5 | shatter 0.60 | Steady, blue-white |
| + War Cry | 6 | shatter 0.50, edge 0.33 | Kindling again: the pick dimmed it, visibly |
| + Oblivion Strike, + Limit Break | 8 | shatter 0.63, edge 0.25 | Steady with a violet fringe |
| Remove Eclipse Slash at the shop | 7 | shatter 0.71 | Steady, fringe gone; removal read as stabilising |
| Two of each way, no more | 6 | 0.33 each | Soot |

**When it is read.** At every deck change (reward taken, shop purchase or removal, event op, upgrade that changes a card id) and at combat start. Never mid-combat; the tier a combat starts with is the tier it keeps. This is the hysteresis: the flame moves when the player acts, not while they fight.

**Upgrades** do not change affinity. **Relics** carry affinity too (§6), used only for shop and offer weighting; relics never enter N.

## 5. Tiers and the lantern's quality (Option C)

The flame changes only the lantern: how much fire it holds and how dearly the Art is paid. It never changes a way's own numbers, enemy numbers or card numbers. Initial knobs, all **CALIBRATE** in the order given in §11; a value a readout has since moved carries that readout's name, and the initial values are kept in the note under the table:

| Tier | Lantern effect | Player reading |
|---|---|---|
| Soot 塵 | At the end of each of your turns the lantern loses 1 Ember. The Lantern Art costs 1 more. | The flame gutters; the Art comes slowly |
| Kindling 燃 | None. Today's game. | A small orange flame |
| Steady 定 | Ember cap +4 (readout 6). The first Ember gain of each turn yields +2 (readout 6). | The colour shows; the flame is still |
| True 真 | As Steady. The Lantern Art costs 2 less (readout 6), minimum 1. | Pure colour, taller, a halo |

Readout 6 (2026-09-30) moved three of the initial values: the Steady cap from +2 to +4, the Steady first Ember gain from +1 to +2, and the True Art discount from 1 to 2 (the Flare costs 3, so a True lantern pays 1). The Soot values are as first set. The mechanism is unchanged and identical for every way; only a lit lantern feels it, so committed Edge and Lantern decks gain and Shatter's, rarely lit, do not. It is a step of calibration, not the answer: G1 and G4 still fail in every graded cell.

Why this is enough to make scattered decks lose without touching enemies: all three ways run through the lantern (Shatter spills Embers, Kindle makes Embers, the Art and the capstones spend them). A scattered deck has a leaking lantern, a dearer Art, no capstone synergy, and no crown arriving for it (§7). Three structural reasons, one dial.

Why it does not become a set bonus: the effect is identical for all three ways, so it cannot make one way win. A 65/35 hybrid is Steady with a fringe and pays no tax. Only a genuinely scattered deck is Soot, and Soot is recoverable within one removal or two like picks.

## 6. Duskblade's three ways

The blurb already names them: *"Strikes, shatters, and turns broken facets into fuel."* The starter deck seeds one card of each.

| Way | Flame | Colour | Shape | Verbs |
|---|---|---|---|---|
| 碎 Shatter | 霜焰 Frostlight | blue-white | sharp tongues | Chip, Stagger, Shatter, Echo |
| 燼 Lantern | 熾焰 Hearthfire | amber-gold | round, hearth-like | Kindle, Ember, Lantern, Flare |
| 蝕 Edge | 蝕焰 Eclipse | violet-crimson | thin and tall | Cracked, Dimmed, Fervor, the precise cut |
| Soot 塵 | 塵焰 | dust-brown | guttering | none |

Shape carries the way as well as colour, so a colour-blind player still reads three flames. Final hexes are the presentation lane's call, approved on device (§9).

### 6.1 Affinity table (initial; the content PR is the source of truth)

**碎 Shatter**

| Card | Weight | Availability |
|---|---|---|
| chisel | 1.0 | starter |
| uppercut | 1.0 | base pool |
| oblivionStrike | 1.0 | base pool (capstone) |
| limitBreak | 1.0 | poolWave2 (capstone) |
| quakeblow | 1.0 | deed "Breaker of Panes" |
| resonantLance | 0.5 (+0.5 Edge) | deed "Breaker of Panes" (duo) |
| spall | 1.0 | base pool (common) |
| heavyBlow (Quarry Maul) | 1.0 | base pool (common; [readout 12](readouts/readout-12.md)) |
| cleave (Fan of Glass) | 1.0 | base pool (common; [readout 12](readouts/readout-12.md)) |

Relics: shatterersCrown (crown), bellOfEndings 1.0, prismCharm 0.5 (+0.5 Lantern). Art: Beacon is the Ashwarden's; Flare is Duskblade's and belongs to no way.

*Correction (2026-10-04, #544):* "Beacon is the Ashwarden's" was a slip. A class's starting Art is content (`aspects[].art`): the Duskblade's is Flare and the Ashwarden's is Ashfall (6 Smolder on every enemy, 5 Ward). Beacon ("Your attacks chip 1 extra facet this turn") speaks the Duskblade's language of Chip. It is one of the Arts the Lamplighter's gift offers at the setting-out (`offer_arts` in `domain/rules/rewards.gd`), to any class whose `excludes.arts` does not name it; today only the Duskblade's names one, Ashfall. No Art carries affinity, so Flare and Beacon belong to no way. #544's plan of record excludes Beacon from the Ashwarden (decision 9); that is planned, not built.

Quarry Maul and Fan of Glass were clear glass until [readout 12](readouts/readout-12.md) made them Shatter: Spall was Shatter's only common, so a committed Shatter deck ended Act 1 one pick short of Steady. Both are attacks whose chip is the point (Quarry Maul chips when upgraded; Fan of Glass chips every enemy it bloods), and a commit-blind deck keeps them rarely (13% and 5% of offers).

**燼 Lantern**

| Card | Weight | Availability |
|---|---|---|
| firstSpark | 1.0 | starter |
| preparation | 1.0 | base pool |
| surge | 1.0 | base pool |
| devour | 1.0 | poolWave2 |
| offering | 1.0 | poolWave3 (capstone) |
| tithe | 1.0 | deed "The Lantern Fed" |
| pyreheart | 1.0 | deed "The Lantern Fed" |
| novaflare | 1.0 | deed "Fire Given Freely" (capstone) |
| emberdance | 1.0 | deed "Fire Given Freely" |
| cripple | 0.5 | base pool |
| aegis | 0.5 | base pool |

Relics: crownOfCinders (crown), crownOfTheHearth and crownOfTithes (crown alternates), verdantBranch 1.0, thiefOfWicks 1.0, prismCharm 0.5, emberLantern 0.5.

**蝕 Edge**

| Card | Weight | Availability |
|---|---|---|
| eclipseSlash | 1.0 | starter |
| warCry | 1.0 | base pool |
| executioner | 1.0 | poolWave2 |
| momentum | 0.5 | poolWave2 |
| lunge | 0.5 | base pool |
| resonantLance | 0.5 | duo, see Shatter |

Empower (Inner Blaze), frenzy (Overglow) and risingLitany (Rising Litany) were Edge 1.0 here until [readout 11](readouts/readout-11.md) made them clear glass: stat powers that any deck takes coloured the adaptive player's lantern blood-moon, as no other power in the Duskblade's offers does.

Relics: crownOfTheEclipse (crown, **new**), executionersSeal 1.0, duskmirror 0.5, warFetish 0.5, ironTalisman 0.5.

**Clear glass** (no affinity): strike, defend, brace, bulwark, fortify, sidestep, deflect, guardedStrike, quickSlash, tempest, shardstorm, twinFangs, flurry, leechBlade, phantomBlades, agility, ironSkin, regrowth, bastion, flawlessForm, nightSight, bloodRite, and from readout 11 empower, frenzy and risingLitany. Curses and quest cards are excluded from N.

**Excluded from Duskblade's offers** (pool hygiene; Smolder is blocked for aspect 0 in `combat.gd`, so these are dead or half-dead glass for the Duskblade): cards venomStrike, toxicMist, annihilate, catalyst, virulence, ashenChoir; relic smolderingCoal. The Ashwarden keeps all of them. Nothing is deleted from content. Pool hygiene changes which cards a seeded aspect-0 run meets at events, shops and card rewards compared with pre-Flame content, by design; historical replays use the frozen copy at `docs/balance/data/421-h39/full-content.json`.

### 6.2 What Edge lacks, and what the content lane adds

Edge is the thin way: three coloured cards in a fresh pool, no crown, no capstone, no deed. The content lane adds, in Duskblade's language, with numbers finalised against the readout:

| Role | Working name | Rarity | Sketch | Availability |
|---|---|---|---|---|
| applicator | Splinter Cut 裂痕斬 | common | Deal 5. Apply 1 Cracked. | base pool |
| tempo | Dim the Glass 暗琉 | common | Apply 2 Dimmed. Draw 1. | base pool |
| amplifier | Fault Line 斷層 | uncommon | Deal 8. If the target is Cracked, apply 1 more Cracked and gain 1 Fervor. | base pool |
| defence in the way's words | Eclipse Step 蝕影步 | uncommon | Gain 5 Ward. Apply 1 Cracked to the enemy about to strike you. | base pool |
| multi-hit | Tremor 震紋 | uncommon | Deal 3 damage three times. Each hit on Cracked glass deals 2 more. | poolWave2 |
| capstone | Totality 全蝕 | rare | Deal 14. Cracked on the target doubles. | new deed |
| duo Lantern/Edge | Ember Eye 燼瞳 | rare | Spend 2 Embers: apply 2 Cracked to ALL enemies. Kindle. | poolWave3 |
| crown | Crown of the Eclipse 蝕月冠 | boss | Cracked you apply does not fade. | boss pool |
| deed | Fault in the Glass 裂痕 | deed | Apply 40 Cracked across runs; unlocks Totality and Ember Eye | requires `run.stats["cracked"]` |

Seven cards, one crown, one deed. After this, each way has roughly ten coloured cards at full unlock and four to five in a fresh pool, one crown, one or two capstones, and at least one duo card to each neighbour (Shatter/Edge: resonantLance; Shatter/Lantern: prismCharm; Lantern/Edge: Ember Eye).

### 6.3 Deeds already teach the ways

The deeds system already rewards playing a way with more of that way: "Breaker of Panes" (shatters) unlocks quakeblow and resonantLance; "The Lantern Fed" (kindles) unlocks tithe and pyreheart; "Fire Given Freely" (embers spent) unlocks novaflare and emberdance. The new Edge deed completes the set. This is D2's "find your route" as meta-progression, and it is why viability must be measured under both a fresh pool and a full pool (§11).

### 6.4 Lit glass (readout 9)

Each way's payoff that only a committed deck collects, added by [readout 9](readouts/readout-9.md). A card effect may carry `lit` with a way's id; it resolves only while the lantern burns that way's colour, Steady or True, as the fight began. It reads the same flame reading as §5's lantern quality, once at combat start, so the tier a combat starts with is the tier it keeps. The rest of the card always resolves. The printed rider names the colour and nothing else: no tier word, no path name.

| Way | Rider (en / zh-Hant) | On |
|---|---|---|
| 碎 Shatter | Frost-white flame: chip 1 more Facet. / 霜白之火：再琢擊 1 格璃面。 | chisel, spall, quakeblow |
| 燼 Lantern | Amber flame: gain 1 Ember. / 金黃之火：獲得 1 點餘燼。 | preparation (Tinder), surge (Struck Match), tithe |
| 蝕 Edge | Blood-moon flame: gain #3# Ward. / 血月之火：獲得 #3# 點護光。 (`#…#` marks the Ward number, as on every Ward card) | eclipseSlash, splinterCut, dimTheGlass, warCry (Shatterhymn) |

Hearthfall carried the Lantern's rider until [readout 13](readouts/readout-13.md): on the Lantern's own Ember-spend card it refunded a third of the cost and carried the committed Lantern's fresh-pool lead, so it left.

Why it is not the set bonus §5 rules out: the rider is printed on the way's own glass and pays per card played, as any card synergy does; a deck that holds none of it gets nothing from a lit flame beyond §5. Why it reaches committed decks: with readout 8's search player at V0, a committed deck fights 54–78% of its fights in its own colour, the adaptive arm 12–17% and the random arm 11–13% in any colour. The rider sizes are content, numbers set against readout 9.

## 7. Recognition at the boss

The act boss does not ask. It recognises. For `run.aspect == 0`, `roll_boss_relics` becomes:

```text
read the flame (tier, dominant, fringe)
slot 1: crownOf(dominant)  if tier in {STEADY, TRUE}
        sootCrown          if tier == SOOT           (hollowCrown: energy, and the glass dims)
        random             otherwise
slot 2: crownOf(fringe)    if fringe and tier in {STEADY, TRUE}, else random
slot 3: random from the remaining boss pool
a held crown is never offered; a slot whose crown is held falls back to random
random draws are made in a fixed count regardless of branch, so the seed stream stays stable
```

`crownOf`: Shatter → shatterersCrown; Lantern → crownOfCinders, then crownOfTheHearth, then crownOfTithes if earlier ones are held; Edge → crownOfTheEclipse. Later act bosses use the same rule, so a hybrid's second crown arrives in Act 2 and a pivot is recognised, not punished.

No text says why the crown came. The first aha is "that crown was for my flame". The later aha is "keep it amber and the Hearth comes".

## 8. Like calls to like

Once the flame is Steady or True, the world leans toward it, softly:

- `_roll_card_reward` and `gen_shop`: a pool entry whose affinity to the dominant way is at least 0.5 has its draw weight multiplied by `likeWeight` (initial **1.5**, CALIBRATE); to the fringe way, by `fringeWeight` (initial **1.2**). Kindling and Soot apply no weighting. Rarity cuts are unchanged. The shared seed cursor advances identically at every tier, so replays stay deterministic: a shop pick is one draw whatever the weights, and a card reward is rolled on a detached chain seeded from the cursor, so weighting may change how many draws that chain takes (a duplicate is drawn again) but never moves the cursor or any later draw.
- Relic shop stock uses relic affinity the same way.
- Pool hygiene (§6.1) applies at every tier.
- Removal needs no rule. Removing off-colour glass raises purity and the flame answers on the spot. Players find "thin the deck, steady the flame" by themselves.

The bias is soft on purpose. Good cards of the other ways still appear, so main-path-plus-splash emerges rather than being enforced.

## 9. The flame on screen

Presentation reads the flame from `EventTypes.FLAME` events emitted by the domain at every read (§4). It never computes purity itself.

- **Where:** the combat HUD lantern (`presentation/combat/hud_bar.gd` already draws the lantern, its glow and ember pips); the reward, shop and event screens carry the same small lantern so the change after a pick is seen where the pick happens (an event is where §8's removal is made; [the event screen](event/README.md)); the map's run HUD if it shows the lantern. The choice screen's title lantern is untouched.
- **What:** a flame shader with four inputs: dominant colour, fringe colour (drawn at the tips), stability (flicker amplitude: Soot guttering, Kindling lively, Steady calm, True still) and height (tier). Shape per way as in §6.
- **How it moves:** a change tweens over about a second; it never snaps. A Soot flame throws occasional dust motes. A True flame has a faint halo.
- **Later, after visual approval:** the Art's VFX and the chip VFX tinted by the dominant colour. Measure the budget before that; do not restructure until the flame itself is approved on the reference shapes.
- **Accessibility:** tier is legible from stability and height alone; way from shape alone.

## 10. Lines

Six lines, each heard once per Vigil, through Stagecraft's existing `once` gates and the line table's whisper slot. The register is the Keeper's warm tiredness and the road's whispers. Never a mechanic word.

| Moment | Speaker / surface | zh-Hant | en |
|---|---|---|---|
| The lantern is lit at the opening | Keeper, in the opening scene | 它燒的是你帶著的東西。 | It burns what you carry. |
| First Steady | Lamplighter, or a whisper if he is not met | 它認得你了。 | It knows you now. |
| First True | whisper | 一種玻璃，一種火。 | One glass. One fire. |
| First Soot | whisper | 塵火照不亮路。 | A dusty flame lights no road. |
| Vigil after a death in Soot | Vigil whisper | 你的火從未安定下來。 | Your flame never settled. |
| First Steady with a fringe | whisper | 火尖上有另一種顏色。 | There is another colour at the tip. |

Codex: the help entry "The Lantern" gains one sentence per colour, each revealed after that colour has been seen Steady once. Three sentences, no numbers.

## 11. Science: the instrument panel

The previous programme measured shatters and Smolder kills, one of which is the Ashwarden's word, then partitioned runs by relative medians. It could not see the Lantern way at all. The new instrument is the game's own purity function plus the stats the run already keeps (`run.stats`: shatters, kindles, embersSpent; add `cracked` and `embersGained`).

**Descriptor per run:** dominant way and tier at run end, plus the per-fight rates. Absolute, deterministic, identical in game and simulator.

**Arms** (policy gains a `way` field in {none, shatter, lantern, edge}; a committed policy multiplies the pilot's card and relic scores of its way by `commit` = 3.0, for two copies of a card (readout 13), and other coloured glass by 0.5, steers shop and removal the same way and removes its off-colour starter seeds first (readout 13); it does not change combat play):

| Arm | Build | Play | Meaning |
|---|---|---|---|
| C_shatter, C_lantern, C_edge | committed | competent | "I chose this way and I insist" |
| A | adaptive (today's arm 1) | competent | "I read the offers" |
| A_lit | adaptive, reading its own flame ([readout 10](readouts/readout-10.md)) | competent | "I read the offers and my lantern" |
| R | random (today's arm 2) | competent | "I scatter" |

A_lit is A until its lantern burns a way's colour, Steady or True; from then, until the flame dims, it values that way's glass ×2.0 (`litLean`) and other coloured glass ×0.5 (`litOff`), and counts that colour's riders (§6.4) in full. From readout 10 on, G3 and G6 are read against A_lit, and B2 reads A_lit's feel beside the committed arms' (its expression against the colour each fight begins in, as the grader's feel table measures the adaptive arms); A stays in the table as the floor.

**Status (readout 13, 2026-10-02).** With the committed bot fixed (it removes its off-colour seeds and its ×3 covers two copies), G5 read over the runs alive at the act's end, and Hearthfall's amber rider gone ([readout 13](readouts/readout-13.md)): G5 passes on point and interval in every graded cell. G2 passes on point at V0 full (9.7 pp, interval UNDECIDED) and at V5 in both pools; at V0 fresh the Lantern's lead is 12.8 pp, FAIL on point and UNDECIDED (readout 12: a decided FAIL at 17.9 pp). G3 passes on point at V0 fresh (−1.6 pp), V0 full (−2.2 pp) and V5 fresh (−0.3 pp, PASS on interval too); at V5 full it reads −3.5 pp on 4,000 paired seeds (−5.0 to −2.0), FAIL on point and UNDECIDED, which about 36,000 paired seeds would decide. G6 passes on point in every cell for A_lit; arm A's floor fails on point at V0 full (Edge 61.3% of its wins). G7 and B1 pass; B2 passes for committed Edge in both pools and A_lit at V0 full, A_lit's own B2 at V0 fresh stays a decided FAIL (59.2%), and G1 and G4 fail as instrument readings. Verdicts that worsen with readout 13: G6's floor at V0 full (PASS to FAIL on point), G3 at V5 full on the table's band (PASS to FAIL on point; readout 12's 4,000-seed reading was already FAIL), G3's floor at V5 full (interval UNDECIDED to FAIL), and the committed Lantern at V5, now the joint weakest way at V5 full (12.2%).

Cells: aspect 0 × vows {0, 5} × pool states {fresh, full} × 200 paired seeds (common random numbers across arms). About 4,000 runs; minutes on the #558 simulator.

**Gates** (initial; signed after the first readout, then frozen for the exam):

| Gate | Statement | Initial threshold |
|---|---|---|
| G1 viability | each committed way wins | full pool: V0 ≥ 50%, V5 ≥ 25%; fresh pool: V0 ≥ 40% |
| G2 parity | the ways are comparable | best committed − worst committed ≤ 10 pp at each vow |
| G3 skill | reading offers is rewarded but commitment is not a trap | A ≥ best committed − 3 pp and A ≤ best committed + 15 pp |
| G4 random loses | scattering cannot win | R ≤ worst committed − 25 pp; R < 35% at V0, < 15% at V5 |
| G5 reachability | insisting gets there | full pool: committed arms reach Steady by the end of Act 1 in ≥ 70% of runs alive at the end of Act 1, True by the end of Act 2 in ≥ 40% of runs alive at the end of Act 2; fresh pool: V0 ≥ 40% Steady by the end of Act 1 of runs alive then, True not graded (readout 5). The all-runs figure is reported beside it (readout 13) |
| G6 diversity of adaptive play | different runs are different | among A's wins no way exceeds 60%; at least two ways hold ≥ 20% |
| G7 guards | nothing degenerate, nothing broken | CEM stress: V5 best holdout < 90%; zero stalls and errors; deterministic replay; save lineage and internal IDs unchanged |
| B bot round | every way can be won and has a feel | Replaces the human row (owner ruling, 2026-10-01). The headless simulator's search player ([readout 8](readouts/readout-8.md)) plays the cell table above, at least 200 paired seeds per cell, every figure graded on its 95% interval. (1) Every committed way wins at V0 with the search player: win rate ≥ 20% in the full pool and ≥ 10% in the fresh pool. (2) No way has no feel: at V0 in both pools each committed way's coloured plays favour its own glass in ≥ 60% of its fights (expression), and 1–10% of its won fights end under 20% HP (close calls). James's play reports are input, never a gate. |

*Row H, as locked on 2026-09-29, read:* "H human | it is fun | James plus two or three players each win at V0 with every way at least once across the group; easy / fun / hard labels; #205 verdict". *Superseded on 2026-10-01* by row B (owner ruling; #631, [readout 8](readouts/readout-8.md)). Play reports, #205's included, are input to the verdict, never a gate.

**How the table is read since the owner's rulings** (recorded 2026-10-04). The thresholds above stand; what they decide changed:

- *30 Sep 2026:* G1 and G4 are readings, not GO blockers. They are reported in every graded cell with their intervals, and their thresholds never decide the verdict. Global calibration is closed (see *Calibration order* below).
- *1 Oct 2026:* the bots replace the human round: row B replaces H, and play reports are input.
- *2 Oct 2026:* the result is one verdict, ACCEPT or NOT ACCEPTED, on the design's intent, with the gates as its evidence (*Verdict*, below).
- *The lock's own amendments:* G5's fresh-pool figure ([readout 5](readouts/readout-5.md)); G3 and G6 read against A_lit ([readout 10](readouts/readout-10.md)); G5 over survivors, G3 paired on common seeds, and the committed bot `p8-d0-v3` ([readout 13](readouts/readout-13.md)).

[`docs/rc-bar.md`](../../rc-bar.md) P9 binds which gates are graded and which are readings (#685). "Signed after the first readout, then frozen for the exam" is replaced there by this table with its recorded amendments.

**G5 over survivors (orchestrator ruling, 2026-10-02, applied from [readout 13](readouts/readout-13.md)).** Reachability is a question about the flame, not survival. A run that dies before an act's end has no flame reading there, so it leaves that act's denominator: Steady by the end of Act 1 is graded among runs alive at the end of Act 1, True by the end of Act 2 among runs alive at the end of Act 2. The all-runs figure stays in every table beside it. Readouts 1–12 graded G5 over every run and stay as recorded; at V5 that reading was bounded by survival (only 44–60% of committed runs lived to the end of Act 1 in readout 12).

**The committed bot from readout 13.** The committed arms' build (pilot `p8-d0-v3`) removes its two off-colour starter seeds first whenever a removal is offered, as §4's worked example does, and its ×`commit` covers two copies of a card; a further copy offered is weighed as clear glass. Readouts 1–12 used the earlier bot (two copies of the worst card before a shop removal, the shrine taking a Strike or a Defend, and ×3 on every copy) and stay as recorded; from readout 13 on, the improved bot is the reading of record. Arm A, A_lit and R build as before (an A_lit that removed the seeds off its lit colour lost 2.7 pp at V0 full, p = 0.01, in readout 13's check).

**Calibration order**, one commit and one ten-minute readout per step; the step that reaches G4 with the least damage to G3 is kept:

1. pool hygiene, affinity table and the flame as a pure mirror (every lantern knob at zero);
2. the Soot leak;
3. Steady and True lantern quality;
4. recognition at the boss and like-calls-to-like.

*Closed on 2026-09-30.* Readouts 1–3 ran these steps, and readouts 5 and 6 tried further global levers. They found that no global lever reaches G1 or G4 and that enemy scalars lift every arm alike, and the owner ruled that the game may be hard and that G1 and G4 are readings. Calibration by global knobs ended there. From [readout 7](readouts/readout-7.md) on, the only balance lever is each way's own wall: diagnose, try at most three candidates per way, ship the measured ones or drop them.

**Seeds:** development 12000–12999; calibration 13000–13399, paired across arms; the historical holdout 5000–5199 is used once on the final candidate; the CEM stress keeps 4200–4999 for training and 5000–5199 for its ceiling. Acceptance seeds 3000–5199 stay otherwise untouched. *Added 2026-10-04:* 17000–18999 is reserved as 1.1's holdout (#544's plan of record, decision 7). The bands of record for 1.0 are in `docs/rc-bar.md` P9.

**Exam:** the final candidate SHA runs the full cell table above plus the CEM stress. An independent re-run from a clean checkout on any host must agree on every gate's verdict (owner ruling of 2026-09-27; numbers need not match). Then the bot round (B). *From 2026-10-04,* `docs/rc-bar.md` P9 defines the exact candidate, the independent re-run and the exam's own items.

**Verdict** (recorded here on 2026-10-04; items 3 and 5 are also in [#544](https://github.com/fol2/glassvow/issues/544)'s plan of record, decision 12, and this record is the first written record of item 1). The orchestrator gives the Duskblade's verdict under the owner's delegation of design calls (30 Sep 2026). As it happened:

1. **2 Oct 2026, morning.** After the owner's ruling of 09:04 BST ("i want the result. i don't even mind the gate… just give me the acceptance result"), the orchestrator's verdict was **NOT ACCEPTED**, on two product grounds in the full pool: an Edge monoculture (G6) and the True tier unreachable (G5). It was given on [readout 10](readouts/readout-10.md)'s table and reported to the owner in the orchestrator's session that day; it is entered here from that session's record.
2. Readouts [11](readouts/readout-11.md), [12](readouts/readout-12.md) and [13](readouts/readout-13.md) (#644, #646, #648) answered both grounds.
3. **2 Oct 2026, 22:12 BST.** **ACCEPT**, on readouts 11–13 and on readout 13's complete §11 table, with one reservation: the fresh-pool Lantern lead, 12.8 pp at V0 (G2 at V0 fresh: FAIL on point, UNDECIDED on interval), carried as a 1.0.x readout. Readout 13 is 1.0's reading of record.
4. The other graded figures short of their thresholds, and why each gate's intent holds, are recorded in [`docs/rc-bar.md`](../../rc-bar.md) P9 (#685). They are not restated here.
5. **4 Oct 2026, 12:25 BST.** The owner confirmed: "we have completed game balance for dusk", and activated the Ashwarden programme (#544).
6. Readout 13 has been reproduced run for run by the repository's readout runner (#684, #544's step P2): 44,012 rows identical to the archive. Its record is [`readouts/readout-13-reproduction.md`](readouts/readout-13-reproduction.md).
7. **4–5 Oct 2026, readout 14** (#544's step P6). The orchestrator accepted pilot `p9` and search player `s2` as the 1.1 instrument, at `3dcbe37b`, after review fixes to `s2`: the payoff credit now uses only cards held before a draw, and the draw credit is priced against the Energy left. The first ruling (4 Oct) found G2 at V0 fresh a decided FAIL. That figure came from the instrument before the fixes, and on the fixed instrument it no longer holds: the Lantern leads Shatter and Edge by 13.5 pp (+9.6 to +17.3), FAIL on point and UNDECIDED on interval, the class readout 13's reservation had. The restated ruling (5 Oct) has three parts. The 1.0 verdict above stands. Read on 1.0's content under the 1.1 instrument, the Duskblade's intent holds with the same one reservation; this is an interim reading, not a verdict, and the 1.1 verdict is given at step A9 on the combined product. The fresh-pool Lantern lead stays the reservation, carried into 1.1. A Duskblade fresh-pool wall lane is optional research; its changes would land only after the 1.0 release candidate is cut. The ruling and its grounds are readout 14's last section.

**The 1.0.x readout asks** ([readout 13](readouts/readout-13.md), *What the next readout should ask*, items 1 and 5):

- the fresh-pool Lantern lead (12.8 pp at V0): the reservation. Readout 14 answered whether it is real: it is, at the same size under the better player (13.5 pp, UNDECIDED). It stays the reservation, carried into 1.1 (item 7 above);
- A_lit's feel at V0 fresh (59.2% against row B's 60%). It is an ask, not a reservation; `docs/rc-bar.md` P9 records why row B's intent holds without it.

## 12. Implementation map

One outcome per PR, in this order. Each PR carries its own tests and the narrow gate that answers its question; the full core gate runs once on each coherent candidate before push.

| # | Outcome | Surfaces | Proof |
|---|---|---|---|
| 1 | This lock, the template and the roadmap | docs | `check_anchors`, `check_benchmark_freeze` |
| 2 | Affinity data, `domain/rules/flame.gd`, pool hygiene, `cracked` and `embersGained` stats, `EventTypes.FLAME`, simulator metrics, committed arms, `tools/balance_ways.py` readout; every lantern knob at zero | content, domain, tools, tests | unit tests for the purity function and tiers; readout 1 |
| 3 | Recognition at the boss; like-calls-to-like | `rewards.gd` | determinism tests (draw counts, seed-1000 digest re-pinned in an explicit commit); readout 2 |
| 4 | Lantern quality knobs, calibrated | `combat.gd` | readout 3 |
| 5 | The flame on screen | `hud_bar.gd`, reward and shop screens, a flame shader | visual inspection on the reference shapes, then James on device |
| 6 | Edge way content, crown, deed, art | content, locale, art ledger | readout 4 on the exam candidate |
| 7 | Lines and the codex reveal | `scenes.json`, line table, locale | `test_stagecraft`, locale coverage |
| 8 | #549: `rc-bar.md` P9 becomes G1–G7 plus H; the old P9 method doc gets a historical header. *Done in #549 (PR #572, 2026-09-29). Amended on 2026-10-04 by #685: one verdict per class on the design's intent, G1 and G4 readings, row B for H.* | docs | `check_agent_contracts` if agent docs move |

Invariants: no save schema change (the flame is derived); new card and relic ids are additions; `port_fixtures/` change only where boss offers and reward weights deliberately moved, in an explicit commit that says so; `domain/` stays pure and presentation consumes events.

## 13. Non-goals

Per-way stat boons; a path chooser or any explicit path UI; card or map sigils; tutorial text; enemy or shared-scalar retuning as the first lever; carrying the unmerged #556 and #557 scalar changes by default (the flame starts from `main`'s content and the readout decides); Ashwarden balance (1.1, via the template); the mythic set (#212); the CEM landscape as a plurality certifier; the certificate, oracle and containment vocabulary of the superseded programme.

## 14. Open items for the content and presentation lanes

- Final wording and numbers of the seven Edge cards and the Eclipse crown, against readout 4.
  - *Implementation note (PR 6, 2026-09-29):* the amplifier ships as **Cleft 裂隙**. The working name "Fault Line 斷層" is taken: the existing card `executioner` is displayed as "Faultline" in English and 斷層 in zh-Hant. The other six cards, the crown and the deed keep their working names. Their costs and upgrades, and the first reading of the way with them, are in [readout 4a](readouts/readout-4a.md).
- Crown of Tithes keeps its current effect; it is a Lantern alternate crown. Revisit only if the readout shows it idle.
- Flame hexes and shapes, approved on device.
- Whether the map's run HUD shows the lantern today; if not, the reward screen is the minimum surface.
