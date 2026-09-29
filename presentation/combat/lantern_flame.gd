class_name LanternFlame
extends Node
## The Flame, drawn in the Duskblade's lantern (design lock §9, issue #577).
##
## Presentation is handed the lantern's reading and never computes purity:
## `show_event()` takes an `EventTypes.FLAME` event exactly as the domain emits
## it and turns it into the inputs of `lantern_flame.gdshader`. Every input then
## moves over about a second on one ease, so a pick that changes the flame is
## SEEN changing, and a reading that lands mid-tween turns the flame from where
## it is: nothing snaps. `light()` puts the flame on a lantern: the material on
## its art, and the glow behind it re-lit in the light the flame throws.
##
## The clock is the shader's own rather than TIME: `pinned` stops it, so a still
## is the same still every time it is taken, and `advance()` steps it by hand.

const SHADER: Shader = preload("res://presentation/combat/lantern_flame.gdshader")

## About a second, on the stylesheet's ease-in-out: long enough to be watched
## after a pick, over before the next one.
const TWEEN_TIME: float = 1.0

## The flame's colours, keyed by what it burns: a way's id once the flame has
## declared one (lock §6), and its tier while it has not (§5). Content carries
## the ids; the colours are presentation's alone, and for approval on device.
const COLOUR: Dictionary[String, Color] = {
	"shatter": Color("#8fd0ff"),  # 碎 霜焰 Frostlight, blue-white: the facet blue
	"lantern": Color("#f2c14e"),  # 燼 熾焰 Hearthfire, amber-gold: the lantern gold
	"edge": Color("#9c2fa6"),     # 蝕 蝕焰 Eclipse, violet-crimson
	Flame.TIER_KINDLING: Color("#e8702a"),  # 燃 a small orange flame
	Flame.TIER_SOOT: Color("#8a6e52"),      # 塵 dust-brown
}
## The light a lantern throws on the chrome behind it while it burns as
## painted: the HUD's own amber glow, so Kindling's firelight is the lantern's
## firelight as it always was.
const PAINTED_LIGHT: Color = Color(1.0, 0.71, 0.35)
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
	Flame.TIER_SOOT: 0.0, Flame.TIER_KINDLING: 0.40, Flame.TIER_STEADY: 0.85,
	Flame.TIER_TRUE: 1.0,
}
const TIER_HEIGHT: Dictionary[String, float] = {
	Flame.TIER_SOOT: 0.46, Flame.TIER_KINDLING: 0.55, Flame.TIER_STEADY: 0.80,
	Flame.TIER_TRUE: 1.0,
}
## Kindling is today's game (lock §5): its lantern burns as painted. Every
## other tier has a reading of its own, and relights the glass to show it.
const TIER_PAINTED: Dictionary[String, float] = {Flame.TIER_KINDLING: 1.0}
## A fringe shows from `fringeMin` (0.25 for the Duskblade), already plain at
## FRINGE_FLOOR, and is at full strength by 0.40, the most a Steady flame's
## second way can hold.
const FRINGE_FROM: float = 0.25
const FRINGE_FULL: float = 0.40
const FRINGE_FLOOR: float = 0.55

## The HUD's glow falloff, drawn white so it can take the flame's light.
static var _falloff: Texture2D = null


## Everything the shader is told, as one value that can be blended.
class Reading:
	var dominant: Color = Color.BLACK
	var fringe: Color = Color.BLACK
	var fringe_amount: float = 0.0
	var stability: float = 0.0
	var height: float = 0.0
	var shape: Vector4 = PLAIN_SHAPE
	var painted: float = 0.0

	func blend(to: Reading, t: float) -> Reading:
		var out: Reading = Reading.new()
		out.dominant = dominant.lerp(to.dominant, t)
		out.fringe = fringe.lerp(to.fringe, t)
		out.fringe_amount = lerpf(fringe_amount, to.fringe_amount, t)
		out.stability = lerpf(stability, to.stability, t)
		out.height = lerpf(height, to.height, t)
		out.shape = shape.lerp(to.shape, t)
		out.painted = lerpf(painted, to.painted, t)
		return out

	## The light this flame throws past the iron.
	func light() -> Color:
		return dominant.lerp(PAINTED_LIGHT, painted)


