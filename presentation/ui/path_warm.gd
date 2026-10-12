class_name PathWarm
extends Control
## The first map open's and the first fight's shaders, paid for ahead (#682).
## On the iPad 8 a cold install held the first fight's load frame for about
## 12.6 s, compiling.
##
## Two parts:
## - Behind the launch screen (`prime_targets`, frame 0): the fight's 3D
##   materials, drawn once on stages of the targets the fight draws them on
##   (4x MSAA, transparent). This engine builds a pipeline for a viewport's
##   own MSAA only at a draw, on the frame that draws, which waits for it: the
##   pipelines it builds ahead in the background are for the project's MSAA
##   (RenderForwardMobile::_update_global_pipeline_data_requirements_from_project).
##   So no frame after frame 0 can build them without waiting. Only what the
##   fight's load frame draws is drawn here (the foe's body and shadow, the
##   card's side, face and stone), since each costs frame 0 its compile; the
##   foe's other materials stand behind the camera, which builds their
##   libraries and their pipelines for the project's MSAA in the background,
##   and their own draw still waits at its first use in a fight. A pipeline's
##   key also holds the stage's light, so the foe's materials stand as
##   EnemyView's stage draws them (its sky as light, a key and two omni
##   lights) and the card's on the card's own prism, unlit, as CardView's
##   stage draws them. The foe stage's sky builds the sky's pipelines too.
## - While the title rests (this node, after RoomWarm), one step a frame: the
##   2D materials are made, then, SETTLE seconds later, each is drawn once,
##   near-invisibly under everything, as RoomWarm draws its pipeline samples,
##   and so are the kinds of draw the engine's own canvas material keys
##   apart (a nine-patch, a Polygon2D, the back card's face). Then, once the
##   title's floor bake has ended (its soft key switches free every scene
##   pipeline built before them): an empty view of the map's stage, lit as
##   Act I's journey land, whose glow pass is a target format of its own;
##   frame 0's targets again, the ward in front too (the first card play
##   draws it); and Act I's kept land lent to that view, a frame unseen (its
##   surfaces' pipelines queued in the background), then, once those have
##   compiled, a frame drawn whole from above (their specialised pipelines),
##   so the map's first open builds none (#682 Part 2).
##   A tap that leaves the title stops it where it stands; anything not yet
##   warm compiles where it always did.
## Every material made is HELD FOR THE PROCESS: the engine frees a shader, its
## compiled variants and every pipeline built for it with the last material
## wearing it (a BaseMaterial3D's generated shader). A shader built from a
## string is the process's one Shader for that code (`SharedShaders`), the one
## the fight and the transitions wear too, so the pipelines drawn here are the
## ones the use finds. Kept for the process because fights recur and the cost
## is a few MiB of shader code, not textures.

## How long the title rests before the work starts, and before the draws.
const REST: float = 0.8
const SETTLE: float = 2.0
## The eye the land is drawn from, after the bake: straight down from this
## height (metres), seeing a square this wide, more than the land's bounds
## (`MapJourneyLandscape.MAP_BOUNDS`).
const LAND_EYE_HEIGHT: float = 60.0
const LAND_EYE_SPAN: float = 140.0
## A road for the waylight tracer's stand-in: any two points will do.
const WAYLIGHT_ROAD: Dictionary = {"centerline": [[0.0, 0.0, 0.0], [4.0, 0.0, 0.0]], "corridor_width": 1.0}

## Every material made, for the process (see above).
static var _held: Array[Material] = []
static var _started: bool = false
static var _primed: bool = false
## Frame 0's targets as [foe drawn, foe drawn again after the bake (first
## drawn by the first card play), foe behind the camera, the card's prism].
static var _targets: Array = []

var rests: Callable = Callable()
var _steps: Array[Callable] = []
var _rested: float = 0.0
var _settled: float = -1.0
var _sample: Node = null
var _canvas: Array[Material] = []
## The view of the map's stage the land is drawn on, after the bake.
var _map_view: SubViewport = null
var _canaries: Array[int] = []
var _settle_until: int = 0


static func started() -> bool:
	return _started


