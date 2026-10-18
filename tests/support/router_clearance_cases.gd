extends RefCounted

static func rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y0)])

static func cases() -> Array[Dictionary]:
	var box: Array[Dictionary] = [{"id": "box", "polygon": rect(-1.0, -1.0, 1.0, 1.0)}]
	var barriers: Array[Dictionary] = [
		{"id": "top", "polygon": rect(-1.0, 0.25, 1.0, 1.2)},
		{"id": "bottom", "polygon": rect(-1.0, -1.2, 1.0, -0.25)},
	]
	var rotated: PackedVector2Array = MapAssetProfiles.new().transformed_footprint(
		{"local_footprint": rect(-3.0, -0.4, 3.0, 0.4)}, Vector3.ZERO, 25.0, Vector3.ONE)
	var staggered: Array[Dictionary] = [
		{"id": "a", "polygon": rect(-2.5, -1.6, -1.7, 0.3)},
		{"id": "b", "polygon": rect(-0.4, -0.3, 0.4, 1.6)},
		{"id": "c", "polygon": rect(1.7, -1.6, 2.5, 0.3)},
	]
	var reordered: Array[Dictionary] = [staggered[2], staggered[0], staggered[1]]
	return [
		{"name": "straight", "obstacles": [], "half_width": 0.2},
		{"name": "symmetric", "obstacles": box, "half_width": 0.2},
		{"name": "staggered", "obstacles": staggered, "half_width": 0.15},
		{"name": "staggered-reordered", "obstacles": reordered, "half_width": 0.15},
		{"name": "rotated", "obstacles": [{"id": "long", "polygon": rotated}], "half_width": 0.2},
		{"name": "narrow", "obstacles": barriers, "half_width": 0.15, "channel": rect(-5.0, -1.2, 5.0, 1.2)},
		{"name": "wide", "obstacles": barriers, "half_width": 0.25, "channel": rect(-5.0, -1.2, 5.0, 1.2)},
		{"name": "near-tie", "obstacles": [{"id": "box", "polygon": rect(-1.0, -1.0005, 1.0, 1.0)}], "half_width": 0.2},
		{"name": "outside-tie", "obstacles": [{"id": "box", "polygon": rect(-1.0, -1.002, 1.0, 1.0)}], "half_width": 0.2},
	]

static func route(router: GDScript, fixture: Dictionary) -> Dictionary:
	var obstacles: Array[Dictionary] = []
	var raw: Array = fixture["obstacles"]
	obstacles.assign(raw)
	var half_width: float = fixture["half_width"]
	var channel: PackedVector2Array = fixture.get("channel", PackedVector2Array())
	return router.route(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), obstacles,
		half_width, 0.05, channel)
