extends RefCounted
## The map screen is kept between visits to one act (`MapScreenKeep`): a return
## to the map re-attaches the screen it left instead of building another, and
## shows exactly what a fresh screen would for the run's state. Anything that
## changes what the screen is built for (the map, the act, the run, the shape)
## builds a new one, and an ended run or a finished act frees what was kept.
## The stage's render buffers parked off the tree (`MapScene.PARKED_STAGE`) are
## measured by `tools/bench_map_open.gd`: the runner's tree is not live while
## suites run, so nothing here enters or leaves it.

const RUN_PATH: String = "user://test_map_keep_screen_run_v2.json"
const VIGIL_PATH: String = "user://test_map_keep_screen_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("map_keep_screen: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_reopen_reuses_the_screen_and_applies_the_delta(fails, content)
	_shape_and_act_changes_rebuild(fails, content)
	_ended_run_and_finished_act_free_it(fails, content)
	_resume_at_a_map_node(fails, content)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _reopen_reuses_the_screen_and_applies_the_delta(fails: Array[String],
		content: ContentDB) -> void:
	var main: Main = _map_main(content, 61001)
	var screen: WorldMapScreen = main._map_screen
	_check(fails, screen != null and screen.layout_result() != null, "the first map binds")
	if screen == null or screen.layout_result() == null:
		_dispose(main)
		return
	var id: int = screen.get_instance_id()
	_check(fails, main._hints.showing() == HintGuide.MAP_SELECT,
		"the first interactive map shows the map-select hint")
	var live: Array[int] = main._map.reachable()
	var i: int = live[0]
	# The pick records the hint; the quarantine keeps the route on the map.
	main._route_checkpoint_quarantined = true
	screen.instant = true
	_check(fails, screen.choose(i), "a live waystone can be picked")
	main._route_checkpoint_quarantined = false
	# A node the screen built unlit is drawn with another face once it is lit,
	# and one built lit can turn unlit only in a test, which proves the same.
	var far: int = _far_node(main._map, i)
	var near_ws: GlassWaystone = screen._waystones[i]
	var far_ws: GlassWaystone = screen._waystones[far]
	main._map.nodes[far].unlit = true
	main._map.nodes[far].bounty = 15
	# Leave for the node's route, then clear it as a won fight does.
	main._clear_route()
	_check(fails, main._map_keep.kept() == screen and screen.get_parent() == null,
		"leaving the map keeps its screen off the tree")
	main._map.clear_current()
	main.game.run.player.gold += 30
	main._show_map()
	var again: WorldMapScreen = main._map_screen
	_check(fails, again != null and again.get_instance_id() == id,
		"a return to the same act re-attaches the kept screen")
	_check(fails, main._map_keep.kept() == null and again.get_parent() == main,
		"the re-attached screen is the live one, not still kept")
	_check(fails, again._waystones[i].cleared and again._waystones[i].current,
		"the visited node shows visited and current")
	_check(fails, again._waystones[i] == near_ws,
		"a waystone whose face did not change is kept")
	_check(fails, again._waystones[far] != far_ws and not is_instance_valid(far_ws)
			and again._waystones[far].kind == "unlit" and again._waystones[far].bounty == 15,
		"a waystone whose node changed face is rebuilt with the new face")
	_check(fails, not again.instant, "a reopened screen walks again (instant is a boot's)")
	_check(fails, again.node_chosen.get_connections().size() == 1
			and again.sealed_door_requested.get_connections().size() == 1,
		"re-attaching connects nothing twice")
	_check(fails, main._run_hud != null and main._run_hud.get_parent() == main,
		"the run HUD comes back with the map")
	# Exactly what a fresh screen shows for the same state.
	var fresh: WorldMapScreen = WorldMapScreen.new(main._map, content, main._shape,
		main.game.run.act)
	fresh._layout_compile = main._compile_map_layout
	fresh.refresh(main.game.run)
	main._hints.consider_map(fresh)
	_check(fails, fresh.layout_digest() == again.layout_digest(),
		"the kept screen draws the layout a fresh one binds")
	_check(fails, _waystone_states(fresh) == _waystone_states(again),
		"every waystone is live, cleared and current as on a fresh screen")
	_check(fails, again._route_states() == fresh._route_states(),
		"the roads are lit as on a fresh screen")
	_check(fails, again._hint_label.visible == fresh._hint_label.visible
			and again._hint_label.text == fresh._hint_label.text,
		"the instruction reads as on a fresh screen")
	_check(fails, again._title_label.text == fresh._title_label.text
			and again._sealed_door.visible == fresh._sealed_door.visible,
		"the title and the sealed door read as on a fresh screen")
	_check(fails, again._map_scene.get_rig().camera_xz().is_equal_approx(
			fresh._map_scene.get_rig().camera_xz())
			and again._map_scene.get_rig().zoom_stop == MapCameraRig.DEFAULT_STOP,
		"the camera sits on the current node at the default zoom")
	fresh.free()
	_dispose(main)


