class_name ScenePlayer
extends Control
## Shared scripted-scene sequencer. DawnScreen's beat grammar over a
## full-bleed plate that degrades to graded ground, staged by SceneDirector:
## a JRPG two-shot of lit and unlit glass portraits, the leaded dialogue pane
## with its typed reveal, beat weather and grade, and one-shot effects.

signal advance_requested
signal finished

const REVEAL_TIME: float = 0.55
## Reading pace, not a fixed beat. DawnScreen's flat 1.6s was sized for a
## short result card; a line of dialogue is not one, and a long line would
## walk out from under the player mid-sentence. A tap always pre-empts the
## dwell, so this only ever sets the hands-off pace.
##
## KNOWN CEILING: one rate serves both locales, and zh-Hant carries roughly
## twice the meaning per character that English does — so a zh line dwells
## too briefly at the same count. Both constants are placeholder-era and get
## measured once real copy lands (story Batch 2 / Batch 4, #263).
const DWELL_BASE: float = 1.2
const DWELL_PER_CHAR: float = 0.09
const SKIP_HOLD: float = 0.6
const SKIP_WAIT: float = 0.04
const PUSH_IN_TIME: float = 8.0
const PUSH_IN_SCALE: float = 1.08
const LINGER_SCALE: float = 1.06
const LINGER_AMP: Vector2 = Vector2(12.0, 8.0)

const BEAT_IDLE: int = 0
const BEAT_REVEAL: int = 1
const BEAT_WAIT: int = 2

var instant: bool = false
var shape: StringName = StageShape.IDENTITY
var _pool_row: Dictionary = {}

var _script: SceneScript
var _cursor: int = 0
var _sfx: SfxBus
var _beat: int = BEAT_IDLE
var _beat_t: float = 0.0
var skipped: bool = false
var _hold_t: float = 0.0
var _holding: bool = false
var _skipping: bool = false
var _asked: bool = false
var _done: bool = false
var _motion_t: float = 0.0
var _motion: String = "hold"
var _beat_i: int = -1
var _plate_host: Control
var _plate: TextureRect
var _copy: DialogueBox
var _speaker: Label
var _line: Label
var _caption_seat: VBoxContainer
var _caption: Label
var _skip_fill: ColorRect
var _letter_top: ColorRect
var _letter_bot: ColorRect
var _hearth_figure: HearthFigure = null
var _unsealing: UnsealingStaging = null
var _unsealing_sting_beat: int = -1
var _finale: FinaleStaging = null
var _walk_t: float = 0.0
var _director: SceneDirector
var _hero: String = ""
var _presented: bool = false
var _arriving: bool = false
var _reveal_for: float = REVEAL_TIME


## `hero` is the run's aspect id; the `hero` actor wears its figure.
func _init(scene_script: SceneScript, cursor: int = 0,
		stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null,
		pool_row: Dictionary = {}, hero: String = "") -> void:
	_script = scene_script
	_hero = hero
	_cursor = clampi(cursor, 0, scene_script.line_count())
	_pool_row = pool_row.duplicate(true)
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _ready() -> void:
	if _cursor >= _script.line_count():
		_complete()
	else:
		_begin_beat()
	set_process(true)


