class_name LeadlightConfirm
extends Control
## A yes-or-stay question in the same house: a small leaded arch over the
## dimmed route — its title in the crown, one line, the action as a lit pane and
## the way back as a quiet word beneath it. Begin Anew, Leave the Road, Abandon
## Run and Erase Everything all ask through this one sheet.
##
## The quiet word is the safe answer: it holds the first focus, Escape and a
## tap on the veil choose it. The pane dips under the hand before the answer is
## sent, so the press is seen; outside a tree (tests) or under Reduce Motion the
## answer goes at once.

signal chosen(id: String)

const VEIL_ALPHA: float = 0.62
const SPRING: float = 0.3

var shape: StringName = StageShape.IDENTITY
var _primary_id: String
var _quiet_id: String
var _sfx: SfxBus
var _veil: ColorRect
var _sheet: LeadlightSheet
var _title: Label
var _column: VBoxContainer
var _body: Label
var _primary: LeadlightPane
var _quiet: LeadlightWord
var _answered: bool = false


## `primary` and `quiet` are {"id", "label"}; `danger` tints the action pane
## for a choice that cannot be taken back.
func _init(title_text: String, body_text: String, primary: Dictionary, quiet: Dictionary,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null,
		danger: bool = false) -> void:
	name = "LeadlightConfirm"
	shape = stage_shape
	_sfx = sfx
	_primary_id = str(primary.get("id", ""))
	_quiet_id = str(quiet.get("id", ""))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(LeadlightTokens.VOID, VEIL_ALPHA)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(_on_veil_input)
	add_child(_veil)
	_sheet = LeadlightSheet.new()
	_sheet.name = "Sheet"
	_sheet.spring = SPRING
	_sheet.sharpness = 1.6
	_sheet.light_at = Vector2(0.5, 1.08)
	if danger:
		_sheet.light_colour = LeadlightTokens.DANGER.lerp(LeadlightTokens.EMBER, 0.45)
	add_child(_sheet)
	_title = Label.new()
	_title.name = "ConfirmTitle"
	_title.text = title_text if LeadlightTokens.is_zh() else title_text.to_upper()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", LeadlightTokens.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_title)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_sheet.content().add_child(_column)
	_body = Label.new()
	_body.name = "ConfirmLine"
	_body.text = body_text
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", LeadlightTokens.TEXT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_body)
	_primary = LeadlightPane.new(str(primary.get("label", "")), stage_shape,
		LeadlightGlassBox.Shape.LOZENGE)
	_primary.name = "ConfirmAction"
	_primary.lit = true
	if danger:
		_primary.accent = LeadlightTokens.DANGER
		_primary.lit = true
	_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_primary.pressed.connect(_choose.bind(_primary_id, _primary))
	_column.add_child(_primary)
	_quiet = LeadlightWord.new(str(quiet.get("label", "")), stage_shape)
	_quiet.name = "ConfirmStay"
	_quiet.near = true
	_quiet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_quiet.pressed.connect(_choose.bind(_quiet_id, _quiet))
	_column.add_child(_quiet)
	_fit_type()


func _ready() -> void:
	_layout()
	LeadlightFocus.give(_quiet)
	if _sfx != null:
		_sfx.play_owed(&"roomOpen")
	LeadlightMotion.enter(_sheet)
	var veil_in: Tween = create_tween()
	_veil.modulate.a = 0.0
	veil_in.tween_property(_veil, "modulate:a", 1.0,
		LeadlightMotion.REDUCED_FADE if LeadlightMotion.reduced() else LeadlightMotion.QUICK)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_fit_type()
	_layout()


## The answer this sheet would give to Escape, a veil tap or the quiet word.
func quiet_id() -> String:
	return _quiet_id


func primary_id() -> String:
	return _primary_id


func action() -> LeadlightPane:
	return _primary


func stay() -> LeadlightWord:
	return _quiet


func sheet() -> LeadlightSheet:
	return _sheet


func _fit_type() -> void:
	var phone: bool = LeadlightTokens.is_phone(shape)
	var title_px: int = 15 if phone else 19
	_title.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, title_px))
	_title.add_theme_font_size_override("font_size", title_px)
	var read: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_READ, shape)
	_body.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, read))
	_body.add_theme_font_size_override("font_size", read)
	_column.add_theme_constant_override("separation", 6 if phone else 12)
	_primary.custom_minimum_size.x = 200.0 if phone else 248.0


## The sheet is as tall as what it holds: its width comes from the stage, the
## line wraps inside it, and the arch's crown is added above.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var phone: bool = LeadlightTokens.is_phone(shape)
	var width: float = clampf(size.x * (0.5 if phone else 0.44), 300.0, 540.0)
	var inset: float = clampf(width * 0.05, 18.0, 44.0)
	_body.custom_minimum_size.x = width - inset * 2.0 - 12.0
	var held: float = _column.get_combined_minimum_size().y
	var bottom: float = 18.0 if phone else 26.0
	var height: float = minf((held + 6.0 + bottom) / (1.0 - SPRING), size.y - 16.0)
	_sheet.size = Vector2(width, height)
	_sheet.position = ((size - _sheet.size) * 0.5).round()
	_sheet.content().add_theme_constant_override("margin_top", int(height * SPRING + 6.0))
	_sheet.content().add_theme_constant_override("margin_bottom", int(bottom))
	# In the crown: below the point, above the spring.
	_title.position = Vector2(0.0, height * SPRING * 0.62 - _title.get_combined_minimum_size().y * 0.5)
	_title.size = Vector2(width, 0.0)


func _choose(id: String, by: Control) -> void:
	if _answered:
		return
	_answered = true
	if _sfx != null and id == _primary_id:
		_sfx.play_owed(&"paneChoose", &"click")
	elif _sfx != null:
		_sfx.play_owed(&"roomClose")
	var dip: Tween = LeadlightMotion.press(by)
	if dip == null or not is_inside_tree():
		chosen.emit(id)
		return
	get_tree().create_timer(LeadlightMotion.TICK).timeout.connect(chosen.emit.bind(id))


func _on_veil_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if (mouse != null and mouse.pressed) or (touch != null and touch.pressed):
		_choose(_quiet_id, _quiet)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_choose(_quiet_id, _quiet)
		get_viewport().set_input_as_handled()
