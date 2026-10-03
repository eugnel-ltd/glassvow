extends RefCounted
## #660: Back to the Road opens a drawn map. From the launch rite's first frame
## the title warms the saved run's Act I land on the worker pool (the kit held
## while the pictures decode), and Continue's restore adopts it without a second
## build, with the same layout a cold open binds, also when the tap comes before
## the warm-up has ended: a map that opens mid-build takes the layout the
## worker has already made, and the flare and flood play over a paced build. The
## warm land is keyed by what it is built from: another save is never given it,
## and Begin Anew and Erase Everything let it go, stopping a build in flight; a
## language change keeps it, on the title and on the map, since the land holds
## no words. The warm-up reads nothing back from the renderer, so its cards and
## kit are checked against the renderer's own: and a headless boot warms
## nothing and still builds inline.

const RUN_PATH: String = "user://test_map_title_road_run_v2.json"
const VIGIL_PATH: String = "user://test_map_title_road_vigil_v2.json"
const SEED_A: int = 6601
const SEED_B: int = 6602
const SEED_C: int = 6603
const SETTLE_MS: int = 120000
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_title_road: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Locale.active = Locale.new(Locale.CODE_EN)
	Preferences.active = Preferences.new()
	var content: ContentDB = ContentDB.load_full()
	_cards_are_the_renderers(fails)
	_kit_templates_are_the_scenes(fails)
	_headless_builds_inline(fails, content)
	var reference: Dictionary = _cold_reference(content, SEED_A)
	MapScene.journey_async = true
	var warm_heights: PackedFloat32Array = _title_warms_and_continue_adopts(fails, content,
		reference)
	_early_continue_adopts_the_build(fails, content, reference, warm_heights)
	_map_opened_mid_build_takes_the_layout(fails, content)
	MapScene.journey_async = false
	_release_all()
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	Locale.active = previous_locale
	Preferences.active = previous_preferences


## The catalogue builds each card on the CPU; it must be the card the renderer
## made from a `QuadMesh`, and every act's catalogue keeps its digest.
static func _cards_are_the_renderers(fails: Array[String]) -> void:
	var tilt: Transform3D = Transform3D(Basis(Vector3.RIGHT,
		deg_to_rad(MapCameraRig.TILT_DEGREES)), Vector3.ZERO)
	var same: bool = true
	for height: float in [0.85, 2.3, 3.6, 4.4, 4.5, 5.6, 5.8]:
		for pixels: Vector2i in [Vector2i(97, 333), Vector2i(512, 640), Vector2i(1500, 1024),
				Vector2i(2048, 128), Vector2i(777, 2048)]:
			var size: Vector2 = Vector2(height * float(pixels.x) / pixels.y, height)
			var quad: QuadMesh = QuadMesh.new()
			quad.size = size
			quad.center_offset = Vector3(0, height * 0.5, 0)
			var surface: SurfaceTool = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.append_from(quad, 0, tilt)
			var renderer: Array = surface.commit_to_arrays()
			var cpu: Array = MapLandscapeAssets.card_arrays(size, Vector3(0, height * 0.5, 0))
			same = same and renderer == cpu
	_check(fails, same, "a card built on the CPU is the renderer's QuadMesh card, array for array")
	for act: int in range(4):
		var catalogue: MapLandscapeAssets = MapLandscapeAssets.new(act)
		var faces_same: bool = catalogue.failure.is_empty()
		for id: String in catalogue.meshes:
			var mesh: Mesh = catalogue.meshes[id]
			var profile: Dictionary = catalogue.profiles[id]
			faces_same = faces_same and catalogue.registry.profile(id, mesh) == profile
		_check(fails, faces_same,
			"act %d's profiles are those of its uploaded meshes" % act)


