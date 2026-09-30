class_name MapLayoutFast
extends RefCounted
## The production world layout: bounded, search-free and deterministic.
##
## Every node stands on its authored lattice seat (row and column plus the
## run's own jitter, the same seat the compiler's first candidate proposes).
## Same-row neighbours that the jitter crowds are pushed apart along the lane
## axis, inside their own legal envelopes, until their waystones clear at the
## default zoom on the phone. A seat that would stand inside a hero's protected
## zone steps to the nearest point of a fixed grid over its own legal envelope
## that clears every zone.
##
## Every edge is one gently curved road: a cubic that leaves and arrives
## halfway between the chord and the journey axis, so roads fanning into one
## node meet only at its seal. Where two roads between the same two rows cross,
## one rises over the other on a bridge deck.
##
## The work is bounded: a fixed number of lane sweeps per row, a fixed grid per
## displaced node and one crossing test per pair of roads leaving the same row.
## There is no search, no retry and no failure mode for a valid input. The
## geometry uses only IEEE arithmetic and square roots, never a transcendental
## function, so the same canonical input gives the same result digest on every
## device.
##
## Map Compiler v2 (`MapLayoutCompiler`) remains available as an authoring
## opt-in through `MapLayoutPolicy`; see docs/map/production-layout.md.

const COMPILED: String = MapLayoutCompiler.COMPILED
const SCHEMA: String = "map-fast-layout-v1"
const VERSION: String = "map-layout-fast-v1"
const SELECTED_CANDIDATE_ID: String = "fast/authored-lattice"
## Segments per road. Enough for the curve to read as a curve at the closest
## zoom; each extra point costs every scenery candidate one more segment test.
const ROUTE_SEGMENTS: int = 10
## Fractions of a displaced node's legal envelope, per axis.
const STEP_GRID: int = 7
## Least lane-axis (z) distance between same-row neighbours. Two waystone inks
## (28 px x 0.92 scale each) plus the 8 px ink clearance, on the shortest
## shipping stage (phone, 390 px) at the default zoom stop (20 m) under the 40
## degree tilt: 59.52 px / (19.5 px/m x sin 40) = 4.75 m. A constant rather than
## a computed value so no transcendental enters the geometry;
## tests/test_map_layout_fast.gd holds it to the registry.
const LANE_GAP_M: float = 4.75
## The same clearance along the journey axis, which the camera does not
## foreshorten: 59.52 px / 19.5 px/m = 3.05 m. Adjacent rows stand 5.14 m apart
## and their jitter cannot bring them nearer than 3.08 m, so only a node pushed
## off its seat by a landmark needs this.
const ROW_GAP_M: float = 3.06
## Weight of the journey axis (+X) against the chord in a road's end tangents:
## 1 bisects them. Heavier leaves and arrives more along the journey and bends
## harder between rows; lighter tends to the straight chord.
const ROAD_AXIS_PULL: float = 1.0
## 1 / tan(40 degrees), the camera tilt: the ground behind a landmark (-Z)
## that each metre of its height covers on screen. A literal for the same reason
## as `LANE_GAP_M`; the test holds it to `MapCameraRig.TILT_DEGREES`.
const COT_TILT: float = 1.19175359259421
## Deck height where one road bridges another: the governed two-level
## clearance (`MapGradeSeparation.MINIMUM_VERTICAL_CLEARANCE_M`, 0.384 m) with
## headroom. The renderer draws bridge masonry wherever a road stands above
## 0.15 m.
const BRIDGE_DECK_M: float = 0.45
## Relaxation sweeps along one row. Seven lanes settle well inside this.
const LANE_SWEEPS: int = 8

@warning_ignore_start("unsafe_call_argument")


