class_name VigilEpitaphs
extends ScrollContainer
## The Epitaphs look of the Vigil's hall (docs/design/2026-10-03-title-rooms
## §4.1): looking down at the floor before the fire, each fall's last words
## cut into it, numbered in carved numerals, with a dark groove under every
## stroke. Centred in the hall's body box when they are few, scrolling when
## they are many; the firelight crawls across them (the fire's own flicker,
## so it stays under Reduce Motion). Each is a Label holding the line-table
## text, as the story's tests read it.

var shape: StringName = StageShape.IDENTITY
## The fire's flicker now (the hall's), for the light that crawls.
var fire: float = 1.0
var _lines: VBoxContainer
var _time: float = 0.0


func _init(vigil: VigilState, content: ContentDB, stage_shape: StringName = StageShape.IDENTITY) -> void:
	name = "Epitaphs"
	shape = stage_shape
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = true
	_lines = VBoxContainer.new()
	_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 18)
	add_child(_lines)
	var zh: bool = Locale.active.code == Locale.CODE_ZH_HANT
	for i: int in range(vigil.defeat_epitaphs.size()):
		var id: String = vigil.defeat_epitaphs[i]
		var row: Dictionary = LineTable.row_by_id(content.line_table, id)
		var body: String = LineTable.text(row, zh) if not row.is_empty() else id
		var line: Label = Label.new()
		line.text = "%s  %s" % [LeadlightNumerals.carved_drawn(i + 1), body]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_color_override("font_color", LeadlightTokens.PARCHMENT)
		# Cut into the floor: a dark groove under every stroke.
		line.add_theme_constant_override("shadow_offset_x", 0)
		line.add_theme_constant_override("shadow_offset_y", 2)
		line.add_theme_constant_override("shadow_outline_size", 3)
		line.add_theme_color_override("font_shadow_color", Color(LeadlightTokens.VOID, 0.85))
		_lines.add_child(line)
	set_shape(shape)


## The lines are centred in the box's height when they are fewer than it holds.
func fit(box: Rect2) -> void:
	position = box.position
	size = box.size
	_lines.custom_minimum_size = Vector2(0.0, box.size.y)


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_HEAD, shape)
	for line: Node in _lines.get_children():
		(line as Label).add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
		(line as Label).add_theme_font_size_override("font_size", px)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var lines: Array[Node] = _lines.get_children()
	for i: int in lines.size():
		var warm: float = 0.86 + 0.14 * sin(_time * 0.9 - float(i) * 0.7) * fire
		(lines[i] as Label).self_modulate = Color(warm, warm, warm, 1.0)
