class_name HandView
extends Control
## The hand: arc layout + the tap/drag state machine (plan M5). Below the
## slop threshold a release is a tap (inspect); above it the card is dragged
## and the screen decides what a release means (play on an enemy / above the
## hand line, else snap back). Hover raise is mouse-only.

signal card_tapped(uid: int)
signal card_drag_moved(uid: int, global_pos: Vector2)
signal card_drag_released(uid: int, global_pos: Vector2)
## Which card the pointer is over, or -1 for none. `cardHover` (combat.js:1375)
## fires only when the answer CHANGES, which is what keeps `sfx.hover()` from
## machine-gunning as the cursor crosses a seat.
signal card_hover_changed(uid: int)
## The drag armed, or was refused because the card can neither be played nor
## burned. `beginCardDrag` (combat.js:1112) answers the first with a hover tick
## and the second with a rejection.
signal card_drag_armed(uid: int)
signal card_drag_refused(uid: int)

## `DRAG_START_PX` / `LONG_PRESS_CANCEL_PX` (pointer.js:5). Two different
## numbers doing two different jobs: 26px of UPWARD travel arms a drag, and a
## press that never armed is a tap only if it stayed inside 12px. A press that
## wandered 20px sideways is neither — which is what stops a fumbled drag from
## committing a card the player was only steadying.
const DRAG_START_PX: float = 26.0
const CLICK_SLOP: float = 12.0
## The fan's gap rule, from the benchmark (combat.js:460). `GAP_MAX` is the
## resting gap; `GAP_BUDGET / count` is what tightens it as the hand grows;
## `STAGE_MARGIN` is the room the chrome keeps at both ends of the stage.
const GAP_MAX: float = 112.0
const GAP_BUDGET: float = 640.0
const STAGE_MARGIN: float = 246.0
## The rest of the fan law, from `src/ui/hand-layout.js` — the benchmark's own
## single source for resting seats. The tilt is a per-seat STEP that shrinks as
## the hand grows (`min(5, 42 / n)`), and the sag is proportional to how far a
## card is tilted, not to the square of its index. The two produce visibly
## different fans: a flat 4-degree step with a `t * t` drop peaks in the middle
## and flattens at the edges, which is the shape this port had and the benchmark
## never did.
const TILT_STEP_MAX: float = 5.0
const TILT_TOTAL_DEG: float = 42.0
const SAG_PER_DEG: float = 3.2
const BASE_Y: float = 26.0
## Seats stop being added past ten; an eleventh card sits on the tenth's seat.
const MAX_CARDS: int = 10
## `handCardBottomInset` for pad-landscape — a resting card's bottom edge sits
## this far above the hand zone's own bottom.
##
## The zone itself hangs 12px BELOW the stage, so a resting card's bottom lands at
## 850 on an 820 stage — 30px off-screen for the middle of five, 62px for the
## outer ones. Measured on the reference, not inferred: `.hand-zone` bottom 832,
## `.hand-zone .card` computed `bottom: 8px`, resting transform `translate(…, 26px)`.
##
## This port used to lift the whole fan to stop that, on the reading that a card
## losing its name and rules text was a bug. It is the design: a resting hand is
## CUT OFF on purpose, and the 92px hover lift at 1.38 is what makes a card
## legible. Lifting the fan spent the hover's job before the pointer arrived, and
## it put the fan 22px higher than the reference for a five-card hand.
const CARD_INSET: float = 8.0

## What this shape says a card is, set by the screen from `chrome.card` before
## any card is added. Both are pad-landscape's numbers, so a HandView built with
## no book behaves exactly as it did before shapes existed.
##
## `card_w` is the benchmark's `--cw`; `card_inset` is `.hand-zone .card`'s own
## `bottom`, which the phone regimes move to 46 and 0. Neither is a constant
## upstream and neither was carried, which is why every shape drew the pad's
## 152px card.
var card_w: float = CardView.CARD_W
var card_inset: float = CARD_INSET
## The stage the fan gap is measured against, told rather than looked up.
##
## This used to read `get_viewport_rect().size.x`, which is the same number in a
## running game and is NOT the same number anywhere else — a headless probe or a
## bench that hosts a stage inside a bigger window got the window's width and
## fanned a phone's five cards 586px wide instead of 282. The screen already
## knows the stage it composed against (`CombatScreen._stage_w`), so there is no
## reason for a second, weaker answer to exist here.
var stage_w: float = float(StageShape.REFERENCES[StageShape.IDENTITY].x)

