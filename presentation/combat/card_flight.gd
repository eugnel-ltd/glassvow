class_name CardFlight
extends RefCounted
## How a card travels between the piles and the hand (issue #657; the motion
## spec's Draw, Play, End-of-turn discard and Exhaust rows in
## docs/design/2026-10-03-cards-real-objects/README.md §3). HandView flies the
## cards and owns their state; this holds the arithmetic and the dressing, so
## where a card is at any moment of a flight is a pure function of how far
## through it is (`t`, linear time, 0 to 1).
##
## THE DEAL is a picture turn (CardView.turn, not live): the frozen card is
## warped on the canvas, so a five-card deal renders nothing a resting hand
## does not. A card leaves the draw pile face down, at the pile's size and
## tilt, and lifts LIFT_OFF px off it in its first LIFT_TIME. It then travels
## to its seat on an ease-out cubic, bowed up by an arc that peaks at DEAL_ARC
## of the stage height (a fixed height was far too tall on the 390 px phone
## stage), turning to its seat's angle. Its growth from a pile card to a hand
## card rides the seat overshoot (CardView.POSE_EASE), so it swells a little
## past a hand card as it arrives and settles into it. It turns over between
## TURN_FROM and TURN_TO of the flight (yaw 180 to 0, smoothstep), pitched
## toward the viewer by PITCH * sin(pi t); its table shadow narrows with the
## turn and drops away under the arc. As it lands an edge glint runs round it.
##
## LEAVING. A played skill eases in to the discard pile and lands face up on
## top, a few degrees loose; the end of a turn sweeps the hand there card by
## card, landing looser. A card bound for the ash blazes, turns face down as it
## burns and lands as a charred back whose ember rim cools. Each lies on its
## pile a moment and then hands over to the pile (`HANDOFF_*`): the pile itself
## becomes the cards it holds in a later step of #657.
##
## The landings' jitter is a hash of the card's uid, not a random draw: the
## same card lands the same way, and nothing here touches the run's RNG.

## The deal. Five cards leave 90 ms apart, so a five-card deal takes 0.78 s.
const DEAL_TIME: float = 0.42
const DEAL_STAGGER: float = 0.09
## Past five cards the stagger shares this budget, never closer than the floor.
const DEAL_STAGGER_BUDGET: float = 0.45
const DEAL_STAGGER_MIN: float = 0.04
const DEAL_ARC: float = 0.09         # of the stage height
const TURN_FROM: float = 0.12
const TURN_TO: float = 0.78
const PITCH: float = -14.0           # degrees, toward the viewer
const PILE_TILT: float = -4.0        # degrees: the pile's top card
const LIFT_OFF: float = 6.0          # px
const LIFT_TIME: float = 0.06
## How far the table shadow drops away at the top of the arc, in units of the
## hover lift's own shadow move (CardView.set_air).
const AIR: float = 2.0
## A tap lands every card still in the deal, face up, in this long.
const SKIP_LAND: float = 0.12

## Leaving. A discard eases in over DISCARD_TIME; the end of a turn sweeps the
## hand SWEEP_STAGGER apart (five cards: 0.46 s).
const DISCARD_TIME: float = 0.26
const SWEEP_STAGGER: float = 0.05
const DISCARD_TILT: float = 3.0      # degrees either way, a played card
const SWEEP_TILT: float = 5.0        # degrees either way, the end of a turn
const SWEEP_SLIP: float = 3.0        # px either way, the end of a turn
## The exhaust: the existing blaze (`.card.exhausting`, styles.css:650) over
## the existing 0.2 s, turning face down as it burns.
const BURN_TIME: float = 0.2
const BURN_TILT: float = 8.0
const BURN_SHRINK: float = 0.6
const BLAZE: Color = Color(2.4, 2.15, 1.8)
const CHAR: Color = Color(0.42, 0.4, 0.38)
const EMBER: Color = Color(1.0, 0.66, 0.26)
## The ember rim's cold end: what its glow multiplies down to as it dies.
const EMBER_COLD: Color = Color(0.5, 0.18, 0.12, 0.0)
const EMBER_COOL: float = 1.2
## A landed card lies on its pile this long, then fades into it.
const HANDOFF_HOLD: float = 0.3
const HANDOFF_FADE: float = 0.15

