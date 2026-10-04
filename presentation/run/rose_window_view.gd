class_name RoseWindowView
extends Control
## The Rose Window look of the Vigil's hall (docs/design/2026-10-03-title-rooms
## §4.1): the Emberglass rose stands in the hall's own window
## (LeadlightRose.vigil), its six panes in their states; under it a lozenge
## lit for each shard recovered or, once all six are whole, the Replay pane;
## beside it the reading glass (a lancet of the kit's glass): the selected
## pane's name and state, its inscription, every dawn memory it holds in full,
## and the whispers heard at dawn. The glass has a fixed box and scrolls, so
## nothing it holds can push the seat or the stage's edge. Laid out on the
## stage (VigilHall.rose_spot), the view itself full-rect and input-blind.

signal replay_requested
## A pane was chosen: whether it is whole (the glass takes the light).
signal pane_chosen(complete: bool)

const IDS: Array[String] = [
	"paleOnes", "ownShade", "usurper", "eighthOmen", "unreadablePage",
	"hollowLamplighter",
]
const MURAL: String = "res://assets/art/meta/emberglass-mural.png"
const FRAME: String = "res://assets/art/meta/emberglass-frame.png"
const MASK: String = "res://assets/art/meta/emberglass-mask-%s.png"
const PANE_SHADER: Shader = preload("res://presentation/run/rose_pane.gdshader")
## The reading glass on the stage (pad and desktop, phone).
const GLASS_PAD: Rect2 = Rect2(530.0, 168.0, 610.0, 562.0)
const GLASS_PHONE: Rect2 = Rect2(336.0, 56.0, 500.0, 274.0)
## A pane's tap, a share of the rose's side, and the least it may be.
const PANE_HIT: float = 0.2
## How far in from the glass's top and foot a line fades out (pad, phone).
const EDGE_FADE: Vector2 = Vector2(24.0, 16.0)
## The six panes' brightening before the Replay's flood (V6).
const FLARE_TIME: float = 0.24

var shape: StringName = StageShape.IDENTITY

var _quests: Dictionary
var _content: Dictionary
var _whispers: int
var _whisper_lines: Array
var _selected: int
var _rose: LeadlightRose
var _pane_buttons: Array[Button] = []
var _lozenges: _Lozenges
var _replay: LeadlightPane = null
var _glass: LeadlightSheet
var _scroll: ScrollContainer
var _page: VBoxContainer
var _name: Label
var _state_line: Label
var _state_came: LeadlightCame
var _detail: VBoxContainer
var _log: VBoxContainer
var _swap: Tween = null


