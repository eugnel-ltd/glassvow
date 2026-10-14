class_name MapCausewayLandscape
extends MapJourneyLandscape
## Act II's journey land, the Sunken City: the record's routes as masonry
## causeways on piers and arches over one still water sheet, the waystones
## seated on the decks and the pilgrim walking them. The archive's approved
## Act II (`chapters/act2`, `chapters/stone_bridge`; 7d64678b) revived on the
## production layout (#660 II.2), lit as a drowned library city at night
## (#660 II.3): slate-lavender masonry on its atlas, dark water mirroring the
## jade lanterns at every landing, teal light and drifting motes, and amber
## only where the pilgrim's flame is. Its ruins (II.4) and dressing (II.5)
## are still to come. Everything Act I's land does beyond the journey (the
## woodland, its kit and stone, the floor's bake) stays Act I's.

const CityTerrain = preload("res://presentation/map/causeway/city_terrain.gd")
const CityKit = preload("res://presentation/map/causeway/city_kit.gd")
const CityLamps = preload("res://presentation/map/causeway/city_lamps.gd")
const CityMask = preload("res://presentation/map/causeway/city_mask.gd")
## The lanterns' flame and glow, and the pilgrim's flame's pool's reach (m).
const JADE: Color = Color(0.32, 1.0, 0.64, 1.0)
const FLAME_REACH: float = 2.6

var lanterns: CityLamps
## Every material the pilgrim's flame lights (`set_traveller`).
var _lit: Array[ShaderMaterial] = []
var _flame: Color = Color(1.0, 0.55, 0.2)


## Act II's light: night over still water. A pale, cool moon low from the
## south-east keeps Act I's shadow direction; a teal fill lifts the masonry out
## of the dark; the grade cools and deepens the water; the bloom takes only the
## lanterns, their reflections and the flame. A lane pick, the owner's re-pick
## open (`docs/art-ledger.md`).
static func light(key: DirectionalLight3D, environment: Environment) -> void:
	key.rotation_degrees = KEY_ROTATION
	key.light_color = Color("a9c8dd")
	key.light_energy = 1.35
	key.light_specular = 0.8
	key.shadow_enabled = true
	key.shadow_opacity = 0.6
	key.directional_shadow_max_distance = 70
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("06171d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4d8f9c")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.fog_enabled = false
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.05
	environment.glow_enabled = true
	for level: int in range(7):
		# The half- and quarter-resolution levels only, as Act I's (measured free
		# on the A12).
		environment.set_glow_level(level, 1.0 if level < 2 else 0.0)
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.85


## Readies what Act II's builds draw with, a step at a time on the main thread
## (`MapJourneyLandscape.ready_kit`): the unit box the masonry appends, and the
## masonry atlas.
static func ready_kit(wait: bool = false) -> bool:
	Meshes.prepare_unit_box()
	return CityKit.prepare_step(wait)


## The tilt-shift's far haze: a cold mist off the water.
static func haze() -> Color:
	return Color(0.24, 0.42, 0.46)


## Reads back, before a title's first frame, the unit cube the masonry
## appends (`MapJourneyLandscape.prime_kit`); and the floor's bake pipelines,
## as every title warms them, for a later Act I.
static func prime_kit() -> void:
	Meshes.prepare_unit_box()
	LandFloor.Warm.warm()


## Lets go of what Act II's builds draw with (`MapJourneyLandscape.release_kit`).
static func release_kit() -> void:
	CityKit.release()


func _begin(data: Dictionary, pacing: Meshes.Pacing) -> void:
	_source = Source.from_layout(data)
	terrain = CityTerrain.new()
	terrain.pacing = pacing
	add_child(terrain)
	terrain.prepare(_source, false, MAP_BOUNDS)


## The causeways and water, then the waystones seated on the decks and the
## pilgrim, then the lanterns at the landings and the light mask the water and
## masonry read. On a worker, with the land outside the tree.
func _finish() -> void:
	var started: int = Time.get_ticks_msec()
	terrain.finish()
	timings_ms["terrain"] = Time.get_ticks_msec() - started
	timings_ms["terrain_parts"] = terrain.build_timings_ms
	if _halted():
		return
	if not terrain.failure.is_empty():
		failure = terrain.failure
		return
	started = Time.get_ticks_msec()
	var resolved: PackedVector3Array = PackedVector3Array()
	for point: Vector3 in anchors:
		resolved.append(terrain.present(point))
	journey = Journey.new()
	add_child(journey)
	journey.build(terrain, resolved, anchors)
	journey.set_process(false)
	journey.walker.visible = false
	var seats: Array[Vector3] = []
	var waits: Array[Vector3] = []
	for i: int in range(node_ids.size()):
		var seat: Vector3 = journey.bases[i].position
		_seats[node_ids[i]] = seat
		seats.append(seat)
		waits.append(journey.parked(seat))
	timings_ms["waystones"] = Time.get_ticks_msec() - started
	if _halted():
		return
	started = Time.get_ticks_msec()
	_light(seats, waits)
	timings_ms["light"] = Time.get_ticks_msec() - started


## The lanterns, their flames and the air, and the light mask bound to the
## water and every masonry material.
func _light(seats: Array[Vector3], waits: Array[Vector3]) -> void:
	var walks: Array[PackedVector3Array] = []
	for edge: Dictionary in terrain.source_edges.values():
		# Kept as `walking_route` keeps them: the map asks for them again.
		var walk: PackedVector3Array = walking_route(str(edge["from"]), str(edge["to"]))
		walks.append(walk)
	var city: CityTerrain = terrain as CityTerrain
	var fields: Array = city.causeways.fields
	var parts: Dictionary = city.causeways.materials
	var trim: Material = parts["trim"]
	lanterns = CityLamps.new()
	add_child(lanterns)
	lanterns.build(seats, walks, waits, fields, trim)
	var mask: CityMask = CityMask.new()
	var footprints: Array = city.causeways.footprints
	mask.build(MAP_BOUNDS, footprints, lanterns.anchors)
	var picture: ImageTexture = mask.texture()
	var materials: Array = parts.values()
	materials.append(city.water.material)
	for material: Material in materials:
		mask.bind(material, picture)
		if material is ShaderMaterial:
			_lit.append(material as ShaderMaterial)
	lamps = Lamps.new()
	add_child(lamps)
	lamps.build(lanterns.anchors, JADE)
	air = Air.new()
	add_child(air)
	air.build(true)


func set_traveller(at: Vector3, ahead: Vector3, moving: bool) -> void:
	super.set_traveller(at, ahead, moving)
	_light_walker(at)


func set_flame(colour: Color) -> void:
	super.set_flame(colour)
	_flame = colour
	if journey != null:
		_light_walker(journey.walker.position if journey.walker.visible else Vector3.INF)


## The pilgrim's flame lights the paving round him and is mirrored in the
## water; nothing where he is not on the land (`at` not finite).
func _light_walker(at: Vector3) -> void:
	var here: Vector4 = Vector4(at.x, at.y, at.z, FLAME_REACH) if at.is_finite() \
		else Vector4(0, -100, 0, FLAME_REACH)
	var colour: Color = _flame.srgb_to_linear()
	var glow: Vector4 = Vector4(colour.r, colour.g, colour.b, 1.0 if at.is_finite() else 0.0)
	for material: ShaderMaterial in _lit:
		material.set_shader_parameter("walker", here)
		material.set_shader_parameter("walker_colour", glow)
