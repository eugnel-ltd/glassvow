class_name SceneFx
extends Control
## Effects for scripted scenes, drawn in one pass on one canvas. The world is
## glass, so the vocabulary is glass: a blow cracks the frame, a shatter
## throws jewel-toned shards with their leading still on, a kindle carries
## sparks from one hand to another, light arrives as rays through a window.
##
## Two instances stand in a scene: an ambient layer behind the portraits
## (embers, ash, motes, glass snow) and a front layer between the portraits
## and the dialogue pane — so text is never painted over.
##
## Every effect is transient; resume and capture never replay them. Reduced
## motion keeps flashes soft and long, stills the ambience, and drops shake,
## cracks, shards, slashes and rays outright (the title's Reduce Motion rule).
## Shake additionally honours the player's screen-shake preference.

const FLASH_COLOURS: Dictionary[StringName, Color] = {
	&"flash": Color(1.0, 0.95, 0.84),
	&"flash-ember": Color(1.0, 0.62, 0.28),
	&"flash-cold": Color(0.66, 0.82, 1.0),
	&"flash-blood": Color(0.70, 0.07, 0.10),
}
const SHARD_COLOURS: Array[Color] = [
	Color(0.95, 0.64, 0.26), Color(0.20, 0.58, 0.60), Color(0.46, 0.34, 0.72),
	Color(0.72, 0.20, 0.26), Color(0.82, 0.86, 0.90), Color(0.18, 0.34, 0.66),
]
const LEAD: Color = Color(0.02, 0.018, 0.028, 0.88)
const CRACK_EDGE: Color = Color(0.86, 0.93, 1.0, 0.78)
const REDUCED_FLASH_PEAK: float = 0.25
const CRACK_LIFE: float = 2.6
const GRAVITY: float = 980.0

class Crack:
	var segs: PackedVector2Array = PackedVector2Array()
	var dists: PackedFloat32Array = PackedFloat32Array()
	var reach: float = 0.0
	var t: float = 0.0


class Shard:
	var pos: Vector2
	var vel: Vector2
	var rot: float = 0.0
	var spin: float = 0.0
	var pts: PackedVector2Array
	var colour: Color
	var t: float = 0.0


class Spark:
	var from: Vector2
	var to: Vector2
	var lift: float = 0.0
	var delay: float = 0.0
	var radius: float = 2.0
	var t: float = 0.0


class Streak:
	var a: Vector2
	var b: Vector2
	var spin: float = 0.0
	var t: float = 0.0


class Mote:
	var pos: Vector2
	var radius: float = 1.0
	var phase: float = 0.0
	var speed: float = 1.0
	var hue: int = 0


var reduce_motion: bool = false
var allow_shake: bool = true
var shake_targets: Array[Control] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0
var _view: Vector2 = Vector2.ZERO
var _disc: Texture2D
var _flash_colour: Color = Color.WHITE
var _flash_a: float = 0.0
var _flash_fade: float = 1.0
var _shake_amp: float = 0.0
var _shake_t: float = 0.0
var _shake_dur: float = 0.0
var _pulse: float = 0.0
var _cracks: Array[Crack] = []
var _shards: Array[Shard] = []
var _sparks: Array[Spark] = []
var _slashes: Array[Streak] = []
var _rays: Array[Streak] = []
var _rings: Array[Streak] = []
var _ambient: StringName = &"none"
var _motes: Array[Mote] = []


func _init(layer_name: String = "SceneFx") -> void:
	name = layer_name
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc = GlassStyle.disc(Color.WHITE, 1.0, 32)


func reseed(value: int) -> void:
	_rng.seed = value


func set_view(view: Vector2) -> void:
	var was: Vector2 = _view
	_view = view
	if was != view and _ambient != &"none":
		_spawn_ambient()


## Persistent weather for the beat. Re-seeding the same kind keeps its motes.
func set_ambient(kind: StringName) -> void:
	if kind == _ambient:
		return
	_ambient = kind
	_spawn_ambient()


