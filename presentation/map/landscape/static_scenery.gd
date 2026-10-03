extends Node3D
## Static imported meshes share spatially bounded draw batches. Placement anchors
## retain identity; each actual GPU instance is linked back to its source part.
const Surfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
const CELL: float = 32.0
## Ground-hugging kinds whose shadows the 55° camera barely sees: they render
## lit but stay out of the shadow pass, which keeps that pass inside the A12
## budget (trees, banks, ridges and the gateway still cast).
const NO_SHADOW: PackedStringArray = ["ash-heath", "ash-copse", "ash-fern", "ash-bramble", "slate-scree"]
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
	_shared[path] = {"root":original.transform,"parts":parts,"kind":kind}
	original.free()
	return failure


func prepare(path: String, kind: String) -> Node3D:
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
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if str(groups[key]["kind"]) in NO_SHADOW else part["shadow"]
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
