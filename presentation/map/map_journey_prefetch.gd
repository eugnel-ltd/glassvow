class_name MapJourneyPrefetch
extends RefCounted
## Builds Act I's journey land before its map opens, the way
## `MapLandscapeAssets.prefetch` decodes an act's pictures before it opens.
##
## `Main` starts it whenever the next map it will open is the journey act's:
## when it routes a run, and from the title, before the launch rite's first
## frame, for the saved run Back to the Road restores. Main steps it every
## frame. Its main-thread setup is a little per frame, so the rite and the
## title it runs under keep their frames: it holds the kit's scenes one at a
## time (`Kit.preload_step`) while the act's pictures decode on the pool, and
## builds the act's catalogue from them a few small pieces at a time
## (`MapLandscapeAssets.prepare_step`). A map that opens meanwhile finishes that
## setup at once (`hurry`). Then the canonical layout input, the layout (the
## production generator) and the land are built on one worker-pool task, paced
## until a map is waiting for it. The layout input, the layout and the screen's
## scenery binding are handed over as soon as the worker has them
## (`_take_layout`), so a map that opens while the land is still building does
## not make them again on the main thread. The finished land is handed to
## `MapScene` as its kept land under the binding key the screen will ask for,
## so the first open re-parents it instead of building.
##
## One journey land at a time: a prefetch for another layout drops the older
## one and frees the land it built, and `release` lets go of both when the next
## map is not the journey act's.

enum Step { WAITING_PICTURES, CATALOGUE, KIT, BUILDING, DONE, FAILED }
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
## How long a frame of the setup may spend on the act's catalogue. Its pieces
## are small (a card laid out on the CPU, one profile, the digest), so a frame
## builds as many as fit, and the land's build is not kept waiting for them.
const CATALOGUE_BUDGET_US: int = 2000

static var _current: MapJourneyPrefetch = null

var step: Step = Step.WAITING_PICTURES
## The binding key `MapScene.bind_layout` will use for this layout.
var key: String = ""
var _act: int = 0
var _seed: int = 0
var _salt: int = 0
var _nodes: Array = []
var _edges: Array = []
var _assets: MapLandscapeAssets = null
var _bundle: Dictionary = {}
var _heroes: Dictionary = {}
var _quality: Dictionary = {}
var _task: int = -1
var _out: Array = []
var _land: MapJourneyLandscape = null
## How the worker hands the renderer its meshes: a frame's worth at a time
## while the title is up, all at once when a map is waiting for the land.
var _pacing: Meshes.Pacing = null
## The generator's packet for the layout input digested as `_input_digest`,
## once handed over: Main's compile hands it to the screen (`layout_packet`).
var _packet: Dictionary = {}
var _input_digest: String = ""
## What the worker hands over once it has bound the layout, before it builds
## the land: `[input, input digest, packet, binding, key]`, written under
## `_layout_lock` and never touched by the worker again.
var _layout: Array = []
var _layout_lock: Mutex = Mutex.new()
var _layout_taken: bool = false
## Whether the setup has let its first frame go by (`_advance`).
var _first_frame_gone: bool = false


## Starts a prefetch of `map`'s land for `run` when its act is the journey act
## and nothing is already prefetched or prefetching for the same layout. For
## any other act the journey land is let go (`release`): it is never drawn
## there.
static func start(map: WorldMap, run: RunState) -> void:
	if map == null or run == null or run.act != 0:
		release()
		return
	var bound: Dictionary = MapLayoutInputBinding.bind(map, run.act)
	if bound.get("ok", false) != true:
		return
	var job: MapJourneyPrefetch = MapJourneyPrefetch.new()
	job._act = run.act
	job._seed = run.seed
	job._salt = run.seed + WorldMapScreen.SCENERY_SEED_OFFSET
	job._nodes = bound["nodes"]
	job._edges = bound["edges"]
	if _current != null and _current._same(job):
		return
	_drop()
	_current = job


## Advances the current prefetch by one piece of work; Main calls it every
## frame. Lands given up while their worker still ran are freed here once it
## ends, since no map may be open to do it.
static func step_current() -> void:
	if _current != null:
		_current._advance(false)
	MapScene.reap()


## A map is opening now: whatever main-thread setup the current prefetch has
## left runs at once, and its worker starts (unpaced, as a high-priority task
## that works the land's heights out across the pool, so it never queues
## behind the title's own loads or a build given up), or stops pacing its
## meshes.
static func hurry() -> void:
	if _current == null:
		return
	if _current._pacing != null:
		_current._pacing.on = false
	_current._advance(true)


## Whether a prefetch is still waiting or building; its land's key is known
## only once it is built, so a screen that opens meanwhile waits to see.
static func busy() -> bool:
	return _current != null and _current.step in [
		Step.WAITING_PICTURES, Step.CATALOGUE, Step.KIT, Step.BUILDING]


## The generator's packet the current prefetch made for the layout input
## digested as `input_digest`, or {} when it made none for it. Main's compile
## takes it instead of generating the same layout again on the main thread.
static func layout_packet(input_digest: String) -> Dictionary:
	if _current == null or input_digest.is_empty() or _current._input_digest != input_digest:
		return {}
	return _current._packet


