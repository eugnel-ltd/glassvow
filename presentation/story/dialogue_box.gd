class_name DialogueBox
extends Control
## The leaded dialogue pane: a dark cathedral-glass body inside a heavy lead
## came, a worn gold hairline, jewel rosettes at the corners that take the
## speaker's glass colour, and a name plaque riding the top edge on the
## speaker's side. Lines type in at a reading pace that knows CJK from Latin
## and breathes at punctuation; a lozenge ember bobs when the line is done.
##
## Styles change the delivery, never the grammar: `speech`, `narration`
## (no plaque, centred, slanted), `shout` (bigger, lands at once, the frame
## flares), `whisper` (small, dim, slow), `chorus` (a second voice echoes a
## half-beat behind), `title` (no pane at all — a gold card over the scene).
##
## Layout is a pure function of the stage size (`box_rect`) so geometry is
## testable headless. `Line` stays a Label — callers and tests read `.text`;
## the reveal only moves `visible_characters` over the already-shaped line
## (`VC_CHARS_AFTER_SHAPING`), so wrapping never reflows while it types.

const CPS_LATIN: float = 50.0
const CPS_CJK: float = 24.0
const PAUSE_STOP: float = 0.26
const PAUSE_COMMA: float = 0.11
const PAUSE_DASH: float = 0.20
const WHISPER_PACE: float = 0.72
const STOPS: String = "。！？.!?"
const COMMAS: String = "，、,;；：:"
const DASHES: String = "…—–"

const LEAD: Color = Color(0.018, 0.016, 0.024, 0.97)
const BODY_TOP: Color = Color(0.070, 0.078, 0.125, 0.94)
const BODY_BOT: Color = Color(0.030, 0.034, 0.060, 0.96)
const HAIRLINE: Color = Color(0.83, 0.66, 0.33, 0.62)
const TEXT_SPEECH: Color = Color("#e6e1d3")
const TEXT_NARRATION: Color = Color("#cfd4dc")
const TEXT_WHISPER: Color = Color("#9fa8b8")
const TEXT_SHOUT: Color = Color("#fff2dc")
const TEXT_CHORUS: Color = Color("#e9d7a4")
const TITLE_GOLD: Color = Color("#f2d38a")
const SHOUT_FLARE: Color = Color(1.0, 0.52, 0.22)

var style: StringName = StageDirection.STYLE_NARRATION
var side: StringName = &"left"
var tint: Color = RunStyle.GOLD
var shape: StringName = StageShape.IDENTITY
var reduce_motion: bool = false

var _speaker: Label
var _line: Label
var _echo: Label
var _plaque: PanelContainer
var _gem: Control
var _glyph: Control
var _times: PackedFloat32Array = PackedFloat32Array()
var _type_time: float = 0.0
var _elapsed: float = 0.0
var _complete: bool = true
var _clock: float = 0.0
var _flare: float = 0.0
var _jolt: float = 0.0


func _init() -> void:
	name = "DialogueBox"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo = _label("Echo")
	add_child(_echo)
	_line = _label("Line")
	add_child(_line)
	_plaque = PanelContainer.new()
	_plaque.name = "Plaque"
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plaque)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(row)
	_gem = Control.new()
	_gem.name = "Gem"
	_gem.custom_minimum_size = Vector2(10.0, 10.0)
	_gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gem.draw.connect(_draw_gem)
	row.add_child(_gem)
	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_override("font", RunStyle.tracked(GlassStyle.CINZEL_700, 2))
	_speaker.add_theme_color_override("font_color", TITLE_GOLD)
	row.add_child(_speaker)
	_glyph = Control.new()
	_glyph.name = "Advance"
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.custom_minimum_size = Vector2(14.0, 14.0)
	_glyph.size = Vector2(14.0, 14.0)
	_glyph.draw.connect(_draw_glyph)
	add_child(_glyph)
	resized.connect(_layout)


