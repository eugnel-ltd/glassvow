extends Node
## Act I's floor (R3.2, issue #660): the land's ground drawn from its bake.
##
## The plan is worked out on the land's worker as the land is built
## (`prepare`, `floor_plan.gd`); the bake then runs a step a frame on the main
## thread behind the veil (`step`, `floor_bake.gd`), and once it is in, the
## ground's chunks take the floor's shader (`floor.gdshader`) and the land
## gives up what the bake now carries: the woodland's and the small things'
## live shadows, which fell only on the ground (the gateway, the shrines, the
## rocks and the bridges still cast, on each other), the road's small stones
## and fallen leaves (baked into the picture), and the pilgrim's own shadow
## (a soft blob under it now). Where the renderer cannot bake, or the bake
## fails, the land keeps its painted ground and everything as it was.
##
## The baked textures are the floor's own (RenderingDevice textures); it frees
## them with itself.

const Plan = preload("res://presentation/map/landscape/floor_plan.gd")
const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
const Warm = preload("res://presentation/map/landscape/floor_warm.gd")
const Details = preload("res://presentation/map/landscape/road_details.gd")
const FLOOR: Shader = preload("res://presentation/map/landscape/floor.gdshader")
const DETAIL: Texture2D = preload("res://assets/art/map-journey/floor/floor-detail.png")
## What goes on casting live once the floor is baked: the gateway and the
## rock outcrops, whose faces shade each other, and the bridges' parapets,
## whose stones mark their decks (the live shadow pass's budget, R3.2: 15k
## primitives at the Journey view). Everything else's shadow is in the floor.
const LIVE_CASTERS: PackedStringArray = ["amber-arch", "slate-bank", "slate-ridge", "slate-shard"]
const LIVE_BRIDGE: String = "Bridge parapet stones"
## The pilgrim's carried light on the floor: its reach (metres) and strength,
## R1's small one on phones and tablets, a wider one on the desktop
## (`pilgrim.gd`'s own light).
const WALKER_REACH: Vector2 = Vector2(1.6, 2.8)
const WALKER_STRENGTH: Vector2 = Vector2(0.55, 1.1)

enum State { PLANNED, BAKING, BAKED, PAINTED }

var state: State = State.PLANNED
var plan: Plan = null
var material: ShaderMaterial = null
var failure: String = ""
var timings_ms: Dictionary = {}
var _bake: Bake = null
var _rids: Array[RID] = []
var _textures: Array[Texture2DRD] = []
var _flame: Color = Color("e9ab54")


## On the land's worker, once the land is built.
func prepare(land: MapJourneyLandscape) -> void:
	name = "Floor"
	plan = Plan.new()
	plan.build(land, MapJourneyLandscape.KEY_ROTATION)
	timings_ms["plan"] = plan.timings_ms.get("plan", 0.0)


## Whether the floor has settled: baked, or left painted.
func settled() -> bool:
	return state == State.BAKED or state == State.PAINTED


## One frame of the bake (main thread); true once the floor has settled.
## `paced` (a bake begun under a lit title) bakes a tile a frame.
func step(land: MapJourneyLandscape, paced: bool = false) -> bool:
	if settled():
		return true
	if state == State.PLANNED:
		if plan == null or not Bake.supported():
			state = State.PAINTED
			return true
		_bake = Bake.new(land, plan, paced)
		state = State.BAKING
	if _bake == null:
		state = State.PAINTED
		return true
	if not _bake.advance():
		return false
	timings_ms["bake"] = _bake.timings
	if _bake.step == Bake.Step.DONE:
		_rids = _bake.take()
		_apply(land, _bake.lit_size)
		state = State.BAKED
	else:
		failure = _bake.failure
		push_warning("Journey floor: the bake failed (%s); the land keeps its painted ground" % failure)
		state = State.PAINTED
	_bake = null
	return true


## Where the pilgrim stands and whether it shows: its carried light warms the
## floor round it.
func set_walker(at: Vector3, shown: bool) -> void:
	if material == null:
		return
	var lean: bool = MapScene.lean_profile()
	var reach: float = (WALKER_REACH.x if lean else WALKER_REACH.y) if shown and at.is_finite() else 0.0
	material.set_shader_parameter("walker", Vector3(at.x, at.z, reach) if reach > 0.0 else Vector3.ZERO)


