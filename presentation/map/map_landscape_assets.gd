class_name MapLandscapeAssets
extends RefCounted
## Fixed-camera painted meshes and sculpted stone share the compiler's real bounds.
## The 40-degree tilt is baked into each card's vertices, including its footprint.

const ROOT: String = "res://assets/art/map-atelier/"
## The ground pictures. Every other picture an act draws is a painted card.
const TERRAIN: Array[String] = ["slate-heath.png", "forest-floor.png"]
const GATES: Array[String] = ["amber-tower", "drowned-gate", "obsidian-ring", "rose-gate"]
const SCENERY: Array[Array] = [
	["ash-copse", "ash-tree", "heath-tuft", "slate-cluster"],
	["drowned-cloister", "heath-tuft", "slate-cluster"],
	["obsidian-blades", "slate-cluster"],
	["memorials", "ash-tree", "heath-tuft", "slate-cluster"],
]

var ground: Texture2D
var stone: Texture2D
var meshes: Dictionary[String, Mesh] = {}
var profiles: Dictionary = {}
var registry: MapAssetProfiles
var digest: String = ""
var paths: PackedStringArray = []
var resources: Array[Resource] = []
var failure: String = ""
var act: int = 0
## The build `step` carries on, piece by piece; emptied once it is complete.
var _pictures: Pictures = null
var _ids: Array[String] = []
var _rows: Array = []
var _defaults: Dictionary = {}
var _values: Array[Dictionary] = []
## Each card's arrays as it was built, for its profile (`_profile_mesh`).
var _card_arrays: Dictionary[String, Array] = {}
var _piece: int = 0
var _complete: bool = false

## The one catalogue `for_act` keeps for the life of the process.
static var _kept: MapLandscapeAssets = null
## A catalogue `prepare_step` is building a piece at a time, kept once complete.
static var _building: MapLandscapeAssets = null
## The act whose pictures are decoding on a worker for the next `for_act`.
static var _warming: Pictures = null
## Warm-ups no longer wanted, held until their worker task has ended.
static var _retired: Array[Pictures] = []
## One upload at a time. The RenderingDevice keeps a staging buffer, as large as
## the largest picture, for every upload it ever ran side by side; decoding in
## parallel but uploading in turn keeps that to one.
static var _upload: Mutex = Mutex.new()
## The slate cluster, held once `prime` has read its faces back.
static var _slate: PackedScene = null


## `pictures` is the act's decoded artwork, from `prefetch`; without it (or for
## another act) the pictures are decoded now, while the calling thread waits.
## Built at once, unless `stepped`: then `step` builds it a piece at a time.
func _init(act_index: int = 0, pictures: Pictures = null, stepped: bool = false) -> void:
	act = clampi(act_index, 0, 3)
	_pictures = pictures if pictures != null and pictures.act == act else Pictures.new(act)
	_ids = declared_ids(act)
	if not stepped:
		while not step():
			pass


## Builds the next piece of the catalogue and answers whether it is complete
## (or has failed): the terrain, then each declared asset's mesh, then each
## one's profile, then the digest. No piece reads a mesh back from the renderer,
## a stall until the GPU has drained that the title's frames cannot pay: a card
## is laid out on the CPU and profiled from its own arrays, and the slate
## cluster's faces were read before the first frame (`prime`). `prepare_step`
## spreads the pieces over frames.
func step() -> bool:
	if _complete:
		return true
	var count: int = _ids.size()
	if _piece == 0:
		_pictures.finish()
		stone = _terrain(_pictures, TERRAIN[0])
		ground = stone if act == 2 else _terrain(_pictures, TERRAIN[1])
		if ground == null or stone == null:
			return _end("Cannot load landscape terrain")
	elif _piece <= count:
		var id: String = _ids[_piece - 1]
		if not _add_mesh(id):
			return _end("Cannot load landscape asset: " + id)
	elif _piece <= 2 * count:
		if registry == null:
			registry = MapAssetProfiles.new({"assets": _rows, "profile_defaults": _defaults}, ROOT)
		var id: String = _ids[_piece - count - 1]
		var profile: Dictionary = registry.profile(id, _profile_mesh(id))
		if profile.is_empty():
			return _end("Invalid landscape geometry: " + id)
		profiles[id] = profile
		_values.append(profile)
	else:
		digest = registry.digest(_values)
		return _end("")
	_piece += 1
	return false


