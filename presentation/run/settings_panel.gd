class_name SettingsPanel
extends LeadlightRoomHost
## The player-facing settings overlay: AUDIO / DISPLAY / MOTION / PRIVACY /
## THE LEDGER, with the route behind it staying visible. Reads and writes the
## main-owned Preferences handle; the DISPLAY section hides itself where the
## platform owns the window (web) or there is no window at all (headless).
##
## Settings is the lantern-maker's window (docs/design/2026-10-03-title-rooms
## §4.4): a leaded arched window (LeadlightRoom) standing right of the seat,
## fitted to its tallest section, lit by the seated lantern. Its sections are
## panes, every control from the Leadlight kit at the rubric's floor, and the
## way back is the seat's Return. The passage plays its sounds.

signal reset_requested
signal language_changed(code: StringName)

const GOLD: Color = LeadlightTokens.GOLD
const DANGER: Color = LeadlightTokens.DANGER
## The room on the identity stage (§3.2): right of the seat, its centre this far
## right of the stage's, its foot clear of the seat's word; a phone fills the
## stage beside the seat.
const ROOM_W: float = 792.0
const ROOM_MAX_H: float = 470.0
const ROOM_SHIFT: float = 124.0
const ROOM_TOP: float = 300.0
## On a phone: from x 108 (right of the seat's lantern) to 6 px from the right
## edge, and from 6 px under the top to 60 px over the foot (the seat's word).
const PHONE_LEFT: float = 108.0
const PHONE_RIGHT: float = 6.0
const PHONE_TOP: float = 6.0
const PHONE_FOOT: float = 60.0

var _preferences: Preferences
var _sfx: SfxBus
var _room: LeadlightRoom
var _brand_line: Label
var _language_toggle: Button
var _language_label: Label
var _language_deferred: bool
var _reset_disabled: bool
## The volume sliders, whose lantern discs breathe with the room's light.
var _sliders: Array[LeadlightSlider] = []
var _time: float = 0.0
## The one-line diagnostics notice, present only in the first panel built
## after install (see `_add_diagnostics`).
var _diagnostics_notice: Label
## Opens an address in the system browser. A seam for tests, which hand in a
## recorder so no suite run ever launches a browser.
var open_url: Callable = Callable(OS, "shell_open")


func _init(preferences: Preferences, reset_disabled: bool = false,
		sfx: SfxBus = null, language_deferred: bool = false) -> void:
	_host(StageShape.IDENTITY)
	_preferences = preferences
	_language_deferred = language_deferred
	_reset_disabled = reset_disabled
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		# Injected bus already lives under main; only own a fallback.
		add_child(_sfx)
	_build()


