class_name LeadlightWord
extends Button
## A quiet utility word: no box. Rest is dim; `near` (closest the flame) is a
## little brighter; hover and focus bring parchment and a gold hairline beneath
## — the shared lantern ring in its unboxed form. A press shows the hairline at
## once, as the rubric asks of every pressed state.

var near: bool = false:
	set(value):
		near = value
		_recolour()
## The least height a tap takes, centred on the word (the rubric's 60 px at pad
## and desktop): the word is drawn where it is and only its hit grows.
var hit_height: float = 0.0
## How long the word a room was left back to keeps its glow (§5.2, G2).
const AFTERGLOW: float = 0.6
var _glow_t: float = -1.0
## 0..1: the glow of the word a room was left back to (the afterglow).
var glow: float = 0.0:
	set(value):
		glow = value
		var lift: float = 0.55 * glow
		modulate = Color(1.0 + lift, 1.0 + lift * 0.8, 1.0 + lift * 0.4, modulate.a)


class Hairline extends StyleBox:
	var strength: float = 1.0

	func _draw(ci: RID, rect: Rect2) -> void:
		var y: float = rect.end.y - 3.0
		var a: Vector2 = Vector2(rect.position.x + rect.size.x * 0.12, y)
		var b: Vector2 = Vector2(rect.end.x - rect.size.x * 0.12, y)
		var mid: Vector2 = (a + b) * 0.5
		var gold: Color = Color(LeadlightTokens.GOLD, 0.95 * strength)
		var clear: Color = Color(LeadlightTokens.GOLD, 0.0)
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([a, mid, b]),
			PackedColorArray([clear, gold, clear]), 1.2, true)


func _init(label: String = "", stage_shape: StringName = StageShape.IDENTITY) -> void:
	text = label
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_WORD, stage_shape)
	add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, px))
	add_theme_font_size_override("font_size", px)
	add_theme_constant_override("outline_size", 6)
	add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.75))
	# The touch floor always: words sit in open air, so the hit rect is free.
	custom_minimum_size.y = 44.0
	focus_mode = Control.FOCUS_ALL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 10.0
	empty.content_margin_right = 10.0
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("normal", empty)
	var hover: Hairline = Hairline.new()
	hover.strength = 0.55
	hover.content_margin_left = 10.0
	hover.content_margin_right = 10.0
	add_theme_stylebox_override("hover", hover)
	var focus: Hairline = Hairline.new()
	add_theme_stylebox_override("focus", focus)
	# Pressed: the full hairline under the gold word, from the frame it is down.
	var down: Hairline = Hairline.new()
	down.content_margin_left = 10.0
	down.content_margin_right = 10.0
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	_recolour()


func _ready() -> void:
	set_process(false)


## "You came from here": a glow that fades over AFTERGLOW, SINE/OUT. A glow,
## never the hairline. None under Reduce Motion.
func afterglow() -> void:
	if LeadlightMotion.reduced():
		return
	_glow_t = 0.0
	glow = 1.0
	set_process(true)


## Put the glow out at once.
func quench() -> void:
	_glow_t = -1.0
	glow = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if _glow_t < 0.0:
		set_process(false)
		return
	_glow_t += delta
	var u: float = _glow_t / AFTERGLOW
	if u >= 1.0:
		quench()
	else:
		glow = 1.0 - LeadlightMotion.ease_on(u, Vector2i(Tween.TRANS_SINE, Tween.EASE_OUT))


## The word's tap, in its own coordinates: its rect, grown to `hit_height`.
func hit_rect() -> Rect2:
	var tall: float = maxf(size.y, hit_height)
	return Rect2(Vector2(0.0, (size.y - tall) * 0.5), Vector2(size.x, tall))


func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


func _recolour() -> void:
	var rest: Color = Color("#b9bfd3") if near else LeadlightTokens.TEXT_DIM
	add_theme_color_override("font_color", rest)
	add_theme_color_override("font_hover_color", LeadlightTokens.PARCHMENT)
	add_theme_color_override("font_focus_color", LeadlightTokens.PARCHMENT)
	add_theme_color_override("font_pressed_color", LeadlightTokens.GOLD)
	add_theme_color_override("font_hover_pressed_color", LeadlightTokens.GOLD)
	add_theme_color_override("font_disabled_color", Color(rest, 0.45))
