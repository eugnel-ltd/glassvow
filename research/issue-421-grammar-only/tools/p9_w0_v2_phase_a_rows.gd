extends SceneTree
## Frozen row generator for the single p9-w0-v4 matched attribution re-exam.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Observer: GDScript = preload("res://tools/p9_ward_observer.gd")
const PROTOCOL_ID: String = "p9-w0-v4-phase-a"
const SEED_FIRST: int = 4000
const SEED_COUNT: int = 200
const EXPECTED_ROWS: int = 1600
const ARM: int = 3
const ASPECT: String = "duskblade"
const VOWS: Array[int] = [0, 5]
const PREFLIGHT_SEED_FIRST: int = 9000
const PREFLIGHT_SEED_LAST: int = 9049


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		_fail(str(opts["error"]))
		return
	var protocol_path: String = str(opts["protocol"])
	if FileAccess.get_sha256(protocol_path) != str(opts["protocolSha"]):
		_fail("protocol SHA-256 mismatch")
		return
	var protocol_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(protocol_path))
	if typeof(protocol_v) != TYPE_DICTIONARY:
		_fail("protocol did not parse")
		return
	var protocol: Dictionary = protocol_v
	if str(protocol.get("protocolId", "")) != PROTOCOL_ID:
		_fail("protocol identity mismatch")
		return
	var out_path: String = str(opts["out"])
	if FileAccess.file_exists(out_path):
		_fail("row output already exists")
		return
	var candidate: ContentDB = ContentDB.load_full(false)
	var current_main: ContentDB = ContentDB.load_from(str(opts["currentMain"]), false)
	var null_card: ContentDB = _null_card_content()
	if candidate == null or current_main == null or null_card == null:
		_fail("one or more frozen content projections did not load")
		return
	var mode: String = str(opts["mode"])
	if mode == "preflight":
		_write_preflight(out_path, candidate, str(opts["protocolSha"]),
			str(opts["expectedHead"]))
		return
	if mode != "rows":
		_fail("unknown mode: %s" % mode)
		return
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create row output")
		return
	file.store_line(JSON.stringify({
		"t": "manifest", "protocolId": PROTOCOL_ID,
		"protocolSha256": opts["protocolSha"], "expectedRows": EXPECTED_ROWS,
		"executionHead": opts["expectedHead"],
		"godot": Engine.get_version_info().get("string", "unknown"),
		"pilot": Pilot.VERSION, "observer": Observer.VERSION,
		"candidateContentSha256": FileAccess.get_sha256(ContentDB.FULL_PATH),
		"currentMainContentSha256": FileAccess.get_sha256(str(opts["currentMain"])),
	}))
	var row_index: int = 0
	for vow: int in VOWS:
		for seed: int in range(SEED_FIRST, SEED_FIRST + SEED_COUNT):
			row_index += 1
			_write_row(file, candidate, "omitted", "control", ARM, ASPECT, vow, seed,
				{}, false, true, {}, row_index)
	print("p9 v4 matched re-exam: omitted control complete (%d rows)" % row_index)
	row_index = _write_panel(file, current_main, "current-main", {}, row_index)
	row_index = _write_panel(file, candidate, "explicit-off",
		{"combat": {"wardSurplus": 0.0}}, row_index)
	row_index = _write_panel(file, null_card, "null-card", {}, row_index)
	file.flush()
	file.close()
	if row_index != EXPECTED_ROWS:
		_fail("row count drifted: %d" % row_index)
		return
	print(JSON.stringify({"protocolId": PROTOCOL_ID, "rows": row_index, "out": out_path}))
	quit(0)


func _write_panel(file: FileAccess, content: ContentDB, variant: String,
		policy: Dictionary, row_index: int) -> int:
	for vow: int in VOWS:
		for seed: int in range(SEED_FIRST, SEED_FIRST + SEED_COUNT):
			row_index += 1
			_write_row(file, content, variant, "comparator", ARM, ASPECT, vow,
				seed, policy, false, true, {}, row_index)
	print("p9 v4 matched re-exam: %s comparator complete (%d rows)" % [variant, row_index])
	return row_index


func _write_row(file: FileAccess, content: ContentDB, variant: String, cohort: String,
		arm: int, aspect: String, vow: int, seed: int, policy: Dictionary,
		random_build: bool, random_play: bool, mix: Dictionary, row_index: int) -> void:
	var row: Dictionary = Sim.simulate(content, aspect, seed, vow, PackedStringArray(),
		policy, random_build, random_play, mix)
	file.store_line(JSON.stringify(_serialise_row(row, variant, cohort, arm, row_index)))
	if row_index % 50 == 0:
		file.flush()


