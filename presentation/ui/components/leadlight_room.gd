class_name LeadlightRoom
extends LeadlightSheet
## A room in the same house: the leaded arched window of LeadlightSheet holding
## a title in its crown, its section panes (one lit at a time) in a column at
## the left or, on a phone's short glass, across the top, the lit section's
## page, and a footer. Every section's controls are built up front and stay in
## the tree, so keyboard order is the order they read; only the lit page shows.
##
## A section change is a passage of its own (docs/design/2026-10-03-title-rooms
## §5.2, G3): the page leaving fades, the page arriving rises 6 px into place
## (or slides in from a phone swipe's side), and a glint runs along the lead
## from the pane to the page. A new choice retargets at once. Under Reduce
## Motion it is a 150 ms cross-fade.

## Any section shown (a press, a key or code).
signal section_selected(id: StringName)
## A section chosen by the player (its pane pressed): the room's sound.
signal section_chosen(id: StringName)

const OUT_TIME: float = 0.10
const IN_FROM: float = 0.02
const IN_TIME: float = 0.20
const GLINT_FROM: float = 0.04
const GLINT_TIME: float = 0.18
const RISE: float = 6.0
const SLIDE: float = 12.0

var _title: Label
var _tabs: BoxContainer
var _name_line: Label = null
var _pages: MarginContainer
var _scroll: ScrollContainer
var _footer: VBoxContainer
var _tab_by_id: Dictionary = {}
var _page_by_id: Dictionary = {}
var _name_by_id: Dictionary = {}
var _shape: StringName = StageShape.IDENTITY
var _across: bool = false
var _tab_width: float = 150.0
var _change: Tween = null
## The glint's progress along the lead, 0..1; below 0 when none runs.
var _glint: float = -1.0
var _glint_from: Vector2 = Vector2.ZERO
var _glint_to: Vector2 = Vector2.ZERO


## `across`: the panes stand in a row over the page, the lit section's name
## beside them (a phone's How to Play).
func _init(title_text: String, stage_shape: StringName = StageShape.IDENTITY,
		across: bool = false) -> void:
	super()
	_shape = stage_shape
	_across = across
	spring = 0.14
	var phone: bool = LeadlightTokens.is_phone(stage_shape)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10 if not phone else 6)
	content().add_child(column)
	# The title sits in the arch's crown, not in the column below it.
	_title = Label.new()
	_title.name = "Crown"
	_title.text = title_text if LeadlightTokens.is_zh() else title_text.to_upper()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_CROWN, stage_shape)
	_title.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, px))
	_title.add_theme_font_size_override("font_size", px)
	_title.add_theme_color_override("font_color", LeadlightTokens.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var body: BoxContainer = VBoxContainer.new() if across else HBoxContainer.new()
	body.add_theme_constant_override("separation", (22 if not phone else 14) if not across else 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	if across:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		_tabs = HBoxContainer.new()
		_tabs.add_theme_constant_override("separation", 4)
		row.add_child(_tabs)
		_name_line = Label.new()
		_name_line.name = "SectionName"
		var name_px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, stage_shape)
		_name_line.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, name_px))
		_name_line.add_theme_font_size_override("font_size", name_px)
		_name_line.add_theme_color_override("font_color", LeadlightTokens.GOLD)
		_name_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_line.size_flags_vertical = Control.SIZE_FILL
		_name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_line.clip_text = true
		_name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_name_line)
	else:
		_tabs = VBoxContainer.new()
		_tabs.add_theme_constant_override("separation", 8 if not phone else 4)
		body.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	# The pages stand one over another, so two can show while they cross.
	_pages = MarginContainer.new()
	_pages.name = "Pages"
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	column.add_child(_footer)


## The least width of a section pane in the column.
func set_tab_width(width: float) -> void:
	_tab_width = width
	for pane_v: Variant in _tab_by_id.values():
		var pane: LeadlightPane = pane_v
		pane.custom_minimum_size.x = width


