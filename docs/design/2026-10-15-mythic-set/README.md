# The mythic set (秘藏): design

Issue #212, lane `mythic-design`, 15 October 2026. Base `3a502235`.

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
  shares the moment the Knight's hand opens (§3) and the realisation, several
  fights later, that the lantern has not gone out since.
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
| Rules | Unplayable. Unless you have Kindled this, the first time each fight you would fall, you stay standing: you cannot lose HP until the end of your next turn. If you have 0 HP then, you fall. | 無法打出。若此牌未被燃燼，每場戰鬥中你首次將要倒下時，你仍然站着：直到你下一個回合結束前，你不會失去生命。屆時若生命為 0，你才倒下。 |
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
- **Interactions.** Smolder, Hex, Cinder and self-loss (Blood for Oil) are all
  absorbed while standing. Mendglass, Hearthglow and other heals lift the doom if
  HP is above 0 at the deadline. Kindling it gives the usual Ember and removes
  the protection for that fight: a real choice. It works in the Own Shade fight
  and the final fight.
- **Save and load, determinism.** Fight-scoped flags. No random draw.

### 1.6 The Known Road (熟路)

| | en | zh-Hant |
|---|---|---|
| Rules | At the start of each turn, choose your hand from your draw pile instead of drawing it. | 每個回合開始時，改為從抽牌堆中挑選你的手牌，而不是抽牌。 |
| Upgraded | Cost 2. | 費用 2。 |

- **The rule it breaks.** The deal is random. Every deckbuilder is built on it.
- **Why a player shares it.** The perfect hand, every turn, by choice. It is a
  build screenshot and a "how did you do that" clip.
- **Mechanics.** While it is in play, `domain/rules/combat.gd`
  (`_start_player_turn`) does not draw the deal. It sets a pending choice of the
  deal's size (hand size, omen delta, Night Sight, the Traveller's Pack). A new
  command, `GlassvowGame.apply({"t": "chooseHand", "uids": [...]})`, takes the
  chosen cards. If the draw pile holds fewer cards than the deal, the discard is
  shuffled into it first, exactly as a normal draw would, and the player chooses
  from the whole pile. Cards drawn later in the turn stay random.
- **The picker.** It opens with the cards the shuffle would have dealt already
  selected. Confirming at once is an ordinary draw, so the extra taps are only
  for the player who wants them.
- **Interactions.** All 0-cost draw and Energy cards Kindle, so there is no
  infinite turn. Momentum and Phantom Blades become reliable. The hand cap of 10
  still holds.
- **Save and load, determinism.** Fight-scoped. The default selection is the
  shuffle's own deal, so no extra random draw.

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
  complete (call 3).
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
4. A Vow 2 run whose profile has the Knight's route at step 0 rolls its first
   event exactly as a fresh Vow 2 run does.

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

---

## 3. The side quest: the Knight's amber

### 3.1 The idea

The shipped Wounded Knight event (`assets/art/events/woundedKnight.png`) shows a
dying knight holding out a glowing amber crystal. Every player who has met him
has seen it. At Vow 3 the story reinterprets that image: the amber is his fire,
banked so it would not go out. Over three Vow 3 runs the player meets him three
times. At the third meeting he stands, still, and his hand is open.

Assets are immutable; story may reinterpret any shipped image (story skill §6).
This route changes no shipped asset and no shipped event text.

### 3.2 Gate, steps and nodes

| Step | When | Where | What happens | Progress mark |
|---|---|---|---|---|
| 0 → 1 | A run at Vow ≥ 3 | The first event node the run enters | The shipped `woundedKnight` event, forced in place of the roll. Choosing **Aid him** (choice 0) plays scene `knight-1` after its outcome. | `knight-1` in the Vigil's `scenes_seen` |
| 1 → 2 | A later run at Vow ≥ 3 | The first event node | Scene `knight-2`, staged in place of an event. | `knight-2` |
| 2 → 3 | A later run at Vow ≥ 3, with the run's mythic slot open | The first event node | Scene `knight-3`. Its last beat grants Banked Fire. | `knight-3` |

