extends MeshInstance3D
## A bounded river surface, with bathymetry from the actual rendered bank.
##
## The water runs in the production layout's ravines: one river per
## `MapRavine.CUTS` entry, on `MapRavine.centre`. The layout already keeps its
## waystones off those ravines (or stands them on piers), so the water never
## needs a waystone moved. The archived river was 4 m wide either side of its
## line; `CHANNEL` narrows the whole cross-section to the ravine. Distances the
## landscape compares with river thresholds are in channel units
## (`distance`), so those thresholds keep the archive's proportions.
const LEVEL: float = -2.30
## Half the water's width, in channel units.
const HALF_WIDTH: float = 4.0
const HALF_LENGTH: float = 35.0
const CHANNEL: float = 0.6
## The bathymetry the water shader reads: about 15 cm across and 25 cm along,
## plenty for a depth tint, and a sixteenth of the archive's samples.
const FIELD_SIZE: Vector2i = Vector2i(32,1120)
var half_length: float = HALF_LENGTH
## The ravine this river runs in: an entry of `MapRavine.CUTS`.
var cut: float = 0.0
var field_size: Vector2i = FIELD_SIZE
var clock_time: float = 0
var animate: bool = true
var field_image: Image

static func centre(z: float, cut_x: float) -> float:
	return MapRavine.centre(cut_x, z)

## Distance from (x, z) to the nearest river's line, in channel units.
static func distance(x: float, z: float) -> float:
	var best: float = INF
	for cut_x: float in MapRavine.CUTS:
		best = minf(best, absf(x - centre(z, cut_x)))
	return best / CHANNEL

static func contains(x: float,z: float, length_half: float = HALF_LENGTH) -> bool:
	return distance(x,z)<HALF_WIDTH and absf(z)<length_half

func build(land: Node3D) -> void:
	name = "Stream"
	half_length = land.river_half_length
	var rows: int = ceili(half_length*2/.25)
	field_size = Vector2i(FIELD_SIZE.x,ceili(half_length*2*4))
	layers = 2
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in range(rows):
		for ix: int in range(32):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,1),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0),Vector2i(1,1)]:
				var uv: Vector2 = Vector2(ix+corner.x,iz+corner.y)/Vector2(32,rows)
				var z: float = lerpf(-half_length,half_length,uv.y)
				var x: float = centre(z,cut)+lerpf(-HALF_WIDTH,HALF_WIDTH,uv.x)*CHANNEL
				top.set_uv(uv)
				top.set_normal(Vector3.UP)
				top.add_vertex(Vector3(x,LEVEL,z))
	mesh = preload("res://presentation/map/landscape/mesh_tools.gd").committed(top.commit())
	field_image = Image.create(field_size.x,field_size.y,false,Image.FORMAT_RF)
	for iz: int in range(field_size.y):
		var z: float = lerpf(-half_length,half_length,(iz+.5)/field_size.y)
		for ix: int in range(field_size.x):
			var x: float = centre(z,cut)+lerpf(-HALF_WIDTH,HALF_WIDTH,(ix+.5)/field_size.x)*CHANNEL
			var ground: float = land.surface_height(x,z)
			field_image.set_pixel(ix,iz,Color(LEVEL-ground,0,0))
	var water: ShaderMaterial = ShaderMaterial.new()
	water.shader = preload("res://presentation/map/landscape/river.gdshader")
	water.set_shader_parameter("river_length_m",half_length*2)
	water.set_shader_parameter("river_cut",cut)
	water.set_shader_parameter("channel",CHANNEL)
	water.set_shader_parameter("bathymetry",ImageTexture.create_from_image(field_image))
	var piers: PackedVector4Array = []
	var deck: RefCounted = land.get_meta("bridge_field") if land.has_meta("bridge_field") else null
	if deck!=null:
		for value: Array in land.anchors.values():
			var p: Vector3 = preload("res://presentation/map/landscape/mesh_tools.gd").v3(value)
			if absf(p.x-centre(p.z,cut))>2.7*CHANNEL:
				continue
			var contact: Dictionary = deck.field(Vector2(p.x,p.z))
			var distance: float = contact["distance"]
			var bottom: float = contact["bottom"]
			if distance<0 and bottom<LEVEL:
				piers.append(Vector4(p.x,p.z,.85,0))
	water.set_shader_parameter("pier_count",mini(16,piers.size()))
	piers.resize(16)
	water.set_shader_parameter("piers",piers)
	material_override = water
	var bank: MeshInstance3D = land.get_node("Quiet sculpted ground") as MeshInstance3D
	if bank.material_override is ShaderMaterial:
		(bank.material_override as ShaderMaterial).set_shader_parameter("river_level",LEVEL)
	set_time(0)

func set_time(seconds: float) -> void:
	clock_time = seconds
	(material_override as ShaderMaterial).set_shader_parameter("flow_time",seconds)

func _process(delta: float) -> void:
	if animate:
		set_time(clock_time+delta)
