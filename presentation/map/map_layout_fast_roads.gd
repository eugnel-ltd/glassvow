class_name MapLayoutFastRoads
extends RefCounted
## The fast layout's roads: one gently curved road per edge, kept clear of the
## waystones and of each other. Where two must cross, `MapLayoutFastBridges`
## carries one over the other.
##
## Every road starts as a cubic that leaves and arrives halfway between the
## chord and the journey axis (+X), so roads fanning into one node meet only at
## its seal. Then, in this order and in a fixed number of steps:
##
## 1. Roads leaving one node that would read as one at the branch sample
##    distance on the phone at the farthest zoom lean towards their chords until
##    they part.
## 2. Roads that pass within their corridor of a waystone they do not serve, or
##    of each other, are bumped apart. Roads that cross are left to the bridges.
## 3. Each lower road of a crossing is routed through its upper road, then the
##    bumps run again for the roads that moved.
##
## Scalar arithmetic and square roots only, so the roads are the same on every
## device. The work is bounded: a few passes over a fixed set of neighbouring
## roads, each road a fixed number of points.

## Segments per road. Enough for the curve to read as a curve at the closest
## zoom; each extra point costs every scenery candidate one more segment test.
const SEGMENTS: int = 10
## Weight of the journey axis (+X) against the chord in a road's end tangents:
## 1 bisects them. Heavier leaves and arrives more along the journey and bends
## harder between rows; 0 is the straight chord.
const AXIS_PULL: float = 1.0
## What a road leaving a crowded branch may fall back to, in order.
const FAN_PULLS: Array[float] = [0.5, 0.0]
## Branch separation to reach (px): the governed 32 with a pixel of headroom.
const FAN_PX: float = 33.0
## Distance kept beyond the governed corridor from a waystone and from another road.
const HEADROOM_M: float = 0.15
## How far a bump may carry a road beyond the bounds measured at the start of a
## pass (m).
const BOX_SLACK_M: float = 1.0
## Bump passes over every road.
const PASSES: int = 3
## How much of a bump each vertex takes, for the vertex and two neighbours either side.
const BUMP: Array[float] = [0.35, 0.8, 1.0, 0.8, 0.35]
## Share of the correction two roads each take.
const SHARE: float = 0.6
const EPSILON: float = 0.000001
## Stops this close are joined by one straight segment: the two points either
## side of a crossing, which the road crosses between.
const JOIN_M: float = 1.0

@warning_ignore_start("unsafe_call_argument")

## Read by `MapLayoutFastBridges`: the edge IDs in order, each road's first and
## last node, the row it leaves, whether it is bound for a lower lane, the nodes'
## ground position, the pairs of roads that share no node and run in the same or
## adjacent rows, the corridor width and each road's points.
var ids: Array[String] = []
var from_id: Dictionary = {}
var to_id: Dictionary = {}
var rows: Dictionary = {}
var downs: Dictionary = {}
var node_x: Dictionary = {}
var node_z: Dictionary = {}
var pairs: Array[Array] = []
var width: float = 0.0
var lines_x: Dictionary = {}
var lines_z: Dictionary = {}
var _anchors: Dictionary = {}
## Per road, the nodes in its row and the next that it does not serve.
var _near: Dictionary = {}
var _half_x: float = 0.0
var _half_z: float = 0.0
var _node_reach: float = 0.0
var _road_gap: float = 0.0
var _sample_m: float = 0.0
var _pull_start: Dictionary = {}
var _pull_end: Dictionary = {}
## Per road, the indices of the points where it passes through another's middle.
var _vias: Dictionary = {}
## The pairs of roads (by `pair_key`) that cross, which the bumps leave alone.
var _crossing: Dictionary = {}
## Per road, its bounds as [min x, min z, max x, max z] as of the last
## `measure`; a pass moves a point by less than `BOX_SLACK_M`.
var _boxes: Dictionary = {}


