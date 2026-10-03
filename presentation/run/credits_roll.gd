class_name CreditsRoll
extends VBoxContainer
## The credits as a roll on the road onward (docs/design/2026-10-03-title-rooms
## §4.3): under the title's own wordmark (lent to the roll by the room), the
## "Credits" heading the tapped word rides to, the brand and the glass, the
## music titles from the manifest in its order (two columns at pad, one on a
## phone) with the track now playing carrying a breathing flame, the sound, the
## type, the engine, the two licence panes and the footer. Headings 20, names
## 20, secondary lines 18: the rubric's floor at pad.
##
## Track titles that belong to Act IV stay carved dots until the unsealing has
## been seen (Help says three acts; the credits no longer contradict it), and
## the count line counts them all. No pack id is shown, and no item the
## manifest marks unwired.
##
## The roll is built with the room down to ROWS_NOW rows of each column, and
## the rest a part a frame from the frame after (`finish` builds it at once):
## every line's text is shaped as it enters the tree, and the whole roll in
## the tap frame put Credits over §11.6's 33 ms on the iPad 8. What comes later
## stands below the fold at every shape, and the passage holds it unseen.

signal licence_requested(which: StringName)

const MUSIC_MANIFEST: String = "res://assets/audio/music/manifest.json"
const SFX_MANIFEST: String = "res://assets/audio/sfx/manifest.json"
## Act IV's loops and their held alternates (docs/music-ledger.md, "Shipped —
## Act IV" and its held-alternates table): unsaid until the unsealing.
const HELD_UNTIL_UNSEALING: Array[StringName] = [&"act4Combat", &"act4Boss", &"act4CombatA",
	&"act4CombatB", &"act4CombatD", &"act4BossB"]
const HELD_MARK: String = "· · ·"
## A line under the lamp: warm parchment.
const WARM: Color = Color("#fff1d0")
## Track rows a column builds with the roll: more than any stage shows before
## the roll moves (six at pad, seven on the iPad 8's taller stage).
const ROWS_NOW: int = 9

var shape: StringName = StageShape.IDENTITY
## Where the wordmark stands over the roll: the gap before its first heading.
var head_gap: Control
## "Credits": the roll's first heading, where the word that opened it lands.
var heading_node: Label
var footer_node: Label
## Every line the lamp warms (`base` meta: its colour at rest).
var lines: Array[Label] = []
## The now-playing flame, when a listed track is the one playing.
var now_glyph: Control = null
var font_pane: LeadlightPane
var engine_pane: LeadlightPane
var _unsealed: bool = false
var _now: StringName = &""
## The manifests, read once a session (they ship with the build), so the
## 25 KB sound manifest is not parsed again in every opening's tap frame.
static var _manifests: Dictionary[String, Dictionary] = {}
## The parts still to build, in order, and the frame the roll entered on.
var _later: Array[Callable] = []
var _entered: int = -1


func _init(stage_shape: StringName = StageShape.IDENTITY, unsealed: bool = false,
		now_playing: StringName = &"") -> void:
	name = "CreditsRoll"
	shape = stage_shape
	_unsealed = unsealed
	_now = now_playing
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_gap = Control.new()
	head_gap.name = "WordmarkSeat"
	head_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head_gap)
	heading_node = _line(Locale.active.t("ui.credits.title"), LeadlightTokens.ROLE_LABEL,
		LeadlightTokens.SIZE_ROOM_CROWN, LeadlightTokens.GOLD)
	heading_node.name = "CreditsHeading"
	heading_node.text = heading_node.text if LeadlightTokens.is_zh() else heading_node.text.to_upper()
	_body(Locale.active.t("ui.credits.bodyBrand"))
	_heading(Locale.active.t("ui.credits.headingGlass"))
	_body(Locale.active.t("ui.credits.bodyGlass"))
	_heading(Locale.active.t("ui.credits.headingMusic"))
	var music: Dictionary = _read_manifest(MUSIC_MANIFEST)
	var tracks: Array[Dictionary] = wired_items(music)
	if tracks.is_empty():
		_secondary(Locale.active.t("ui.credits.musicAttribution"))
		_secondary(Locale.active.t("ui.credits.musicTracklistFallback"))
	else:
		_secondary(Locale.active.t("ui.credits.musicAttributionCount", {"count": tracks.size()}))
		_add_tracks(tracks)
	_later.append(_add_sound_and_type)
	_later.append(_add_engine_and_footer)


