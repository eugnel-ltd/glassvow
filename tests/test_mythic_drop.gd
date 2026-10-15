extends RefCounted
## #212 lane 2: the mythic drop (design §2, §8.2). O1 by construction: no
## rate and no draw below Vow 3, after Act IV too. One mythic a run. The full set
## waits for the Act IV clear. No mythic in any offer, the Bequest or the
## Mirror's copy. The Spoil's save shape. O6: with the set dark, a Vow 5 run with
## the rate forced high offers nothing and draws nothing.

const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const PoolCallers: GDScript = preload("res://tests/test_pool_callers.gd")
const LanternFlameTest: GDScript = preload("res://tests/test_lantern_flame.gd")
const SEED: int = 21201


class QuietMain extends Main:
	func _route_run() -> void:
		pass


static func _check(fails: Array[String], ok: Variant, what: String) -> void:
	if ok != true:
		fails.append("mythic drop: " + what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var was_live: bool = RewardRules.mythics_live
	RewardRules.mythics_live = true
	_zero_rate_below_vow_three(content, fails)
	_one_roll_and_one_pick(content, fails)
	_one_per_run(content, fails)
	_full_set_needs_the_act_four_clear(content, fails)
	_never_in_an_offer(content, fails)
	_spoil_saves(content, fails)
	_bequest_never_a_mythic(content, fails)
	_mirror_never_copies_a_mythic(content, fails)
	RewardRules.mythics_live = false
	_ships_dark(content, fails)
	_pending_grants_respect_gate(content, fails)
	RewardRules.mythics_live = was_live


## O1 §2.4 check 1: Vow 0-2 roll at 0 with or without the Act IV clear; Vow 3-5
## roll the shipped mix's curve, plus 1 pp after the clear. The game reads the
## clear from the run's unlocks.
static func _zero_rate_below_vow_three(content: ContentDB, fails: Array[String]) -> void:
	var curve: Array[float] = [0.0, 0.0, 0.0, 0.02, 0.03, 0.05]
	for vow: int in range(curve.size()):
		for cleared: bool in [false, true]:
			var rewards: RewardRules = RewardRules.new(content)
			Incentives.apply(rewards, Incentives.shipping(), vow, cleared)
			var want: float = curve[vow] + (0.01 if cleared and vow >= 3 else 0.0)
			_check(fails, is_equal_approx(rewards.mythic_rate, want),
				"Vow %d (Act IV cleared %s) rolls %.3f, not %.3f" % [vow, cleared, rewards.mythic_rate, want])
	for vow: int in [0, 3]:
		var run_state: RunState = RunState.new_run(content, SEED, "mythic-wire",
			{"vow": vow, "unlocks": [RunState.MIRRORED_ROAD]})
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		var want: float = 0.0 if vow == 0 else 0.03
		_check(fails, is_equal_approx(game.rewards.mythic_rate, want),
			"a Vow %d run after Act IV rolls %.3f, not %.3f" % [vow, game.rewards.mythic_rate, want])


## O1 §2.4 check 2, the positive control: at Vow 3 a rate of 1 moves the cursor
## exactly two draws (the roll and the pick) past a rate of 0.
static func _one_roll_and_one_pick(content: ContentDB, fails: Array[String]) -> void:
	var without: Array = _elite(content, 0.0, [])
	var with: Array = _elite(content, 1.0, [])
	var cursor_without: int = without[1]
	var cursor_with: int = with[1]
	var probe: Rng = Rng.new(cursor_without)
	probe.next()
	probe.next()
	_check(fails, probe.get_state() == cursor_with,
		"a forced roll did not take exactly two draws")
	var out: Dictionary = with[0]
	var plain: Dictionary = without[0]
	_check(fails, content.is_mythic(str(out.get("mythic", ""))) and not plain.has("mythic"),
		"a rate of 1 offered %s, a rate of 0 offered %s" % [out.get("mythic"), plain.get("mythic")])


## One per run: the first elite fills the slot, the second rolls nothing and draws
## nothing; a deck already holding a mythic is offered none; the slot survives a
## save and load.
static func _one_per_run(content: ContentDB, fails: Array[String]) -> void:
	var twice: RunState = RunState.new_run(content, SEED, "mythic-twice", {"vow": 3})
	var once: RunState = RunState.new_run(content, SEED, "mythic-twice", {"vow": 3})
	var first: Dictionary = _rewards(content, 1.0).gen_combat_rewards(twice, "elite")
	_rewards(content, 1.0).gen_combat_rewards(once, "elite")
	var second: Dictionary = _rewards(content, 1.0).gen_combat_rewards(twice, "elite")
	_rewards(content, 0.0).gen_combat_rewards(once, "elite")
	var slot: Dictionary = twice.quest_scratch.get(RewardRules.MYTHIC_SLOT, {})
	_check(fails, first.has("mythic") and not second.has("mythic"),
		"two elites in a run offered %s and %s" % [first.get("mythic"), second.get("mythic")])
	_check(fails, twice.rng_state() == once.rng_state(),
		"an elite after the slot closed still drew for a mythic")
	_check(fails, slot.get("id") == first.get("mythic") and slot.get("via") == "elite",
		"the slot does not record the elite's mythic: %s" % [slot])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(twice.to_save_dict()))
	var loaded: RunState = RunState.from_save_dict(saved, content)
	_check(fails, loaded != null and loaded.quest_scratch.get(RewardRules.MYTHIC_SLOT) == slot,
		"the slot did not survive a save and load")
	var held: Array = _elite(content, 1.0, ["silvering"])
	var held_baseline: Array = _elite(content, 0.0, ["silvering"])
	var held_out: Dictionary = held[0]
	_check(fails, not held_out.has("mythic") and held[1] == held_baseline[1],
		"a deck holding a mythic was rolled another")


