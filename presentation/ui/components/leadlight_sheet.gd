class_name LeadlightSheet
extends Control
## A room in the same house: a pointed-arch leaded window — dark quarry
## glazing in lead, a gold line inside the came — with its contents seated
## below the arch's spring. Lit from `light_at` (0..1 of its own rect) in the
## lantern's colour, so the room is lit by the light that brought you there.

## Where the arch springs, as a share of the height from the top.
var spring: float = 0.16
var sharpness: float = 1.25
var light_at: Vector2 = Vector2(0.12, 1.0)
var light_colour: Color = LeadlightTokens.EMBER
var quarry_pitch: float = 34.0
## Glints along the leading: (u, v, phase) in the glazing's own 0..1 space.
const GLINTS: Array[Vector3] = [
	Vector3(0.12, 0.30, 0.0), Vector3(0.31, 0.62, 1.7), Vector3(0.52, 0.22, 3.1),
	Vector3(0.68, 0.78, 4.4), Vector3(0.86, 0.41, 5.6), Vector3(0.22, 0.88, 2.4),
	Vector3(0.44, 0.47, 6.9), Vector3(0.77, 0.14, 8.2), Vector3(0.93, 0.70, 9.5),
]
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
	return LeadlightShapes.arch(Rect2(Vector2.ZERO, size), spring, sharpness, 24)


func _draw() -> void:
	var body: PackedVector2Array = outline()
	var cols: PackedColorArray = PackedColorArray()
	for p: Vector2 in body:
		var t: float = clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
		cols.append(Color(0.063, 0.078, 0.157, 0.95).lerp(Color(0.031, 0.039, 0.086, 0.97), t))
	draw_polygon(body, cols)
	# The lantern's light on the glass, from below where it hangs.
	var lr: float = maxf(size.x, size.y) * 0.75 * (1.0 + 0.04 * LeadlightMotion.breath(_time, 5.0))
	var drift: Vector2 = Vector2(sin(_time * 0.37) * 0.04, cos(_time * 0.29) * 0.03)
	var lc: Vector2 = (light_at + drift) * size
	draw_texture_rect(SkyField.disc(), Rect2(lc - Vector2(lr, lr), Vector2(lr, lr) * 2.0),
		false, Color(light_colour, 0.22 * (1.0 + 0.18 * LeadlightMotion.breath(_time, 3.3))))
	# Quarry glazing, clipped to the box below the arch's crown.
	var glazing: Rect2 = Rect2(Vector2(0.0, size.y * spring), Vector2(size.x, size.y * (1.0 - spring)))
	var lines: PackedVector2Array = LeadlightShapes.quarry(glazing, quarry_pitch)
	if not lines.is_empty():
		draw_multiline(lines, Color(LeadlightTokens.LEAD, 0.38), 1.4)
	if _time > 0.0:
		_draw_glints(glazing)
	var loop: PackedVector2Array = body.duplicate()
	loop.append(body[0])
	draw_polyline(loop, LeadlightTokens.LEAD, 5.0, true)
	var inner: PackedVector2Array = LeadlightShapes.arch(Rect2(Vector2(4, 4), size - Vector2(8, 8)), spring, sharpness, 24)
	inner.append(inner[0])
	draw_polyline(inner, Color(LeadlightTokens.GOLD_DIM, 0.6), 1.2, true)


func _draw_glints(glazing: Rect2) -> void:
	var disc: Texture2D = SkyField.disc()
	for g: Vector3 in GLINTS:
		var a: float = pow(maxf(0.0, sin(_time * 0.7 + g.z)), 12.0)
		if a < 0.02:
			continue
		var at: Vector2 = glazing.position + Vector2(g.x, g.y) * glazing.size
		var r: float = 5.0 + 4.0 * a
		draw_texture_rect(disc, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(light_colour.lerp(Color.WHITE, 0.5), 0.55 * a))
		draw_line(at - Vector2(r * 1.8, 0.0), at + Vector2(r * 1.8, 0.0), Color(1, 1, 1, 0.35 * a), 1.0)
		draw_line(at - Vector2(0.0, r * 1.8), at + Vector2(0.0, r * 1.8), Color(1, 1, 1, 0.35 * a), 1.0)
