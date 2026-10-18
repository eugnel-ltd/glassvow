@tool
class_name TitlePaintingTexture
extends Texture2D
## The original title painting as two independent bounded uploads. Each page
## carries one original-neighbor row so inherited linear filtering reads the
## same pixels across the join. TextureRect still owns cover/crop and alpha.

@export var pages: Array[Texture2D] = []


func _get_width() -> int:
	return 1536


func _get_height() -> int:
	return 1024


func _has_alpha() -> bool:
	return false


func _draw_rect_region(item: RID, rect: Rect2, source: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	for index: int in range(2):
		var low: float = maxf(source.position.y, index * 512.0)
		var high: float = minf(source.end.y, (index + 1) * 512.0)
		if high <= low:
			continue
		var draw: Rect2 = rect
		var axis: int = 0 if transpose else 1
		var position: Vector2 = draw.position
		var size: Vector2 = draw.size
		position[axis] += (low - source.position.y) / source.size.y * rect.size[axis]
		size[axis] = (high - low) / source.size.y * rect.size[axis]
		draw.position = position
		draw.size = size
		var page_start: float = 511.0 if index == 1 else 0.0
		var region: Rect2 = Rect2(source.position.x, low - page_start, source.size.x, high - low)
		pages[index].draw_rect_region(item, draw, region, modulate, transpose, clip_uv)


func _draw_rect(item: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
	_draw_rect_region(item, rect, Rect2(0, 0, 1536, 1024), modulate, transpose, false)


func _draw(item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(item, Rect2(pos, Vector2(1536, 1024)), false, modulate, transpose)
