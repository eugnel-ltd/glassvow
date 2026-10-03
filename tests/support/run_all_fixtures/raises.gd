extends RefCounted
## A `tests/test_run_all.gd` fixture: a script error in a function the test
## calls. The test carries on and appends nothing.


static func run(_fails: Array[String]) -> void:
	_raise()


static func _raise() -> void:
	var node: Node = null
	print(node.name)
