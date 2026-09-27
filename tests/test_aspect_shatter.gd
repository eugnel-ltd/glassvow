extends RefCounted
## H10: shatter/stagger is Dusk-only. H11: enemy Smolder from the player is Ash-only.


static func run(fails: Array[String]) -> void:
	_connecting_strike(fails, 0, true)
	_connecting_strike(fails, 1, false)
	_unbroken_crown(fails)
	_unbroken_crown_scalars(fails)
	_dusk_emberbite_no_poison(fails)
	_dusk_flare_no_poison(fails)
	_ash_ashbite_applies_poison(fails)
	_dusk_cinder_veined_still_hits_player(fails)


static func _connecting_strike(fails: Array[String], aspect: int, expect_chip: bool) -> void:
	var who: String = "Dusk" if aspect == 0 else "Ash"
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42110, "h10-%d" % aspect, {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect shatter: %s fight did not start" % who)
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.chips = enemy.facet_max - 1
	enemy.staggered = false
	enemy.hp = maxi(enemy.hp, 20)
	var strike: CardInst = CardInst.new(game.run.next_uid(), &"strike", false)
	game.cb.hand.append(strike)
	game.cb.player.energy = maxi(game.cb.player.energy, 1)
	var preview: Variant = game.rules.preview_play(game.cb, strike, 0, game.run)
	game.apply({"t": "playCard", "uid": strike.uid, "target": 0})
	if typeof(preview) != TYPE_DICTIONARY:
		fails.append("aspect shatter: %s preview missing" % who)
		return
	var pv: Dictionary = preview
	var preview_chips: int = int(float(str(pv["chips"])))
	var will: bool = pv["willShatter"] == true
	if expect_chip:
		if not enemy.staggered:
			fails.append("aspect shatter: Dusk connecting strike did not stagger")
		if preview_chips <= 0 or not will:
			fails.append("aspect shatter: Dusk preview must chip and willShatter")
	else:
		if enemy.chips != enemy.facet_max - 1:
			fails.append("aspect shatter: Ash connecting strike chipped (%d)" % enemy.chips)
		if enemy.staggered:
			fails.append("aspect shatter: Ash connecting strike staggered")
		if preview_chips != 0 or will:
			fails.append("aspect shatter: Ash preview must report chips=0")


static func _stacks(statuses: Dictionary, id: String) -> int:
	return int(float(str(statuses.get(id, 0))))


static func _fight(aspect: int, tag: String) -> GlassvowGame:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42111, tag, {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	return game


static func _play(game: GlassvowGame, card_id: StringName) -> EnemyCombatant:
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.statuses.erase("poison")
	var card: CardInst = CardInst.new(game.run.next_uid(), card_id, false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	game.apply({"t": "playCard", "uid": card.uid, "target": 0})
	return enemy


static func _dusk_emberbite_no_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(0, "h11-emberbite")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk Emberbite fight did not start")
		return
	var enemy: EnemyCombatant = _play(game, &"venomStrike")
	if _stacks(game.cb.player.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Emberbite applied Smolder to the player")
	if _stacks(enemy.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Emberbite applied Smolder (%d)" % _stacks(enemy.statuses, "poison"))


static func _dusk_flare_no_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(0, "h11-flare")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk Flare fight did not start")
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.statuses.erase("poison")
	var hp_before: int = enemy.hp
	game.cb.embers = maxi(game.cb.embers, 3)
	game.apply({"t": "useArt"})
	if _stacks(enemy.statuses, "poison") != 0:
		fails.append("aspect smolder: Dusk Flare applied Smolder (%d)" % _stacks(enemy.statuses, "poison"))
	if hp_before - enemy.hp != 9:
		fails.append("aspect smolder: Dusk Flare should deal 9, dealt %d" % (hp_before - enemy.hp))


static func _ash_ashbite_applies_poison(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(1, "h11-ashbite")
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Ash Ashbite fight did not start")
		return
	var enemy: EnemyCombatant = _play(game, &"ashBite")
	if _stacks(enemy.statuses, "poison") < 2:
		fails.append("aspect smolder: Ash Ashbite did not apply Smolder (%d)"
			% _stacks(enemy.statuses, "poison"))


static func _dusk_cinder_veined_still_hits_player(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new_run(content, 42111, "h11-cinder", {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "elite", "affix": "cinderVeined"})
	if game.cb == null or game.cb.enemies.is_empty():
		fails.append("aspect smolder: Dusk cinderVeined fight did not start")
		return
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.block = 0
	enemy.staggered = false
	enemy.move_key = &"spit"
	game.cb.player.block = 0
	game.apply({"t": "endTurn"})
	var saw_player_smolder: bool = false
	for ev: Dictionary in game.cb.queue:
		if str(ev.get("t", "")) == "status" and str(ev.get("id", "")) == "poison" \
				and str(ev.get("who", "")) == "player":
			saw_player_smolder = true
			break
	if not saw_player_smolder:
		fails.append("aspect smolder: cinderVeined must still leave Smolder on Dusk")


static func _unbroken_crown(fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(0, "unbroken-crown")
	game.run.player.relics.append("unbrokenCrown")
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.hp = 100
	enemy.chips = enemy.facet_max - 1
	game.cb.player.block = 0
	var strike: CardInst = CardInst.new(game.run.next_uid(), &"strike", false)
	var preview: Dictionary = game.rules.preview_play(game.cb, strike, 0, game.run)
	if int(float(str(preview["chips"]))) != 0 or preview["willShatter"]:
		fails.append("Unbroken Crown: preview promises chip or shatter")
	_play(game, &"venomStrike")
	if _stacks(enemy.statuses, "poison") != 7:
		fails.append("Unbroken Crown: Emberbite must apply its 4 Smolder plus crown 3")
	if enemy.chips != enemy.facet_max - 1 or enemy.staggered:
		fails.append("Unbroken Crown: attack chipped or staggered")
	if game.cb.player.block != 3:
		fails.append("Unbroken Crown: attack must gain 3 Ward")
	game.rules.apply_chips(game.run, game.cb, enemy, 9)
	if enemy.chips != enemy.facet_max - 1:
		fails.append("Unbroken Crown: explicit chips must also be suppressed")
	var content: ContentDB = ContentDB.load_full(false)
	var rewards: RewardRules = RewardRules.new(content)
	for aspect: int in [0, 1]:
		var run_state: RunState = RunState.new_run(content, 42112, "crown-pool", {"aspect": aspect})
		if rewards.relic_pool(run_state, "boss").has("unbrokenCrown") != (aspect == 0):
			fails.append("Unbroken Crown: wrong aspect availability")
		run_state.unlocks.append("relic:unbrokenCrown")
		if rewards.relic_pool(run_state, "boss").has("unbrokenCrown") != (aspect == 0):
			fails.append("Unbroken Crown: unlock bypasses aspect availability")


static func _unbroken_crown_scalars(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	content.relics["unbrokenCrown"]["wardPerAttack"] = 7
	content.relics["unbrokenCrown"]["smolderPerAttack"] = 6
	var run_state: RunState = RunState.new_run(content, 42113, "crown-scalars", {"aspect": 0})
	run_state.player.relics.append("unbrokenCrown")
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling", "sporeling"], "kind": "normal"})
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy.hp = 100
		enemy.block = 0
		enemy.statuses.erase("poison")
	game.cb.player.block = 0
	game.cb.player.statuses["venomous"] = 2
	_play(game, &"cleave")
	for enemy: EnemyCombatant in game.cb.enemies:
		if _stacks(enemy.statuses, "poison") != 8 or enemy.chips != 0:
			fails.append("Unbroken Crown: AoE must combine tuned Smolder and venomous without chips")
	if game.cb.player.block != 7:
		fails.append("Unbroken Crown: tuned Ward must apply once per attack, not per target")