func _ready() -> void:
	_entered = Engine.get_process_frames()


func _process(_delta: float) -> void:
	if Engine.get_process_frames() > _entered and not _later.is_empty():
		_later.pop_front().call()
	if _later.is_empty():
		set_process(false)


## The whole roll now (the room at rest, a capture, a suite).
func finish() -> void:
	while not _later.is_empty():
		_later.pop_front().call()
	set_process(false)


func _add_sound_and_type() -> void:
	_heading(Locale.active.t("ui.credits.headingSound"))
	var sound: Array[Dictionary] = wired_items(_read_manifest(SFX_MANIFEST))
	_secondary(Locale.active.t("ui.credits.sfxAttributionCount", {"count": sound.size()})
		if not sound.is_empty() else Locale.active.t("ui.credits.sfxAttribution"))
	_heading(Locale.active.t("ui.credits.headingType"))
	for key: String in ["ui.credits.bodyCinzel", "ui.credits.bodyAlegreya", "ui.credits.bodyNoto"]:
		_body(Locale.active.t(key))


func _add_engine_and_footer() -> void:
	_heading(Locale.active.t("ui.credits.headingEngine"))
	_body(Locale.active.t("ui.credits.bodyEngine"))
	_add_licence_panes()
	footer_node = _line(Locale.active.t("ui.credits.footer"), LeadlightTokens.ROLE_READ,
		LeadlightTokens.SIZE_ROOM_READ, LeadlightTokens.TEXT_DIM)
	footer_node.name = "Footer"


