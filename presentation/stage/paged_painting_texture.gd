@tool
class_name PagedPaintingTexture
extends Texture2D
## Two physical uploads; logical dimensions and imported pixels stay unchanged.
## Polygon UVs reproduce the original crop clamp without clamping the page join.

@export var image_size: Vector2i = Vector2i.ZERO
@export var image_alpha: bool = false
@export var pages: Array[Texture2D] = []


func _get_width() -> int:
	return image_size.x


func _get_height() -> int:
	return image_size.y


func _has_alpha() -> bool:
	return image_alpha


func _draw_rect_region(item: RID, rect: Rect2, source: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if pages.size() != 2 or source.size.x <= 0.0 or source.size.y <= 0.0:
		return
	var split: int = image_size.y / 2
	var xs: PackedFloat64Array = _cuts(source.position.x, source.end.x, clip_uv)
	for page: int in range(2):
		var owner_begin: float = 0.0 if page == 0 else float(split)
		var owner_end: float = float(split) if page == 0 else float(image_size.y)
		var low: float = maxf(source.position.y, owner_begin)
		var high: float = minf(source.end.y, owner_end)
		if high <= low:
			continue
		var ys: PackedFloat64Array = _cuts(source.position.y, source.end.y, clip_uv, low, high)
		var start: float = 0.0 if page == 0 else split - 1.0
		var page_size: Vector2 = pages[page].get_size()
		for x: int in range(xs.size() - 1):
			for y: int in range(ys.size() - 1):
				var points: PackedVector2Array = []
				var uvs: PackedVector2Array = []
				for coordinate: Vector2 in [Vector2(xs[x], ys[y]), Vector2(xs[x + 1], ys[y]),
						Vector2(xs[x + 1], ys[y + 1]), Vector2(xs[x], ys[y + 1])]:
					var fraction: Vector2 = (coordinate - source.position) / source.size
					if transpose:
						fraction = Vector2(fraction.y, fraction.x)
					points.append(rect.position + fraction * rect.size)
					var sample: Vector2 = coordinate
					if clip_uv:
						sample.x = minf(maxf(sample.x, source.position.x + 0.5), source.end.x - 0.5)
						sample.y = minf(maxf(sample.y, source.position.y + 0.5), source.end.y - 0.5)
					uvs.append((sample - Vector2(0, start)) / page_size)
				RenderingServer.canvas_item_add_polygon(item, points,
					PackedColorArray([modulate, modulate, modulate, modulate]), uvs, pages[page].get_rid())


static func _cuts(begin: float, end: float, clip_uv: bool, low: float = -INF, high: float = INF) -> PackedFloat64Array:
	var first: float = maxf(begin, low)
	var last: float = minf(end, high)
	var out: PackedFloat64Array = [first]
	if clip_uv:
		for edge: float in [begin + 0.5, end - 0.5]:
			if edge > out[-1] and edge < last:
				out.append(edge)
	out.append(last)
	return out


func _draw_rect(item: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
	_draw_rect_region(item, rect, Rect2(Vector2.ZERO, Vector2(image_size)), modulate, transpose, false)


func _draw(item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	_draw_rect(item, Rect2(pos, Vector2(image_size)), false, modulate, transpose)