func ambient() -> StringName:
	return _ambient


func active() -> bool:
	return _flash_a > 0.0 or _shake_t < _shake_dur or not _cracks.is_empty() \
		or not _shards.is_empty() or not _sparks.is_empty() \
		or not _slashes.is_empty() or not _rays.is_empty() \
		or not _rings.is_empty() or _pulse > 0.0


## Fire one named effect. `at` is a stage-space focus (impact point, ray
## source); `to` is a kindle's destination.
func play(fx: StringName, at: Vector2 = Vector2(-1, -1), to: Vector2 = Vector2(-1, -1)) -> void:
	var view: Vector2 = _stage()
	var centre: Vector2 = at if at.x >= 0.0 else Vector2(view.x * 0.5, view.y * 0.42)
	match fx:
		&"flash", &"flash-ember", &"flash-cold", &"flash-blood":
			flash(FLASH_COLOURS[fx], 0.85, 0.55)
		&"shake":
			shake(9.0, 0.35)
		&"quake":
			shake(16.0, 0.95)
		&"impact":
			flash(FLASH_COLOURS[&"flash"], 0.7, 0.35)
			shake(14.0, 0.32)
			_ring(centre)
		&"slash":
			_slash(view)
			flash(FLASH_COLOURS[&"flash"], 0.35, 0.25)
			shake(7.0, 0.22)
		&"crack":
			_crack(centre)
			shake(6.0, 0.2)
		&"shatter":
			_shatter(centre)
			flash(FLASH_COLOURS[&"flash-cold"], 0.45, 0.4)
			shake(10.0, 0.4)
		&"kindle":
			_kindle(centre, to if to.x >= 0.0 else Vector2(view.x * 0.25, view.y * 0.55))
			flash(FLASH_COLOURS[&"flash-ember"], 0.28, 0.6)
		&"rays":
			_ray_burst(at if at.x >= 0.0 else Vector2(view.x * 0.5, -view.y * 0.1))
		&"pulse":
			_pulse = 1.0


func flash(colour: Color, peak: float, duration: float) -> void:
	_flash_colour = colour
	if reduce_motion:
		peak = minf(peak, REDUCED_FLASH_PEAK)
		duration = maxf(duration, 0.6)
	_flash_a = maxf(_flash_a, peak)
	_flash_fade = peak / maxf(duration, 0.05)


func shake(amplitude: float, duration: float) -> void:
	if reduce_motion or not allow_shake:
		return
	_shake_amp = maxf(amplitude, _shake_amp if _shake_t < _shake_dur else 0.0)
	_shake_dur = duration
	_shake_t = 0.0


## Drop everything in flight — a beat change or a skip.
func clear() -> void:
	_flash_a = 0.0
	_pulse = 0.0
	_cracks.clear()
	_shards.clear()
	_sparks.clear()
	_slashes.clear()
	_rays.clear()
	_rings.clear()
	_end_shake()


