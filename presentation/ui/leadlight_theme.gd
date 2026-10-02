class_name LeadlightTheme
extends RefCounted
## The canonical Theme, generated from the Leadlight tokens and applied on Main:
## every routed Control inherits it, every Control type is covered, and every
## focusable type wears the one shared lantern ring (`GlassStyle.focus_ring`).
## Moved here from `GlassStyle.theme()` unchanged (2026-08-14 decision 2, paid by
## docs/design/2026-10-02-opening-start §8); `GlassStyle.theme()` delegates.
## Per-instance helpers still override geometry (compact radius, primary CTA,
## card seats) — they do not fork the palette.


## Built once per process: it is pure in the tokens and nothing mutates a
## Theme at runtime, and every screen asked for its own copy at ~20 ms each.
static var _built: Theme = null


static func build() -> Theme:
	if _built != null:
		return _built
	var t: Theme = Theme.new()
	# Keep the default UI face in the runtime resource chain. A project-level
	# custom font is resolved before cache-cold import has produced its fontdata,
	# while this factory runs only after resources are ready.
	t.default_font = GlassStyle.face(GlassStyle.NOTO_SERIF_TC_REGULAR)
	t.default_font_size = 15
	_theme_type(t)
	_theme_chrome(t)
	_theme_fields(t)
	_theme_toggles(t)
	_built = t
	return t


static func _theme_type(t: Theme) -> void:
	t.set_color("font_color", "Label", LeadlightTokens.GLASS_TEXT)
	t.set_font_size("font_size", "Label", 15)
	t.set_color("default_color", "RichTextLabel", LeadlightTokens.GLASS_TEXT)
	t.set_color("selection_color", "RichTextLabel", Color(LeadlightTokens.GOLD, 0.28))
	t.set_font("normal_font", "RichTextLabel", GlassStyle.face(GlassStyle.ALEGREYA_400))
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_color("font_color", "TooltipLabel", LeadlightTokens.GLASS_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("panel", "TooltipPanel", GlassStyle.pane(LeadlightTokens.GOLD, 0.94))
	_theme_button_type(t, "Button")
	_theme_button_type(t, "OptionButton")
	t.set_icon("arrow", "OptionButton", _chevron(LeadlightTokens.GOLD))
	t.set_constant("arrow_margin", "OptionButton", 6)
	t.set_constant("modulate_arrow", "OptionButton", 1)


static func _theme_button_type(t: Theme, type_name: String) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, type_name, RunStyle.button_stylebox(state))
	# Radius 8 matches the unstyled secondary box above. Custom-radius
	# surfaces still push their own ring so it stays concentric (PR #43).
	t.set_stylebox("focus", type_name, GlassStyle.focus_ring(LeadlightTokens.GOLD, 8))
	t.set_color("font_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_hover_color", type_name, LeadlightTokens.GOLD)
	t.set_color("font_pressed_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_focus_color", type_name, RunStyle.PARCHMENT)
	t.set_color("font_hover_pressed_color", type_name, LeadlightTokens.GOLD)
	t.set_color("font_disabled_color", type_name, Color(LeadlightTokens.GLASS_TEXT_DIM, 0.45))
	t.set_font_size("font_size", type_name, 15)


