extends RefCounted
## Flame lock §11 simulator arms: a committed policy scales the build-side score
## of its own glass by 3.0 and of other coloured glass by 0.5, never combat play;
## the pool states; and the per-run flame descriptor, kept out of the digest.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_way_scales_build_scores(content, fails)
	_combat_play_ignores_the_way(content, fails)
	_pool_states(content, fails)
	_flame_row(content, fails)
	Pilot.apply_policy({})


static func _way_scales_build_scores(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	for id: String in ["strike", "uppercut", "warCry", "resonantLance", "venomStrike"]:
		if Pilot.build_card_score(content, 0, id) != Pilot.catalogue_card_score(content, 0, id):
			fails.append("balance arms: way none must leave %s's build score untouched" % id)
	Pilot.apply_policy({"way": "shatter"})
	var cases: Dictionary = {"uppercut": Pilot.WAY_COMMIT, "resonantLance": Pilot.WAY_COMMIT,
		"warCry": Pilot.WAY_OFF, "firstSpark": Pilot.WAY_OFF, "strike": 1.0}
	for id: String in cases:
		var factor: float = cases[id]
		var base: float = Pilot.catalogue_card_score(content, 0, id)
		var scaled: float = Pilot.build_card_score(content, 0, id)
		if not is_equal_approx(scaled, base * factor):
			fails.append("balance arms: shatter must scale %s by %s" % [id, factor])
	var relics: Dictionary = {"shatterersCrown": Pilot.WAY_COMMIT, "prismCharm": Pilot.WAY_COMMIT,
		"crownOfCinders": Pilot.WAY_OFF, "hollowCrown": 1.0}
	var shatter_scores: Dictionary = {}
	for id: String in relics:
		shatter_scores[id] = Pilot.relic_score(id, content, 0)
	Pilot.apply_policy({})
	for id: String in relics:
		var factor: float = relics[id]
		var base: float = Pilot.relic_score(id, content, 0)
		var scaled: float = shatter_scores[id]
		if not is_equal_approx(scaled, base * factor):
			fails.append("balance arms: shatter must scale relic %s by %s" % [id, factor])


## Combat play never reads the way: whole fights, with glass of every way in
## hand, log the same events for the adaptive and every committed pilot.
static func _combat_play_ignores_the_way(content: ContentDB, fails: Array[String]) -> void:
	for seed: int in range(12000, 12012):
		var adaptive: Array = _fight_log(content, seed, "none")
		for way: String in ["shatter", "lantern", "edge"]:
			if _fight_log(content, seed, way) != adaptive:
				fails.append("balance arms: way %s changed combat play (seed %d)" % [way, seed])
				return
	var committed: Dictionary = Sim.simulate(content, "duskblade", 12007, 0,
		PackedStringArray(), {"way": "lantern"})
	var adaptive_row: Dictionary = Sim.simulate(content, "duskblade", 12007, 0)
	if str(committed["policy"].get("way")) != "lantern" or adaptive_row["policy"].has("way"):
		fails.append("balance arms: only a committed policy records its way")


static func _fight_log(content: ContentDB, seed: int, way: String) -> Array:
	Pilot.apply_policy({} if way == "none" else {"way": way})
	var run_state: RunState = RunState.new_run(content, seed, "arms-fight-%d" % seed, {"aspect": 0})
	for id: String in ["uppercut", "quakeblow", "firstSpark", "surge", "warCry", "empower"]:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling", "sporeling"], "kind": "normal"})
	while not game.cb.over and game.cb.turn < 30:
		Pilot.play_turn(game)
		if not game.cb.over:
			game.apply({"t": "endTurn"})
	return game.cb.queue.duplicate(true)


static func _pool_states(content: ContentDB, fails: Array[String]) -> void:
	var fresh: Dictionary = {"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"]}
	Sim._apply_pool(fresh, content, "fresh")
	var fresh_reveals: Array = fresh["reveals"]
	var fresh_unlocks: Array = fresh["unlocks"]
	if not fresh_reveals.is_empty() or not fresh_unlocks.is_empty():
		fails.append("balance arms: fresh is a new Vigil: no reveals and no unlocks")
	var full: Dictionary = {"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"]}
	Sim._apply_pool(full, content, "full")
	var full_unlocks: Array = full["unlocks"]
	for unlock: String in ["aspect2", "card:quakeblow", "card:novaflare", "relic:prismCharm"]:
		if not full_unlocks.has(unlock):
			fails.append("balance arms: full must hold every deed's unlocks, missing %s" % unlock)
	var mature: Dictionary = {"reveals": content.reveal_ids.duplicate(), "unlocks": ["aspect2"]}
	Sim._apply_pool(mature, content, "mature")
	var mature_unlocks: Array = mature["unlocks"]
	if mature_unlocks != ["aspect2"]:
		fails.append("balance arms: the mature pool must stay the historical profile")


static func _flame_row(content: ContentDB, fails: Array[String]) -> void:
	var row: Dictionary = Sim.simulate(content, "duskblade", 12011, 0, PackedStringArray(),
		{"way": "shatter"}, false, false, {}, null, false, "full")
	var flame: Dictionary = row.get("flame", {})
	var rates: Dictionary = flame.get("rates", {})
	var acts: Array = flame.get("acts", [])
	var end: Dictionary = flame.get("end", {})
	if str(flame.get("way", "")) != "shatter" or rates.keys() != Sim.RATE_STATS \
			or acts.size() > 3 or not end.has("tier") or not end.has("purity"):
		fails.append("balance arms: the run row must carry way, end, acts and rates, got %s" % flame)
	var bare: Dictionary = row.duplicate(true)
	bare.erase("flame")
	if Sim.outcome_digest(row) != Sim.outcome_digest(bare):
		fails.append("balance arms: the flame descriptor must stay out of the outcome digest")
