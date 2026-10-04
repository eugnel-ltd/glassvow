class_name VigilHall
extends Control
## The hearth hall (docs/design/2026-10-03-title-rooms §4.1): the hearth at
## the road's west end (守夜之爐, docs/story/01-world.md), where the Vigil is
## kept. The hall is the shipped opening plate with the Keeper seated by the
## fire through HearthFigure's own stagecraft, so it adds no canon and no art.
##
## One plate, three looks across it (`frame`, a pure rule): to the hearth
## (Deeds), up to the window (the Rose Window, where the Emberglass rose stands
## over the plate's own painted window, so the hall never shows two), and down
## to the floor before the fire (Epitaphs). The turn west (V1) slides the hall
## in from the west and the turn east (V3) out again; a look change moves the
## framing (V4). Every framing, and every blend of two, covers the stage.
##
## Alive at rest on one clock, all drawing: the firelight (two additive discs
## from the hearth's mouth and its spill on the floor, flickering on two sines
## and a stepped breath), embers rising from the fire, the Keeper's breath,
## and on the Rose look a shaft of moonlight from the window with dust in it.
## Under Reduce Motion only the firelight moves: it is the fire's flicker.
##
## The cards lane's back shelf (#657) stands on the hall's wall: `shelf()` is
## its seat, a named, empty, input-blind layer on the plate (plate pixels,
## lit by the fire drawn over it, under the Keeper), moving with every look.

const PLATE: String = "res://assets/art/scenes/opening-hearth.png"
const PLATE_SIZE: Vector2 = Vector2(1536.0, 1024.0)
## Plate pixels: the Keeper sprite's right edge (HearthFigure's seat with the
## cutout's 682:1024 aspect), his hem, the painted rose window (centre and
## radius with its moulding, measured off the plate), the fire's heart and
## the floor it lights.
const KEEPER_ASPECT: float = 682.0 / 1024.0
## The cutout's art starts this share of its height below its top (its hood).
const KEEPER_HOOD: float = 0.09
## Looking down, the Keeper's hood stays this far below the stage's top (pad
## and desktop, phone): under the look panes.
const HEAD_ROOM: Vector2 = Vector2(154.0, 46.0)
const KEEPER_RIGHT: float = 1360.0
const HEM: float = 861.0
const WINDOW: Vector3 = Vector3(215.0, 184.0, 100.0)
const FIRE: Vector2 = Vector2(1212.0, 630.0)
const SPILL: Vector2 = Vector2(1120.0, 812.0)
## The Deeds framing's enlargement over cover, and the Epitaphs look's over it.
const ENLARGE: float = 1.08
const FLOOR_GROW: float = 1.15
## The painted window lies inside the Emberglass rose by this share of its radius.
const WINDOW_IN_ROSE: float = 0.92
## The turn west and east: the hall's slide, a share of the stage's width.
const TURN: float = 0.08
const ROSE_DIM: float = 0.86
const MOVE_TIME: float = 0.48
## Where the Emberglass rose stands on the Rose look (centre, visible radius),
## pad and desktop, and phone: at left, the reading glass beside it.
const ROSE_PAD: Vector3 = Vector3(300.0, 312.0, 190.0)
const ROSE_PHONE: Vector3 = Vector3(220.0, 182.0, 112.0)
const EMBERS: int = 20
const MOTES: int = 30

const DEEDS: StringName = &"deeds"
const ROSE: StringName = &"rose"
const EPITAPHS: StringName = &"epitaphs"

## 0..1: how far the fire has caught (V1 brings it up), and the flare as the
## lantern seats (the fire answers the flame).
var fire: float = 1.0
## Stage px the hall is slid by (the turn), applied over the framing.
var slide: float = 0.0:
	set(value):
		slide = value
		_place()
var shape: StringName = StageShape.IDENTITY

