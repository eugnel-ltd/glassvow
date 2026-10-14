extends "res://presentation/map/landscape/bridge_surfaces.gd"
## A causeway deck's surface: Act I's clipped deck field, with heights blended
## compactly across neighbouring spans (no nearest-segment crease on the outside
## of a bend) and fitted to the deck's flights (`flight_grade.gd`). The
## archive's `common/smooth_surfaces.gd`.
const FlightGrade = preload("res://presentation/map/causeway/flight_grade.gd")
var stair_profile: FlightGrade
## Whether the deck's height blends only within a route and the routes at its
## own height (the raised decks: two raised roads apart in height never pull
## each other's decks between them).
var routes_apart: bool = false
## How far apart in height two routes' spans stay unblended (`routes_apart`).
const APART: float = .3
var _boundary_positions: Dictionary = {}
## The spans packed for `field` (`_pack`), and each cell's span indices.
var _packed: Dictionary = {}
var _a: PackedVector2Array = []
var _b: PackedVector2Array = []
var _ay: PackedFloat64Array = []
var _by: PackedFloat64Array = []
var _half_a: PackedFloat64Array = []
var _half_b: PackedFloat64Array = []
var _rise_a: PackedFloat64Array = []
var _rise_b: PackedFloat64Array = []
var _wa: PackedFloat64Array = []
var _wb: PackedFloat64Array = []
var _low_a: PackedFloat64Array = []
var _low_b: PackedFloat64Array = []
var _s: PackedFloat64Array = []
var _owner: PackedStringArray = []
## Whether every span rises fully (no `raise_a`/`raise_b`, `wa` and `wb` 1).
var _unit_rise: bool = true


func setup(source: Array[Dictionary], height: Callable, deck_profile: Callable = Callable()) -> void:
	_boundary_positions.clear()
	cells.clear()
	vertices.clear()
	spans = source
	ground = height
	profile = deck_profile
	# The whole interpolation support around widened node landings, indexed
	# once, so the support does not change at a cell's edge.
	for span: Dictionary in spans:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		var low: Vector2 = Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * 1.65
		var high: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * 1.65
		for x: int in range(floori(low.x / query_cell_size), ceili(high.x / query_cell_size) + 1):
			for z: int in range(floori(low.y / query_cell_size), ceili(high.y / query_cell_size) + 1):
				var key: Vector2i = Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(span)
	_pack()