func _init(nodes: Array, edge_rows: Array, anchors: Dictionary,
		quality: Dictionary) -> void:
	_anchors = anchors
	var geometry: Dictionary = quality["geometry"]
	var corridor: Dictionary = geometry["road_corridor"]
	var half_width: float = _f(corridor["physical_half_width_m"])
	width = 2.0 * half_width
	_node_reach = half_width + _f(corridor["world_clearance_m"]) + HEADROOM_M
	_road_gap = width + HEADROOM_M
	_sample_m = _f(geometry["branch_fanout"]["sample_distance_m"])
	var half: Array = quality["calibration"]["shipping_touch_waystone"][
		"node_pair_half_extent_m"]
	_half_x = _f(half[0])
	_half_z = _f(half[1])
	var node_rows: Dictionary = {}
	var cols: Dictionary = {}
	var by_row: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var row: int = MapLayoutCanonical.int_value(node["row"])
		node_rows[node_id] = row
		cols[node_id] = MapLayoutCanonical.int_value(node["col"])
		node_x[node_id] = _f(anchors[node_id][0])
		node_z[node_id] = _f(anchors[node_id][2])
		if not by_row.has(row):
			by_row[row] = []
		by_row[row].append(node_id)
	var edges_by_row: Dictionary = {}
	for edge: Dictionary in edge_rows:
		var id: String = str(edge["id"])
		var source_id: String = str(edge["from"])
		var target_id: String = str(edge["to"])
		from_id[id] = source_id
		to_id[id] = target_id
		rows[id] = node_rows[source_id]
		downs[id] = cols[target_id] < cols[source_id]
		if not edges_by_row.has(node_rows[source_id]):
			edges_by_row[node_rows[source_id]] = []
		edges_by_row[node_rows[source_id]].append(id)
	ids.assign(MapLayoutCanonical.sorted_keys(from_id))
	for id: String in ids:
		var near: Array[String] = []
		for row_offset: int in [0, 1]:
			for node_id: String in by_row.get(int(rows[id]) + row_offset, []):
				if node_id != from_id[id] and node_id != to_id[id]:
					near.append(node_id)
		_near[id] = near
	var row_keys: Array = edges_by_row.keys()
	row_keys.sort()
	for row: int in row_keys:
		var here: Array = edges_by_row[row]
		here.sort()
		var ahead: Array = edges_by_row.get(row + 1, [])
		ahead.sort()
		for i: int in range(here.size()):
			for j: int in range(i + 1, here.size()):
				_add_pair(str(here[i]), str(here[j]))
			for other: String in ahead:
				_add_pair(str(here[i]), other)


## Every road, by edge ID: `from`, `to`, `centerline` and `corridor_width`, and
## the `bridges` as [upper, lower] edge ID pairs.
func route() -> Dictionary:
	for id: String in ids:
		_pull_start[id] = AXIS_PULL
		_pull_end[id] = AXIS_PULL
		shape(id, [])
	_spread_branches()
	var bridges: MapLayoutFastBridges = MapLayoutFastBridges.new(self)
	var crossings: Array[Dictionary] = bridges.find()
	for crossing: Dictionary in crossings:
		_crossing[pair_key(str(crossing["upper"]), str(crossing["lower"]))] = true
	_clear_obstacles()
	bridges.route_through(crossings)
	_clear_obstacles()
	var edges: Dictionary = _edges()
	return {"edges": edges, "bridges": bridges.span(edges, crossings)}


func _add_pair(a: String, b: String) -> void:
	if from_id[a] != from_id[b] and from_id[a] != to_id[b] and to_id[a] != from_id[b] \
			and to_id[a] != to_id[b]:
		pairs.append([a, b])


static func pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Rebuilds road `id` from its pulls, through each [x, z, tangent x, tangent z]
## in `through` in order.
func shape(id: String, through: Array) -> void:
	var source_id: String = from_id[id]
	var target_id: String = to_id[id]
	var ax: float = node_x[source_id]
	var az: float = node_z[source_id]
	var bx: float = node_x[target_id]
	var bz: float = node_z[target_id]
	var length: float = sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
	var chord_x: float = (bx - ax) / length
	var chord_z: float = (bz - az) / length
	var start: PackedFloat64Array = _unit(chord_x + _pull_start[id], chord_z)
	var finish: PackedFloat64Array = _unit(chord_x + _pull_end[id], chord_z)
	var xs: PackedFloat64Array = PackedFloat64Array([ax])
	var zs: PackedFloat64Array = PackedFloat64Array([az])
	var vias: Array = []
	var stops: Array = through.duplicate()
	stops.append([bx, bz])
	var short_legs: int = 0
	var from_x: float = ax
	var from_z: float = az
	for stop: Array in stops:
		if _is_join(from_x, from_z, _f(stop[0]), _f(stop[1])):
			short_legs += 1
		from_x = _f(stop[0])
		from_z = _f(stop[1])
	var long_legs: int = stops.size() - short_legs
	var steps: int = maxi(2, (SEGMENTS - short_legs) / long_legs)
	var spent: int = 0
	var tangent_x: float = start[0]
	var tangent_z: float = start[1]
	from_x = ax
	from_z = az
	for index: int in range(stops.size()):
		var stop_x: float = _f(stops[index][0])
		var stop_z: float = _f(stops[index][1])
		var last: bool = index == stops.size() - 1
		var leg: int = SEGMENTS - spent
		if not last:
			leg = 1 if _is_join(from_x, from_z, stop_x, stop_z) else steps
		var end_x: float = finish[0] if last else _f(stops[index][2])
		var end_z: float = finish[1] if last else _f(stops[index][3])
		_hermite(xs, zs, from_x, from_z, tangent_x, tangent_z, stop_x, stop_z,
			end_x, end_z, leg)
		spent += leg
		if not last:
			vias.append(xs.size() - 1)
		from_x = stop_x
		from_z = stop_z
		tangent_x = end_x
		tangent_z = end_z
	lines_x[id] = xs
	lines_z[id] = zs
	_vias[id] = vias


