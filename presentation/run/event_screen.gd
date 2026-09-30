class_name EventScreen
extends Control
## A road event, staged (stagecraft). The application owns resolution and
## passes this view an immutable projection of the event and its current
## resolution state; the view stands the event's own painting full-bleed as
## the place, names it on a location card, speaks its prose into the leaded
## pane, and offers the choices from a choice window above it. Each event
## carries its own weather and grade, and a result beat its own effect
## (`content/event-staging.json`) — played once, when the beat first arrives,
## never on resume. The Flame's lantern hangs beside the choices once the run
## has a reading to show (`show_flame`), so a card cut, copied or added here is
## seen changing the flame here (lock §8, §9).

signal choice_selected(ordinal: int)
signal continue_requested

const EVENT_ART: String = "res://assets/art/events/%s.png"
const STAGING_PATH: String = "res://content/event-staging.json"
const WINDOW_W: float = 520.0
const WASH_ALPHA: float = 0.34
const DIM_ALPHA: float = 0.58

static var _staging: Dictionary = {}
static var _staging_loaded: bool = false

var shape: StringName = StageShape.IDENTITY
## The story beat this screen shows (`c0`…, `coda`), or "" for the choice.
var beat: String = ""

var _event_id: String
var _event: Dictionary
var _result_log: String
var _choices_enabled: bool
var _completed: bool
var _sfx: SfxBus
var _title: Label
var _art: TextureRect
var _body: Label
var _choices: VBoxContainer
var _buttons: Array[Button] = []
var _wash: ColorRect
var _ambient: SceneFx
var _front: SceneFx
var _copy: DialogueBox
var _window: PanelContainer
var _scroll: ScrollContainer
var _wash_goal: float = WASH_ALPHA
## The Flame, once a reading arrives (`show_flame`).
var _lantern: RunLantern = null


func _init(event_id: String, event_definition: Dictionary,
		result_log: String = "", choices_enabled: bool = true,
		completed: bool = false,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	_event_id = event_id
	_event = event_definition
	_result_log = result_log
	_choices_enabled = choices_enabled
	_completed = completed
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	RunStyle.add_backdrop(self)
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


## This event's staging row: ambient, grade and per-beat effects.
static func staging_for(event_id: String) -> Dictionary:
	if not _staging_loaded:
		_staging_loaded = true
		var loaded: Variant = load_staging(STAGING_PATH)
		if typeof(loaded) == TYPE_DICTIONARY:
			_staging = loaded
	var row: Variant = _staging.get(event_id, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


## Parse `content/event-staging.json`; unknown weather, grade or effect fails.
static func load_staging(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return "event-staging: missing %s" % path
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return "event-staging: root is not an object"
	var root: Dictionary = raw
	var events_v: Variant = root.get("events")
	if typeof(events_v) != TYPE_DICTIONARY:
		return "event-staging: missing events object"
	var events: Dictionary = events_v
	var out: Dictionary = {}
	for id_v: Variant in events:
		var id: String = str(id_v)
		var row_v: Variant = events[id_v]
		if typeof(row_v) != TYPE_DICTIONARY:
			return "event-staging: %s is not an object" % id
		var row: Dictionary = row_v
		var beat_out: Dictionary = {}
		var failed: String = StageDirection.parse_beat(row, beat_out, "event-staging: %s" % id)
		if not failed.is_empty():
			return failed
		var beats_v: Variant = row.get("beats", {})
		if typeof(beats_v) != TYPE_DICTIONARY:
			return "event-staging: %s beats is not an object" % id
		var beats: Dictionary = beats_v
		var clean: Dictionary = {}
		for key_v: Variant in beats:
			var line: Dictionary = {}
			failed = StageDirection.parse_line({"fx": beats[key_v]}, line,
				"event-staging: %s beat %s" % [id, key_v])
			if not failed.is_empty():
				return failed
			clean[str(key_v)] = line.get("fx", [])
		beat_out["beats"] = clean
		var dock: String = str(row.get("window", "left"))
		if not ["left", "right", "centre"].has(dock):
			return "event-staging: %s window '%s'" % [id, dock]
		beat_out["window"] = dock
		out[id] = beat_out
	return out


func _build() -> void:
	var row: Dictionary = staging_for(_event_id)
	var reduce: bool = Preferences.active.reduce_motion
	_art = TextureRect.new()
	_art.name = "Plate"
	var art_path: String = EVENT_ART % _event_id
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path) as Texture2D
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	var tone: StringName = row.get("grade", &"none")
	var tint: Color = SceneDirector.GRADES.get(tone, SceneDirector.GRADES[&"none"])
	var grade: ColorRect = _rect("Grade", tint)
	add_child(grade)
	_wash = _rect("Wash", Color(0.025, 0.020, 0.035, WASH_ALPHA))
	add_child(_wash)
	_ambient = SceneFx.new("AmbientFx")
	_ambient.reduce_motion = reduce
	var weather: StringName = row.get("ambient", &"none")
	_ambient.set_ambient(weather)
	add_child(_ambient)
	_front = SceneFx.new("FrontFx")
	_front.reduce_motion = reduce
	_front.allow_shake = Preferences.active.screen_shake
	add_child(_front)

	_title = _label(str(_event.get("name", Locale.active.t("ui.event.strangePlace"))).to_upper(),
		26, RunStyle.PARCHMENT, true)
	_title.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 3))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_outline_size", 6)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_copy = DialogueBox.new()
	_copy.reduce_motion = reduce
	add_child(_copy)
	_body = _copy.line_label()
	var prose: String = _result_log if not _result_log.is_empty() \
		else str(_event.get("text", ""))
	_copy.show_line(prose, "", StageDirection.STYLE_NARRATION, DialogueBox.HAIRLINE,
		&"left", false)

	_window = PanelContainer.new()
	_window.name = "ChoiceWindow"
	_window.add_theme_stylebox_override("panel", DialogueBox.window_style())
	add_child(_window)
	# Same reachability rule as #72's boon screen: the view travels with focus,
	# so a choice below the fold on a phone is never focused and invisible.
	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_window.add_child(_scroll)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_choices)
	if _completed:
		_add_continue()
	else:
		_add_choices()
	resized.connect(_layout)