func tick(delta: float) -> void:
	_clock += delta
	var view: Vector2 = _stage()
	_flash_a = maxf(0.0, _flash_a - _flash_fade * delta)
	_pulse = maxf(0.0, _pulse - delta * 1.4)
	if _shake_t < _shake_dur:
		_shake_t += delta
		var u: float = clampf(_shake_t / maxf(_shake_dur, 0.01), 0.0, 1.0)
		var fall: float = (1.0 - u) * (1.0 - u)
		var offset: Vector2 = Vector2(
			sin(_clock * 71.0) + sin(_clock * 43.0) * 0.6,
			cos(_clock * 59.0) + sin(_clock * 37.0) * 0.5) * 0.62 * _shake_amp * fall
		for target: Control in shake_targets:
			if is_instance_valid(target):
				target.position = offset
		if _shake_t >= _shake_dur:
			_end_shake()
	# Only lists with something live in them are aged and pruned: an idle
	# stage allocates nothing per frame.
	if not _cracks.is_empty():
		for crack: Crack in _cracks:
			crack.t += delta
		_cracks = _cracks.filter(func(c: Crack) -> bool: return c.t < CRACK_LIFE)
	if not _shards.is_empty():
		for shard: Shard in _shards:
			shard.vel.y += GRAVITY * delta
			shard.pos += shard.vel * delta
			shard.rot += shard.spin * delta
			shard.t += delta
		_shards = _shards.filter(func(s: Shard) -> bool: return s.t < 1.5)
	if not _sparks.is_empty():
		for spark: Spark in _sparks:
			spark.t += delta
		_sparks = _sparks.filter(func(s: Spark) -> bool: return s.t < s.delay + 0.95)
	if not _slashes.is_empty():
		_slashes = _aged(_slashes, delta, 0.5)
	if not _rays.is_empty():
		_rays = _aged(_rays, delta, 2.8)
	if not _rings.is_empty():
		_rings = _aged(_rings, delta, 0.55)
	if not reduce_motion:
		_drift_ambient(delta, view)
	queue_redraw()


static func _aged(list: Array[Streak], delta: float, life: float) -> Array[Streak]:
	for item: Streak in list:
		item.t += delta
	return list.filter(func(item: Streak) -> bool: return item.t < life)


func _end_shake() -> void:
	_shake_t = _shake_dur
	for target: Control in shake_targets:
		if is_instance_valid(target):
			target.position = Vector2.ZERO


func _stage() -> Vector2:
	if _view.x >= 1.0 and _view.y >= 1.0:
		return _view
	if size.x >= 1.0 and size.y >= 1.0:
		return size
	return Vector2(StageShape.REFERENCES[StageShape.IDENTITY])


# --- spawners -------------------------------------------------------------

func _crack(centre: Vector2) -> void:
	if reduce_motion:
		return
	var view: Vector2 = _stage()
	var diag: float = view.length()
	var segs: PackedVector2Array = PackedVector2Array()
	var dists: PackedFloat32Array = PackedFloat32Array()
	var arms: int = 8 + _rng.randi_range(0, 3)
	var ring_a: Array[Vector2] = []
	var ring_b: Array[Vector2] = []
	for i: int in range(arms):
		var angle: float = TAU * float(i) / float(arms) + _rng.randf_range(-0.22, 0.22)
		var length: float = diag * _rng.randf_range(0.20, 0.46)
		var steps: int = _rng.randi_range(4, 6)
		var p: Vector2 = centre
		var travelled: float = 0.0
		for s: int in range(steps):
			var bend: float = angle + _rng.randf_range(-0.28, 0.28)
			var step: float = length / float(steps) * _rng.randf_range(0.75, 1.25)
			var q: Vector2 = p + Vector2.from_angle(bend) * step
			segs.append(p)
			segs.append(q)
			dists.append(travelled)
			travelled += step
			if s == 0:
				ring_a.append(q)
			elif s == 2:
				ring_b.append(q)
			p = q
	for ring: Array[Vector2] in [ring_a, ring_b]:
		for i: int in range(ring.size()):
			if _rng.randf() < 0.3:
				continue
			segs.append(ring[i])
			segs.append(ring[(i + 1) % ring.size()])
			dists.append(centre.distance_to(ring[i]))
	var crack: Crack = Crack.new()
	crack.segs = segs
	crack.dists = dists
	crack.reach = diag * 0.5
	_cracks.append(crack)


