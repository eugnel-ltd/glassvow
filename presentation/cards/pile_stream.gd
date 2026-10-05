class_name PileStream
extends Control
## The reshuffle (issue #657; §3's Shuffle row in
## docs/design/2026-10-03-cards-real-objects/README.md): the discard lifts
## into the draw pile as a stream of real cards.
##
## At most MAX_SHOWN cards fly, one every `stagger(n)` (SECONDS * SHARE
## shared among them), each on an arc over the stage to the draw pile's top,
## so the last lands SECONDS after the first leaves. The first is the
## discard's top card: it still shows its face and turns face down in the
## first TURN_SHARE of its flight (a picture turn, CardTurn.picture, over its
## baked face); the rest are the table's baked back, the block turned over.
## The owner hears each card leave (`left`) and land (`landed`), so the two
## piles' counts walk card by card, and squares the deck as the last lands
## (PileStack.jog); JOG_TIME later the stream is `done()`, about 0.72 s in all.
##
## A tap anywhere while it flies (heard, never consumed) completes it within
## SKIP_TIME: every card still to go leaves at once, every card in the air
## lands by then, and the stream is done as the last lands. The stream is canvas only: one `_draw()` for the backs,
## one picture-turn sprite for the turning face, nothing rendered.

## The `k`th card (from 0) has left the discard.
signal left(k: int)
## The `k`th card has reached the draw pile.
signal landed(k: int)

const SECONDS: float = 0.6
const SHARE: float = 0.35
const MAX_SHOWN: int = 8
const TURN_SHARE: float = 0.4
const SKIP_TIME: float = 0.15
## The arc's peak, a share of the stage height, a little higher every third
## card so the stream reads as cards rather than one card's trail.
const ARC: float = 0.11
const ARC_STEP: float = 0.03
const SPIN: float = 18.0   # degrees, at the top of the arc
## The turning card's stock: a standard card's thickness, and the edge's tone.
const THICK: float = 7.0

var _n: int = 0
var _shown: int = 0
var _from: Rect2
var _to: Callable
var _back: Texture2D
var _arc_h: float = 0.0
var _t: float = 0.0
var _skip_at: float = -1.0
var _skip_from: PackedFloat32Array = PackedFloat32Array()
var _p: PackedFloat32Array = PackedFloat32Array()
var _left: int = 0
var _landed: int = 0
var _done: bool = false
var _settled_at: float = -1.0
var _turner: TextureRect = null
var _turn_mat: ShaderMaterial = null


## The progress of card `k`'s flight (0 to 1) at `t` seconds into a stream
## of `n` cards.
static func progress(k: int, n: int, t: float) -> float:
	return clampf((t - float(k) * stagger(n)) / flight(n), 0.0, 1.0)


static func shown(n: int) -> int:
	return clampi(n, 1, MAX_SHOWN)


static func stagger(n: int) -> float:
	return SECONDS * SHARE / float(shown(n))


static func flight(n: int) -> float:
	return maxf(0.12, SECONDS - stagger(n) * float(shown(n) - 1))


## How many of `n` reshuffled cards have moved once `k` of the stream's
## shown cards have: the counts walk in step with the cards that fly.
static func moved(k: int, n: int) -> int:
	return roundi(float(n) * float(k) / float(shown(n)))


## The first card's turn: face up (0) to face down (180) over the first
## TURN_SHARE of its flight.
static func yaw(p: float) -> float:
	return 180.0 * smoothstep(0.0, TURN_SHARE, p)


## `n` cards from `from` (the discard's top card, global) to the rect `to`
## returns (the draw pile's top as it thickens, global), wearing `back` and,
## on the first, `face`, over a stage `stage_h` px high.
func _init(n: int, from: Rect2, to: Callable, back: Texture2D, face: Texture2D,
		stage_h: float) -> void:
	_n = maxi(n, 1)
	_shown = shown(_n)
	_from = from
	_to = to
	_back = back
	_arc_h = stage_h
	_p.resize(_shown)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if face != null:
		_turner = _turning(face)
		add_child(_turner)


