extends RefCounted
## Hold Act I at the woodland stage, after its stone task starts.
## Cancellation and queued screen disposal must keep the shared kit until
## every abandoned worker ends.
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Stone = preload("res://presentation/map/landscape/land_stone.gd")


static func run(fails: Array[String]) -> void:
	_cancelled_prefetch(fails)
	for disposal: String in ["route", "kept release", "stale take", "unkeepable"]:
		await _queued_own_build(fails, disposal)


static func _cancelled_prefetch(fails: Array[String]) -> void:
	MapJourneyPrefetch.release()
	MapJourneyPrefetch.join()
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "test-kit-release")
	MapJourneyPrefetch.start(WorldMap.for_run(run, content), run)
	var job: MapJourneyPrefetch = MapJourneyPrefetch._current
	# Attach before launch: the worker adds woodland immediately before it
	# reads the atlas, after it starts the concurrent stone gather.
	var entered: Semaphore = Semaphore.new()
	var resume: Semaphore = Semaphore.new()
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	var blocked: Array[bool] = [false]
	land.child_order_changed.connect(func() -> void:
		if not blocked[0] and land.wood != null and land.lamps == null:
			blocked[0] = true
			entered.post()
			resume.wait())
	while not MapJourneyLandscape.ready_kit(true):
		pass
	MapJourneyPrefetch.prime()
	if not job._take(MapLandscapeAssets.for_act(0)):
		fails.append("test_map_kit_release: catalogue unavailable")
		land.free()
		MapJourneyPrefetch.release()
		return
	job._land = land
	job._pacing = MapJourneyPrefetch.Meshes.Pacing.new()
	job._pacing.on = false
	job._task = WorkerThreadPool.add_task(MapJourneyPrefetch._paced_build.bind(
		job._pacing, job._out, job._layout, job._layout_lock, land, job._assets,
		job._bundle, job._heroes, job._quality, job._nodes, job._edges,
		job._act, job._seed, job._salt), true, "kit release test")
	job.step = MapJourneyPrefetch.Step.BUILDING
	var reached: bool = false
	var deadline: int = Time.get_ticks_msec() + 60000
	while not reached and not WorkerThreadPool.is_task_completed(job._task) \
			and Time.get_ticks_msec() < deadline:
		reached = entered.try_wait()
		OS.delay_msec(1)
	if not reached:
		fails.append("test_map_kit_release: did not reach Act I scenery")
	MapJourneyPrefetch.release()
	MapJourneyPrefetch.step_current()
	if reached and (Atlas.by_kind.is_empty() or Stone._held.is_empty() or Stone._pieces == null):
		fails.append("test_map_kit_release: release cleared a running scenery worker's kit")
		# Restore the cache before the blocked worker resumes, so the mutation
		# fails the assertion without producing unrelated null-access errors.
		while not MapJourneyLandscape.ready_kit(true):
			pass
	resume.post()
	while not WorkerThreadPool.is_task_completed(job._task):
		OS.delay_msec(1)
	MapJourneyPrefetch.step_current()
	if not Atlas.by_kind.is_empty() or not Stone._held.is_empty() or Stone._pieces != null:
		fails.append("test_map_kit_release: completed worker retained its released kit")
	if is_instance_valid(land):
		fails.append("test_map_kit_release: completed abandoned land was not reaped")


## Erase Everything queues the screen in _clear_route, then releases kits in
## _warm_title_road in the same stack. PREDELETE has not run at that point.
static func _queued_own_build(fails: Array[String], disposal: String) -> void:
	MapJourneyPrefetch.release()
	MapJourneyPrefetch.join()
	var previous_async: bool = MapScene.journey_async
	var previous_threads: int = MapJourneyLandscape.Terrain.pool_threads
	# Keep stone on this real worker, so the failing baseline can restore the
	# released caches before either scenery reader resumes. The prefetch case
	# above retains its concurrent stone task.
	MapJourneyLandscape.Terrain.pool_threads = 1
	MapScene.journey_async = true
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "test-own-kit-release")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(run, content), content)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.refresh(run)
	var scene: MapScene = screen._map_scene
	var land: MapJourneyLandscape = scene.journey_landscape()
	var entered: Semaphore = Semaphore.new()
	var resume: Semaphore = Semaphore.new()
	var blocked: Array[bool] = [false]
	land.child_order_changed.connect(func() -> void:
		if not blocked[0] and land.wood != null and land.lamps == null:
			blocked[0] = true
			entered.post()
			resume.wait())
	var reached: bool = false
	var deadline: int = Time.get_ticks_msec() + 60000
	while not reached and Time.get_ticks_msec() < deadline:
		scene._poll_journey()
		reached = entered.try_wait()
		if land.is_built():
			break
		OS.delay_msec(1)
	if not reached:
		fails.append("test_map_kit_release: own build did not reach Act I scenery")
	if MapJourneyPrefetch._current != null or MapScene._abandoned.has(land):
		fails.append("test_map_kit_release: fallback worker is not owned only by its scene")
	var task: int = land._task
	var main: Main = Main.new()
	TestProfile.install(main)
	# No yield between each production disposal caller and title release.
	match disposal:
		"route":
			main._map_screen = screen
			main._clear_route()
		"kept release":
			main._map_keep.keep(screen, {"seed": 717})
			main._map_keep.release()
		"stale take":
			main._map_keep.keep(screen, {"seed": 717})
			if main._map_keep.take({"seed": 718}) != null:
				fails.append("test_map_kit_release: stale screen was handed out")
		"unkeepable":
			screen._travelling = true
			main._map_keep.keep(screen, {"seed": 717})
	main._warm_title_road(null, null)
	MapJourneyPrefetch.step_current()
	if not is_instance_valid(screen) or not screen.is_queued_for_deletion() \
			or not is_instance_valid(scene) or not is_instance_valid(land):
		fails.append("test_map_kit_release: did not exercise the queued deletion interval")
	if reached and (WorkerThreadPool.is_task_completed(task) or Atlas.by_kind.is_empty() \
			or Stone._held.is_empty() or Stone._pieces == null):
		fails.append("test_map_kit_release: title release cleared a queued own-build worker's kit (%s)" % disposal)
		# Repair caches before resuming the real worker on the failing baseline.
		while not MapJourneyLandscape.ready_kit(true):
			pass
	resume.post()
	deadline = Time.get_ticks_msec() + 60000
	while task >= 0 and not WorkerThreadPool.is_task_completed(task) \
			and Time.get_ticks_msec() < deadline:
		OS.delay_msec(1)
	if task >= 0 and not WorkerThreadPool.is_task_completed(task):
		push_error("test_map_kit_release: own scenery worker did not finish within 60 seconds")
		(Engine.get_main_loop() as SceneTree).quit(1)
		return
	# Now let the queued screen reach PREDELETE, then reap through Main's path.
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	MapJourneyPrefetch.step_current()
	if is_instance_valid(screen) or is_instance_valid(land) or not MapScene._abandoned.is_empty():
		fails.append("test_map_kit_release: disposed own build was not reaped")
	if not Atlas.by_kind.is_empty() or not Stone._held.is_empty() or Stone._pieces != null:
		fails.append("test_map_kit_release: disposed own build retained its released kit")
	main.free()
	MapScene.journey_async = previous_async
	MapJourneyLandscape.Terrain.pool_threads = previous_threads
