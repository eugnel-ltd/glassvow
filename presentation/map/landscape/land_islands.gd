extends RefCounted
## The islands between Act I's road loops (R3.3, issue #660): ground that no
## road or river lets out to the land's edge. The kit anchors each with a
## composed group, an outcrop with a conifer, shrubs and gravestones
## (`kit.gd` `_islands`).
##
## On a `CELL` grid over the land: a cell is open where it is out of the
## rivers' channels and off the roads (the ground paint's road field,
## `terrain_paint.gd`). The open cells
## reached from the land's edge are the land's outer ground; every other run
## of open cells of `LEAST_AREA` or more is an island, held at its pole: of
## its cells farthest from closed ground, the first a raised road keeps
## `ROAD_CLEAR` from too.

const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const CELL: float = 1.5
## The road field's value past which a cell is off the road (it is exact only
## within about a metre and a quarter of a road's line).
const OFF_ROAD: float = 1.2
const ROAD_CLEAR: float = 2.0
const LEAST_AREA: float = 24.0
## How many of an island's deepest cells are tried for its pole.
const POLE_TRIES: int = 16


## Every island of `terrain`, largest first: its pole (on the ground), its
## area (square metres) and how far its pole stands from closed ground
## (metres, in whole cells).
static func find(terrain: Terrain) -> Array[Dictionary]:
	var bounds: Rect2 = terrain.bounds
	var columns: int = floori(bounds.size.x / CELL)
	var rows: int = floori(bounds.size.y / CELL)
	var field: Image = terrain.paint.get_meta("distance_image") if terrain.paint != null \
		and terrain.paint.has_meta("distance_image") else null
	if field == null:
		return []
	# A few thousand samples: read them where they lie, never the whole field.
	var scale: Vector2 = Vector2(field.get_size()) / bounds.size
	var open: PackedByteArray = []
	open.resize(columns * rows)
	for row: int in range(rows):
		for column: int in range(columns):
			var p: Vector3 = _at(bounds, column, row)
			var fx: int = clampi(floori((p.x - bounds.position.x) * scale.x), 0, field.get_width() - 1)
			var fz: int = clampi(floori((p.z - bounds.position.y) * scale.y), 0, field.get_height() - 1)
			open[row * columns + column] = 1 if field.get_pixel(fx, fz).r >= OFF_ROAD \
				and River.distance(p.x, p.z) >= River.HALF_WIDTH else 0
	var depth: PackedInt32Array = _depths(open, columns, rows)
	var seen: PackedByteArray = []
	seen.resize(columns * rows)
	var edge: PackedInt32Array = []
	for row: int in range(rows):
		for column: int in range(columns):
			if row == 0 or column == 0 or row == rows - 1 or column == columns - 1:
				edge.append(row * columns + column)
	_spread(edge, open, seen, columns, rows)
	var out: Array[Dictionary] = []
	for index: int in range(columns * rows):
		if open[index] == 0 or seen[index] == 1:
			continue
		var cells: PackedInt32Array = _spread(PackedInt32Array([index]), open, seen, columns, rows)
		var area: float = cells.size() * CELL * CELL
		if area < LEAST_AREA:
			continue
		var order: Array = Array(cells)
		order.sort_custom(func(a: int, b: int) -> bool:
			return depth[a] > depth[b] or (depth[a] == depth[b] and a < b))
		for k: int in range(mini(POLE_TRIES, order.size())):
			var cell: int = order[k]
			var at: Vector3 = _at(bounds, cell % columns, cell / columns)
			at.y = terrain.surface_height(at.x, at.z)
			if terrain.distance_to_roads(at) >= ROAD_CLEAR:
				out.append({"centre": at, "area": area, "clearance": depth[cell] * CELL})
				break
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(str(a["area"])) > float(str(b["area"])))
	return out


static func _at(bounds: Rect2, column: int, row: int) -> Vector3:
	return Vector3(bounds.position.x + (column + 0.5) * CELL, 0.0, bounds.position.y + (row + 0.5) * CELL)


const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Each open cell's distance (in cells, four ways) from the nearest closed
## cell or the land's edge.
static func _depths(open: PackedByteArray, columns: int, rows: int) -> PackedInt32Array:
	var depth: PackedInt32Array = []
	depth.resize(columns * rows)
	var queue: PackedInt32Array = []
	for index: int in range(columns * rows):
		var column: int = index % columns
		var row: int = index / columns
		if open[index] == 0 or row == 0 or column == 0 or row == rows - 1 or column == columns - 1:
			depth[index] = 0
			queue.append(index)
		else:
			depth[index] = -1
	var cursor: int = 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for step: Vector2i in STEPS:
			var c: int = index % columns + step.x
			var r: int = index / columns + step.y
			if c < 0 or r < 0 or c >= columns or r >= rows:
				continue
			var next: int = r * columns + c
			if depth[next] < 0:
				depth[next] = depth[index] + 1
				queue.append(next)
	return depth


## Marks every open cell reachable from `start` (four ways) as seen and
## returns them.
static func _spread(start: PackedInt32Array, open: PackedByteArray, seen: PackedByteArray,
		columns: int, rows: int) -> PackedInt32Array:
	var queue: PackedInt32Array = []
	for index: int in start:
		if open[index] == 1 and seen[index] == 0:
			seen[index] = 1
			queue.append(index)
	var cursor: int = 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		for step: Vector2i in STEPS:
			var c: int = index % columns + step.x
			var r: int = index / columns + step.y
			if c < 0 or r < 0 or c >= columns or r >= rows:
				continue
			var next: int = r * columns + c
			if open[next] == 1 and seen[next] == 0:
				seen[next] = 1
				queue.append(next)
	return queue