## §2.7: without the Act IV clear, the pool never holds the Unbroken Flame at any
## vow, deck or route state, so only five ids can ever reach a deck (four by the
## roll, Banked Fire by the route). With the clear it joins.
static func _full_set_needs_the_act_four_clear(content: ContentDB, fails: Array[String]) -> void:
	var reachable: Dictionary = {RewardRules.BANKED_FIRE: true}
	var rewards: RewardRules = _rewards(content, 1.0)
	for cleared: bool in [false, true]:
		for vow: int in [3, 4, 5]:
			for step: int in [0, 1, 2, 3]:
				for extra: String in ["", "oblivionStrike", "silvering", "bankedFire"]:
					var unlocks: Array = [RunState.MIRRORED_ROAD] if cleared else []
					var run_state: RunState = RunState.new_run(content, SEED, "mythic-set",
						{"vow": vow, "unlocks": unlocks})
					run_state.quest_scratch["knight"] = {"step": step, "met": false}
					if not extra.is_empty():
						run_state.player.deck.append(
							CardInst.new(run_state.next_uid(), StringName(extra), false))
					var pool: Array[String] = rewards.mythic_pool(run_state)
					var where: String = "Vow %d, Act IV cleared %s, route step %d, deck +%s" \
						% [vow, cleared, step, extra]
					_check(fails, pool.has(RewardRules.UNBROKEN_FLAME) == cleared,
						"%s: the pool %s the Unbroken Flame" % [where, "lacks" if cleared else "holds"])
					_check(fails, pool.has(RewardRules.BANKED_FIRE) == (step >= 3 and extra != "bankedFire"),
						"%s: Banked Fire's place in the pool is wrong: %s" % [where, pool])
					_check(fails, not pool.has(extra), "%s: the pool holds a card the deck holds" % where)
					if not cleared:
						for id: String in pool:
							reachable[id] = true
	_check(fails, reachable.size() == 5 and not reachable.has(RewardRules.UNBROKEN_FLAME),
		"before the Act IV clear these mythics can reach a deck: %s" % [reachable.keys()])


