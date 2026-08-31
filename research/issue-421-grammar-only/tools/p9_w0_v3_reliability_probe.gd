extends SceneTree
## Zero-row assertion of the p9-w0-v3 reliability classification.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Metrics: GDScript = preload("res://tools/balance_metrics.gd")

func _initialize() -> void:
	var content: ContentDB = ContentDB.load_full(false)
	if content == null:
		_fail("candidate content did not load")
		return
	var ceiling: Dictionary = Sim.simulate(content, "duskblade", 4151, 0,
		PackedStringArray(), {}, false, true)
	var fights: Array = ceiling.get("fights", [])
	if str(ceiling.get("outcome", "")) != "turnCeiling" or fights.is_empty() \
			or typeof(fights[-1]) != TYPE_DICTIONARY:
		_fail("forced 30-turn run did not yield turnCeiling")
		return
	var final_fight: Dictionary = fights[-1]
	if str(final_fight.get("result", "")) != "turnCeiling" \
			or int(float(str(final_fight.get("turns", -1)))) != 30:
		_fail("forced fight did not retain the unchanged 30-turn ceiling")
		return
	var run: RunState = RunState.new_run(content, 7, "p9-w0-v3-induced-error")
	var empty: Array[Dictionary] = []
	var induced: Dictionary = Sim._finish(run, "duskblade", 7, "error", empty,
		"induced simulator failure probe", empty, null, content)
	if str(induced.get("outcome", "")) != "error" \
			or str(induced.get("error", "")) != "induced simulator failure probe":
		_fail("induced simulator failure did not retain error")
		return
	var rows: Array[Dictionary] = [ceiling, induced]
	var report: Dictionary = Metrics.report(rows, {"vow": 0})
	var summaries: Dictionary = report["summary"]
	var summary: Dictionary = summaries["duskblade"]
	if int(float(str(summary["runs"]))) != 2 or int(float(str(summary["wins"]))) != 0 \
			or int(float(str(summary["turnCeilings"]))) != 1 \
			or int(float(str(summary["stalls"]))) != 0 or int(float(str(summary["errors"]))) != 1:
		_fail("turnCeiling/error metric buckets or denominator drifted")
		return
	print("PASS (turnCeiling at 30, induced error retained, censored denominator retained)")
	quit(0)

func _fail(message: String) -> void:
	push_error("p9_w0_v3_reliability_probe: %s" % message)
	quit(1)
