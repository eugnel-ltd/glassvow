class_name LeadlightPane
extends Button
## Secondary action: a leaded lozenge of glass (Rekindle beside a saved run, the
## first-launch language panes, Embark's choices). `lit` is the chosen or
## pre-lit pane; in toggle mode the pressed pane is lit (settings sections).

var lit: bool = false:
	set(value):
		lit = value
		_restyle()
var shape_kind: LeadlightGlassBox.Shape = LeadlightGlassBox.Shape.LOZENGE
var accent: Color = LeadlightTokens.GOLD
var _shape: StringName = StageShape.IDENTITY
var _px: int = 15


func _init(label: String = "", stage_shape: StringName = StageShape.IDENTITY,
		kind: LeadlightGlassBox.Shape = LeadlightGlassBox.Shape.LOZENGE) -> void:
	text = label
	_shape = stage_shape
	shape_kind = kind
	_px = LeadlightTokens.size_for(LeadlightTokens.SIZE_PANE, stage_shape)
	focus_mode = Control.FOCUS_ALL
	clip_text = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	custom_minimum_size.y = RunStyle.hit_floor(34.0 if LeadlightTokens.is_phone(stage_shape) else 44.0)
	add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, _px))
	add_theme_font_size_override("font_size", _px)
	toggled.connect(func(_on: bool) -> void: _restyle())
	_restyle()


## Grow the pane to an exact size (the stage shape picks it).
func set_px(px: int) -> void:
	_px = px
	add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, px))
	add_theme_font_size_override("font_size", px)


func _restyle() -> void:
	var on: bool = lit or (toggle_mode and button_pressed)
	var cut: float = 10.0 if LeadlightTokens.is_phone(_shape) else 12.0
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, LeadlightGlassBox.make(shape_kind, state, on, cut, accent))
	# Lit glass carries ink; cold glass carries parchment, gold under the hand.
	# A press always lights the pane, so the pressed ink is always ink.
	var rest: Color = LeadlightTokens.INK if on else LeadlightTokens.PARCHMENT
	add_theme_color_override("font_color", rest)
	add_theme_color_override("font_focus_color", rest)
	add_theme_color_override("font_hover_color", LeadlightTokens.INK if on else LeadlightTokens.GOLD)
	add_theme_color_override("font_pressed_color", LeadlightTokens.INK)
	add_theme_color_override("font_hover_pressed_color", LeadlightTokens.INK)
	add_theme_color_override("font_disabled_color", Color(LeadlightTokens.TEXT_DIM, 0.45))
