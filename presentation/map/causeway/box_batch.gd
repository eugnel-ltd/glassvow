extends RefCounted
## Unit boxes appended to one surface by pose (the archive's
## `common/box_batch.gd`). The cube's arrays are the copy `mesh_tools.gd` held
## on the main thread, so a worker appending them never reads the renderer.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
var surface: SurfaceTool
var vertices: PackedVector3Array
var uvs: PackedVector2Array
var indices: PackedInt32Array
var vertex_count: int = 0


func _init(target: SurfaceTool) -> void:
	surface = target
	var arrays: Array = Meshes.unit_box().surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	uvs = arrays[Mesh.ARRAY_TEX_UV]
	indices = arrays[Mesh.ARRAY_INDEX]


func append(pose: Transform3D) -> void:
	for i: int in range(vertices.size()):
		surface.set_uv(uvs[i])
		surface.add_vertex(pose * vertices[i])
	for index: int in indices:
		surface.add_index(vertex_count + index)
	vertex_count += vertices.size()
