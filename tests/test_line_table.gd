extends RefCounted
## #270: line-table selection, Vigil epitaphs, and the condition-column gate.
## Flame lock §10: the lantern's lines are owed by tier transitions, drawn
## through the once gates and heard once per Vigil; a fall in Soot writes the
## flame's epitaph once; the codex keeps each colour seen steady.

const TEST_VIGIL_PATH: String = "user://glassvow_test_line_table_vigil_v2.json"
## The six lines exactly as the lock wrote them, zh held to the house 着.
const FLAME_LOCKED: Dictionary = {
	"flame.steady": ["它認得你了。", "It knows you now."],
	"flame.true": ["一種玻璃，一種火。", "One glass. One fire."],
	"flame.soot": ["塵火照不亮路。", "A dusty flame lights no road."],
	"flame.sootDeath": ["你的火從未安定下來。", "Your flame never settled."],
	"flame.fringe": ["火尖上有另一種顏色。", "There is another colour at the tip."],
}
const FLAME_OPENING_KEY: String = "story.opening.b2.lantern"
const FLAME_OPENING: Array[String] = ["它燒的是你帶着的東西。", "It burns what you carry."]
## Never a mechanic word: the lock's list as English words (and their plain
## inflections), and the mechanic terms in zh-Hant (the lock's forms and the
## catalogue's own 燃燼 and 黯淡). 塵 and 火 stay legal: the lock's text uses them.
const FLAME_BANNED_EN: String = \
	"(?i)\\b(ember|kindle|shatter|cracked|dimmed|tier|purity|steady|true|soot)(s|es|d|ed|ing)?\\b"
const FLAME_BANNED_ZH: Array[String] = ["餘燼", "點燃", "燃燼", "碎裂", "裂痕", "暗淡", "黯淡"]
## No numbers in the codex.
const CODEX_NUMBERS: String = "(?i)[0-9一二三四五六七八九十兩百千]|\\b(one|two|three|four|five|six|seven|eight|nine|ten)\\b"
const SHATTER_CODEX: String = "codex.lantern.shatter"
const LANTERN_CODEX: String = "codex.lantern.lantern"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_line_table: %s" % what)


static func _i(value: Variant) -> int:
	return int(float(str(value)))


static func _empty_bucket(recent: Array, index: int) -> bool:
	if index < 0 or index >= recent.size():
		return false
	var bucket_v: Variant = recent[index]
	if typeof(bucket_v) != TYPE_ARRAY:
		return false
	var bucket: Array = bucket_v
	return bucket.is_empty()


static func run(fails: Array[String]) -> void:
	_conditions(fails)
	_selection(fails)
	_thresholds(fails)
	_losses(fails)
	_dialogue(fails)
	_vigil_surface(fails)
	_progress_persists(fails)
	_batch3_pools(fails)
	_flame_transitions(fails)
	_flame_heard_once(fails)
	_flame_soot_fall(fails)
	_flame_codex(fails)
	_flame_copy(fails)


static func _rows() -> Array:
	return ContentDB.load_full(false).line_table


static func _ctx(shards: int, act: int = 0) -> Dictionary:
	return {"shards": shards, "act": act, "quests": {}}


static func _probe(
		id: String, slot: String, conditions: Variant, zh: String, en: String,
		cooldown: int = 0
) -> Dictionary:
	return {
		"id": id, "slot": slot, "conditions": conditions, "zh": zh, "en": en,
		"priority": 0, "once": false, "cooldown_runs": cooldown, "weight": 1,
		"asserts": {},
	}


