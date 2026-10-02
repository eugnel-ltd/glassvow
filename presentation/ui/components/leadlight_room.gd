class_name LeadlightRoom
extends LeadlightSheet
## A room in the same house: the leaded arched window of LeadlightSheet holding
## a title in its crown, a column of section panes (one lit at a time), the
## lit section's page, and a footer. Every section's controls are built up
## front and stay in the tree, so keyboard order is the order they read; only
## the lit page is shown.

signal section_selected(id: StringName)

var _title: Label
var _tabs: VBoxContainer
var _pages: Control
var _scroll: ScrollContainer
var _footer: VBoxContainer
var _tab_by_id: Dictionary = {}
var _page_by_id: Dictionary = {}
var _shape: StringName = StageShape.IDENTITY


func _init(title_text: String, stage_shape: StringName = StageShape.IDENTITY) -> void:
	super()
	_shape = stage_shape
	spring = 0.14
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	content().add_child(column)
	# The title sits in the arch's crown, not in the column below it.
	_title = Label.new()
	_title.text = title_text if LeadlightTokens.is_zh() else title_text.to_upper()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var px: int = 16 if not LeadlightTokens.is_phone(stage_shape) else 13
	_title.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, px))
	_title.add_theme_font_size_override("font_size", px)
	_title.add_theme_color_override("font_color", LeadlightTokens.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 22 if not LeadlightTokens.is_phone(stage_shape) else 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8 if not LeadlightTokens.is_phone(stage_shape) else 4)
	body.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_pages = VBoxContainer.new()
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	column.add_child(_footer)


## A new section: its pane in the column and its page. Returns the page.
func add_section(id: StringName, heading: String,
		accent: Color = LeadlightTokens.GOLD) -> VBoxContainer:
	var tab: LeadlightPane = LeadlightPane.new(
		heading if LeadlightTokens.is_zh() else heading.to_upper(), _shape, LeadlightGlassBox.Shape.TAB)
	tab.name = "Section%s" % String(id).capitalize().replace(" ", "")
	tab.accent = accent
	tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tab.set_px(13 if not LeadlightTokens.is_phone(_shape) else 11)
	tab.custom_minimum_size.x = 150.0 if not LeadlightTokens.is_phone(_shape) else 108.0
	tab.pressed.connect(_show.bind(id))
	_tabs.add_child(tab)
	var page: VBoxContainer = VBoxContainer.new()
	page.name = "Page%s" % String(id).capitalize().replace(" ", "")
	page.add_theme_constant_override("separation", 2)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.visible = false
	_pages.add_child(page)
	_tab_by_id[id] = tab
	_page_by_id[id] = page
	if _tab_by_id.size() == 1:
		tab.lit = true
		page.visible = true
	return page


func footer() -> VBoxContainer:
	return _footer


func scroll() -> ScrollContainer:
	return _scroll


func tab(id: StringName) -> LeadlightPane:
	return _tab_by_id.get(id, null)


## Light section `id`: its pane lit, its page shown, scrolled to the top.
func select(id: StringName) -> void:
	var pane: LeadlightPane = tab(id)
	if pane == null:
		return
	_show(id)


func selected() -> StringName:
	for id_v: Variant in _page_by_id:
		var page: Control = _page_by_id[id_v]
		if page.visible:
			return StringName(str(id_v))
	return &""


func _show(id: StringName) -> void:
	for id_v: Variant in _page_by_id:
		var page: Control = _page_by_id[id_v]
		page.visible = StringName(str(id_v)) == id
	for id_v: Variant in _tab_by_id:
		var pane: LeadlightPane = _tab_by_id[id_v]
		pane.lit = StringName(str(id_v)) == id
	_scroll.scroll_vertical = 0
	section_selected.emit(id)


## Contents below the arch's spring; the title centred in its crown.
func _seat() -> void:
	super()
	var top: int = int(size.y * spring + 12.0)
	content().add_theme_constant_override("margin_top", top)
	if _title != null:
		_title.position = Vector2(0.0, size.y * spring * 0.42)
		_title.size = Vector2(size.x, 0.0)