## Reads back from the renderer, before the first frame, when nothing is in
## flight and a read-back costs next to nothing, the two meshes a prefetch
## would otherwise read back under the title's frames: the kit's unit cube and
## the slate cluster's faces. Main's first title calls it, on the game's
## renderer, only when it has a saved Act I run to warm.
static func prime() -> void:
	MapJourneyLandscape.Kit.Meshes.prepare_unit_box()
	MapLandscapeAssets.prime()


## The current prefetch's step, or -1 when there is none (tests and probes).
static func current_step() -> int:
	return _current.step if _current != null else -1


## Lets go of the journey land: any prefetch ends, and the kept land is freed
## once nothing draws it. For when the next map is not the journey act's (past
## its boss, a painted act, a title with no run to return to) and for tests
## and benches dropping every cache.
static func release() -> void:
	_drop()
	MapScene.release_kept_journey()


## Joins the prefetch's worker and every abandoned land's, for the process's
## exit (`Main`): a task left running holds the layout records it made, and
## freeing them after the scripting has shut down crashed the engine at exit.
## The build never waits on the main thread, and a build waited for here is
## given up first (unpaced and stopped, `Meshes.Pacing.stop`), as every
## abandoned one already is, so this waits at most for the current stage of
## each.
static func join() -> void:
	if _current != null and _current.step == Step.BUILDING:
		_current._pacing.stop()
		WorkerThreadPool.wait_for_task_completion(_current._task)
		_current._land.free()
	_current = null
	MapScene.join_abandoned()


## Gives up the current prefetch. Its worker is never waited on here: the
## build is stopped (`Meshes.Pacing.stop`: unpaced, it ends after its current
## stage and frees the pool's thread for the next build) and the land it was
## building is abandoned to `MapScene.reap`, which frees it once the task ends.
## A land it finished is freed unless a map draws it.
static func _drop() -> void:
	if _current == null:
		return
	if _current.step == Step.BUILDING and _current._land != null:
		_current._pacing.stop()
		_current._land.adopt_task(_current._task)
		MapScene.abandon(_current._land)
	elif _current.step == Step.DONE:
		MapScene.release_journey(_current.key)
	_current = null


func _same(other: MapJourneyPrefetch) -> bool:
	return _act == other._act and _seed == other._seed and _nodes == other._nodes \
		and _edges == other._edges


## One frame's piece of the main-thread setup, or (`hurry`) all of it; then
## the build. The kit needs no pictures, so a scene of it is held every frame
## of the setup: while the pictures decode, and beside each piece of the
## catalogue built from them. The first frame after the prefetch starts holds
## nothing: the title starts it before its first frame, which builds every
## pipeline the launch rite will show (`TitleScreen._warm_pipelines`), and the
## kit's loads beside that frame lengthened it on the iPad 8.
func _advance(hurry: bool) -> void:
	if step == Step.BUILDING:
		_take_layout()
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_finish()
		return
	if step == Step.DONE or step == Step.FAILED:
		return
	if not hurry and not _first_frame_gone:
		_first_frame_gone = true
		return
	var kit_held: bool = true
	if hurry:
		MapJourneyLandscape.Kit.preload_scenes()
	else:
		kit_held = MapJourneyLandscape.Kit.preload_step()
	if step == Step.WAITING_PICTURES:
		var warming: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
		if not hurry and warming != null and warming.act == _act and not warming.is_done():
			return
		step = Step.CATALOGUE
	if step == Step.CATALOGUE:
		var assets: MapLandscapeAssets = MapLandscapeAssets.for_act(_act) if hurry \
			else _catalogue_pieces()
		if assets == null:
			return
		if not _take(assets):
			step = Step.FAILED
			return
		step = Step.KIT
		if not hurry:
			return
	if kit_held:
		_launch(not hurry)


## As many pieces of the act's catalogue as fit in `CATALOGUE_BUDGET_US`, at
## least one; the catalogue once it is complete, else null.
func _catalogue_pieces() -> MapLandscapeAssets:
	var until: int = Time.get_ticks_usec() + CATALOGUE_BUDGET_US
	var assets: MapLandscapeAssets = MapLandscapeAssets.prepare_step(_act)
	while assets == null and Time.get_ticks_usec() < until:
		assets = MapLandscapeAssets.prepare_step(_act)
	return assets


## What the worker needs from the act's catalogue; false when it is incomplete.
func _take(assets: MapLandscapeAssets) -> bool:
	_assets = assets
	_bundle = assets.bundle()
	_heroes = MapScene.hero_contract(assets.registry, assets.profiles,
		MapLandscapeAssets.GATES[_act], "vigil" if _act == 0 else "")
	_quality = WorldMapScreen.quality_registry()
	return not (_bundle.is_empty() or _heroes.is_empty() or _quality.is_empty())


