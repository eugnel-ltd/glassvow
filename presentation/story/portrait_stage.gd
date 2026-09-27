class_name PortraitStage
extends Control
## The dialogue stage: up to five seats across the frame, each holding one
## StagePortrait. `stage()` takes the folded cast for the current line (see
## StageDirection.fold) and walks the actors there — entrances, exits, seat
## changes, mood swaps — then lights whoever speaks. The busts stand behind
## the dialogue pane, cut at the waist by it, the classic JRPG two-shot.

const NAME: String = "PortraitStage"

var book: ActorBook
var hero: String = ""
var shape: StringName = StageShape.IDENTITY
var reduce_motion: bool = false
var _actors: Dictionary = {}  # id -> StagePortrait
var _view: Vector2 = Vector2.ZERO


func _init(actor_book: ActorBook, hero_id: String = "") -> void:
	book = actor_book
	hero = hero_id
	name = NAME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The bust's rect for a seat on a stage of `view`. `occupied` is every seat
## standing: a crowded side pulls its near seat inward, three or more voices
## stand a little smaller, and the outer seats a step further back. Pure, so
## geometry is pinned headless at every reference shape.
static func bust_rect(view: Vector2, stage_shape: StringName, at: StringName,
		aspect: float, occupied: Array[StringName] = []) -> Rect2:
	var short: bool = stage_shape == &"phone-landscape"
	var pane: Rect2 = DialogueBox.box_rect(view, stage_shape, StageDirection.STYLE_SPEECH)
	var h: float = view.y * (0.78 if short else 0.70)
	if occupied.size() >= 3:
		h *= 0.86
	if at == &"far-left" or at == &"far-right":
		h *= 0.90
	var w: float = h * maxf(aspect, 0.2)
	var cap: float = view.x * (0.40 if short else 0.42)
	if w > cap:
		w = cap
		h = w / maxf(aspect, 0.2)
	# Busts stand behind the pane; their dissolving cut sits under it.
	var bottom: float = pane.position.y + pane.size.y * 0.80
	if at == &"far-left" or at == &"far-right":
		bottom -= view.y * 0.03
	var seat_x: float = StageDirection.SLOT_X.get(at, 0.5)
	if at == &"right" and occupied.has(&"far-right"):
		seat_x = 0.68
	elif at == &"left" and occupied.has(&"far-left"):
		seat_x = 0.32
	var cx: float = view.x * seat_x
	return Rect2(cx - w * 0.5, bottom - h, w, h)


## Walk the stage to `cast` (seat order) and light `focus`.
func stage(cast: Array[Dictionary], focus: String, instant: bool) -> void:
	var wanted: Dictionary = {}
	for entry: Dictionary in cast:
		wanted[str(entry["id"])] = true
	for id: String in _actors.keys():
		var p: StagePortrait = _actors[id]
		if not wanted.has(id) and not p.leaving:
			p.leave(instant)
	for entry: Dictionary in cast:
		var id: String = str(entry["id"])
		if not book.has(id):
			continue
		var at: StringName = StringName(str(entry["at"]))
		var entry_mood: String = str(entry.get("mood", ""))
		var p: StagePortrait = _actors.get(id)
		if p != null and p.leaving:
			_actors.erase(id)
			p.queue_free()
			p = null
		if p == null:
			p = StagePortrait.new(book, id, hero)
			p.reduce_motion = reduce_motion
			_actors[id] = p
			add_child(p)
			p.slot = at
			p.stand(at, entry_mood, true)
			if not instant:
				p.begin_entrance()
		else:
			p.stand(at, entry_mood, instant)
		p.flipped = _flip(id, at)
	var anyone_lit: bool = false
	var speaker: StagePortrait = _actors.get(focus)
	if speaker != null and not speaker.leaving and speaker.has_art():
		anyone_lit = true
	for id: String in _actors:
		var p: StagePortrait = _actors[id]
		if not p.leaving:
			p.set_lit(id == focus, anyone_lit, instant)
	_layout()


func set_view(view: Vector2, stage_shape: StringName) -> void:
	_view = view
	shape = stage_shape
	_layout()


func tick(delta: float) -> void:
	for id: String in _actors.keys():
		var p: StagePortrait = _actors[id]
		p.tick(delta)
		if p.is_gone():
			_actors.erase(id)
			p.queue_free()


## On stage and not on the way off.
func has_actor(id: String) -> bool:
	var p: StagePortrait = _actors.get(id)
	return p != null and not p.leaving


func portrait(id: String) -> StagePortrait:
	return _actors.get(id)


func standing() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in _actors:
		var p: StagePortrait = _actors[id]
		if not p.leaving:
			out.append(id)
	return out


## Actor-targeted beats: `hop`, `recoil`, `shake`, `kindle` (the caller
## draws the kindle's sparks; this lights the giver).
func actor_fx(fx: StringName, id: String) -> void:
	var p: StagePortrait = _actors.get(id)
	if p == null or p.leaving:
		return
	match fx:
		&"hop":
			p.hop()
		&"recoil":
			p.recoil()
			p.flash()
		&"shake":
			p.tremble()
		&"kindle":
			p.flash()


func _flip(id: String, at: StringName) -> bool:
	var x: float = StageDirection.SLOT_X.get(at, 0.5)
	if is_equal_approx(x, 0.5):
		return false
	var looks_left: bool = book.faces(id) == &"left"
	# Seated on the left half, a figure must look right, and vice versa.
	return looks_left if x < 0.5 else not looks_left


func _layout() -> void:
	var view: Vector2 = _view
	if view.x < 1.0 or view.y < 1.0:
		var ref: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
		view = Vector2(ref)
	var occupied: Array[StringName] = []
	for id: String in _actors:
		var p: StagePortrait = _actors[id]
		if not p.leaving:
			occupied.append(p.slot)
	for id: String in _actors:
		var p: StagePortrait = _actors[id]
		p.seat(bust_rect(view, shape, p.slot, p.bust_aspect(), occupied))
	# Outer seats draw first — a step behind the pair in front.
	var back: int = 0
	for id: String in _actors:
		var p: StagePortrait = _actors[id]
		if p.slot == &"far-left" or p.slot == &"far-right":
			move_child(p, back)
			back += 1
