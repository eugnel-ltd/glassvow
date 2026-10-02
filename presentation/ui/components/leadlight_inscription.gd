class_name LeadlightInscription
extends Control
## Carved text: gold cut into dark stone, a shadow above and a glint below,
## foreshortened as if it lay on the road (`lie` 0 stands it up, 1 lays it
## nearly flat). The Vigil's deeds are inscriptions, not a stats line.

var lines: PackedStringArray = PackedStringArray()
var lie: float = 0.45
var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
var colour: Color = Color(LeadlightTokens.GOLD, 0.62)
var _px: int = 14


func _init(stage_shape: StringName = StageShape.IDENTITY) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_px = LeadlightTokens.size_for(LeadlightTokens.SIZE_CARVED, stage_shape)


func set_lines(text_lines: PackedStringArray) -> void:
	lines = text_lines
	queue_redraw()


func _draw() -> void:
	if lines.is_empty():
		return
	var font: Font = LeadlightTokens.font(LeadlightTokens.ROLE_CARVED, _px)
	var squash: float = 1.0 - clampf(lie, 0.0, 0.9) * 0.7
	var line_h: float = float(_px) * 1.6
	draw_set_transform(Vector2(0.0, size.y * (1.0 - squash) * 0.5), 0.0, Vector2(1.0, squash))
	for i: int in range(lines.size()):
		var text: String = lines[i] if LeadlightTokens.is_zh() else lines[i].to_upper()
		var y: float = float(i) * line_h + float(_px)
		var at: Vector2 = Vector2(0.0, y)
		draw_string(font, at + Vector2(0.0, -1.0), text, align, size.x, _px, Color(0, 0, 0, 0.85))
		draw_string(font, at + Vector2(0.0, 1.0), text, align, size.x, _px, Color(LeadlightTokens.PARCHMENT, 0.10))
		draw_string(font, at, text, align, size.x, _px, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
