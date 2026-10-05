extends Node3D
## Static imported meshes share spatially bounded draw batches. Placement anchors
## retain identity; each actual GPU instance is linked back to its source part.
const Surfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
const ImpostorAtlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const CELL: float = 32.0
## Ground-hugging kinds whose shadows the 55° camera barely sees: they render
## lit but stay out of the shadow pass, which keeps that pass inside the A12
## budget (trees, banks, ridges and the gateway still cast).
const NO_SHADOW: PackedStringArray = ["ash-heath", "ash-copse", "ash-fern", "ash-bramble", "slate-scree"]
## A conifer's shadow proxy (`_proxy_shadows`): a cone this many sides round,
## this wide at its top.
const CONE_SIDES: int = 6
const CONE_TOP: float = 0.05
var failure: String = ""
var templates: Dictionary = {}
var groups: Dictionary = {}
var material_pool: Dictionary = {}
var draw_count: int = 0
## Every kit scene's parts, collected once on the main thread
## (`prepare_template`), before any worker builds a land from them.
static var _shared: Dictionary = {}


## Collects the parts of the kit scene `packed`, loaded for `path` as its own
## copy (`ResourceLoader.CACHE_MODE_IGNORE`): each part takes its mesh as it is
## and is given its prepared materials. Duplicating a mesh shared with the
## cache instead would read it back from the renderer, a stall per buffer.
static func prepare_template(path: String, kind: String, packed: PackedScene) -> String:
	if _shared.has(path):
		return ""
	if packed == null:
		return "Cannot load static scenery: " + path
	var original: Node3D = packed.instantiate() as Node3D
	var pool: Dictionary = {}
	var surfaces: int = Surfaces.prepare(original, pool)
	if (kind.begins_with("conifer") or kind.begins_with("ash-")) and kind not in ["conifer-snag","ash-fern"] and surfaces==0:
		original.free()
		return "Static foliage has no prepared cut-out surface: "+kind
	var parts: Array[Dictionary] = []
	var failure: String = _collect(original, original.transform.affine_inverse(), parts)
	if failure.is_empty() and MapScene.lean_profile() and kind not in NO_SHADOW:
		_proxy_shadows(parts)
	_shared[path] = {"root":original.transform,"parts":parts,"kind":kind}
	original.free()
	return failure


func prepare(path: String, kind: String) -> Node3D:
	if ImpostorAtlas.KIT_KINDS.has(kind):
		# Drawn as an impostor card (`impostor_wood.gd`): the anchor only.
		var plant: Node3D = Node3D.new()
		plant.name = kind
		return plant
	if not templates.has(path):
		if not _shared.has(path):
			failure = "Static scenery template was not prepared: " + path
			return null
		templates[path] = _shared[path]
	var anchor: Node3D = Node3D.new()
	anchor.name=kind
	anchor.transform=templates[path]["root"]
	anchor.set_meta("static_template",path)
	anchor.set_meta("static_draws",[])
	return anchor
func register(anchor: Node3D) -> void:
	if not anchor.has_meta("static_template"):
		return
	var path: String = anchor.get_meta("static_template")
	var parts: Array = templates[path]["parts"]
	var cell: Vector2i = Vector2i(floori(anchor.position.x/CELL),floori(anchor.position.z/CELL))
	for index: int in range(parts.size()):
		var key: String = path+"/%d/%d/%d"%[index,cell.x,cell.y]
		if not groups.has(key): groups[key]={"part":parts[index],"placements":[],"kind":templates[path]["kind"]}
		groups[key]["placements"].append(anchor)
func finish() -> void:
	for key: String in groups:
		var part: Dictionary = groups[key]["part"]
		var anchors: Array = groups[key]["placements"]
		var relative: Transform3D = part["transform"]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=part["mesh"]
		multi.instance_count=anchors.size()
		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.multimesh=multi
		draw.layers=part["layers"]
		# A shadow proxy only ever casts; every other part of a NO_SHADOW kind
		# draws without casting.
		var proxy: bool = part["shadow"] == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if str(groups[key]["kind"]) in NO_SHADOW and not proxy else part["shadow"]
		draw.set_meta("kind",str(groups[key]["kind"]))
		add_child(draw)
		for i: int in range(anchors.size()):
			var anchor: Node3D = anchors[i]
			multi.set_instance_transform(i,anchor.transform*relative)
			var links: Array = anchor.get_meta("static_draws")
			links.append({"draw":draw,"index":i,"part":relative})
		draw_count+=1
