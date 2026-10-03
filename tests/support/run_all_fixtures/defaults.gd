extends RefCounted
## A `tests/test_run_all.gd` fixture: a passing run with a defaulted second
## parameter, which the runner can still call with its one argument.


static func run(_fails: Array[String], _verbose: bool = false) -> void:
	pass
