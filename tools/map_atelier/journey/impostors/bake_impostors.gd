extends SceneTree
## Bakes Act I's woodland as fixed-view impostors (R3.1, issue #660).
##
## The journey camera never turns (yaw 0) and is orthographic at one pitch
## (`MapJourneyCameraContract.PITCH`) in Close, Journey and Whole act alike, so
## a plant is only ever seen from one direction: its picture, baked from that
## direction and drawn on a card facing the camera, is the mesh's exact
## picture at every zoom stop and pan (`impostor_wood.gd`).
##
## Each kind in `RECIPES` is rendered at a few yaws in four passes: albedo
## (cut out as the map's foliage is), world-space normal, how much of the map's
## key light (`MapJourneyLandscape.light`) reaches each fragment through the
## plant's own crown, and depth. `pack_impostors.py` packs the passes into the
## atlases under `assets/art/map-journey/impostors/`.
##
## The sources are the kit's own models (`assets/art/map-journey/*.glb`, built
## by `tools/map_atelier/journey/`). A recipe may compose a broadleaf crown
## from the kit's bare snag and leaf clumps, or repaint a kind's leaves in
## another colour of the Ashen Woods (same luminance, new hue). A crafted
## Blender source replaces a recipe as a data-only re-bake.
##
## Run windowed (it renders):
##   godot --path . -s res://tools/map_atelier/journey/impostors/bake_impostors.gd -- --raw=<dir>
## then: python3 tools/map_atelier/journey/impostors/pack_impostors.py <dir>
## (`<dir>` outside the project, or under the ignored `build/`).

const FLAT: Shader = preload("res://tools/map_atelier/journey/impostors/bake_flat.gdshader")
const SHADOW: Shader = preload("res://tools/map_atelier/journey/impostors/bake_shadow.gdshader")
const Surfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
## Texels per metre of the packed albedo (the bake renders `SS` times finer).
const PX_PER_M: float = 56.0
const SS: int = 2
const MARGIN: float = 0.25
## Leaf colours a recipe may repaint with (sRGB), and how bright against the
## source leaves.
const LEAVES: Dictionary = {
	"rust": [Color("a85c20"), 1.3],
	"amber": [Color("c08e2a"), 1.55],
	"olive": [Color("5d5a24"), 1.2],
	"dark": [Color("26321f"), 0.9],
}
## Every kind the woodland draws. `source` is the kit model (default: the
## kind's own); `stack` layers turned copies of it (yaw, scale) so a thin kit
## conifer reads as a full spruce; `crown` composes a broadleaf on the kit's
## bare snag; `leaf` repaints the leaves; `yaws` is how many turns are baked.
const RECIPES: Dictionary = {
	"conifer": {"yaws": 4, "stack": [[1.1, 0.96], [2.3, 0.9]]},
	"conifer-spire": {"yaws": 4, "stack": [[1.4, 0.94]]},
	"conifer-wind": {"yaws": 3},
	"ember-oak": {"yaws": 4, "crown": "oak"},
	"ember-round": {"yaws": 3, "crown": "round"},
	"rust-oak": {"yaws": 3, "crown": "oak", "leaf": "rust"},
	"amber-round": {"yaws": 3, "crown": "round", "leaf": "amber"},
	"ash-heath": {"yaws": 3},
	"ash-copse": {"yaws": 3},
	"ash-bramble": {"yaws": 3},
	"ash-fern": {"yaws": 3},
	"olive-heath": {"yaws": 3, "source": "ash-heath", "leaf": "olive"},
	"dark-copse": {"yaws": 3, "source": "ash-copse", "leaf": "dark"},
}
## A composed crown: its centre height, its reach, how many sprays and how
## many leaf clumps each, and the trunk's scale. Sprays sit at the ends of
## the limbs with gaps between them, so the crown reads as sprays, not a blob.
const CROWNS: Dictionary = {
	"oak": {"centre": Vector3(0, 3.5, 0), "radii": Vector3(2.2, 1.35, 2.2), "sprays": 7,
		"clumps": 6, "trunk": 0.82},
	"round": {"centre": Vector3(0, 2.6, 0), "radii": Vector3(1.6, 1.15, 1.6), "sprays": 5,
		"clumps": 6, "trunk": 0.6},
}

var _raw: String = ""
var _vp: SubViewport
var _camera: Camera3D
var _rows: Array = []
var _hidden_material: ShaderMaterial = null


