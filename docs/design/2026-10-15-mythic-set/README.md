# The mythic set (秘藏): design

Issue #212, lane `mythic-design`, 15 October 2026. Base `3a502235`.

Round 2 (the review of PR #732) changes §1.5 (Unbowed's HP guard), §1.6 (the
Known Road's deal), §2.4 and §2.7 (the Act IV gate on the full set), §3 (the
Knight's route now fits his shipped death and has a scene seam), §4, §6, §7,
§8 and §9.

This is a design document. It changes no code, content, locale file or asset.
Every name, rules line, fragment and scene line below is **[PROPOSED]** copy. It
enters `content/` or `locale/` only through the story-draft batch (§4.4). The
calls the owner may want to re-pick are numbered in §9.

**Binding inputs.** #212 and the settled parts of #206, #210 and #175. The
owner's words of 15 October: mythics may be overpowered, end-game balance is not
a gate, and exactly one mythic is guaranteed through a story side quest behind
Vow 3, overpowered too but subtle. The orchestrator's O1–O5 (15 October). The
story bible (`docs/story/`), the holo design (frame M0 and the toolkit, branch
`research/cards-holo-2026-10-14`) and the art ledger.

**The spirit of the set.** A mythic breaks a rule the player has learned. A big
number cannot do that. The bar is shareability: the player gets one and wants to
show someone. Five cards are pure chance. One card, Banked Fire, comes through a
story and wins quietly over a whole run.

---

## 1. The six cards

### 1.1 The set

| Petal | id | en | zh-Hant | Type | Cost (+) | The rule it breaks |
|---|---|---|---|---|---|---|
| 1 | `bankedFire` | Banked Fire | 封火 | Skill | 0 (0) | The lantern goes dark when a fight ends. |
| 2 | `silvering` | Silvering | 鍍銀 | Skill | 2 (1) | An enemy only ever acts against you. |
| 3 | `unbrokenFlame` | The Unbroken Flame | 未碎之火 | Power | 2 (1) | Your flame burns one colour, and only that colour's effects fire. |
| 4 | `unbowed` | Unbowed | 不臥 | Skill | Unplayable | At 0 HP you fall. |
| 5 | `knownRoad` | The Known Road | 熟路 | Power | 3 (2) | Your hand is dealt at random. |
| 6 | `cleanBreak` | Clean Break | 無痕 | Attack | 2 (2) | Glass that shatters reseams with one more Facet. |

Rules every mythic shares:

- `rarity: "mythic"`. The ids are new and append-only. They freeze when they
  ship, because an unknown content id rejects the whole save.
- No mythic appears in `cardPools`. Every card offer (combat, shop, event) reads
  a tier through `domain/rules/rewards.gd` (`card_pool`), so a tier nobody asks
  for can never be offered. The exclusion is by construction (#206).
- **Clear glass.** No mythic carries way affinity. A mythic never moves the
  Flame's reading, so the flame stays the player's own deck. No Flame or Ash
  content changes (O3).
- The six rules are class-neutral, except Clean Break: Facets exist only in the
  Duskblade's engine (`domain/rules/combat.gd` (`apply_chips`)). 1.0 ships the
  Duskblade only. When the Ashwarden ships, its aspect `excludes` should list
  `cleanBreak`. The mythic pool already honours `excludes` (§2.4).
- No mythic adds a random draw in combat. A fight that resumes restarts from its
  saved start (`application/main.gd` (`_resume_pending_combat`)), so all
  fight-scoped mythic state is rebuilt in the same way every time.
- The petal is the card's place in the six-petal seal on its frame (§5).

### 1.2 Banked Fire (封火) — the guaranteed mythic

| | en | zh-Hant |
|---|---|---|
| Rules | Gain 1 Ember. When this fight ends, your lantern keeps its Embers for the next fight. | 獲得 1 點餘燼。本場戰鬥結束時，提燈保留其餘燼，留待下一場戰鬥。 |
| Upgraded | Gain 2 Embers. When this fight ends, your lantern keeps its Embers for the next fight. | 獲得 2 點餘燼。本場戰鬥結束時，提燈保留其餘燼，留待下一場戰鬥。 |

- **The rule it breaks.** Every fight starts with a dark lantern. That rule is so
  basic that most players never notice it.
- **Why it is subtle and still strong.** The card reads like a modest common. It
  has no headline number. The strength builds over a run: the next fight opens
  with a lit lantern, so the Art is ready on turn one and Ember-priced cards cost
  nothing extra to set up. The player finds this out by playing, not by reading.
- **Why a player shares it.** It is the story card, not a clip card. The player
  shares the third visit to the Knight's monument, where one ember has stayed
  out of the wind (§3). Then, several fights later, the player sees that the
  lantern has not gone out since.
- **Mechanics.** Playing it marks the fight. On a **win** in a marked fight, the
  run stores the lantern's Embers. At the next `start_combat`, after the lantern
  quality is set, the store goes into the lantern through
  `domain/rules/combat.gd` (`_light_lantern`), clamped to that fight's cap. The
  store is **overwritten** at every win (0 when the card was not played). It is
  never added to, and it is never cleared at fight start.
- **Interactions.** Crown of the Hearth heals for the same Embers and they are
  still carried: both apply. Pyreheart and a Steady or True cap raise what is
  carried. A Soot lantern still leaks every turn. Carried Embers enter through
  `_light_lantern`, which takes no tithe, so they do not pay the Hollow
  Lamplighter's Ember debt; they were caught once already.
- **Save and load.** The store lives in `run.quest_scratch["mythic"]["embers"]`
  and is saved with the run. Because it is written only at a win and read (not
  cleared) at fight start, a fight killed and resumed reads the same value.
- **Determinism.** No random draw.

### 1.3 Silvering (鍍銀)

| | en | zh-Hant |
|---|---|---|
| Rules | Choose an enemy. The next time it acts, it does to itself what it meant to do to you. Kindle. | 選擇一名敵人。它下一次行動時，把原本要對你做的事施於自身。燃燼。 |
| Upgraded | Cost 1. | 費用 1。 |

- **The rule it breaks.** An enemy's telegraphed move is aimed at you. The
  intent is the one thing the player cannot change, except by Stagger.
- **Why a player shares it.** The boss raises its biggest blow and breaks itself
  with it. That is a clip.
- **Mechanics.** The chosen enemy's next move resolves with itself as the
  target. Damage uses the enemy's own Fervor, Dimmed and Cracked, then goes
  through `domain/rules/combat.gd` (`hit_enemy`) as a non-attack hit, so the
  player's Fervor never adds to it and the enemy's Splinters do not fire. Statuses
  it would put on you go on itself. Ward and buffs it gives itself are unchanged.
  Cards it would add to your piles are not added. If it is Staggered, the
  reflection waits until it next acts.
- **Interactions.** Edge's Cracked makes the self-hit 50% larger: the natural
  combo. A self-kill counts as a kill (stats, quest drops) because it uses the
  normal death path. The Eternal Keeper's finale handoff still holds: `hit_enemy`
  stops it at 1 HP and starts the handoff.
- **Save and load, determinism.** Fight-scoped flag on the enemy. No random
  draw.

### 1.4 The Unbroken Flame (未碎之火)

| | en | zh-Hant |
|---|---|---|
| Rules | Every flame effect resolves, whatever colour your lantern burns. | 無論提燈燃着哪一種火，每一種火色效果都會生效。 |
| Upgraded | Cost 1. | 費用 1。 |

- **The rule it breaks.** The Flame reads the deck, and only the leading way's
  lit riders fire. Purity is the deepest system a Duskblade player learns.
- **Why a player shares it.** The lantern burns blood-moon, frost-white and amber
  at once. That is a screenshot (§5 asks presentation to draw it).
- **Mechanics.** A fight flag. `domain/rules/combat.gd` (`effect_lit`) returns
  true for every rider while it is set. That covers card riders and the Art's.
  The flame's tier and the lantern's quality do not change: a Soot deck still
  leaks.
- **Interactions.** It frees drafting: a deck can take any way's glass. Crown
  recognition and the Flame reading are unchanged.
- **Save and load, determinism.** Fight-scoped flag. No random draw.

### 1.5 Unbowed (不臥)

| | en | zh-Hant |
|---|---|---|
| Rules | Unplayable. Unless you have Kindled this, the first time each fight you would fall, you stay standing: until the end of your next turn, you cannot lose HP and you cannot play a card that makes you lose HP. If you have 0 HP then, you fall. | 無法打出。若此牌未被燃燼，每場戰鬥中你首次將要倒下時，你仍然站着：直到你下一個回合結束前，你不會失去生命，也不能打出令你失去生命的牌。屆時若生命為 0，你才倒下。 |
| Upgraded | None. Like a curse, it has no `up`. | 無。 |

- **The rule it breaks.** Two rules. At 0 HP you fall. And an unplayable card is
  a curse; this one is the best card in the deck.
- **Why a player shares it.** "I was at 0 HP for a whole turn and won." The
  standing hero is the clip.
- **Mechanics.** In `domain/rules/combat.gd` (`damage_player`), before the
  defeat: if the card is in the draw pile, hand or discard pile (not Kindled) and
  the fight has not used it, set HP to 0 and mark the fight standing until the
  end of turn `cb.turn + 1`. That is the player's next turn, whether the fall
  came in the enemy phase or from your own card. While standing, damage cannot
  lower HP. Healing can raise it. At the end of that turn
  (`domain/rules/combat.gd` (`end_turn`)), if HP is still 0, the fight is lost.
  A win before then goes through `_win_combat`, which already clamps HP to at
  least 1.
- **The HP guard.** While standing, HP cannot be a payment.
  `domain/rules/combat.gd` (`can_play`), the one gate every play passes,
  refuses a card whose resolved effects hold a `loseHp` effect. In the content
  today, `loseHp` exists only on Blood for Oil (`bloodRite`, base and
  upgraded); no relic, potion, Art or other card pays HP in a fight. Without
  the guard, Blood for Oil gives 2 or 3 Energy for nothing while standing, and
  two Tinder+ (`preparation` upgraded: 0 cost, draw 2, no Kindle) bring it back
  every cycle, so the cycle never ends. With the guard, the cycle ends at the
  stand (§7.1, the directed test in §8.2). A later card or relic that pays HP
  in a fight must go through the same check.
- **Interactions.** Smolder, Hex, Cinder and enemy hits are all absorbed while
  standing. Blood for Oil can cause the stand (its `loseHp` resolves first, then
  its Energy), and after that it cannot be played until the deadline. Mendglass,
  Hearthglow and other heals lift the doom if HP is above 0 at the deadline.
  Kindling it gives the usual Ember and removes the protection for that fight: a
  real choice. It works in the Own Shade fight and the final fight.
- **Save and load, determinism.** Fight-scoped flags. No random draw.

### 1.6 The Known Road (熟路)

| | en | zh-Hant |
|---|---|---|
| Rules | At the start of each turn, choose your hand from your draw pile instead of drawing it. | 每個回合開始時，改為從抽牌堆中挑選你的手牌，而不是抽牌。 |
| Upgraded | Cost 2. | 費用 2。 |

- **The rule it breaks.** The deal is random. Every deckbuilder is built on it.
- **Why a player shares it.** The perfect hand, every turn, by choice. It is a
  build screenshot and a "how did you do that" clip.
- **Mechanics: the default deal is the normal draw.** While it is in play,
  `domain/rules/combat.gd` (`_start_player_turn`) runs the normal deal
  (`_draw_from_pile`, the same count `maxi(1, draws)`, covering hand size, omen
  delta, Night Sight and the Traveller's Pack) into a staging list instead of
  the hand. Staged cards count toward the hand cap of 10. So the deal takes the
  draw pile first, from its end, and shuffles the discard (and only the
  discard) only when the pile runs out while a card is still due. The RNG calls
  are the same calls, in the same order, as a normal draw. The staged cards are
  the **default deal**.
- **The pick.** The pool is the staged cards plus the cards left in the draw
  pile after that deal. A new command,
  `GlassvowGame.apply({"t": "chooseHand", "uids": [...]})`, takes exactly as
  many uids as were staged, all from the pool. A pick only swaps places: the
  i-th chosen card that was not staged (in draw-pile order) swaps with the i-th
  staged card that was not chosen (in deal order). The staged card goes back
  into the draw pile at the chosen card's index. No RNG call. The chosen cards
  then enter the hand in deal order, with their `DRAW` events; the `RESHUFFLE`
  event stays where the deal made it. `_tally_drawn` counts the same number as
  a normal draw. Cards drawn later in the turn stay random.
- **Example (the short pile).** Draw pile `[A]`, discard `[B, C]`, a deal of 2.
  The deal takes A, then shuffles B and C (one Fisher–Yates call), then takes
  the pile's end, say C. Default deal {A, C}; B stays in the pile. The player
  may confirm {A, C}, which is the normal draw, or pick {B, C}, which puts A
  back in B's place. Either way the RNG cursor ends where a normal draw leaves
  it.
- **The picker.** It opens with the default deal already selected. Confirming
  at once is an ordinary draw, so the extra taps are only for the player who
  wants them.
- **While the pick is pending,** `GlassvowGame.apply` takes only `chooseHand`:
  no card, potion, Art or end turn. So nothing can draw or call the RNG between
  the deal and the pick.
- **Interactions.** It changes only which cards make up the deal. It adds no
  card, draw or Energy, so it cannot make a finite turn infinite (§7.1).
  Momentum and Phantom Blades become reliable. The hand cap of 10 still holds.
- **Save and load, determinism.** Fight-scoped. A pending pick is never saved:
  a killed fight restarts from its saved start (§1.1). The default deal is the
  normal draw, and a pick calls no RNG, so the RNG cursor after the deal never
  depends on the pick.

### 1.7 Clean Break (無痕)

| | en | zh-Hant |
|---|---|---|
| Rules | Deal @8@ damage. Chip 2 extra Facets. For the rest of this fight, enemies no longer gain a Facet when they shatter. | 造成 @8@ 點傷害。額外琢擊 2 格璃面。本場戰鬥餘下時間，敵人碎裂後不再增加璃面。 |
| Upgraded | Deal @11@ damage. Chip 3 extra Facets. (rest unchanged) | 造成 @11@ 點傷害。額外琢擊 3 格璃面。（其餘不變） |

- **The rule it breaks.** Each shatter reseams the glass harder: the Facet gauge
  grows by one (`domain/rules/combat.gd` (`_shatter_enemy`)). Shatter players
  plan around it.
- **Why a player shares it.** The boss Staggered six turns in a row.
- **Mechanics.** A fight flag. `_shatter_enemy` skips the `facet_max += 1` while
  it is set. The adamant hold still fires once.
- **Interactions.** Beacon, Prism Charm and the Bell of Endings all trigger per
  shatter, so they scale. Vow 3's extra boss Facet still applies at the start.
- **Save and load, determinism.** Fight-scoped flag. No random draw.

### 1.8 Unique in a deck

A deck holds at most one mythic, because a run gets at most one (§2.3). Three
paths could still copy a card, and each is closed:

- **The Bequest.** `application/main.gd` (`_bequest_choices`) ranks cards with
  `application/main.gd` (`RARITY_RANK`). A rarity missing from that map ranks 0
  and is never offered. Leave `mythic` out on purpose, with a comment and a test
  (call 4, §9). The Bequest offers the best non-mythic card instead.
- **The Silvered Mirror's "Reflect"** duplicates a deck card.
  `application/main.gd` (`_show_event_pick`) must not list a mythic for
  `duplicate`, and `application/main.gd` (`_on_event_pick`) must refuse one.
  The balance sim's own event resolver, `tools/balance_sim.gd`
  (`_resolve_event`), needs the same rule.
- **The Developer Console** can add any card. That is a dev surface and stays
  as it is.

A shop may remove a mythic. That does not reopen the run's slot.

---

## 2. The drop

### 2.1 Where a mythic can drop

- **Elite clears only**, in any act, Act IV's one elite included, at Vow 3 or
  above.
- Never from a boss, a normal fight, a shop, an event, a treasure node or the
  Bequest.
- Plus the one story route (§3), which grants Banked Fire.

### 2.2 The rate per vow (O2)

The shipped mix has a curve, so it is used as signed. `tools/vow_incentives.gd`
(`catalog`), row `A_modest_linear`: `[0, 0, 0, 0.02, 0.03, 0.05]` per elite
clear, plus 1 pp once Act IV has been cleared (`"stack"`).

| Vow | Per elite | Per elite after Act IV | Any mythic in a run, 3 elites | 6 elites |
|---|---|---|---|---|
| 0–2 | 0 | 0 | 0 | 0 |
| 3 | 2% | 3% | 5.9% (8.7% after IV) | 11.4% (16.7%) |
| 4 | 3% | 4% | 8.7% (11.5%) | 16.7% (21.7%) |
| 5 | 5% | 6% | 14.3% (16.9%) | 26.5% (31.0%) |

The run columns are arithmetic, `1 - (1 - r)^E`, not measurements. Three and
six elites per run are two illustrative routes; how many elites a real route
meets is not measured here (lane 6 can count it). A specific mythic is one fifth
or one sixth of these figures (§2.4).

**A leak to close.** `tools/vow_incentives.gd` (`mythic_rate`) adds the post-Act-IV
delta to whatever the rung holds, so at Vow 0 after Act IV it returns 0.01. That
would roll mythics below the Vow 3 gate and break O1 for every profile that has
cleared Act IV. The fix: `mythic_rate` returns 0 whenever the rung's own rate is
0. Nothing live calls it today, and the bake-off never rolled it, so no recorded
number moves.

"Act IV cleared" is `run.unlocks.has(RunState.MIRRORED_ROAD)` at run start. The
Vigil folds that unlock in at the first Act IV clear. A run cannot change it
after an elite: the Act IV win ends the run.

### 2.3 One per run

- The run's slot is `run.quest_scratch["mythic"]`, a dictionary
  `{"id", "via", "embers"}`. It is written when a mythic is rolled or granted.
  `quest_scratch` is saved with the run and already carries run-wide flags
  (`seenEvents`), so this needs no new save field.
- The slot is **open** only when that key is absent **and** the deck holds no
  mythic. Both are checked before any random draw.
- After the slot closes, later elites make no mythic draw at all.

### 2.4 The roll (O1 by construction)

In `domain/rules/rewards.gd` (`gen_combat_rewards`), after the relic draws,
with the same short-circuit shape as the existing second-relic roll:

```
if kind == "elite" and mythic_rate > 0.0 and _mythic_open(run):
    var pool := _mythic_pool(run)          # no draw
    if not pool.is_empty() and run.rng.next() < mythic_rate:
        var id: String = pool[run.rng.pick_index(pool.size())]
        out["mythic"] = id
        run.quest_scratch["mythic"] = {"id": id, "via": "elite"}
```

- `mythic_rate` is a new `RewardRules` knob, identity 0.0. `tools/vow_incentives.gd`
  (`apply`) sets it from `mythic_rate(mix, vow, post_act4)`. `domain/game.gd`
  (in `_init`) passes `post_act4`.
- `_mythic_pool(run)`: every card of rarity `mythic`, sorted by id (a fixed
  order), minus the aspect's `excludes` (`domain/rules/rewards.gd` (`_excluded`)),
  minus cards in the deck, minus `bankedFire` until the Knight's route is
  complete (call 3), minus `unbrokenFlame` until the profile has cleared Act IV
  (§2.7, call 16).
- Uniform pick. No pity counter: a scheduled reward is not one anybody posts.

**Why Vow 0–2 cannot move.** The rate is 0 at Vow 0–2 for every profile (with
the leak closed). The guard `mythic_rate > 0.0` comes before the first draw.
Mythic cards are in no pool. The Knight seam (§3.4) is gated on `run.vow >= 3`
before it touches anything. So below Vow 3 no draw is consumed and no offer can
change.

**How a test proves it.**

1. `apply()` at Vow 0, 1 and 2, with and without `mirroredRoad`, leaves
   `mythic_rate == 0.0`. Mutation check: remove the zero-rung gate and the
   post-Act-IV Vow 0 case must fail.
2. Positive control: at Vow 3 with the rate forced to 1.0, an elite reward
   advances `run.rng_state()` by exactly two more draws (roll and pick) than with
   the rate at 0. This shows the test can see a draw.
3. The whole-game proof: on the implementation head, the Vow 0 balance digests
   `tests/test_balance_sim.gd` (`EXPECTED`) and (`EXPECTED_UNLIT`) and every
   `port_fixtures/` trace pass unchanged. Every `"vow"` field in
   `port_fixtures/` (33 of them) is 0.
4. A Vow 2 run whose profile has the Knight's route at step 0, 1 or 2 rolls its
   first event exactly as a fresh Vow 2 run does, and stages no scene.

### 2.5 How the drop is handed over

The mythic is a **Spoil**, not part of the Offering. CONCEPTS.md defines Spoils
as handed over, not chosen. It is laid on the husk with the relic, banked when
the player walks on (`application/main.gd` (`_on_reward_finished`)), and never
declined. The pending reward carries `rewards.mythic`, an additive key next to
the existing `relic2`, with `taken.mythic`. `application/main.gd`
(`_on_reward_claimed`) gains a `mythic` branch that appends the card.

Load validation: `domain/state/run_state.gd` (`_valid_pending_reward`) accepts a
missing or null `mythic` and otherwise requires a known card of rarity `mythic`.
An old save has no key and loads unchanged. `SAVE_VERSION` stays 2.

### 2.6 The Bequest

**Decision: a mythic cannot be bequeathed.** The Bequest offers the best
non-mythic card (§1.8). Reasons: #206 rejected routing mythics through the
Bequest, because a player could then farm deaths to keep one. And a mythic that
crosses runs would break "at most one per run" for the next run. In the fiction
the card stays with the fallen walker; nothing on screen needs to say so.

### 2.7 The full set waits for Act IV

The settled #210 resolution (repeated on #212): "Full-set collection therefore
requires **Vow 3 and** an Act IV clear; a lucky player may still see a mythic
before Act IV." Without a gate, all five chance mythics can drop before Act IV,
and the Knight's route gives Banked Fire at Vow 3. So a Vow 3 profile
could own all six without the clear.

**The rule.** The Unbroken Flame joins the elite pool only when
`run.unlocks.has(RunState.MIRRORED_ROAD)` at run start: the profile has cleared
Act IV at least once (§2.2). Before that, only five of the six can ever reach a
deck (four by elite roll, Banked Fire by the route), so the set cannot be
complete. A lucky player still sees mythics before Act IV.

Why this card: its fragment is "Before it was six, it was one" (§4.1). The
player who has stood at the door finds the fire whole. The gate needs no new
state and no draw: `_mythic_pool` is built before the roll, so the RNG calls do
not change; only the pool the pick reads changes, and only at Vow 3 and above.

**The test.** `test_mythic_drop` › `full set needs the Act IV clear` (§8.2).

---

## 3. The side quest: the Knight's ember

### 3.1 The idea

The shipped Wounded Knight event (`assets/art/events/woundedKnight.png`) shows a
knight near death against a shattered pillar. All three choices (Aid him, Loot
him, Leave) end with him on his feet, and the shipped coda follows each one:
"The next time you come by, there is a monument at the foot of the pillar"
(foreshadow ledger rows 377–380).

At Vow 3 the route keeps that promise. The player comes by again, twice. The
monument stands in the wind, and in its lee one ember has not blown away. On the
third visit the player takes it into the lantern, and it is Banked Fire.

- **It fits the shipped outcome.** Meeting one is the shipped event, unchanged.
  Meetings two and three happen at the monument. The Knight never speaks again,
  so the route adds no line in his voice and no cast or truth row.
- **It keeps row 380's two readings open.** At L1 the monument is either one
  that someone set up for him or his own body (`00-truth.md` §3,
  [SETTLED — #258 R1 Q1A]; the #340 choice recorded on row 380). The route says
  only what a passer-by sees.
- **It adds no canon fact.** Embers drift west on the wind (`00-truth.md` §2,
  [SETTLED — #258 R2 Q8]). An ember out of the wind does not drift. That is
  plain physics.
- **Vow 0–2 see the shipped event unchanged**, and so does Vow 3: the route adds
  only the two later visits. No shipped asset or event text changes. No
  route-only coda override is needed.

### 3.2 Gate, steps and nodes

| Step | When | Where | What happens | Progress mark |
|---|---|---|---|---|
| 0 → 1 | A run at Vow ≥ 3 | The first event node the run enters | The shipped `woundedKnight` event, forced in place of the roll, with its shipped copy and coda. Choosing **Aid him** (choice 0) advances the route. No new line. | Once-flag `knight-1` (no scene) |
| 1 → 2 | A later run at Vow ≥ 3 | The first event node | Scene `knight-2` in place of the event: the monument, and the ember in its lee. | `knight-2` |
| 2 → 3 | A later run at Vow ≥ 3, with the run's mythic slot open | The first event node | Scene `knight-3`. Its last beat grants Banked Fire. | `knight-3` |

- **The Vow 3 gate.** `run.vow >= 3`, the value fixed at run start. Below Vow 3
  the route is dormant and the event behaves exactly as today.
- **At most one meeting per run** (`quest_scratch["knight"]["met"]`, §3.4).
- **Why only Aid him advances.** All three choices end at the monument. The
  route follows the player who stopped for him.
- **Continuity.** At Vow ≥ 3, once the route has reached step 1, the run starts
  with `woundedKnight` already in `quest_scratch["seenEvents"]`, so the slumped
  knight never appears beside the monument. This reuses the existing no-repeat
  mechanism and is gated on the vow, so Vow 0–2 rolls do not change.
- **No Knight scene at a Lamplighter node.** A node where the Hollow
  Lamplighter met the player already uses `pending_scene` for his scenes. A
  Knight scene due there waits for the next event node (§3.4). The forced
  step-0 event is an event, so it can still occur there.

### 3.3 Reward, failure and abandon

- **Reward.** Banked Fire, granted on the last beat of `knight-3`. It fills the
  run's mythic slot (`via: "knight"`).
- **Loot him or Leave** at step 0: no advance. The event is forced again at the
  next Vow ≥ 3 run's first event node.
- **No event node** in a run: no advance. The route waits.
- **Death or abandon after a meeting:** the meeting counts. The flag is written
  when the meeting ends (§3.4), so it outlives the run.
- **Killed mid-scene:** the run still holds `pending_scene` and the uncleared
  node, and resume replays the scene from its cursor (§3.4).
- **The run's slot is already used** when step 2 is due: `knight-3` is not
  staged this run. It waits for a run with an open slot.
- **After completion** the route never plays again. Banked Fire then joins the
  elite pool (call 3).

### 3.4 How it is built (O4)

`domain/rules/quests.gd` is the home of quest rules, but its state machine is
the six Emberglass journeys: `domain/state/vigil_state.gd` (`QUEST_IDS`) is fixed
at six, and each completion lights a pane and grants a Shard. A seventh entry
would light a seventh pane. So the route reuses the module's seam pattern (as
`domain/rules/quests.gd` (`stage_hollow_meeting`) stages the Lamplighter), not
its state machine.

**Progress (Vigil).** The once-flags `knight-1`, `knight-2` and `knight-3` in
`domain/state/vigil_state.gd` (`scenes_seen`). The Vigil load keeps any
non-empty id there, and no code lists the flags, so `knight-1`, which has no
scene, is a plain once-flag. No new Vigil field.

**Run start.** `application/main.gd` (`_new_run`) adds `"knight": n` (flags
seen) to the profile. `domain/state/run_state.gd` (`new_run`) copies it into
`quest_scratch["knight"] = {"step": n, "met": false}`.

**Domain seams.** Pure, no draw. Each checks `run.vow >= 3` first and does
nothing below it.

| Seam | What it does |
|---|---|
| `domain/rules/rewards.gd` (`roll_event`) | At step 0 with `met` false: sets `met`, adds `woundedKnight` to `seenEvents` and returns it **before** its own draw. It still returns only event ids, so both callers keep their `content.events` lookup. |
| `QuestRules.knight_aid_flag(run, event_id, choice)` | Returns `knight-1` at step 0 for `woundedKnight`, choice 0; else "". |
| `QuestRules.stage_knight_scene(run)` | With `met` false: returns `knight-2` at step 1, or `knight-3` at step 2 when the run's mythic slot is open (§2.3), and sets `met`. Else returns "" and changes nothing. |
| `QuestRules.finish_knight_meeting(run, scene_id)` | For `knight-3`: appends Banked Fire **if the deck holds no mythic**, and sets the slot `{"id": "bankedFire", "via": "knight"}`. A replay grants nothing twice. |

**The scene seam in `application/main.gd`.** `_show_event` and
`_stage_hollow_exit` both call `roll_event` and keep its result as
`eventNode`, and the event screen then indexes `content.events` with it. A
scene id must never reach that lookup, so the scene path branches before the
roll:

1. **Meeting one's flag.** `_on_event_choice`, after the choice's ops apply,
   asks `knight_aid_flag`. If it returns the flag, main appends it to
   `scenes_seen`, stores the Vigil, then stores the run (the order
   `_on_scene_finished` uses). A kill between the two stores replays the event
   choice; the flag already holds, so the route advances once.
2. **Before the roll.** `_show_event`, when `eventNode` is empty, calls a new
   `_stage_knight_scene()` before `roll_event`. If `stage_knight_scene` returns
   an id, main sets `pending_scene = {"id": id, "cursor": 0}`, stores the run
   (on failure it undoes `pending_scene` and `met` and shows the save error)
   and calls `_show_scene`. No `eventNode` is written, so
   `_dispatch_current_route` never looks up a scene id in `content.events`.
3. **Not at the Lamplighter's exit.** `_stage_hollow_exit` does not call it
   (§3.2).
4. **Resume.** `_route_run` shows a `pending_scene` before any route dispatch,
   so a killed meeting replays from its cursor.
5. **Completion.** `_stage_after_scene` gains a `knight-` branch. It calls
   `finish_knight_meeting`, then completes the node with the state half of
   `_finish_node` (clear the current node, write `run.map`, erase the route
   scratch, clear `pending_hollow_route`), split out as a helper that does not
   store. The one Vigil-then-run store at the end of `_on_scene_finished` then
   writes the flag, the card and the cleared node together. A kill between the
   two stores leaves the disk run on the scene and the node; resume replays the
   scene, and the deck check stops a second grant. After the store,
   `_route_run` shows the map.

**The persisted continuation**, in short: `pending_scene` and the uncleared node
are the whole continuation. Both are already in the run save. The meeting's own
completion write clears them.

**The simulator** (`tools/balance_sim.gd` (`_resolve_event`)). Before
`roll_event`, it calls `stage_knight_scene`. If that returns an id, it calls
`finish_knight_meeting` and returns: the node is done, and no event is looked
up. The forced step-0 event needs no change there, because it is an event. The
simulator plays no scenes, so this is its whole path.

**Ownership.** Lane 3 owns all of §3.4: the domain seams, the `main.gd`
dispatch and completion, and the simulator's path. The simulator's path lands
in the same PR as the seam, so no Vow 3 simulator run can meet a scene id it
cannot resolve. Lane 6 also edits `tools/balance_sim.gd`, so it follows lane 3
(§8.1).

**Scenes** are data in `content/scenes.json`. Meetings two and three must not
reuse `events/woundedKnight.png`, because it shows him alive. Until the owner
picks a monument plate (new scene assets allowed under the #263 rule, owner
pick), they play plate-less over the act's stage backdrop, as the scene player
already does for a scene without a plate (`application/main.gd`
(`_scene_plate_act`)). Call 17.

### 3.5 Scene beats and lines [PROPOSED]

Ceiling L1 (event scripts, `docs/story/04-delivery.md`). Meeting one is the
shipped event: no new line. Forbidden in `knight-2` and `knight-3`: any line in
the Knight's voice; any line that says or implies whose monument it is (row 380
keeps both readings); 凝; 隊伍 / queue; 行者 / walker; 死 / die; any vertical
word. 碑 / monument is allowed: the shipped coda already names it at L1.

**`knight-2`**

1. Beat: the shattered pillar. At its foot, the monument. Wind crosses the road
   and carries ash west.
2. Narration: 「石柱前那座碑仍在。」 / "The monument is still at the foot of the
   pillar."
3. Beat: in the monument's lee, out of the wind, one ember glows under a skin of
   ash.
4. Narration: 「風吹不到碑腳。那一點火，沒有被吹走。」 / "The wind does not
   reach the foot of the monument. That one ember has not blown away."

**`knight-3`**

1. Beat: the pillar, the monument, the ember in its lee. The ash has fallen from
   it.
2. Narration: 「它還在。」 / "It is still there."
3. Beat (tap): you lift the ember into your lantern. The card turns to face you:
   Banked Fire on the M0 frame, its Lantern hologram cold until you tilt it.
4. Narration: 「仍有餘溫。」 / "Still warm."

**The two readings.** Surface: a stone breaks the wind, and one coal survives.
After the twist: he still stands between the wind and the fire. No line says
which. Both readings go through the twist-safety pass (§4.3).

---

## 4. The story bundle

### 4.1 One bundle per card

Every mythic carries a **fragment**: one unattributed line shown under the card
when it is revealed (§5) and in the card's inspect view. It is a new optional
card field, `lore`, with its zh leaf `content.cards.<id>.lore`. Channel: card
lore, ceiling L1.

| Card | Bundle | Fragment (zh / en) | Anchor in canon |
|---|---|---|---|
| Banked Fire | **Quest** (§3) + fragment | 仍有餘溫。風吹不到碑腳。 / Still warm. The wind does not reach the foot of the monument. | The shipped coda (ledger row 380); embers drift west on the wind (`00-truth.md` §2, [SETTLED — #258 R2 Q8]); fire = will (`00-truth.md` §8.6, [SETTLED #259]) |
| Silvering | **Event** anchor + fragment | 鏡子從不先動。這一次，它把那一擊還了回去。 / A mirror never moves first. This time, it gave the blow back. | The Silvered Mirror, 鍍銀之鏡 (ledger row 14, L1); `mirror.png` (row 10) |
| The Unbroken Flame | Fragment | 成為六片之前，它是一團。 / Before it was six, it was one. | The surface legend of one fire and six shards (`00-truth.md` §5 note; ledger row 20) |
| Unbowed | **Whisper** anchor + fragment | 有些人，始終沒有躺下。 / Some of them never lay down. | Whisper 11 (ledger row 1); Page 3 (row 9) |
| The Known Road | **Whisper** anchor + fragment | 這段路你走過。你很肯定。 / You have walked this before. You are sure of it. | Whisper 9 (row 11); the stayer inherits every memory (`00-truth.md` §3.2) |
| Clean Break | Fragment | 切得乾淨，它便記不住。 / Cut it clean and it cannot remember. | Glass = memory (`00-truth.md` §8.6) |

No new whisper is written: the 24 are the walkers' last words in queue order and
are fixed.

### 4.2 Canon check

- **No new canon fact.** Every fragment leans on settled physics, shipped
  whispers, the surface legend or the shipped mirror motif. None leans on an
  [OPEN] item.
- **No new character arc.** The Knight's route fits his shipped death (rows
  377–380): meeting one is the shipped event, and meetings two and three are
  narration at his monument. He has no new line, so the route needs no voice
  sheet and no information-matrix row. The copy still goes through the batch
  (§4.4).
- **Row 380 stays open.** No route line says whose monument it is, so both L1
  readings survive (§3.5).
- **One reading to lint.** The post-twist reading of `knight-2` and Banked
  Fire's fragment is "what he kept from the wind outlasts him" (fire = will).
  Canon lint must confirm that this stays a reading and does not contradict
  "the fire goes west, back to the hearth" (ledger row 303). If it does, cut
  the post-twist reading to the surface one; the lines stand on the surface
  alone.
- **Keeper rules.** No Keeper line is written. The Keeper's rules (never lies,
  never urges departure, never claims a step) are not touched.
- **Vocabulary.** No banned vertical word. zh uses 着 and 裏 (燃着, 擋着, 站着,
  提燈裏). Register is Hong Kong 書面語; no 口語.

### 4.3 Ledger rows to append

The story lane appends these to `docs/story/05-foreshadow-ledger.md` under a new
section, renumbered against the ledger at that time (parallel sessions collide on
row ids).

| Line | Source | Level | Surface reading | After the twist | Leak risk |
|---|---|---|---|---|---|
| 封火 / Banked Fire + fragment | `bankedFire` name, lore | L1 | A coal kept alive out of the wind. | What he kept from the wind outlasts him (§4.2, lint item). | Low–medium: twist-safety pass |
| 鍍銀 / Silvering + fragment | `silvering` name, lore | L1 | A mirror throws a blow back. | "Never moves first": the one behind the glass has never walked first, until the finale. | Low–medium: twist-safety pass |
| 未碎之火 + fragment | `unbrokenFlame` name, lore | L1 | The legend of six from one. | The whole fire the door asks for. | None |
| 不臥 / Unbowed + fragment | `unbowed` name, lore | L1 | Brave pilgrims who would not yield. | The walkers died standing. Same weight as whisper 11. | Low |
| 熟路 / The Known Road + fragment | `knownRoad` name, lore | L1 | Déjà vu. | The stayer never walked; the memory is second-hand, and "you are sure" is the illusion. | Medium: twist-safety pass |
| 無痕 / Clean Break + fragment | `cleanBreak` name, lore | L1 | Glazier's craft. | Glass is memory: a clean cut leaves none. | Low |
| 石柱前那座碑仍在。 | `knight-2` | L1 | The coda's monument is still there. | His only body still stands (`00-truth.md` §3), unread. Both row-380 readings stay open. | Low |
| 風吹不到碑腳。那一點火，沒有被吹走。 | `knight-2` | L1 | A stone breaks the wind, and one ember stays. | He still stands between the wind and the fire. No line says so. | Low–medium: twist-safety pass |
| 它還在。 | `knight-3` | L1 | The ember waited. | It waited in the lee of what still stands. No line says what that is. | Low |
| 仍有餘溫。 | `knight-3`, Banked Fire lore | L1 | The coal is warm. | What he kept from the wind outlasts him (§4.2, lint item). | Low |

Meeting one adds no line, so the shipped rows 377–380 are unchanged.

### 4.4 The copy pipeline

The story lane runs the batch workflow (`.claude/workflows/story-draft.js`):
brief, draft against the bible, canon lint, twist safety, adversarial blocker
check, then promotion. Only then do the strings enter `content/full-content.json`
(en) and `locale/zh-Hant.json` (zh). Also add `ui.rarity.mythic` (en "Mythic",
zh 秘藏) to both locales. New zh characters must pass
`tools/check_locale_font_coverage.py`; rebuild the subsets with
`tools/subset_noto_serif_tc.py` if they do not.

---

## 5. The visual

### 5.1 The shared grade

Frame **M0**, the owner's pick (14 October): the leaded sapphire and amber frame
from the holo design, with the cost crystal standing above the frame and
glowing. The toolkit and M0 are kept on branch `research/cards-holo-2026-10-14`
at `b16c1501`: `research/holo/shaders/mythic_toolkit.gdshaderinc` (with
`myth_gem` for the crystal), `mythic_frames.gdshaderinc`, and the three example
shaders `mythic_lantern`, `mythic_door` and `mythic_shade`.

- **The six-petal seal** on the rule under the art window lights **this card's
  petal** (§1.1). Every mythic therefore says there are six, without a word of
  tutorial. If the set grows to ten, the next four get a second seal (call 9).
- **Rank, not concealment.** #177 recorded that 秘藏 reads as concealment, not as
  a rank above 稀有. The frame and the seal carry the rank. No extra banner text
  is added.
- Unbowed has no cost. Its crystal stays in place, unlit.
- Wiring: `presentation/cards/card_holo.gd` (`BY_RARITY`) gains `mythic`;
  the per-card recipe goes through `presentation/combat/card_surface.gd`
  (`BY_CARD`), the seam left for exactly this. `presentation/combat/card_view.gd`
  (`_is_rare`) must not paint the rare gilt on a mythic.

### 5.2 One hologram per card

All are angle-driven (CONCEPTS.md, "Angle, not time"), use at most 2 samplers,
add no pass and make no backbuffer copy, as the holo design measured.

| Card | Hologram | From | What the lean does |
|---|---|---|---|
| Banked Fire | **Lantern** | Toolkit, as built | The art sits cold. Past the threshold lean the banked coal flares white-hot under its ash, warmth floods the window and the frame turns amber. |
| Silvering | **Shade** | Toolkit, as built | A pale copy of the picture lags half a breath behind, the other way. At a hard lean the copy steps over the picture. |
| The Unbroken Flame | **Six into one** | New, from toolkit parts | A six-petal mask holds six coloured shards (the three way colours, twice). At rest they sit apart. At one lean they slide into one white-gold flame. Motes drift in front. |
| Unbowed | **Will not tilt** | New, `myth_window` with inverse parallax | The frame leans with the card; the picture holds level, so the figure stays upright whatever the tilt. No mask, so no third sampler. |
| The Known Road | **Door** | Toolkit, as built | An arched door's shadow swings with the lean. At the far lean the door opens a slit of light. |
| Clean Break | **Clean seam** | New, `myth_reveal` with a fracture mask | One straight fracture lights as a bright seam at one lean and vanishes completely at the other. |

### 5.3 Moments presentation must draw

- **The reveal.** The mythic lies on the husk as a Spoil, larger than a relic,
  with its fragment beneath. That frame is the screenshot.
- **The Unbroken Flame in play.** The combat lantern burns all three colours.
- **Silvering.** The chosen enemy's intent glyph turns to face it.
- **Unbowed.** The hero does not fall: a glazed, still hero plate with HP at 0,
  until the deadline. A card that makes you lose HP shows as unplayable while
  the hero stands, as a card you cannot afford does.
- **The Known Road.** The hand picker (§1.6).
- **Banked Fire.** Nothing announces it. The next fight opens with the lantern
  already lit.

A reveal sound reuses an existing cue. A new SFX goes through
`docs/sfx-ledger.md` with an owner audition. No new music.

---

## 6. The six art briefs

Common to all six: one plate per card at `assets/art/cards/<id>.jpg`, 2048×1374
JPEG, landed as the 30 September plates were (`docs/art-ledger.md`, the Edge-way
card art section). The prompt follows the card-art template and the style block
that `docs/art-ledger.md` › "Where the prompts live" names, with the style master
and two shipped cards as style references. Stained glass with heavy lead lines,
one focal light, deep saturated colour. **No text, letters, numerals or
glyphs.** Walkers are faceless. Each plate must read on the 148×91 art window
crop and on a 64 px thumbnail. Two candidates per card in different
compositions; the owner picks; nothing enters `assets/` before that.

1. **Banked Fire.** Low and close: the foot of a weathered upright stone at the
   base of a shattered pillar. Grey ash streams across the frame on a hard
   diagonal. In the stone's lee, on the ground, one coal glows under a skin of
   ash: banked, not blazing. The coal sits on the left-centre third; the stone
   fills the right half. No figure, no armour, no inscription, and the stone has
   no human shape (row 380's two readings stay open). Palette: a cold blue-grey
   world, and the coal's amber is the only warm colour, so the Lantern
   hologram's cold-to-warm reveal reads. No flame tongue: the hologram supplies
   the flare. At 64 px: one amber point in blue dark.
2. **Silvering.** A tall arched mirror in a leaded frame on a rubble floor. A
   hooded walker stands before it, back to us. In the glass the reflection is
   half a step out of pose: its blade is already raised while the walker's is
   lowered. Palette: silver-blue and cold white, with one blood-moon crimson
   line on the reflection's blade (Edge). Leave clear space on the right for the
   Shade hologram's lagging copy. At 64 px: the arched mirror's outline.
3. **The Unbroken Flame.** One flame inside a lantern whose glass is a six-lobed
   rose. The six panes are amber, frost-white and blood-moon crimson, twice, and
   all their light runs into one white-gold core. Centred and symmetrical, rose
   window geometry, dark surround. At 64 px: a six-lobed light with a white
   centre.
4. **Unbowed.** A lone armoured walker standing upright on a road at dusk, sword
   point down, cloak torn, completely still. Ash and wind sweep across the frame
   on a hard diagonal: the world leans, the figure does not. Rim light from
   behind. Palette: ash grey with an ember-orange rim. At 64 px: a vertical
   figure against a diagonal sweep.
5. **The Known Road.** A road of leaded-glass slabs running to a small arched
   door on the horizon, one-point perspective, low horizon. On the slabs ahead,
   faint footprints of pale gold light are already there. A slit of light at the
   door. Palette: deep blue night and pale gold. At 64 px: converging lines to a
   bright slit.
6. **Clean Break.** A pane of frost-white glass split by one perfectly straight
   fracture, no splinters, the two halves offset by a hair. A blade's edge has
   just left the cut. Cold blue-white light comes through the gap (Shatter's
   colour). Palette: frost-white and steel blue. At 64 px: one bright diagonal
   line across a pane.

Check `tools/payload_budget.json` (the `assets/art/cards` group) with
`tools/payload_report.py` when the six plates land.

---

## 7. The balance check

### 7.1 By reasoning

**The structural guard.** One mythic per run means two mythics never meet. No
combination of mythics needs a guard: Silvering with Clean Break, for example,
cannot happen.

**What "finite" means here.** The first draft said that every 0-cost draw and
Energy card Kindles. That is false. Tinder+ (`preparation` upgraded) and Dim the
Glass+ (`dimTheGlass` upgraded) are 0-cost draw cards that do not Kindle, and
Blood for Oil (`bloodRite`) is a 0-cost Energy card that does not Kindle. Two
such draw cards can already cycle each other in the base game when the other
cards stay in hand. That is a base-game property and out of scope here. The
claim for the mythics is narrower, and it holds by construction:

- No mythic adds a draw, an Energy source or a card. No lit rider in
  `content/full-content.json` gives draw or Energy (of those kinds, only
  Ember riders exist, and Embers are capped), so the Unbroken Flame, which
  lights every rider, adds neither.
- In the base game, Blood for Oil's Energy is bounded by HP: each play costs 3
  HP, and 0 HP ends the fight. Unbowed is the only mythic that lifts a bound the
  base game relies on, and its guard puts that bound back: while standing, no
  card that makes you lose HP can be played (§1.5).
- The Known Road changes only which cards make up the deal (§1.6).

| Card | Degenerate line | Softlock | Infinite turn | Guard |
|---|---|---|---|---|
| Banked Fire | Turn-one Art in every fight; Crown of the Hearth heals and carries the same Embers. Accepted: subtle-overpowered is the brief. | None | None | Carry clamped to the next fight's cap; store overwritten, never added; written only on a win; read, not cleared, at fight start. |
| Silvering | Bosses with big telegraphs kill themselves. Accepted. | None: a Staggered target's reflection waits until it acts. | None: Kindle, and one copy per deck. | Non-attack self-hit through `hit_enemy`, so the finale handoff holds; card-adding parts are dropped. |
| The Unbroken Flame | Draft anything; every rider fires. Accepted. | None | None: no lit rider gives draw or Energy. | Only riders change; tier and lantern quality do not. |
| Unbowed | Fall on purpose for a turn of immunity. Accepted. | None: the deadline always resolves the fight. | None. While standing, HP is no payment, so the Blood for Oil and Tinder+ cycle ends at the stand (directed test, §8.2). | Kindle disables it; while standing, `can_play` refuses any card with a `loseHp` effect; HP cannot fall below 0; the normal win path sets HP to 1. |
| The Known Road | A perfect hand every turn. Accepted. | A pool smaller than the deal: the deal takes what exists, as today. Empty piles give an empty hand, as today. | None added: it changes only which cards make up the deal, and later draws stay random. | The default deal is the normal draw (same cards, same RNG calls, same order); a pick only swaps cards with the draw pile and calls no RNG; while the pick is pending, `apply` takes only `chooseHand`; uids validated against the pool; hand cap 10. |
| Clean Break | A strong Shatter deck Staggers an enemy every turn, so it never acts. A player win, not a softlock. Accepted. | None | None | Fight-scoped; the adamant hold still fires once. |

### 7.2 What the implementation lane must run

- **Forced arms.** For each of the six mythics, put it in the starting deck and
  run the balance sim at Vow 3, 4 and 5: Duskblade, the default pilot, 200 seeds
  per cell (for example seeds 9000–9199). Run a control arm without a mythic on
  the same seeds. Set the sim profile's Knight route to complete, so the route
  does not change the event rolls. `--jobs 4` or fewer, one batch at a time (the
  Mac is shared with ks2's CI).
- **Natural-drop arm.** Vow 5, 1,000 seeds, no forcing, a profile without the
  Act IV clear. The roll stops after the first mythic of a run, so elite clears
  are the wrong denominator. For each elite clear, record whether a roll was
  made (the guard passed and the pool was not empty: an **eligible roll
  attempt**) and the rate it used. The expected offer count is the sum of those
  rates, and its standard deviation is the square root of the sum of
  `r × (1 − r)`. At Vow 5 before the clear every rate is 5%. Also count The
  Unbroken Flame's offers: there must be zero (§2.7). And Vow 2, 200 seeds:
  there must be zero eligible attempts and zero offers.
- **Sim support** (§8, lane 6): a `--mythic=<id>` option, the pilot's play rule
  for each mythic (Silvering targets the largest incoming hit; the Known Road
  picks by the pilot's card score), the eligible-attempt record, and the
  invariant checks below.

**A failure is any of these:**

- an `error` outcome, or a `stall` that the control arm does not have on the
  same seed;
- the same seed giving two different digests;
- the Vow 0 digests (`EXPECTED`, `EXPECTED_UNLIT`) moving, or any `port_fixtures/`
  trace changing;
- a mythic offered at Vow 0–2, or appearing in a shop, an event or the normal
  Offering;
- The Unbroken Flame offered to a profile without the Act IV clear;
- two mythics in one deck;
- Embers above the lantern's cap, a hand above 10, or HP below 0 at a fight's
  end;
- the natural-drop offer count outside three standard deviations of the count
  expected over the eligible roll attempts.

**Information only:** win rate, turns per fight, HP at each act's end, deck
size, deaths by act. Win-rate deltas do not fail anything.

---

## 8. The implementation plan

### 8.1 Lanes and file ownership

One owner, one branch and one PR per lane. Lanes that share a file run in
sequence, never in parallel.

| # | Lane | Owns | Needs | Proof |
|---|---|---|---|---|
| 1 | **Story copy** | `docs/story/05-foreshadow-ledger.md`, a batch file under `docs/story/batches/` | Nothing; starts at once (the route adds no cast or truth row) | The story-draft workflow; `tools/check_anchors.py` |
| 2 | **Tier, drop and the six rules** | `content/full-content.json` (six rows), `locale/en.json`, `locale/zh-Hant.json` (card leaves, `ui.rarity.mythic`), `tools/vow_incentives.gd`, `domain/game.gd`, `domain/rules/rewards.gd` (roll), `domain/rules/combat.gd`, `domain/state/combat_state.gd`, `domain/state/run_state.gd` (`_valid_pending_reward`), `content/content_db.gd`, `application/main.gd` (Bequest, duplicate, reward claim, `chooseHand` routing), font subsets | Lane 1's promoted strings | The core Godot gate; new tests (§8.2); the counts (§8.3) |
| 3 | **The Knight's route** | `domain/rules/quests.gd` (`knight_aid_flag`, `stage_knight_scene`, `finish_knight_meeting`), `domain/rules/rewards.gd` (the `roll_event` seam only), `domain/state/run_state.gd` (`new_run`), `content/scenes.json`, scene locale leaves, `application/main.gd` (`_new_run`, `_show_event`, `_on_event_choice`, `_stage_after_scene`, the `_finish_node` split), `tools/balance_sim.gd` (`_resolve_event`, the Knight path only) | Lanes 1 and 2 merged | The core gate; route tests; scene stills at three shapes |
| 4 | **Presentation** | `presentation/cards/` (M0, the six recipes, from `b16c1501`), `presentation/combat/card_view.gd`, `presentation/combat/card_surface.gd`, `presentation/reward/`, the combat screen's lantern, intent, standing and hand-picker views, `presentation/lab/card_lab.gd` | Lane 2 merged (faces can start earlier in the lab with stand-in art) | Stills at the three reference shapes, looked at; an A12 iPad combat-frame read with a mythic in hand (QA app, shared lock) |
| 5 | **Art** | Candidate plates and contact sheets under `docs/reviews/`; after the owner's pick, `assets/art/cards/<id>.jpg` and a `docs/art-ledger.md` entry | Nothing; starts at once | Owner pick; the payload report |
| 6 | **Balance read** | `tools/balance_sim.gd` (all but the Knight path), `tools/balance_pilot.gd`, `tools/balance_policy.gd` (a `mythic` rarity value) | Lanes 2 and 3 merged | The runs and failure rules of §7.2 |

Order: 1 and 5 start now. 2 follows 1. 3, 4 and 6 follow 2. 3 and 4 both touch
`application/main.gd`, so run them in sequence. 6 follows 3, because both touch
`tools/balance_sim.gd`.

`domain/rules/combat.gd` gains six small mechanics in lane 2. If the lane's diff
there passes 600 lines in one commit, split the commit (CLAUDE.md stop
condition).

### 8.2 Tests

New tests, each able to fail:

- **`test_mythic_drop`**: the four O1 checks (§2.4); one per run (rate forced to
  1.0: the first elite offers, the second does not; a deck holding a mythic gets
  no offer); the slot survives `to_save_dict` / `from_save_dict`; no mythic in
  any `cardPools` tier and none from `offer_cards` or `roll_event_cards`; the
  Bequest offers the rare, never the mythic; the duplicate pick excludes a
  mythic; a pending reward with a mythic round-trips, an unknown id rejects the
  save, an old save without the key loads.
  - **`full set needs the Act IV clear`** (§2.7): for a profile without
    `mirroredRoad`, at Vow 3, 4 and 5, over every deck and route state,
    `_mythic_pool` never holds `unbrokenFlame`, and the route grants only
    `bankedFire`. So the ids that can reach a deck number five, not six. With
    `mirroredRoad`, the pool holds `unbrokenFlame`. Mutation check: remove the
    gate, and the test must fail.
- **`test_mythic_cards`**, one case per card: Banked Fire carries, clamps to the
  new cap and survives a restarted fight; Silvering's self-hit, including the
  Eternal Keeper stopping at 1 HP; the Unbroken Flame lights every rider and
  leaves the tier alone; Unbowed's deadline, Kindle disabling it, healing lifting
  the doom, and a win setting HP to 1; Clean Break holding `facet_max` and still
  honouring adamant. Two directed cases:
  - **Unbowed: the Blood for Oil cycle ends.** Hand: Unbowed, Blood for Oil and
    two Tinder+; empty draw and discard piles; 6 HP; 0 Energy. The cycle: play
    Blood for Oil, then play Tinder+ until Blood for Oil is back in hand. The
    cycle ends when Blood for Oil is in hand and `can_play` refuses it. Assert
    that it ends, that Blood for Oil was played exactly twice (6 → 3 HP, then
    the stand at 0), that the cycle gained exactly 4 Energy, and that
    `can_play` still refuses it while standing. A limit of 100 plays is a
    harness bound that fails the test if reached; it is not a game rule.
    Mutation check: remove the HP guard, and Blood for Oil is playable on every
    return, so the cycle reaches the bound and the test fails.
  - **The Known Road: the short pile.** Draw pile `[A]`, discard `[B, C]`, a
    deal of 2, one seed. (1) A normal draw and the Known Road confirmed at
    once give the same hand uids in the same order and the same
    `run.rng_state()`. (2) The Known Road with the pick {B, C} ends with the
    same `run.rng_state()` as the normal draw, with A in the draw pile. (3) A
    full draw pile calls no RNG during the deal or the pick. Also: uids outside
    the pool or of the wrong count are refused, and while the pick is pending,
    every other command is refused.
- **`test_knight_route`**: Vow 2 untouched at steps 0, 1 and 2; Vow 3 step 0
  forces `woundedKnight` with no draw; Aid him writes `knight-1`, Loot and
  Leave write nothing; one meeting per run; at steps 1 and 2 `_show_event`
  stages the scene and writes no `eventNode`, and no scene id ever reaches
  `content.events`; the scene's completion clears the node in the same store;
  a kill between the Vigil and run stores replays the scene, and a replayed
  `knight-3` grants nothing twice; no Knight scene at the Lamplighter's exit;
  `knight-3` deferred while the slot is used; the simulator's
  `_resolve_event` completes a due scene at step 1 and grants Banked Fire at
  step 2 without an event lookup.

### 8.3 The hard-coded counts

#212 listed four counts in August. Their current homes and values:

| #212 (August) | Today | Change |
|---|---|---|
| 61 cards | `tests/test_content.gd` (in `run`) asserts `[70, 36, 32, 6]` | `[76, 36, 32, 6]` |
| 646 zh-Hant keys | `tests/test_locale_hydration_catalogue.gd` (in `_real_catalogue_census`) asserts 741 live leaves | 741 plus the new zh content leaves. Count them in the lane; do not guess. |
| The card lab | `presentation/lab/card_lab.gd` (`RARITY_ORDER`) and the 61-card parity sheet (in `_init`) | Add `mythic` after `rare`. Keep mythics off the parity sheet, as backs are. |
| The balance pool digest | The content identity, `tests/test_balance_catalogue.gd` (`LIVE_SEMANTIC`) | Moves, on purpose, in the content commit, with the reason in the message. |

Also: `tests/test_locale.gd` (in `_derived_display_seed`) gains the
`ui.rarity.mythic` row. And two values must **not** move:
`tests/test_balance_sim.gd` (`EXPECTED`) and (`EXPECTED_UNLIT`).

### 8.4 Port-fixture impact

None. Every `"vow"` field in `port_fixtures/` is 0. Below Vow 3 no draw
is consumed, no offer changes and no event roll changes (§2.4, §3.2). Any change
to a fixture on the implementation head is a bug: stop and report, never
regenerate.

### 8.5 Save compatibility

No save-schema change and no new save field. The new state lives in fields that
already exist: `run.quest_scratch["mythic"]` and `["knight"]`, the additive
`rewards.mythic` key in the pending reward, and `scenes_seen` once-flags in the
Vigil. `SAVE_VERSION` stays 2. Content ids are append-only.

---

## 9. Calls the owner may re-pick

Each line gives the call made here, then the alternative. (R2) marks a call
that round 2 changed or added.

1. **The six rules.** Lantern goes dark, intent, one flame colour, falling at 0
   HP, a random deal, glass reseaming harder. Alternatives considered: an HP
   swap with an enemy (dropped: it rhymes with the finale's swap, an L4 secret);
   extra turns and keeping the hand (dropped: the genre already has them).
2. (R2) **The guaranteed route is the Wounded Knight**, over three Vow 3 runs:
   the shipped event (Aid him), then two visits to the monument the shipped
   coda promises, where one ember stays out of the wind. He has no new line,
   so the route needs no voice sheet and no matrix row. The first draft had him
   speak after his death, which contradicted rows 377–380. Alternatives: a
   one-run route of three steps; or a route-only coda override that keeps him
   alive (not needed, so not specified).
3. **Banked Fire joins the elite roll after the route completes.** Alternatives:
   never again, or a route that repeats every run.
4. **A mythic cannot be bequeathed.** Alternative: it can, and it fills the next
   run's one slot.
5. **The mythic is a Spoil, handed over, never declined.** Alternative: an
   Offering the player may refuse, which spends the slot.
6. **The curve is shipped mix A as signed**, with the post-Act-IV +1 pp limited
   to Vow 3 and above. Alternative: the bake-off's default `[0, 0, 0, 0.01, 0.02,
   0.04]`.
7. **Elites only, uniform pick, no pity.**
8. **Every mythic shows a one-line fragment** on its reveal and in inspect (a
   new `lore` field). Alternative: no fragment; the art and name carry the
   story.
9. **The seal lights the card's own petal**, numbering the set 1 to 6. Growth to
   ten needs a second seal. Alternative: a plain seal.
10. **Names** (zh first): 封火, 鍍銀, 未碎之火, 不臥, 熟路, 無痕. "The Broken Halo"
    was dropped because an Act IV enemy move already uses it.
11. (R2) **Unbowed is Unplayable and passive**, and Kindling it gives up the
    protection. While it holds you, you cannot play a card that makes you lose
    HP (the loop guard, on the card's own text). Alternatives: a playable
    power; or a hidden cap on HP payments (not readable on the card).
12. (R2) **The Known Road's default deal is the normal draw**, preselected, and
    a pick only swaps cards with the draw pile. Alternative: the player picks
    from the whole draw and discard (needs a different RNG story).
13. **All six are clear glass** and never move the Flame. Alternative: Banked
    Fire carries Lantern affinity.
14. **No Keeper line acknowledges a mythic.** A dual-reading hearth line ("that
    fire did not come from mine") is available later, but it needs a new line
    condition.
15. **The shipped Wounded Knight event stays in the random pool** at every vow.
    Only Vow 3+ runs on the route hide it.
16. (R2) **The Unbroken Flame waits for the first Act IV clear.** Before it,
    five mythics can drop, so the full set needs Vow 3 and an Act IV clear
    (#210). Alternatives: gate a different card; or gate the Knight's last
    meeting on the clear (that delays the guaranteed mythic past Act IV).
17. (R2) **Meetings two and three play plate-less** over the act's backdrop
    until the owner picks a monument plate. Alternative: commission the plate
    with the six card plates (lane 5).
