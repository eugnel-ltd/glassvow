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
var _content: MarginContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = MarginContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_seat()


## The seat for this room's contents (one child).
func content() -> MarginContainer:
	return _content


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
	var lr: float = maxf(size.x, size.y) * 0.75
	var lc: Vector2 = light_at * size
	draw_texture_rect(SkyField.disc(), Rect2(lc - Vector2(lr, lr), Vector2(lr, lr) * 2.0),
		false, Color(light_colour, 0.22))
	# Quarry glazing, clipped to the box below the arch's crown.
	var glazing: Rect2 = Rect2(Vector2(0.0, size.y * spring), Vector2(size.x, size.y * (1.0 - spring)))
	var lines: PackedVector2Array = LeadlightShapes.quarry(glazing, quarry_pitch)
	if not lines.is_empty():
		draw_multiline(lines, Color(LeadlightTokens.LEAD, 0.55), 1.6)
	var loop: PackedVector2Array = body.duplicate()
	loop.append(body[0])
	draw_polyline(loop, LeadlightTokens.LEAD, 5.0, true)
	var inner: PackedVector2Array = LeadlightShapes.arch(Rect2(Vector2(4, 4), size - Vector2(8, 8)), spring, sharpness, 24)
	inner.append(inner[0])
	draw_polyline(inner, Color(LeadlightTokens.GOLD_DIM, 0.6), 1.2, true)
