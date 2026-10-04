extends RefCounted
## The road is never torn down for the Vigil (docs/design/2026-10-03-title-
## rooms §2.1, §5, §9 item 2, §11.1; #655). Through Main as a tap delivers it,
## in a real tree, the passage stepped by hand at 60 fps:
##
## - the title's Vigil word turns west into the hall (V1): the hall is the
##   route on the tap frame, the title held under it (the same instance, out of
##   `_choice_screen`), lent to the seat; once the hall lands the title's road
##   is hidden and its clock stops;
## - its Return turns east (V3): the same title comes back on that frame, its
##   road going on from where it stopped, the hall left to the passage, the
##   word that opened it holding the focus; the music is `vigil`, then `title`;
## - the title's rose opens the hall on the Rose look, held, `roseWindow`;
## - every other entry (the dev scenario's call, a run's sealed door) is the
##   route alone, its seat the word with no lantern, and its Return builds the
##   title beneath the hall lifted off it (V9);
## - every other route change frees the held title; `_reshape` reaches it; it
##   takes no key while held;
## - the departure's Back lifts the departure off a title built beneath it (X2),
##   and a screen being lifted counts as one of the transitions' leaves, so
##   over the map their grain covers it (#674);
## - a language or shape change while the rooms' warm runs is warmed after it
##   (#670 review follow-up 1: before, the new key was dropped for the launch),
##   and the warm waits while the map's prefetch is still working (follow-up 3);
## - once the title has rested with the hall's art in hand and its rooms
##   warmed, the hall its Vigil word opens is built ahead on the tree, hidden
##   and still, and the word shows that same hall; a shape change or a route
##   change lets it go, and the rose's entry builds its own;
## - the title's track resumes where it stopped; a fight's never does.
##
## V2′ (the door's rose flying into the window after the unsealing) is cut
## (§13's first cut), so nothing here can run it.

const SUITE: String = "res://tests/test_vigil_hold.gd"
const RUN_PATH: String = "user://test_vigil_hold_run_v2.json"
const VIGIL_PATH: String = "user://test_vigil_hold_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const STEP: float = 1.0 / 60.0


class QuietMain extends Main:
	func _ready() -> void:
		pass


## Every cue asked for, in order.
class SpyMusic extends MusicBus:
	var heard: Array[StringName] = []

	func play(cue: StringName, context: StringName = &"") -> void:
		heard.append(cue)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("vigil_hold: %s" % what)


static func run(fails: Array[String]) -> void:
	_music_resumes(fails)
	_lift_fades(fails)
	TreeSuite.spawn(fails, SUITE)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## Where a cue starts: the title's, the Vigil's and the Rose Window's resume
## where they stopped this session; a fight's starts from its top.
static func _music_resumes(fails: Array[String]) -> void:
	var at: Dictionary = {"title": 41.5, "act1-combat": 12.0}
	_check(fails, is_equal_approx(MusicBus.resume_at(at, &"title", "title", 180.0), 41.5),
		"the title's track does not resume where it stopped")
	_check(fails, is_equal_approx(MusicBus.resume_at(at, &"title", "title", 30.0), 11.5),
		"a resumed track does not wrap round its loop")
	_check(fails, MusicBus.resume_at(at, &"act1Combat", "act1-combat", 180.0) == 0.0,
		"a fight's track resumed instead of starting from its top")
	_check(fails, MusicBus.resume_at({}, &"vigil", "vigil", 180.0) == 0.0,
		"a track never played resumed from somewhere")