## Frame 0's part, once a process: the stages join `host` and draw in the
## next frame drawn (behind the launch screen), then free themselves.
static func prime_targets(host: Node) -> void:
	if _primed:
		return
	_primed = true
	var foe_drawn: Array[Material] = []
	for code: String in [EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER)), EnemyView.SHADOW_SHADER]:
		foe_drawn.append(_keep(_string(code)))
	var foe_later: Array[Material] = [_keep(_string(EnemyView.WARD_SHADER))]
	var foe_behind: Array[Material] = []
	for code: String in [EnemyView.with_tint(EnemyView.GLASS_SHADER),
			EnemyView.with_tint(EnemyView.with_erode(EnemyView.SHARD_SHADER)), EnemyView.FX_SHADER]:
		foe_behind.append(_keep(_string(code)))
	# The card's prism, surface by surface (CardView._build_stage): its side,
	# its face, its stone.
	var card: Array[Material] = [_keep(CardView.generated_materials()[0]),
		_keep(_file("res://presentation/combat/card_surface.gdshader")),
		_keep(_file("res://presentation/combat/card_gem.gdshader"))]
	_targets = [foe_drawn, foe_later, foe_behind, card]
	var holder: Node = _holder()
	holder.add_child(_foe_stage(false))
	holder.add_child(_card_stage())
	host.add_child(holder)


## A holder of target stages, drawn in the next frame drawn, then freed. They
## are drawn again by the title's warm (`_restand_foe`, `_restand_card`), a
## frame each: the floor bake's soft key switches free every scene pipeline
## built before them, and a pipeline built once rebuilds from the Metal cache
## in moments, so the fight finds them all.
static func _holder() -> Node:
	var holder: Node = Node.new()
	holder.name = "PathWarmTargets"
	RenderingServer.frame_post_draw.connect(holder.queue_free, CONNECT_ONE_SHOT)
	return holder


## The foe's stage: what the load frame draws in front of the camera, and,
## when `again` (the redraw after the bake), the ward too, which the first
## card play draws (#709); the rest behind the camera.
static func _foe_stage(again: bool) -> SubViewport:
	var foe: SubViewport = _target_stage("PathWarmFoe")
	var light: WorldEnvironment = WorldEnvironment.new()
	light.environment = EnemyView.stage_environment()
	_held.append(light.environment.sky.sky_material)
	foe.add_child(light)
	foe.add_child(DirectionalLight3D.new())
	# Two omni lights, as EnemyView's rim and fire: a specialised pipeline's key
	# counts the omni lights reaching the surface.
	for _i: int in range(2):
		var omni: OmniLight3D = OmniLight3D.new()
		omni.position = Vector3(0.0, 0.0, -3.0)
		foe.add_child(omni)
	for i: int in range(3):
		var mats: Array[Material] = _targets[i]
		var front: bool = i == 0 or (i == 1 and again)
		for mat: Material in mats:
			var plane: MeshInstance3D = MeshInstance3D.new()
			var mesh: PlaneMesh = PlaneMesh.new()
			mesh.orientation = PlaneMesh.FACE_Z
			plane.mesh = mesh
			plane.material_override = mat
			plane.position = Vector3(0.0, 0.0, -4.0 if front else 4.0)
			foe.add_child(plane)
	return foe


## The card's stage: its prism, surface by surface.
static func _card_stage() -> SubViewport:
	var card: SubViewport = _target_stage("PathWarmCard")
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.mesh = CardView._prism_mesh(4.0, true)
	var prism: Array[Material] = _targets[3]
	for surface: int in range(3):
		slab.set_surface_override_material(surface, prism[surface])
	slab.position = Vector3(0.0, 0.0, -400.0)
	card.add_child(slab)
	return card


## A stage of the fight's target (EnemyView, CardView): 4x MSAA, transparent,
## its own world, 8 px, drawn once, with a camera looking down -Z.
static func _target_stage(label: String) -> SubViewport:
	var stage: SubViewport = SubViewport.new()
	stage.name = label
	stage.size = Vector2i(8, 8)
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.msaa_3d = EnemyView.msaa
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	stage.add_child(Camera3D.new())
	return stage


func _init(title_rests: Callable) -> void:
	_started = true
	name = "PathWarm"
	rests = title_rests
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -100
	for source: Callable in _sources():
		_steps.append(_hold.bind(source))
	_steps.append(_settle)


## The census's 2D targets (lane #682, Phase A2), each made when its step
## comes: the first fight's and the first map open's.
static func _sources() -> Array[Callable]:
	var out: Array[Callable] = []
	for code: String in [EnemyView.RESEAM_SHADER, CombatScreen.VIGNETTE_SHADER,
			CombatScreen.STAGE_DIM_SHADER, CombatScreen.GRAIN_SHADER, TransitionLayer.IRIS_SHADER]:
		out.append(_string.bind(code))
	for path: String in ["res://presentation/combat/lantern_flame.gdshader",
			"res://presentation/combat/card_edge.gdshader", "res://presentation/cards/card_turn.gdshader",
			"res://presentation/combat/card_shine.gdshader", "res://presentation/map/map_display.gdshader",
			"res://presentation/map/map_display_fade.gdshader", "res://presentation/map/map_tilt_shift.gdshader"]:
		out.append(_file.bind(path))
	out.append(func() -> Material:
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return add)
	return out