## A seat has four poses and they do not stack — one branch per card writes the
## whole transform. Two of them are CSS, and these are their numbers:
##
##     .hand-zone .card.lifted .card-lift { transform: translateY(-92px) scale(1.38); }
##     .hand-zone .card.armed  .card-lift { transform: translateY(-118px) scale(1.24); }
##                                                              (styles.css:634-635)
##
## This port had 20px at 1.08 and 24px at 1.08 — a quarter of the travel and a
## fifth of the growth, on the gesture the entire hand is read through. The
## previous citation here was `combat-gl.js:1096-1123`, a file the reference does
## not contain; the poses were guessed from it rather than measured.
##
## The scale is the load-bearing half. A resting hand in the reference is CUT OFF
## by the bottom of the stage on purpose — the middle card of five hangs 30px
## past it and the outer ones more — so a card is unreadable until you hover it
## and the lift is what makes it legible, not a flourish on top of legibility.
## Godot scales about `pivot_offset`, which `card_view.gd` centres, so 1.38 on a
## 216px card adds 41px above the centre as well: the top rises 133px, not 92.
##
## Armed is not "hovered, harder". It lifts FURTHER and grows LESS — the card
## leaves the row entirely and settles, which is what says the choice is made and
## it is now waiting on a target rather than on you.
const HOVER_LIFT: float = 92.0
const HOVER_SCALE: float = 1.38
const ARMED_LIFT: float = 118.0
const ARMED_SCALE: float = 1.24
const ARMED_PULL: float = 0.4   # of the seat's own offset from the zone centre
const ARMED_ROT: float = 0.5
const DRAG_SCALE: float = 1.12
## How long the screen waits for a pile copy to arrive when the card itself
## never flew there (`schedule: { flightDur: 200 }` at drain.js:866): a
## targeted card went at its foe, and the `toDiscard` that follows moves the
## pile copy. Every flight's own timing is CardFlight's.
const SPEND_FLIGHT: float = 0.2
## `flyCardBacks([...], {x, y}, 270, ...)` with the anchor at `r.width * 0.22` —
## how long a targeted card takes to reach its foe, and how small it gets there.
const STRIKE_FLIGHT: float = 0.27
const STRIKE_SCALE: float = 0.22

## Ignore pointer input while the sequencer is busy (input-lock contract).
var locked: bool = false
## Kindle turns every card into fuel, so nothing aims. Mirrors the benchmark's
## `kindleOnly` branch, which sets `free` and clears targeting.
var kindle_mode: bool = false
## How far this box deliberately hangs past the stage's bottom edge — the screen
## that placed it says so, because only the screen knows.
##
## `S.hoveredCard` — the seat the pointer is over, -1 for none. Held here
## rather than inferred per event so the change test has something to compare
## against, and so a card leaving under the cursor cannot leave it stuck.
var hovered_uid: int = -1
## `model.targetingUid` — the card that has been committed to and is waiting on
## a target. Its own pose, not a louder hover.
var armed_uid: int = -1

var _views: Dictionary = {}  # uid -> CardView
var _order: Array[int] = []  # layout order, independent of z-order changes
var _drag_uid: int = -1
var _dragging: bool = false
## True while the live drag is AIMING rather than carrying: the card holds its
## seat and the screen draws an arc from it. See `is_aiming()`.
var _aiming: bool = false
var _press_pos: Vector2 = Vector2.ZERO
## The cards in the air. A card being dealt is still in the fan, and while it
## flies its transform is its flight's, not its seat's (`_dealing`, by uid). A
## card leaving is out of the fan already, and only its flight holds it
## (`_leaving`) until it lands.
var _dealing: Dictionary = {}   # uid -> _Flight
var _leaving: Array[_Flight] = []
## uid -> the CardView that left the fan for a pile by a flight, until that
## node has gone: the pile event that follows a play finds its card already on
## the way there.
var _sent: Dictionary = {}
## A tap landed the deal: the rest of its wave lands at once too.
var _deal_skipped: bool = false
## The stage height the deal's arc is measured against, told by the screen
## for the same reason `stage_w` is.
var stage_h: float = float(StageShape.REFERENCES[StageShape.IDENTITY].y)

## How a card leaves the hand for a pile (CardFlight): a played card's
## discard, the end of a turn's sweep, or the burn to the ash.
enum Leave { DISCARD, SWEEP, BURN }


## One card in the air: how far through its flight it is (`t`, linear time),
## the tween that carries it, how to place it at any `t`, and what to do when
## it lands. A deal can be fast-forwarded (`skip`); a leaving card lands at once.
class _Flight:
	extends RefCounted
	var view: CardView
	var uid: int
	var t: float = 0.0
	var tween: Tween = null
	var step: Callable
	var land: Callable
	var skipped: bool = false
	## A deal: the pile it left, and the pile card's size in resting units.
	var from: Rect2 = Rect2()
	var born: float = 1.0
	## Leaving: how, the pose it set off in and the one it lands in, and what
	## the screen runs as it arrives.
	var how: Leave = Leave.DISCARD
	var start_centre: Vector2 = Vector2.ZERO
	var start_rot: float = 0.0
	var start_scale: float = 1.0
	var end_centre: Vector2 = Vector2.ZERO
	var end_rot: float = 0.0
	var end_scale: float = 1.0
	var on_land: Callable = Callable()

	func _init(card: CardView, id: int) -> void:
		view = card
		uid = id


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # cards take the pointer, not the strip
	resized.connect(_relayout)
	set_process_input(false)   # heard only while a card is in the air


