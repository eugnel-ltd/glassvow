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
	_removal_takes_the_off_colour_seeds(content, fails)
	_colour_weighting_covers_two_copies(content, fails)
	Pilot.apply_policy({})


## Flame readout 13: a committed bot's removal (shop, shrine and its worth at an
## event) takes its off-colour starter seeds first, the lowest scored, whatever
## their copies and at the full appetite; its own seed stays, and arm A removes
## its worst card as before.
static func _removal_takes_the_off_colour_seeds(content: ContentDB, fails: Array[String]) -> void:
	var expected: Dictionary = {"shatter": "firstSpark", "lantern": "chisel", "edge": "firstSpark"}
	var shrine: Dictionary = content.events["forgottenShrine"]["choices"][0]
	for way: String in expected:
		Pilot.apply_policy({"way": way})
		var run_state: RunState = RunState.new_run(content, 61300, "arms-removal", {"aspect": 0})
		var target: CardInst = Pilot.removal_target(run_state, content)
		if target == null or String(target.id) != str(expected[way]):
			fails.append("balance arms: %s must remove %s first, took %s" % [way, expected[way], target])
			continue
		if Pilot.removal_worth(content, 0, String(target.id)) != Pilot.removal_appetite:
			fails.append("balance arms: an off-colour seed's removal must be worth the full appetite")
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		if Sim._event_choice_score(game, shrine) != Pilot.removal_appetite:
			fails.append("balance arms: %s's shrine removal must be worth the full appetite" % way)
		var bought: Array[Dictionary] = Pilot.choose_shop({"removeCost": 75}, run_state, content)
		if bought.size() != 1 or str(bought[0]["category"]) != "remove" \
				or str(bought[0]["id"]) != str(expected[way]):
			fails.append("balance arms: %s's shop must buy out its single %s, bought %s"
				% [way, expected[way], bought])
		var own: Dictionary = {"shatter": "chisel", "lantern": "firstSpark", "edge": "eclipseSlash"}
		if Pilot.is_off_colour_seed(content, 0, str(own[way])) \
				or Pilot.is_off_colour_seed(content, 0, "strike"):
			fails.append("balance arms: %s's own seed and clear starters are never off-colour" % way)
		for card: CardInst in run_state.player.deck.duplicate():
			if Pilot.is_off_colour_seed(content, 0, String(card.id)):
				run_state.player.deck.erase(card)
		var worst: CardInst = Pilot.worst_card(run_state, content, run_state.player.deck)
		var after: CardInst = Pilot.removal_target(run_state, content)
		if after == null or after.uid != worst.uid:
			fails.append("balance arms: with its seeds gone %s must remove its worst card" % way)
	Pilot.apply_policy({})
	var plain: RunState = RunState.new_run(content, 61300, "arms-removal", {"aspect": 0})
	var worst_a: CardInst = Pilot.worst_card(plain, content, plain.player.deck)
	var target_a: CardInst = Pilot.removal_target(plain, content)
	if target_a == null or target_a.uid != worst_a.uid \
			or Pilot.is_off_colour_seed(content, 0, "eclipseSlash") \
			or Pilot.removal_worth(content, 0, String(worst_a.id)) \
				!= Pilot.remove_value(Pilot.build_card_score(content, 0, String(worst_a.id))):
		fails.append("balance arms: arm A must remove its worst card at appetite less its score")


## Flame readout 13: WAY_COMMIT covers two copies of a card. With two Fans of
## Glass in the deck, a committed Shatter bot weighs a third at catalogue worth
## and takes Deflect over it; with one, it takes the third at x3. Off-colour and
## clear glass, cards already in the deck, and arm A never read the count.
static func _colour_weighting_covers_two_copies(content: ContentDB, fails: Array[String]) -> void:
	var offer: Array = ["cleave", "deflect"]
	for held_copies: int in [1, 2]:
		Pilot.apply_policy({"way": "shatter"})
		var run_state: RunState = RunState.new_run(content, 61301, "arms-copies", {"aspect": 0})
		for _i: int in range(held_copies):
			run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"cleave", false))
		Pilot.see_flame(content, run_state)
		var capped: bool = held_copies >= Pilot.WAY_COPIES
		var base: float = Pilot.catalogue_card_score(content, 0, "cleave")
		var offered: float = Pilot.offer_card_score(content, 0, "cleave")
		if not is_equal_approx(offered, base * (1.0 if capped else Pilot.WAY_COMMIT)):
			fails.append("balance arms: with %d held a Fan of Glass offered must score %s, got %s"
				% [held_copies, base * (1.0 if capped else Pilot.WAY_COMMIT), offered])
		var held_score: float = Pilot.build_card_score(content, 0, "cleave")
		if not is_equal_approx(held_score, base * Pilot.WAY_COMMIT):
			fails.append("balance arms: the copy count must not touch the build score of cards held")
		var taken: String = Pilot.choose_card(offer, content, 0)
		if taken != ("deflect" if capped else "cleave"):
			fails.append("balance arms: with %d Fans of Glass held, shatter must take %s, took %s"
				% [held_copies, "deflect" if capped else "cleave", taken])
	Pilot.apply_policy({"way": "edge"})
	var edge_run: RunState = RunState.new_run(content, 61301, "arms-copies", {"aspect": 0})
	for _i: int in range(3):
		edge_run.player.deck.append(CardInst.new(edge_run.next_uid(), &"cleave", false))
	Pilot.see_flame(content, edge_run)
	var off_offer: float = Pilot.offer_card_score(content, 0, "cleave")
	var off_base: float = Pilot.catalogue_card_score(content, 0, "cleave")
	if not is_equal_approx(off_offer, off_base * Pilot.WAY_OFF):
		fails.append("balance arms: off-colour glass keeps its x0.5 at any count")
	Pilot.apply_policy({})
	Pilot.see_flame(content, edge_run)
	if not Pilot.held.is_empty() or Pilot.offer_card_score(content, 0, "cleave") \
			!= Pilot.catalogue_card_score(content, 0, "cleave"):
		fails.append("balance arms: arm A must not count its copies")


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
	for id: String in ["uppercut", "quakeblow", "firstSpark", "surge", "warCry", "cleft"]:
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
