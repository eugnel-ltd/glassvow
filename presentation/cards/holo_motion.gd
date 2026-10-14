class_name HoloMotion
extends RefCounted
## THE ONE MOTION SIGNAL every card hologram reads (#657): -1..1 on both axes,
## x leaning right and y toward the player, in the convention of the card's own
## tilt (`CardView.hold_pose`), so a device lean and a held card's lean add.
##
## The card is fixed to the screen, so a device tilt does not tilt the slab:
## it changes the card's angle to the room's light, which is exactly and only
## what the hologram draws. The 3D stages stay frozen; one canvas uniform per
## card moves (CardHolo).
##
## SOURCES, in order:
##   Reduce Motion  one fixed, flattering pose (STILL_POSE): a tier still reads
##                  at a glance; nothing moves and nothing runs on time.
##   gravity        a phone or pad (Input.get_gravity, OS-fused, hand shake
##                  already gone), fused with the gyroscope for the twist that
##                  gravity cannot see (an upright device turned left-right).
##                  A missing or non-finite gyroscope leaves the twist at zero.
##   pointer        desktop: the pointer over the window, at POINTER_GAIN, a
##                  room light drifting; the hovered card adds its own tilt.
##   none           touch with no sensor: neutral; the held card's own tilt is
##                  all that moves.
##
## THE SIGNAL PATH (step): the first reading on a screen entry is the neutral,
## so the player's own resting hold is "flat", and the neutral leaks toward the
## current hold with RECENTRE_TAU, so a player who leans back on the sofa gets
## the foil centred again within seconds. The lean is the small rotation that
## carries the neutral gravity direction to the current one (it works lying
## flat, propped or upright), plus the gyroscope's integrated twist about
## gravity, which leaks home on the same re-centre. A DEADZONE_DEG deadzone,
## then a soft clamp, tanh(1.3 * lean / FULL_SCALE_DEG): a 16 degree lean is
## nearly full throw, inside the card's own angular budget however small the
## slab's own tilt. Last, a low-pass at SMOOTH_TAU.
##
## SENSORS ARE READ ONLY WHILE A CARD IS ON SCREEN: the shared signal (`ambient`)
## is stepped by the cards' own drivers (CardHolo.Lean), once a frame, and only
## from a card that is visible. A frame with none leaves the sensors unread; the
## next one is a screen entry and re-centres.
##
## AXES. Godot rotates iOS readings into the interface's frame only when it can
## read the window scene's orientation; on the iPad 8 under 4.7 it reports the
## device's portrait axes: upright in landscape on its stand, the iPad 8 reads
## gravity (9.80, 0.07, 0.21), along +x, not -y (QA build, 14 Oct 2026), which
## `to_screen` maps to (0.07, -9.80, 0.21), straight down the screen.
## `to_screen` turns those into the screen's axes (x right, y up, z out of the
## glass), picking the landscape from the side gravity falls to. Android
## (input_devices/sensors/enable_gravity and enable_gyroscope, both on in
## project.godot) already reports in the screen's frame.

const FULL_SCALE_DEG: float = 16.0   # a 16 degree lean from neutral is full throw
const DEADZONE_DEG: float = 0.6
const SMOOTH_TAU: float = 0.09       # seconds, low-pass on the reading
const RECENTRE_TAU: float = 6.0      # seconds, neutral and twist leak home
const SENSOR_FLOOR: float = 1.0      # m/s^2: below this there is no gravity sensor
const GYRO_MAX: float = 12.0         # rad/s: anything faster is a glitch, clamped
const POINTER_GAIN: float = 0.5
## Reduce Motion: the hologram holds still at one flattering pose.
const STILL_POSE: Vector2 = Vector2(0.35, -0.25)
## A gravity reading this far (as a share of its length) along the device's
## long axis tells which way round a landscape device is held.
const LANDSCAPE_TELL: float = 0.35

enum Source { STILL, SENSOR, POINTER, NONE }

## The shaped, smoothed signal: -1..1 on both axes.
var tilt: Vector2 = Vector2.ZERO
var source: Source = Source.NONE

var _neutral: Vector3 = Vector3(0.0, 0.0, -1.0)
var _have_neutral: bool = false
var _twist: float = 0.0              # radians about the gravity axis
## Which landscape a device reporting portrait axes is in: +1 when gravity
## falls toward its +x (upright, as the iPad 8 stands), -1 the other way round.
var _down_x: float = 1.0

## The signal every card on screen shares, stepped once a frame (`ambient`).
static var _shared: HoloMotion = null
static var _stepped: int = -2
## GLASSVOW_HOLO="x,y": hold the signal there, for a scripted capture.
static var _forced: Variant = null


## One frame of readings, already in the screen's frame. `pointer` is the
## pointer over the window, -1..1, when there is one to read.
func update(g: Vector3, w: Vector3, pointer: Variant, still: bool, dt: float) -> Vector2:
	if still:
		source = Source.STILL
		tilt = STILL_POSE
		return tilt
	var goal: Vector2 = Vector2.ZERO
	if g.is_finite() and g.length() > SENSOR_FLOOR:
		source = Source.SENSOR
		goal = step(g, w, dt)
	elif pointer is Vector2:
		source = Source.POINTER
		var at: Vector2 = pointer
		goal = at.clamp(-Vector2.ONE, Vector2.ONE) * POINTER_GAIN
	else:
		source = Source.NONE
	tilt += (goal - tilt) * (1.0 - exp(-minf(dt, 0.1) / SMOOTH_TAU))
	return tilt


