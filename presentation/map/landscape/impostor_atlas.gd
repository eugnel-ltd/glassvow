extends RefCounted
## Act I's woodland as baked impostors (R3.1, issue #660): the two atlases
## (`tools/map_atelier/journey/impostors/`), each tile's page, picture-plane rect and silhouette,
## and the card, shadow casters and material every land shares.
##
## The journey camera never turns and is orthographic at one pitch, so a plant
## is only ever seen from one direction: a card facing the camera, painted with
## the model as baked from that direction, is the mesh's own picture at every
## zoom stop and pan. A tile is one kind at one yaw; its picture-plane rect is
## in metres relative to the model's base (`MapJourneyCameraContract.
## projected_plane`: x across, y down the screen).
##
## Each atlas is a two-layer texture array (`CompressedTexture2DArray`), a
## page a layer, so no upload passes 4 MiB: the engine uploads an array a layer
## at a time, and a transfer worker's staging buffer grows to the next power of
## two above its largest upload and is never shrunk (R3.3;
## `tests/test_texture_uploads.gd`).
##
## Readied on the main thread before any land is built on a worker
## (`prepare_step`, through `Kit.preload_step`): the atlases load on the
## loader's threads; the tiles, meshes and material are made once per process.
## Atlases that cannot load leave the woodland out of every land (`failed`)
## rather than holding the map's opening.

const SHADER: Shader = preload("res://presentation/map/landscape/impostor.gdshader")
const ALBEDO_PATH: String = "res://assets/art/map-journey/impostors/wood-albedo.png"
const NORMAL_PATH: String = "res://assets/art/map-journey/impostors/wood-normal.png"
const TILES_PATH: String = "res://assets/art/map-journey/impostors/wood-tiles.json"
## The yaw of a kind's first tile; the others turn evenly from it.
const FIRST_YAW: float = 0.35
## The ruins (R3.3), drawn as impostors where the kit places them: the
## gravestones, the broken walls and the rubble.
const GRAVES: PackedStringArray = ["grave-arched", "grave-cross", "grave-broken", "grave-tablet"]
const WALLS: PackedStringArray = ["wall-run", "wall-corner", "wall-pier"]
const RUBBLE: PackedStringArray = ["rubble-blocks", "rubble-scree", "rubble-mossy"]
const RUINS: PackedStringArray = GRAVES + WALLS + RUBBLE
## The kit's foliage drawn as impostors (the bare snag stays a mesh).
const FOLIAGE: PackedStringArray = ["conifer", "conifer-spire", "conifer-wind",
	"ash-copse", "ash-heath", "ash-bramble", "ash-fern"]
## The kit's kinds drawn as impostors where the kit plants them, its foliage
## and the ruins: the kit keeps their placements and never loads or batches
## their meshes.
const KIT_KINDS: PackedStringArray = FOLIAGE + RUINS

## Per tile: its kind, page (the arrays' layer) and rect on that page,
## picture-plane low corner and size (metres at scale 1), how far the model
## reaches toward the camera from its base and how tall it stands, and its
## silhouette as covered x spans (tile units) per `span_m` metres down the
## picture.
static var tile_kinds: PackedStringArray = []
static var layer: PackedInt32Array = []
static var uv: PackedVector4Array = []
static var low: PackedVector2Array = []
static var size: PackedVector2Array = []
static var front: PackedFloat32Array = []
static var top: PackedFloat32Array = []
## Per tile, `shift` worked out once.
static var shifts: PackedFloat32Array = []
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
## Whether the atlases cannot be loaded: no land draws a woodland then.
static var failed: bool = false
## How long readying the atlas has taken on the main thread, waits included
## (benches and probes).
static var prepare_ms: float = 0.0
static var _take: Take = null


