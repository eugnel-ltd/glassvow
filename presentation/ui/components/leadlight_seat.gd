class_name LeadlightSeat
extends Control
## The way back from every room (docs/design/2026-10-03-title-rooms §2.2, §3.1):
## the lantern that carried you in is lowered to the seat, bottom left, and
## beside it a quiet **Return** with a small lead chevron drawn before it. A tap
## on the seated lantern's body or on the word is the same action, through two
## separate hits, never one box, so the seat cannot take a tap meant for
## content beside it. It is anchored to the stage, never to content, so nothing
## scrolls it or pushes it off. Where no lantern was lent (a room opened in a
## run) the word stands alone in the same place.

signal pressed

## Clear of every room's content, measured on the identity stage (pad) and
## the phone, from the stage's bottom-left corner: the lantern's art square,
## the word's hit, and the two keep-clear rects.
const PAD: Dictionary = {
	"art": Rect2(-6.0, -232.0, 220.0, 220.0), "word": Rect2(152.0, -78.0, 150.0, 64.0),
	"keep_lantern": Rect2(0.0, -232.0, 170.0, 232.0), "keep_word": Rect2(146.0, -84.0, 164.0, 84.0),
}
const PHONE: Dictionary = {
	"art": Rect2(-4.0, -124.0, 132.0, 132.0), "word": Rect2(100.0, -50.0, 116.0, 44.0),
	"keep_lantern": Rect2(0.0, -128.0, 104.0, 128.0), "keep_word": Rect2(96.0, -56.0, 124.0, 56.0),
}
const CHEVRON_INSET: float = 24.0
const ARC_DROP: float = 40.0

var shape: StringName = StageShape.IDENTITY
var with_lantern: bool = true
var _word: LeadlightWord
var _lantern_hit: Button


## The seat on a stage of `stage` size: {art, wick, lantern_hit, word,
## keep_lantern, keep_word}, every rect in stage pixels. Pure.
static func for_stage(stage_shape: StringName, stage: Vector2) -> Dictionary:
	var spec: Dictionary = PHONE if LeadlightTokens.is_phone(stage_shape) else PAD
	var out: Dictionary = {}
	for key: String in spec:
		var rect: Rect2 = spec[key]
		out[key] = Rect2(rect.position + Vector2(0.0, stage.y), rect.size)
	var art: Rect2 = out["art"]
	out["wick"] = art.position + art.size * LeadlightLantern.WICK_UV
	var body: Rect2 = Rect2(art.position + art.size * LeadlightLantern.HIT_UV.position,
		art.size * LeadlightLantern.HIT_UV.size)
	# Two hits, never one box: the lantern's stops where the word's begins.
	var word: Rect2 = out["word"]
	body.size.x = minf(body.end.x, word.position.x) - body.position.x
	out["lantern_hit"] = body.intersection(Rect2(Vector2.ZERO, stage))
	return out


## The lantern between its home and the seat, `p` (0..1) along a lowered arc
## (§3.1): its square's centre on a quadratic curve whose control point is a
## quarter of the way along the chord and ARC_DROP below it, so it reads as
## lowered to the hand, not slid. Pure.
static func path(home: Rect2, seat_art: Rect2, p: float) -> Rect2:
	var from: Vector2 = home.get_center()
	var to: Vector2 = seat_art.get_center()
	var bend: Vector2 = from.lerp(to, 0.25) + Vector2(0.0, ARC_DROP)
	var q: float = clampf(p, 0.0, 1.0)
	var at: Vector2 = from * (1.0 - q) * (1.0 - q) + bend * 2.0 * (1.0 - q) * q + to * q * q
	var side: float = lerpf(home.size.x, seat_art.size.x, q)
	return Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side))


func _init(stage_shape: StringName = StageShape.IDENTITY, lantern: bool = true) -> void:
	name = "Seat"
	shape = stage_shape
	with_lantern = lantern
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern_hit = Button.new()
	_lantern_hit.name = "SeatLantern"
	_lantern_hit.flat = true
	_lantern_hit.focus_mode = Control.FOCUS_NONE
	_lantern_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		_lantern_hit.add_theme_stylebox_override(state, empty)
	_lantern_hit.tooltip_text = Locale.active.t("ui.menu.return")
	_lantern_hit.pressed.connect(_on_pressed)
	_lantern_hit.visible = lantern
	add_child(_lantern_hit)
	_word = LeadlightWord.new(Locale.active.t("ui.menu.return"), stage_shape)
	_word.name = "Return"
	_word.near = true
	_word.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box: StyleBox = _word.get_theme_stylebox(state)
		if box != null:
			box.content_margin_left = CHEVRON_INSET
	_word.pressed.connect(_on_pressed)
	_word.button_down.connect(func() -> void: LeadlightMotion.press(_word))
	add_child(_word)


func _ready() -> void:
	_place()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()
		queue_redraw()


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	_word.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL,
		LeadlightTokens.size_for(LeadlightTokens.SIZE_WORD, stage_shape)))
	_word.add_theme_font_size_override("font_size", LeadlightTokens.size_for(LeadlightTokens.SIZE_WORD, stage_shape))
	_place()


## Whether a lantern stands at the seat (lent by the title): its body takes a
## tap too. In a run there is none and the word stands alone.
func set_lantern(lantern: bool) -> void:
	with_lantern = lantern
	_lantern_hit.visible = lantern


## The word that leaves the room (it takes the focus a keyboard reaches).
func word() -> LeadlightWord:
	return _word


## The hit over the seated lantern's body.
func lantern_hit() -> Button:
	return _lantern_hit


func _place() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var seat: Dictionary = for_stage(shape, size)
	var word_rect: Rect2 = seat["word"]
	_word.position = word_rect.position
	_word.size = word_rect.size
	_word.custom_minimum_size = word_rect.size
	var hit: Rect2 = seat["lantern_hit"]
	_lantern_hit.position = hit.position
	_lantern_hit.size = hit.size


func _on_pressed() -> void:
	pressed.emit()


## The chevron: two strokes of lead with a gold line, pointing back to the
## lantern. Drawn, not a glyph, so no font fallback can change it.
func _draw() -> void:
	if _word == null:
		return
	var h: float = _word.size.y
	var tip: Vector2 = _word.position + Vector2(8.0, h * 0.5)
	var arm: float = 7.0 if not LeadlightTokens.is_phone(shape) else 5.5
	var points: PackedVector2Array = PackedVector2Array([
		tip + Vector2(arm, -arm), tip, tip + Vector2(arm, arm)])
	draw_polyline(points, Color(LeadlightTokens.LEAD, 0.9), 4.0, true)
	draw_polyline(points, Color(LeadlightTokens.GOLD, 0.8 * _word.modulate.a), 1.4, true)