func _build() -> void:
	_room = LeadlightRoom.new(Locale.active.t("ui.settings.title"), shape)
	_room.section_chosen.connect(func(_id: StringName) -> void: _sfx.play_owed(&"paneChoose", &"click"))
	add_child(_room)

	var audio: VBoxContainer = _section(&"audio", Locale.active.t("ui.settings.audio"), GOLD)
	audio.add_child(_audio_row(Locale.active.t("ui.settings.master"), Preferences.MASTER))
	audio.add_child(_audio_row(Locale.active.t("ui.settings.music"), Preferences.MUSIC))
	audio.add_child(_audio_row(Locale.active.t("ui.settings.sfx"), Preferences.SFX))

	if _display_supported():
		var display: VBoxContainer = _section(&"display", Locale.active.t("ui.settings.display"), GOLD)
		display.add_child(_toggle_row(Locale.active.t("ui.settings.fullscreen"),
			func() -> bool: return _preferences.fullscreen,
			func(on: bool) -> void: _preferences.set_fullscreen(on)))
		display.add_child(_toggle_row(Locale.active.t("ui.settings.vsync"),
			func() -> bool: return _preferences.vsync,
			func(on: bool) -> void: _preferences.set_vsync(on)))
		display.add_child(_language_row())
	else:
		# Web / headless have no window toggles; language still must be reachable.
		var language_section: VBoxContainer = _section(
			&"display", Locale.active.t("ui.language.label"), GOLD)
		language_section.add_child(_language_row())

	var motion: VBoxContainer = _section(&"motion", Locale.active.t("ui.settings.motion"), GOLD)
	motion.add_child(_toggle_row(Locale.active.t("ui.settings.screenShake"),
		func() -> bool: return _preferences.screen_shake,
		func(on: bool) -> void: _preferences.set_screen_shake(on)))
	motion.add_child(_toggle_row(Locale.active.t("ui.settings.reduceMotion"),
		func() -> bool: return _preferences.reduce_motion,
		func(on: bool) -> void: _preferences.set_reduce_motion(on)))

	var privacy: VBoxContainer = _section(&"privacy", Locale.active.t("ui.settings.privacy"), GOLD)
	_add_diagnostics(privacy)
	_add_policy_link(privacy)

	# The destructive section is its own pane in the danger accent — reaching
	# it takes a deliberate choice, and ERASE keeps its two-step confirmation.
	# Its sound is the confirm's arrival (one cue per tap).
	var ledger: VBoxContainer = _section(&"ledger", Locale.active.t("ui.settings.ledger"), DANGER)
	var erase: Button = _button(Locale.active.t("ui.settings.eraseAll").to_upper(), DANGER, shape)
	erase.disabled = _reset_disabled
	erase.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	erase.pressed.connect(func() -> void: reset_requested.emit())
	ledger.add_child(erase)
	var warning: Label = _note(Locale.active.t("ui.settings.resetWarn"), shape)
	ledger.add_child(warning)

	# The build, as the title's corner shows it: a report's identifier, not
	# read for any choice (the one waiver, §14 of the rooms spec).
	var footer: Label = Label.new()
	footer.name = "BrandLine"
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var brand: String = Locale.active.t("ui.brand.title")
	footer.text = "%s %s" % [brand, version] if version != "" else brand
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 2))
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(GlassStyle.TEXT_DIM, 0.7))
	_room.footer().add_child(footer)
	_brand_line = footer
	_seat_last()
	# A notice recorded as shown must be on screen: the first panel after
	# install opens on PRIVACY.
	if _diagnostics_notice != null:
		_room.select(&"privacy")


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape) or stage_shape == shape:
		super(stage_shape)
		return
	# The rows are cut for their shape: a new shape rebuilds the room, on the
	# section that was lit.
	var lit: StringName = _room.selected()
	var focused: bool = _language_toggle != null and _language_toggle.has_focus()
	shape = stage_shape
	remove_child(_room)
	_room.free()
	_sliders.clear()
	remove_child(_seat)
	_seat.free()
	_build()
	_room.select(lit)
	if focused:
		focus_language()
	super(stage_shape)


func sheet() -> LeadlightSheet:
	return _room


func crown() -> Control:
	return _room.crown()


func reveal_groups() -> Array[Control]:
	return [_room.tabs(), _room.scroll(), _room.footer()]


## The lit section's pane, unless the language control asked for focus.
func first_focus() -> Control:
	if _focus_first != null:
		return _focus_first
	return _room.tab(_room.selected())


func content_rects() -> Array[Rect2]:
	return [Rect2(_room.position, _room.size)]


## The room stands right of the seat (§3.2), as tall as its tallest section
## needs and no taller, its foot clear of the seat's word; on a phone it fills
## the stage beside the seat.
func _fit() -> void:
	if _room == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if LeadlightTokens.is_phone(shape):
		_room.position = Vector2(PHONE_LEFT, PHONE_TOP)
		_room.size = Vector2(size.x - PHONE_LEFT - PHONE_RIGHT, size.y - PHONE_TOP - PHONE_FOOT)
	else:
		var tall: float = minf(_needed_height(), ROOM_MAX_H)
		var foot: float = size.y - (820.0 - ROOM_TOP - ROOM_MAX_H)
		_room.size = Vector2(ROOM_W, tall)
		_room.position = Vector2((size.x - ROOM_W) * 0.5 + ROOM_SHIFT, foot - tall)
	_room.set_light(LeadlightTokens.EMBER, Vector2(-0.2, 1.1))
	# A phone's short room keeps its rows; the title already shows the build.
	_brand_line.visible = not LeadlightTokens.is_phone(shape)