## Resources (textures unless `hint` says otherwise) taken from the loader's
## threads, each exactly once and in whatever order they finish: a second
## `load_threaded_get` of a path returns null, so a step keeps what it took for
## the next. A path the loader cannot load settles the take as failed, so a
## wait for it always ends.
class Take:
	extends RefCounted
	var paths: PackedStringArray
	var hint: String = "Texture2D"
	var textures: Dictionary = {}
	var failed: bool = false
	## The loader's two calls (tests stand in for them).
	var status: Callable = ResourceLoader.load_threaded_get_status
	var get_texture: Callable = ResourceLoader.load_threaded_get

	func _init(from: PackedStringArray, type_hint: String = "Texture2D") -> void:
		paths = from
		hint = type_hint

	## Asks the loader's threads for every path.
	func request() -> void:
		for path: String in paths:
			if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path, hint) != OK:
				failed = true

	## Takes every texture that has loaded and answers whether the take is
	## settled: all taken, or failed. `wait`ing, it waits for each one while
	## keeping the renderer in step, as `Kit.preload_step` does.
	func step(wait: bool) -> bool:
		for path: String in paths:
			if failed:
				break
			if textures.has(path):
				continue
			var state: int = status.call(path)
			while state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not wait:
					return false
				RenderingServer.force_sync()
				OS.delay_usec(500)
				state = status.call(path)
			var texture: Variant = get_texture.call(path) if state == ResourceLoader.THREAD_LOAD_LOADED else null
			var taken: Resource = texture if texture is Resource else null
			if taken != null and (hint.is_empty() or taken.is_class(hint)):
				textures[path] = taken
			else:
				failed = true
		return true


## Whether the atlas is ready for a build.
static func ready() -> bool:
	return material != null


## Asks the loader's threads for the atlases (cheap; once).
static func request() -> void:
	if _take != null or ready() or failed:
		return
	_take = Take.new(PackedStringArray([ALBEDO_PATH, NORMAL_PATH]), "TextureLayered")
	_take.request()


## Readies the atlas a step at a time and answers whether nothing is left to
## wait for: the atlas is ready, or it cannot load (`failed`). Not `wait`ing
## (the journey prefetch under the title), a step returns while the atlases
## are still loading; `wait`ing (a map opening now), it waits for them.
static func prepare_step(wait: bool = false) -> bool:
	if ready() or failed:
		return true
	var started: int = Time.get_ticks_usec()
	request()
	var settled: bool = _take.step(wait)
	if settled and _take.failed:
		failed = true
		push_error("Journey wood: cannot load the impostor atlases; the woodland is left out")
	elif settled:
		var albedo: TextureLayered = _take.textures[ALBEDO_PATH]
		var normal: TextureLayered = _take.textures[NORMAL_PATH]
		_make(albedo, normal)
	if settled:
		_take = null
	prepare_ms += (Time.get_ticks_usec() - started) / 1000.0
	return settled


static func _make(albedo: TextureLayered, normal: TextureLayered) -> void:
	_read_tiles()
	card = _quad()
	cone = _cone()
	egg = _egg()
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas_albedo", albedo)
	material.set_shader_parameter("atlas_normal", normal)


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
		layer.append(int(str(tile["layer"])))
		uv.append(_v4(rect))
		low.append(_v2(corner))
		size.append(_v2(extent))
		front.append(float(str(tile["front"])))
		top.append(float(str(tile["top"])))
		shifts.append(clampf((low[i].y + size[i].y) * 1.25 + 0.1, 0.3, front[i]))
		var rows: PackedVector2Array = []
		for row: Array in tile["spans"]:
			rows.append(_v2(row))
		spans.append(rows)


static func _v2(raw: Array) -> Vector2:
	return Vector2(float(str(raw[0])), float(str(raw[1])))


static func _v4(raw: Array) -> Vector4:
	return Vector4(float(str(raw[0])), float(str(raw[1])), float(str(raw[2])), float(str(raw[3])))


## What a card of tile `tile` carries for the shaders (its instance custom
## data): its rect on its page, with the page added to the rect's top. A rect's
## top lies under 1 on its page, so `impostor.gdshader` and
## `floor_caster.gdshader` read the page back as the whole part.
static func custom(tile: int) -> Vector4:
	var rect: Vector4 = uv[tile]
	return Vector4(rect.x, rect.y + layer[tile], rect.z, rect.w)


## The tile kind `kind` shows at `yaw` (the nearest baked turn).
static func tile_for(kind: String, yaw: float) -> int:
	var choices: PackedInt32Array = by_kind[kind]
	var step: float = TAU / choices.size()
	return choices[posmod(roundi((yaw - FIRST_YAW) / step), choices.size())]


## How far toward the camera a tile's card stands from its base, at scale 1:
## just far enough that the card's foot clears the ground in front of it
## (`low.y + size.y` is how far the picture reaches below the base).
static func shift(tile: int) -> float:
	return shifts[tile]


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