## Appends the points after (ax, az) of the cubic to (bx, bz) with unit end
## tangents (t0) and (t1).
static func _hermite(xs: PackedFloat64Array, zs: PackedFloat64Array, ax: float,
		az: float, t0x: float, t0z: float, bx: float, bz: float, t1x: float,
		t1z: float, steps: int) -> void:
	var reach: float = sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az)) / 3.0
	var p1x: float = ax + t0x * reach
	var p1z: float = az + t0z * reach
	var p2x: float = bx - t1x * reach
	var p2z: float = bz - t1z * reach
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		var w0: float = u * u * u
		var w1: float = 3.0 * u * u * t
		var w2: float = 3.0 * u * t * t
		var w3: float = t * t * t
		xs.append(w0 * ax + w1 * p1x + w2 * p2x + w3 * bx)
		zs.append(w0 * az + w1 * p1z + w2 * p2z + w3 * bz)


## True when two stops are one join apart: the points either side of a crossing.
static func _is_join(ax: float, az: float, bx: float, bz: float) -> bool:
	return (bx - ax) * (bx - ax) + (bz - az) * (bz - az) < JOIN_M * JOIN_M


static func _unit(x: float, z: float) -> PackedFloat64Array:
	var length: float = sqrt(x * x + z * z)
	return PackedFloat64Array([x / length, z / length])


## Roads leaving one node that stand closer than `FAN_PX` apart at the branch
## sample distance, projected on the phone at the farthest zoom, lean towards
## their chords until they part (or the straight chord is reached).
func _spread_branches() -> void:
	var leaving: Dictionary = {}
	for id: String in ids:
		if not leaving.has(from_id[id]):
			leaving[from_id[id]] = []
		leaving[from_id[id]].append(id)
	for node_id: String in MapLayoutCanonical.sorted_keys(leaving):
		var roads: Array = leaving[node_id]
		for i: int in range(roads.size()):
			for j: int in range(i + 1, roads.size()):
				var a: String = roads[i]
				var b: String = roads[j]
				for pull: float in FAN_PULLS:
					if _branch_gap(a, b) >= FAN_PX:
						break
					_pull_start[a] = minf(_pull_start[a], pull)
					_pull_start[b] = minf(_pull_start[b], pull)
					shape(a, [])
					shape(b, [])


## Projected distance (px) between two roads at the branch sample distance.
func _branch_gap(a: String, b: String) -> float:
	var at_a: PackedFloat64Array = _point_at(a, _sample_m)
	var at_b: PackedFloat64Array = _point_at(b, _sample_m)
	var along: float = (at_a[0] - at_b[0]) * MapLayoutFastSeating.FAR_PX_PER_M
	var across: float = (at_a[1] - at_b[1]) * MapLayoutFastSeating.FAR_PX_PER_M_LANE
	return sqrt(along * along + across * across)


## The point `distance` along road `id`, as [x, z].
func _point_at(id: String, distance: float) -> PackedFloat64Array:
	var xs: PackedFloat64Array = lines_x[id]
	var zs: PackedFloat64Array = lines_z[id]
	var remaining: float = distance
	for i: int in range(xs.size() - 1):
		var dx: float = xs[i + 1] - xs[i]
		var dz: float = zs[i + 1] - zs[i]
		var length: float = sqrt(dx * dx + dz * dz)
		if remaining <= length:
			var t: float = remaining / maxf(length, EPSILON)
			return PackedFloat64Array([xs[i] + dx * t, zs[i] + dz * t])
		remaining -= length
	return PackedFloat64Array([xs[xs.size() - 1], zs[zs.size() - 1]])


func path_length(id: String) -> float:
	var xs: PackedFloat64Array = lines_x[id]
	var zs: PackedFloat64Array = lines_z[id]
	var total: float = 0.0
	for i: int in range(xs.size() - 1):
		var dx: float = xs[i + 1] - xs[i]
		var dz: float = zs[i + 1] - zs[i]
		total += sqrt(dx * dx + dz * dz)
	return total


