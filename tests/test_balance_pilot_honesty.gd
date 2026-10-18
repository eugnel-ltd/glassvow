extends RefCounted
## #544 A9: p10 sees current Smolder, never the hidden leap RNG. These fixed
## positions run the real forecast/search seam for both classes; legacy p9/p8
## outputs, RNG cursor, hand/rider scoring and Phantom preview consumption stay
## explicit. Literal p10 is intentional: old select accepts it, so the old code
## reaches and fails the functional counterexample rather than failing to load.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
const HONEST: String = "p10"


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.apply_policy({})
	_hidden_leap(content, fails)
	_known_ticks(content, fails)
	_hand_and_riders(content, fails)
	_historical_preview(content, fails)
	if not Pilot.VERSIONS.has(HONEST):
		fails.append("pilot honesty: p10 is not selectable")
	Pilot.select(Pilot.VERSION)
	Search.select(Search.VERSION)
	Pilot.apply_policy({})


## Seed-state 0 first chooses B, state 1 chooses C. A dies keeping 4 Smolder.
## B at 4 HP either dies before its 5-damage Spit or lives; C always Spits for
## 5. Legacy forecasts are 5/10. p10 claims neither ambiguous leap and returns
## 10/10. Dusk can meet starting Smolder through its Ashfall omen.
static func _hidden_leap(content: ContentDB, fails: Array[String]) -> void:
	for aspect: int in [0, 1]:
		for version: String in [Pilot.VERSION, Pilot.HAND_VERSION, HONEST]:
			Pilot.select(version)
			for state: int in [0, 1]:
				var game: GlassvowGame = _position(content, aspect,
					[{"hp": 1, "poison": 5}, {"hp": 4}, {"hp": 100}])
				game.run.rng = Rng.new(state)
				var before: int = game.run.rng_state()
				var hp: Array = _visible(game)
				var expected: int = 10 if version == HONEST or state == 1 else 5
				var actual: int = Pilot.incoming_on(game.rules, game.run, game.cb)
				if actual != expected:
					fails.append("pilot honesty: %s aspect %d hidden state %d incoming %d, expected %d"
						% [version, aspect, state, actual, expected])
				Search.select(Search.SMOLDER_VERSION)
				var blow: int = Search._blow(game.rules, game.run, game.cb)
				if blow != expected:
					fails.append("pilot honesty: s3/%s aspect %d hidden state %d blow %d, expected %d"
						% [version, aspect, state, blow, expected])
				if game.run.rng_state() != before or _visible(game) != hp:
					fails.append("pilot honesty: %s mutates live RNG or visible foes" % version)


## Hand-calculated tick order: a leap spends one, only a unique recipient is
## credited, an earlier foe does not tick twice, and a handoff prevents later
## blows without erasing a blow that happened before it. Block does not stop a
## Smolder tick; Stagger/Silvering suppress their foe's own blow.
static func _known_ticks(content: ContentDB, fails: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"name": "no poison", "foes": [{"hp": 10}, {"hp": 10}], "n": 10},
		{"name": "nonlethal", "foes": [{"hp": 10, "poison": 9}], "n": 5},
		{"name": "exact ignores block", "foes": [{"hp": 5, "poison": 5, "block": 99}], "n": 0},
		{"name": "unique leap", "foes": [{"hp": 1, "poison": 5}, {"hp": 4}], "n": 0},
		{"name": "spend one first", "foes": [{"hp": 1, "poison": 5}, {"hp": 5}], "n": 5},
		{"name": "earlier already acted", "foes": [{"hp": 4}, {"hp": 1, "poison": 5}], "n": 5},
		{"name": "handoff first", "foes": [{"hp": 1, "poison": 1, "keeper": true}, {"hp": 10}], "n": 0},
		{"name": "handoff later", "foes": [{"hp": 10}, {"hp": 1, "poison": 1, "keeper": true}], "n": 5},
		{"name": "stagger", "foes": [{"hp": 10, "stagger": true}, {"hp": 10}], "n": 5},
		{"name": "silver", "foes": [{"hp": 10, "silver": true}, {"hp": 10}], "n": 5},
	]
	Pilot.select(HONEST)
	for aspect: int in [0, 1]:
		for spec: Dictionary in cases:
			var foes: Array = spec["foes"]
			var game: GlassvowGame = _position(content, aspect, foes)
			var expected: int = int(float(str(spec["n"])))
			var actual: int = Pilot.incoming_on(game.rules, game.run, game.cb)
			if actual != expected:
				fails.append("pilot honesty: p10 aspect %d %s incoming %d, expected %d"
					% [aspect, spec["name"], actual, expected])
			# _foes_after passes detached counterfactual twins; they must remain
			# read-only and replace, rather than supplement, the indexed live foe.
			var twin: EnemyCombatant = Pilot._twin(game.cb.enemies[0])
			twin.hp = 0
			var overridden: int = Pilot.incoming_on(game.rules, game.run, game.cb, {0: twin})
			if twin.hp != 0 or overridden < 0:
				fails.append("pilot honesty: detached forecast changed a twin or became negative")