func has_card(uid: int) -> bool:
	return _views.has(uid)


func card_view(uid: int) -> CardView:
	var v: CardView = _views.get(uid)
	return v


func uids() -> Array[int]:
	return _order.duplicate()


## Is the live drag an aim rather than a carry? The screen asks so it knows
## whether to draw the arc.
func is_aiming() -> bool:
	return _dragging and _aiming


## Where an aimed card's arc launches from: the centre of its RESTING seat, in
## global coordinates. `handCardSeatBounds` reads the same thing — the seat, not
## wherever a carried card happens to be.
func seat_centre(uid: int) -> Vector2:
	var view: CardView = _views.get(uid)
	if view == null:
		return Vector2.ZERO
	return global_position + view.home_position + view.size * 0.5


func add_card(inst: CardInst, data: Dictionary, cost: int) -> CardView:
	if _views.has(inst.uid):
		return _views[inst.uid]
	var view: CardView = CardView.new(inst, data, cost)
	# Before the tree sees it, so the card is never laid out at the wrong size
	# for a frame — a card that pops from 152 to 104 on its first relayout reads
	# as a bug even though it settles correctly.
	view.base_scale = card_w / CardView.CARD_W
	_views[inst.uid] = view
	_order.append(inst.uid)
	add_child(view)
	view.pressed_at.connect(_on_card_pressed_at)
	view.moved_to.connect(_on_card_moved_to)
	view.released_at.connect(_on_card_released_at)
	view.hover_changed.connect(_on_card_hover)
	_relayout()
	return view


func remove_card(uid: int) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	if hovered_uid == uid:
		hovered_uid = -1
		card_hover_changed.emit(-1)
	_end_deal(uid)
	_let_go(uid)
	remove_child(view)  # detach now — queue_free alone leaves a zombie until frame end
	view.queue_free()
	_relayout()


## Out of the fan, and out of any gesture that held it.
func _let_go(uid: int) -> void:
	_views.erase(uid)
	_order.erase(uid)
	if _drag_uid == uid:
		_drag_uid = -1
		_dragging = false
		_aiming = false


## Bring the fan in line with the engine's hand without rebuilding it.
##
## `presentation.syncHand` reconciles; this used to `clear()` and re-add every
## card at every drain-idle, which destroys a CardView that is still flying. A
## five-card deal overlaps its flights by design, so the last one was reliably
## in the air when the pump went idle — and it did not land, it was replaced by
## a fresh card already sitting in its seat.
##
## Returns the views now in the fan, in hand order, so the caller can set
## playability without asking for each one back.
func sync_hand(order: Array[int]) -> Array[CardView]:
	var wanted: Dictionary = {}
	for uid: int in order:
		wanted[uid] = true
	for uid_v: Variant in _views.keys():
		var uid: int = uid_v
		if not wanted.has(uid):
			remove_card(uid)
	_order.clear()
	var out: Array[CardView] = []
	for uid: int in order:
		var view: CardView = _views.get(uid)
		if view != null:
			_order.append(uid)
			out.append(view)
	_relayout()
	return out


func clear() -> void:
	for f: _Flight in _dealing.values():
		f.tween.kill()
	for f: _Flight in _leaving:
		f.tween.kill()
		if is_instance_valid(f.view):
			f.view.queue_free()
	_dealing.clear()
	_leaving.clear()
	_sent.clear()
	_deal_skipped = false
	set_process_input(false)
	for uid_v: Variant in _views.keys():
		var view: CardView = _views[uid_v]
		remove_child(view)
		view.queue_free()
	_views.clear()
	_order.clear()
	_drag_uid = -1
	_dragging = false
	_aiming = false


## Cancel an in-flight drag (input lock kicking in mid-gesture). Dropping the
## drag first is what lets the card TRAVEL home: `.dragging` is the class that
## suppresses the transition, so the pose is only resolved once it is off.
func cancel_drag() -> void:
	var was: int = _drag_uid
	_drag_uid = -1
	_dragging = false
	_aiming = false
	if was >= 0:
		_pose(was)


func snap_back(uid: int) -> void:
	_pose(uid)


# ---------------------------------------------------------------- layout

## The gap between card centres, from the benchmark's own `handZoneWidth`
## (combat.js:460): capped at 112, tightening as the hand grows so a big hand
## overlaps rather than overflowing, and finally clamped to the stage.
##
## This used to be a flat 120 tapered by `(size.x - 160) / (n - 1)` — which made
## the spread depend on how wide the CONTAINER happened to be rather than on how
## many cards are in the hand. Two screens with the same five cards fanned
## differently, and neither matched the benchmark's 112.
static func fan_gap(count: int, stage_w: float) -> float:
	var n: int = maxi(1, count)
	return minf(GAP_MAX, minf(GAP_BUDGET / float(n),
		(stage_w - STAGE_MARGIN) / float(maxi(n - 1, 1))))


