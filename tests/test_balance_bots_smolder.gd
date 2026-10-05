extends RefCounted
## #544 P6b: search `s3` credits the enemy phase's Smolder ticks (pilot `p9`).
##
## Probes: fixed Ashwarden fights whose best line is known by hand, each played as
## the simulator plays it and then ended through the rules, so the tick itself
## shows what the line did. `s3` must find each one. `s2` must miss the probe that
## the kill alone decides, and find the other two: its blow forecast already ticks
## Smolder (`Pilot.incoming_on`). Then `_tick`, the tick as the rules have it, case
## by case, and the two credits beside the kill: a tick that ends the fight, and
## the Smolder way's stat.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
const ASH: int = 1


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.apply_policy({})
	Pilot.select(Pilot.HAND_VERSION)
	_probes(content, fails)
	_ticks(content, fails)
	_credits(content, fails)
	Pilot.select(Pilot.VERSION)
	Search.select(Search.VERSION)
	Pilot.apply_policy({})


## Each probe is one turn from a fixed position under `s3` and under `s2`, then the
## turn ends. `found` reads the fight after the enemy phase.
static func _probes(content: ContentDB, fails: Array[String]) -> void:
	for probe: Dictionary in _probe_table():
		var found: Dictionary = {}
		var value: Dictionary = {}
		for version: String in [Search.SMOLDER_VERSION, Search.HAND_VERSION]:
			Search.select(version)
			value[version] = Search.plan_turn(_position(content, probe)).value
			var game: GlassvowGame = _position(content, probe)
			Search.play_turn(game)
			var first: String = _first_play(game)
			if not game.cb.over:
				game.apply({"t": "endTurn"})
			found[version] = probe["found"].call(game, first)
		if not found[Search.SMOLDER_VERSION]:
			fails.append("balance bots: s3 misses the probe %s" % probe["name"])
		if found[Search.HAND_VERSION] != probe["s2"]:
			fails.append("balance bots: s2 %s the probe %s"
				% ["finds" if found[Search.HAND_VERSION] else "misses", probe["name"]])
		if probe.get("same", false) and value[Search.SMOLDER_VERSION] != value[Search.HAND_VERSION]:
			fails.append("balance bots: s3 scores the probe %s at %f, s2 at %f"
				% [probe["name"], value[Search.SMOLDER_VERSION], value[Search.HAND_VERSION]])


## The probes, checked by hand at the default policy (one point of damage dealt is
## worth 1.08, a kill 20, a stack of `n` Smolder gained ½ × n(n+1) × 0.78). The hero
## is an Ashwarden at 30 HP; each Sporeling Blooms (no blow) unless stated; the
## draw pile is all Defends.
static func _probe_table() -> Array[Dictionary]:
	return [
		# The kill alone decides. Energy 2. Sporeling A: 4 HP behind 10 block, out of
		# reach of the hand's attacks. Sporeling B: 500 HP. Ashen Choir on A (4 Smolder)
		# kills it at the turn's end: s3 scores 4 x 1.08 + 20 = 24.3, s2 only the setup,
		# 7.8. Ashbite on B scores 6 x 1.08 + 2.3 = 8.8 under both, so s2 plays it and A
		# lives. The Choir lands exactly on A's HP, and A's block does not stop it.
		{"name": "lethal tick", "energy": 2, "s2": false,
			"foes": [{"hp": 4, "block": 10}, {"hp": 500}],
			"hand": ["ashenChoir", "ashBite", "defend", "defend", "defend"],
			"found": func(game: GlassvowGame, _first: String) -> bool:
				return game.cb.enemies[0].hp <= 0 and game.cb.enemies[1].hp > 0},
		# The tick lands before the blow. Energy 1, one Sporeling at 4 HP behind 10
		# block, its Spore Spit raised by 36 Fervor to 40 against the hero's 30 HP. Only
		# Ashen Choir survives: the tick kills the Sporeling before it acts and the fight
		# is won. A Defend leaves 35 to take; a Strike breaks only its block. s2 finds it
		# too, as the forecast it scores the blow by already ticks Smolder.
		{"name": "tick before a lethal blow", "energy": 1, "s2": true,
			"foes": [{"hp": 4, "block": 10, "str": 36, "move": "spit"}],
			"hand": ["ashenChoir", "strike", "defend", "defend", "defend"],
			"found": func(game: GlassvowGame, _first: String) -> bool:
				return game.cb.over and game.cb.result == "win"},
		# The guard: a tick that does not kill earns nothing new. Energy 1, one Sporeling
		# at 20 HP. Strike deals 6 now (6.5); Smother's 2 Smolder deal 3 over two turns
		# (2.3), and its block has no blow to stop. Both play Strike, and s3 scores it as
		# s2 does.
		{"name": "non-lethal guard", "energy": 1, "s2": true, "same": true,
			"foes": [{"hp": 20}],
			"hand": ["smother", "strike", "defend", "defend", "defend"],
			"found": func(game: GlassvowGame, first: String) -> bool:
				return first == "strike" and game.cb.enemies[0].hp == 14},
	]