func _shatter(centre: Vector2) -> void:
	if reduce_motion:
		return
	for i: int in range(38):
		var angle: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(260.0, 820.0)
		var r: float = _rng.randf_range(14.0, 46.0)
		var pts: PackedVector2Array = PackedVector2Array()
		var corners: int = _rng.randi_range(3, 4)
		for k: int in range(corners):
			var a: float = TAU * float(k) / float(corners) + _rng.randf_range(-0.5, 0.5)
			pts.append(Vector2.from_angle(a) * r * _rng.randf_range(0.6, 1.0))
		var shard: Shard = Shard.new()
		shard.pos = centre + Vector2.from_angle(angle) * _rng.randf_range(0.0, 40.0)
		shard.vel = Vector2.from_angle(angle) * speed + Vector2(0.0, -220.0)
		shard.rot = _rng.randf_range(0.0, TAU)
		shard.spin = _rng.randf_range(-9.0, 9.0)
		shard.pts = pts
		shard.colour = SHARD_COLOURS[_rng.randi_range(0, SHARD_COLOURS.size() - 1)]
		_shards.append(shard)


func _kindle(from: Vector2, to: Vector2) -> void:
	if reduce_motion:
		return
	for i: int in range(24):
		var spark: Spark = Spark.new()
		spark.from = from + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-12, 12))
		spark.to = to + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-24, 24))
		spark.lift = _rng.randf_range(80.0, 190.0)
		spark.delay = float(i) * 0.025
		spark.radius = _rng.randf_range(2.0, 4.5)
		_sparks.append(spark)


func _slash(view: Vector2) -> void:
	if reduce_motion:
		return
	var tilt: float = _rng.randf_range(-0.12, 0.12)
	var a: Vector2 = Vector2(view.x * -0.05, view.y * (0.18 + tilt))
	var b: Vector2 = Vector2(view.x * 1.05, view.y * (0.74 - tilt))
	var streak: Streak = Streak.new()
	streak.a = a
	streak.b = b
	_slashes.append(streak)


func _ray_burst(origin: Vector2) -> void:
	if reduce_motion:
		return
	var ray: Streak = Streak.new()
	ray.a = origin
	ray.spin = _rng.randf_range(-0.05, 0.05)
	_rays.append(ray)


func _ring(centre: Vector2) -> void:
	if reduce_motion:
		return
	var ring: Streak = Streak.new()
	ring.a = centre
	_rings.append(ring)


func _spawn_ambient() -> void:
	_motes.clear()
	var view: Vector2 = _stage()
	var weather: RandomNumberGenerator = RandomNumberGenerator.new()
	weather.seed = hash(String(_ambient))
	var counts: Dictionary[StringName, int] = {
		&"embers": 34, &"ash": 46, &"motes": 26, &"snow-glass": 40}
	var count: int = counts.get(_ambient, 0)
	for i: int in range(count):
		var mote: Mote = Mote.new()
		mote.pos = Vector2(weather.randf() * view.x, weather.randf() * view.y)
		mote.radius = weather.randf_range(1.2, 3.6)
		mote.phase = weather.randf() * TAU
		mote.speed = weather.randf_range(0.6, 1.4)
		mote.hue = weather.randi_range(0, 2)
		_motes.append(mote)


func _drift_ambient(delta: float, view: Vector2) -> void:
	for mote: Mote in _motes:
		var pos: Vector2 = mote.pos
		var speed: float = mote.speed
		var phase: float = mote.phase
		var sway: float = sin(_clock * 0.9 + phase) * 10.0
		match _ambient:
			&"embers":
				pos += Vector2(sway, -32.0 * speed) * delta
			&"ash":
				pos += Vector2(sway * 0.8, 18.0 * speed) * delta
			&"motes":
				pos += Vector2(sin(_clock * 0.3 + phase) * 6.0, -4.0 * speed) * delta
			&"snow-glass":
				pos += Vector2(sway * 0.5, 22.0 * speed) * delta
		if pos.y < -12.0:
			pos = Vector2(fposmod(pos.x + 97.0, view.x), view.y + 8.0)
		elif pos.y > view.y + 12.0:
			pos = Vector2(fposmod(pos.x + 61.0, view.x), -8.0)
		mote.pos = pos


# --- drawing --------------------------------------------------------------