func _init(quests: Dictionary, quest_content: Dictionary, whispers: int,
		whisper_lines: Array, stage_shape: StringName = StageShape.IDENTITY) -> void:
	_quests = quests
	_content = quest_content
	_whispers = maxi(0, whispers)
	_whisper_lines = whisper_lines
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	_selected = _initial_selection()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	var states: Dictionary = {}
	var counts: Dictionary = {}
	for id: String in IDS:
		var record: Dictionary = _record(id)
		states[id] = StringName(_state(record))
		counts[id] = Vector2i(int(float(str(record.get("progress", 0)))),
			maxi(1, int(float(str(_quest(id).get("target", 1))))))
	_rose = LeadlightRose.vigil(states, counts)
	_rose.name = "Rose"
	# The rose holds the light it has: a warm halo in the hall's window.
	_rose.radiance = 0.35
	add_child(_rose)
	for index: int in range(IDS.size()):
		_add_pane(index)
	_lozenges = _Lozenges.new()
	_lozenges.lit = IDS.filter(func(id: String) -> bool: return _state(_record(id)) == "complete").size()
	add_child(_lozenges)
	# The lozenges give way to Replay once all six are whole.
	if _all_complete():
		_add_replay()
		_lozenges.visible = false
	_glass = LeadlightSheet.new()
	_glass.name = "ReadingGlass"
	_glass.spring = 0.13
	_glass.quarry_pitch = 0.0
	_glass.light_at = Vector2(0.0, 0.2)
	_glass.light_colour = Color(0.70, 0.78, 1.0)
	add_child(_glass)
	_scroll = ScrollContainer.new()
	_scroll.name = "Reading"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Without this the view never travels with keyboard focus (issue #72).
	_scroll.follow_focus = true
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _fade_edges())
	_glass.content().add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 10)
	_scroll.add_child(_page)
	_name = _text(LeadlightTokens.ROLE_PRIMARY, Vector2i(22, 15), LeadlightTokens.GOLD)
	_page.add_child(_name)
	var state_row: VBoxContainer = VBoxContainer.new()
	state_row.add_theme_constant_override("separation", 2)
	_page.add_child(state_row)
	_state_line = _text(LeadlightTokens.ROLE_LABEL, LeadlightTokens.SIZE_ROOM_LABEL, LeadlightTokens.PARCHMENT)
	state_row.add_child(_state_line)
	_state_came = LeadlightCame.new()
	_state_came.custom_minimum_size = Vector2(160.0, 8.0)
	_state_came.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	state_row.add_child(_state_came)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 12)
	_page.add_child(_detail)
	var divider: _Divider = _Divider.new()
	_page.add_child(divider)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 6)
	_page.add_child(_log)
	_build_log()
	_refresh_selection()
	set_shape(shape)


func _add_pane(index: int) -> void:
	var id: String = IDS[index]
	var record: Dictionary = _record(id)
	var button: Button = Button.new()
	button.name = "Pane%d" % (index + 1)
	button.flat = true
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state_name: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state_name, empty)
	# A keyboard's ring is a circle round the pane, never a box.
	button.add_theme_stylebox_override("focus", LeadlightRose._Ring.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = _pane_accessible_name(index, id, record)
	button.accessibility_name = button.tooltip_text
	button.pressed.connect(_choose.bind(index))
	add_child(button)
	_pane_buttons.append(button)


func _add_replay() -> void:
	_replay = LeadlightPane.new(Locale.active.t("ui.rose.replayUnsealing"), shape)
	_replay.name = "Replay"
	_replay.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, shape))
	_replay.hit_height = LeadlightTokens.room_hit(shape)
	_replay.pressed.connect(_on_replay)
	add_child(_replay)