var _plate: TextureRect
var _shelf: Control
var _fire: _Fire
var _shaft: _Shaft
var _keeper: HearthFigure
var _band: TextureRect
var _look: StringName = DEEDS
var _from: Transform2D = Transform2D.IDENTITY
var _from_dim: float = 1.0
var _move: float = -1.0
var _time: float = 0.0
var _flare: float = -1.0
var _step: float = 0.0
var _step_to: float = 0.0
var _step_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## (x, y, age, life) in plate px and seconds; and the dust in the shaft.
var _embers: Array[Vector4] = []
var _motes: Array[Vector3] = []
var _shaft_on: float = 0.0
## The band's width (stage px): where a look change takes it from, and to.
var _band_from: float = 0.0
var _band_to: float = 0.0
## The band's soft light, made once a session.
static var _band_light: GradientTexture2D = null


## The framing of `look` on a stage of `stage` size: the plate's scale and
## where its top-left lands (stage px). Pure; every framing covers the stage.
static func frame(stage: Vector2, look: StringName, stage_shape: StringName) -> Transform2D:
	var base: float = cover(stage) * ENLARGE
	var s: float = base
	var at: Vector2 = Vector2.ZERO
	if look == ROSE:
		# Looking up: the painted window centred under the rose, and no
		# smaller than the plate must be for its corner to stay off the stage.
		var rose: Vector3 = rose_spot(stage_shape)
		s = maxf(base, maxf(rose.x / WINDOW.x, rose.y / WINDOW.y))
		at = Vector2(rose.x, rose.y) - Vector2(WINDOW.x, WINDOW.y) * s
	elif look == EPITAPHS:
		# Looking down: the floor before the fire fills the stage's foot, and
		# the Keeper's hood stays under the look panes.
		s = base * FLOOR_GROW
		var keeper: Rect2 = keeper_on_plate()
		var hood: float = keeper.position.y + keeper.size.y * KEEPER_HOOD
		var room: float = HEAD_ROOM.y if LeadlightTokens.is_phone(stage_shape) else HEAD_ROOM.x
		at = Vector2(stage.x - 24.0 - KEEPER_RIGHT * s, maxf(stage.y - PLATE_SIZE.y * s, room - hood * s))
	else:
		# The hearth: the Keeper whole on the stage, his hem on it.
		at = Vector2(stage.x - 24.0 - KEEPER_RIGHT * s,
			minf((stage.y - PLATE_SIZE.y * s) * 0.5, stage.y - 8.0 - HEM * s))
	return covering(stage, s, at)


## A plate of scale `s` at `at`, held so it covers the stage. Pure.
static func covering(stage: Vector2, s: float, at: Vector2) -> Transform2D:
	var held: Vector2 = Vector2(clampf(at.x, stage.x - PLATE_SIZE.x * s, 0.0),
		clampf(at.y, stage.y - PLATE_SIZE.y * s, 0.0))
	return Transform2D(0.0, Vector2(s, s), 0.0, held)


static func cover(stage: Vector2) -> float:
	return maxf(stage.x / PLATE_SIZE.x, stage.y / PLATE_SIZE.y)


## Where the Emberglass rose stands on the Rose look: centre and visible radius.
static func rose_spot(stage_shape: StringName) -> Vector3:
	return ROSE_PHONE if LeadlightTokens.is_phone(stage_shape) else ROSE_PAD


## The Keeper's sprite on the plate (HearthFigure's seat), plate px. Pure.
static func keeper_on_plate() -> Rect2:
	var box: Rect2 = Rect2(Vector2(HearthFigure.SEAT_LEFT, HearthFigure.SEAT_TOP) * PLATE_SIZE,
		Vector2(HearthFigure.SEAT_RIGHT - HearthFigure.SEAT_LEFT,
			HearthFigure.SEAT_BOTTOM - HearthFigure.SEAT_TOP) * PLATE_SIZE)
	var w: float = minf(box.size.y * KEEPER_ASPECT, box.size.x)
	var h: float = w / KEEPER_ASPECT
	return Rect2(Vector2(box.position.x + (box.size.x - w) * 0.5, box.end.y - h), Vector2(w, h))


## The Keeper's sprite on the stage under `xf`.
static func keeper_on_stage(xf: Transform2D) -> Rect2:
	return xf * keeper_on_plate()


## The painted window on the stage under `xf`: centre and radius.
static func window_on_stage(xf: Transform2D) -> Vector3:
	var at: Vector2 = xf * Vector2(WINDOW.x, WINDOW.y)
	return Vector3(at.x, at.y, WINDOW.z * xf.get_scale().x)


