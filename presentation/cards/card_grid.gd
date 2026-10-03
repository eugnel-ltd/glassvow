class_name CardGrid
extends HFlowContainer
## Many cards at once — the deck overlay and every deck picker (ChoiceScreen's
## card mode) — as baked faces (BakedCard, CardFaces), with at most one live
## card: the one under the pointer. A card the pointer leaves springs back to
## rest and goes back to its face; a card the pointer reaches first drops the
## previous live card at once, so two never stand together. A deck of any size
## then holds one face per distinct card and one live card, not a live card
## per card (#657).
##
## Rows are ChoiceScreen's: `card` (a CardInst), `definition`, `id`, and
## `disabled` for a card that is shown but cannot be chosen. Rows without a
## card are not this grid's.

## A card that can be chosen was pressed and let go.
signal picked(id: String)

var _cards: Array[BakedCard] = []
var _seats: Array[Control] = []
var _live: BakedCard = null


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
		var cost_v: Variant = definition.get("cost")
		var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
		var card: BakedCard = BakedCard.new(inst, definition, cost)
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
	if not on:
		card.let_go()
		return
	if _live != card and is_instance_valid(_live):
		_live.go_rest()
	_live = card
	card.go_live()