## The height that holds the tallest section, the crown, the footer and the
## glass's margins: the arch's spring is a share of the height, so it is solved.
func _needed_height() -> float:
	var body: float = _room.tabs().get_combined_minimum_size().y
	for id: StringName in _room.section_ids():
		var page_node: Control = _room.page(id)
		var shown: bool = page_node.visible
		page_node.visible = true
		body = maxf(body, page_node.get_combined_minimum_size().y)
		page_node.visible = shown
	var footer: float = _room.footer().get_combined_minimum_size().y + 10.0
	var margins: float = 12.0 + 18.0
	return ceilf((body + footer + margins) / (1.0 - _room.spring)) + 6.0


## Alive at rest (§4.4): the sliders' lantern discs breathe ±6% in step with
## the lit pane (3.3 s); still under Reduce Motion, as the glass is.
func _process(delta: float) -> void:
	if LeadlightMotion.reduced():
		return
	_time += delta
	var glow: float = 1.0 + 0.06 * LeadlightMotion.breath(_time, 3.3)
	for slider: LeadlightSlider in _sliders:
		if is_instance_valid(slider):
			slider.self_modulate = Color(glow, glow, glow, 1.0)


static func _display_supported() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _section(id: StringName, heading: String, accent: Color) -> VBoxContainer:
	return _room.add_section(id, heading, accent)


func _audio_row(label_text: String, bus: StringName) -> LeadlightRow:
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider: LeadlightSlider = LeadlightSlider.new(roundf(_preferences.volume(bus) * 100.0))
	_sliders.append(slider)
	slider.tooltip_text = Locale.active.t("ui.settings.volumeTip", {"name": label_text})
	slider.custom_minimum_size.y = LeadlightTokens.room_hit(shape)
	controls.add_child(slider)
	var mute: Button = _small_button(shape)
	controls.add_child(mute)
	var row: LeadlightRow = LeadlightRow.new(label_text, controls, shape)
	var sync: Callable = func() -> void:
		var muted: bool = _preferences.is_muted(bus)
		mute.text = Locale.active.t(
			"ui.settings.unmute" if muted else "ui.settings.mute").to_upper()
		slider.editable = not muted
	sync.call()
	slider.value_changed.connect(func(value: float) -> void:
		_preferences.set_volume(bus, value / 100.0)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		_sfx.play(&"click")
	)
	mute.pressed.connect(func() -> void:
		_preferences.set_muted(bus, not _preferences.is_muted(bus))
		sync.call()
		_sfx.play(&"click")
	)
	return row


## Language cycles English ↔ 繁體中文: the control names the language on
## screen, and pressing it asks for the other. Labels are themselves
## localised. Live re-render is owned by main (rebuild the routed screen);
## mid-combat defers until the next route — see ui.language.deferNote.
func _language_row() -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)

	_language_toggle = _small_button(shape)
	_language_toggle.name = "LanguageToggle"
	_language_toggle.custom_minimum_size.x = maxf(
		_language_toggle.custom_minimum_size.x, 132.0)
	var code: StringName = _preferences.effective_language()
	_language_toggle.text = Locale.active.t(
		"ui.language.zhHant" if code == Locale.CODE_ZH_HANT else "ui.language.en")
	_language_toggle.pressed.connect(func() -> void:
		var next: StringName = Locale.CODE_EN \
			if _preferences.effective_language() == Locale.CODE_ZH_HANT \
			else Locale.CODE_ZH_HANT
		_sfx.play(&"click")
		language_changed.emit(next)
	)
	var row: LeadlightRow = LeadlightRow.new(
		Locale.active.t("ui.language.label"), _language_toggle, shape)
	_language_label = row.label()
	_language_label.name = "LanguageLabel"
	body.add_child(row)

	if _language_deferred:
		var note: Label = _note(Locale.active.t("ui.language.deferNote"), shape)
		note.name = "LanguageDeferNote"
		body.add_child(note)
	return body