var material: ShaderMaterial = ShaderMaterial.new()
## True stops the clock and the tween; `advance()` still steps both.
var pinned: bool = false
var clock: float = 0.0

var _from: Reading = Reading.new()
var _to: Reading = Reading.new()
var _elapsed: float = TWEEN_TIME
var _glow: CanvasItem = null


## A flame that has heard nothing yet burns as Kindling, the run's start.
func _init() -> void:
	material.shader = SHADER
	show_event({}, true)


## Put this flame on a lantern: the material on its art, and the glow behind
## it (optional) re-lit in the flame's light. The glow's texture becomes the
## same falloff drawn white, so it can take any colour the flame throws.
func light(art: CanvasItem, glow: TextureRect = null) -> void:
	art.material = material
	_glow = glow
	if glow != null:
		glow.texture = falloff()
	_push(_current())


## The domain's reading of the deck, cast at the boundary. Kindling and Soot
## have declared no way, so they burn plain whatever the shares say: Kindling
## as the lantern is painted, Soot dust-brown (§5, §6).
func show_event(event: Dictionary, instant: bool = false) -> void:
	var tier: String = str(event.get("tier", Flame.TIER_KINDLING))
	if not TIER_STABILITY.has(tier):
		tier = Flame.TIER_KINDLING
	var dominant: String = str(event.get("dominant", ""))
	var fringe: String = str(event.get("fringe", ""))
	var shares_v: Variant = event.get("shares", {})
	var shares: Dictionary = shares_v if typeof(shares_v) == TYPE_DICTIONARY else {}
	var want: Reading = Reading.new()
	want.stability = TIER_STABILITY[tier]
	want.height = TIER_HEIGHT[tier]
	want.painted = TIER_PAINTED.get(tier, 0.0)
	var declared: bool = (tier == Flame.TIER_STEADY or tier == Flame.TIER_TRUE) \
		and WAY_SHAPE.has(dominant) and COLOUR.has(dominant)
	if declared:
		want.dominant = COLOUR[dominant]
		want.shape = WAY_SHAPE[dominant]
	else:
		want.dominant = COLOUR[Flame.TIER_SOOT if tier == Flame.TIER_SOOT else Flame.TIER_KINDLING]
	want.fringe = want.dominant
	if declared and WAY_SHAPE.has(fringe) and COLOUR.has(fringe):
		want.fringe = COLOUR[fringe]
		want.fringe_amount = fringe_amount_for(float(str(shares.get(fringe, FRINGE_FROM))))
	_retarget(want, instant)


## How strongly a second way's share shows at the tips: already plain at the
## threshold, where the lock says it starts to matter, and full by FRINGE_FULL.
static func fringe_amount_for(share: float) -> float:
	if share < FRINGE_FROM:
		return 0.0
	return lerpf(FRINGE_FLOOR, 1.0, clampf((share - FRINGE_FROM) / (FRINGE_FULL - FRINGE_FROM), 0.0, 1.0))


## The HUD's glow falloff drawn white, made once per process.
static func falloff() -> Texture2D:
	if _falloff == null:
		_falloff = GlassStyle.grad_tex(
			PackedColorArray([Color(1.0, 1.0, 1.0, 0.30), Color(1.0, 1.0, 1.0, 0.0)]),
			PackedFloat32Array([0.0, 1.0]), true, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	return _falloff


## The light the lantern throws this frame, tween and all.
func light_now() -> Color:
	return _current().light()


## Whether a reading is still arriving.
func tweening() -> bool:
	return _elapsed < TWEEN_TIME


## Step the flame's clock and its tween by hand. The reading is only pushed
## while it moves; at rest the clock is the one input that changes.
func advance(delta: float) -> void:
	clock += delta
	material.set_shader_parameter(&"clock", clock)
	if tweening():
		_elapsed = minf(_elapsed + delta, TWEEN_TIME)
		_push(_current())


## Put the clock at `at` seconds and a running tween back at its start.
func seek(at: float) -> void:
	clock = at
	_elapsed = 0.0 if tweening() else TWEEN_TIME
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
	material.set_shader_parameter(&"painted", r.painted)
	if _glow != null and is_instance_valid(_glow):
		_glow.self_modulate = r.light()
