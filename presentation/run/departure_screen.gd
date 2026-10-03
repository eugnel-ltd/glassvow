class_name DepartureScreen
extends Control
## The setting-out, as one continuous departure on the title's road (build 18:
## "The setup page please be immersive" and "seems repeated the choices").
## One place — the road at dusk, the Hollow Lamplighter standing at its head,
## the hero's lantern in the foreground — and up to three beats that follow
## one another in it, each rising out of the last, never a screen swap:
##
##   (a) who carries the lantern, and the vow      only when there is a choice
##   (b) the parting gift: three boons in leaded glass
##   (c) the lantern art: the arts in glass, the chosen one kindled
##
## The last answer flows into the lantern: Main floods from its wick into the
## opening or the departure, as the title does. Main keeps every route and
## every domain command; this screen only emits.

## (a) answered: Main admits the class and creates the run.
signal embark_chosen(aspect: int, vow: int)
## (a)'s quiet word: back to the title.
signal back_requested
## (b) and (c) answered.
signal gift_chosen(boon_id: String, art_id: StringName)

const ROMAN: PackedStringArray = ["0", "I", "II", "III", "IV", "V"]
const BEAT_A: StringName = &"embark"
const BEAT_B: StringName = &"gift"
const BEAT_C: StringName = &"art"

var shape: StringName = StageShape.IDENTITY
var lantern: LeadlightLantern
var figure: LamplighterFigure
var world: TitleWorld
var beat: StringName = &""

var _sfx: SfxBus
var _column: VBoxContainer
var _primary: BaseButton = null
## (a)
var _aspects: Array = []
var _vows: Array = []
var _aspect_pick: bool = false
var _vow_unlocked: int = 0
var _saved_run: bool = false
var _aspect: int = 0
var _vow: int = 0
var _vow_line: Label
var _aspect_line: Label
var _vow_caption: Label
var _vow_choice: LeadlightChoice
## (b), (c)
var _boons: Dictionary = {}
var _boon_ids: Array[String] = []
var _arts: Dictionary = {}
var _boon: String = ""
var _art: StringName = &""
var _art_panes: Dictionary = {}
var _art_line: Label
## Setting out as before: {"aspect", "vow", "art"} from earlier this session.
var _same: Dictionary = {}
var _same_taken: bool = false
var _aspect_name: String = ""


class Layout:
	## Fractions of the stage.
	var figure: Rect2 = Rect2(0.0, 0.06, 0.40, 0.86)
	## x centre, top (fractions) and side (share of the stage height).
	var lantern: Vector3 = Vector3(0.5, 0.62, 0.40)
	var column: Rect2 = Rect2(0.40, 0.03, 0.57, 0.57)

	static func for_shape(stage_shape: StringName) -> Layout:
		var l: Layout = Layout.new()
		if stage_shape == &"desktop-landscape":
			l.figure = Rect2(0.03, 0.06, 0.322, 0.86)
			l.column = Rect2(0.34, 0.03, 0.62, 0.57)
		elif LeadlightTokens.is_phone(stage_shape):
			l.figure = Rect2(-0.01, 0.02, 0.295, 0.96)
			l.lantern = Vector3(0.9, 0.55, 0.42)
			l.column = Rect2(0.27, 0.03, 0.52, 0.94)
		return l


func _init(stage_shape: StringName = StageShape.IDENTITY, sfx: SfxBus = null) -> void:
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		add_child(_sfx)
	world = TitleScreen.add_road(self)
	figure = LamplighterFigure.new()
	figure.visible = false
	add_child(figure)
	lantern = LeadlightLantern.new()
	lantern.focus_mode = Control.FOCUS_NONE
	lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lantern)
	_column = VBoxContainer.new()
	_column.name = "Beat"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 3 if LeadlightTokens.is_phone(shape) else 6)
	add_child(_column)
	# A new beat's size is known once its container has measured it.
	_column.minimum_size_changed.connect(_queue_layout)


## (a): who carries the lantern and the vow. `aspect_pick` offers the classes
## (more than one admitted); the vow row shows when one is sworn-able.
## `same` ({"aspect", "vow", "art"}) offers setting out as before.
func show_embark(aspects: Array, vows: Array, aspect_pick: bool, vow_unlocked: int,
		saved_run: bool, aspect: int, vow: int, same: Dictionary = {},
		lamplighter: bool = false) -> void:
	_aspects = aspects
	_vows = vows
	_aspect_pick = aspect_pick and aspects.size() > 1
	_vow_unlocked = clampi(vow_unlocked, 0, vows.size())
	_saved_run = saved_run
	_aspect = clampi(aspect, 0, maxi(0, aspects.size() - 1)) if _aspect_pick else 0
	_vow = clampi(vow, 0, _vow_unlocked)
	_same = same
	figure.visible = lamplighter
	_enter(BEAT_A, &"recognising")


