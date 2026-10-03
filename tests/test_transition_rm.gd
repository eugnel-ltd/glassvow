extends RefCounted
## One ground and no cuts (docs/design/2026-10-03-title-rooms §2.7, §2.8, §11.1).
## Any gap between two screens is the night, never the engine's 0.3 grey: the
## project's clear colour is VOID, so a route that fades in comes up out of it.
## Under Reduce Motion every route change is a 150 ms linear fade, never the
## hard cut it was; without it the 0.45 s entrance with its 1.015 settle is
## unchanged. The fades need real tweens on nodes inside a tree, so that half
## runs in `TreeSuite`.

const SUITE: String = "res://tests/test_transition_rm.gd"
const CLEAR_COLOUR: String = "rendering/environment/defaults/default_clear_color"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("transition_rm: %s" % what)


static func run(fails: Array[String]) -> void:
	_ground_is_the_night(fails)
	TreeSuite.spawn(fails, SUITE)


## The grey-frame gate: nothing may be drawn on the engine's default grey.
static func _ground_is_the_night(fails: Array[String]) -> void:
	var setting: Variant = ProjectSettings.get_setting(CLEAR_COLOUR, Color(0.3, 0.3, 0.3))
	var clear: Color = setting if setting is Color else Color(0.3, 0.3, 0.3)
	_check(fails, clear.to_html() == LeadlightTokens.VOID.to_html(),
		"the clear colour is %s, not the night (VOID %s): a gap shows the engine's grey" % [
			clear.to_html(), LeadlightTokens.VOID.to_html()])


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	_check(fails, RenderingServer.get_default_clear_color().to_html() == LeadlightTokens.VOID.to_html(),
		"the running clear colour is %s, not VOID" % RenderingServer.get_default_clear_color())
	var layer: TransitionLayer = TransitionLayer.new()
	host.add_child(layer)
	_reduced_fades(fails, tree, host, layer)
	await _full_entrance_unchanged(fails, tree, host, layer)
	_instant_lands_whole(fails, host, layer)
	layer.queue_free()
	Preferences.active = kept


static func _screen(host: SubViewport) -> Control:
	var root: Control = Control.new()
	root.size = Vector2(1180.0, 820.0)
	host.add_child(root)
	return root


## The tweens started since `before` was taken.
static func _started(tree: SceneTree, before: Array[Tween]) -> Array[Tween]:
	var out: Array[Tween] = []
	for tween: Tween in tree.get_processed_tweens():
		if not before.has(tween):
			out.append(tween)
	return out


static func _step(tweens: Array[Tween], seconds: float) -> void:
	for tween: Tween in tweens:
		if tween.is_valid():
			tween.custom_step(seconds)


static func _reduced_fades(fails: Array[String], tree: SceneTree, host: SubViewport,
		layer: TransitionLayer) -> void:
	Preferences.active.reduce_motion = true
	var root: Control = _screen(host)
	var before: Array[Tween] = tree.get_processed_tweens()
	layer.screen_in(root)
	_check(fails, root.modulate.a < 1.0,
		"under Reduce Motion a route still lands whole on its first frame (a hard cut)")
	var fade: Array[Tween] = _started(tree, before)
	_check(fails, fade.size() == 1, "under Reduce Motion the entrance started %d tweens, not one fade" % fade.size())
	_step(fade, LeadlightMotion.REDUCED_FADE * 0.5)
	_check(fails, absf(root.modulate.a - 0.5) < 0.05,
		"halfway through the Reduce Motion fade the screen is at %.2f, not a linear half" % root.modulate.a)
	_check(fails, root.scale == Vector2.ONE, "the Reduce Motion fade scales the screen")
	_step(fade, 0.16 - LeadlightMotion.REDUCED_FADE * 0.5)
	_check(fails, is_equal_approx(root.modulate.a, 1.0) and root.scale == Vector2.ONE,
		"the Reduce Motion fade is not whole by 0.16 s (alpha %.2f, scale %s)" % [
			root.modulate.a, root.scale])
	# A later entrance of the same root takes over; the earlier fade never writes again.
	var older: Array[Tween] = tree.get_processed_tweens()
	layer.screen_in(root)
	var newer: Array[Tween] = _started(tree, older)
	_step(newer, LeadlightMotion.REDUCED_FADE * 0.25)
	_check(fails, root.modulate.a < 0.5, "a second entrance of the same root did not restart its fade")
	root.queue_free()
	Preferences.active.reduce_motion = false


static func _full_entrance_unchanged(fails: Array[String], tree: SceneTree, host: SubViewport,
		layer: TransitionLayer) -> void:
	var root: Control = _screen(host)
	var before: Array[Tween] = tree.get_processed_tweens()
	layer.screen_in(root)
	_check(fails, root.modulate.a == 0.0, "the full entrance no longer starts from nothing")
	await tree.process_frame
	_check(fails, root.scale.x > 1.0, "the full entrance lost its 1.015 settle")
	_step(_started(tree, before), TransitionLayer.SCREEN_IN_TIME + 0.01)
	_check(fails, is_equal_approx(root.modulate.a, 1.0) and root.scale.is_equal_approx(Vector2.ONE),
		"the full entrance does not land whole after %.2f s" % TransitionLayer.SCREEN_IN_TIME)
	root.queue_free()


static func _instant_lands_whole(fails: Array[String], host: SubViewport, layer: TransitionLayer) -> void:
	layer.instant = true
	for reduced: bool in [false, true]:
		Preferences.active.reduce_motion = reduced
		var root: Control = _screen(host)
		layer.screen_in(root)
		_check(fails, root.modulate.a == 1.0, "a capture (instant) waits on an entrance (reduce motion %s)" % reduced)
		root.queue_free()
	Preferences.active.reduce_motion = false
	layer.instant = false
