extends RefCounted
## One ground and no cuts (docs/design/2026-10-03-title-rooms §2.7, §2.8, §11.1).
## Any gap between two screens is the night, never the engine's 0.3 grey: the
## project's clear colour is VOID, so a route that fades in comes up out of it.
## Under Reduce Motion every change of screen is a 150 ms linear cross-fade,
## never the hard cut it was, nor a cut to the night and a fade up: the frame
## on screen before the change is copied and laid over the new screen, which
## stands whole beneath it, and fades out; a room, a confirm or the run menu
## cross-fades with the screen it opens over the same way. A long frame (a
## route built on the tap) cannot spend the fade unseen, and the screen that
## left is freed at once, as under full motion, so it can route nothing. The
## real copy needs a renderer (the stills prove it, `sequence-gates.txt`); here
## a texture stands in for it. Without Reduce Motion the 0.45 s entrance with
## its 1.015 settle is unchanged. The fades need nodes inside a tree, so that
## half runs in `TreeSuite`.

const SUITE: String = "res://tests/test_transition_rm.gd"
const CLEAR_COLOUR: String = "rendering/environment/defaults/default_clear_color"
const RUN_PATH: String = "user://test_transition_rm_run_v2.json"
const VIGIL_PATH: String = "user://test_transition_rm_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


## Main without its boot (see test_focus_modality).
class QuietMain extends Main:
	func _ready() -> void:
		pass


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("transition_rm: %s" % what)


static func run(fails: Array[String]) -> void:
	_ground_is_the_night(fails)
	TreeSuite.spawn(fails, SUITE)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


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
	_reduced_fades(fails, host, layer)
	_cross_fades(fails, host, layer)
	await _full_entrance_unchanged(fails, tree, host, layer)
	_instant_lands_whole(fails, host, layer)
	layer.queue_free()
	await _main_under_reduce_motion(fails, tree, host)
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