## (b) then (c): the parting gift and the lantern art. `aspect` is the run's
## class row (its name is in the Lamplighter's line).
func show_gift(aspect: Dictionary, boons: Dictionary, arts: Dictionary, boon_ids: Array,
		art: StringName) -> void:
	_boons = boons
	_arts = arts
	_boon_ids.clear()
	for id_v: Variant in boon_ids:
		if boons.has(str(id_v)):
			_boon_ids.append(str(id_v))
	_art = art if arts.has(String(art)) else StringName(str(arts.keys()[0]) if not arts.is_empty() else "")
	if _same_taken and arts.has(str(_same.get("art", ""))):
		_art = StringName(str(_same["art"]))
	_aspect_name = str(aspect.get("name", ""))
	figure.visible = true
	_enter(BEAT_B, &"asking")


## The wick on the stage: where the last answer floods out from.
func wick_on_stage() -> Vector2:
	return lantern.position + lantern.wick()


func primary() -> BaseButton:
	return _primary


func set_shape(stage_shape: StringName) -> void:
	if StageShape.REFERENCES.has(stage_shape):
		shape = stage_shape
		_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _ready() -> void:
	_layout()
	_focus()


var _layout_queued: bool = false


func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	_layout.call_deferred()


func _layout() -> void:
	_layout_queued = false
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var l: Layout = Layout.for_shape(shape)
	figure.position = l.figure.position * size
	figure.size = l.figure.size * size
	var side: float = l.lantern.z * size.y
	lantern.size = Vector2(side, side)
	lantern.position = Vector2(l.lantern.x * size.x - side * 0.5, l.lantern.y * size.y)
	figure.light_side = 1.0 if lantern.position.x > figure.position.x + figure.size.x * 0.5 else -1.0
	var column: Rect2 = Rect2(l.column.position * size, l.column.size * size)
	# A wrapping line measures its height at its width: seat the width first
	# (a line with none measures at zero width, hundreds of pixels tall).
	for node: Node in _column.get_children():
		var line: Label = node as Label
		if line != null and line.autowrap_mode != TextServer.AUTOWRAP_OFF:
			line.custom_minimum_size.x = column.size.x
	_column.custom_minimum_size.x = column.size.x
	_column.size = Vector2(column.size.x, 0.0)
	var held: float = beat_height()
	_column.position = Vector2(column.position.x, column.position.y + maxf(0.0, (column.size.y - held) * 0.5))
	_column.size = Vector2(column.size.x, held)


## How tall the beat stands at its width: wrapped lines measured with their
## font (a wrapping label has no true height until a running tree shapes it),
## everything else by its minimum size, with the column's gaps.
func beat_height() -> float:
	var total: float = 0.0
	var count: int = 0
	for node: Node in _column.get_children():
		var control: Control = node as Control
		if control == null or not control.visible:
			continue
		var line: Label = control as Label
		if line != null and line.autowrap_mode != TextServer.AUTOWRAP_OFF:
			var font: Font = line.get_theme_font("font")
			var px: int = line.get_theme_font_size("font_size")
			var lines: float = font.get_multiline_string_size(line.text, HORIZONTAL_ALIGNMENT_CENTER,
				line.custom_minimum_size.x, px).y
			total += maxf(lines, control.get_combined_minimum_size().y)
		else:
			total += control.get_combined_minimum_size().y
		count += 1
	return total + float(maxi(0, count - 1) * _column.get_theme_constant("separation"))


## Bring beat `next` up out of the last: the old beat sinks away, the new one
## rises into the same place, and the Lamplighter's mood follows.
func _enter(next: StringName, mood: StringName, rise: bool = true) -> void:
	beat = next
	figure.set_mood(mood)
	var old: Array[Node] = _column.get_children()
	for node: Node in old:
		_column.remove_child(node)
		node.queue_free()
	_primary = null
	match next:
		BEAT_A:
			_build_embark()
		BEAT_B:
			_build_gift()
		BEAT_C:
			_build_art()
	if is_inside_tree():
		_layout()
		if rise:
			LeadlightMotion.enter(_column, 0.06, LeadlightMotion.SETTLE)
			_sfx.play_owed(&"paneRise")
		_focus()


