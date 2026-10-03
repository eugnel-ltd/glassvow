extends RefCounted
## A `tests/test_run_all.gd` fixture: turns the engine's error log off and
## leaves it off, which hides every later script error from every logger.


static func run(_fails: Array[String]) -> void:
	Engine.print_error_messages = false
