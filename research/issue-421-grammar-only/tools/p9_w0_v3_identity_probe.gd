extends SceneTree
## Aggregate-only replay assertion for every non-censored v2 coordinate.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Incentives: GDScript = preload("res://tools/vow_incentives.gd")
const V2_ROWS: String = "res://research/issue-421-grammar-only/artifacts/p9-w0-v2-phase-a/raw-rows.jsonl"
const V2_SHA: String = "f7c1ab4a5ca0228f98393c30b9f4f998d22f61e833c7eda791bf2404375323dd"
const CURRENT: String = "res://research/issue-421-grammar-only/inputs/current-main-c28ae388-full-content.json"

func _initialize() -> void:
	if FileAccess.get_sha256(V2_ROWS) != V2_SHA:
		_fail("immutable v2 raw-row identity mismatch")
		return
	var candidate: ContentDB = ContentDB.load_full(false)
	var current: ContentDB = ContentDB.load_from(CURRENT, false)
	var null_card: ContentDB = _null_card()
	var file: FileAccess = FileAccess.open(V2_ROWS, FileAccess.READ)
	if candidate == null or current == null or null_card == null or file == null:
		_fail("frozen identity-probe input did not load")
		return
	var rows: int = 0
	var checked: int = 0
	var censored: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail("v2 raw-row JSON did not parse")
			return
		var source: Dictionary = parsed
		if str(source.get("t", "")) == "manifest":
			continue
		rows += 1
		if str(source.get("outcome", "")) == "stall":
			censored += 1
			continue
		var actual: Dictionary = _replay(source, candidate, current, null_card)
		checked += 1
		if Sim.outcome_digest(actual) != str(source["outcomeDigest"]):
			_fail("non-censored outcomeDigest drift at row %d" % int(float(str(source["rowIndex"]))))
			return
		if int(float(str(actual.get("rng", -1)))) != int(float(str(source["rng"]))):
			_fail("non-censored final-RNG drift at row %d" % int(float(str(source["rowIndex"]))))
			return
	file.close()
	if rows != 5200 or checked != 5197 or censored != 3:
		_fail("identity cardinality drift: rows=%d checked=%d censored=%d" % [rows, checked, censored])
		return
	print("PASS (5197/5197 non-censored v2 rows preserve outcomeDigest and final RNG; 3 censored excluded)")
	quit(0)

func _replay(source: Dictionary, candidate: ContentDB, current: ContentDB,
		null_card: ContentDB) -> Dictionary:
	var variant: String = str(source["variant"])
	var content: ContentDB = current if variant == "current-main" else (
		null_card if variant == "null-card" else candidate)
	var policy: Dictionary = {"combat": {"wardSurplus": 0.0}} \
		if variant == "explicit-off" else {}
	var arm: int = int(float(str(source["arm"])))
	var mix: Dictionary = Incentives.by_id("none") \
		if str(source["cohort"]) == "holdout" else {}
	return Sim.simulate(content, str(source["aspect"]), int(float(str(source["seed"]))),
		int(float(str(source["vow"]))), PackedStringArray(), policy,
		arm == 2 or arm == 4, arm == 3 or arm == 4, mix)

func _null_card() -> ContentDB:
	var content: ContentDB = ContentDB.load_full(false)
	if content == null:
		return null
	content.cards.erase("facetBurst")
	for tier_v: Variant in content.card_pools:
		var pool: Array = content.card_pools[str(tier_v)]
		pool.erase("facetBurst")
	return content

func _fail(message: String) -> void:
	push_error("p9_w0_v3_identity_probe: %s" % message)
	quit(1)