func _add_mesh(id: String) -> bool:
	var spec: Dictionary = _spec(id)
	var path: String = ROOT + str(spec["file"])
	var mesh: Mesh
	if id == "slate-cluster":
		var source: PackedScene = load(path) as PackedScene
		if source != null:
			var node: Node = source.instantiate()
			mesh = _first_mesh(node)
			node.free()
			resources.append(source)
	else:
		mesh = _card(id, _pictures.texture(str(spec["file"])), spec)
	if mesh == null:
		return false
	meshes[id] = mesh
	if not paths.has(path):
		paths.append(path)
	var hero: bool = id in GATES or id == "vigil"
	_rows.append({"id": id, "kind": "terminus" if hero else "kit",
		"act": act, "path": str(spec["file"])})
	_defaults[id] = {"scale": 1.0,
		"semantic_class": "hero" if hero else "scenery",
		"yaw_mode": "free" if id == "slate-cluster" else "fixed", "yaw_degrees": 0.0}
	return true


## Ends the build, failed with `reason` or complete when it is empty, and lets
## go of what only the build needed.
func _end(reason: String) -> bool:
	failure = reason
	_complete = true
	_pictures = null
	_rows = []
	_defaults = {}
	_values = []
	_card_arrays = {}
	return true


## The act's catalogue, decoded once and kept until another act is asked for
## (#621). Decoding an act's artwork is most of the cost of opening the map, and
## the player reopens the same act after every fight, event, shop and rest. Only
## one act is kept, so the previous act's artwork is released on an act change
## (the residency contract `tools/bench_map_assets.gd` measures, #295). A
## catalogue that failed is returned but never kept. Callers treat the result as
## read-only: every map screen of the act shares it.
##
## When `prefetch` warmed the act, its pictures are used as they are; when the
## warm-up is still running, the pictures its worker has not reached are decoded
## at once and only the one it is on is waited for. A warm-up of another act is
## never waited for. A catalogue `prepare_step` began is finished here.
static func for_act(act_index: int) -> MapLandscapeAssets:
	var wanted: int = clampi(act_index, 0, 3)
	if _kept != null and _kept.act == wanted:
		return _kept
	var assets: MapLandscapeAssets = _begin(wanted)
	_building = null
	while not assets.step():
		pass
	if assets.failure.is_empty():
		_kept = assets
	return assets


## Builds the act's catalogue one piece per call (`step`) and keeps it once it
## is complete, as `for_act` would: the journey prefetch spreads it over the
## title's frames. Returns the catalogue once it is complete (check `failure`),
## null while pieces remain. Its pictures should be warm first (`prefetch`),
## or the first piece decodes them.
static func prepare_step(act_index: int) -> MapLandscapeAssets:
	var wanted: int = clampi(act_index, 0, 3)
	if _kept != null and _kept.act == wanted:
		return _kept
	_building = _begin(wanted)
	if not _building.step():
		return null
	var assets: MapLandscapeAssets = _building
	_building = null
	if assets.failure.is_empty():
		_kept = assets
	return assets


## The act's catalogue under construction: the one `prepare_step` began, or a
## new one from the act's warm pictures. Anything kept for another act goes.
static func _begin(wanted: int) -> MapLandscapeAssets:
	_kept = null
	if _building != null and _building.act == wanted:
		return _building
	var warm: Pictures = _warming
	_warming = null
	if warm != null and warm.act != wanted:
		_retire(warm)
		warm = null
	_reap()
	return MapLandscapeAssets.new(wanted, warm, true)


## Starts decoding an act's pictures on a WorkerThreadPool task, so the first
## map of that act (a new or resumed run, or the act after a boss) does not
## decode them on the main thread. Does nothing when the act is kept, already
## warming or being built. Warming another act releases the kept one, so one
## act's artwork is held at a time, as `for_act` promises.
static func prefetch(act_index: int) -> void:
	var wanted: int = clampi(act_index, 0, 3)
	if (_kept != null and _kept.act == wanted) or (_warming != null and _warming.act == wanted) \
			or (_building != null and _building.act == wanted):
		return
	_kept = null
	_building = null
	if _warming != null:
		_retire(_warming)
	_reap()
	_warming = Pictures.new(wanted)
	_warming.task = WorkerThreadPool.add_task(_warming.drain, false, "Map landscape pictures")


