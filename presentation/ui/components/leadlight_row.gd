class_name LeadlightRow
extends HBoxContainer
## One setting: its name on the left in the reading face, its control on the
## right, a lead hairline beneath. 48px tall on pad, 44 on a phone.

var rule: bool = true
var _label: Label


func _init(label_text: String, control: Control,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size.y = 44.0 if LeadlightTokens.is_phone(stage_shape) else 48.0
	_label = Label.new()
	_label.text = label_text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_READ, stage_shape)
	_label.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	_label.add_theme_font_size_override("font_size", px)
	_label.add_theme_color_override("font_color", LeadlightTokens.TEXT)
	add_child(_label)
	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(control)


func label() -> Label:
	return _label


func _draw() -> void:
	if rule:
		draw_line(Vector2(0.0, size.y - 0.5), Vector2(size.x, size.y - 0.5),
			Color(LeadlightTokens.GOLD_DIM, 0.22), 1.0)
