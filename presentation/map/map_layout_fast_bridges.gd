class_name MapLayoutFastBridges
extends RefCounted
## Where two of the fast layout's roads cross: which one rises, where they cross
## and the deck that carries it.
##
## Of two roads that leave the same row and cross, the one bound for a lower
## lane (else the later ID) is the upper. The lower is routed through the middle
## of the upper, between two points a little either side so the crossing falls
## inside a segment of each, then moved once along the upper to the middle of
## the room the deck leaves, so its ramps have equal room. The upper then rises
## on the deck `MapGradeSeparation` governs: level with its nodes at both ends,
## a ramp up short of the whole corridor overlap and a ramp down past it. A
## crossing the governed span does not fit (a road too short for two ramps and
## the overlap) is lifted to a plain deck instead, which still reads as a bridge.
##
## Scalar arithmetic and square roots only, like the roads it reads.

## Deck height where a crossing's governed span does not fit: the renderer draws
## bridge masonry wherever a road stands above 0.15 m.
const FALLBACK_DECK_M: float = 0.45
## Half the length of the straight segment the lower road crosses by.
const CROSSING_HALF_M: float = 0.25
## A crossing keeps this fraction of a segment from its ends.
const SEGMENT_INSET: float = 0.15
## The most a crossing moves along the upper road when centred (m), and the move
## below which it is left where it is.
const CENTRE_LIMIT_M: float = 1.5
const CENTRE_TOLERANCE_M: float = 0.05

@warning_ignore_start("unsafe_call_argument")

var _roads: MapLayoutFastRoads = null


func _init(roads: MapLayoutFastRoads) -> void:
	_roads = roads


## The crossings between roads leaving the same row, as `upper`, `lower` and
## `at`: where along the upper's points (0 to 1) they first meet.
func find() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_roads.measure()
	for pair: Array in _roads.pairs:
		var a: String = pair[0]
		var b: String = pair[1]
		if _roads.rows[a] != _roads.rows[b] or not _roads.boxes_meet(a, b, 0.0):
			continue
		var hit: Array = _first_crossing(a, b)
		if hit.is_empty():
			continue
		var upper_is_a: bool = _roads.downs[a] if _roads.downs[a] != _roads.downs[b] else false
		out.append({"upper": a if upper_is_a else b, "lower": b if upper_is_a else a,
			"at": _f(hit[0]) if upper_is_a else _f(hit[1])})
	return out


## Routes each lower road through the middle of its upper road, then moves the
## crossing once to the middle of the room the deck leaves.
func route_through(crossings: Array[Dictionary]) -> void:
	for crossing: Dictionary in crossings:
		crossing["s"] = _roads.path_length(str(crossing["upper"])) * 0.5
	_reroute(crossings)
	var moved: bool = false
	for crossing: Dictionary in crossings:
		var shift: float = _centring(crossing)
		crossing["s"] = _f(crossing["s"]) + shift
		moved = moved or absf(shift) > CENTRE_TOLERANCE_M
	if moved:
		_reroute(crossings)


## Lifts the upper road of each crossing in `edges` (the roads as the layout
## result's edges) over its lower, and returns the crossings as [upper, lower]
## edge ID pairs.
func span(edges: Dictionary, crossings: Array[Dictionary]) -> Array:
	var bridges: Array = []
	var spans: Dictionary = {}
	var fallbacks: Dictionary = {}
	for crossing: Dictionary in crossings:
		var upper: String = crossing["upper"]
		var lower: String = crossing["lower"]
		bridges.append([upper, lower])
		var option: Dictionary = MapGradeSeparation.span_option(upper, edges[upper],
			lower, edges[lower])
		if option.get("ok", false) == true:
			if not spans.has(upper):
				spans[upper] = []
			spans[upper].append(option["span"])
		else:
			if not fallbacks.has(upper):
				fallbacks[upper] = []
			fallbacks[upper].append(crossing["at"])
	if not spans.is_empty():
		var merged: Dictionary = MapGradeSeparation.merged_spans(spans)
		var graded: Dictionary = {}
		for id: String in spans:
			graded[id] = edges[id]
		graded = MapGradeSeparation.apply_spans(graded, merged["spans"])
		for id: String in spans:
			edges[id] = graded[id]
	for id: String in MapLayoutCanonical.sorted_keys(fallbacks):
		if not spans.has(id):
			_lift(edges[id]["centerline"], fallbacks[id])
	return bridges