static func _theme_chrome(t: Theme) -> void:
	t.set_stylebox("panel", "Panel", RunStyle.panel())
	t.set_stylebox("panel", "PanelContainer", RunStyle.panel())
	t.set_stylebox("panel", "PopupPanel", RunStyle.panel(8, 10, 0.94))
	t.set_stylebox("panel", "AcceptDialog", RunStyle.panel(12, 16, 0.92))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())
	var rule: StyleBoxLine = StyleBoxLine.new()
	rule.color = Color(LeadlightTokens.GOLD, 0.22)
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	var v_rule: StyleBoxLine = StyleBoxLine.new()
	v_rule.color = Color(LeadlightTokens.GOLD, 0.22)
	v_rule.thickness = 1
	v_rule.vertical = true
	t.set_stylebox("separator", "VSeparator", v_rule)
	var menu_hover: StyleBoxFlat = _fill(Color(LeadlightTokens.GOLD, 0.14), 6, Color(LeadlightTokens.GOLD, 0.40), 1, 6.0)
	t.set_stylebox("panel", "PopupMenu", RunStyle.panel(8, 10, 0.94))
	t.set_stylebox("hover", "PopupMenu", menu_hover)
	t.set_stylebox("separator", "PopupMenu", rule)
	t.set_stylebox("labeled_separator_left", "PopupMenu", rule)
	t.set_stylebox("labeled_separator_right", "PopupMenu", rule)
	t.set_color("font_color", "PopupMenu", LeadlightTokens.GLASS_TEXT)
	t.set_color("font_hover_color", "PopupMenu", LeadlightTokens.GOLD)
	t.set_color("font_disabled_color", "PopupMenu", Color(LeadlightTokens.GLASS_TEXT_DIM, 0.45))
	t.set_color("font_separator_color", "PopupMenu", Color(LeadlightTokens.GOLD, 0.45))
	t.set_color("font_accelerator_color", "PopupMenu", LeadlightTokens.GLASS_TEXT_DIM)
	var check_on: Texture2D = _box_icon(Color(LeadlightTokens.GOLD, 0.90), LeadlightTokens.GOLD)
	var check_off: Texture2D = _box_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.55))
	var check_on_dim: Texture2D = _box_icon(Color(LeadlightTokens.GOLD, 0.35), Color(LeadlightTokens.GOLD, 0.30))
	var check_off_dim: Texture2D = _box_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.22))
	t.set_icon("checked", "PopupMenu", check_on)
	t.set_icon("unchecked", "PopupMenu", check_off)
	t.set_icon("checked_disabled", "PopupMenu", check_on_dim)
	t.set_icon("unchecked_disabled", "PopupMenu", check_off_dim)
	t.set_icon("radio_checked", "PopupMenu", _circle_icon(Color(LeadlightTokens.GOLD, 0.90), LeadlightTokens.GOLD))
	t.set_icon("radio_unchecked", "PopupMenu", _circle_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.55)))
	t.set_icon("radio_checked_disabled", "PopupMenu",
		_circle_icon(Color(LeadlightTokens.GOLD, 0.35), Color(LeadlightTokens.GOLD, 0.30)))
	t.set_icon("radio_unchecked_disabled", "PopupMenu",
		_circle_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.22)))
	_theme_scroll(t, "VScrollBar")
	_theme_scroll(t, "HScrollBar")
	var bar_bg: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.92), 5, Color(LeadlightTokens.GOLD, 0.28), 1)
	var bar_fg: StyleBoxFlat = _fill(LeadlightTokens.GOLD, 5)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_color("font_color", "ProgressBar", LeadlightTokens.GLASS_TEXT)
	_theme_slider(t, "HSlider")
	_theme_slider(t, "VSlider")


static func _theme_scroll(t: Theme, type_name: String) -> void:
	var track: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.90), 4)
	track.set_content_margin_all(3.0)
	var focus_track: StyleBoxFlat = _fill(
		Color(0.02, 0.03, 0.06, 0.90), 4, Color(LeadlightTokens.GOLD, 0.42), 1)
	focus_track.set_content_margin_all(3.0)
	t.set_stylebox("scroll", type_name, track)
	t.set_stylebox("scroll_focus", type_name, focus_track)
	t.set_stylebox("grabber", type_name, _fill(Color(LeadlightTokens.GOLD, 0.55), 4))
	t.set_stylebox("grabber_highlight", type_name, _fill(Color(LeadlightTokens.GOLD, 0.85), 4))
	t.set_stylebox("grabber_pressed", type_name, _fill(LeadlightTokens.GOLD, 4))
	var blank: PlaceholderTexture2D = PlaceholderTexture2D.new()
	blank.size = Vector2.ZERO
	for icon_name: String in [
		"increment", "increment_highlight", "increment_pressed",
		"decrement", "decrement_highlight", "decrement_pressed",
	]:
		t.set_icon(icon_name, type_name, blank)


