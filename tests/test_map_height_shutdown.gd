extends RefCounted
## An adopted prefetch owns height finalisation even when cancellation precedes
## its HEIGHTS write. Shutdown joins that outer task; scene-owned heights still
## need their own finalisation.
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const Landform = preload("res://presentation/map/landscape/landform.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const LIMIT_MS: int = 10000


class HeldHeights extends Terrain:
	var entered: Semaphore = Semaphore.new()
	var resume: Semaphore = Semaphore.new()
	var finalising: Semaphore = Semaphore.new()
	var lock: Mutex = Mutex.new()
	var calls: int = 0
	var evidence: Dictionary = {"calls": 0, "active_at_shutdown": false}

	func _bake_column(ix: int) -> void:
		if ix == 0:
			entered.post()
			resume.wait()
		super._bake_column(ix)

	func finish_heights() -> void:
		lock.lock()
		calls += 1
		evidence["calls"] = calls
		var duplicate: bool = calls > 1
		lock.unlock()
		if duplicate:
			# Keep the old ordering safe to test: record its second finaliser,
			# then unblock the real owner instead of corrupting its shared grid.
			resume.post()
			return
		finalising.post()
		super.finish_heights()


class HeldLand extends MapJourneyLandscape:
	var before_heights: Semaphore = Semaphore.new()
	var resume_build: Semaphore = Semaphore.new()
	var shutdown: Semaphore = Semaphore.new()
	var held: HeldHeights

	func _begin(_data: Dictionary, pacing: Meshes.Pacing) -> void:
		held = HeldHeights.new()
		terrain = held
		add_child(terrain)
		terrain.pacing = pacing
		terrain.landform = Landform.new()
		terrain.prepare({"edges": {}, "anchors": {}}, false, Rect2(0, 0, 1, 1))
		before_heights.post()
		resume_build.wait()

	func settle() -> void:
		held.evidence["active_at_shutdown"] = not held.heights_ready()
		shutdown.post()
		super.settle()


static func _wait(barrier: Semaphore) -> bool:
	var deadline: int = Time.get_ticks_msec() + LIMIT_MS
	while Time.get_ticks_msec() < deadline:
		if barrier.try_wait():
			return true
		OS.delay_usec(100)
	return false


## Release only after shutdown has started. The bounded watchdog lets a correct
## outer-task join complete; semaphores fix cancellation and active-height order.
static func _release_height(land: HeldLand) -> void:
	if not _wait(land.shutdown):
		land.held.resume.post()
		return
	var deadline: int = Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < deadline:
		land.held.lock.lock()
		var duplicate: bool = land.held.calls > 1
		land.held.lock.unlock()
		if duplicate:
			return
		OS.delay_usec(100)
	land.held.resume.post()


static func run(fails: Array[String]) -> void:
	MapJourneyPrefetch.release()
	MapJourneyPrefetch.join()
	var previous_threads: int = Terrain.pool_threads
	Terrain.pool_threads = 3
	var land: HeldLand = HeldLand.new()
	var job: MapJourneyPrefetch = MapJourneyPrefetch.new()
	job._land = land
	job._pacing = Meshes.Pacing.new()
	job._pacing.on = false
	MapJourneyPrefetch._current = job
	job._task = WorkerThreadPool.add_task(land.build_detached.bind({}, job._pacing),
		true, "adopted height shutdown")
	job.step = MapJourneyPrefetch.Step.BUILDING
	if not _wait(land.before_heights):
		fails.append("test_map_height_shutdown: build did not reach the cancellation barrier")
	MapJourneyPrefetch.release()
	if land._task != job._task or not MapScene._abandoned.has(land) \
			or land._stage != MapJourneyLandscape.Stage.REST:
		fails.append("test_map_height_shutdown: cancellation did not adopt the outer task before HEIGHTS")
	land.resume_build.post()
	if not _wait(land.held.entered) or not _wait(land.held.finalising):
		fails.append("test_map_height_shutdown: real height group did not remain active")
	if land._stage != MapJourneyLandscape.Stage.HEIGHTS or not land.busy():
		fails.append("test_map_height_shutdown: adopted task did not overwrite REST with active HEIGHTS")
	var evidence: Dictionary = land.held.evidence
	var release: Thread = Thread.new()
	release.start(_release_height.bind(land))
	# This is the production synchronous shutdown caller, with real height work
	# held in _bake_column and the outer task held in finish_heights.
	MapJourneyPrefetch.join()
	release.wait_to_finish()
	if evidence["calls"] != 1:
		fails.append("test_map_height_shutdown: shutdown finalised adopted HEIGHTS twice")
	if not evidence["active_at_shutdown"]:
		fails.append("test_map_height_shutdown: shutdown missed the active height group")
	if is_instance_valid(land) or not MapScene._abandoned.is_empty():
		fails.append("test_map_height_shutdown: shutdown retained its abandoned land")
	Terrain.pool_threads = previous_threads
	_scene_owned_control(fails)


static func _scene_owned_control(fails: Array[String]) -> void:
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	land.terrain = Terrain.new()
	land.add_child(land.terrain)
	land.terrain.prepare({"edges": {}, "anchors": {}}, false, Rect2(0, 0, 1, 1))
	land.terrain.start_heights()
	land._stage = MapJourneyLandscape.Stage.HEIGHTS
	land.settle()
	if land._stage != MapJourneyLandscape.Stage.DONE or land.terrain._grid.size() != 9 \
			or not land.terrain._baked.is_empty() or land.terrain._heights_task != -1:
		fails.append("test_map_height_shutdown: scene-owned HEIGHTS did not settle")
	# Settling an already completed build must leave its grid unchanged.
	var grid: PackedFloat32Array = land.terrain._grid.duplicate()
	land.settle()
	if land.terrain._grid != grid:
		fails.append("test_map_height_shutdown: completed build changed on repeated settle")
	land.free()
