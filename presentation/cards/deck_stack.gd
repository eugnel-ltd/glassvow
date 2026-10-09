class_name DeckStack
extends Control
## The deck on the top menu as a stack of real cards (issue #657, PR 5b; §4's
## "Top-menu deck" in docs/design/2026-10-03-cards-real-objects/README.md).
## The run HUD's deck button and the combat seal both wear one, where the
## painted deck (`ui/deck`) stood: a stack of backs in the table's back, as
## thick as the deck is by the piles' law.
##
## THE SIZE. On the pad, a 36 x 51 px card where the painting stood 56 px
## square; the painting's side scales it, so the phone's 42 px gives a 27 x 38
## card. The stack is a PileStack drawn at the combat pile's card, the card the
## thickness law is written for, and scaled down to this one: its thickness,
## its slivers, their jitter, its shadow and its glint all scale together, so
## the law reads the same at both sizes (on the pad, 1 px a card becomes
## 0.61 px and the 14 px cap 8.6 px).
##
## THE TOP CARD STAYS PUT, `top` px under the square's top (TOP_PX unless the
## button says otherwise), and the deck deepens under it. A 51 px card and its
## thickness overfill the 56 px the painting had, and both top bars start at
## the screen's edge: a stack that rose from a fixed bottom card cut its top
## off on the pad from about 30 cards. Held by its top, the count sits on the
## same place on the card at every size, and a full deck's edge runs about
## 6 px under the run HUD's bar.
##
## THE BACK. The stack wears the table's back (CardTurn.back) and follows it
## frame by frame, as the combat piles do, so a change of back shows as soon as
## its bake lands. Until a bake lands, and while a change of back waits for its
## own, the button draws what it drew before this stack: the painting, never a
## blank. Main bakes the back outside a fight (`Main._bake_table_back`).
##
## LIFE AT REST. The draw pile's glint (PileStack), every GLINT_CYCLE, starting
## half a cycle after the draw pile's: in a fight the two stacks never glint
## together. Canvas only; Reduce Motion stills it.

## The stack's card on the pad, where the painting stood ICON_SIDE px square.
const CARD_H: float = 51.0
const ICON_SIDE: float = 56.0
## The card the thickness law is written for: the combat pile's, on the pad.
const LAW_CARD_H: float = HudBar.PILE_BOX.x * HudBar.PILE_CARD_H
## The top card's margin under the square's top, at ICON_SIDE, by default.
const TOP_PX: float = 2.0
## Where in its cycle this stack's glint starts: half a cycle after the draw
## pile's, which starts at 0. A sweep is 1.4 s of 9, so the two never overlap.
const GLINT_PHASE: float = PileStack.GLINT_CYCLE * 0.5

## The stack of backs, drawn once a back is baked.
var stack: PileStack
## The painting the button wore before: shown until a back is worn.
var painting: TextureRect
var _worn: CardBacks.Baked = null
## The top card's centre in the stack's own px, where it stays.
var _top: Vector2 = Vector2.ZERO


## A stack in a `side` px square, the size the painting stood at, with
## `art` as that painting and the top card `top` px under the square's top
## (by default TOP_PX, scaled with the square).
func _init(side: float, art: Texture2D, top: float = NAN) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	painting = TextureRect.new()
	painting.texture = art
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painting.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(painting)
	stack = PileStack.new(PileStack.Kind.DRAW)
	stack.idle_phase = GLINT_PHASE
	var k: float = scale_for(side)
	stack.scale = Vector2(k, k)
	stack.size = size / k
	stack.card = Vector2(CardView.CARD_W / CardView.CARD_H, 1.0) * LAW_CARD_H
	if is_nan(top):
		top = TOP_PX * side / ICON_SIDE
	_top = Vector2(stack.size.x * 0.5, top / k + stack.card.y * 0.5)
	stack.base = _top
	add_child(stack)
	_follow()


## How far a stack in a `side` px square is drawn down from the law's card.
static func scale_for(side: float) -> float:
	return CARD_H * side / ICON_SIDE / LAW_CARD_H


## Stand `n` cards, the top one where it was and the deck deeper under it.
func set_count(n: int) -> void:
	stack.base = _top + Vector2(0.0, PileStack.thickness(maxi(n, 0)))
	stack.set_count(n)


## The back the stack wears, or null while it shows the painting.
func worn() -> CardBacks.Baked:
	return _worn


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var back: CardBacks.Baked = CardTurn.back()
	if back == _worn and stack.visible == (back != null):
		return
	_worn = back
	stack.wear_back(back.stage if back != null else null)
	stack.visible = back != null
	painting.visible = back == null