## `handZoneWidth` — the box hugs the fan, so the hand is as wide as it needs to
## be and no wider. The zone stays centred; only its edges move.
##
## `card_width` is a parameter for the same reason it is one upstream
## (`combat.js:460` takes `cardW`): the gap constants above are fixed across
## every shape, and the card's own width is the ONLY shape-dependent term. It
## defaults to the authored silhouette so a caller with no book still gets
## pad-landscape's answer.
static func zone_width(count: int, stage_w: float,
		card_width: float = CardView.CARD_W) -> float:
	var n: int = maxi(1, count)
	var span: float = card_width
	if n > 1:
		span = float(n - 1) * fan_gap(n, stage_w) + card_width
	return minf(stage_w - 24.0, maxf(card_width + 16.0, ceilf(span + 20.0)))


# ---------------------------------------------------------------- dealing

## The gap the screen leaves between one draw of a wave of `count` and the
## next: the deal's stagger (CardFlight.stagger), Reduce Motion's, or none
## once a tap has landed the deal.
func deal_gap(count: int) -> float:
	if _deal_skipped or count <= 1:
		return 0.0
	if Preferences.active.reduce_motion:
		return CardFlight.RM_STAGGER
	return CardFlight.stagger(count)


## Fly a card that is already in the fan in from the draw pile, `delay`
## seconds from now: CardFlight's deal, turning face up on the way, or under
## Reduce Motion a fade at its seat. Once a tap has landed this wave's deal,
## it lands within SKIP_LAND.
func deal_in(uid: int, from: Rect2, delay: float = 0.0) -> void:
	var view: CardView = _views.get(uid)
	if view == null or not is_inside_tree():
		return
	_end_deal(uid)
	var f: _Flight = _Flight.new(view, uid)
	f.from = from
	# In RESTING units, so the card leaves the pile at the pile's width whatever
	# a card is worth on this shape.
	f.born = from.size.x / card_w if from.size.x > 0.0 else 1.0
	view.release_pose()
	view.pivot_offset = view.size * 0.5
	var still: bool = Preferences.active.reduce_motion
	f.step = (_appear_step if still else _deal_step).bind(f)
	f.land = (_appear_land if still else _deal_land).bind(f)
	_dealing[uid] = f
	if _deal_skipped:
		f.skipped = true
		_launch(f, 0.0, CardFlight.SKIP_LAND)
	else:
		_launch(f, delay, CardFlight.RM_FADE if still else CardFlight.DEAL_TIME)


## The deal at progress `t`. The seat is read LIVE on every step, because
## each further card in the same wave re-fans the hand and moves the seat this
## one is heading for; a flight given the old seat would land beside it. Both
## ends are measured by the card's centre (`_centre_at`).
func _deal_step(t: float, f: _Flight) -> void:
	f.t = t
	var view: CardView = f.view
	if not is_instance_valid(view):
		return
	var e: float = CardFlight.travel(t)
	var seat: Vector2 = global_position + view.home_position + view.size * 0.5
	var start: Vector2 = f.from.get_center() - Vector2(0.0, CardFlight.lift(t))
	var bow: float = CardFlight.arc(e)
	_centre_at(view, start.lerp(seat, e) - Vector2(0.0, stage_h * CardFlight.DEAL_ARC * bow))
	view.rotation = lerpf(deg_to_rad(CardFlight.PILE_TILT), view.home_rotation, e)
	view.scale = view.rest_scale(lerpf(f.born, 1.0, CardFlight.grow(t)))
	view.turn(CardFlight.yaw(t), CardFlight.pitch(t), false)
	view.set_air(bow)


func _deal_land(f: _Flight) -> void:
	if not _finish_deal(f):
		return
	var view: CardView = f.view
	view.turn(0.0, 0.0, false)
	view.set_air(0.0)
	view.scale = view.rest_scale()
	view.snap_home()
	CardFlight.glint(view)


## Reduce Motion's deal: the card fades in at its seat, rising RM_RISE px.
func _appear_step(t: float, f: _Flight) -> void:
	f.t = t
	var view: CardView = f.view
	if not is_instance_valid(view):
		return
	var k: float = 1.0 - (1.0 - t) * (1.0 - t)
	view.position = view.home_position + Vector2(0.0, CardFlight.RM_RISE * (1.0 - k))
	view.rotation = view.home_rotation
	view.scale = view.rest_scale()
	view.set_presence(k)


func _appear_land(f: _Flight) -> void:
	if not _finish_deal(f):
		return
	f.view.set_presence(1.0)
	f.view.snap_home()


## The deal `f` is over: out of the air, and true when its card is still
## there to be put down.
func _finish_deal(f: _Flight) -> bool:
	if _dealing.get(f.uid) == f:
		_dealing.erase(f.uid)
	_settle()
	return is_instance_valid(f.view)