static func compile(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = {
		"schema_version": 1, "version": VERSION,
		"input_digest": "" if input == null else input.digest(),
		"spaced_nodes": [], "displaced_nodes": {}, "unresolved_nodes": [],
		"bridges": [],
	}
	if input == null:
		return _failure(diagnostics, "input", "validated input is null")
	var source: Dictionary = input.to_dict()
	var nodes: Array = input.node_records()
	var edge_rows: Array = input.edge_records()
	var bounds: Dictionary = MapQualityEvaluator.node_candidate_bounds(
		nodes, edge_rows, quality)
	var zones: Array[Dictionary] = _zones(source, quality, assets)
	var half: Vector2 = _v2(quality["calibration"]["shipping_touch_waystone"][
		"node_pair_half_extent_m"])
	var lanes: Dictionary = _spaced_lanes(nodes, bounds)
	# Where every node stands so far: spaced seats, replaced as nodes are seated.
	var seats: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var authored: Vector3 = bounds[node_id]["base"]
		seats[node_id] = Vector2(authored.x, lanes[node_id])
	var anchors: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var seat: Dictionary = _seat(node, bounds[node_id], lanes[node_id], zones,
			half, seats)
		anchors[node_id] = seat["anchor"]
		seats[node_id] = Vector2(_f(seat["anchor"][0]), _f(seat["anchor"][2]))
		if seat["status"] == "spaced":
			diagnostics["spaced_nodes"].append(node_id)
		elif seat["status"] == "displaced":
			diagnostics["displaced_nodes"][node_id] = seat["displacement_m"]
		elif seat["status"] == "unresolved":
			diagnostics["unresolved_nodes"].append(node_id)
	var width: float = 2.0 * _f(
		quality["geometry"]["road_corridor"]["physical_half_width_m"])
	var edges: Dictionary = {}
	for edge: Dictionary in edge_rows:
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		edges[str(edge["id"])] = {
			"from": from_id, "to": to_id,
			"centerline": _road(anchors[from_id], anchors[to_id]),
			"corridor_width": width,
		}
	_bridge_crossings(nodes, edges, diagnostics)
	var result: MapLayoutResult = MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": source["generator_version"],
		"node_anchors": MapLayoutCanonical.ordered_dictionary(anchors),
		"edges": MapLayoutCanonical.ordered_dictionary(edges),
		"hero_placements": _heroes(source),
		"scenery_instances": {},
		"hard_measurements": {},
		"soft_scores": {},
		"selected_restart_id": 0,
		"selected_candidate_id": SELECTED_CANDIDATE_ID,
		"input_digest": input.digest(),
	})
	if result == null:
		return _failure(diagnostics, "result_contract",
			"fast layout produced an invalid result")
	return {
		"status": COMPILED, "result": result, "report": {}, "failure": {},
		"diagnostics": MapLayoutCanonical.ordered_dictionary(diagnostics),
	}


## Lane coordinate (z) per node: the authored lane, with same-row neighbours
## nearer than `LANE_GAP_M` pushed apart evenly inside their own legal lane
## envelopes. Fixed nodes have a point envelope and never move.
static func _spaced_lanes(nodes: Array, bounds: Dictionary) -> Dictionary:
	var lanes: Dictionary = {}
	var rows: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var base: Vector3 = bounds[node_id]["base"]
		lanes[node_id] = base.z
		var row: int = MapLayoutCanonical.int_value(node["row"])
		if not rows.has(row):
			rows[row] = []
		rows[row].append(node)
	for row_nodes: Array in rows.values():
		row_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var col_a: int = MapLayoutCanonical.int_value(a["col"])
			var col_b: int = MapLayoutCanonical.int_value(b["col"])
			return col_a < col_b or (col_a == col_b and str(a["id"]) < str(b["id"])))
		for _sweep: int in range(LANE_SWEEPS):
			var moved: bool = false
			for i: int in range(row_nodes.size() - 1):
				var low_id: String = str(row_nodes[i]["id"])
				var high_id: String = str(row_nodes[i + 1]["id"])
				var low: float = lanes[low_id]
				var high: float = lanes[high_id]
				var need: float = LANE_GAP_M - (high - low)
				if need <= 0.0:
					continue
				var room_low: float = maxf(0.0, low - _f(bounds[low_id]["min_z"]))
				var room_high: float = maxf(0.0, _f(bounds[high_id]["max_z"]) - high)
				var down: float = minf(need * 0.5, room_low)
				var up: float = minf(need - down, room_high)
				down = minf(need - up, room_low)
				if down <= 0.0 and up <= 0.0:
					continue
				lanes[low_id] = low - down
				lanes[high_id] = high + up
				moved = true
			if not moved:
				break
	return lanes


