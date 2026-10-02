class_name LeadlightGlassBox
extends StyleBox
## Leaded glass as a StyleBox, so a Button draws it UNDER its own label (a
## script `_draw` on a Button lands on top of the text; see ChoiceScreen's
## TitleFacetStyleBox). One box per state; the focus box draws the lantern
## ring around the same outline, so focus is an addition, never a repaint.

enum Shape { LOZENGE, TAB, RECT }

var shape: Shape = Shape.LOZENGE
var state: String = "normal"
## Lit glass: the gold-from-below pane of a chosen or primary control.
var lit: bool = false
## Chosen glass: still cold (it carries art and text), warmed a little, with a
## gold came — the selected card of a set.
var chosen: bool = false
var cut: float = 12.0
var accent: Color = LeadlightTokens.GOLD


static func make(box_shape: Shape, box_state: String, is_lit: bool,
		box_cut: float = 12.0, box_accent: Color = LeadlightTokens.GOLD) -> LeadlightGlassBox:
	var box: LeadlightGlassBox = LeadlightGlassBox.new()
	box.shape = box_shape
	box.state = box_state
	box.lit = is_lit
	box.cut = box_cut
	box.accent = box_accent
	box.content_margin_left = box_cut + 14.0
	box.content_margin_right = box_cut + 14.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


func outline(rect: Rect2) -> PackedVector2Array:
	match shape:
		Shape.LOZENGE:
			return LeadlightShapes.lozenge(rect, cut)
		Shape.TAB:
			var p: Vector2 = rect.position
			var s: Vector2 = rect.size
			var c: float = minf(cut * 0.8, s.y * 0.5)
			return PackedVector2Array([p, p + Vector2(s.x - c, 0.0), p + Vector2(s.x, s.y * 0.5),
				p + Vector2(s.x - c, s.y), p + Vector2(0.0, s.y)])
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])


func _draw(ci: RID, rect: Rect2) -> void:
	if state == "focus":
		var ring: PackedVector2Array = outline(rect.grow(3.0))
		ring.append(ring[0])
		RenderingServer.canvas_item_add_polyline(ci, ring,
			PackedColorArray([Color(accent, 0.95)]), 1.6, true)
		var halo: PackedVector2Array = outline(rect.grow(5.0))
		halo.append(halo[0])
		RenderingServer.canvas_item_add_polyline(ci, halo,
			PackedColorArray([Color(accent, 0.28)]), 3.0, true)
		return
	var pressed: bool = state == "pressed"
	var hover: bool = state == "hover"
	var disabled: bool = state == "disabled"
	var body: PackedVector2Array = outline(rect)
	var top: Color
	var bottom: Color
	if lit or pressed:
		top = Color("#c98d22").lerp(LeadlightTokens.GOLD, 0.35 if hover else 0.0)
		bottom = Color("#ffe9ac") if not pressed else LeadlightTokens.GOLD
	else:
		top = LeadlightTokens.GLASS_COLD_TOP.lerp(Color(accent, 1.0), 0.10 if hover else 0.0)
		bottom = LeadlightTokens.GLASS_COLD_BOTTOM.lerp(Color(accent, 1.0), 0.12 if chosen else 0.0)
	if disabled:
		top.a *= 0.45
		bottom.a *= 0.45
	var cols: PackedColorArray = PackedColorArray()
	for point: Vector2 in body:
		var t: float = clampf((point.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
		cols.append(top.lerp(bottom, t))
	RenderingServer.canvas_item_add_polygon(ci, body, cols)
	# The facet: one paler streak across the upper glass, as hand-blown glass has.
	if not disabled:
		var streak: PackedVector2Array = outline(Rect2(rect.position + Vector2(cut * 0.6, 2.0),
			Vector2(rect.size.x - cut * 1.2, rect.size.y * 0.36)))
		RenderingServer.canvas_item_add_polygon(ci, streak,
			PackedColorArray([Color(1.0, 1.0, 1.0, 0.07 if not lit else 0.18)]))
	var loop: PackedVector2Array = body.duplicate()
	loop.append(body[0])
	RenderingServer.canvas_item_add_polyline(ci, loop,
		PackedColorArray([LeadlightTokens.LEAD]), LeadlightTokens.LEAD_W + 0.5, true)
	var inner: PackedVector2Array = outline(rect.grow(-2.0))
	inner.append(inner[0])
	var line: Color = Color(accent, 0.85) if (hover or lit or chosen) else LeadlightTokens.LEAD_LINE
	if disabled:
		line.a *= 0.4
	RenderingServer.canvas_item_add_polyline(ci, inner, PackedColorArray([line]),
		2.0 if chosen else 1.0, true)
