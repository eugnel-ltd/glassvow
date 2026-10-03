class_name LeadlightGhostWord
extends Control
## The word in flight (docs/design/2026-10-03-title-rooms §2.3): the word that
## was tapped lifts out of the road and rides to the room's crown, where it
## becomes the crown label, and rides back on leaving. Two labels, the word as
## it reads (Cinzel's small capitals in English) and the crown's capitals,
## cross over the last third of the flight; zh-Hant has no case to change.
## Draw-only and input-blind; its owner frees it on landing.

const CROSS_FROM: float = 0.66

var _from: Label
var _to: Label
var _start: Vector2 = Vector2.ZERO


## A flight from `from` (a word, or a crown) to `to`, or null when either is
## not a text control.
static func between(from: Control, to: Control) -> LeadlightGhostWord:
	var a: Label = _label_like(from)
	var b: Label = _label_like(to)
	if a == null or b == null:
		for label: Label in [a, b]:
			if label != null:
				label.free()
		return null
	var ghost: LeadlightGhostWord = LeadlightGhostWord.new()
	ghost.name = "GhostWord"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost._from = a
	ghost._to = b
	ghost._start = from.get_global_rect().get_center()
	ghost.add_child(a)
	ghost.add_child(b)
	return ghost


static func _label_like(source: Control) -> Label:
	if source == null or not is_instance_valid(source) or not ("text" in source):
		return null
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(source.get("text"))
	label.add_theme_font_override("font", source.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	label.add_theme_color_override("font_color", source.get_theme_color("font_color"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.6))
	label.size = label.get_combined_minimum_size()
	return label


## Half the word's extent in flight: the larger of the word and the crown, so
## what it passes is measured against the most it covers.
func half_extent() -> Vector2:
	var a: Vector2 = _from.get_combined_minimum_size()
	var b: Vector2 = _to.get_combined_minimum_size()
	var pa: float = float(_from.get_theme_font_size("font_size"))
	var pb: float = float(_to.get_theme_font_size("font_size"))
	# Each label is drawn scaled to the other's size at the far end.
	return Vector2(maxf(a.x * maxf(1.0, pb / pa), b.x * maxf(1.0, pa / pb)),
		maxf(a.y * maxf(1.0, pb / pa), b.y * maxf(1.0, pa / pb))) * 0.5


## Where along a straight flight from `from` to `to` (0..1) a word of `half`
## extent last overlaps `rect`, or -1 when it never does (§2.3: what the word
## crosses waits for it, so it never runs through lit text). Pure.
static func leaves_at(from: Vector2, to: Vector2, half: Vector2, rect: Rect2) -> float:
	var box: Rect2 = rect.grow_individual(half.x, half.y, half.x, half.y)
	var d: Vector2 = to - from
	var lo: float = 0.0
	var hi: float = 1.0
	for axis: int in range(2):
		var p: float = from[axis]
		var v: float = d[axis]
		var a: float = box.position[axis]
		var b: float = box.end[axis]
		if absf(v) < 0.0001:
			if p < a or p > b:
				return -1.0
			continue
		var t0: float = (a - p) / v
		var t1: float = (b - p) / v
		lo = maxf(lo, minf(t0, t1))
		hi = minf(hi, maxf(t0, t1))
		if lo > hi:
			return -1.0
	return hi


## The word `g` (0..1) of the way from `from_node` to `to_node`, each read
## where it stands now (a room still laying out moves its crown).
func fly(g: float, from_node: Control, to_node: Control) -> void:
	var start: Vector2 = from_node.get_global_rect().get_center() \
		if from_node != null and is_instance_valid(from_node) else _start
	var end: Vector2 = to_node.get_global_rect().get_center() \
		if to_node != null and is_instance_valid(to_node) else start
	var at: Vector2 = start.lerp(end, g) - get_global_rect().position
	var pa: float = float(_from.get_theme_font_size("font_size"))
	var pb: float = float(_to.get_theme_font_size("font_size"))
	var cross: float = smoothstep(CROSS_FROM, 1.0, g)
	_seat(_from, at, lerpf(1.0, pb / pa, g), 1.0 - cross)
	_seat(_to, at, lerpf(pa / pb, 1.0, g), cross)


static func _seat(label: Label, at: Vector2, scale_by: float, alpha: float) -> void:
	label.size = label.get_combined_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.position = at - label.size * 0.5
	label.scale = Vector2.ONE * scale_by
	label.modulate.a = alpha
