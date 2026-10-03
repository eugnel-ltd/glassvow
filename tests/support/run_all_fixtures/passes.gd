extends RefCounted
## A `tests/test_run_all.gd` fixture: a passing test that logs a plain engine
## error, which fails nothing.


static func run(_fails: Array[String]) -> void:
	push_error("run_all fixture: a plain engine error")
