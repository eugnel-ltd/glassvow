class_name LeadlightCame
extends Control
## Progress as a came of lead (docs/design/2026-10-03-title-rooms §4.1): a
## 2 px lead line with a gold-dim line under it, lit gold up to the progress,
## with an ember at the tip that breathes; done, the whole came is white-gold
## and glows. One drawing for every came, so a deed's foot and a rose pane's
## rim read as the same lead: `draw_came` takes any path (a line, an arc).
## Draw-only and input-blind; still under Reduce Motion but for the tip's
## breath.

const LEAD_W: float = 2.0
const TIP_PERIOD: float = 2.8
const DONE: Color = Color("#fff1d0")

## 0..1 of the came lit.
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var done: bool = false:
	set(value):
		done = value
		queue_redraw()
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 8.0


func _process(delta: float) -> void:
	if LeadlightMotion.reduced() or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var y: float = size.y * 0.5
	draw_came(self, PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), progress, done, _time)


## The came along `path` (local px): the lead, its gold-dim line, the lit run
## to `lit` (0..1 of the path's length) and its ember, breathing on `time`.
static func draw_came(ci: CanvasItem, path: PackedVector2Array, lit: float, finished: bool,
		time: float) -> void:
	if path.size() < 2:
		return
	var under: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in path:
		under.append(p + Vector2(0.0, LEAD_W))
	ci.draw_polyline(path, Color(LeadlightTokens.LEAD, 0.92), LEAD_W + 1.0, true)
	ci.draw_polyline(under, Color(LeadlightTokens.GOLD_DIM, 0.55), 1.0, true)
	if finished:
		ci.draw_polyline(path, Color(DONE, 0.30), LEAD_W + 5.0, true)
		ci.draw_polyline(path, DONE, LEAD_W, true)
		return
	var run: PackedVector2Array = _run(path, clampf(lit, 0.0, 1.0))
	if run.size() < 2:
		return
	ci.draw_polyline(run, LeadlightTokens.GOLD, LEAD_W, true)
	var breath: float = 0.5 + 0.5 * LeadlightMotion.breath(time, TIP_PERIOD)
	var tip: Vector2 = run[run.size() - 1]
	var r: float = 4.0 + 2.0 * breath
	ci.draw_texture_rect(SkyField.disc(), Rect2(tip - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false,
		Color(LeadlightTokens.EMBER, 0.35 + 0.35 * breath))
	ci.draw_circle(tip, 1.8, Color(LeadlightTokens.EMBER.lerp(Color.WHITE, 0.4), 0.9))


## The first `share` of `path` by length. Pure.
static func _run(path: PackedVector2Array, share: float) -> PackedVector2Array:
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var left: float = total * share
	var out: PackedVector2Array = PackedVector2Array([path[0]])
	for i: int in range(1, path.size()):
		var leg: float = path[i - 1].distance_to(path[i])
		if leg >= left:
			if leg > 0.0:
				out.append(path[i - 1].lerp(path[i], left / leg))
			break
		out.append(path[i])
		left -= leg
	return out
