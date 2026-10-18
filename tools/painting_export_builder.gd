@tool
extends RefCounted
## Export inputs are already alpha-border processed by the normal importer.
## Never resize, reimport, alpha-fix or grade a cropped page.

const Painting = preload("res://presentation/stage/paged_painting_texture.gd")
const INPUTS: String = "res://tools/painting_upload_inputs.json"
const ROOT: String = "res://_paged_paintings/"
const LIMIT: int = 4 * 1024 * 1024


static func rows() -> Array[Dictionary]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INPUTS))
	var out: Array[Dictionary] = []
	if not parsed is Array:
		return out
	for row: Variant in parsed:
		if not row is Dictionary:
			return []
		out.append(row)
	return out


static func sha(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func rgba_sha(image: Image) -> String:
	var copy: Image = image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	return sha(copy.get_data())


static func output_path(path: String) -> String:
	return ROOT + path.trim_prefix("res://assets/art/").trim_suffix(".png") + ".res"


static func texture_for(path: String) -> Texture2D:
	var failures: Array[String] = []
	for row: Dictionary in rows():
		if row["path"] == path:
			return build(row, failures)
	return null


static func build(row: Dictionary, failures: Array[String]) -> Texture2D:
	var path: String = row["path"]
	if FileAccess.get_sha256(path) != row["source_sha256"] or FileAccess.get_sha256(path + ".import") != row["import_sha256"]:
		failures.append(path + ": original source/import hash differs")
		return null
	var original: Texture2D = ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if original == null:
		failures.append(path + ": original import cannot load")
		return null
	var image: Image = original.get_image()
	var width: int = row["width"]
	var height: int = row["height"]
	if image == null or image.get_size() != Vector2i(width, height) or image.has_mipmaps() or image.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		failures.append(path + ": unsupported imported image")
		return null
	if rgba_sha(image) != row["rgba_sha256"]:
		failures.append(path + ": imported pixels differ")
		return null
	var painting: Painting = Painting.new()
	painting.resource_scene_unique_id = "painting"
	painting.image_size = image.get_size()
	painting.image_alpha = row["alpha"]
	var split: int = height / 2
	for region: Rect2i in [Rect2i(0, 0, width, split + 1), Rect2i(0, split - 1, width, height - split + 1)]:
		var page: Image = image.get_region(region)
		if not leaf_error(page).is_empty():
			failures.append(path + ": " + leaf_error(page))
			return null
		var leaf: ImageTexture = ImageTexture.create_from_image(page)
		leaf.resource_scene_unique_id = "page_%d" % painting.pages.size()
		leaf.get_image().resource_scene_unique_id = "pixels_%d" % painting.pages.size()
		painting.pages.append(leaf)
	return painting


static func leaf_error(image: Image) -> String:
	if image == null or image.is_empty() or image.has_mipmaps() or image.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		return "invalid physical leaf image"
	var bytes: int = maxi(image.get_data_size(), image.get_width() * image.get_height() * 4)
	return "physical leaf exceeds 4 MiB (%d bytes)" % bytes if bytes > LIMIT else ""


static func save(row: Dictionary, directory: String, failures: Array[String]) -> Dictionary:
	var texture: Texture2D = build(row, failures)
	if texture == null:
		return {}
	var logical: String = row["path"]
	var virtual: String = output_path(logical)
	var file: String = directory.path_join(logical.get_file().trim_suffix(".png") + ".res")
	if ResourceSaver.save(texture, file) != OK:
		failures.append(logical + ": failed resource serialization")
		return {}
	var uid: int = virtual.sha256_text().substr(0, 15).hex_to_int()
	if ResourceSaver.set_uid(file, uid) != OK:
		failures.append(logical + ": failed deterministic resource UID")
		return {}
	var saved: Texture2D = ResourceLoader.load(file, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if saved == null:
		failures.append(logical + ": serialized texture cannot reopen")
		return {}
	var pages: Array = saved.get("pages")
	if pages.size() != 2:
		failures.append(logical + ": serialized leaf count differs")
		return {}
	for index: int in range(2):
		var leaf: Texture2D = pages[index]
		var expected: Texture2D = texture.get("pages")[index]
		if not leaf_error(leaf.get_image()).is_empty() or leaf.get_image().get_data() != expected.get_image().get_data():
			failures.append(logical + ": serialized physical image differs")
			return {}
	for dependency: String in ResourceLoader.get_dependencies(file):
		if not dependency.ends_with("res://presentation/stage/paged_painting_texture.gd"):
			failures.append(logical + ": unexpected resource dependency " + dependency)
			return {}
	return {"logical": logical, "path": virtual, "bytes": FileAccess.get_file_as_bytes(file)}
