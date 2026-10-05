class_name MapJourneyLandscape
extends MapLandscape
## Act I's journey woodland: the owner-approved landscape of the September
## rebuild (Review 10; archived at 7d64678b), revived on the production layout.
##
## Presentation only. `MapScene` keeps MapLayoutFast's record, its scenery
## filter and every digest; this node reads that record (through
## `layout_source.gd`) and draws the land, the river, the bridges, the woodland
## kit, the seated waystones and the pilgrim. The base class still prepares the
## record's anchors and scenery candidates, so the governed filter runs exactly
## as it does for the other acts; only its painted cards are not drawn here.

const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const Kit = preload("res://presentation/map/landscape/kit.gd")
const Journey = preload("res://presentation/map/landscape/journey.gd")
const Details = preload("res://presentation/map/landscape/road_details.gd")
const Source = preload("res://presentation/map/landscape/layout_source.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Lamps = preload("res://presentation/map/landscape/lamps.gd")
const LandMotion = preload("res://presentation/map/landscape/land_motion.gd")
const Air = preload("res://presentation/map/landscape/air.gd")
const ImpostorWood = preload("res://presentation/map/landscape/impostor_wood.gd")
const LandFloor = preload("res://presentation/map/landscape/land_floor.gd")
const MAP_BOUNDS: Rect2 = Rect2(-48, -30, 96, 60)
## Act I's key light (`light`): low from the south-east, as the target's.
const KEY_ROTATION: Vector3 = Vector3(-52, -32, 0)
const LIT_GLASS: Color = Color("b38d57")
const LIT_EMISSION: Color = Color("aa7841")
const COLD_GLASS: Color = Color("49424f")
## The failure of a build given up before it ended (`Meshes.Pacing.stopped`).
const STOPPED: String = "Stopped: no map waits for this land"
## How many pool threads work a paced build's heights out: behind the launch
## rite the title's warm-up builds the land the player may ask for as the rite
## lands (#660), and the heights need no renderer, so two threads take them,
## leaving the rest of the pool to the rite and the title.
const PACED_HEIGHT_THREADS: int = 2

var terrain: Terrain
var kit: Kit
var journey: Journey
var lamps: Lamps
var air: Air
var wood: ImpostorWood
## The ground drawn from its bake once baked (R3.2; `floor_step`).
var forest_floor: LandFloor
var failure: String = ""
var timings_ms: Dictionary = {}
## The record's node id to its waystone's seat on the rendered surface.
var _seats: Dictionary = {}
var _walks: Dictionary = {}
var _curves: Dictionary = {}
var _travel_distance: float = 0.0
enum Stage { IDLE, HEIGHTS, REST, DONE }
var _stage: Stage = Stage.IDLE
var _task: int = -1
var _started: int = 0
var _source: Dictionary = {}
var _was_moving: bool = false


## Act I's light (R2): the golden hour of the owner's target
## (`docs/design/2026-10-02-map-living-land/target/`): a warm low key, cool sky
## fill in the shadows, a little more saturation, and a two-level bloom that
## only the flames and their brightest pools reach. Review 10's workshop light
## (key `ddd7d2` at 0.95, ambient `a19caa` at 0.5, no grade) is the R1 base.
static func light(key: DirectionalLight3D, environment: Environment) -> void:
	key.rotation_degrees = KEY_ROTATION
	key.light_color = Color("ffd1a0")
	key.light_energy = 1.6
	key.light_specular = 1.0
	key.shadow_enabled = true
	key.shadow_opacity = 0.72
	key.directional_shadow_max_distance = 70
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2a2427")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7d86a8")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = false
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.2
	environment.adjustment_saturation = 1.18
	environment.glow_enabled = true
	for level: int in range(7):
		# The half- and quarter-resolution levels only: measured free on the A12.
		environment.set_glow_level(level, 1.0 if level < 2 else 0.0)
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.95


## The whole build on the calling thread (tests, tools, captures).
func build(data: Dictionary) -> void:
	start(data)
	terrain.finish_heights()
	_finish()
	_stage = Stage.DONE