## Put a card still being dealt down where it is, face up, and end its flight:
## it is about to be removed, spent, struck or dealt again.
func _end_deal(uid: int) -> void:
	var f: _Flight = _dealing.get(uid)
	if f == null:
		return
	f.tween.kill()
	_dealing.erase(uid)
	if is_instance_valid(f.view):
		f.view.turn(0.0, 0.0, false)
		f.view.set_air(0.0)
		f.view.set_presence(1.0)
	_settle()


## Start a flight: placed at its start now, then carried over `seconds`
## after `delay`, and landed.
func _launch(f: _Flight, delay: float, seconds: float) -> void:
	f.step.call(0.0)
	f.tween = create_tween()
	if delay > 0.0:
		f.tween.tween_interval(delay)
	f.tween.tween_method(f.step, 0.0, 1.0, seconds)
	f.tween.tween_callback(f.land)
	_settle()


## Taps are heard only while something is in the air; a deal that has
## finished stops landing the rest of its wave.
func _settle() -> void:
	if _dealing.is_empty():
		_deal_skipped = false
	set_process_input(not _dealing.is_empty() or not _leaving.is_empty())


## A tap anywhere while cards are in the air lands them. It is not consumed:
## whatever the tap was for still gets it.
func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) \
			or (st != null and st.pressed):
		skip()


## Every card still in the deal lands face up within SKIP_LAND, the rest of
## its wave with it (`deal_gap`, `deal_in`); every card leaving lands on its
## pile at once.
func skip() -> void:
	if not _dealing.is_empty():
		_deal_skipped = true
	for f: _Flight in _dealing.values():
		if f.skipped:
			continue
		f.skipped = true
		f.tween.kill()
		f.tween = create_tween()
		f.tween.tween_method(f.step, f.t, 1.0, CardFlight.SKIP_LAND)
		f.tween.tween_callback(f.land)
	for f: _Flight in _leaving.duplicate():
		f.tween.kill()
		f.step.call(1.0)
		f.land.call()


## Whether a card left the fan for a pile by a flight and is still on its way
## there or lying on it.
func sent(uid: int) -> bool:
	return is_instance_valid(_sent.get(uid))


## A card leaves the hand for a pile (CardFlight). It is out of the fan the
## moment this is called — the others close the gap at once, as they do in the
## benchmark — and the node lives until it has landed and handed over to the
## pile. `delay` holds it where it is first (the end of a turn's sweep).
## `on_land` runs as it reaches the pile: the pile answers the card that
## arrives. Under Reduce Motion it fades where it is and never arrives.
## Returns the seconds until it has landed or faded, 0 for no such card.
func spend_to(uid: int, to: Rect2, how: Leave = Leave.DISCARD, delay: float = 0.0,
		on_land: Callable = Callable()) -> float:
	var view: CardView = _views.get(uid)
	if view == null:
		return 0.0
	_end_deal(uid)
	_let_go(uid)
	if not is_inside_tree():
		remove_child(view)
		view.queue_free()
		_relayout()
		return 0.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.release_pose()
	view.pivot_offset = view.size * 0.5
	view.move_to_front()
	var f: _Flight = _Flight.new(view, uid)
	f.how = how
	f.on_land = on_land
	var seconds: float = CardFlight.RM_FADE
	if Preferences.active.reduce_motion:
		delay = 0.0
		if how == Leave.BURN:
			CardFlight.ember(view, CardFlight.EMBER_COOL)
		f.step = _fade_step.bind(f)
		f.land = _fade_land.bind(f)
	else:
		_aim_leave(f, to)
		seconds = CardFlight.BURN_TIME if how == Leave.BURN else CardFlight.DISCARD_TIME
		f.step = _leave_step.bind(f)
		f.land = _leave_land.bind(f)
	_sent[uid] = view
	_leaving.append(f)
	_launch(f, delay, seconds)
	_relayout()
	return delay + seconds


## Where a leaving card sets off from and lands: the pile's top card, at its
## size, a little loose (a burning card smaller and turned, as
## `.card.exhausting` throws it).
func _aim_leave(f: _Flight, to: Rect2) -> void:
	var view: CardView = f.view
	var shrink: float = to.size.x / card_w if to.size.x > 0.0 else 1.0
	f.start_centre = view.global_centre()
	f.start_rot = view.rotation
	f.start_scale = view.scale.x
	f.end_centre = to.get_center()
	f.end_scale = view.rest_scale(shrink).x
	match f.how:
		Leave.DISCARD:
			f.end_rot = deg_to_rad(CardFlight.DISCARD_TILT * CardFlight.jitter(f.uid, 0))
		Leave.SWEEP:
			f.end_rot = deg_to_rad(CardFlight.SWEEP_TILT * CardFlight.jitter(f.uid, 0))
			f.end_centre += Vector2(CardFlight.jitter(f.uid, 1),
				CardFlight.jitter(f.uid, 2)) * CardFlight.SWEEP_SLIP
		Leave.BURN:
			f.end_rot = deg_to_rad(CardFlight.BURN_TILT)
			f.end_scale = view.rest_scale(shrink * CardFlight.BURN_SHRINK).x