func _build() -> void:
	var ground: TextureRect = TextureRect.new()
	ground.texture = GlassStyle.grad_tex(
		PackedColorArray([GlassStyle.NIGHT_TOP, GlassStyle.NIGHT_BOT]),
		PackedFloat32Array([0.0, 1.0]), false, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.name = "Ground"
	add_child(ground)
	_plate_host = Control.new()
	_plate_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate_host.clip_contents = true
	_plate_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate_host)
	_plate = TextureRect.new()
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.name = "Plate"
	_plate_host.add_child(_plate)
	_director = SceneDirector.new(ActorBook.shared(), _hero, _sfx)
	add_child(_director.grade)
	add_child(_director.wash)
	add_child(_director.ambient_fx)
	add_child(_director.stage)
	add_child(_director.front_fx)
	_director.front_fx.shake_targets = [_plate_host, _director.stage]
	_letter_top = _band()
	_letter_bot = _band()
	add_child(_letter_top)
	add_child(_letter_bot)
	_copy = _director.box
	add_child(_copy)
	_speaker = _copy.speaker_label()
	_line = _copy.line_label()
	_caption_seat = VBoxContainer.new()
	_caption_seat.alignment = BoxContainer.ALIGNMENT_CENTER
	_caption_seat.add_theme_constant_override("separation", 3)
	_caption_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption_seat)
	_caption = _label(Locale.active.t("ui.dawn.inputHint"), 10,
		Color(RunStyle.TEXT_DIM, 0.85))
	_caption.name = "Caption"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption_seat.add_child(_caption)
	_skip_fill = ColorRect.new()
	_skip_fill.name = "SkipFill"
	_skip_fill.color = RunStyle.GOLD
	_skip_fill.custom_minimum_size = Vector2(0.0, 2.0)
	_skip_fill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_seat.add_child(_skip_fill)
	add_child(_director.veil)
	resized.connect(_layout_stage)
	set_shape(shape)


func advance_confirmed() -> void:
	if _done:
		return
	_cursor += 1
	if _cursor >= _script.line_count():
		_complete()
	else:
		_begin_beat()


func _begin_beat() -> void:
	_asked = false
	# Skip momentum dies at the walk (07-scenes §5): a fast-forward that
	# reaches a walk line still owes the step to the player's own hand.
	if _walk_line():
		_skipping = false
		_walk_t = 0.0
	_present_line()
	_beat = BEAT_REVEAL
	_beat_t = 0.0
	if instant or _skipping:
		_copy.modulate.a = 1.0
		_finish_beat()
		return
	# The pane fades in only when it arrives; within a conversation it stays
	# and the words type in (07-scenes §1: tap lands the reveal, then steps).
	_copy.modulate.a = 0.0 if _arriving else 1.0
	_reveal_for = maxf(REVEAL_TIME, _copy.type_time())


func _finish_beat() -> void:
	_beat = BEAT_WAIT
	_beat_t = 0.0
	_copy.complete()


func _complete() -> void:
	_beat = BEAT_IDLE
	_caption.visible = false
	_skip_fill.visible = false
	if _done:
		return
	_done = true
	finished.emit()


func _present_line() -> void:
	if _cursor < 0 or _cursor >= _script.line_count():
		return
	var row: Dictionary = _script.lines[_cursor]
	var text: String = ""
	var lines: Array[Dictionary] = _script.lines
	if not _pool_row.is_empty():
		text = LineTable.text(_pool_row, Locale.active.code == Locale.CODE_ZH_HANT)
		lines = [_pool_line()]
	else:
		text = Locale.active.t(str(row["key"]))
	var animate: bool = not instant and not _skipping
	var beat_i: int = row["beat"]
	if beat_i != _beat_i:
		_beat_i = beat_i
		_motion_t = 0.0
		_motion = str(_script.beat_at(_cursor).get("motion", "hold"))
		_bind_plate()
		_director.begin_beat(_script.beat_at(_cursor), animate)
		_sync_unsealing()
	# A resumed scene stands its cast at once; a fresh one walks them on.
	var stand_instant: bool = not _presented and _cursor > 0
	_arriving = _director.present(lines, 0 if not _pool_row.is_empty() else _cursor,
		text, animate, stand_instant)
	_presented = true
	_sync_hearth_figure()
	_caption.visible = true
	_caption.text = _caption_text()
	_skip_fill.visible = not _walk_cursor()
	_sync_finale()


