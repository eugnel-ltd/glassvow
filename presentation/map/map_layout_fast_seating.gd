class_name MapLayoutFastSeating
extends RefCounted
## Where the fast layout stands each waystone.
##
## A node starts on its authored lattice seat (row and column plus the run's own
## jitter). A seat that a hero's keep-out box claims, or that a ravine would hold
## on a pier, steps to the nearest point of a fixed grid over the node's legal
## envelope that is open. Then every pair of nearby waystones is pushed apart,
## inside the two envelopes and never onto a closed point, until they clear each
## other at the farthest zoom on the phone, the tightest the map is drawn. A
## second sweep lets a pair that a ravine's banks left on top of each other use
## the ravine too: a waystone on a pier reads better than two on one another.
##
## The work is bounded: a fixed grid per displaced node and a fixed number of
## sweeps over a fixed set of neighbouring pairs. There is no search and no
## failure mode. Only IEEE arithmetic and square roots are used, so the same
## input seats the same nodes on every device.

## Fractions of a displaced node's legal envelope, per axis.
const STEP_GRID: int = 7
## The farthest zoom stop (28 m) on the shortest shipping stage (phone, 390 px)
## is the tightest the map is drawn: 390 / 28 = 13.93 px per metre along the
## journey (+X) and 13.93 x sin 40 degrees = 8.95 px per metre across it, under
## the 40 degree tilt. Literals rather than computed values so no transcendental
## enters the geometry; tests/test_map_layout_fast.gd holds them to the registry.
const FAR_PX_PER_M: float = 13.928571428571429
const FAR_PX_PER_M_LANE: float = 8.953113134919654
## Two waystone inks (28 px x 0.92 scale each) plus the 8 px ink clearance, and
## the side of one hit region (the ink's diameter, above the 44 px floor), each
## with a little headroom.
const INK_PITCH_PX: float = 60.0
const TOUCH_PITCH_PX: float = 52.0
## Spacing sweeps over every pair of nearby waystones, at most. Seven lanes
## settle well inside this.
const SWEEPS: int = 24
## A sweep must push less than this share of the one before to be worth another.
const HEADWAY: float = 0.9
## The least spacing push worth making (m): the chains of waystones that settle
## by ever smaller pushes stop here, well inside the headroom of the pitches.
const MOVE_EPSILON_M: float = 0.02
## Halvings of a spacing push that would land a waystone on a closed point.
const HALVINGS: int = 3
## How much further than a pier's margin a waystone keeps from a ravine, so a
## single-precision anchor never rounds back inside it.
const RAVINE_HEADROOM_M: float = 0.05
## 1 / tan(40 degrees), the camera tilt: the ground behind a landmark (-Z) that
## each metre of its height covers on screen. A literal for the same reason as
## `FAR_PX_PER_M_LANE`; the test holds it to `MapCameraRig.TILT_DEGREES`.
const COT_TILT: float = 1.19175359259421

var _ids: PackedStringArray = PackedStringArray()
var _rows: PackedInt32Array = PackedInt32Array()
var _base_x: PackedFloat64Array = PackedFloat64Array()
var _base_y: PackedFloat64Array = PackedFloat64Array()
var _base_z: PackedFloat64Array = PackedFloat64Array()
var _min_x: PackedFloat64Array = PackedFloat64Array()
var _max_x: PackedFloat64Array = PackedFloat64Array()
var _min_z: PackedFloat64Array = PackedFloat64Array()
var _max_z: PackedFloat64Array = PackedFloat64Array()
## Per node, the keep-out boxes that apply to it, flattened as
## [low x, low z, high x, high z, ...].
var _boxes: Array[PackedFloat64Array] = []
var _half: Vector2 = Vector2.ZERO
var _x: PackedFloat64Array = PackedFloat64Array()
var _z: PackedFloat64Array = PackedFloat64Array()
var _status: PackedStringArray = PackedStringArray()
## Whether `_open` keeps waystones off the ravine. Spacing keeps them off first,
## then gives way where a pair would otherwise stay on top of each other.
var _ravine_guard: bool = true


## `bounds` is `MapQualityEvaluator.node_candidate_bounds`; `half` the node's
## pair rectangle half extent.
func _init(nodes: Array, bounds: Dictionary, source: Dictionary, quality: Dictionary,
		assets: Dictionary, half: Vector2) -> void:
	_half = half
	var zones: Array[Dictionary] = zones_of(source, quality, assets)
	var ordered: Array = nodes.duplicate()
	ordered.sort_custom(_by_seat)
	for node: Dictionary in ordered:
		var id: String = str(node["id"])
		var limit: Dictionary = bounds[id]
		var base: Vector3 = limit["base"]
		_ids.append(id)
		_rows.append(MapLayoutCanonical.int_value(node["row"]))
		_base_x.append(base.x)
		_base_y.append(base.y)
		_base_z.append(base.z)
		_min_x.append(_f(limit["min_x"]))
		_max_x.append(_f(limit["max_x"]))
		_min_z.append(_f(limit["min_z"]))
		_max_z.append(_f(limit["max_z"]))
		var boxes: PackedFloat64Array = PackedFloat64Array()
		for zone: Dictionary in zones:
			if not exempt(str(node["type"]), str(zone["role"])):
				var lo: Vector2 = zone["lo"]
				var hi: Vector2 = zone["hi"]
				boxes.append_array([lo.x, lo.y, hi.x, hi.y])
		_boxes.append(boxes)
	_x = _base_x.duplicate()
	_z = _base_z.duplicate()
	_status.resize(_ids.size())
	_status.fill("authored")


