class_name BattleDialogue
extends Control
## JRPG battle dialogue: when a foe speaks mid-fight, the fight dims a step,
## the speaker's glass bust rises on the right, and the line types into the
## same leaded pane the story scenes use — with the line's own effects (a
## crack on "mask", a hop on a threat, a cold flash on a dying word). The
## fight is turn-based and the drain awaits the dialogue, so nothing moves
## underneath it. One tap lands a typing line, the next moves on; left alone
## it holds for a reading dwell. Consecutive lines keep the bust standing.
##
## Directions come from `content/battle-lines.json` by variant id; a foe with
## lines but no registered body falls back to the plain banner (the caller
## checks `can_voice`). Headless and out-of-tree playback return at once.

signal line_done

const NAME: String = "BattleDialogue"
const PATH: String = "res://content/battle-lines.json"
const IN_TIME: float = 0.26
const OUT_TIME: float = 0.24
const VEIL_ALPHA: float = 0.5
const DWELL_BASE: float = 1.1
const DWELL_PER_CHAR: float = 0.06
const DWELL_MAX: float = 6.0

const PHASE_IDLE: int = 0
const PHASE_TYPE: int = 1
const PHASE_HOLD: int = 2

static var _staging: Dictionary = {}
static var _staging_loaded: bool = false

var instant: bool = false
var shape: StringName = StageShape.IDENTITY
var reduce_motion: bool = false

var _book: ActorBook
var _veil: ColorRect
var _stage: PortraitStage
var _fx: SceneFx
var _box: DialogueBox
var _phase: int = PHASE_IDLE
var _t: float = 0.0
var _hold_for: float = 0.0
var _fade: float = 0.0
var _fade_goal: float = 0.0
var _sfx: SfxBus


func _init(sfx: SfxBus = null) -> void:
	name = NAME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_sfx = sfx
	_book = ActorBook.shared()
	reduce_motion = Preferences.active.reduce_motion
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0.01, 0.01, 0.02, 0.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_stage = PortraitStage.new(_book)
	_stage.reduce_motion = reduce_motion
	add_child(_stage)
	_fx = SceneFx.new("BattleFx")
	_fx.reduce_motion = reduce_motion
	_fx.allow_shake = Preferences.active.screen_shake
	add_child(_fx)
	_box = DialogueBox.new()
	_box.reduce_motion = reduce_motion
	add_child(_box)
	resized.connect(_layout)
	set_process(false)