static func _conditions(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.new()
	var faults: PackedStringArray = db.apply_line_table([
		_probe("g.shards", "probe", "shards>=4", "甲", "Shards"),
		_probe("g.act", "probe", "act=2", "乙", "ActTwo"),
		_probe("g.quest", "probe", "quest:ownShade.complete", "丙", "Quest"),
		_probe("g.progress", "probe", "quest:hollowLamplighter>=1", "丁", "Progress"),
	])
	_check(fails, faults.is_empty(), "valid conditions failed to load")
	if not faults.is_empty():
		return
	var shards_row: Dictionary = LineTable.row_by_id(db.line_table, "g.shards")
	_check(fails, LineTable.conditions_match(shards_row.get("conditions", {}), _ctx(4))
		and not LineTable.conditions_match(shards_row.get("conditions", {}), _ctx(3))
		and LineTable.specificity(shards_row.get("conditions", {})) == 1,
		"shards>=4 did not parse to the four-shard gate")
	var act_row: Dictionary = LineTable.row_by_id(db.line_table, "g.act")
	_check(fails, LineTable.conditions_match(act_row.get("conditions", {}), _ctx(0, 2))
		and not LineTable.conditions_match(act_row.get("conditions", {}), _ctx(0, 1)),
		"act=2 did not parse to an act gate")
	var quest_row: Dictionary = LineTable.row_by_id(db.line_table, "g.quest")
	var ready: Dictionary = _ctx(0)
	ready["quests"] = {"ownShade": "complete"}
	var dormant: Dictionary = _ctx(0)
	dormant["quests"] = {"ownShade": "dormant"}
	_check(fails, LineTable.conditions_match(quest_row.get("conditions", {}), ready)
		and not LineTable.conditions_match(quest_row.get("conditions", {}), dormant),
		"quest:ownShade.complete did not parse to a quest gate")
	var progress_row: Dictionary = LineTable.row_by_id(db.line_table, "g.progress")
	var paid: Dictionary = _ctx(0)
	paid["quest_progress"] = {"hollowLamplighter": 1}
	var unpaid: Dictionary = _ctx(0)
	unpaid["quest_progress"] = {"hollowLamplighter": 0}
	_check(fails, LineTable.conditions_match(progress_row.get("conditions", {}), paid)
		and not LineTable.conditions_match(progress_row.get("conditions", {}), unpaid)
		and LineTable.specificity(progress_row.get("conditions", {})) == 1,
		"quest:hollowLamplighter>=1 did not parse to a progress gate")
	_check(fails, LineTable.specificity({"shards_gte": 1, "junk": 9}) == 1,
		"specificity counted an unvalidated key")
	var bad: ContentDB = ContentDB.new()
	var bad_faults: PackedStringArray = bad.apply_line_table([
		_probe("g.bad", "probe", "nope>=1", "戊", "Nope"),
	])
	_check(fails, not bad_faults.is_empty() and bad.line_table.is_empty(),
		"malformed condition did not fail the table load")
	var bought: ContentDB = ContentDB.new()
	var bought_faults: PackedStringArray = bought.apply_line_table([
		_probe("g.bought", "probe", "quest:usurper.bought", "己", "Bought"),
	])
	_check(fails, not bought_faults.is_empty() and bought.line_table.is_empty()
		and str(bought_faults[0]).contains("unknown quest state bought"),
		"quest:usurper.bought did not fail the table load")
	var resolved: ContentDB = ContentDB.new()
	var resolved_faults: PackedStringArray = resolved.apply_line_table([
		_probe("g.resolved", "probe", "quest:ownShade.resolved", "庚", "Resolved"),
	])
	_check(fails, not resolved_faults.is_empty() and resolved.line_table.is_empty()
		and str(resolved_faults[0]).contains("unknown quest state resolved"),
		"quest:ownShade.resolved did not fail the table load")
	var dict_form: ContentDB = ContentDB.new()
	_check(fails, not dict_form.apply_line_table([
		_probe("g.dict", "probe", {"shards_gte": 1}, "辛", "DictForm"),
	]).is_empty(), "internal dict conditions failed open")
	var same: ContentDB = ContentDB.new()
	_check(fails, not same.apply_line_table([
		_probe("g.same", "probe", "", "Same", "Same"),
	]).is_empty(), "en == zh loaded")
	var cjk: ContentDB = ContentDB.new()
	_check(fails, not cjk.apply_line_table([
		_probe("g.cjk", "probe", "", "壬", "Latin中文"),
	]).is_empty(), "non-Latin en loaded")
	var missing: ContentDB = ContentDB.new()
	_check(fails, not missing.apply_line_table([{
		"id": "g.miss", "slot": "probe", "zh": "癸", "cooldown_runs": 0,
	}]).is_empty(), "row missing en loaded")
	var one: ContentDB = ContentDB.new()
	_check(fails, not one.apply_line_table([
		_probe("pool.loss.e01", "loss", "", "子", "Alone", 3),
	]).is_empty() and one.line_table.is_empty(),
		"single-row pool loaded")


static func _selection(fails: Array[String]) -> void:
	var rows: Array = [
		{"id": "g", "slot": "loss", "conditions": {}, "weight": 1,
			"cooldown_runs": 3, "zh": "通", "en": "generic"},
		{"id": "a", "slot": "loss", "conditions": {"act": 1}, "weight": 1,
			"cooldown_runs": 3, "zh": "一", "en": "act-one"},
	]
	var generic: Dictionary = LineTable.select(rows, "loss", _ctx(0, 0), null, {})
	_check(fails, str(generic.get("id")) == "g", "empty conditions are the generic fallback")
	var specific: Dictionary = LineTable.select(rows, "loss", _ctx(0, 1), null, {})
	_check(fails, str(specific.get("id")) == "a", "most-specific-wins lost to the generic row")
	var shard0: Dictionary = LineTable.select(_rows(), "loss", _ctx(0), null, {})
	_check(fails, str(shard0.get("id")).begins_with("pool.loss.e"),
		"shard-zero loss did not draw a generic epitaph")
	_check(fails, LineTable.ladder_of(shard0) == 0,
		"generic fallback carried an L1+ ladder")
	_check(fails, not LineTable.select(_rows(), "hearth", _ctx(0), null, {}).is_empty(),
		"shard-zero hearth went silent")
	_check(fails, not LineTable.select(_rows(), "waystone", _ctx(0), null, {}).is_empty(),
		"shard-zero waystone went silent")
	_check(fails, LineTable.conditions_match(
			LineTable.row_by_id(_rows(), "pool.loss.e02").get("conditions", {}),
			_ctx(0)),
		"generic pool.loss.e02 did not match at shard zero")
	_check(fails, not LineTable.conditions_match(
			LineTable.row_by_id(_rows(), "pool.loss.e21").get("conditions", {}),
			_ctx(0, 0)),
		"act-specific pool.loss.e21 matched outside act 1")
	var open: Dictionary = LineTable.select(_rows(), "loss", _ctx(1), null, {})
	_check(fails, not open.is_empty(), "L1 loss pool went silent")
	_check(fails, LineTable.slot_open(_rows(), "whisper", _ctx(0)) == false
		and LineTable.slot_open(_rows(), "whisper", _ctx(1)),
		"whisper channel is not the conditions column")
	_check(fails, LineTable.slot_open(_rows(), "closer.ownShade", _ctx(1)) == false
		and LineTable.slot_open(_rows(), "closer.ownShade", _ctx(4)),
		"L2 closer opened below four shards")


static func _thresholds(fails: Array[String]) -> void:
	var cases: Array = [
		[0, 0, 1], [1, 0, 0], [1, 1, 1],
		[2, 3, 0], [2, 4, 1], [3, 5, 0], [3, 6, 1],
	]
	for row_v: Variant in cases:
		var row: Array = row_v
		var level: int = _i(row[0])
		var shards: int = _i(row[1])
		var want: bool = _i(row[2]) == 1
		var conditions: Dictionary = {}
		if level == 1:
			conditions["shards_gte"] = LineTable.L1_SHARDS
		elif level == 2:
			conditions["shards_gte"] = LineTable.L2_SHARDS
		elif level == 3:
			conditions["shards_gte"] = LineTable.L3_SHARDS
		_check(fails, LineTable.conditions_match(conditions, _ctx(shards)) == want,
			"level %d / shards %d" % [level, shards])


static func _run(content: ContentDB, vigil: VigilState, id: String) -> RunState:
	var state: RunState = RunState.new_run(content, id.hash() & 0x7FFFFFFF,
		id, {"quests": vigil.quests, "shards": vigil.shards})
	state.act = 1
	state.waystones_lit = 7
	return state


static func _losses(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var sealed: VigilState = VigilState.blank()
	_check(fails, sealed.commit_run(_run(content, sealed, "run-win-l0"), "win", content)
		and sealed.whispers == 0, "shard-zero win exposed an L1 whisper")
	var opened: VigilState = VigilState.blank()
	var opening_win: RunState = _run(content, opened, "run-win-first-shard")
	var opening_quest: Dictionary = opening_win.quests["paleOnes"]
	opening_quest["state"] = "complete"
	_check(fails, opened.commit_run(opening_win, "win", content)
		and opened.shards.has("paleOnes") and opened.whispers == 1,
		"same-run first shard did not open the whisper channel")

	var vigil: VigilState = VigilState.blank()
	var l0: RunState = _run(content, vigil, "run-loss-l0")
	_check(fails, vigil.commit_run(l0, "death", content)
		and vigil.defeat_epitaphs.size() == 1 and vigil.whispers == 0,
		"shard-zero death did not write exactly one epitaph")
	_check(fails, str(vigil.defeat_epitaphs[0]).begins_with("pool.loss.e"),
		"shard-zero death wrote a non-generic epitaph")

	vigil.shards.append("paleOnes")
	var first: RunState = _run(content, vigil, "run-loss-first")
	_check(fails, vigil.commit_run(first, "death", content)
		and vigil.defeat_epitaphs.size() == 2,
		"first eligible loss did not write an epitaph")
	var first_id: String = vigil.defeat_epitaphs[1]
	_check(fails, vigil.commit_run(first, "death", content)
		and vigil.defeat_epitaphs.size() == 2,
		"terminal retry consumed the pool twice")

	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and loaded.defeat_epitaphs == vigil.defeat_epitaphs,
		"epitaph ledger did not survive v2 load")
	if loaded == null:
		return
	var second: RunState = _run(content, loaded, "run-loss-second")
	_check(fails, loaded.commit_run(second, "death", content)
		and loaded.defeat_epitaphs.size() == 3
		and loaded.defeat_epitaphs[2] != first_id,
		"second loss repeated the first line inside cooldown")

	var raw: Dictionary = VigilState.blank().to_dict()
	raw.erase("defeatEpitaphs")
	raw.erase("lineRecent")
	raw.erase("lineOnce")
	var old: VigilState = VigilState.from_dict(raw)
	_check(fails, old != null and old.defeat_epitaphs.is_empty(),
		"a v2 vigil without defeatEpitaphs did not default")

	SaveService.clear_vigil(TEST_VIGIL_PATH)
	_check(fails, SaveService.store_vigil(loaded, TEST_VIGIL_PATH), "epitaph store failed")
	var disk: VigilState = SaveService.load_vigil(TEST_VIGIL_PATH)
	_check(fails, disk.defeat_epitaphs.size() == 3, "epitaphs did not round-trip through SaveService")
	SaveService.clear_vigil(TEST_VIGIL_PATH)

	var exhaust: VigilState = VigilState.blank()
	exhaust.shards.append("paleOnes")
	var seen: Dictionary = {}
	var last: String = ""
	for n: int in range(8):
		var loss: RunState = _run(content, exhaust, "run-loss-ex-%d" % n)
		_check(fails, exhaust.commit_run(loss, "death", content), "exhaust death %d rejected" % n)
		_check(fails, exhaust.defeat_epitaphs.size() == n + 1, "exhaust death %d silent" % n)
		var id: String = exhaust.defeat_epitaphs[n]
		if n > 0:
			_check(fails, id != last, "exhaust recycled the same line consecutively")
		seen[id] = true
		last = id
	_check(fails, seen.size() >= 2, "loss pool never recycled across distinct lines")
	_cooldown_counts_runs(fails)
	_two_row_pool_never_repeats(fails)
	_whisper_row_governs(fails)


static func _cooldown_counts_runs(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.load_full(false)
	var faults: PackedStringArray = db.apply_line_table([
		_probe("pool.loss.e01", "loss", "", "甲", "Alpha", 3),
		_probe("pool.loss.e02", "loss", "", "乙", "Bravo", 3),
	])
	_check(fails, faults.is_empty(), "cooldown fixture failed to load")
	if not faults.is_empty():
		return
	var vigil: VigilState = VigilState.blank()
	var death1: RunState = _run(db, vigil, "cd-d1")
	_check(fails, vigil.commit_run(death1, "death", db) and vigil.defeat_epitaphs.size() == 1,
		"run-1 loss did not draw")
	var first: String = vigil.defeat_epitaphs[0]
	var recent_after_draw: int = vigil.line_recent.size()
	_check(fails, vigil.commit_run(death1, "death", db)
		and vigil.line_recent.size() == recent_after_draw,
		"retry double-appended a run bucket")
	for n: int in range(3):
		var win: RunState = _run(db, vigil, "cd-w%d" % n)
		_check(fails, vigil.commit_run(win, "win", db), "cooldown win %d rejected" % n)
	_check(fails, vigil.line_recent.size() == 4
		and _empty_bucket(vigil.line_recent, 1)
		and _empty_bucket(vigil.line_recent, 2)
		and _empty_bucket(vigil.line_recent, 3),
		"wins did not append empty run buckets")
	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and loaded.line_recent.size() == 4
		and _empty_bucket(loaded.line_recent, 1),
		"empty run buckets did not survive save/load")
	_check(fails, not LineTable._used_in(vigil.line_recent, first, 3),
		"run-1 draw was still excluded by a ~3-run cooldown after three wins")


static func _two_row_pool_never_repeats(fails: Array[String]) -> void:
	var db: ContentDB = ContentDB.new()
	var faults: PackedStringArray = db.apply_line_table([
		_probe("pool.loss.e01", "loss", "", "甲", "Alpha", 3),
		_probe("pool.loss.e02", "loss", "", "乙", "Bravo", 3),
	])
	_check(fails, faults.is_empty(), "two-row fixture failed to load")
	if not faults.is_empty():
		return
	var last: String = ""
	var recent: Array = []
	for n: int in range(6):
		var row: Dictionary = LineTable.select(db.line_table, "loss", _ctx(0), null, {
			"recent": recent, "once": [], "last_id": last,
		})
		var id: String = str(row.get("id", ""))
		_check(fails, not id.is_empty(), "two-row pool went silent at draw %d" % n)
		if n > 0:
			_check(fails, id != last, "two-row pool repeated %s consecutively" % id)
		recent = LineTable.remember(recent, [id])
		last = id


static func _whisper_row_governs(fails: Array[String]) -> void:
	var open_db: ContentDB = ContentDB.load_full(false)
	var whisper: Dictionary = LineTable.row_by_id(open_db.line_table, "whisper.channel")
	_check(fails, not whisper.is_empty(), "shipping table has no whisper row")
	whisper["conditions"] = {}
	var open_vigil: VigilState = VigilState.blank()
	_check(fails, open_vigil.commit_run(_run(open_db, open_vigil, "win-open"), "win", open_db)
		and open_vigil.whispers == 1,
		"whisper row without a condition still sealed a shard-zero win")
	var gated: ContentDB = ContentDB.load_full(false)
	var gated_vigil: VigilState = VigilState.blank()
	_check(fails, gated_vigil.commit_run(_run(gated, gated_vigil, "win-gated"), "win", gated)
		and gated_vigil.whispers == 0,
		"whisper row condition did not govern a shard-zero win")


static func _speaks(content: ContentDB, variant: String, shards: Array,
		current: Array = []) -> bool:
	var vigil: VigilState = VigilState.blank()
	var progress: int = 2 if variant == "ownShade3" else 0
	vigil.quests["ownShade"] = {
		"state": "armed", "progress": progress, "memory": {},
	}
	var state: RunState = RunState.new_run(content, variant.hash() & 0x7FFFFFFF,
		"run-" + variant, {"quests": vigil.quests, "shards": shards})
	for id_v: Variant in current:
		state.quest_completions.append(str(id_v))
	var game: GlassvowGame = GlassvowGame.new(content, state)
	game.apply({"t": "startCombat", "enemies": [variant], "kind": "monster"})
	game.cb.queue.clear()
	var enemy: EnemyCombatant = game.cb.enemies[0]
	game.rules.hit_enemy(state, game.cb, enemy, 999, false)
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.VARIANT_DIALOGUE:
			return true
	return false


static func _dialogue(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check(fails, not _speaks(content, "ownShade1", [])
		and _speaks(content, "ownShade1", ["paleOnes"]),
		"L1 Shade line crossed the one-shard gate")
	_check(fails, not LineTable.slot_open(content.line_table, "closer.ownShade",
			_ctx(1)),
		"L2 closer opened below four shards")
	_check(fails, _speaks(content, "ownShade3", ["paleOnes"]),
		"ownShade3 L1 death line stayed sealed at one shard")
	_check(fails, _speaks(content, "ownShade3",
			["paleOnes", "usurper"], ["eighthOmen"]),
		"projected current-run shards did not open an L1 Shade death line")
	var projected: RunState = RunState.new_run(content, 7, "run-proj", {
		"shards": ["paleOnes", "usurper", "eighthOmen"],
	})
	projected.quests["ownShade"] = {"state": "armed", "progress": 2, "memory": {}}
	_check(fails, LineTable.projected_shard_count(projected, &"ownShade3") >= 4,
		"ownShade3 kill does not project the fourth pane")
	_check(fails, LineTable.slot_open(content.line_table, "closer.ownShade",
			LineTable.context(projected,
				LineTable.projected_shard_count(projected, &"ownShade3"))),
		"projected fourth pane did not open the L2 closer")


static func _vigil_surface(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	vigil.defeat_epitaphs.append("pool.loss.e01")
	var screen: VigilScreen = VigilScreen.new(vigil, content)
	_check(fails, screen._epitaph_tab != null and screen._epitaph_list != null,
		"Vigil hid a non-empty epitaph ledger")
	screen._show_epitaphs()
	_check(fails, screen._epitaph_list.visible and not screen._deed_list.visible,
		"epitaph tab did not reveal the ledger")
	screen.free()
	var empty: VigilScreen = VigilScreen.new(VigilState.blank(), content)
	_check(fails, empty._epitaph_tab == null,
		"empty ledger still grew an epitaph tab")
	empty.free()


static func _progress_persists(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var parsed: Dictionary = LineTable.parse_conditions("quest:hollowLamplighter>=1")
	var parsed_ok: bool = parsed["ok"] == true
	_check(fails, parsed_ok, "progress clause failed to parse")
	if not parsed_ok:
		return
	var vigil: VigilState = VigilState.blank()
	var prior: RunState = _run(content, vigil, "run-hollow-pay")
	prior.quests["hollowLamplighter"]["state"] = "revealed"
	prior.quests["hollowLamplighter"]["progress"] = 1
	_check(fails, vigil.commit_run(prior, "death", content), "hollow progress fold rejected")
	_check(fails, _i(vigil.quests["hollowLamplighter"].get("progress", 0)) == 1,
		"hollowLamplighter progress did not survive vigil fold")
	var next: RunState = _run(content, vigil, "run-hollow-next")
	_check(fails, LineTable.conditions_match(parsed["conditions"], LineTable.context(next)),
		"folded hollowLamplighter progress did not open quest:id>=1")
	_check(fails, not LineTable.conditions_match(
			parsed["conditions"],
			LineTable.context(_run(content, VigilState.blank(), "run-hollow-zero"))),
		"zero hollowLamplighter progress opened quest:id>=1")


static func _batch3_pools(fails: Array[String]) -> void:
	var rows: Array = _rows()
	var counts: Dictionary = {"hearth": 0, "waystone": 0, "loss": 0}
	for row_v: Variant in rows:
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var slot: String = str(row.get("slot", ""))
		if counts.has(slot):
			counts[slot] = _i(counts[slot]) + 1
	_check(fails, _i(counts["hearth"]) == 60 and _i(counts["waystone"]) == 60
		and _i(counts["loss"]) == 50,
		"pool counts hearth=%d waystone=%d loss=%d" % [
			_i(counts["hearth"]), _i(counts["waystone"]), _i(counts["loss"])])
	_check(fails, LineTable.conditions_match(
			LineTable.row_by_id(rows, "pool.waystone.w18").get("conditions", {}),
			_ctx(0))
		and LineTable.conditions_match(
			LineTable.row_by_id(rows, "pool.loss.e02").get("conditions", {}),
			_ctx(0)),
		"generic standing-stone plants w18/e02 did not match at shard zero")
	var h57: Dictionary = LineTable.row_by_id(rows, "pool.hearth.h57")
	var bought: Dictionary = _ctx(0)
	bought["quests"] = {"usurper": "revealed"}
	_check(fails, LineTable.conditions_match(h57.get("conditions", {}), bought)
		and not LineTable.conditions_match(h57.get("conditions", {}), _ctx(0)),
		"h57 did not fire on usurper.revealed")
	var h58: Dictionary = LineTable.row_by_id(rows, "pool.hearth.h58")
	var settled: Dictionary = _ctx(0)
	settled["quests"] = {"ownShade": "complete"}
	_check(fails, LineTable.conditions_match(h58.get("conditions", {}), settled)
		and not LineTable.conditions_match(h58.get("conditions", {}), _ctx(0)),
		"h58 did not fire on ownShade.complete")
	var h59: Dictionary = LineTable.row_by_id(rows, "pool.hearth.h59")
	var paid: Dictionary = _ctx(0)
	paid["quest_progress"] = {"hollowLamplighter": 1}
	var unpaid: Dictionary = _ctx(0)
	unpaid["quest_progress"] = {"hollowLamplighter": 0}
	_check(fails, LineTable.conditions_match(h59.get("conditions", {}), paid)
		and not LineTable.conditions_match(h59.get("conditions", {}), unpaid),
		"h59 did not fire on hollowLamplighter>=1")


## A Duskblade run: the starter deck (one seed of each way), plus `add`, less
## `drop`. The decks are the lock's §4 worked examples.
static func _dusk(content: ContentDB, id: String, add: Array[String] = [],
		drop: Array[String] = []) -> RunState:
	var state: RunState = RunState.new_run(content, id.hash() & 0x7FFFFFFF, id, {"aspect": 0})
	_deck(state, add, drop)
	return state


static func _deck(state: RunState, add: Array[String], drop: Array[String] = []) -> void:
	for id: String in add:
		state.player.deck.append(CardInst.new(state.next_uid(), StringName(id), false))
	for id: String in drop:
		for card: CardInst in state.player.deck:
			if String(card.id) == id:
				state.player.deck.erase(card)
				break


static func _draw_all(state: RunState, vigil: VigilState, content: ContentDB,
		slots: Array[String]) -> void:
	for slot: String in slots:
		PoolBeats.draw(state, vigil, content, slot, slot)


static func _ids(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(str(row.get("id", "")))
	return out


## Each line is owed by a change of tier between two consecutive readings; the
## codex by any reading of a steady colour. A fringe that appears on a flame
## already steady is no transition.
static func _flame_transitions(fails: Array[String]) -> void:
	var start: Dictionary = FlameLines.START
	var steady: Dictionary = {"tier": Flame.TIER_STEADY, "dominant": "shatter", "fringe": ""}
	var fringed: Dictionary = {"tier": Flame.TIER_STEADY, "dominant": "shatter", "fringe": "edge"}
	var dimmed: Dictionary = {"tier": Flame.TIER_KINDLING, "dominant": "shatter", "fringe": "edge"}
	var pure: Dictionary = {"tier": Flame.TIER_TRUE, "dominant": "lantern", "fringe": ""}
	var soot: Dictionary = {"tier": Flame.TIER_SOOT, "dominant": "shatter", "fringe": "lantern"}
	var cases: Array = [
		["the first steady", start, steady, [FlameLines.SLOT_STEADY, SHATTER_CODEX]],
		["steady with a fringe", start, fringed,
			[FlameLines.SLOT_STEADY, FlameLines.SLOT_FRINGE, SHATTER_CODEX]],
		["a steady flame held", steady, steady, [SHATTER_CODEX]],
		["a fringe on a steady flame", steady, fringed, [SHATTER_CODEX]],
		["steady dimmed to kindling", fringed, dimmed, []],
		["kindling back to steady", dimmed, fringed,
			[FlameLines.SLOT_STEADY, FlameLines.SLOT_FRINGE, SHATTER_CODEX]],
		["the first true", start, pure, [FlameLines.SLOT_TRUE, LANTERN_CODEX]],
		["true settling to steady", pure, steady, [FlameLines.SLOT_STEADY, SHATTER_CODEX]],
		["the first soot", start, soot, [FlameLines.SLOT_SOOT]],
		["soot held", soot, soot, []],
		["the starter deck", start, start, []],
	]
	for case_v: Variant in cases:
		var entry: Array = case_v
		var before: Dictionary = entry[1]
		var after: Dictionary = entry[2]
		var want: Array = entry[3]
		var got: Array[String] = FlameLines.owed(before, after)
		_check(fails, got == want,
			"flame: %s owed %s, not %s" % [entry[0], str(got), str(want)])
	_check(fails, FlameLines.death_slot(soot) == FlameLines.SLOT_SOOT_DEATH
			and FlameLines.death_slot(steady).is_empty()
			and FlameLines.death_slot(start).is_empty(),
		"flame: only a fall in Soot owes the flame's epitaph")


## The domain observes every reading: a transition owes its line once, a second
## transition into the same tier draws nothing new, and the once gates carry the
## line across the Vigil. A resumed run reads from the starter deck's flame.
static func _flame_heard_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var state: RunState = _dusk(content, "flame-heard-once")
	var game: GlassvowGame = GlassvowGame.new(content, state)
	game.flame_events(true)
	_check(fails, game.take_flame_lines().is_empty(), "flame: the starter deck owed a line")
	_deck(state, ["uppercut", "quakeblow"])
	game.flame_events(true)
	var first: Array[String] = game.take_flame_lines()
	_check(fails, first == [FlameLines.SLOT_STEADY, SHATTER_CODEX],
		"flame: the first steady reading owed %s" % str(first))
	_check(fails, game.take_flame_lines().is_empty(), "flame: taking the owed lines did not drain them")
	_draw_all(state, vigil, content, first)
	game.flame_events(true)
	_check(fails, not game.take_flame_lines().has(FlameLines.SLOT_STEADY),
		"flame: a steady flame read again owed its line again")
	_deck(state, ["warCry"])
	game.flame_events(true)
	_deck(state, ["oblivionStrike", "limitBreak"])
	game.flame_events(true)
	var again: Array[String] = game.take_flame_lines()
	_check(fails, again == [FlameLines.SLOT_STEADY, FlameLines.SLOT_FRINGE, SHATTER_CODEX],
		"flame: steady regained with a fringe owed %s" % str(again))
	var draws: int = state.pool_draws.size()
	_draw_all(state, vigil, content, again)
	_check(fails, state.pool_draws.count(FlameLines.SLOT_STEADY) == 1
			and state.pool_draws.has(FlameLines.SLOT_FRINGE)
			and state.pool_draws.size() == draws + 1,
		"flame: a second transition drew the steady line twice (draws %s)" % str(state.pool_draws))
	_check(fails, vigil.commit_run(state, "win", content)
			and vigil.line_once.has(FlameLines.SLOT_STEADY)
			and vigil.line_once.has(FlameLines.SLOT_FRINGE)
			and vigil.line_once.has(SHATTER_CODEX),
		"flame: the run's lines did not fold into the Vigil's once gate")
	var next: RunState = _dusk(content, "flame-heard-next", ["uppercut", "quakeblow"])
	var resumed: GlassvowGame = GlassvowGame.new(content, next)
	resumed.flame_events(true)
	var owed: Array[String] = resumed.take_flame_lines()
	_check(fails, owed.has(FlameLines.SLOT_STEADY),
		"flame: a new game did not read from the starter deck's flame")
	_draw_all(next, vigil, content, owed)
	_check(fails, next.pool_draws.is_empty() and next.pool_beats.is_empty(),
		"flame: a line heard in an earlier run was drawn again")
	var soot_run: RunState = _dusk(content, "flame-soot", ["uppercut", "preparation", "warCry"])
	var soot_game: GlassvowGame = GlassvowGame.new(content, soot_run)
	soot_game.flame_events(true)
	_check(fails, soot_game.take_flame_lines() == [FlameLines.SLOT_SOOT],
		"flame: two of each way did not owe the first Soot")
	var pure_run: RunState = _dusk(content, "flame-true",
		["preparation", "surge", "devour", "offering"], ["chisel", "eclipseSlash"])
	var pure_game: GlassvowGame = GlassvowGame.new(content, pure_run)
	pure_game.flame_events(true)
	_check(fails, pure_game.take_flame_lines() == [FlameLines.SLOT_TRUE, LANTERN_CODEX],
		"flame: one glass did not owe the first True")


## The Vigil's whisper for a fall in Soot is that fall's epitaph, once; a later
## fall in Soot, a fall elsewhere, and a win keep to the loss pool's law.
static func _flame_soot_fall(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var soot: Array[String] = ["uppercut", "preparation", "warCry"]
	var vigil: VigilState = VigilState.blank()
	_check(fails, vigil.commit_run(_dusk(content, "soot-fall-1", soot), "death", content)
			and vigil.defeat_epitaphs == [FlameLines.SLOT_SOOT_DEATH]
			and vigil.line_once.has(FlameLines.SLOT_SOOT_DEATH),
		"flame: a fall in Soot did not write the flame's epitaph (%s)" % str(vigil.defeat_epitaphs))
	_check(fails, vigil.commit_run(_dusk(content, "soot-fall-2", soot), "death", content)
			and vigil.defeat_epitaphs.size() == 2
			and vigil.defeat_epitaphs[1].begins_with("pool.loss.e"),
		"flame: a second fall in Soot heard the flame's epitaph again")
	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and loaded.line_once.has(FlameLines.SLOT_SOOT_DEATH),
		"flame: the epitaph's once gate did not survive the Vigil save")
	var steady: VigilState = VigilState.blank()
	_check(fails, steady.commit_run(_dusk(content, "steady-fall", ["uppercut", "quakeblow"]),
			"death", content)
			and steady.defeat_epitaphs[0].begins_with("pool.loss.e"),
		"flame: a fall outside Soot heard the flame's epitaph")
	var won: VigilState = VigilState.blank()
	_check(fails, won.commit_run(_dusk(content, "soot-win", soot), "win", content)
			and won.defeat_epitaphs.is_empty()
			and not won.line_once.has(FlameLines.SLOT_SOOT_DEATH),
		"flame: a win in Soot wrote the fall's epitaph")
	var screen: VigilScreen = VigilScreen.new(vigil, content)
	var row: Dictionary = LineTable.row_by_id(content.line_table, FlameLines.SLOT_SOOT_DEATH)
	var body: String = LineTable.text(row, Locale.active.code == Locale.CODE_ZH_HANT)
	var shown: bool = false
	for label: Node in screen._epitaph_list.find_children("*", "Label", true, false):
		shown = shown or (label as Label).text.ends_with(body)
	_check(fails, shown, "flame: the Vigil did not show the fall's whisper")
	screen.free()


## The codex keeps each colour seen steady: in the run as drawn, across the
## Vigil once folded, in way order, and one sentence for every way.
static func _flame_codex(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var state: RunState = _dusk(content, "codex-steady", ["uppercut", "quakeblow"])
	_check(fails, FlameLines.codex(content, vigil, state).is_empty(),
		"codex: a colour was revealed before it was seen")
	var game: GlassvowGame = GlassvowGame.new(content, state)
	game.flame_events(true)
	var owed: Array[String] = game.take_flame_lines()
	_draw_all(state, vigil, content, owed.filter(func(slot: String) -> bool:
		return FlameLines.is_codex(slot)))
	_check(fails, _ids(FlameLines.codex(content, vigil, state)) == [SHATTER_CODEX],
		"codex: the steady colour was not revealed in its run")
	_check(fails, FlameLines.codex(content, vigil, null).is_empty(),
		"codex: the Vigil held a colour before its run was folded")
	_check(fails, vigil.commit_run(state, "death", content)
			and _ids(FlameLines.codex(content, vigil, null)) == [SHATTER_CODEX],
		"codex: a colour seen steady did not stay revealed across the Vigil")
	var pure: RunState = _dusk(content, "codex-true",
		["preparation", "surge", "devour", "offering"], ["chisel", "eclipseSlash"])
	var pure_game: GlassvowGame = GlassvowGame.new(content, pure)
	pure_game.flame_events(true)
	_draw_all(pure, vigil, content, pure_game.take_flame_lines().filter(
		func(slot: String) -> bool: return FlameLines.is_codex(slot)))
	_check(fails, _ids(FlameLines.codex(content, vigil, pure)) == [SHATTER_CODEX, LANTERN_CODEX],
		"codex: a true colour was not revealed, in way order")
	for aspect: int in range(content.aspects.size()):
		for way: Dictionary in Flame.ways(content, aspect):
			var slot: String = FlameLines.CODEX_PREFIX + str(way.get("id", ""))
			_check(fails, LineTable.has_slot(content.line_table, slot),
				"codex: way %s has no sentence" % str(way.get("id", "")))


## The six lines ship exactly as locked; none of the nine (the six and the
## codex's three) speaks a mechanic word; each is bilingual and in the house
## orthography; every row is heard once; the codex has no numbers.
static func _flame_copy(fails: Array[String]) -> void:
	var rows: Array = _rows()
	var banned: RegEx = RegEx.new()
	banned.compile(FLAME_BANNED_EN)
	var numbers: RegEx = RegEx.new()
	numbers.compile(CODEX_NUMBERS)
	var lines: Array[Array] = []
	for id_v: Variant in FLAME_LOCKED:
		var id: String = str(id_v)
		var row: Dictionary = LineTable.row_by_id(rows, id)
		var locked: Array = FLAME_LOCKED[id_v]
		var once: bool = row.get("once", false)
		_check(fails, LineTable.text(row, true) == str(locked[0])
				and LineTable.text(row, false) == str(locked[1]) and once,
			"flame copy: %s is not the locked line, heard once" % id)
		lines.append([id, LineTable.text(row, true), LineTable.text(row, false)])
	var codex: int = 0
	for row_v: Variant in rows:
		var row: Dictionary = row_v
		if not FlameLines.is_codex(str(row.get("slot", ""))):
			continue
		codex += 1
		var zh: String = LineTable.text(row, true)
		var en: String = LineTable.text(row, false)
		var once: bool = row.get("once", false)
		_check(fails, numbers.search(zh) == null and numbers.search(en) == null and once,
			"flame copy: codex %s carries a number or can be heard twice" % str(row.get("id")))
		lines.append([str(row.get("id")), zh, en])
	_check(fails, codex == 3, "flame copy: the codex has %d sentences, not three" % codex)
	var en_locale: Locale = Locale.new(Locale.CODE_EN)
	var zh_locale: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh_locale.t(FLAME_OPENING_KEY) == FLAME_OPENING[0]
			and en_locale.t(FLAME_OPENING_KEY) == FLAME_OPENING[1],
		"flame copy: the Keeper's opening line is not the locked line")
	lines.append([FLAME_OPENING_KEY, zh_locale.t(FLAME_OPENING_KEY), en_locale.t(FLAME_OPENING_KEY)])
	for line_v: Variant in lines:
		var line: Array = line_v
		var zh: String = str(line[1])
		var en: String = str(line[2])
		_check(fails, not zh.is_empty() and not en.is_empty() and zh != en,
			"flame copy: %s is not bilingual" % str(line[0]))
		_check(fails, banned.search(en) == null,
			"flame copy: %s speaks a mechanic word: %s" % [str(line[0]), en])
		for word: String in FLAME_BANNED_ZH:
			_check(fails, not zh.contains(word),
				"flame copy: %s speaks the mechanic word %s" % [str(line[0]), word])
		_check(fails, not zh.contains("著") and not zh.contains("裡"),
			"flame copy: %s breaks the 着/裏 orthography" % str(line[0]))
	var probe: RegEx = RegEx.new()
	probe.compile(FLAME_BANNED_EN)
	_check(fails, probe.search("Embers spill.") != null and probe.search("It burns true.") != null
			and probe.search("A construe") == null,
		"flame copy: the mechanic-word guard does not bite")