## Where every node stands, by node ID: `anchor`, `status` (authored, spaced,
## displaced or unresolved) and `displacement_m` from its authored seat. A node
## whose envelope is a single point (boss, entrance) never moves.
func seat() -> Dictionary:
	for i: int in range(_ids.size()):
		if _open(i, _x[i], _z[i]):
			continue
		var spot: Array = _nearest_open(i)
		if spot.is_empty():
			_status[i] = "unresolved"
			continue
		_x[i] = _f(spot[0])
		_z[i] = _f(spot[1])
		_status[i] = "displaced"
	_space()
	_ravine_guard = false
	_space()
	var out: Dictionary = {}
	for i: int in range(_ids.size()):
		var dx: float = _x[i] - _base_x[i]
		var dz: float = _z[i] - _base_z[i]
		out[_ids[i]] = {"status": _status[i], "anchor": [_x[i], _base_y[i], _z[i]],
			"displacement_m": sqrt(dx * dx + dz * dz)}
	return out


## The nearest point of a fixed grid over node `i`'s legal envelope that is
## open, as [x, z], or [] when no grid point is. The first grid point in index
## order wins a tie.
func _nearest_open(i: int) -> Array:
	var best: Array = []
	var best_cost: float = INF
	for u: int in range(STEP_GRID):
		var x: float = _min_x[i] + (_max_x[i] - _min_x[i]) * float(u) / float(STEP_GRID - 1)
		for v: int in range(STEP_GRID):
			var z: float = _min_z[i] + (_max_z[i] - _min_z[i]) * float(v) / float(STEP_GRID - 1)
			var dx: float = x - _base_x[i]
			var dz: float = z - _base_z[i]
			var cost: float = dx * dx + dz * dz
			if cost < best_cost and _open(i, x, z):
				best = [x, z]
				best_cost = cost
	return best


## Node `i` may stand at (x, z) when no hero's keep-out box claims its pair
## rectangle and, while the ravine guard stands, no ravine would hold its
## waystone on a pier.
func _open(i: int, x: float, z: float) -> bool:
	var boxes: PackedFloat64Array = _boxes[i]
	for k: int in range(0, boxes.size(), 4):
		if x + _half.x > boxes[k] and x - _half.x < boxes[k + 2] \
				and z + _half.y > boxes[k + 1] and z - _half.y < boxes[k + 3]:
			return false
	return not _ravine_guard \
		or not MapRavine.holds(x, z, MapRavine.PIER_MARGIN + RAVINE_HEADROOM_M)


## Pushes every nearby pair of waystones apart until they are `_spaced`, or the
## sweeps stop making headway (a chain that a ravine's banks leave no room for
## only trades pushes back and forth). A pair is two nodes in the same or
## adjacent rows, taken in seat order, so a sweep is a fixed walk.
func _space() -> void:
	var previous: float = INF
	for _sweep: int in range(SWEEPS):
		var pushed: float = 0.0
		for i: int in range(_ids.size()):
			for j: int in range(i + 1, _ids.size()):
				if _rows[j] - _rows[i] > 1:
					break
				pushed += _separate(i, j)
		if pushed == 0.0 or pushed > previous * HEADWAY:
			break
		previous = pushed


