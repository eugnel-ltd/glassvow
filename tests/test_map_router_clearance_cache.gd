extends RefCounted
## Keep the author's visibility-router bytes while bounding repeated geometry.

const Cases = preload("res://tests/support/router_clearance_cases.gd")
## Captured from c0e0010c before the cache, on Godot 4.7.2. Includes every route
## field: centerline, costs, failure, diagnostics and digest, on all nine cases.
const ORIGINAL_ROWS: String = "0a9e3c0a3e3f377dc6a59ae7b6e6f868a54e2bda8327e0c180a4371622d87527"

static func run(fails: Array[String]) -> void:
	var rows: Array = []
	for fixture: Dictionary in Cases.cases():
		rows.append({"name": fixture["name"], "result": Cases.route(MapSingleEdgeRouter, fixture)})
	_check(fails, MapLayoutCanonical.digest(rows) == ORIGINAL_ROWS,
		"canonical output changed on the symmetric, reordered, rotated, channel or near-tie fixtures")
	_check_search_geometry(fails)

static func _check_search_geometry(fails: Array[String]) -> void:
	var router: GDScript = _counting_router(fails)
	if router == null:
		return
	# The target is disconnected. Every other directed state is visited, so
	# each edge is considered through several distinct predecessor states.
	var points: Array[Vector2] = [Vector2.ZERO, Vector2(50.0, 0.0)]
	for index: int in range(12):
		points.append(Vector2(float(index % 4) + 1.0, floorf(float(index) / 4.0) + 1.0))
	var adjacency: Array[PackedInt32Array] = []
	for at: int in range(points.size()):
		var neighbours: PackedInt32Array = PackedInt32Array()
		if at != 1:
			for next: int in range(points.size()):
				if next != 1 and next != at:
					neighbours.append(next)
		adjacency.append(neighbours)
	var obstacles: Array = [{"id": "far", "polygon": Cases.rect(0.0, 8.0, 8.0, 9.0)}]
	var searched: Dictionary = router._search(points, {"adjacency": adjacency}, obstacles, points[0], points[1])
	_check(fails, searched == {"ok": false, "state_count": 157, "expansions": 157},
		"the disconnected dense graph changed its search result or traversal counts")
	var counts: Dictionary = router.probe_counts
	var calls: int = 0
	var maximum: int = 0
	for count: int in counts.values():
		calls += count
		maximum = maxi(maximum, count)
	_check(fails, counts.size() == 156 and calls == 156 and maximum == 1,
		"a directed edge repeated its obstacle geometry: %d calls over %d edges, maximum %d"
			% [calls, counts.size(), maximum])

static func _counting_router(fails: Array[String]) -> GDScript:
	# Instrument a private in-memory copy so the measurement counts actual
	# geometry work without adding counters to production route diagnostics.
	var source: String = FileAccess.get_file_as_string("res://presentation/map/map_single_edge_router.gd")
	var signature: String = "static func _clearance(length: float, a: Vector2, b: Vector2, obstacles: Array) -> float:\n"
	if source.count(signature) != 1:
		fails.append("test_map_router_clearance_cache: cannot locate the clearance measurement seam")
		return null
	source = source.replace("class_name MapSingleEdgeRouter\n", "")
	source = source.replace("extends RefCounted\n", "extends RefCounted\nstatic var probe_counts: Dictionary = {}\n")
	source = source.replace(signature, signature
		+ "\tvar probe_key: Vector4 = Vector4(a.x, a.y, b.x, b.y)\n"
		+ "\tprobe_counts[probe_key] = MapLayoutCanonical.int_value(probe_counts.get(probe_key, 0)) + 1\n")
	var router: GDScript = GDScript.new()
	router.source_code = source
	if router.reload() != OK:
		fails.append("test_map_router_clearance_cache: the counting router failed to load")
		return null
	return router

static func _check(fails: Array[String], ok: bool, message: String) -> void:
	if not ok:
		fails.append("test_map_router_clearance_cache: " + message)