## The spaced seat, or the nearest legal grid point that clears every hero
## zone, preferring one that also keeps its waystone clear of every other
## node's. Fixed nodes (boss, entrance) never move: their envelope is a point.
static func _seat(node: Dictionary, limit: Dictionary, lane: float,
		zones: Array[Dictionary], half: Vector2, seats: Dictionary) -> Dictionary:
	var authored: Vector3 = limit["base"]
	var base: Vector3 = Vector3(authored.x, authored.y, lane)
	var node_type: String = str(node["type"])
	if _clear(base.x, lane, node_type, zones, half):
		return {"status": "authored" if lane == authored.z else "spaced",
			"anchor": [base.x, base.y, lane], "displacement_m": 0.0}
	var min_x: float = _f(limit["min_x"])
	var max_x: float = _f(limit["max_x"])
	var min_z: float = _f(limit["min_z"])
	var max_z: float = _f(limit["max_z"])
	var node_id: String = str(node["id"])
	var best: Array = []
	var best_cost: float = INF
	for spaced: bool in [true, false]:
		for i: int in range(STEP_GRID):
			var x: float = min_x + (max_x - min_x) * float(i) / float(STEP_GRID - 1)
			for j: int in range(STEP_GRID):
				var z: float = min_z + (max_z - min_z) * float(j) / float(STEP_GRID - 1)
				var dx: float = x - base.x
				var dz: float = z - lane
				var cost: float = dx * dx + dz * dz
				# Strict: the first grid point in index order wins a tie.
				if cost < best_cost and _clear(x, z, node_type, zones, half) \
						and (not spaced or _apart(node_id, x, z, seats)):
					best = [x, base.y, z]
					best_cost = cost
		if not best.is_empty():
			break
	if best.is_empty():
		return {"status": "unresolved", "anchor": [base.x, base.y, lane],
			"displacement_m": 0.0}
	return {"status": "displaced", "anchor": best, "displacement_m": sqrt(best_cost)}


## True when a waystone at (x, z) keeps clear of every other node's at the
## default zoom on the phone: a full row gap along the journey or a full lane
## gap across it.
static func _apart(node_id: String, x: float, z: float, seats: Dictionary) -> bool:
	for other_id: String in seats:
		if other_id == node_id:
			continue
		var other: Vector2 = seats[other_id]
		if absf(other.x - x) < ROW_GAP_M and absf(other.y - z) < LANE_GAP_M:
			return false
	return true


## A node's pair rectangle stays outside each zone's bounding box grown by the
## zone's governed padding. A box is stricter than the polygon, and comparing
## input numbers directly keeps the decision identical on every device.
static func _clear(x: float, z: float, node_type: String,
		zones: Array[Dictionary], half: Vector2) -> bool:
	for zone: Dictionary in zones:
		if _exempt(node_type, str(zone["role"])):
			continue
		var lo: Vector2 = zone["lo"]
		var hi: Vector2 = zone["hi"]
		if x + half.x > lo.x and x - half.x < hi.x \
				and z + half.y > lo.y and z - half.y < hi.y:
			return false
	return true


## The same exemptions the compiler's candidate rules grant: the boss stands
## at its terminus and the entrance at the Vigil by design.
static func _exempt(node_type: String, role: String) -> bool:
	return (node_type == "boss" and role == "terminus") \
		or (node_type in ["act4", "entrance"] and role == "vigil")


