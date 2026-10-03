class_name HelpScreen
extends LeadlightRoomHost
## How to Play: seven panes of one window (docs/design/2026-10-03-title-rooms
## §4.2). A glass room in the same house as Settings, lit from the seat: the
## seven sections are panes in a column, each with its carved numeral and its
## title up to the dash, and the lit one's page stands beside them, its heading
## whole. On a phone's short glass the panes are numerals across the top with
## the lit section's name beside them, and a swipe across the page turns it.
## Every page fits its glass at pad; each still sits in a scroll, opened at 0.
##
## The Lantern's page keeps the Flame codex under its rules (flame lock §10):
## each colour this Vigil has seen steady, one to a line, beside a small flame
## of that colour, shown and never named. Two pages are alive: the Glass page's
## facets chip and refill, the Lantern page's ember flies into its lantern.
##
## A page's text is shaped as it enters the tree, so the room is built with
## its lit page only, and each other page on its first showing: seven pages at
## once made its tap frame 34 to 35 ms on the iPad 8, over §11.6's 33.

const SECTION_IDS: Array[StringName] = [&"road", &"combat", &"glass", &"lantern", &"ward",
	&"fires", &"vigil"]
## The room on the identity stage (§3.2): its centre this far right of the
## stage's, from 22 px under the top to 66 px over the foot (the seat's word).
const ROOM_W: float = 832.0
const ROOM_SHIFT: float = 142.0
const ROOM_TOP: float = 22.0
const ROOM_FOOT: float = 66.0
const TAB_W: float = 264.0
const TAB_H: float = 64.0
const PHONE_LEFT: float = 108.0
const PHONE_RIGHT: float = 6.0
const PHONE_TOP: float = 6.0
const PHONE_FOOT: float = 60.0
## A swipe across a phone's page that turns it.
const SWIPE: float = 60.0


static func _sections(act_count: int, lantern_coda: String = "") -> Array[Dictionary]:
	var params: Dictionary = {"count": act_count}
	return [
		{"title": Locale.active.t("ui.help.roadTitle"),
			"body": Locale.active.t("ui.help.roadBody", params)},
		{"title": Locale.active.t("ui.help.combatTitle"),
			"body": Locale.active.t("ui.help.combatBody")},
		{"title": Locale.active.t("ui.help.glassTitle"),
			"body": Locale.active.t("ui.help.glassBody")},
		{"title": Locale.active.t("ui.help.lanternTitle"),
			"body": Locale.active.t("ui.help.lanternBody"), "coda": lantern_coda},
		{"title": Locale.active.t("ui.help.wardTitle"),
			"body": Locale.active.t("ui.help.wardBody")},
		{"title": Locale.active.t("ui.help.firesTitle"),
			"body": Locale.active.t("ui.help.firesBody")},
		{"title": Locale.active.t("ui.help.vigilTitle"),
			"body": Locale.active.t("ui.help.vigilBody")},
	]


## The Lantern's colour sentences this Vigil has revealed (flame lock §10), one
## to a line in the reader's language; empty until a colour is seen steady.
static func _lantern_coda(codex: Array[Dictionary]) -> String:
	var zh: bool = Locale.active.code == Locale.CODE_ZH_HANT
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in codex:
		lines.append(LineTable.text(row, zh))
	return "\n".join(lines)


## A section's title up to its dash (" — " in English, "——" in zh-Hant): the
## pane's name. The page heading carries the whole title.
static func short_title(title: String) -> String:
	for dash: String in [" — ", "——"]:
		var at: int = title.find(dash)
		if at > 0:
			return title.substr(0, at)
	return title


## The flame colour a codex row describes (its slot names the flame).
static func codex_colour(row: Dictionary) -> Color:
	var slot: String = str(row.get("slot", ""))
	var flame: String = slot.trim_prefix(FlameLines.CODEX_PREFIX)
	return LanternFlame.COLOUR.get(flame, LeadlightTokens.EMBER)


