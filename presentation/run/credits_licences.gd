class_name CreditsLicences
extends RefCounted
## The licence texts the credits carry: the bundled fonts' OFL texts, and the
## engine's own licence, its components and their licence texts (with the
## Sentry SDK's MIT notice wherever the addon ships). Built into a fold the
## credits own, on demand (the engine's is long), and read in a licence glass
## of its own (docs/design/2026-10-03-title-rooms §4.3), never inline.

## The Sentry SDK's own licence, read where the addon is in the pack.
const SENTRY_LICENCE: String = "res://addons/sentry/LICENSE.md"
## The reading sizes in a licence glass, pad and phone (the rooms' floor).
const READ: Vector2i = LeadlightTokens.SIZE_ROOM_READ
const HEAD: Vector2i = LeadlightTokens.SIZE_ROOM_HEAD

## Text set at a shape's room sizes; the folds below read it.
static var shape: StringName = StageShape.IDENTITY

const FONT_LICENCES: Array[Dictionary] = [
	{"family": "Cinzel", "path": "res://assets/fonts/OFL-Cinzel.txt"},
	{"family": "Alegreya", "path": "res://assets/fonts/OFL-Alegreya.txt"},
	# Noto Serif CJK TC is an Adobe/Google Noto CJK family and remains OFL.
	{"family": "Noto Serif CJK TC", "path": "res://assets/fonts/OFL.txt"},
	{"family": "Noto Sans Symbols2", "path": "res://assets/fonts/OFL-NotoSansSymbols2.txt"},
]


## The engine's licence, its components and their licence texts, into `fold`.
static func fill_engine(fold: VBoxContainer) -> void:
	var engine_text: RichTextLabel = body(Engine.get_license_text())
	fold.add_child(engine_text)
	if FileAccess.file_exists(SENTRY_LICENCE) and ClassDB.class_exists(&"SentrySDK"):
		fold.add_child(heading("Sentry SDK for Godot"))
		fold.add_child(body(FileAccess.get_file_as_string(SENTRY_LICENCE)))

	fold.add_child(heading(Locale.active.t("ui.credits.components")))

	var copyright_info: Array = Engine.get_copyright_info()
	for entry_raw: Variant in copyright_info:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_raw
		var lines: PackedStringArray = PackedStringArray()
		var parts_raw: Variant = entry.get("parts", [])
		if typeof(parts_raw) == TYPE_ARRAY:
			var parts: Array = parts_raw
			for part_raw: Variant in parts:
				if typeof(part_raw) != TYPE_DICTIONARY:
					continue
				var part: Dictionary = part_raw
				var cr_raw: Variant = part.get("copyright", [])
				var cr_bits: PackedStringArray = PackedStringArray()
				if typeof(cr_raw) == TYPE_ARRAY:
					var cr_list: Array = cr_raw
					for cr_item: Variant in cr_list:
						cr_bits.append(str(cr_item))
				elif typeof(cr_raw) == TYPE_STRING:
					var cr_str: String = str(cr_raw).strip_edges()
					if not cr_str.is_empty():
						cr_bits.append(cr_str)
				if not cr_bits.is_empty():
					lines.append(("© " + "; ".join(cr_bits)).replace("\\n", "\n"))
				var lic_id: String = str(part.get("license", "")).strip_edges()
				if not lic_id.is_empty():
					lines.append(lic_id)
		# Two-tier entry: the name a step brighter than its © lines, and the
		# intra-entry gap tighter than the roll's separation, so ~100
		# near-identical entries stay scannable.
		var component: VBoxContainer = VBoxContainer.new()
		component.add_theme_constant_override("separation", 2)
		var name_line: Label = Label.new()
		name_line.text = str(entry.get("name", ""))
		name_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_read(name_line, GlassStyle.TEXT)
		component.add_child(name_line)
		if not lines.is_empty():
			var part_lines: Label = Label.new()
			part_lines.text = "\n".join(lines)
			part_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_read(part_lines, GlassStyle.TEXT_DIM)
			component.add_child(part_lines)
		fold.add_child(component)

	fold.add_child(heading(Locale.active.t("ui.credits.licenceTexts")))

	var licence_info: Dictionary = Engine.get_license_info()
	for name_raw: Variant in licence_info.keys():
		# Seated heading: the gap above each licence name must beat a blank
		# line inside its body, or the strongest break reads weakest.
		fold.add_child(heading(str(name_raw)))
		var text_raw: Variant = licence_info[name_raw]
		fold.add_child(body(str(text_raw)))


