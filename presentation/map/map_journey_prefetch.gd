class_name MapJourneyPrefetch
extends RefCounted
## Builds Act I's journey land before its map opens, the way
## `MapLandscapeAssets.prefetch` decodes an act's pictures before it opens.
##
## `Main` starts it whenever it routes a run into the journey act and steps it
## every frame. It waits for the act's pictures, takes the catalogue's profiles
## and hero contract on the main thread (milliseconds once the pictures are
## decoded), then builds the canonical layout input, lays the layout out with
## the production generator and builds the land on one worker-pool task. The
## finished land is handed to `MapScene` as its kept land under the binding key
## the screen will ask for, so the first open re-parents it instead of building.
## One prefetch at a time; a newer one drops the older.

enum Step { WAITING_PICTURES, BUILDING, DONE, FAILED }

static var _current: MapJourneyPrefetch = null

var step: Step = Step.WAITING_PICTURES
## The binding key `MapScene.bind_layout` will use for this layout.
var key: String = ""
var _act: int = 0
var _seed: int = 0
var _salt: int = 0
var _nodes: Array = []
var _edges: Array = []
var _task: int = -1
var _out: Array = []
var _land: MapJourneyLandscape = null


## Starts a prefetch of `map`'s land for `run`, when its act is the journey act
## and nothing is already prefetched or prefetching for it.
static func start(map: WorldMap, run: RunState) -> void:
	if map == null or run == null or run.act != 0:
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


## Advances the current prefetch; Main calls it every frame.
static func step_current() -> void:
	if _current != null:
		_current._advance()


## Whether a prefetch is still waiting or building; its land's key is known
## only once it is built, so a screen that opens meanwhile waits to see.
static func busy() -> bool:
	return _current != null and _current.step in [Step.WAITING_PICTURES, Step.BUILDING]


## Ends any prefetch (a test or bench dropping every cache).
static func release() -> void:
	_drop()


## Gives up the current prefetch. Its worker is never waited on here: the land
## it builds is abandoned to `MapScene.reap`, which frees it once the task ends.
static func _drop() -> void:
	if _current != null and _current._land != null and _current.step == Step.BUILDING:
		_current._land.adopt_task(_current._task)
		MapScene.abandon(_current._land)
	_current = null


func _same(other: MapJourneyPrefetch) -> bool:
	return _act == other._act and _seed == other._seed and _nodes == other._nodes \
		and _edges == other._edges


func _advance() -> void:
	match step:
		Step.WAITING_PICTURES:
			var warming: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
			if warming != null and warming.act == _act and not warming.is_done():
				return
			_begin()
		Step.BUILDING:
			if WorkerThreadPool.is_task_completed(_task):
				WorkerThreadPool.wait_for_task_completion(_task)
				_task = -1
				_finish()


func _begin() -> void:
	var assets: MapLandscapeAssets = MapLandscapeAssets.for_act(_act)
	var bundle: Dictionary = assets.bundle()
	var heroes: Dictionary = MapScene.hero_contract(assets.registry, assets.profiles,
		MapLandscapeAssets.GATES[_act], "vigil" if _act == 0 else "")
	var quality: Dictionary = WorldMapScreen.quality_registry()
	if bundle.is_empty() or heroes.is_empty() or quality.is_empty():
		step = Step.FAILED
		return
	MapJourneyLandscape.Kit.preload_scenes()
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	_land = land
	_task = WorkerThreadPool.add_task(_build.bind(_out, land, assets, bundle, heroes,
		quality.duplicate(true), _nodes.duplicate(true), _edges.duplicate(true),
		_act, _seed, _salt), false, "journey land prefetch")
	step = Step.BUILDING


## On the worker: input, layout and land, written into `out` as
## `[land, key, failure]`.
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
	var result: MapLayoutResult = result_v
	var data: Dictionary = result.identity_dict()
	land.prepare(data, assets, salt)
	land.build_detached(data)
	out.append_array(["|".join([result.digest(), bundle["digest"], str(salt)]), land.failure])


func _finish() -> void:
	var land: MapJourneyLandscape = _land
	key = str(_out[1])
	if key.is_empty() or not str(_out[2]).is_empty():
		land.free()
		step = Step.FAILED
		return
	MapScene.adopt_journey(key, land)
	step = Step.DONE
