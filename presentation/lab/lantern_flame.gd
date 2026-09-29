class_name LanternFlame
extends Node
## The Flame, drawn in the Duskblade's lantern. Issue #577 step 1, a spike.
##
## Presentation is handed the lantern's reading and never computes purity
## (design lock §9): `show_event()` takes an `EventTypes.FLAME` event exactly as
## the domain emits it and turns it into the inputs of `lantern_flame.gdshader`.
## Every input then moves over about a second on one ease, so a pick that dims
## the flame is SEEN dimming and nothing snaps. Put `material` on the lantern
## art and add this node anywhere it will process.
##
## The clock is the shader's own rather than TIME: `pinned` stops it, so a still
## is the same still every time it is taken, and `advance()` steps it by hand
## for a strip.

const SHADER: Shader = preload("res://presentation/lab/lantern_flame.gdshader")

enum Look { LEADED, VECTOR }

## About a second, on the stylesheet's ease-in-out: long enough to be watched
## after a pick, over before the next one.
const TWEEN_TIME: float = 1.0

## The ways' colours (§6), keyed by the content's way ids. Proposals: the lock
## leaves final hexes to approval on device.
const WAY_COLOUR: Dictionary[String, Color] = {
	"shatter": Color("#8fd0ff"),  # 碎 霜焰 Frostlight, blue-white: the game's facet blue
	"lantern": Color("#f2c14e"),  # 燼 熾焰 Hearthfire, amber-gold: the lantern gold
	"edge": Color("#9c2fa6"),     # 蝕 蝕焰 Eclipse, violet-crimson
}
## The flame before any way is declared: "a small orange flame", today's lantern.
const KINDLING_COLOUR: Color = Color("#e8702a")
## 塵焰, dust-brown.
const SOOT_COLOUR: Color = Color("#8a6e52")
## The shader's shape weight for each way; the plain flame is the fourth axis.
const WAY_SHAPE: Dictionary[String, Vector4] = {
	"shatter": Vector4(1.0, 0.0, 0.0, 0.0),
	"lantern": Vector4(0.0, 1.0, 0.0, 0.0),
	"edge": Vector4(0.0, 0.0, 1.0, 0.0),
}
const PLAIN_SHAPE: Vector4 = Vector4(0.0, 0.0, 0.0, 1.0)

## Per tier: how still the flame stands (0 guttering, 1 still) and how tall it
## burns. Both orders agree, so either alone ranks the tiers.
const TIER_STABILITY: Dictionary[String, float] = {
	"SOOT": 0.0, "KINDLING": 0.40, "STEADY": 0.85, "TRUE": 1.0,
}
const TIER_HEIGHT: Dictionary[String, float] = {
	"SOOT": 0.46, "KINDLING": 0.55, "STEADY": 0.80, "TRUE": 1.0,
}
## A fringe shows from `fringeMin` (0.25 for the Duskblade), already plain at
## FRINGE_FLOOR, and is at full strength by 0.40, the most a Steady flame's
## second way can hold.
const FRINGE_FROM: float = 0.25
const FRINGE_FULL: float = 0.40
const FRINGE_FLOOR: float = 0.55


## Everything the shader is told, as one value that can be blended.
class Reading:
	var dominant: Color = Color.BLACK
	var fringe: Color = Color.BLACK
	var fringe_amount: float = 0.0
	var stability: float = 0.0
	var height: float = 0.0
	var shape: Vector4 = PLAIN_SHAPE

	func blend(to: Reading, t: float) -> Reading:
		var out: Reading = Reading.new()
		out.dominant = dominant.lerp(to.dominant, t)
		out.fringe = fringe.lerp(to.fringe, t)
		out.fringe_amount = lerpf(fringe_amount, to.fringe_amount, t)
		out.stability = lerpf(stability, to.stability, t)
		out.height = lerpf(height, to.height, t)
		out.shape = shape.lerp(to.shape, t)
		return out


var material: ShaderMaterial = ShaderMaterial.new()
## True stops the clock and the tween; `advance()` still steps both.
var pinned: bool = false
var clock: float = 0.0

