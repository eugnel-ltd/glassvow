extends RefCounted
## The light reaches the room (docs/design/2026-10-03-title-rooms §2.4, §11.1):
## a glass room is drawn by the seated lantern's light with no shader. `reach`
## 0 lights none of the glazing and 1 all of it, growing between; `trace` 0
## draws no lead and 1 the whole loop, half each way from the sill nearest the
## lantern; and both are pure functions of their value, so a still at a time is
## the same still every time.

const ROOM: Vector2 = Vector2(792.0, 470.0)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("leadlight_sheet_reach: %s" % what)


static func run(fails: Array[String]) -> void:
	var body: PackedVector2Array = LeadlightShapes.arch(Rect2(Vector2.ZERO, ROOM), 0.14, 1.25,
		LeadlightSheet.ARCH_SEGMENTS)
	# The seated lantern's wick, below and left of the room (pad: room at 318, 300).
	var from: Vector2 = Vector2(104.0, 761.0) - Vector2(318.0, 300.0)
	_reach(fails, body, from)
	_trace(fails, body, from)
	_lines(fails, from)
	_sheet_defaults(fails)


static func _area(pieces: Array[PackedVector2Array]) -> float:
	var total: float = 0.0
	for piece: PackedVector2Array in pieces:
		var sum: float = 0.0
		for i: int in range(piece.size()):
			var a: Vector2 = piece[i]
			var b: Vector2 = piece[(i + 1) % piece.size()]
			sum += a.x * b.y - b.x * a.y
		total += absf(sum) * 0.5
	return total


static func _reach(fails: Array[String], body: PackedVector2Array, from: Vector2) -> void:
	var whole: Array[PackedVector2Array] = [body]
	var full: float = _area(whole)
	var none: Array[PackedVector2Array] = LeadlightSheet.lit_glazing(body, from,
		LeadlightSheet.reach_radius(body, from, 0.0))
	_check(fails, none.is_empty(), "reach 0 lights glazing")
	var all: Array[PackedVector2Array] = LeadlightSheet.lit_glazing(body, from,
		LeadlightSheet.reach_radius(body, from, 1.0))
	_check(fails, absf(_area(all) - full) < 1.0, "reach 1 does not light the whole window")
	var last: float = 0.0
	for step: int in range(1, 10):
		var t: float = float(step) / 10.0
		var lit: float = _area(LeadlightSheet.lit_glazing(body, from, LeadlightSheet.reach_radius(body, from, t)))
		_check(fails, lit >= last - 0.5 and lit <= full + 0.5, "reach %.1f lights %.0f after %.0f" % [t, lit, last])
		last = lit
		var again: float = _area(LeadlightSheet.lit_glazing(body, from, LeadlightSheet.reach_radius(body, from, t)))
		_check(fails, is_equal_approx(lit, again), "reach %.1f is not a pure function of its value" % t)
	_check(fails, last > 0.0 and last < full, "reach 0.9 is not part of the way across")


static func _length(paths: Array[PackedVector2Array]) -> float:
	var total: float = 0.0
	for path: PackedVector2Array in paths:
		for i: int in range(1, path.size()):
			total += path[i - 1].distance_to(path[i])
	return total


static func _trace(fails: Array[String], body: PackedVector2Array, from: Vector2) -> void:
	var loop_length: float = 0.0
	for i: int in range(body.size()):
		loop_length += body[i].distance_to(body[(i + 1) % body.size()])
	_check(fails, LeadlightSheet.traced(body, from, 0.0).is_empty(), "trace 0 draws lead")
	var whole: Array[PackedVector2Array] = LeadlightSheet.traced(body, from, 1.0)
	_check(fails, whole.size() == 1 and absf(_length(whole) - loop_length) < 0.5,
		"trace 1 is not the whole loop")
	for t: float in [0.25, 0.5, 0.75]:
		var part: Array[PackedVector2Array] = LeadlightSheet.traced(body, from, t)
		_check(fails, absf(_length(part) - loop_length * t) < 1.0,
			"trace %.2f draws %.0f of %.0f px" % [t, _length(part), loop_length])
		_check(fails, part.size() == 2 and part[0][0].is_equal_approx(part[1][0]),
			"trace %.2f does not grow both ways from one point" % t)
		var again: Array[PackedVector2Array] = LeadlightSheet.traced(body, from, t)
		_check(fails, again.size() == part.size() and again[0] == part[0] and again[1] == part[1],
			"trace %.2f is not a pure function of its value" % t)
	# It starts at the sill nearest the lantern: the left jamb's foot.
	var start: Vector2 = LeadlightSheet.traced(body, from, 0.1)[0][0]
	_check(fails, start.x < 1.0 and start.y > ROOM.y * 0.5, "the lead does not start at the sill nearest the lantern: %s" % start)


static func _lines(fails: Array[String], from: Vector2) -> void:
	var lines: PackedVector2Array = LeadlightShapes.quarry(Rect2(Vector2(0.0, 66.0), Vector2(792.0, 404.0)), 34.0)
	_check(fails, LeadlightSheet.clip_lines(lines, from, 0.0).is_empty(), "quarry lines show with no light")
	var far: PackedVector2Array = LeadlightSheet.clip_lines(lines, from, 5000.0)
	_check(fails, far == lines, "a disc clearing the window changes its quarry lines")
	var near: PackedVector2Array = LeadlightSheet.clip_lines(lines, from, 300.0)
	var inside: bool = true
	for p: Vector2 in near:
		inside = inside and p.distance_to(from) <= 300.01
	_check(fails, inside and not near.is_empty(), "clipped quarry lines leave the light's disc")


static func _sheet_defaults(fails: Array[String]) -> void:
	var sheet: LeadlightSheet = LeadlightSheet.new()
	_check(fails, is_equal_approx(sheet.reach, 1.0) and is_equal_approx(sheet.trace, 1.0)
			and is_equal_approx(sheet.glazing, 1.0),
		"a sheet does not rest whole (reach, trace and glazing at 1)")
	sheet.reach = 1.4
	sheet.trace = -0.2
	_check(fails, is_equal_approx(sheet.reach, 1.0) and is_equal_approx(sheet.trace, 0.0),
		"reach and trace are not held to 0..1")
	sheet.free()