## One sensor step on this signal's own calibration: gravity `g` and the
## gyroscope's rate `w` in the screen's frame. Returns the shaped lean, before
## the low-pass.
func step(g: Vector3, w: Vector3, dt: float) -> Vector2:
	var n: Vector3 = g.normalized()
	var k: float = 1.0 - exp(-minf(dt, 0.1) / RECENTRE_TAU)
	if not _have_neutral:
		_neutral = n
		_have_neutral = true
	_neutral = (_neutral + (n - _neutral) * k).normalized()
	# The rotation gravity can see: the small rotation carrying the current
	# gravity direction back to the neutral one, as a rotation vector.
	var r: Vector3 = n.cross(_neutral)
	# The twist gravity cannot see: the gyroscope's rate about the gravity
	# axis, integrated, leaking home, clamped to the budget.
	var rate: Vector3 = w.limit_length(GYRO_MAX) if w.is_finite() else Vector3.ZERO
	var budget: float = deg_to_rad(FULL_SCALE_DEG)
	_twist = clampf(_twist + rate.dot(n) * dt - _twist * k, -budget, budget)
	r += n * sin(_twist)
	# A device turned by an angle about the screen's y axis is the card's own
	# slab turned by it, which hold_pose writes as -x (rotation_degrees.y is
	# -n.x * MAX_TILT); about x, as -y.
	var d: Vector2 = -Vector2(rad_to_deg(asin(clampf(r.y, -1.0, 1.0))),
		rad_to_deg(asin(clampf(r.x, -1.0, 1.0))))
	var out: Vector2 = Vector2.ZERO
	for i: int in range(2):
		var mag: float = maxf(0.0, absf(d[i]) - DEADZONE_DEG)
		out[i] = signf(d[i]) * tanh(mag / FULL_SCALE_DEG * 1.3)
	return out


## Forget the neutral and the twist: the next reading is home.
func recentre() -> void:
	_have_neutral = false
	_twist = 0.0


## `v` in the device's portrait axes as the screen's (x right, y up, z out of
## the glass), for a landscape device held with gravity falling toward its
## +x (`down_x` +1) or its -x (-1).
static func to_screen(v: Vector3, down_x: float) -> Vector3:
	return Vector3(down_x * v.y, -down_x * v.x, v.z)


## Which landscape a portrait-axes gravity reading says the device is in, or
## `was` while it lies too flat to tell.
static func landscape_of(g: Vector3, was: float) -> float:
	if absf(g.x) > LANDSCAPE_TELL * g.length():
		return signf(g.x)
	return was


## A card's hologram tilt: the shared signal plus the card's own lean (a held
## or settling card's spring tilt), clamped; under Reduce Motion, the still
## pose alone.
static func lean_of(ambient_tilt: Vector2, own: Vector2, still: bool) -> Vector2:
	if still:
		return STILL_POSE
	return (ambient_tilt + own).clamp(-Vector2.ONE, Vector2.ONE)


## Whether Reduce Motion is on.
static func still() -> bool:
	return Preferences.active != null and Preferences.active.reduce_motion


## The shared signal for this frame, stepped by the first card that asks.
## A frame after one with no card on screen is a screen entry: it starts from
## a fresh neutral.
static func ambient(vp: Viewport, dt: float) -> Vector2:
	var frame: int = Engine.get_process_frames()
	if _shared != null and frame == _stepped:
		return _shared.tilt
	if _shared == null:
		_shared = HoloMotion.new()
	if frame > _stepped + 1:
		_shared.recentre()
		_shared.tilt = Vector2.ZERO
	_stepped = frame
	if _forced == null:
		_forced = _read_forced()
	if _forced is Vector2:
		_shared.tilt = _forced
		return _shared.tilt
	var g: Vector3 = Input.get_gravity()
	var w: Vector3 = Input.get_gyroscope()
	if OS.get_name() == "iOS":
		_shared._down_x = landscape_of(g, _shared._down_x)
		g = to_screen(g, _shared._down_x)
		w = to_screen(w, _shared._down_x)
	return _shared.update(g, w, _pointer(vp), still(), dt)


## Hold the shared signal at `t` (a scripted capture's three tilts), or let it
## go with null, back to the sensors (GLASSVOW_HOLO holds it from the launch).
static func hold(t: Variant) -> void:
	_forced = t if t is Vector2 else false


## The pointer over the window, -1..1, or null on a touch screen or with the
## pointer outside it.
static func _pointer(vp: Viewport) -> Variant:
	if vp == null or DisplayServer.is_touchscreen_available():
		return null
	var r: Rect2 = vp.get_visible_rect()
	var m: Vector2 = vp.get_mouse_position()
	if not r.has_point(m):
		return null
	return (m - r.get_center()) / (r.size * 0.5)


static func _read_forced() -> Variant:
	var held: PackedStringArray = OS.get_environment("GLASSVOW_HOLO").split(",")
	if held.size() == 2:
		return Vector2(float(held[0]), float(held[1]))
	return false
