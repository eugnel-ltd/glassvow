class_name ChoiceScreen
extends Control
## One quiet glass panel for every non-combat decision. The application owns
## routing and domain mutation; this view only emits the selected id. The title
## is its own screen since 2026-10-02 (presentation/title/title_screen.gd).

signal chosen(id: String)

const TITLE_BACKGROUND: String = "res://assets/art/title-background/background.png"
const TITLE_WORDMARK: String = "res://assets/art/title/title.png"
const TITLE_WORDMARK_ZH: String = "res://assets/art/title/title-zh.png"
const ROSE_MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const ROSE_FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const ROSE_MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const ROSE_PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")
const BANNER_SHADOW_SHADER: Shader = preload("res://presentation/run/drop_shadow.gdshader")

## The title banner, verbatim from `styles.css:341-343`: a plate held at 55% of
## the stage height and 90% of its width, seated 18% up from the bottom, the
## whole group at `opacity: 0.35`, and a `drop-shadow(0 12px 40px rgba(0,0,0,.6))`
## the port had never carried.
const BANNER_ALPHA: float = 0.35
const BANNER_H_RATE: float = 0.55
const BANNER_W_RATE: float = 0.90
const BANNER_LIFT: float = 0.18
const BANNER_SHADOW_BLUR: float = 40.0
const BANNER_SHADOW_DY: float = 12.0
const BANNER_SHADOW_INK: Color = Color(0.0, 0.0, 0.0, 0.6)
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
## Ceremonial title furniture, transcribed from title-b.html (1180×820).
const TITLE_PRIMARY_H: float = 76.0
const TITLE_SECONDARY_H: float = 64.0
const TITLE_UTILITY_H: float = 64.0
const TITLE_CHAMFER_PRIMARY: float = 18.0
const TITLE_CHAMFER_SECONDARY: float = 15.0
const TITLE_SEAM_W: float = 520.0
const TITLE_LANTERN_SIZE: Vector2 = Vector2(620.0, 240.0)

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
var _card_views: Array[CardView] = []
var _card_pedestals: Array[Control] = []
var _title_variant: bool = false
var _title_banner: TextureRect
var _banner_shadow: ColorRect = null
var _title_column: VBoxContainer
var _wordmark_slot: Control
var _wordmark: TextureRect
var _wordmark_label: Label = null
var _tagline_slot: Control
var _tagline: Label
var _lantern: TextureRect = null
var _primary: VBoxContainer
var _primary_buttons: Array[Button] = []
var _seam: Control = null
var _utility: HBoxContainer
var _utility_buttons: Array[Button] = []
var _dev_button: Button = null
var _rose_medallion: Button = null
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
	var grid: HFlowContainer = HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", roundi(16.0 * k))
	grid.add_theme_constant_override("v_separation", roundi(16.0 * k))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid)
	for row: Dictionary in choices:
		if not row.has("card"):
			continue
		var inst: CardInst = row["card"]
		var definition: Dictionary = row.get("definition", {})
		var cost_v: Variant = definition.get("cost")
		var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
		var view: CardView = CardView.new(inst, definition, cost)
		if not row.get("disabled", false):
			var choice_id: String = str(row.get("id", ""))
			view.released_at.connect(func(_uid: int, _position: Vector2) -> void:
				_sfx.play(&"card")
				chosen.emit(choice_id)
			)
		var pedestal: Control = Control.new()
		grid.add_child(pedestal)
		pedestal.add_child(view)
		_card_views.append(view)
		_card_pedestals.append(pedestal)
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
	var card_scale: float = _card_scale()
	for i: int in range(_card_views.size()):
		var span: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) * card_scale
		var view: CardView = _card_views[i]
		var pedestal: Control = _card_pedestals[i]
		pedestal.custom_minimum_size = span
		view.position = (span - Vector2(CardView.CARD_W, CardView.CARD_H)) * 0.5
		view.scale = Vector2.ONE * card_scale


func _card_scale() -> float:
	match shape:
		&"phone-landscape":
			return 0.89 if _card_pick else 0.84
		&"desktop-landscape":
			return 1.17 if _card_pick else 1.0
		_:
			return 0.99 if _card_pick else 0.87