## The caption carries the beat's own hand: the walk lines name their input
## form, the short door crossing says "walk in", everything else keeps the
## shared tap/hold hint.
func _caption_text() -> String:
	if _walk_cursor():
		return Locale.active.t(FinaleStaging.caption_key())
	if _script.id == "unsealing-short":
		return Locale.active.t("ui.map.walkIn")
	return Locale.active.t("ui.dawn.inputHint")


func _bind_plate() -> void:
	var path: String = _art_path(_cursor)
	if path.is_empty():
		_plate.texture = null
		_plate.visible = false
		return
	_plate.texture = load(path) as Texture2D
	_plate.visible = _plate.texture != null


## A pool row is one line; a registered speaker with a body steps into their
## own seat, anyone else (a walker's echo) is heard, not seen.
func _pool_line() -> Dictionary:
	var speaker: String = str(_pool_row.get("speaker", "")).strip_edges()
	var line: Dictionary = {"key": "pool.inline", "beat": 0}
	var book: ActorBook = ActorBook.shared()
	if not book.has(speaker):
		line["style"] = String(StageDirection.STYLE_WHISPER)
		return line
	line["speaker"] = speaker
	if not str(book.resolve(speaker, "", _hero)["path"]).is_empty():
		line["enter"] = [{"id": speaker, "at": String(book.side(speaker))}]
	return line


## One Keeper body at a time (#334's rule, kept): the seated figure is the
## wide shot; when the Keeper steps into the two-shot as a portrait, the
## hearth step is empty behind them. The pane keeps clear of the seat.
func _sync_hearth_figure() -> void:
	var wanted: bool = _script.id == "opening" and HearthFigure.present()
	if not wanted:
		if _hearth_figure != null:
			_hearth_figure.queue_free()
			_hearth_figure = null
		_director.set_clear_right(0.0)
		return
	_hearth_figure = HearthFigure.attach(_plate)
	_hearth_figure.visible = _plate.visible \
		and not _director.stage.has_actor("keeper")
	_director.set_clear_right(
		HearthFigure.SEAT_LEFT if _hearth_figure.visible else 0.0)


func _sync_unsealing() -> void:
	if _script.id != "unsealing":
		if _unsealing != null:
			_unsealing.queue_free()
			_unsealing = null
		_unsealing_sting_beat = -1
		return
	if _unsealing == null:
		_unsealing = UnsealingStaging.new()
		_plate_host.add_child(_unsealing)
	_unsealing.present(_beat_i, instant or Preferences.active.reduce_motion)
	if _beat_i == UnsealingStaging.STING_BEAT \
			and _unsealing_sting_beat != UnsealingStaging.STING_BEAT:
		_unsealing_sting_beat = UnsealingStaging.STING_BEAT
		_sfx.play(UnsealingStaging.STING_CUE)


## The finale's walk-out overlay (07-scenes §5). Attached for the whole
## scene; it only shows itself from the first walk line onward.
func _sync_finale() -> void:
	if _script.id != "finale":
		if _finale != null:
			_finale.queue_free()
			_finale = null
		return
	if _finale == null:
		_finale = FinaleStaging.new()
		add_child(_finale)
	_finale.present(_walk_cursor(), _walk_steps_done())


## The cursor stands on a walk line — the position check alone, so capture
## stills (instant) still render the walk affordance.
func _walk_cursor() -> bool:
	if _script.id != "finale" or _cursor < 0 or _cursor >= _script.line_count():
		return false
	return FinaleStaging.walk_key(str(_script.lines[_cursor]["key"]))


## The one grammar-break check (07-scenes §5): a walk line never advances on
## its own, and skip cannot cross it — only the player's hand moves the step.
## Instant mode (headless tests) keeps the shared grammar.
func _walk_line() -> bool:
	return not instant and _walk_cursor()


func _walk_steps_done() -> int:
	var done: int = 0
	for i: int in range(mini(_cursor, _script.line_count())):
		if FinaleStaging.walk_key(str(_script.lines[i]["key"])):
			done += 1
	return done