func _init() -> void:
	_raw = "res://build/impostor-raw/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--raw="):
			_raw = arg.trim_prefix("--raw=").trim_suffix("/") + "/"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_raw))
	_stage()
	for kind: String in RECIPES:
		var recipe: Dictionary = RECIPES[kind]
		var yaws: int = recipe["yaws"]
		for yaw_index: int in range(yaws):
			var yaw: float = TAU * yaw_index / yaws + 0.35
			var plant: Node3D = _build(kind, recipe)
			plant.rotation.y = yaw
			_vp.add_child(plant)
			await _bake(plant, "%s-%d" % [kind, yaw_index], kind, yaw, recipe)
			plant.queue_free()
			await process_frame
	var file: FileAccess = FileAccess.open(_raw + "tiles_raw.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pitch": MapJourneyCameraContract.PITCH, "px_per_m": PX_PER_M,
		"ss": SS, "tiles": _rows}, "\t"))
	file.close()
	print("BAKED %d tiles into %s" % [_rows.size(), ProjectSettings.globalize_path(_raw)])
	quit(0)


## The bake's own world: an orthographic camera at the journey pitch and the
## map's key light direction, no ambient, a linear tonemap.
func _stage() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# A thin slab round the model: an orthographic camera's directional
	# shadow spends its texels over the whole near-to-far slice.
	_camera.near = 12.0
	_camera.far = 28.0
	_camera.rotation_degrees = Vector3(-MapJourneyCameraContract.PITCH, 0.0, 0.0)
	_vp.add_child(_camera)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -32, 0)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 30.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 0.6
	key.light_energy = 1.0
	_vp.add_child(key)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	world.environment = environment
	_vp.add_child(world)


## A kind's model at the origin: a kit model, or a broadleaf composed from
## the kit's bare snag crowned with leaf clumps in sprays.
func _build(kind: String, recipe: Dictionary) -> Node3D:
	if not recipe.has("crown"):
		var model: Node3D = _kit(str(recipe.get("source", kind)))
		for layer: Array in recipe.get("stack", []):
			var copy: Node3D = _kit(str(recipe.get("source", kind)))
			var turn: float = layer[0]
			var layer_scale: float = layer[1]
			copy.rotation.y = turn
			copy.scale = Vector3.ONE * layer_scale
			model.add_child(copy)
		return model
	var crown: Dictionary = CROWNS[recipe["crown"]]
	var plant: Node3D = Node3D.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var trunk: Node3D = _kit("conifer-snag")
	var trunk_scale: float = crown["trunk"]
	trunk.scale = Vector3.ONE * trunk_scale
	plant.add_child(trunk)
	var centre: Vector3 = crown["centre"]
	var radii: Vector3 = crown["radii"]
	var sprays: int = crown["sprays"]
	for spray: int in range(sprays):
		# A spray's heart on the crown's shell, turned evenly round the trunk
		# with a little jitter, upper half favoured.
		var turn: float = TAU * spray / sprays + rng.randf_range(-0.35, 0.35)
		var rise: float = rng.randf_range(-0.35, 0.9)
		var heart: Vector3 = centre + Vector3(cos(turn) * radii.x * rng.randf_range(0.55, 0.85),
			rise * radii.y, sin(turn) * radii.z * rng.randf_range(0.55, 0.85))
		var clumps: int = crown["clumps"] + (1 if spray == 0 else 0)
		for i: int in range(clumps):
			var clump: Node3D = _kit("ash-heath" if i % 3 != 2 else "ash-copse")
			_hide_bark(clump)
			var offset: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.8),
				rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.15, 0.75)
			clump.position = heart + offset
			clump.rotation = Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(-PI, PI),
				rng.randf_range(-0.55, 0.55))
			clump.scale = Vector3.ONE * rng.randf_range(0.45, 0.72)
			plant.add_child(clump)
	return plant


