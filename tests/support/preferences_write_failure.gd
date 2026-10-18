extends SceneTree
## Its caller seeded a valid scratch settings file before setting RLIMIT_FSIZE
## to zero. A normal setter must leave those accepted bytes intact.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].get_file().begins_with("test_preferences_atomic_"):
		print("preferences write failure: missing scratch settings path")
		quit(2)
		return
	var path: String = args[0]
	var fails: Array[String] = []
	var accepted: String = FileAccess.get_file_as_string(path)
	var probe: FileAccess = FileAccess.open(path + ".probe", FileAccess.WRITE)
	if probe == null:
		fails.append("could not open write-error control")
	else:
		probe.store_string("x".repeat(65536))
		probe.flush()
		if probe.get_error() == OK:
			fails.append("file-size limit did not cause a real write error")
		probe.close()
	# Small buffered writes expose a flush-only failure for which Godot 4.7.2
	# leaves get_error() at OK; checking that field alone would accept it.
	var json_path: String = path + ".json"
	var accepted_json: String = FileAccess.get_file_as_string(json_path)
	if SaveService._store_json_atomic(json_path, {"accepted": false}):
		fails.append("buffered JSON flush failure reported success")
	if FileAccess.get_file_as_string(json_path) != accepted_json:
		fails.append("buffered JSON flush failure replaced accepted bytes")
	if FileAccess.file_exists(json_path + ".tmp"):
		fails.append("buffered JSON flush failure left its temporary file")
	var preferences: Preferences = Preferences.read_from_disk(path, path + ".legacy")
	preferences.set_screen_shake(false)
	if preferences.screen_shake:
		fails.append("setter did not update the in-memory choice")
	if FileAccess.get_file_as_string(path) != accepted:
		fails.append("failed setter replaced accepted settings")
	if Preferences.read_diagnostics_enabled(path):
		fails.append("failed setter re-enabled diagnostics")
	if FileAccess.file_exists(path + ".tmp"):
		fails.append("failed setter left its temporary file")
	if fails.is_empty():
		print("preferences write failure: PASS")
		quit(0)
	else:
		for failure: String in fails:
			print("preferences write failure: FAIL: ", failure)
		quit(1)
