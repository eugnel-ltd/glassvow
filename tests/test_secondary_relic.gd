extends RefCounted
## The shipping Vow 4 incentive reaches the run once and keeps v2 saves valid.

const PoolCallers: GDScript = preload("res://tests/test_pool_callers.gd")
const RewardEmbersTest: GDScript = preload("res://tests/test_reward_embers.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_saved_ids(content, fails)
	_distinct_draws(content, fails)
	_exhausted_pool(content, fails)
	_spoil_entries(content, fails)
	_live_claim_and_resume(content, fails)
	_four_spoils_fit(content, fails)
	TestProfile.wipe(PoolCallers.RUN_PATH, PoolCallers.VIGIL_PATH)


static func _check(fails: Array[String], ok: Variant, message: String) -> void:
	if ok != true:
		fails.append("secondary elite relic: " + message)


static func _run(content: ContentDB, seed: int = 4) -> RunState:
	return RunState.new_run(content, seed, "run-secondary-relic", {"vow": 4, "reveals": null})


static func _saved_ids(content: ContentDB, fails: Array[String]) -> void:
	for id: Variant in [null, "wardingCharm", "not-a-relic", 17]:
		var saved: Dictionary = _run(content).to_save_dict()
		saved["pendingReward"] = {"rewards": {"gold": 1, "cards": ["strike"],
			"potion": null, "relic": "emberLantern", "relic2": id}, "taken": {}}
		var loaded: RunState = RunState.from_save_dict(saved, content)
		var valid: bool = id == null or str(id) == "wardingCharm"
		_check(fails, (loaded != null) == valid,
			"v2 checkpoint with relic2=%s should accept=%s" % [id, valid])
	var old_save: Dictionary = _run(content).to_save_dict()
	old_save["pendingReward"] = {"rewards": {"gold": 1, "cards": ["strike"],
		"potion": null, "relic": "emberLantern"}, "taken": {}}
	_check(fails, RunState.from_save_dict(old_save, content) != null,
		"a v2 checkpoint without the additive second slot stopped loading")


static func _distinct_draws(content: ContentDB, fails: Array[String]) -> void:
	for seed: int in [4, 48]:
		var run_state: RunState = _run(content, seed)
		var reward: Dictionary = GlassvowGame.new(content, run_state).gen_combat_rewards("elite")
		_check(fails, reward.has("relic2"), "shipping Vow 4 seed %d lost its second drop" % seed)
		_check(fails, reward.get("relic2") != reward.get("relic"),
			"seed %d offered the same relic in both slots" % seed)
		for key: String in ["relic", "relic2"]:
			_check(fails, content.relics.has(str(reward.get(key)))
				and not run_state.player.relics.has(str(reward.get(key))),
				"seed %d offered an invalid or already owned %s" % [seed, key])
	# A populated second draw uses the existing roll, tier and pick: three draws.
	var baseline: RunState = _run(content)
	var enhanced: RunState = _run(content)
	var plain: RewardRules = RewardRules.new(content)
	var double: RewardRules = RewardRules.new(content)
	double.elite_relic_second = 1.0
	plain.gen_combat_rewards(baseline, "elite")
	var two: Dictionary = double.gen_combat_rewards(enhanced, "elite")
	var cursor: Rng = Rng.new(baseline.rng_state())
	for _i: int in range(3):
		cursor.next()
	_check(fails, enhanced.rng_state() == cursor.get_state() and two.has("relic2"),
		"a second eligible relic changed the seeded draw count")


static func _exhausted_pool(content: ContentDB, fails: Array[String]) -> void:
	for remaining: Array in [["thornBand"], ["thornBand", "wardingCharm"]]:
		var run_state: RunState = _run(content)
		var rules: RewardRules = RewardRules.new(content)
		rules.elite_relic_second = 1.0
		for tier: String in ["common", "uncommon", "rare"]:
			for id: String in rules.offer_relics(run_state, tier):
				if not remaining.has(id) and not run_state.player.relics.has(id):
					run_state.player.relics.append(id)
		var baseline: RunState = RunState.from_save_dict(run_state.to_save_dict(), content)
		var plain: RewardRules = RewardRules.new(content)
		plain.gen_combat_rewards(baseline, "elite")
		var reward: Dictionary = rules.gen_combat_rewards(run_state, "elite")
		_check(fails, remaining.has(reward.get("relic")), "the primary exhausted-pool drop was invalid")
		var want_second: bool = remaining.size() == 2
		_check(fails, reward.has("relic2") == want_second,
			"with %d eligible relics the second slot should exist=%s" % [remaining.size(), want_second])
		if want_second:
			_check(fails, remaining.has(reward.get("relic2")) and reward["relic2"] != reward["relic"],
				"two remaining relics were not both offered")
		var cursor: Rng = Rng.new(baseline.rng_state())
		# Suppressing an exhausted second slot still keeps its scheduled pick draw.
		for _i: int in range(3):
			cursor.next()
		_check(fails, cursor.get_state() == run_state.rng_state(),
			"the exhausted second pool consumed an unexpected seeded draw")


static func _spoil_entries(content: ContentDB, fails: Array[String]) -> void:
	var reward: Dictionary = {"gold": 9, "cards": ["strike"], "potion": "healing",
		"relic": "emberLantern", "relic2": "wardingCharm"}
	var rows: Array[Dictionary] = RewardSpoils.list(reward, content)
	var keys: Array = rows.map(func(row: Dictionary) -> StringName: return row["what"])
	_check(fails, keys == [&"gold", &"potion", &"relic", &"relic2"],
		"the existing spoil model omitted or reordered the second relic: %s" % [keys])
	if rows.size() == 4:
		_check(fails, rows[3]["id"] == "wardingCharm"
			and rows[3]["name"] == content.relics["wardingCharm"]["name"],
			"the secondary announcement lost the existing relic metadata")
	reward["relic2"] = null
	_check(fails, RewardSpoils.list(reward, content).size() == 3,
		"a null additive slot created a phantom announcement")


static func _live_claim_and_resume(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content, _run(content))
	var rewards: Dictionary = main.game.gen_combat_rewards("elite")
	main.game.run.pending_reward = {"kind": "elite", "rewards": rewards,
		"taken": {"gold": false, "card": false, "potion": false, "relic": false}}
	main._show_pending_reward()
	var screen: RewardEmbers = main._reward_screen
	var claims: Array[StringName] = []
	screen.claimed.connect(func(what: StringName, _id: String) -> void: claims.append(what))
	for i: int in range(screen._spoils.size()):
		screen._announce(i)
		screen._announce(i)
	_check(fails, claims.count(&"relic") == 1 and claims.count(&"relic2") == 1,
		"the live entrance did not claim both generated relics once: %s" % [claims])
	var taken: Dictionary = main.game.run.pending_reward["taken"]
	_check(fails, taken.get("relic", false) and taken.get("relic2", false),
		"the live claimant failed to record both independent taken slots")
	var loaded: RunState = SaveService.load_run(content, PoolCallers.RUN_PATH)
	_check(fails, loaded != null and loaded.player.relics.count(str(rewards["relic"])) == 1
		and loaded.player.relics.count(str(rewards["relic2"])) == 1,
		"both generated relics were not persisted once through Main")
	PoolCallers._dispose(main)
	if loaded == null:
		return
	var resumed: Main = _main(content, loaded)
	resumed._show_pending_reward()
	var resumed_screen: RewardEmbers = resumed._reward_screen
	var resumed_claims: Array[StringName] = []
	resumed_screen.claimed.connect(func(what: StringName, _id: String) -> void: resumed_claims.append(what))
	for i: int in range(resumed_screen._spoils.size()):
		resumed_screen._announce(i)
	_check(fails, resumed_claims.is_empty(),
		"a resumed banked secondary relic announced again: %s" % [resumed_claims])
	_check(fails, loaded.player.relics.count(str(rewards["relic2"])) == 1,
		"resuming duplicated the persisted secondary relic")
	PoolCallers._dispose(resumed)


static func _main(content: ContentDB, run_state: RunState) -> Main:
	var main: Main = PoolCallers._main(content)
	main.game = GlassvowGame.new(content, run_state)
	main._vigil = VigilState.blank()
	main._map = WorldMap.slice()
	main.game.run.map = main._map.to_dict()
	return main


static func _four_spoils_fit(content: ContentDB, fails: Array[String]) -> void:
	var reward: Dictionary = {"gold": 9, "cards": ["flurry", "surge", "fortify"],
		"potion": "healing", "relic": "emberLantern", "relic2": "wardingCharm"}
	for shape: StringName in StageShape.SHIPPING:
		var screen: RewardEmbers = RewardEmbers.new(reward.duplicate(true), content,
			"elite", 22.0, shape, true)
		screen.size = Vector2(StageShape.REFERENCES[shape])
		screen._burst = 1.0
		screen._place()
		_check(fails, screen._spoils.size() == 4, "%s omitted the fourth spoil" % shape)
		var stage: Rect2 = Rect2(Vector2(0.0, RunHud.relic_row_bottom(shape)),
			screen.size - Vector2(0.0, RunHud.relic_row_bottom(shape)))
		var cards: Array[Rect2] = []
		for card: CardView in screen._cards:
			var pad: Control = card.get_parent()
			cards.append(Rect2(pad.position, pad.custom_minimum_size))
		for i: int in range(screen._seat_rel.size()):
			var slab: Rect2 = Rect2()
			var first: bool = true
			for point: Vector2 in RewardEmbers._slab(i, screen._seat):
				var at: Vector2 = screen._centre + screen._seat_rel[i] + point
				slab = Rect2(at, Vector2.ZERO) if first else slab.expand(at)
				first = false
			_check(fails, stage.encloses(slab.grow(-0.5)), "%s put a spoil outside the stage" % shape)
			for card: Rect2 in cards:
				_check(fails, not slab.intersects(card), "%s put a spoil across the offering" % shape)
		for rules: Rect2 in RewardEmbersTest._rules_rects(screen):
			_check(fails, stage.encloses(rules.grow(-0.5)), "%s clipped a spoil rules line" % shape)
		screen.free()
