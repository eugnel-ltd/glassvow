class_name RewardEmbersPhone
extends RefCounted
## The embers' set-out on the phone. Pure geometry, no Node: every input is an
## argument, so a test can hold the whole screen inside 844x390 headlessly.
##
## WHY IT IS ITS OWN SET-OUT. The pad column is ~700 tall and the phone has 390,
## a hundred of it under the run HUD; no scale that fits the column leaves a card
## readable. So the offering stands at the right at the layout book's phone
## width (`rack/w`), the spoils stack as a column at its left — clear of the
## Flame's lantern seat — and the fire lies along the floor between them. The
## husk breaks at half size so its wreckage still fits the gap it falls into.
##
## Everything comes back as an offset from `centre`, the fire, because that is
## what `RewardEmbers` measures every piece from.

const K: float = 0.5                 # the husk, the throw and the bed
## The slab overhangs its box by 12% top and bottom too, so the box is
## `PITCH - 18` tall and stacked slabs stand apart instead of overlapping.
const SEAT: Vector2 = Vector2(290.0, 70.0)
const PITCH: float = 88.0
const EDGE: float = 16.0
## The take line and the word row under the rack; with no offering, the word
## row alone under the column.
const FOOT: float = 56.0
const LEAN_FOOT: float = 40.0
const COLUMN_GAP: float = 14.0
## A seat slab overhangs its box by 8% each side (`RewardEmbers._slab`), so the
## box is the column's width over 1.16 or the slabs touch the lantern and rack.
const SLAB_REACH: float = 1.16
## Where the fire lies, as a fraction of the band: low, but high enough that the
## wreckage along it stays inside the frame.
const FLOOR: float = 0.80


## `stage` is the screen's size, `top`/`bottom` the band left once the HUD and
## the floor margin come off, `card` one offered card's drawn size and
## `left_clear` the x the lantern's seat ends at.
static func lay_out(stage: Vector2, top: float, bottom: float, spoils: int,
		cards: int, card: Vector2, gap: float, left_clear: float) -> Dictionary:
	var band: float = maxf(0.0, bottom - top)
	var rack_w: float = float(cards) * card.x + float(maxi(0, cards - 1)) * gap
	var rack_x: float = stage.x - EDGE - rack_w
	var col_right: float = rack_x - COLUMN_GAP if cards > 0 else stage.x - EDGE
	var foot: float = 0.0 if cards > 0 else LEAN_FOOT
	var pitch: float = minf(PITCH, (band - foot) / float(maxi(1, spoils)))
	var seat: Vector2 = Vector2(minf(SEAT.x, (col_right - left_clear) / SLAB_REACH),
		pitch - 18.0)
	var stack: float = float(spoils) * pitch - (pitch - seat.y)
	var col_x: float = (left_clear + col_right) * 0.5
	var col_top: float = top + maxf(0.0, (band - foot - stack) * 0.5)
	# The fire lies on the floor, between the column and the rack: the column
	# stands in it and the rack is backlit from its left.
	var centre: Vector2 = Vector2(
		lerpf(col_x, rack_x if cards > 0 else col_x, 0.5), top + band * FLOOR)
	var seat_rel: Array[Vector2] = []
	for i: int in range(spoils):
		seat_rel.append(Vector2(col_x, col_top + seat.y * 0.5 + float(i) * pitch) - centre)
	var card_rel: Array[Vector2] = []
	var card_top: float = top + maxf(0.0, (band - card.y - FOOT) * 0.5)
	for i: int in range(cards):
		card_rel.append(Vector2(rack_x + float(i) * (card.x + gap), card_top) - centre)
	return {
		"centre": centre,
		"seat": seat,
		"seat_rel": seat_rel,
		"card_rel": card_rel,
		"husk_at": Vector2(0.0, -24.0),
		"bed_y": 0.0,
		# `RewardEmbers` hangs the word row 28 below this; with no offering the
		# row sits 10 under the column instead.
		"foot_y": card_top + card.y if cards > 0 else col_top + stack - 18.0,
		"foot_x": Vector2(rack_x, rack_x + rack_w) if cards > 0
			else Vector2(left_clear, col_right),
	}
