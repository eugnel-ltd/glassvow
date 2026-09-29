extends RefCounted
## Flame lock §11 run stats: `cracked` sums the Cracked the player applies and
## `embersGained` the Embers the lantern catches, those it opens a fight with
## included. Both are additive to the v2 save: an older save without them still
## loads, at zero.


static func run(fails: Array[String]) -> void:
	_cracked(fails)
	_embers_gained(fails)
	_embers_at_combat_start(fails)
	_old_save_loads(fails)


static func _fight(tag: String) -> GlassvowGame:
	var content: ContentDB = ContentDB.load_full(false)
	var run_state: RunState = RunState.new_run(content, 42113, "stats-%s" % tag, {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.max_hp = 200
	enemy.hp = 200
	enemy.block = 0
	return game


static func _play(game: GlassvowGame, id: String, target: Variant) -> void:
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	game.apply({"t": "playCard", "uid": card.uid, "target": target})


static func _stat(run_state: RunState, key: String) -> int:
	return int(float(str(run_state.stats.get(key, -1))))


## Cards, shatters and every other player source count; the player's own
## self-Cracked and anything an enemy applies do not.
static func _cracked(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("cracked")
	var enemy: EnemyCombatant = game.cb.enemies[0]
	_play(game, "eclipseSlash", 0)
	_play(game, "warCry", null)
	enemy.chips = enemy.facet_max - 1
	_play(game, "strike", 0)
	if not enemy.staggered:
		fails.append("run stats: the strike did not shatter the sporeling")
	_play(game, "frenzy", null)
	game.rules.add_status_player(game.cb, "vulnerable", 1)
	game.rules.add_status_enemy(game.cb, enemy, "vulnerable", 3)
	var cracked: int = _stat(game.run, "cracked")
	if cracked != 4:
		fails.append("run stats: cracked expected 4 (Eclipse Slash 1, War Cry 1, shatter 2), got %d"
			% cracked)


## Every Ember caught counts once, clamped at the cap; spending never does. The
## tally equals the positive EMBER deltas the fight emitted.
static func _embers_gained(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight("embers")
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.chips = enemy.facet_max - 1
	_play(game, "strike", 0)
	game.cb.embers = game.cb.ember_cap - 1
	game.rules.gain_embers(game.run, game.cb, 3)
	game.rules.gain_embers(game.run, game.cb, -2)
	var emitted: int = 0
	for ev: Dictionary in game.cb.queue:
		var n: int = int(float(str(ev.get("n", 0))))
		if ev.get("t") == EventTypes.EMBER and n > 0:
			emitted += n
	var gained: int = _stat(game.run, "embersGained")
	if gained != emitted or gained < 3:
		fails.append("run stats: embersGained %d must equal the %d Embers caught (shatter 2, cap 1)"
			% [gained, emitted])


## The Embers a fight opens with, the Ember Wind omen's and the Crown of Cinders',
## go straight into the lantern with no EMBER event, yet the lantern receives
## them: the tally equals the Embers held, after the cap (the omen's fill the
## plain cap of that moment, the Crown's are added under its own), whichever
## aspect carries them. A fight with neither starts at nothing and tallies
## nothing.
static func _embers_at_combat_start(fails: Array[String]) -> void:
	var plain_cap: int = CombatState.new().ember_cap
	# [label, aspect, omen's start Embers or -1 for no omen, Crown held, held, cap]
	var cases: Array = [
		["neither", 0, -1, false, 0, plain_cap],
		["the omen", 0, 2, false, 2, plain_cap],
		["the Crown", 0, -1, true, 2, 12],
		["the omen and the Crown", 0, 2, true, 4, 12],
		["an omen past the cap", 0, 99, false, plain_cap, plain_cap],
		["an omen past the cap and the Crown", 0, 99, true, plain_cap + 2, 12],
		["the Ashwarden with neither", 1, -1, false, 0, plain_cap],
		["the Ashwarden with the omen and the Crown", 1, 2, true, 4, 12],
	]
	for case_v: Variant in cases:
		var case: Array = case_v
		var label: String = str(case[0])
		var aspect: int = case[1]
		var omen_embers: int = case[2]
		var crowned: bool = case[3]
		var expected_held: int = case[4]
		var expected_cap: int = case[5]
		var opened: Dictionary = _opening(label, aspect, omen_embers, crowned)
		var game: GlassvowGame = opened["game"]
		var events: Array[Dictionary] = opened["events"]
		var held: int = game.cb.embers
		var tallied: int = _stat(game.run, "embersGained")
		if held != expected_held or game.cb.ember_cap != expected_cap:
			fails.append("run stats: %s opens with %d of %d Embers, expected %d of %d"
				% [label, held, game.cb.ember_cap, expected_held, expected_cap])
		if tallied != held:
			fails.append("run stats: %s opens with %d Embers but embersGained is %d"
				% [label, held, tallied])
		for ev: Dictionary in events:
			if ev.get("t") == EventTypes.EMBER:
				fails.append("run stats: %s emitted an EMBER event at combat start: %s" % [label, ev])
		var room: int = mini(1, game.cb.ember_cap - held)
		game.rules.gain_embers(game.run, game.cb, 1)
		if _stat(game.run, "embersGained") != tallied + room:
			fails.append("run stats: %s: a later catch must add %d to the opening tally %d, got %d"
				% [label, room, tallied, _stat(game.run, "embersGained")])


## A fight against one sporeling, opened on `startCombat` for an aspect whose run
## holds the Ember Wind omen for act one (`omen_embers` Embers, or none below 0)
## and, if `crowned`, the Crown of Cinders. Returns {game, events}: the start
## batch as `apply` gave it.
static func _opening(tag: String, aspect: int, omen_embers: int, crowned: bool) -> Dictionary:
	var content: ContentDB = ContentDB.load_full(false)
	var run_state: RunState = RunState.new_run(content, 42115, "stats-%s" % tag, {"aspect": aspect})
	if omen_embers >= 0:
		var omen: Dictionary = content.omens["emberWind"]
		var mods: Dictionary = omen["mods"]
		mods["startEmbers"] = omen_embers
		run_state.omens[0] = "emberWind"
	if crowned:
		run_state.player.relics.append("crownOfCinders")
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var events: Array[Dictionary] = game.apply(
		{"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	return {"game": game, "events": events}


static func _old_save_loads(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run_state: RunState = RunState.new_run(content, 42114, "stats-old-save", {"aspect": 0})
	run_state.stats["shatters"] = 5
	run_state.stats["cracked"] = 7
	run_state.stats["embersGained"] = 9
	var save: Dictionary = run_state.to_save_dict()
	if int(float(str(save.get("v", -1)))) != 2:
		fails.append("run stats: the save version must stay 2")
	var old: Dictionary = save.duplicate(true)
	var old_stats: Dictionary = old["stats"]
	old_stats.erase("cracked")
	old_stats.erase("embersGained")
	var loaded: RunState = RunState.from_save_dict(old, content)
	if loaded == null:
		fails.append("run stats: a v2 save without the new stats must load")
	elif _stat(loaded, "cracked") != 0 or _stat(loaded, "embersGained") != 0 \
			or _stat(loaded, "shatters") != 5:
		fails.append("run stats: an older save must load the new stats at zero, got %s"
			% loaded.stats)
	var current: RunState = RunState.from_save_dict(save, content)
	if current == null or _stat(current, "cracked") != 7 or _stat(current, "embersGained") != 9:
		fails.append("run stats: a current save must round-trip cracked and embersGained")
