class_name LeadlightPlaque
extends VBoxContainer
## The lit name that belongs to the lantern (Back to the Road / Rekindle) and its
## optional sub-line: a flame glyph in the run's colour and where the run stands.
## The flame is shown, never named (dusk-flame lock: the player discovers it).

var _name: Label
var _sub_row: HBoxContainer
var _glyph: Glyph
var _sub: Label


class Glyph extends Control:
	var colour: Color = LeadlightTokens.EMBER

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var t: float = float(i) / 16.0 * TAU
			var x: float = sin(t) * w * 0.42
			var y: float = h * 0.62 - cos(t) * h * 0.36
			if cos(t) > 0.0:
				y -= cos(t) * h * 0.22
				x *= 1.0 - cos(t) * 0.45
			pts.append(Vector2(w * 0.5 + x, y))
		draw_texture_rect(SkyField.disc(), Rect2(Vector2(-w, -h * 0.4), Vector2(w * 3.0, h * 1.8)),
			false, Color(colour, 0.45))
		draw_colored_polygon(pts, colour.lerp(Color.WHITE, 0.35))


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_PLAQUE, stage_shape)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, px))
	_name.add_theme_font_size_override("font_size", px)
	_name.add_theme_color_override("font_color", LeadlightTokens.GOLD)
	_name.add_theme_color_override("font_shadow_color", Color(LeadlightTokens.GOLD, 0.30))
	_name.add_theme_constant_override("shadow_outline_size", 10)
	_name.add_theme_constant_override("shadow_offset_x", 0)
	_name.add_theme_constant_override("shadow_offset_y", 0)
	_name.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.85))
	_name.add_theme_constant_override("outline_size", 4)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_sub_row = HBoxContainer.new()
	_sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_row.add_theme_constant_override("separation", 8)
	_sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_row)
	var sub_px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_CAPTION, stage_shape)
	_glyph = Glyph.new()
	_glyph.custom_minimum_size = Vector2(float(sub_px) * 0.7, float(sub_px) * 1.1)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sub_row.add_child(_glyph)
	_sub = Label.new()
	_sub.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, sub_px))
	_sub.add_theme_font_size_override("font_size", sub_px)
	_sub.add_theme_color_override("font_color", LeadlightTokens.TEXT_DIM)
	_sub.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub_row.add_child(_sub)
	set_text("", "")


func set_text(title: String, sub: String, flame_colour: Color = LeadlightTokens.EMBER) -> void:
	_name.text = title.to_upper() if not LeadlightTokens.is_zh() else title
	_sub.text = sub.to_upper() if not LeadlightTokens.is_zh() else sub
	_sub_row.visible = not sub.is_empty()
	_glyph.colour = flame_colour
	_glyph.queue_redraw()


func title_label() -> Label:
	return _name
