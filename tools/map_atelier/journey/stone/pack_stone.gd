extends SceneTree
## Packs Act I's hero stone (R3.3, issue #660) for the game: each outcrop's
## and cliff piece's reduced mesh (`glb/<kind>.glb`, from `build_stone.py`) as
## plain arrays in `assets/art/map-journey/stone/stone-pieces.res`
## (`stone_pieces.gd`), which a land merges on its worker without reading
## anything back from the renderer (`land_stone.gd`). The headless renderer
## keeps an imported mesh's arrays, so this runs headless:
##
##   godot --headless --path . -s res://tools/map_atelier/journey/stone/pack_stone.gd

const Pieces = preload("res://presentation/map/landscape/stone_pieces.gd")
const LandStone = preload("res://presentation/map/landscape/land_stone.gd")
const SOURCES: String = "res://tools/map_atelier/journey/stone/glb/"
const KEPT: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV,
	Mesh.ARRAY_INDEX]


func _initialize() -> void:
	var pieces: Pieces = Pieces.new()
	var failures: PackedStringArray = []
	for kind: String in Array(LandStone.OUTCROPS) + Array(LandStone.CLIFFS):
		var scene: PackedScene = load(SOURCES + kind + ".glb") as PackedScene
		if scene == null:
			failures.append("cannot load " + kind)
			continue
		var root: Node3D = scene.instantiate() as Node3D
		var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		if found.size() != 1:
			failures.append("%s: %d meshes, not one" % [kind, found.size()])
			root.free()
			continue
		var item: MeshInstance3D = found[0]
		# Blender applied every transform on export: the mesh is in the kind's
		# own space.
		if not _pose(item, root).is_equal_approx(Transform3D.IDENTITY):
			failures.append(kind + ": its mesh is not at the scene's origin")
			root.free()
			continue
		var source: Array = item.mesh.surface_get_arrays(0)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		for slot: int in KEPT:
			arrays[slot] = source[slot]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		if tangents.is_empty():
			failures.append(kind + ": no tangents")
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bounds: AABB = AABB(points[0], Vector3.ZERO)
		for point: Vector3 in points:
			bounds = bounds.expand(point)
		pieces.arrays[kind] = arrays
		pieces.bounds[kind] = bounds
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		print("%-16s %5d triangles  %s" % [kind, index.size() / 3, bounds])
		root.free()
	if not failures.is_empty():
		printerr("PACK_STONE FAIL: " + "; ".join(failures))
		quit(1)
		return
	var error: Error = ResourceSaver.save(pieces, LandStone.PIECES_PATH, ResourceSaver.FLAG_COMPRESS)
	print("PACK_STONE %s (%d kinds)" % ["OK" if error == OK else "FAIL %d" % error, pieces.arrays.size()])
	quit(0 if error == OK else 1)


## `node`'s pose relative to `root`, read up its parents (off the tree).
static func _pose(node: Node3D, root: Node3D) -> Transform3D:
	var pose: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != root:
		pose = (parent as Node3D).transform * pose
		parent = parent.get_parent()
	return pose