func _add_title_rose(context: Dictionary) -> void:
	var shards_v: Variant = context.get("rose_shards", [])
	if typeof(shards_v) != TYPE_ARRAY or shards_v.is_empty():
		return
	var shards: Array = shards_v
	_rose_medallion = Button.new()
	_rose_medallion.tooltip_text = Locale.active.t("ui.rose.openLabel")
	_rose_medallion.clip_contents = true
	_rose_medallion.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_rose_medallion.add_theme_stylebox_override("focus",
		GlassStyle.focus_ring(GOLD, 39))
	for state: String in ["normal", "hover", "pressed"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("#070912")
		style.set_border_width_all(1)
		style.border_color = Color(GOLD, 0.82 if state == "hover" else 0.45)
		style.set_corner_radius_all(39)
		style.shadow_color = Color(GOLD, 0.24 if state == "hover" else 0.16)
		style.shadow_size = 16 if state == "hover" else 10
		_rose_medallion.add_theme_stylebox_override(state, style)
	add_child(_rose_medallion)
	for id_v: Variant in shards:
		var id: String = str(id_v)
		var mask_path: String = ROSE_MASK % id
		if not ResourceLoader.exists(mask_path):
			continue
		var pane: TextureRect = TextureRect.new()
		pane.texture = load(mask_path) as Texture2D
		pane.set_anchors_preset(Control.PRESET_FULL_RECT)
		pane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pane.stretch_mode = TextureRect.STRETCH_SCALE
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = ROSE_PANE_SHADER
		material.set_shader_parameter("mural", load(ROSE_MURAL) as Texture2D)
		material.set_shader_parameter("show_mural", true)
		material.set_shader_parameter("fill_colour", Color.TRANSPARENT)
		pane.material = material
		_rose_medallion.add_child(pane)
	var frame: TextureRect = TextureRect.new()
	frame.texture = load(ROSE_FRAME) as Texture2D
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rose_medallion.add_child(frame)
	_rose_medallion.pressed.connect(func() -> void:
		_sfx.play(&"relic")
		chosen.emit("rose")
	)


func _ceremonial_button(text: String, ceremonial: bool) -> TitleFacetButton:
	var button: TitleFacetButton = TitleFacetButton.new()
	button.text = text
	button.ceremonial = ceremonial
	button.chamfer = TITLE_CHAMFER_PRIMARY if ceremonial else TITLE_CHAMFER_SECONDARY
	button.custom_minimum_size = Vector2(400.0,
		TITLE_PRIMARY_H if ceremonial else TITLE_SECONDARY_H)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pt: int = 27 if ceremonial else 21
	var track: int = 4 if ceremonial else 3
	button.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, track))
	button.add_theme_font_size_override("font_size", pt)
	var fill: Color = RunStyle.GOLD if ceremonial else RunStyle.TEXT
	button.add_theme_color_override("font_color", fill)
	button.add_theme_color_override("font_hover_color",
		fill.lerp(Color.WHITE, 0.35) if ceremonial else RunStyle.GOLD)
	button.add_theme_color_override("font_pressed_color",
		fill.lerp(RunStyle.GOLD_DIM, 0.45) if ceremonial else RunStyle.TEXT)
	button.add_theme_color_override("font_focus_color", fill)
	if ceremonial:
		button.add_theme_color_override("font_shadow_color", Color(GlassStyle.EMBER, 0.32))
		button.add_theme_constant_override("shadow_offset_x", 0)
		button.add_theme_constant_override("shadow_offset_y", 0)
	# State plates come from TitleFacetStyleBox in _ready; only focus is extra.
	# The mock's hover & focus dressing is warm — a GLASS ring here reads as a
	# cold blue halo against the gold plate (first capture), so both tiers ring
	# in gold.
	var chamfer: int = roundi(TITLE_CHAMFER_PRIMARY if ceremonial else TITLE_CHAMFER_SECONDARY)
	button.add_theme_stylebox_override("focus", GlassStyle.focus_ring(RunStyle.GOLD, chamfer))
	return button


func _place_lantern() -> void:
	if _lantern == null:
		return
	_lantern.visible = not _primary_buttons.is_empty()
	if not _lantern.visible:
		return
	var host: Button = _primary_buttons[0]
	var plate: Vector2 = host.size
	if plate.x < 1.0:
		plate = host.custom_minimum_size
	var origin: Vector2 = host.get_global_rect().position - get_global_rect().position
	_lantern.position = origin + Vector2(
		plate.x * 0.5 - TITLE_LANTERN_SIZE.x * 0.5,
		plate.y * 0.34 - TITLE_LANTERN_SIZE.y * 0.34)
	_lantern.size = TITLE_LANTERN_SIZE


