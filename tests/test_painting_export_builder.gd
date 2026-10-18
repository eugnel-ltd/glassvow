extends RefCounted

const Builder = preload("res://tools/painting_export_builder.gd")
const Contract = preload("res://tests/test_painting_upload_pages.gd")


static func _check(fails: Array[String], condition: bool, what: String) -> void:
	if not condition:
		fails.append("test_painting_export_builder: " + what)


static func run(fails: Array[String]) -> void:
	var rows: Array[Dictionary] = Builder.rows()
	_check(fails, rows.size() == 21, "exactly 21 independent source inputs")
	var directory: String = OS.get_user_data_dir().path_join("painting-serialization")
	for suffix: String in ["a", "b"]:
		_check(fails, DirAccess.make_dir_recursive_absolute(directory.path_join(suffix)) == OK, "create isolated serialization directory")
	var outputs: Dictionary = {}
	for row: Dictionary in rows:
		var errors: Array[String] = []
		var a: Dictionary = Builder.save(row, directory.path_join("a"), errors)
		var b: Dictionary = Builder.save(row, directory.path_join("b"), errors)
		_check(fails, errors.is_empty() and not a.is_empty() and not b.is_empty(), "serialize/reopen " + str(row["path"]) + ": " + str(errors))
		if a.is_empty() or b.is_empty():
			continue
		var equal_bytes: bool = a["bytes"] == b["bytes"]
		_check(fails, equal_bytes, "deterministic binary resource bytes " + str(row["path"]))
		_check(fails, not outputs.has(a["path"]), "unique generated resource path")
		outputs[a["path"]] = true
	for key: String in ["source_sha256", "import_sha256", "rgba_sha256"]:
		var wrong: Dictionary = rows[0].duplicate(true)
		wrong[key] = "wrong"
		var errors: Array[String] = []
		_check(fails, Builder.build(wrong, errors) == null and not errors.is_empty(), "reject mismatched " + key)
	var full: Image = Image.create_empty(1536, 1024, false, Image.FORMAT_RGBA8)
	_check(fails, not Builder.leaf_error(full).is_empty(), "reject real full-resolution oversized RGBA leaf before texture creation")
	var errors: Array[String] = []
	var texture: Texture2D = Builder.build(rows[0], errors)
	var pages: Array = texture.get("pages")
	var first: Texture2D = pages[0]
	var changed: Image = first.get_image()
	changed.set_pixel(0, changed.get_height() - 1, Color.MAGENTA)
	pages[0] = ImageTexture.create_from_image(changed)
	texture.set("pages", pages)
	var negative: Array[String] = []
	Contract.audit_texture(negative, Contract.INPUTS[0], texture, false)
	_check(fails, not negative.is_empty(), "unchanged oracle detects a broken internal filter gutter")
	for suffix: String in ["a", "b"]:
		var folder: String = directory.path_join(suffix)
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(directory)
