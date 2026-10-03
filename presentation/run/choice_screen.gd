class_name ChoiceScreen
extends Control
## One quiet glass panel for every non-combat decision. The application owns
## routing and domain mutation; this view only emits the selected id. The title
## is its own screen since 2026-10-02 (presentation/title/title_screen.gd).

signal chosen(id: String)

const GOLD: Color = Color("#f2c14e")
const PARCHMENT: Color = Color("#e8dfc8")
const BENCH_TEXT_DIM: Color = Color("#8b93ad")

## The panel as authored at the identity shape, and the fallbacks the book's
## `run` scope carries defaults for. Kept as named constants rather than magic
## numbers at the call site so the 1.0 column stays readable next to the book.
const PANEL_W: float = 520.0
const CARD_PANEL_W: float = 1080.0
const PANEL_INSET: float = 24.0
const PANEL_SCROLL: float = 420.0
const PANEL_FLOOR: float = 280.0
const COLUMN_GAP: float = 14.0
const TITLE_PT: float = 30.0
const BODY_PT: float = 18.0
const BUTTON_H: float = 48.0

## The stage shape this panel composes for, and its resolved `run` layout.
var shape: StringName = StageShape.IDENTITY

var _panel_layout: Dictionary = {}
var _first_button: Button = null
var _cancel_button: Button = null
var _panel: PanelContainer
var _frame: MarginContainer = null
var _centre: CenterContainer
var _column: VBoxContainer
var _scroll: ScrollContainer = null
var _card_mode: bool = false
var _card_pick: bool = false
## Card mode's cards: baked faces with one live card under the pointer (#657).
var _grid: CardGrid = null
var _sfx: SfxBus
## When set, Escape emits `chosen` with this id (safe cancel). Absent → Escape ignored.
var _cancel_id: String = ""
var _has_cancel: bool = false
## Overlay mode: scrim over a live routed surface instead of an opaque night ground.
var _overlay: bool = false


func _init(title_text: String, body_text: String, choices: Array[Dictionary],
		context: Dictionary = {}, sfx: SfxBus = null) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	var asked: StringName = StringName(str(context.get("shape", StageShape.IDENTITY)))
	shape = asked if StageShape.REFERENCES.has(asked) else StageShape.IDENTITY
	_panel_layout = LayoutBook.resolve(&"run", shape)
	_overlay = context.get("overlay", false) == true
	if context.has("cancel"):
		_has_cancel = true
		_cancel_id = str(context["cancel"])
	_card_mode = choices.any(func(row: Dictionary) -> bool: return row.has("card"))
	_card_pick = choices.any(func(row: Dictionary) -> bool:
		return row.has("card") and not row.get("disabled", false))
	_build_standard(title_text, body_text, choices)


func _build_standard(title_text: String, body_text: String,
		choices: Array[Dictionary]) -> void:

	var ground: ColorRect = ColorRect.new()
	ground.color = GlassStyle.scrim() if _overlay else GlassStyle.NIGHT_BOT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var k: float = _panel_num("scale", 1.0)
	var inset: float = _panel_num("inset", PANEL_INSET)

	# The old inner scroll opened on `choices.size() > 7`, which was a
	# choice-count guard for what is a viewport-height problem: measured at
	# 844x390, six plain choices make a 424px panel and seven make a 479px one,
	# both taller than the 390px stage, and neither tripped the guard. Seating
	# the complete panel in the same
	# ScrollContainer -> Margin -> Centre stack the other run screens use fixes
	# every count at once. The margin sits INSIDE the scroll so the scroll's
	# viewport is the whole stage: a panel that fits is still centred at exactly
	# the position it had before, and one that does not gains travel instead of
	# a clipped edge.
	var page: ScrollContainer = ScrollContainer.new()
	page.follow_focus = true
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	_frame = MarginContainer.new()
	var frame: MarginContainer = _frame
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seat_frame(inset)
	page.add_child(frame)

	_centre = CenterContainer.new()
	var centre: CenterContainer = _centre
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(_authored_panel_width(), 0.0)
	_panel.add_theme_stylebox_override("panel", GlassStyle.pane(GlassStyle.GLASS, 0.94))
	centre.add_child(_panel)

	_column = VBoxContainer.new()
	var column: VBoxContainer = _column
	column.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	_panel.add_child(column)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", GlassStyle.face(GlassStyle.CINZEL_700))
	title.add_theme_font_size_override("font_size", roundi(TITLE_PT * k))
	title.add_theme_color_override("font_color", GlassStyle.TEXT)
	column.add_child(title)

	if not body_text.is_empty():
		var body: Label = Label.new()
		body.text = body_text
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
		body.add_theme_font_size_override("font_size", roundi(BODY_PT * k))
		body.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
		column.add_child(body)

	if _card_mode:
		_build_card_grid(column, choices, k)
		return

	# Plain choices travel with the complete page. Keeping the old >7 inner
	# scroll under the new page scroll would make eight choices the exact point
	# at which wheel and touch input had two competing vertical owners.
	var button_column: VBoxContainer = column
	for row: Dictionary in choices:
		var button: Button = Button.new()
		button.text = str(row.get("label", row.get("id", "")))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = row.get("disabled", false)
		button.tooltip_text = str(row.get("hint", ""))
		button.custom_minimum_size.y = roundi(BUTTON_H * k)
		var icon_path: String = str(row.get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			button.icon = load(icon_path) as Texture2D
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", roundi(48.0 * k))
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = roundi(72.0 * k)
		GlassStyle.style_button(button, GlassStyle.EMBER if not row.get("quiet", false) else GlassStyle.GLASS)
		_wire_button(button, str(row.get("id", "")))
		button_column.add_child(button)


func _build_card_grid(column: VBoxContainer, choices: Array[Dictionary],
		k: float) -> void:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = _panel_num("scroll", PANEL_SCROLL)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_grid = CardGrid.new(choices, 16.0 * k)
	_grid.picked.connect(func(choice_id: String) -> void:
		_sfx.play(&"card")
		chosen.emit(choice_id)
	)
	_scroll.add_child(_grid)
	_apply_card_scale()

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	column.add_child(actions)
	for row: Dictionary in choices:
		if row.has("card"):
			continue
		var button: Button = _title_button(
			str(row.get("label", row.get("id", ""))),
			true if row.get("quiet", false) else false)
		button.custom_minimum_size.x = 180.0
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.disabled = row.get("disabled", false)
		_wire_button(button, str(row.get("id", "")))
		actions.add_child(button)


func _apply_card_scale() -> void:
	if _grid != null:
		_grid.set_card_scale(_card_scale())


func _card_scale() -> float:
	match shape:
		&"phone-landscape":
			return 0.89 if _card_pick else 0.84
		&"desktop-landscape":
			return 1.17 if _card_pick else 1.0
		_:
			return 0.99 if _card_pick else 0.87


func _title_button(text: String, quiet: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_700, 1))
	button.add_theme_font_size_override("font_size", 13 if quiet else 17)
	# Radius 8 GOLD ring is the canonical Theme default — no per-button
	# focus box. Custom-radius seats still push their own ring.
	button.add_theme_color_override("font_focus_color", PARCHMENT)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.055, 0.071, 0.133, 0.60 if quiet else 0.90)
		box.set_border_width_all(1)
		box.border_color = Color(GOLD, 0.28 if state == "normal" else 0.82)
		box.set_corner_radius_all(8)
		box.content_margin_left = 8.0 if quiet else 24.0
		box.content_margin_right = 8.0 if quiet else 24.0
		box.content_margin_top = 8.0
		box.content_margin_bottom = 8.0
		box.shadow_color = Color(0, 0, 0, 0.50)
		box.shadow_size = 6
		if state == "hover":
			box.shadow_color = Color(GOLD, 0.22)
			box.shadow_size = 12
		elif state == "pressed":
			box.bg_color = Color(0.035, 0.045, 0.090, 0.90)
		elif state == "disabled":
			box.border_color = Color(GOLD, 0.12)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color("#fff3d6"))
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_color_override("font_disabled_color", Color(BENCH_TEXT_DIM, 0.45))
	return button


