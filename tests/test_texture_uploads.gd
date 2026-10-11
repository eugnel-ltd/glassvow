extends RefCounted
## No texture the store builds ship uploads more than 4 MiB at once (R3.3,
## issue #660). A RenderingDevice transfer worker's staging buffer grows to the
## next power of two above the largest single upload it has made and is never
## shrunk, so one upload over 4 MiB holds 8 MiB or more of device memory that
## Godot does not account, for the life of the process: the woodland atlas at
## 4.63 MiB cost the iPad 8 about 16 MiB that way. The engine uploads a texture
## a layer at a time, each layer with its whole mip chain, so a layer of an
## array counts alone.
##
## Reads every imported texture the iOS preset (the floor device's) packs: its
## header and each layer's image block, sized as the engine uploads it.
##
## `BEFORE` holds the textures that already uploaded more when this guard
## landed: 2D art imported lossless (the boot splash, the title's background,
## the scenes and the combat stages). Each is held at its upload, so none may
## grow and nothing may join them; bringing them under 4 MiB is a follow-up.

const LIMIT_BYTES: int = 4 * 1024 * 1024
const PRESET: String = "iOS"
## The texture variants the iOS export keeps (`tools/payload_report.py`).
const FEATURES: PackedStringArray = ["etc2", "astc"]
## Folders an export never packs (`tools/payload_report.py`).
const UNPACKED_DIRS: PackedStringArray = [".godot", ".git", ".github", ".claude", "build",
	"export", "artifacts"]
## The compressed texture files' image blocks (`CompressedTexture2D`).
const DATA_FORMAT_IMAGE: int = 0
const DATA_FORMAT_PNG: int = 1
const DATA_FORMAT_WEBP: int = 2
## Uploads over 4 MiB when this guard landed (R3.3, 10 Oct 2026), in bytes.
const BEFORE: Dictionary = {
	"assets/art/title/splash.png": 11611200,
	"assets/art/title-background/background.png": 4718592,
	"assets/art/scenes/act4-node1.png": 4718592,
	"assets/art/scenes/act4-node2.png": 4718592,
	"assets/art/scenes/act4-node3.png": 4718592,
	"assets/art/scenes/act4-node4.png": 4718592,
	"assets/art/scenes/act4-node5.png": 4718592,
	"assets/art/scenes/finale-swap.png": 4718592,
	"assets/art/scenes/night-stall.png": 4718592,
	"assets/art/scenes/opening-hearth.png": 4718592,
	"assets/art/scenes/unsealing-door-open.png": 4718592,
	"assets/art/scenes/unsealing-mirror-queue.png": 4718592,
	"assets/art/scenes/unsealing-monuments-push.png": 4718592,
	"assets/art/stage/act1-backdrop.png": 6291456,
	"assets/art/stage/act1-mid.png": 6291456,
	"assets/art/stage/act1-ledge.png": 4675584,
	"assets/art/stage/act2-backdrop.png": 6291456,
	"assets/art/stage/act2-mid.png": 6291456,
	"assets/art/stage/act3-backdrop.png": 6291456,
	"assets/art/stage/act3-mid.png": 6291456,
	"assets/art/stage/act4-backdrop.png": 6291456,
	"assets/art/stage/act4-mid.png": 6291456,
	"assets/art/stage/act4-ledge.png": 4847616,
}
## The woodland's impostor atlas, which must be among what is read.
const ATLAS: String = "assets/art/map-journey/impostors/wood-albedo.png"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_texture_uploads: %s" % what)


static func run(fails: Array[String]) -> void:
	var excluded: PackedStringArray = _exclusions()
	_check(fails, not excluded.is_empty(), "the %s preset's exclusions are read" % PRESET)
	var imports: PackedStringArray = []
	_walk("res://", imports)
	var read: int = 0
	var problems: PackedStringArray = []
	var over: PackedStringArray = []
	var atlas_read: bool = false
	for import_path: String in imports:
		var source: String = import_path.trim_prefix("res://").trim_suffix(".import")
		if _matches(source, excluded):
			continue
		for artefact: String in _artefacts(import_path):
			var layers: PackedInt64Array = layer_bytes(artefact)
			if layers.is_empty():
				problems.append("%s (%s)" % [source, artefact.get_file()])
				continue
			read += 1
			atlas_read = atlas_read or source == ATLAS
			var before: int = BEFORE.get(source, 0)
			var limit: int = maxi(LIMIT_BYTES, before)
			for i: int in range(layers.size()):
				if layers[i] > limit:
					over.append("%s layer %d: %.2f MiB (%s)" % [source, i, layers[i] / 1048576.0,
						artefact.get_extension()])
	_check(fails, read > 100 and atlas_read,
		"every shipped texture is read, the woodland atlas among them (%d read)" % read)
	_check(fails, problems.is_empty(), "every shipped texture's file can be sized: %s" % ", ".join(problems))
	_check(fails, over.is_empty(),
		"no shipped texture uploads more than 4 MiB at once, or more than it did before this guard: %s" % ", ".join(over))


