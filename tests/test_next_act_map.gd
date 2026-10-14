extends RefCounted
## `NextActMap` (#660 II.3): once an act's boss is beaten, the map the next act
## opens on is worked out ahead on a copy of the run, and it is the map `Main`
## then draws (`_show_boss_relic`, `_on_boss_relic_chosen`), whether the
## crown's offer was rolled yet or not, whichever relic is taken. The run
## itself is never touched, and nothing is predicted before the boss falls or
## past the final act.

const SEEDS: Array[int] = [1, 717, 17634]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_next_act_map: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for seed_value: int in SEEDS:
		for pick: int in [0, -1]:
			_beaten_boss(fails, content, seed_value, pick)
	_final_act(fails, content)


## A run at Act I's beaten boss: the prediction before the offer and after it
## both equal the next act's real map, and leave the run as it was. `pick` is
## the offer's relic taken (-1: none).
static func _beaten_boss(fails: Array[String], content: ContentDB, seed_value: int, pick: int) -> void:
	var run: RunState = RunState.new_run(content, seed_value, "run-next-act")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var map: WorldMap = WorldMap.for_run(run, content)
	game.quests.decorate_map(run, map)
	run.map = map.to_dict()
	var boss: int = -1
	for i: int in range(map.nodes.size()):
		if map.nodes[i].type == "boss":
			boss = i
	map.at = boss
	_check(fails, NextActMap.predict(run, map, content).is_empty(),
		"seed %d: nothing is predicted while the boss stands" % seed_value)
	map.cleared[boss] = true
	# The fight and its rewards draw on the run's randomness before the crown.
	for draw: int in range(17 + seed_value % 11):
		run.rng.next()
	run.map = map.to_dict()
	var before: Dictionary = run.to_save_dict()
	var early: Dictionary = NextActMap.predict(run, map, content)
	_check(fails, not early.is_empty() and run.to_save_dict() == before,
		"seed %d: the prediction leaves the run untouched" % seed_value)
	var offer: Array[String] = game.rewards.roll_boss_relics(run)
	run.quest_scratch["bossRelicOffer"] = offer.duplicate()
	var late: Dictionary = NextActMap.predict(run, map, content)
	if pick >= 0 and pick < offer.size():
		game.rewards.gain_relic(run, offer[pick])
	run.boss_relic_act = run.act
	run.quest_scratch.erase("bossRelicOffer")
	run.start_next_act(content)
	var real: WorldMap = WorldMap.for_run(run, content)
	game.quests.decorate_map(run, real)
	var drawn: Dictionary = real.to_dict()
	var bound: Dictionary = MapLayoutInputBinding.bind(real, run.act)
	for predicted: Dictionary in [early, late]:
		var next_run: RunState = predicted.get("run")
		var next_map: WorldMap = predicted.get("map")
		# The layout binds the map as drawn, its jitter unrounded: the map the
		# prefetch builds from must bind to the same nodes and edges.
		_check(fails, next_run != null and next_run.act == run.act and next_run.seed == run.seed
				and next_run.map == drawn and next_map != null
				and MapLayoutInputBinding.bind(next_map, next_run.act) == bound,
			"seed %d (relic %d): the predicted map is the one the next act opens on" % [seed_value, pick])


## The final act's boss leads to no next act: nothing is predicted.
static func _final_act(fails: Array[String], content: ContentDB) -> void:
	var run: RunState = RunState.new_run(content, SEEDS[0], "run-next-act-final")
	run.act = run.final_act()
	var map: WorldMap = WorldMap.for_run(run, content)
	for i: int in range(map.nodes.size()):
		if map.nodes[i].type == "boss":
			map.at = i
			map.cleared[i] = true
	_check(fails, NextActMap.predict(run, map, content).is_empty(), "nothing is predicted past the final act")
