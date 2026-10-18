extends RefCounted
## A saved departure can finish its gift in another Main instance. Its choice
## must not depend on the previous process's temporary acceptance marker.

const Memory: GDScript = preload("res://tests/test_departure_persistence.gd")


static func run(fails: Array[String]) -> void:
	if not Preferences.new().has_method("last_departure"):
		fails.append("departure persistence resume: remembered setup contract is missing")
		return
	var previous: Preferences = Preferences.active
	Memory._cleanup()
	Memory._preferences(fails)
	var content: ContentDB = ContentDB.load_full()
	var first: Main = Memory._main(content, true, 1)
	first._forced_seed = 66103
	first._new_run({"aspect": 0, "vow": 1})
	var pending: RunState = first._load_run()
	Memory._check(fails, pending != null and pending.pending_lamplighter,
		"no durable pending gift was available for relaunch")
	Memory._dispose(first)
	if pending != null:
		Preferences.active = Preferences.read_from_disk(Memory.PREFS_PATH, Memory.PREFS_PATH + ".legacy")
		var resumed: Main = Memory._main(content, true, 1)
		# Plant the accepted checkpoint through the real persistence API, then
		# load it as a fresh process would; no new run or seed is constructed.
		Memory._check(fails, SaveService.store(pending, Memory.RUN_PATH), "could not restore pending checkpoint")
		var loaded: RunState = resumed._load_run()
		if loaded != null:
			resumed.game = GlassvowGame.new(content, loaded)
			resumed._map = WorldMap.from_dict(loaded.map)
			resumed._show_lamplighter()
			var offers: Array = resumed.game.run.quest_scratch.get("lamplighterOffer", {}).get("boons", [])
			Memory._check(fails, not offers.is_empty(), "resumed gift has no valid offer")
			if not offers.is_empty():
				resumed._on_lamplighter_confirmed(str(offers[0]), &"beacon")
				Memory._check(fails, Memory._last(Preferences.active)
					== {"aspect": "duskblade", "vow": 1, "art": "beacon"},
					"a gift completed after relaunch was not remembered")
				Memory._check(fails, resumed.game.run.seed == 66103,
					"remembering a resumed gift allocated another seed")
		else:
			fails.append("departure persistence resume: accepted pending checkpoint did not load")
		Memory._dispose(resumed)
	Preferences.active = previous
	Memory._cleanup()
