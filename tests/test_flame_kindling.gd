extends RefCounted
## Flame lock §8, the Kindling lift (readout 5): while the flame is Kindling,
## card draws weigh coloured glass of every colour by the aspect's
## `kindlingLift` against clear glass, a duo once and no way above another. The
## shop's relics, a Soot flame and a lit flame (which leans by `likeWeight`)
## ignore it, and every draw is made as at 1, so the run's cursor, the prices,
## gold, potions and rarity rolls never move with it. Measured on catalogues
## whose lift is set here, whatever value ships.

const Like: GDScript = preload("res://tests/test_flame_like.gd")
const LIFT: float = 1.5


static func run(fails: Array[String]) -> void:
	var inert: ContentDB = _with_lift(1.0)
	var lifted: ContentDB = _with_lift(LIFT)
	_every_draw_is_kept(inert, lifted, fails)
	_the_lift_is_even(lifted, fails)


static func _with_lift(lift: float) -> ContentDB:
	var content: ContentDB = ContentDB.load_full(false)
	var dusk: Dictionary = content.aspects[0]
	var flame: Dictionary = dusk["flame"]
	flame["kindlingLift"] = lift
	return content


## Kindling decks make the same draws lifted as at 1 (only ids may change) and
## replay alike; Soot and lit decks are offered exactly what they are at 1.
static func _every_draw_is_kept(inert: ContentDB, lifted: ContentDB, fails: Array[String]) -> void:
	var plain: RewardRules = RewardRules.new(inert)
	var rules: RewardRules = RewardRules.new(lifted)
	for seed: int in range(Like.SEEDS):
		for deck: Array in [Like.STARTER, Like.KINDLING]:
			var before: Dictionary = Like._offers(plain, Like._dusk(inert, seed, deck), false)
			var after: Dictionary = Like._offers(rules, Like._dusk(lifted, seed, deck), false)
			var problem: String = Like._same_draws(lifted, before, after)
			if problem.is_empty() and Like._offers(rules, Like._dusk(lifted, seed, deck), false) != after:
				problem = "offered differently on a replay"
			if not problem.is_empty():
				fails.append("kindling lift: %s seed %d %s" % [deck[0], seed, problem])
				return
		for deck: Array in [Like.SOOT, Like.LIT, Like.TRUE_LANTERN]:
			if Like._offers(rules, Like._dusk(lifted, seed, deck), true) \
					!= Like._offers(plain, Like._dusk(inert, seed, deck), true):
				fails.append("kindling lift: %s moved with the lift (seed %d)" % [deck[0], seed])
				return


## The expected-frequency test, on a Kindling deck: in the shop's uncommon card
## slots each way's single-colour glass draws LIFT times as often as clear
## glass; a duo on the first card of a boss reward draws LIFT times too, never
## LIFT squared; the shop's uncommon relics do not lift.
static func _the_lift_is_even(lifted: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(lifted)
	var run_state: RunState = Like._dusk(lifted, 0, Like.KINDLING)
	var card_pool: Array = rules.offer_cards(run_state, "uncommon")
	var relic_pool: Array = rules.offer_relics(run_state, "uncommon")
	var rares: Array = rules.offer_cards(run_state, "rare")
	var cards: Dictionary = {}
	var relics: Dictionary = {}
	var first: Dictionary = {}
	for _i: int in range(Like.SAMPLES):
		var stock: Dictionary = rules.gen_shop(run_state)
		for slot: int in [2, 3]:
			Like._tally(cards, stock["cards"][slot]["id"])
		for row_v: Variant in stock["relics"]:
			var row: Dictionary = row_v
			if relic_pool.has(row["id"]):
				Like._tally(relics, row["id"])
		Like._tally(first, rules.gen_combat_rewards(run_state, "boss")["cards"][0])
	var rows: Array = [
		["shatter glass", _lift(lifted, cards, card_pool, false, _only("shatter")), LIFT],
		["lantern glass", _lift(lifted, cards, card_pool, false, _only("lantern")), LIFT],
		["edge glass", _lift(lifted, cards, card_pool, false, _only("edge")), LIFT],
		["duo glass", _lift(lifted, first, rares, false, _colours(2)), LIFT],
		["coloured relics", _lift(lifted, relics, relic_pool, true, _colours(1)), 1.0],
	]
	var measured: Array[String] = []
	for row_v: Variant in rows:
		var row: Array = row_v
		var lift: float = row[1]
		var expected: float = row[2]
		measured.append("%s %.2f" % [row[0], lift])
		if absf(lift - expected) > Like.TOLERANCE:
			fails.append("kindling lift: %s lifts %.3f, expected %.2f +- %.2f"
				% [row[0], lift, expected, Like.TOLERANCE])
	print("  kindling lift %.2f: %s" % [LIFT, ", ".join(measured)])


## Entries with at least 0.5 affinity to `way` and to no other way.
static func _only(way: String) -> Callable:
	return func(affinity: Dictionary) -> bool:
		return _ways_of(affinity) == [way]


## Entries with at least 0.5 affinity to `count` ways, or to at least one when
## `count` is 1.
static func _colours(count: int) -> Callable:
	return func(affinity: Dictionary) -> bool:
		var ways: Array[String] = _ways_of(affinity)
		return ways.size() == count if count > 1 else not ways.is_empty()


static func _ways_of(affinity: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for way_v: Variant in affinity:
		if float(str(affinity[way_v])) >= 0.5:
			out.append(str(way_v))
	return out


## The per-entry draw rate of the entries `test` selects over that of clear
## entries (no affinity), within one pool; -1 when either class is missing.
static func _lift(content: ContentDB, hits: Dictionary, pool: Array, relics: bool,
		test: Callable) -> float:
	var hit: int = 0
	var entries: int = 0
	var clear_hits: int = 0
	var clear_entries: int = 0
	for id_v: Variant in pool:
		var id: String = str(id_v)
		var affinity: Dictionary = Flame.relic_affinity(content, 0, id) if relics \
			else Flame.card_affinity(content, 0, id)
		var count: int = hits.get(id, 0)
		if _ways_of(affinity).is_empty():
			clear_hits += count
			clear_entries += 1
		elif test.call(affinity):
			hit += count
			entries += 1
	if entries == 0 or clear_entries == 0 or clear_hits == 0:
		return -1.0
	return (float(hit) / entries) / (float(clear_hits) / clear_entries)
