extends Node3D
## Act I's hero stone (R3.3, issue #660): the kit's granite outcrops and the
## ravine's cliff pieces (`ravine_cliffs.gd`), merged into one mesh per `CELL`
## metres of land on one material (`stone.gdshader`): every kind shares one
## atlas, so the whole of the stone draws in a few draws.
##
## Built off the tree on the land's worker from plain arrays
## (`stone_pieces.gd`) held as meshes the renderer never sees
## (`Meshes.HeldArrays`), appended by the engine (`SurfaceTool.append_from`):
## nothing is read back from the renderer. Every piece casts
## into the floor's bake; once the floor is baked the stone casts no live
## shadow (`LandFloor.quiet`) and shades itself through its baked normals and
## occlusion.

const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Pieces = preload("res://presentation/map/landscape/stone_pieces.gd")
const SHADER: Shader = preload("res://presentation/map/landscape/stone.gdshader")
const PIECES_PATH: String = "res://assets/art/map-journey/stone/stone-pieces.res"
const ALBEDO_PATH: String = "res://assets/art/map-journey/stone/stone-albedo.png"
const NORMAL_PATH: String = "res://assets/art/map-journey/stone/stone-normal.png"
const MOSS: Texture2D = preload("res://assets/art/map-journey/floor/floor-moss.png")
## The granite outcrops, which the kit places (`kit.gd`), and the cliff
## pieces, which the ravine's rule places.
const OUTCROPS: PackedStringArray = ["granite-bank", "granite-ridge", "granite-shard", "granite-tor",
	"granite-boulder"]
const CLIFFS: PackedStringArray = ["cliff-wall", "cliff-notch", "cliff-buttress", "cliff-bend",
	"cliff-step", "cliff-tall"]
const CELL: float = 32.0

static var _pieces: Pieces = null
static var _held: Dictionary = {}
static var _material: ShaderMaterial = null
## Whether the stone cannot load: lands are drawn without it then.
static var failed: bool = false
static var _take: Atlas.Take = null

## One entry per piece drawn: its kind and its pose (tests and probes).
var placed: Array[Dictionary] = []
var draws: Array[MeshInstance3D] = []
var triangles: int = 0


## Whether `kind` is drawn by the stone (the kit keeps only its anchor).
static func draws_kind(kind: String) -> bool:
	return OUTCROPS.has(kind) or CLIFFS.has(kind)


## Readies the pieces and the material a step at a time, on the main thread
## before any land is built on a worker (`Kit.preload_step`), and answers
## whether nothing is left to wait for: ready, or unable to load (`failed`).
## As the woodland's atlas does (`ImpostorAtlas.prepare_step`), the files load
## on the loader's threads; `wait`ing, a step waits for them.
static func prepare_step(wait: bool = false) -> bool:
	if _material != null or failed:
		return true
	if _take == null:
		_take = Atlas.Take.new(PackedStringArray([PIECES_PATH, ALBEDO_PATH, NORMAL_PATH]), "")
		_take.request()
	if not _take.step(wait):
		return false
	var taken: Dictionary = _take.textures
	_take = null
	var got: Array = [taken.get(PIECES_PATH), taken.get(ALBEDO_PATH), taken.get(NORMAL_PATH)]
	if not (got[0] is Pieces and got[1] is Texture2D and got[2] is Texture2D):
		failed = true
		push_error("Journey stone: cannot load the stone kit; lands are drawn without it")
		return true
	_pieces = got[0]
	for kind: String in _pieces.arrays:
		var arrays: Array = _pieces.arrays[kind]
		_held[kind] = Meshes.HeldArrays.new(arrays)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("albedo_atlas", got[1])
	_material.set_shader_parameter("normal_atlas", got[2])
	_material.set_shader_parameter("moss", MOSS)
	return true


static func material() -> ShaderMaterial:
	return _material


## The piece `kind`'s extent in its own space (x along, y up, z toward its
## face); empty before `prepare`.
static func extent(kind: String) -> AABB:
	if _pieces == null or not _pieces.bounds.has(kind):
		return AABB()
	return _pieces.bounds[kind]


## Merges every piece in `poses` ([kind, Transform3D] pairs) into one mesh a
## cell.
func build(poses: Array) -> void:
	name = "Stone"
	if _pieces == null:
		return
	var cells: Dictionary = {}
	for pose: Array in poses:
		var kind: String = pose[0]
		var at: Transform3D = pose[1]
		if not _pieces.arrays.has(kind):
			push_error("Journey stone: no piece of kind " + kind)
			continue
		placed.append({"kind": kind, "transform": at})
		var key: Vector2i = Vector2i(floori(at.origin.x / CELL), floori(at.origin.z / CELL))
		var list: Array = cells.get(key, [])
		list.append(pose)
		cells[key] = list
	for key: Vector2i in cells:
		var poses_here: Array = cells[key]
		var mesh: ArrayMesh = _merge(poses_here)
		var draw: MeshInstance3D = MeshInstance3D.new()
		draw.name = "Stone %d %d" % [key.x, key.y]
		draw.mesh = Meshes.committed(mesh)
		draw.material_override = _material
		add_child(draw)
		draws.append(draw)


## One mesh of every piece in `poses`, each piece's arrays turned into land
## space by the engine (poses scale evenly, so normals and tangents turn with
## the basis).
func _merge(poses: Array) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pose: Array in poses:
		var held: Mesh = _held[pose[0]]
		var at: Transform3D = pose[1]
		surface.append_from(held, 0, at)
		triangles += piece_triangles(str(pose[0]))
	return surface.commit()


## How many triangles a piece of `kind` has.
static func piece_triangles(kind: String) -> int:
	var arrays: Array = _pieces.arrays[kind]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return index.size() / 3