static func _theme_slider(t: Theme, type_name: String) -> void:
	var track: StyleBoxFlat = _fill(Color(0.02, 0.03, 0.06, 0.90), 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = _fill(LeadlightTokens.GOLD, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", type_name, track)
	t.set_stylebox("grabber_area", type_name, fill)
	t.set_stylebox("grabber_area_highlight", type_name, fill)
	var grabber: Texture2D = GlassStyle.disc(LeadlightTokens.GOLD, 1.0)
	t.set_icon("grabber", type_name, grabber)
	t.set_icon("grabber_highlight", type_name, grabber)
	t.set_icon("grabber_disabled", type_name, GlassStyle.disc(LeadlightTokens.GLASS_TEXT_DIM, 0.45))


static func _theme_fields(t: Theme) -> void:
	var field: StyleBoxFlat = _fill(Color(LeadlightTokens.GLASS_INK.r, LeadlightTokens.GLASS_INK.g, LeadlightTokens.GLASS_INK.b, 0.80), 8,
		Color(LeadlightTokens.GOLD, 0.28), 1, 8.0)
	var field_read: StyleBoxFlat = _fill(Color(LeadlightTokens.GLASS_INK.r, LeadlightTokens.GLASS_INK.g, LeadlightTokens.GLASS_INK.b, 0.45), 8,
		Color(LeadlightTokens.GOLD, 0.12), 1, 8.0)
	for type_name: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type_name, field)
		t.set_stylebox("focus", type_name, GlassStyle.focus_ring(LeadlightTokens.GOLD, 8))
		t.set_stylebox("read_only", type_name, field_read)
		t.set_color("font_color", type_name, LeadlightTokens.GLASS_TEXT)
		t.set_color("font_uneditable_color", type_name, LeadlightTokens.GLASS_TEXT_DIM)
		t.set_color("font_placeholder_color", type_name, LeadlightTokens.GLASS_TEXT_DIM)
		t.set_color("caret_color", type_name, LeadlightTokens.GOLD)
		t.set_color("selection_color", type_name, Color(LeadlightTokens.GOLD, 0.28))
		t.set_font_size("font_size", type_name, 15)
	t.set_color("font_readonly_color", "TextEdit", LeadlightTokens.GLASS_TEXT_DIM)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	t.set_stylebox("panel", "ItemList", GlassStyle.pane(LeadlightTokens.GOLD, 0.80))
	t.set_stylebox("focus", "ItemList", GlassStyle.focus_ring(LeadlightTokens.GOLD, 12))
	t.set_stylebox("hovered", "ItemList", _fill(Color(LeadlightTokens.GOLD, 0.10), 6))
	t.set_stylebox("selected", "ItemList", _fill(Color(LeadlightTokens.GOLD, 0.16), 6, Color(LeadlightTokens.GOLD, 0.40), 1))
	t.set_stylebox("selected_focus", "ItemList",
		_fill(Color(LeadlightTokens.GOLD, 0.22), 6, Color(LeadlightTokens.GOLD, 0.70), 1))
	t.set_color("font_color", "ItemList", LeadlightTokens.GLASS_TEXT)
	t.set_color("font_hovered_color", "ItemList", LeadlightTokens.GOLD)
	t.set_color("font_selected_color", "ItemList", RunStyle.PARCHMENT)


static func _theme_toggles(t: Theme) -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	var check_on: Texture2D = _box_icon(Color(LeadlightTokens.GOLD, 0.90), LeadlightTokens.GOLD)
	var check_off: Texture2D = _box_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.55))
	var check_on_dim: Texture2D = _box_icon(Color(LeadlightTokens.GOLD, 0.35), Color(LeadlightTokens.GOLD, 0.30))
	var check_off_dim: Texture2D = _box_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.22))
	for type_name: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "pressed", "disabled", "hover", "hover_pressed"]:
			t.set_stylebox(state, type_name, empty)
		t.set_stylebox("focus", type_name, GlassStyle.focus_ring(LeadlightTokens.GOLD, 6))
		t.set_color("font_color", type_name, LeadlightTokens.GLASS_TEXT)
		t.set_color("font_pressed_color", type_name, LeadlightTokens.GOLD)
		t.set_color("font_hover_color", type_name, LeadlightTokens.GOLD)
		t.set_color("font_hover_pressed_color", type_name, LeadlightTokens.GOLD)
		t.set_color("font_focus_color", type_name, LeadlightTokens.GLASS_TEXT)
		t.set_color("font_disabled_color", type_name, Color(LeadlightTokens.GLASS_TEXT_DIM, 0.45))
		t.set_font_size("font_size", type_name, 14)
	t.set_icon("checked", "CheckBox", check_on)
	t.set_icon("unchecked", "CheckBox", check_off)
	t.set_icon("checked_disabled", "CheckBox", check_on_dim)
	t.set_icon("unchecked_disabled", "CheckBox", check_off_dim)
	t.set_icon("radio_checked", "CheckBox", _circle_icon(Color(LeadlightTokens.GOLD, 0.90), LeadlightTokens.GOLD))
	t.set_icon("radio_unchecked", "CheckBox", _circle_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.55)))
	t.set_icon("radio_checked_disabled", "CheckBox",
		_circle_icon(Color(LeadlightTokens.GOLD, 0.35), Color(LeadlightTokens.GOLD, 0.30)))
	t.set_icon("radio_unchecked_disabled", "CheckBox",
		_circle_icon(Color.TRANSPARENT, Color(LeadlightTokens.GOLD, 0.22)))
	t.set_color("checkbox_checked_color", "CheckBox", Color.WHITE)
	t.set_color("checkbox_unchecked_color", "CheckBox", Color.WHITE)
	var sw_on: Texture2D = _switch_icon(true, false)
	var sw_off: Texture2D = _switch_icon(false, false)
	t.set_icon("checked", "CheckButton", sw_on)
	t.set_icon("unchecked", "CheckButton", sw_off)
	t.set_icon("checked_disabled", "CheckButton", _switch_icon(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_icon(false, true))
	t.set_icon("checked_mirrored", "CheckButton", sw_on)
	t.set_icon("unchecked_mirrored", "CheckButton", sw_off)
	t.set_icon("checked_disabled_mirrored", "CheckButton", _switch_icon(true, true))
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", _switch_icon(false, true))
	t.set_color("button_checked_color", "CheckButton", Color.WHITE)
	t.set_color("button_unchecked_color", "CheckButton", Color.WHITE)


static func _fill(bg: Color, radius: int, border: Color = Color.TRANSPARENT,
		width: int = 0, margin: float = 0.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if width > 0:
		sb.set_border_width_all(width)
		sb.border_color = border
	if margin > 0.0:
		sb.set_content_margin_all(margin)
	return sb


static func _box_icon(fill: Color, stroke: Color, size: int = 14) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(0, 0, size, size), stroke)
	img.fill_rect(Rect2i(1, 1, size - 2, size - 2), fill)
	return ImageTexture.create_from_image(img)


static func _circle_icon(fill: Color, stroke: Color, size: int = 14) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c: float = float(size - 1) * 0.5
	var outer: float = c - 0.4
	var inner: float = outer - 1.4
	for y: int in range(size):
		for x: int in range(size):
			var d: float = Vector2(float(x) - c, float(y) - c).length()
			if d <= inner and fill.a > 0.0:
				img.set_pixel(x, y, fill)
			elif d <= outer and d > inner:
				img.set_pixel(x, y, stroke)
			elif d <= outer and fill.a > 0.0:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


static func _switch_icon(on: bool, disabled: bool) -> ImageTexture:
	var w: int = 28
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var body: Color = Color(LeadlightTokens.GOLD, 0.55 if on else 0.10)
	var rim: Color = Color(LeadlightTokens.GOLD, 0.85 if on else 0.28)
	if disabled:
		body.a *= 0.45
		rim.a *= 0.45
	if not on:
		body = Color(LeadlightTokens.GLASS_INK.r, LeadlightTokens.GLASS_INK.g, LeadlightTokens.GLASS_INK.b, 0.80 if not disabled else 0.40)
	img.fill_rect(Rect2i(0, 0, w, h), rim)
	img.fill_rect(Rect2i(1, 1, w - 2, h - 2), body)
	var knob: Color = Color(RunStyle.PARCHMENT, 0.95 if not disabled else 0.45)
	var knob_x: int = w - 14 if on else 2
	img.fill_rect(Rect2i(knob_x, 2, 12, h - 4), knob)
	return ImageTexture.create_from_image(img)


static func _chevron(colour: Color, w: int = 11, h: int = 7) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var mid: int = int(float(w - 1) / 2.0)
	var last: int = maxi(h - 1, 1)
	for y: int in range(h):
		var span: int = roundi(float(mid) * float(y) / float(last))
		for x: int in range(mid - span, mid + span + 1):
			if x >= 0 and x < w:
				img.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(img)
