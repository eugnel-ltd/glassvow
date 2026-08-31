extends RefCounted
## #461 Stage 2: compiled scenery is the sole contact-alpha authority.

const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")
const REAL_SEED: int = 717
const REAL_ACT: int = 0
const SYNTHETIC_RESOLUTION: Vector2i = Vector2i(64, 32)
const PAINTED_RESOLUTION: Vector2i = Vector2i(512, 256)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_grade_contact: %s" % what)


static func run(fails: Array[String]) -> void:
	var synthetic: PackedVector3Array = PackedVector3Array([
		_world_at_texel(Vector2i(12, 10), SYNTHETIC_RESOLUTION),
		_world_at_texel(Vector2i(13, 10), SYNTHETIC_RESOLUTION),
		_world_at_texel(Vector2i(48, 23), SYNTHETIC_RESOLUTION),
	])
	_assert_contract(fails, "synthetic positions", SYNTHETIC_RESOLUTION, synthetic)

	var compiled_origins: PackedVector3Array = _act_one_origins(fails)
	if not compiled_origins.is_empty():
		_assert_contract(fails, "Act I seed 717 compiled origins",
			PAINTED_RESOLUTION, compiled_origins)

	var empty: Image = MapMaterials.contact_alpha_image(
		PAINTED_RESOLUTION, PackedVector3Array())
	var all_unity: bool = true
	for y: int in range(empty.get_height()):
		for x: int in range(empty.get_width()):
			all_unity = all_unity and empty.get_pixel(x, y).a == 1.0
	_check(fails, all_unity, "an empty position set leaves alpha at unity everywhere")


static func _assert_contract(fails: Array[String], label: String,
		resolution: Vector2i, positions: PackedVector3Array) -> void:
	var compact: Image = MapMaterials.contact_alpha_image(resolution, positions)
	var minimum_under_each: bool = true
	var in_rect_count: int = 0
	for position: Vector3 in positions:
		if not _inside_grade_rect(position):
			continue
		in_rect_count += 1
		var texel: Vector2i = _texel_containing(position, resolution)
		minimum_under_each = minimum_under_each \
			and compact.get_pixelv(texel).a <= 0.19
	_check(fails, in_rect_count > 0 and minimum_under_each,
		"%s reaches the contact floor under every in-rect placement" % label)

	var far_texels_are_unity: bool = true
	var every_non_unity_texel_has_an_origin: bool = true
	for y: int in range(resolution.y):
		for x: int in range(resolution.x):
			var world: Vector2 = _world_xz(Vector2i(x, y), resolution)
			var nearest: float = INF
			for position: Vector3 in positions:
				nearest = minf(nearest,
					world.distance_to(Vector2(position.x, position.z)))
			var alpha: float = compact.get_pixel(x, y).a
			if nearest >= MapMaterials.CONTACT_OUTER_RADIUS:
				far_texels_are_unity = far_texels_are_unity and alpha == 1.0
			if alpha < 1.0:
				every_non_unity_texel_has_an_origin = \
					every_non_unity_texel_has_an_origin \
					and nearest < MapMaterials.CONTACT_OUTER_RADIUS
	_check(fails, far_texels_are_unity,
		"%s leaves every texel outside compact support at unity" % label)
	_check(fails, every_non_unity_texel_has_an_origin,
		"%s has no contact texel without a placement inside 1.75 m" % label)

	var reference: Image = _full_image_reference(resolution, positions)
	_check(fails, compact.get_data() == reference.get_data(),
		"%s compact-support bake is byte-equal to a full-image walk" % label)


