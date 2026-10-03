extends RefCounted
## The runner itself (`tests/run_all.gd`), run the way CI runs it: a headless
## child Godot on a throwaway project that holds a copy of the runner, its
## guard, and the fixtures in `tests/support/run_all_fixtures/` as its tests.
## A script error fails the test that raised it, including one raised by a
## deferred call, and the next test is not charged for it. A check made after
## an await counts. A test that leaves the engine's error log off fails. A run
## the runner cannot call fails without hanging the runner, and a run with a
## defaulted parameter is called. A plain engine error fails nothing, so a
## selection of passing tests passes. The guard's own record (its filter,
## message, bound and thread safety) is test_script_error_guard.gd.

const RUNNER: String = "res://tests/run_all.gd"
const GUARD: String = "res://tests/support/script_error_guard.gd"
const FIXTURE: String = "res://tests/support/run_all_fixtures/%s.gd"
## The child's tests in run order, each a copy of the named fixture.
const TESTS: Dictionary = {
	"test_a_raises.gd": "raises",
	"test_b_defers.gd": "defers",
	"test_c_passes.gd": "passes",
	"test_d_defaults.gd": "defaults",
	"test_e_awaits.gd": "awaits",
	"test_f_silences.gd": "silences",
	"test_g_wrong_type.gd": "wrong_type",
	"test_z_passes.gd": "passes",
}
const PROJECT: String = """config_version=5

[application]

config/name="glassvow-run-all-fixture"

[debug]

file_logging/enable_file_logging.pc=false
"""
## A child still running by then has hung, and is killed.
const DEADLINE_MSEC: int = 60000


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_run_all: %s" % what)


static func run(fails: Array[String]) -> void:
	var project: DirAccess = DirAccess.create_temp("glassvow-run-all")
	if project == null or not _write_project(project.get_current_dir()):
		fails.append("test_run_all: could not write the fixture project")
		return
	_grades_each_test_by_what_it_raised(fails, project.get_current_dir())
	_passes_a_passing_selection(fails, project.get_current_dir())


static func _grades_each_test_by_what_it_raised(fails: Array[String], root: String) -> void:
	var child: Dictionary = _run_runner(root, [])
	var exit: int = child["exit"]
	var lines: PackedStringArray = child["lines"]
	_check(fails, exit == 1, "a run with failing tests exits 1, not %d: %s" % [exit, lines])
	var verdicts: PackedStringArray = []
	for line: String in lines:
		if line.begins_with("ok   res://") or line.begins_with("FAIL res://"):
			verdicts.append(line)
	_check(fails, verdicts == PackedStringArray([
			"FAIL res://tests/test_a_raises.gd",
			"FAIL res://tests/test_b_defers.gd",
			"ok   res://tests/test_c_passes.gd",
			"ok   res://tests/test_d_defaults.gd",
			"FAIL res://tests/test_e_awaits.gd",
			"FAIL res://tests/test_f_silences.gd",
			"ok   res://tests/test_z_passes.gd"]),
		"each test is graded by what it raised, and the runner reaches the last: %s" % [verdicts])
	_check(fails, lines.has("FAIL (5)"), "five failures are counted: %s" % [lines])
	_check(fails, _listed(lines, "res://tests/test_a_raises.gd: script error at "
			+ "res://tests/test_a_raises.gd:", " in _raise(): Invalid access to property or key 'name'"),
		"a script error fails the test that raised it, naming where and what")
	_check(fails, _listed(lines, "res://tests/test_b_defers.gd: script error at "
			+ "res://tests/test_b_defers.gd:", " in _raise(): Invalid access"),
		"a script error raised by a deferred call fails the test that queued it")
	_check(fails, _listed(lines, "run_all fixture: a check after an await"),
		"a check made after an await counts")
	_check(fails, _listed(lines, "res://tests/test_f_silences.gd: left Engine.print_error_messages off"),
		"a test that leaves the engine's error log off fails")
	_check(fails, _listed(lines, "res://tests/test_g_wrong_type.gd: has no static run(fails: Array[String])"),
		"a run the runner cannot call with an Array[String] fails and is never called")
	var late: bool = false
	for line: String in lines:
		late = late or line.begins_with("run_all: script errors")
	_check(fails, not late, "no test's script error is left for the teardown at exit: %s" % [lines])


static func _passes_a_passing_selection(fails: Array[String], root: String) -> void:
	var child: Dictionary = _run_runner(root,
		["--tests=res://tests/test_c_passes.gd,res://tests/test_d_defaults.gd"])
	var exit: int = child["exit"]
	var lines: PackedStringArray = child["lines"]
	_check(fails, exit == 0 and lines.has("PASS (2 tests)"),
		"passing tests, one of them logging a plain engine error, pass and exit 0: exit %d, %s"
			% [exit, lines])


## Whether a `  - ` failure line starts with `head` and contains `part`.
static func _listed(lines: PackedStringArray, head: String, part: String = "") -> bool:
	for line: String in lines:
		if line.begins_with("  - " + head) and (part.is_empty() or line.contains(part)):
			return true
	return false


## Writes the throwaway project under `root`. False when any file could not be
## read or written.
static func _write_project(root: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(root.path_join("tests/support")) != OK:
		return false
	var files: Dictionary = {
		"project.godot": PROJECT,
		"tests/run_all.gd": FileAccess.get_file_as_string(RUNNER),
		"tests/support/script_error_guard.gd": FileAccess.get_file_as_string(GUARD),
	}
	for test: String in TESTS:
		files["tests/" + test] = FileAccess.get_file_as_string(FIXTURE % TESTS[test])
	for path: String in files:
		var text: String = files[path]
		var file: FileAccess = FileAccess.open(root.path_join(path), FileAccess.WRITE)
		if text.is_empty() or file == null or not file.store_string(text):
			return false
		file.close()
	return true


## Runs the runner headless on the project at `root`, with `user_args` after
## `--`. Returns its exit status and the lines it printed; a child still running
## at `DEADLINE_MSEC` is killed and reported with exit -1.
static func _run_runner(root: String, user_args: PackedStringArray) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--path", root, "-s", RUNNER]
	if not user_args.is_empty():
		args.append("--")
		args.append_array(user_args)
	var child: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), args, false)
	if child.is_empty():
		return {"exit": -1, "lines": PackedStringArray(["could not start a child Godot"])}
	var pid: int = child["pid"]
	var stdio: FileAccess = child["stdio"]
	var stderr: FileAccess = child["stderr"]
	var out: PackedByteArray = []
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MSEC
	while OS.is_process_running(pid):
		out.append_array(_drain(stdio))
		# Read and dropped: a full stderr pipe would stall the child.
		_drain(stderr)
		if Time.get_ticks_msec() > deadline:
			OS.kill(pid)
			return {"exit": -1, "lines": _lines(out) + PackedStringArray(["(hung, killed)"])}
		OS.delay_msec(10)
	out.append_array(_drain(stdio))
	return {"exit": OS.get_process_exit_code(pid), "lines": _lines(out)}


## Everything `pipe` holds now (it does not block).
static func _drain(pipe: FileAccess) -> PackedByteArray:
	var out: PackedByteArray = []
	var chunk: PackedByteArray = pipe.get_buffer(4096)
	while not chunk.is_empty():
		out.append_array(chunk)
		chunk = pipe.get_buffer(4096)
	return out


static func _lines(out: PackedByteArray) -> PackedStringArray:
	var lines: PackedStringArray = []
	for line: String in out.get_string_from_utf8().split("\n"):
		lines.append(line.strip_edges(false, true))
	return lines
