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
##   itself once its steps are done;
## - what the floor bake's switches free is drawn again only once the bake has
##   ended (#682 Part 2), and Act I's kept land, lent to the map's view a frame
##   at a time, comes back as it was kept.
## The suite never draws, so "drawn" is the renderer's frame_post_draw signal,
## emitted here. What the warm draws, and that the fight then compiles
## nothing, is measured on the device (#682's B7 read) and windowed.

## Calls a warm may take to finish its steps, driven here a step a call.
const STEP_LIMIT: int = 200
## Calls the warm is held at the floor bake's gate before the bake ends.
const GATE_CALLS: int = 5
const LAND_KEY: String = "test_path_warm"
## The views drawn only once the floor bake has ended.
const AFTER_BAKE: Array[String] = ["PathWarmMap", "PathWarmFoe", "PathWarmCard"]


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
	await _land_lent(fails, tree, host)
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


## The planes a foe stage draws: those in front of its camera (looking down -Z).
static func _drawn(stage: Node) -> int:
	var front: int = 0
	for node: Node in stage.find_children("*", "MeshInstance3D", true, false):
		front += 1 if (node as MeshInstance3D).position.z < 0.0 else 0
	return front


static func _count(counts: Dictionary[String, int], key: String) -> int:
	return counts[key] if counts.has(key) else 0


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
	var foe: Node = holder.find_child("PathWarmFoe", true, false)
	_check(fails, foe != null and _drawn(foe) == 3 and foe.find_children("*", "OmniLight3D", true, false).size() == 2,
		"frame 0 draws the foe's body, shadow and ward (the first card play's) under two omni lights, as EnemyView lights them")
	RenderingServer.frame_post_draw.emit()
	await tree.process_frame
	_check(fails, not is_instance_valid(holder), "frame 0's stages are let go once drawn")
	_check(fails, _alive(refs) == refs.size(),
		"every material frame 0's stages wore outlives them (%d of %d)" % [_alive(refs), refs.size()])


## The title's steps: the 2D materials made and each drawn once, and the
## engine's own canvas kinds sampled once each; then, only once the floor bake
## has ended, the map's view, frame 0's stages again (the foe's, then the
## card's, a frame each) and the land's steps. Every view and sample let go
## once drawn, the warm gone at the end, and every material it made held.
static func _title_steps(fails: Array[String], tree: SceneTree, host: Node) -> void:
	MapScene.release_kept_journey()
	var gate: MapJourneyPrefetch = MapJourneyPrefetch.new()
	gate.step = MapJourneyPrefetch.Step.BAKING
	var kept: MapJourneyPrefetch = MapJourneyPrefetch._current
	MapJourneyPrefetch._current = gate
	var warm: PathWarm = PathWarm.new(func() -> bool: return true)
	host.add_child(warm)
	warm.set_process(false)
	var views: Dictionary[String, int] = {}
	var seen: Array[Node] = []
	var kinds: Dictionary[String, int] = {}
	var lingering: int = 0
	var canvas: Array[WeakRef] = []
	var held_at_gate: int = 0
	var early: int = 0
	var ward_drawn: bool = false
	var ends_waiting: int = -1
	for _call: int in range(STEP_LIMIT):
		if not is_instance_valid(warm) or warm.is_queued_for_deletion():
			break
		var gated: bool = gate.step == MapJourneyPrefetch.Step.BAKING
		if gated and not warm._steps.is_empty() and warm._steps[0] == warm._await_bake:
			held_at_gate += 1
			if held_at_gate == GATE_CALLS:
				gate.step = MapJourneyPrefetch.Step.DONE
		var before: Node = warm._sample
		warm._process(1.0)
		if before != null and is_instance_valid(before) and not before.is_queued_for_deletion():
			lingering += 1
		if warm._sample != null:
			var kind: String = warm._sample.get_class()
			kinds[kind] = _count(kinds, kind) + 1
		for node: Node in warm.find_children("*", "SubViewport", true, false):
			if not seen.has(node):
				seen.append(node)
				if node.name == "PathWarmFoe":
					ward_drawn = _drawn(node) == 3
				views[node.name] = _count(views, node.name) + 1
				early += 1 if gated and node.name in AFTER_BAKE else 0
		if canvas.is_empty() and warm._settled >= 0.0:
			canvas = _weak(warm._canvas)
			var n: int = warm._steps.size()
			ends_waiting = 1 if n >= 4 and warm._steps[n - 4] == warm._land_queue \
				and warm._steps[n - 3] == warm._await_compiles and warm._steps[n - 2] == warm._land_draw \
				and warm._steps[n - 1] == warm._await_compiles else 0
		RenderingServer.frame_post_draw.emit()
		await tree.process_frame
	MapJourneyPrefetch._current = kept
	_check(fails, held_at_gate == GATE_CALLS and early == 0,
		"nothing is redrawn while the floor bake runs (held %d calls, %d views early)" % [held_at_gate, early])
	_check(fails, ward_drawn, "the foe's redraw draws the ward again with the body and the shadow")
	_check(fails, ends_waiting == 1,
		"the warm queues the land, waits for its compiles, draws it, and ends only once that draw's compiles are done")
	_check(fails, _count(views, "PathWarmMap") == 1 and _count(views, "PathWarmFoe") == 1 and _count(views, "PathWarmCard") == 1,
		"after the bake the map's view, the foe's and the card's stages stand once each (%s)" % str(views))
	_check(fails, _count(kinds, "ColorRect") == canvas.size() and _count(kinds, "NinePatchRect") == 1
			and _count(kinds, "Polygon2D") == 1 and _count(kinds, "Control") == 1 and lingering == 0,
		"each 2D material and each canvas kind is drawn once and let go at the next step (%s of %d, %d kept)" % [
			str(kinds), canvas.size(), lingering])
	_check(fails, not is_instance_valid(warm), "the warm lets itself go once its steps are done")
	await tree.process_frame
	_check(fails, host.get_child_count() == 0, "nothing the warm drew on stays in the tree (%d nodes)" % host.get_child_count())
	_check(fails, _alive(canvas) == canvas.size(),
		"every 2D material the warm made outlives it (%d of %d)" % [_alive(canvas), canvas.size()])


## Act I's kept land, lent to the map's view a frame at a time: lent with its
## scripts and particles stilled, given back at the frame's end as it was
## kept, and taken back by any bind meanwhile.
static func _land_lent(fails: Array[String], tree: SceneTree, host: Node) -> void:
	var land: MapJourneyLandscape = MapJourneyLandscape.new()
	MapScene._keep_journey(LAND_KEY, land)
	var warm: PathWarm = PathWarm.new(func() -> bool: return true)
	host.add_child(warm)
	warm.set_process(false)
	warm._map_look()
	for step: Callable in [warm._land_queue, warm._land_draw]:
		step.call()
		_check(fails, land.get_parent() == warm._map_view and land.process_mode == Node.PROCESS_MODE_DISABLED,
			"the land stands still on the map's view while lent")
		RenderingServer.frame_post_draw.emit()
		await tree.process_frame
		_check(fails, land.get_parent() == null and land.process_mode == Node.PROCESS_MODE_INHERIT,
			"the land is given back as it was kept at the frame's end")
	_check(fails, warm._map_view == null, "the map's view is let go once the land is drawn")
	var lent: MapJourneyLandscape = MapScene.lend_journey()
	host.add_child(lent)
	_check(fails, MapScene._kept_for(LAND_KEY) == land and land.get_parent() == null,
		"a map binding while the land is lent takes it back")
	warm.free()
	MapScene.release_kept_journey()
	_check(fails, not is_instance_valid(land), "the kept land is let go as before")