## One push on a pair that is not yet `_spaced`; `j` follows `i` in seat order.
## The pair moves along the lane axis or the journey axis, whichever fits inside
## the two envelopes with the smaller move (or, when neither fits, the one with
## more room), each node taking half and the other what it could not. Returns
## the distance (m) the pair was pushed apart, 0 when it needed no push.
func _separate(i: int, j: int) -> float:
	var dx: float = absf(_x[j] - _x[i])
	var dz: float = absf(_z[j] - _z[i])
	if _spaced(dx, dz):
		return 0.0
	var lane_up: float = -1.0 if _z[j] < _z[i] else 1.0
	var lane_need: float = _lane_pitch(dx) - dz
	var lane_room: float = _room(i, true, -lane_up) + _room(j, true, lane_up)
	var row_up: float = -1.0 if _x[j] < _x[i] else 1.0
	var row_need: float = _row_pitch(dz) - dx
	var row_room: float = _room(i, false, -row_up) + _room(j, false, row_up)
	var on_lane: bool = lane_room >= row_room
	if lane_need <= lane_room and row_need <= row_room:
		on_lane = lane_need <= row_need
	elif lane_need <= lane_room or row_need <= row_room:
		on_lane = lane_need <= lane_room
	var shift: float = minf(lane_need, lane_room) if on_lane else minf(row_need, row_room)
	if shift <= MOVE_EPSILON_M:
		return 0.0
	var up: float = lane_up if on_lane else row_up
	var down_share: float = minf(shift * 0.5, _room(i, on_lane, -up))
	var up_share: float = minf(shift - down_share, _room(j, on_lane, up))
	down_share = minf(shift - up_share, _room(i, on_lane, -up))
	var moved_i: float = _nudge(i, on_lane, -up * down_share)
	var moved_j: float = _nudge(j, on_lane, up * up_share)
	return moved_i + moved_j


## How far node `i` can still move along the lane (z) or journey (x) axis in
## `direction` (+1 or -1) before it leaves its legal envelope.
func _room(i: int, on_lane: bool, direction: float) -> float:
	var at: float = _z[i] if on_lane else _x[i]
	if direction > 0.0:
		return maxf(0.0, (_max_z[i] if on_lane else _max_x[i]) - at)
	return maxf(0.0, at - (_min_z[i] if on_lane else _min_x[i]))


## Moves node `i` along the lane or journey axis by `delta`, or by the largest
## of its successive halves that leaves it open. Returns the distance moved.
func _nudge(i: int, on_lane: bool, delta: float) -> float:
	var step: float = delta
	for _halving: int in range(HALVINGS + 1):
		if step == 0.0:
			return 0.0
		var x: float = _x[i] + (0.0 if on_lane else step)
		var z: float = _z[i] + (step if on_lane else 0.0)
		if _open(i, x, z):
			_x[i] = x
			_z[i] = z
			if _status[i] == "authored":
				_status[i] = "spaced"
			return absf(step)
		step *= 0.5
	return 0.0


## Journey order, then lane, then ID: the one order every sweep follows.
static func _by_seat(a: Dictionary, b: Dictionary) -> bool:
	var row_a: int = MapLayoutCanonical.int_value(a["row"])
	var row_b: int = MapLayoutCanonical.int_value(b["row"])
	if row_a != row_b:
		return row_a < row_b
	var col_a: int = MapLayoutCanonical.int_value(a["col"])
	var col_b: int = MapLayoutCanonical.int_value(b["col"])
	return col_a < col_b or (col_a == col_b and str(a["id"]) < str(b["id"]))


## True when two waystones this far apart (metres, along the journey and across
## it) clear each other at the farthest zoom on the phone: the inks keep their
## clearance and the hit regions do not overlap.
static func _spaced(dx: float, dz: float) -> bool:
	var along: float = dx * FAR_PX_PER_M
	var across: float = dz * FAR_PX_PER_M_LANE
	return along * along + across * across >= INK_PITCH_PX * INK_PITCH_PX \
		and (along >= TOUCH_PITCH_PX or across >= TOUCH_PITCH_PX)


## The least lane gap (m) that spaces two waystones `dx` apart along the journey.
static func _lane_pitch(dx: float) -> float:
	var along: float = dx * FAR_PX_PER_M
	var ink: float = sqrt(maxf(0.0, INK_PITCH_PX * INK_PITCH_PX - along * along))
	return (ink if along >= TOUCH_PITCH_PX else maxf(ink, TOUCH_PITCH_PX)) \
		/ FAR_PX_PER_M_LANE


## The least journey gap (m) that spaces two waystones `dz` apart across it.
static func _row_pitch(dz: float) -> float:
	var across: float = dz * FAR_PX_PER_M_LANE
	var ink: float = sqrt(maxf(0.0, INK_PITCH_PX * INK_PITCH_PX - across * across))
	return (ink if across >= TOUCH_PITCH_PX else maxf(ink, TOUCH_PITCH_PX)) \
		/ FAR_PX_PER_M


## The same exemptions the compiler's candidate rules grant: the boss stands at
## its terminus and the entrance at the Vigil by design.
static func exempt(node_type: String, role: String) -> bool:
	return (node_type == "boss" and role == "terminus") \
		or (node_type in ["act4", "entrance"] and role == "vigil")


## Each hero's keep-out box: its protected zone grown by the governed padding,
## and stretched away from the camera (-Z) over the ground its silhouette covers
## on screen, so no waystone stands hidden behind a tall landmark. A box is
## stricter than the polygon, and comparing input numbers directly keeps the
## decision identical on every device.
static func zones_of(source: Dictionary, quality: Dictionary,
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
			var row: Array = point_v
			var point: Vector2 = Vector2(_f(row[0]), _f(row[1]))
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


static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
