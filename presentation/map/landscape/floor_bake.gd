extends RefCounted
## Act I's floor, baked once per land behind the veil (R3.2, issue #660): the
## lit forest floor as a picture of the land taken from straight above, in
## world space, so it serves every view and every pan (`floor.gdshader`).
##
## A step a frame on the main thread (`advance`), so no frame waits on the rest:
## 1. the plants' reach, summed in a small 2D pass (`FloorPlan.stamps`);
## 2. the lit floor at `LIT_TEXELS_PER_M` in tiles, `TILES_A_FRAME` a frame,
##    each with the key's shadow map fitted to it (`floor_stage.gd`'s world,
##    `floor_paint.gdshader`), and the mask at `MASK_TEXELS_PER_M` in one
##    (`floor_mask.gdshader`);
## 3. the lit picture's mip chain, every level in one frame through nested 2D
##    views (`floor_mip.gdshader`).
## Behind the veil it draws in the frame that sets it up: every frame it saves
## is a frame of the cold open (R3.2 round 3: about 20 ms on the iPad 8, its
## frames 50-67 ms at most). Paced (the journey prefetch's bake, under a lit
## title), it sets up a frame before its first draw and draws one tile a
## frame, so no frame of the title carries more than a tile.
## Each view's picture is copied on the GPU into the floor's own textures
## (`RenderingDevice.texture_copy`), so nothing is read back and no frame waits
## for the GPU. The views and the world are freed as the bake ends; the two
## textures pass to the land's floor (`land_floor.gd`), which frees them.
## A renderer without a RenderingDevice (the headless suite, the web's
## Compatibility renderer) cannot bake: the land keeps its painted ground.

const Stage = preload("res://presentation/map/landscape/floor_stage.gd")
const Plan = preload("res://presentation/map/landscape/floor_plan.gd")
const PAINT: Shader = preload("res://presentation/map/landscape/floor_paint.gdshader")
const MASK: Shader = preload("res://presentation/map/landscape/floor_mask.gdshader")
const MIP: Shader = preload("res://presentation/map/landscape/floor_mip.gdshader")
## The ground covers and the scatter the lit pass paints with (lane picks,
## `assets/art/map-journey/floor/`).
const COVERS: Dictionary = {
	"moss": "res://assets/art/map-journey/floor/floor-moss.png",
	"litter": "res://assets/art/map-journey/floor/floor-litter.png",
	"soil": "res://assets/art/map-journey/floor/floor-soil.png",
	"road": "res://assets/art/map-journey/floor/floor-road.png",
	"splats": "res://assets/art/map-journey/floor/floor-splats.png",
}
## The picture's and the mask's texels a metre. The plan's 20 and 10 held the
## two textures to 13.9 MiB, but on the A12 the floor's whole cost to video
## memory (its pipelines and buffers beside them, which Metal counts too) came
## to +21.8 MiB at the median against R3.2's +20; at 18 and 8, +18.7 at the
## hold starts and +20.6 at the first open. 16 and 8 hold the textures to
## 8.9 MiB; side by side at Close and Journey the picture is not told apart.
const LIT_TEXELS_PER_M: float = 16.0
const MASK_TEXELS_PER_M: float = 8.0
## The largest tile of the lit pass, each with the key's shadow map to itself,
## and how many tiles a frame draws (one view each).
const TILE_LIMIT: Vector2i = Vector2i(960, 600)
const TILES_A_FRAME: int = 2
## The key's shadow filter while the bake draws (the live floor's is the
## platform's; the A12's is hard).
const SOFT: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_HIGH
const SOFT_SETTING: String = "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"

enum Step { START, WARM, FIELDS, TILES, MIPS, DONE, FAILED }

var step: Step = Step.START
var failure: String = ""
## The two results while the bake owns them (`take`).
var lit_rid: RID = RID()
var mask_rid: RID = RID()
var lit_size: Vector2i = Vector2i.ZERO
var mask_size: Vector2i = Vector2i.ZERO
## Main-thread time of each step, the wall time, and what was drawn.
var timings: Dictionary = {}
var _land: MapJourneyLandscape = null
var _plan: Plan = null
var _rd: RenderingDevice = null
var _host: Node = null
var _stage: Stage = null
var _fields: SubViewport = null
var _lit_views: Array[SubViewport] = []
var _mask_view: SubViewport = null
var _lit_cameras: Array[Camera3D] = []
var _mips: Array[SubViewport] = []
var _lit: Texture2DRD = null
var _tiles: Array[Rect2i] = []
var _tile: int = 0
var _top: float = 0.0
var _started_us: int = 0
var _steps_ms: PackedFloat32Array = PackedFloat32Array()
## The frames the bake spans, step to step.
var _frames_ms: PackedFloat32Array = PackedFloat32Array()
var _last_us: int = 0
var _soft_set: bool = false
var _paced: bool = false
static var _radial: GradientTexture2D = null