## A fold in `wrap`, filled with the font texts (`fonts`) or the engine's.
static func fill_wrap(wrap: MarginContainer, fonts: bool) -> void:
	var fold: VBoxContainer = VBoxContainer.new()
	fold.add_theme_constant_override("separation", 8)
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(fold)
	if fonts:
		fill_fonts(fold)
	else:
		fill_engine(fold)


## Each bundled font family's OFL text, into `fold`.
static func fill_fonts(fold: VBoxContainer) -> void:
	for entry: Dictionary in FONT_LICENCES:
		var family: String = str(entry["family"])
		var path: String = str(entry["path"])
		fold.add_child(heading(family))
		if not FileAccess.file_exists(path):
			var missing: Label = Label.new()
			missing.text = "licence file not found: %s" % family
			missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_read(missing, GlassStyle.TEXT_DIM)
			fold.add_child(missing)
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			var missing_open: Label = Label.new()
			missing_open.text = "licence file not found: %s" % family
			missing_open.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_read(missing_open, GlassStyle.TEXT_DIM)
			fold.add_child(missing_open)
			continue
		fold.add_child(body(file.get_as_text()))


static func heading(text: String) -> MarginContainer:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 12)
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var px: int = LeadlightTokens.size_for(HEAD, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_PRIMARY, px))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", GlassStyle.GOLD)
	seat.add_child(label)
	return seat


static func _read(label: Label, colour: Color) -> void:
	var px: int = LeadlightTokens.size_for(READ, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)


