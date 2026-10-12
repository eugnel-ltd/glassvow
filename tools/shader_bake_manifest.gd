extends SceneTree
## The iOS shader bake's manifest (#682). Writes `OUT`, a scene that holds one
## material for every shader the game writes, so the export's shader baker
## finds them: it visits only the materials stored in exported scenes and
## resources (the editor's `ShaderBakerExportPlugin::_customize_resource` and
## `_customize_scene`), and this game builds every material in GDScript, so
## without a manifest it bakes none of the game's own shaders.
##
## Each material sits on a node the scene root owns: a MeshInstance3D's
## material_override for a spatial shader, a ColorRect's material for a
## canvas_item one. The baked cache key is the shader's generated source, so a
## manifest material bakes the very container a runtime material asks for.
##
## The scene is generated, never committed (.gitignore): the baked export
## (`tools/godot/bake_export.sh`, which both `scripts/ios_release.sh` and the
## QA export run) writes it just before it exports, so the string shaders'
## code is the code that ships. A shader missing here is not baked and
## compiles on the device at its first use, as every shader did before.
##
##   godot --headless --path <repo> -s res://tools/shader_bake_manifest.gd

const OUT: String = "res://tools/shader_bake_manifest.tscn"


func _init() -> void:
	var root: Node = Node.new()
	root.name = "ShaderBakeManifest"
	var spatial: int = 0
	var canvas: int = 0
	var listed: Array[Shader] = shaders()
	for i: int in range(listed.size()):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = listed[i]
		var node: Node = null
		if listed[i].get_mode() == Shader.MODE_SPATIAL:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.material_override = mat
			node = mesh
			spatial += 1
		else:
			var rect: ColorRect = ColorRect.new()
			rect.material = mat
			node = rect
			canvas += 1
		node.name = "M%02d" % i
		root.add_child(node)
		node.owner = root
	var scene: PackedScene = PackedScene.new()
	var err: int = scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, OUT)
	print("SHADER_BAKE_MANIFEST %s spatial=%d canvas=%d err=%d" % [OUT, spatial, canvas, err])
	root.free()
	quit(0 if err == OK else 1)


## Every shader the game writes: each `.gdshader` under presentation/, then
## each shader the GDScript builds from a string, with the code it builds.
static func shaders() -> Array[Shader]:
	var out: Array[Shader] = []
	for path: String in gdshaders("res://presentation"):
		out.append(load(path) as Shader)
	for code: String in string_shaders():
		var sh: Shader = Shader.new()
		sh.code = code
		out.append(sh)
	return out


## The code of each shader the GDScript builds from a string.
static func string_shaders() -> Array[String]:
	return [
		EnemyView.with_tint(EnemyView.with_erode(EnemyView.BODY_SHADER)),
		EnemyView.WARD_SHADER,
		EnemyView.with_tint(EnemyView.GLASS_SHADER),
		EnemyView.with_tint(EnemyView.with_erode(EnemyView.SHARD_SHADER)),
		EnemyView.RESEAM_SHADER,
		EnemyView.SHADOW_SHADER,
		EnemyView.FX_SHADER,
		CombatScreen.VIGNETTE_SHADER,
		CombatScreen.STAGE_DIM_SHADER,
		CombatScreen.GRAIN_SHADER,
		TransitionLayer.IRIS_SHADER,
		TransitionLayer.GRAIN_SHADER,
	]


static func gdshaders(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(gdshaders(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gdshader"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out
