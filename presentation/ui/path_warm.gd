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
##   fight's load frame and its first card play draw is drawn here (the foe's
##   body, shadow and ward, the card's side, face and stone), since each costs
##   frame 0 its compile; the foe's other materials stand behind the camera,
##   which builds their libraries and their pipelines for the project's MSAA
##   in the background, and their own draw still waits at its first use in a
##   fight. A pipeline's
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
##   frame 0's targets again; and Act I's kept land lent to that view, a frame unseen (its
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
## A road for the waylight tracer's stand-in: any two points will do.
const WAYLIGHT_ROAD: Dictionary = {"centerline": [[0.0, 0.0, 0.0], [4.0, 0.0, 0.0]], "corridor_width": 1.0}

## Every material made, for the process (see above).
static var _held: Array[Material] = []
static var _started: bool = false
static var _primed: bool = false
## Frame 0's targets as [foe drawn, foe behind the camera, the card's prism].
static var _targets: Array = []

var rests: Callable = Callable()
var _steps: Array[Callable] = []
var _rested: float = 0.0
var _settled: float = -1.0
var _sample: Node = null
var _canvas: Array[Material] = []
## The land's warm (`MapLandWarm`): its view of the map's stage, after the
## bake.
var _land: MapLandWarm = null


static func started() -> bool:
	return _started


## Frame 0's part, once a process: the stages join `host` and draw in the
## next frame drawn (behind the launch screen), then free themselves.
static func prime_targets(host: Node) -> void:
	if _primed:
		return
	_primed = true
	var foe_drawn: Array[Material] = []
	for code: String in [EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER)), EnemyView.SHADOW_SHADER,
			EnemyView.WARD_SHADER]:
		foe_drawn.append(_keep(_string(code)))
	var foe_behind: Array[Material] = []
	for code: String in [EnemyView.with_tint(EnemyView.GLASS_SHADER),
			EnemyView.with_tint(EnemyView.with_erode(EnemyView.SHARD_SHADER)), EnemyView.FX_SHADER]:
		foe_behind.append(_keep(_string(code)))
	# The card's prism, surface by surface (CardView._build_stage): its side,
	# its face, its stone.
	var card: Array[Material] = [_keep(CardView.generated_materials()[0]),
		_keep(_file("res://presentation/combat/card_surface.gdshader")),
		_keep(_file("res://presentation/combat/card_gem.gdshader"))]
	_targets = [foe_drawn, foe_behind, card]
	var holder: Node = _holder()
	holder.add_child(_foe_stage())
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


## The foe's stage: what the load frame draws (the body and the shadow) and
## the ward, which the first card play draws (#709), in front of the camera;
## the rest behind it. The ward is drawn here at frame 0 too: its first 4x
## MSAA pipeline, built cold in a title frame, held that frame 250-264 ms on
## the iPad 8 (#682 Part 2's read); built once, the redraw finds it in the
## Metal cache.
static func _foe_stage() -> SubViewport:
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
	for i: int in range(2):
		var mats: Array[Material] = _targets[i]
		var front: bool = i == 0
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
	var prism: Array[Material] = _targets[2]
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


## A view of the map's stage, lit as the kept land's act lights it (Act I's
## journey land under a first title), drawn empty (`MapLandWarm.look`). Drawn
## a frame before the fight's targets stand again, so theirs include its glow's
## target format; kept to draw the land on.
func _map_look() -> void:
	_land = MapLandWarm.new()
	_land.name = "PathWarmLand"
	add_child(_land)
	_land.look("PathWarmMap")


## Frame 0's targets drawn again, after the floor bake's switches: the foe's
## stage in one frame, the card's in the next.
func _restand_foe() -> void:
	var holder: Node = _holder()
	holder.add_child(_foe_stage())
	add_child(holder)


func _restand_card() -> void:
	var holder: Node = _holder()
	holder.add_child(_card_stage())
	add_child(holder)


## The kept land on the map's view for a frame, seen by no camera
## (`MapLandWarm.queue`).
func _land_queue() -> void:
	if _land.queue() == null:
		_steps.clear()
		return
	# A waylight tracer, as the map binds one per road at its open (hidden on
	# the journey land, its surfaces' pipelines built all the same); its
	# material held, so the shader the engine generates for it outlives the
	# stand-in.
	var tracer: MapWaylightTracer = MapWaylightTracer.new()
	if tracer.configure_route(WAYLIGHT_ROAD, MapWaylightTracer.STATE_COLD):
		_keep(tracer.material_override)
		tracer.visible = false
		_land.view.add_child(tracer)
		RenderingServer.frame_post_draw.connect(tracer.queue_free, CONNECT_ONE_SHOT)
	else:
		tracer.free()


## Waits, without holding a frame, until the pipelines queued so far have
## compiled (`MapLandWarm.compiled`). Once after the land is queued (its draw
## then finds them built), and once after it is drawn: the warm is done only
## when its specialised pipelines are, since on the iPad 8 their compiles,
## still running when the title's first room opened, slowed that opening by
## 10-15 ms (#682 Part 2's read).
func _await_compiles() -> void:
	if not _land.compiled():
		_steps.push_front(_await_compiles)


## The land drawn once, whole, from above, lit and shadowed as the map lights
## it (`MapLandWarm.draw`); then given back and the view let go.
func _land_draw() -> void:
	_land.draw()


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
	_steps.append(_await_compiles)
	_steps.append(_land_draw)
	_steps.append(_await_compiles)


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