## True when the measured bounds of two roads, each grown by `margin`, overlap.
func boxes_meet(a: String, b: String, margin: float) -> bool:
	var box_a: PackedFloat64Array = _boxes[a]
	var box_b: PackedFloat64Array = _boxes[b]
	return box_a[0] <= box_b[2] + margin and box_b[0] <= box_a[2] + margin \
		and box_a[1] <= box_b[3] + margin and box_b[1] <= box_a[3] + margin


## Measures every road's bounds as [min x, min z, max x, max z].
func measure() -> void:
	for id: String in ids:
		var xs: PackedFloat64Array = lines_x[id]
		var zs: PackedFloat64Array = lines_z[id]
		var box: PackedFloat64Array = PackedFloat64Array([INF, INF, -INF, -INF])
		for i: int in range(xs.size()):
			box[0] = minf(box[0], xs[i])
			box[1] = minf(box[1], zs[i])
			box[2] = maxf(box[2], xs[i])
			box[3] = maxf(box[3], zs[i])
		_boxes[id] = box


## Bumps every road off the waystones it does not serve and off every road it
## does not cross or share a node with, `PASSES` times or until nothing moves.
func _clear_obstacles() -> void:
	for _pass: int in range(PASSES):
		var moved: bool = false
		measure()
		for id: String in ids:
			moved = _clear_nodes(id) or moved
		for pair: Array in pairs:
			if not _crossing.has(pair_key(pair[0], pair[1])):
				moved = _clear_pair(pair[0], pair[1]) or moved
		if not moved:
			break


## Bumps road `id` out of the corridor of each waystone near it that it does
## not serve. Returns true when a point moved.
func _clear_nodes(id: String) -> bool:
	var xs: PackedFloat64Array = lines_x[id]
	var zs: PackedFloat64Array = lines_z[id]
	var moved: bool = false
	for node_id: String in _near[id]:
		var cx: float = node_x[node_id]
		var cz: float = node_z[node_id]
		var box: PackedFloat64Array = _boxes[id]
		var margin: float = _node_reach + BOX_SLACK_M
		if box[0] > cx + _half_x + margin or box[2] < cx - _half_x - margin \
				or box[1] > cz + _half_z + margin or box[3] < cz - _half_z - margin:
			continue
		for i: int in range(1, xs.size() - 1):
			var nearest_x: float = clampf(xs[i], cx - _half_x, cx + _half_x)
			var nearest_z: float = clampf(zs[i], cz - _half_z, cz + _half_z)
			var away_x: float = xs[i] - nearest_x
			var away_z: float = zs[i] - nearest_z
			var distance: float = sqrt(away_x * away_x + away_z * away_z)
			if distance >= _node_reach:
				continue
			if distance < EPSILON:
				away_x = xs[i] - cx
				away_z = zs[i] - cz
				distance = sqrt(away_x * away_x + away_z * away_z)
				if distance < EPSILON:
					away_x = 0.0
					away_z = 1.0
					distance = 1.0
			var push: float = (_node_reach - distance) / distance
			_bump(id, i, away_x * push, away_z * push)
			xs = lines_x[id]
			zs = lines_z[id]
			moved = true
	return moved


## Bumps two roads apart when they pass closer than the corridor allows.
## Returns true when a point moved.
func _clear_pair(a: String, b: String) -> bool:
	if not boxes_meet(a, b, _road_gap + BOX_SLACK_M):
		return false
	var near: PackedFloat64Array = _nearest(a, b)
	if near.is_empty():
		return false
	var away_x: float = near[3] - near[5]
	var away_z: float = near[4] - near[6]
	var distance: float = sqrt(away_x * away_x + away_z * away_z)
	if distance < EPSILON:
		return false
	var push: float = (_road_gap - distance) / distance
	var index_a: int = int(near[1]) + (1 if near[2] > 0.5 else 0)
	var index_b: int = int(near[7]) + (1 if near[8] > 0.5 else 0)
	var movable_a: bool = index_a > 0 and index_a < lines_x[a].size() - 1
	var movable_b: bool = index_b > 0 and index_b < lines_x[b].size() - 1
	if not movable_a and not movable_b:
		return false
	var share_a: float = SHARE if movable_b else 2.0 * SHARE
	var share_b: float = SHARE if movable_a else 2.0 * SHARE
	if movable_a:
		_bump(a, index_a, away_x * push * share_a, away_z * push * share_a)
	if movable_b:
		_bump(b, index_b, -away_x * push * share_b, -away_z * push * share_b)
	return true


