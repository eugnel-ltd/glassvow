class_name VigilDeeds
extends ScrollContainer
## The Deeds look of the Vigil's hall (docs/design/2026-10-03-title-rooms
## §4.1): every deed a row carved in the firelight, with no box. A leaded
## roundel holds the deed's art, backlit by the fire once done and under cold
## glass until then; beside it the deed's name and its count, its description
## with what it gives, and along its foot a came lit to its progress. Every
## datum of every deed reads without a tap; the rows take none. One scroll in
## the hall's body box: its lines fade at its top and foot, and a lead rail
## with a gold bead marks the place.

## The roundel's side (pad, phone).
const ROUNDEL: Vector2 = Vector2(56.0, 44.0)

var shape: StringName = StageShape.IDENTITY
## The firelight's breath on the done roundels (the hall's flicker).
var glow: float = 1.0:
	set(value):
		glow = value
		# Redrawn only for a change the eye can see.
		if absf(glow - _drawn_glow) < 0.01:
			return
		_drawn_glow = glow
		for roundel: _Roundel in _roundels:
			if roundel.done:
				roundel.queue_redraw()
var _drawn_glow: float = 1.0

## The rail's own light, 0..1: it comes and goes with the rows (the passage).
var rail: float = 1.0:
	set(value):
		rail = value
		queue_redraw()

var _vigil: VigilState
var _content: ContentDB
var _list: VBoxContainer
var _rows: Array[Control] = []
var _bodies: Array[Control] = []
var _roundels: Array[_Roundel] = []
var _labels: Array[Label] = []


