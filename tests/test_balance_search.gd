extends RefCounted
## Flame readout 8's search player (tools/balance_search.gd): it plans on a
## detached copy and never touches the live fight; the copy plays exactly as the
## live fight does; every action it plays is legal; a seeded run replays; and on
## a fixed set of 20 development seeds it wins at least as many fights and runs
## as the greedy pilot it is built on.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
## Development seeds (lock §11: 12000-12999), adaptive arm, V0 full pool.
const SEED0: int = 12000
const SEEDS: int = 20


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.apply_policy({})
	_plans_on_a_copy(content, fails)
	_replays(content, fails)
	_never_below_greedy(content, fails)
	Pilot.apply_policy({})


## Act-1 fights (a normal, an elite and the boss) on three seeds, played turn by
## turn: planning leaves the live fight byte for byte as it was; each planned
## action is legal live; and a copy that plays the same line ends where the live
## fight ends, so the search reads the fight the rules would produce.
static func _plans_on_a_copy(content: ContentDB, fails: Array[String]) -> void:
	var turns: int = 0
	var searched: int = 0
	for seed: int in [12001, 12002, 12003]:
		for kind: String in ["monster", "elite", "boss"]:
			var game: GlassvowGame = _fight(content, seed, kind)
			for _turn: int in range(Sim.TURN_GUARD):
				if game.cb.over:
					break
				turns += 1
				Pilot._use_potions(game)
				for _plan: int in range(Search.REPLAN_GUARD):
					if game.cb.over:
						break
					var before: String = _snapshot(game.run, game.cb)
					var plan: Search.Plan = Search.plan_turn(game)
					if _snapshot(game.run, game.cb) != before:
						fails.append("balance search: planning moved the live fight (seed %d, %s)" % [seed, kind])
						return
					if plan.greedy:
						Pilot.play_hand(game)
						break
					searched += 1
					var run_copy: RunState = Search.clone_run(game.run)
					var cb_copy: CombatState = Search.clone_combat(game.cb)
					var copy: Search.Position = Search.Position.new(run_copy, cb_copy)
					for action: Dictionary in plan.actions:
						if not Search._apply(game.rules, copy, action) or not Search.execute(game, action):
							fails.append("balance search: illegal planned action %s (seed %d, %s)"
								% [action, seed, kind])
							return
					if _snapshot(copy.run, copy.cb) != _snapshot(game.run, game.cb):
						fails.append("balance search: the copy and the live fight part ways (seed %d, %s)"
							% [seed, kind])
						return
					if not plan.reopen or plan.actions.is_empty():
						break
				if not game.cb.over:
					game.apply({"t": "endTurn"})
	if searched == 0 or turns < 20:
		fails.append("balance search: the copy check is vacuous (%d turns, %d searched plans)"
			% [turns, searched])


## A seeded search run replays exactly, outcome and per-fight flame rows alike.
static func _replays(content: ContentDB, fails: Array[String]) -> void:
	var rows: Array[Dictionary] = []
	for _i: int in range(2):
		rows.append(Sim.simulate(content, "duskblade", SEED0, 0, PackedStringArray(), {}, false, false,
			{}, null, false, "full", "search"))
	if Sim.outcome_digest(rows[0]) != Sim.outcome_digest(rows[1]) \
			or JSON.stringify(rows[0]["flame"]) != JSON.stringify(rows[1]["flame"]):
		fails.append("balance search: seed %d does not replay" % SEED0)
	if str(rows[0]["flame"].get("play", "")) != "search":
		fails.append("balance search: the flame row must name its player")


## The sim's own fight measures (a fight row's result and HP lost) on 60 fixed
## fights: an Act-1 normal, elite and boss on each of seeds 12000-12019, each
## played from the same start by both players. The search must win at least as
## many and lose no more HP in all; no planned action may be refused live.
## Whole runs on 20 seeds diverge too far to compare one by one; readout 8
## compares them paired over 1,000 seeds per cell.
static func _never_below_greedy(content: ContentDB, fails: Array[String]) -> void:
	var players: Array[GDScript] = [Pilot, Search]
	var won: Array[int] = [0, 0]
	var lost_hp: Array[int] = [0, 0]
	Search.reset_counters()
	for i: int in range(players.size()):
		for offset: int in range(SEEDS):
			for kind: String in ["monster", "elite", "boss"]:
				var game: GlassvowGame = _fight(content, SEED0 + offset, kind)
				_play_out(game, players[i])
				won[i] += 1 if game.cb.result == "win" else 0
				lost_hp[i] += game.cb.hp_lost
	if won[1] < won[0] or lost_hp[1] > lost_hp[0]:
		fails.append("balance search: 60 fights, won %d and %d HP lost against greedy's %d and %d"
			% [won[1], lost_hp[1], won[0], lost_hp[0]])
	if Search.refused != 0 or Search.plans == 0:
		fails.append("balance search: %d of %d plans refused live" % [Search.refused, Search.plans])


## A fight to its end as the simulator plays it, the turn guard included.
static func _play_out(game: GlassvowGame, player: GDScript) -> void:
	while not game.cb.over and game.cb.turn < Sim.TURN_GUARD:
		player.play_turn(game)
		if not game.cb.over:
			game.apply({"t": "endTurn"})


static func _fight(content: ContentDB, seed: int, kind: String) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, seed, "search-%d-%s" % [seed, kind], {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var enemies: Array[String] = game.rewards.roll_encounter(run_state, kind, 4)
	game.apply({"t": "startCombat", "enemies": enemies,
		"kind": "normal" if kind == "monster" else kind})
	return game


## Everything the combat rules write, as one string.
static func _snapshot(run_state: RunState, cb: CombatState) -> String:
	return JSON.stringify([cb.to_dict(), run_state.stats, run_state.rng_state(), run_state.player.hp,
		run_state.player.potions, run_state.uid, cb.kindles_this_turn, cb.art_used_turn, cb.hp_lost,
		cb.counters_played, cb.first_card_played])
