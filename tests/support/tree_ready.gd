class_name TreeReady
extends RefCounted
## Test support: runs a node's `_ready` by hand only when the engine has not.
##
## `tests/run_all.gd` lets frames run before the first test and after each one,
## so every test runs with the root already inside the tree. A node a suite adds
## under the root gets `_ready` from the engine there and then; a node built
## outside the tree never does. A suite that drives a node by hand calls `once`
## instead of `_ready()`, so the node is readied exactly once either way: a
## second `_ready` connects its signals twice and builds its parts twice.


static func once(node: Node) -> void:
	if not node.is_node_ready():
		node._ready()