## Forgets the kept act and stops any warm-up or build, so the next `for_act`
## decodes from nothing: for tests and benches, and for a title with no run to
## return to, which needs no act's artwork.
static func release() -> void:
	_kept = null
	_building = null
	if _warming != null:
		_retire(_warming)
		_warming = null
	_reap()


## Joins every warm-up's worker, for the process's exit (`Main`): a task left
## running holds its pictures, and freeing them after the scripting has shut
## down crashed the engine at exit. No picture is claimed after this.
static func join() -> void:
	if _warming != null:
		_retire(_warming)
		_warming = null
	for pictures: Pictures in _retired:
		if pictures.task >= 0:
			WorkerThreadPool.wait_for_task_completion(pictures.task)
			pictures.task = -1
	_retired.clear()


## The warm-up `prefetch` started, or null. For tests and benches.
static func warming() -> Pictures:
	return _warming


static func _retire(pictures: Pictures) -> void:
	pictures.stop()
	_retired.append(pictures)


## Ends the worker tasks of retired warm-ups that have finished. A task still
## running stays held, so its pictures outlive it.
static func _reap() -> void:
	for pictures: Pictures in _retired.duplicate():
		if pictures.is_done():
			pictures.finish()
			_retired.erase(pictures)


## Every picture an act draws, in bind order: the terrain, then each painted
## card of `declared_ids`.
static func picture_files(act_index: int) -> PackedStringArray:
	var files: PackedStringArray = [TERRAIN[0]]
	if act_index != 2:
		files.append(TERRAIN[1])
	for id: String in declared_ids(act_index):
		if id != "slate-cluster":
			files.append(str(_spec(id)["file"]))
	return files


## Every asset an act declares, in bind order: its scenery, its gate and, for
## Act I only, the Vigil. The one answer to "what must this act resolve", read by
## `_init` and by the count a partial resolve reports. `act_index` is 0-based and
## must already be inside the tables, as `_init` clamps it.
static func declared_ids(act_index: int) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(SCENERY[act_index])
	ids.append(GATES[act_index])
	if act_index == 0:
		ids.append("vigil")
	return ids


## `failure` in words that name the act and how much of its declared set resolved,
## or "" when the set is whole. Resolution stops at the first asset that will not
## load, so `meshes` holds exactly what resolved before it.
func shortfall() -> String:
	if failure.is_empty():
		return ""
	return "Act %d (act_index %d) declares %d landscape assets and resolved %d: %s" % [
		ActFlag.number_of(act), act, declared_ids(act).size(), meshes.size(), failure]


func bundle() -> Dictionary:
	return {} if not failure.is_empty() or digest.is_empty() else {
		"profiles": profiles.duplicate(true), "digest": digest}


static func _spec(id: String) -> Dictionary:
	match id:
		"slate-cluster":
			return {"file": "slate-cluster.glb"}
		"ash-copse":
			return {"file": "ash-copse.png", "height": 4.4}
		"heath-tuft":
			return {"file": "heath-tuft.png", "height": 0.85}
		"ash-tree":
			return {"file": "ash-tree-painted.png", "height": 3.6}
		"vigil":
			return {"file": "vigil-painted.png", "height": 4.5}
		"rose-gate":
			return {"file": "sanctuary-painted.png", "height": 5.8}
		_:
			return {"file": id + ".png", "height": 5.6 if id in GATES else 2.3}


## A painted card from its decoded picture (`_picture`); null when the picture
## did not decode. The quad is laid out here exactly as `QuadMesh` lays it out
## and `SurfaceTool.append_from` tilts it, byte for byte, normals and tangents
## through the renderer's 16-bit encoding included: building it from a
## `QuadMesh` read the quad back from the renderer, a stall the title's frames
## cannot pay (the journey prefetch builds catalogues under them). Its arrays
## are kept for its profile.
func _card(id: String, texture: Texture2D, spec: Dictionary) -> Mesh:
	if texture == null:
		return null
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	resources.append(texture)
	material.albedo_color = Color("b4c6ca") if str(spec["file"]) == "ash-tree-painted.png" else Color("ced4d2")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.3
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var height: float = spec["height"]
	var size: Vector2 = Vector2(height * float(texture.get_width()) / texture.get_height(), height)
	var arrays: Array = card_arrays(size, Vector3(0, height * 0.5, 0))
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_card_arrays[id] = arrays
	return mesh


