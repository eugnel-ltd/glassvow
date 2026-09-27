class_name HollowScreen
extends Control
## Persisted Hollow Lamplighter interruption on an Unlit Way, staged as the
## meeting's own two-shot (stagecraft): the hero on the left, the Lamplighter
## lit on the right, his ask typed into the leaded pane under his plaque, and
## the price as a choice window between them. The night road carries the same
## dusk grade and falling ash as the meeting's pre- and post-scenes, so the
## three read as one conversation. His posture follows the price — asking,
## wary when it cannot be met, recognising once it is paid — and paying
## kindles your embers into the dark lantern.

signal action_requested(action: StringName)

const HOLLOW: String = "res://assets/art/meta/hollow-lamplighter.png"
const ACTOR: String = "lamplighter"
const MOOD_ASK: String = "asking"
const MOOD_PAID: String = "recognising"
const MOOD_REFUSED: String = "wary"

var shape: StringName = StageShape.IDENTITY

var _pending: Dictionary
var _meeting: Dictionary
var _meeting_number: int
var _target: int
var _hero: String = ""
var _sfx: SfxBus
var _book: ActorBook
var _stage: PortraitStage
var _ambient: SceneFx
var _front: SceneFx
var _header: VBoxContainer
var _copy: DialogueBox
var _window: PanelContainer
var _kicker: Label
var _title: Label
var _ask: Label
var _answer: Label
var _error: Label
var _actions: GridContainer
var _pay: Button
var _continue: Button
var _leave: Button


func _init(pending: Dictionary, meeting: Dictionary, meeting_number: int,
		target: int, stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null, hero: String = "") -> void:
	_pending = pending
	_meeting = meeting
	_meeting_number = clampi(meeting_number, 1, maxi(1, target))
	_target = maxi(1, target)
	_hero = hero
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_book = ActorBook.shared()
	_build()


func _build() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = GlassStyle.grad_tex(
		PackedColorArray([Color("#05080d"), Color("#0a1118"), Color("#08090f")]),
		PackedFloat32Array([0.0, 0.48, 1.0]), false,
		Vector2.ZERO, Vector2.RIGHT)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var grade: ColorRect = ColorRect.new()
	grade.color = SceneDirector.GRADES[&"dusk"]
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grade)
	var reduce: bool = Preferences.active.reduce_motion
	_ambient = SceneFx.new("AmbientFx")
	_ambient.reduce_motion = reduce
	_ambient.set_ambient(&"ash")
	add_child(_ambient)
	_stage = PortraitStage.new(_book, _hero)
	_stage.reduce_motion = reduce
	add_child(_stage)
	_front = SceneFx.new("FrontFx")
	_front.reduce_motion = reduce
	_front.allow_shake = Preferences.active.screen_shake
	add_child(_front)

	_header = VBoxContainer.new()
	_header.alignment = BoxContainer.ALIGNMENT_CENTER
	_header.add_theme_constant_override("separation", 2)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)
	_kicker = _label(
		Locale.active.t("ui.hollow.kicker", {
			"current": _meeting_number, "total": _target}),
		11, Color("#83939d"))
	_kicker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(_kicker)
	_title = _label(Locale.active.t("ui.hollow.title"), 30, Color("#c3cdd2"))
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 2))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(_title)

	_copy = DialogueBox.new()
	_copy.reduce_motion = reduce
	add_child(_copy)
	_ask = _copy.line_label()

	_window = PanelContainer.new()
	_window.name = "ChoiceWindow"
	_window.add_theme_stylebox_override("panel", _window_style())
	add_child(_window)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_window.add_child(column)
	_actions = GridContainer.new()
	_actions.columns = 1
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 8)
	column.add_child(_actions)
	_pay = _action(Locale.active.t("ui.hollow.payPrice").to_upper(), &"pay", true)
	_actions.add_child(_pay)
	_continue = _action(Locale.active.t("ui.common.continue").to_upper(), &"continue", false)
	_actions.add_child(_continue)
	_leave = _action(Locale.active.t("ui.hollow.returnLater").to_upper(), &"leave", false)
	_actions.add_child(_leave)
	_answer = _label("", 13, Color("#d9c98c"))
	_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_answer)
	_error = _label("", 12, Color("#e2a0a0"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_error)

	# The ask arrives typed, as every line on the stagecraft pane does.
	_copy.show_line("“%s”" % str(_meeting.get("ask", "")),
		Locale.active.t(_book.name_key(ACTOR)), StageDirection.STYLE_SPEECH,
		_book.tint(ACTOR), &"right", false)
	var paid: bool = str(_pending.get("paid", false)) == "true"
	_stand(MOOD_PAID if paid else MOOD_ASK, true)
	set_paid(paid, str(_pending.get("answer", "")))
	resized.connect(_layout)
	set_shape(shape)


func _action(text: String, action: StringName, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 42)
	RunStyle.style_button(button, primary, Color("#83939d"))
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		action_requested.emit(action)
	)
	return button