## A material wearing the process's Shader for `code`, the one every use wears
## (`SharedShaders`), so the pipelines drawn here serve the use.
static func _string(code: String) -> Material:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SharedShaders.of(code)
	return mat


static func _file(path: String) -> Material:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(path) as Shader
	return mat


## Held for the process; a BaseMaterial3D makes its shader at its first use.
static func _keep(mat: Material) -> Material:
	var _rid: RID = mat.get_rid()
	_held.append(mat)
	return mat


func done() -> bool:
	return _steps.is_empty() and _sample == null


func _process(delta: float) -> void:
	if _sample != null:
		_sample.queue_free()
		_sample = null
	var resting: bool = rests.call() if rests.is_valid() else true
	if not resting:
		_rested = 0.0
		return
	_rested += delta
	if _rested < REST:
		return
	if _settled >= 0.0 and _settled < SETTLE:
		_settled += delta
		return
	if _steps.is_empty():
		queue_free()
		return
	var step: Callable = _steps.pop_front()
	step.call()


## Waits, a frame at a time, until the title's floor bake has ended: each of
## its soft key switches frees every scene pipeline built before it, so what
## follows is drawn only once both have run (#682).
func _await_bake() -> void:
	if MapJourneyPrefetch.busy():
		_steps.push_front(_await_bake)


## A view of the map's stage (`MapScene.stage_view`), lit as Act I's journey
## land, drawn empty: its glow's post pass is a target format of its own, and
## the engine builds a surface's pipelines for a format only once a view has
## drawn with it. Drawn a frame before the fight's targets stand again, so
## theirs include it; kept to draw the land on.
func _map_look() -> void:
	_map_view = MapScene.stage_view()
	_map_view.name = "PathWarmMap"
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "Key"
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	var light: WorldEnvironment = WorldEnvironment.new()
	light.environment = Environment.new()
	MapScene._painted_light(key, light.environment)
	MapJourneyLandscape.light(key, light.environment)
	_map_view.add_child(key)
	_map_view.add_child(light)
	var eye: Camera3D = Camera3D.new()
	eye.name = "Eye"
	_map_view.add_child(eye)
	add_child(_map_view)


## Frame 0's targets drawn again, after the floor bake's switches: the foe's
## stage in one frame, the card's in the next.
func _restand_foe() -> void:
	var holder: Node = _holder()
	holder.add_child(_foe_stage(true))
	add_child(holder)


func _restand_card() -> void:
	var holder: Node = _holder()
	holder.add_child(_card_stage())
	add_child(holder)


## Act I's kept land (`MapScene.lend_journey`) on the map's view for a frame,
## seen by no camera: the engine queues its surfaces' pipelines, in the
## background, for every target format the map draws with. Its shadow is off
## for the frame, so nothing is drawn and no frame waits.
func _land_queue() -> void:
	var land: MapJourneyLandscape = MapScene.lend_journey()
	if land == null:
		_steps.clear()
		_drop_map_view()
		return
	(_map_view.get_node("Key") as DirectionalLight3D).shadow_enabled = false
	(_map_view.get_node("Eye") as Camera3D).cull_mask = 0
	_map_view.add_child(land)
	# A waylight tracer, as the map binds one per road at its open (hidden on
	# Act I's land, its surfaces' pipelines built all the same); its material
	# held, so the shader the engine generates for it outlives the stand-in.
	var tracer: MapWaylightTracer = MapWaylightTracer.new()
	if tracer.configure_route(WAYLIGHT_ROAD, MapWaylightTracer.STATE_COLD):
		_keep(tracer.material_override)
		tracer.visible = false
		_map_view.add_child(tracer)
	else:
		tracer.free()
		tracer = null
	_map_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func() -> void:
		MapScene.return_journey()
		if tracer != null:
			tracer.queue_free(), CONNECT_ONE_SHOT)


