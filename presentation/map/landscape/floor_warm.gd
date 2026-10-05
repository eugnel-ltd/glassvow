extends Node
## The floor's pipelines, built ahead (R3.2, issue #660), so neither the first
## bake nor the first floor compiles one on a frame the player sees.
##
## The 3D ones are never drawn here. The bake's and the floor's materials stand
## on quads in a world no view draws (the bake's set-up: the lit ground, its
## shadow casters and a caster cut out of the woodland's atlas, the mask, and
## the floor's own shader). The renderer compiles a new surface's pipelines on
## its worker threads as the surface enters the world, and nothing waits on
## them. Drawn on the title's first frame instead, they cost the iPad 8 3.1 s
## on that frame and 1.37 s on the next after an update (batch T, R3.2 review).
##
## The 2D ones (the bake's additive stamp and its mip shader) are drawn once,
## in an 8 px view on the first frame, behind the launch screen: a canvas
## builds its pipelines only as it draws.
##
## `MapJourneyPrefetch.prime` starts it before the title's first frame. It
## frees itself once the worker threads have had `HOLD_S` to finish, well
## before a land's bake can begin.

const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
const Stage = preload("res://presentation/map/landscape/floor_stage.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const CASTER: Shader = preload("res://presentation/map/landscape/floor_caster.gdshader")
const FLOOR: Shader = preload("res://presentation/map/landscape/floor.gdshader")
## A 2D sample's side in pixels: the least the renderer draws.
const SIDE: int = 8
## How long the 3D surfaces stand for their pipelines (seconds).
const HOLD_S: float = 6.0

static var _done: bool = false
var _held: float = 0.0


## Starts the warm-up once a process, under the scene tree's root.
static func warm() -> void:
	if _done or not Bake.supported():
		return
	_done = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sample: Node = (load("res://presentation/map/landscape/floor_warm.gd") as GDScript).new()
	tree.root.add_child.call_deferred(sample)


func _ready() -> void:
	name = "Floor pipelines"
	_surfaces()
	_canvas()


## The 3D materials in a world that no view draws: their pipelines compile on
## the worker threads as the surfaces enter it.
func _surfaces() -> void:
	var unseen: SubViewport = SubViewport.new()
	unseen.size = Vector2i(SIDE, SIDE)
	unseen.world_3d = World3D.new()
	unseen.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(unseen)
	var ground: MeshInstance3D = _quad(Bake.PAINT, Stage.LIT_LAYER)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	unseen.add_child(ground)
	var caster: MeshInstance3D = _quad(CASTER, Stage.CASTER_LAYER)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if Atlas.material != null:
		(caster.material_override as ShaderMaterial).set_shader_parameter("atlas_albedo",
			Atlas.material.get_shader_parameter("atlas_albedo"))
	unseen.add_child(caster)
	unseen.add_child(_quad(Bake.MASK, Stage.MASK_LAYER))
	unseen.add_child(_quad(FLOOR, 1))


## The 2D samples, drawn once in an 8 px view.
func _canvas() -> void:
	var flat: SubViewport = SubViewport.new()
	flat.size = Vector2i(SIDE, SIDE)
	flat.disable_3d = true
	flat.transparent_bg = true
	flat.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(flat)
	var stamp: Sprite2D = Sprite2D.new()
	stamp.texture = Bake.radial()
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stamp.material = add
	flat.add_child(stamp)
	var level: ColorRect = ColorRect.new()
	level.size = Vector2(SIDE, SIDE)
	var mip: ShaderMaterial = ShaderMaterial.new()
	mip.shader = Bake.MIP
	mip.set_shader_parameter("source", stamp.texture)
	level.material = mip
	flat.add_child(level)


func _process(delta: float) -> void:
	_held += delta
	if _held >= HOLD_S:
		queue_free()


static func _quad(shader: Shader, layer: int) -> MeshInstance3D:
	var quad: MeshInstance3D = MeshInstance3D.new()
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2.ONE
	quad.mesh = mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	quad.material_override = material
	quad.layers = layer
	return quad