func _leave_step(t: float, f: _Flight) -> void:
	f.t = t
	var view: CardView = f.view
	if not is_instance_valid(view):
		return
	var e: float = CardFlight.ease_in_out(t) if f.how == Leave.SWEEP \
		else CardFlight.ease_in(t)
	_centre_at(view, f.start_centre.lerp(f.end_centre, e))
	view.rotation = lerpf(f.start_rot, f.end_rot, e)
	view.scale = Vector2.ONE * lerpf(f.start_scale, f.end_scale, e)
	if f.how == Leave.BURN:
		view.turn(180.0 * smoothstep(0.0, 1.0, t), 0.0, false)
		view.tint_picture(CardFlight.burn_tint(t))


## On the pile: the pile answers, the card lies there a moment (a burnt one
## while its ember rim cools) and then fades into the pile. It is held on its
## pile meanwhile: the hand's own box moves as the fan re-edges.
func _leave_land(f: _Flight) -> void:
	_leaving.erase(f)
	_settle()
	if not is_instance_valid(f.view):
		return
	var hold: float = CardFlight.HANDOFF_HOLD
	if f.how == Leave.BURN:
		hold = CardFlight.EMBER_COOL
		CardFlight.ember(f.view, hold)
	if f.on_land.is_valid():
		f.on_land.call()
	var tw: Tween = f.view.create_tween()
	tw.tween_method(_pin.bind(f), 0.0, 1.0, hold)
	tw.tween_property(f.view, "modulate:a", 0.0, CardFlight.HANDOFF_FADE)
	tw.tween_callback(_gone.bind(f))


func _pin(_t: float, f: _Flight) -> void:
	if is_instance_valid(f.view):
		_centre_at(f.view, f.end_centre)


## Put a card's centre on a global point. A card turns and scales about its
## centre (`pivot_offset`), so its centre is `position + size / 2` in this
## box whatever its scale and angle. Not through `global_position`: in 4.7 that
## places the card's transformed origin, which a scaled or turned card has
## moved away from its corner.
func _centre_at(view: CardView, centre: Vector2) -> void:
	view.position = get_global_transform().affine_inverse() * centre - view.size * 0.5


## Reduce Motion's leaving: the card fades where it is.
func _fade_step(t: float, f: _Flight) -> void:
	f.t = t
	if is_instance_valid(f.view):
		f.view.set_presence(1.0 - t)


func _fade_land(f: _Flight) -> void:
	_leaving.erase(f)
	_settle()
	_gone(f)


func _gone(f: _Flight) -> void:
	if _sent.get(f.uid) == f.view:
		_sent.erase(f.uid)
	if is_instance_valid(f.view):
		f.view.queue_free()


## A targeted card does not leave the hand for a pile — it goes at the foe.
## `drain.js:501`: the card streaks into the enemy and lands at 22% of its own
## size, and only the `toDiscard` that follows moves the pile copy. 270ms, which
## is the window the blow is waiting inside.
func strike_to(uid: int, target: Vector2) -> void:
	var view: CardView = _views.get(uid)
	if view == null:
		return
	_end_deal(uid)
	_let_go(uid)
	if not is_inside_tree():
		remove_child(view)
		view.queue_free()
		_relayout()
		return
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.move_to_front()
	view.release_pose()
	view.pivot_offset = view.size * 0.5
	# By its centre (`_centre_at`): through `global_position` the shrinking
	# card landed up and to the left of the foe it was thrown at.
	var from: Vector2 = view.global_centre()
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(view):
			_centre_at(view, from.lerp(target, CardFlight.ease_in(t))),
		0.0, 1.0, STRIKE_FLIGHT)
	tw.tween_property(view, "scale", view.rest_scale(STRIKE_SCALE), STRIKE_FLIGHT)
	tw.tween_property(view, "rotation", 0.0, STRIKE_FLIGHT)
	# Held opaque for the first half: a card that fades as it launches never
	# reads as having been thrown at anything.
	tw.tween_property(view, "modulate:a", 0.0, STRIKE_FLIGHT * 0.45) \
		.set_delay(STRIKE_FLIGHT * 0.55)
	tw.chain().tween_callback(view.queue_free)
	_relayout()


# ---------------------------------------------------------------- layout

## `handRotationDeg` — the tilt of seat `i`, in degrees, positive clockwise.
static func rotation_deg(i: int, count: int) -> float:
	var n: int = maxi(1, count)
	if n <= 1:
		return 0.0
	return (float(i) - float(n - 1) * 0.5) * minf(TILT_STEP_MAX, TILT_TOTAL_DEG / float(n))


## `handMaxDrop` — how far the lowest seat of an `n`-card fan hangs below the
## resting baseline.
static func max_drop(count: int) -> float:
	var n: int = maxi(1, mini(MAX_CARDS, count))
	return absf(rotation_deg(0, n)) * SAG_PER_DEG + BASE_Y


## Re-fan against a stage width that has changed under the hand. Public because
## nothing else outside may need `_relayout`, and this one thing does.
func refan() -> void:
	_relayout()


