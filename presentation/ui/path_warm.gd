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
##   EnemyView's stage draws them (its sky as light, a key and an omni light)
##   and the card's on the card's own prism, unlit, as CardView's stage draws
##   them. The foe stage's sky builds the sky's pipelines too.
## - While the title rests (this node, after RoomWarm), one step a frame: the
##   2D materials are made, then, SETTLE seconds later, each is drawn once,
##   near-invisibly under everything, as RoomWarm draws its pipeline samples.
##   A tap that leaves the title stops it where it stands; anything not yet
##   warm compiles where it always did.
## Every material made is HELD FOR THE PROCESS: the engine frees a shader, its
## compiled variants and every pipeline built for it with the last material
## wearing it (a BaseMaterial3D's generated shader, and a Shader built from a
## string). The fight builds fresh string shaders each time; a held twin keeps
## the Metal libraries those share by source. Kept for the process because
## fights recur and the cost is a few MiB of shader code, not textures.

## How long the title rests before the work starts, and before the draws.
const REST: float = 0.8
const SETTLE: float = 2.0

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
	var foe_behind: Array[Material] = []
	for code: String in [EnemyView.WARD_SHADER, EnemyView.with_tint(EnemyView.GLASS_SHADER),
			EnemyView.with_tint(EnemyView.with_erode(EnemyView.SHARD_SHADER)), EnemyView.FX_SHADER]:
		foe_behind.append(_keep(_string(code)))
	# The card's prism, surface by surface (CardView._build_stage): its side,
	# its face, its stone.
	var card: Array[Material] = [_keep(CardView.generated_materials()[0]),
		_keep(_file("res://presentation/combat/card_surface.gdshader")),
		_keep(_file("res://presentation/combat/card_gem.gdshader"))]
	_targets = [foe_drawn, foe_behind, card]
	host.add_child(_target_stages())


## The targets' stages, drawn in the next frame drawn, then freed. Drawn again
## by the title's warm (`_restand`): the floor bake's soft key switches free
## every scene pipeline built before them, and a pipeline built once rebuilds
## from the Metal cache in moments, so the fight finds them all.
static func _target_stages() -> Node:
	var holder: Node = Node.new()
	holder.name = "PathWarmTargets"
	var foe: SubViewport = _target_stage("PathWarmFoe")
	holder.add_child(foe)
	var light: WorldEnvironment = WorldEnvironment.new()
	light.environment = EnemyView.stage_environment()
	_held.append(light.environment.sky.sky_material)
	foe.add_child(light)
	foe.add_child(DirectionalLight3D.new())
	var omni: OmniLight3D = OmniLight3D.new()
	omni.position = Vector3(0.0, 0.0, -3.0)
	foe.add_child(omni)
	for i: int in range(2):
		var mats: Array[Material] = _targets[i]
		for mat: Material in mats:
			var plane: MeshInstance3D = MeshInstance3D.new()
			var mesh: PlaneMesh = PlaneMesh.new()
			mesh.orientation = PlaneMesh.FACE_Z
			plane.mesh = mesh
			plane.material_override = mat
			plane.position = Vector3(0.0, 0.0, -4.0 if i == 0 else 4.0)
			foe.add_child(plane)
	var card: SubViewport = _target_stage("PathWarmCard")
	holder.add_child(card)
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.mesh = CardView._prism_mesh(4.0, true)
	var prism: Array[Material] = _targets[2]
	for surface: int in range(3):
		slab.set_surface_override_material(surface, prism[surface])
	slab.position = Vector3(0.0, 0.0, -400.0)
	card.add_child(slab)
	RenderingServer.frame_post_draw.connect(holder.queue_free, CONNECT_ONE_SHOT)
	return holder


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
	if not _targets.is_empty():
		_steps.append(_restand)
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


static func _string(code: String) -> Material:
	var sh: Shader = Shader.new()
	sh.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
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


## Frame 0's targets drawn again, after the floor bake's switches.
func _restand() -> void:
	add_child(_target_stages())


## Made and held.
func _hold(source: Callable) -> void:
	var mat: Material = source.call()
	_canvas.append(_keep(mat))


## Once everything is made, a pause for the compiles, then the draws.
func _settle() -> void:
	_settled = 0.0
	for mat: Material in _canvas:
		_steps.append(_draw_once.bind(mat))


## Drawn once under everything, at the least alpha Godot still draws
## (RoomWarm.SAMPLE_ALPHA).
func _draw_once(mat: Material) -> void:
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(8.0, 8.0)
	rect.material = mat
	rect.modulate.a = RoomWarm.SAMPLE_ALPHA
	add_child(rect)
	_sample = rect