func set_paid(paid: bool, answer: String = "") -> void:
	_pending["paid"] = paid
	_pending["answer"] = answer
	_answer.text = _message_text(answer)
	_answer.add_theme_color_override(
		"font_color", Color("#d9c98c") if paid else Color("#9eabb2"))
	_pay.text = (Locale.active.t("ui.hollow.pricePaid") if paid \
		else Locale.active.t("ui.hollow.payPrice")).to_upper()
	_pay.disabled = paid
	_continue.disabled = not paid
	_leave.disabled = paid
	_error.text = ""
	_sync_notes()
	_stand(MOOD_PAID if paid else MOOD_ASK, false)


func show_error(message: String) -> void:
	_error.text = _message_text(message)
	_answer.text = ""
	_pay.disabled = false
	_continue.disabled = true
	_leave.disabled = false
	_sync_notes()
	_stand(MOOD_REFUSED, false)
	_stage.actor_fx(&"recoil", ACTOR)


## The price just landed: your embers kindle across into the hollow lantern
## (which, being hollow, still does not light — the post-scene says so).
func play_paid() -> void:
	var giver: StagePortrait = _stage.portrait("hero")
	var taker: StagePortrait = _stage.portrait(ACTOR)
	if giver == null or taker == null:
		return
	_front.play(&"kindle", giver.hands(), taker.hands())
	_stage.actor_fx(&"kindle", ACTOR)
	_sfx.play(&"kindle")


func _stand(mood: String, instant: bool) -> void:
	var cast: Array[Dictionary] = [
		{"id": "hero", "at": &"left", "mood": ""},
		{"id": ACTOR, "at": &"right", "mood": mood},
	]
	_stage.stage(cast, ACTOR, instant)


## Empty notes take no room in the choice window.
func _sync_notes() -> void:
	_answer.visible = not _answer.text.is_empty()
	_error.visible = not _error.text.is_empty()
	if is_inside_tree():
		_layout.call_deferred()


func _ready() -> void:
	# The window's minimum size is only final once the theme reaches it.
	_layout.call_deferred()


static func _message_text(message: String) -> String:
	if message.begins_with("ui.hollow.message."):
		return Locale.active.t(message)
	return message


func _process(delta: float) -> void:
	_copy.advance_type(delta)
	_stage.tick(delta)
	_ambient.tick(delta)
	_front.tick(delta)


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var short: bool = shape == &"phone-landscape"
	_actions.columns = 3 if short else 1
	for button: Button in [_pay, _continue, _leave]:
		button.custom_minimum_size = Vector2(150 if short else 220, 38 if short else 42)
	_title.add_theme_font_size_override("font_size", 20 if short else 30)
	_copy.set_shape(shape)
	_layout()


func _layout() -> void:
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		var ref: Vector2i = StageShape.REFERENCES[shape]
		view = Vector2(ref)
	var short: bool = shape == &"phone-landscape"
	var pane: Rect2 = DialogueBox.box_rect(view, shape, StageDirection.STYLE_SPEECH)
	_copy.place(pane)
	_stage.set_view(view, shape)
	_ambient.set_view(view)
	_front.set_view(view)
	var head: Vector2 = _header.get_combined_minimum_size()
	_header.size = Vector2(view.x * 0.6, head.y)
	_header.position = Vector2(view.x * 0.2, view.y * (0.03 if short else 0.09))
	# On a phone the location card gives way to the choice window.
	_header.visible = not short
	var win: Vector2 = _window.get_combined_minimum_size()
	_window.size = win
	_window.position = Vector2((view.x - win.x) * 0.5,
		pane.position.y - win.y - (10.0 if short else 22.0))


func _window_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.034, 0.055, 0.90)
	box.set_border_width_all(4)
	box.border_color = DialogueBox.LEAD
	box.set_corner_radius_all(10)
	box.set_content_margin_all(14)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 18
	return box


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