## The closest approach of two roads when it is nearer than the corridor, as
## [distance, segment of a, along it, x of a, z of a, x of b, z of b, segment of
## b, along it]; [] when no two segments come that close.
func _nearest(a: String, b: String) -> PackedFloat64Array:
	var axs: PackedFloat64Array = lines_x[a]
	var azs: PackedFloat64Array = lines_z[a]
	var bxs: PackedFloat64Array = lines_x[b]
	var bzs: PackedFloat64Array = lines_z[b]
	var best: PackedFloat64Array = PackedFloat64Array()
	var limit: float = _road_gap
	for i: int in range(axs.size() - 1):
		var a_low_x: float = minf(axs[i], axs[i + 1]) - limit
		var a_high_x: float = maxf(axs[i], axs[i + 1]) + limit
		var a_low_z: float = minf(azs[i], azs[i + 1]) - limit
		var a_high_z: float = maxf(azs[i], azs[i + 1]) + limit
		for j: int in range(bxs.size() - 1):
			if maxf(bxs[j], bxs[j + 1]) < a_low_x or minf(bxs[j], bxs[j + 1]) > a_high_x \
					or maxf(bzs[j], bzs[j + 1]) < a_low_z \
					or minf(bzs[j], bzs[j + 1]) > a_high_z:
				continue
			var closest: PackedFloat64Array = _closest(axs[i], azs[i], axs[i + 1],
				azs[i + 1], bxs[j], bzs[j], bxs[j + 1], bzs[j + 1])
			if closest[0] < limit:
				limit = closest[0]
				best = PackedFloat64Array([closest[0], float(i), closest[1],
					closest[3], closest[4], closest[5], closest[6], float(j), closest[2]])
	return best


## The closest points of segments P (p1 to q1) and Q (p2 to q2), as [distance,
## along P, along Q, P's x, P's z, Q's x, Q's z].
static func _closest(p1x: float, p1z: float, q1x: float, q1z: float, p2x: float,
		p2z: float, q2x: float, q2z: float) -> PackedFloat64Array:
	var d1x: float = q1x - p1x
	var d1z: float = q1z - p1z
	var d2x: float = q2x - p2x
	var d2z: float = q2z - p2z
	var rx: float = p1x - p2x
	var rz: float = p1z - p2z
	var a: float = d1x * d1x + d1z * d1z
	var e: float = d2x * d2x + d2z * d2z
	var f: float = d2x * rx + d2z * rz
	var s: float = 0.0
	var t: float = 0.0
	if a > EPSILON:
		var c: float = d1x * rx + d1z * rz
		if e <= EPSILON:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1x * d2x + d1z * d2z
			var denominator: float = a * e - b * b
			if denominator > EPSILON:
				s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	elif e > EPSILON:
		t = clampf(f / e, 0.0, 1.0)
	var cx: float = p1x + d1x * s
	var cz: float = p1z + d1z * s
	var ox: float = p2x + d2x * t
	var oz: float = p2z + d2z * t
	return PackedFloat64Array([sqrt((cx - ox) * (cx - ox) + (cz - oz) * (cz - oz)),
		s, t, cx, cz, ox, oz])


## Moves point `index` of road `id` by (dx, dz) and its neighbours by less,
## sparing the anchors and the points where the road passes through another's
## middle.
func _bump(id: String, index: int, dx: float, dz: float) -> void:
	var xs: PackedFloat64Array = lines_x[id]
	var zs: PackedFloat64Array = lines_z[id]
	var spared: Array = _vias[id]
	for k: int in range(BUMP.size()):
		var at: int = index + k - 2
		if at < 1 or at > xs.size() - 2 or spared.has(at):
			continue
		xs[at] += dx * BUMP[k]
		zs[at] += dz * BUMP[k]
	lines_x[id] = xs
	lines_z[id] = zs


## The unit vector from road `id`'s first node to its last.
func chord(id: String) -> PackedFloat64Array:
	return _unit(node_x[to_id[id]] - node_x[from_id[id]],
		node_z[to_id[id]] - node_z[from_id[id]])


## The roads as the layout result's edges, all on the ground.
func _edges() -> Dictionary:
	var edges: Dictionary = {}
	for id: String in ids:
		var xs: PackedFloat64Array = lines_x[id]
		var zs: PackedFloat64Array = lines_z[id]
		var line: Array = [_anchors[from_id[id]].duplicate()]
		for i: int in range(1, xs.size() - 1):
			line.append([xs[i], 0.0, zs[i]])
		line.append(_anchors[to_id[id]].duplicate())
		edges[id] = {"from": from_id[id], "to": to_id[id], "centerline": line,
			"corridor_width": width}
	return edges


static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