func _focus() -> void:
	if is_inside_tree() and _primary != null:
		LeadlightFocus.give(_primary)


# ── (a) ───────────────────────────────────────────────────────────────────

func _build_embark() -> void:
	_heading(Locale.active.t("ui.embark.title"))
	# A phone with choices to make keeps its height for them.
	var roomy: bool = not LeadlightTokens.is_phone(shape) or not (_aspect_pick or not _same.is_empty())
	if roomy:
		_line(Locale.active.t("ui.embark.subChoose") if _aspect_pick or _vow_unlocked > 0
			else Locale.active.t("ui.embark.subWait"))
	if not _same.is_empty():
		var same: LeadlightPane = _pane(Locale.active.t("ui.departure.same"), LeadlightGlassBox.Shape.LOZENGE)
		same.name = "SetOutAsBefore"
		same.pressed.connect(_set_out_as_before)
		_column.add_child(same)
	if _aspect_pick:
		if roomy:
			_caption(Locale.active.t("ui.embark.aspectLabel"))
		var row: GridContainer = _row(2)
		for index: int in _aspects.size():
			var aspect_row: Dictionary = _aspects[index] if typeof(_aspects[index]) == TYPE_DICTIONARY else {}
			var card: LeadlightPane = _card(str(aspect_row.get("name", "")), "",
				"res://assets/art/heroes/%s.png" % str(aspect_row.get("id", "")), index == _aspect)
			card.name = "Aspect_%d" % index
			card.tooltip_text = str(aspect_row.get("blurb", ""))
			card.pressed.connect(_pick_aspect.bind(index))
			row.add_child(card)
		# The chosen class's blurb, read beneath the glass (on a crowded phone,
		# in the card's tooltip only).
		if roomy:
			var chosen_row: Dictionary = _aspects[_aspect] if typeof(_aspects[_aspect]) == TYPE_DICTIONARY else {}
			_aspect_line = _line(str(chosen_row.get("blurb", "")))
	if _vow_unlocked > 0:
		_vow_caption = _caption("")
		var labels: PackedStringArray = PackedStringArray()
		for level: int in _vow_unlocked + 1:
			labels.append(ROMAN[level] if level < ROMAN.size() else str(level))
		_vow_choice = LeadlightChoice.new(labels, _vow, shape)
		_vow_choice.name = "VowChoice"
		_vow_choice.alignment = BoxContainer.ALIGNMENT_CENTER
		_vow_choice.chosen.connect(_pick_vow)
		_column.add_child(_vow_choice)
		_vow_line = _line("")
		_refresh_vow()
	if _saved_run:
		var warn: Label = _line(Locale.active.t("ui.embark.warnSaved"))
		warn.add_theme_color_override("font_color", LeadlightTokens.DANGER)
	var go: LeadlightPane = _pane(
		Locale.active.t("ui.menu.beginAnew" if _saved_run else "ui.menu.rekindle"), LeadlightGlassBox.Shape.LOZENGE)
	go.name = "SetOut"
	go.lit = true
	go.pressed.connect(func() -> void: _answer_embark(_aspect, _vow))
	var back: LeadlightWord = LeadlightWord.new(Locale.active.t("ui.menu.back"), shape)
	back.name = "Back"
	back.pressed.connect(func() -> void: back_requested.emit())
	_actions(go, back)


func _pick_aspect(index: int) -> void:
	_aspect = index
	_sfx.play_owed(&"paneChoose", &"click")
	_enter(BEAT_A, &"recognising", false)


func _pick_vow(level: int) -> void:
	_vow = level
	_sfx.play_owed(&"paneChoose", &"click")
	_refresh_vow()


func _refresh_vow() -> void:
	if _vow_line == null:
		return
	var level: String = ROMAN[_vow] if _vow < ROMAN.size() else str(_vow)
	var top: String = ROMAN[_vow_unlocked] if _vow_unlocked < ROMAN.size() else str(_vow_unlocked)
	_vow_caption.text = Locale.active.t("ui.embark.vowLevel", {"level": level, "max": top})
	if _vow == 0:
		_vow_line.text = Locale.active.t("ui.embark.noVows")
		return
	var lines: PackedStringArray = PackedStringArray()
	for index: int in mini(_vow, _vows.size()):
		var row: Dictionary = _vows[index] if typeof(_vows[index]) == TYPE_DICTIONARY else {}
		lines.append("%s — %s" % [row.get("name", ""), row.get("desc", "")])
	_vow_line.text = "\n".join(lines)