## The art the hall draws on its Deeds look, the look it opens on: what Main
## loads on a worker while the title rests (§7 item 16). The rose's masks are
## the Rose look's alone (LeadlightRose.mask_paths()), held apart.
static func art_paths() -> PackedStringArray:
	var paths: PackedStringArray = [PLATE, HearthFigure.ART, LeadlightRose.MURAL, LeadlightRose.FRAME]
	for id: String in VigilScreen.DEED_IDS:
		paths.append("res://assets/art/deeds/%s.png" % id)
	return paths


## The hall's first-use pipelines in one small scene, for RoomWarm to draw once
## under the road before the first turn west (§7 item 15): the plate, the
## fire's and the moonlight's additive light, the Keeper's clip pass, and the
## rose's pane shader at its size in every state, with a came.
static func pipeline_sample(stage_shape: StringName) -> Control:
	var reference: Vector2i = StageShape.REFERENCES.get(stage_shape, Vector2i(1180, 820))
	var stage: Vector2 = Vector2(reference)
	var sample: Control = Control.new()
	sample.name = "VigilPipelines"
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample.size = stage
	var hall: VigilHall = VigilHall.new(stage_shape)
	hall.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hall.size = stage
	hall.look_to(ROSE, false)
	sample.add_child(hall)
	var states: Dictionary = {}
	var each: Array[StringName] = [LeadlightRose.DORMANT, LeadlightRose.ARMED, LeadlightRose.REVEALED,
		LeadlightRose.COMPLETE, LeadlightRose.COMPLETE, LeadlightRose.REVEALED]
	for i: int in LeadlightRose.SHARDS.size():
		states[LeadlightRose.SHARDS[i]] = each[i]
	var rose: LeadlightRose = LeadlightRose.vigil(states, {})
	var spot: Vector3 = rose_spot(stage_shape)
	var side: float = 2.0 * spot.z / LeadlightRose.RIM
	rose.position = Vector2(spot.x, spot.y) - Vector2(side, side) * 0.5
	rose.size = Vector2(side, side)
	rose.selected = LeadlightRose.SHARDS[3]
	sample.add_child(rose)
	return sample


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	name = "Hall"
	shape = stage_shape
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = 0x7E44
	_plate = TextureRect.new()
	_plate.name = "Plate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Texture, then expand mode, then size: a size written first is floored
	# at the texture's own.
	_plate.texture = load(PLATE) as Texture2D
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.size = PLATE_SIZE
	add_child(_plate)
	_shelf = Control.new()
	_shelf.name = "Shelf"
	_shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shelf.size = PLATE_SIZE
	_plate.add_child(_shelf)
	_fire = _Fire.new()
	_fire.hall = self
	_plate.add_child(_fire)
	if HearthFigure.present():
		_keeper = HearthFigure.attach(_plate)
		_keeper.breathe = true
	_shaft = _Shaft.new()
	_shaft.hall = self
	_plate.add_child(_shaft)
	_band = TextureRect.new()
	_band.name = "Band"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.texture = _band_texture()
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_band)
	for i: int in range(EMBERS):
		_embers.append(_new_ember(true))
	for i: int in range(MOTES):
		_motes.append(Vector3(_rng.randf(), _rng.randf() * 2.0 - 1.0, _rng.randf() * TAU))


## The cards lane's back shelf stands here (#657 PR 7): plate px, on the wall.
func shelf() -> Control:
	return _shelf


func plate() -> TextureRect:
	return _plate


func keeper() -> HearthFigure:
	return _keeper


func look() -> StringName:
	return _look


## The framing now on the stage (the turn's slide included).
func framing() -> Transform2D:
	return Transform2D(0.0, _plate.scale, 0.0, _plate.position)


## Turn to `look`: at once, or over MOVE_TIME (V4).
func look_to(to: StringName, animate: bool) -> void:
	var moves: bool = animate and to != _look and not LeadlightMotion.reduced()
	if moves:
		_from = Transform2D(0.0, _plate.scale, 0.0, _plate.position - Vector2(slide, 0.0))
		_from_dim = _plate.modulate.r
		_band_from = _band.size.x
		_move = 0.0
	else:
		_move = -1.0
		_shaft_on = 1.0 if to == ROSE else 0.0
	_look = to
	_place()