## The whole build from a worker-pool task (`MapJourneyPrefetch`), with the
## node outside the tree. The kit's scenes must already be held
## (`Kit.preload_scenes`, on the main thread). `pacing` is how the build hands
## its meshes to the renderer: unpaced (a map is waiting for the land), the
## heights are worked out across the whole pool, as a map's own build works
## them out, and paced (behind the launch rite or the lit title) across
## `PACED_HEIGHT_THREADS` of it, each only on a pool with threads to spare
## (`Terrain.pool_spares_threads`; otherwise on the build's own thread); and a
## build given up (`stopped`) ends after its current stage, as a failure
## nothing adopts.
func build_detached(data: Dictionary, pacing: Meshes.Pacing = null) -> void:
	_started = Time.get_ticks_msec()
	_begin(data, pacing)
	var spread: bool = pacing != null and Terrain.pool_spares_threads()
	terrain.start_heights(spread, PACED_HEIGHT_THREADS if spread and pacing.on else -1)
	_stage = Stage.HEIGHTS
	terrain.finish_heights()
	if not _halted():
		_finish()
	_stage = Stage.DONE
	timings_ms["total"] = Time.get_ticks_msec() - _started


## Begins a build: the cheap preparation here, the land's heights on the
## worker pool. `poll` carries it on; the node must stay outside the tree until
## `poll` reports done, because the rest is built on a worker. Unpaced, and
## given up as a prefetch's build is (`give_up`).
func start(data: Dictionary, parallel: bool = true) -> void:
	_started = Time.get_ticks_msec()
	if parallel:
		Kit.preload_scenes()
	var pacing: Meshes.Pacing = Meshes.Pacing.new()
	pacing.on = false
	_begin(data, pacing)
	terrain.start_heights(parallel)
	_stage = Stage.HEIGHTS


## The cheap preparation every build begins with: the record's source and the
## terrain's landform.
func _begin(data: Dictionary, pacing: Meshes.Pacing) -> void:
	_source = Source.from_layout(data)
	terrain = Terrain.new()
	terrain.lite_surfaces = MapScene.lean_profile()
	terrain.pacing = pacing
	add_child(terrain)
	terrain.prepare(_source, false, MAP_BOUNDS)


## Whether the build was given up (`build_detached`); it then fails as
## `STOPPED` and is left incomplete.
func _halted() -> bool:
	if terrain == null or not terrain.stopped():
		return false
	failure = STOPPED
	return true


## Advances an asynchronous build; true once it has finished (or failed).
func poll() -> bool:
	if _stage == Stage.HEIGHTS and terrain.heights_ready():
		terrain.finish_heights()
		_task = WorkerThreadPool.add_task(_finish, true, "journey landscape")
		_stage = Stage.REST
	if _stage == Stage.REST and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_stage = Stage.DONE
		timings_ms["total"] = Time.get_ticks_msec() - _started
	return _stage == Stage.DONE


## Whether a worker may still be writing into this land. No frame waits on
## that task: a land given up mid-build is freed once its task ends
## (`MapScene.reap`). Only a land whose screen is going waits (`give_up`).
func busy() -> bool:
	if _task >= 0:
		return not WorkerThreadPool.is_task_completed(_task)
	if _stage == Stage.HEIGHTS:
		terrain.finish_heights()
		_stage = Stage.DONE
	return false


## Takes over a task another owner started on this land (`MapJourneyPrefetch`),
## so `busy` and `settle` answer for it.
func adopt_task(task: int) -> void:
	_task = task
	_stage = Stage.REST


## Gives the build up (it ends after its current stage, as a failure nothing
## adopts) and waits for its worker, so the land can be freed at once. The
## worker reads nothing back from the renderer, so it never waits on the main
## thread that waits on it here (`MapScene`'s predelete).
func give_up() -> void:
	if terrain != null and terrain.pacing != null:
		terrain.pacing.stop()
	settle()


## Ends the bookkeeping of a finished task so the land can be freed.
func settle() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func is_started() -> bool:
	return _stage != Stage.IDLE


func is_built() -> bool:
	return _stage == Stage.DONE