## The pane's rect on a stage of `view`. `clear_right` (a fraction of the
## width, 0 = none) keeps the pane off a figure standing in the plate itself.
static func box_rect(view: Vector2, stage_shape: StringName, box_style: StringName,
		clear_right: float = 0.0) -> Rect2:
	var short: bool = stage_shape == &"phone-landscape"
	var band: float = view.y * (0.05 if short else 0.08)
	if box_style == StageDirection.STYLE_TITLE:
		var w: float = view.x * 0.78
		var h: float = view.y * (0.26 if short else 0.18)
		var x: float = (view.x - w) * 0.5
		# A card keeps clear of a figure standing in the plate, as the pane does.
		if clear_right > 0.0 and x + w > view.x * clear_right - 18.0:
			var clear_w: float = view.x * clear_right - 18.0 - 40.0
			if clear_w >= 480.0:
				x = 40.0
				w = clear_w
		return Rect2(x, view.y * 0.70 - h * 0.5, w, h)
	var height: float = 112.0 if short else 152.0
	var bottom: float = view.y - band - (6.0 if short else 12.0)
	var margin: float = 14.0 if short else maxf(48.0, view.x * 0.12)
	var width: float = minf(view.x - margin * 2.0, 980.0)
	var left: float = (view.x - width) * 0.5
	if clear_right > 0.0 and not short:
		var right_edge: float = view.x * clear_right - 18.0
		var clear_left: float = 40.0
		if right_edge - clear_left >= 480.0 and left + width > right_edge:
			left = clear_left
			width = right_edge - clear_left
	return Rect2(left, bottom - height, width, height)


## The leaded window a staged screen docks its choices in, cut from the
## same glass as the pane (one definition, so the two never drift).
static func window_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.034, 0.055, 0.90)
	box.set_border_width_all(4)
	box.border_color = LEAD
	box.set_corner_radius_all(10)
	box.set_content_margin_all(14)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 18
	return box


## Present one line. `instant` lands it whole (capture, resume, skip, and
## reduced motion — reduced motion never shortens the dwell, only the reveal).
func show_line(text: String, speaker_name: String, line_style: StringName,
		speaker_tint: Color, plaque_side: StringName, instant: bool) -> void:
	style = line_style
	tint = speaker_tint
	side = plaque_side
	_line.text = text
	_echo.text = text
	_speaker.text = speaker_name
	_plaque.visible = not speaker_name.is_empty() \
		and style != StageDirection.STYLE_NARRATION \
		and style != StageDirection.STYLE_TITLE
	_echo.visible = style == StageDirection.STYLE_CHORUS
	_apply_style()
	_build_times(text)
	_elapsed = 0.0
	_flare = 1.0 if style == StageDirection.STYLE_SHOUT else 0.0
	_jolt = 1.0 if style == StageDirection.STYLE_SHOUT and not instant else 0.0
	if instant or reduce_motion or style == StageDirection.STYLE_SHOUT:
		complete()
	else:
		_complete = false
		_line.visible_characters = 0
		_echo.visible_characters = 0
	_layout()
	queue_redraw()


## Advance the reveal and the pane's own motion. Driven by the scene player
## every frame (so headless tests drive it too). True once the line stands.
func advance_type(delta: float) -> bool:
	_clock += delta
	var flaring: bool = _flare > 0.0
	_flare = maxf(0.0, _flare - delta * 1.6)
	if _jolt > 0.0:
		_jolt = maxf(0.0, _jolt - delta * 3.2)
		var home: float = _text_rect().position.x
		_line.position.x = home + sin(_clock * 90.0) * 3.0 * _jolt
	if _complete:
		# Only the advance ember moves once a line stands; the leaded frame
		# redraws only while a shout's flare is still fading.
		_glyph.queue_redraw()
		if flaring:
			queue_redraw()
		return true
	_elapsed += delta
	var shown: int = 0
	while shown < _times.size() and _times[shown] <= _elapsed:
		shown += 1
	_line.visible_characters = shown
	# The chorus echo trails a half-beat behind its own words.
	var echo_shown: int = 0
	while echo_shown < _times.size() and _times[echo_shown] <= _elapsed - 0.14:
		echo_shown += 1
	_echo.visible_characters = echo_shown
	if shown >= _times.size() and _elapsed >= _type_time + 0.14:
		complete()
	queue_redraw()
	return _complete


