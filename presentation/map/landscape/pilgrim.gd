extends Node3D
## Small anonymous cloaked traveller, with a carried light and a grounded hem.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
var cloak: Node3D
var lamp: Node3D
var boots: Array[Node3D] = []
## The run's Flame: the lantern's glass and the light it throws (`set_flame`).
var flame: Color = Color("e9ab54")
var _ember: StandardMaterial3D
var _light: OmniLight3D
## The soft shadow under the pilgrim once the land's floor is baked
## (`ground_blob`): the floor takes no live shadow. Wanted before the pilgrim
## is built (the land is baked off the tree), it is made as it is.
var _blob: MeshInstance3D = null
var _blob_wanted: bool = false
## The blob's width (metres) and how dark its middle is.
const BLOB_SIZE: float = 0.95
const BLOB_DEPTH: float = 0.5

func _ready() -> void:
	var cloth: StandardMaterial3D = Meshes.material(Color("38333e"))
	var dark: StandardMaterial3D = Meshes.material(Color("211e27"))
	var iron: StandardMaterial3D = Meshes.material(Color("443b39"),.65)
	cloak = Node3D.new()
	add_child(cloak)
	var folds: SurfaceTool = SurfaceTool.new()
	folds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector2] = [Vector2(.33,.10),Vector2(.27,.70),Vector2(.24,1.25),Vector2(.15,1.38)]
	for j: int in range(rings.size()-1):
		for i: int in range(12):
			var a: float = i*TAU/12
			var b: float = (i+1)*TAU/12
			var r: float = 1.0 if i%2==0 else .91
			var next_r: float = 1.0 if (i+1)%2==0 else .91
			var p: Vector3 = Vector3(cos(a)*rings[j].x*r,rings[j].y,sin(a)*rings[j].x*r)
			var q: Vector3 = Vector3(cos(b)*rings[j].x*next_r,rings[j].y,sin(b)*rings[j].x*next_r)
			var u: Vector3 = Vector3(cos(a)*rings[j+1].x*r,rings[j+1].y,sin(a)*rings[j+1].x*r)
			var v: Vector3 = Vector3(cos(b)*rings[j+1].x*next_r,rings[j+1].y,sin(b)*rings[j+1].x*next_r)
			Meshes.triangle(folds,p,v,u)
			Meshes.triangle(folds,p,q,v)
	Meshes.node(cloak,Meshes.finish(folds),cloth,"Heavy travelling cloak")
	var hood: SphereMesh = SphereMesh.new()
	hood.radius = .205
	hood.height = .43
	hood.radial_segments = 12
	hood.rings = 6
	Meshes.node(cloak,hood,cloth,"Deep hood").position = Vector3(0,1.47,0)
	var face: SphereMesh = SphereMesh.new()
	face.radius = .13
	face.height = .28
	# A few pixels on the map: the default 64 x 32 sphere is 4k triangles in
	# both the stage and the shadow pass.
	face.radial_segments = 10
	face.rings = 5
	var hollow: MeshInstance3D = Meshes.node(cloak,face,dark,"Hood shadow")
	hollow.position = Vector3(0,1.47,.215)
	hollow.scale.z = .42
	for side: float in [-1,1]:
		boots.append(Meshes.box(self,Vector3(side*.11,.06,.05),Vector3(.13,.12,.24),dark,"Worn boot"))
	var sleeve: CylinderMesh = CylinderMesh.new()
	sleeve.top_radius = .10
	sleeve.bottom_radius = .075
	sleeve.height = .48
	sleeve.radial_segments = 8
	var arm: MeshInstance3D = Meshes.node(cloak,sleeve,cloth,"Lantern arm")
	arm.position = Vector3(.29,1.01,.08)
	arm.rotation.z = .30
	var glove: SphereMesh = SphereMesh.new()
	glove.radius = .07
	glove.height = .15
	glove.radial_segments = 8
	glove.rings = 4
	Meshes.node(cloak,glove,iron,"Worn glove").position = Vector3(.38,.80,.14)
	lamp = Node3D.new()
	lamp.position = Vector3(.40,.58,.19)
	add_child(lamp)
	Meshes.box(lamp,Vector3(0,.17,0),Vector3(.18,.035,.18),iron,"Lantern cap")
	Meshes.box(lamp,Vector3(0,-.07,0),Vector3(.17,.035,.17),iron,"Lantern foot")
	_ember = Meshes.material(Color("edbd71"))
	_ember.emission_enabled = true
	_ember.emission_energy_multiplier = 1.8
	Meshes.box(lamp,Vector3(0,.05,0),Vector3(.115,.20,.115),_ember,"Carried ember")
	for x: float in [-1,1]:
		for z: float in [-1,1]:
			Meshes.box(lamp,Vector3(x*.073,.05,z*.073),Vector3(.022,.24,.022),iron,"Lantern corner")
	# The Flame carries a pool of the run's colour along the road (R2): a wider
	# one on the desktop; on phones and tablets (the lean profile) R1's small
	# one, which the iPad 8 measured free.
	var lean: bool = MapScene.lean_profile()
	_light = OmniLight3D.new()
	_light.light_energy = .32 if lean else .9
	_light.omni_range = 1.4 if lean else 2.6
	_light.shadow_enabled = false
	lamp.add_child(_light)
	set_flame(flame)
	Meshes.box(lamp,Vector3(0,.21,0),Vector3(.025,.12,.025),iron,"Lantern handle")
	if _blob_wanted:
		ground_blob(true)

func pose(distance: float, walking: bool) -> void:
	if cloak == null:
		return
	cloak.rotation.z = sin(distance*5)*.025 if walking else 0.0
	lamp.rotation.x = sin(distance*5)*.12 if walking else 0.0
	for i: int in range(boots.size()):
		var stride: float = sin(distance*5+i*PI) if walking else 0.0
		boots[i].position.z = .05+stride*.09
		boots[i].position.y = .06+maxf(0,stride)*.045


## The pilgrim's shadow as a soft blob on the ground under it (true), or its
## own live shadow (false): the floor drawn from its bake takes no live
## shadow, and the deck's or a stone's would be the pilgrim's only one.
func ground_blob(on: bool) -> void:
	_blob_wanted = on
	if cloak == null:
		return
	if on and _blob == null:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(BLOB_SIZE, BLOB_SIZE)
		quad.orientation = PlaneMesh.FACE_Y
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
		var fall: GradientTexture2D = GradientTexture2D.new()
		fall.gradient = gradient
		fall.fill = GradientTexture2D.FILL_RADIAL
		fall.fill_from = Vector2(0.5, 0.5)
		fall.fill_to = Vector2(1.0, 0.5)
		fall.width = 32
		fall.height = 32
		var shade: StandardMaterial3D = StandardMaterial3D.new()
		shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shade.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		shade.albedo_color = Color(0.02, 0.015, 0.02, BLOB_DEPTH)
		shade.albedo_texture = fall
		_blob = Meshes.node(self, quad, shade, "Ground blob")
		_blob.position = Vector3(0.0, 0.03, 0.0)
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _blob != null:
		_blob.visible = on
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		if node != _blob:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Burns the carried lantern in the run's Flame colour: its glass and its light.
func set_flame(colour: Color) -> void:
	flame = colour
	if _ember == null:
		return
	_ember.albedo_color = colour.lightened(0.25)
	_ember.emission = colour
	_light.light_color = colour.lightened(0.15)
