extends RefCounted
## Public hand payoffs mirror real plays; frozen pilots retain their old input.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	for aspect: int in [0, 1]:
		for probe: Dictionary in _cases():
			_case(content, aspect, probe, fails)
		_counterfactual(content, aspect, fails)
		_mixed(aspect, fails)
		_pilot_target(content, aspect, fails)
	Pilot.select(Pilot.VERSION)
	Pilot.apply_policy({})


static func _cases() -> Array[Dictionary]:
	return [
		{"name": "base", "total": 9, "loss": 9},
		{"name": "upgraded", "up": true, "total": 12, "loss": 12},
		{"name": "alone", "others": 0, "total": 0, "loss": 0},
		{"name": "larger hand", "others": 6, "total": 18, "loss": 18},
		{"name": "copied UID", "copy": true, "total": 9, "loss": 9},
		{"name": "sequential floors", "str": 2, "weak": 1, "cracked": 1,
			"block": 5, "total": 12, "loss": 7},
		{"name": "third attack", "attacks": 2, "relics": ["ironTalisman"], "total": 10, "loss": 10},
		{"name": "tenth attack", "attacks": 9, "relics": ["executionersSeal"], "total": 18, "loss": 18},
		{"name": "thirtieth attack", "attacks": 29, "relics": ["ironTalisman", "executionersSeal"],
			"total": 20, "loss": 20},
		{"name": "relics after floors", "attacks": 29, "str": 2, "weak": 1, "cracked": 1,
			"relics": ["ironTalisman", "executionersSeal"], "block": 5, "total": 26, "loss": 21},
		{"name": "lethal", "hp": 9, "total": 9, "loss": 9, "lethal": true},
		{"name": "handoff", "keeper": true, "hp": 4, "total": 9, "loss": 3, "handoff": true},
	]


static func _case(content: ContentDB, aspect: int, probe: Dictionary, fails: Array[String]) -> void:
	var game: GlassvowGame = _position(content, aspect, probe)
	var card: CardInst = game.cb.hand[0]
	if probe.get("copy", false):
		card = card.combat_copy()
	var before: String = _snapshot(game)
	var preview_v: Variant = game.rules.preview_play(game.cb, card, 0, game.run)
	var historical: Variant = game.rules.preview_play(game.cb, card, 0, game.run, false)
	var label: String = "Phantom %s aspect %d" % [probe["name"], aspect]
	_check(fails, _snapshot(game) == before, label + ": preview mutated state")
	_check(fails, historical == null, label + ": historical preview gained Phantom")
	if typeof(preview_v) != TYPE_DICTIONARY:
		fails.append(label + ": public preview missing")
		return
	var preview: Dictionary = preview_v
	_check(fails, preview.get("total") == probe["total"] and preview.get("loss") == probe["loss"],
		label + ": wrong damage %s" % preview)
	_check(fails, preview.get("lethal") == probe.get("lethal", false)
		and preview.get("handoff") == probe.get("handoff", false), label + ": wrong terminal projection")
	var real: GlassvowGame = _position(content, aspect, probe)
	var old_block: int = real.cb.enemies[0].block
	var old_hp: int = real.cb.enemies[0].hp
	var events: Array[Dictionary] = real.apply({"t": "playCard", "uid": real.cb.hand[0].uid, "target": 0})
	var hits: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.get("t") == EventTypes.HIT_ENEMY:
			hits.append(event)
	_check(fails, real.last_ret == true and hits.size() == 1, label + ": real play did not hit once")
	if hits.size() != 1:
		return
	var hit: Dictionary = hits[0]
	var projected_hits: Array = preview["hits"]
	var projected_hit: Dictionary = projected_hits[0]
	var expected_total: int = probe["total"]
	var expected_blocked: int = mini(old_block, expected_total)
	_check(fails, projected_hit == {"dmg": probe["total"], "times": 1}
		and hit.get("amount") == preview["loss"] and hit.get("blocked") == expected_blocked,
		label + ": queued hit disagrees %s / %s" % [hit, preview])
	_check(fails, hit.get("dead") == preview["lethal"]
		and real.cb.finale_handoff == preview["handoff"], label + ": terminal state disagrees")
	var target: EnemyCombatant = real.cb.enemies[0]
	var projected_loss: int = preview["loss"]
	_check(fails, target.hp == old_hp - projected_loss
		and hit.get("hpAfter") == maxi(0, target.hp) and target.block == old_block - expected_blocked
		and target.chips == preview["chips"], label + ": block/chips disagree")
	if probe.get("handoff", false):
		_check(fails, target.hp == 1 and real.cb.over and real.cb.result == "win"
			and not preview["willShatter"], label + ": handoff is not a kill or shatter")


static func _counterfactual(content: ContentDB, aspect: int, fails: Array[String]) -> void:
	var game: GlassvowGame = _position(content, aspect, {})
	var absent: CardInst = CardInst.new(game.run.next_uid(), &"phantomBlades")
	var before: String = _snapshot(game)
	var preview: Dictionary = game.rules.preview_play(game.cb, absent, 0, game.run)
	_check(fails, preview["total"] == 12 and _snapshot(game) == before,
		"Phantom absent UID must retain all four unrelated held cards")
	var real: GlassvowGame = _position(content, aspect, {})
	var played: CardInst = CardInst.new(real.run.next_uid(), &"phantomBlades")
	real.cb.hand.append(played)
	var events: Array[Dictionary] = real.apply({"t": "playCard", "uid": played.uid, "target": 0})
	for event: Dictionary in events:
		if event.get("t") == EventTypes.HIT_ENEMY:
			_check(fails, event.get("amount") == preview["loss"], "Phantom absent UID real play differs")


