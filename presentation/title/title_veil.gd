class_name TitleVeil
extends Control
## The dark the flame pushes back: everything is night except a soft disc of
## light around `centre`, `radius` px out. The kindling grows the radius until
## the whole stage is lit (light reach). Draw-only — one radial texture and four
## flat bands — so it costs no screen read.

const FEATHER: float = 0.55

var centre: Vector2 = Vector2.ZERO:
	set(value):
		centre = value
		queue_redraw()
var radius: float = 0.0:
	set(value):
		radius = value
		queue_redraw()
## How far the light has reached, 0..1: from a small disc round the flame to
## past every corner of the stage. Sets `radius` from the veil's own size.
var reach: float = 0.0:
	set(value):
		reach = value
		radius = lerpf(0.08, 1.0, clampf(value, 0.0, 1.0)) * full_radius()
## 0 lifts the veil entirely; 1 is full night outside the light.
var strength: float = 1.0:
	set(value):
		strength = value
		queue_redraw()

static var _hole: GradientTexture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## A radius that clears every corner from anywhere on the stage, feather and all.
func full_radius() -> float:
	return maxf(size.x, size.y) * 1.25 + 200.0


static func hole() -> GradientTexture2D:
	if _hole == null:
		var ink: Color = LeadlightTokens.VOID
		_hole = GlassStyle.grad_tex(
			PackedColorArray([Color(ink, 0.0), Color(ink, 0.0), Color(ink, 0.55), Color(ink, 1.0)]),
			PackedFloat32Array([0.0, 1.0 - FEATHER, 0.82, 1.0]), true,
			Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	return _hole


func _draw() -> void:
	if strength <= 0.001:
		return
	var ink: Color = Color(LeadlightTokens.VOID, strength)
	var r: float = maxf(radius, 1.0)
	var box: Rect2 = Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)
	if box.encloses(Rect2(Vector2.ZERO, size)) and r * (1.0 - FEATHER) > (size + centre.abs()).length():
		return
	draw_texture_rect(hole(), box, false, Color(1.0, 1.0, 1.0, strength))
	draw_rect(Rect2(0.0, 0.0, size.x, maxf(box.position.y, 0.0)), ink)
	draw_rect(Rect2(0.0, box.end.y, size.x, maxf(size.y - box.end.y, 0.0)), ink)
	draw_rect(Rect2(0.0, box.position.y, maxf(box.position.x, 0.0), box.size.y), ink)
	draw_rect(Rect2(box.end.x, box.position.y, maxf(size.x - box.end.x, 0.0), box.size.y), ink)