func _art_path(index: int) -> String:
	var intended: String = ""
	for i: int in range(index + 1):
		var art: String = str(_script.beat_at(i).get("art", ""))
		if not art.is_empty():
			intended = art
	if not intended.is_empty() and ResourceLoader.exists(intended):
		return intended
	for i: int in range(index, -1, -1):
		var art: String = str(_script.beat_at(i).get("art", ""))
		if not art.is_empty() and ResourceLoader.exists(art):
			return art
	return ""


func _process(delta: float) -> void:
	_apply_motion(delta)
	var typed: bool = _director.tick(delta)
	if _holding and _beat != BEAT_IDLE:
		if _walk_line():
			_hold_walk(delta)
		else:
			_hold_t += delta
			_skip_fill.custom_minimum_size.x = maxf(_caption.size.x, 220.0) \
				* clampf(_hold_t / SKIP_HOLD, 0.0, 1.0)
			if _hold_t >= SKIP_HOLD and not _skipping:
				_skipping = true
				skipped = true
				_sfx.play(&"click")
				# Fast-forward lands a line still typing; its floor (below)
				# then counts from the moment it stands whole.
				if _beat == BEAT_REVEAL:
					_copy.modulate.a = 1.0
					_director.settle()
					_finish_beat()
				# Do not emit on arm. The WAIT branch below enforces `_beat_t`
				# against `_skip_wait()`, so a hold that arms on beat ② still
				# owes the destination floor instead of skipping it.
	match _beat:
		BEAT_REVEAL:
			_beat_t += delta
			if _arriving:
				var u: float = clampf(_beat_t / REVEAL_TIME, 0.0, 1.0)
				_copy.modulate.a = 1.0 if Preferences.active.reduce_motion \
					else Motion.ease(Motion.CSS_EASE, u)
			if _beat_t >= _reveal_for and typed:
				_copy.modulate.a = 1.0
				_finish_beat()
		BEAT_WAIT:
			if _walk_line():
				return  # the grammar break: only the hand advances a step
			_beat_t += delta
			var wait: float = 0.0 if instant else _skip_wait()
			if _beat_t >= wait and not _asked:
				_asked = true
				advance_requested.emit()


## FORM_HOLD's walk: the held press fills to a step. FORM_STEP holds nothing
## on a walk line — the tap is the step, and skip can never arm here.
func _hold_walk(delta: float) -> void:
	if FinaleStaging.form != FinaleStaging.FORM_HOLD \
			or _beat != BEAT_WAIT or _asked:
		return
	_walk_t += delta
	if _finale != null:
		_finale.set_fill(_walk_t / FinaleStaging.HOLD_TIME)
	if _walk_t >= FinaleStaging.HOLD_TIME:
		_walk_t = 0.0
		_sfx.play(&"click")
		_asked = true
		advance_requested.emit()


## How long a settled line holds before it asks on its own.
func _dwell() -> float:
	return DWELL_BASE + DWELL_PER_CHAR * float(_line.text.length())