func _set_out_as_before() -> void:
	_same_taken = true
	var aspect: int = int(str(_same.get("aspect", 0)))
	var vow: int = int(str(_same.get("vow", 0)))
	_answer_embark(clampi(aspect, 0, maxi(0, _aspects.size() - 1)), clampi(vow, 0, _vow_unlocked))


func _answer_embark(aspect: int, vow: int) -> void:
	_sfx.play_owed(&"paneChoose", &"click")
	if _primary != null:
		LeadlightMotion.press(_primary as Control)
	embark_chosen.emit(aspect, vow)


# ── (b) ───────────────────────────────────────────────────────────────────

func _build_gift() -> void:
	_heading(Locale.active.t("ui.lamp.title"))
	_line(Locale.active.t("ui.lamp.sub", {"aspect": _aspect_name}))
	_caption(Locale.active.t("ui.lamp.boonLabel"))
	var row: GridContainer = _row(3)
	for id: String in _boon_ids:
		var boon: Dictionary = _boons[id]
		var card: LeadlightPane = _card(str(boon.get("name", id)), str(boon.get("text", "")),
			"res://assets/art/boons/%s.png" % id, id == _boon)
		card.name = "Boon_%s" % id
		card.pressed.connect(_pick_boon.bind(id))
		row.add_child(card)
		if _primary == null:
			_primary = card


func _pick_boon(id: String) -> void:
	_boon = id
	_sfx.play_owed(&"paneChoose", &"click")
	if _same_taken and _arts.has(String(_art)):
		# Setting out as before: the art is the one carried last time.
		_depart()
		return
	_enter(BEAT_C, &"urgent")


# ── (c) ───────────────────────────────────────────────────────────────────

func _build_art() -> void:
	_heading(Locale.active.t("ui.lamp.artLabel"))
	_caption(Locale.active.t("ui.lamp.artHint"))
	var count: int = _arts.size()
	var row: GridContainer = _row(3 if LeadlightTokens.is_phone(shape)
		else (count if count <= 4 else ceili(float(count) / 2.0)))
	_art_panes.clear()
	for id_v: Variant in _arts:
		var id: StringName = StringName(str(id_v))
		var art: Dictionary = _arts[str(id_v)]
		var pane: LeadlightPane = _card(str(art.get("name", id)), "",
			"res://assets/art/arts/%s.png" % String(id), id == _art)
		pane.name = "Art_%s" % String(id)
		pane.pressed.connect(_pick_art.bind(id))
		row.add_child(pane)
		_art_panes[id] = pane
	_art_line = _line("")
	_refresh_art()
	var go: LeadlightPane = _pane(Locale.active.t("ui.menu.lightTheWay"), LeadlightGlassBox.Shape.LOZENGE)
	go.name = "LightTheWay"
	go.lit = true
	go.pressed.connect(_depart)
	var back: LeadlightWord = LeadlightWord.new(Locale.active.t("ui.lamp.boonLabel"), shape)
	back.name = "BackToGift"
	back.pressed.connect(func() -> void: _enter(BEAT_B, &"asking"))
	_actions(go, back)


func _pick_art(id: StringName) -> void:
	_art = id
	_sfx.play_owed(&"paneChoose", &"click")
	_refresh_art()
	# The chosen fire catches in the lantern too.
	if is_inside_tree() and not LeadlightMotion.reduced():
		var catch: Tween = create_tween()
		catch.tween_property(lantern, "flare", 0.7, LeadlightMotion.QUICK)
		catch.tween_property(lantern, "flare", 0.0, LeadlightMotion.CEREMONY)


func _refresh_art() -> void:
	for id: StringName in _art_panes:
		var pane: LeadlightPane = _art_panes[id]
		_light_card(pane, id == _art)
	if _art_line != null:
		var art: Dictionary = _arts.get(String(_art), {})
		_art_line.text = "%s %s · %s" % [art.get("glyph", ""), art.get("name", ""), art.get("text", "")]


func _depart() -> void:
	if _boon.is_empty() or not _arts.has(String(_art)):
		return
	_sfx.play_owed(&"paneChoose", &"click")
	if _primary != null and beat == BEAT_C:
		LeadlightMotion.press(_primary as Control)
	gift_chosen.emit(_boon, _art)


# ── the kit, at this screen's sizes ───────────────────────────────────────

func _heading(text: String) -> Label:
	var label: Label = _label(text if LeadlightTokens.is_zh() else text.to_upper(),
		LeadlightTokens.ROLE_LABEL, 15 if LeadlightTokens.is_phone(shape) else 20, LeadlightTokens.GOLD)
	label.name = "Heading"
	return label