func complete() -> void:
	_complete = true
	_line.visible_characters = -1
	_echo.visible_characters = -1
	_glyph.queue_redraw()


func is_complete() -> bool:
	return _complete


## Seconds the reveal takes at this line's pace.
func type_time() -> float:
	return _type_time


## Seat the pane at `rect` and lay its text out now. Setting `size` on a
## node outside the tree emits no `resized`, so callers place explicitly.
func place(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	custom_minimum_size = Vector2(rect.size.x, 0.0)
	_layout()


func line_label() -> Label:
	return _line


func speaker_label() -> Label:
	return _speaker


func set_shape(stage_shape: StringName) -> void:
	shape = stage_shape
	_apply_style()
	_layout()


func _build_times(text: String) -> void:
	_times = PackedFloat32Array()
	_times.resize(text.length())
	var pace: float = WHISPER_PACE if style == StageDirection.STYLE_WHISPER else 1.0
	var t: float = 0.0
	for i: int in range(text.length()):
		_times[i] = t
		var ch: String = text[i]
		var cjk: bool = text.unicode_at(i) >= 0x2E80
		t += 1.0 / ((CPS_CJK if cjk else CPS_LATIN) * pace)
		if i == text.length() - 1:
			break
		if STOPS.contains(ch):
			t += PAUSE_STOP
		elif COMMAS.contains(ch):
			t += PAUSE_COMMA
		elif DASHES.contains(ch):
			t += PAUSE_DASH
	_type_time = t


func _apply_style() -> void:
	var short: bool = shape == &"phone-landscape"
	var base: int = 14 if short else 21
	var face: Font = GlassStyle.face(GlassStyle.ALEGREYA_400)
	# Han script has no italic; a sheared CJK line reads as a rendering fault.
	var quiet_face: Font = face if Locale.active.code == Locale.CODE_ZH_HANT \
		else RunStyle.slanted(GlassStyle.ALEGREYA_400)
	var colour: Color = TEXT_SPEECH
	var size_px: int = base
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	match style:
		StageDirection.STYLE_NARRATION:
			face = quiet_face
			colour = TEXT_NARRATION
			align = HORIZONTAL_ALIGNMENT_CENTER
		StageDirection.STYLE_SHOUT:
			face = GlassStyle.face(GlassStyle.ALEGREYA_700)
			colour = TEXT_SHOUT
			size_px = base + (3 if short else 6)
		StageDirection.STYLE_WHISPER:
			face = quiet_face
			colour = TEXT_WHISPER
			size_px = base - (1 if short else 2)
		StageDirection.STYLE_CHORUS:
			colour = TEXT_CHORUS
		StageDirection.STYLE_TITLE:
			face = RunStyle.tracked(GlassStyle.CINZEL_700, 3)
			colour = TITLE_GOLD
			size_px = 20 if short else 34
			align = HORIZONTAL_ALIGNMENT_CENTER
	var valign: VerticalAlignment = VERTICAL_ALIGNMENT_TOP
	if style == StageDirection.STYLE_NARRATION or style == StageDirection.STYLE_TITLE:
		valign = VERTICAL_ALIGNMENT_CENTER
	for label: Label in [_line, _echo]:
		label.add_theme_font_override("font", face)
		label.add_theme_font_size_override("font_size", size_px)
		label.horizontal_alignment = align
		label.vertical_alignment = valign
	_line.add_theme_color_override("font_color", colour)
	_line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_line.add_theme_constant_override("shadow_offset_y", 2)
	_line.add_theme_constant_override("shadow_outline_size", 4 if style == StageDirection.STYLE_TITLE else 0)
	_echo.add_theme_color_override("font_color", Color(tint, 0.30))
	_speaker.add_theme_font_size_override("font_size", 11 if short else 14)
	_plaque.add_theme_stylebox_override("panel", _plaque_style(short))


func _layout() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var text_rect: Rect2 = _text_rect()
	_line.position = text_rect.position
	_line.size = text_rect.size
	_echo.position = text_rect.position + Vector2(3.0, 2.0)
	_echo.size = text_rect.size
	var short: bool = shape == &"phone-landscape"
	var plaque_size: Vector2 = _plaque.get_combined_minimum_size()
	_plaque.size = plaque_size
	var inset: float = 22.0 if short else 34.0
	var px: float = inset if side != &"right" else size.x - inset - plaque_size.x
	_plaque.position = Vector2(px, -plaque_size.y * 0.62)
	_glyph.position = Vector2(size.x - (22.0 if short else 30.0),
		size.y - (20.0 if short else 26.0))


func _text_rect() -> Rect2:
	if style == StageDirection.STYLE_TITLE:
		return Rect2(Vector2.ZERO, size)
	var short: bool = shape == &"phone-landscape"
	var pad_x: float = 22.0 if short else 40.0
	var pad_top: float = 18.0 if short else 30.0
	var pad_bottom: float = 14.0 if short else 22.0
	return Rect2(pad_x, pad_top, size.x - pad_x * 2.0, size.y - pad_top - pad_bottom)


func _draw() -> void:
	if style == StageDirection.STYLE_TITLE or size.x < 8.0:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var quiet: bool = style == StageDirection.STYLE_NARRATION \
		or style == StageDirection.STYLE_WHISPER
	var body_alpha: float = 0.74 if quiet else 1.0
	# Soft drop shadow, stacked rather than blurred (no backbuffer).
	for i: int in range(4):
		var grow: float = 6.0 + float(i) * 7.0
		draw_style_box(_round(Color(0, 0, 0, 0.16 - float(i) * 0.03), 14.0 + grow),
			rect.grow(grow).grow_individual(0, -grow * 0.3, 0, grow * 0.2))
	# The glass body: a cold cathedral dark, lit faintly from the speaker's
	# side by their own glass colour.
	var body: StyleBoxFlat = _round(Color(BODY_BOT, BODY_BOT.a * body_alpha), 12.0)
	draw_style_box(body, rect)
	# The speaker's glass colour bleeds in from their own side of the pane.
	var bleed: float = 0.20 * body_alpha
	if style == StageDirection.STYLE_NARRATION:
		bleed *= 0.35
	var from_right: bool = side == &"right"
	var bleed_w: float = size.x * 0.62
	var bleed_x: float = size.x - bleed_w if from_right else 0.0
	var lit: Color = Color(tint, bleed)
	var clear: Color = Color(tint, 0.0)
	draw_polygon(PackedVector2Array([
		Vector2(bleed_x, 4.0), Vector2(bleed_x + bleed_w, 4.0),
		Vector2(bleed_x + bleed_w, size.y - 4.0), Vector2(bleed_x, size.y - 4.0)]),
		PackedColorArray([clear, lit, lit, clear] if from_right else [lit, clear, clear, lit]))
	# Cold sheen across the upper glass, fading out — never a hard edge.
	var sheen: Color = Color(BODY_TOP, BODY_TOP.a * body_alpha * 0.6)
	var none: Color = Color(BODY_TOP, 0.0)
	var sheen_h: float = size.y * 0.55
	draw_polygon(PackedVector2Array([Vector2(6.0, 5.0), Vector2(size.x - 6.0, 5.0),
		Vector2(size.x - 6.0, sheen_h), Vector2(6.0, sheen_h)]),
		PackedColorArray([sheen, sheen, none, none]))
	# Heavy lead came, then the worn gold hairline inside it.
	var flare: Color = LEAD.lerp(SHOUT_FLARE, _flare * 0.7)
	var came: StyleBoxFlat = _round(Color(0, 0, 0, 0), 12.0)
	came.set_border_width_all(5)
	came.border_color = flare
	draw_style_box(came, rect)
	var hair: StyleBoxFlat = _round(Color(0, 0, 0, 0), 8.0)
	hair.set_border_width_all(1)
	hair.border_color = Color(HAIRLINE, HAIRLINE.a * (0.55 if quiet else 1.0))
	draw_style_box(hair, rect.grow(-7.0))
	# Leaded mullion ticks along the top and bottom rails — the pane is a
	# window strip, not a card.
	var tick_gap: float = 132.0 if shape != &"phone-landscape" else 96.0
	var x_tick: float = tick_gap
	while x_tick < size.x - tick_gap * 0.5:
		draw_line(Vector2(x_tick, 0.0), Vector2(x_tick, 7.0), LEAD, 3.0)
		draw_line(Vector2(x_tick, size.y - 7.0), Vector2(x_tick, size.y), LEAD, 3.0)
		x_tick += tick_gap
	# Corner rosettes in the speaker's glass.
	var jewel: Color = tint if style != StageDirection.STYLE_NARRATION else HAIRLINE
	for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0),
			Vector2(0, size.y), Vector2(size.x, size.y)]:
		var inward: Vector2 = Vector2(
			7.0 if corner.x < 1.0 else -7.0, 7.0 if corner.y < 1.0 else -7.0)
		_draw_lozenge(self, corner + inward, 8.0 + _flare * 3.0, jewel)


