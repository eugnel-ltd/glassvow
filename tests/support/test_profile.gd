class_name TestProfile
extends RefCounted
## Test support: keeps a suite off the player's real save.
##
## The player's profile is `SaveService.RUN_PATH`, `SaveService.VIGIL_PATH` and
## the settings file `Preferences.PATH`. A suite that reaches them either reads a
## real pilgrimage (and diverges from whatever it asserts: #346 recorded 26
## failures from one stray run save) or overwrites one, so no suite names them.
## This file and the census, `tests/test_suite_isolation.gd`, are the only places
## under `tests/` allowed to; the census fails on any other.
##
## There are two ways to stay clear of them:
##
##  - `install` binds a `Main` to a scratch pair before it can touch a save. It
##    is what nearly every suite needs, because the logic under test does not
##    care which files it stores into.
##  - `in_sandbox` moves `user://` itself into an empty private directory, for
##    the few suites whose subject IS the player's profile. A tooling boot must
##    leave the player's files alone, and the only way to prove that is to put
##    files at the player's paths and watch them; inside a sandbox those paths
##    hold nothing of anyone's, and the accessors below refuse to hand them out
##    anywhere else.

## The shared scratch pair. A suite that needs its own names keeps them, so long
## as they start with one of `SCRATCH_PREFIXES`.
const RUN_PATH: String = "user://glassvow_test_run_v2.json"
const VIGIL_PATH: String = "user://glassvow_test_vigil_v2.json"
## What a scratch file is called. The player's never start this way, which is what
## lets `install` and `wipe` refuse a path they must not touch.
const SCRATCH_PREFIXES: PackedStringArray = ["test_", "glassvow_test_"]
const SANDBOX_PREFIX: String = "glassvow-test-sandbox-"
const _CUSTOM_DIR_FLAG: String = "application/config/use_custom_user_dir"
const _CUSTOM_DIR_NAME: String = "application/config/custom_user_dir_name"
const _PROBE: String = "sandbox_probe"

static var _sandboxed: bool = false


## Bind a `Main` to a scratch pair before it can touch a save: both path fields
## and the Vigil move together (`Main.install_profile`), and the Vigil starts
## blank whatever a scratch file holds, as the hand-rolled fixtures this replaces
## always did. Files already at the paths are left alone: a suite clears them
## with `wipe` when it wants a clean slate, and keeps them when it is replaying a
## relaunch. A path that is not scratch binds the shared pair instead, loudly.
static func install(main: Main, run_path: String = RUN_PATH,
		vigil_path: String = VIGIL_PATH) -> void:
	var pair: PackedStringArray = binding_for(run_path, vigil_path)
	if pair[0] != run_path or pair[1] != vigil_path:
		push_error("TestProfile.install: %s and %s are not both scratch paths; binding %s and %s instead"
			% [run_path, vigil_path, pair[0], pair[1]])
	main.install_profile(pair[0], pair[1])
	main._vigil = VigilState.blank()


## The pair `install` binds for a request: the request itself when both paths are
## scratch, otherwise the shared pair.
static func binding_for(run_path: String, vigil_path: String) -> PackedStringArray:
	if is_scratch(run_path) and is_scratch(vigil_path):
		return PackedStringArray([run_path, vigil_path])
	return PackedStringArray([RUN_PATH, VIGIL_PATH])


## Delete a scratch pair. Refuses anything that is not scratch, so a wrong path
## can never delete a player's file.
static func wipe(run_path: String = RUN_PATH, vigil_path: String = VIGIL_PATH) -> void:
	for path: String in [run_path, vigil_path]:
		if not is_scratch(path):
			push_error("TestProfile.wipe: refusing to delete %s, it is not a scratch path" % path)
			return
	SaveService.clear_run("", run_path)
	SaveService.clear_vigil(vigil_path)


## A scratch file lives under `user://` and is named the way a test names its own.
static func is_scratch(path: String) -> bool:
	if not path.begins_with("user://") or path.contains(".."):
		return false
	var file: String = path.get_file()
	for prefix: String in SCRATCH_PREFIXES:
		if file.begins_with(prefix):
			return true
	return false


