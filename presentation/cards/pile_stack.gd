class_name PileStack
extends Control
## A pile of real cards (issue #657; §4 of
## docs/design/2026-10-03-cards-real-objects/README.md): a stack whose
## thickness follows its count, its top card drawn from a baked texture and
## the cards under it as edge slivers. One `_draw()` for the pile, no node per
## card, and one shared texture: the table's baked back (CardTurn.back) or,
## on a face-up pile, the last card's baked face (CardFaces).
##
## THE THICKNESS LAW, in pad stage px (the HUD's shell scales a phone's pile):
## 1 px a card up to ten, then 0.35 px a card, capped at CAP_PX, so 1, 5 and
## 10 cards read differently, 40 is deeper than 10, and 99 never becomes a
## tower. One sliver per pixel of thickness, at most MAX_SLIVERS, in two
## alternating tones so single cards resolve, each jittered by a hash of its
## depth (JITTER_PX, JITTER_DEG): the same pile always lies the same way.
##
## THE THREE PILES.
##   DRAW     squared, backs up. Empty, it draws nothing (the HUD keeps its
##            count and name).
##   DISCARD  face up: the top is the last discarded card's baked face, at
##            the angle it landed at; the cards under it lie loose (LOOSE_PX,
##            LOOSE_DEG). While a reshuffle lifts it (`flipped`) it shows the
##            back, the block of cards turned over to go back into the draw.
##   ASHES    backs up, charred (CardFlight.CHAR, the tint a burnt card lands
##            in), an ember rim round the top card.
##
## LIFE AT REST (§3's idle rule for the A12): canvas only. A slow glint
## travels over the draw pile's top back once every GLINT_CYCLE, and the ash
## pile's rim breathes between RIM_LOW and RIM_HIGH over RIM_CYCLE. Both live
## on one small child (`_Glow`), so a breath changes a modulate and a glint
## redraws one polygon pair while it crosses: the pile itself redraws only when
## its count, top or back changes. Under Reduce Motion the glint is off and the
## rim holds still.

enum Kind { DRAW, DISCARD, ASHES }

const CAP_PX: float = 14.0
const PER_CARD: float = 1.0
const TAIL: float = 0.35
const MAX_SLIVERS: int = 24
const JITTER_PX: float = 0.6
const JITTER_DEG: float = 0.6
## The discard's cards under its top, as a thrown pile lies.
const LOOSE_PX: float = 3.0
const LOOSE_DEG: float = 5.0
## The slivers' two tones: the stock's lit edge and its shadowed one.
const EDGE_LIGHT: Color = Color(0.72, 0.66, 0.52)
const EDGE_DARK: Color = Color(0.16, 0.14, 0.13)
const CINDER: Color = Color(0.08, 0.05, 0.04)
const EMBER: Color = Color(1.0, 0.5, 0.15)
## A card with no picture to wear (no bake yet, a headless run): dark glass.
const BLANK: Color = Color(0.09, 0.11, 0.19)
## Where the four taps of a face's picture fall, in px: see `_draw`.
const FACE_TAPS: Array[Vector2] = [Vector2(-0.3, -0.3), Vector2(0.3, 0.3),
	Vector2(0.3, -0.3), Vector2(-0.3, 0.3)]
const GLINT_CYCLE: float = 9.0
const GLINT_SWEEP: float = 1.4
const GLINT: Color = Color(1.0, 0.96, 0.86, 0.24)
const RIM_LOW: float = 0.45
const RIM_HIGH: float = 0.65
const RIM_CYCLE: float = 3.2
## The reshuffle squares the deck: its slivers jog JOG_PX either way and come
## back square over JOG_TIME.
const JOG_PX: float = 2.0
const JOG_TIME: float = 0.12

var kind: Kind = Kind.DRAW
## The card's size in this control's px, and the centre of the bottom card.
var card: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
var base: Vector2 = Vector2.ZERO
var count: int = 0
## Where in its cycle this pile's glint starts, in seconds: two stacks on one
## screen do not glint together.
var idle_phase: float = 0.0
## The discard shows backs while a reshuffle lifts it.
var flipped: bool = false

var _back: Texture2D = null
var _face: Texture2D = null
var _face_uid: int = -1
var _face_rot: float = 0.0
var _face_slip: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _jog: float = 0.0
var _glow: _Glow = null
var _sb_shadow: StyleBoxFlat = StyleBoxFlat.new()
var _sb_edge: StyleBoxFlat = StyleBoxFlat.new()
var _sb_blank: StyleBoxFlat = StyleBoxFlat.new()


## The pile's moving light, laid over its top card: the travelling glint on
## the draw pile, the ember rim on the ash. Its transform is the top card's
## centre and angle; its size is the card's.
class _Glow:
	extends Control
	var pile: PileStack
	var rim: StyleBoxFlat = null
	## Where the glint's band is across the card (-1 to 1), or NAN when off it.
	var band: float = NAN

	func _init(owner_pile: PileStack) -> void:
		pile = owner_pile
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var half: Vector2 = size * 0.5
		if rim != null:
			draw_style_box(rim, Rect2(-half, size))
		if not is_nan(band):
			pile.draw_glint(self, band)