## No mythic is in a `cardPools` tier, so none is ever drawn into an Offering,
## a shop, an event's pick or a pool a reveal opens.
static func _never_in_an_offer(content: ContentDB, fails: Array[String]) -> void:
	_check(fails, content.mythic_ids().size() == 6, "the set is not six cards: %s" % [content.mythic_ids()])
	for tier: Variant in content.card_pools:
		for id: Variant in content.card_pools[tier]:
			_check(fails, not content.is_mythic(str(id)), "cardPools %s holds %s" % [tier, id])
	for i: int in range(24):
		var run_state: RunState = RunState.new_run(content, SEED + i, "mythic-offer",
			{"vow": 5, "reveals": null, "unlocks": [RunState.MIRRORED_ROAD]})
		var rewards: RewardRules = _rewards(content, 1.0)
		var offered: Array = []
		for kind: String in ["normal", "elite", "boss"]:
			var cards: Array = rewards.gen_combat_rewards(run_state, kind)["cards"]
			offered.append_array(cards)
		for row: Variant in rewards.gen_shop(run_state)["cards"]:
			offered.append(row["id"])
		offered.append_array(rewards.roll_event_cards(run_state, 4))
		for tier: String in ["common", "uncommon", "rare", "boss"]:
			offered.append_array(rewards.offer_cards(run_state, tier))
		for id: Variant in offered:
			_check(fails, not content.is_mythic(str(id)), "seed %d offered the mythic %s" % [SEED + i, id])


## §2.5: a pending reward carrying a mythic loads; one naming an unknown card or
## a card that is not a mythic rejects the whole save; an older save without the
## key loads unchanged.
static func _spoil_saves(content: ContentDB, fails: Array[String]) -> void:
	var run_state: RunState = RunState.new_run(content, SEED, "mythic-spoil")
	run_state.pending_reward = {"rewards": {"gold": 12, "cards": ["strike"], "potion": null,
		"relic": null, "mythic": "silvering"}, "taken": {}}
	var saved: Dictionary = JSON.parse_string(JSON.stringify(run_state.to_save_dict()))
	var loaded: RunState = RunState.from_save_dict(saved.duplicate(true), content)
	var pending: Dictionary = loaded.pending_reward if loaded != null else {"rewards": {}}
	var spoils: Dictionary = pending["rewards"]
	_check(fails, spoils.get("mythic") == "silvering", "a pending mythic did not round-trip")
	for wrong: Variant in ["notACard", "strike", 7]:
		var bad: Dictionary = saved.duplicate(true)
		bad["pendingReward"]["rewards"]["mythic"] = wrong
		_check(fails, RunState.from_save_dict(bad, content) == null,
			"a pending mythic of %s loaded" % [wrong])
	var old: Dictionary = saved.duplicate(true)
	old["pendingReward"]["rewards"].erase("mythic")
	_check(fails, RunState.from_save_dict(old, content) != null,
		"a pending reward from before the set did not load")


## §1.8, §2.6: `RARITY_RANK` leaves `mythic` out, so the Bequest offers the rare.
static func _bequest_never_a_mythic(content: ContentDB, fails: Array[String]) -> void:
	var run_state: RunState = RunState.new_run(content, SEED, "mythic-bequest")
	var rare: CardInst = CardInst.new(run_state.next_uid(), &"oblivionStrike", false)
	run_state.player.deck.append(rare)
	run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"silvering", true))
	var main: Main = Main.new()
	TestProfile.install(main)
	main.content = content
	main.game = GlassvowGame.new(content, run_state)
	var card_choice: String = ""
	for choice: Dictionary in main._bequest_choices():
		if choice.get("kind") == "card":
			card_choice = str(choice["id"])
	_check(fails, card_choice == "card:%d" % rare.uid,
		"the Bequest offered %s, not the rare" % card_choice)
	main.free()


## §1.8: the Silvered Mirror's Reflect never lists a mythic, and refuses one.
static func _mirror_never_copies_a_mythic(content: ContentDB, fails: Array[String]) -> void:
	var run_state: RunState = RunState.new_run(content, SEED, "mythic-mirror")
	var plain: CardInst = CardInst.new(run_state.next_uid(), &"uppercut", false)
	var mythic: CardInst = CardInst.new(run_state.next_uid(), &"unbowed", false)
	run_state.player.deck.append(plain)
	run_state.player.deck.append(mythic)
	var main: Main = LanternFlameTest._event_main(content, run_state, "mirror")
	main._on_event_choice("0", "mirror")
	var screen: ChoiceScreen = main._choice_screen as ChoiceScreen
	var listed: Array[int] = []
	if screen != null and screen._grid != null:
		for card: BakedCard in screen._grid.cards():
			listed.append(card.inst.uid)
	_check(fails, listed.has(plain.uid) and not listed.has(mythic.uid),
		"Reflect listed %s; the mythic is %d" % [listed, mythic.uid])
	main._on_event_pick(str(mythic.uid), "duplicate")
	var copies: int = 0
	for card: CardInst in run_state.player.deck:
		if card.id == mythic.id:
			copies += 1
	_check(fails, copies == 1, "Reflect copied a mythic: %d in the deck" % copies)
	PoolCallers._dispose(main)


