extends SceneTree
## Small native structural proof before whole-chapter assembly.
const Flight = preload("res://tools/map_workshop/common/resolved_flight.gd")
const FlightMesh = preload("res://tools/map_workshop/common/flight_mesh.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1180, 820)
	DisplayServer.window_set_size(root.size)
	root.msaa_3d = Viewport.MSAA_4X
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15131d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("aaa1c4")
	environment.environment.ambient_light_energy = .5
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	world.add_child(sun)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("625e73")
	material.roughness = .72
	var plan: Dictionary = Flight.resolve(Vector3(-5, 0, 0), Vector3(5, 2.04, 0), 3.0, -1.0, 1.0)
	var item: MeshInstance3D = MeshInstance3D.new()
	item.mesh = FlightMesh.build(plan)
	item.material_override = material
	world.add_child(item)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	world.add_child(camera)
	camera.position = Vector3(-10, 10, 14)
	camera.look_at(Vector3(0, .5, 0))
	camera.make_current()
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("/tmp/act3-flight-study.png")
	print("FLIGHT_STUDY triangles=", item.mesh.get_faces().size() / 3, " capture=", error)
	quit(0 if error == OK else 1)