func _caption(text: String) -> Label:
	var label: Label = _label(text if LeadlightTokens.is_zh() else text.to_upper(),
		LeadlightTokens.ROLE_LABEL, 11 if LeadlightTokens.is_phone(shape) else 13, LeadlightTokens.GOLD_DIM)
	return label


func _line(text: String) -> Label:
	var label: Label = _label(text, LeadlightTokens.ROLE_READ,
		LeadlightTokens.size_for(LeadlightTokens.SIZE_READ, shape), LeadlightTokens.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = maxf(_column.custom_minimum_size.x, 120.0)
	return label


func _label(text: String, role: StringName, px: int, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", LeadlightTokens.font(role, px))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(label)
	return label


## The beat's answer as a lit pane, with its quiet way back beside it.
func _actions(go: LeadlightPane, back: LeadlightWord) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12 if LeadlightTokens.is_phone(shape) else 22)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(go)
	row.add_child(back)
	_column.add_child(row)
	_primary = go


## A grid of glass, `columns` to a row, centred in the beat.
func _row(columns: int) -> GridContainer:
	var row: GridContainer = GridContainer.new()
	row.columns = maxi(1, columns)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var gap: int = 8 if LeadlightTokens.is_phone(shape) else 14
	row.add_theme_constant_override("h_separation", gap)
	row.add_theme_constant_override("v_separation", gap)
	_column.add_child(row)
	return row


func _pane(text: String, kind: LeadlightGlassBox.Shape) -> LeadlightPane:
	var pane: LeadlightPane = LeadlightPane.new(text, shape, kind)
	pane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pane.custom_minimum_size.x = 200.0 if LeadlightTokens.is_phone(shape) else 260.0
	return pane


## A leaded glass card: its art, its name and (optionally) a line, on a
## pane that lights when it is the choice.
func _card(title: String, text: String, art_path: String, chosen: bool) -> LeadlightPane:
	var phone: bool = LeadlightTokens.is_phone(shape)
	var card: LeadlightPane = LeadlightPane.new("", shape, LeadlightGlassBox.Shape.RECT)
	card.tooltip_text = title
	var width: float = (140.0 if text.is_empty() else 150.0) if phone else (140.0 if text.is_empty() else 210.0)
	var art_px: float = (34.0 if phone else 48.0) if text.is_empty() else (40.0 if phone else 56.0)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_anchors_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = 10.0
	copy.offset_right = -10.0
	copy.offset_top = 8.0
	copy.offset_bottom = -8.0
	card.add_child(copy)
	if ResourceLoader.exists(art_path):
		var art: TextureRect = TextureRect.new()
		art.texture = load(art_path) as Texture2D
		art.custom_minimum_size = Vector2(art_px, art_px)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(art)
	var name_px: int = 12 if phone else 15
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, name_px))
	name_label.add_theme_font_size_override("font_size", name_px)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(name_label)
	name_label.custom_minimum_size.x = width - 20.0
	if not text.is_empty():
		var read_px: int = 11 if phone else 13
		var body: Label = Label.new()
		body.text = text
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = width - 20.0
		body.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, read_px))
		body.add_theme_font_size_override("font_size", read_px)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.add_child(body)
	# As tall as its copy wraps to at its width (the font's own measure: a
	# wrapping label has no height until a running tree shapes it), with the
	# glass round it.
	var inner: float = width - 20.0
	var height: float = 16.0 + art_px + 2.0 + _wrapped(title, LeadlightTokens.ROLE_LABEL, name_px, inner)
	if not text.is_empty():
		var read_px: int = 11 if phone else 13
		height += 2.0 + _wrapped(text, LeadlightTokens.ROLE_READ, read_px, inner)
		# CJK breaks per character in the fallback face: a line of slack.
		if LeadlightTokens.is_zh():
			height += float(read_px) * 1.5
	card.custom_minimum_size = Vector2(width, height + 18.0)
	_light_card(card, chosen)
	return card


static func _wrapped(text: String, role: StringName, px: int, width: float) -> float:
	var font: Font = LeadlightTokens.font(role, px)
	return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, px).y


## A card lights as the choice: lit glass, its words in ink; cold glass keeps
## a gold name over parchment-grey words.
static func _light_card(card: LeadlightPane, on: bool) -> void:
	card.lit = on
	var first: bool = true
	for node: Node in card.find_children("", "Label", true, false):
		var label: Label = node as Label
		label.add_theme_color_override("font_color", LeadlightTokens.INK if on
			else (LeadlightTokens.GOLD if first else LeadlightTokens.TEXT))
		first = false
