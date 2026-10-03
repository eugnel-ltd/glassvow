class_name LeadlightSheet
extends Control
## A room in the same house: a pointed-arch leaded window — dark quarry
## glazing in lead, a gold line inside the came — with its contents seated
## below the arch's spring. Lit from `light_at` (0..1 of its own rect) in the
## lantern's colour, so the room is lit by the light that brought you there.
##
## A room is drawn by that light as it arrives (docs/design/2026-10-03-title-
## rooms §2.4), with no shader: `trace` draws the lead by arc length from the
## sill nearest the lantern, and `reach` grows a disc of light from
## `reach_from` across the window, the glazing lit only inside it, its front a
## soft band in the flame's colour. Both at 1 draw the window whole, exactly as
## it rests.

## Where the arch springs, as a share of the height from the top.
var spring: float = 0.16
var sharpness: float = 1.25
var light_at: Vector2 = Vector2(0.12, 1.0)
var light_colour: Color = LeadlightTokens.EMBER
var quarry_pitch: float = 34.0
## How far the light has reached across the glass, 0..1.
var reach: float = 1.0:
	set(value):
		reach = clampf(value, 0.0, 1.0)
		queue_redraw()
## Where the light grows from, in this control's coordinates.
var reach_from: Vector2 = Vector2.ZERO:
	set(value):
		reach_from = value
		queue_redraw()
## How much of the lead is drawn, 0..1, from the point nearest `reach_from`.
var trace: float = 1.0:
	set(value):
		trace = clampf(value, 0.0, 1.0)
		queue_redraw()
## The glazing's own alpha: the glass going dark as a room leaves.
var glazing: float = 1.0:
	set(value):
		glazing = clampf(value, 0.0, 1.0)
		queue_redraw()
## Glints along the leading: (u, v, phase) in the glazing's own 0..1 space.
const GLINTS: Array[Vector3] = [
	Vector3(0.12, 0.30, 0.0), Vector3(0.31, 0.62, 1.7), Vector3(0.52, 0.22, 3.1),
	Vector3(0.68, 0.78, 4.4), Vector3(0.86, 0.41, 5.6), Vector3(0.22, 0.88, 2.4),
	Vector3(0.44, 0.47, 6.9), Vector3(0.77, 0.14, 8.2), Vector3(0.93, 0.70, 9.5),
]
## The light front's disc, as a polygon.
const FRONT_SEGMENTS: int = 48
const ARCH_SEGMENTS: int = 24
var _content: MarginContainer
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = MarginContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func _ready() -> void:
	_seat()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_seat()
		queue_redraw()


## The seat for this room's contents (one child).
func content() -> MarginContainer:
	return _content


## A room is never a still frame: the light drifts and breathes on the glass
## and the leading catches it in brief glints. Draw-only; still under Reduce
## Motion.
func _process(delta: float) -> void:
	if LeadlightMotion.reduced():
		return
	_time += delta
	queue_redraw()


func set_light(colour: Color, at: Vector2) -> void:
	light_colour = colour
	light_at = at
	queue_redraw()


func _seat() -> void:
	var inset: float = clampf(size.x * 0.05, 18.0, 44.0)
	_content.add_theme_constant_override("margin_left", int(inset))
	_content.add_theme_constant_override("margin_right", int(inset))
	_content.add_theme_constant_override("margin_top", int(size.y * spring * 0.55 + 18.0))
	_content.add_theme_constant_override("margin_bottom", int(clampf(size.y * 0.035, 10.0, 26.0)))


func outline() -> PackedVector2Array:
	return LeadlightShapes.arch(Rect2(Vector2.ZERO, size), spring, sharpness, ARCH_SEGMENTS)


## The radius that lights every point of `body` from `from`. Pure.
static func far_radius(body: PackedVector2Array, from: Vector2) -> float:
	var far: float = 0.0
	for p: Vector2 in body:
		far = maxf(far, from.distance_to(p))
	return far


## The light front's radius at `t` (0..1) of the way across `body`. Pure.
static func reach_radius(body: PackedVector2Array, from: Vector2, t: float) -> float:
	return far_radius(body, from) * clampf(t, 0.0, 1.0)


## A disc as a polygon. Pure.
static func disc(centre: Vector2, radius: float, segments: int = FRONT_SEGMENTS) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments):
		points.append(centre + Vector2.from_angle(TAU * float(i) / float(segments)) * radius)
	return points