func _utility_word(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = Vector2(68.0, TITLE_UTILITY_H)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, 2))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", RunStyle.TEXT_DIM)
	button.add_theme_color_override("font_hover_color", RunStyle.GOLD)
	button.add_theme_color_override("font_pressed_color", RunStyle.TEXT_DIM)
	button.add_theme_color_override("font_focus_color", RunStyle.TEXT_DIM)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 1)
	RunStyle.hide_button_boxes(button)
	var pad: StyleBoxEmpty = StyleBoxEmpty.new()
	pad.content_margin_left = 16.0
	pad.content_margin_right = 16.0
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, pad)
	return button


func _utility_pip() -> Control:
	var pip: TitlePip = TitlePip.new()
	pip.custom_minimum_size = Vector2(3.0, TITLE_UTILITY_H)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pip


func _apply_utility_pt(pt: int) -> void:
	var track: int = maxi(roundi(float(pt) * 0.14), 0)
	for button: Button in _utility_buttons:
		button.text = str(button.get_meta("title_label", button.text))
		button.clip_text = false
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_500, track))
		button.add_theme_font_size_override("font_size", pt)
		button.custom_minimum_size.y = TITLE_UTILITY_H
	if _dev_button != null:
		_dev_button.clip_text = false
		_dev_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		_dev_button.add_theme_font_size_override("font_size", mini(pt, 13))


func _utility_row_width() -> float:
	var total: float = 0.0
	for button: Button in _utility_buttons:
		var font: Font = button.get_theme_font("font")
		var pt: int = button.get_theme_font_size("font_size")
		var text_w: float = 0.0
		if font != null:
			text_w = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
		total += maxf(68.0, text_w + 32.0)
	if _utility_buttons.size() > 1:
		total += 3.0 * float(_utility_buttons.size() - 1)
	return total


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


## The title screen's own bucket, hanging off the same `run` scope — the same
## arrangement `map` uses for its top rail.
func _title_num(field: String, fallback: float = 0.0) -> float:
	return LayoutBook.num(_panel_layout.get("title", {}).get(field), fallback)


## Put the banner's drop-shadow under the plate it belongs to.
##
## The Control has to be BIGGER than the plate, because the shadow bleeds past
## every edge — a shader can only draw inside its own rect, so a margin of three
## standard deviations plus the offset is what keeps the tail from being clipped
## into a second hard edge, which would defeat the whole point of adding it.
func _seat_banner_shadow(at: Vector2, span: Vector2) -> void:
	if _banner_shadow == null:
		return
	var sigma: float = BANNER_SHADOW_BLUR * 0.5
	var pad: float = sigma * 3.0 + absf(BANNER_SHADOW_DY)
	_banner_shadow.position = at - Vector2.ONE * pad
	_banner_shadow.size = span + Vector2.ONE * pad * 2.0
	var mat: ShaderMaterial = _banner_shadow.material as ShaderMaterial
	if mat == null:
		return
	var plate_min: Vector2 = Vector2.ONE * pad
	mat.set_shader_parameter("ctrl_size", _banner_shadow.size)
	mat.set_shader_parameter("box_min", plate_min + Vector2(0.0, BANNER_SHADOW_DY))
	mat.set_shader_parameter("box_max", plate_min + span + Vector2(0.0, BANNER_SHADOW_DY))
	mat.set_shader_parameter("plate_min", plate_min)
	mat.set_shader_parameter("plate_max", plate_min + span)


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


## Waystone-facet plate: chamfered came + glass, transcribed from title-b.html.
class TitleFacetButton extends Button:
	## The plate is painted by per-state TitleFacetStyleBox instances, NOT a
	## _draw() override: a GDScript _draw runs after the Button's own pass, so
	## polygons drawn there land ON TOP of the label and erase the text
	## (measured on the first capture of this branch). A StyleBox draws under.
	var ceremonial: bool = false
	var chamfer: float = 15.0

	func _ready() -> void:
		clip_text = false
		autowrap_mode = TextServer.AUTOWRAP_OFF
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var box: TitleFacetStyleBox = TitleFacetStyleBox.new()
			box.ceremonial = ceremonial
			box.chamfer = chamfer
			box.state = state
			add_theme_stylebox_override(state, box)