## Re-size the cards already in the fan when the stage crosses a shape boundary.
## New cards read `card_w` in `add_card`; the live ones need the same answer.
func set_card_metrics(width: float, inset: float) -> void:
	card_w = maxf(1.0, width)
	card_inset = inset
	for view: CardView in _views.values():
		view.base_scale = card_w / CardView.CARD_W
	_relayout()


## Fan the cards along a shallow arc: centred spread, outer cards sit lower
## and tilt outward. `layoutHandSeats` in the benchmark, seat for seat.
func _relayout() -> void:
	var n: int = _order.size()
	if n == 0:
		return
	# The gap is measured against the STAGE, not this box — the box is sized BY
	# the gap, so reading it here would be circular.
	# Anchored centred by the screen, so the zone resizes by moving its own
	# edges and stays on the stage's centre line. The WIDTH is measured on the
	# real count; the SEATS stop at ten, so an eleventh card doubles up.
	var want: float = zone_width(n, stage_w, card_w)
	if absf(want - size.x) > 0.5 and absf(anchor_left - 0.5) < 0.001:
		offset_left = -want * 0.5
		offset_right = want * 0.5
	var seats: int = maxi(1, mini(MAX_CARDS, n))
	var spacing: float = fan_gap(seats, stage_w)
	var center_x: float = want * 0.5
	# The zone hangs past the stage bottom on purpose, and the fan is left there.
	var base_bottom: float = size.y - card_inset
	# A card is drawn at the authored silhouette and SCALED to the shape, about
	# its own centre. The centre is therefore invariant and `x` needs no
	# correction; the bottom edge is not, so the top is placed from where the
	# scaled bottom has to land rather than from the unscaled height.
	var shrink: float = card_w / CardView.CARD_W
	var half_h: float = CardView.CARD_H * 0.5
	for i: int in range(n):
		var view: CardView = _views[_order[i]]
		var idx: int = mini(i, seats - 1)
		var rot: float = rotation_deg(idx, seats)
		var offset_x: float = (float(idx) - float(seats - 1) * 0.5) * spacing
		var sag: float = absf(rot) * SAG_PER_DEG + BASE_Y
		view.home_position = Vector2(
			center_x + offset_x - view.size.x * 0.5,
			base_bottom + sag - half_h * (1.0 + shrink)
		)
		view.home_rotation = deg_to_rad(rot)
		# A card being carried follows the pointer, and a card in flight is on its
		# own clock — it reads the seat set just above on its next step, so the
		# new seat is honoured without this function touching its transform.
		# `_pose` skips both, and it re-resolves the pose rather than dropping the
		# card back into its seat: a hand that changes under a hovered card used to
		# put that card down, and the reference just re-fans the others around it.
		_pose(view.uid)


# ---------------------------------------------------------------- gestures

func _on_card_pressed_at(uid: int, global_pos: Vector2) -> void:
	# A card still in the air is not in the hand yet: the tap that lands it
	# (`skip`) takes nothing else.
	if locked or _dealing.has(uid):
		return
	_drag_uid = uid
	_dragging = false
	_press_pos = global_pos


func _on_card_moved_to(uid: int, global_pos: Vector2) -> void:
	if locked or _drag_uid != uid:
		return
	var view: CardView = _views.get(uid)
	if view == null:
		return
	if not _dragging:
		# `st.y0 - event.clientY < DRAG_START_PX` — UPWARD, not any direction.
		# A card is lifted OFF the fan; sliding along it is not a lift, and
		# arming on raw distance made a sideways drift throw a card.
		if _press_pos.y - global_pos.y < DRAG_START_PX:
			return
		if not view.playable:
			card_drag_refused.emit(uid)
			return  # unplayable cards can be tapped, never dragged
		_dragging = true
		card_drag_armed.emit(uid)
		# `beginCardDrag` (combat.js:1112): a card that targets an enemy AIMS —
		# it keeps its seat and the screen throws an arc from it — and every
		# other card is carried. Kindle turns the whole hand into fuel, so
		# nothing aims, which is the benchmark's `kindleOnly` branch.
		_aiming = view.target_kind == "enemy" and not kindle_mode
		if not _aiming:
			view.move_to_front()
			view.rotation = 0.0
			# `scale = model.drag.scale ?? 1.12` — a carried card is bigger than an
			# armed one, because it is the thing the pointer is holding.
			view.scale = view.rest_scale(DRAG_SCALE)
	if not _aiming:
		view.global_position = global_pos - view.size * 0.5
	card_drag_moved.emit(uid, global_pos)


func _on_card_released_at(uid: int, global_pos: Vector2) -> void:
	if _drag_uid != uid:
		return
	var was_dragging: bool = _dragging
	_drag_uid = -1
	_dragging = false
	_aiming = false
	if locked:
		snap_back(uid)
		return
	if was_dragging:
		card_drag_released.emit(uid, global_pos)
	elif global_pos.distance_to(_press_pos) < CLICK_SLOP:
		card_tapped.emit(uid)
	else:
		# Moved too far to be a click and not far enough up to be a drag. The
		# benchmark drops it on the floor too, deliberately.
		snap_back(uid)


