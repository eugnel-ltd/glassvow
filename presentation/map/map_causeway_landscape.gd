class_name MapCausewayLandscape
extends MapJourneyLandscape
## Act II's journey land, the Sunken City: the record's routes as masonry
## causeways on piers and arches over one still water sheet, the waystones
## seated on the decks and the pilgrim walking them. The archive's approved
## Act II (`chapters/act2`, `chapters/stone_bridge`; 7d64678b) revived on the
## production layout (#660 II.2), without its ruins (II.4), dressing (II.5) or
## final water, stone and light (II.3).
##
## Only a dev flag gives Act II this land (`MapJourneyProfile.DEV_FLAG`):
## players still see the painted Act II. Everything Act I's land does beyond
## the causeways and the journey (the woodland, its lamps and air, the floor's
## bake) stays Act I's.

const CityTerrain = preload("res://presentation/map/causeway/city_terrain.gd")


## Act II's placeholder light: the archive's native study's (`act2/run.gd`), a
## cool key from the south-east over a blue-grey fill, without Act I's grade
## or bloom. II.3 lights the act.
static func light(key: DirectionalLight3D, environment: Environment) -> void:
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("bacdda")
	key.light_energy = 1.1
	key.light_specular = 1.0
	key.shadow_enabled = true
	key.shadow_opacity = 0.65
	key.directional_shadow_max_distance = 70
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10252f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("85a9c4")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = false
	environment.adjustment_enabled = false
	environment.glow_enabled = false


func _begin(data: Dictionary, pacing: Meshes.Pacing) -> void:
	_source = Source.from_layout(data)
	terrain = CityTerrain.new()
	terrain.pacing = pacing
	add_child(terrain)
	terrain.prepare(_source, false, MAP_BOUNDS)


## The causeways and water, then the waystones seated on the decks and the
## pilgrim. On a worker, with the land outside the tree.
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
	for i: int in range(node_ids.size()):
		_seats[node_ids[i]] = journey.bases[i].position
	timings_ms["waystones"] = Time.get_ticks_msec() - started
