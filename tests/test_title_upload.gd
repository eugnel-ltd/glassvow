extends RefCounted
## The live title painting preserves its source while each real texture upload
## stays below 4 MiB, including the renderer's possible RGB8 -> RGBA8 expansion.

const SOURCE: String = "res://assets/art/title-background/background.png"
const SOURCE_SHA: String = "2e06a05a294b277d0a9736aeece6971282d501859276a314a20162b6645ade5d"
const LIMIT: int = 4 * 1024 * 1024


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_title_upload: %s" % what)


static func run(fails: Array[String]) -> void:
	var painting: Texture2D = load(TitleScreen.TITLE_BACKGROUND) as Texture2D
	_check(fails, painting != null, "the live title painting loads as Texture2D")
	if painting == null:
		return
	_check(fails, painting.get_size() == Vector2(1536, 1024), "full source resolution remains 1536 x 1024")
	var pages: Array[Texture2D] = [painting]
	for property: Dictionary in painting.get_property_list():
		if str(property.get("name", "")) == "pages":
			pages.clear()
			var actual: Array = painting.get("pages")
			for page: Texture2D in actual:
				pages.append(page)
	var images: Array[Image] = []
	for page: Texture2D in pages:
		var image: Image = page.get_image()
		_check(fails, image != null, "each live upload has readable pixels")
		if image == null:
			continue
		images.append(image)
		var payload: int = maxi(image.get_data_size(), image.get_width() * image.get_height() * 4)
		_check(fails, payload <= LIMIT,
			"live title painting upload is <= 4 MiB even if RGB8 expands to RGBA8 (%d bytes)" % payload)
		_check(fails, not image.has_mipmaps(), "source filtering keeps its original no-mipmap import")
	_check(fails, pages.size() == 2 and images.size() == 2, "two independent bounded uploads carry the painting")
	if images.size() == 2:
		_pixels(fails, images)
	_check(fails, FileAccess.get_sha256(SOURCE) == SOURCE_SHA, "original source file bytes remain unchanged")
	var original: Resource = load(SOURCE)
	_check(fails, original is CompressedTexture2D, "the original source retains its Texture2D resource type")
	_exports(fails)
	var guard: Script = load("res://tests/test_texture_uploads.gd") as Script
	var before: Dictionary = guard.get_script_constant_map().get("BEFORE", {})
	_check(fails, not before.has(SOURCE.trim_prefix("res://")), "the title no longer has an oversized-upload exception")


static func _pixels(fails: Array[String], images: Array[Image]) -> void:
	var source: Image = Image.load_from_file(SOURCE)
	var rebuilt: Image = Image.create(1536, 1024, false, Image.FORMAT_RGB8)
	for index: int in range(2):
		var image: Image = images[index]
		_check(fails, image.get_size() == Vector2i(1536, 513) and image.get_format() == Image.FORMAT_RGB8,
			"each lossless RGB page has its original-neighbor gutter")
		if image.get_size() != Vector2i(1536, 513) or image.get_format() != Image.FORMAT_RGB8:
			return
		rebuilt.blit_rect(image, Rect2i(0, index, 1536, 512), Vector2i(0, index * 512))
	_check(fails, rebuilt.get_data() == source.get_data(), "page ownership reconstructs every original source pixel exactly")
	_check(fails, images[0].get_region(Rect2i(0, 512, 1536, 1)).get_data()
		== source.get_region(Rect2i(0, 512, 1536, 1)).get_data(), "top page's linear filter reads original row 512")
	_check(fails, images[1].get_region(Rect2i(0, 0, 1536, 1)).get_data()
		== source.get_region(Rect2i(0, 511, 1536, 1)).get_data(), "bottom page's linear filter reads original row 511")


static func _exports(fails: Array[String]) -> void:
	var presets: ConfigFile = ConfigFile.new()
	_check(fails, presets.load("res://export_presets.cfg") == OK, "export presets can be read")
	for section: String in presets.get_sections():
		if section.count(".") != 1:
			continue
		var excluded: PackedStringArray = str(presets.get_value(section, "exclude_filter", "")).split(",")
		_check(fails, excluded.has(SOURCE.trim_prefix("res://")),
			"%s ships the bounded pages instead of the unused original import" % str(presets.get_value(section, "name", "")))
