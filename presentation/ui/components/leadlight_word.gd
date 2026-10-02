class_name LeadlightWord
extends Button
## A quiet utility word: no box. Rest is dim; `near` (closest the flame) is a
## little brighter; hover and focus bring parchment and a gold hairline beneath
## — the shared lantern ring in its unboxed form.

var near: bool = false:
	set(value):
		near = value
		_recolour()


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
	custom_minimum_size.y = RunStyle.hit_floor(32.0)
	focus_mode = Control.FOCUS_ALL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 10.0
	empty.content_margin_right = 10.0
	for state: String in ["normal", "pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	var hover: Hairline = Hairline.new()
	hover.strength = 0.55
	hover.content_margin_left = 10.0
	hover.content_margin_right = 10.0
	add_theme_stylebox_override("hover", hover)
	var focus: Hairline = Hairline.new()
	add_theme_stylebox_override("focus", focus)
	_recolour()


func _recolour() -> void:
	var rest: Color = Color("#b9bfd3") if near else LeadlightTokens.TEXT_DIM
	add_theme_color_override("font_color", rest)
	add_theme_color_override("font_hover_color", LeadlightTokens.PARCHMENT)
	add_theme_color_override("font_focus_color", LeadlightTokens.PARCHMENT)
	add_theme_color_override("font_pressed_color", LeadlightTokens.GOLD)
	add_theme_color_override("font_hover_pressed_color", LeadlightTokens.GOLD)
	add_theme_color_override("font_disabled_color", Color(rest, 0.45))
