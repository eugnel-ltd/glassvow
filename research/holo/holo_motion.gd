class_name HoloMotion
extends Node
## Research (#657 holo, never shipped): the one motion signal every holo
## reads, -1..1 on both axes.
##
## On a phone or pad it fuses the device's GRAVITY (OS-fused, hand shake
## already gone) with its GYROSCOPE:
##
##   * gravity gives the lean about the two axes it can see, measured against
##     the player's own resting hold (the first reading is the neutral, and the
##     neutral leaks toward the current hold, so a player who leans back gets
##     the foil centred again within seconds);
##   * a twist ABOUT gravity (an upright phone turned left-right) is invisible
##     to gravity, so the gyroscope's rate about the gravity axis is integrated
##     into a "twist" rotation that leaks back to zero on the same slow
##     re-centre, and is clamped to the same budget;
##   * no gyroscope (a zero rate, or a device without one) simply leaves the
##     twist at zero: gravity alone still works.
##
## Without a gravity sensor (desktop, or a device that reports zero) it falls
## back to the pointer over the window. Reduce Motion holds a still pose.
##
## The card is fixed to the screen, so a device tilt does not tilt the slab:
## it changes the angle to the room's light, which is exactly and only what
## the holo layer draws. The 3D stages therefore stay frozen; only canvas
## uniforms move.
##
## Android: production must set input_devices/sensors/enable_gravity and
## enable_gyroscope to true (both default false since 4.4). iOS reads them
## regardless.

const FULL_SCALE_DEG: float = 16.0   # a 16 degree lean from neutral is full throw
const DEADZONE_DEG: float = 0.6
const SMOOTH_TAU: float = 0.09       # seconds, low-pass on the reading
const RECENTRE_TAU: float = 6.0      # seconds, neutral and twist leak home
const SENSOR_FLOOR: float = 1.0      # m/s^2: below this there is no gravity sensor
const GYRO_MAX: float = 12.0         # rad/s: anything faster is a glitch, clamped
## Reduce Motion: the holo holds still at one flattering pose, so a tier still
## reads at a glance; nothing moves, nothing runs on time.
const STILL_POSE: Vector2 = Vector2(0.35, -0.25)

var tilt: Vector2 = Vector2.ZERO
var source: String = "none"
var raw: Vector3 = Vector3.ZERO
var gyro: Vector3 = Vector3.ZERO
var reduce_motion: bool = false
## Device check only: no calibration, the neutral is the screen lying flat.
var absolute: bool = false
## Screen-axis signs, flipped on a device check if a lean reads backwards.
var axis_sign: Vector2 = Vector2(1.0, 1.0)

var _neutral3: Vector3 = Vector3(0.0, 0.0, -1.0)
var _have_neutral: bool = false
var _twist: float = 0.0              # radians about the neutral gravity axis


func _process(delta: float) -> void:
	raw = Input.get_gravity()
	gyro = Input.get_gyroscope()
	if reduce_motion:
		source = "reduce-motion"
		tilt = STILL_POSE
		return
	var goal: Vector2
	if raw.length() > SENSOR_FLOOR:
		source = "gravity+gyro" if gyro.length() > 0.0 else "gravity"
		goal = step(raw, gyro, minf(delta, 0.1))
	else:
		source = "pointer"
		goal = _from_pointer()
	tilt += (goal - tilt) * (1.0 - exp(-minf(delta, 0.1) / SMOOTH_TAU))


## One sensor step, pure apart from this node's own state, so a script can
## drive it with synthetic readings. Returns the shaped lean, -1..1.
func step(g: Vector3, w: Vector3, dt: float) -> Vector2:
	var n: Vector3 = g.normalized()
	var k: float = 1.0 - exp(-dt / RECENTRE_TAU)
	if absolute:
		_neutral3 = Vector3(0.0, 0.0, -1.0)
	else:
		if not _have_neutral:
			_neutral3 = n
			_have_neutral = true
		_neutral3 = (_neutral3 + (n - _neutral3) * k).normalized()
	# The device's rotation that gravity can see: the small rotation carrying
	# the current gravity direction back to the neutral one.
	var r: Vector3 = n.cross(_neutral3)
	# The twist gravity cannot see: the gyro's rate about the gravity axis,
	# integrated, leaking home, clamped to the budget.
	var rate: Vector3 = w.limit_length(GYRO_MAX) if w.is_finite() else Vector3.ZERO
	_twist += rate.dot(n) * dt
	_twist -= _twist * k
	_twist = clampf(_twist, -deg_to_rad(FULL_SCALE_DEG), deg_to_rad(FULL_SCALE_DEG))
	r += n * sin(_twist)
	var d: Vector2 = Vector2(rad_to_deg(asin(clampf(r.y, -1.0, 1.0))),
		rad_to_deg(asin(clampf(r.x, -1.0, 1.0))))
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


## Forget the neutral and the twist: the next reading is home (a screen entry).
func recentre() -> void:
	_have_neutral = false
	_twist = 0.0
