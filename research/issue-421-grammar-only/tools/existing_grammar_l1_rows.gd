extends SceneTree
## Frozen L0/L1 row generator for the existing-grammar expression exam.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const PROTOCOL_ID: String = "existing-grammar-l0-l1-v2"
const ASPECT: String = "duskblade"
const COHORT_FIRST: int = 6000
const COHORT_LAST: int = 6255
const PREFLIGHT_FIRST: int = 9500
const PREFLIGHT_LAST: int = 9549
const EXPECTED_ROWS: int = 2048
const L0_UNLOCKS: Array[String] = ["aspect2"]
const L1_UNLOCKS: Array[String] = ["aspect2", "card:quakeblow", "card:resonantLance"]


func _initialize() -> void:
	var opts: Dictionary = _options(OS.get_cmdline_user_args())
	if opts.has("error"):
		_fail(str(opts["error"]))
		return
	if FileAccess.get_sha256(str(opts["protocol"])) != str(opts["protocolSha"]):
		_fail("protocol SHA-256 mismatch")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(opts["protocol"])))
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("protocolId", "")) != PROTOCOL_ID:
		_fail("protocol identity mismatch")
		return
	var out_path: String = str(opts["out"])
	if FileAccess.file_exists(out_path):
		_fail("output already exists")
		return
	var content: ContentDB = ContentDB.load_full(false)
	if content == null:
		_fail("content did not load")
		return
	match str(opts["mode"]):
		"preflight":
			_write_preflight(out_path, content, opts)
		"rows":
			_write_rows(out_path, content, opts)
		_:
			_fail("mode must be preflight or rows")


func _write_preflight(out_path: String, content: ContentDB, opts: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create preflight output")
		return
	file.store_line(JSON.stringify(_manifest("preflightManifest", opts, 0)))
	var baseline: Dictionary = Sim.simulate(content, ASPECT, 1000, 0)
	file.store_line(JSON.stringify({
		"t": "baseline", "seed": 1000, "protocolRows": 0,
		"outcomeDigest": Sim.outcome_digest(baseline),
	}))
	var rewards: RewardRules = RewardRules.new(content)
	var l0_run: RunState = _pool_run(content, PackedStringArray(L0_UNLOCKS), "pool-l0")
	var l1_run: RunState = _pool_run(content, PackedStringArray(L1_UNLOCKS), "pool-l1")
	var pools: Dictionary = {"L0": {}, "L1": {}}
	for tier: String in ["common", "uncommon", "rare"]:
		pools["L0"][tier] = rewards.card_pool(l0_run, tier)
		pools["L1"][tier] = rewards.card_pool(l1_run, tier)
	file.store_line(JSON.stringify({"t": "pools", "protocolRows": 0, "pools": pools}))
	for seed: int in range(PREFLIGHT_FIRST, PREFLIGHT_LAST + 1):
		var l0_row: Dictionary = _run(content, seed, 0, false, PackedStringArray(L0_UNLOCKS))
		var l1_row: Dictionary = _run(content, seed, 0, false, PackedStringArray(L1_UNLOCKS))
		var probe: Dictionary = {
			"t": "probe", "seed": seed, "protocolRows": 0,
			"l0Rng": l0_row.get("rng", -1), "l1Rng": l1_row.get("rng", -1),
			"l0Outcome": l0_row.get("outcome", "error"),
			"l1Outcome": l1_row.get("outcome", "error"),
		}
		_add_participation(probe, l1_row, "resonantLance")
		_add_participation(probe, l1_row, "quakeblow")
		file.store_line(JSON.stringify(probe))
		if _integer(probe["resonantLancePlayed"]) > 0:
			break
	file.flush()
	file.close()
	print("existing grammar L0/L1: preflight artifact complete (protocol rows=0)")
	quit(0)


func _write_rows(out_path: String, content: ContentDB, opts: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create cohort output")
		return
	file.store_line(JSON.stringify(_manifest("manifest", opts, EXPECTED_ROWS)))
	var row_index: int = 0
	for arm: String in ["L0", "L1"]:
		var unlocks: PackedStringArray = PackedStringArray(
			L0_UNLOCKS if arm == "L0" else L1_UNLOCKS)
		for vow: int in [0, 5]:
			for policy: String in ["competent", "RandomBuild"]:
				for seed: int in range(COHORT_FIRST, COHORT_LAST + 1):
					row_index += 1
					var source: Dictionary = _run(content, seed, vow,
						policy == "RandomBuild", unlocks)
					file.store_line(JSON.stringify(_serialise(source, arm, policy, row_index)))
					if row_index % 64 == 0:
						file.flush()
				print("existing grammar L0/L1: %s V%d %s complete (%d rows)" %
					[arm, vow, policy, row_index])
	file.flush()
	file.close()
	if row_index != EXPECTED_ROWS:
		_fail("row count drifted: %d" % row_index)
		return
	print(JSON.stringify({"protocolId": PROTOCOL_ID, "rows": row_index, "out": out_path}))
	quit(0)


func _run(content: ContentDB, seed: int, vow: int, random_build: bool,
		unlocks: PackedStringArray) -> Dictionary:
	return Sim.simulate(content, ASPECT, seed, vow, PackedStringArray(), {},
		random_build, false, {}, null, false, unlocks)


func _serialise(source: Dictionary, arm: String, policy: String, row_index: int) -> Dictionary:
	var out: Dictionary = {
		"t": "row", "rowIndex": row_index, "arm": arm, "policy": policy,
		"aspect": source.get("aspect", ""), "vow": source.get("vow", -1),
		"seed": source.get("seed", -1), "outcome": source.get("outcome", "error"),
		"error": source.get("error", ""), "rng": source.get("rng", -1),
		"outcomeDigest": Sim.outcome_digest(source), "shatters": 0,
	}
	for fight_v: Variant in source.get("fights", []):
		var fight: Dictionary = fight_v
		out["shatters"] = _integer(out["shatters"]) + _integer(fight.get("shatters", 0))
	_add_participation(out, source, "resonantLance")
	_add_participation(out, source, "quakeblow")
	return out


func _add_participation(out: Dictionary, source: Dictionary, card_id: String) -> void:
	var events: Dictionary = source.get("packageEvents", {})
	var deck_ids: Array = source.get("deckIds", [])
	for suffix: String in ["Offered", "Drawn", "Played"]:
		out[card_id + suffix] = _integer(events.get(card_id + suffix, 0))
	out[card_id + "InDeck"] = 1 if deck_ids.has(card_id) else 0


func _pool_run(content: ContentDB, unlocks: PackedStringArray, run_id: String) -> RunState:
	return RunState.new_run(content, 1, run_id, {
		"aspect": 0, "vow": 0, "reveals": content.reveal_ids.duplicate(),
		"unlocks": unlocks, "quests": {}, "shards": [], "lamplighter": false,
	})


func _manifest(kind: String, opts: Dictionary, expected_rows: int) -> Dictionary:
	return {
		"t": kind, "protocolId": PROTOCOL_ID, "protocolSha256": opts["protocolSha"],
		"executionHead": opts["expectedHead"], "expectedRows": expected_rows,
		"godot": Engine.get_version_info().get("string", "unknown"),
		"contentSha256": FileAccess.get_sha256(ContentDB.FULL_PATH),
	}


func _options(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {
		"mode": "", "out": "", "protocol": "", "protocolSha": "", "expectedHead": "",
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
	push_error("existing_grammar_l1_rows: %s" % message)
	quit(2)
