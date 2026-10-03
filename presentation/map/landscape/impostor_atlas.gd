extends RefCounted
## Act I's woodland as baked impostors (R3.1, issue #660): the two atlases
## (`tools/map_atelier/journey/impostors/`), each tile's picture-plane rect and silhouette, and the
## card, shadow casters and material every land shares.
##
## The journey camera never turns and is orthographic at one pitch, so a plant
## is only ever seen from one direction: a card facing the camera, painted with
## the model as baked from that direction, is the mesh's own picture at every
## zoom stop and pan. A tile is one kind at one yaw; its picture-plane rect is
## in metres relative to the model's base (`MapJourneyCameraContract.
## projected_plane`: x across, y down the screen).
##
## Readied on the main thread before any land is built on a worker
## (`prepare_step`, through `Kit.preload_step`): the atlases load on the
## loader's threads; the tiles, meshes and material are made once per process.

const SHADER: Shader = preload("res://presentation/map/landscape/impostor.gdshader")
const ALBEDO_PATH: String = "res://assets/art/map-journey/impostors/wood-albedo.png"
const NORMAL_PATH: String = "res://assets/art/map-journey/impostors/wood-normal.png"
const TILES_PATH: String = "res://assets/art/map-journey/impostors/wood-tiles.json"
## The yaw of a kind's first tile; the others turn evenly from it.
const FIRST_YAW: float = 0.35
## The kit's foliage kinds, drawn as impostors where the kit plants them: the
## kit keeps their placements and never loads or batches their meshes (the
## bare snag stays a mesh).
const KIT_KINDS: PackedStringArray = ["conifer", "conifer-spire", "conifer-wind",
	"ash-copse", "ash-heath", "ash-bramble", "ash-fern"]

## Per tile: its kind, atlas rect, picture-plane low corner and size (metres
## at scale 1), how far the model reaches toward the camera from its base and
## how tall it stands, and its silhouette as covered x spans (tile units) per
## `span_m` metres down the picture.
static var tile_kinds: PackedStringArray = []
static var uv: PackedVector4Array = []
static var low: PackedVector2Array = []
static var size: PackedVector2Array = []
static var front: PackedFloat32Array = []
static var top: PackedFloat32Array = []
static var spans: Array[PackedVector2Array] = []
static var span_m: float = 0.25
## Each kind's tiles, in yaw order.
static var by_kind: Dictionary = {}
## The card every instance draws (a unit quad, x across, y down), the shadow
## casters (a cone for a conifer, an egg for a broadleaf crown) and the cards'
## one material.
static var card: ArrayMesh = null
static var cone: ArrayMesh = null
static var egg: ArrayMesh = null
static var material: ShaderMaterial = null
static var _requested: bool = false


## Whether the atlas is ready for a build.
static func ready() -> bool:
	return material != null


## Asks the loader's threads for the atlases (cheap; once).
static func request() -> void:
	if _requested or ready():
		return
	_requested = true
	for path: String in [ALBEDO_PATH, NORMAL_PATH]:
		ResourceLoader.load_threaded_request(path, "Texture2D")


## Readies the atlas a step at a time and answers whether it is ready. Not
## `wait`ing (the journey prefetch under the title), a step returns while the
## atlases are still loading; `wait`ing (a map opening now), it waits for
## them while keeping the renderer in step, as `Kit.preload_step` does.
static func prepare_step(wait: bool = false) -> bool:
	if ready():
		return true
	request()
	var textures: Array[Texture2D] = []
	for path: String in [ALBEDO_PATH, NORMAL_PATH]:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not wait:
				return false
			RenderingServer.force_sync()
			OS.delay_usec(500)
		textures.append(ResourceLoader.load_threaded_get(path) as Texture2D)
	if textures.has(null):
		push_error("Journey wood: cannot load the impostor atlases")
		return false
	_read_tiles()
	card = _quad()
	cone = _cone()
	egg = _egg()
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas_albedo", textures[0])
	material.set_shader_parameter("atlas_normal", textures[1])
	return true


static func _read_tiles() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TILES_PATH))
	span_m = float(str(data["span_m"]))
	var tiles: Array = data["tiles"]
	for i: int in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		var kind: String = tile["kind"]
		tile_kinds.append(kind)
		var list: PackedInt32Array = by_kind.get(kind, PackedInt32Array())
		list.append(i)
		by_kind[kind] = list
		var rect: Array = tile["uv"]
		var corner: Array = tile["low"]
		var extent: Array = tile["size"]
		uv.append(_v4(rect))
		low.append(_v2(corner))
		size.append(_v2(extent))
		front.append(float(str(tile["front"])))
		top.append(float(str(tile["top"])))
		var rows: PackedVector2Array = []
		for row: Array in tile["spans"]:
			rows.append(_v2(row))
		spans.append(rows)


static func _v2(raw: Array) -> Vector2:
	return Vector2(float(str(raw[0])), float(str(raw[1])))


static func _v4(raw: Array) -> Vector4:
	return Vector4(float(str(raw[0])), float(str(raw[1])), float(str(raw[2])), float(str(raw[3])))


## The tile kind `kind` shows at `yaw` (the nearest baked turn).
static func tile_for(kind: String, yaw: float) -> int:
	var choices: PackedInt32Array = by_kind[kind]
	var step: float = TAU / choices.size()
	return choices[posmod(roundi((yaw - FIRST_YAW) / step), choices.size())]


## How far toward the camera a tile's card stands from its base, at scale 1:
## just far enough that the card's foot clears the ground in front of it
## (`low.y + size.y` is how far the picture reaches below the base).
static func shift(tile: int) -> float:
	return clampf((low[tile].y + size[tile].y) * 1.25 + 0.1, 0.3, front[tile])


## The card's pose for a plant of tile `tile` standing at `base`, at `scale`.
static func card_transform(tile: int, base: Vector3, scale_value: float) -> Transform3D:
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	var toward: Vector3 = Vector3(0, sin(pitch), cos(pitch))
	var down: Vector3 = Vector3(0, -cos(pitch), sin(pitch))
	var origin: Vector3 = base + (Vector3.RIGHT * low[tile].x + down * low[tile].y) * scale_value \
		+ toward * shift(tile) * scale_value
	return Transform3D(Basis(Vector3.RIGHT * size[tile].x * scale_value,
		down * size[tile].y * scale_value, toward), origin)


## The card's picture-plane rect (metres) for a plant at `base`, at `scale`.
static func rect(tile: int, base: Vector3, scale_value: float) -> Rect2:
	return Rect2(MapJourneyCameraContract.projected_plane(base) + low[tile] * scale_value,
		size[tile] * scale_value)


## A unit card (x right, y down the picture), wound clockwise as the picture
## shows it (Godot's front faces).
static func _quad() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0),
		Vector3(1, 1, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A conifer's shadow: an opaque six-sided cone, apex up, height 2, radius 1.
static func _cone() -> ArrayMesh:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = 0.05
	shape.bottom_radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 6
	shape.rings = 0
	shape.cap_top = false
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shape.get_mesh_arrays())
	return mesh


## A broadleaf crown's shadow: a coarse unit sphere, scaled into an egg.
static func _egg() -> ArrayMesh:
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 8
	shape.rings = 4
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shape.get_mesh_arrays())
	return mesh
