extends SceneTree
## Import the current Blender candidate directly, then inspect multiple native views.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.content_scale_size = Vector2i(1458, 820)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1458, 820)
	root.msaa_3d = Viewport.MSAA_4X
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17141f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8b0d0")
	environment.environment.ambient_light_energy = .6
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.7
	sun.light_color = Color("d6cceb")
	sun.shadow_enabled = true
	world.add_child(sun)
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file(
		"res://tools/map_workshop/act3/kit/obsidian-great-hall.glb", state)
	if error != OK:
		quit(1)
		return
	var hall: Node3D = document.generate_scene(state)
	world.add_child(hall)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.far = 300
	camera.make_current()
	var views: Dictionary = {"quarter": Vector3(34, 28, 42), "front": Vector3(0, 20, 48),
		"roof": Vector3(24, 47, 32)}
	for name: String in views:
		camera.position = views[name]
		camera.look_at(Vector3(0, 9, 0))
		for frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png("/tmp/act3-hall-" + name + ".png")
		if error != OK:
			quit(1)
			return
	print("PRECINCT_KIT_NATIVE_CAPTURE three views, one assembly")
	quit()