## Whether this renderer can bake (it has a RenderingDevice to copy with).
static func supported() -> bool:
	return RenderingServer.get_rendering_device() != null and DisplayServer.get_name() != "headless"


## `paced`: one tile a frame (`TILES_A_FRAME` otherwise).
func _init(land: MapJourneyLandscape, plan: Plan, paced: bool = false) -> void:
	_land = land
	_plan = plan
	_paced = paced


## Carries the bake on by one frame's work; true once it has ended (`DONE`, or
## `FAILED` with `failure` said).
func advance() -> bool:
	var started: int = Time.get_ticks_usec()
	if _last_us > 0:
		_frames_ms.append((started - _last_us) / 1000.0)
	_last_us = started
	match step:
		Step.START:
			_start()
		Step.WARM:
			_warm()
		Step.FIELDS:
			_first_tile()
		Step.TILES:
			_next_tile()
		Step.MIPS:
			_finish_mips()
	_steps_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	if step == Step.DONE:
		timings["steps_ms"] = _steps_ms
		timings["frames_ms"] = _frames_ms
		timings["frames"] = _steps_ms.size()
	return finished()


func finished() -> bool:
	return step == Step.DONE or step == Step.FAILED


## The lit picture and the mask; the caller owns them from now on (and frees
## them with the RenderingDevice).
func take() -> Array[RID]:
	var out: Array[RID] = [lit_rid, mask_rid]
	lit_rid = RID()
	mask_rid = RID()
	if _lit != null:
		_lit.texture_rd_rid = RID()
		_lit = null
	return out


## Ends the bake at once and frees whatever it holds.
func cancel() -> void:
	if not finished():
		_fail("cancelled")
	_release_rids()


func _start() -> void:
	_started_us = Time.get_ticks_usec()
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		_fail("no RenderingDevice")
		return
	var bounds: Rect2 = _plan.bounds
	var ground: Vector2 = _plan.ground
	# The views look down from above the tallest thing that casts: the key's
	# shadow map holds only what the view's depth holds.
	_top = maxf(ground.y, MapJourneyCameraContract.LAND_HIGH) + 0.5
	lit_size = Vector2i(ceili(bounds.size.x * LIT_TEXELS_PER_M), ceili(bounds.size.y * LIT_TEXELS_PER_M))
	mask_size = Vector2i(ceili(bounds.size.x * MASK_TEXELS_PER_M), ceili(bounds.size.y * MASK_TEXELS_PER_M))
	lit_rid = _texture(lit_size, mip_count(lit_size))
	mask_rid = _texture(mask_size, 1)
	if not lit_rid.is_valid() or not mask_rid.is_valid():
		_fail("cannot make the floor's textures")
		return
	_tiles = tiles(lit_size, TILE_LIMIT)
	_host = Node.new()
	_host.name = "Floor bake"
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)
	_fields = _fields_pass()
	var world: World3D = World3D.new()
	for k: int in range(mini(1 if _paced else TILES_A_FRAME, _tiles.size())):
		_lit_views.append(_view("Floor bake lit %d" % k, _tiles[0].size, world))
	_mask_view = _view("Floor bake mask", mask_size, world)
	var paint: ShaderMaterial = _material(PAINT, true)
	var mask: ShaderMaterial = _material(MASK, false)
	_stage = Stage.new()
	_lit_views[0].add_child(_stage)
	_stage.compose(_land, _plan, paint, mask)
	for view: SubViewport in _lit_views:
		_lit_cameras.append(_camera(view, _stage.environment, Stage.LIT_LAYER | Stage.CASTER_LAYER))
	var plain: Environment = Environment.new()
	plain.background_mode = Environment.BG_COLOR
	plain.background_color = Color.BLACK
	plain.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var mask_camera: Camera3D = _camera(_mask_view, plain, Stage.MASK_LAYER)
	_aim(mask_camera, Rect2i(Vector2i.ZERO, mask_size), MASK_TEXELS_PER_M)
	timings["receivers"] = _stage.receivers
	timings["casters"] = _stage.casters
	timings["tiles"] = _tiles.size()
	timings["paced"] = _paced
	_tile = 0
	if _paced:
		step = Step.WARM
	else:
		_warm()


## A first draw, kept by no one: a light new to its world casts nothing in its
## first frame.
func _warm() -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(SOFT)
	_soft_set = true
	_draw_tiles()
	step = Step.FIELDS


func _first_tile() -> void:
	_draw_tiles()
	_mask_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	step = Step.TILES