## A lifted screen fades from its first frame and is freed at its end.
static func _lift_fades(fails: Array[String]) -> void:
	var layer: TransitionLayer = TransitionLayer.new()
	var screen: Control = Control.new()
	layer._lifts[screen] = {"t": 0.0, "time": TransitionLayer.LIFT_TIME}
	layer.advance_lifts(STEP)
	_check(fails, screen.modulate.a < 0.95 and screen.modulate.a > 0.0,
		"a lifted screen does not answer on its first frame (%.3f)" % screen.modulate.a)
	# A lifted screen is a leaf crossing whatever is under it: over the map,
	# the layer's grain covers the screen while it goes (#674's rule).
	_check(fails, layer.leaves_showing(), "a screen being lifted is not one of the layer's leaves")
	layer.advance_lifts(TransitionLayer.LIFT_TIME)
	_check(fails, screen.is_queued_for_deletion() and not layer.lifting() and not layer.leaves_showing(),
		"a lifted screen is not freed at its end")
	layer.free()


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = String(Locale.CODE_EN)
	Preferences.active.diagnostics_notice_seen = true
	var content: ContentDB = ContentDB.load_full()
	await _round_trip(fails, tree, host, content)
	await _rose_entry(fails, tree, host, content)
	await _route_forms(fails, tree, host, content)
	await _other_routes_free_it(fails, tree, host, content)
	await _departure_lifts(fails, tree, host, content)
	await _warm_requeued(fails, tree, host, content)
	await _warm_waits_for_the_map(fails, tree, host, content)
	await _hall_built_ahead(fails, tree, host, content)
	Preferences.active = kept


