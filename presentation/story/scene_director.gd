class_name SceneDirector
extends RefCounted
## Stagecraft for ScenePlayer. The player owns the grammar — tap, hold-skip,
## the persistence-gated advance, the walk — and hands each presented line
## here; the director stands the cast, lights the speaker, sets the pane's
## voice, lays the beat's weather and grade, and fires the line's effects.
##
## `animate` is false for capture, resume and skip: the stage is then folded
## straight to the cursor and no effect fires, so a still is exactly what a
## live playthrough would be standing in once its motion settled.

const GRADES: Dictionary[StringName, Color] = {
	&"none": Color(0, 0, 0, 0),
	&"hearth": Color(1.0, 0.52, 0.18, 0.10),
	&"cold": Color(0.36, 0.56, 1.0, 0.14),
	&"dusk": Color(0.55, 0.30, 0.75, 0.12),
	&"inverted": Color(0.25, 0.70, 0.82, 0.16),
}
const WASH_ALPHA: float = 0.28
const DIM_ALPHA: float = 0.58
## Effects that carry a cue when the line names none: the stagecraft sample
## first (`docs/sfx-ledger.md`, commissioned), else the shipped fallback — so
## landing a file is the whole audio integration, as it is for portraits.
const FX_CUES: Dictionary[StringName, Array] = {
	&"impact": [&"glassImpact", &"hit"], &"slash": [&"slash", &"slash"],
	&"shatter": [&"shatter", &"shatter"], &"crack": [&"glassCrack", &"chip"],
	&"kindle": [&"kindle", &"kindle"], &"quake": [&"stagger", &"stagger"],
	&"flash-blood": [&"hit", &"hit"],
}
## A conversation's pane arriving, and a shouted line landing. Silent until
## their samples exist — neither has a shipped stand-in.
const PANE_CUE: StringName = &"paneOpen"
const SHOUT_CUE: StringName = &"shoutSting"
## Seconds each transition's veil takes to clear.
const VEILS: Dictionary[StringName, float] = {
	&"fade": 0.7, &"black": 0.9, &"white": 1.0, &"wake": 2.6,
}

var book: ActorBook
var box: DialogueBox
var stage: PortraitStage
var ambient_fx: SceneFx
var front_fx: SceneFx
var grade: ColorRect
var wash: ColorRect
var veil: ColorRect
var sfx: SfxBus
var reduce_motion: bool = false:
	set(value):
		reduce_motion = value
		box.reduce_motion = value
		stage.reduce_motion = value
		ambient_fx.reduce_motion = value
		front_fx.reduce_motion = value

var _view: Vector2 = Vector2.ZERO
var _shape: StringName = StageShape.IDENTITY
var _clear_right: float = 0.0
var _veil_rate: float = 0.0
var _wash_goal: float = WASH_ALPHA
var _last_style: StringName = &""


func _init(actor_book: ActorBook, hero: String, sfx_bus: SfxBus) -> void:
	book = actor_book
	sfx = sfx_bus
	box = DialogueBox.new()
	stage = PortraitStage.new(actor_book, hero)
	ambient_fx = SceneFx.new("AmbientFx")
	front_fx = SceneFx.new("FrontFx")
	grade = _rect("Grade", Color(0, 0, 0, 0))
	wash = _rect("Wash", Color(0.025, 0.020, 0.035, WASH_ALPHA))
	veil = _rect("Veil", Color(0, 0, 0, 0))
	front_fx.allow_shake = Preferences.active.screen_shake
	reduce_motion = Preferences.active.reduce_motion


## A new beat: its weather, its grade, and how the frame arrives.
func begin_beat(beat: Dictionary, animate: bool) -> void:
	var weather: StringName = beat.get("ambient", &"none")
	ambient_fx.set_ambient(weather)
	var tone: StringName = beat.get("grade", &"none")
	grade.color = GRADES.get(tone, GRADES[&"none"])
	front_fx.clear()
	var arrival: StringName = beat.get("transition", &"cut")
	if not animate or reduce_motion and arrival != &"wake":
		veil.color.a = 0.0
		_veil_rate = 0.0
		return
	match arrival:
		&"fade":
			veil.color = Color(0, 0, 0, 0.7)
		&"black", &"wake":
			veil.color = Color(0, 0, 0, 1.0)
		&"white":
			veil.color = Color(1.0, 0.97, 0.9, 1.0)
		&"flash":
			front_fx.play(&"flash")
			veil.color.a = 0.0
		_:
			veil.color.a = 0.0
	_veil_rate = veil.color.a / VEILS.get(arrival, 0.7)


## Present line `cursor` of `lines`. Returns true when the pane is arriving
## (it was hidden, or the line changes between a title card and a pane) so
## the player owes the arrival fade.
func present(lines: Array[Dictionary], cursor: int, text: String, animate: bool,
		stand_instant: bool) -> bool:
	var line: Dictionary = lines[cursor] if cursor >= 0 and cursor < lines.size() else {}
	var folded: Dictionary = StageDirection.fold(lines, cursor)
	var cast: Array[Dictionary] = folded["cast"]
	var focus: String = folded["focus"]
	stage.stage(cast, focus, stand_instant or not animate)
	var speaker: String = str(line.get("speaker", ""))
	var style: StringName = StageDirection.style_of(line)
	var shown_name: String = ""
	if book.has(speaker) and not book.name_key(speaker).is_empty():
		shown_name = Locale.active.t(book.name_key(speaker))
	var tint: Color = book.tint(speaker) if book.has(speaker) else DialogueBox.HAIRLINE
	var side: StringName = _plaque_side(speaker, cast)
	var arriving: bool = _last_style.is_empty() \
		or (_last_style == StageDirection.STYLE_TITLE) != (style == StageDirection.STYLE_TITLE)
	_last_style = style
	box.show_line(text, shown_name, style, tint, side, not animate)
	_layout_box()
	_wash_goal = WASH_ALPHA
	if animate:
		if arriving and style != StageDirection.STYLE_TITLE and sfx != null:
			var chime: StringName = _cue(PANE_CUE, &"")
			if not chime.is_empty():
				sfx.play(chime)
		_fire(line, cast, focus)
	return arriving