func _finish() -> void:
	var started: int = Time.get_ticks_msec()
	terrain.finish()
	timings_ms["terrain"] = Time.get_ticks_msec() - started
	timings_ms["terrain_parts"] = terrain.build_timings_ms
	if _halted():
		return
	started = Time.get_ticks_msec()
	var resolved: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in anchors:
		resolved.append(terrain.present(point))
	kit = Kit.new()
	kit.use_static_batches = true
	add_child(kit)
	var heroes: Dictionary = _source["heroes"]
	kit.build(terrain, resolved, false, heroes)
	if not kit.build_complete or not kit.failure.is_empty():
		failure = kit.failure if not kit.failure.is_empty() else "Woodland assembly incomplete"
		return
	# Without its atlas (`ImpostorWood.Atlas.failed`, reported once) the land
	# opens without its woodland rather than not at all.
	if ImpostorWood.Atlas.ready():
		var planted: int = Time.get_ticks_msec()
		wood = ImpostorWood.new()
		add_child(wood)
		wood.build(kit, terrain, resolved)
		timings_ms["wood"] = Time.get_ticks_msec() - planted
	lamps = Lamps.new()
	add_child(lamps)
	lamps.build(kit.lamp_anchors())
	air = Air.new()
	add_child(air)
	air.build()
	timings_ms["scenery"] = Time.get_ticks_msec() - started
	if _halted():
		return
	started = Time.get_ticks_msec()
	Details.build(terrain)
	timings_ms["road_details"] = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	journey = Journey.new()
	add_child(journey)
	journey.build(terrain, resolved, anchors)
	journey.set_process(false)
	journey.walker.visible = false
	for i: int in range(node_ids.size()):
		_seats[node_ids[i]] = journey.bases[i].position
	timings_ms["waystones"] = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	forest_floor = LandFloor.new()
	add_child(forest_floor)
	forest_floor.prepare(self)
	timings_ms["floor_plan"] = Time.get_ticks_msec() - started


## Carries the floor's bake on by a frame (main thread, behind the veil); true
## once the floor has settled, baked or left painted (`LandFloor`).
func floor_step() -> bool:
	return forest_floor == null or forest_floor.step(self)


## Where node `id`'s waystone actually stands, or `fallback` before a build.
func seat(id: String, fallback: Vector3) -> Vector3:
	return _seats.get(id, fallback)


func set_node_states(states: Dictionary) -> void:
	if journey == null:
		return
	for i: int in range(node_ids.size()):
		var state: String = str(states.get(node_ids[i], "cold"))
		var lit: bool = state in ["current", "open"]
		journey.glasses[i].albedo_color = LIT_GLASS if lit else COLD_GLASS
		journey.glasses[i].emission = LIT_EMISSION if lit else Color.BLACK


## Gives the land's real lamp lights to the lanterns nearest `at`, and centres
## the drifting air there.
func focus_lamps(at: Vector3) -> void:
	if lamps != null and at.is_finite():
		lamps.focus(at)
		air.focus(at)


## The walkable route from waystone `from_id` to `to_id`: the road graded onto
## the land and around both stones. Empty when no road joins them.
func walking_route(from_id: String, to_id: String) -> PackedVector3Array:
	var key: String = from_id + ">" + to_id
	if not _walks.has(key):
		_walks[key] = journey.path(from_id, to_id) if journey != null else PackedVector3Array()
	return _walks[key]


func travel_position(from_id: String, to_id: String, progress: float) -> Vector3:
	var curve: Curve3D = _curve(from_id, to_id)
	if curve.point_count == 0:
		return Vector3.INF
	return curve.sample_baked(clampf(progress, 0.0, 1.0) * curve.get_baked_length())


func travel_duration(from_id: String, to_id: String) -> float:
	return clampf(_curve(from_id, to_id).get_baked_length() / 3.5, 0.7, 4.5)


## Stands the pilgrim at `at`, facing `ahead`; `moving` swings its stride.
func set_traveller(at: Vector3, ahead: Vector3, moving: bool) -> void:
	if journey == null:
		return
	journey.walker.visible = at.is_finite()
	if forest_floor != null:
		forest_floor.set_walker(at, at.is_finite())
	if not at.is_finite():
		return
	if moving and _was_moving:
		_travel_distance += journey.walker.position.distance_to(at)
	else:
		_travel_distance = 0.0
	_was_moving = moving
	journey.walker.position = at
	if moving and at.distance_to(ahead) > 0.001:
		journey.walker.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
	journey.walker.pose(_travel_distance, moving)


func set_flame(colour: Color) -> void:
	if journey != null:
		journey.walker.set_flame(colour)
	if forest_floor != null:
		forest_floor.set_flame(colour)


## Where the pilgrim waits beside waystone `id`.
func parked(id: String, fallback: Vector3) -> Vector3:
	if journey == null:
		return fallback
	return journey.parked(seat(id, fallback))


func _curve(from_id: String, to_id: String) -> Curve3D:
	var key: String = from_id + ">" + to_id
	if not _curves.has(key):
		var curve: Curve3D = Curve3D.new()
		curve.bake_interval = 0.06
		for point: Vector3 in walking_route(from_id, to_id):
			curve.add_point(point)
		_curves[key] = curve
	return _curves[key]