## The Reduce Motion fades through `seconds` of 60 fps frames.
static func _frames(layer: TransitionLayer, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		layer.advance_fades(minf(left, 1.0 / 60.0))
		left -= 1.0 / 60.0


## Nothing leaving: an entrance fades up from the night, linearly, at full
## scale, and a long frame moves it no more than one frame's worth.
static func _reduced_fades(fails: Array[String], host: SubViewport, layer: TransitionLayer) -> void:
	Preferences.active.reduce_motion = true
	var root: Control = _screen(host)
	layer.screen_in(root)
	_check(fails, root.modulate.a < 0.01,
		"under Reduce Motion, with nothing leaving, a route lands whole on its first frame (a hard cut)")
	layer.advance_fades(0.5)
	_check(fails, absf(root.modulate.a - 1.0 / 9.0) < 0.01,
		"a long frame (a route built on the tap) spent %.2f of the fade at once" % root.modulate.a)
	_frames(layer, LeadlightMotion.REDUCED_FADE * 0.5 - 1.0 / 60.0)
	_check(fails, absf(root.modulate.a - 0.5) < 0.06,
		"halfway through the Reduce Motion fade the screen is at %.2f, not a linear half" % root.modulate.a)
	_check(fails, root.scale == Vector2.ONE, "the Reduce Motion fade scales the screen")
	_frames(layer, 0.16 - LeadlightMotion.REDUCED_FADE * 0.5)
	_check(fails, is_equal_approx(root.modulate.a, 1.0) and root.scale == Vector2.ONE,
		"the Reduce Motion fade is not whole by 0.16 s (alpha %.2f, scale %s)" % [
			root.modulate.a, root.scale])
	# A later entrance of the same root takes over; the earlier fade never writes again.
	layer.screen_in(root)
	_frames(layer, LeadlightMotion.REDUCED_FADE * 0.25)
	_check(fails, root.modulate.a < 0.5, "a second entrance of the same root did not restart its fade")
	_frames(layer, 0.2)
	root.queue_free()
	Preferences.active.reduce_motion = false


## A change of screen: the frame before it lies over the new screen, which
## stands whole beneath it from the first frame, and fades out linearly, a
## ninth a frame at most; one copy serves every change on the same frame; the
## copy is let go once it has faded.
static func _cross_fades(fails: Array[String], host: SubViewport, layer: TransitionLayer) -> void:
	var copies: Array[int] = [0]
	layer.snapshot_source = func() -> Texture2D:
		copies[0] += 1
		return ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	_check(fails, not layer.cross_fade() and not layer.cross_fading(),
		"under full motion a change of screen cross-fades instead of going at once, as shipped")
	Preferences.active.reduce_motion = true
	_check(fails, layer.cross_fade() and layer.cross_fading(),
		"under Reduce Motion a change of screen does not cross-fade (a cut)")
	_check(fails, layer.cross_fade() and copies[0] == 1,
		"a second change on the same frame copied the frame again (%d copies)" % copies[0])
	var snapshot: TextureRect = layer._snapshot
	_check(fails, snapshot.get_index() == 0,
		"the copy is not under the transition leaves (the wipe, the flood and the grain draw over it)")
	var arriving: Control = _screen(host)
	layer.screen_in(arriving)
	_check(fails, arriving.modulate.a == 1.0 and snapshot.modulate.a == 1.0,
		"the arriving screen does not stand whole beneath the frame it replaces (the change dips to the night)")
	layer.advance_fades(0.5)
	_check(fails, absf(snapshot.modulate.a - 8.0 / 9.0) < 0.01,
		"a long frame (a route built on the tap) moved the cross-fade to %.2f, more than a ninth" % snapshot.modulate.a)
	_frames(layer, 0.16)
	_check(fails, not layer.cross_fading() and snapshot.texture == null,
		"the copy is not let go once it has faded")
	arriving.queue_free()
	layer.snapshot_source = Callable()
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
		_check(fails, not layer.cross_fade(), "a capture (instant) waits on a cross-fade (reduce motion %s)" % reduced)
		root.queue_free()
	Preferences.active.reduce_motion = false
	layer.instant = false


## Main under Reduce Motion: Settings (a room) opening and closing over the
## title, the Vigil (a route), a route with no entrance of its own (a death,
## a fight) and the map leaving for a fight each cross-fade from the frame
## before; the screen that left is gone at once, and the map is kept.
static func _main_under_reduce_motion(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var main: Main = await _boot(tree, host)
	var layer: TransitionLayer = main._transitions
	var copies: Array[int] = [0]
	layer.snapshot_source = func() -> Texture2D:
		copies[0] += 1
		return ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	Preferences.active.reduce_motion = true
	var title: Control = main._choice_screen
	main._show_settings()
	var panel: Control = main._modal
	_check(fails, copies[0] == 1 and layer.cross_fading() and panel != null and panel.modulate.a == 1.0,
		"Settings lands over the title in one frame (a cut), or not whole under the cross-fade")
	await _next(tree, layer)
	main._close_overlay()
	_check(fails, copies[0] == 2 and layer.cross_fading() and main._modal == null
			and panel.is_queued_for_deletion() and title.modulate.a > 0.99,
		"Settings leaves in one frame (a cut), or lingers after it is closed")
	await _next(tree, layer)
	main._show_vigil()
	var vigil: Control = main._route_screen
	_check(fails, copies[0] == 3 and vigil != null and vigil.modulate.a == 1.0
			and title.is_queued_for_deletion(),
		"the Vigil does not arrive whole under a cross-fade from the title")
	await _next(tree, layer)
	var death: Control = Control.new()
	main._show_route(death, false, &"", false)
	_check(fails, copies[0] == 4 and layer.cross_fading() and death.modulate.a == 1.0,
		"a route with no entrance of its own (a death) still cuts in")
	await _next(tree, layer)
	main._new_run()
	if main._route_screen is DepartureScreen:
		var offer: Dictionary = main.game.run.quest_scratch["lamplighterOffer"]
		main._on_lamplighter_confirmed(str(offer["boons"][0]), main.game.run.art)
	if main._map_screen == null:
		main._show_map()
	await _next(tree, layer)
	var map: WorldMapScreen = main._map_screen
	_check(fails, map != null, "a new run did not reach the map")
	if map != null:
		var before: int = copies[0]
		main._clear_route()
		_check(fails, copies[0] == before + 1 and layer.cross_fading() and main._map_keep.kept() == map,
			"the map leaving for a fight does not cross-fade, or is not kept for its next visit")
	await _next(tree, layer)
	layer.snapshot_source = Callable()
	Preferences.active.reduce_motion = false
	main._clear_route()
	main.get_parent().remove_child(main)
	main.queue_free()


## The cross-fade through, then the next frame: one copy a frame.
static func _next(tree: SceneTree, layer: TransitionLayer) -> void:
	_frames(layer, 0.16)
	await tree.process_frame


static func _boot(tree: SceneTree, host: SubViewport) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = QuietMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = ContentDB.load_full()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._vigil.scenes_seen.append("opening")
	host.add_child(main)
	main._title_kindled = true
	main._show_title()
	# The title's own entrance lands before anything is asked of it.
	await tree.create_timer(TransitionLayer.SCREEN_IN_TIME + 0.1).timeout
	await tree.process_frame
	return main
