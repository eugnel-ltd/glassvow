extends RefCounted
## Thirsting Shard's heal survives the final blow, victory relics and v2 saves.


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var cases: Array[Dictionary] = [
		{"tag": "final blow", "run_hp": 34, "combat_hp": 34},
		{"tag": "upgraded final blow", "up": true, "run_hp": 36, "combat_hp": 36},
		{"tag": "nonfinal kill", "enemies": 2, "run_hp": 30, "combat_hp": 34},
		{"tag": "nonlethal hit", "enemy_hp": 25, "run_hp": 30, "combat_hp": 34},
		{"tag": "victory relic", "relics": ["emberHeart"], "run_hp": 37, "combat_hp": 34},
		{"tag": "healing multiplier", "relics": ["sunBlossom"], "run_hp": 36, "combat_hp": 36},
		{"tag": "victory multiplier", "relics": ["sunBlossom", "emberHeart"], "run_hp": 41, "combat_hp": 36},
		{"tag": "maximum health", "hp": 68, "relics": ["emberHeart"], "run_hp": 70, "combat_hp": 70},
		{"tag": "lethal thorns", "hp": 1, "enemy_hp": 25, "thorns": 3, "run_hp": 0, "combat_hp": 4},
	]
	for case: Dictionary in cases:
		_check_case(fails, content, case)


static func _check_case(fails: Array[String], content: ContentDB, case: Dictionary) -> void:
	var tag: String = "leech healing %s: " % case["tag"]
	var run_state: RunState = RunState.new_run(content, 717, "run-leech-healing")
	run_state.player.relics.clear()
	for relic: String in case.get("relics", []):
		run_state.player.relics.append(relic)
	run_state.player.max_hp = 70
	run_state.player.hp = case.get("hp", 30)
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var enemies: Array = ["duskfang"]
	if case.get("enemies", 1) == 2:
		enemies.append("duskfang")
	game.apply({"t": "startCombat", "enemies": enemies})
	var upgraded: bool = case.get("up", false)
	var card: CardInst = CardInst.new(run_state.next_uid(), &"leechBlade", upgraded)
	game.cb.hand = [card]
	game.cb.player.energy = 3
	game.cb.enemies[0].hp = case.get("enemy_hp", 5)
	if case.has("thorns"):
		game.cb.enemies[0].statuses["thorns"] = case["thorns"]
	game.cb.queue.clear()
	var events: Array[Dictionary] = game.apply({"t": "playCard", "uid": card.uid, "target": 0})
	if game.last_ret != true:
		fails.append(tag + "a legal Thirsting Shard was rejected")
	if game.cb.player.hp != case["combat_hp"]:
		fails.append(tag + "combat heal changed: expected %d HP, got %d" % [case["combat_hp"], game.cb.player.hp])
	if run_state.player.hp != case["run_hp"]:
		fails.append(tag + "run health lost or duplicated the heal: expected %d HP, got %d" % [case["run_hp"], run_state.player.hp])
	var expected_result: String = "loss" if case.has("thorns") else (
		"" if case.has("enemies") or case.has("enemy_hp") else "win")
	if game.cb.result != expected_result:
		fails.append(tag + "expected result %s, got %s" % [expected_result, game.cb.result])
	var heals: Array[Dictionary] = events.filter(func(event: Dictionary) -> bool:
		return event.get("t") == EventTypes.HEAL and event.get("who") == "player")
	if heals.size() != 1:
		fails.append(tag + "the existing combat heal event was lost or repeated")
	if expected_result != "win":
		return
	var reloaded: RunState = RunState.from_save_dict(run_state.to_save_dict(), content)
	if reloaded == null or reloaded.player.hp != case["run_hp"]:
		fails.append(tag + "the final-blow heal did not survive the v2 save round-trip")
	elif CombatRules.new(content).start_combat(reloaded, ["duskfang"], &"normal").player.hp != case["run_hp"]:
		fails.append(tag + "the next combat did not start at the healed health")