class TitleFacetStyleBox extends StyleBox:
	var ceremonial: bool = false
	var chamfer: float = 15.0
	var state: String = "normal"

	func _draw(ci: RID, rect: Rect2) -> void:
		var pressed: bool = state == "pressed"
		var hover: bool = state == "hover"
		var cut: float = chamfer
		var plate: Rect2 = Rect2(
			rect.position + Vector2(0.0, 1.0 if pressed else 0.0),
			rect.size - Vector2(0.0, 1.0 if pressed else 0.0))
		var came: PackedColorArray
		var glass: PackedColorArray
		if ceremonial:
			if pressed:
				came = _facet_cols(Color(RunStyle.GOLD_DIM, 0.75), Color(RunStyle.GOLD, 0.45))
				glass = _facet_cols(Color(RunStyle.INK, 0.86), Color(RunStyle.GOLD, 0.10))
			elif hover:
				came = _facet_cols(RunStyle.GOLD, Color(RunStyle.GOLD, 0.72))
				glass = _facet_cols(Color(RunStyle.GOLD, 0.30), Color(GlassStyle.EMBER, 0.12))
			else:
				came = _facet_cols(Color(RunStyle.GOLD, 0.95), Color(RunStyle.GOLD_DIM, 0.62))
				glass = _facet_cols(Color(RunStyle.GOLD, 0.20), Color(GlassStyle.EMBER, 0.07))
			_poly(ci, _octagon(plate.grow(2.0), cut + 2.0),
				PackedColorArray([Color(GlassStyle.EMBER, 0.12 if hover else 0.08)]))
		else:
			came = _facet_cols(Color(RunStyle.GOLD, 0.32), Color(RunStyle.GOLD, 0.15))
			glass = _facet_cols(RunStyle.PANEL, RunStyle.PANEL)
			_poly(ci, _octagon(plate.grow(1.0), cut + 1.0),
				PackedColorArray([Color(0.0, 0.0, 0.0, 0.40)]))
		_poly(ci, _octagon(plate, cut), came)
		var inner: Rect2 = plate.grow(-1.0)
		var glass_pts: PackedVector2Array = _octagon(inner, maxf(cut - 1.0, 1.0))
		if ceremonial:
			_poly(ci, glass_pts, PackedColorArray([RunStyle.INK]))
		_poly(ci, glass_pts, glass)

	static func _poly(ci: RID, points: PackedVector2Array, colors: PackedColorArray) -> void:
		RenderingServer.canvas_item_add_polygon(ci, points, colors)

	static func _facet_cols(top: Color, bot: Color) -> PackedColorArray:
		var mid: Color = top.lerp(bot, 0.55)
		return PackedColorArray([top, top, mid, bot, bot, bot, mid, top])

	static func _octagon(rect: Rect2, cut: float) -> PackedVector2Array:
		var c: float = minf(cut, minf(rect.size.x, rect.size.y) * 0.45)
		var x0: float = rect.position.x
		var y0: float = rect.position.y
		var x1: float = rect.end.x
		var y1: float = rect.end.y
		return PackedVector2Array([
			Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
			Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1),
			Vector2(x0, y1 - c), Vector2(x0, y0 + c),
		])


class TitleSeam extends Control:
	func _draw() -> void:
		var y: float = size.y * 0.5
		var cx: float = size.x * 0.5
		var gap: float = 14.0
		var half: float = 3.5
		var gold: Color = Color(RunStyle.GOLD, 0.36)
		var left_to: float = cx - gap
		var right_from: float = cx + gap
		var h: float = 0.5
		draw_polygon(
			PackedVector2Array([
				Vector2(0.0, y - h), Vector2(left_to, y - h),
				Vector2(left_to, y + h), Vector2(0.0, y + h),
			]),
			PackedColorArray([
				Color(RunStyle.GOLD, 0.0), gold, gold, Color(RunStyle.GOLD, 0.0),
			]))
		draw_polygon(
			PackedVector2Array([
				Vector2(right_from, y - h), Vector2(size.x, y - h),
				Vector2(size.x, y + h), Vector2(right_from, y + h),
			]),
			PackedColorArray([
				gold, Color(RunStyle.GOLD, 0.0), Color(RunStyle.GOLD, 0.0), gold,
			]))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - half - 2.0), Vector2(cx + half + 2.0, y),
			Vector2(cx, y + half + 2.0), Vector2(cx - half - 2.0, y),
		]), Color(GlassStyle.EMBER, 0.28))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - half), Vector2(cx + half, y),
			Vector2(cx, y + half), Vector2(cx - half, y),
		]), Color(RunStyle.GOLD, 0.82))


class TitlePip extends Control:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = 1.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x, c.y - r), Vector2(c.x + r, c.y),
			Vector2(c.x, c.y + r), Vector2(c.x - r, c.y),
		]), Color(RunStyle.GOLD_DIM, 0.85))