## Whether a path is one of the player's files. Pure: it reads nothing, so a suite
## can assert that a profile it is about to use is not the player's.
static func is_production(path: String) -> bool:
	return path in [
		SaveService.RUN_PATH, SaveService.VIGIL_PATH,
		Preferences.PATH, Preferences.LEGACY_AUDIO_PATH,
	]


## Run `body` with `user://` moved into a new, empty directory of its own, then
## put it back and delete the directory. Only the engine's own `user://` mapping
## moves, so `Main._ready`, `Preferences` and `SaveService` all follow without a
## seam. Fails closed: the move is proved with a real write before `body` runs, and
## if it did not take effect (a later engine may cache the directory) `body` never
## runs and the suite fails, rather than planting sentinels where a player's save
## may be.
static func in_sandbox(fails: Array[String], body: Callable) -> void:
	if _sandboxed:
		fails.append("test profile: in_sandbox() does not nest")
		return
	var outside: String = OS.get_user_data_dir()
	var was_flag: Variant = ProjectSettings.get_setting(_CUSTOM_DIR_FLAG, false)
	var was_name: Variant = ProjectSettings.get_setting(_CUSTOM_DIR_NAME, "")
	var dir_name: String = "%s%d-%d" % [SANDBOX_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProjectSettings.set_setting(_CUSTOM_DIR_FLAG, true)
	ProjectSettings.set_setting(_CUSTOM_DIR_NAME, dir_name)
	var inside: String = OS.get_user_data_dir()
	if _relocated(outside, inside, dir_name, fails):
		_sandboxed = true
		body.call()
		_sandboxed = false
	if inside != outside:
		_remove_sandbox(inside)
	ProjectSettings.set_setting(_CUSTOM_DIR_FLAG, was_flag)
	ProjectSettings.set_setting(_CUSTOM_DIR_NAME, was_name)
	if OS.get_user_data_dir() != outside:
		fails.append("test profile: user:// did not return to %s after the sandbox" % outside)


## The player's run path, only inside `in_sandbox`.
static func production_run_path() -> String:
	return _inside_only(SaveService.RUN_PATH)


## The player's Vigil path, only inside `in_sandbox`.
static func production_vigil_path() -> String:
	return _inside_only(SaveService.VIGIL_PATH)


static func is_sandboxed() -> bool:
	return _sandboxed


## `path` for a sandbox and, for anything else, a path whose directory does not
## exist, so an IO call that slips through fails instead of reaching a real file.
static func reveal(path: String, open: bool) -> String:
	return path if open else "user://__outside_sandbox__/%s" % path.get_file()


static func _inside_only(path: String) -> String:
	if not _sandboxed:
		push_error("TestProfile: %s is the player's file, reachable only inside in_sandbox()" % path)
	return reveal(path, _sandboxed)


static func _relocated(outside: String, inside: String, dir_name: String,
		fails: Array[String]) -> bool:
	if inside == outside or inside.get_file() != dir_name:
		fails.append("test profile: user:// did not move into a sandbox (%s -> %s)"
			% [outside, inside])
		return false
	if DirAccess.dir_exists_absolute(inside) \
			or DirAccess.make_dir_recursive_absolute(inside) != OK:
		fails.append("test profile: could not create a fresh sandbox at %s" % inside)
		return false
	var handle: FileAccess = FileAccess.open("user://%s" % _PROBE, FileAccess.WRITE)
	if handle != null:
		handle.close()
	var landed: bool = FileAccess.file_exists(inside.path_join(_PROBE))
	var strayed: bool = FileAccess.file_exists(outside.path_join(_PROBE))
	if strayed:
		DirAccess.remove_absolute(outside.path_join(_PROBE))
	if not landed or strayed:
		fails.append("test profile: a write through user:// did not land in the sandbox at %s"
			% inside)
		return false
	return true


## Only ever a directory this file made: the prefix is what a sandbox is called.
static func _remove_sandbox(path: String) -> void:
	if path.get_file().begins_with(SANDBOX_PREFIX):
		_remove_tree(path)


static func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)