## The codex's flames: one beside each line of the Coda, in its colour,
## breathing (2.8 s). Drawn over the Coda's own left margin.
class CodaFlames extends Control:
	var colours: Array[Color] = []
	var _time: float = 0.0

	func _process(delta: float) -> void:
		if LeadlightMotion.reduced():
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var coda: RichTextLabel = get_parent() as RichTextLabel
		if coda == null:
			return
		var px: float = float(coda.get_theme_font_size("normal_font_size"))
		for i: int in colours.size():
			var top: float = coda.get_theme_stylebox("normal").content_margin_top \
				+ (coda.get_paragraph_offset(i) if i < coda.get_paragraph_count() else 0.0)
			var breath: float = 1.0 + 0.12 * LeadlightMotion.breath(_time + float(i) * 0.7, 2.8)
			var w: float = px * 0.62 * breath
			var h: float = px * 0.95 * breath
			var at: Vector2 = Vector2(4.0 + px * 0.31 - w * 0.5, top + px * 0.6 - h * 0.5)
			var flame: PackedVector2Array = PackedVector2Array()
			for k: int in range(17):
				var t: float = float(k) / 16.0 * TAU
				var x: float = sin(t) * w * 0.42
				var y: float = h * 0.62 - cos(t) * h * 0.36
				if cos(t) > 0.0:
					y -= cos(t) * h * 0.22
					x *= 1.0 - cos(t) * 0.45
				flame.append(at + Vector2(w * 0.5 + x, y))
			draw_texture_rect(SkyField.disc(), Rect2(at - Vector2(w, h * 0.4), Vector2(w * 3.0, h * 1.8)),
				false, Color(colours[i], 0.40))
			draw_colored_polygon(flame, colours[i].lerp(Color.WHITE, 0.3))


## The Glass page, alive: five facets, one chipping every 2.4 s until the glass
## shatters and the row refills. Still under Reduce Motion.
class FacetRow extends Control:
	var _time: float = 0.0

	func _process(delta: float) -> void:
		if LeadlightMotion.reduced():
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var chipped: int = int(_time / 2.4) % 6
		var w: float = 34.0
		for i: int in range(5):
			var rect: Rect2 = Rect2(Vector2(4.0 + float(i) * (w + 8.0), 8.0), Vector2(w, 18.0))
			var lit: bool = i >= chipped
			var body: PackedVector2Array = LeadlightShapes.lozenge(rect, 7.0)
			draw_colored_polygon(body, Color(LeadlightTokens.GLASS, 0.55) if lit else Color(LeadlightTokens.FOG, 0.9))
			body.append(body[0])
			draw_polyline(body, LeadlightTokens.LEAD, 2.0, true)
			if not lit:
				draw_line(rect.position + Vector2(w * 0.35, 3.0), rect.end - Vector2(w * 0.4, 4.0),
					Color(LeadlightTokens.GLASS, 0.6), 1.0, true)


## The Lantern page, alive: every 4 s an ember flies along a short arc into a
## lantern (ring, roof, glass, base, in lead) and its glass brightens. Still
## under Reduce Motion.
class EmberFlight extends Control:
	var _time: float = 0.0

	func _process(delta: float) -> void:
		if LeadlightMotion.reduced():
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var u: float = fmod(_time, 4.0) / 1.4
		var glass: Rect2 = Rect2(Vector2(170.0, 14.0), Vector2(20.0, 22.0))
		var lift: float = 0.0 if u < 1.0 else clampf(1.0 - (u - 1.0) * 0.6, 0.0, 1.0)
		var c: Vector2 = glass.get_center()
		draw_texture_rect(SkyField.disc(), glass.grow(10.0 + 8.0 * lift), false,
			Color(LeadlightTokens.EMBER, 0.18 + 0.35 * lift))
		var body: PackedVector2Array = LeadlightShapes.lozenge(glass, 5.0)
		draw_colored_polygon(body, Color(LeadlightTokens.GOLD, 0.25 + 0.5 * lift))
		body.append(body[0])
		draw_polyline(body, LeadlightTokens.LEAD, 2.0, true)
		# The roof, the ring it hangs by, and the base.
		var roof: PackedVector2Array = PackedVector2Array([glass.position + Vector2(-3.0, 0.0),
			Vector2(c.x, glass.position.y - 9.0), Vector2(glass.end.x + 3.0, glass.position.y)])
		draw_polyline(roof, LeadlightTokens.LEAD, 2.5, true)
		draw_polyline(roof, Color(LeadlightTokens.GOLD_DIM, 0.8), 1.0, true)
		draw_arc(Vector2(c.x, glass.position.y - 12.0), 3.0, 0.0, TAU, 12, Color(LeadlightTokens.GOLD_DIM, 0.9), 1.2, true)
		draw_line(Vector2(glass.position.x - 1.0, glass.end.y + 2.0), Vector2(glass.end.x + 1.0, glass.end.y + 2.0),
			Color(LeadlightTokens.GOLD_DIM, 0.8), 2.5, true)
		if u < 1.0:
			var from: Vector2 = Vector2(8.0, 34.0)
			var at: Vector2 = from.lerp(c, u) + Vector2(0.0, -sin(u * PI) * 18.0)
			draw_texture_rect(SkyField.disc(), Rect2(at - Vector2(7.0, 7.0), Vector2(14.0, 14.0)), false,
				Color(LeadlightTokens.EMBER, 0.8 * sin(u * PI)))