## The bytes each layer of a compressed texture file uploads (its mip chain
## included), or nothing if the file cannot be read.
static func layer_bytes(path: String) -> PackedInt64Array:
	var out: PackedInt64Array = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var magic: String = file.get_buffer(4).get_string_from_ascii()
	var layers: int = 1
	if magic == "GST2":
		# Version, width, height, flags, mipmap limit and three reserved words.
		file.seek(file.get_position() + 32)
	elif magic == "GSTL":
		file.get_32()
		layers = file.get_32()
		# Type, flags, mipmap limit and three reserved words.
		file.seek(file.get_position() + 24)
	else:
		return out
	for i: int in range(layers):
		var size: int = _image_bytes(file)
		if size <= 0:
			return PackedInt64Array()
		out.append(size)
	return out


## Reads one image block and answers what it uploads: its width, height and
## format with its mip chain, whether stored raw or as PNG or WebP.
static func _image_bytes(file: FileAccess) -> int:
	var data_format: int = file.get_32()
	var w: int = file.get_16()
	var h: int = file.get_16()
	var mipmaps: int = file.get_32()
	var format: int = file.get_32()
	if file.eof_reached() or w <= 0 or h <= 0 or format < 0 or format >= Image.FORMAT_MAX:
		return 0
	var bytes: int = Image.create_empty(w, h, mipmaps > 0, format).get_data_size()
	if data_format == DATA_FORMAT_IMAGE:
		file.seek(file.get_position() + bytes)
	elif data_format == DATA_FORMAT_PNG or data_format == DATA_FORMAT_WEBP:
		for level: int in range(mipmaps + 1):
			file.seek(file.get_position() + file.get_32())
	else:
		return 0
	return bytes


## The imported files the iOS export packs for one `.import` sidecar: its
## compressed textures, the platform's variants only.
static func _artefacts(import_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var sidecar: ConfigFile = ConfigFile.new()
	if sidecar.load(import_path) != OK or not sidecar.has_section("remap"):
		return out
	for key: String in sidecar.get_section_keys("remap"):
		if key != "path" and not (key.begins_with("path.") and FEATURES.has(key.get_slice(".", 1))):
			continue
		var artefact: String = str(sidecar.get_value("remap", key))
		if artefact.get_extension().begins_with("ctex"):
			out.append(artefact)
	return out


## The iOS preset's exclusion globs.
static func _exclusions() -> PackedStringArray:
	var presets: ConfigFile = ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		return PackedStringArray()
	for section: String in presets.get_sections():
		if section.count(".") == 1 and str(presets.get_value(section, "name", "")) == PRESET:
			var globs: PackedStringArray = []
			for glob: String in str(presets.get_value(section, "exclude_filter", "")).split(","):
				if not glob.strip_edges().is_empty():
					globs.append(glob.strip_edges())
			return globs
	return PackedStringArray()


static func _matches(path: String, globs: PackedStringArray) -> bool:
	for glob: String in globs:
		if path.match(glob):
			return true
	return false


## Every `.import` sidecar under `folder`, skipping hidden folders, those an
## export never packs and those a `.gdignore` hides.
static func _walk(folder: String, out: PackedStringArray) -> void:
	if FileAccess.file_exists(folder.path_join(".gdignore")):
		return
	for name: String in DirAccess.get_directories_at(folder):
		if name.begins_with(".") or (folder == "res://" and UNPACKED_DIRS.has(name)):
			continue
		_walk(folder.path_join(name), out)
	for name: String in DirAccess.get_files_at(folder):
		if name.ends_with(".import"):
			out.append(folder.path_join(name))
