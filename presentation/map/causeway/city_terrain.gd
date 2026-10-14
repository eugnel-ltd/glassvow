extends "res://presentation/map/landscape/terrain.gd"
## Act II's land: no ground, only the record's routes as causeways
## (`routes.gd`) standing in one still water sheet (`water.gd`). The archive's
## `act2/terrain.gd` (7d64678b) behind the woodland terrain's interface, so the
## journey (seated waystones, the pilgrim's walk) reads the decks as it reads
## Act I's land. It has no height grid: the decks answer every height.
const Routes = preload("res://presentation/map/causeway/routes.gd")
const Water = preload("res://presentation/map/causeway/water.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
var causeways: Routes
var water: Water
var _sample: Dictionary = {}


## Reads the source; cheap, on the calling thread.
func prepare(sample: Dictionary, grey: bool, extent: Rect2 = Rect2(-48,-30,96,60)) -> void:
	bounds = extent
	river_half_length = maxf(absf(extent.position.y), absf(extent.end.y))
	set_meta("world_bounds", bounds)
	greybox = grey
	source_edges = sample["edges"]
	anchors = sample["anchors"]
	_sample = sample
	for edge: Dictionary in source_edges.values():
		var points: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			points.append(Meshes.v3(point))
		lines.append(points)


## The land has no height grid to work out.
func start_heights(_parallel: bool = true, _threads: int = -1) -> void:
	build_timings_ms["heights"] = 0


func heights_ready() -> bool:
	return true


func finish_heights() -> void:
	pass


func ground_heights() -> Vector2:
	return Vector2(Presets.WATER, Presets.WATER)


## The causeways, then the water under them. Touches only this node's subtree.
func finish() -> void:
	var started: int = Time.get_ticks_msec()
	causeways = Routes.new()
	causeways.name = "Causeways"
	causeways.pacing = pacing
	add_child(causeways)
	causeways.build(_sample)
	build_timings_ms["causeways"] = Time.get_ticks_msec() - started
	build_timings_ms["causeway_parts"] = causeways.build_timings_ms
	failure = causeways.failure
	landform = causeways.levels
	if stopped() or not failure.is_empty():
		return
	started = Time.get_ticks_msec()
	water = Water.new()
	add_child(water)
	water.build(bounds)
	build_timings_ms["water"] = Time.get_ticks_msec() - started


## The deck at (x, z): the raised deck when asked for it (`upper`, or a point
## tagged above the ground) and standing on it, else the nearest deck.
func present(p: Vector3, upper: bool = false) -> Vector3:
	var preferred: int = 1 if upper or p.y > .015 else 0
	var nearest: float = INF
	var height: float = p.y
	for i: int in range(causeways.fields.size()):
		var query: Dictionary = causeways.fields[i].field(Vector2(p.x, p.z))
		var distance: float = query["distance"]
		if distance < nearest:
			nearest = distance
			height = query["height"]
		if i == preferred and distance < 0:
			return Vector3(p.x, MapLayoutCanonical.float_value(query["height"]), p.z)
	return Vector3(p.x, height, p.z)


func height_at(x: float, z: float) -> float:
	return present(Vector3(x, 0, z)).y


func surface_height(x: float, z: float) -> float:
	return height_at(x, z)


func route_height(p: Vector3) -> float:
	return present(p).y


func is_dry(p: Vector3) -> bool:
	return present(p).y > Presets.WATER


func is_elevated(p: Vector3) -> bool:
	return p.y > .015