## A card's surface arrays: a `QuadMesh` of `size` (no subdivision, facing +Z,
## centred on `offset`) tilted back by the camera's angle, as
## `SurfaceTool.append_from` returns it from the renderer. Two rows of two
## corners, from the far-left corner, with the quad's own index order; the
## normal and tangent are the renderer's decoding of the stored +Z and +X.
static func card_arrays(size: Vector2, offset: Vector3) -> Array:
	var tilt: Transform3D = Transform3D(Basis(Vector3.RIGHT,
		deg_to_rad(MapCameraRig.TILT_DEGREES)), Vector3.ZERO)
	var normal: Vector3 = tilt.basis * Vector3.octahedron_decode(_stored(
		Vector3(0, 0, 1).octahedron_encode()))
	var encoded: Vector2 = Vector3(1, 0, 0).octahedron_encode()
	encoded.y = encoded.y * 0.5 + 0.5
	var decoded: Vector2 = _stored(encoded)
	decoded.y = absf(decoded.y * 2.0 - 1.0)
	var tangent: Vector3 = tilt.basis * Vector3.octahedron_decode(decoded)
	var start: Vector2 = size * -0.5
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z: float = start.y
	for row: int in range(2):
		var x: float = start.x
		for column: int in range(2):
			surface.set_normal(normal)
			surface.set_tangent(Plane(tangent, 1.0))
			surface.set_uv(Vector2(1.0 - column, 1.0 - row))
			surface.add_vertex(tilt * (Vector3(-x, z, 0.0) + offset))
			x += size.x
		z += size.y
	for index: int in [0, 1, 2, 1, 3, 2]:
		surface.add_index(index)
	return surface.commit_to_arrays()


## An octahedral pair as the renderer stores it, in 16-bit units, and reads it.
static func _stored(pair: Vector2) -> Vector2:
	return Vector2(float(int(pair.x * 65535.0)) / 65535.0, float(int(pair.y * 65535.0)) / 65535.0)


## The mesh a profile is measured on: a card's own arrays (`HeldSurface`), so
## its faces are not read back from the renderer; the slate cluster as loaded,
## whose faces `prime` read back before the title.
func _profile_mesh(id: String) -> Mesh:
	if _card_arrays.has(id):
		return HeldSurface.new(_card_arrays[id], meshes[id].get_aabb())
	return meshes[id]


## Reads the slate cluster's faces back from the renderer once, before the
## first frame, when nothing is in flight and a read-back costs next to
## nothing, and holds the cluster for the process: the mesh keeps its faces,
## so no catalogue reads them back under a frame (Main's boot).
static func prime() -> void:
	if _slate != null:
		return
	_slate = load(ROOT + str(_spec("slate-cluster")["file"])) as PackedScene
	if _slate == null:
		return
	var node: Node = _slate.instantiate()
	var mesh: Mesh = _first_mesh(node)
	node.free()
	if mesh != null:
		mesh.get_faces()


func _terrain(pictures: Pictures, file: String) -> Texture2D:
	var texture: Texture2D = pictures.texture(file)
	if texture == null:
		return null
	if not paths.has(ROOT + file):
		paths.append(ROOT + file)
	resources.append(texture)
	return texture