## Whether every card has landed: the deck is squared and the counts are home.
func done() -> bool:
	return _done


## Complete the stream within SKIP_TIME.
func skip() -> void:
	if _done or _skip_at >= 0.0:
		return
	_skip_at = _t
	_skip_from = _p.duplicate()


func _ready() -> void:
	set_process_input(true)
	_step(0.0)


func _input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) \
			or (st != null and st.pressed):
		skip()


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if _done:
		return
	_t += delta
	for k: int in range(_shown):
		if _skip_at >= 0.0:
			_p[k] = lerpf(_skip_from[k], 1.0, clampf((_t - _skip_at) / SKIP_TIME, 0.0, 1.0))
		else:
			_p[k] = progress(k, _n, _t)
	while _left < _shown and _p[_left] > 0.0:
		_left += 1
		left.emit(_left - 1)
	while _landed < _shown and _p[_landed] >= 1.0:
		_landed += 1
		landed.emit(_landed - 1)
	if _landed >= _shown:
		if _settled_at < 0.0:
			_settled_at = _t
			visible = false
			set_process_input(false)
		if _skip_at >= 0.0 or _t - _settled_at >= PileStack.JOG_TIME:
			_done = true
			set_process(false)
		return
	_pose_turner()
	queue_redraw()


## Where card `k` is at progress `p`: its centre and its spin.
func _where(k: int, p: float) -> Transform2D:
	var e: float = Motion.ease(Motion.OUT_SOFT, p)
	var to: Rect2 = _to.call()
	var p0: Vector2 = _from.get_center()
	var p1: Vector2 = to.get_center()
	var lift: float = _arc_h * (ARC + ARC_STEP * float(k % 3))
	var ctrl: Vector2 = (p0 + p1) * 0.5 - Vector2(0.0, lift)
	var at: Vector2 = Motion.quad(p0, ctrl, p1, e) - global_position
	return Transform2D(deg_to_rad(SPIN * sin(e * PI)), at)


func _draw() -> void:
	if _back == null:
		return
	var card: Vector2 = _from.size
	var pad: Vector2 = card / Vector2(CardView.CARD_W, CardView.CARD_H) * CardView.PAD_3D
	# The last to leave is drawn first, so the cards in front are the ones
	# that left first, as they lay on the pile.
	for k: int in range(_shown - 1, -1, -1):
		var p: float = _p[k]
		if p <= 0.0 or p >= 1.0 or (k == 0 and _turner != null):
			continue
		draw_set_transform_matrix(_where(k, p))
		draw_texture_rect(_back, Rect2(-card * 0.5 - pad, card + pad * 2.0), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The first card as it turns over: its baked face on a picture turn whose
## far side is the table's back.
func _turning(face: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = face
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) \
		+ Vector2.ONE * CardView.PAD_3D * 2.0
	rect.size = stage
	rect.pivot_offset = stage * 0.5
	_turn_mat = CardTurn.picture(THICK, PileStack.EDGE_LIGHT)
	_turn_mat.set_shader_parameter("face_span", Vector2(CardView.CARD_W, CardView.CARD_H)
		+ Vector2.ONE * CardFaces.REACH * 2.0)
	_turn_mat.set_shader_parameter("back_tex", _back)
	rect.material = _turn_mat
	return rect


func _pose_turner() -> void:
	if _turner == null:
		return
	var p: float = _p[0]
	_turner.visible = p > 0.0 and p < 1.0
	if not _turner.visible:
		return
	var xf: Transform2D = _where(0, p)
	var k: float = _from.size.x / CardView.CARD_W
	_turner.scale = Vector2.ONE * k
	_turner.rotation = xf.get_rotation()
	_turner.position = xf.origin - _turner.size * 0.5
	CardTurn.set_pose(_turn_mat, CardTurn.pose(yaw(p), 0.0))
