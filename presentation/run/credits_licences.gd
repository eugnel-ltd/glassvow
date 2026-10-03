class_name CreditsLicences
extends RefCounted
## The licence texts the credits carry: the bundled fonts' OFL texts, and the
## engine's own licence, its components and their licence texts. Built into a
## fold the credits own, on demand (the engine's is about 37,000 px of text).

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
					lines.append("© " + "; ".join(cr_bits))
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
		name_line.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
		name_line.add_theme_font_size_override("font_size", 12)
		name_line.add_theme_color_override("font_color", GlassStyle.TEXT)
		component.add_child(name_line)
		if not lines.is_empty():
			var part_lines: Label = Label.new()
			part_lines.text = "\n".join(lines)
			part_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			part_lines.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
			part_lines.add_theme_font_size_override("font_size", 11)
			part_lines.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			component.add_child(part_lines)
		fold.add_child(component)

	fold.add_child(heading(Locale.active.t("ui.credits.licenceTexts")))

	var licence_info: Dictionary = Engine.get_license_info()
	for name_raw: Variant in licence_info.keys():
		# Seated heading: the gap above each licence name must beat a blank
		# line inside its body, or the strongest break reads weakest.
		fold.add_child(heading(str(name_raw)))
		var text_raw: Variant = licence_info[name_raw]
		fold.add_child(body(str(text_raw), 11))


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
			missing.add_theme_font_override("font",
				GlassStyle.face(GlassStyle.ALEGREYA_400))
			missing.add_theme_font_size_override("font_size", 11)
			missing.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			fold.add_child(missing)
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			var missing_open: Label = Label.new()
			missing_open.text = "licence file not found: %s" % family
			missing_open.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			missing_open.add_theme_font_override("font",
				GlassStyle.face(GlassStyle.ALEGREYA_400))
			missing_open.add_theme_font_size_override("font_size", 11)
			missing_open.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
			fold.add_child(missing_open)
			continue
		fold.add_child(body(file.get_as_text(), 11))


static func heading(text: String) -> MarginContainer:
	var seat: MarginContainer = MarginContainer.new()
	seat.add_theme_constant_override("margin_top", 12)
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 1))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", GlassStyle.GOLD)
	seat.add_child(label)
	return seat


static func body(text: String, font_size: int = 12) -> RichTextLabel:
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