## O6: while the set is dark a Vow 5 elite, its rate forced to 1, offers no mythic
## and draws exactly what a rate of 0 draws.
static func _ships_dark(content: ContentDB, fails: Array[String]) -> void:
	var states: Array[int] = []
	for rate: float in [0.0, 1.0]:
		var run_state: RunState = RunState.new_run(content, SEED, "mythic-dark", {"vow": 5})
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		_check(fails, is_equal_approx(game.rewards.mythic_rate, 0.05),
			"the shipped Vow 5 rate is %.3f" % game.rewards.mythic_rate)
		game.rewards.mythic_rate = rate
		var out: Dictionary = game.gen_combat_rewards("elite")
		_check(fails, not out.has("mythic") and not run_state.quest_scratch.has(RewardRules.MYTHIC_SLOT),
			"a dark set offered %s at rate %.1f" % [out.get("mythic"), rate])
		states.append(run_state.rng_state())
	_check(fails, states[0] == states[1], "a dark set still drew for a mythic")


## O6 covers saved grants as well as new rolls. Exercise both Main handlers
## after a valid v2 round-trip; the live control grants once, and the dark set
## still completes the reward without changing the run's occupied slot.
static func _pending_grants_respect_gate(content: ContentDB, fails: Array[String]) -> void:
	for live: bool in [false, true]:
		RewardRules.mythics_live = live
		for claim: bool in [false, true]:
			var run_state: RunState = RunState.new_run(content, SEED, "mythic-pending", {"vow": 5})
			var slot: Dictionary = {"id": "silvering", "via": "elite"}
			run_state.quest_scratch[RewardRules.MYTHIC_SLOT] = slot
			run_state.pending_reward = {"rewards": {"gold": 12, "cards": ["strike"],
				"potion": null, "relic": null, "mythic": "silvering"}, "taken": {}}
			var saved: Dictionary = JSON.parse_string(JSON.stringify(run_state.to_save_dict()))
			run_state = RunState.from_save_dict(saved, content)
			_check(fails, run_state != null, "a saved pending mythic did not load")
			if run_state == null:
				continue
			var main: QuietMain = QuietMain.new()
			TestProfile.install(main)
			main.content = content
			main.game = GlassvowGame.new(content, run_state)
			main._map = WorldMap.slice()
			var deck_size: int = run_state.player.deck.size()
			var gold: int = run_state.player.gold
			main._on_reward_claimed(&"gold", "")
			main._on_reward_claimed(&"card", "strike")
			if claim:
				main._on_reward_claimed(&"mythic", "silvering")
				main._on_reward_claimed(&"mythic", "silvering")
				_check(fails, run_state.player.deck.size() == deck_size + 1 + int(live),
					"saved claim with gate %s granted a mythic incorrectly" % live)
			main._on_reward_finished()
			_check(fails, run_state.player.deck.size() == deck_size + 1 + int(live),
				"saved completion with gate %s (claim %s) granted a mythic incorrectly" % [live, claim])
			_check(fails, run_state.player.gold == gold + 12 and run_state.pending_reward == null
					and run_state.quest_scratch[RewardRules.MYTHIC_SLOT] == slot,
				"saved completion lost ordinary spoils, the slot or its continuation")
			main.free()


static func _rewards(content: ContentDB, rate: float) -> RewardRules:
	var rewards: RewardRules = RewardRules.new(content)
	rewards.mythic_rate = rate
	return rewards


## [the elite's rewards, the cursor after them] for a Vow 3 run holding `extra`.
static func _elite(content: ContentDB, rate: float, extra: Array) -> Array:
	var run_state: RunState = RunState.new_run(content, SEED, "mythic-elite", {"vow": 3})
	for id: Variant in extra:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(str(id)), false))
	var out: Dictionary = _rewards(content, rate).gen_combat_rewards(run_state, "elite")
	return [out, run_state.rng_state()]
