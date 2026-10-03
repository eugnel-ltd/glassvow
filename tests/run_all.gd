extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and calls static run(fails).
## Pass -- --tests=res://tests/test_a.gd,res://tests/test_b.gd for a fail-closed subset.
##
## A GDScript error raised while a test loads or runs fails that test, naming
## where it was raised (`ScriptErrorGuard`): the error aborts only the function
## it is raised in, so without the guard the test printed "ok" while every check
## after the error never ran. A test is graded only once the frames after it
## have run (`_settle`), so an error raised by a deferred call, a frame of
## processing, a queued free or an already due timer it left behind is charged
## to it, and a `run` that awaits is awaited. Script errors raised while the tree is torn
## down at exit come after the result and name no test: they are listed and
## change nothing. A test that leaves `Engine.print_error_messages` off fails,
## because the engine hands no logger anything while it is off.
## A test that does not parse, or has no static run(fails) that takes an
## `Array[String]`, is never called: the call error would abort this runner
## itself, which then never quits.

const ScriptErrorGuard = preload("res://tests/support/script_error_guard.gd")
## Frames run after each test before it is graded. The first finishes the frame
## the test returned in (its deferred calls, processing, timers and queued
## frees); the second runs one whole frame more.
const SETTLE_FRAMES: int = 2

var _guard: ScriptErrorGuard = ScriptErrorGuard.new()


func _initialize() -> void:
	OS.add_logger(_guard)
	_run_selected()


## Runs the selected tests one at a time, then quits with the result. It is a
## coroutine: the runner waits out each test's frames before grading it. Frames
## run before the first test too, so every test, alone or in the whole suite,
## runs inside a frame with the root window already sized.
func _run_selected() -> void:
	var fails: Array[String] = []
	var scripts: Array[String] = _select_scripts(fails)
	if scripts.is_empty():
		print("run_all: no test_*.gd selected under res://tests/")
	await _settle()
	for path: String in scripts:
		var script: Script = load(path) as Script
		var unrunnable: String = _unrunnable(script)
		if not unrunnable.is_empty():
			fails.append("%s: %s" % [path, unrunnable])
			_grade(path, fails)
			continue
		var before: int = fails.size()
		await script.call("run", fails)
		await _settle()
		_grade(path, fails)
		if fails.size() == before:
			print("ok   %s" % path)
		else:
			print("FAIL %s" % path)
	if fails.is_empty():
		print("PASS (%d tests)" % scripts.size())
		quit(0)
	else:
		print("FAIL (%d)" % fails.size())
		for msg: String in fails:
			print("  - %s" % msg)
		quit(1)


func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame


## Records, as failures of the test at `path`, every script error raised since
## the previous test, and the engine's error log left off (it is turned back on,
## so the next test is seen).
func _grade(path: String, fails: Array[String]) -> void:
	for message: String in _guard.take():
		fails.append("%s: script error at %s" % [path, message])
	if not Engine.print_error_messages:
		Engine.print_error_messages = true
		fails.append("%s: left Engine.print_error_messages off, which hides every script error from the runner" % path)


## Why `script` cannot be run, or "" when it parsed and declares a static run
## that this runner can call with its one `Array[String]`.
static func _unrunnable(script: Script) -> String:
	if script == null or not script.can_instantiate():
		return "failed to load"
	for method: Dictionary in script.get_script_method_list():
		if method["name"] == "run" and _takes_fails(method):
			return ""
	return "has no static run(fails: Array[String])"


## Whether `method` is static and takes exactly one argument, an `Array[String]`
## (or an untyped `Array` or `Variant`), once its defaulted and variadic
## parameters are left out.
static func _takes_fails(method: Dictionary) -> bool:
	var flags: int = method["flags"]
	var args: Array = method["args"]
	var defaults: Array = method["default_args"]
	if not flags & METHOD_FLAG_STATIC or args.size() - defaults.size() > 1:
		return false
	if args.is_empty():
		return flags & METHOD_FLAG_VARARG != 0
	var first: Dictionary = args[0]
	var type: int = first["type"]
	var element: String = first["hint_string"]
	return type == TYPE_NIL or (type == TYPE_ARRAY and element in ["", "String"])


## Runs once the tree has been torn down, after the result above was printed.
func _finalize() -> void:
	var late: Array[String] = _guard.take()
	OS.remove_logger(_guard)
	if late.is_empty():
		return
	print("run_all: script errors while the tree was torn down at exit, charged to no test (the result stands):")
	for message: String in late:
		print("  - %s" % message)


func _select_scripts(fails: Array[String]) -> Array[String]:
	var requested: Array[String] = []
	var saw_filter: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--tests="):
			continue
		if saw_filter:
			fails.append("run_all: --tests may be supplied only once")
			continue
		saw_filter = true
		var raw: String = arg.substr("--tests=".length())
		if raw.is_empty():
			fails.append("run_all: --tests requires at least one path")
			continue
		var parts: PackedStringArray = raw.split(",", true)
		for entry: String in parts:
			var path: String = entry.strip_edges()
			if path.is_empty():
				fails.append("run_all: requested test path may not be empty")
				continue
			if not path.begins_with("res://tests/test_") or not path.ends_with(".gd") or path.contains(".."):
				fails.append("run_all: invalid requested test path %s" % path)
				continue
			if not FileAccess.file_exists(path):
				fails.append("run_all: requested test does not exist: %s" % path)
				continue
			if requested.has(path):
				fails.append("run_all: duplicate requested test: %s" % path)
				continue
			requested.append(path)
	if not saw_filter:
		return _discover()
	requested.sort()
	return requested


func _discover() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://tests")
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
			out.append("res://tests/%s" % name)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