- **The Vow 3 gate.** `run.vow >= 3`, the value fixed at run start. Below Vow 3
  the route is dormant and the event behaves exactly as today.
- **At most one meeting per run.**
- **Step 0 also counts a natural roll.** If the random roll gives `woundedKnight`
  at Vow ≥ 3 while the route is at step 0, Aid him advances it the same way.
- **Continuity.** At Vow ≥ 3, once the route has reached step 1, the run starts
  with `woundedKnight` already in `quest_scratch["seenEvents"]`, so the slumped
  knight never appears beside the standing one. This reuses the existing
  no-repeat mechanism and is gated on the vow, so Vow 0–2 rolls do not change.

### 3.3 Reward, failure and abandon

- **Reward.** Banked Fire, granted on the last beat of `knight-3`. It fills the
  run's mythic slot (`via: "knight"`).
- **Loot him or Leave** at step 0: no advance. The Knight is there again at the
  next Vow ≥ 3 run's first event node.
- **No event node** in a run: no advance. The route waits.
- **Death or abandon after a meeting:** the meeting counts. The mark is written
  when the scene finishes, so it outlives the run.
- **Killed mid-scene:** the run still points at the scene, and resume replays it
  (the scene player's persistence-gated advance).
- **The run's slot is already used** when step 2 is due: `knight-3` is not
  forced this run. It waits for a run with an open slot.
- **After completion** the route never plays again. Banked Fire then joins the
  elite pool (call 3).

### 3.4 How it is built (O4)

`domain/rules/quests.gd` is the home of quest rules, but its state machine is
the six Emberglass journeys: `domain/state/vigil_state.gd` (`QUEST_IDS`) is fixed
at six, and each completion lights a pane and grants a Shard. A seventh entry
would light a seventh pane. So the route reuses the module's seam pattern
(`domain/rules/quests.gd` (`encounter_override`)), not its state machine:

- **Progress** is the once-flags `knight-1`, `knight-2`, `knight-3` in
  `domain/state/vigil_state.gd` (`scenes_seen`). `application/main.gd`
  (`_on_scene_finished`) already writes the flag Vigil first, then the run, so a
  kill between the two replays a scene that finishes idempotently. No new Vigil
  field.
- **Run start.** `application/main.gd` (`_new_run`) adds `"knight": n` (flags
  seen) to the profile. `domain/state/run_state.gd` (`new_run`) copies it into
  `quest_scratch["knight"] = {"step": n, "met": false}`.
- **The seam.** A static `QuestRules.knight_event(run)` returns the meeting due
  or "". `domain/rules/rewards.gd` (`roll_event`), the one function both event
  call sites use, returns it before its own draw. Vow is checked first.
- **The grant.** When `knight-3` finishes, append Banked Fire **if the deck holds
  no mythic**, then set the slot. That check makes a replayed scene grant
  nothing twice.
- **Scenes** are data in `content/scenes.json`. All three reuse
  `events/woundedKnight.png`, staged by the scene player. Dedicated plates for
  meetings 2 and 3 are optional; if made, they follow the #263 rule (new scene
  assets allowed, owner pick).

### 3.5 Scene beats and lines [PROPOSED]

Ceiling L1 (event scripts, `docs/story/04-delivery.md`). Forbidden in all three:
碑 / monument / stone, 凝, 隊伍 / queue, 行者 / walker, any statement that he is
the player, and any vertical word.

**`knight-1`** (after Aid him)

1. Beat: he pushes the chained satchel across the floor to you. The relic came
   from there.
2. Beat: his other hand closes over the amber.
3. Knight: 「這個不給。還不是時候。」 / "Not this one. Not yet."
4. Knight: 「我會在這裏。」 / "I will be here."

**`knight-2`**

1. Beat: the same pillar. He is on his feet, one hand on the stone, frost-like
   glaze on the steel.
2. Knight: 「我站起來了。」 / "I got up."
3. Beat: the amber glows between his closed fingers.
4. Knight: 「它還暖。我替它擋着風。」 / "It is still warm. I am keeping the wind
   off it."
5. Knight: 「再來一次。」 / "Once more."

