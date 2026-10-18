extends RefCounted
## Real imported paintings must ship as bounded physical uploads, with unchanged pixels.
## The dynamic adapter lets this exact fixture exercise the old supported API first.

const LIMIT: int = 4 * 1024 * 1024
const BUILDER: String = "res://tools/painting_export_builder.gd"
const INPUTS: Array[Dictionary] = [
	{"path": "res://assets/art/scenes/act4-node1.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "720f19af0ec8c03a4c7be3fdeac037713d29fb42acc55d13773cd987febcca3f"},
	{"path": "res://assets/art/scenes/act4-node2.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "c85c7a198d1b9b2b2bf93dd7fbaa9205654e5c3219d5180ddae441ec398cf4b5"},
	{"path": "res://assets/art/scenes/act4-node3.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "ee3174d03bad900281d2d6118f4b5f5d88d63b239156860163268ec438e01f90"},
	{"path": "res://assets/art/scenes/act4-node4.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "36abd634a334f7f1326a62f7a779d9e11672d25698bc2f095691081a6347d10a"},
	{"path": "res://assets/art/scenes/act4-node5.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "1ccd48a13c3c5e7efc83fc663a99eba06d530317143126a5f3c7392c8c99bd69"},
	{"path": "res://assets/art/scenes/finale-swap.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "7ddb827b247b6598dd5a2665a007e40c7cfc55b6d09c44fbc3787364f23d0f5f"},
	{"path": "res://assets/art/scenes/night-stall.png", "width": 1512, "height": 1040, "alpha": false, "rgba_sha256": "f48711f9a690ac8735e5241a251e005b17a4e045f032497d6de86510c5b10d7f"},
	{"path": "res://assets/art/scenes/opening-hearth.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "553ddc20b4d6ea839d1a2fdf81be746a3ee06febc0c04613ea170e921af4f8ae"},
	{"path": "res://assets/art/scenes/unsealing-door-open.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "cb79ace851a47aeb0bbd1c03ba0cb0cc33b825c6bdded080c38bd81ebbc77fc5"},
	{"path": "res://assets/art/scenes/unsealing-mirror-queue.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "0133fe4309583eb73af672403b68cf80b2cfa38162b959b62b77c17fcac7484e"},
	{"path": "res://assets/art/scenes/unsealing-monuments-push.png", "width": 1536, "height": 1024, "alpha": false, "rgba_sha256": "8cc9f87c83cf4426de9558f2528b69a5a93d9d87d6f9283b8f40137811aa059b"},
	{"path": "res://assets/art/stage/act1-backdrop.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "434e4ee78a2293c259d689251ada6114a99d1a6a8811c937df093edb88391a51"},
	{"path": "res://assets/art/stage/act1-mid.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "775a3d2c579b129f2a8db3b12f5cf4636461f7375b2d53a071895372adc1fd73"},
	{"path": "res://assets/art/stage/act1-ledge.png", "width": 1536, "height": 761, "alpha": true, "rgba_sha256": "db66eeb61af6a98273e8ef8a106ffc7e79a4239d94c5c8cbce3ed152c09ef57a"},
	{"path": "res://assets/art/stage/act2-backdrop.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "d8ee29f05446928188a93fc671d03a3ba75a63836724a016cde6bd7aaf8f8506"},
	{"path": "res://assets/art/stage/act2-mid.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "3a40b37783f146c753848d4adabc13bcf35d87f8886aeaf56279a186d52c360b"},
	{"path": "res://assets/art/stage/act3-backdrop.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "df97c164eeb07dfdd316dd96cc67b37f4e54b45486533f0ed658d4652b5b72dd"},
	{"path": "res://assets/art/stage/act3-mid.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "5ae9457eb189af244caeb33102ba0295024bd6cab5ad995afdcb8ecfa492f106"},
	{"path": "res://assets/art/stage/act4-backdrop.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "ef3e4d05c79f7b0732cbd4bbd8ad7b3c22d6611e62d167ab131f033e9d7d015c"},
	{"path": "res://assets/art/stage/act4-mid.png", "width": 1536, "height": 1024, "alpha": true, "rgba_sha256": "42a065d74d20b821444e682a660c0141d6ed7699e820df093272cf605a692c74"},
	{"path": "res://assets/art/stage/act4-ledge.png", "width": 1536, "height": 789, "alpha": true, "rgba_sha256": "ef8fc530e899e521c68873cb04138603f416679bb484cc6d8db601f9c56bfe3b"},
]


static func _check(fails: Array[String], condition: bool, what: String) -> void:
	if not condition:
		fails.append("test_painting_upload_pages: " + what)


static func _sha(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func run(fails: Array[String]) -> void:
	for row: Dictionary in INPUTS:
		var path: String = row["path"]
		var texture: Texture2D = load(path) as Texture2D
		if FileAccess.file_exists(BUILDER):
			var builder: GDScript = load(BUILDER) as GDScript
			if builder != null and builder.has_method("texture_for"):
				var candidate: Variant = builder.call("texture_for", path)
				if candidate is Texture2D:
					texture = candidate
		audit_texture(fails, row, texture, false)


static func audit_texture(fails: Array[String], row: Dictionary, texture: Texture2D, identity: bool) -> void:
	var path: String = row["path"]
	_check(fails, texture != null, path + " loads as Texture2D")
	if texture == null:
		return
	var width: int = row["width"]
	var height: int = row["height"]
	_check(fails, texture.get_size() == Vector2(width, height), path + " preserves full dimensions")
	var expected_alpha: bool = row["alpha"]
	_check(fails, texture.has_alpha() == expected_alpha, path + " preserves alpha contract")
	if identity:
		_check(fails, ResourceLoader.exists(path) and texture.resource_path == path, path + " keeps exists and original resource_path")
	var pages: Array[Texture2D] = []
	for property: Dictionary in texture.get_property_list():
		if property["name"] == "pages":
			var values: Array = texture.get("pages")
			pages.assign(values)
	if pages.is_empty():
		pages.append(texture)
	var result: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var split: int = height / 2
	_check(fails, pages.size() == 2, path + " has exactly two physical leaves")
	for index: int in range(pages.size()):
		var image: Image = pages[index].get_image()
		_check(fails, image != null and not image.is_empty(), path + " has readable physical image")
		if image == null or image.is_empty():
			continue
		var conservative: int = maxi(image.get_data_size(), image.get_width() * image.get_height() * 4)
		_check(fails, conservative <= LIMIT, "%s physical leaf %d uploads %d bytes, limit %d" % [path, index, conservative, LIMIT])
		_check(fails, not image.has_mipmaps() and image.get_format() in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8], path + " keeps RGB/RGBA without mipmaps")
		image.convert(Image.FORMAT_RGBA8)
		if pages.size() == 1:
			result = image
		elif pages.size() == 2:
			var expected_height: int = split + 1 if index == 0 else height - split + 1
			_check(fails, image.get_size() == Vector2i(width, expected_height), path + " has exact neighbour-page dimensions")
			var begin: int = 0 if index == 0 else 1
			var owned_height: int = split if index == 0 else height - split
			result.blit_rect(image, Rect2i(0, begin, width, owned_height), Vector2i(0, 0 if index == 0 else split))
	_check(fails, _sha(result.get_data()) == str(row["rgba_sha256"]), path + " reconstructs every imported RGBA byte")
	if pages.size() == 2:
		var top: Image = pages[0].get_image()
		var bottom: Image = pages[1].get_image()
		top.convert(Image.FORMAT_RGBA8)
		bottom.convert(Image.FORMAT_RGBA8)
		_check(fails, top.get_region(Rect2i(0, split, width, 1)).get_data() == result.get_region(Rect2i(0, split, width, 1)).get_data(), path + " top filter row matches original")
		_check(fails, bottom.get_region(Rect2i(0, 0, width, 1)).get_data() == result.get_region(Rect2i(0, split - 1, width, 1)).get_data(), path + " bottom filter row matches original")