## A new section: its pane and its page. Returns the page. `pane_text`, when
## given, is the pane's own label (a numeral) in place of the heading.
func add_section(id: StringName, heading: String,
		accent: Color = LeadlightTokens.GOLD, pane_text: String = "") -> VBoxContainer:
	var phone: bool = LeadlightTokens.is_phone(_shape)
	var label: String = pane_text if not pane_text.is_empty() else heading
	var tab: LeadlightPane = LeadlightPane.new(
		label if LeadlightTokens.is_zh() else label.to_upper(), _shape,
		LeadlightGlassBox.Shape.LOZENGE if _across else LeadlightGlassBox.Shape.TAB)
	tab.name = "Section%s" % String(id).capitalize().replace(" ", "")
	tab.accent = accent
	tab.alignment = HORIZONTAL_ALIGNMENT_CENTER if _across else HORIZONTAL_ALIGNMENT_LEFT
	tab.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, _shape))
	var hit: float = LeadlightTokens.room_hit(_shape)
	if _across:
		tab.custom_minimum_size = Vector2(hit, hit)
	else:
		tab.custom_minimum_size = Vector2(_tab_width, hit - 8.0 if not phone else hit - 4.0)
		tab.hit_height = hit
	tab.pressed.connect(_choose.bind(id))
	_tabs.add_child(tab)
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Page%s" % String(id).capitalize().replace(" ", "")
	page.add_theme_constant_override("separation", 2)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.visible = false
	_pages.add_child(page)
	_tab_by_id[id] = tab
	_page_by_id[id] = page
	_name_by_id[id] = heading
	if _tab_by_id.size() == 1:
		tab.lit = true
		page.visible = true
		if _name_line != null:
			_name_line.text = heading
	return page


func footer() -> VBoxContainer:
	return _footer


func scroll() -> ScrollContainer:
	return _scroll


## The label in the arch's crown (where the word that opened the room lands).
func crown() -> Label:
	return _title


func tab(id: StringName) -> LeadlightPane:
	return _tab_by_id.get(id, null)


func page(id: StringName) -> VBoxContainer:
	return _page_by_id.get(id, null)


func section_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id_v: Variant in _tab_by_id:
		ids.append(StringName(str(id_v)))
	return ids


## The column (or row) of section panes.
func tabs() -> Control:
	return _tabs


## Light section `id` at once, with no passage: its pane lit, its page shown,
## scrolled to the top.
func select(id: StringName) -> void:
	if tab(id) == null:
		return
	_show(id, false)


## The section after (`step` 1) or before (-1) the lit one, as a swipe asks:
## the page slides in from that side.
func step_section(step: int) -> void:
	var ids: Array[StringName] = section_ids()
	var at: int = ids.find(selected())
	var next: int = clampi(at + step, 0, ids.size() - 1)
	if next != at:
		_choose(ids[next], float(step))


func selected() -> StringName:
	for id_v: Variant in _tab_by_id:
		var pane: LeadlightPane = _tab_by_id[id_v]
		if pane.lit:
			return StringName(str(id_v))
	return &""


func _choose(id: StringName, slide: float = 0.0) -> void:
	if id == selected():
		return
	section_chosen.emit(id)
	_show(id, true, slide)