func _serialise_row(row: Dictionary, variant: String, cohort: String,
		arm: int, row_index: int) -> Dictionary:
	var events: Dictionary = row.get("packageEvents", {})
	var shatters: int = 0
	var ceiling_fight: Dictionary = {}
	for fight_v: Variant in row.get("fights", []):
		var fight: Dictionary = fight_v
		shatters += _integer(fight.get("shatters", 0))
		if str(fight.get("result", "")) == "turnCeiling":
			ceiling_fight = {
				"act": fight.get("act", -1), "kind": fight.get("kind", ""),
				"enemies": fight.get("enemies", []), "turns": fight.get("turns", -1),
			}
	var resolved_policy: Dictionary = row.get("policy", {})
	var combat_policy: Dictionary = resolved_policy.get("combat", {})
	var deck_ids: Array = row.get("deckIds", [])
	var trajectory: Dictionary = row.duplicate(true)
	trajectory.erase("packageEvents")
	trajectory.erase("policy")
	return {
		"t": "row", "rowIndex": row_index, "variant": variant, "cohort": cohort,
		"arm": arm, "aspect": row.get("aspect", ""), "vow": row.get("vow", -1),
		"seed": row.get("seed", -1),
		"outcome": row.get("outcome", "error"), "error": row.get("error", ""),
		"rng": row.get("rng", -1), "outcomeDigest": Sim.outcome_digest(row),
		"trajectoryDigest": JSON.stringify(trajectory).sha256_text(),
		"shatters": shatters,
		"facetBurstOffered": _integer(events.get("facetBurstOffered", 0)),
		"facetBurstDrawn": _integer(events.get("facetBurstDrawn", 0)),
		"facetBurstPlayed": _integer(events.get("facetBurstPlayed", 0)),
		"facetBurstInDeck": 1 if deck_ids.has("facetBurst") else 0,
		"ceilingFight": ceiling_fight,
		"h11PlayerDuskEnemySmolder": _integer(events.get(Observer.COUNT_KEY, 0)),
		"wardSurplus": float(str(combat_policy.get("wardSurplus", -1.0))),
	}


func _write_preflight(out_path: String, content: ContentDB, protocol_sha: String,
		expected_head: String) -> void:
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create preflight output")
		return
	file.store_line(JSON.stringify({
		"t": "preflightManifest", "protocolId": PROTOCOL_ID,
		"protocolSha256": protocol_sha, "executionHead": expected_head,
		"seedFirst": PREFLIGHT_SEED_FIRST,
		"seedLast": PREFLIGHT_SEED_LAST, "protocolRows": 0,
	}))
	var found_positive: bool = false
	for seed: int in range(PREFLIGHT_SEED_FIRST, PREFLIGHT_SEED_LAST + 1):
		var legacy_source: Dictionary = Sim.simulate(content, ASPECT, seed, 0,
			PackedStringArray(), {}, false, true)
		var enriched_source: Dictionary = Sim.simulate(content, ASPECT, seed, 0,
			PackedStringArray(), {}, false, true)
		var non_default_source: Dictionary = Sim.simulate(content, ASPECT, seed, 0,
			PackedStringArray(), {"combat": {"wardSurplus": 0.0}}, false, true)
		var enriched: Dictionary = _serialise_row(enriched_source, "omitted", "preflight",
			ARM, seed - PREFLIGHT_SEED_FIRST + 1)
		var non_default: Dictionary = _serialise_row(non_default_source, "explicit-off",
			"preflight", ARM, seed - PREFLIGHT_SEED_FIRST + 1)
		var events: Dictionary = enriched_source.get("packageEvents", {})
		var legacy_trajectory: Dictionary = legacy_source.duplicate(true)
		legacy_trajectory.erase("packageEvents")
		legacy_trajectory.erase("policy")
		file.store_line(JSON.stringify({
			"t": "probe", "seed": seed, "protocolRows": 0,
			"eventKeys": {
				"facetBurstOffered": events.has("facetBurstOffered"),
				"facetBurstDrawn": events.has("facetBurstDrawn"),
				"facetBurstPlayed": events.has("facetBurstPlayed"),
			},
			"v3Writer": {
				"outcome": legacy_source.get("outcome", "error"),
				"rng": legacy_source.get("rng", -1),
				"trajectoryDigest": JSON.stringify(legacy_trajectory).sha256_text(),
			},
			"enrichedWriter": enriched,
			"nonDefaultWriter": non_default,
		}))
		if _integer(enriched.get("facetBurstPlayed", 0)) > 0:
			found_positive = true
			break
	file.flush()
	file.close()
	if not found_positive:
		_fail("facetBurstPlayed stayed zero across preflight seeds 9000-9049")
		return
	print("PASS (p9-w0-v4 probe signal became positive; protocol rows=0)")
	quit(0)


func _null_card_content() -> ContentDB:
	var content: ContentDB = ContentDB.load_full(false)
	if content == null:
		return null
	content.cards.erase("facetBurst")
	for tier_v: Variant in content.card_pools:
		var pool: Array = content.card_pools[str(tier_v)]
		pool.erase("facetBurst")
	return content


func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {
		"protocol": "", "protocolSha": "", "expectedHead": "", "currentMain": "",
		"out": "", "mode": "",
	}
	for arg: String in args:
		if not arg.begins_with("--") or not arg.contains("="):
			return {"error": "expected --name=value, got %s" % arg}
		var key: String = arg.get_slice("=", 0).trim_prefix("--")
		if not out.has(key):
			return {"error": "unknown option --%s" % key}
		out[key] = arg.substr(arg.find("=") + 1)
	for key: String in out:
		if str(out[key]).is_empty():
			return {"error": "--%s is required" % key}
	return out


func _integer(value: Variant) -> int:
	return int(float(str(value)))


func _fail(message: String) -> void:
	push_error("p9_w0_v2_phase_a_rows: %s" % message)
	quit(2)