## Reduce Motion: no arc, no turn, no pitch. A drawn card fades in at its seat,
## rising RM_RISE px; a leaving one fades where it is.
const RM_FADE: float = 0.16
const RM_RISE: float = 6.0
const RM_STAGGER: float = 0.04

## The edge glint as a dealt card's face settles.
const GLINT_TIME: float = 0.25
const GLINT: Color = Color(1.0, 0.95, 0.84, 0.9)


## The gap between one card leaving the pile and the next, for a wave of
## `count` draws: 90 ms up to five, then `max(40 ms, 450 ms / n)`.
static func stagger(count: int) -> float:
	if count <= 1:
		return 0.0
	if count <= 5:
		return DEAL_STAGGER
	return maxf(DEAL_STAGGER_MIN, DEAL_STAGGER_BUDGET / float(count))


## The share of the deal spent lifting off the pile.
static func lift_share() -> float:
	return LIFT_TIME / DEAL_TIME


## Progress along the path from the pile to the seat: none while the card
## lifts off, then ease-out cubic.
static func travel(t: float) -> float:
	var u: float = clampf((t - lift_share()) / (1.0 - lift_share()), 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## How far the card has risen off the pile, in px.
static func lift(t: float) -> float:
	var u: float = clampf(t / lift_share(), 0.0, 1.0)
	return LIFT_OFF * (1.0 - (1.0 - u) * (1.0 - u))


## The deal's turn: face down (180) until TURN_FROM, face up (0) from TURN_TO.
static func yaw(t: float) -> float:
	return 180.0 * (1.0 - smoothstep(TURN_FROM, TURN_TO, t))


static func pitch(t: float) -> float:
	return PITCH * sin(PI * clampf(t, 0.0, 1.0))


## How high the arc stands at path progress `e`, as a share of its peak.
static func arc(e: float) -> float:
	return sin(PI * clampf(e, 0.0, 1.0))


## The card's growth from a pile card (0) to a hand card (1), with the seat's
## overshoot.
static func grow(t: float) -> float:
	var u: float = clampf((t - lift_share()) / (1.0 - lift_share()), 0.0, 1.0)
	return Motion.ease(CardView.POSE_EASE, u)


## A card's own jitter for one quantity (`salt`), -1 to 1: the same card
## always lands the same way.
static func jitter(uid: int, salt: int) -> float:
	return float(posmod(hash(Vector2i(uid, salt)), 2001)) / 1000.0 - 1.0


static func ease_in(t: float) -> float:
	return t * t * t


static func ease_in_out(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


## The burning card's picture: white to the blaze by the time it is edge on,
## then down to char as its back comes round.
static func burn_tint(t: float) -> Color:
	if t < 0.5:
		return Color.WHITE.lerp(BLAZE, t * 2.0)
	return BLAZE.lerp(CHAR, (t - 0.5) * 2.0)


## A light round the card's edge, on the canvas over its picture: the card's
## own passes stay frozen. The panel fills the card's rect and rides its
## transform, so it is lit only while the card lies flat, face up or face
## down, where the card's silhouette is that rect.
static func rim(colour: Color, width: int, glow: int) -> Panel:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(colour, 0.0)
	sb.draw_center = false
	sb.set_corner_radius_all(CardView.RADIUS)
	sb.set_border_width_all(width)
	sb.border_color = colour
	sb.shadow_color = Color(colour, colour.a * 0.6)
	sb.shadow_size = glow
	var panel: Panel = Panel.new()
	panel.name = "Rim"
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = Vector2(CardView.CARD_W, CardView.CARD_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## The edge glint: up in its first quarter, gone by GLINT_TIME.
static func glint(card: Control) -> void:
	var light: Panel = rim(GLINT, 2, 6)
	light.modulate.a = 0.0
	card.add_child(light)
	var tw: Tween = light.create_tween()
	tw.tween_property(light, "modulate:a", 1.0, GLINT_TIME * 0.25)
	tw.tween_property(light, "modulate:a", 0.0, GLINT_TIME * 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)


## The ember rim of a card that has burnt: hot at once, holding its heat a
## moment and cooling over `seconds` to nothing.
static func ember(card: Control, seconds: float) -> void:
	var glow: Panel = rim(EMBER, 3, 12)
	card.add_child(glow)
	var tw: Tween = glow.create_tween()
	tw.tween_property(glow, "modulate", EMBER_COLD, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(glow.queue_free)
