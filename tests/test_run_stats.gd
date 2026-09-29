extends RefCounted
## Flame lock §11 run stats: `cracked` sums the Cracked the player applies and
## `embersGained` the Embers the lantern catches. Both are additive to the v2
## save: an older save without them still loads, at zero.


static func run(fails: Array[String]) -> void:
	_cracked(fails)
	_embers_gained(fails)
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