## The kit's templates take their own copies' meshes instead of duplicating the
## cached ones: the same arrays, given the prepared materials.
static func _kit_templates_are_the_scenes(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	var statics: GDScript = load("res://presentation/map/landscape/static_scenery.gd")
	var shared: Dictionary = statics.get("_shared")
	var same: bool = shared.size() == MapJourneyLandscape.Kit.PROFILES.size() - 1
	for path: String in shared:
		var parts: Array = shared[path]["parts"]
		var cached: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		var meshes: Array[Mesh] = []
		_drawn_meshes(cached, meshes)
		cached.free()
		same = same and meshes.size() == parts.size()
		for index: int in range(mini(meshes.size(), parts.size())):
			var part: Mesh = parts[index]["mesh"]
			same = same and part != meshes[index] \
				and part.get_surface_count() == meshes[index].get_surface_count()
			for surface: int in range(part.get_surface_count()):
				var arrays: Array = part.surface_get_arrays(surface)
				same = same and not arrays.is_empty() \
					and arrays == meshes[index].surface_get_arrays(surface) \
					and part.surface_get_material(surface) != null
	_check(fails, same, "each kit template draws its scene's meshes with the prepared materials")


## The meshes a template collects from a scene: every mesh instance whose
## branch is visible, in tree order.
static func _drawn_meshes(node: Node, out: Array[Mesh]) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D:
		out.append((node as MeshInstance3D).mesh)
	for child: Node in node.get_children():
		_drawn_meshes(child, out)


## Headless (tests, tools) has no frames to wait through: nothing warms on the
## title, and Continue builds the land inline.
static func _headless_builds_inline(fails: Array[String], content: ContentDB) -> void:
	_release_all()
	_check(fails, not MapScene.journey_async, "a headless run builds the journey land inline")
	var main: Main = _main(content)
	var saved: RunState = _store_run(content, SEED_A)
	main._title_kindled = true
	main._show_title()
	main._process(0.016)
	_check(fails, MapJourneyPrefetch.current_step() == -1 and MapScene._journey_kept == null
			and MapLandscapeAssets.warming() == null and MapLandscapeAssets._kept == null,
		"a headless title warms nothing, not even the act's pictures")
	main._on_title_choice("continue", saved)
	var screen: WorldMapScreen = main._map_screen
	_check(fails, screen != null and not screen.landscape_pending()
			and screen._map_scene.journey_landscape() != null
			and screen._map_scene.journey_landscape().is_built(),
		"a headless Continue builds the land inline")
	_dispose(main)


## The layout and binding a cold open makes for `run_seed`'s saved run.
static func _cold_reference(content: ContentDB, run_seed: int) -> Dictionary:
	_release_all()
	var main: Main = _main(content)
	_store_run(content, run_seed)
	main._title_kindled = true
	main._show_title()
	# Continue restores the run as the title read it from the save.
	main._on_title_choice("continue", main._load_run())
	var screen: WorldMapScreen = main._map_screen
	var out: Dictionary = {}
	if screen != null:
		out = {"layout": screen.layout_digest(), "input": screen.layout_input_digest(),
			"binding": screen.layout_diagnostics().get("live_binding", {})}
	_dispose(main)
	_release_all()
	return out


## The title's warm-up, adopted by Continue, kept and let go; returns the warm
## land's heights, worked out on a few of the pool's threads under the title.
static func _title_warms_and_continue_adopts(fails: Array[String], content: ContentDB,
		reference: Dictionary) -> PackedFloat32Array:
	var main: Main = _main(content)
	var saved: RunState = _store_run(content, SEED_A)
	# The kit is held again, so this warm-up holds it as a title's first would.
	MapJourneyLandscape.Kit._held_kinds = 0
	MapJourneyLandscape.Kit._held.clear()
	MapJourneyLandscape.Kit._requested.clear()
	# The first title of a session plays the launch rite, and the warm-up starts
	# with it, before its first frame.
	main._show_title()
	var title: TitleScreen = main._choice_screen as TitleScreen
	title.kindle_now()
	_check(fails, title.rite != null and title.rite.is_running() and MapJourneyPrefetch.busy()
			and MapLandscapeAssets.warming() != null,
		"the saved run's land warms from the launch rite's first frame")
	# The kit needs no pictures: its scenes are held while they decode.
	var kit_until: int = Time.get_ticks_msec() + SETTLE_MS
	while MapJourneyPrefetch.current_step() == MapJourneyPrefetch.Step.WAITING_PICTURES \
			and MapJourneyLandscape.Kit._held_kinds == 0 and Time.get_ticks_msec() < kit_until:
		main._process(0.016)
		OS.delay_msec(1)
	_check(fails, MapJourneyLandscape.Kit._held_kinds > 0
			and MapJourneyPrefetch.current_step() == MapJourneyPrefetch.Step.WAITING_PICTURES,
		"the warm-up holds the kit's scenes while the pictures decode")
	title.rite.skip()
	main._process(0.016)
	_check(fails, MapJourneyPrefetch.busy(), "the warm-up goes on once the rite has landed")
	_check(fails, _settle(main) and MapJourneyPrefetch.current_step()
			== MapJourneyPrefetch.Step.DONE and MapScene._journey_kept != null,
		"the title's warm-up builds the land")
	var warm: MapJourneyLandscape = MapScene._journey_kept
	var warm_heights: PackedFloat32Array = warm.terrain._grid.duplicate() if warm != null \
		else PackedFloat32Array()
	if warm != null:
		warm.terrain.start_heights(false)
		warm.terrain.finish_heights()
	_check(fails, warm != null and not warm_heights.is_empty()
			and warm.terrain._grid == warm_heights,
		"the warm-up's heights, worked out on the pool's threads, are those worked out on one")
	_check(fails, MapJourneyPrefetch._current._pacing != null and MapJourneyPrefetch._current._pacing.on,
		"the title's build hands the renderer its meshes a frame's worth at a time")
	_check(fails, MapScene._bound_key == MapScene._journey_kept_key
			and not MapJourneyPrefetch.layout_packet(WorldMapScreen._input_digest_kept).is_empty(),
		"the warm-up leaves the open its layout input, layout and scenery binding")
	# Language: the land holds no words, so the rebuilt title keeps it.
	main._on_language_changed(Locale.CODE_ZH_HANT, false)
	main._process(0.016)
	_check(fails, Locale.active.code == Locale.CODE_ZH_HANT and main._choice_screen is TitleScreen
			and MapScene._journey_kept == warm and not MapJourneyPrefetch.busy(),
		"a language change keeps the warm land and builds nothing again")
	main._on_language_changed(Locale.CODE_EN, false)
	main._process(0.016)
	# Continue adopts it: no second build, and the layout a cold open binds.
	var title_now: TitleScreen = main._choice_screen as TitleScreen
	title_now.chosen.emit("continue")
	var screen: WorldMapScreen = main._map_screen
	_check(fails, screen != null and not screen.landscape_pending()
			and screen._map_scene.journey_landscape() == warm and is_instance_valid(warm),
		"Continue opens the map on the warm land, without building another")
	if screen != null:
		var binding: Dictionary = screen.layout_diagnostics().get("live_binding", {})
		var cold_binding: Dictionary = reference.get("binding", {})
		_check(fails, not cold_binding.is_empty()
				and screen.layout_digest() == str(reference.get("layout", ""))
				and screen.layout_input_digest() == str(reference.get("input", ""))
				and binding == cold_binding,
			"the warm open binds the layout and scenery a cold open binds")
	_map_keeps_the_land(fails, main, warm)
	# Back on the title with the same save: the land is kept, nothing rebuilt.
	_to_title(main)
	main._process(0.016)
	_check(fails, MapScene._journey_kept == warm and warm.get_parent() == null
			and not MapJourneyPrefetch.busy(),
		"the title of the same saved run keeps its land")
	# Another save: the title warms its land and frees the other.
	_store_run(content, SEED_B)
	main._show_title()
	main._process(0.016)
	_check(fails, MapJourneyPrefetch.busy() and _settle(main), "another save's land warms")
	var other: MapJourneyLandscape = MapScene._journey_kept
	_check(fails, not is_instance_valid(warm) and other != null and other != warm,
		"another save is never given the warm land, and the old one is freed")
	# A restore of a run the title did not warm takes nothing warm either.
	var stranger: RunState = _store_run(content, SEED_C)
	main._continue_run(stranger)
	var stranger_screen: WorldMapScreen = main._map_screen
	_check(fails, not is_instance_valid(other) and stranger_screen != null,
		"a restore of another run lets the land warmed for another save go")
	_check(fails, MapJourneyPrefetch._current != null and MapJourneyPrefetch._current._pacing != null
			and not MapJourneyPrefetch._current._pacing.on,
		"a land a map is waiting for is built unpaced")
	_settle(main)
	_pump_screen(main)
	_check(fails, stranger_screen != null and not stranger_screen.landscape_pending()
			and stranger_screen._map_scene.journey_landscape() != null,
		"a restore of another run builds its own land")
	# Begin Anew: the new run's land replaces the saved run's.
	_store_run(content, SEED_A)
	_to_title(main)
	main._process(0.016)
	_settle(main)
	var anew: MapJourneyLandscape = MapScene._journey_kept
	main._vigil.scenes_seen.append("opening")
	main._forced_seed = SEED_B
	main._new_run()
	_check(fails, not is_instance_valid(anew), "Begin Anew lets the saved run's warm land go")
	# Erase Everything: the title holds no map at all, a build in flight included.
	main._on_reset_choice("yes")
	main._process(0.016)
	_check(fails, MapJourneyPrefetch.current_step() == -1 and MapScene._journey_kept == null
			and MapLandscapeAssets._kept == null and MapLandscapeAssets.warming() == null,
		"Erase Everything leaves the title holding no map")
	var until: int = Time.get_ticks_msec() + SETTLE_MS
	while not MapScene._abandoned.is_empty() and Time.get_ticks_msec() < until:
		main._process(0.016)
		OS.delay_msec(4)
	_check(fails, MapScene._abandoned.is_empty(), "a land given up mid-build is freed once built")
	_dispose(main)
	return warm_heights


## The map's own screen changes keep the land: a language change on the map
## rebuilds the screen, and a title reached with the run still live (a save
## error's door) keeps the screen until Continue restores the run again. Either
## way the screen that held the land is freed at the frame's end and the new one
## binds first: it takes the land over instead of building another.
static func _map_keeps_the_land(fails: Array[String], main: Main,
		warm: MapJourneyLandscape) -> void:
	var before: WorldMapScreen = main._map_screen
	main._show_title()
	main._process(0.016)
	main._continue_run(main._load_run())
	var after: WorldMapScreen = main._map_screen
	_check(fails, after != null and after != before and not after.landscape_pending()
			and after._map_scene.journey_landscape() == warm and is_instance_valid(warm)
			and warm.get_parent() != null and not MapJourneyPrefetch.busy(),
		"a run restored over its kept screen draws the same land, without building another")
	_free_left(before)
	before = after
	main._on_language_changed(Locale.CODE_ZH_HANT, false)
	after = main._map_screen
	_check(fails, after != null and after != before and not after.landscape_pending()
			and after._map_scene.journey_landscape() == warm and is_instance_valid(warm)
			and warm.get_parent() != null and not MapJourneyPrefetch.busy(),
		"a language change on the map draws the same land, without building another")
	_free_left(before)
	before = after
	main._on_language_changed(Locale.CODE_EN, false)
	_free_left(before)


## A tap on Back to the Road before the title's warm-up has ended: the map
## hurries the warm-up instead of building again. Tapped during its setup, the
## build starts at once, unpaced, its heights worked out across the pool;
## tapped mid-build, the build stops pacing. Either way the map draws that
## build's land, the land a cold open binds.
static func _early_continue_adopts_the_build(fails: Array[String], content: ContentDB,
		reference: Dictionary, warm_heights: PackedFloat32Array) -> void:
	for mid_build: bool in [false, true]:
		_release_all()
		var main: Main = _main(content)
		_store_run(content, SEED_A)
		main._title_kindled = true
		main._show_title()
		main._process(0.016)
		var setup: Array[int] = [MapJourneyPrefetch.Step.WAITING_PICTURES,
			MapJourneyPrefetch.Step.CATALOGUE, MapJourneyPrefetch.Step.KIT]
		if mid_build:
			var until: int = Time.get_ticks_msec() + SETTLE_MS
			while MapJourneyPrefetch.current_step() in setup and Time.get_ticks_msec() < until:
				main._process(0.016)
				OS.delay_msec(1)
		var job: MapJourneyPrefetch = MapJourneyPrefetch._current
		var when: String = "mid-build" if mid_build else "during the warm-up's setup"
		var at_tap: bool = job != null and job.step in setup
		if mid_build:
			at_tap = job != null and job.step == MapJourneyPrefetch.Step.BUILDING \
				and job._pacing.on
		_check(fails, at_tap, "the title's warm-up is %s when the lantern is tapped" % when)
		var paced: Meshes.Pacing = job._pacing if job != null else null
		var building: MapJourneyLandscape = job._land if job != null else null
		(main._choice_screen as TitleScreen).chosen.emit("continue")
		var screen: WorldMapScreen = main._map_screen
		if not mid_build and job != null:
			paced = job._pacing
			building = job._land
		_check(fails, screen != null and screen.landscape_pending()
				and MapJourneyPrefetch._current == job and paced != null and not paced.on
				and job.step == MapJourneyPrefetch.Step.BUILDING,
			"a Continue %s builds that land unpaced" % when)
		_pump_screen(main)
		var drawn: MapJourneyLandscape = screen._map_scene.journey_landscape() \
			if screen != null else null
		_check(fails, drawn != null and drawn == building and drawn.is_built()
				and drawn.failure.is_empty(),
			"a Continue %s draws the warm-up's land, without building another" % when)
		if screen != null:
			var binding: Dictionary = screen.layout_diagnostics().get("live_binding", {})
			var cold_binding: Dictionary = reference.get("binding", {})
			_check(fails, screen.layout_digest() == str(reference.get("layout", ""))
					and not cold_binding.is_empty() and binding == cold_binding,
				"a Continue %s binds the layout and scenery a cold open binds" % when)
		if not mid_build:
			_check(fails, drawn != null and not warm_heights.is_empty()
					and drawn.terrain._grid == warm_heights,
				"heights worked out across the whole pool are the warm-up's")
		_dispose(main)
	_stopped_build_ends_early(fails, content)


## Begin Anew mid-build gives the title's build up: it stops pacing and ends at
## its next stage as a failure nothing adopts, freeing the pool's thread for
## the new run's build.
static func _stopped_build_ends_early(fails: Array[String], content: ContentDB) -> void:
	_release_all()
	var main: Main = _main(content)
	_store_run(content, SEED_A)
	main._title_kindled = true
	main._show_title()
	main._process(0.016)
	var until: int = Time.get_ticks_msec() + SETTLE_MS
	while MapJourneyPrefetch.current_step() != MapJourneyPrefetch.Step.BUILDING \
			and MapJourneyPrefetch.busy() and Time.get_ticks_msec() < until:
		main._process(0.016)
		OS.delay_msec(1)
	var job: MapJourneyPrefetch = MapJourneyPrefetch._current
	var given_up: MapJourneyLandscape = job._land if job != null else null
	var pacing: Meshes.Pacing = job._pacing if job != null else null
	main._vigil.scenes_seen.append("opening")
	main._forced_seed = SEED_B
	main._new_run()
	_check(fails, pacing != null and pacing.stopped and not pacing.on
			and MapScene._abandoned.has(given_up),
		"Begin Anew stops the title's build in flight, unpaced")
	until = Time.get_ticks_msec() + SETTLE_MS
	while given_up != null and given_up.busy() and Time.get_ticks_msec() < until:
		OS.delay_msec(2)
	_check(fails, given_up != null and given_up.failure == MapJourneyLandscape.STOPPED,
		"a build given up ends early, as a failure nothing adopts")
	_settle(main)
	_check(fails, not is_instance_valid(given_up) and MapScene._abandoned.is_empty(),
		"a stopped build's land is freed once its task ends")
	_dispose(main)


## A tap on Back to the Road mid-build: the build stays paced while the flare
## and flood play over the title, so they keep their frames, and stops pacing
## once the map opens under the flood. The worker hands the layout over before
## it builds the land, so that map takes the input, layout and scenery binding
## instead of making them again, then draws the build's land.
static func _map_opened_mid_build_takes_the_layout(fails: Array[String],
		content: ContentDB) -> void:
	_release_all()
	var main: Main = _main(content)
	var held: HeldFlood = HeldFlood.new()
	held.instant = true
	main.remove_child(main._transitions)
	main._transitions.free()
	main._transitions = held
	main.add_child(held)
	_store_run(content, SEED_A)
	main._title_kindled = true
	main._show_title()
	var job: MapJourneyPrefetch = MapJourneyPrefetch._current
	var until: int = Time.get_ticks_msec() + SETTLE_MS
	while job != null and MapJourneyPrefetch.busy() and Time.get_ticks_msec() < until \
			and not (job.step == MapJourneyPrefetch.Step.BUILDING and job._layout_taken):
		main._process(0.016)
		OS.delay_msec(1)
	var building: MapJourneyLandscape = job._land if job != null else null
	_check(fails, job != null and job.step == MapJourneyPrefetch.Step.BUILDING
			and job._layout_taken and job._pacing.on and MapScene._journey_kept == null
			and not MapJourneyPrefetch.layout_packet(WorldMapScreen._input_digest_kept).is_empty()
			and MapScene._bound_key == str(job._layout[4]),
		"the worker hands the layout over before the land is built")
	(main._choice_screen as TitleScreen).chosen.emit("continue")
	_check(fails, job != null and job._pacing.on and main._map_screen == null
			and held.covered.is_valid() and job.step == MapJourneyPrefetch.Step.BUILDING,
		"the flare and flood of a tap on Back to the Road play over a paced build")
	held.covered.call()
	var screen: WorldMapScreen = main._map_screen
	_check(fails, screen != null and screen.landscape_pending() and job != null
			and not job._pacing.on
			and is_same(main._map_layout_packet, job._packet)
			and is_same(MapScene._bound, job._layout[3]),
		"a map opened mid-build takes the worker's layout and scenery binding")
	_pump_screen(main)
	_check(fails, screen != null and screen._map_scene.journey_landscape() == building
			and building != null and building.is_built(),
		"the map opened mid-build draws the build's land")
	_dispose(main)


## The flood of a tap held over the title: its callback (the restore) runs
## when the test calls it, as the real flood's does once it covers.
class HeldFlood extends TransitionLayer:
	var covered: Callable = Callable()

	func flood(_at: Vector2, _colour: Color, on_covered: Callable) -> void:
		covered = on_covered


## A screen let go with `queue_free`, freed now: the test frames never come.
static func _free_left(screen: WorldMapScreen) -> void:
	if is_instance_valid(screen) and screen.get_parent() == null:
		screen.free()


## Back to the title from a run (the run menu's door), and the frame's end that
## frees the screen it leaves.
static func _to_title(main: Main) -> void:
	var left: WorldMapScreen = main._map_screen
	main.game = null
	main._map = null
	main._route_idle()
	if is_instance_valid(left):
		left.free()


## Steps Main until the prefetch is no longer busy.
static func _settle(main: Main) -> bool:
	var until: int = Time.get_ticks_msec() + SETTLE_MS
	while MapJourneyPrefetch.busy() and Time.get_ticks_msec() < until:
		main._process(0.016)
		OS.delay_msec(4)
	return not MapJourneyPrefetch.busy()


## Steps the open map's scene until its land is drawn.
static func _pump_screen(main: Main) -> void:
	var until: int = Time.get_ticks_msec() + SETTLE_MS
	while main._map_screen != null and main._map_screen.landscape_pending() \
			and Time.get_ticks_msec() < until:
		main._process(0.016)
		main._map_screen._map_scene._process(0.016)
		OS.delay_msec(4)


## A saved Act I run on the scratch profile, stored as a new run stores it,
## without warming anything.
static func _store_run(content: ContentDB, run_seed: int) -> RunState:
	var run: RunState = RunState.new_run(content, run_seed, "run-title-road-%d" % run_seed)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	game.quests.prepare_run(run)
	var map: WorldMap = WorldMap.benchmark(run)
	game.quests.decorate_map(run, map)
	run.map = map.to_dict()
	SaveService.store(run, RUN_PATH)
	return run


static func _main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	main._map_keep.release()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func _release_all() -> void:
	MapJourneyPrefetch.release()
	MapScene.release_kept_journey()
	MapLandscapeAssets.release()
	MapScene._bound = {}
	MapScene._bound_key = ""
	WorldMapScreen._input_kept = null
	WorldMapScreen._input_sources = []
	WorldMapScreen._input_digest_kept = ""
