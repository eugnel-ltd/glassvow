extends SceneTree
## Runs outside the source checkout against one cold --main-pack process.
## The first frozen regression and input manifest are EXTERNAL oracle inputs.

const PREFIX: String = "res://_paged_paintings/"
const SCRIPT: String = "res://presentation/stage/paged_painting_texture.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("painting pack audit requires external contract and input manifest")
		quit(2)
		return
	var contract: GDScript = ResourceLoader.load(args[0]) as GDScript
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if contract == null or not parsed is Array or parsed.size() != 21:
		printerr("painting pack audit: invalid external oracle")
		quit(2)
		return
	var constants: Dictionary = contract.get_script_constant_map()
	var expected: Array = constants["INPUTS"]
	var failures: Array[String] = []
	var expected_files: PackedStringArray = []
	for index: int in range(21):
		var row: Dictionary = parsed[index]
		var fixed: Dictionary = expected[index]
		var path: String = fixed["path"]
		for key: String in fixed:
			if row.get(key) != fixed[key]:
				failures.append(path + ": input manifest differs from frozen contract " + key)
		var virtual: String = PREFIX + path.trim_prefix("res://assets/art/").trim_suffix(".png") + ".res"
		expected_files.append(virtual)
		var remap: ConfigFile = ConfigFile.new()
		if remap.load(path + ".remap") != OK or remap.get_value("remap", "path", "") != virtual:
			failures.append(path + ": missing or wrong original-path remap")
		var old_artifact: String = row["artifact"]
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".import") or FileAccess.file_exists(old_artifact):
			failures.append(path + ": oversized source/import artifact remains packed")
		if not ResourceLoader.exists(path):
			failures.append(path + ": logical resource does not exist")
			continue
		var texture: Texture2D = ResourceLoader.load(path) as Texture2D
		if texture != null:
			var script: Script = texture.get_script()
			if script == null or script.resource_path != SCRIPT:
				failures.append(path + ": wrong runtime wrapper script")
		contract.call("audit_texture", failures, fixed, texture, true)
		var dependencies: PackedStringArray = ResourceLoader.get_dependencies(virtual)
		if dependencies.size() != 1 or not dependencies[0].ends_with(SCRIPT):
			failures.append(path + ": dependency closure differs: " + str(dependencies))
	var actual_files: PackedStringArray = []
	_walk(PREFIX, actual_files)
	expected_files.sort()
	actual_files.sort()
	if expected_files != actual_files:
		failures.append("generated namespace differs: expected %d, found %d files" % [expected_files.size(), actual_files.size()])
	if failures.is_empty():
		print("PAINTING_PACK_PASS logical=21 physical_leaves=42 limit=4194304")
		quit(0)
	else:
		for failure: String in failures:
			printerr("PAINTING_PACK_FAIL " + failure)
		quit(1)


func _walk(path: String, files: PackedStringArray) -> void:
	for name: String in DirAccess.get_files_at(path):
		files.append(path.path_join(name))
	for name: String in DirAccess.get_directories_at(path):
		_walk(path.path_join(name), files)