func _init(pile_kind: Kind) -> void:
	kind = pile_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sb_shadow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_sb_shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_sb_blank.bg_color = BLANK
	_sb_blank.set_border_width_all(1)
	_sb_blank.border_color = Color(EDGE_LIGHT, 0.6)
	if kind == Kind.DISCARD:
		set_process(false)
		return
	_glow = _Glow.new(self)
	if kind == Kind.ASHES:
		_glow.rim = StyleBoxFlat.new()
		_glow.rim.bg_color = Color(EMBER, 0.0)
		_glow.rim.draw_center = false
		_glow.rim.set_border_width_all(1)
		_glow.rim.border_color = EMBER
		_glow.rim.shadow_color = Color(1.0, 0.42, 0.1, 0.6)
	add_child(_glow)


## How thick a pile of `n` cards stands, in pad stage px.
static func thickness(n: int) -> float:
	if n <= 0:
		return 0.0
	var t: float = float(mini(n, 10)) * PER_CARD + float(maxi(n - 10, 0)) * TAIL
	return minf(t, CAP_PX)


## How many edge slivers a pile of `n` cards shows: one per pixel of its
## thickness, at least one, at most MAX_SLIVERS.
static func slivers(n: int) -> int:
	if n <= 0:
		return 0
	return clampi(roundi(thickness(n)), 1, MAX_SLIVERS)


func set_count(n: int) -> void:
	n = maxi(n, 0)
	if n == count:
		return
	count = n
	_changed()


## Wear the table's back (a bake's `stage`: the card with PAD_3D round it).
func wear_back(stage: Texture2D) -> void:
	if stage == _back:
		return
	_back = stage
	_changed()


## The discard's top: card `uid`'s baked face (the card with CardFaces.REACH
## round it), lying `rot` radians round and `slip` px off square. A null face
## keeps the picture the pile had until the card's own lands.
func set_face(uid: int, face: Texture2D, rot: float = 0.0, slip: Vector2 = Vector2.ZERO) -> void:
	_face_uid = uid
	if face == null:
		return
	_face = face
	_face_rot = rot
	_face_slip = slip
	_changed()


## The face-up pile has no top any more (it was reshuffled away).
func clear_face() -> void:
	_face_uid = -1
	if _face == null:
		return
	_face = null
	_changed()


## The card the discard says is on top, or -1.
func face_uid() -> int:
	return _face_uid


## The picture the face-up pile's top wears, or null.
func face_texture() -> Texture2D:
	return _face


func back_texture() -> Texture2D:
	return _back


func set_flipped(on: bool) -> void:
	if flipped == on:
		return
	flipped = on
	_changed()


## Square the deck: its slivers jog either way and settle over JOG_TIME.
func jog() -> void:
	_jog = JOG_TIME
	set_process(true)


## The top card of a pile of `n` cards (this pile's count by default), in
## this control's space, unturned: where a dealt card leaves and a spent one
## lands.
func top_rect(n: int = -1) -> Rect2:
	var c: int = count if n < 0 else n
	return Rect2(base - card * 0.5 - Vector2(0.0, thickness(c)), card)


## The angle the top card lies at, in radians.
func top_rotation() -> float:
	return _face_rot if _shows_face() else 0.0


func _shows_face() -> bool:
	return kind == Kind.DISCARD and not flipped and _face != null


func _changed() -> void:
	queue_redraw()
	_place_glow()


func _place_glow() -> void:
	if _glow == null:
		return
	var top: Rect2 = top_rect()
	_glow.visible = count > 0
	_glow.size = top.size
	_glow.position = top.get_center()
	_glow.rotation = top_rotation()
	if _glow.rim != null:
		var r: int = _radius()
		_glow.rim.set_corner_radius_all(r)
		_glow.rim.shadow_size = maxi(2, roundi(6.0 * card.x / 80.0))
	_glow.queue_redraw()


func _radius() -> int:
	return roundi(float(CardView.RADIUS) * card.x / CardView.CARD_W)