## One picture as the map draws it: decoded from its Image import, a painted
## card cropped to its artwork, given the edge bleed the texture importer used to
## apply (so the pixels are the ones it stored), then mipmapped and uploaded.
## Null when the file is missing, or a card has no transparent margin or nothing
## drawn. Touches no shared state and asks the renderer for nothing back, so it
## is safe on a worker thread: the RenderingDevice renderers create the texture
## there, and the others queue it for the main thread.
static func _picture(file: String) -> ImageTexture:
	var path: String = ROOT + file
	if not ResourceLoader.exists(path):
		return null
	# Through the cache: an uncached load from a worker thread can return null
	# in Godot 4.7.2. The cached Image may be shared, so it is only read, and
	# what is edited in place is a copy.
	var source: Image = load(path) as Image
	if source == null or source.is_empty():
		return null
	var image: Image
	if file in TERRAIN:
		image = source.duplicate() as Image
	else:
		if source.detect_alpha() == Image.ALPHA_NONE:
			return null
		var used: Rect2i = source.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			return null
		image = source.get_region(used)
	# After the crop, which is exact and cheaper: the bleed copies colour only
	# from texels with alpha of 20 or more, and none lie outside the used rect.
	image.fix_alpha_edges()
	image.generate_mipmaps()
	_upload.lock()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_upload.unlock()
	return texture


## One surface's arrays held on the CPU, answering what a profile asks of a
## mesh (its box, its faces) without the renderer.
class HeldSurface extends Mesh:
	var _arrays: Array
	var _aabb: AABB

	func _init(arrays: Array, aabb: AABB) -> void:
		_arrays = arrays
		_aabb = aabb

	func _get_surface_count() -> int:
		return 1

	func _surface_get_array_len(_index: int) -> int:
		var vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
		return vertices.size()

	func _surface_get_array_index_len(_index: int) -> int:
		var indices: PackedInt32Array = _arrays[Mesh.ARRAY_INDEX]
		return indices.size()

	func _surface_get_arrays(_index: int) -> Array:
		return _arrays

	func _surface_get_format(_index: int) -> int:
		return Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_INDEX

	func _surface_get_primitive_type(_index: int) -> int:
		return Mesh.PRIMITIVE_TRIANGLES

	func _get_aabb() -> AABB:
		return _aabb


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child: Node in node.get_children():
		var found: Mesh = _first_mesh(child)
		if found != null:
			return found
	return null


## An act's pictures, each decoded once by whichever thread claims it first:
## the worker `prefetch` starts, or the threads `finish` adds when the map
## opens before that worker is done.
class Pictures extends RefCounted:
	var act: int
	var files: PackedStringArray
	## File name to its texture; a file that did not decode is absent.
	var textures: Dictionary[String, ImageTexture] = {}
	## Every file decoded so far, in the order each finished.
	var decoded: PackedStringArray = []
	## The worker task decoding these pictures, or -1 when none is owed a wait.
	var task: int = -1
	var _next: int = 0
	var _stopped: bool = false
	var _lock: Mutex = Mutex.new()

	func _init(act_index: int) -> void:
		act = act_index
		files = MapLandscapeAssets.picture_files(act_index)

	## Decodes the next unclaimed picture. False once none is left or `stop`
	## was called.
	func step() -> bool:
		_lock.lock()
		if _stopped or _next >= files.size():
			_lock.unlock()
			return false
		var file: String = files[_next]
		_next += 1
		_lock.unlock()
		var texture: ImageTexture = MapLandscapeAssets._picture(file)
		_lock.lock()
		if texture != null:
			textures[file] = texture
		decoded.append(file)
		_lock.unlock()
		return true

	## The decoded texture of `file`, or null when it did not decode.
	func texture(file: String) -> ImageTexture:
		return textures[file] if textures.has(file) else null

	func drain() -> void:
		while step():
			pass

	## Decodes whatever is still unclaimed, then waits for the warm-up's worker
	## to end the picture it is on. The calling thread waits for the pictures
	## in any case, so they are decoded side by side on high-priority pool
	## threads rather than one after another.
	func finish() -> void:
		_lock.lock()
		var left: int = 0 if _stopped else files.size() - _next
		_lock.unlock()
		if left > 0:
			WorkerThreadPool.wait_for_group_task_completion(WorkerThreadPool.add_group_task(
				_claim, left, -1, true, "Map landscape pictures"))
		if task >= 0:
			WorkerThreadPool.wait_for_task_completion(task)
			task = -1

	func _claim(_index: int) -> void:
		step()

	## No picture is claimed after this; one being decoded completes.
	func stop() -> void:
		_lock.lock()
		_stopped = true
		_lock.unlock()

	func is_done() -> bool:
		return task < 0 or WorkerThreadPool.is_task_completed(task)