func _kit(kind: String) -> Node3D:
	var scene: PackedScene = ResourceLoader.load("res://assets/art/map-journey/%s.glb" % kind,
		"PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	return scene.instantiate() as Node3D


## A clump's bark is hidden: only its leaves build a composed crown.
func _hide_bark(clump: Node3D) -> void:
	for child: Node in clump.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(item.mesh.get_surface_count()):
			var material: Material = item.get_active_material(surface)
			if material != null and not _leafy(material):
				item.set_meta("hide_%d" % surface, true)


static func _leafy(material: Material) -> bool:
	return material.resource_name.begins_with("Foliage /") or material.resource_name.begins_with("Fern /")


## Every visible surface of `plant` with its pose in the bake's coordinates.
func _surfaces(plant: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in plant.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = child as MeshInstance3D
		if not item.is_visible_in_tree() or item.mesh == null:
			continue
		for surface: int in range(item.mesh.get_surface_count()):
			if item.has_meta("hide_%d" % surface):
				continue
			out.append({"item": item, "surface": surface, "pose": item.global_transform})
	return out


func _bake(plant: Node3D, name: String, kind: String, yaw: float, recipe: Dictionary) -> void:
	await process_frame
	var surfaces: Array[Dictionary] = _surfaces(plant)
	# The tile: the posed model's extent on the camera's picture plane
	# (`projected_plane`: x across, y down the screen), and how far its nearest
	# point stands toward the camera from the plane through its base.
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	var toward: Vector3 = Vector3(0, sin(pitch), cos(pitch))
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var front: float = 0.0
	var top: float = 0.0
	for entry: Dictionary in surfaces:
		var item: MeshInstance3D = entry["item"]
		var pose: Transform3D = entry["pose"]
		var surface_index: int = entry["surface"]
		var points: PackedVector3Array = item.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in points:
			var p: Vector3 = pose * point
			var projected: Vector2 = MapJourneyCameraContract.projected_plane(p)
			low = low.min(projected)
			high = high.max(projected)
			front = maxf(front, p.dot(toward))
			top = maxf(top, p.y)
	low -= Vector2(MARGIN, MARGIN)
	high += Vector2(MARGIN, MARGIN)
	var size_m: Vector2 = high - low
	var pixels: Vector2i = Vector2i(ceili(size_m.x * PX_PER_M), ceili(size_m.y * PX_PER_M))
	size_m = Vector2(pixels) / PX_PER_M
	high = low + size_m
	_vp.size = pixels * SS
	_camera.size = size_m.y
	var centre: Vector2 = (low + high) * 0.5
	var down: Vector3 = Vector3(0, -cos(pitch), sin(pitch))
	_camera.position = Vector3(centre.x, 0, 0) + down * centre.y + toward * 20.0
	for pass_name: String in ["albedo", "normal", "shadow", "depth"]:
		_dress(surfaces, pass_name, recipe)
		for i: int in range(4):
			await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().save_png(_raw + "%s-%s.png" % [name, pass_name])
	_rows.append({"name": name, "kind": kind, "yaw": yaw, "low": [low.x, low.y],
		"size": [size_m.x, size_m.y], "pixels": [pixels.x, pixels.y], "front": front, "top": top})
	print("tile %s %dx%d front %.2f top %.2f" % [name, pixels.x, pixels.y, front, top])


## Gives every surface the bake pass's material.
func _dress(surfaces: Array[Dictionary], pass_name: String, recipe: Dictionary) -> void:
	var leaf: Array = LEAVES.get(str(recipe.get("leaf", "")), [])
	for entry: Dictionary in surfaces:
		var item: MeshInstance3D = entry["item"]
		var surface: int = entry["surface"]
		var standard: StandardMaterial3D = item.mesh.surface_get_material(surface) as StandardMaterial3D
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADOW if pass_name == "shadow" else FLAT
		var texture: Texture2D = null
		var colour: Color = Color.WHITE
		var leafy: bool = standard != null and _leafy(standard)
		if standard != null:
			texture = Surfaces.source_for(standard.resource_name)
			if texture == null:
				texture = standard.albedo_texture
			colour = standard.albedo_color
		material.set_shader_parameter("albedo",
			colour if leafy or pass_name == "albedo" else Color(1, 1, 1, colour.a))
		material.set_shader_parameter("tex", texture)
		material.set_shader_parameter("use_tex", texture != null)
		material.set_shader_parameter("scissor", 0.3 if leafy else 0.01)
		if leafy and not leaf.is_empty():
			var hue: Color = leaf[0]
			material.set_shader_parameter("recolour", Color(hue.r, hue.g, hue.b, 1.0))
			var gain: float = leaf[1]
			material.set_shader_parameter("recolour_gain", gain)
		if pass_name != "shadow":
			material.set_shader_parameter("mode", {"albedo": 0, "normal": 1, "depth": 2}[pass_name])
		item.set_surface_override_material(surface, material)
	# Hidden surfaces (a composed crown's clump bark) draw nothing.
	for child: Node in _vp.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = child as MeshInstance3D
		for surface: int in range(item.mesh.get_surface_count()):
			if item.has_meta("hide_%d" % surface):
				item.set_surface_override_material(surface, _invisible())


func _invisible() -> ShaderMaterial:
	if _hidden_material == null:
		_hidden_material = ShaderMaterial.new()
		_hidden_material.shader = FLAT
		_hidden_material.set_shader_parameter("albedo", Color(0, 0, 0, 0))
		_hidden_material.set_shader_parameter("scissor", 0.5)
	return _hidden_material
