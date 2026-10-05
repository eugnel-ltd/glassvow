extends Node
## The floor's pipelines, built behind the launch screen (R3.2, issue #660), so
## that no frame the player sees waits on them.
##
## On the iPad 8 this engine builds a pipeline only as a draw needs it, on the
## frame that draws. Neither of the cheaper routes builds the ones the bake
## draws with (R3.2 round 3, batches G and I, after an update):
## - a material made ahead built nothing ahead. The bake's first draw under the
##   title then held a frame 2.7 s, a later one 1.9 s, and the first open
##   0.67 s;
## - surfaces standing in a world no view draws cost the first frame 1.4 s.
##   The bake still held two frames, of 2.2 and 1.7 s.
## So the warm-up draws a sample of every one, twice (the key casts nothing in
## its first frame), with `RenderingServer.force_draw` and nothing presented.
## That happens inside `MapJourneyPrefetch.prime`, before the title's first
## frame, while the launch screen still shows. The samples stand on meshes of
## the bake's own kinds: the ground's (vertex, normal and colour) and the
## woodland's shadow cards (a MultiMesh with colour and custom data). After an
## update this lengthens the launch, once; afterwards it costs a few
## milliseconds.

const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
const Stage = preload("res://presentation/map/landscape/floor_stage.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const CASTER: Shader = preload("res://presentation/map/landscape/floor_caster.gdshader")
const FLOOR: Shader = preload("res://presentation/map/landscape/floor.gdshader")
## A sample's side in pixels: the least the renderer draws.
const SIDE: int = 8

static var _done: bool = false
var _views: Array[SubViewport] = []
var _lit: SubViewport = null


## Draws the samples once a process, before the next frame shows. `prime`
## runs inside the title's build, so the sample joins the scene being built.
static func warm() -> void:
	if _done or not Bake.supported():
		return
	_done = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var sample: Node = (load("res://presentation/map/landscape/floor_warm.gd") as GDScript).new()
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(sample)
	sample.call("draw_now")


func _ready() -> void:
	name = "Floor pipelines"
	var world: World3D = World3D.new()
	var stage: Stage = Stage.new()
	stage.light_up()
	_lit = _view(world)
	_lit.add_child(stage)
	var ground: MeshInstance3D = _sample(_ground_mesh(), Bake.PAINT, Stage.LIT_LAYER)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stage.add_child(ground)
	stage.add_child(_cards())
	stage.add_child(_sample(_ground_mesh(), Bake.MASK, Stage.MASK_LAYER))
	_camera(_lit, stage.environment, Stage.LIT_LAYER | Stage.CASTER_LAYER)
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
	live.add_child(_sample(_ground_mesh(), FLOOR, 1))
	_camera(live, journey, 1)
	_canvas()


## Draws every view twice and lets go: the first draw builds every pipeline
## but the shadows' (the key casts nothing in its first frame), the second
## those. The bake's soft key is on for both, as the bake draws with it.
func draw_now() -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(Bake.SOFT)
	for view: SubViewport in _views:
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false)
	_lit.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw(false)
	var quality: int = int(str(ProjectSettings.get_setting_with_override(Bake.SOFT_SETTING)))
	RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)
	queue_free()


## The 2D passes: an additive stamp, a mip level.
func _canvas() -> void:
	var flat: SubViewport = SubViewport.new()
	flat.size = Vector2i(SIDE, SIDE)
	flat.disable_3d = true
	flat.transparent_bg = true
	flat.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(flat)
	_views.append(flat)
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


## The woodland's shadow cards as the bake casts them: one card in a MultiMesh
## with colour and custom data, shadows only.
func _cards() -> GeometryInstance3D:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CASTER
	if Atlas.material != null:
		material.set_shader_parameter("atlas_albedo", Atlas.material.get_shader_parameter("atlas_albedo"))
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = Atlas.card if Atlas.card != null else QuadMesh.new()
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D(Basis(), Vector3(0.0, 0.5, 0.0)))
	multi.set_instance_color(0, Color.WHITE)
	multi.set_instance_custom_data(0, Color(0.0, 0.0, 1.0, 1.0))
	var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
	draw.multimesh = multi
	draw.material_override = material
	draw.layers = Stage.CASTER_LAYER
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return draw


## A patch of ground in the ground chunks' own vertex format (position, normal
## and colour, indexed).
static func _ground_mesh() -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		surface.set_color(Color("302b30"))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(corner.x, 0.0, corner.y))
	for index: int in [0, 3, 1, 0, 2, 3]:
		surface.add_index(index)
	return surface.commit()


static func _sample(mesh: Mesh, shader: Shader, layer: int) -> MeshInstance3D:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = mesh
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	item.material_override = material
	item.layers = layer
	return item


func _view(world: World3D) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(SIDE, SIDE)
	view.world_3d = world
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 0
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	_views.append(view)
	return view


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
