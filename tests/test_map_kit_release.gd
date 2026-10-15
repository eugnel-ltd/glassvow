extends RefCounted
## Hold Act I at the woodland stage, after its stone task starts.
## Cancellation must keep the shared kit until every abandoned worker ends.
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Stone = preload("res://presentation/map/landscape/land_stone.gd")


static func run(fails: Array[String]) -> void:
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