## Each lit view aimed at its tile of the next few, and drawn.
func _draw_tiles() -> void:
	for k: int in range(_lit_views.size()):
		if _tile + k < _tiles.size():
			_aim(_lit_cameras[k], _tiles[_tile + k], LIT_TEXELS_PER_M)
			_lit_views[k].render_target_update_mode = SubViewport.UPDATE_ONCE


## Copies the tiles the last frame drew (and the mask with the first), then
## draws the next, or once all are in, the mip chain from them.
func _next_tile() -> void:
	for k: int in range(_lit_views.size()):
		if _tile + k >= _tiles.size():
			break
		var tile: Rect2i = _tiles[_tile + k]
		if not _copy(_lit_views[k], lit_rid, Rect2i(Vector2i.ZERO, tile.size), tile.position, 0):
			return
	if _tile == 0 and not _copy(_mask_view, mask_rid, Rect2i(Vector2i.ZERO, mask_size), Vector2i.ZERO, 0):
		return
	_tile += _lit_views.size()
	if _tile < _tiles.size():
		_draw_tiles()
		return
	_restore_soft()
	_lit = Texture2DRD.new()
	_lit.texture_rd_rid = lit_rid
	_mip_chain()
	step = Step.MIPS


func _finish_mips() -> void:
	for k: int in range(_mips.size()):
		var size: Vector2i = mip_size(lit_size, k + 1)
		if not _copy(_mips[k], lit_rid, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO, k + 1):
			return
	_free_host()
	timings["wall_ms"] = (Time.get_ticks_usec() - _started_us) / 1000.0
	step = Step.DONE


func _mip_chain() -> void:
	_mips = mip_views(_host, _lit, lit_size)


## The mip chain of a `size` picture `source` as views nested under `holder`,
## the smallest outermost: the engine draws a view's children before it, so
## each level reads the level below it drawn in the same frame, and the first
## reads the picture's own top level. Each view draws once. The warm-up builds
## one too (`floor_warm.gd`), so the bake's pipelines are its own.
static func mip_views(holder: Node, source: Texture2D, size: Vector2i) -> Array[SubViewport]:
	var levels: int = mip_count(size) - 1
	var views: Array[SubViewport] = []
	for k: int in range(levels):
		views.append(null)
	for k: int in range(levels - 1, -1, -1):
		var view: SubViewport = SubViewport.new()
		view.name = "Floor mip %d" % (k + 1)
		view.size = mip_size(size, k + 1).max(Vector2i(2, 2))
		view.disable_3d = true
		view.transparent_bg = false
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		holder.add_child(view)
		holder = view
		views[k] = view
	for k: int in range(levels):
		var rect: ColorRect = ColorRect.new()
		rect.size = Vector2(views[k].size)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = MIP
		material.set_shader_parameter("source", source if k == 0 else views[k - 1].get_texture())
		material.set_shader_parameter("source_size", mip_size(size, k))
		rect.material = material
		views[k].add_child(rect)
		views[k].render_target_update_mode = SubViewport.UPDATE_ONCE
	return views


## The lit picture's tiles: as few as fit `limit`, equal but for the last.
static func tiles(size: Vector2i, limit: Vector2i) -> Array[Rect2i]:
	var grid: Vector2i = Vector2i(ceili(float(size.x) / limit.x), ceili(float(size.y) / limit.y))
	var cell: Vector2i = Vector2i(ceili(float(size.x) / grid.x), ceili(float(size.y) / grid.y))
	var out: Array[Rect2i] = []
	for row: int in range(grid.y):
		for column: int in range(grid.x):
			var at: Vector2i = Vector2i(column, row) * cell
			out.append(Rect2i(at, (size - at).min(cell)))
	return out


static func mip_count(size: Vector2i) -> int:
	return 1 + floori(log(float(maxi(size.x, size.y))) / log(2.0))


static func mip_size(size: Vector2i, level: int) -> Vector2i:
	return Vector2i(maxi(1, size.x >> level), maxi(1, size.y >> level))


func _texture(size: Vector2i, mipmaps: int) -> RID:
	return texture_rd(_rd, size, mipmaps)


## A picture of the floor's own format on `rd`: RGBA8, with an sRGB view to
## share, copied to and from, `mipmaps` levels.
static func texture_rd(rd: RenderingDevice, size: Vector2i, mipmaps: int) -> RID:
	var format: RDTextureFormat = RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = size.x
	format.height = size.y
	format.mipmaps = mipmaps
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	format.add_shareable_format(RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)
	format.add_shareable_format(RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB)
	return rd.texture_create(format, RDTextureView.new())