## The staging row for a variant, or {} when it has none.
static func staging_for(variant_id: String) -> Dictionary:
	if not _staging_loaded:
		_staging_loaded = true
		var loaded: Variant = load_file(PATH)
		if typeof(loaded) == TYPE_DICTIONARY:
			_staging = loaded
	var row: Variant = _staging.get(variant_id, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


## Parse and validate `content/battle-lines.json`: every row names a
## registered actor and every line direction passes StageDirection.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return "battle-lines: missing %s" % path
	return parse(JSON.parse_string(FileAccess.get_file_as_string(path)), ActorBook.shared())


static func parse(raw: Variant, book: ActorBook) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("battle-lines: root is not an object")
	var root: Dictionary = raw
	var speakers_v: Variant = root.get("speakers")
	if typeof(speakers_v) != TYPE_DICTIONARY:
		return _fail("battle-lines: missing speakers object")
	var speakers: Dictionary = speakers_v
	var out: Dictionary = {}
	for id_v: Variant in speakers:
		var id: String = str(id_v)
		var row_v: Variant = speakers[id_v]
		if typeof(row_v) != TYPE_DICTIONARY:
			return _fail("battle-lines: %s is not an object" % id)
		var row: Dictionary = row_v
		var actor: String = str(row.get("actor", ""))
		if not book.has(actor):
			return _fail("battle-lines: %s names unregistered actor '%s'" % [id, actor])
		var clean: Dictionary = {"actor": actor, "intro": [], "death": {}}
		var intro_v: Variant = row.get("intro", [])
		if typeof(intro_v) != TYPE_ARRAY:
			return _fail("battle-lines: %s intro is not a list" % id)
		var intro: Array = intro_v
		var parsed_intro: Array[Dictionary] = []
		for i: int in range(intro.size()):
			var dir: Variant = _direction(intro[i], "battle-lines: %s intro %d" % [id, i])
			if typeof(dir) == TYPE_STRING:
				return dir
			parsed_intro.append(dir)
		clean["intro"] = parsed_intro
		if row.has("death"):
			var death: Variant = _direction(row["death"], "battle-lines: %s death" % id)
			if typeof(death) == TYPE_STRING:
				return death
			clean["death"] = death
		out[id] = clean
	return out


static func _direction(raw: Variant, where: String) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("%s is not an object" % where)
	var row: Dictionary = raw
	var out: Dictionary = {}
	var failed: String = StageDirection.parse_line(row, out, where)
	if not failed.is_empty():
		return _fail(failed)
	return out


## True from a foe's first line until its pane has faded: the fight beneath
## takes no input meanwhile.
func speaking() -> bool:
	return visible


## Whether this foe's lines can be voiced here rather than as a banner.
func can_voice(variant_id: String) -> bool:
	return not staging_for(variant_id).is_empty()


## Voice `lines` (Array of {"text", "direction"}) from one foe, as one
## entrance. Awaitable; returns at once when headless or out of tree.
func speak(variant_id: String, speaker_name: String, lines: Array[Dictionary]) -> void:
	if instant or not is_inside_tree() or lines.is_empty():
		return
	var row: Dictionary = staging_for(variant_id)
	var actor: String = str(row.get("actor", ""))
	if not _book.has(actor):
		return
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	_fade_goal = 1.0
	set_process(true)
	for i: int in range(lines.size()):
		var entry: Dictionary = lines[i]
		var direction: Dictionary = entry.get("direction", {})
		var mood: String = str(direction.get("mood", ""))
		var cast: Array[Dictionary] = [{"id": actor, "at": &"right", "mood": mood}]
		_stage.stage(cast, actor, i > 0)
		var style: StringName = StageDirection.style_of(
			{"speaker": actor, "style": direction.get("style", "")})
		var text: String = str(entry.get("text", ""))
		_box.show_line(text, speaker_name, style, _book.tint(actor), &"right", false)
		_fire(direction, actor)
		_phase = PHASE_TYPE
		_t = 0.0
		_hold_for = minf(DWELL_MAX, DWELL_BASE + DWELL_PER_CHAR * float(text.length()))
		await line_done
		if not is_inside_tree():
			return
	_fade_goal = 0.0
	_stage.stage([], "", false)
	_phase = PHASE_IDLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	while _fade > 0.0 and is_inside_tree():
		await get_tree().process_frame
	visible = false
	set_process(false)


func _fire(direction: Dictionary, actor: String) -> void:
	var fx_list: Array = direction.get("fx", [])
	var cue: String = str(direction.get("sfx", ""))
	for entry_v: Variant in fx_list:
		var entry: String = str(entry_v)
		var fx: StringName = StageDirection.fx_name(entry)
		if StageDirection.ACTOR_FX.has(fx) and fx != &"shake":
			_stage.actor_fx(fx, actor)
		else:
			var at: Vector2 = Vector2(-1, -1)
			var p: StagePortrait = _stage.portrait(actor)
			if p != null and (fx == &"crack" or fx == &"rays"):
				at = p.hands()
			_fx.play(fx, at)
		if cue.is_empty():
			cue = String(SceneDirector.cue_for(fx))
	if not cue.is_empty() and _sfx != null:
		_sfx.play(StringName(cue))


func _process(delta: float) -> void:
	var rate: float = 1.0 / (IN_TIME if _fade_goal > _fade else OUT_TIME)
	_fade = move_toward(_fade, _fade_goal, delta * rate)
	_veil.color.a = VEIL_ALPHA * _fade
	_box.modulate.a = _fade
	_stage.tick(delta)
	_fx.tick(delta)
	var typed: bool = _box.advance_type(delta)
	match _phase:
		PHASE_TYPE:
			if typed:
				_phase = PHASE_HOLD
				_t = 0.0
		PHASE_HOLD:
			_t += delta
			if _t >= _hold_for:
				_phase = PHASE_IDLE
				line_done.emit()


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		_tap()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if _phase == PHASE_IDLE:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or key_event.echo or key_event.pressed:
		return
	if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_tap()
		get_viewport().set_input_as_handled()


## One tap lands a typing line; the next moves on (07-scenes §1).
func _tap() -> void:
	match _phase:
		PHASE_TYPE:
			_box.complete()
		PHASE_HOLD:
			_phase = PHASE_IDLE
			line_done.emit()


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	_layout()


func _layout() -> void:
	var view: Vector2 = size
	if view.x < 1.0 or view.y < 1.0:
		var ref: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
		view = Vector2(ref)
	_box.set_shape(shape)
	_box.place(DialogueBox.box_rect(view, shape, StageDirection.STYLE_SPEECH))
	_stage.set_view(view, shape)
	_fx.set_view(view)


static func _fail(message: String) -> String:
	push_error(message)
	return message