static func _tracked_font(path: String, glyph_spacing: int) -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = GlassStyle.face(path)
	tracked.spacing_glyph = glyph_spacing
	return tracked


func _wire_button(button: Button, id: String) -> void:
	button.pressed.connect(func() -> void:
		_sfx.play(&"click")
		chosen.emit(id)
	)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_sfx.play(&"hover", 0.45)
	)
	if _first_button == null and not button.disabled:
		_first_button = button
	if _cancel_button == null and id == _cancel_id and not _cancel_id.is_empty():
		_cancel_button = button


## Optional safe cancel: context key `"cancel"` maps Escape onto that choice id.
## Absent key → Escape does nothing (must-choose dialogs).
func _unhandled_key_input(event: InputEvent) -> void:
	if not _has_cancel:
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	chosen.emit(_cancel_id)
	get_viewport().set_input_as_handled()


func _ready() -> void:
	resized.connect(_fit)
	_fit()
	var focus: Button = _cancel_button if _cancel_button != null else _first_button
	if focus != null:
		focus.grab_focus()


## The panel's authored width, held inside what the stage can actually give it.
##
## This clamp already existed and already worked — it is the reason a narrow
## stage never had the panel hanging off both sides. What it could not do is
## know that a phone wants a NARROWER panel than the clamp alone would leave it
## with, or that the type inside should shrink too. The book supplies the
## authored width and the clamp keeps holding the floor and the ceiling.
func _fit() -> void:
	if _panel != null:
		var inset: float = _panel_num("inset", PANEL_INSET)
		_panel.custom_minimum_size.x = minf(_authored_panel_width(),
			maxf(PANEL_FLOOR, size.x - inset * 2.0))


func _panel_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_panel_layout.get(field), fallback)


## The panel's breathing room, held by the margin inside the page scroll rather
## than by the centre's offsets — a container's offsets are overwritten by its
## parent, so they stopped being the place to keep this the moment the centre
## gained one.
func _seat_frame(inset: float) -> void:
	if _frame == null:
		return
	for side: String in ["left", "top", "right", "bottom"]:
		_frame.add_theme_constant_override("margin_%s" % side, roundi(inset))


func _authored_panel_width() -> float:
	return CARD_PANEL_W if _card_mode else _panel_num("w", PANEL_W)


## Follow a re-pick. Only the numbers move — the panel keeps its buttons, its
## focus and its fade-in, because none of those depend on the shape.
func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_panel_layout = LayoutBook.resolve(&"run", shape)
	var k: float = _panel_num("scale", 1.0)
	var inset: float = _panel_num("inset", PANEL_INSET)
	_seat_frame(inset)
	if _column != null:
		_column.add_theme_constant_override("separation", roundi(COLUMN_GAP * k))
	if _scroll != null:
		_scroll.custom_minimum_size.y = _panel_num("scroll", PANEL_SCROLL)
	if _card_mode:
		_apply_card_scale()
	_fit()
