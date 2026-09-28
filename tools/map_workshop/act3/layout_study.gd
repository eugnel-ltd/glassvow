extends SceneTree
## Private generated-layout greybox: no chapter art acceptance implied.
const M = preload("res://tools/map_workshop/mesh_tools.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sample_path: String = ""
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="):
			sample_path = arg.trim_prefix("--sample=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(sample_path))
	if not raw is Dictionary or raw.get("compiler_hard_pass") != true or output.is_empty():
		push_error("Layout greybox requires a passing generated sample and output")
		quit(1)
		return
	var sample: Dictionary = raw
	root.content_scale_size = Vector2i(1458, 820)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1458, 820)
	DisplayServer.window_set_size(root.size)
	root.msaa_3d = Viewport.MSAA_4X
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("13121a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d2cce5")
	environment.environment.ambient_light_energy = .65
	world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var paving: StandardMaterial3D = StandardMaterial3D.new()
	paving.albedo_color = Color("8c859b")
	paving.roughness = .8
	var marker: StandardMaterial3D = StandardMaterial3D.new()
	marker.albedo_color = Color("cfc1dd")
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Dictionary = sample["edges"]
	for edge: Dictionary in edges.values():
		var line: Array = edge["centerline"]
		var half_width: float = MapLayoutCanonical.float_value(edge["corridor_width"]) * .5
		for index: int in range(line.size() - 1):
			var a: Vector3 = _point(line[index])
			var b: Vector3 = _point(line[index + 1])
			var side: Vector3 = Vector3(b.x - a.x, 0, b.z - a.z).normalized().cross(Vector3.UP) * half_width
			M.triangle(surface, a - side, b - side, b + side)
			M.triangle(surface, a - side, b + side, a + side)
	M.node(world, M.finish(surface), paving, "GeneratedRouteGreybox")
	var anchors: Dictionary = sample["anchors"]
	for node_id: String in anchors:
		var node: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 1.45
		mesh.bottom_radius = 1.45
		mesh.height = .2
		mesh.radial_segments = 12
		node.mesh = mesh
		node.position = _point(anchors[node_id]) + Vector3(0, .1, 0)
		node.material_override = marker
		world.add_child(node)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 108
	camera.far = 500
	camera.position = Vector3(5, 130, 155)
	camera.look_at(Vector3(5, 0, 0))
	camera.make_current()
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(output)
	print("SPATIAL_GREYBOX nodes=", anchors.size(), " edges=", edges.size(), " capture=", result)
	quit(0 if result == OK else 1)

func _point(value: Variant) -> Vector3:
	var coordinates: Array = value
	return M.v3(coordinates)
