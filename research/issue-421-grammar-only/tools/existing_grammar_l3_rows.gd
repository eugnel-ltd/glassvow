extends SceneTree
## Frozen L2/L3 row generator for the existing-grammar L3 exam.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const PROTOCOL_ID: String = "existing-grammar-l2-l3-v1"
const ASPECT: String = "duskblade"
const COHORT_FIRST: int = 8000
const COHORT_LAST: int = 8255
const PREFLIGHT_FIRST: int = 9700
const PREFLIGHT_LAST: int = 9749
const EXPECTED_ROWS: int = 2048
const L2_UNLOCKS: Array[String] = [
	"aspect2", "card:quakeblow", "card:resonantLance",
	"card:shardstorm", "relic:bellOfEndings", "card:flawlessForm", "relic:prismCharm",
]
const L3_UNLOCKS: Array[String] = [
	"aspect2", "card:quakeblow", "card:resonantLance",
	"card:shardstorm", "relic:bellOfEndings", "card:flawlessForm", "relic:prismCharm",
	"card:nightSight", "relic:thiefOfWicks", "card:novaflare", "card:emberdance",
]
const CARDS: Array[String] = [
	"resonantLance", "quakeblow", "shardstorm", "flawlessForm",
	"nightSight", "novaflare", "emberdance",
]
const RELICS: Array[String] = ["bellOfEndings", "prismCharm", "thiefOfWicks"]
const CARD_TIERS: Array[String] = ["common", "uncommon", "rare"]
const RELIC_TIERS: Array[String] = ["common", "uncommon", "rare", "boss"]


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
	var l2_run: RunState = _pool_run(content, PackedStringArray(L2_UNLOCKS), "pool-l2")
	var l3_run: RunState = _pool_run(content, PackedStringArray(L3_UNLOCKS), "pool-l3")
	var pools: Dictionary = {"cards": {"L2": {}, "L3": {}}, "relics": {"L2": {}, "L3": {}}}
	for tier: String in CARD_TIERS:
		pools["cards"]["L2"][tier] = rewards.card_pool(l2_run, tier)
		pools["cards"]["L3"][tier] = rewards.card_pool(l3_run, tier)
	for tier: String in RELIC_TIERS:
		pools["relics"]["L2"][tier] = rewards.relic_pool(l2_run, tier)
		pools["relics"]["L3"][tier] = rewards.relic_pool(l3_run, tier)
	file.store_line(JSON.stringify({"t": "pools", "protocolRows": 0, "pools": pools}))
	var consumer_found: bool = false
	var thief_proc_found: bool = false
	for seed: int in range(PREFLIGHT_FIRST, PREFLIGHT_LAST + 1):
		var source: Dictionary = _run(content, seed, 0, false, PackedStringArray(L3_UNLOCKS))
		var probe: Dictionary = {
			"t": "consumerProbe", "seed": seed, "protocolRows": 0,
			"outcome": source.get("outcome", "error"), "error": source.get("error", ""),
		}
		_add_participation(probe, source)
		var events: Dictionary = source.get("packageEvents", {})
		probe["unlitVisited"] = _integer(events.get("unlitVisited", 0))
		file.store_line(JSON.stringify(probe))
		consumer_found = consumer_found or _consumer_activated(probe)
		thief_proc_found = thief_proc_found or _integer(probe.get("thiefOfWicksProcs", 0)) > 0
		if consumer_found and thief_proc_found:
			break
	for seed: int in range(COHORT_FIRST, COHORT_LAST + 1):
		var l2: Dictionary = _run(content, seed, 0, false, PackedStringArray(L2_UNLOCKS))
		var l3: Dictionary = _run(content, seed, 0, false, PackedStringArray(L3_UNLOCKS))
		var rng_probe: Dictionary = {
			"t": "rngProbe", "seed": seed, "vow": 0, "policy": "competent",
			"protocolRows": 0, "l2Rng": l2.get("rng", -1), "l3Rng": l3.get("rng", -1),
			"l2Outcome": l2.get("outcome", "error"), "l3Outcome": l3.get("outcome", "error"),
		}
		file.store_line(JSON.stringify(rng_probe))
		if rng_probe["l2Rng"] != rng_probe["l3Rng"]:
			break
	file.flush()
	file.close()
	print("existing grammar L2/L3: preflight artifact complete (protocol rows=0)")
	quit(0)


func _write_rows(out_path: String, content: ContentDB, opts: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("cannot create cohort output")
		return
	file.store_line(JSON.stringify(_manifest("manifest", opts, EXPECTED_ROWS)))
	var row_index: int = 0
	for arm: String in ["L2", "L3"]:
		var unlocks: PackedStringArray = PackedStringArray(L2_UNLOCKS if arm == "L2" else L3_UNLOCKS)
		for vow: int in [0, 5]:
			for policy: String in ["competent", "RandomBuild"]:
				for seed: int in range(COHORT_FIRST, COHORT_LAST + 1):
					row_index += 1
					var source: Dictionary = _run(content, seed, vow, policy == "RandomBuild", unlocks)
					file.store_line(JSON.stringify(_serialise(source, arm, policy, row_index)))
					if row_index % 64 == 0:
						file.flush()
				print("existing grammar L2/L3: %s V%d %s complete (%d rows)" %
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
	var events: Dictionary = source.get("packageEvents", {})
	var out: Dictionary = {
		"t": "row", "rowIndex": row_index, "arm": arm, "policy": policy,
		"aspect": source.get("aspect", ""), "vow": source.get("vow", -1),
		"seed": source.get("seed", -1), "outcome": source.get("outcome", "error"),
		"error": source.get("error", ""), "rng": source.get("rng", -1),
		"outcomeDigest": Sim.outcome_digest(source),
		"unlitVisited": _integer(events.get("unlitVisited", 0)),
		"embersSpent": _integer(events.get("embersSpent", 0)),
	}
	_add_participation(out, source)
	return out


func _add_participation(out: Dictionary, source: Dictionary) -> void:
	var events: Dictionary = source.get("packageEvents", {})
	var deck_ids: Array = source.get("deckIds", [])
	for card_id: String in CARDS:
		for suffix: String in ["Offered", "Drawn", "Played"]:
			out[card_id + suffix] = _integer(events.get(card_id + suffix, 0))
		out[card_id + "InDeck"] = 1 if deck_ids.has(card_id) else 0
	var owned_relics: Array = source.get("relics", [])
	for relic_id: String in RELICS:
		out[relic_id + "Offered"] = _integer(events.get(relic_id + "Offered", 0))
		out[relic_id + "Owned"] = 1 if owned_relics.has(relic_id) else 0
		out[relic_id + "Procs"] = _integer(events.get(relic_id + "Procs", 0))


func _consumer_activated(row: Dictionary) -> bool:
	return _integer(row.get("resonantLancePlayed", 0)) > 0 \
		or _integer(row.get("shardstormPlayed", 0)) > 0 \
		or _integer(row.get("flawlessFormPlayed", 0)) > 0 \
		or _integer(row.get("bellOfEndingsProcs", 0)) > 0 \
		or _integer(row.get("prismCharmProcs", 0)) > 0 \
		or _integer(row.get("nightSightPlayed", 0)) > 0 \
		or _integer(row.get("novaflarePlayed", 0)) > 0 \
		or _integer(row.get("emberdancePlayed", 0)) > 0 \
		or _integer(row.get("thiefOfWicksProcs", 0)) > 0


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
	push_error("existing_grammar_l3_rows: %s" % message)
	quit(2)
