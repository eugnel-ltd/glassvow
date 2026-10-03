class_name LeadlightRoomHost
extends Control
## A room the title opens (docs/design/2026-10-03-title-rooms §2): Settings,
## How to Play and Credits are each one. The host owns what every room shares —
## the veil over the road, the seat and its one way back, Escape, the double
## tap guard's veil half — and says where its crown, its light and its content
## are, so one LeadlightPassage carries the lantern into any of them.
##
## The way out is `leave()`: the seat's Return (or the seated lantern), a tap on
## the veil released without a drag (a wheel tick or the start of a scroll never
## closes a room), and Escape. Each emits `closed` once; the passage plays the
## room's sound, never the room.

signal closed

## How far a press may travel before it is a drag, not a tap.
const DRAG: float = 10.0

var shape: StringName = StageShape.IDENTITY
## Set by the passage while the room arrives.
var arriving: bool = false
## The title lent to the room (its lantern at the seat), while it is lent.
var title: TitleScreen = null
## A tap on the veil closes the room (glass rooms); a place has no veil to tap.
var veil_closes: bool = true
var _veil: ColorRect
var _seat: LeadlightSeat
var _veil_down: bool = false
var _veil_from: Vector2 = Vector2.ZERO
## The frame a press landed an arrival on: that press is not the veil's.
var _swallow_frame: int = -1
var _left: bool = false
## Focus asked for before the room took it (Settings' language control).
var _focus_first: Control = null


## Called first by every room's constructor: the veil, under everything.
func _host(stage_shape: StringName) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GlassStyle.theme()
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(LeadlightTokens.VOID, LeadlightTokens.VEIL_ROOM)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.gui_input.connect(_on_veil_input)
	add_child(_veil)


## Called last by every room's constructor: the seat, over everything.
func _seat_last() -> void:
	_seat = LeadlightSeat.new(shape)
	_seat.pressed.connect(leave)
	add_child(_seat)


func veil() -> ColorRect:
	return _veil


func seat() -> LeadlightSeat:
	return _seat


## Leave the room (the one close path). Once.
func leave() -> void:
	if _left:
		return
	_left = true
	closed.emit()


func left() -> bool:
	return _left


# ------------------------------------------------------------- the room's shape

## The glass the lantern's light reaches (a glass room), or null (a place).
func sheet() -> LeadlightSheet:
	return null


## Where the word that opened the room lands.
func crown() -> Control:
	return null


## The room's content, in groups that rise as the light reaches them.
func reveal_groups() -> Array[Control]:
	return []


## Whether the room stands over the title's wordmark (it then goes with the
## title's furniture while the room is open).
func covers_wordmark() -> bool:
	return false


## The control focus goes to on arrival.
func first_focus() -> Control:
	return _focus_first if _focus_first != null else _seat.word()


## The rects the room's content stands in, on the stage (never under the seat).
func content_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var glass: LeadlightSheet = sheet()
	if glass != null:
		rects.append(Rect2(glass.position, glass.size))
	return rects


## The lent title is coming home: anything the room borrowed goes back.
func title_returns() -> void:
	pass


## How long the room's arrival and departure run (glass: 520 / 400 ms).
func arrival_time() -> float:
	return 0.52


func departure_time() -> float:
	return 0.40


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	if _seat != null:
		_seat.set_shape(stage_shape)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## Seat the room's content on the stage (each room its own).
func _fit() -> void:
	pass


# ------------------------------------------------------------- the passage

## The room at `t` seconds into its arrival, lit from `wick` (stage px) in
## `colour`. A glass room is traced and lit by the light front; its groups
## rise as the front reaches them. Places override.
func arrive_at(t: float, wick: Vector2, colour: Color) -> void:
	_light(wick, colour)
	var glass: LeadlightSheet = sheet()
	if glass == null:
		return
	glass.trace = LeadlightMotion.ease_on((t - 0.06) / 0.30, LeadlightMotion.SETTLE_OUT)
	glass.reach = LeadlightMotion.ease_on((t - 0.08) / 0.36, LeadlightMotion.REVEAL)
	var far: float = LeadlightSheet.far_radius(glass.outline(), glass.reach_from)
	for group: Control in reveal_groups():
		var d: float = clampf(glass.reach_from.distance_to(_centre_in(glass, group)) / maxf(far, 1.0), 0.0, 1.0)
		# When the front (REVEAL over 80–440 ms) reaches the group's centre.
		var reached: float = 0.08 + 0.36 * (1.0 - pow(1.0 - d, 0.2))
		var from: float = clampf(reached, 0.12, arrival_time() - 0.2)
		_reveal(group, LeadlightMotion.ease_on((t - from) / 0.2, LeadlightMotion.REVEAL))