## Skip is 40 ms/line unless the beat names a floor. The design holds a
## minimum ~1 s on beat ② (the destination-naming beat) — once, on that
## beat's first line, not 1 s stacked on every line of the beat.
func _skip_wait() -> float:
	if not _skipping:
		return _dwell()
	var floor_s: float = float(str(_script.beat_at(_cursor).get("skip_dwell", 0.0)))
	if floor_s <= 0.0:
		return SKIP_WAIT
	if _cursor > 0:
		var row: Dictionary = _script.lines[_cursor]
		var prev: Dictionary = _script.lines[_cursor - 1]
		var beat_i: int = row["beat"]
		var prev_i: int = prev["beat"]
		if beat_i == prev_i:
			return SKIP_WAIT
	return floor_s


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_press(mouse.pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo:
		return
	if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_press(key_event.pressed)


func _press(down: bool) -> void:
	if _beat == BEAT_IDLE:
		return
	if down:
		_holding = true
		_hold_t = 0.0
		_walk_t = 0.0
		return
	if not _holding:
		return
	_holding = false
	var was_tap: bool = _hold_t < SKIP_HOLD
	_hold_t = 0.0
	_skip_fill.custom_minimum_size.x = 0.0
	if _walk_line():
		_release_walk(was_tap)
		return
	if not was_tap or _skipping or _asked:
		return
	_sfx.play(&"click")
	if _beat == BEAT_WAIT:
		_asked = true
		advance_requested.emit()
	elif _beat == BEAT_REVEAL:
		# 07-scenes §1: a tap mid-reveal lands the line; the next tap steps.
		# One tap never costs the player a line they have not seen whole.
		_copy.modulate.a = 1.0
		_director.settle()
		_finish_beat()


## Release on a walk line. A tap mid-reveal only settles the line — the step
## itself is a second, deliberate press. FORM_HOLD lets go of an unfinished
## walk without stepping; FORM_STEP steps on the tap.
func _release_walk(was_tap: bool) -> void:
	_walk_t = 0.0
	if _finale != null:
		_finale.set_fill(0.0)
	if not was_tap or _asked:
		return
	if _beat == BEAT_REVEAL:
		_copy.modulate.a = 1.0
		_finish_beat()
		return
	if FinaleStaging.form == FinaleStaging.FORM_STEP and _beat == BEAT_WAIT:
		_sfx.play(&"click")
		_asked = true
		advance_requested.emit()


func _apply_motion(delta: float) -> void:
	var host_size: Vector2 = _plate_host.size
	if host_size.x < 1.0 or host_size.y < 1.0:
		return
	var scale_n: float = 1.0
	var drift: Vector2 = Vector2.ZERO
	if not instant and not Preferences.active.reduce_motion:
		match _motion:
			"push-in":
				_motion_t += delta
				var u: float = clampf(_motion_t / PUSH_IN_TIME, 0.0, 1.0)
				scale_n = lerpf(1.0, PUSH_IN_SCALE, Motion.ease(Motion.EASE_IN_OUT, u))
			"linger":
				_motion_t += delta
				scale_n = LINGER_SCALE
				drift = Vector2(sin(_motion_t * 0.15) * LINGER_AMP.x,
					sin(_motion_t * 0.11) * LINGER_AMP.y)
	var cover: Vector2 = host_size * scale_n
	_plate.size = cover
	_plate.position = (host_size - cover) * 0.5 + drift


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	var short: bool = shape == &"phone-landscape"
	var band: float = 0.05 if short else 0.08
	_set_band(_letter_top, 0.0, band)
	_set_band(_letter_bot, 1.0 - band, 1.0)
	# The input hint sits in the lower letterbox band, under the pane.
	_caption_seat.anchor_left = 0.2
	_caption_seat.anchor_right = 0.8
	_caption_seat.anchor_top = 1.0 - band
	_caption_seat.anchor_bottom = 1.0
	for side: String in ["offset_left", "offset_right", "offset_top", "offset_bottom"]:
		_caption_seat.set(side, 0.0)
	_layout_stage()


## Stage-space layout. Outside a tree the size is zero, so the reference
## shape stands in — headless tests then read the real geometry.
func _layout_stage() -> void:
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		var ref: Vector2i = StageShape.REFERENCES[shape]
		view = Vector2(ref)
	var clear: float = HearthFigure.SEAT_LEFT \
		if _hearth_figure != null and _hearth_figure.visible else 0.0
	_director.layout(view, shape, clear)


static func _set_band(bar: ColorRect, top: float, bottom: float) -> void:
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = top
	bar.anchor_bottom = bottom
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	bar.offset_top = 0.0
	bar.offset_bottom = 0.0


static func _band() -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.color = Color(0.01, 0.012, 0.02, 0.92)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func _label(text: String, font_size: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
