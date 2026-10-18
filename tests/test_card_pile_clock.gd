extends RefCounted
## The two card/pile regressions use the engine's fixed simulation step while
## retaining its real timers, tweens and callbacks. A slow host frame must not
## spend their animation budgets or change the order of those callbacks.

const SUITE: String = "res://tests/test_card_pile_clock.gd"
const FIXED_FPS: int = 60
const FRAME_COUNT: int = 6
const SECONDS: float = 0.1
const HARNESS: GDScript = preload("res://tests/support/tree_suite.gd")


static func run(fails: Array[String]) -> void:
	for path: String in ["res://tests/test_card_flights.gd", "res://tests/test_pile_fight.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		if not source.contains("TreeSuite.spawn(fails, SUITE, FIXED_FPS)") \
				or not source.contains("const FIXED_FPS: int = 60"):
			fails.append("card pile clock: %s does not use the fixed-step child" % path)
		if source.contains("Time.get_ticks_msec()"):
			fails.append("card pile clock: %s still bounds animation progress by wall time" % path)
	var supported: bool = false
	for method: Dictionary in HARNESS.get_script_method_list():
		if str(method.get("name", "")) == "spawn":
			var arguments: Array = method.get("args", [])
			supported = arguments.size() == 3
	if not supported:
		fails.append("card pile clock: TreeSuite.spawn cannot request a fixed simulation step")
		return
	# Reflection lets this regression report the missing seam on the old helper,
	# rather than failing to parse because the old spawn accepts two arguments.
	HARNESS.call("spawn", fails, SUITE, FIXED_FPS)


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var started: int = Engine.get_process_frames()
	var timer_frames: Array[int] = []
	var tween_frames: Array[int] = []
	var timer: SceneTreeTimer = tree.create_timer(SECONDS)
	timer.timeout.connect(func() -> void:
		timer_frames.append(Engine.get_process_frames() - started))
	var tween: Tween = host.create_tween()
	tween.tween_interval(SECONDS)
	tween.tween_callback(func() -> void:
		tween_frames.append(Engine.get_process_frames() - started))
	for frame: int in range(FRAME_COUNT + 3):
		await tree.process_frame
		var delta: float = tree.root.get_process_delta_time()
		if not is_equal_approx(delta, 1.0 / float(FIXED_FPS)):
			fails.append("card pile clock: frame %d advances %.6f s, not 1/60" % [frame, delta])
		if frame == 1:
			# More than four nominal frames elapse on the host. Neither of the
			# production timing primitives may turn that into simulation progress.
			OS.delay_msec(80)
	for row: Array[int] in [timer_frames, tween_frames]:
		# A timer and a newly-created tween start on different engine phases;
		# allow that one-frame phase, retaining the nominal 100 ms duration.
		if row.size() != 1 or row[0] < FRAME_COUNT - 1 or row[0] > FRAME_COUNT + 1:
			fails.append("card pile clock: a 100 ms callback completed at frames %s, want once at 5..7"
				% str(row))