## Each hero's keep-out box: its protected zone grown by the governed padding,
## and stretched away from the camera (-Z) over the ground its silhouette covers
## on screen, so no waystone stands hidden behind a tall landmark.
static func _zones(source: Dictionary, quality: Dictionary,
		assets: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var contract: Dictionary = source["hero_anchor_contract"]
	var zones: Dictionary = contract["protected_zones"]
	var anchors: Dictionary = contract["anchors"]
	var profiles: Dictionary = assets.get("profiles", {})
	var geometry: Dictionary = quality["geometry"]
	for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
		var zone: Dictionary = zones[zone_id]
		var role: String = str(zone.get("role", ""))
		var rule_id: String = "%s_protected_zone" % role
		var padding: float = _f(geometry[rule_id]["padding_m"]) \
			if geometry.has(rule_id) else 0.0
		var points: Array = zone["polygon"]
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		for point_v: Variant in points:
			var point: Vector2 = _v2(point_v)
			lo = Vector2(minf(lo.x, point.x), minf(lo.y, point.y))
			hi = Vector2(maxf(hi.x, point.x), maxf(hi.y, point.y))
		var reach: float = 0.0
		var anchor: Dictionary = anchors.get(role, {})
		var profile: Dictionary = profiles.get(str(anchor.get("profile_id", "")), {})
		if profile.has("grounded_height") and anchor.has("scale"):
			var scale: Array = anchor["scale"]
			reach = _f(profile["grounded_height"]) * _f(scale[1]) * COT_TILT
		out.append({"role": role, "lo": Vector2(lo.x - padding, lo.y - padding - reach),
			"hi": Vector2(hi.x + padding, hi.y + padding)})
	return out


## A cubic from `a` to `b` whose end tangents bisect the chord and the journey
## axis (+X). Endpoints are the anchors themselves, byte for byte.
static func _road(a_v: Variant, b_v: Variant) -> Array:
	var a: Array = a_v
	var b: Array = b_v
	var ax: float = _f(a[0])
	var ay: float = _f(a[1])
	var az: float = _f(a[2])
	var bx: float = _f(b[0])
	var by: float = _f(b[1])
	var bz: float = _f(b[2])
	var dx: float = bx - ax
	var dz: float = bz - az
	var length: float = sqrt(dx * dx + dz * dz)
	var points: Array = [a.duplicate()]
	if length <= 0.0:
		points.append(b.duplicate())
		return points
	var tx: float = dx / length + ROAD_AXIS_PULL
	var tz: float = dz / length
	var reach: float = length / (3.0 * sqrt(tx * tx + tz * tz))
	var p1x: float = ax + tx * reach
	var p1z: float = az + tz * reach
	var p2x: float = bx - tx * reach
	var p2z: float = bz - tz * reach
	for i: int in range(1, ROUTE_SEGMENTS):
		var t: float = float(i) / float(ROUTE_SEGMENTS)
		var u: float = 1.0 - t
		var w0: float = u * u * u
		var w1: float = 3.0 * u * u * t
		var w2: float = 3.0 * u * t * t
		var w3: float = t * t * t
		points.append([
			w0 * ax + w1 * p1x + w2 * p2x + w3 * bx,
			(w0 + w1) * ay + (w2 + w3) * by,
			w0 * az + w1 * p1z + w2 * p2z + w3 * bz,
		])
	points.append(b.duplicate())
	return points


## Two roads that leave the same row and share no node can cross. The one bound
## for a lower lane (else the later ID) is lifted over the other: level with its
## nodes at both ends, ramping linearly to `BRIDGE_DECK_M` one segment before
## the first crossing and back down one segment after the last.
static func _bridge_crossings(nodes: Array, edges: Dictionary,
		diagnostics: Dictionary) -> void:
	var rows: Dictionary = {}
	var cols: Dictionary = {}
	for node: Dictionary in nodes:
		rows[str(node["id"])] = MapLayoutCanonical.int_value(node["row"])
		cols[str(node["id"])] = MapLayoutCanonical.int_value(node["col"])
	var groups: Dictionary = {}
	var boxes: Dictionary = {}
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var row: int = rows[str(edges[edge_id]["from"])]
		if not groups.has(row):
			groups[row] = []
		groups[row].append(edge_id)
		boxes[edge_id] = _box(edges[edge_id]["centerline"])
	var lifts: Dictionary = {}
	var rows_in_order: Array = groups.keys()
	rows_in_order.sort()
	for row: int in rows_in_order:
		var ids: Array = groups[row]
		for i: int in range(ids.size()):
			var a: Dictionary = edges[ids[i]]
			for j: int in range(i + 1, ids.size()):
				var b: Dictionary = edges[ids[j]]
				if str(a["from"]) in [str(b["from"]), str(b["to"])] \
						or str(a["to"]) in [str(b["from"]), str(b["to"])] \
						or not _boxes_meet(boxes[ids[i]], boxes[ids[j]]):
					continue
				var hit: Array = _first_crossing(a["centerline"], b["centerline"])
				if hit.is_empty():
					continue
				var a_down: bool = cols[str(a["to"])] < cols[str(a["from"])]
				var b_down: bool = cols[str(b["to"])] < cols[str(b["from"])]
				var upper_is_a: bool = a_down if a_down != b_down else false
				var upper: String = str(ids[i]) if upper_is_a else str(ids[j])
				var lower: String = str(ids[j]) if upper_is_a else str(ids[i])
				if not lifts.has(upper):
					lifts[upper] = []
				lifts[upper].append(hit[0] if upper_is_a else hit[1])
				diagnostics["bridges"].append([upper, lower])
	for edge_id: String in MapLayoutCanonical.sorted_keys(lifts):
		_lift(edges[edge_id]["centerline"], lifts[edge_id])


## A polyline's XZ bounds as [min x, min z, max x, max z].
static func _box(line: Array) -> Array:
	var box: Array = [INF, INF, -INF, -INF]
	for point_v: Variant in line:
		var point: Array = point_v
		box = [minf(box[0], _f(point[0])), minf(box[1], _f(point[2])),
			maxf(box[2], _f(point[0])), maxf(box[3], _f(point[2]))]
	return box


static func _boxes_meet(a: Array, b: Array) -> bool:
	return _f(a[0]) <= _f(b[2]) and _f(b[0]) <= _f(a[2]) \
		and _f(a[1]) <= _f(b[3]) and _f(b[1]) <= _f(a[3])


## Where two polylines first cross, as [a's progress, b's progress] in 0..1 of
## their segment count, or [] when they do not. Scalar arithmetic only.
static func _first_crossing(a_line: Array, b_line: Array) -> Array:
	for i: int in range(a_line.size() - 1):
		var p: Array = a_line[i]
		var p2: Array = a_line[i + 1]
		var px: float = _f(p[0])
		var pz: float = _f(p[2])
		var rx: float = _f(p2[0]) - px
		var rz: float = _f(p2[2]) - pz
		for j: int in range(b_line.size() - 1):
			var q: Array = b_line[j]
			var q2: Array = b_line[j + 1]
			var qx: float = _f(q[0])
			var qz: float = _f(q[2])
			var sx: float = _f(q2[0]) - qx
			var sz: float = _f(q2[2]) - qz
			var denominator: float = rx * sz - rz * sx
			if denominator == 0.0:
				continue
			var u: float = ((qx - px) * sz - (qz - pz) * sx) / denominator
			var v: float = ((qx - px) * rz - (qz - pz) * rx) / denominator
			if u >= 0.0 and u <= 1.0 and v >= 0.0 and v <= 1.0:
				return [(float(i) + u) / float(a_line.size() - 1),
					(float(j) + v) / float(b_line.size() - 1)]
	return []


static func _lift(line: Array, crossings: Array) -> void:
	var step: float = 1.0 / float(line.size() - 1)
	var first: float = 1.0
	var last: float = 0.0
	for t_v: Variant in crossings:
		first = minf(first, _f(t_v))
		last = maxf(last, _f(t_v))
	var rise_end: float = maxf(first - step, step)
	var fall_start: float = minf(last + step, 1.0 - step)
	for i: int in range(1, line.size() - 1):
		var t: float = float(i) * step
		var height: float = BRIDGE_DECK_M * clampf(minf(t / rise_end,
			(1.0 - t) / (1.0 - fall_start)), 0.0, 1.0)
		var point: Array = line[i]
		line[i] = [point[0], _f(point[1]) + height, point[2]]


static func _heroes(source: Dictionary) -> Dictionary:
	var anchors: Dictionary = source["hero_anchor_contract"]["anchors"]
	var out: Dictionary = {}
	for anchor_id: String in MapLayoutCanonical.sorted_keys(anchors):
		var anchor: Dictionary = anchors[anchor_id]
		out[anchor_id] = {
			"asset_id": anchor["asset_id"], "profile_id": anchor["profile_id"],
			"transform": {
				"origin": anchor["position"], "yaw_radians": anchor["yaw_radians"],
				"scale": anchor["scale"],
			},
		}
	return MapLayoutCanonical.ordered_dictionary(out)


static func _failure(diagnostics: Dictionary, id: String, reason: String) -> Dictionary:
	return {
		"status": MapLayoutCompiler.NO_FEASIBLE_NODE_ROUTE_LAYOUT,
		"result": null, "report": {},
		"failure": {"kind": "fast_layout", "id": id, "reason": reason},
		"diagnostics": MapLayoutCanonical.ordered_dictionary(diagnostics),
	}


static func _v2(value: Variant) -> Vector2:
	var row: Array = value
	return Vector2(_f(row[0]), _f(row[1]))


static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