**`knight-3`**

1. Beat: he stands. No breath. The cape does not move.
2. Narration: 「他沒有躺下。」 / "He has not lain down."
3. Narration: 「他的手張開了。」 / "His hand is open."
4. Beat (tap): you take the amber. The card turns to face you: Banked Fire on
   the M0 frame, its Lantern hologram cold until you tilt it.
5. Narration: 「仍有餘溫。」 / "Still warm."

**The Knight's voice [PROPOSED, for `docs/story/02-cast.md`].** Few words. Short
declaratives. No names. He never says "die" or 死. He talks only of warmth, wind,
standing and his hand. He does not know about the split, the Keeper or the door.
He knows only that he is staying where he is.

---

## 4. The story bundle

### 4.1 One bundle per card

Every mythic carries a **fragment**: one unattributed line shown under the card
when it is revealed (§5) and in the card's inspect view. It is a new optional
card field, `lore`, with its zh leaf `content.cards.<id>.lore`. Channel: card
lore, ceiling L1.

| Card | Bundle | Fragment (zh / en) | Anchor in canon |
|---|---|---|---|
| Banked Fire | **Quest** (§3) + fragment | 仍有餘溫。他替它擋了很久的風。 / Still warm. He kept the wind off it for a long time. | The Knight's shipped art; fire = will, glass = memory (`00-truth.md` §8.6, [SETTLED #259]) |
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
- **One new character arc.** The Knight's route adds a voice sheet (§3.5) and an
  information-matrix row for `00-truth.md` §4: knows the split ✗; knows that he
  himself is becoming still, partly; knows the Keeper ✗; knows the door ✗. Both
  are [PROPOSED]. Under the story skill (§2), the scene copy cannot ship until
  the owner promotes them (call 2).
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
| 封火 / Banked Fire + fragment | `bankedFire` name, lore | L1 | The Knight kept a coal alive. | Unfinished will kept, like the light in each walker's chest. | Low |
| 鍍銀 / Silvering + fragment | `silvering` name, lore | L1 | A mirror throws a blow back. | "Never moves first": the one behind the glass has never walked first, until the finale. | Low–medium: twist-safety pass |
| 未碎之火 + fragment | `unbrokenFlame` name, lore | L1 | The legend of six from one. | The whole fire the door asks for. | None |
| 不臥 / Unbowed + fragment | `unbowed` name, lore | L1 | Brave pilgrims who would not yield. | The walkers died standing. Same weight as whisper 11. | Low |
| 熟路 / The Known Road + fragment | `knownRoad` name, lore | L1 | Déjà vu. | The stayer never walked; the memory is second-hand, and "you are sure" is the illusion. | Medium: twist-safety pass |
| 無痕 / Clean Break + fragment | `cleanBreak` name, lore | L1 | Glazier's craft. | Glass is memory: a clean cut leaves none. | Low |
| 這個不給。還不是時候。 | `knight-1` | L1 | He is not ready to give it. | He is not yet still. | Low |
| 我會在這裏。 | `knight-1` | L1 | He expects to last. | He will stand here for good. | Low |
| 我站起來了。 | `knight-2` | L1 | He recovers a little. | He has begun to die standing. | Low |
| 它還暖。我替它擋着風。 | `knight-2` | L1 | He shields the amber. | He keeps his own will alive. | Low |
| 再來一次。 | `knight-2` | L1 | Come back. | One more meeting before he is still. | Low |
| 他沒有躺下。／他的手張開了。 | `knight-3` | L1 | He died on his feet. | A walker becoming what lines the road. The nearest the route comes to L2: it must not name 碑 or 凝. | Medium: twist-safety pass |
| 仍有餘溫。 | `knight-3` | L1 | The amber is warm. | His will outlived him. | Low |

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
| Banked Fire | **Lantern** | Toolkit, as built | The art sits cold. Past the threshold lean the banked coal inside the amber flares white-hot, warmth floods the window and the frame turns amber. |
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
  until the deadline.
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