var _sfx: SfxBus
var _room: LeadlightRoom
var _codex: Array[Dictionary] = []
var _coda: RichTextLabel = null
## The sections whose pages are not built yet, by id.
var _unbuilt: Dictionary[StringName, Dictionary] = {}
var _swipe_from: Vector2 = Vector2.INF


func _init(stage_shape: StringName = StageShape.IDENTITY,
		sfx: SfxBus = null, codex: Array[Dictionary] = []) -> void:
	_host(stage_shape)
	_codex = codex
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	_build()


func _build() -> void:
	var codex: Array[Dictionary] = _codex
	var phone: bool = LeadlightTokens.is_phone(shape)
	_room = LeadlightRoom.new(Locale.active.t("ui.help.title"), shape, phone)
	_room.name = "HelpRoom"
	_room.section_chosen.connect(func(_id: StringName) -> void: _sfx.play_owed(&"paneChoose", &"click"))
	add_child(_room)
	if not phone:
		_room.set_tab_width(TAB_W)
	var sections: Array[Dictionary] = _sections(3, _lantern_coda(codex))
	_unbuilt.clear()
	for i: int in sections.size():
		_add_section(i, sections[i])
	_room.section_selected.connect(_fill)
	_fill(_room.selected())
	_room.scroll().gui_input.connect(_on_page_input)
	_seat_last()


## A section's pane, and its page still empty (`_fill` builds it).
func _add_section(i: int, section: Dictionary) -> void:
	var id: StringName = SECTION_IDS[i]
	var numeral: String = LeadlightNumerals.carved(i + 1)
	var title: String = str(section["title"])
	var phone: bool = LeadlightTokens.is_phone(shape)
	var pane_text: String = numeral if phone else "%s  %s" % [numeral, short_title(title)]
	var page_node: VBoxContainer = _room.add_section(id, short_title(title), LeadlightTokens.GOLD,
		pane_text, false)
	page_node.add_theme_constant_override("separation", 10 if not phone else 6)
	var pane: LeadlightPane = _room.tab(id)
	if not phone:
		pane.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pane.custom_minimum_size.y = TAB_H
		pane.hit_height = TAB_H
	_unbuilt[id] = section


## Section `id`'s page, built the first time it is about to show.
func _fill(id: StringName) -> void:
	if not _unbuilt.has(id):
		return
	var section: Dictionary = _unbuilt[id]
	_unbuilt.erase(id)
	var numeral: String = LeadlightNumerals.carved(SECTION_IDS.find(id) + 1)
	var title: String = str(section["title"])
	var page_node: VBoxContainer = _room.page(id)
	# The heading is the whole title: its name, and what follows the dash as a
	# quieter line under it (tracked capitals would split a zh-Hant "——").
	var name_text: String = short_title(title)
	var heading: Label = Label.new()
	heading.name = "Heading"
	heading.text = "%s · %s" % [numeral, name_text if LeadlightTokens.is_zh() else name_text.to_upper()]
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var head_px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_HEAD, shape)
	heading.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, head_px))
	heading.add_theme_font_size_override("font_size", head_px)
	heading.add_theme_color_override("font_color", LeadlightTokens.GOLD)
	page_node.add_child(heading)
	var rest: String = title.substr(name_text.length()).lstrip(" —").strip_edges()
	if not rest.is_empty():
		var subtitle: Label = Label.new()
		subtitle.name = "Subtitle"
		subtitle.text = rest
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var read_px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_READ, shape)
		subtitle.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, read_px))
		subtitle.add_theme_font_size_override("font_size", read_px)
		subtitle.add_theme_color_override("font_color", Color(LeadlightTokens.GOLD, 0.72))
		page_node.add_child(subtitle)
	var body: RichTextLabel = _prose(LeadlightTokens.TEXT, true, shape)
	body.name = "Body"
	body.text = _markup(str(section["body"]), shape)
	page_node.add_child(body)
	if id == &"glass":
		page_node.add_child(_diagram(FacetRow.new(), "FacetRow"))
	var coda: String = str(section.get("coda", ""))
	if not coda.is_empty():
		_add_coda(page_node, coda, _codex)
	if id == &"lantern":
		page_node.add_child(_diagram(EmberFlight.new(), "EmberFlight"))


