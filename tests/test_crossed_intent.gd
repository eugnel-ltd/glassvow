class_name TestCrossedIntent
extends RefCounted


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rules: CombatRules = CombatRules.new(content)
	var dusk: RunState = RunState.new_run(content, 42, "crossed", {"aspect": 0})
	dusk.player.relics.append("crossedThreads")
	var cb: CombatState = _combat(content, [["sporeling", "spit"], ["thornling", "prick"], ["sporeling", "spit"]])
	rules._form_crossed_link(dusk, cb)
	_check(fails, cb.crossed_intent.get("indices", []) == [0, 1], "stable tie selects [0, 1]")
	_check(fails, rules.live_crossed_link(cb) != null, "producer exposes a live link")
	_check(fails, rules.effective_enemy_move(cb, cb.enemies[0]).get("dmg") == 4,
		"producer does not move an effective payload")
	var card: CardInst = CardInst.new(900, &"crossedIntent", false)
	cb.hand.append(card)
	cb.player.energy = 3
	_check(fails, rules.can_play(dusk, cb, card, null), "linked Dusk can play consumer")
	_check(fails, rules.play_card(dusk, cb, card.uid), "consumer resolves")
	_check(fails, cb.enemies[0].move_key == &"spit" and cb.enemies[1].move_key == &"prick",
		"original move keys stay on their bodies")
	_check(fails, rules.effective_enemy_move(cb, cb.enemies[0]).get("dmg") == 6
		and rules.effective_enemy_move(cb, cb.enemies[1]).get("dmg") == 4,
		"consumer exchanges complete effective payloads")
	_check(fails, rules.live_crossed_link(cb) == null, "consumption hides the live projection")
	var queue_before: int = cb.queue.size()
	rules.end_turn(dusk, cb)
	var acts: Array = cb.queue.slice(queue_before).filter(
		func(event: Dictionary) -> bool: return event.get("t") == EventTypes.ENEMY_ACT)
	_check(fails, acts.size() == 3 and acts[0].get("payload", {}).get("dmg") == 6
		and acts[1].get("payload", {}).get("dmg") == 4,
		"enemyAct reports the exchanged effective payloads")
	_check(fails, cb.enemies[0].last_moves[-1] == "spit"
		and cb.enemies[1].last_moves[-1] == "prick",
		"enemy history records each body's original move key")

	var null_cb: CombatState = _combat(content, [["sporeling", "spit"], ["sporeling", "spit"]])
	rules._form_crossed_link(dusk, null_cb)
	_check(fails, null_cb.crossed_intent.is_empty(), "equal threat is exact-null")
	var impure: CombatState = _combat(content, [["gloomslime", "ooze"], ["sporeling", "spit"]])
	rules._form_crossed_link(dusk, impure)
	_check(fails, impure.crossed_intent.is_empty(), "impure attack is excluded")

	var ash: RunState = RunState.new_run(content, 43, "crossed-ash", {"aspect": 1})
	ash.player.relics.append("crossedThreads")
	var ash_cb: CombatState = _combat(content, [["sporeling", "spit"], ["thornling", "prick"]])
	rules._form_crossed_link(ash, ash_cb)
	_check(fails, ash_cb.crossed_intent.is_empty(), "Ash runtime is exact-null")

	var rewards: RewardRules = RewardRules.new(content)
	_check(fails, rewards.card_pool(dusk, "common").count("crossedIntent") == 1
		and rewards.relic_pool(dusk, "uncommon").count("crossedThreads") == 1,
		"Dusk base pools contain each identity once")
	_check(fails, not rewards.card_pool(ash, "common").has("crossedIntent")
		and not rewards.relic_pool(ash, "uncommon").has("crossedThreads"),
		"Ash pools exclude both identities")


static func _combat(content: ContentDB, specs: Array) -> CombatState:
	var cb: CombatState = CombatState.new()
	cb.player.hp = 64
	cb.player.max_hp = 64
	for i: int in range(specs.size()):
		var spec: Array = specs[i]
		var e: EnemyCombatant = EnemyCombatant.new()
		e.key = StringName(str(spec[0]))
		e.def = content.enemy(e.key)
		e.name = str(e.def.get("name", ""))
		e.idx = i
		e.hp = 20
		e.max_hp = 20
		e.facet_max = 4
		e.move_key = StringName(str(spec[1]))
		cb.enemies.append(e)
	return cb


static func _check(fails: Array[String], ok: Variant, message: String) -> void:
	if ok != true:
		fails.append("crossedIntent: %s" % message)
