class_name MapJourneyPrefetch
extends RefCounted
## Builds Act I's journey land before its map opens, the way
## `MapLandscapeAssets.prefetch` decodes an act's pictures before it opens.
##
## `Main` starts it whenever the next map it will open is the journey act's:
## when it routes a run, and from the title, once the launch rite has landed,
## for the saved run Back to the Road restores. Main steps it every frame. Its
## main-thread setup is one small piece per frame, so the title it runs under
## keeps its frames: it waits for the act's pictures to decode on a worker,
## builds the act's catalogue a piece at a time
## (`MapLandscapeAssets.prepare_step`) and holds the kit's scenes one at a time
## (`Kit.preload_step`). A map that opens meanwhile finishes that setup at once
## (`hurry`). Then the canonical layout input, the layout (the production
## generator) and the land are built on one worker-pool task. The finished land
## is handed to `MapScene` as its kept land under the binding key the screen
## will ask for, so the first open re-parents it instead of building.
##
## One journey land at a time: a prefetch for another layout drops the older
## one and frees the land it built, and `release` lets go of both when the next
## map is not the journey act's.

enum Step { WAITING_PICTURES, CATALOGUE, KIT, BUILDING, DONE, FAILED }

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
## The generator's packet for the layout input digested as `_input_digest`,
## once built: Main's compile hands it to the screen (`layout_packet`).
var _packet: Dictionary = {}
var _input_digest: String = ""


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
## left runs at once, and its worker starts.
static func hurry() -> void:
	if _current != null:
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
	if _current == null or _current.step != Step.DONE or input_digest.is_empty() \
			or _current._input_digest != input_digest:
		return {}
	return _current._packet


## Reads back from the renderer, before the first frame, when nothing is in
## flight and a read-back costs next to nothing, the two meshes a prefetch
## would otherwise read back under the title's frames: the kit's unit cube and
## the slate cluster's faces (Main's boot, on the game's renderer only).
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
## The build never waits on the main thread, so this waits at most for the
## rest of one build.
static func join() -> void:
	if _current != null and _current.step == Step.BUILDING:
		WorkerThreadPool.wait_for_task_completion(_current._task)
		_current._land.free()
	_current = null
	MapScene.join_abandoned()


## Gives up the current prefetch. Its worker is never waited on here: the land
## it builds is abandoned to `MapScene.reap`, which frees it once the task ends.
## A land it finished is freed unless a map draws it.
static func _drop() -> void:
	if _current == null:
		return
	if _current.step == Step.BUILDING and _current._land != null:
		_current._land.adopt_task(_current._task)
		MapScene.abandon(_current._land)
	elif _current.step == Step.DONE:
		MapScene.release_journey(_current.key)
	_current = null


func _same(other: MapJourneyPrefetch) -> bool:
	return _act == other._act and _seed == other._seed and _nodes == other._nodes \
		and _edges == other._edges


## One piece of the main-thread setup, or (`hurry`) all of it; then the build.
func _advance(hurry: bool) -> void:
	if step == Step.WAITING_PICTURES:
		var warming: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
		if not hurry and warming != null and warming.act == _act and not warming.is_done():
			return
		step = Step.CATALOGUE
	if step == Step.CATALOGUE:
		var assets: MapLandscapeAssets = MapLandscapeAssets.for_act(_act) if hurry \
			else MapLandscapeAssets.prepare_step(_act)
		if assets == null:
			return
		if not _take(assets):
			step = Step.FAILED
			return
		step = Step.KIT
		if not hurry:
			return
	if step == Step.KIT:
		if hurry:
			MapJourneyLandscape.Kit.preload_scenes()
		elif not MapJourneyLandscape.Kit.preload_step():
			return
		_launch()
	elif step == Step.BUILDING and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_finish()


## What the worker needs from the act's catalogue; false when it is incomplete.
func _take(assets: MapLandscapeAssets) -> bool:
	_assets = assets
	_bundle = assets.bundle()
	_heroes = MapScene.hero_contract(assets.registry, assets.profiles,
		MapLandscapeAssets.GATES[_act], "vigil" if _act == 0 else "")
	_quality = WorldMapScreen.quality_registry()
	return not (_bundle.is_empty() or _heroes.is_empty() or _quality.is_empty())


func _launch() -> void:
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	_land = land
	_task = WorkerThreadPool.add_task(_build.bind(_out, land, _assets, _bundle, _heroes,
		_quality.duplicate(true), _nodes.duplicate(true), _edges.duplicate(true),
		_act, _seed, _salt), false, "journey land prefetch")
	step = Step.BUILDING


## On the worker: input, layout, the screen's scenery binding and the land,
## written into `out` as `[land, key, failure, input, input digest, packet,
## binding]`.
static func _build(out: Array, land: MapJourneyLandscape, assets: MapLandscapeAssets,
		bundle: Dictionary, heroes: Dictionary, quality: Dictionary, nodes: Array,
		edges: Array, act: int, run_seed: int, salt: int) -> void:
	out.append(land)
	var generator: Dictionary = MapLayoutPolicy.generator_fields(false)
	var input: MapLayoutInput = WorldMapScreen.layout_input(nodes, edges, act, run_seed,
		bundle, heroes, generator, quality)
	if input == null:
		out.append_array(["", "invalid input"])
		return
	var packet: Dictionary = MapLayoutPolicy.generate(input, quality, bundle)
	var result_v: Variant = packet.get("result", null)
	if not result_v is MapLayoutResult:
		out.append_array(["", "layout failed"])
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
	land.prepare(data, assets, salt)
	land.build_detached(data)
	out.append_array(["|".join([result.digest(), bundle["digest"], str(salt)]), land.failure,
		input, input_digest, packet, binding])


func _finish() -> void:
	var land: MapJourneyLandscape = _land
	_land = null
	key = str(_out[1])
	if key.is_empty() or not str(_out[2]).is_empty():
		land.free()
		step = Step.FAILED
		return
	MapScene.adopt_journey(key, land)
	var input: MapLayoutInput = _out[3]
	_input_digest = str(_out[4])
	_packet = _out[5]
	var binding: Dictionary = _out[6]
	if not binding.is_empty():
		MapScene.keep_binding(key, binding)
	WorldMapScreen.keep_input(WorldMapScreen.input_sources(_nodes, _edges, _act, _seed,
		str(_bundle["digest"]), _heroes, MapLayoutPolicy.generator_fields(false), _quality),
		input, _input_digest)
	step = Step.DONE
