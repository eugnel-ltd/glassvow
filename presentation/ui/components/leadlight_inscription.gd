class_name LeadlightInscription
extends Control
## Carved text: gold cut into dark stone, a shadow above and a glint below,
## foreshortened as if it lay on the road (`lie` 0 stands it up, 1 lays it
## nearly flat). The Vigil's deeds are inscriptions, not a stats line.

## A line's pitch, as a share of the carved size: two deeds read as one
## inscription, closer than the title's words are to each other.
const LEADING: float = 1.3

var lines: PackedStringArray = PackedStringArray()
## Foreshortening. The carved size grows with it, so the letters as drawn
## stand at the carved role's size (the rubric's floor on the title, #655):
## lying on the road never makes them smaller to the eye.
var lie: float = 0.45:
	set(value):
		lie = value
		_px = ceili(float(_role_px) / squash_for(lie))
		_faces.clear()
		queue_redraw()
var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
var colour: Color = Color(LeadlightTokens.GOLD, 0.62)
## Perspective on the flagstones: the lines lean toward the road's vanishing
## point (left slab positive, right slab negative). 0 stands them square.
var shear: float = 0.0
## A dark groove cut round each letter, so carved gold reads on busy stone.
var groove: bool = false
## The carved role's size for the shape, as the letters must stand.
var _role_px: int = 14
## The size the letters are set at, before they lie down.
var _px: int = 14
## Each line's face, fitted to the slab's width (see `face_for`).
var _faces: Dictionary = {}


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_px = LeadlightTokens.size_for(LeadlightTokens.SIZE_CARVED, stage_shape)
	lie = lie


## How much of its height a letter keeps, lying at `amount`. Pure.
static func squash_for(amount: float) -> float:
	return 1.0 - clampf(amount, 0.0, 0.9) * 0.7


## The size the letters stand at as drawn: the set size, foreshortened.
func drawn_px() -> float:
	return float(_px) * squash_for(lie)


## The slab's height for its lines, unforeshortened: the box `_draw` lays down.
func box_height() -> float:
	return float(lines.size()) * float(_px) * LEADING + 4.0


## The carved letters' extent as drawn, in the slab's own coordinates: every
## line's ink box (its set width, the face's ascent and descent) through the
## lie and the lean. What the title keeps clear of its words.
func drawn_rect() -> Rect2:
	var slant: Transform2D = _slant()
	var out: Rect2 = Rect2()
	for i: int in range(lines.size()):
		var text: String = carved_text(lines[i])
		var font: Font = face_for(text)
		var wide: float = carved_width(text)
		var x: float = 0.0
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x = (size.x - wide) * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - wide
		var base: float = _baseline(i)
		var box: Rect2 = Rect2(Vector2(x, base - font.get_ascent(_px)),
			Vector2(wide, font.get_height(_px)))
		var drawn: Rect2 = slant * box
		out = drawn if i == 0 else out.merge(drawn)
	return out


func _baseline(i: int) -> float:
	return float(i) * float(_px) * LEADING + float(_px)


func _slant() -> Transform2D:
	var squash: float = squash_for(lie)
	return Transform2D(Vector2(1.0, 0.0), Vector2(shear, squash),
		Vector2(-shear * size.y * 0.5, size.y * (1.0 - squash) * 0.5))


func set_lines(text_lines: PackedStringArray) -> void:
	lines = text_lines
	_faces.clear()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_faces.clear()


## The line as it is carved: upper case in Latin script.
func carved_text(line: String) -> String:
	return line if LeadlightTokens.is_zh() else line.to_upper()


## The face `text` is carved in: the carved role at full size, its tracking
## closed up (never below none) when a long count would not otherwise fit the
## slab, so a line is set tighter rather than cut, and never set smaller.
func face_for(text: String) -> Font:
	if _faces.has(text):
		return _faces[text]
	var face: FontVariation = LeadlightTokens.font(LeadlightTokens.ROLE_CARVED, _px)
	var wide: float = face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _px).x
	if size.x > 0.0 and wide > size.x:
		var tighter: FontVariation = face.duplicate() as FontVariation
		while wide > size.x and tighter.spacing_glyph > 0:
			tighter.spacing_glyph -= 1
			wide = tighter.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _px).x
		face = tighter
	_faces[text] = face
	return face


## How wide `text` is carved on this slab.
func carved_width(text: String) -> float:
	return face_for(text).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _px).x


func _draw() -> void:
	if lines.is_empty():
		return
	draw_set_transform_matrix(_slant())
	for i: int in range(lines.size()):
		var text: String = carved_text(lines[i])
		var font: Font = face_for(text)
		var at: Vector2 = Vector2(0.0, _baseline(i))
		if groove:
			draw_string_outline(font, at, text, align, size.x, _px, 5, Color(0.0, 0.0, 0.0, 0.62))
		draw_string(font, at + Vector2(0.0, -1.0), text, align, size.x, _px, Color(0, 0, 0, 0.85))
		draw_string(font, at + Vector2(0.0, 1.0), text, align, size.x, _px, Color(LeadlightTokens.PARCHMENT, 0.10))
		draw_string(font, at, text, align, size.x, _px, colour)
	draw_set_transform_matrix(Transform2D.IDENTITY)
