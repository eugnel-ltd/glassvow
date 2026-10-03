extends RefCounted
## A `tests/test_run_all.gd` fixture: a script error raised by a deferred call
## the test queued, after it returned.


static func run(_fails: Array[String]) -> void:
	_raise.call_deferred()


static func _raise() -> void:
	var node: Node = null
	print(node.name)