func _init(vigil: VigilState, content: ContentDB, ids: PackedStringArray,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	name = "Deeds"
	_vigil = vigil
	_content = content
	shape = stage_shape
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Without this the view never travels with keyboard focus (issue #72).
	follow_focus = true
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	add_child(_list)
	for id: String in ids:
		# A deed no offered class can pursue would sit at 0 for ever (#543).
		if ClassScope.shows_deed(_content, id):
			_add_deed(id)
	get_v_scroll_bar().value_changed.connect(func(_v: float) -> void:
		_fade_edges()
		queue_redraw())


## The rows, nearest the top first: each rises as the firelight reaches it.
func rows() -> Array[Control]:
	return _rows


func _add_deed(id: String) -> void:
	var deed_v: Variant = _content.deeds.get(id, {})
	if typeof(deed_v) != TYPE_DICTIONARY:
		return
	var deed: Dictionary = deed_v
	var current: int = maxi(0,
		int(float(str(_vigil.deeds.get(str(deed.get("stat")), 0)))))
	var target: int = maxi(1, int(float(str(deed.get("n", 1)))))
	var done: bool = current >= target
	var row: MarginContainer = MarginContainer.new()
	row.name = "Deed_%s" % id
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("margin_top", 8)
	row.add_theme_constant_override("margin_bottom", 4)
	row.add_theme_constant_override("margin_right", 18)
	_list.add_child(row)
	_rows.append(row)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	row.add_child(body)
	_bodies.append(body)
	var roundel: _Roundel = _Roundel.new()
	var art_path: String = "res://assets/art/deeds/%s.png" % id
	# A deed whose art is still owed (docs/art-ledger.md) keeps an empty roundel.
	roundel.art = load(art_path) as Texture2D if ResourceLoader.exists(art_path) else null
	roundel.done = done
	roundel.deeds = self
	roundel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(roundel)
	_roundels.append(roundel)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	body.add_child(text)
	var head: HBoxContainer = HBoxContainer.new()
	text.add_child(head)
	var name_label: Label = _label(str(deed.get("name", id)), LeadlightTokens.ROLE_LABEL,
		LeadlightTokens.SIZE_ROOM_LABEL, LeadlightTokens.GOLD if done else LeadlightTokens.PARCHMENT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	# A meter reads best in figures: whole numbers, never "2/3.0".
	head.add_child(_label("%d / %d" % [mini(current, target), target], LeadlightTokens.ROLE_LABEL,
		LeadlightTokens.SIZE_ROOM_LABEL, Color(LeadlightTokens.PARCHMENT, 0.78)))
	var rewards: String = _reward_names(deed.get("unlocks", []))
	var desc: Label = _label(str(deed.get("desc", "")) if rewards.is_empty()
		else "%s → %s" % [deed.get("desc", ""), rewards], LeadlightTokens.ROLE_READ,
		LeadlightTokens.SIZE_ROOM_READ, LeadlightTokens.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	var came: LeadlightCame = LeadlightCame.new()
	came.progress = float(mini(current, target)) / float(target)
	came.done = done
	came.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(came)


func _reward_names(unlocks_v: Variant) -> String:
	var names: PackedStringArray = []
	var unlocks: Array = unlocks_v if typeof(unlocks_v) == TYPE_ARRAY else []
	# A deferred class is never promised as a reward; the deed still counts.
	var withheld: Array[String] = ClassScope.withheld_unlocks(_content)
	for unlock_v: Variant in unlocks:
		var unlock: String = str(unlock_v)
		if withheld.has(unlock):
			continue
		if unlock == "aspect2":
			names.append(Locale.active.t("ui.vigil.ashwarden"))
			continue
		var bits: PackedStringArray = unlock.split(":", false, 1)
		if bits.size() != 2:
			names.append(unlock)
			continue
		var registry: Dictionary = _content.cards if bits[0] == "card" \
			else _content.relics
		names.append(str(registry.get(bits[1], {}).get("name", bits[1])))
	return ("、" if LeadlightTokens.is_zh() else ", ").join(names)


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	var side: float = ROUNDEL.y if LeadlightTokens.is_phone(shape) else ROUNDEL.x
	for roundel: _Roundel in _roundels:
		roundel.custom_minimum_size = Vector2(side, side)
	for label: Label in _labels:
		_size(label)
	_fade_edges()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fade_edges()


## Each row fades as the view's top or foot cuts it, by how much of it is
## left in view, so no row is ever seen cut through by the edge.
func _fade_edges() -> void:
	if not is_inside_tree():
		return
	var view: Rect2 = get_global_rect()
	for body: Control in _bodies:
		var at: Rect2 = body.get_global_rect()
		var shown: float = at.intersection(view).size.y / maxf(at.size.y, 1.0) if at.intersects(view) else 0.0
		body.modulate.a = pow(smoothstep(0.0, 1.0, shown), 1.5)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_fade_edges()


## The scroll's place: a lead rail at the box's right edge and a gold bead,
## only when the rows run past the box.
func _draw() -> void:
	var span: float = _list.size.y - size.y
	if span <= 1.0 or rail <= 0.0:
		return
	var x: float = size.x - 4.0
	draw_line(Vector2(x, 6.0), Vector2(x, size.y - 6.0), Color(LeadlightTokens.LEAD, 0.95 * rail), 3.0, true)
	draw_line(Vector2(x, 6.0), Vector2(x, size.y - 6.0), Color(LeadlightTokens.GOLD_DIM, 0.45 * rail), 1.0, true)
	var share: float = clampf(float(scroll_vertical) / span, 0.0, 1.0)
	var y: float = lerpf(14.0, size.y - 14.0, share)
	draw_circle(Vector2(x, y), 4.5, Color(LeadlightTokens.GOLD, 0.95 * rail))
	draw_circle(Vector2(x, y), 7.0, Color(LeadlightTokens.GOLD, 0.25 * rail))


func _label(text: String, role: StringName, token: Vector2i, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.set_meta(&"role", role)
	label.set_meta(&"token", token)
	label.add_theme_color_override("font_color", colour)
	_size(label)
	_labels.append(label)
	return label


func _size(label: Label) -> void:
	var token: Vector2i = label.get_meta(&"token")
	var role: StringName = label.get_meta(&"role")
	var px: int = LeadlightTokens.size_for(token, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(role, px))
	label.add_theme_font_size_override("font_size", px)


## A leaded roundel holding a deed's art: lit by the fire behind it once the
## deed is done; dim and under cold glass until then. No shader: the art is a
## textured polygon, the glass a fill over it.
class _Roundel extends Control:
	var art: Texture2D = null
	var done: bool = false
	var deeds: VigilDeeds = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(56.0, 56.0)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		if r < 2.0:
			return
		if done and deeds != null:
			var g: float = r * 1.7
			draw_texture_rect(SkyField.disc(), Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), false,
				Color(LeadlightTokens.EMBER, 0.30 * deeds.glow))
		var ring: PackedVector2Array = LeadlightShapes.arc_points(c, Vector2(r, r), 0.0, TAU, 33)
		ring.remove_at(ring.size() - 1)
		draw_colored_polygon(ring, Color(0.04, 0.05, 0.09, 0.95))
		if art != null:
			var uvs: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in ring:
				uvs.append((p - c) / (2.0 * r) + Vector2(0.5, 0.5))
			var k: float = (0.9 + 0.1 * deeds.glow) if done and deeds != null else 0.5
			draw_polygon(ring, PackedColorArray([Color(k, k, k, 1.0)]), uvs, art)
		if not done:
			draw_colored_polygon(ring, Color(0.09, 0.10, 0.17, 0.55))
		var closed: PackedVector2Array = ring.duplicate()
		closed.append(ring[0])
		draw_polyline(closed, LeadlightTokens.LEAD, 3.0, true)
		draw_polyline(closed, Color(LeadlightTokens.GOLD if done else LeadlightTokens.GOLD_DIM, 0.7), 1.0, true)
