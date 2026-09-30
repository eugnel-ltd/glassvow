extends RefCounted
## Baseline hardship: every run's enemies resolve with the catalogue's
## `hardship` mods folded beneath the vows. A normal, an elite and a boss are
## pinned with hardship absent, on, and on together with the Vow of Iron.

const NORMAL: String = "duskfang"  # no facets key: 4; `bite` 7, `rend` 4 x2
const ELITE: String = "gravewarden"  # no facets key: 5; `crush` 12
const BOSS: String = "rootheart"  # 240 HP fixed, no facets key: 6; `lash` 12
const PLAYER_HP: int = 60


static func run(fails: Array[String]) -> void:
	_absent_key_is_no_hardship(fails)
	_catalogue_row(fails)
	# case, vow, hardship on, [normal hp, elite hp, boss hp], [facets], [hit dmg]
	_resolves("absent", 0, false, [40, 80, 240], [4, 5, 6], [7, 12, 12], fails)
	_resolves("hardship", 0, true, [46, 92, 276], [4, 6, 6], [8, 13, 13], fails)
	_resolves("hardship+Iron", 1, true, [52, 103, 309], [4, 6, 6], [8, 13, 13], fails)
	_resolves("hardship+Iron+Malice", 2, true, [52, 103, 309], [4, 6, 6], [9, 14, 14], fails)
	_multi_hit(fails)


static func _absent_key_is_no_hardship(fails: Array[String]) -> void:
	var bare: ContentDB = ContentDB.new()
	bare.apply_catalogue({"enemies": {}})
	if not bare.hardship.is_empty():
		fails.append("hardship: a catalogue without the key must load as no hardship")
	if not ContentDB.load_slice().hardship.is_empty():
		fails.append("hardship: the fixture slice carries no hardship")


static func _catalogue_row(fails: Array[String]) -> void:
	var mods: Dictionary = ContentDB.load_full().hardship.get("mods", {})
	if not is_equal_approx(float(str(mods.get("hpMult"))), 1.15) \
			or int(float(str(mods.get("enemyDmgBonus")))) != 1 \
			or int(float(str(mods.get("eliteFacetDelta")))) != 1 or mods.size() != 3:
		fails.append("hardship: full content must carry hpMult 1.15, enemyDmgBonus 1, "
			+ "eliteFacetDelta 1, got %s" % str(mods))


## Full content with the three test enemies pinned to one HP value each, so the
## seeded HP roll cannot hide the multiplier.
static func _content(hardship_on: bool) -> ContentDB:
	var content: ContentDB = ContentDB.load_full()
	content.enemies[NORMAL]["hp"] = [40, 40]
	content.enemies[ELITE]["hp"] = [80, 80]
	if not hardship_on:
		content.hardship = {}
	return content


static func _start(content: ContentDB, vow: int, id: String, kind: StringName) -> Array:
	var run_state: RunState = RunState.new_run(content, 7, "hardship-%s" % id, {"vow": vow})
	run_state.omens.clear()
	run_state.player.relics.clear()
	var rules: CombatRules = CombatRules.new(content)
	# Ember-Fat pays gold only: the elite's title touches neither HP nor facets.
	var affix: StringName = &"emberFat" if kind == &"elite" else &""
	var cb: CombatState = rules.start_combat(run_state, [id], kind, affix)
	return [rules, run_state, cb]


static func _resolves(
	label: String, vow: int, hardship_on: bool, hps: Array[int], facets: Array[int], hits: Array[int],
	fails: Array[String]
) -> void:
	var content: ContentDB = _content(hardship_on)
	var ids: Array[String] = [NORMAL, ELITE, BOSS]
	var kinds: Array[StringName] = [&"normal", &"elite", &"boss"]
	var moves: Array[String] = ["bite", "crush", "lash"]
	for i: int in range(ids.size()):
		var id: String = ids[i]
		var started: Array = _start(content, vow, id, kinds[i])
		var rules: CombatRules = started[0]
		var run_state: RunState = started[1]
		var cb: CombatState = started[2]
		var e: EnemyCombatant = cb.enemies[0]
		if e.max_hp != hps[i] or e.hp != hps[i]:
			fails.append("hardship %s: %s HP %d, expected %d" % [label, id, e.max_hp, hps[i]])
		if e.facet_max != facets[i]:
			fails.append("hardship %s: %s facets %d, expected %d"
				% [label, id, e.facet_max, facets[i]])
		var base: int = int(float(str(content.enemies[id]["moves"][moves[i]]["dmg"])))
		var taken: int = _hit(rules, run_state, cb, e, base)
		if taken != hits[i]:
			fails.append("hardship %s: %s %s hit for %d, expected %d"
				% [label, id, moves[i], taken, hits[i]])


## One enemy blow against a bare player: no Ward, no statuses on either side.
static func _hit(
	rules: CombatRules, run_state: RunState, cb: CombatState, e: EnemyCombatant, base: int
) -> int:
	cb.player.hp = PLAYER_HP
	cb.player.block = 0
	cb.player.statuses.clear()
	e.statuses.clear()
	e.flags.erase("rampBonus")
	rules.damage_player(run_state, cb, base, e.idx, true, e)
	return PLAYER_HP - cb.player.hp


## The bonus lands on every hit of a multi-hit move, exactly like Vow of Malice.
static func _multi_hit(fails: Array[String]) -> void:
	var content: ContentDB = _content(true)
	var started: Array = _start(content, 0, NORMAL, &"normal")
	var rules: CombatRules = started[0]
	var run_state: RunState = started[1]
	var cb: CombatState = started[2]
	var e: EnemyCombatant = cb.enemies[0]
	e.statuses.clear()
	cb.player.statuses.clear()
	e.move_key = &"rend"
	var preview: Variant = rules.preview_enemy_dmg(cb, e, run_state)
	if typeof(preview) != TYPE_DICTIONARY or preview["dmg"] != 5 or preview["times"] != 2:
		fails.append("hardship: rend (4 x2) must preview 5 x2, got %s" % str(preview))
	var taken: int = _hit(rules, run_state, cb, e, 4) + _hit(rules, run_state, cb, e, 4)
	if taken != 10:
		fails.append("hardship: rend's two hits must deal 5 each, dealt %d" % taken)
