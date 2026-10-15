class_name MapLandWarm
extends Node
## The kept journey land drawn ahead, unseen, so the map that opens on it
## builds none of its surfaces' pipelines (#682 Part 2): first lent to a view
## of the map's stage for a frame no camera sees (the engine queues its
## pipelines in the background for every target format the map draws with),
## then, once those have compiled, drawn once whole from above, lit as its own
## act lights it (their specialised pipelines). Its scripts and particles
## stand still while it is lent, and a map opening meanwhile takes it back
## (`MapScene.lend_journey`).
##
## `PathWarm` steps it under the title for the land the title built ahead;
## `Main` runs it on its own (`alone`) for the next act's land, built ahead
## under the boss's rewards (#660 II.3), a step a frame.

## The eye the land is drawn from: straight down from this height (metres),
## seeing a square this wide, more than the land's bounds
## (`MapJourneyLandscape.MAP_BOUNDS`).
const EYE_HEIGHT: float = 60.0
const EYE_SPAN: float = 140.0
## How long past the queued pipelines' start the last ones are given to end.
const SETTLE: float = 2.0

## The view of the map's stage the land is drawn on.
var view: SubViewport = null
var _canaries: Array[int] = []
var _settle_until: int = 0
## The steps a warm running alone takes, a frame each (`alone`); none for a
## warm another stepper drives (`PathWarm`).
var _steps: Array[Callable] = []
var _alone: bool = false


## A warm that runs itself, a step a frame, and frees itself when done or when
## there is no kept land to draw.
static func alone() -> MapLandWarm:
	var warm: MapLandWarm = MapLandWarm.new()
	warm.name = "MapLandWarm"
	warm._alone = true
	warm._steps = [warm.look, warm._queue_step, warm._compiled_step, warm._draw_step,
		warm._compiled_step]
	return warm


func _process(_delta: float) -> void:
	if not _alone:
		set_process(false)
	elif not _steps.is_empty():
		var step: Callable = _steps.pop_front()
		step.call()
	elif view == null:
		queue_free()


## A view of the map's stage (`MapScene.stage_view`), lit as the kept land's
## act lights it (its class's `light`; Act I's when none is kept), drawn
## empty: its glow's post pass is a target format of its own, and the engine
## builds a surface's pipelines for a format only once a view has drawn with
## it. Kept to draw the land on; named `label`.
func look(label: String = "MapLandWarmView") -> void:
	view = MapScene.stage_view()
	view.name = label
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "Key"
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	var light: WorldEnvironment = WorldEnvironment.new()
	light.environment = Environment.new()
	MapScene._painted_light(key, light.environment)
	var kept: MapJourneyLandscape = MapScene._journey_kept if is_instance_valid(MapScene._journey_kept) else null
	var land_class: GDScript = kept.get_script() if kept != null else MapJourneyProfile.land_class(MapJourneyProfile.FIRST_ACT)
	land_class.light(key, light.environment)
	view.add_child(key)
	view.add_child(light)
	var eye: Camera3D = Camera3D.new()
	eye.name = "Eye"
	view.add_child(eye)
	add_child(view)


## The kept land lent to the view for a frame, seen by no camera, its shadow
## off, so nothing is drawn and no frame waits; null (and the view let go)
## when there is no land to lend.
func queue() -> MapJourneyLandscape:
	var land: MapJourneyLandscape = MapScene.lend_journey()
	if land == null:
		drop()
		return null
	(view.get_node("Key") as DirectionalLight3D).shadow_enabled = false
	(view.get_node("Eye") as Camera3D).cull_mask = 0
	view.add_child(land)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(MapScene.return_journey, CONNECT_ONE_SHOT)
	return land


## Whether the pipelines queued so far have compiled, without holding a frame:
## a task queued after them on each queue of the worker pool ends once they
## have all started, and `SETTLE` more lets the last ones end (as the floor
## bake waits, `floor_bake.gd`).
func compiled() -> bool:
	if _canaries.is_empty() and _settle_until == 0:
		for high: bool in [true, false]:
			_canaries.append(WorkerThreadPool.add_task(func() -> void: pass, high, "MapLandWarm: land pipelines started"))
	for task: int in _canaries:
		if not WorkerThreadPool.is_task_completed(task):
			return false
	for task: int in _canaries:
		WorkerThreadPool.wait_for_task_completion(task)
	_canaries.clear()
	if _settle_until == 0:
		_settle_until = Time.get_ticks_msec() + roundi(SETTLE * 1000.0)
	return Time.get_ticks_msec() >= _settle_until


## The land drawn once, whole, from above, lit and shadowed as the map lights
## it: each surface's specialised pipelines are built for the map's lights.
## Then the land is given back and the view let go. False when there was no
## land to draw.
func draw() -> bool:
	var land: MapJourneyLandscape = MapScene.lend_journey()
	if land == null:
		drop()
		return false
	var key: DirectionalLight3D = view.get_node("Key")
	key.shadow_enabled = true
	key.directional_shadow_max_distance = EYE_HEIGHT * 2.0
	var eye: Camera3D = view.get_node("Eye")
	eye.cull_mask = 0xFFFFF
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = EYE_SPAN
	eye.far = EYE_HEIGHT * 2.0
	eye.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	eye.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	view.add_child(land)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func() -> void:
		MapScene.return_journey()
		drop(), CONNECT_ONE_SHOT)
	return true


func drop() -> void:
	if view != null:
		view.queue_free()
		view = null


func _queue_step() -> void:
	if queue() == null:
		_steps.clear()


func _compiled_step() -> void:
	if not compiled():
		_steps.push_front(_compiled_step)


func _draw_step() -> void:
	if not draw():
		_steps.clear()
