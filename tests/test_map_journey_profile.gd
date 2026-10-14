extends RefCounted
## The per-act journey table (`MapJourneyProfile`) alone decides whether an act
## draws a journey land, of what class, under what light, at what gate and
## threshold, and whether the prefetch warms it. Act II is given a probe row
## here and nothing else (no scene, branch or constant names it), so a code
## path that still asks "is this Act I?" shows as a check that fails.

const SEED: int = 717
const PROBE_ENERGY: float = 7.25


## A land class that is not `MapJourneyLandscape` itself, to tell which class a
## row's act is given.
class ProbeLand extends MapJourneyLandscape:
	## How many lands of this class were prepared for a layout (the prefetch
	## prepares its dealer and its land: two).
	static var prepared: int = 0

	func prepare(data: Dictionary, catalogue: MapLandscapeAssets, salt: int) -> void:
		ProbeLand.prepared += 1
		super(data, catalogue, salt)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_journey_profile: %s" % what)


## The probe light: a key energy and a background colour no other light sets.
static func _probe_light(key: DirectionalLight3D, environment: Environment) -> void:
	key.light_energy = PROBE_ENERGY
	environment.background_color = Color("123456")


static func run(fails: Array[String]) -> void:
	_act_one_row(fails)
	_probe_row_routes_act_two(fails)
	_without_a_row_nothing_routes(fails)
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()


## Act I is the only row, and it carries what the map used to hard-code.
static func _act_one_row(fails: Array[String]) -> void:
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()
	_check(fails, MapJourneyProfile.has(0) and MapJourneyProfile.rows.size() == 1,
		"Act I is the only act with a journey row")
	_check(fails, MapJourneyProfile.land_class(0) == MapJourneyLandscape
			and MapJourneyProfile.warms(0)
			and MapJourneyProfile.gate_id(0) == "amber-tower"
			and MapJourneyProfile.threshold_id(0) == "vigil",
		"Act I's row: the journey land, warmed, its gate and its vigil")
	for act: int in range(1, 4):
		_check(fails, not MapJourneyProfile.has(act) and not MapJourneyProfile.warms(act)
				and MapJourneyProfile.gate_id(act) == MapLandscapeAssets.GATES[act]
				and MapJourneyProfile.threshold_id(act).is_empty(),
			"act %d keeps the painted landscape, its own gate and no threshold" % act)


## A row for Act II, and the scene and the prefetch follow it.
static func _probe_row_routes_act_two(fails: Array[String]) -> void:
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()
	MapJourneyProfile.rows[1] = MapJourneyProfile.Row.make(ProbeLand, _probe_light,
		"amber-tower", "vigil", true)
	var scene: MapScene = MapScene.new(1)
	_check(fails, scene.is_journey_act(), "a row makes its act a journey act")
	MapScene.journey_enabled = false
	_check(fails, not scene.is_journey_act(), "journey_enabled still turns every row off")
	MapScene.journey_enabled = true
	var land: MapLandscape = scene._new_landscape()
	_check(fails, land is ProbeLand, "the row's land class is the one drawn")
	land.free()
	var setting: WorldEnvironment = scene._world.get_node("MapEnvironment") as WorldEnvironment
	_check(fails, is_equal_approx(scene._key.light_energy, PROBE_ENERGY)
			and setting.environment.background_color == Color("123456"),
		"the row's light function lights the act")
	_check(fails, scene._terminus_id == "amber-tower" and scene._threshold_id == "vigil",
		"the row's gate and threshold are the act's")
	scene.free()
	_check(fails, MapLandscapeAssets.declared_ids(1) == _declared(1, ["vigil"]),
		"the row's threshold is an asset its act resolves")
	for act: int in [0, 2, 3]:
		_check(fails, MapLandscapeAssets.declared_ids(act) == _declared(act,
				["vigil"] if act == 0 else []),
			"act %d resolves its scenery, its gate and only the thresholds its row names" % act)

	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, SEED, "run-map-journey-profile")
	run.act = 1
	MapJourneyPrefetch.release()
	MapJourneyPrefetch.start(WorldMap.for_run(run, content), run)
	_check(fails, MapJourneyPrefetch._current != null and MapJourneyPrefetch._current._act == 1,
		"a row that warms has its act prefetched")
	_launched_land_class(fails)
	MapJourneyPrefetch.release()
	MapJourneyProfile.rows[1].warm = false
	MapJourneyPrefetch.start(WorldMap.for_run(run, content), run)
	_check(fails, MapJourneyPrefetch._current == null,
		"a row that does not warm has its act left alone")
	MapJourneyPrefetch.release()


## The ids an act declares: its scenery, its gate, then `thresholds`.
static func _declared(act: int, thresholds: Array) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(MapLandscapeAssets.SCENERY[act])
	ids.append(MapLandscapeAssets.GATES[act])
	ids.append_array(thresholds)
	return ids


## The started prefetch is launched unpaced (`hurry`), and both the land it
## builds and the dealer it deals the scenery with are of the row's class.
static func _launched_land_class(fails: Array[String]) -> void:
	var prefetch: MapJourneyPrefetch = MapJourneyPrefetch._current
	if prefetch == null:
		return
	# The build deals the row's gate out of its act's own profiles.
	MapJourneyProfile.rows[1].gate = MapLandscapeAssets.GATES[1]
	ProbeLand.prepared = 0
	MapJourneyPrefetch.hurry()
	_check(fails, prefetch.step == MapJourneyPrefetch.Step.BUILDING and prefetch._land is ProbeLand,
		"the prefetch builds the land of the row's class")
	if prefetch.step != MapJourneyPrefetch.Step.BUILDING:
		return
	WorkerThreadPool.wait_for_task_completion(prefetch._task)
	prefetch._task = -1
	_check(fails, ProbeLand.prepared == 2,
		"the prefetch deals its scenery with a land of the row's class too")
	prefetch._land.free()
	prefetch._land = null
	prefetch.step = MapJourneyPrefetch.Step.FAILED


## Taking Act I's row away turns all of it off at once.
static func _without_a_row_nothing_routes(fails: Array[String]) -> void:
	MapJourneyProfile.rows = {}
	var scene: MapScene = MapScene.new(0)
	_check(fails, not scene.is_journey_act(), "without a row Act I is no journey act")
	var land: MapLandscape = scene._new_landscape()
	_check(fails, not (land is MapJourneyLandscape), "without a row the painted land is drawn")
	land.free()
	_check(fails, scene._terminus_id == MapLandscapeAssets.GATES[0] and scene._threshold_id.is_empty(),
		"without a row Act I has its gate and no threshold")
	scene.free()
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, SEED, "run-map-journey-profile")
	MapJourneyPrefetch.start(WorldMap.for_run(run, content), run)
	_check(fails, MapJourneyPrefetch._current == null, "without a row Act I is not prefetched")
	MapJourneyPrefetch.release()
