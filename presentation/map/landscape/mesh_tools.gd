extends RefCounted
## Small mesh construction primitives for the native art workshop.

static func material(colour: Color, roughness: float = 0.95) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = roughness
	return mat

static func node(parent: Node3D, mesh: Mesh, mat: Material, label: String) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.name = label
	item.mesh = mesh
	item.material_override = mat
	parent.add_child(item)
	return item

static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material,
		label: String = "Block", yaw: float = 0.0) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var item: MeshInstance3D = node(parent, mesh, mat, label)
	item.position = at
	item.rotation.y = yaw
	return item

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		colour: Color = Color.WHITE) -> void:
	for p: Vector3 in [a, b, c]:
		surface.set_color(colour)
		surface.add_vertex(p)

static func finish(surface: SurfaceTool) -> ArrayMesh:
	surface.generate_normals()
	return surface.commit()

static func v3(value: Array) -> Vector3:
	return Vector3(float(str(value[0])), float(str(value[1])), float(str(value[2])))


## A unit cube's surface held as arrays, for `SurfaceTool.append_from`. Every
## way of reading a mesh's arrays (`PrimitiveMesh.get_mesh_arrays` included)
## reads them back from the renderer, which off the main thread waits for the
## main thread to flush: a worker doing it stalls once per call, and a quit
## during the build deadlocks. So the cube is read once on the main thread
## (`prepare_unit_box`, from `Kit.preload_scenes`) and workers append the copy.
static var _unit_arrays: Array = []


static func prepare_unit_box() -> void:
	if not _unit_arrays.is_empty():
		return
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		push_error("mesh_tools: the unit cube was first read on a worker (a renderer stall)")
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	_unit_arrays = box.get_mesh_arrays()


static func unit_box() -> Mesh:
	prepare_unit_box()
	return HeldArrays.new(_unit_arrays)


class HeldArrays extends Mesh:
	var _arrays: Array

	func _init(arrays: Array) -> void:
		_arrays = arrays

	func _get_surface_count() -> int:
		return 1

	func _surface_get_arrays(_index: int) -> Array:
		return _arrays

	func _surface_get_primitive_type(_index: int) -> int:
		return Mesh.PRIMITIVE_TRIANGLES

	func _get_aabb() -> AABB:
		return AABB(-Vector3.ONE * 0.5, Vector3.ONE)