## Starts the build on the pool: `paced` under a lit screen, as a low-priority
## task; unpaced and high-priority when a map is already waiting (`hurry`).
func _launch(paced: bool) -> void:
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	_land = land
	_pacing = Meshes.Pacing.new()
	_pacing.on = paced
	_task = WorkerThreadPool.add_task(_paced_build.bind(_pacing, _out, _layout, _layout_lock,
		land, _assets, _bundle, _heroes, _quality.duplicate(true), _nodes.duplicate(true),
		_edges.duplicate(true), _act, _seed, _salt), not paced, "journey land prefetch")
	step = Step.BUILDING


## On the worker: `_build`, its meshes handed over as `pacing` says.
static func _paced_build(pacing: Meshes.Pacing, out: Array, layout: Array,
		layout_lock: Mutex, land: MapJourneyLandscape, assets: MapLandscapeAssets,
		bundle: Dictionary, heroes: Dictionary, quality: Dictionary, nodes: Array,
		edges: Array, act: int, run_seed: int, salt: int) -> void:
	Meshes.pace(pacing)
	_build(pacing, out, layout, layout_lock, land, assets, bundle, heroes, quality, nodes,
		edges, act, run_seed, salt)
	Meshes.pace(null)


## On the worker: input, layout and the screen's scenery binding, handed over
## in `layout` (under `layout_lock`) before the land is built, then the land,
## written into `out` as `[land, key, failure]`. A build given up
## (`pacing.stopped`) ends at its next stage.
static func _build(pacing: Meshes.Pacing, out: Array, layout: Array, layout_lock: Mutex,
		land: MapJourneyLandscape, assets: MapLandscapeAssets, bundle: Dictionary,
		heroes: Dictionary, quality: Dictionary, nodes: Array, edges: Array, act: int,
		run_seed: int, salt: int) -> void:
	out.append(land)
	var generator: Dictionary = MapLayoutPolicy.generator_fields(false)
	var input: MapLayoutInput = WorldMapScreen.layout_input(nodes, edges, act, run_seed,
		bundle, heroes, generator, quality)
	if input == null:
		out.append_array(["", "invalid input"])
		return
	if _given_up(pacing, land, out):
		return
	var packet: Dictionary = MapLayoutPolicy.generate(input, quality, bundle)
	var result_v: Variant = packet.get("result", null)
	if not result_v is MapLayoutResult:
		out.append_array(["", "layout failed"])
		return
	if _given_up(pacing, land, out):
		return
	var input_digest: String = input.digest()
	var result: MapLayoutResult = result_v
	var data: Dictionary = result.identity_dict()
	# As `MapScene.bind_layout` binds: a land of the act's class prepared for
	# the record deals the candidates the filter keeps or rejects.
	var bound_data: Dictionary = result.identity_dict()
	var dealer: MapJourneyLandscape = MapJourneyLandscape.new()
	dealer.prepare(bound_data, assets, salt)
	var profiles: Dictionary = bundle["profiles"]
	var binding: Dictionary = MapScene.scenery_binding(bound_data, dealer, assets.registry,
		profiles, heroes, quality)
	dealer.free()
	if not binding.is_empty():
		binding["bake"] = {}
		binding["quality"] = quality.duplicate(true)
	var key: String = "|".join([result.digest(), bundle["digest"], str(salt)])
	layout_lock.lock()
	layout.append_array([input, input_digest, packet, binding, key])
	layout_lock.unlock()
	land.prepare(data, assets, salt)
	land.build_detached(data, pacing)
	out.append_array([key, land.failure])


## On the worker: whether the build was given up (`pacing.stopped`); if so its
## land fails as `STOPPED` and `out` says so.
static func _given_up(pacing: Meshes.Pacing, land: MapJourneyLandscape, out: Array) -> bool:
	if not pacing.stopped:
		return false
	land.failure = MapJourneyLandscape.STOPPED
	out.append_array(["", land.failure])
	return true


## Hands the screen what the worker has made of the layout so far, once: the
## input, the layout and the scenery binding, each kept where the screen looks
## for it (`layout_packet`, `MapScene.keep_binding`, `WorldMapScreen.keep_input`).
func _take_layout() -> void:
	if _layout_taken:
		return
	_layout_lock.lock()
	var ready: bool = not _layout.is_empty()
	_layout_lock.unlock()
	if not ready:
		return
	_layout_taken = true
	var input: MapLayoutInput = _layout[0]
	_input_digest = str(_layout[1])
	_packet = _layout[2]
	var binding: Dictionary = _layout[3]
	if not binding.is_empty():
		MapScene.keep_binding(str(_layout[4]), binding)
	WorldMapScreen.keep_input(WorldMapScreen.input_sources(_nodes, _edges, _act, _seed,
		str(_bundle["digest"]), _heroes, MapLayoutPolicy.generator_fields(false), _quality),
		input, _input_digest)


func _finish() -> void:
	var land: MapJourneyLandscape = _land
	_land = null
	_take_layout()
	key = str(_out[1])
	if key.is_empty() or not str(_out[2]).is_empty():
		land.free()
		step = Step.FAILED
		return
	MapScene.adopt_journey(key, land)
	step = Step.DONE