1. **Banked Fire.** An armoured gauntlet, blue steel with gold trim like the
   Knight's, cupping an amber crystal. Inside the crystal a low coal glows under
   a skin of grey ash: banked, not blazing. Crystal on the left-centre third;
   the gauntlet fills the lower half; behind, a broken pillar and dim leaded
   windows. Palette: a cold blue-grey world, and the amber core is the only warm
   colour, so the Lantern hologram's cold-to-warm reveal reads. No flame tongue:
   the hologram supplies the flare. At 64 px: one amber jewel in blue dark.
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

| Card | Degenerate line | Softlock | Infinite turn | Guard |
|---|---|---|---|---|
| Banked Fire | Turn-one Art in every fight; Crown of the Hearth heals and carries the same Embers. Accepted: subtle-overpowered is the brief. | None | None | Carry clamped to the next fight's cap; store overwritten, never added; written only on a win; read, not cleared, at fight start. |
| Silvering | Bosses with big telegraphs kill themselves. Accepted. | None: a Staggered target's reflection waits until it acts. | None: Kindle, and one copy per deck. | Non-attack self-hit through `hit_enemy`, so the finale handoff holds; card-adding parts are dropped. |
| The Unbroken Flame | Draft anything; every rider fires. Accepted. | None | None | Only riders change; tier and lantern quality do not. |
| Unbowed | Fall on purpose for a turn of immunity; self-loss is free while standing. Accepted. | None: the deadline always resolves the fight. | None: once per fight. | Kindle disables it; HP cannot fall below 0; the normal win path sets HP to 1. |
| The Known Road | A perfect hand every turn. Accepted. | Picker with fewer cards than the deal: it takes what exists and confirms. Empty piles give an empty hand, as today. | None: the choice is only at the deal, later draws are random, and all 0-cost draw and Energy cards Kindle. | Validate chosen uids against the draw pile; default selection is the shuffle's own deal; hand cap 10. |
| Clean Break | A strong Shatter deck Staggers an enemy every turn, so it never acts. A player win, not a softlock. Accepted. | None | None | Fight-scoped; the adamant hold still fires once. |

### 7.2 What the implementation lane must run