func _show(id: StringName, animate: bool, slide: float = 0.0) -> void:
	var was: StringName = selected()
	for id_v: Variant in _tab_by_id:
		var pane: LeadlightPane = _tab_by_id[id_v]
		pane.lit = StringName(str(id_v)) == id
	if _name_line != null:
		_name_line.text = str(_name_by_id.get(id, ""))
	if _change != null and _change.is_valid():
		_change.kill()
	_change = null
	_glint = -1.0
	var arriving: Control = _page_by_id[id]
	var leaving: Control = _page_by_id.get(was, null) if was != id else null
	for page_v: Variant in _page_by_id.values():
		var other: Control = page_v
		if other != arriving and other != leaving:
			_rest(other, false)
	_scroll.scroll_vertical = 0
	section_selected.emit(id)
	if not animate or leaving == null or not is_inside_tree():
		_rest(arriving, true)
		if leaving != null:
			_rest(leaving, false)
		return
	arriving.visible = true
	arriving.modulate.a = 0.0
	_change = create_tween().set_parallel()
	if LeadlightMotion.reduced():
		_change.tween_property(leaving, "modulate:a", 0.0, LeadlightMotion.REDUCED_FADE)
		_change.tween_property(arriving, "modulate:a", 1.0, LeadlightMotion.REDUCED_FADE)
	else:
		_change.tween_property(leaving, "modulate:a", 0.0, OUT_TIME) \
			.set_trans(LeadlightMotion.EXIT.x as Tween.TransitionType) \
			.set_ease(LeadlightMotion.EXIT.y as Tween.EaseType)
		_change.tween_property(arriving, "modulate:a", 1.0, IN_TIME).set_delay(IN_FROM) \
			.set_trans(LeadlightMotion.REVEAL.x as Tween.TransitionType) \
			.set_ease(LeadlightMotion.REVEAL.y as Tween.EaseType)
		var axis: String = "position:x" if slide != 0.0 else "position:y"
		var offset: float = SLIDE * signf(slide) if slide != 0.0 else RISE
		var seat: float = 0.0
		_change.tween_property(arriving, axis, seat, IN_TIME).from(seat + offset).set_delay(IN_FROM) \
			.set_trans(LeadlightMotion.REVEAL.x as Tween.TransitionType) \
			.set_ease(LeadlightMotion.REVEAL.y as Tween.EaseType)
		var pane: LeadlightPane = _tab_by_id[id]
		_start_glint(pane)
		_change.tween_method(_set_glint, 0.0, 1.0, GLINT_TIME).set_delay(GLINT_FROM)
	_change.chain().tween_callback(func() -> void:
		_rest(leaving, false)
		_rest(arriving, true)
		_glint = -1.0
		queue_redraw())


## A page at rest: shown whole in its seat, or hidden.
func _rest(page_node: Control, shown: bool) -> void:
	page_node.visible = shown
	page_node.modulate.a = 1.0
	page_node.position = Vector2.ZERO


## Whether a section change is running now.
func changing() -> bool:
	return _change != null and _change.is_valid() and _change.is_running()


func _start_glint(pane: Control) -> void:
	var pane_rect: Rect2 = Rect2(pane.global_position - global_position, pane.size)
	var pages_at: Vector2 = _pages.global_position - global_position
	if _across:
		_glint_from = Vector2(pane_rect.get_center().x, pane_rect.end.y + 4.0)
		_glint_to = Vector2(pane_rect.get_center().x, pages_at.y + 24.0)
	else:
		_glint_from = Vector2(pane_rect.end.x + 2.0, pane_rect.get_center().y)
		_glint_to = Vector2(pages_at.x + 24.0, pane_rect.get_center().y)
	_glint = 0.0


func _set_glint(t: float) -> void:
	_glint = t
	queue_redraw()


func _draw() -> void:
	super()
	if _glint < 0.0:
		return
	# One glint along the lead from the pane to its page.
	var t: float = LeadlightMotion.ease_on(_glint, LeadlightMotion.SETTLE_OUT)
	var at: Vector2 = _glint_from.lerp(_glint_to, t)
	var a: float = sin(_glint * PI)
	draw_line(_glint_from, at, Color(LeadlightTokens.GOLD, 0.35 * a), 1.2, true)
	var r: float = 6.0
	draw_texture_rect(SkyField.disc(), Rect2(at - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false,
		Color(light_colour.lerp(Color.WHITE, 0.5), 0.75 * a))
	draw_line(at - Vector2(r * 1.8, 0.0), at + Vector2(r * 1.8, 0.0), Color(1, 1, 1, 0.45 * a), 1.0)


## Contents below the arch's spring; the title centred in its crown.
func _seat() -> void:
	super()
	var top: int = int(size.y * spring + 12.0)
	content().add_theme_constant_override("margin_top", top)
	if _title != null:
		var tall: float = _title.get_combined_minimum_size().y
		_title.position = Vector2(0.0, maxf(size.y * spring * 0.55 - tall * 0.5, 2.0))
		_title.size = Vector2(size.x, 0.0)
