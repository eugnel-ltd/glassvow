extends Node3D
## The floor bake's private world (R3.2, `floor_bake.gd`): the land's ground,
## once with the lit forest floor (`floor_paint.gdshader`) and once with its
## mask (`floor_mask.gdshader`), under Act I's key light and sky, with every
## static thing that stands on the land casting into the key's shadow map and
## nothing else drawn. Built from a land already in hand: the ground's
## chunks, the kit's batches, the bridges and the waystones lend their meshes
## (shared, never copied), and the woodland casts through its plants' own
## silhouettes turned to the light (`FloorPlan.casters`). The pilgrim, the
## water, the flames and the drifting air are live and stay out.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Plan = preload("res://presentation/map/landscape/floor_plan.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const Details = preload("res://presentation/map/landscape/road_details.gd")
const CASTER: Shader = preload("res://presentation/map/landscape/floor_caster.gdshader")

## The lit pass's receivers, the mask pass's, and what casts.
const LIT_LAYER: int = 1
const MASK_LAYER: int = 2
const CASTER_LAYER: int = 4
## The share of the land's light the picture keeps (the floor doubles it back,
## `floor.gdshader` `decode`): room above white for the lamps' pools.
const EXPOSURE: float = 0.5

var key: DirectionalLight3D
## The live land's sky and ambient, through a linear tonemap at `EXPOSURE` with
## no grade, glow or fog: the picture keeps the land's light as it falls, and
## the live frame grades it as it grades everything else.
var environment: Environment
var receivers: int = 0
var casters: int = 0


## Builds the world for `land` from its `plan`, the ground drawn with `paint`
## (lit) and `mask`.
func compose(land: MapJourneyLandscape, plan: Plan, paint: Material, mask: Material) -> void:
	name = "Floor bake world"
	light_up()
	for chunk: MeshInstance3D in land.terrain.chunks:
		_receiver(chunk, paint, LIT_LAYER, true)
		_receiver(chunk, mask, MASK_LAYER, false)
	for label: String in Details.NAMES:
		var detail: MeshInstance3D = land.terrain.get_node_or_null(label) as MeshInstance3D
		if detail != null:
			_receiver(detail, null, LIT_LAYER, false)
	_wood(plan)
	for child: Node in land.terrain.get_children():
		if child is MeshInstance3D and not land.terrain.chunks.has(child) \
				and not Details.NAMES.has(str(child.name)) and child.get_script() != River:
			_casts_from(child)
	if land.kit != null:
		_casts_from(land.kit)
	if land.journey != null:
		for child: Node in land.journey.get_children():
			if child != land.journey.walker:
				_casts_from(child)


## Act I's key, as the live land lights it (`MapJourneyLandscape.light`), its
## shadow soft and from both the ground and what stands on it.
func light_up() -> void:
	key = DirectionalLight3D.new()
	key.name = "Floor bake key"
	environment = Environment.new()
	MapJourneyLandscape.light(key, environment)
	environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = EXPOSURE
	environment.adjustment_enabled = false
	environment.glow_enabled = false
	environment.fog_enabled = false
	key.layers = LIT_LAYER | CASTER_LAYER
	key.light_cull_mask = LIT_LAYER | CASTER_LAYER
	key.shadow_caster_mask = LIT_LAYER | CASTER_LAYER
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# A little deeper than the live key's 0.72: the floor's dapple is the
	# picture's main shading now.
	key.shadow_opacity = 0.84
	key.shadow_blur = 2.2
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.2
	add_child(key)


func _receiver(source: MeshInstance3D, material: Material, layer: int, casts: bool) -> void:
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = source.mesh
	item.material_override = material if material != null else source.material_override
	item.transform = _in_land(source)
	item.layers = layer
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	receivers += 1


## The woodland's shadow cards, one draw.
func _wood(plan: Plan) -> void:
	var count: int = plan.caster_count
	if count == 0 or Atlas.material == null:
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = CASTER
	material.set_shader_parameter("atlas_albedo", Atlas.material.get_shader_parameter("atlas_albedo"))
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = Atlas.card
	multi.instance_count = count
	multi.buffer = plan.casters
	var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
	draw.name = "Woodland shadow cards"
	draw.multimesh = multi
	draw.material_override = material
	draw.layers = CASTER_LAYER
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(draw)
	casters += count


## Every drawn part under `root` that casts on the live land casts here too,
## shadows only (the woodland's own casters aside: its cards cast instead).
func _casts_from(root: Node) -> void:
	var parts: Array[Node] = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		parts.append(root)
	for node: Node in parts:
		var part: GeometryInstance3D = node as GeometryInstance3D
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not part.visible:
			continue
		var copy: GeometryInstance3D = null
		if part is MultiMeshInstance3D:
			var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
			batch.multimesh = (part as MultiMeshInstance3D).multimesh
			copy = batch
		elif part is MeshInstance3D:
			var source: MeshInstance3D = part as MeshInstance3D
			var single: MeshInstance3D = MeshInstance3D.new()
			single.mesh = source.mesh
			for surface: int in range(source.get_surface_override_material_count()):
				single.set_surface_override_material(surface, source.get_surface_override_material(surface))
			copy = single
		if copy == null:
			continue
		copy.material_override = part.material_override
		copy.transform = _in_land(part)
		copy.layers = CASTER_LAYER
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(copy)
		casters += 1


## `node`'s pose in its land's space (the land stands at the world's origin),
## read from the transforms up its parents: the land may be off the tree.
static func _in_land(node: Node3D) -> Transform3D:
	var pose: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent is Node3D and not parent is MapJourneyLandscape:
		pose = (parent as Node3D).transform * pose
		parent = parent.get_parent()
	return pose