func set_flame(colour: Color) -> void:
	_flame = colour
	_walker_light()


func _walker_light() -> void:
	if material == null:
		return
	var strength: float = WALKER_STRENGTH.x if MapScene.lean_profile() else WALKER_STRENGTH.y
	var light: Color = _flame.lightened(0.15)
	material.set_shader_parameter("walker_light", Vector3(light.r, light.g, light.b) * strength)


func _apply(land: MapJourneyLandscape, lit_size: Vector2i) -> void:
	for rid: RID in _rids:
		var texture: Texture2DRD = Texture2DRD.new()
		texture.texture_rd_rid = rid
		_textures.append(texture)
	timings_ms["lit_texels"] = [lit_size.x, lit_size.y]
	draw_floor(land, floor_material(_textures[0], _textures[1], plan.bounds))
	quiet(land)
	if land.journey != null:
		land.journey.walker.ground_blob(true)
	_walker_light()


## The floor's runtime material on the baked picture `lit` and its `mask`.
static func floor_material(lit: Texture2D, mask: Texture2D, bounds: Rect2) -> ShaderMaterial:
	var floor_paint: ShaderMaterial = ShaderMaterial.new()
	floor_paint.shader = FLOOR
	floor_paint.set_shader_parameter("lit", lit)
	floor_paint.set_shader_parameter("mask", mask)
	floor_paint.set_shader_parameter("detail", DETAIL)
	floor_paint.set_shader_parameter("world_bounds", Vector4(bounds.position.x, bounds.position.y,
		bounds.size.x, bounds.size.y))
	floor_paint.set_shader_parameter("decode", 1.0 / Bake.Stage.EXPOSURE)
	return floor_paint


## The ground's chunks drawn with `with`, and the road's small stones and
## fallen leaves, which the bake drew into the picture, put out.
func draw_floor(land: MapJourneyLandscape, with: ShaderMaterial) -> void:
	material = with
	for chunk: MeshInstance3D in land.terrain.chunks:
		chunk.material_override = material
	for label: String in Details.NAMES:
		var detail: Node3D = land.terrain.get_node_or_null(label) as Node3D
		if detail != null:
			detail.visible = false


## The live shadow pass keeps only `LIVE_CASTERS` and the bridges' parapets.
func quiet(land: MapJourneyLandscape) -> void:
	for node: Node in land.terrain.find_children("*", "GeometryInstance3D", true, false):
		if str(node.name) != LIVE_BRIDGE:
			_no_shadow(node as GeometryInstance3D)
	if land.wood != null:
		for caster: GeometryInstance3D in land.wood.casters:
			_no_shadow(caster)
	if land.kit != null:
		for node: Node in land.kit.find_children("*", "GeometryInstance3D", true, false):
			if not hero_part(node, land.kit):
				_no_shadow(node as GeometryInstance3D)
	if land.journey != null:
		for node: Node in land.journey.find_children("*", "GeometryInstance3D", true, false):
			_no_shadow(node as GeometryInstance3D)


## A part that only ever cast (a shadow proxy) is put out; any other stops
## casting and goes on drawing.
static func _no_shadow(part: GeometryInstance3D) -> void:
	if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		part.visible = false
	else:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Whether a drawn part of the kit is one of `LIVE_CASTERS`: by its batch's
## kind (`static_scenery.gd`), else by the placement it stands under.
static func hero_part(part: Node, kit: Node) -> bool:
	var kind: String = str(part.get_meta("kind", ""))
	if kind.is_empty():
		var node: Node = part
		while node != null and node.get_parent() != kit:
			node = node.get_parent()
		kind = str(node.name) if node != null else ""
	for hero: String in LIVE_CASTERS:
		if kind.begins_with(hero):
			return true
	return false


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if _bake != null:
		_bake.cancel()
		_bake = null
	for texture: Texture2DRD in _textures:
		texture.texture_rd_rid = RID()
	_textures.clear()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	for rid: RID in _rids:
		if rid.is_valid() and rd != null:
			rd.free_rid(rid)
	_rids.clear()