func _draw() -> void:
	var view: Vector2 = _stage()
	_draw_ambient()
	for ray: Streak in _rays:
		_draw_rays(ray, view)
	for ring: Streak in _rings:
		var u: float = ring.t / 0.55
		var r: float = view.length() * 0.38 * Motion.ease(Motion.OUT_SOFT, u)
		draw_arc(ring.a, r, 0.0, TAU, 72, Color(1.0, 0.95, 0.86, 0.6 * (1.0 - u)),
			lerpf(8.0, 1.0, u), true)
	for crack: Crack in _cracks:
		_draw_crack(crack)
	for shard: Shard in _shards:
		_draw_shard(shard)
	for spark: Spark in _sparks:
		_draw_spark(spark)
	for slash: Streak in _slashes:
		_draw_slash(slash)
	if _pulse > 0.0:
		_draw_vignette(view, 0.55 * sin(_pulse * PI))
	if _flash_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(_flash_colour, _flash_a))


func _draw_ambient() -> void:
	for mote: Mote in _motes:
		var pos: Vector2 = mote.pos
		var r: float = mote.radius
		var phase: float = mote.phase
		var flicker: float = 0.65 + 0.35 * sin(_clock * 3.0 + phase)
		var colour: Color
		match _ambient:
			&"embers":
				colour = Color(1.0, 0.55 + 0.1 * float(mote.hue), 0.22, 0.75 * flicker)
			&"ash":
				colour = Color(0.72, 0.70, 0.70, 0.32)
			&"motes":
				colour = Color(1.0, 0.86, 0.55, 0.22 * flicker)
			_:
				var cold: Array[Color] = [Color(0.6, 0.85, 0.9), Color(0.7, 0.6, 0.95),
					Color(0.9, 0.93, 1.0)]
				colour = Color(cold[mote.hue], 0.55 * flicker)
		var glow: float = r * (4.0 if _ambient == &"embers" else 2.5)
		draw_texture_rect(_disc, Rect2(pos - Vector2(glow, glow), Vector2(glow, glow) * 2.0),
			false, Color(colour, colour.a * 0.35))
		draw_circle(pos, r * 0.5, colour)


func _draw_rays(ray: Streak, view: Vector2) -> void:
	var t: float = ray.t
	var life: float = clampf(t / 0.5, 0.0, 1.0) * clampf((2.8 - t) / 1.2, 0.0, 1.0)
	var origin: Vector2 = ray.a
	var spin: float = ray.spin
	var reach: float = view.length() * 1.1
	for i: int in range(9):
		var base: float = PI * 0.5 + (float(i) - 4.0) * 0.16 + t * spin
		var width: float = 0.035 + 0.02 * sin(float(i) * 1.7)
		var pts: PackedVector2Array = PackedVector2Array([
			origin,
			origin + Vector2.from_angle(base - width) * reach,
			origin + Vector2.from_angle(base + width) * reach])
		var a: float = 0.16 * life * (0.6 + 0.4 * sin(float(i) * 2.3 + t * 1.5))
		draw_polygon(pts, PackedColorArray([
			Color(1.0, 0.88, 0.60, a), Color(1.0, 0.80, 0.50, 0.0),
			Color(1.0, 0.80, 0.50, 0.0)]))


func _draw_crack(crack: Crack) -> void:
	var t: float = crack.t
	var grow: float = clampf(t / 0.16, 0.0, 1.0)
	var fade: float = clampf((CRACK_LIFE - t) / 0.9, 0.0, 1.0)
	var reach: float = crack.reach * Motion.ease(Motion.OUT_SOFT, grow)
	var segs: PackedVector2Array = crack.segs
	var dists: PackedFloat32Array = crack.dists
	for i: int in range(dists.size()):
		if dists[i] > reach:
			continue
		var a: Vector2 = segs[i * 2]
		var b: Vector2 = segs[i * 2 + 1]
		draw_line(a, b, Color(LEAD, LEAD.a * fade), 4.5, true)
		draw_line(a + Vector2(-1.5, -1.5), b + Vector2(-1.5, -1.5),
			Color(CRACK_EDGE, CRACK_EDGE.a * fade), 1.6, true)


