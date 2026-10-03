extends RefCounted
## A `tests/test_run_all.gd` fixture: a check that fails a frame after run
## started, once it has awaited.


static func run(fails: Array[String]) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	fails.append("run_all fixture: a check after an await")