## Where two roads first cross, as [a's progress, b's progress] in 0..1 of their
## point count, or [] when they do not.
func _first_crossing(a: String, b: String) -> Array:
	var axs: PackedFloat64Array = _roads.lines_x[a]
	var azs: PackedFloat64Array = _roads.lines_z[a]
	var bxs: PackedFloat64Array = _roads.lines_x[b]
	var bzs: PackedFloat64Array = _roads.lines_z[b]
	for i: int in range(axs.size() - 1):
		var px: float = axs[i]
		var pz: float = azs[i]
		var rx: float = axs[i + 1] - px
		var rz: float = azs[i + 1] - pz
		for j: int in range(bxs.size() - 1):
			var qx: float = bxs[j]
			var qz: float = bzs[j]
			var sx: float = bxs[j + 1] - qx
			var sz: float = bzs[j + 1] - qz
			var denominator: float = rx * sz - rz * sx
			if denominator == 0.0:
				continue
			var u: float = ((qx - px) * sz - (qz - pz) * sx) / denominator
			var v: float = ((qx - px) * rz - (qz - pz) * rx) / denominator
			if u >= 0.0 and u <= 1.0 and v >= 0.0 and v <= 1.0:
				return [(float(i) + u) / float(axs.size() - 1),
					(float(j) + v) / float(bxs.size() - 1)]
	return []


## How far (m) along the upper road to move a crossing so the deck's ramps get
## equal room either side: half the difference between the room left before and
## after the span the corridor overlap needs.
func _centring(crossing: Dictionary) -> float:
	var upper: String = crossing["upper"]
	var envelope: Vector2 = MapGradeSeparation.overlap_envelope(_line(upper),
		_line(str(crossing["lower"])), _roads.width)
	if not is_finite(envelope.x):
		return 0.0
	return clampf((_roads.path_length(upper) - envelope.x - envelope.y) * 0.5,
		-CENTRE_LIMIT_M, CENTRE_LIMIT_M)


func _line(id: String) -> Array:
	var xs: PackedFloat64Array = _roads.lines_x[id]
	var zs: PackedFloat64Array = _roads.lines_z[id]
	var line: Array = []
	for i: int in range(xs.size()):
		line.append(Vector3(xs[i], 0.0, zs[i]))
	return line


## Reroutes each lower road through every crossing it makes, each at its upper
## road's arc length `s`, between two points a little either side.
func _reroute(crossings: Array[Dictionary]) -> void:
	var through: Dictionary = {}
	for crossing: Dictionary in crossings:
		var lower: String = crossing["lower"]
		if not through.has(lower):
			through[lower] = []
		through[lower].append(_point_in(str(crossing["upper"]), _f(crossing["s"])))
	for lower: String in MapLayoutCanonical.sorted_keys(through):
		var chord: PackedFloat64Array = _roads.chord(lower)
		var ax: float = _roads.node_x[_roads.from_id[lower]]
		var az: float = _roads.node_z[_roads.from_id[lower]]
		var points: Array = through[lower]
		points.sort_custom(func(p: Array, q: Array) -> bool:
			return (_f(p[0]) - ax) * chord[0] + (_f(p[1]) - az) * chord[1] \
				< (_f(q[0]) - ax) * chord[0] + (_f(q[1]) - az) * chord[1])
		var stops: Array = []
		for point: Array in points:
			stops.append([_f(point[0]) - chord[0] * CROSSING_HALF_M,
				_f(point[1]) - chord[1] * CROSSING_HALF_M, chord[0], chord[1]])
			stops.append([_f(point[0]) + chord[0] * CROSSING_HALF_M,
				_f(point[1]) + chord[1] * CROSSING_HALF_M, chord[0], chord[1]])
		_roads.shape(lower, stops)


## The point `s` metres along road `id`, as [x, z], held inside its segment
## (never on a vertex).
func _point_in(id: String, s: float) -> Array:
	var xs: PackedFloat64Array = _roads.lines_x[id]
	var zs: PackedFloat64Array = _roads.lines_z[id]
	var remaining: float = s
	var at: int = xs.size() - 2
	for i: int in range(xs.size() - 1):
		var dx: float = xs[i + 1] - xs[i]
		var dz: float = zs[i + 1] - zs[i]
		var length: float = sqrt(dx * dx + dz * dz)
		if remaining <= length:
			at = i
			break
		remaining -= length
	var dx: float = xs[at + 1] - xs[at]
	var dz: float = zs[at + 1] - zs[at]
	var t: float = clampf(remaining / sqrt(dx * dx + dz * dz), SEGMENT_INSET,
		1.0 - SEGMENT_INSET)
	return [xs[at] + dx * t, zs[at] + dz * t]


## Lifts a road to `FALLBACK_DECK_M` over its crossings where the governed span
## does not fit: level with its nodes at both ends, ramping linearly one point
## before the first crossing and back down one point after the last.
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
		var height: float = FALLBACK_DECK_M * clampf(minf(t / rise_end,
			(1.0 - t) / (1.0 - fall_start)), 0.0, 1.0)
		var point: Array = line[i]
		line[i] = [point[0], _f(point[1]) + height, point[2]]


static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
