class_name TreeSuite
extends SceneTree
## The in-tree half of a suite. `run_all.gd` calls every suite inside its own
## `_initialize`, before the tree runs: no node is inside a tree there, so
## nothing can hold focus and no tween advances. A suite whose subject needs
## both (focus and its visibility, a fade over real frames) keeps its
## `static func run(fails)` for the runner and spawns this script there, through
## `spawn`, with its own path. Here its
## `static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String])`
## runs as a coroutine with real frames inside a 1180×820 SubViewport, and its
## failures come back to the runner on this process's output.
##
##   godot --headless -s res://tests/support/tree_suite.gd -- --suite=res://tests/test_x.gd

const STAGE: Vector2i = Vector2i(1180, 820)
## A suite that never finishes fails instead of holding the gate.
const WATCHDOG: float = 90.0
const FAIL_MARK: String = "tree suite fail: "
const DONE_MARK: String = "tree suite done"


## Run `suite`'s in-tree half in a child process and add its failures to
## `fails`. Blocks until the child exits.
static func spawn(fails: Array[String], suite: String) -> void:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tests/support/tree_suite.gd",
		"--", "--suite=%s" % suite])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "\n".join(PackedStringArray(output))
	var lines: PackedStringArray = text.split("\n")
	var before: int = fails.size()
	for line: String in lines:
		var at: int = line.find(FAIL_MARK)
		if at >= 0:
			fails.append(line.substr(at + FAIL_MARK.length()))
	if fails.size() == before and (code != 0 or not text.contains(DONE_MARK)):
		var tail: PackedStringArray = lines.slice(maxi(0, lines.size() - 12))
		fails.append("%s: the in-tree half exited %d without finishing:\n%s" % [
			suite, code, "\n".join(tail)])


func _initialize() -> void:
	var suite: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			suite = arg.trim_prefix("--suite=")
	var host: SubViewport = SubViewport.new()
	host.size = STAGE
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print(FAIL_MARK + "%s did not finish in %d s" % [suite, int(WATCHDOG)])
		quit(2))
	_run.call_deferred(suite, host)


func _run(suite: String, host: SubViewport) -> void:
	var fails: Array[String] = []
	var script: Script = load(suite) as Script if suite.begins_with("res://tests/test_") else null
	if script == null or not script.can_instantiate():
		fails.append("%s is not a suite under res://tests/ that loads" % suite)
	else:
		await script.call("run_in_tree", self, host, fails)
	for message: String in fails:
		print(FAIL_MARK + message)
	print(DONE_MARK)
	quit(0 if fails.is_empty() else 1)