## The items a manifest lists as wired, in its order, each with its `id`.
static func wired_items(manifest: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var items_raw: Variant = manifest.get("items", null)
	if typeof(items_raw) != TYPE_DICTIONARY:
		return out
	var items: Dictionary = items_raw
	for id_v: Variant in items:
		var item_raw: Variant = items[id_v]
		if typeof(item_raw) != TYPE_DICTIONARY:
			continue
		var listed: Dictionary = item_raw
		var item: Dictionary = listed.duplicate()
		if item.get("wired", true) == false:
			continue
		item["id"] = str(id_v)
		out.append(item)
	return out


## What a track's row reads: its title, or the carved dots while it is held.
static func track_text(item: Dictionary, unsealed: bool) -> String:
	if not unsealed and HELD_UNTIL_UNSEALING.has(StringName(str(item.get("id", "")))):
		return HELD_MARK
	return str(item.get("title", ""))


static func _read_manifest(path: String) -> Dictionary:
	if _manifests.has(path):
		return _manifests[path]
	var manifest: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			manifest = parsed
	_manifests[path] = manifest
	return manifest


func _add_tracks(tracks: Array[Dictionary]) -> void:
	var columns: int = 1 if LeadlightTokens.is_phone(shape) else 2
	var per: int = ceili(float(tracks.size()) / float(columns))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Tracks"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for c: int in range(columns):
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var first: int = c * per
		var last: int = mini(tracks.size(), first + per)
		_add_rows(column, tracks.slice(first, mini(last, first + ROWS_NOW)))
		if last > first + ROWS_NOW:
			_later.append(_add_rows.bind(column, tracks.slice(first + ROWS_NOW, last)))


func _add_rows(column: VBoxContainer, items: Array[Dictionary]) -> void:
	for item: Dictionary in items:
		column.add_child(_track(item))


func _track(item: Dictionary) -> Control:
	var seat: HBoxContainer = HBoxContainer.new()
	seat.alignment = BoxContainer.ALIGNMENT_CENTER
	seat.add_theme_constant_override("separation", 8)
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text: String = track_text(item, _unsealed)
	var held: bool = text == HELD_MARK
	var name_px: Vector2i = LeadlightTokens.SIZE_ROOM_HEAD
	var label: Label = _label(text, LeadlightTokens.ROLE_READ, name_px,
		LeadlightTokens.TEXT_DIM if held else LeadlightTokens.PARCHMENT)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.name = "Track_%s" % str(item.get("id", ""))
	if not held and StringName(str(item.get("id", ""))) == _now and not _now.is_empty():
		var glyph: LeadlightPlaque.Glyph = LeadlightPlaque.Glyph.new()
		var px: float = float(LeadlightTokens.size_for(name_px, shape))
		glyph.name = "NowPlaying"
		glyph.custom_minimum_size = Vector2(px * 0.7, px * 1.1)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		now_glyph = glyph
		seat.add_child(glyph)
	seat.add_child(label)
	lines.append(label)
	return seat


func _add_licence_panes() -> void:
	var row: BoxContainer = VBoxContainer.new() if LeadlightTokens.is_phone(shape) else HBoxContainer.new()
	row.name = "Licences"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 10.0
	add_child(spacer)
	add_child(row)
	var hit: float = LeadlightTokens.room_hit(shape)
	font_pane = LeadlightPane.new(Locale.active.t("ui.credits.fontLicences"), shape)
	engine_pane = LeadlightPane.new(Locale.active.t("ui.credits.engineLicences"), shape)
	for pair: Array in [[font_pane, &"fonts", "FontLicences"], [engine_pane, &"engine", "EngineLicences"]]:
		var pane: LeadlightPane = pair[0]
		pane.name = str(pair[2])
		pane.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, shape))
		pane.custom_minimum_size.y = hit - 12.0 if not LeadlightTokens.is_phone(shape) else hit
		pane.hit_height = hit
		pane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pane.pressed.connect(func() -> void: licence_requested.emit(pair[1]))
		row.add_child(pane)


func _heading(text: String) -> void:
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 18.0 if not LeadlightTokens.is_phone(shape) else 10.0
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
	_line(text, LeadlightTokens.ROLE_PRIMARY, LeadlightTokens.SIZE_ROOM_HEAD, LeadlightTokens.GOLD)


func _body(text: String) -> void:
	_line(text, LeadlightTokens.ROLE_READ, LeadlightTokens.SIZE_ROOM_HEAD, LeadlightTokens.PARCHMENT)


func _secondary(text: String) -> void:
	_line(text, LeadlightTokens.ROLE_READ, LeadlightTokens.SIZE_ROOM_READ, LeadlightTokens.TEXT)


func _line(text: String, role: StringName, token: Vector2i, colour: Color) -> Label:
	var label: Label = _label(text, role, token, colour)
	add_child(label)
	lines.append(label)
	return label


func _label(text: String, role: StringName, token: Vector2i, colour: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px: int = LeadlightTokens.size_for(token, shape)
	label.add_theme_font_override("font", LeadlightTokens.font(role, px))
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", colour)
	label.set_meta(&"base", colour)
	return label


## Warm every line by how near the lamp line (`lamp_y`, stage px) it stands:
## alpha 0.75 to 1, its colour towards warm parchment. A modulate per label.
func warm(lamp_y: float, reach: float) -> void:
	for label: Label in lines:
		var y: float = label.get_global_rect().get_center().y
		var w: float = 1.0 - clampf(absf(y - lamp_y) / maxf(reach, 1.0), 0.0, 1.0)
		var base: Color = label.get_meta(&"base", LeadlightTokens.PARCHMENT)
		var to: Color = base.lerp(WARM, 0.6 * w)
		label.self_modulate = Color(to.r / maxf(base.r, 0.01), to.g / maxf(base.g, 0.01),
			to.b / maxf(base.b, 0.01), 0.75 + 0.25 * w)
