extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and calls static run(fails).
## Pass -- --tests=res://tests/test_a.gd,res://tests/test_b.gd for a fail-closed subset.
##
## A GDScript error raised while a test loads or runs fails that test, naming
## where it was raised (`ScriptErrorGuard`): the error aborts only the function
## it is raised in, so without the guard the test printed "ok" while every check
## after the error never ran. Script errors raised after the last test (at exit)
## belong to no test: they are reported after the result and do not change it.
## A test that does not parse, or has no static run(fails), is never called: the
## call error would abort this runner itself, which then never quits.

const ScriptErrorGuard = preload("res://tests/support/script_error_guard.gd")

var _guard: ScriptErrorGuard = ScriptErrorGuard.new()


func _initialize() -> void:
	OS.add_logger(_guard)
	var fails: Array[String] = []
	var scripts: Array[String] = _select_scripts(fails)
	if scripts.is_empty():
		print("run_all: no test_*.gd selected under res://tests/")
	for path: String in scripts:
		var script: Script = load(path) as Script
		var unrunnable: String = _unrunnable(script)
		if not unrunnable.is_empty():
			fails.append("%s: %s" % [path, unrunnable])
			_fail_on_script_errors(path, fails)
			continue
		var before: int = fails.size()
		script.call("run", fails)
		_fail_on_script_errors(path, fails)
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


## Records every script error raised since the previous test as a failure of
## the test at `path`.
func _fail_on_script_errors(path: String, fails: Array[String]) -> void:
	for message: String in _guard.take():
		fails.append("%s: script error at %s" % [path, message])


## Why `script` cannot be run, or "" when it parsed and declares a static
## run(fails).
static func _unrunnable(script: Script) -> String:
	if script == null or not script.can_instantiate():
		return "failed to load"
	for method: Dictionary in script.get_script_method_list():
		var flags: int = method["flags"]
		var args: Array = method["args"]
		if method["name"] == "run" and flags & METHOD_FLAG_STATIC and args.size() == 1:
			return ""
	return "has no static run(fails)"


## Runs once the tree has been torn down, after the result above was printed.
func _finalize() -> void:
	var late: Array[String] = _guard.take()
	OS.remove_logger(_guard)
	if late.is_empty():
		return
	print("run_all: script errors after the last test, attributed to no test (the result stands):")
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