static func _mixed(aspect: int, fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var definition: Dictionary = content.cards["phantomBlades"].duplicate(true)
	definition["effects"] = [{"kind": "dmg", "n": 3}, {"kind": "block", "n": 4},
		{"kind": "chip", "n": 2}, {"kind": "special", "id": "phantom", "n": 3}]
	content.cards["phantomBlades"] = definition
	var probe: Dictionary = {"block": 5}
	var game: GlassvowGame = _position(content, aspect, probe)
	var before: String = _snapshot(game)
	var public: Dictionary = game.rules.preview_play(game.cb, game.cb.hand[0], 0, game.run)
	var historical: Dictionary = game.rules.preview_play(game.cb, game.cb.hand[0], 0, game.run, false)
	var expected: Dictionary = {"hits": [{"dmg": 3, "times": 1}], "total": 3, "loss": 0,
		"lethal": false, "block": 4, "chips": 2 if aspect == 0 else 0, "willShatter": false}
	_check(fails, historical == expected, "Phantom mixed false must preserve every old field: %s" % historical)
	_check(fails, public["total"] == 12 and public["loss"] == 7 and public["block"] == 4,
		"Phantom mixed public must include both hits")
	_check(fails, _snapshot(game) == before, "Phantom mixed preview mutated state")
	var real: GlassvowGame = _position(content, aspect, probe)
	real.apply({"t": "playCard", "uid": real.cb.hand[0].uid, "target": 0})
	var public_loss: int = public["loss"]
	_check(fails, real.cb.enemies[0].hp == 100 - public_loss
		and real.cb.enemies[0].chips == public["chips"] and real.cb.player.block == public["block"],
		"Phantom mixed real state differs")


static func _pilot_target(content: ContentDB, aspect: int, fails: Array[String]) -> void:
	var game: GlassvowGame = _position(content, aspect, {"two": true})
	game.cb.enemies[0].hp = 8
	game.cb.enemies[0].block = 99
	game.cb.enemies[1].hp = 9
	var before: String = _snapshot(game)
	var card: CardInst = game.cb.hand[0]
	var public: Dictionary = game.rules.preview_play(game.cb, card, 1, game.run)
	_check(fails, public["lethal"] and public["loss"] == 9, "Phantom public must see unblocked kill")
	for version: String in Pilot.VERSIONS:
		Pilot.select(version)
		Pilot.apply_policy({})
		var previews: Dictionary = {}
		var target: Variant = Pilot._target(game, card, game.rules.card_data(card),
			game.cb.living_enemies(), previews)
		_check(fails, target == 0 and previews.get(0) == null and previews.get(1) == null,
			"Phantom frozen pilot %s changed old lower-HP target" % version)
	_check(fails, _snapshot(game) == before, "Phantom pilot/public previews mutated state")


static func _position(content: ContentDB, aspect: int, probe: Dictionary) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 220545, "phantom-preview", {"aspect": aspect})
	run_state.player.relics.clear()
	for relic: String in probe.get("relics", []):
		run_state.player.relics.append(relic)
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var ids: Array[String] = ["eternalKeeper" if probe.get("keeper", false) else "sporeling"]
	if probe.get("two", false):
		ids.append("sporeling")
	game.apply({"t": "startCombat", "enemies": ids, "kind": "normal"})
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	var upgraded: bool = probe.get("up", false)
	game.cb.hand.append(CardInst.new(run_state.next_uid(), &"phantomBlades", upgraded))
	var others: int = probe.get("others", 3)
	for _i: int in range(others):
		game.cb.hand.append(CardInst.new(run_state.next_uid(), &"defend"))
	game.cb.counters_attacks = probe.get("attacks", 0)
	game.cb.player.energy = 10
	game.cb.player.block = 0
	game.cb.player.statuses = {"str": probe.get("str", 0), "weak": probe.get("weak", 0)}
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy.hp = probe.get("hp", 100)
		enemy.max_hp = 100
		enemy.block = probe.get("block", 0)
		enemy.statuses = {"vulnerable": probe.get("cracked", 0)}
		enemy.chips = 0
		enemy.facet_max = 100
	game.cb.queue.clear()
	return game


static func _snapshot(game: GlassvowGame) -> String:
	return JSON.stringify({"combat": game.cb.to_dict(), "queue": game.cb.queue,
		"counters": [game.cb.counters_attacks, game.cb.counters_played, game.cb.first_card_played],
		"pending": [game.cb.pending_chips_active, game.cb.pending_chips, game.cb.finale_handoff],
		"rng": game.run.rng_state(), "uid": game.run.uid, "stats": game.run.stats,
		"relics": game.run.player.relics})


static func _check(fails: Array[String], passed: Variant, message: String) -> void:
	if passed != true:
		fails.append(message)
