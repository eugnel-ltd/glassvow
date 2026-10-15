extends RefCounted
## One surface for every `CELL` metres of land a part of the masonry reaches,
## so each cell is its own draw and the renderer culls the cells off screen, as
## Act I's stone does (`land_stone.gd`; #660 II.3). A piece goes whole to the
## cell its centre is in.
const BoxBatch = preload("res://presentation/map/causeway/box_batch.gd")
const CELL: float = 32.0
## Each cell's surface, by cell, begun on first use.
var surfaces: Dictionary = {}
var _batches: Dictionary = {}
var _smooth: int = 0


func _init(smooth_group: int = 0) -> void:
	_smooth = smooth_group


## The surface of the cell `point` is in.
func at(point: Vector3) -> SurfaceTool:
	var key: Vector2i = _key(point)
	if not surfaces.has(key):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_smooth_group(_smooth)
		surfaces[key] = surface
	return surfaces[key]


## The unit-box batch over the surface of the cell `point` is in (a part drawn
## from boxes only: a batch counts its own vertices).
func batch(point: Vector3) -> BoxBatch:
	var key: Vector2i = _key(point)
	if not _batches.has(key):
		_batches[key] = BoxBatch.new(at(point))
	return _batches[key]


static func _key(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))
