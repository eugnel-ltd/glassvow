extends RefCounted
## Act I's floor drawn from its bake (R3.2, issue #660), held where the
## headless suite can hold it: the bake's tiling and mip chain, the plan its
## frames read (every lamp, a shadow card for every tree turned to the key,
## a stamp for every plant, stone and seat, the ground's heights), the private
## world it draws (the ground twice, what casts, the key and sky as the live
## land's), the fallback where no renderer can bake (the painted ground and
## every live shadow kept), what the floor gives up once baked (the shadows
## that fell only on the ground, the road's small details, the pilgrim's own
## shadow for a blob), the prefetch holding its land until the floor settles,
## and the floor's shaders: the pools flicker with their own flame's phase and
## hold still, with the glints, under Reduce Motion; and the warm-up, which
## draws a sample of every pipeline they use before the title shows.
## The GPU half (the bake's pictures, copies and mips) is the windowed proof's:
## `tools/check_floor_bake.gd`.

const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
const Plan = preload("res://presentation/map/landscape/floor_plan.gd")
const Stage = preload("res://presentation/map/landscape/floor_stage.gd")
const LandFloor = preload("res://presentation/map/landscape/land_floor.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Details = preload("res://presentation/map/landscape/road_details.gd")
const Pilgrim = preload("res://presentation/map/landscape/pilgrim.gd")
const Warm = preload("res://presentation/map/landscape/floor_warm.gd")
const SEED: int = 717
## What R3.2 keeps casting live once the floor is baked: the gateway and the
## rock outcrops (the bridges' parapets aside), named here apart from the code.
const HEROES: PackedStringArray = ["amber-arch", "slate-bank", "slate-ridge", "slate-shard"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_floor: %s" % what)


static func run(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	_tiles(fails)
	_mips(fails)
	_shaders(fails)
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = RunState.new_run(content, SEED, "run-map-floor")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(run_state, content), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.set_shape(StageShape.IDENTITY)
	screen.refresh(run_state)
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	_check(fails, land != null and land.is_built() and land.forest_floor != null,
		"Act I's land is built with its floor's plan")
	if land != null and land.is_built() and land.forest_floor != null:
		_plan(fails, land)
		_stage(fails, land)
		_painted(fails, screen, land)
		_baked(fails, land)
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()
	_blob(fails)
	_warm(fails)


## The lit picture's tiles cover it exactly, none over the limit, none apart.
static func _tiles(fails: Array[String]) -> void:
	for size: Vector2i in [Vector2i(1920, 1200), Vector2i(1931, 1207), Vector2i(500, 300)]:
		var tiles: Array[Rect2i] = Bake.tiles(size, Bake.TILE_LIMIT)
		var area: int = 0
		var inside: bool = true
		var apart: bool = true
		for i: int in range(tiles.size()):
			var tile: Rect2i = tiles[i]
			area += tile.get_area()
			inside = inside and Rect2i(Vector2i.ZERO, size).encloses(tile) \
				and tile.size.x <= Bake.TILE_LIMIT.x and tile.size.y <= Bake.TILE_LIMIT.y
			for j: int in range(i + 1, tiles.size()):
				apart = apart and not tile.intersects(tiles[j])
		_check(fails, area == size.x * size.y and inside and apart,
			"the bake's tiles cover a %dx%d picture exactly, each within the limit" % [size.x, size.y])
	var bounds: Rect2 = MapJourneyLandscape.MAP_BOUNDS
	var act: Vector2i = Vector2i(ceili(bounds.size.x * Bake.LIT_TEXELS_PER_M), ceili(bounds.size.y * Bake.LIT_TEXELS_PER_M))
	_check(fails, Bake.tiles(act, Bake.TILE_LIMIT).size() == 4 and Bake.TILES_A_FRAME == 2,
		"Act I's picture bakes in four tiles, two a frame")


## The mip chain runs from the picture's size down to a texel, halving.
static func _mips(fails: Array[String]) -> void:
	var size: Vector2i = Vector2i(1920, 1200)
	_check(fails, Bake.mip_count(size) == 11 and Bake.mip_size(size, 1) == Vector2i(960, 600)
		and Bake.mip_size(size, 7) == Vector2i(15, 9) and Bake.mip_size(size, 10) == Vector2i(1, 1),
		"the lit picture's mip chain halves to one texel in 11 levels")


## The floor's shaders: the pools flicker with the flame (its wave and its
## phase, worked out as the flame works it out) and, with the glints, hold
## still under Reduce Motion; standing water is the ground made darker, never a
## colour of its own; the Close grain is full at a Journey's Close and gone at
## the Journey itself; no sampler the A12's Metal cannot bind.
static func _shaders(fails: Array[String]) -> void:
	var flame: String = (load("res://presentation/map/landscape/flame.gdshader") as Shader).code
	var ground: String = FileAccess.get_file_as_string("res://presentation/map/landscape/floor_ground.gdshaderinc")
	var live: String = (load("res://presentation/map/landscape/floor.gdshader") as Shader).code
	_check(fails, flame.contains("fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453)")
		and ground.contains("fract(sin(dot(at, vec2(12.9898, 78.233))) * 43758.5453)"),
		"a pool's flicker phase is its own flame's")
	_check(fails, flame.contains("sin(TIME * 9.0 + phase * 40.0)")
		and live.contains("sin(TIME * 9.0 + kept.g * 40.0) * land_motion"),
		"a pool flickers with its flame's wave and holds still with the land's motion")
	_check(fails, live.contains("global uniform float land_motion;")
		and live.contains("twinkle * twinkle * land_motion"),
		"the puddles' glints go out with the land's motion")
	_check(fails, live.contains("render_mode unshaded") and live.contains("shadows_disabled"),
		"the floor is unshaded and takes no live shadow")
	_check(fails, live.contains("colour *= mix(1.0, water_dark, water);")
		and not live.contains("sky_colour") and not live.contains("colour = mix(colour,"),
		"standing water darkens the ground it lies on and lays no colour over it")
	var heights: Vector2 = _uniform_vec2(live, "close_heights")
	var journey: float = MapJourneyCameraContract.PREFERRED_ZOOM
	_check(fails, heights.x >= journey * MapJourneyView.CLOSE_FACTOR and heights.y < journey
		and live.contains("length(dFdx(at)) * VIEWPORT_SIZE.y"),
		"the Close grain is full at Close (%.2f m) and gone at Journey (%.1f m): %s" % [
			journey * MapJourneyView.CLOSE_FACTOR, journey, heights])
	for path: String in ["res://presentation/map/landscape/floor.gdshader",
			"res://presentation/map/landscape/floor_paint.gdshader",
			"res://presentation/map/landscape/floor_mask.gdshader",
			"res://presentation/map/landscape/floor_caster.gdshader"]:
		var code: String = (load(path) as Shader).code
		_check(fails, not code.contains("anisotropic"),
			"%s binds no anisotropic sampler (the A12's sampler slots)" % path.get_file())


## A `uniform vec2 <name> = vec2(x, y);` default in `code`, or NaN.
static func _uniform_vec2(code: String, name: String) -> Vector2:
	var found: RegExMatch = RegEx.create_from_string("uniform vec2 %s = vec2\\(([0-9.]+), ([0-9.]+)\\);" % name).search(code)
	if found == null:
		return Vector2(NAN, NAN)
	return Vector2(float(found.get_string(1)), float(found.get_string(2)))


## The plan the bake reads: every lamp, a card for every tree facing the key
## and standing on its base, a stamp for every plant, stone and seat inside
## the 2D pass, and the ground's heights.
static func _plan(fails: Array[String], land: MapJourneyLandscape) -> void:
	var plan: Plan = land.forest_floor.plan
	var anchors: PackedVector3Array = land.lamps.anchors
	var lamps_ok: bool = plan.lamps.size() == mini(anchors.size(), Plan.MOST_LAMPS) and not anchors.is_empty()
	for i: int in range(plan.lamps.size()):
		lamps_ok = lamps_ok and Vector3(plan.lamps[i].x, plan.lamps[i].y, plan.lamps[i].z).is_equal_approx(anchors[i])
	_check(fails, lamps_ok, "the plan holds every lamp's flame")
	var planting: Planting = land.wood.planting
	var trees: PackedInt32Array = PackedInt32Array()
	var shrubs: int = 0
	for i: int in range(planting.kinds.size()):
		if Planting.TREES.has(planting.kinds[i]):
			trees.append(i)
		else:
			shrubs += 1
	_check(fails, plan.caster_count == trees.size() and trees.size() > 0
		and plan.casters.size() == trees.size() * 20, "a shadow card for every tree and none for undergrowth")
	var toward: Vector3 = Plan.toward_key(MapJourneyLandscape.KEY_ROTATION)
	var key: Basis = Basis.from_euler(MapJourneyLandscape.KEY_ROTATION * (PI / 180.0))
	_check(fails, toward.dot(key.z) > 0.5 and is_zero_approx(toward.y) and is_equal_approx(toward.length(), 1.0),
		"the cards face the key light along the ground")
	var cards_ok: bool = true
	for k: int in range(trees.size()):
		var i: int = trees[k]
		var at: int = k * 20
		var x_axis: Vector3 = Vector3(plan.casters[at], plan.casters[at + 4], plan.casters[at + 8])
		var y_axis: Vector3 = Vector3(plan.casters[at + 1], plan.casters[at + 5], plan.casters[at + 9])
		var normal: Vector3 = Vector3(plan.casters[at + 2], plan.casters[at + 6], plan.casters[at + 10])
		var corner: Vector3 = Vector3(plan.casters[at + 3], plan.casters[at + 7], plan.casters[at + 11])
		var tile: int = planting.tiles[i]
		var s: float = planting.scales[i]
		var foot: Vector3 = corner + y_axis
		var rect: Vector4 = Atlas.uv[tile]
		cards_ok = cards_ok and normal.is_equal_approx(toward) and absf(x_axis.dot(toward)) < 0.0001 \
			and is_zero_approx(x_axis.y) and is_equal_approx(-y_axis.y, Atlas.top[tile] * s) \
			and is_zero_approx(y_axis.x) and is_zero_approx(y_axis.z) \
			and is_equal_approx(foot.y, planting.bases[i].y) \
			and is_equal_approx(x_axis.length(), Atlas.size[tile].x * s) \
			and is_equal_approx(plan.casters[at + 15], -Atlas.low[tile].y / Atlas.size[tile].y) \
			and Vector4(plan.casters[at + 16], plan.casters[at + 17], plan.casters[at + 18],
				plan.casters[at + 19]).is_equal_approx(rect)
	_check(fails, cards_ok, "each tree's card stands upright on its base, its own silhouette above it")
	var stones: int = 0
	for item: Dictionary in land.kit.placed:
		var kind: String = item["kind"]
		stones += 2 if kind.begins_with("slate") else (2 if kind == "amber-arch" else (1 if Plan.FOOTS.has(kind) else 0))
	var expected: int = trees.size() * 2 + shrubs * 3 + stones + land.journey.bases.size()
	_check(fails, plan.stamp_count == expected and plan.stamps.size() == expected * 12,
		"a stamp for every plant's reach and foot, every shrub's shade, every stone and every seat (%d of %d)" % [plan.stamp_count, expected])
	var inside: bool = true
	var field: Rect2 = Rect2(Vector2.ZERO, Vector2(plan.field_size)).grow(1.0)
	for k: int in range(plan.stamp_count):
		inside = inside and field.has_point(Vector2(plan.stamps[k * 12 + 3], plan.stamps[k * 12 + 7]))
	_check(fails, inside and plan.field_size == Vector2i(768, 480), "every stamp lies inside the 2D pass")
	var heights_ok: bool = plan.ground.x < plan.ground.y
	for x: float in range(-48, 49, 6):
		for z: float in range(-30, 31, 6):
			var h: float = land.terrain.height_at(x, z)
			heights_ok = heights_ok and h >= plan.ground.x - 0.0001 and h <= plan.ground.y + 0.0001
	_check(fails, heights_ok and plan.bounds == land.terrain.bounds,
		"the plan's ground heights hold every vertex of the land")


## The bake's world: the ground with the lit floor and with its mask, the
## road's details lit, every static caster shadows only and nothing of the
## pilgrim, under the live land's key and sky through a linear tonemap.
static func _stage(fails: Array[String], land: MapJourneyLandscape) -> void:
	var plan: Plan = land.forest_floor.plan
	var paint: ShaderMaterial = ShaderMaterial.new()
	var mask: ShaderMaterial = ShaderMaterial.new()
	var stage: Stage = Stage.new()
	stage.compose(land, plan, paint, mask)
	var details: int = 0
	for label: String in Details.NAMES:
		details += 1 if land.terrain.get_node_or_null(label) != null else 0
	_check(fails, stage.receivers == land.terrain.chunks.size() * 2 + details and not land.terrain.chunks.is_empty(),
		"the bake draws the ground once lit and once for its mask, and the road's details")
	var lit: int = 0
	var masked: int = 0
	var casting: bool = true
	var walker_meshes: Array[Mesh] = []
	for node: Node in land.journey.walker.find_children("*", "MeshInstance3D", true, false):
		walker_meshes.append((node as MeshInstance3D).mesh)
	var no_walker: bool = true
	var cards: MultiMeshInstance3D = null
	for node: Node in stage.get_children():
		if not node is GeometryInstance3D:
			continue
		var part: GeometryInstance3D = node
		if part.layers == Stage.LIT_LAYER:
			lit += 1
			casting = casting and ((part as MeshInstance3D).material_override == paint
				or Details.NAMES.has(_source_name(land, part)))
		elif part.layers == Stage.MASK_LAYER:
			masked += 1
			casting = casting and (part as MeshInstance3D).material_override == mask \
				and part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			casting = casting and part.layers == Stage.CASTER_LAYER \
				and part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if part is MeshInstance3D:
			no_walker = no_walker and not walker_meshes.has((part as MeshInstance3D).mesh)
		if str(part.name) == "Woodland shadow cards":
			cards = part as MultiMeshInstance3D
	_check(fails, lit == land.terrain.chunks.size() + details and masked == land.terrain.chunks.size() and casting,
		"every receiver is on its pass's layer and every other part casts shadows only")
	_check(fails, no_walker, "the pilgrim stays out of the bake")
	_check(fails, cards != null and cards.multimesh.instance_count == plan.caster_count
		and cards.multimesh.buffer == plan.casters and stage.casters > plan.caster_count,
		"the woodland casts through its cards, beside the kit, the bridges and the waystones")
	_check(fails, stage.key.rotation_degrees.is_equal_approx(MapJourneyLandscape.KEY_ROTATION)
		and stage.key.shadow_enabled and is_equal_approx(stage.key.light_energy, 1.6)
		and stage.environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR
		and is_equal_approx(stage.environment.tonemap_exposure, Stage.EXPOSURE)
		and not stage.environment.adjustment_enabled and not stage.environment.glow_enabled,
		"the bake lights the floor as the live land does, through a linear tonemap at its exposure")
	stage.free()


static func _source_name(land: MapJourneyLandscape, part: GeometryInstance3D) -> String:
	for label: String in Details.NAMES:
		var detail: MeshInstance3D = land.terrain.get_node_or_null(label) as MeshInstance3D
		if detail != null and part is MeshInstance3D and (part as MeshInstance3D).mesh == detail.mesh:
			return label
	return ""


## Where no renderer can bake (this headless suite), the floor settles at once
## as the painted ground, and the land keeps every live shadow.
static func _painted(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape) -> void:
	_check(fails, not Bake.supported(), "the headless renderer cannot bake")
	_check(fails, land.floor_step() and land.forest_floor.state == LandFloor.State.PAINTED
		and not screen.landscape_pending(), "the floor settles painted at once and holds no veil")
	var painted: bool = true
	for chunk: MeshInstance3D in land.terrain.chunks:
		painted = painted and chunk.material_override == land.terrain.paint
	var casting: bool = true
	for caster: GeometryInstance3D in land.wood.casters:
		casting = casting and caster.visible \
			and caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_check(fails, painted and casting, "unbaked, the ground keeps its paint and the woodland its live shadows")


## Once baked, the ground is drawn from the floor's material, the road's
## details are in the picture, and the live shadow pass keeps only the
## gateway, the outcrops and the bridges' parapets.
static func _baked(fails: Array[String], land: MapJourneyLandscape) -> void:
	var floor_node: LandFloor = land.forest_floor
	var drawn: ShaderMaterial = LandFloor.floor_material(ImageTexture.create_from_image(
		Image.create(4, 4, false, Image.FORMAT_RGBA8)), ImageTexture.create_from_image(
		Image.create(2, 2, false, Image.FORMAT_RGBA8)), land.terrain.bounds)
	floor_node.draw_floor(land, drawn)
	floor_node.quiet(land)
	var swapped: bool = true
	for chunk: MeshInstance3D in land.terrain.chunks:
		swapped = swapped and chunk.material_override == drawn
	for label: String in Details.NAMES:
		var detail: Node3D = land.terrain.get_node_or_null(label) as Node3D
		swapped = swapped and (detail == null or not detail.visible)
	_check(fails, swapped and is_equal_approx(float(str(drawn.get_shader_parameter("decode"))), 1.0 / Stage.EXPOSURE),
		"the baked floor draws every chunk and the details are put out")
	var woods: bool = true
	for caster: GeometryInstance3D in land.wood.casters:
		woods = woods and not caster.visible
	var journey: bool = true
	for node: Node in land.journey.find_children("*", "GeometryInstance3D", true, false):
		journey = journey and (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var heroes: int = 0
	var quiet: bool = true
	for node: Node in land.kit.find_children("*", "GeometryInstance3D", true, false):
		var part: GeometryInstance3D = node
		var casts: bool = part.visible and part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hero: bool = _hero_kind(part, land.kit)
		heroes += 1 if hero and casts else 0
		quiet = quiet and casts == hero
	var terrain: bool = true
	for node: Node in land.terrain.find_children("*", "GeometryInstance3D", true, false):
		var part: GeometryInstance3D = node
		var casts: bool = part.visible and part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		terrain = terrain and casts == (str(part.name) == LandFloor.LIVE_BRIDGE)
	_check(fails, woods and journey, "the woodland's and the waystones' live shadows are in the floor now")
	_check(fails, heroes > 0 and quiet and terrain,
		"only the gateway, the outcrops and the bridges' parapets cast live")


## Whether a kit part is of one of `HEROES`: its batch's kind, else the
## placement it stands under.
static func _hero_kind(part: Node, kit: Node) -> bool:
	var kind: String = str(part.get_meta("kind", ""))
	var node: Node = part
	while kind.is_empty() and node != null and node.get_parent() != kit:
		node = node.get_parent()
	if kind.is_empty() and node != null:
		kind = str(node.name)
	for hero: String in HEROES:
		if kind.begins_with(hero):
			return true
	return false


## The pilgrim's soft blob stands in for its shadow, asked before or after the
## pilgrim is built, and gives it back.
static func _blob(fails: Array[String]) -> void:
	var pilgrim: Pilgrim = Pilgrim.new()
	pilgrim.ground_blob(true)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(pilgrim)
	var blob: MeshInstance3D = pilgrim.get_node_or_null("Ground blob") as MeshInstance3D
	var quiet: bool = true
	for node: Node in pilgrim.find_children("*", "GeometryInstance3D", true, false):
		if node != blob:
			quiet = quiet and (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(fails, blob != null and blob.visible and quiet and blob.position.y > 0.0,
		"the pilgrim casts no live shadow and stands on its blob")
	pilgrim.ground_blob(false)
	var back: bool = not blob.visible
	for node: Node in pilgrim.find_children("*", "GeometryInstance3D", true, false):
		if node != blob:
			back = back and (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_check(fails, back, "without the blob the pilgrim casts its own shadow again")
	pilgrim.free()


## The warm-up draws a sample of every pipeline the bake and the floor use
## before the title's first frame shows (on the iPad 8 this engine builds them
## only as a draw needs them): the bake's and the floor's materials on meshes
## of the bake's own kinds (the ground's vertex, normal and colour; the cards'
## MultiMesh), every view drawn then let go. Its mip chain needs a
## RenderingDevice; the windowed proof checks it (`tools/check_floor_bake.gd`).
static func _warm(fails: Array[String]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var warm: Node = Warm.new()
	tree.root.add_child(warm)
	var shaders: Array[Shader] = []
	var ground_kind: bool = true
	for item: Node in warm.find_children("*", "GeometryInstance3D", true, false):
		var drawn: GeometryInstance3D = item as GeometryInstance3D
		var material: ShaderMaterial = drawn.material_override as ShaderMaterial
		if material == null:
			continue
		shaders.append(material.shader)
		if drawn is MeshInstance3D:
			var mesh: Mesh = (drawn as MeshInstance3D).mesh
			var format: int = mesh.surface_get_format(0)
			ground_kind = ground_kind and (format & Mesh.ARRAY_FORMAT_NORMAL) != 0 \
				and (format & Mesh.ARRAY_FORMAT_COLOR) != 0
		elif drawn is MultiMeshInstance3D:
			var multi: MultiMesh = (drawn as MultiMeshInstance3D).multimesh
			ground_kind = ground_kind and multi.use_colors and multi.use_custom_data \
				and drawn.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var wanted: Array[Shader] = [Bake.PAINT, Bake.MASK, Warm.CASTER, Warm.FLOOR]
	var all: bool = true
	for shader: Shader in wanted:
		all = all and shaders.has(shader)
	var waiting: bool = true
	for view: Node in warm.find_children("*", "SubViewport", false, false):
		waiting = waiting and (view as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED
	_check(fails, all and ground_kind and waiting,
		"the warm-up stands the bake's and the floor's materials on meshes of the bake's own kinds, undrawn until it draws them")
	var stamps_clear: bool = false
	for view: Node in warm.find_children("*", "SubViewport", false, false):
		var flat: SubViewport = view as SubViewport
		if flat.disable_3d and not flat.find_children("*", "MultiMeshInstance2D", false, false).is_empty():
			stamps_clear = flat.transparent_bg
	_check(fails, stamps_clear, "the warm-up draws the plants' stamps in a clear view, as the bake does")
	warm.call("draw_now")
	_check(fails, warm.is_queued_for_deletion(), "the warm-up draws its samples at once and lets them go")
	if is_instance_valid(warm) and warm.is_inside_tree():
		tree.root.remove_child(warm)
	warm.free()