static func _shape_and_act_changes_rebuild(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, 61002)
	var first: WorldMapScreen = main._map_screen
	main._clear_route()
	main._shape = &"phone-landscape"
	main._show_map()
	_check(fails, main._map_screen != first and first.is_queued_for_deletion(),
		"a shape change builds a new screen and frees the kept one")
	var phone: WorldMapScreen = main._map_screen
	main._clear_route()
	_check(fails, main._map_keep.kept() == phone, "the phone screen is kept in turn")
	# The act change `_on_boss_relic_chosen` makes: a new map for the next act.
	main.game.run.start_next_act(content)
	main._map = WorldMap.for_run(main.game.run, content)
	_check(fails, main._map_keep.kept() == null and phone.is_queued_for_deletion(),
		"replacing the map frees the screen kept for the old one")
	main.game.quests.decorate_map(main.game.run, main._map)
	main.game.run.map = main._map.to_dict()
	main._show_map()
	_check(fails, main._map_screen != null and main._map_screen != phone
			and main._map_screen._act == main.game.run.act,
		"the next act's map is built for that act")
	_dispose(main)
	# A screen that followed a shape re-pick while live is kept for the shape it
	# now has, so a return under the shape it was built for builds anew.
	var turned: Main = _map_main(content, 61005)
	var built_pad: WorldMapScreen = turned._map_screen
	turned._shape = &"phone-landscape"
	turned._reshape()
	turned._clear_route()
	turned._shape = &"pad-landscape"
	turned._show_map()
	_check(fails, turned._map_screen != built_pad and built_pad.is_queued_for_deletion()
			and turned._map_screen.shape == &"pad-landscape",
		"a screen re-picked to another shape is not shown under its first one")
	_dispose(turned)


static func _ended_run_and_finished_act_free_it(fails: Array[String],
		content: ContentDB) -> void:
	var main: Main = _map_main(content, 61003)
	var first: WorldMapScreen = main._map_screen
	main._clear_route()
	_check(fails, main._map_keep.kept() == first, "the map is kept while the run goes on")
	# A boss win routes with the run standing on the boss: the next map is the
	# next act's, so this act's screen (and its artwork) goes now.
	var boss: int = -1
	for n: int in range(main._map.nodes.size()):
		if main._map.nodes[n].type == "boss":
			boss = n
	main._map.at = boss
	main._warm_map_landscape()
	MapLandscapeAssets.release()
	_check(fails, main._map_keep.kept() == null and first.is_queued_for_deletion(),
		"standing on the boss frees the kept screen")
	main._map.at = -1
	main._show_map()
	var second: WorldMapScreen = main._map_screen
	# Leaving the map with the run over (the run menu's abandon) frees it outright.
	main.game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	main._clear_route()
	_check(fails, main._map_keep.kept() == null and second.is_queued_for_deletion(),
		"a map left by an ended run is not kept")
	main.game.run.pending_run_end = null
	main._show_map()
	var third: WorldMapScreen = main._map_screen
	main._clear_route()
	_check(fails, main._map_keep.kept() == third, "kept again once the run goes on")
	# A death routes the run to its end.
	main.game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	main._route_run()
	_check(fails, main._map_keep.kept() == null and third.is_queued_for_deletion(),
		"routing an ended run frees the kept screen")
	# The run menu's abandon from a fight shows the run's end directly, with the
	# map already kept and no map screen live.
	main.game.run.pending_run_end = null
	main._show_map()
	var fourth: WorldMapScreen = main._map_screen
	main._clear_route()
	_check(fails, main._map_keep.kept() == fourth, "kept while a fight is up")
	main.game.run.pending_run_end = {"outcome": "abandon", "bequestAnswered": true}
	main._show_run_end()
	_check(fails, main._map_keep.kept() == null and fourth.is_queued_for_deletion(),
		"showing the run's end frees the map kept for it")
	_dispose(main)


static func _resume_at_a_map_node(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, 61004)
	var first: WorldMapScreen = main._map_screen
	var i: int = main._map.reachable()[0]
	main._map.enter(i)
	main._map.clear_current()
	main.game.run.node_id = main._map.nodes[i].id
	main.game.run.map = main._map.to_dict()
	_check(fails, main._store_run(), "the run stores at a cleared map node")
	main._clear_route()
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, loaded != null, "the stored run loads")
	if loaded == null:
		_dispose(main)
		return
	main._continue_run(loaded)
	var resumed: WorldMapScreen = main._map_screen
	_check(fails, first.is_queued_for_deletion() and main._map_keep.kept() == null,
		"resuming frees the screen kept for the run before")
	_check(fails, resumed != null and resumed != first and resumed.layout_result() != null,
		"a resume at a map node opens a freshly bound map")
	if resumed != null:
		_check(fails, resumed.map.at == i and resumed._waystones[i].current
				and resumed._waystones[i].cleared,
			"the resumed map stands on the saved node")
	_dispose(main)


static func _waystone_states(screen: WorldMapScreen) -> Array:
	var out: Array = []
	for ws: GlassWaystone in screen._waystones:
		out.append([ws.kind, ws.reachable, ws.cleared, ws.current, ws.bounty])
	return out


## A node in the last row before the boss, far from `near`.
static func _far_node(world: WorldMap, near: int) -> int:
	var best: int = -1
	for n: int in range(world.nodes.size()):
		if n != near and world.nodes[n].type != "boss" \
				and (best < 0 or world.nodes[n].row > world.nodes[best].row):
			best = n
	return best


static func _map_main(content: ContentDB, seed: int) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._forced_seed = seed
	main._vigil.scenes_seen.append("opening")
	main._new_run()
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
