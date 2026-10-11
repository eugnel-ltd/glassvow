extends RefCounted
## PathWarm (#682), the first map open's and the first fight's shaders paid
## for ahead, as far as the headless suite can hold it:
## - the warm holds every material it makes for the process: a generated
##   shader, and a Shader built from a string, die with their last material,
##   and every pipeline built for them goes with it, so a material let go
##   would leave the fight to compile again;
## - the warm lets go of every view and sample it draws on once drawn: frame
##   0's stages after the frame that draws them, their redraw after the floor
##   bake's switches likewise, each 2D sample at the next step, and the warm
##   itself once its steps are done.
## The suite never draws, so "drawn" is the renderer's frame_post_draw signal,
## emitted here. What the warm draws, and that the fight then compiles
## nothing, is measured on the device (#682's B7 read) and windowed.

## Calls a warm may take to finish its steps, driven here a step a call.
const STEP_LIMIT: int = 200


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_path_warm: %s" % what)


static func run(fails: Array[String]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Node = Node.new()
	host.name = "PathWarmTestHost"
	tree.root.add_child(host)
	await _frame_zero(fails, tree, host)
	await _title_steps(fails, tree, host)
	host.free()


## Every material a view of `root` wears, its 3D surfaces' and its sky's.
static func _worn(root: Node) -> Array[Material]:
	var out: Array[Material] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.material_override != null:
			out.append(mesh.material_override)
		for surface: int in range(mesh.get_surface_override_material_count()):
			if mesh.get_surface_override_material(surface) != null:
				out.append(mesh.get_surface_override_material(surface))
	for node: Node in root.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = (node as WorldEnvironment).environment
		if env != null and env.sky != null:
			out.append(env.sky.sky_material)
	return out


static func _weak(mats: Array[Material]) -> Array[WeakRef]:
	var out: Array[WeakRef] = []
	for mat: Material in mats:
		out.append(weakref(mat))
	return out


static func _alive(refs: Array[WeakRef]) -> int:
	var alive: int = 0
	for ref: WeakRef in refs:
		alive += 1 if ref.get_ref() != null else 0
	return alive


## Frame 0's stages: drawn once, then let go; what they wore outlives them.
static func _frame_zero(fails: Array[String], tree: SceneTree, host: Node) -> void:
	PathWarm.prime_targets(host)
	var holder: Node = host.get_node_or_null("PathWarmTargets")
	_check(fails, holder != null and holder.find_children("*", "SubViewport", true, false).size() == 2,
		"frame 0 stands the foe's and the card's stages")
	if holder == null:
		return
	var refs: Array[WeakRef] = _weak(_worn(holder))
	_check(fails, refs.size() >= 10, "frame 0's stages wear the fight's materials and the sky (%d)" % refs.size())
	RenderingServer.frame_post_draw.emit()
	await tree.process_frame
	_check(fails, not is_instance_valid(holder), "frame 0's stages are let go once drawn")
	_check(fails, _alive(refs) == refs.size(),
		"every material frame 0's stages wore outlives them (%d of %d)" % [_alive(refs), refs.size()])


## The title's steps: the redraw of frame 0's stages, then the 2D materials
## made and each drawn once; every view and sample let go once drawn, the warm
## gone at the end, and every material it made still held.
static func _title_steps(fails: Array[String], tree: SceneTree, host: Node) -> void:
	var warm: PathWarm = PathWarm.new(func() -> bool: return true)
	host.add_child(warm)
	warm.set_process(false)
	var redraw: Array[Node] = []
	var samples: int = 0
	var lingering: int = 0
	var canvas: Array[WeakRef] = []
	for _call: int in range(STEP_LIMIT):
		if not is_instance_valid(warm) or warm.is_queued_for_deletion():
			break
		var before: Node = warm._sample
		warm._process(1.0)
		if before != null and is_instance_valid(before) and not before.is_queued_for_deletion():
			lingering += 1
		if warm._sample != null:
			samples += 1
		for node: Node in warm.get_children():
			if node.name == "PathWarmTargets" and not redraw.has(node):
				redraw.append(node)
		if canvas.is_empty() and warm._settled >= 0.0:
			canvas = _weak(warm._canvas)
		RenderingServer.frame_post_draw.emit()
		await tree.process_frame
	_check(fails, redraw.size() == 1, "the title redraws frame 0's stages once (%d)" % redraw.size())
	_check(fails, redraw.size() == 1 and not is_instance_valid(redraw[0]), "the redrawn stages are let go once drawn")
	_check(fails, not canvas.is_empty() and samples == canvas.size() and lingering == 0,
		"each 2D material is drawn once and its sample let go at the next step (%d drawn of %d, %d kept)" % [
			samples, canvas.size(), lingering])
	_check(fails, not is_instance_valid(warm), "the warm lets itself go once its steps are done")
	await tree.process_frame
	_check(fails, host.get_child_count() == 0, "nothing the warm drew on stays in the tree (%d nodes)" % host.get_child_count())
	_check(fails, _alive(canvas) == canvas.size(),
		"every 2D material the warm made outlives it (%d of %d)" % [_alive(canvas), canvas.size()])