- **Forced arms.** For each of the six mythics, put it in the starting deck and
  run the balance sim at Vow 3, 4 and 5: Duskblade, the default pilot, 200 seeds
  per cell (for example seeds 9000–9199). Run a control arm without a mythic on
  the same seeds. Set the sim profile's Knight route to complete, so the route
  does not change the event rolls. `--jobs 4` or fewer, one batch at a time (the
  Mac is shared with ks2's CI).
- **Natural-drop arm.** Vow 5, 1,000 seeds, no forcing: count offers per elite
  clear against 5%. And Vow 2, 200 seeds: there must be zero offers.
- **Sim support** (§8, lane 6): a `--mythic=<id>` option, the pilot's play rule
  for each mythic (Silvering targets the largest incoming hit; the Known Road
  picks by the pilot's card score), and the invariant checks below.

**A failure is any of these:**

- an `error` outcome, or a `stall` that the control arm does not have on the
  same seed;
- the same seed giving two different digests;
- the Vow 0 digests (`EXPECTED`, `EXPECTED_UNLIT`) moving, or any `port_fixtures/`
  trace changing;
- a mythic offered at Vow 0–2, or appearing in a shop, an event or the normal
  Offering;
- two mythics in one deck;
- Embers above the lantern's cap, a hand above 10, or HP below 0 at a fight's
  end;
- the natural-drop count outside three standard deviations of the curve.

**Information only:** win rate, turns per fight, HP at each act's end, deck
size, deaths by act. Win-rate deltas do not fail anything.

---

## 8. The implementation plan

### 8.1 Lanes and file ownership

One owner, one branch and one PR per lane. Lanes that share a file run in
sequence, never in parallel.

| # | Lane | Owns | Needs | Proof |
|---|---|---|---|---|
| 1 | **Story copy** | `docs/story/05-foreshadow-ledger.md`, `docs/story/02-cast.md` (Knight row), `docs/story/00-truth.md` §4 (Knight row), a batch file under `docs/story/batches/` | Owner promotion of the Knight row (call 2) | The story-draft workflow; `tools/check_anchors.py` |
| 2 | **Tier, drop and the six rules** | `content/full-content.json` (six rows), `locale/en.json`, `locale/zh-Hant.json` (card leaves, `ui.rarity.mythic`), `tools/vow_incentives.gd`, `domain/game.gd`, `domain/rules/rewards.gd` (roll), `domain/rules/combat.gd`, `domain/state/combat_state.gd`, `domain/state/run_state.gd` (`_valid_pending_reward`), `content/content_db.gd`, `application/main.gd` (Bequest, duplicate, reward claim, `chooseHand` routing), font subsets | Lane 1's promoted strings | The core Godot gate; new tests (§8.2); the counts (§8.3) |
| 3 | **The Knight's route** | `domain/rules/quests.gd` (a new `knight_event`), `domain/rules/rewards.gd` (the `roll_event` seam only), `domain/state/run_state.gd` (`new_run`), `content/scenes.json`, scene locale leaves, `application/main.gd` (`_new_run`, `_on_scene_finished`, the Aid him hook) | Lanes 1 and 2 merged | The core gate; route tests; scene stills at three shapes |
| 4 | **Presentation** | `presentation/cards/` (M0, the six recipes, from `b16c1501`), `presentation/combat/card_view.gd`, `presentation/combat/card_surface.gd`, `presentation/reward/`, the combat screen's lantern, intent, standing and hand-picker views, `presentation/lab/card_lab.gd` | Lane 2 merged (faces can start earlier in the lab with stand-in art) | Stills at the three reference shapes, looked at; an A12 iPad combat-frame read with a mythic in hand (QA app, shared lock) |
| 5 | **Art** | Candidate plates and contact sheets under `docs/reviews/`; after the owner's pick, `assets/art/cards/<id>.jpg` and a `docs/art-ledger.md` entry | Nothing; starts at once | Owner pick; the payload report |
| 6 | **Balance read** | `tools/balance_sim.gd`, `tools/balance_pilot.gd`, `tools/balance_policy.gd` (a `mythic` rarity value) | Lane 2 merged | The runs and failure rules of §7.2 |

Order: 1 and 5 start now. 2 follows 1. 3, 4 and 6 follow 2. 3 and 4 both touch
`application/main.gd`, so run them in sequence.

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
- **`test_mythic_cards`**, one case per card: Banked Fire carries, clamps to the
  new cap and survives a restarted fight; Silvering's self-hit, including the
  Eternal Keeper stopping at 1 HP; the Unbroken Flame lights every rider and
  leaves the tier alone; Unbowed's deadline, Kindle disabling it, healing lifting
  the doom, and a win setting HP to 1; the Known Road's validation, default
  selection and short-pile case; Clean Break holding `facet_max` and still
  honouring adamant.
- **`test_knight_route`**: Vow 2 untouched; Vow 3 step 0 forces `woundedKnight`
  with no draw; one meeting per run; `knight-3` deferred while the slot is used;
  a replayed `knight-3` grants nothing twice.

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

Each line gives the call made here, then the alternative.

1. **The six rules.** Lantern goes dark, intent, one flame colour, falling at 0
   HP, a random deal, glass reseaming harder. Alternatives considered: an HP
   swap with an enemy (dropped: it rhymes with the finale's swap, an L4 secret);
   extra turns and keeping the hand (dropped: the genre already has them).
2. **The guaranteed route is the Wounded Knight**, three meetings over three Vow
   3 runs. It needs the owner to promote the Knight's voice sheet and matrix row.
   Alternative: a one-run route of three steps.
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
11. **Unbowed is Unplayable and passive**, and Kindling it gives up the
    protection. Alternative: a playable power.
12. **The Known Road's picker preselects the shuffle's deal.**
13. **All six are clear glass** and never move the Flame. Alternative: Banked
    Fire carries Lantern affinity.
14. **No Keeper line acknowledges a mythic.** A dual-reading hearth line ("that
    fire did not come from mine") is available later, but it needs a new line
    condition.
15. **The shipped Wounded Knight event stays in the random pool** at every vow.
    Only Vow 3+ runs on the route hide it.