## The deck at `at`: the clipped deck's query (`bridge_surfaces.gd`'s
## `field`, the nearest span's edge distance, height, blend, underside and
## UV) and the blend across neighbouring spans fitted to their flights, in
## one pass over the cell's spans, read from packed arrays (`_pack`): the same
## operations in the same order as the two queries it stands for, so the same
## result, without a Dictionary read per span (the build's costliest work, on
## the iPad 8's worker under Act I's boss).
func field(at: Vector2) -> Dictionary:
	var candidates: PackedInt32Array = _packed.get(Vector2i(floori(at.x / query_cell_size),
		floori(at.y / query_cell_size)), PackedInt32Array())
	var best: float = INF
	var rise_sum: float = 0
	var rise_weight: float = 0
	var highest_rise: float = 0
	var span_height: float = 0.0
	var blend: float = 0.0
	var bottom: float = 0.0
	var uv: Vector2 = Vector2.ZERO
	var own: String = ""
	var own_height: float = 0.0
	if routes_apart:
		var nearest: float = INF
		for i: int in candidates:
			var start: Vector2 = _a[i]
			var delta: Vector2 = _b[i] - start
			var t: float = clampf((at - start).dot(delta) / maxf(.000001, delta.length_squared()), 0, 1)
			var d2: float = at.distance_squared_to(start + delta * t)
			if d2 < nearest:
				nearest = d2
				own = _owner[i]
				own_height = lerpf(_ay[i], _by[i], t)
	var flights: Dictionary = {}
	var height_sum: float = 0
	var weight_sum: float = 0
	for i: int in candidates:
		var a: Vector2 = _a[i]
		var b: Vector2 = _b[i]
		var t: float = clampf((at - a).dot(b - a) / maxf(.000001, a.distance_squared_to(b)), 0, 1)
		var distance: float = at.distance_to(a.lerp(b, t))
		if _unit_rise:
			highest_rise = 1.0
		else:
			var rise: float = lerpf(_rise_a[i], _rise_b[i], t)
			var rise_at: float = exp(-distance * distance / .15) * a.distance_to(b)
			rise_sum += rise * rise_at
			rise_weight += rise_at
			highest_rise = maxf(highest_rise, rise)
		var boundary: float = distance - lerpf(_half_a[i], _half_b[i], t)
		if boundary < best:
			best = boundary
			span_height = lerpf(_ay[i], _by[i], t) + .022
			blend = lerpf(_wa[i], _wb[i], t)
			bottom = lerpf(_low_a[i], _low_b[i], t)
			uv = Vector2((b - a).normalized().cross(at - a), _s[i] + a.distance_to(b) * t)
		# The blend across spans (the archive's smooth surface).
		var delta: Vector2 = b - a
		var u: float = clampf((at - a).dot(delta) / maxf(.000001, delta.length_squared()), 0, 1)
		var d2: float = at.distance_squared_to(a + delta * u)
		var kernel: float = maxf(0, 1.0 - d2 / 2.25)
		var weight: float = kernel * kernel * kernel * delta.length() / (.02 + d2)
		var height: float = lerpf(_ay[i], _by[i], u)
		if routes_apart and _owner[i] != own and absf(height - own_height) > APART:
			continue
		if stair_profile != null and weight > 0:
			var owner: String = _owner[i]
			if not flights.has(owner):
				flights[owner] = stair_profile.sample(at, owner)
			var fitted: Vector2 = flights[owner]
			height = lerpf(height, fitted.x - .022, fitted.y)
		height_sum += height * weight
		weight_sum += weight
	if best == INF:
		return {"distance": INF, "height": 0.0, "blend": 0.0, "bottom": 0.0, "uv": Vector2.ZERO}
	if profile.is_valid():
		var deck_height: float = profile.call(at.x, at.y)
		span_height = deck_height + .022
	var ground_height: float = ground.call(at.x, at.y)
	# Every causeway span rises fully (`_unit_rise`): the weighted mean of ones
	# is one, as the woodland's query works it out.
	var rise_mean: float = 1.0 if _unit_rise else rise_sum / maxf(.000001, rise_weight)
	rise_mean = lerpf(rise_mean, highest_rise, smoothstep(.6, 1.2, span_height - ground_height))
	span_height = lerpf(ground_height + .012, span_height, rise_mean)
	span_height = maxf(ground_height + .012, span_height)
	bottom = minf(span_height - .005, lerpf(ground_height + .008, bottom, blend))
	if weight_sum > .000000001:
		# The deck's height blends across spans; its arch profile stays the
		# nearest span's, since averaging it pinches the solid piers.
		span_height = height_sum / weight_sum + .022
	return {"distance": best, "height": span_height, "blend": blend, "bottom": bottom, "uv": uv}


## Packs every span's values the query reads into typed arrays, and each
## cell's spans as their indices, in `cells`' order.
func _pack() -> void:
	_packed.clear()
	_a.clear()
	_b.clear()
	_owner.clear()
	for array: PackedFloat64Array in [_ay, _by, _half_a, _half_b, _rise_a, _rise_b, _wa, _wb, _low_a, _low_b, _s]:
		array.clear()
	_unit_rise = true
	var index: Dictionary = {}
	for span: Dictionary in spans:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		index[span] = _a.size()
		_a.append(Vector2(a.x, a.z))
		_b.append(Vector2(b.x, b.z))
		_ay.append(a.y)
		_by.append(b.y)
		var half_a: float = span.get("half_a", HALF)
		var half_b: float = span.get("half_b", HALF)
		_half_a.append(half_a)
		_half_b.append(half_b)
		var rise_a: float = span.get("raise_a", span["wa"])
		var rise_b: float = span.get("raise_b", span["wb"])
		_rise_a.append(rise_a)
		_rise_b.append(rise_b)
		_unit_rise = _unit_rise and rise_a == 1.0 and rise_b == 1.0
		_wa.append(_number(span, "wa"))
		_wb.append(_number(span, "wb"))
		var low_a: float = span.get("bottom_a", a.y - .18)
		var low_b: float = span.get("bottom_b", b.y - .18)
		_low_a.append(low_a)
		_low_b.append(low_b)
		_s.append(_number(span, "s"))
		_owner.append(str(span.get("edge", "")))
	for key: Vector2i in cells:
		var list: PackedInt32Array = []
		for span: Dictionary in cells[key]:
			var at: int = index[span]
			list.append(at)
		_packed[key] = list


func _position(item: Dictionary) -> Vector3:
	var result: Vector3 = super._position(item)
	var distance: float = item["distance"]
	if absf(distance) < .00000001:
		# A clipping edge lies between an inside and an outside sample, and the
		# outside one may belong to another leg of a tight bend: the boundary
		# takes its own height, not one interpolated from that leg.
		var key: Vector2 = Vector2(result.x, result.z)
		if not _boundary_positions.has(key):
			_boundary_positions[key] = field(key)["height"]
		result.y = _boundary_positions[key]
	return result
