class_name DiscardTop
extends RefCounted
## Which card lies face up on top of the discard pile, and the face it wears
## (issue #657; §4 of docs/design/2026-10-03-cards-real-objects/README.md).
## The screen says when a card arrives (`arrive`); this names it the top at
## once, at the angle it landed at (CardFlight.landing_rot), and gives the
## pile its face as soon as there is one:
##
##   the face the card handed on as it left the hand (HandView.face_ready):
##   taken from its own stage at rest, on the GPU, so no bake is made. A
##   struck card hands it on at the end of its strike, before the discard
##   hears of it, so it is kept (`_seen`) until the card arrives;
##   else a face already baked (CardFaces.cached);
##   else a bake made now (CardFaces.request), when the card has no view left
##   to hand one on (it went at a foe before it was at rest, it faded, or it
##   was added to the pile by a foe).
##
## Until the face is there the pile keeps the picture it had, under the card
## lying on it. When the face lands the card on the pile goes at once
## (HandView.hand_over). The drain going idle settles the top on the domain's
## last discard (`settle`), so once every card has landed it is always that
## card. It holds the face it shows, whose GPU copy lives as long as it does.

## The card on top, -1 for none.
var uid: int = -1
var _swept: bool = false
var _face: CardFaces.Face = null
var _face_uid: int = -1
var _seen: Dictionary = {}    # uid -> CardFaces.Face
var _hud: HudBar = null
var _hand: HandView = null
## func(uid: int) -> CardInst, and func(inst: CardInst) -> Dictionary.
var _card_of: Callable
var _data_of: Callable


func _init(card_of: Callable, data_of: Callable) -> void:
	_card_of = card_of
	_data_of = data_of


## Show the top on this HUD (a rebuilt one too) and take faces from this hand.
func show_on(hud: HudBar, hand: HandView) -> void:
	_hud = hud
	_hand = hand
	_apply()


## Card `card_uid` has arrived on the discard and lies on top, as a card swept
## at the end of a turn lands (`swept`) or as a played one does.
func arrive(card_uid: int, swept: bool = false) -> void:
	uid = card_uid
	_swept = swept
	var face: CardFaces.Face = _seen.get(card_uid)
	_seen.erase(card_uid)
	if face == null:
		face = _cached(card_uid)
	if face != null:
		_wear(card_uid, face)
		return
	_apply()
	if _hand == null or not _hand.sent(card_uid):
		_bake(card_uid)


## HandView.face_ready: the face a card bound for the discard handed on, or
## null when it could not.
func face_ready(card_uid: int, face: CardFaces.Face) -> void:
	if face == null:
		if card_uid == uid and _face_uid != uid:
			_bake(card_uid)
		return
	if card_uid == uid:
		_wear(card_uid, face)
	else:
		_seen[card_uid] = face


## The discard has gone (a reshuffle took it).
func clear() -> void:
	uid = -1
	_face = null
	_face_uid = -1
	_apply()


## The drain is idle: the top is `want_uid`, the domain's last discard (-1
## for an empty pile). A card still in the air there is left to arrive by its
## own flight, a moment later, so it never shows under itself.
func settle(want_uid: int) -> void:
	if want_uid == uid:
		_seen.clear()
		return
	if want_uid >= 0 and _hand != null and _hand.in_air(false).has(want_uid):
		return
	_seen.clear()
	if want_uid < 0:
		clear()
	else:
		arrive(want_uid)


func _wear(card_uid: int, face: CardFaces.Face) -> void:
	if card_uid != uid:
		return
	_face = face
	_face_uid = card_uid
	_apply()
	if _hand != null:
		_hand.hand_over(card_uid)


func _apply() -> void:
	if _hud == null:
		return
	if uid < 0:
		_hud.clear_discard_top()
		return
	var picture: Texture2D = _face.picture if _face != null and _face_uid == uid else null
	_hud.set_discard_top(uid, picture, CardFlight.landing_rot(uid, _swept),
		CardFlight.landing_slip(uid, _swept))


func _cached(card_uid: int) -> CardFaces.Face:
	var inst: CardInst = _card_of.call(card_uid)
	if inst == null:
		return null
	var data: Dictionary = _data_of.call(inst)
	return CardFaces.cached(inst, data, CardFaces.cost_of(data))


func _bake(card_uid: int) -> void:
	var inst: CardInst = _card_of.call(card_uid)
	if inst == null or _hud == null or not _hud.is_inside_tree():
		return
	var data: Dictionary = _data_of.call(inst)
	CardFaces.request(_hud, inst, data, CardFaces.cost_of(data),
		func(face: CardFaces.Face) -> void: _wear(card_uid, face))