## p10 inherits p9's expected hand, every catalogue score, and foreign-way
## rider suppression. A new version must not accidentally take the p8 branch.
static func _hand_and_riders(content: ContentDB, fails: Array[String]) -> void:
	for aspect: int in [0, 1]:
		var game: GlassvowGame = _position(content, aspect, [{"hp": 100}])
		game.run.player.deck = _cards(game.run, ["phantomBlades", "preparation", "preparation", "defend"])
		var scores: Dictionary = {}
		var expected: float = 0.0
		for version: String in [Pilot.HAND_VERSION, HONEST]:
			Pilot.select(version)
			Pilot.see_flame(content, game.run)
			if version == Pilot.HAND_VERSION:
				expected = Pilot.hand
			elif Pilot.hand != expected:
				fails.append("pilot honesty: p10 aspect %d lost p9 expected hand" % aspect)
			for id: String in ["phantomBlades", "preparation", "surge", "firstSpark"]:
				for upgraded: bool in [false, true]:
					var key: String = "%s/%s" % [id, upgraded]
					var score: float = Pilot.catalogue_card_score(content, aspect, id, upgraded)
					if version == Pilot.HAND_VERSION:
						scores[key] = score
					else:
						var prior: float = scores[key]
						if score != prior:
							fails.append("pilot honesty: p10 aspect %d %s score changed from p9" % [aspect, key])


## No UI preview is repaired by this instrument outcome. p9 currently sees no
## Phantom damage: it therefore targets the lower-HP blocked foe, not the other
## foe the real hand-size hit would kill. This explicitly freezes consumption
## rather than silently letting a future shared preview repair rewrite p9.
static func _historical_preview(content: ContentDB, fails: Array[String]) -> void:
	for aspect: int in [0, 1]:
		var game: GlassvowGame = _position(content, aspect, [{"hp": 8, "block": 99}, {"hp": 9}])
		game.cb.hand = _cards(game.run, ["phantomBlades", "defend", "defend", "defend"])
		var card: CardInst = game.cb.hand[0]
		Pilot.select(Pilot.HAND_VERSION)
		var previews: Dictionary = {}
		var target: Variant = Pilot._target(game, card, game.rules.card_data(card),
			game.cb.living_enemies(), previews)
		if target != 0 or previews.get(0) != null or previews.get(1) != null:
			fails.append("pilot honesty: historical p9 aspect %d Phantom preview/target changed" % aspect)


static func _visible(game: GlassvowGame) -> Array:
	var out: Array = []
	for foe: EnemyCombatant in game.cb.enemies:
		out.append([foe.hp, foe.block, foe.statuses.duplicate(), foe.staggered, foe.flags.duplicate()])
	return out


static func _position(content: ContentDB, aspect: int, specs: Array) -> GlassvowGame:
	var state: RunState = RunState.new_run(content, 12000, "honesty-probe", {"aspect": aspect})
	state.player.potions = ["", "", ""]
	var game: GlassvowGame = GlassvowGame.new(content, state)
	var ids: Array = []
	for spec: Dictionary in specs:
		ids.append("eternalKeeper" if spec.get("keeper", false) else "sporeling")
	game.apply({"t": "startCombat", "enemies": ids, "kind": "normal"})
	game.cb.hand = _cards(state, [])
	game.cb.player.statuses = {}
	game.cb.player.block = 0
	for i: int in range(specs.size()):
		var spec: Dictionary = specs[i]
		var foe: EnemyCombatant = game.cb.enemies[i]
		foe.hp = int(float(str(spec["hp"])))
		foe.block = int(float(str(spec.get("block", 0))))
		foe.statuses = {"poison": int(float(str(spec.get("poison", 0))))}
		foe.staggered = spec.get("stagger", false) == true
		foe.flags = {CombatRules.SILVERED: true} if spec.get("silver", false) else {}
		if not spec.get("keeper", false):
			foe.move_key = &"spit"
	return game


static func _cards(state: RunState, ids: Array) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for id: String in ids:
		out.append(CardInst.new(state.next_uid(), StringName(id), false))
	return out