static func _draw_lozenge(canvas: CanvasItem, at: Vector2, r: float, colour: Color) -> void:
	var outer: PackedVector2Array = PackedVector2Array([
		at + Vector2(0, -r - 2.5), at + Vector2(r + 2.5, 0),
		at + Vector2(0, r + 2.5), at + Vector2(-r - 2.5, 0)])
	canvas.draw_colored_polygon(outer, LEAD)
	var inner: PackedVector2Array = PackedVector2Array([
		at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	canvas.draw_colored_polygon(inner, colour.darkened(0.25))
	var shine: PackedVector2Array = PackedVector2Array([
		at + Vector2(0, -r * 0.8), at + Vector2(r * 0.45, -r * 0.15),
		at + Vector2(0, r * 0.05), at + Vector2(-r * 0.45, -r * 0.15)])
	canvas.draw_colored_polygon(shine, colour.lightened(0.35))
	canvas.draw_polyline(PackedVector2Array([outer[0], outer[1], outer[2], outer[3], outer[0]]),
		Color(HAIRLINE, 0.8), 1.0)


func _draw_gem() -> void:
	_draw_lozenge(_gem, _gem.size * 0.5, 4.5, tint)


## The advance lozenge: an ember that bobs and breathes once the line stands.
func _draw_glyph() -> void:
	if not _complete or style == StageDirection.STYLE_TITLE:
		return
	var bob: float = 0.0 if reduce_motion else sin(_clock * 4.2) * 2.5
	var breath: float = 0.75 + 0.25 * (0.5 + 0.5 * sin(_clock * 3.1))
	var at: Vector2 = _glyph.size * 0.5 + Vector2(0.0, bob)
	var halo: Color = Color(GlassStyle.EMBER, 0.18 * breath)
	_glyph.draw_circle(at, 9.0, halo)
	_draw_lozenge(_glyph, at, 4.5, Color(GlassStyle.EMBER, breath))


func _plaque_style(short: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.032, 0.05, 0.98)
	box.set_border_width_all(3)
	box.border_color = LEAD
	box.set_corner_radius_all(6)
	box.content_margin_left = 12.0 if short else 16.0
	box.content_margin_right = 14.0 if short else 20.0
	box.content_margin_top = 3.0 if short else 5.0
	box.content_margin_bottom = 3.0 if short else 5.0
	box.shadow_color = Color(tint, 0.30)
	box.shadow_size = 8
	return box


static func _round(fill: Color, radius: float) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	return box


static func _label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
