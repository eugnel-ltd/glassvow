extends RefCounted
## Deterministic laws for the headed performance probe. Runtime timing remains
## outside the headless suite; argument/route failures are exercised headed.

const Bench: GDScript = preload("res://tools/bench_combat.gd")


static func run(fails: Array[String]) -> void:
	var values: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
	var empty_values: Array[float] = []
	var median: float = Bench.percentile(values, 0.50)
	var p95: float = Bench.percentile(values, 0.95)
	var empty: float = Bench.percentile(empty_values, 0.95)
	_check(fails, median == 3.0,
		"combat bench median uses the sorted middle sample")
	_check(fails, p95 == 5.0,
		"combat bench p95 uses the fail-closed upper sample")
	_check(fails, empty == 0.0,
		"combat bench empty percentile is explicit")
	var particles: int = Bench.PEAK_VFX_PARTICLES
	_check(fails, particles == 96,
		"combat bench locks the peak VFX particle count")
	if not Bench.has_method("request"):
		fails.append("combat bench has no fail-closed release request contract")
		return
	var args: PackedStringArray = PackedStringArray([
		"--fight=sporeling,sporeling,sporeling", "--kind=normal",
		"--seed=717", "--act=1", "--shape=phone-landscape",
		"--vp=844x390", "--perf-language=zh-Hant",
		"--perf-commit=0123456789abcdef0123456789abcdef01234567",
		"--perf-out=/tmp/report.json",
	])
	var valid: Dictionary = Bench.request(args)
	_check(fails, not valid.has("error"),
		"combat bench accepts the complete release request")
	# `--act=` is the act NUMBER, counted from 1 (#451). The request keeps the
	# 0-based act index the plan and the report carry, so the evidence schema is
	# unchanged: Act I is index 0, and the release fight's Act II is index 1.
	var act_index: int = valid.get("act", -1)
	_check(fails, act_index == 0, "combat bench reads --act=1 as act index 0")
	for pair: Array in [["--act=2", 1], ["--act=3", 2]]:
		var flag: String = pair[0]
		var want: int = pair[1]
		var numbered: PackedStringArray = args.duplicate()
		numbered[numbered.find("--act=1")] = flag
		var numbered_result: Dictionary = Bench.request(numbered)
		var numbered_index: int = numbered_result.get("act", -1)
		_check(fails, numbered_index == want,
			"combat bench reads %s as act index %d" % [flag, want])
	for refused: String in ["--act=0", "--act=4", "--act=abc", "--act="]:
		var bad_act: PackedStringArray = args.duplicate()
		bad_act[bad_act.find("--act=1")] = refused
		var bad_result: Dictionary = Bench.request(bad_act)
		_check(fails, bad_result.has("error"),
			"combat bench rejects %s: not a release act number" % refused)
	var missing: PackedStringArray = args.duplicate()
	missing.remove_at(missing.find("--shape=phone-landscape"))
	var missing_result: Dictionary = Bench.request(missing)
	_check(fails, missing_result.has("error"),
		"combat bench rejects a request without a shape")
	var wrong_size: PackedStringArray = args.duplicate()
	wrong_size[wrong_size.find("--vp=844x390")] = "--vp=845x390"
	var wrong_size_result: Dictionary = Bench.request(wrong_size)
	_check(fails, wrong_size_result.has("error"),
		"combat bench rejects a window outside its shape reference")
	var duplicate: PackedStringArray = args.duplicate()
	duplicate.append("--seed=718")
	var duplicate_result: Dictionary = Bench.request(duplicate)
	_check(fails, duplicate_result.has("error"),
		"combat bench rejects duplicate release arguments")


static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok:
		fails.append(message)