## Plain text, never markup: the coda is authored copy in the hearth's warmer
## ink, a breath below the rules it follows, each line beside its flame.
func _add_coda(page_node: VBoxContainer, coda: String, codex: Array[Dictionary]) -> void:
	_coda = _prose(LeadlightTokens.PARCHMENT, false, shape)
	_coda.name = "Coda"
	_coda.text = coda
	var margin: StyleBoxEmpty = StyleBoxEmpty.new()
	margin.content_margin_left = float(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_READ, shape)) + 12.0
	_coda.add_theme_stylebox_override("normal", margin)
	var flames: CodaFlames = CodaFlames.new()
	flames.name = "CodaFlames"
	flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flames.set_anchors_preset(Control.PRESET_FULL_RECT)
	for row: Dictionary in codex:
		flames.colours.append(codex_colour(row))
	_coda.add_child(flames)
	var breath: MarginContainer = MarginContainer.new()
	breath.add_theme_constant_override("margin_top", 4)
	breath.add_child(_coda)
	page_node.add_child(breath)


static func _diagram(diagram: Control, node_name: String) -> Control:
	diagram.name = node_name
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram.custom_minimum_size = Vector2(220.0, 42.0)
	return diagram


## The shipped bodies as markup: the energy glyph (a symbol face's taller line)
## set a little smaller so it stops stretching its line.
static func _markup(body_html: String, stage_shape: StringName) -> String:
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_READ, stage_shape)
	return body_html.replace("{count}", "3").replace("<b>", "[b]").replace("</b>", "[/b]") \
		.replace("⬤", "[font_size=%d]⬤[/font_size]" % roundi(float(px) * 0.78))


static func _prose(colour: Color, markup: bool, stage_shape: StringName) -> RichTextLabel:
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_READ, stage_shape)
	var prose: RichTextLabel = RichTextLabel.new()
	prose.bbcode_enabled = markup
	prose.fit_content = true
	prose.scroll_active = false
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.mouse_filter = Control.MOUSE_FILTER_PASS
	prose.add_theme_font_override("normal_font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	prose.add_theme_font_size_override("normal_font_size", px)
	prose.add_theme_font_override("bold_font", GlassStyle.face(GlassStyle.ALEGREYA_700,
		"res://assets/fonts/NotoSerifTC-SemiBold.woff2" if LeadlightTokens.is_zh() else ""))
	prose.add_theme_font_size_override("bold_font_size", px)
	prose.add_theme_color_override("default_color", colour)
	# Line height 1.45.
	prose.add_theme_constant_override("line_separation", roundi(float(px) * 0.45))
	return prose


func sheet() -> LeadlightSheet:
	return _room


func crown() -> Control:
	return _room.crown()


func reveal_groups() -> Array[Control]:
	return [_room.tabs(), _room.scroll()]


## The lit section's pane (the first, on arrival).
func first_focus() -> Control:
	return _room.tab(_room.selected())


## The glass stands over the title's wordmark: it goes with the furniture.
func covers_wordmark() -> bool:
	return true


func content_rects() -> Array[Rect2]:
	return [Rect2(_room.position, _room.size)]


func room() -> LeadlightRoom:
	return _room


## A new shape class (pad or phone) rebuilds the room on the lit section: the
## panes stand across a phone and in a column elsewhere.
func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape) \
			and LeadlightTokens.is_phone(stage_shape) != LeadlightTokens.is_phone(shape):
		var lit: StringName = _room.selected()
		shape = stage_shape
		for node: Node in [_room, _seat]:
			remove_child(node)
			node.free()
		_build()
		_room.select(lit)
	super(stage_shape)


## The room stands right of the seat (§3.2); on a phone it fills the stage
## beside the seat.
func _fit() -> void:
	if _room == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if LeadlightTokens.is_phone(shape):
		_room.position = Vector2(PHONE_LEFT, PHONE_TOP)
		_room.size = Vector2(size.x - PHONE_LEFT - PHONE_RIGHT, size.y - PHONE_TOP - PHONE_FOOT)
	else:
		_room.position = Vector2((size.x - ROOM_W) * 0.5 + ROOM_SHIFT, ROOM_TOP)
		_room.size = Vector2(ROOM_W, size.y - ROOM_TOP - ROOM_FOOT)


## A phone's swipe across the page turns it (a shortcut: the numerals stay).
func _on_page_input(event: InputEvent) -> void:
	if not LeadlightTokens.is_phone(shape):
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_swipe_from = button.position
		return
	if _swipe_from == Vector2.INF:
		return
	var moved: Vector2 = button.position - _swipe_from
	_swipe_from = Vector2.INF
	if absf(moved.x) >= SWIPE and absf(moved.x) > absf(moved.y) * 1.5:
		_room.step_section(-1 if moved.x > 0.0 else 1)
