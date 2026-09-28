extends SceneTree
const Surface = preload("res://tools/map_workshop/common/resolved_route_surface.gd")
const MeshBuilder = preload("res://tools/map_workshop/common/flight_mesh.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/act3-landed-headroom.json"))
	root.content_scale_size = Vector2i(1458,820)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1458,820)
	root.msaa_3d = Viewport.MSAA_4X
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("16121e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6bcd9")
	environment.environment.ambient_light_energy = .6
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_energy = 1.5
	sun.shadow_enabled = not "--no-shadows" in OS.get_cmdline_user_args()
	print("SHADOW_PARAMETERS bias=",sun.shadow_bias," normal_bias=",sun.shadow_normal_bias)
	world.add_child(sun)
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color("635a73")
	stone.roughness = .7
	var road: StandardMaterial3D = stone.duplicate()
	road.albedo_color = Color("38303f")
	var total_faces: int = 0
	for edge_id: String in ["3:8,4>3:9,3","3:7,3>3:8,3"]:
		var line: PackedVector3Array = []
		for value: Array in report["routes"][edge_id]["centerline"]:
			line.append(Vector3(MapLayoutCanonical.float_value(value[0]),
				MapLayoutCanonical.float_value(value[1]),MapLayoutCanonical.float_value(value[2])))
		var plan: Dictionary = Surface.resolve(line,2.5,-1,.65)
		if plan.get("ok") != true:
			push_error(JSON.stringify(plan))
			quit(1)
			return
		var item: MeshInstance3D = MeshInstance3D.new()
		item.mesh = MeshBuilder.build(plan)
		total_faces += item.mesh.get_faces().size()/3
		item.material_override = stone if edge_id == "3:8,4>3:9,3" else road
		world.add_child(item)
	for z: float in [-2.15,2.15]:
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(2.5,3.45,1.0)
		pillar.mesh = mesh
		pillar.position = Vector3(8.723,.725,z)
		pillar.material_override = stone
		world.add_child(pillar)
	var person: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = .18
	capsule.height = 1.8
	person.mesh = capsule
	person.position = Vector3(8.723,.9,0)
	world.add_child(person)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	camera.position = Vector3(28,20,23)
	camera.look_at(Vector3(12,1,1))
	camera.make_current()
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("/tmp/act3-passage-no-shadow.png" if "--no-shadows" in OS.get_cmdline_user_args() else "/tmp/act3-passage-assembled.png")
	print("PASSAGE_ASSEMBLY triangles=",total_faces," capture=",error)
	quit(0 if error == OK else 1)