static func _full_image_reference(resolution: Vector2i,
		positions: PackedVector3Array) -> Image:
	var image: Image = Image.create_empty(
		resolution.x, resolution.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	for y: int in range(resolution.y):
		for x: int in range(resolution.x):
			var world: Vector2 = _world_xz(Vector2i(x, y), resolution)
			var alpha: float = 1.0
			for position: Vector3 in positions:
				var distance: float = world.distance_to(
					Vector2(position.x, position.z))
				alpha = minf(alpha, MapMaterials.contact_alpha_at(distance))
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return image


static func _act_one_origins(fails: Array[String]) -> PackedVector3Array:
	var quality_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	if not quality_v is Dictionary:
		_check(fails, false, "map quality registry is readable")
		return PackedVector3Array()
	var quality: Dictionary = quality_v
	var content: ContentDB = ContentDB.load_full()
	var scene: MapScene = MapScene.new()
	scene.set_scatter_salt(REAL_SEED)
	scene.set_act(REAL_ACT)
	var assets: Dictionary = scene.layout_asset_bundle()
	var heroes: Dictionary = scene.layout_hero_contract()
	var run_state: RunState = RunState.new_run(content, REAL_SEED,
		"map-grade-contact-%d" % REAL_SEED)
	run_state.act = REAL_ACT
	var world: WorldMap = WorldMap.for_run(run_state, content)
	var bound: Dictionary = Binding.bind(world, REAL_ACT)
	if bound.get("ok", false) != true:
		_check(fails, false, "Act I seed 717 production graph records bind")
		scene.free()
		return PackedVector3Array()
	var nodes: Array = bound["nodes"]
	var edges: Array = bound["edges"]
	var input: MapLayoutInput = _input(nodes, edges, heroes, quality, assets)
	var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
	var result_v: Variant = compiled.get("result", null)
	if str(compiled.get("status", "")) != MapLayoutCompiler.COMPILED \
			or not result_v is MapLayoutResult:
		_check(fails, false, "Act I seed 717 compiles for the real-origin contract")
		scene.free()
		return PackedVector3Array()
	var result: MapLayoutResult = result_v
	var scenery: Dictionary = result.to_dict()["scenery_instances"]
	var origins: PackedVector3Array = PackedVector3Array()
	for placement_id: String in MapLayoutCanonical.sorted_keys(scenery):
		var placement: Dictionary = scenery[placement_id]
		var transform: Dictionary = placement["transform"]
		var origin_values: Array = transform["origin"]
		origins.append(_v3(origin_values))
	_check(fails, not origins.is_empty(),
		"Act I seed 717 supplies non-empty compiled scenery origins")
	scene.free()
	return origins


static func _input(nodes: Array, edges: Array, heroes: Dictionary,
		quality: Dictionary, assets: Dictionary) -> MapLayoutInput:
	return MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2",
		"generator_version": MapLayoutCompiler.VERSION,
		"nodes": nodes,
		"edges": edges,
		"act": REAL_ACT,
		"run_seed": REAL_SEED,
		"scenery_seed": REAL_SEED + WorldMapScreen.SCENERY_SEED_OFFSET,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(
			nodes, quality, edges)["digest"],
		"hero_anchor_contract": heroes,
		"quality_registry_digest": MapLayoutCanonical.digest(quality),
	})


static func _world_at_texel(texel: Vector2i, resolution: Vector2i) -> Vector3:
	var world: Vector2 = _world_xz(texel, resolution)
	return Vector3(world.x, 0.0, world.y)


static func _world_xz(texel: Vector2i, resolution: Vector2i) -> Vector2:
	return Vector2(
		MapMaterials.GRADE_MIN.x + (float(texel.x) + 0.5) \
			/ float(resolution.x) * MapMaterials.GRADE_SIZE.x,
		MapMaterials.GRADE_MIN.y + (float(texel.y) + 0.5) \
			/ float(resolution.y) * MapMaterials.GRADE_SIZE.y)


static func _texel_containing(position: Vector3,
		resolution: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(floori((position.x - MapMaterials.GRADE_MIN.x)
			/ MapMaterials.GRADE_SIZE.x * float(resolution.x)), 0, resolution.x - 1),
		clampi(floori((position.z - MapMaterials.GRADE_MIN.y)
			/ MapMaterials.GRADE_SIZE.y * float(resolution.y)), 0, resolution.y - 1))


static func _inside_grade_rect(position: Vector3) -> bool:
	return position.x >= MapMaterials.GRADE_MIN.x \
		and position.x < MapMaterials.GRADE_MIN.x + MapMaterials.GRADE_SIZE.x \
		and position.z >= MapMaterials.GRADE_MIN.y \
		and position.z < MapMaterials.GRADE_MIN.y + MapMaterials.GRADE_SIZE.y


static func _v3(values: Array) -> Vector3:
	return Vector3(
		MapLayoutCanonical.float_value(values[0]),
		MapLayoutCanonical.float_value(values[1]),
		MapLayoutCanonical.float_value(values[2]))