## `_tick` against the rules (`CombatRules.end_turn`), one fight at a time: each
## entry is the foes (`hp`, `smolder`, `block`, `keeper` for the finale boss) and
## the `idx`es the ticks kill, and whether the fight ends there.
static func _ticks(content: ContentDB, fails: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		# Exactly lethal, block or no block.
		{"name": "exact", "foes": [{"hp": 5, "smolder": 5, "block": 9}], "killed": [0], "ends": true},
		# One short: its later ticks will kill it, but not this phase's.
		{"name": "one short", "foes": [{"hp": 5, "smolder": 4}], "killed": [], "ends": false},
		# The leap with one foe to land on: A dies keeping 4, B takes them: 2 + 4 = 6.
		{"name": "leap", "foes": [{"hp": 3, "smolder": 5}, {"hp": 6, "smolder": 2}],
			"killed": [0, 1], "ends": true},
		# The tick spends one before the leap: 1 + 4 = 5 leaves B standing at 6 HP.
		{"name": "leap keeps one less", "foes": [{"hp": 3, "smolder": 5}, {"hp": 6, "smolder": 1}],
			"killed": [0], "ends": false},
		# The leap with two to land on: the run RNG picks, the line has not seen it.
		{"name": "unseen leap", "foes": [{"hp": 3, "smolder": 5}, {"hp": 4}, {"hp": 100}],
			"killed": [0], "ends": false},
		# Each foe ticks once: B's leap lands on A after A's tick.
		{"name": "one tick each", "foes": [{"hp": 10, "smolder": 2}, {"hp": 2, "smolder": 5}],
			"killed": [1], "ends": false},
		# The finale boss's tick to 0 is its handoff: no kill, and the fight is won,
		# whoever else still stands.
		{"name": "handoff", "foes": [{"hp": 4, "smolder": 4, "keeper": true}, {"hp": 10}],
			"killed": [], "ends": true},
	]
	for case: Dictionary in cases:
		var game: GlassvowGame = _position(content, {"energy": 0, "foes": case["foes"], "hand": []})
		var tick: Search.Tick = Search._tick(game.rules, game.cb)
		var killed: Array = case["killed"]
		var ends: bool = case["ends"]
		if str(tick.killed) != str(killed) or tick.ends != ends:
			fails.append("balance bots: s3's tick, %s: killed %s, ends %s; expected %s, %s"
				% [case["name"], tick.killed, tick.ends, killed, case["ends"]])


