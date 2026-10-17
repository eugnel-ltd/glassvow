# Compare the old crouch on both exact skeletons. Only mesh segmentation and joint coverage differ.
# Godot --path godot-inspect --script this.gd -- output-dir old.glb new.glb
extends SceneTree

func _init() -> void:
	call_deferred("capture")

func bounds_of(actor: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var posed := mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		var current := mesh.global_transform * posed.get_aabb()
		box = current if first else box.merge(current)
		first = false
	return box

func floor_summary(actor: Node3D, rig: Skeleton3D) -> Dictionary:
	var minimum := {"all": INF, "Finial": INF, "front_ornament_region": INF, "LeftLowerArm": INF, "RightLowerArm": INF, "LeftFoot": INF, "RightFoot": INF, "Chest": INF}
	for node in actor.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var baked := instance.bake_mesh_from_current_skeleton_pose() if instance.skin != null else instance.mesh
		for surface in instance.mesh.get_surface_count():
			var original := instance.mesh.surface_get_arrays(surface)
			var posed := baked.surface_get_arrays(surface)
			var vertices: PackedVector3Array = posed[Mesh.ARRAY_VERTEX]
			var rest: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = original[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = original[Mesh.ARRAY_BONES]
			assert(vertices.size() == rest.size())
			var per := int(weights.size() / vertices.size())
			for i in vertices.size():
				var height := (instance.global_transform * vertices[i]).y
				minimum["all"] = minf(minimum["all"],height)
				for slot in per:
					if weights[i*per+slot] < .5:
						continue
					var bind := bones[i*per+slot]
					var bone_name := str(instance.skin.get_bind_name(bind))
					if bone_name.is_empty():
						bone_name = str(rig.get_bone_name(instance.skin.get_bind_bone(bind)))
					if minimum.has(bone_name):
						minimum[bone_name] = minf(minimum[bone_name],height)
					# A broad rest region includes the protruding pale front ornament.
					if bone_name == "Chest" and rest[i].z > .35 and rest[i].y > 1.15:
						minimum["front_ornament_region"] = minf(minimum["front_ornament_region"],height)
	return minimum

func capture() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(OS.get_user_data_dir().ends_with("/glassvow-asset-manager-inspect"))
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3 and not DirAccess.dir_exists_absolute(args[0]))
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.18,.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.82,.86,1)
	env.environment.ambient_light_energy = .7
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	light.light_energy = 1.5
	stage.add_child(light)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(100,100)
	plane.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.25,.27,.31)
	plane.material_override = mat
	stage.add_child(plane)
	var actors: Array[Node3D] = []
	var rigs: Array[Skeleton3D] = []
	for i in range(1,3):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(args[i],state) == OK)
		var actor := doc.generate_scene(state) as Node3D
		stage.add_child(actor)
		actors.append(actor)
		var player := actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("death")
		player.seek(player.get_animation("death").length,true)
		player.advance(0)
		player.stop(true)
		rigs.append(actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D)
	await process_frame
	await RenderingServer.frame_post_draw
	print("EXPORTED SPENT FLOOR ",JSON.stringify(floor_summary(actors[1],rigs[1])))
	# Match local poses only after proving identical hierarchy and rest transforms.
	var rest_error := 0.0
	for i in rigs[0].get_bone_count():
		var j := rigs[1].find_bone(rigs[0].get_bone_name(i))
		assert(j >= 0)
		var p0 := rigs[0].get_bone_parent(i)
		var p1 := rigs[1].get_bone_parent(j)
		assert((p0 < 0 and p1 < 0) or (p0 >= 0 and p1 >= 0 and rigs[0].get_bone_name(p0) == rigs[1].get_bone_name(p1)))
		var a := rigs[0].get_bone_rest(i)
		var b := rigs[1].get_bone_rest(j)
		rest_error = maxf(rest_error,a.origin.distance_to(b.origin))
		rest_error = maxf(rest_error,a.basis.x.distance_to(b.basis.x))
		rest_error = maxf(rest_error,a.basis.y.distance_to(b.basis.y))
		rest_error = maxf(rest_error,a.basis.z.distance_to(b.basis.z))
	print("CROUCH REST MAX ERROR ",rest_error)
	assert(rest_error < .00001)
	var error := 0.0
	for i in rigs[0].get_bone_count():
		var j := rigs[1].find_bone(rigs[0].get_bone_name(i))
		assert(j >= 0)
		var pose := rigs[0].get_bone_pose(i)
		rigs[1].set_bone_pose(j,pose)
		error += pose.origin.distance_to(rigs[1].get_bone_pose(j).origin)
		error += pose.basis.get_rotation_quaternion().angle_to(rigs[1].get_bone_pose(j).basis.get_rotation_quaternion())
	print("EXACT CROUCH POSE ERROR ",error)
	assert(error < .00001)
	await process_frame
	await RenderingServer.frame_post_draw
	var bounds := bounds_of(actors[0]).merge(bounds_of(actors[1]))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.position = bounds.get_center() + Vector3(3.6,.9,0).normalized()*10
	camera.look_at(bounds.get_center(),Vector3.UP)
	camera.size = bounds.size.length()*1.06
	camera.make_current()
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var caption := Label.new()
	caption.position = Vector2(16,12)
	caption.add_theme_font_size_override("font_size",20)
	canvas.add_child(caption)
	assert(DirAccess.make_dir_recursive_absolute(args[0]) == OK)
	for i in range(2):
		actors[0].visible = i == 0
		actors[1].visible = i == 1
		caption.text = "Planar joints" if i == 0 else "Coaxial stone cuff / socket"
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(args[0].path_join("crouch-%s.png" % i)) == OK)
	print("EXACT CROUCH DONE")
	quit()