## The lit glazing: the window inside the light's disc, as polygons. None at
## radius 0; the whole window once the disc clears it. Pure.
static func lit_glazing(body: PackedVector2Array, from: Vector2, radius: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if radius <= 0.0 or body.size() < 3:
		return out
	if radius >= far_radius(body, from):
		out.append(body)
		return out
	# The window and a disc are both simple and the window is never inside out,
	# so their intersection has no holes: every piece is lit glass.
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(body, disc(from, radius)):
		out.append(piece)
	return out


## Line pairs (as `draw_multiline` takes them) clipped to a disc. Pure.
static func clip_lines(lines: PackedVector2Array, centre: Vector2, radius: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if radius <= 0.0:
		return out
	var r2: float = radius * radius
	for i: int in range(0, lines.size() - 1, 2):
		var a: Vector2 = lines[i]
		var b: Vector2 = lines[i + 1]
		var d: Vector2 = b - a
		var f: Vector2 = a - centre
		var qa: float = d.dot(d)
		if qa <= 0.0:
			if f.length_squared() <= r2:
				out.append(a)
				out.append(b)
			continue
		var qb: float = 2.0 * f.dot(d)
		var qc: float = f.dot(f) - r2
		var disc_v: float = qb * qb - 4.0 * qa * qc
		if disc_v <= 0.0:
			continue
		var root: float = sqrt(disc_v)
		var t0: float = maxf((-qb - root) / (2.0 * qa), 0.0)
		var t1: float = minf((-qb + root) / (2.0 * qa), 1.0)
		if t1 <= t0:
			continue
		out.append(a if t0 <= 0.0 else a + d * t0)
		out.append(b if t1 >= 1.0 else a + d * t1)
	return out


## The traced lead: the part of the closed `loop` within `t` of its length,
## grown from the point on it nearest `from`, half each way. None at 0; the
## whole loop, closed, at 1. Pure.
static func traced(loop: PackedVector2Array, from: Vector2, t: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var n: int = loop.size()
	if n < 2 or t <= 0.0:
		return out
	if t >= 1.0:
		var whole: PackedVector2Array = loop.duplicate()
		whole.append(loop[0])
		out.append(whole)
		return out
	# The nearest point on the loop to `from`: its edge and where on it.
	var best: float = INF
	var edge: int = 0
	var at: Vector2 = loop[0]
	var length: float = 0.0
	for i: int in range(n):
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % n]
		length += a.distance_to(b)
		var p: Vector2 = Geometry2D.get_closest_point_to_segment(from, a, b)
		var d: float = p.distance_squared_to(from)
		if d < best:
			best = d
			edge = i
			at = p
	var half: float = length * t * 0.5
	out.append(_walk(loop, edge, at, half, 1))
	out.append(_walk(loop, edge, at, half, -1))
	return out


## From `at` on edge `edge`, `distance` along the loop in `dir` (+1 forward).
static func _walk(loop: PackedVector2Array, edge: int, at: Vector2, distance: float,
		dir: int) -> PackedVector2Array:
	var n: int = loop.size()
	var path: PackedVector2Array = PackedVector2Array([at])
	var left: float = distance
	var here: Vector2 = at
	var index: int = (edge + 1) % n if dir > 0 else edge
	for _step: int in range(n + 1):
		var next: Vector2 = loop[index]
		var span: float = here.distance_to(next)
		if span >= left:
			path.append(here + (next - here) * (left / maxf(span, 0.0001)))
			return path
		path.append(next)
		left -= span
		here = next
		index = (index + 1) % n if dir > 0 else (index - 1 + n) % n
	return path


func _draw() -> void:
	var body: PackedVector2Array = outline()
	var whole: bool = reach >= 1.0
	var radius: float = reach_radius(body, reach_from, reach)
	var pieces: Array[PackedVector2Array] = lit_glazing(body, reach_from, radius)
	for piece: PackedVector2Array in pieces:
		_fill(piece)
	if not pieces.is_empty():
		# The lantern's light on the glass, from below where it hangs.
		var lr: float = maxf(size.x, size.y) * 0.75 * (1.0 + 0.04 * LeadlightMotion.breath(_time, 5.0))
		var drift: Vector2 = Vector2(sin(_time * 0.37) * 0.04, cos(_time * 0.29) * 0.03)
		var lc: Vector2 = (light_at + drift) * size
		draw_texture_rect(SkyField.disc(), Rect2(lc - Vector2(lr, lr), Vector2(lr, lr) * 2.0),
			false, Color(light_colour, 0.22 * glazing * reach
				* (1.0 + 0.18 * LeadlightMotion.breath(_time, 3.3))))
		# Quarry glazing, clipped to the box below the arch's crown and the light.
		var glazed: Rect2 = Rect2(Vector2(0.0, size.y * spring), Vector2(size.x, size.y * (1.0 - spring)))
		var lines: PackedVector2Array = LeadlightShapes.quarry(glazed, quarry_pitch)
		if not whole:
			lines = clip_lines(lines, reach_from, radius)
		if not lines.is_empty():
			draw_multiline(lines, Color(LeadlightTokens.LEAD, 0.38 * glazing), 1.4)
		if _time > 0.0 and whole:
			_draw_glints(glazed)
	if not whole and radius > 0.0:
		_draw_front(body, radius)
	_draw_lead(body)


## A lit piece of the glazing: night glass, darker towards the sill.
func _fill(piece: PackedVector2Array) -> void:
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in piece:
		var t: float = clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
		var c: Color = Color(0.063, 0.078, 0.157, 0.95).lerp(Color(0.031, 0.039, 0.086, 0.97), t)
		c.a *= glazing
		cols.append(c)
	draw_polygon(piece, cols)


## The light's front: a soft band along its edge, inside the window only.
func _draw_front(body: PackedVector2Array, radius: float) -> void:
	# Warm and soft: it eases in as the light leaves the wick and out as it
	# clears the window, never a hairline.
	var fade: float = smoothstep(0.0, 0.12, reach) * (1.0 - smoothstep(0.78, 1.0, reach)) * glazing
	if fade <= 0.01:
		return
	var tone: Color = light_colour.lerp(LeadlightTokens.GOLD, 0.55)
	var run: PackedVector2Array = PackedVector2Array()
	var runs: Array[PackedVector2Array] = []
	var count: int = FRONT_SEGMENTS * 2
	for i: int in range(count + 1):
		var p: Vector2 = reach_from + Vector2.from_angle(TAU * float(i) / float(count)) * radius
		if Geometry2D.is_point_in_polygon(p, body):
			run.append(p)
		elif run.size() > 1:
			runs.append(run)
			run = PackedVector2Array()
		else:
			run.clear()
	if run.size() > 1:
		runs.append(run)
	for path: PackedVector2Array in runs:
		draw_polyline(path, Color(tone, 0.10 * fade), 16.0, true)
		draw_polyline(path, Color(tone, 0.16 * fade), 7.0, true)
		draw_polyline(path, Color(tone.lerp(LeadlightTokens.PARCHMENT, 0.3), 0.32 * fade), 2.0, true)


## The came round the window and the gold line inside it, traced by `trace`.
func _draw_lead(body: PackedVector2Array) -> void:
	var inner: PackedVector2Array = LeadlightShapes.arch(Rect2(Vector2(4, 4), size - Vector2(8, 8)),
		spring, sharpness, ARCH_SEGMENTS)
	for path: PackedVector2Array in traced(body, reach_from, trace):
		draw_polyline(path, LeadlightTokens.LEAD, 5.0, true)
	for path: PackedVector2Array in traced(inner, reach_from, trace):
		draw_polyline(path, Color(LeadlightTokens.GOLD_DIM, 0.6), 1.2, true)


func _draw_glints(glazed: Rect2) -> void:
	var disc_tex: Texture2D = SkyField.disc()
	for g: Vector3 in GLINTS:
		var a: float = pow(maxf(0.0, sin(_time * 0.7 + g.z)), 12.0) * glazing
		if a < 0.02:
			continue
		var at: Vector2 = glazed.position + Vector2(g.x, g.y) * glazed.size
		var r: float = 5.0 + 4.0 * a
		draw_texture_rect(disc_tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(light_colour.lerp(Color.WHITE, 0.5), 0.55 * a))
		draw_line(at - Vector2(r * 1.8, 0.0), at + Vector2(r * 1.8, 0.0), Color(1, 1, 1, 0.35 * a), 1.0)
		draw_line(at - Vector2(0.0, r * 1.8), at + Vector2(0.0, r * 1.8), Color(1, 1, 1, 0.35 * a), 1.0)
