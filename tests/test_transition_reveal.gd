extends RefCounted
## A reveal built behind a cover plays in full (#713). The wipe, the iris and a
## screen's entrance are tweens, and the engine hands the frame after a heavy
## one the whole stretch as its delta. A route built behind the cover on a
## 150 ms frame must not spend half the reveal before it is seen: that frame
## moves each reveal by no more than REVEAL_STEP_MAX, and the reveal then plays
## out its whole length. The flood's own clearing runs on the same clock; it
## needs a renderer, so the running probe in the PR carries it. The in-tree half
## runs in `TreeSuite`.

const SUITE: String = "res://tests/test_transition_reveal.gd"
const STALL_MSEC: int = 150
## Real frames beside the stalled one, over the one step the clamp allows.
const SLACK: float = 0.02


static func run(fails: Array[String]) -> void:
	TreeSuite.spawn(fails, SUITE)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("transition_reveal: %s" % what)


## The largest eased progress a reveal of `time` seconds may show after the
## stalled frame.
static func _ceiling(curve: Array[float], time: float) -> float:
	return Motion.ease(curve, (TransitionLayer.REVEAL_STEP_MAX + SLACK) / time)


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	var layer: TransitionLayer = TransitionLayer.new()
	host.add_child(layer)
	var screen: Control = Control.new()
	screen.size = Vector2(1180.0, 820.0)
	host.add_child(screen)
	# Let the suite's own start-up frames pass: the reveal starts on a quiet one.
	for settle: int in 5:
		await tree.process_frame
	var stage: Vector2 = host.get_visible_rect().size
	var full: float = stage.length() * TransitionLayer.IRIS_SPAN
	var wipe_travel: float = 2.0 * TransitionLayer.WIPE_SPAN * stage.x

	layer.wipe()
	layer.iris(stage * 0.5)
	layer.screen_in(screen)
	# The heavy frame: the route is built here, behind the cover.
	OS.delay_msec(STALL_MSEC)
	await tree.process_frame
	await tree.process_frame
	var wiped: float = (layer._wipe.position.x + TransitionLayer.WIPE_SPAN * stage.x) / wipe_travel
	var radius: float = layer._iris_mat.get_shader_parameter("radius")
	var shrunk: float = 1.0 - radius / full
	_check(fails, wiped <= _ceiling(Motion.WIPE, TransitionLayer.WIPE_TIME),
		"a %d ms frame jumped the wipe %.3f of its travel" % [STALL_MSEC, wiped])
	_check(fails, shrunk <= _ceiling(Motion.TRANSIT, TransitionLayer.IRIS_TIME),
		"a %d ms frame jumped the iris %.3f of its way shut" % [STALL_MSEC, shrunk])
	_check(fails, screen.modulate.a <= _ceiling(Motion.SCREEN_IN, TransitionLayer.SCREEN_IN_TIME),
		"a %d ms frame jumped the entrance to %.3f" % [STALL_MSEC, screen.modulate.a])

	# The reveal still plays out, and ends where it always did.
	await tree.create_timer(TransitionLayer.WIPE_TIME + 0.4).timeout
	# A loaded machine draws fewer frames in that time; the reveal needs frames.
	for waited: int in 600:
		if not layer._wipe.visible and not layer._iris.visible and screen.modulate.a >= 1.0:
			break
		await tree.process_frame
	_check(fails, not layer._wipe.visible, "the wipe never finished after the long frame")
	_check(fails, not layer._iris.visible, "the iris never finished after the long frame")
	_check(fails, is_equal_approx(screen.modulate.a, 1.0)
			and screen.scale.is_equal_approx(Vector2.ONE),
		"the entrance does not land whole after the long frame")
	layer.queue_free()
	screen.queue_free()
	Preferences.active = kept
