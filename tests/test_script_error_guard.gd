extends RefCounted
## The runner's script-error guard (`tests/support/script_error_guard.gd`): it
## keeps the GDScript errors the engine logs and nothing else, names where each
## was raised, bounds what one test can report, and keeps an exact count when
## workers log at once. The errors are handed to the guard directly, as the
## engine hands them, so this suite raises none of its own.

const ScriptErrorGuard = preload("res://tests/support/script_error_guard.gd")
const WORKERS: int = 8
const PER_WORKER: int = 50


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_script_error_guard: %s" % what)


static func run(fails: Array[String]) -> void:
	_keeps_only_script_errors(fails)
	_bounds_a_flood(fails)
	_counts_workers_exactly(fails)


static func _log(guard: ScriptErrorGuard, error_type: int, code: String,
		rationale: String = "") -> void:
	guard._log_error("_raise", "res://tests/test_example.gd", 12, code, rationale, false,
		error_type, [])


static func _keeps_only_script_errors(fails: Array[String]) -> void:
	var guard: ScriptErrorGuard = ScriptErrorGuard.new()
	_log(guard, Logger.ERROR_TYPE_ERROR, "Parameter \"material\" is null.")
	_log(guard, Logger.ERROR_TYPE_WARNING, "1028 ObjectDB instances were leaked at exit")
	_log(guard, Logger.ERROR_TYPE_SHADER, "shader compile failed")
	_check(fails, guard.take().is_empty(), "plain engine errors, warnings and shader errors fail nothing")
	_log(guard, Logger.ERROR_TYPE_SCRIPT,
		"Invalid access to property or key 'mesh' on a base object of type 'null instance'.")
	_log(guard, Logger.ERROR_TYPE_SCRIPT, "code", "the rationale")
	var taken: Array[String] = guard.take()
	_check(fails, taken == ["res://tests/test_example.gd:12 in _raise(): Invalid access to property"
				+ " or key 'mesh' on a base object of type 'null instance'.",
			"res://tests/test_example.gd:12 in _raise(): the rationale"],
		"a script error is named by file, line and function, with the message the engine prints: %s"
			% [taken])
	_check(fails, guard.take().is_empty(), "a take starts a new record")


static func _bounds_a_flood(fails: Array[String]) -> void:
	var guard: ScriptErrorGuard = ScriptErrorGuard.new()
	for i: int in range(ScriptErrorGuard.KEPT + 7):
		_log(guard, Logger.ERROR_TYPE_SCRIPT, "error %d" % i)
	var taken: Array[String] = guard.take()
	_check(fails, taken.size() == ScriptErrorGuard.KEPT + 1
			and taken[0].ends_with("error 0") and taken[-1] == "and 7 more script error(s)",
		"an error raised in a loop reports the first few and counts the rest: %s" % _shape(taken))


static func _counts_workers_exactly(fails: Array[String]) -> void:
	var guard: ScriptErrorGuard = ScriptErrorGuard.new()
	var log_some: Callable = func(_worker: int) -> void:
		for _i: int in range(PER_WORKER):
			_log(guard, Logger.ERROR_TYPE_SCRIPT, "worker error")
	var task: int = WorkerThreadPool.add_group_task(log_some, WORKERS)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var taken: Array[String] = guard.take()
	_check(fails, taken.size() == ScriptErrorGuard.KEPT + 1
			and taken[-1] == "and %d more script error(s)" % (WORKERS * PER_WORKER - ScriptErrorGuard.KEPT),
		"errors logged from workers at once are all counted: %s" % _shape(taken))


## How many lines a take returned, and its last.
static func _shape(taken: Array[String]) -> String:
	return "%d line(s), last %s" % [taken.size(), taken[-1] if not taken.is_empty() else "none"]