func _draw_shard(shard: Shard) -> void:
	var alpha: float = clampf((1.5 - shard.t) / 0.5, 0.0, 1.0)
	var placed: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in shard.pts:
		placed.append(shard.pos + p.rotated(shard.rot))
	var colour: Color = shard.colour
	draw_colored_polygon(placed, Color(colour, 0.85 * alpha))
	var ring: PackedVector2Array = placed.duplicate()
	ring.append(placed[0])
	draw_polyline(ring, Color(LEAD, LEAD.a * alpha), 2.6, true)
	# A glint along one facet, so each shard reads as glass, not confetti.
	draw_line(placed[0], placed[1], Color(1.0, 1.0, 1.0, 0.55 * alpha), 1.4, true)


func _draw_spark(spark: Spark) -> void:
	var u: float = (spark.t - spark.delay) / 0.95
	if u <= 0.0 or u >= 1.0:
		return
	var mid: Vector2 = (spark.from + spark.to) * 0.5 + Vector2(0.0, -spark.lift)
	var e: float = Motion.ease(Motion.EASE_IN_OUT, u)
	var p: Vector2 = Motion.quad(spark.from, mid, spark.to, e)
	var r: float = spark.radius
	var a: float = sin(u * PI)
	# The kindle burns the Kindling flame's colour: the same fire the title's
	# lantern caught at launch, handed on by the Keeper (opening-start §10).
	draw_texture_rect(_disc, Rect2(p - Vector2(r, r) * 4.0, Vector2(r, r) * 8.0), false,
		Color(LanternFlame.COLOUR[Flame.TIER_KINDLING], 0.5 * a))
	draw_circle(p, r * 0.6, Color(1.0, 0.9, 0.6, a))


func _draw_slash(slash: Streak) -> void:
	var grow: float = clampf(slash.t / 0.1, 0.0, 1.0)
	var fade: float = clampf((0.5 - slash.t) / 0.35, 0.0, 1.0)
	var a: Vector2 = slash.a
	var b: Vector2 = a.lerp(slash.b, Motion.ease(Motion.OUT_SOFT, grow))
	var n: Vector2 = (b - a).orthogonal().normalized()
	for layer: Array in [[44.0, Color(1.0, 0.5, 0.2, 0.22)], [15.0, Color(1.0, 0.85, 0.6, 0.62)],
			[4.0, Color(1.0, 1.0, 1.0, 0.97)]]:
		var w: float = layer[0]
		var colour: Color = layer[1]
		var quad: PackedVector2Array = PackedVector2Array([
			a, a.lerp(b, 0.5) + n * w, b, a.lerp(b, 0.5) - n * w])
		draw_colored_polygon(quad, Color(colour, colour.a * fade))


func _draw_vignette(view: Vector2, a: float) -> void:
	var dark: Color = Color(0.0, 0.0, 0.0, a)
	var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
	var edge: float = minf(view.x, view.y) * 0.32
	var rects: Array = [
		[Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, edge), Vector2(0, edge), true],
		[Vector2(0, view.y - edge), Vector2(view.x, view.y - edge), Vector2(view.x, view.y),
			Vector2(0, view.y), false],
	]
	for r: Array in rects:
		var top_dark: bool = r[4]
		draw_polygon(PackedVector2Array([r[0], r[1], r[2], r[3]]), PackedColorArray([
			dark if top_dark else clear, dark if top_dark else clear,
			clear if top_dark else dark, clear if top_dark else dark]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(edge, 0), Vector2(edge, view.y),
		Vector2(0, view.y)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(view.x - edge, 0), Vector2(view.x, 0),
		Vector2(view.x, view.y), Vector2(view.x - edge, view.y)]),
		PackedColorArray([clear, dark, dark, clear]))