## The credits, read from `evaluate`. The lethal-tick probe after Ashen Choir on A:
## the Smolder way's stat adds EXPRESSION for the kill under `s3`, nothing under
## `s2`. The finale boss at its handoff with a Sporeling beside it: the turn's end
## is a won fight under `s3`, not under `s2`.
static func _credits(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _position(content, _probe_table()[0])
	var choir: int = game.cb.hand[0].uid
	var at: Search.Position = Search._copy(Search.Position.new(game.run, game.cb))
	Search._apply(game.rules, at, {"t": "playCard", "uid": choir, "target": 0})
	for version: String in [Search.SMOLDER_VERSION, Search.HAND_VERSION]:
		Search.select(version)
		var turn: Search.Turn = _turn(game)
		var plain: float = Search.evaluate(turn, at)
		var stats: Array[String] = [Search.SMOLDER_KILLS]
		turn.expression = stats
		var way: float = Search.evaluate(turn, at) - plain
		var expected: float = Search.EXPRESSION if version == Search.SMOLDER_VERSION else 0.0
		if absf(way - expected) > 1.0e-9:
			fails.append("balance bots: %s credits the Smolder way's stat %f for a tick kill, expected %f"
				% [version, way, expected])
	var keeper: GlassvowGame = _position(content, {"energy": 0, "hand": [],
		"foes": [{"hp": 4, "smolder": 4, "keeper": true}, {"hp": 10}]})
	for version: String in [Search.SMOLDER_VERSION, Search.HAND_VERSION]:
		Search.select(version)
		var turn: Search.Turn = _turn(keeper)
		var won: bool = Search.evaluate(turn, turn.start) >= Search.WIN
		if won != (version == Search.SMOLDER_VERSION):
			fails.append("balance bots: %s %s the finale boss's handoff tick as a won fight"
				% [version, "scores" if won else "does not score"])


## A turn's search state at the live position, as `Search.plan_turn` builds it.
static func _turn(game: GlassvowGame) -> Search.Turn:
	var turn: Search.Turn = Search.Turn.new()
	turn.rules = game.rules
	turn.content = game.content
	turn.start = Search.Position.new(game.run, game.cb)
	turn.start_stats = game.run.stats.duplicate()
	turn.start_blow = Search._blow(game.rules, game.run, game.cb)
	return turn


## The id of the first card the turn played.
static func _first_play(game: GlassvowGame) -> String:
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.PLAY:
			return str(event.get("id", ""))
	return ""


## An Ashwarden's fight on its first turn, rebuilt to the probe's position: one
## Sporeling for each foe listed (the Eternal Keeper for `keeper`), in order.
static func _position(content: ContentDB, probe: Dictionary) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 12000, "probe", {"aspect": ASH})
	run_state.player.potions = ["", "", ""]
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var foes: Array = probe["foes"]
	var ids: Array = []
	for foe_v: Variant in foes:
		var spec: Dictionary = foe_v
		ids.append("eternalKeeper" if spec.get("keeper", false) else "sporeling")
	game.apply({"t": "startCombat", "enemies": ids, "kind": "normal"})
	var cb: CombatState = game.cb
	var hand: Array = probe["hand"]
	cb.hand = _cards(run_state, hand)
	cb.draw = _cards(run_state, ["defend", "defend", "defend", "defend", "defend", "defend"])
	cb.discard = _cards(run_state, [])
	cb.exhaust = _cards(run_state, [])
	cb.embers = 0
	cb.player.hp = 30
	run_state.player.hp = 30
	cb.player.block = 0
	cb.player.statuses = {}
	cb.player.energy = int(float(str(probe["energy"])))
	for i: int in range(foes.size()):
		var spec: Dictionary = foes[i]
		var foe: EnemyCombatant = cb.enemies[i]
		foe.hp = int(float(str(spec["hp"])))
		foe.max_hp = maxi(foe.hp, foe.max_hp)
		foe.block = int(float(str(spec.get("block", 0))))
		foe.statuses = {}
		foe.staggered = false
		for key: String in ["str", "smolder"]:
			var n: int = int(float(str(spec.get(key, 0))))
			if n > 0:
				foe.statuses["poison" if key == "smolder" else key] = n
		if not spec.get("keeper", false):
			foe.move_key = StringName(str(spec.get("move", "grow")))
	return game


static func _cards(run_state: RunState, ids: Array) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for id_v: Variant in ids:
		out.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	return out