## Waits, without holding a frame, until the pipelines the land queued have
## compiled: a task queued after them on each queue of the worker pool ends
## once they have all started, and SETTLE more lets the last ones end (as the
## floor bake waits, `floor_bake.gd`).
func _land_wait() -> void:
	if _canaries.is_empty() and _settle_until == 0:
		for high: bool in [true, false]:
			_canaries.append(WorkerThreadPool.add_task(func() -> void: pass, high, "PathWarm: land pipelines started"))
	for task: int in _canaries:
		if not WorkerThreadPool.is_task_completed(task):
			_steps.push_front(_land_wait)
			return
	for task: int in _canaries:
		WorkerThreadPool.wait_for_task_completion(task)
	_canaries.clear()
	if _settle_until == 0:
		_settle_until = Time.get_ticks_msec() + roundi(SETTLE * 1000.0)
	if Time.get_ticks_msec() < _settle_until:
		_steps.push_front(_land_wait)


## The land drawn once, whole, from above, lit and shadowed as the map lights
## it: each surface's specialised pipelines are built for the map's lights
## (in the background, its ubershader drawing meanwhile, already built). Then
## the land is given back and the view let go.
func _land_draw() -> void:
	var land: MapJourneyLandscape = MapScene.lend_journey()
	if land == null:
		_drop_map_view()
		return
	var key: DirectionalLight3D = _map_view.get_node("Key")
	key.shadow_enabled = true
	key.directional_shadow_max_distance = LAND_EYE_HEIGHT * 2.0
	var eye: Camera3D = _map_view.get_node("Eye")
	eye.cull_mask = 0xFFFFF
	eye.projection = Camera3D.PROJECTION_ORTHOGONAL
	eye.size = LAND_EYE_SPAN
	eye.far = LAND_EYE_HEIGHT * 2.0
	eye.position = Vector3(0.0, LAND_EYE_HEIGHT, 0.0)
	eye.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_map_view.add_child(land)
	_map_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func() -> void:
		MapScene.return_journey()
		_drop_map_view(), CONNECT_ONE_SHOT)


func _drop_map_view() -> void:
	if _map_view != null:
		_map_view.queue_free()
		_map_view = null


## Made and held.
func _hold(source: Callable) -> void:
	var mat: Material = source.call()
	_canvas.append(_keep(mat))


## Once everything is made, a pause for the compiles, then the draws; then,
## once the floor bake has ended, the map's look and frame 0's targets again.
func _settle() -> void:
	_settled = 0.0
	for mat: Material in _canvas:
		_steps.append(_draw_once.bind(mat))
	for sample: Callable in [_nine_patch, _polygon, _back_card]:
		_steps.append(_draw_sample.bind(sample))
	_steps.append(_await_bake)
	_steps.append(_map_look)
	if not _targets.is_empty():
		_steps.append(_restand_foe)
		_steps.append(_restand_card)
	_steps.append(_land_queue)
	_steps.append(_land_wait)
	_steps.append(_land_draw)


## Drawn once under everything, at the least alpha Godot still draws
## (RoomWarm.SAMPLE_ALPHA).
func _draw_once(mat: Material) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(8.0, 8.0)
	rect.material = mat
	_show(rect)


## A sample of a draw the engine's own canvas material keys by its kind, made
## by `make`, drawn once as `_draw_once` draws.
func _draw_sample(make: Callable) -> void:
	var sample: CanvasItem = make.call()
	_show(sample)


func _show(sample: CanvasItem) -> void:
	if sample.visible:
		sample.modulate.a = RoomWarm.SAMPLE_ALPHA
	add_child(sample)
	_sample = sample


## A nine-patch, as a fight's foe rails draw their fill (`StyleBoxTexture`).
static func _nine_patch() -> CanvasItem:
	var patch: NinePatchRect = NinePatchRect.new()
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture = EnemyView._rail_fill()
	patch.size = Vector2(8.0, 8.0)
	return patch


## A Polygon2D, as a card's cost stone stands on one: the engine draws it as a
## mesh of its own vertex format.
static func _polygon() -> CanvasItem:
	var shape: Polygon2D = Polygon2D.new()
	shape.polygon = PackedVector2Array([Vector2.ZERO, Vector2(8.0, 0.0), Vector2(0.0, 8.0)])
	return shape


## The card the table's back is baked from (`CardBacks.build`, as
## `CardBacks.bake` builds it at the map's first open), hidden: its own views
## draw a frame regardless, the face's 2D target among them.
static func _back_card() -> CanvasItem:
	var card: CardView = CardBacks.build(CardBacks.catalogue().default_id)
	card.visible = false
	return card
