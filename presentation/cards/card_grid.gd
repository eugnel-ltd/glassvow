class_name CardGrid
extends HFlowContainer
## Many cards at once — the deck overlay and every deck picker (ChoiceScreen's
## card mode) — as baked faces (BakedCard, CardFaces), with a live card only
## where the pointer is and where it just was. A card the pointer leaves
## springs back to rest, as the live cards did, and goes back to its face once
## it is there. At most LIVE_MAX live cards stand: a pointer sweeping on past
## more cards than that drops the one that has been springing back longest,
## nearest to rest, at once. A deck of any size then holds one face per
## distinct card and at most LIVE_MAX live cards, not a live card per card
## (#657).
##
## Rows are ChoiceScreen's: `card` (a CardInst), `definition`, `id`, and
## `disabled` for a card that is shown but cannot be chosen. Rows without a
## card are not this grid's.

## A card that can be chosen was pressed and let go.
signal picked(id: String)

## The most live cards that stand at once: the card under the pointer and the
## last it left, or the last two it left, springing back. Each holds a live
## card's video memory (about 13 MB) for the second or less it takes.
const LIVE_MAX: int = 2

var _cards: Array[BakedCard] = []
var _seats: Array[Control] = []
## The card under the pointer, or null.
var _live: BakedCard = null
## Cards the pointer has left that are springing back, the longest first.
var _settling: Array[BakedCard] = []


func _init(rows: Array[Dictionary], gap: float) -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	add_theme_constant_override("h_separation", roundi(gap))
	add_theme_constant_override("v_separation", roundi(gap))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row: Dictionary in rows:
		if not row.has("card"):
			continue
		var inst: CardInst = row["card"]
		var definition: Dictionary = row.get("definition", {})
		var card: BakedCard = BakedCard.new(inst, definition, CardFaces.cost_of(definition))
		card.pointer_changed.connect(_on_pointer)
		if not row.get("disabled", false):
			var id: String = str(row.get("id", ""))
			card.released.connect(func(_card: BakedCard) -> void: picked.emit(id))
		# The seat is what the flow lays out; the card hangs centred in it at
		# its scale, as the live cards did.
		var seat: Control = Control.new()
		seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(seat)
		seat.add_child(card)
		_cards.append(card)
		_seats.append(seat)


## Seat every card at `k` times its authored size.
func set_card_scale(k: float) -> void:
	var authored: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
	for i: int in range(_cards.size()):
		_seats[i].custom_minimum_size = authored * k
		_cards[i].position = (authored * k - authored) * 0.5
		_cards[i].scale = Vector2.ONE * k


func cards() -> Array[BakedCard]:
	return _cards


func _on_pointer(card: BakedCard, on: bool) -> void:
	if on:
		_point_to(card)
	else:
		_let_go(card)


func _point_to(card: BakedCard) -> void:
	# Taken off the springing list first, so making room cannot drop it.
	_settling.erase(card)
	if _live != card and is_instance_valid(_live):
		_let_go(_live)
	_live = card
	_make_room(LIVE_MAX - 1)
	card.go_live()


func _let_go(card: BakedCard) -> void:
	if card == _live:
		_live = null
	card.let_go()
	_settling.erase(card)
	_settling.append(card)
	_make_room(LIVE_MAX if _live == null else LIVE_MAX - 1)


## Leave at most `room` cards springing back: those already at rest have gone
## to their faces by themselves; past that, the longest springing go at once.
func _make_room(room: int) -> void:
	_settling = _settling.filter(func(each: BakedCard) -> bool: return each.live() != null)
	while _settling.size() > room:
		_settling.pop_front().go_rest()
