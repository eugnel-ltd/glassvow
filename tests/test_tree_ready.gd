extends RefCounted
## `TreeReady.once` (`tests/support/tree_ready.gd`): a node a suite drives by
## hand is readied exactly once, whether or not the engine has already readied
## it. The runner lets frames run before every test, so the root is in the tree
## here, as it is for every suite.


class Counted:
	extends Node
	var readies: int = 0

	func _ready() -> void:
		readies += 1


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_tree_ready: %s" % what)


static func run(fails: Array[String]) -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	_check(fails, root.is_inside_tree(), "a test ran before the root was in the tree")
	var under_root: Counted = Counted.new()
	root.add_child(under_root)
	TreeReady.once(under_root)
	_check(fails, under_root.readies == 1,
		"a node under the root was readied %d times, not once" % under_root.readies)
	under_root.free()
	var off_tree: Counted = Counted.new()
	TreeReady.once(off_tree)
	_check(fails, off_tree.readies == 1,
		"a node outside the tree was readied %d times, not once" % off_tree.readies)
	off_tree.free()