func moving() -> bool:
	return _move >= 0.0


## The fire answers the lantern as it is set down: a short flare.
func answer() -> void:
	_flare = 0.0


## The firelight's gain now: caught, flickering, flaring.
func fire_gain() -> float:
	var flare: float = 0.15 * sin(PI * clampf(_flare / 0.24, 0.0, 1.0)) if _flare >= 0.0 else 0.0
	return fire * flicker() * (1.0 + flare)


## The fire's flicker, ±12%: two summed sines and a stepped breath.
func flicker() -> float:
	var wave: float = 0.55 * sin(_time * 3.7) + 0.30 * sin(_time * 9.9 + 1.3)
	return 1.0 + 0.12 * clampf(wave + _step, -1.0, 1.0)


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	_place()


## The legibility band: VOID from the stage's left edge, fading out `past`
## stage px beyond `right` (the column's).
func set_band(right: float, past: float = 140.0) -> void:
	_band_to = maxf(right + past, 1.0)
	_band.position = Vector2.ZERO
	if _move < 0.0:
		_band.size = Vector2(_band_to, size.y)


func band() -> TextureRect:
	return _band


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	if _plate == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var to: Transform2D = frame(size, _look, shape)
	var xf: Transform2D = to
	var dim: float = ROSE_DIM if _look == ROSE else 1.0
	if _move >= 0.0:
		# The eye turns up or down the hall: easing in and out, never a lurch
		# (a quint's first two frames took a third of the climb to the window).
		var p: float = LeadlightMotion.ease_on(_move / MOVE_TIME, LeadlightMotion.IN_OUT)
		# Scale and corner blend linearly: a blend of two covering framings covers.
		var s: float = lerpf(_from.get_scale().x, to.get_scale().x, p)
		xf = Transform2D(0.0, Vector2(s, s), 0.0, _from.origin.lerp(to.origin, p))
		dim = lerpf(_from_dim, dim, p)
		_band.size.x = lerpf(_band_from, _band_to, p)
	elif _band_to > 0.0:
		_band.size.x = _band_to
	xf = covering(size, xf.get_scale().x, xf.origin + Vector2(slide, 0.0))
	_plate.scale = xf.get_scale()
	_plate.position = xf.origin
	_plate.modulate = Color(dim, dim, dim, 1.0)
	_band.size.y = size.y


func _process(delta: float) -> void:
	_time += delta
	_step_left -= delta
	if _step_left <= 0.0:
		_step_left = 0.35
		_step_to = _rng.randf_range(-0.35, 0.35)
	_step = lerpf(_step, _step_to, minf(1.0, delta * 10.0))
	if _flare >= 0.0:
		_flare += delta
		if _flare > 0.24:
			_flare = -1.0
	if _move >= 0.0:
		_move += delta
		if _move >= MOVE_TIME:
			_move = -1.0
		_place()
	var shaft_to: float = 1.0 if _look == ROSE else 0.0
	_shaft_on = move_toward(_shaft_on, shaft_to, delta / 0.32)
	if not LeadlightMotion.reduced():
		_rise(delta)
	_fire.queue_redraw()
	if _shaft_on > 0.0 or _shaft.visible:
		_shaft.visible = _shaft_on > 0.0
		_shaft.queue_redraw()


func _rise(delta: float) -> void:
	for i: int in _embers.size():
		var e: Vector4 = _embers[i]
		e.z += delta
		if e.z >= e.w:
			e = _new_ember(false)
		else:
			e.y -= delta * (18.0 + 10.0 * fmod(e.w, 1.0))
			e.x += sin(_time * 1.3 + e.w * 7.0) * delta * 9.0
		_embers[i] = e
	for i: int in _motes.size():
		var m: Vector3 = _motes[i]
		m.x = fposmod(m.x + delta * 0.012, 1.0)
		m.y = clampf(m.y + sin(_time * 0.4 + m.z) * delta * 0.05, -1.0, 1.0)
		_motes[i] = m