var _from: Reading = Reading.new()
var _to: Reading = Reading.new()
var _elapsed: float = TWEEN_TIME


## A lantern that has heard nothing yet burns as Kindling, the run's start.
func _init() -> void:
	material.shader = SHADER
	show_event({}, true)


## The domain's reading of the deck, cast at the boundary. Kindling and Soot
## have declared no way, so they burn plain whatever the shares say: Kindling
## "a small orange flame", Soot dust-brown (§5, §6).
func show_event(event: Dictionary, instant: bool = false) -> void:
	var tier: String = str(event.get("tier", "KINDLING"))
	var dominant: String = str(event.get("dominant", ""))
	var fringe: String = str(event.get("fringe", ""))
	var shares: Dictionary = event.get("shares", {})
	var want: Reading = Reading.new()
	want.stability = TIER_STABILITY.get(tier, TIER_STABILITY["KINDLING"])
	want.height = TIER_HEIGHT.get(tier, TIER_HEIGHT["KINDLING"])
	var declared: bool = (tier == "STEADY" or tier == "TRUE") and WAY_COLOUR.has(dominant)
	if declared:
		want.dominant = WAY_COLOUR[dominant]
		want.shape = WAY_SHAPE[dominant]
	else:
		want.dominant = SOOT_COLOUR if tier == "SOOT" else KINDLING_COLOUR
	want.fringe = want.dominant
	if declared and WAY_COLOUR.has(fringe):
		want.fringe = WAY_COLOUR[fringe]
		want.fringe_amount = fringe_amount_for(float(str(shares.get(fringe, FRINGE_FROM))))
	_retarget(want, instant)


## How strongly a second way's share shows at the tips: already plain at the
## threshold, where the lock says it starts to matter, and full by FRINGE_FULL.
static func fringe_amount_for(share: float) -> float:
	if share < FRINGE_FROM:
		return 0.0
	return lerpf(FRINGE_FLOOR, 1.0, clampf((share - FRINGE_FROM) / (FRINGE_FULL - FRINGE_FROM), 0.0, 1.0))


func set_look(look: Look) -> void:
	material.set_shader_parameter(&"look", int(look))


## The colour the lantern is burning this frame, for light it throws elsewhere
## (the HUD's glow behind the lantern).
func colour_now() -> Color:
	return _current().dominant


## Step the flame's clock and its tween by hand.
func advance(delta: float) -> void:
	clock += delta
	_elapsed = minf(_elapsed + delta, TWEEN_TIME)
	material.set_shader_parameter(&"clock", clock)
	_push(_current())


## Put the clock at `at` seconds and the running tween back at its start.
func seek(at: float) -> void:
	clock = at
	_elapsed = 0.0 if _elapsed < TWEEN_TIME else TWEEN_TIME
	material.set_shader_parameter(&"clock", clock)
	_push(_current())


func _process(delta: float) -> void:
	if not pinned:
		advance(delta)


## Start a tween from wherever the flame is now, so a reading that lands
## mid-tween turns the flame rather than restarting it. A fringe that appears
## takes its own colour from the start, and one that leaves keeps it.
func _retarget(want: Reading, instant: bool) -> void:
	var now: Reading = _current()
	if now.fringe_amount <= 0.0:
		now.fringe = want.fringe
	if want.fringe_amount <= 0.0:
		want.fringe = now.fringe
	_from = want if instant else now
	_to = want
	_elapsed = TWEEN_TIME if instant else 0.0
	_push(_current())


func _current() -> Reading:
	return _from.blend(_to, Motion.ease(Motion.EASE_IN_OUT, _elapsed / TWEEN_TIME))


func _push(r: Reading) -> void:
	material.set_shader_parameter(&"dominant_colour", r.dominant)
	material.set_shader_parameter(&"fringe_colour", r.fringe)
	material.set_shader_parameter(&"fringe_amount", r.fringe_amount)
	material.set_shader_parameter(&"stability", r.stability)
	material.set_shader_parameter(&"height", r.height)
	material.set_shader_parameter(&"shape_weights", r.shape)
