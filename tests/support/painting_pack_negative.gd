extends SceneTree
const Builder = preload("res://tools/painting_export_builder.gd")


func _initialize() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	for kind: String in ["oversized", "missing-page", "broken-gutter"]:
		var errors: Array[String] = []
		var texture: Texture2D = Builder.build(Builder.rows()[0], errors)
		if texture == null or not errors.is_empty():
			quit(2)
			return
		var pages: Array = texture.get("pages")
		if kind == "oversized":
			var image: Image = Image.create_empty(1536, 1024, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.3, 0.6, 0.9, 0.7))
			pages[0] = ImageTexture.create_from_image(image)
		elif kind == "missing-page":
			pages.pop_back()
		else:
			var leaf: Texture2D = pages[0]
			var image: Image = leaf.get_image()
			image.set_pixel(0, image.get_height() - 1, Color.MAGENTA)
			pages[0] = ImageTexture.create_from_image(image)
		texture.set("pages", pages)
		if ResourceSaver.save(texture, output.path_join(kind + ".res")) != OK:
			quit(2)
			return
	print("PAINTING_NEGATIVE_RESOURCES_READY")
	quit(0)
