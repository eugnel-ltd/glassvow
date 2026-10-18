extends SceneTree
## Immutable baseline control: use the actual native PNG loader, before tiling.
## A failure is expected on the unchanged source image; this is not GPU proof.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("baseline_upload: expected the original PNG path")
		quit(2)
		return
	var image: Image = Image.load_from_file(args[0])
	if image == null or image.is_empty():
		printerr("baseline_upload: native ImageLoader failed")
		quit(2)
		return
	var bytes: int = image.get_data_size()
	print("BASELINE_NATIVE_PNG width=%d height=%d format=%d bytes=%d" % [
		image.get_width(), image.get_height(), image.get_format(), bytes])
	if bytes > 4 * 1024 * 1024:
		printerr("FAIL baseline_native_boot_upload: original decoded image exceeds 4 MiB")
		quit(1)
		return
	printerr("baseline_upload: expected the real oversized baseline")
	quit(2)