## V1 and V3, the title held between them.
static func _round_trip(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var music: SpyMusic = main._music as SpyMusic
	var title: TitleScreen = _title(main)
	music.heard.clear()
	await _tap(tree, host, title.word("vigil"))
	_check(fails, main._route_screen is VigilScreen and main._held_title == title
			and main._choice_screen == null and title.lent() and main._passage.arriving(),
		"the Vigil word did not turn west into the hall over the held title")
	_check(fails, music.heard == [&"vigil"], "the hall's first cue is %s, not vigil" % [music.heard])
	await _step(tree, main, ceili(0.6 / STEP) + 2)
	_check(fails, not main._passage.arriving() and title.held() and not title.world.visible
			and title.world.process_mode == Node.PROCESS_MODE_DISABLED,
		"the landed hall does not hold the title's road (hidden, still)")
	var stopped: float = title.world._time
	await _frames(tree, 6)
	_check(fails, is_equal_approx(title.world._time, stopped), "the held road's clock runs on under the hall")
	# The held title takes no key: Tab reaches nothing of it.
	await _key(tree, host, KEY_TAB)
	var owner: Control = host.gui_get_focus_owner()
	_check(fails, owner == null or not title.is_ancestor_of(owner),
		"a key reached the held title (%s)" % [owner.get_path() if owner != null else ""])
	main._shape = &"phone-landscape"
	main._reshape()
	_check(fails, title.shape == &"phone-landscape", "_reshape does not reach the held title")
	main._shape = &"pad-landscape"
	main._reshape()
	var vigil: VigilScreen = main._route_screen as VigilScreen
	music.heard.clear()
	await _tap(tree, host, vigil.seat().word())
	_check(fails, main._choice_screen == title and main._held_title == null and main._route_screen == null
			and not title.held() and title.world.visible,
		"Return did not bring the same title back on its frame")
	_check(fails, main._passage.leaving() and vigil.left(), "the hall did not leave through the passage")
	_check(fails, music.heard == [&"title"], "turning back asked for %s, not the title's track" % [music.heard])
	await _step(tree, main, ceili(0.48 / STEP) + 2)
	_check(fails, title.world._time > stopped and title.world._time < stopped + 1.0,
		"the road did not go on from where it stopped (%.3f from %.3f)" % [title.world._time, stopped])
	_check(fails, not is_instance_valid(vigil) or vigil.is_queued_for_deletion() or vigil.get_parent() == null,
		"the hall was not freed once it had gone")
	_check(fails, title.word("vigil").has_focus() and not title.word("vigil").has_focus(true),
		"the Vigil word does not hold the focus back, hidden, after a tapped Return")
	_check(fails, is_zero_approx(title.world.pan_px) and is_equal_approx(title.rose.modulate.a, 1.0),
		"the road did not turn all the way back")
	_dispose(main)


## The title's rose opens the hall on the Rose look, the title held.
static func _rose_entry(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var music: SpyMusic = main._music as SpyMusic
	var title: TitleScreen = _title(main)
	music.heard.clear()
	main._on_title_pick("rose", title, null)
	var vigil: VigilScreen = main._route_screen as VigilScreen
	_check(fails, vigil != null and vigil.look() == VigilHall.ROSE and main._held_title == title,
		"the rose did not open the hall on the Rose look over the held title")
	_check(fails, music.heard == [&"roseWindow"], "the rose's hall first asked for %s" % [music.heard])
	_dispose(main)


## The dev scenario's call and a run's sealed door: the route alone.
static func _route_forms(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	main._show_vigil()
	var vigil: VigilScreen = main._route_screen as VigilScreen
	_check(fails, vigil != null and main._held_title == null and title.is_queued_for_deletion(),
		"the dev scenario's Vigil held a title it did not open from")
	if vigil != null:
		_check(fails, not vigil.seat().lantern_hit().visible and vigil.seat().word().visible,
			"the route-form hall's seat is not the word alone")
		await _frames(tree, 2)
		await _tap(tree, host, vigil.seat().word())
		_check(fails, main._choice_screen is TitleScreen and main._choice_screen != title
				and main._route_screen == null,
			"the route-form hall's Return did not build the title beneath it")
		_check(fails, not is_instance_valid(vigil) or vigil.is_queued_for_deletion() or vigil.get_parent() != main,
			"the route-form hall was not lifted off the title")
	_dispose(main)
	main = await _boot(tree, host, content)
	var run: RunState = RunState.new_run(content, 65702, "hold-run")
	run.map = WorldMap.benchmark(run).to_dict()
	main.game = GlassvowGame.new(content, run)
	main._map = WorldMap.from_dict(run.map)
	main._show_vigil()
	_check(fails, main._route_screen is VigilScreen and main._held_title == null,
		"the Vigil opened in a run is not the route alone")
	main.game = null
	_dispose(main)


## A route change frees the held title.
static func _other_routes_free_it(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	main._on_title_pick("vigil", title, null)
	_check(fails, main._held_title == title, "the title was not held")
	main._show_route(Control.new(), false, &"", false)
	_check(fails, main._held_title == null and title.is_queued_for_deletion(),
		"a route change left the held title alive")
	_dispose(main)


## X2: the departure's Back lifts it off a title built beneath it.
static func _departure_lifts(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	main._show_embark()
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	_check(fails, departure != null, "the departure did not open")
	if departure != null:
		departure.back_requested.emit()
		_check(fails, main._choice_screen is TitleScreen and main._route_screen == null
				and departure.get_parent() != main,
			"the departure's Back did not lift it off a title built beneath it")
	_dispose(main)


## #670 follow-up 1: a shape (or a language) changed while the rooms' warm
## runs is warmed once that warm is done, never dropped for the launch.
static func _warm_requeued(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, false)
	var first: RoomWarm = main._room_warm
	_check(fails, first != null and main._rooms_warmed.has("en|pad-landscape"), "the title did not warm its rooms")
	# Every builder up front (#675's follow-up): the three rooms, the hall and
	# its window, and the hall's pipelines, from the warm's first frame.
	_check(fails, first != null and first._builders.size() == 5 and first._pipelines.size() == 1,
		"the title's warm was not given every room's builder up front")
	main._shape = &"phone-landscape"
	main._warm_rooms()
	_check(fails, main._room_warm == first and not main._rooms_warmed.has("en|phone-landscape"),
		"a second warm ran over the first")
	first.queue_free()
	await _frames(tree, 3)
	_check(fails, main._room_warm != null and is_instance_valid(main._room_warm) and main._room_warm != first
			and main._rooms_warmed.has("en|phone-landscape"),
		"the shape changed during the warm was never warmed")
	if main._room_warm != null and is_instance_valid(main._room_warm):
		main._room_warm.queue_free()
	main._shape = &"pad-landscape"
	_dispose(main)


## #670 follow-up 3: the rooms' warm never works in the same frames as the
## map's prefetch.
static func _warm_waits_for_the_map(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	_check(fails, main._warm_may_run(), "the warm may not run on a title at rest")
	var run: RunState = RunState.new_run(content, 65703, "hold-prefetch")
	run.map = WorldMap.benchmark(run).to_dict()
	MapJourneyPrefetch.start(WorldMap.from_dict(run.map), run)
	_check(fails, MapJourneyPrefetch.busy() and not main._warm_may_run(),
		"the rooms' warm may run while the map's prefetch works")
	MapJourneyPrefetch.release()
	_check(fails, main._warm_may_run(), "the warm stays held once the map's prefetch is let go")
	_dispose(main)


## The hall built ahead: only on a title at rest with the art in hand and the
## rooms' warm done; hidden and still on the tree; shown by the Vigil word as
## the route itself; let go by a shape change and by a route change.
static func _hall_built_ahead(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	main._warm_headless = false
	main._vigil_art = {"res://stand-in": true}
	main._room_warm = RoomWarm.new([], func() -> bool: return false)
	main.add_child(main._room_warm)
	main._build_vigil_ahead(RoomWarm.REST)
	_check(fails, main._vigil_ahead == null, "the hall was built ahead while the rooms' warm still ran")
	main._room_warm.free()
	main._room_warm = null
	main._build_vigil_ahead(RoomWarm.REST * 0.5)
	_check(fails, main._vigil_ahead == null, "the hall was built ahead before the title had rested")
	main._build_vigil_ahead(RoomWarm.REST * 0.5)
	var ahead: VigilScreen = main._vigil_ahead
	_check(fails, ahead != null and ahead.get_parent() == main and not ahead.visible
			and ahead.process_mode == Node.PROCESS_MODE_DISABLED and main._route_screen == null,
		"the rested title did not build its hall ahead, hidden and still, on the tree")
	var title: TitleScreen = _title(main)
	await _tap(tree, host, title.word("vigil"))
	_check(fails, main._route_screen == ahead and ahead.visible
			and ahead.process_mode == Node.PROCESS_MODE_INHERIT and main._vigil_ahead == null
			and main._held_title == title and main._passage.arriving(),
		"the Vigil word did not show the hall built ahead as its route")
	await _step(tree, main, ceili(0.6 / STEP) + 2)
	await _tap(tree, host, ahead.seat().word())
	await _step(tree, main, ceili(0.48 / STEP) + 2)
	main._build_vigil_ahead(RoomWarm.REST)
	var again: VigilScreen = main._vigil_ahead
	_check(fails, again != null and again != ahead, "no hall was built ahead again once the title rested")
	main._shape = &"phone-landscape"
	main._build_vigil_ahead(0.0)
	_check(fails, main._vigil_ahead == null and again.is_queued_for_deletion(),
		"a hall built for another shape was kept")
	main._shape = &"pad-landscape"
	main._build_vigil_ahead(RoomWarm.REST)
	var held: VigilScreen = main._vigil_ahead
	main._on_title_pick("rose", title, null)
	_check(fails, main._route_screen != held and (main._route_screen as VigilScreen).look() == VigilHall.ROSE,
		"the rose's entry took the hall built for the Deeds look")
	main._clear_route()
	_check(fails, main._vigil_ahead == null and held.is_queued_for_deletion(),
		"a route change did not let the hall built ahead go")
	main._vigil_art = {}
	_dispose(main)


# ---------------------------------------------------------------- the stage

static func _boot(tree: SceneTree, host: SubViewport, content: ContentDB, headless_warm: bool = true) -> Main:
	LeadlightFocus.keyed = false
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = QuietMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._warm_headless = headless_warm
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._music = SpyMusic.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._vigil.scenes_seen.append("opening")
	main._vigil.unlocks.append("emberglass")
	main._vigil.shards.append("paleOnes")
	main._vigil.quests["paleOnes"] = {"state": "complete", "progress": 9, "memory": {}}
	host.add_child(main)
	main._title_kindled = true
	main._passage_node().stepped = true
	main._show_title()
	main._passage.set_process(false)
	await _frames(tree, 3)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	main.get_parent().remove_child(main)
	main.queue_free()


static func _title(main: Main) -> TitleScreen:
	return main._choice_screen as TitleScreen


static func _step(tree: SceneTree, main: Main, count: int) -> void:
	for _i: int in range(maxi(count, 0)):
		main._passage.advance(STEP)
		await tree.process_frame


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame


## A finger down and up in one frame, as a quick tap arrives.
static func _tap(tree: SceneTree, host: SubViewport, control: Control) -> void:
	if control == null:
		return
	var at: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	host.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = at
		event.global_position = at
		host.push_input(event, true)
	await tree.process_frame
	await tree.create_timer(LeadlightMotion.TICK + 0.05).timeout


static func _key(tree: SceneTree, host: SubViewport, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		host.push_input(event)
	await tree.process_frame