## Copies `region` of `view`'s picture to `to` in `target`'s level `mip`.
func _copy(view: SubViewport, target: RID, region: Rect2i, to: Vector2i, mip: int) -> bool:
	var source: RID = RenderingServer.texture_get_rd_texture(RenderingServer.viewport_get_texture(view.get_viewport_rid()))
	var error: Error = _rd.texture_copy(source, target, Vector3(region.position.x, region.position.y, 0),
		Vector3(to.x, to.y, 0), Vector3(region.size.x, region.size.y, 1), 0, mip, 0, 0)
	if error != OK:
		_fail("texture copy failed (%d) into level %d" % [error, mip])
		return false
	return true


func _view(label: String, size: Vector2i, world: World3D) -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.name = label
	view.size = size
	view.world_3d = world
	view.transparent_bg = false
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 0
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_host.add_child(view)
	return view


func _camera(view: SubViewport, environment: Environment, mask: int) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.cull_mask = mask
	camera.environment = environment
	camera.current = true
	view.add_child(camera)
	return camera


## Points `camera` straight down at `texels` of the picture (its view's size
## from the region's corner), the ground's heights between near and far.
func _aim(camera: Camera3D, texels: Rect2i, per_metre: float) -> void:
	var bounds: Rect2 = _plan.bounds
	var ground: Vector2 = _plan.ground
	var view_size: Vector2 = Vector2((camera.get_parent() as SubViewport).size)
	var corner: Vector2 = bounds.position + Vector2(texels.position) / per_metre
	var centre: Vector2 = corner + view_size / per_metre * 0.5
	camera.size = view_size.y / per_metre
	camera.position = Vector3(centre.x, _top, centre.y)
	camera.near = 0.05
	camera.far = _top - ground.x + 1.0


## The 2D pass: every plant's, stone's and seat's stamp added up.
func _fields_pass() -> SubViewport:
	var view: SubViewport = SubViewport.new()
	view.name = "Floor bake fields"
	view.size = _plan.field_size
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_host.add_child(view)
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_2D
	multi.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	multi.mesh = quad
	multi.instance_count = _plan.stamp_count
	if multi.instance_count > 0:
		multi.buffer = _plan.stamps
	var draw: MultiMeshInstance2D = MultiMeshInstance2D.new()
	draw.multimesh = multi
	draw.texture = radial()
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	draw.material = add
	view.add_child(draw)
	return view


## A soft round stamp, full at its centre and gone at its rim.
static func radial() -> GradientTexture2D:
	if _radial == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8),
			Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
		_radial = GradientTexture2D.new()
		_radial.gradient = gradient
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 64
		_radial.height = 64
	return _radial


## The lit pass's or the mask's material: the land's ground as the floor
## reads it, and for the lit pass its covers.
func _material(shader: Shader, covers: bool) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var bounds: Rect2 = _plan.bounds
	var ground: ShaderMaterial = _land.terrain.paint
	material.set_shader_parameter("world_bounds", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	for shared: String in ["route_distance", "river_cuts", "channel", "river_level", "gateway_position"]:
		var value: Variant = ground.get_shader_parameter(shared)
		if value != null:
			material.set_shader_parameter(shared, value)
	material.set_shader_parameter("fields", _fields.get_texture())
	material.set_shader_parameter("fields_origin", bounds.position)
	material.set_shader_parameter("fields_size", bounds.size)
	var lamps: PackedVector4Array = _plan.lamps
	var padded: PackedVector4Array = lamps.duplicate()
	padded.resize(48)
	material.set_shader_parameter("lamps", padded)
	material.set_shader_parameter("lamp_count", lamps.size())
	if covers:
		for cover: String in COVERS:
			var path: String = COVERS[cover]
			if ResourceLoader.exists(path):
				material.set_shader_parameter(cover, load(path))
	return material


func _fail(reason: String) -> void:
	failure = reason
	step = Step.FAILED
	_restore_soft()
	_free_host()
	_release_rids()
	timings["wall_ms"] = (Time.get_ticks_usec() - _started_us) / 1000.0


func _restore_soft() -> void:
	if _soft_set:
		_soft_set = false
		var quality: int = int(str(ProjectSettings.get_setting_with_override(SOFT_SETTING)))
		RenderingServer.directional_soft_shadow_filter_set_quality(quality as RenderingServer.ShadowQuality)


func _free_host() -> void:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	_host = null
	_stage = null
	_mips.clear()
	_lit_views.clear()
	_lit_cameras.clear()


func _release_rids() -> void:
	if _lit != null:
		_lit.texture_rd_rid = RID()
		_lit = null
	for rid: RID in [lit_rid, mask_rid]:
		if rid.is_valid() and _rd != null:
			_rd.free_rid(rid)
	lit_rid = RID()
	mask_rid = RID()