func _draw() -> void:
	if count <= 0:
		return
	var th: float = thickness(count)
	var layers: int = slivers(count)
	var top: Rect2 = top_rect()
	var r: int = _radius()
	var loose: float = 1.0 if kind == Kind.DISCARD else 0.0
	var burnt: bool = kind == Kind.ASHES
	var jog: float = _jog / JOG_TIME
	_sb_shadow.set_corner_radius_all(r)
	_sb_shadow.shadow_size = maxi(2, roundi(9.0 * card.x / 80.0))
	_sb_shadow.shadow_offset = Vector2(0.0, 5.0 * card.x / 80.0)
	_sb_edge.set_corner_radius_all(r)
	_sb_blank.set_corner_radius_all(r)
	draw_style_box(_sb_shadow, Rect2(base - card * 0.5, card))
	var px: float = JITTER_PX + (LOOSE_PX - JITTER_PX) * loose
	var deg: float = JITTER_DEG + (LOOSE_DEG - JITTER_DEG) * loose
	for i: int in range(layers, 0, -1):
		var at: Vector2 = top.get_center() + Vector2(
			CardFlight.jitter(i, 11) * px + JOG_PX * jog * (1.0 if i % 2 == 0 else -1.0),
			float(i) * th / float(layers))
		var tone: Color = EDGE_LIGHT.lerp(EDGE_DARK, 0.35 + 0.5 * float(i % 2)) \
			.darkened(0.25 * float(i) / float(layers))
		if burnt:
			# Cinders, a few of them still catching: at a pixel a sliver, an
			# ember on every edge would read as one orange band.
			tone = tone.lerp(CINDER, 0.7)
			var catch: float = CardFlight.jitter(i, 5)
			_sb_edge.border_width_bottom = 1 if catch > 0.35 else 0
			_sb_edge.border_color = Color(EMBER, 0.25 + 0.35 * catch)
		_sb_edge.bg_color = tone
		draw_set_transform(at, deg_to_rad(deg * CardFlight.jitter(i, 17)), Vector2.ONE)
		draw_style_box(_sb_edge, Rect2(-card * 0.5, card))
	draw_set_transform(top.get_center() + (_face_slip if _shows_face() else Vector2.ZERO),
		top_rotation(), Vector2.ONE)
	var k: float = card.x / CardView.CARD_W
	if _shows_face():
		# A baked face has no mipmaps (a GPU copy), and on a pile it is drawn
		# at a third of its texels or less: four taps a fraction of a pixel
		# apart, each laid over the last at 1/n, average to a box filter where
		# one bilinear tap would sparkle.
		var reach: Vector2 = Vector2.ONE * CardFaces.REACH * k
		var at: Rect2 = Rect2(-card * 0.5 - reach, card + reach * 2.0)
		for j: int in range(FACE_TAPS.size()):
			draw_texture_rect(_face, Rect2(at.position + FACE_TAPS[j], at.size), false,
				Color(1.0, 1.0, 1.0, 1.0 / float(j + 1)))
	elif _back != null and (kind != Kind.DISCARD or flipped):
		var pad: Vector2 = Vector2.ONE * CardView.PAD_3D * k
		draw_texture_rect(_back, Rect2(-card * 0.5 - pad, card + pad * 2.0), false,
			CardFlight.CHAR if burnt else Color.WHITE)
	else:
		draw_style_box(_sb_blank, Rect2(-card * 0.5, card))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	_t += delta
	if _jog > 0.0:
		_jog = maxf(0.0, _jog - delta)
		queue_redraw()
	if _glow == null:
		set_process(_jog > 0.0)
		return
	var still: bool = Preferences.active.reduce_motion
	if _glow.rim != null:
		var breath: float = 0.5 if still else 0.5 - 0.5 * cos(TAU * _t / RIM_CYCLE)
		_glow.modulate.a = lerpf(RIM_LOW, RIM_HIGH, breath)
		return
	var band: float = NAN if still or count <= 0 else glint_at(_t + idle_phase)
	if is_nan(band) and is_nan(_glow.band):
		return
	_glow.band = band
	_glow.queue_redraw()


## Where the glint's band crosses the card at time `t` of its cycle, -1 to 1
## (corner to corner), or NAN while it is off the card.
static func glint_at(t: float) -> float:
	var u: float = fposmod(t, GLINT_CYCLE) / GLINT_SWEEP
	if u >= 1.0:
		return NAN
	return lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, u))


## The glint at `band`: a soft diagonal light, brightest on its centre line,
## clipped to the card on `to`, whose origin is the card's centre.
func draw_glint(to: CanvasItem, band: float) -> void:
	var half: Vector2 = card * 0.5
	var width: float = card.x * 0.22
	# The band runs from lower left to upper right and sweeps across the card
	# from its upper left corner to its lower right one.
	var along: Vector2 = Vector2(0.5, -1.0).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	var reach: float = half.length() + width
	var mid: Vector2 = across * band * reach
	var outline: PackedVector2Array = _outline(half, float(_radius()))
	for side: float in [-1.0, 1.0]:
		var a: Vector2 = mid
		var b: Vector2 = mid + across * width * side
		var strip: PackedVector2Array = PackedVector2Array([
			a - along * reach, a + along * reach, b + along * reach, b - along * reach])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(strip, outline):
			var tones: PackedColorArray = PackedColorArray()
			for p: Vector2 in piece:
				var d: float = absf((p - mid).dot(across)) / width
				tones.append(Color(GLINT, GLINT.a * clampf(1.0 - d, 0.0, 1.0)))
			to.draw_polygon(piece, tones)


## The card's outline as a polygon, its corners rounded by `r`.
static func _outline(half: Vector2, r: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(half.x - r, -half.y + r), Vector2(half.x - r, half.y - r),
		Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r)]
	for c: int in range(4):
		for s: int in range(4):
			var a: float = -PI * 0.5 + (float(c) + float(s) / 3.0) * PI * 0.5
			out.append(corners[c] + Vector2(cos(a), sin(a)) * r)
	return out