func tick(delta: float) -> bool:
	var typed: bool = box.advance_type(delta)
	stage.tick(delta)
	ambient_fx.tick(delta)
	front_fx.tick(delta)
	if veil.color.a > 0.0 and _veil_rate > 0.0:
		veil.color.a = maxf(0.0, veil.color.a - _veil_rate * delta)
	wash.color.a = move_toward(wash.color.a, _wash_goal, delta * 1.2)
	return typed


## Land everything that is still settling — the reveal and the veil.
func settle() -> void:
	box.complete()
	veil.color.a = 0.0


func layout(view: Vector2, stage_shape: StringName, clear_right: float) -> void:
	_view = view
	_shape = stage_shape
	_clear_right = clear_right
	box.set_shape(stage_shape)
	stage.set_view(view, stage_shape)
	ambient_fx.set_view(view)
	front_fx.set_view(view)
	_layout_box()


## Keep the pane off a figure standing in the plate (e.g. the seated Keeper).
func set_clear_right(fraction: float) -> void:
	if is_equal_approx(fraction, _clear_right):
		return
	_clear_right = fraction
	_layout_box()


func pane_rect() -> Rect2:
	return DialogueBox.box_rect(_stage_size(), _shape, box.style, _clear_right)


func _layout_box() -> void:
	box.place(pane_rect())


func _stage_size() -> Vector2:
	if _view.x >= 1.0 and _view.y >= 1.0:
		return _view
	var ref: Vector2i = StageShape.REFERENCES.get(_shape, Vector2i(1180, 820))
	return Vector2(ref)


## The plaque rides the speaker's own side of the pane.
func _plaque_side(speaker: String, cast: Array[Dictionary]) -> StringName:
	for seat: Dictionary in cast:
		if str(seat["id"]) == speaker:
			var x: float = StageDirection.SLOT_X.get(StringName(str(seat["at"])), 0.5)
			return &"right" if x > 0.5 else &"left"
	if book.has(speaker):
		return &"left" if book.side(speaker) == &"left" else &"right"
	return &"left"


func _fire(line: Dictionary, cast: Array[Dictionary], focus: String) -> void:
	var cue: String = str(line.get("sfx", ""))
	var fx_list: Array = line.get("fx", [])
	var view: Vector2 = _stage_size()
	for entry_v: Variant in fx_list:
		var entry: String = str(entry_v)
		var fx: StringName = StageDirection.fx_name(entry)
		var target: String = StageDirection.fx_target(entry)
		if target.is_empty() and StageDirection.ACTOR_FX.has(fx) and fx != &"shake":
			target = focus
		if cue.is_empty() and FX_CUES.has(fx):
			var pair: Array = FX_CUES[fx]
			var preferred: StringName = pair[0]
			var fallback: StringName = pair[1]
			cue = String(_cue(preferred, fallback))
		match fx:
			&"hop", &"recoil":
				stage.actor_fx(fx, target)
			&"shake":
				if target.is_empty():
					front_fx.play(fx)
				else:
					stage.actor_fx(fx, target)
			&"kindle":
				var giver: StagePortrait = stage.portrait(target)
				var from: Vector2 = giver.hands() if giver != null \
					else Vector2(view.x * 0.5, view.y * 0.5)
				front_fx.play(fx, from, _receiver(cast, target, view))
				stage.actor_fx(fx, target)
			&"dim":
				_wash_goal = DIM_ALPHA
			&"rays":
				var lit: StagePortrait = stage.portrait(focus)
				var origin: Vector2 = Vector2(view.x * 0.5, -view.y * 0.12)
				if lit != null:
					origin.x = lit.hands().x
				front_fx.play(fx, origin)
			_:
				front_fx.play(fx)
	if cue.is_empty() and StageDirection.style_of(line) == StageDirection.STYLE_SHOUT:
		cue = String(_cue(SHOUT_CUE, &""))
	if not cue.is_empty() and sfx != null:
		sfx.play(StringName(cue))


static func _cue(preferred: StringName, fallback: StringName) -> StringName:
	if ResourceLoader.exists(SfxBus.DIR % preferred):
		return preferred
	return fallback


## Where a kindle lands: the first other figure on stage, else mid-left.
func _receiver(cast: Array[Dictionary], giver: String, view: Vector2) -> Vector2:
	for seat: Dictionary in cast:
		var id: String = str(seat["id"])
		if id == giver:
			continue
		var p: StagePortrait = stage.portrait(id)
		if p != null:
			return p.hands()
	return Vector2(view.x * 0.24, view.y * 0.52)


static func _rect(node_name: String, colour: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.name = node_name
	rect.color = colour
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