func _on_card_hover(uid: int, hovering: bool) -> void:
	# Coarse has no hover. emulate_mouse_from_touch synthesises mouse_entered
	# before the finger lifts; writing hovered_uid here would skip the first-tap
	# lift in CombatScreen._on_card_tapped (#386). Fine-pointer is unchanged.
	if PointerDevice.coarse():
		return
	if locked or _dragging:
		return
	var view: CardView = _views.get(uid)
	if view == null:
		return
	# `if (S.hoveredCard !== uid)` — the tick and the relayout are on the
	# CHANGE, not on every move the pointer makes inside one seat.
	var next: int = uid if hovering else -1
	if next != hovered_uid and (hovering or hovered_uid == uid):
		hovered_uid = next
		card_hover_changed.emit(next)
	_pose(uid)


## Lift a seat without a pointer over it — the keyboard's cursor through the
## fan does the same thing hovering does (`S.hoveredCard = S.selectedCardUid`).
func raise_seat(uid: int) -> void:
	hovered_uid = uid
	_pose_all()


## `setTargeting` (combat.js:1297) — this card is the one waiting on a target.
func arm_seat(uid: int) -> void:
	armed_uid = uid
	_pose_all()


func drop_seat() -> void:
	armed_uid = -1
	hovered_uid = -1
	_pose_all()


func _pose_all() -> void:
	for uid: int in _order:
		_pose(uid)


## Write one seat's whole transform from whichever of the four poses it is in.
## Branches, never accumulates — a card that is both hovered and armed is armed,
## the same way the renderer's `if / else if` chain resolves it.
func _pose(uid: int) -> void:
	var view: CardView = _views.get(uid)
	# A card in flight is on its own clock; posing it would teleport it back to
	# the fan mid-arc.
	if view == null or _dealing.has(uid):
		return
	# A CARRIED card is written by the pointer on every move, so it is not posed
	# from here at all. An AIMING one keeps its seat — the drag only goes
	# `free` for the kindle branch (combat.js:1121) — so it falls through to `armed` below,
	# which is the pose `beginCardDrag`'s own `setTargeting` puts it in.
	if _dragging and _drag_uid == uid and not _aiming:
		return
	# One branch resolves the whole pose, and the card TRAVELS to it — both the
	# seat and the lift carry `transition: transform 0.28s` in the reference, so a
	# card that changes pose is never seen in two places on consecutive frames.
	var pos: Vector2 = view.home_position
	var rot: float = view.home_rotation
	var scl: float = 1.0
	if uid == armed_uid:
		# `x = zoneCenterX + off.x * 0.4` — measured on the seat's CENTRE, then
		# converted back to a top-left, because that is what `position` is.
		var centre: float = size.x * 0.5
		var seat: float = view.home_position.x + view.size.x * 0.5
		pos = Vector2(centre + (seat - centre) * ARMED_PULL - view.size.x * 0.5,
			view.home_position.y - ARMED_LIFT)
		rot = view.home_rotation * ARMED_ROT
		scl = ARMED_SCALE
		view.move_to_front()
	elif uid == hovered_uid and not locked and not _dragging:
		pos = Vector2(view.home_position.x, view.home_position.y - HOVER_LIFT)
		rot = 0.0
		scl = HOVER_SCALE
		view.move_to_front()
	view.glide_to(pos, rot, scl)


## Which card the pointer is over, or -1. Front to back, because a fanned hand
## overlaps and the card you can see is the one you mean.
## The card being carried or aimed, or -1. `S.drag.live` — a press that has
## not yet cleared the slop is not a drag and previews nothing.
func dragged_uid() -> int:
	return _drag_uid if _dragging else -1


## `S.drag.free` — the card is being CARRIED rather than aimed, which is what
## lets an `allEnemies` card keep lighting every foe while it is in the air.
func is_free_drag() -> bool:
	return _dragging and not _aiming


func card_at(global_pos: Vector2) -> int:
	for i: int in range(get_child_count() - 1, -1, -1):
		var view: CardView = _held(get_child(i))
		if view == null:
			continue
		var local: Vector2 = view.get_global_transform().affine_inverse() * global_pos
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			return view.uid
	return -1


## Which dotted keyword the pointer is over, or "". Same front-to-back walk.
func keyword_at(global_pos: Vector2) -> String:
	for i: int in range(get_child_count() - 1, -1, -1):
		var view: CardView = _held(get_child(i))
		if view == null:
			continue
		var word: String = view.keyword_at(global_pos)
		if word != "":
			return word
	return ""


## `child` when it is a card the hand still holds, else null: a card on its
## way to a pile, or lying on one, is not under the player's finger any more.
func _held(child: Node) -> CardView:
	var view: CardView = child as CardView
	if view == null or _views.get(view.uid) != view:
		return null
	return view
