extends SceneTree
## Frozen row generator for the single p9-w0-v2 Phase A invocation.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const Observer: GDScript = preload("res://tools/p9_ward_observer.gd")
const PROTOCOL_ID: String = "p9-w0-v2-phase-a"
const SEED_FIRST: int = 4000
const SEED_COUNT: int = 200
const ARMS: Array[int] = [1, 2, 3, 4]
const ASPECTS: Array[String] = ["duskblade", "ashwarden"]
const VOWS: Array[int] = [0, 5]


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
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create row output")
		return
	file.store_line(JSON.stringify({
		"t": "manifest", "protocolId": PROTOCOL_ID,
		"protocolSha256": opts["protocolSha"], "expectedRows": 5200,
		"godot": Engine.get_version_info().get("string", "unknown"),
		"pilot": Pilot.VERSION, "observer": Observer.VERSION,
		"candidateContentSha256": FileAccess.get_sha256(ContentDB.FULL_PATH),
		"currentMainContentSha256": FileAccess.get_sha256(str(opts["currentMain"])),
	}))
	var row_index: int = 0
	for arm: int in ARMS:
		for aspect: String in ASPECTS:
			for vow: int in VOWS:
				for seed: int in range(SEED_FIRST, SEED_FIRST + SEED_COUNT):
					row_index += 1
					_write_row(file, candidate, "omitted", "control", arm,
						aspect, vow, seed, {}, arm == 2 or arm == 4,
						arm == 3 or arm == 4, {}, row_index)
	print("p9 Phase A: omitted controls complete (%d rows)" % row_index)
	var no_mix: Dictionary = Incentives.by_id("none")
	for aspect: String in ASPECTS:
		for vow: int in VOWS:
			for seed: int in range(5000, 5000 + SEED_COUNT):
				row_index += 1
				_write_row(file, candidate, "omitted", "holdout", 1, aspect, vow, seed,
					{}, false, false, no_mix, row_index)
	print("p9 Phase A: omitted holdout complete (%d rows)" % row_index)
	row_index = _write_panel(file, current_main, "current-main", {}, row_index)
	row_index = _write_panel(file, candidate, "explicit-off",
		{"combat": {"wardSurplus": 0.0}}, row_index)
	row_index = _write_panel(file, null_card, "null-card", {}, row_index)
	file.flush()
	file.close()
	if row_index != 5200:
		_fail("row count drifted: %d" % row_index)
		return
	print(JSON.stringify({"protocolId": PROTOCOL_ID, "rows": row_index, "out": out_path}))
	quit(0)


func _write_panel(file: FileAccess, content: ContentDB, variant: String,
		policy: Dictionary, row_index: int) -> int:
	for vow: int in VOWS:
		for seed: int in range(SEED_FIRST, SEED_FIRST + SEED_COUNT):
			row_index += 1
			_write_row(file, content, variant, "comparator", 1, "duskblade", vow,
				seed, policy, false, false, {}, row_index)
	print("p9 Phase A: %s comparator complete (%d rows)" % [variant, row_index])
	return row_index


func _write_row(file: FileAccess, content: ContentDB, variant: String, cohort: String,
		arm: int, aspect: String, vow: int, seed: int, policy: Dictionary,
		random_build: bool, random_play: bool, mix: Dictionary, row_index: int) -> void:
	var row: Dictionary = Sim.simulate(content, aspect, seed, vow, PackedStringArray(),
		policy, random_build, random_play, mix)
	var events: Dictionary = row.get("packageEvents", {})
	var shatters: int = 0
	for fight_v: Variant in row.get("fights", []):
		var fight: Dictionary = fight_v
		shatters += _integer(fight.get("shatters", 0))
	var resolved_policy: Dictionary = row.get("policy", {})
	var combat_policy: Dictionary = resolved_policy.get("combat", {})
	file.store_line(JSON.stringify({
		"t": "row", "rowIndex": row_index, "variant": variant, "cohort": cohort,
		"arm": arm, "aspect": aspect, "vow": vow, "seed": seed,
		"outcome": row.get("outcome", "error"), "error": row.get("error", ""),
		"rng": row.get("rng", -1), "outcomeDigest": Sim.outcome_digest(row),
		"shatters": shatters,
		"facetBurstPlayed": _integer(events.get("facetBurstPlayed", 0)),
		"h11PlayerDuskEnemySmolder": _integer(events.get(Observer.COUNT_KEY, 0)),
		"wardSurplus": float(str(combat_policy.get("wardSurplus", -1.0))),
	}))
	if row_index % 50 == 0:
		file.flush()


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
	var out: Dictionary = {"protocol": "", "protocolSha": "", "currentMain": "", "out": ""}
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
