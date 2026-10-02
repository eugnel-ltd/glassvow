extends RefCounted
## The death frame builds, it does not cut. `mark_dead()` starts carving the relieved net
## and extruding every piece on a WorkerThreadPool task while the vessel ignites;
## `shatter()` joins it and only uploads meshes and makes nodes. The pieces must be the
## ones the old in-frame build made — the same prism, and a collider on the same point set
## `get_faces()` used to hand the hull — and anything that changes the net, or the view
## going away, must join the task before it does.

const BLOWS: Array[Array] = [
	[Vector2(0.45, 0.5), 6], [Vector2(0.6, 0.4), 4], [Vector2(0.35, 0.62), 5],
	[Vector2(0.7, 0.6), 6], [Vector2(0.3, 0.4), 5], [Vector2(0.55, 0.7), 6],
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("enemy death shards: %s" % what)


static func run(fails: Array[String]) -> void:
	_cut_is_the_old_build(fails)
	_break_takes_the_prepared_cut(fails)
	_a_blow_or_reset_drops_the_cut(fails)
	_no_net_cuts_on_the_frame(fails)
	_freeing_joins_the_cut(fails)


static func _foe() -> EnemyView:
	var foe: EnemyView = EnemyView.new(0, "Duskfang", 210.0, &"duskfang")
	(Engine.get_main_loop() as SceneTree).root.add_child(foe)
	return foe


static func _wound(foe: EnemyView) -> void:
	for blow: Array in BLOWS:
		var at: Vector2 = blow[0]
		var damage: int = blow[1]
		foe.crack(at, damage)


static func _point_set(points: PackedVector3Array) -> Dictionary:
	var out: Dictionary = {}
	for p: Vector3 in points:
		out[p] = true
	return out


static func _same_set(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for p: Vector3 in a:
		if not b.has(p):
			return false
	return true


static func _cut_is_the_old_build(fails: Array[String]) -> void:
	var foe: EnemyView = _foe()
	_wound(foe)
	foe._relieve_net()
	var cells: Array[PackedVector2Array] = foe._death_cells(Vector2(0.0, foe._box_u * 0.05))
	var cuts: Array[EnemyView.ShardCut] = foe._cut(cells)
	_check(fails, cells.size() > 4 and cuts.size() == cells.size(),
		"a six-blow duskfang carves into pieces, every one of them cut")
	var thick: float = foe._shard_thick()
	var box: Vector2 = Vector2(foe._quad_w, foe._box_u)
	var meshes_same: bool = true
	var hulls_same: bool = true
	for i: int in range(mini(cells.size(), cuts.size())):
		var cut: EnemyView.ShardCut = cuts[i]
		var old: ArrayMesh = EnemyView._prism(cells[i], thick, box, cut.centre)
		var built: ArrayMesh = EnemyView._mesh_of(cut.arrays)
		var oa: Array = old.surface_get_arrays(0)
		var ba: Array = built.surface_get_arrays(0)
		for k: int in range(Mesh.ARRAY_MAX):
			meshes_same = meshes_same and typeof(oa[k]) == typeof(ba[k]) and oa[k] == ba[k]
		meshes_same = meshes_same and old.surface_get_format(0) == built.surface_get_format(0)
		hulls_same = hulls_same and _same_set(_point_set(old.get_faces()),
			_point_set(cut.hull))
	_check(fails, meshes_same, "a cut piece's mesh is the prism the rite always built")
	_check(fails, hulls_same,
		"a collider's points are exactly the set the mesh read-back gave the hull")
	foe.free()


static func _break_takes_the_prepared_cut(fails: Array[String]) -> void:
	var foe: EnemyView = _foe()
	_wound(foe)
	foe.mark_dead()
	_check(fails, foe._cut_task >= 0, "mark_dead starts the cut on a worker")
	if foe._cut_task < 0:
		# No task to wait for: the regression is already recorded, so stop here
		# instead of spinning on an invalid task id until CI times out.
		foe.free()
		return
	while not WorkerThreadPool.is_task_completed(foe._cut_task):
		OS.delay_msec(1)
	_check(fails, foe._cut_out.size() > 4, "the worker cuts the relieved net into pieces")
	# Mark one prepared piece, so the break can be seen to use it rather than recut.
	var marked: EnemyView.ShardCut = foe._cut_out[0]
	var sentinel: PackedVector3Array = marked.hull.duplicate()
	sentinel.append(Vector3(0.0, 0.0, 1.0))
	marked.hull = sentinel
	var prepared: int = foe._cut_out.size()
	foe.shatter()
	var bodies: Array[Node] = foe._debris.find_children("", "RigidBody3D", true, false)
	_check(fails, bodies.size() == prepared, "the break flies every prepared piece")
	var first: CollisionShape3D = null
	if not bodies.is_empty():
		first = bodies[0].find_children("", "CollisionShape3D", false, false)[0]
	_check(fails, first != null and (first.shape as ConvexPolygonShape3D).points == sentinel,
		"the break builds from the prepared cut instead of carving again")
	_check(fails, foe._cut_task == -1 and foe._cut_out.is_empty(),
		"the break joins and releases the cut")
	foe.free()


static func _a_blow_or_reset_drops_the_cut(fails: Array[String]) -> void:
	var foe: EnemyView = _foe()
	_wound(foe)
	foe.mark_dead()
	foe.strike(Vector2(0.5, 0.3))
	_check(fails, foe._cut_task == -1 and foe._cut_out.is_empty(),
		"a blow during the ignition joins and drops the cut of the old net")
	foe.shatter()
	var fresh: Array[EnemyView.ShardCut] = foe._cut(
		foe._death_cells(Vector2(0.0, foe._box_u * 0.05)))
	var bodies: Array[Node] = foe._debris.find_children("", "RigidBody3D", true, false)
	_check(fails, bodies.size() == fresh.size(),
		"a dropped cut is recut from the net as it stands at the break")
	foe.free()

	var again: EnemyView = _foe()
	_wound(again)
	again.mark_dead()
	again.reset_glass()
	_check(fails, again._cut_task == -1 and again._cut_out.is_empty(),
		"a reset joins and drops the cut")
	again.free()


static func _no_net_cuts_on_the_frame(fails: Array[String]) -> void:
	var foe: EnemyView = _foe()
	foe.mark_dead()
	_check(fails, foe._cut_task == -1,
		"an unstruck vessel starts no cut: the Voronoi fallback draws from _frac")
	foe.shatter()
	_check(fails, not foe._debris.find_children("", "RigidBody3D", true, false).is_empty(),
		"an unstruck vessel still breaks, cut on the frame as before")
	foe.free()


static func _freeing_joins_the_cut(fails: Array[String]) -> void:
	var foe: EnemyView = _foe()
	_wound(foe)
	foe.mark_dead()
	var task: int = foe._cut_task
	foe.free()
	_check(fails, task >= 0, "the freed foe had a cut in flight")
