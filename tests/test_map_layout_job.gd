extends RefCounted
## With the Map Compiler v2 opt-in on (MapLayoutPolicy), a launch without
## arguments compiles the world layout on a worker thread behind a charting
## veil, and lands on the same map a main-thread compile draws. A main-thread
## compile froze an A12 past the iOS watchdog (Sentry 1ec0d817, TestFlight
## 1.0.0 build 8), so the veil must be the route while the job runs. Production
## never opts in (docs/map/production-layout.md; tests/test_map_layout_fast.gd).

const RUN_PATH: String = "user://test_map_layout_job_run_v2.json"
const VIGIL_PATH: String = "user://test_map_layout_job_vigil_v2.json"
## Act IV compiles in well under a second, which keeps this real compile cheap.
const ACT: int = 3
const SEED: int = 717
const JOB_BUDGET_MS: int = 60000
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("map_layout_job: %s" % what)


static func run(fails: Array[String]) -> void:
	var opted_in: Variant = ProjectSettings.get_setting(MapLayoutPolicy.SETTING, null)
	ProjectSettings.set_setting(MapLayoutPolicy.SETTING, true)
	_check(fails, MapLayoutPolicy.compiler_requested(),
		"the project setting opts this desktop process into the compiler")
	_run(fails)
	ProjectSettings.set_setting(MapLayoutPolicy.SETTING, opted_in)


static func _run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var sync_main: Main = _map_main(content, false)
	_check(fails, sync_main._map_screen != null
			and not sync_main._map_screen.layout_pending()
			and sync_main._map_screen.layout_failure().is_empty(),
		"a synchronous boot still lands on a compiled map")
	var sync_digest: String = "" if sync_main._map_screen == null \
		else sync_main._map_screen.layout_digest()
	var sync_packet: String = _packet_text(sync_main._map_layout_packet)
	_dispose(sync_main)

	var main: Main = _map_main(content, true)
	_check(fails, main._route_screen is MapChartingVeil and main._map_screen == null,
		"while the layout compiles the veil holds the route, not a half-built map")
	_check(fails, main._map_layout_job != null,
		"the player's launch hands the compile to a worker")
	if main._route_screen is MapChartingVeil:
		var labels: Array[Node] = main._route_screen.find_children("*", "Label", true, false)
		var label: Label = labels[0] if not labels.is_empty() else null
		_check(fails, label != null
				and label.text == Locale.active.t("ui.pilgrimage.charting"),
			"the veil names the wait in the active language")
	var started: int = Time.get_ticks_msec()
	while main._map_layout_job != null and not main._map_layout_job.is_done() \
			and Time.get_ticks_msec() - started < JOB_BUDGET_MS:
		OS.delay_msec(5)
	main._process(0.0)
	_check(fails, main._map_layout_job == null and main._map_screen != null
			and not main._map_screen.layout_pending(),
		"the landed compile routes back to the map")
	_check(fails, main._map_screen != null
			and main._map_screen.layout_digest() == sync_digest
			and not sync_digest.is_empty(),
		"the worker's layout is the main-thread layout (%s vs %s)" % [
			"" if main._map_screen == null else main._map_screen.layout_digest(),
			sync_digest])
	_check(fails, _packet_text(main._map_layout_packet) == sync_packet,
		"the worker's whole compile packet is byte-identical to the main thread's")
	_dispose(main)
	_superseded_job_is_retired(fails, content)
	_free_joins_running_job(fails, content)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## Freeing Main joins a compile still in flight; an unjoined WorkerThreadPool
## task crashed the engine at exit (signal 11 after the suite's PASS line).
static func _free_joins_running_job(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, true)
	var job: MapLayoutJob = main._map_layout_job
	_dispose(main)
	_check(fails, job != null and job._joined,
		"freeing Main joins the running layout job")


## A layout request for another input while a job runs never waits on the old
## job (that would block the main thread for its whole compile); the old job
## is joined once it is done, and the map lands for the newest input.
static func _superseded_job_is_retired(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, true)
	var first: MapLayoutJob = main._map_layout_job
	main.game.run.seed = SEED + 1
	main._show_map()
	_check(fails, first != null and main._map_layout_job != null
			and main._map_layout_job != first
			and main._map_layout_retired == [first]
			and main._route_screen is MapChartingVeil,
		"a new input retires the running job and keeps the veil up")
	var started: int = Time.get_ticks_msec()
	while (not main._map_layout_job.is_done() or not first.is_done()) \
			and Time.get_ticks_msec() - started < JOB_BUDGET_MS:
		OS.delay_msec(5)
	var newest: String = main._map_layout_job.digest
	main._process(0.0)
	_check(fails, main._map_layout_retired.is_empty() and main._map_layout_job == null
			and main._map_layout_input_digest == newest
			and main._map_screen != null and not main._map_screen.layout_pending(),
		"the retired job is joined and the newest layout routes to the map")
	_dispose(main)


## A `Main` standing on the map of a fresh run moved into Act IV, with the real
## compiler (no injected stand-in).
static func _map_main(content: ContentDB, async: bool) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_async = async
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._forced_seed = SEED
	main._vigil.scenes_seen.append("opening")
	# `_new_run` may route through the Act I map, whose real compile takes
	# minutes; a stand-in covers it, then only the Act IV compile is real.
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main._new_run()
	main._map_layout_compile = Callable()
	main._map_layout_input_digest = ""
	main._map_layout_packet = null
	main.game.run.act = ACT
	main._map = WorldMap.for_run(main.game.run, content)
	main._show_map()
	return main


static func _packet_text(packet_v: Variant) -> String:
	if typeof(packet_v) != TYPE_DICTIONARY:
		return ""
	var packet: Dictionary = packet_v
	var plain: Dictionary = packet.duplicate()
	var result_v: Variant = plain.get("result", null)
	if result_v is MapLayoutResult:
		var result: MapLayoutResult = result_v
		plain["result"] = result.to_dict()
	return var_to_str(plain)


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
