extends Logger
## Records the GDScript errors the engine logs, so `tests/run_all.gd` can fail
## the test that raised them.
##
## A runtime error ("SCRIPT ERROR: Invalid access to property or key 'mesh' on
## a base object of type 'null instance'") aborts only the function it is raised
## in. Its caller carries on, so a test that hit one still printed "ok" and every
## check after the error silently never ran. The engine hands every error it
## logs to each `Logger` registered with `OS.add_logger`; this one keeps the
## `ERROR_TYPE_SCRIPT` ones (runtime errors, failed assertions, parse errors)
## and ignores the rest. Plain engine errors and warnings, such as a null
## material on the headless renderer or a leaked RID at exit, stay on stderr and
## fail nothing. `push_error` logs as a plain engine error, so it fails nothing
## either, and so does a call the engine refuses to make (a signal handler that
## takes the wrong arguments): its body never runs, but the engine logs that as
## a plain error. While `Engine.print_error_messages` is off the engine hands no
## logger anything, so the guard sees nothing; the runner fails a test that
## leaves it off.
##
## The engine may call `_log_error` from any thread (a worker-pool build reports
## its errors on its worker), so the record is guarded by a mutex. It must never
## print or log from there: an error raised inside a logger would recurse.

## Messages kept between two `take` calls; the rest are only counted, so a test
## that errors inside a loop reports its first few errors and the total.
const KEPT: int = 5

var _mutex: Mutex = Mutex.new()
var _count: int = 0
var _messages: Array[String] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	# The engine prints the rationale when there is one, otherwise the code.
	var detail: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	_count += 1
	if _messages.size() < KEPT:
		_messages.append("%s:%d in %s(): %s" % [file, line, function, detail])
	_mutex.unlock()


## The script errors logged since the last call, one `file:line in function():
## message` line each (at most `KEPT`, then a line counting the rest), and
## starts a new record.
func take() -> Array[String]:
	_mutex.lock()
	var out: Array[String] = _messages
	var rest: int = _count - _messages.size()
	_messages = []
	_count = 0
	_mutex.unlock()
	if rest > 0:
		out.append("and %d more script error(s)" % rest)
	return out
