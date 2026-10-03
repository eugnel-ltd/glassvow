class_name TitleBeckon
extends Control
## "This is the button", without a word (build 18 play report: the owner kept
## tapping the plaque, not knowing the lantern was Continue). On the first
## title of a session the flame breathes brighter twice and the plaque's gold
## brightens with it; on any title, after IDLE seconds with no input, a single
## ember rises from the flame to the plaque. Draw-only and input-blind: the
## lantern and the plaque are one button already (TitleScreen's reach).

const PULSES: int = 2
## One brighter breath, up and back, in seconds.
const PULSE: float = 0.9
const PULSE_PEAK: float = 0.85
const IDLE: float = 6.0
const RISE: float = 1.7

var lantern: LeadlightLantern
var plaque: LeadlightPlaque
var _armed: bool = false
var _idle: float = 0.0
var _fired: bool = false
## Rise progress 0..1; below 0 when no ember is in the air.
var _rise: float = -1.0
## Time into the beckon's breaths; below 0 when not beckoning.
var _pulse: float = -1.0
## Time into the plaque's glint as the ember arrives; below 0 when none.
var _glint: float = -1.0


func _init(the_lantern: LeadlightLantern, the_plaque: LeadlightPlaque) -> void:
	name = "TitleBeckon"
	lantern = the_lantern
	plaque = the_plaque
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## The two brighter breaths. Brightness only, no movement, so it stays under
## Reduce Motion: it is the flame's own light.
func pulse() -> void:
	_pulse = 0.0


func beckoning() -> bool:
	return _pulse >= 0.0


## Start counting idleness (the title is lit and taking input).
func arm() -> void:
	_armed = true
	_idle = 0.0
	_fired = false


## Held while a room is open (docs/design/2026-10-03-title-rooms §7 item 10):
## nothing beckons and nothing counts until `arm` again, so no ember flies to
## the plaque a second after a room closes.
func hold() -> void:
	_armed = false
	_fired = false
	_idle = 0.0
	if _pulse >= 0.0 or _glint >= 0.0:
		_shine(0.0)
	_pulse = -1.0
	_rise = -1.0
	_glint = -1.0
	queue_redraw()


## Any input: the player is here. The next ember waits for the next idle spell.
func touched() -> void:
	_idle = 0.0
	_fired = false


## True while an ember is rising (for stills and tests).
func rising() -> bool:
	return _rise >= 0.0


func _shine(amount: float) -> void:
	if lantern != null:
		lantern.flare = amount
	if plaque != null:
		plaque.glow = amount


func _process(delta: float) -> void:
	if _pulse >= 0.0:
		_pulse += delta
		if _pulse >= PULSE * float(PULSES):
			_pulse = -1.0
			_shine(0.0)
		else:
			# Each breath: up and back, a sine squared, so it starts and ends dark.
			_shine(PULSE_PEAK * pow(sin(fmod(_pulse, PULSE) / PULSE * PI), 2.0))
	if _glint >= 0.0:
		_glint += delta
		var span: float = LeadlightMotion.QUICK + LeadlightMotion.CEREMONY
		if _glint >= span:
			_glint = -1.0
			plaque.glow = 0.0
		elif _glint < LeadlightMotion.QUICK:
			plaque.glow = 0.7 * _glint / LeadlightMotion.QUICK
		else:
			plaque.glow = 0.7 * (1.0 - (_glint - LeadlightMotion.QUICK) / LeadlightMotion.CEREMONY)
	if not _armed:
		return
	_idle += delta
	if _idle >= IDLE and not _fired:
		_fired = true
		# Reduce Motion: no rising ember; the plaque brightens once in place.
		if LeadlightMotion.reduced():
			_glint = 0.0
		else:
			_rise = 0.0
		# It leaves the wick this frame and starts climbing on the next.
		queue_redraw()
		return
	if _rise >= 0.0:
		_rise += delta / RISE
		if _rise >= 1.0:
			_rise = -1.0
			_glint = 0.0
		queue_redraw()


func _draw() -> void:
	if _rise < 0.0 or lantern == null or plaque == null:
		return
	var from: Vector2 = lantern.position + lantern.wick()
	var to: Vector2 = plaque.position + Vector2(plaque.size.x * 0.5, plaque.size.y * 0.92)
	var t: float = LeadlightMotion.ease_on(_rise, LeadlightMotion.SETTLE_OUT)
	var at: Vector2 = from.lerp(to, t) + Vector2(sin(_rise * TAU * 1.5) * 6.0 * (1.0 - t), 0.0)
	var alpha: float = sin(_rise * PI)
	var colour: Color = lantern.light()
	var r: float = 7.0 + 3.0 * (1.0 - t)
	draw_texture_rect(SkyField.disc(), Rect2(at - Vector2(r, r) * 3.0, Vector2(r, r) * 6.0), false,
		Color(colour, 0.5 * alpha))
	# The ember itself: a small flame, point up.
	var flame: PackedVector2Array = PackedVector2Array()
	for i: int in 13:
		var a: float = float(i) / 12.0 * TAU
		var up: float = maxf(0.0, cos(a))
		flame.append(at + Vector2(sin(a) * r * (1.0 - up * 0.55), -cos(a) * r - up * r * 0.9))
	draw_colored_polygon(flame, Color(colour.lerp(Color.WHITE, 0.45), alpha))
