class_name LeadlightShapes
extends RefCounted
## The lead-cut outlines Leadlight draws with: pure polygon builders, no Node,
## so the geometry is pinned by tests and shared by every component's `_draw`.


## A leaded lozenge: a bar whose two ends are cut to a point `cut` px deep.
static func lozenge(rect: Rect2, cut: float) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, rect.size.x * 0.5)
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	return PackedVector2Array([
		p + Vector2(c, 0.0), p + Vector2(s.x - c, 0.0), p + Vector2(s.x, s.y * 0.5),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0.0, s.y * 0.5),
	])


## A pointed (two-centred) arch over `rect`: straight jambs up to `spring`
## (0..1 of the height from the top), then two arcs meeting at the apex.
## `sharpness` > 1 points the arch; 1 is a semicircle-like crown.
static func arch(rect: Rect2, spring: float, sharpness: float = 1.3,
		segments: int = 14) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var left: float = rect.position.x
	var right: float = rect.end.x
	var top: float = rect.position.y
	var bottom: float = rect.end.y
	var spring_y: float = top + rect.size.y * clampf(spring, 0.0, 1.0)
	points.append(Vector2(left, bottom))
	points.append(Vector2(left, spring_y))
	var n: int = maxi(segments, 2)
	for i: int in range(1, n):
		var t: float = float(i) / float(n)
		var x: float = lerpf(left, right, t)
		var rise: float = 1.0 - pow(absf(2.0 * t - 1.0), sharpness)
		points.append(Vector2(x, lerpf(spring_y, top, rise)))
	points.append(Vector2(right, spring_y))
	points.append(Vector2(right, bottom))
	return points


## The diamond quarry lines of plain leaded glazing across `rect`, as line
## pairs for `draw_multiline`, at `pitch` px. Clipped to the rect's box.
static func quarry(rect: Rect2, pitch: float) -> PackedVector2Array:
	var lines: PackedVector2Array = PackedVector2Array()
	var step: float = maxf(pitch, 4.0)
	var h: float = rect.size.y
	var slope: float = 0.58
	var reach: float = h / slope
	var x: float = rect.position.x - reach
	while x < rect.end.x:
		for dir: float in [1.0, -1.0]:
			var a: Vector2 = Vector2(x, rect.position.y) if dir > 0.0 \
				else Vector2(x + reach, rect.position.y)
			var b: Vector2 = a + Vector2(reach * dir, h)
			var clipped: PackedVector2Array = _clip_segment(a, b, rect)
			if clipped.size() == 2:
				lines.append_array(clipped)
		x += step
	return lines


## Liang–Barsky: the part of segment a→b inside `rect`, or empty.
static func _clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> PackedVector2Array:
	var d: Vector2 = b - a
	var t0: float = 0.0
	var t1: float = 1.0
	var checks: Array[Vector2] = [
		Vector2(-d.x, a.x - rect.position.x), Vector2(d.x, rect.end.x - a.x),
		Vector2(-d.y, a.y - rect.position.y), Vector2(d.y, rect.end.y - a.y),
	]
	for c: Vector2 in checks:
		if is_zero_approx(c.x):
			if c.y < 0.0:
				return PackedVector2Array()
			continue
		var r: float = c.y / c.x
		if c.x < 0.0:
			t0 = maxf(t0, r)
		else:
			t1 = minf(t1, r)
		if t0 > t1:
			return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])


## Points on an arc around `centre` from angle a0 to a1 (radians), for the
## arcs the title's words sit on.
static func arc_points(centre: Vector2, radius: Vector2, a0: float, a1: float,
		count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	if count <= 1:
		points.append(centre + Vector2(cos(a0), sin(a0)) * radius)
		return points
	for i: int in range(count):
		var a: float = lerpf(a0, a1, float(i) / float(count - 1))
		points.append(centre + Vector2(cos(a), sin(a)) * radius)
	return points