static func body(text: String, font_size: int = 0) -> RichTextLabel:
	if font_size <= 0:
		font_size = LeadlightTokens.size_for(READ, shape)
	var prose: RichTextLabel = RichTextLabel.new()
	prose.fit_content = true
	prose.scroll_active = false
	prose.selection_enabled = true
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prose.text = text
	prose.add_theme_font_override("normal_font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	prose.add_theme_font_size_override("normal_font_size", font_size)
	prose.add_theme_color_override("default_color", GlassStyle.TEXT_DIM)
	return prose


## The credits' two licence glasses, the fonts' and the engine's, one open at
## a time, each built on its first opening.
class Shelf extends Control:
	signal shut

	var fonts: Glass
	var engine: Glass
	var opened: Glass = null

	func _init(stage_shape: StringName) -> void:
		name = "Licences"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fonts = Glass.new(Locale.active.t("ui.credits.fontLicences"), stage_shape)
		engine = Glass.new(Locale.active.t("ui.credits.engineLicences"), stage_shape)
		for glass: Glass in [fonts, engine]:
			glass.shut.connect(func() -> void: shut.emit())
			add_child(glass)

	## The glasses stand where How to Play's room does (§3.2).
	func place(stage_shape: StringName, stage: Vector2) -> void:
		var rect: Rect2 = Rect2(Vector2((stage.x - HelpScreen.ROOM_W) * 0.5 + HelpScreen.ROOM_SHIFT,
			HelpScreen.ROOM_TOP), Vector2(HelpScreen.ROOM_W, stage.y - HelpScreen.ROOM_TOP - HelpScreen.ROOM_FOOT))
		if LeadlightTokens.is_phone(stage_shape):
			rect = Rect2(Vector2(HelpScreen.PHONE_LEFT, HelpScreen.PHONE_TOP),
				Vector2(stage.x - HelpScreen.PHONE_LEFT - HelpScreen.PHONE_RIGHT,
					stage.y - HelpScreen.PHONE_TOP - HelpScreen.PHONE_FOOT))
		for glass: Glass in [fonts, engine]:
			glass.place(rect)

	## Open `which` (&"fonts" or &"engine") over `behind`, built if it is not.
	func open(which: StringName, stage_shape: StringName, behind: CanvasItem) -> Glass:
		var glass: Glass = fonts if which == &"fonts" else engine
		if not glass.built:
			build(which, stage_shape)
		opened = glass
		glass.show_over(behind, true)
		return glass

	## Close the open glass, if any; returns it.
	func close(behind: CanvasItem) -> Glass:
		var glass: Glass = opened
		opened = null
		if glass != null:
			glass.show_over(behind, false)
		return glass

	func build(which: StringName, stage_shape: StringName) -> void:
		var glass: Glass = fonts if which == &"fonts" else engine
		CreditsLicences.shape = stage_shape
		CreditsLicences.fill_wrap(glass.wrap, which == &"fonts")
		glass.built = true


## A licence glass (§4.3, C3): a leaded sheet over the paused, dimmed roll,
## its crown the pane's own name and its own scroll, so a long text never folds
## open inside the roll. A tap off the glass (released without a drag) or
## Escape closes it; the seat's Return closes it before the credits.
class Glass extends Control:
	signal shut

	const IN_TIME: float = 0.32
	const OUT_TIME: float = 0.24
	const RISE: float = 12.0

	var wrap: MarginContainer
	var sheet: LeadlightSheet
	var scroll: ScrollContainer
	var crown: Label
	var built: bool = false
	var _down: bool = false
	var _from: Vector2 = Vector2.ZERO
	var _seat: Rect2 = Rect2()
	var _tween: Tween = null

	func _init(title_text: String, stage_shape: StringName) -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		gui_input.connect(_on_input)
		# Its own night over the paused roll, so the roll never reads round it.
		var night: ColorRect = ColorRect.new()
		night.color = Color(LeadlightTokens.VOID, 0.5)
		night.set_anchors_preset(Control.PRESET_FULL_RECT)
		night.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(night)
		sheet = LeadlightSheet.new()
		sheet.name = "LicenceGlass"
		sheet.spring = 0.12
		add_child(sheet)
		crown = Label.new()
		crown.text = title_text if LeadlightTokens.is_zh() else title_text.to_upper()
		crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_CROWN, stage_shape)
		crown.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, px))
		crown.add_theme_font_size_override("font_size", px)
		crown.add_theme_color_override("font_color", LeadlightTokens.GOLD)
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(crown)
		scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sheet.content().add_child(scroll)
		wrap = MarginContainer.new()
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.add_theme_constant_override("margin_right", 10)
		scroll.add_child(wrap)

	## C3: in, the glass rises RISE px and fades in while `behind` (the roll)
	## dims to 0.4; out, the reverse. Reduce Motion: 150 ms fades.
	func show_over(behind: CanvasItem, opening: bool) -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		visible = visible or opening
		if not is_inside_tree():
			modulate.a = 1.0 if opening else 0.0
			visible = opening
			behind.modulate.a = 0.4 if opening else 1.0
			return
		var reduced: bool = LeadlightMotion.reduced()
		var span: float = LeadlightMotion.REDUCED_FADE if reduced else (IN_TIME if opening else OUT_TIME)
		var curve: Vector2i = LeadlightMotion.REVEAL if opening else LeadlightMotion.EXIT
		var trans: Tween.TransitionType = curve.x as Tween.TransitionType
		var ease_kind: Tween.EaseType = curve.y as Tween.EaseType
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "modulate:a", 1.0 if opening else 0.0, span) \
			.from(0.0 if opening else modulate.a).set_trans(trans).set_ease(ease_kind)
		_tween.tween_property(behind, "modulate:a", 0.4 if opening else 1.0, span)
		if not reduced:
			var top: float = _seat.position.y
			_tween.tween_property(sheet, "position:y", top if opening else top + RISE, span) \
				.from(top + RISE if opening else top).set_trans(trans).set_ease(ease_kind)
		if not opening:
			_tween.chain().tween_callback(func() -> void:
				visible = false
				sheet.position.y = _seat.position.y)

	## Stand the glass in `rect` (stage px); its text starts below the crown.
	func place(rect: Rect2) -> void:
		_seat = rect
		sheet.position = rect.position
		sheet.size = rect.size
		var top: float = rect.size.y * sheet.spring
		sheet.content().add_theme_constant_override("margin_top", int(top + 30.0))
		crown.position = Vector2(0.0, maxf(top * 0.55 - crown.get_combined_minimum_size().y * 0.5, 2.0))
		crown.size = Vector2(rect.size.x, 0.0)

	func _on_input(event: InputEvent) -> void:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button == null or button.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if button.pressed:
			_down = true
			_from = button.position
		elif _down and button.position.distance_to(_from) <= LeadlightRoomHost.DRAG:
			_down = false
			shut.emit()
