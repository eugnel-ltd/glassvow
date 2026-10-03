extends RefCounted
## A `tests/test_run_all.gd` fixture: a static run the runner cannot call with
## its `Array[String]`. Calling it would raise the call error in the runner.


static func run(_fails: Array[int]) -> void:
	pass
