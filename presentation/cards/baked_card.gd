class_name BakedCard
extends Control
## One card of a many-card view (CardGrid). At rest it draws its baked face
## (CardFaces) — picture, table shadow and a rare's shine — through CardView's
## own nodes, so it is the live card's pixels for a twentieth of its video
## memory. While a pointer is on it, a live CardView stands in for it: built on
## the spot, lent this node's pointer (the live card takes no input itself),
## and dropped once it has sprung back to rest, when the swap is invisible.
## Which card may stand live is the grid's call (`pointer_changed`).
##
## The node keeps the CardView's footprint and pivot, so a grid seats and
## scales it exactly as it did a live card. It takes input only once its face
## is worn; until then it is invisible, and a face that lands after the view
## opened fades in over FACE_IN (at once under Reduce Motion).
##
## Touch and the mouse take one path each. A touch screen also sends every
## contact as an emulated mouse, which is ignored here so a tap is one press:
## a finger lends the pointer while it is down, a mouse while it is over.

## A pointer came onto the card (`on`), or left it.
signal pointer_changed(card: BakedCard, on: bool)
## A press on the card was let go: the card was chosen.
signal released(card: BakedCard)

const FACE_IN: float = 0.16

var inst: CardInst
var _definition: Dictionary = {}
var _cost: int = 0
var _face: CardFaces.Face = null
## The face's nodes, hidden while the live card stands in.
var _rest: Array[Control] = []
var _live: CardView = null
var _settling: bool = false
var _touching: bool = false
var _held: bool = false


func _init(card: CardInst, definition: Dictionary, cost: int) -> void:
	inst = card
	_definition = definition
	_cost = cost
	custom_minimum_size = Vector2(CardView.CARD_W, CardView.CARD_H)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(false)
	var hit: CardFaces.Face = CardFaces.cached(inst, _definition, _cost)
	if hit != null:
		_wear(hit)
		return
	modulate.a = 0.0
	CardFaces.request(self, inst, _definition, _cost, _landed)


## The face this card wears, or null while it has none.
func face() -> CardFaces.Face:
	return _face


## The live card standing in for this one, or null at rest.
func live() -> CardView:
	return _live


## A new live card of this one, as the slot builds its stand-in.
func stand_in() -> CardView:
	return CardView.new(inst, _definition, _cost)


## Stand a live card in for the face. The grid calls this for the one card it
## lets be live; a card with no face yet stays as it is.
func go_live() -> void:
	_settling = false
	set_process(false)
	if _live != null or _face == null:
		return
	_live = stand_in()
	_live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_live)
	for node: Control in _rest:
		node.visible = false


## Back to the face at once, wherever the live card was.
func go_rest() -> void:
	_settling = false
	set_process(false)
	if _live == null:
		return
	remove_child(_live)
	_live.queue_free()
	_live = null
	for node: Control in _rest:
		node.visible = true


## Let the live card spring back to rest, then go back to the face.
func let_go() -> void:
	if _live == null:
		return
	_live.point_away()
	_settling = true
	set_process(true)


func _process(_delta: float) -> void:
	if _settling and _live != null and _live.at_rest():
		go_rest()


func _landed(face: CardFaces.Face) -> void:
	_wear(face)
	if Preferences.active.reduce_motion:
		modulate.a = 1.0
		return
	create_tween().tween_property(self, "modulate:a", 1.0, FACE_IN)


func _wear(face: CardFaces.Face) -> void:
	_face = face
	_rest.append(CardView.shadow_panel(face.shadow))
	_rest.append(CardView.picture(face.picture, CardFaces.REACH))
	if face.shine:
		_rest.append(CardView.shine())
	for node: Control in _rest:
		add_child(node)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_touching = touch.pressed
		if touch.pressed:
			_point(touch.position)
		else:
			_leave()
		_press(touch.pressed)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_point(drag.position)
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return    # a touch, already taken above
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_press(button.pressed)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_point(motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _touching:
		_leave()


func _point(local_pos: Vector2) -> void:
	if _live == null or _settling:
		pointer_changed.emit(self, true)
	if _live != null:
		_live.point_at(local_pos)


func _leave() -> void:
	if _live != null and not _settling:
		pointer_changed.emit(self, false)


func _press(pressed: bool) -> void:
	if pressed:
		_held = true
	elif _held:
		_held = false
		released.emit(self)
