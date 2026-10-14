class_name HoloMotion
extends Node
## Research (#657 holo, never shipped): the one motion signal every holo
## reads, -1..1 on both axes.
##
## On a phone or pad it is the device's GRAVITY (OS-fused, so hand shake is
## already gone), measured against the player's own resting hold: the first
## reading is the neutral, and the neutral leaks toward the current hold with
## a slow time constant, so a player who leans back on the sofa gets the foil
## centred again within seconds instead of pinned at one edge. Without a
## sensor (desktop, or a device that reports zero) it falls back to the
## pointer over the window. Reduce Motion holds it at rest.
##
## The card is fixed to the screen, so a device tilt does not tilt the slab:
## it changes the angle to the room's light, which is exactly and only what
## the holo layer draws. The 3D stages therefore stay frozen; only canvas
## uniforms move.

const FULL_SCALE_DEG: float = 16.0   # a 16 degree lean from neutral is full throw
const DEADZONE_DEG: float = 0.6
const SMOOTH_TAU: float = 0.09       # seconds, low-pass on the reading
const RECENTRE_TAU: float = 6.0      # seconds, neutral leaks toward the hold
const SENSOR_FLOOR: float = 1.0      # m/s^2: below this there is no gravity sensor
## Reduce Motion: the holo holds still at one flattering pose, so a tier still
## reads at a glance; nothing moves, nothing runs on time.
const STILL_POSE: Vector2 = Vector2(0.35, -0.25)

var tilt: Vector2 = Vector2.ZERO
var source: String = "none"
var raw: Vector3 = Vector3.ZERO
var reduce_motion: bool = false
## Device check only: no calibration, the neutral is the screen lying flat,
## so a device resting on a stand shows its stand angle as a lean.
var absolute: bool = false
## Gravity axes into screen axes; flipped on the device check if a lean reads
## the wrong way round. Godot already rotates gravity into the interface
## orientation on iOS and Android.
var axis_sign: Vector2 = Vector2(1.0, 1.0)

var _neutral: Vector2 = Vector2.ZERO
var _have_neutral: bool = false


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	var goal: Vector2 = Vector2.ZERO
	raw = Input.get_gravity()
	if reduce_motion:
		source = "reduce-motion"
		tilt = STILL_POSE
		return
	elif raw.length() > SENSOR_FLOOR:
		source = "gravity"
		goal = _from_gravity(raw, dt)
	else:
		source = "pointer"
		goal = _from_pointer()
	tilt += (goal - tilt) * (1.0 - exp(-dt / SMOOTH_TAU))


func _from_gravity(g: Vector3, dt: float) -> Vector2:
	var n: Vector3 = g.normalized()
	var ang: Vector2 = Vector2(rad_to_deg(asin(clampf(n.x, -1.0, 1.0))),
		rad_to_deg(asin(clampf(n.y, -1.0, 1.0))))
	if absolute:
		_neutral = Vector2.ZERO
	else:
		if not _have_neutral:
			_neutral = ang
			_have_neutral = true
		_neutral += (ang - _neutral) * (1.0 - exp(-dt / RECENTRE_TAU))
	var d: Vector2 = ang - _neutral
	var out: Vector2 = Vector2.ZERO
	for i: int in range(2):
		var v: float = d[i]
		var mag: float = maxf(0.0, absf(v) - DEADZONE_DEG)
		out[i] = signf(v) * tanh(mag / FULL_SCALE_DEG * 1.3) * axis_sign[i]
	return out


func _from_pointer() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ZERO
	var r: Rect2 = vp.get_visible_rect()
	var m: Vector2 = vp.get_mouse_position()
	if not r.has_point(m):
		return Vector2.ZERO
	var c: Vector2 = (m - r.get_center()) / (r.size * 0.5)
	return c.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))


## Forget the neutral: the next reading becomes it (a screen entry).
func recentre() -> void:
	_have_neutral = false