static func _collect(node: Node, parent: Transform3D, parts: Array[Dictionary]) -> String:
	var pose: Transform3D = parent
	if node is Node3D:
		var spatial: Node3D = node as Node3D
		if not spatial.visible: return ""
		pose=parent*spatial.transform
	if node is MeshInstance3D:
		var item: MeshInstance3D = node as MeshInstance3D
		if item.skin!=null or not item.mesh is ArrayMesh:
			return "Static scenery contains unsupported deforming geometry"
		var mesh: ArrayMesh = item.mesh as ArrayMesh
		for surface: int in range(mesh.get_surface_count()):
			mesh.surface_set_material(surface,item.get_active_material(surface))
		parts.append({"mesh":mesh,"transform":pose,"layers":item.layers,"shadow":item.cast_shadow})
	for child: Node in node.get_children():
		var failure: String = _collect(child,pose,parts)
		if not failure.is_empty(): return failure
	return ""


## On phones and tablets (`MapScene.lean_profile`) a leafy part of a kind that
## casts at all (not `NO_SHADOW`; in practice the conifers) casts no shadow
## of its own: its cut-out foliage would discard fragment by fragment in the
## shadow pass, which the A12 pays for. An opaque six-sided cone fitted to the
## part's bounds casts instead (shadows only), one more batch per cell.
static func _proxy_shadows(parts: Array[Dictionary]) -> void:
	for index: int in range(parts.size()):
		var part: Dictionary = parts[index]
		var mesh: ArrayMesh = part["mesh"]
		var leafy: bool = false
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(surface)
			leafy = leafy or (material != null and material.resource_name.begins_with("Foliage /"))
		if not leafy:
			continue
		# The part's whole bounds, trunk and crown: its vertices are not read
		# back from the renderer (`prepare_template`).
		var crown: AABB = mesh.get_aabb()
		part["shadow"] = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var proxy: ArrayMesh = ArrayMesh.new()
		proxy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cone_arrays(CONE_TOP,
			maxf(crown.size.x, crown.size.z) * 0.42, crown.size.y))
		var relative: Transform3D = part["transform"]
		parts.append({"mesh": proxy, "layers": part["layers"],
			"transform": relative * Transform3D(Basis(), crown.get_center()),
			"shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY})


## The shadow proxy's cone, `CONE_SIDES` sides, open at the top: the arrays a
## `CylinderMesh` of these radii and `height` with no rings and no top cap
## uploads, laid out on the CPU. Its own arrays (`get_mesh_arrays`) are read
## back from the renderer, a stall until the GPU has drained, and the kit's
## templates are prepared under the launch rite's frames (#660).
static func cone_arrays(top: float, bottom: float, height: float) -> Array:
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var slope: float = (bottom - top) / height
	for row: int in range(2):
		var radius: float = top if row == 0 else bottom
		for i: int in range(CONE_SIDES + 1):
			var u: float = float(i) / CONE_SIDES
			var x: float = sin(u * TAU)
			var z: float = cos(u * TAU)
			points.append(Vector3(x * radius, height * (0.5 - row), z * radius))
			normals.append(Vector3(x, slope, z).normalized())
			tangents.append_array([z, 0.0, -x, 1.0])
			uvs.append(Vector2(u, row * 0.5))
			if row == 1 and i > 0:
				var below: int = CONE_SIDES + i
				indices.append_array([i - 1, i, below, i, below + 1, below])
	var centre: int = points.size()
	points.append(Vector3(0.0, -height * 0.5, 0.0))
	normals.append(Vector3.DOWN)
	tangents.append_array([1.0, 0.0, 0.0, 1.0])
	uvs.append(Vector2(0.75, 0.75))
	for i: int in range(CONE_SIDES + 1):
		var u: float = float(i) / CONE_SIDES
		var x: float = sin(u * TAU)
		var z: float = cos(u * TAU)
		points.append(Vector3(x * bottom, -height * 0.5, z * bottom))
		normals.append(Vector3.DOWN)
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
		uvs.append(Vector2((x + 1.0) * 0.25 + 0.5, 1.0 - (z + 1.0) * 0.25))
		if i > 0:
			indices.append_array([centre, centre + i, centre + i + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