## The room at `t` seconds into its departure: the glass goes dark far to near
## from the seat (the light drawn back into the flame) and its lead retracts.
func leave_at(t: float, wick: Vector2, colour: Color) -> void:
	_light(wick, colour)
	var glass: LeadlightSheet = sheet()
	if glass == null:
		return
	glass.reach = 1.0 - LeadlightMotion.ease_on(t / 0.22, LeadlightMotion.EXIT)
	glass.trace = 1.0 - LeadlightMotion.ease_on((t - 0.04) / 0.20, LeadlightMotion.EXIT)
	var radius: float = LeadlightSheet.reach_radius(glass.outline(), glass.reach_from, glass.reach)
	for group: Control in reveal_groups():
		var d: float = glass.reach_from.distance_to(_centre_in(glass, group))
		_reveal(group, clampf((radius - d) / 80.0 + 0.5, 0.0, 1.0), false)


## The room whole, at rest: every lane at its end.
func rest(wick: Vector2, colour: Color) -> void:
	_light(wick, colour)
	var glass: LeadlightSheet = sheet()
	if glass != null:
		glass.trace = 1.0
		glass.reach = 1.0
		glass.glazing = 1.0
	for group: Control in reveal_groups():
		_reveal(group, 1.0)


## The light follows the lantern's live wick (stage px) every frame.
func _light(wick: Vector2, colour: Color) -> void:
	var glass: LeadlightSheet = sheet()
	if glass == null or glass.size.x <= 0.0:
		return
	var local: Vector2 = wick - glass.global_position
	glass.reach_from = local
	glass.set_light(colour, local / glass.size)


static func _centre_in(glass: Control, group: Control) -> Vector2:
	return group.get_global_rect().get_center() - glass.global_position


## A group `amount` (0..1) of the way into view: faded, and risen 8 px from
## below (`rise`) without moving it in its container, so a re-sort never
## fights it: the offset is in its drawing only.
static func _reveal(group: Control, amount: float, rise: bool = true) -> void:
	group.modulate.a = amount
	var offset: float = 0.0 if (amount >= 1.0 or not rise or LeadlightMotion.reduced()) \
		else 8.0 * (1.0 - amount)
	RenderingServer.canvas_item_set_transform(group.get_canvas_item(),
		group.get_transform().translated(Vector2(0.0, offset)))


# ------------------------------------------------------------- input

## A press landed the arrival on this frame: it is not the veil's to close on.
func swallow_press() -> void:
	_swallow_frame = Engine.get_process_frames()
	_veil_down = false


## Inert: it takes no input and holds no focus (a room leaving, or lingering).
func make_inert() -> void:
	_left = true
	set_process_unhandled_input(false)
	set_process_input(false)
	_veil_down = false
	var owner: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner != null and is_ancestor_of(owner):
		owner.release_focus()
	_ignore(self)


static func _ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_ignore(child)


## A tap on the veil closes the room on release, if the finger did not drag.
func _on_veil_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if button != null and button.button_index != MOUSE_BUTTON_LEFT:
		return
	var down: bool = (button != null and button.pressed) or (touch != null and touch.pressed)
	var up: bool = (button != null and not button.pressed) or (touch != null and not touch.pressed)
	if down:
		_veil_down = Engine.get_process_frames() != _swallow_frame and not arriving
		_veil_from = button.position if button != null else touch.position
		accept_event()
	elif up:
		var at: Vector2 = button.position if button != null else touch.position
		if _veil_down and veil_closes and at.distance_to(_veil_from) <= DRAG:
			leave()
		_veil_down = false
		accept_event()
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		var to: Vector2 = (event as InputEventMouseMotion).position if event is InputEventMouseMotion \
			else (event as InputEventScreenDrag).position
		if _veil_down and to.distance_to(_veil_from) > DRAG:
			_veil_down = false


## Escape (and a pad's cancel) leaves.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()
