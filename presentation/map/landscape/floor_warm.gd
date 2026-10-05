extends Node
## The floor's pipelines, built ahead (R3.2, issue #660): one frame of small
## views drawing every material the floor's bake and the floor itself use, in
## the bake's own set-up (its soft key shadows, a caster cut out of the
## woodland's atlas, the mask, the 2D pass's additive stamps, the mip chain's
## shader, and the floor's own shader under the journey's light), so neither
## the first bake nor the first floor compiles a pipeline on the frame that
## needs it. `MapJourneyPrefetch.prime` starts it before the title's first
## frame; it frees itself once drawn, and gives the key's shadow filter back.

const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
const Stage = preload("res://presentation/map/landscape/floor_stage.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const CASTER: Shader = preload("res://presentation/map/landscape/floor_caster.gdshader")
const FLOOR: Shader = preload("res://presentation/map/landscape/floor.gdshader")
## A sample's side in pixels: the least the renderer draws.
const SIDE: int = 8

static var _done: bool = false
var _frames: int = 0


## Draws the samples once a process, under the scene tree's root.
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
	RenderingServer.directional_soft_shadow_filter_set_quality(Bake.SOFT)
	var world: World3D = World3D.new()
	var stage: Stage = Stage.new()
	stage.light_up()
	var lit: SubViewport = _view(world)
	lit.add_child(stage)
	var ground: MeshInstance3D = _quad(Bake.PAINT, Stage.LIT_LAYER)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stage.add_child(ground)
	var caster: MeshInstance3D = _quad(CASTER, Stage.CASTER_LAYER)
	caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	caster.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	caster.position = Vector3(0.0, 0.5, 0.0)
	if Atlas.material != null:
		(caster.material_override as ShaderMaterial).set_shader_parameter("atlas_albedo",
			Atlas.material.get_shader_parameter("atlas_albedo"))
	stage.add_child(caster)
	stage.add_child(_quad(Bake.MASK, Stage.MASK_LAYER))
	_camera(lit, stage.environment, Stage.LIT_LAYER | Stage.CASTER_LAYER)
	var plain: Environment = Environment.new()
	plain.background_mode = Environment.BG_COLOR
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera(_view(world), plain, Stage.MASK_LAYER)
	# The floor itself, under the journey's own light and grade. Its glow is a
	# pass after the floor's own, and an 8 px view has too few mip levels for
	# it: the glow's chain failed its framebuffers there.
	var live: SubViewport = _view(World3D.new())
	var key: DirectionalLight3D = DirectionalLight3D.new()
	var journey: Environment = Environment.new()
	MapJourneyLandscape.light(key, journey)
	journey.glow_enabled = false
	live.add_child(key)
	live.add_child(_quad(FLOOR, 1))
	_camera(live, journey, 1)
	# The 2D passes: an additive stamp, a mip level.
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


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= 2:
		var quality: int = int(str(ProjectSettings.get_setting_with_override(Bake.SOFT_SETTING)))
		RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)
		queue_free()


func _view(world: World3D) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(SIDE, SIDE)
	view.world_3d = world
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 0
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(view)
	return view


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


static func _camera(view: SubViewport, environment: Environment, mask: int) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 2.0, 0.0)
	camera.cull_mask = mask
	camera.environment = environment
	camera.current = true
	view.add_child(camera)
