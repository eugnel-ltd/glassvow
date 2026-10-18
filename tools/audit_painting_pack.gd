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
		if not _serialized_graph(virtual):
			failures.append(path + ": unexpected serialized texture resource graph")
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
			else:
				var pages: Array = texture.get("pages")
				for value: Variant in pages:
					if not value is ImageTexture:
						failures.append(path + ": physical leaf is not a native ImageTexture")
					elif value.get_script() != null:
						failures.append(path + ": physical leaf has an unexpected script")
				if pages.size() == 2 and pages[0] == pages[1]:
					failures.append(path + ": physical leaf references are not distinct")
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


## ResourceFormatBinary v6 (Godot 4.7.2): inspect every internal resource,
## including unused/orphan entries that a visible-pages traversal cannot see.
## The builder deliberately saves uncompressed resources with flags=0.
func _serialized_graph(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_buffer(4).get_string_from_ascii() != "RSRC":
		return false
	if file.get_32() != 0 or file.get_32() != 0:
		return false  # little endian; native single-precision build
	var major: int = file.get_32()
	var minor: int = file.get_32()
	if major != 4 or minor < 7 or file.get_32() != 6 or _resource_text(file) != "Texture2D":
		return false
	if file.get_64() != 0 or file.get_32() != 11:
		return false  # no import metadata; named IDs, UIDs and script class
	file.get_64()  # generated resource UID
	if _resource_text(file) != "PagedPaintingTexture":
		return false
	for _reserved: int in range(11):
		if file.get_32() != 0:
			return false
	var strings: int = file.get_32()
	if strings < 1 or strings > 64:
		return false
	for _index: int in range(strings):
		if _resource_text(file).is_empty():
			return false
	if file.get_32() != 1 or _resource_text(file) != "Script" or _resource_text(file) != SCRIPT:
		return false
	file.get_64()  # external script UID; original path remains the fallback
	if file.get_32() != 5:
		return false
	var offsets: PackedInt64Array = []
	var names: Dictionary = {}
	for _index: int in range(5):
		var name: String = _resource_text(file)
		var offset: int = file.get_64()
		if name.is_empty() or names.has(name) or offset <= 0 or offset >= file.get_length() or offsets.has(offset):
			return false
		names[name] = true
		offsets.append(offset)
	var classes: Dictionary = {}
	for offset: int in offsets:
		file.seek(offset)
		var kind: String = _resource_text(file)
		var count: int = classes.get(kind, 0)
		classes[kind] = count + 1
	var expected: Dictionary = {"Image": 2, "ImageTexture": 2, "Texture2D": 1}
	return classes == expected


func _resource_text(file: FileAccess) -> String:
	var length: int = file.get_32()
	if length < 1 or length > 1024 or length > file.get_length() - file.get_position():
		return ""
	var bytes: PackedByteArray = file.get_buffer(length)
	if bytes[-1] != 0:
		return ""
	return bytes.slice(0, length - 1).get_string_from_utf8()
