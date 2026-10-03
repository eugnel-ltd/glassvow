class_name LeadlightInscription
extends Control
## Carved text: gold cut into dark stone, a shadow above and a glint below,
## foreshortened as if it lay on the road (`lie` 0 stands it up, 1 lays it
## nearly flat). The Vigil's deeds are inscriptions, not a stats line.

var lines: PackedStringArray = PackedStringArray()
var lie: float = 0.45
var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
var colour: Color = Color(LeadlightTokens.GOLD, 0.62)
## Perspective on the flagstones: the lines lean toward the road's vanishing
## point (left slab positive, right slab negative). 0 stands them square.
var shear: float = 0.0
## A dark groove cut round each letter, so carved gold reads on busy stone.
var groove: bool = false
var _px: int = 14
## Each line's face, fitted to the slab's width (see `face_for`).
var _faces: Dictionary = {}


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_px = LeadlightTokens.size_for(LeadlightTokens.SIZE_CARVED, stage_shape)


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
	var squash: float = 1.0 - clampf(lie, 0.0, 0.9) * 0.7
	var line_h: float = float(_px) * 1.6
	var slant: Transform2D = Transform2D(Vector2(1.0, 0.0), Vector2(shear, squash),
		Vector2(-shear * size.y * 0.5, size.y * (1.0 - squash) * 0.5))
	draw_set_transform_matrix(slant)
	for i: int in range(lines.size()):
		var text: String = carved_text(lines[i])
		var font: Font = face_for(text)
		var y: float = float(i) * line_h + float(_px)
		var at: Vector2 = Vector2(0.0, y)
		if groove:
			draw_string_outline(font, at, text, align, size.x, _px, 5, Color(0.0, 0.0, 0.0, 0.62))
		draw_string(font, at + Vector2(0.0, -1.0), text, align, size.x, _px, Color(0, 0, 0, 0.85))
		draw_string(font, at + Vector2(0.0, 1.0), text, align, size.x, _px, Color(LeadlightTokens.PARCHMENT, 0.10))
		draw_string(font, at, text, align, size.x, _px, colour)
	draw_set_transform_matrix(Transform2D.IDENTITY)