## Crash diagnostics. The main loop reads this switch before Sentry starts, so
## the note under it says a change waits for the next launch. The first panel
## built after install also carries the one-line notice, recorded as shown at
## once so it never returns (docs/privacy/README.md, D1 option B).
func _add_diagnostics(section: VBoxContainer) -> void:
	var row: LeadlightRow = _toggle_row(
		Locale.active.t("ui.settings.diagnostics"),
		func() -> bool: return _preferences.diagnostics_enabled,
		func(on: bool) -> void: _preferences.set_diagnostics_enabled(on))
	row.name = "DiagnosticsRow"
	section.add_child(row)
	if not _preferences.diagnostics_notice_seen or _diagnostics_notice != null:
		_diagnostics_notice = _note(Locale.active.t("ui.settings.diagnosticsNotice"), shape)
		_diagnostics_notice.name = "DiagnosticsNotice"
		section.add_child(_diagnostics_notice)
		_preferences.mark_diagnostics_notice_seen()
	var note: Label = _note(Locale.active.t("ui.settings.diagnosticsNote"), shape)
	note.name = "DiagnosticsNote"
	section.add_child(note)


## The privacy policy for the language on screen, opened in the system
## browser. It sits last in PRIVACY, so focus order runs the switch, then the
## policy, then THE LEDGER, as the rows read.
func _add_policy_link(section: VBoxContainer) -> void:
	var link: Button = _button(
		Locale.active.t("ui.settings.privacyPolicy").to_upper(), GOLD, shape)
	link.name = "PrivacyPolicyButton"
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	link.pressed.connect(_open_policy)
	section.add_child(link)


func _open_policy() -> void:
	_sfx.play(&"click")
	var url: String = PrivacyPolicy.url_for(Locale.active.code)
	var result: Variant = open_url.call(url)
	if result is int and result != OK:
		push_warning("Settings: could not open the privacy policy (error %d)" % result)


## Moves keyboard focus and the settings scroll to the language control.
func focus_language() -> void:
	if _language_toggle == null:
		return
	_room.select(&"display")
	_focus_first = _language_toggle
	LeadlightFocus.give_deferred(_language_toggle)
	_room.scroll().ensure_control_visible.call_deferred(_language_toggle)


## A labelled glass switch reading through a getter so it always restates the
## stored truth rather than a mirrored local.
func _toggle_row(label_text: String, getter: Callable, setter: Callable) -> LeadlightRow:
	var toggle: LeadlightToggle = LeadlightToggle.new(getter, setter)
	toggle.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, shape))
	toggle.custom_minimum_size.y = LeadlightTokens.room_hit(shape)
	toggle.pressed.connect(func() -> void: _sfx.play(&"click"))
	return LeadlightRow.new(label_text, toggle, shape)


## A row's pane (Erase All Progress, the Privacy Policy link) at the room's
## label size, its tap at the room's floor.
static func _button(text: String, accent: Color, stage_shape: StringName = StageShape.IDENTITY) -> Button:
	var button: LeadlightPane = LeadlightPane.new(text, stage_shape)
	button.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, stage_shape))
	button.accent = accent
	button.lit = false
	var hit: float = LeadlightTokens.room_hit(stage_shape)
	button.custom_minimum_size.y = hit - 12.0 if not LeadlightTokens.is_phone(stage_shape) else hit
	button.hit_height = hit
	return button


static func _small_button(stage_shape: StringName = StageShape.IDENTITY) -> Button:
	var button: LeadlightPane = LeadlightPane.new("", stage_shape, LeadlightGlassBox.Shape.RECT)
	var hit: float = LeadlightTokens.room_hit(stage_shape)
	button.custom_minimum_size = Vector2(96.0 if not LeadlightTokens.is_phone(stage_shape) else 80.0,
		hit - 16.0 if not LeadlightTokens.is_phone(stage_shape) else hit)
	button.hit_height = hit
	button.set_px(LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_LABEL, stage_shape))
	return button


## A dim wrapped line under a control: the language defer note, the
## diagnostics notice and note, and the ledger's warning.
static func _note(text: String, stage_shape: StringName = StageShape.IDENTITY) -> Label:
	var note: Label = Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_ROOM_READ, stage_shape)
	note.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	note.add_theme_font_size_override("font_size", px)
	note.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return note


static func _tracked_font(path: String, glyph_spacing: int) -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = GlassStyle.face(path)
	tracked.spacing_glyph = glyph_spacing
	return tracked