## V6: the six panes brighten, then the flood (Main's) carries the scene in.
func _on_replay() -> void:
	if LeadlightMotion.reduced() or not is_inside_tree() or DisplayServer.get_name() == "headless":
		replay_requested.emit()
		return
	var flare: Tween = create_tween()
	flare.tween_method(func(k: float) -> void: _rose.modulate = Color(k, k, k, 1.0), 1.0, 1.6, FLARE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flare.tween_callback(func() -> void: replay_requested.emit())


## The rose's centre on the stage: where the Replay's flood starts.
func rose_centre() -> Vector2:
	return _rose.get_global_rect().get_center()


func rose() -> LeadlightRose:
	return _rose


## The look's parts, each its own group as the hall comes in: the reading
## glass, the rose, and its lozenges or Replay.
func parts() -> Array[Control]:
	var out: Array[Control] = [_glass, _rose]
	out.append(_replay if _replay != null else _lozenges)
	return out


func glass() -> LeadlightSheet:
	return _glass


func replay() -> LeadlightPane:
	return _replay


func pane_buttons() -> Array[Button]:
	return _pane_buttons


## The rects the look stands in, on the stage: the rose, its lozenges or
## Replay, and the reading glass.
func content_rects() -> Array[Rect2]:
	# The rose by its glass (its tracery's ring), not its square's clear corners.
	var spot: Vector3 = VigilHall.rose_spot(shape)
	var disc: Rect2 = Rect2(Vector2(spot.x, spot.y) - Vector2(spot.z, spot.z), Vector2(spot.z, spot.z) * 2.0)
	var rects: Array[Rect2] = [disc, _glass.get_rect()]
	rects.append(_replay.get_rect() if _replay != null else _lozenges.get_rect())
	return rects


## The pane chosen by a tap: its glass and its rim, with the pane's sound.
func _choose(index: int) -> void:
	var was: int = _selected
	_select(index)
	if index != was:
		pane_chosen.emit(_state(_record(IDS[index])) == "complete")


func _select(index: int) -> void:
	_selected = index
	_refresh_selection(true)


## V5: the reading glass cross-fades to the selected pane (out 0–100 ms, in
## 60–220) as its rim comes up round the pane.
func _refresh_selection(animate: bool = false) -> void:
	var id: String = IDS[_selected]
	_rose.selected = id
	for index: int in range(_pane_buttons.size()):
		_pane_buttons[index].button_pressed = index == _selected
	if _swap != null:
		_swap.kill()
	if not animate or not is_inside_tree() or LeadlightMotion.reduced():
		_fill_glass(id)
		_page.modulate.a = 1.0
		return
	_swap = create_tween()
	_swap.tween_property(_page, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swap.tween_callback(_fill_glass.bind(id))
	_swap.tween_property(_page, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


## The selected pane in the glass: name, state, inscription, every memory.
func _fill_glass(id: String) -> void:
	var record: Dictionary = _record(id)
	var state: String = _state(record)
	if state in ["revealed", "complete"]:
		_name.text = str(_quest(id).get("name", id))
	elif state == "armed":
		_name.text = Locale.active.t("ui.rose.unknownPane", {"n": _selected + 1})
	else:
		_name.text = Locale.active.t("ui.rose.dormantPane", {"n": _selected + 1})
	var progress: int = int(float(str(record.get("progress", 0))))
	var target: int = maxi(1, int(float(str(_quest(id).get("target", 1)))))
	match state:
		"revealed":
			_state_line.text = "%d / %d" % [mini(progress, target), target]
		"armed":
			_state_line.text = "???"
		"complete":
			_state_line.text = Locale.active.t("ui.rose.shardRecoveredShort")
		_:
			_state_line.text = Locale.active.t("ui.rose.paneDark")
	_state_came.visible = state == "revealed"
	_state_came.progress = float(progress) / float(target)
	for child: Node in _detail.get_children():
		child.queue_free()
		_detail.remove_child(child)
	if state in ["revealed", "complete"]:
		_detail.add_child(_prose(str(_quest(id).get("inscription", "")), LeadlightTokens.TEXT))
	for memory: String in _memories(record):
		_detail.add_child(_prose(memory, LeadlightTokens.PARCHMENT))
	_scroll.scroll_vertical = 0
	_fade_edges.call_deferred()


## Every dawn memory the pane holds, in full (each its own paragraph).
func _memories(record: Dictionary) -> PackedStringArray:
	var joined: String = _archived_dawn(record)
	return PackedStringArray() if joined.is_empty() else joined.split("\n\n", false)


func _build_log() -> void:
	var title: Label = _text(LeadlightTokens.ROLE_CARVED, LeadlightTokens.SIZE_ROOM_CARVED,
		Color(LeadlightTokens.GOLD, 0.7))
	title.text = Locale.active.t("ui.rose.whisperLogTitleUpper")
	_log.add_child(title)
	var heard: int = mini(_whispers, _whisper_lines.size())
	for index: int in range(heard):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_log.add_child(row)
		var number: Label = _text(LeadlightTokens.ROLE_CARVED, LeadlightTokens.SIZE_ROOM_CARVED,
			Color(LeadlightTokens.GOLD_DIM, 0.9))
		number.text = LeadlightNumerals.carved_drawn(index + 1)
		number.custom_minimum_size.x = 64.0 if not LeadlightTokens.is_phone(shape) else 44.0
		row.add_child(number)
		var line: Label = _prose(str(_whisper_lines[index]), LeadlightTokens.TEXT)
		row.add_child(line)
	if _whispers > _whisper_lines.size():
		var final: Label = _prose(Locale.active.t("ui.rose.finalWhisperMark"), LeadlightTokens.GOLD)
		_log.add_child(final)


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## The rose at its spot in the hall's window, its pane hits on its panes, the
## lozenges or Replay under it, the glass beside it.
func _fit() -> void:
	if _rose == null:
		return
	var phone: bool = LeadlightTokens.is_phone(shape)
	var spot: Vector3 = VigilHall.rose_spot(shape)
	var side: float = 2.0 * spot.z / LeadlightRose.RIM
	_rose.size = Vector2(side, side)
	_rose.position = Vector2(spot.x, spot.y) - Vector2(side, side) * 0.5
	var hit: float = maxf(side * PANE_HIT, LeadlightTokens.room_hit(shape))
	for index: int in range(_pane_buttons.size()):
		var centre: Vector2 = LeadlightRose.PANE_AT[IDS[index]]
		var at: Vector2 = _rose.position + centre * side
		_pane_buttons[index].size = Vector2(hit, hit)
		_pane_buttons[index].position = at - Vector2(hit, hit) * 0.5
	var foot: float = spot.y + spot.z + (10.0 if phone else 16.0)
	_lozenges.size = Vector2(spot.z * 1.3, 14.0 if phone else 20.0)
	_lozenges.position = Vector2(spot.x - _lozenges.size.x * 0.5, foot)
	if _replay != null:
		var wide: float = _replay.get_combined_minimum_size().x + 24.0
		_replay.size = Vector2(wide, _replay.get_combined_minimum_size().y)
		_replay.position = Vector2(spot.x - wide * 0.5, foot - 4.0)
	var rect: Rect2 = GLASS_PHONE if phone else GLASS_PAD
	_glass.position = rect.position
	_glass.size = rect.size
	_scroll.custom_minimum_size = Vector2.ZERO
	for label: Label in _labels():
		_size_label(label)
	_fade_edges()


## Every line in the glass fades out over its top and foot, never cut through.
func _fade_edges() -> void:
	if _scroll == null or not _scroll.is_inside_tree() or _scroll.size.y <= 0.0:
		return
	var edge: float = EDGE_FADE.y if LeadlightTokens.is_phone(shape) else EDGE_FADE.x
	var view: Rect2 = _scroll.get_global_rect()
	for label: Label in _labels():
		var at: Rect2 = label.get_global_rect()
		var top: float = clampf((at.end.y - view.position.y) / edge, 0.0, 1.0)
		var foot: float = clampf((view.end.y - at.position.y) / edge, 0.0, 1.0)
		label.self_modulate.a = minf(top, foot)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		_fade_edges()


func _labels() -> Array[Label]:
	var out: Array[Label] = []
	for node: Node in _page.find_children("", "Label", true, false):
		out.append(node as Label)
	return out


func _text(role: StringName, token: Vector2i, colour: Color) -> Label:
	var label: Label = Label.new()
	label.set_meta(&"role", role)
	label.set_meta(&"token", token)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	_size_label(label)
	return label


func _prose(text: String, colour: Color) -> Label:
	var label: Label = _text(LeadlightTokens.ROLE_READ, LeadlightTokens.SIZE_ROOM_READ, colour)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _size_label(label: Label) -> void:
	var role: StringName = label.get_meta(&"role", LeadlightTokens.ROLE_READ)
	var token: Vector2i = label.get_meta(&"token", LeadlightTokens.SIZE_ROOM_READ)
	var px: int = LeadlightTokens.size_for(token, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(role, px))
	label.add_theme_font_size_override("font_size", px)



func _initial_selection() -> int:
	for wanted: String in ["revealed", "armed", "complete"]:
		for index: int in range(IDS.size()):
			if _state(_record(IDS[index])) == wanted:
				return index
	return 0


func _record(id: String) -> Dictionary:
	var value: Variant = _quests.get(id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _quest(id: String) -> Dictionary:
	var value: Variant = _content.get(id, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _state(record: Dictionary) -> String:
	var state: String = str(record.get("state", "dormant"))
	return state if state in ["dormant", "armed", "revealed", "complete"] else "dormant"


func _all_complete() -> bool:
	for id: String in IDS:
		if _state(_record(id)) != "complete":
			return false
	return true


func _detail_copy(id: String, record: Dictionary) -> String:
	var archived: String = _archived_dawn(record)
	if not archived.is_empty():
		return archived
	var state: String = _state(record)
	if state == "armed":
		return "???"
	if state == "revealed":
		return "%s\n%s\n%s/%s" % [
			_quest(id).get("name", id), _quest(id).get("inscription", ""),
			record.get("progress", 0), _quest(id).get("target", 0)]
	if state == "complete":
		return Locale.active.t("ui.rose.shardRecoveredStack", {
			"name": str(_quest(id).get("name", id)),
		})
	return Locale.active.t("ui.rose.paneDark")


func _archived_dawn(record: Dictionary) -> String:
	var memory_v: Variant = record.get("memory", {})
	if typeof(memory_v) != TYPE_DICTIONARY:
		return ""
	var memory: Dictionary = memory_v
	var dawn_v: Variant = memory.get("dawn", [])
	if typeof(dawn_v) != TYPE_ARRAY:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for id_v: Variant in dawn_v:
		var key: String = str(id_v)
		var text: String = Locale.active.t(key)
		if text != key:
			parts.append(text)
	return "\n\n".join(parts)


func _pane_accessible_name(index: int, id: String, record: Dictionary) -> String:
	var state: String = _state(record)
	if state == "dormant":
		return Locale.active.t("ui.rose.dormantPane", {"n": index + 1})
	if state == "armed":
		return Locale.active.t("ui.rose.unknownPane", {"n": index + 1})
	return _detail_copy(id, record).replace("\n", ", ")


## Under the rose: a leaded lozenge for each of the six shards, lit for each
## recovered (the count at a glance).
class _Lozenges extends Control:
	var lit: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x / 6.0
		if w < 4.0 or size.y < 4.0:
			return
		for i: int in range(6):
			var box: Rect2 = Rect2(Vector2(w * float(i) + w * 0.18, 0.0), Vector2(w * 0.64, size.y))
			var shape_points: PackedVector2Array = LeadlightShapes.lozenge(box, box.size.y * 0.5)
			var on: bool = i < lit
			draw_colored_polygon(shape_points, Color(LeadlightTokens.GOLD, 0.85) if on
				else LeadlightTokens.GLASS_COLD_BOTTOM)
			var ring: PackedVector2Array = shape_points.duplicate()
			ring.append(shape_points[0])
			draw_polyline(ring, LeadlightTokens.LEAD, 2.5, true)
			draw_polyline(ring, Color(LeadlightTokens.GOLD_DIM, 0.7), 1.0, true)


## A lead rule with a diamond at its middle, between the pane and the whispers.
class _Divider extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 18.0

	func _draw() -> void:
		var y: float = size.y * 0.5
		var mid: float = size.x * 0.5
		draw_line(Vector2(0.0, y), Vector2(mid - 10.0, y), Color(LeadlightTokens.GOLD_DIM, 0.6), 1.0, true)
		draw_line(Vector2(mid + 10.0, y), Vector2(size.x, y), Color(LeadlightTokens.GOLD_DIM, 0.6), 1.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 5.0), Vector2(mid + 5.0, y),
			Vector2(mid, y + 5.0), Vector2(mid - 5.0, y)]), Color(LeadlightTokens.GOLD, 0.8))