func _new_ember(anywhere: bool) -> Vector4:
	var life: float = _rng.randf_range(6.0, 9.0)
	return Vector4(FIRE.x + _rng.randf_range(-95.0, 95.0), FIRE.y + 40.0 + _rng.randf_range(-20.0, 30.0),
		_rng.randf() * life if anywhere else 0.0, life)


## VOID from the left, holding behind the column and gone past it.
func _band_texture() -> GradientTexture2D:
	if _band_light != null:
		return _band_light
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 0.82, 1.0])
	ramp.colors = PackedColorArray([Color(LeadlightTokens.VOID, 0.80), Color(LeadlightTokens.VOID, 0.70),
		Color(LeadlightTokens.VOID, 0.42), Color(LeadlightTokens.VOID, 0.0)])
	_band_light = GradientTexture2D.new()
	_band_light.gradient = ramp
	_band_light.width = 256
	_band_light.height = 4
	return _band_light


## The fire's light on the hall, in plate px, additive: the hearth's mouth, its
## spill on the floor, and the embers it sends up.
class _Fire extends Control:
	var hall: VigilHall = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = PLATE_SIZE
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _draw() -> void:
		if hall == null:
			return
		var g: float = hall.fire_gain()
		if g <= 0.002:
			return
		var disc: Texture2D = SkyField.disc()
		draw_texture_rect(disc, Rect2(FIRE - Vector2(340.0, 300.0), Vector2(680.0, 600.0)), false,
			Color(1.0, 0.56, 0.22, 0.24 * g))
		draw_texture_rect(disc, Rect2(SPILL - Vector2(600.0, 150.0), Vector2(1200.0, 300.0)), false,
			Color(1.0, 0.62, 0.30, 0.14 * g))
		for e: Vector4 in hall._embers:
			var a: float = clampf(e.z / 0.8, 0.0, 1.0) * clampf((e.w - e.z) / 1.6, 0.0, 1.0) * g
			if a <= 0.02:
				continue
			var r: float = 3.0 + 2.0 * fmod(e.w * 3.0, 1.0)
			draw_texture_rect(disc, Rect2(Vector2(e.x, e.y) - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false,
				Color(1.0, 0.66, 0.30, 0.55 * a))


## Moonlight from the window on the Rose look, in plate px, additive: a shaft
## that drifts ±2° over 11 s, with dust turning in it.
class _Shaft extends Control:
	var hall: VigilHall = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = PLATE_SIZE
		visible = false
		var add: CanvasItemMaterial = CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _draw() -> void:
		if hall == null or hall._shaft_on <= 0.0:
			return
		var k: float = hall._shaft_on
		var still: bool = LeadlightMotion.reduced()
		var sway: float = 0.0 if still else deg_to_rad(2.0) * sin(TAU * hall._time / 11.0)
		var top: Vector2 = Vector2(WINDOW.x, WINDOW.y)
		# Down from the window to the floor where you stand, by the doorway.
		var dir: Vector2 = Vector2(-0.12, 1.0).normalized().rotated(sway)
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var reach: float = 860.0
		var near_w: float = WINDOW.z * 0.8
		var far_w: float = 260.0
		var moon: Color = Color(0.60, 0.70, 1.0)
		draw_polygon(PackedVector2Array([top - side * near_w, top + side * near_w,
			top + dir * reach + side * far_w, top + dir * reach - side * far_w]),
			PackedColorArray([Color(moon, 0.20 * k), Color(moon, 0.20 * k), Color(moon, 0.0), Color(moon, 0.0)]))
		var disc: Texture2D = SkyField.disc()
		for m: Vector3 in hall._motes:
			var along: float = m.x * reach
			var across: float = m.y * lerpf(near_w, far_w, m.x) * 0.8
			var at: Vector2 = top + dir * along + side * across
			var a: float = (0.5 + 0.5 * sin(hall._time * 1.1 + m.z)) * (1.0 - m.x) * k
			draw_texture_rect(disc, Rect2(at - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), false,
				Color(0.85, 0.90, 1.0, 0.35 * a))