func _add_choices() -> void:
	var rows: Array = _event.get("choices", [])
	for ordinal: int in range(rows.size()):
		var value: Variant = rows[ordinal]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var button: Button = Button.new()
		var sub: String = str(row.get("sub", ""))
		button.text = str(row.get("label", Locale.active.t("ui.common.leave"))) \
			+ ("\n%s" % sub if not sub.is_empty() else "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 52 if sub.is_empty() else 66
		button.disabled = not _choices_enabled or row.get("disabled", false)
		button.add_theme_font_override("font", GlassStyle.face(
			GlassStyle.CINZEL_700 if sub.is_empty() else GlassStyle.ALEGREYA_400))
		button.add_theme_font_size_override("font_size", 15)
		RunStyle.style_button(button, ordinal == 0)
		button.pressed.connect(_choose.bind(ordinal))
		button.mouse_entered.connect(_hover.bind(button))
		_choices.add_child(button)
		_buttons.append(button)


func _add_continue() -> void:
	var button: Button = Button.new()
	button.text = Locale.active.t("ui.event.continue")
	button.custom_minimum_size = Vector2(180, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_700))
	RunStyle.style_button(button, true)
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		continue_requested.emit()
	)
	_choices.add_child(button)
	_buttons.append(button)


## The beat just arrived (not a resume): play its effect once.
func play_beat() -> void:
	var beats: Dictionary = staging_for(_event_id).get("beats", {})
	var fx_list: Array = beats.get(beat, [])
	var cue: String = ""
	for fx_v: Variant in fx_list:
		var fx: StringName = StageDirection.fx_name(str(fx_v))
		if fx == &"dim":
			_wash_goal = DIM_ALPHA
			continue
		_front.play(fx)
		if cue.is_empty():
			cue = String(SceneDirector.cue_for(fx))
	if not cue.is_empty():
		_sfx.play(StringName(cue))


## The Flame's reading, in the hero's lantern beside the choices, so a card cut,
## copied or added here is seen changing the flame here (lock §8, §9). Main hands
## it the reading as the screen opens (`instant`) and again after each deck
## change. The lantern is built on the first reading, so a run whose aspect has
## no ways never grows one.
func show_flame(event: Dictionary, instant: bool = false) -> void:
	if _lantern == null:
		_hang_lantern(RunLantern.new(shape))
	_lantern.show_flame(event, instant)


## Carry on the lantern of the event screen this one replaces, as it stands and
## mid-tween if it is. A deck change is made on a choice and its result beat
## replaces that screen at once, so the flame would turn on a screen already
## gone; carried on, it turns on the one the player is looking at (lock §9:
## nothing snaps). False when `previous` has no lantern to give.
func inherit_lantern(previous: EventScreen) -> bool:
	if previous == null or previous._lantern == null:
		return false
	var lantern: RunLantern = previous._lantern
	previous._lantern = null
	previous.remove_child(lantern)
	lantern.set_shape(shape)
	_hang_lantern(lantern)
	return true


func _hang_lantern(lantern: RunLantern) -> void:
	_lantern = lantern
	add_child(lantern)
	# Under the title, the pane and the choices: were anything to crowd the
	# lantern, the words would still read.
	move_child(lantern, _title.get_index())
	_layout()


func _choose(ordinal: int) -> void:
	for button: Button in _buttons:
		button.disabled = true
	_sfx.play(&"click")
	choice_selected.emit(ordinal)


func _hover(button: Button) -> void:
	if not button.disabled:
		_sfx.play(&"hover", 0.45)


func _ready() -> void:
	_layout()
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			break


func _process(delta: float) -> void:
	_copy.advance_type(delta)
	_ambient.tick(delta)
	_front.tick(delta)
	_wash.color.a = move_toward(_wash.color.a, _wash_goal, delta * 1.2)


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		if _lantern != null:
			_lantern.set_shape(shape)
		_layout()


func _layout() -> void:
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		var ref: Vector2i = StageShape.REFERENCES[shape]
		view = Vector2(ref)
	var phone: bool = shape == &"phone-landscape"
	_copy.set_shape(shape)
	var pane: Rect2 = DialogueBox.box_rect(view, shape, StageDirection.STYLE_SPEECH)
	_copy.place(pane)
	_ambient.set_view(view)
	_front.set_view(view)
	_title.add_theme_font_size_override("font_size", 18 if phone else 26)
	var title_h: float = _title.get_combined_minimum_size().y
	_title.size = Vector2(view.x * 0.8, title_h)
	# On the phone the title takes its own band under the run HUD's top bar (the
	# bar carries the location line, and the title used to overprint it), and the
	# choices' window starts under the HUD's relic row, so nothing of the HUD's
	# stands over the window (#595). The pad and the desktop have room to spare.
	var title_y: float = view.y * 0.09
	if phone:
		title_y = RunHud.bar_bottom(shape) + RunHud.COLLECTION_GAP
	_title.position = Vector2(view.x * 0.1, title_y)
	var top: float = _title.position.y + title_h + (6.0 if phone else 18.0)
	if phone:
		top = maxf(top, RunHud.relic_row_bottom(shape) + RunHud.COLLECTION_GAP)
	var gap: float = 8.0 if phone else 20.0
	var w: float = minf(WINDOW_W, view.x - 28.0)
	var room: float = maxf(80.0, pane.position.y - gap - top)
	var want: float = _choices.get_combined_minimum_size().y
	var style_pad: float = 28.0
	var h: float = minf(want + style_pad, room)
	_scroll.custom_minimum_size = Vector2(w - style_pad, h - style_pad)
	_window.size = Vector2(w, h)
	# The choices dock to one side of the painting so its figure stays seen.
	var dock: String = str(staging_for(_event_id).get("window", "left"))
	var x: float = pane.position.x
	if dock == "right":
		x = pane.end.x - w
	elif dock == "centre":
		x = (view.x - w) * 0.5
	_window.position = Vector2(clampf(x, 14.0, view.x - w - 14.0), pane.position.y - gap - h)
	# The lantern keeps the reward and shop screens' seat, at the left under the
	# run HUD's chrome, unless the choices reach it: the phone's window does.
	if _lantern != null:
		_lantern.keep_clear_of(view.x, Rect2(_window.position, _window.size))


static func _rect(node_name: String, colour: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.name = node_name
	rect.color = colour
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _label(text: String, font_size: int, colour: Color,
		centred: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred \
		else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
