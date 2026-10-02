class_name SettingsPanel
extends Control
## The player-facing settings overlay: AUDIO / DISPLAY / MOTION / PRIVACY /
## THE LEDGER, with the route behind it staying visible. Reads and writes the
## main-owned Preferences handle; the DISPLAY section hides itself where the
## platform owns the window (web) or there is no window at all (headless).
##
## Settings is a room in the same house (docs/design/2026-10-02-opening-start
## §2): a leaded arched window (LeadlightRoom) whose sections are panes, every
## control from the Leadlight kit, the route behind it dimmed but visible.

signal closed
signal reset_requested
signal language_changed(code: StringName)

const GOLD: Color = LeadlightTokens.GOLD
const DANGER: Color = LeadlightTokens.DANGER
## The room's authored size on the identity stage; a phone takes its height.
## It stands low on the stage so the title's wordmark stays visible above it.
const ROOM: Vector2 = Vector2(760.0, 580.0)
const ROOM_FOOT: float = 34.0

var _preferences: Preferences
var _sfx: SfxBus
var _room: LeadlightRoom
var _brand_line: Label
var _shape: StringName = StageShape.IDENTITY
var _language_toggle: Button
var _language_label: Label
var _language_deferred: bool
## The one-line diagnostics notice, present only in the first panel built
## after install (see `_add_diagnostics`).
var _diagnostics_notice: Label
## Opens an address in the system browser. A seam for tests, which hand in a
## recorder so no suite run ever launches a browser.
var open_url: Callable = Callable(OS, "shell_open")


func _init(preferences: Preferences, reset_disabled: bool = false,
		sfx: SfxBus = null, language_deferred: bool = false) -> void:
	_preferences = preferences
	_language_deferred = language_deferred
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sfx = sfx if sfx != null else SfxBus.new()
	if sfx == null:
		# Injected bus already lives under main; only own a fallback.
		add_child(_sfx)

	var scrim: ColorRect = ColorRect.new()
	# The route stays visible but must not COMPETE: the canonical veil.
	scrim.color = GlassStyle.scrim()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	_room = LeadlightRoom.new(Locale.active.t("ui.settings.title"), _shape)
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
	var ledger: VBoxContainer = _section(&"ledger", Locale.active.t("ui.settings.ledger"), DANGER)
	var erase: Button = _button(Locale.active.t("ui.settings.eraseAll").to_upper(), DANGER)
	erase.disabled = reset_disabled
	erase.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	erase.pressed.connect(func() -> void:
		_sfx.play(&"click")
		reset_requested.emit()
	)
	ledger.add_child(erase)
	var warning: Label = _note(Locale.active.t("ui.settings.resetWarn"))
	ledger.add_child(warning)

	var close: Button = _button(Locale.active.t("ui.menu.close").to_upper(), GlassStyle.GLASS)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		_sfx.play(&"click")
		closed.emit()
	)
	_room.footer().add_child(close)

	var footer: Label = Label.new()
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var brand: String = Locale.active.t("ui.brand.title")
	footer.text = "%s %s" % [brand, version] if version != "" else brand
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", _tracked_font(GlassStyle.CINZEL_500, 2))
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(GlassStyle.TEXT_DIM, 0.7))
	_room.footer().add_child(footer)
	_brand_line = footer

	close.grab_focus.call_deferred()
	# A notice recorded as shown must be on screen: the first panel after
	# install opens on PRIVACY.
	if _diagnostics_notice != null:
		_room.select(&"privacy")


func set_shape(stage_shape: StringName) -> void:
	if not StageShape.REFERENCES.has(stage_shape):
		return
	_shape = stage_shape
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


## The room never outgrows the stage: its authored size, held inside the
## stage with a margin, centred.
func _fit() -> void:
	if _room == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var want: Vector2 = Vector2(minf(ROOM.x, size.x - 24.0), minf(ROOM.y, size.y - 12.0))
	_room.size = want
	var foot: float = minf(ROOM_FOOT, (size.y - want.y) * 0.5)
	_room.position = Vector2((size.x - want.x) * 0.5, size.y - want.y - foot)
	_room.set_light(LeadlightTokens.EMBER, Vector2(0.08, 1.0))
	# A phone's short room keeps its rows; the title already shows the build.
	_brand_line.visible = not LeadlightTokens.is_phone(_shape)


static func _display_supported() -> bool:
	return not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _section(id: StringName, heading: String, accent: Color) -> VBoxContainer:
	return _room.add_section(id, heading, accent)


func _audio_row(label_text: String, bus: StringName) -> LeadlightRow:
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slider: LeadlightSlider = LeadlightSlider.new(roundf(_preferences.volume(bus) * 100.0))
	slider.tooltip_text = Locale.active.t("ui.settings.volumeTip", {"name": label_text})
	controls.add_child(slider)
	var mute: Button = _small_button()
	controls.add_child(mute)
	var row: LeadlightRow = LeadlightRow.new(label_text, controls, _shape)
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

	_language_toggle = _small_button()
	_language_toggle.name = "LanguageToggle"
	_language_toggle.custom_minimum_size.x = maxf(
		_language_toggle.custom_minimum_size.x, 120.0)
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
		Locale.active.t("ui.language.label"), _language_toggle, _shape)
	_language_label = row.label()
	_language_label.name = "LanguageLabel"
	body.add_child(row)

	if _language_deferred:
		var note: Label = _note(Locale.active.t("ui.language.deferNote"))
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
	if not _preferences.diagnostics_notice_seen:
		_diagnostics_notice = _note(Locale.active.t("ui.settings.diagnosticsNotice"))
		_diagnostics_notice.name = "DiagnosticsNotice"
		section.add_child(_diagnostics_notice)
		_preferences.mark_diagnostics_notice_seen()
	var note: Label = _note(Locale.active.t("ui.settings.diagnosticsNote"))
	note.name = "DiagnosticsNote"
	section.add_child(note)


## The privacy policy for the language on screen, opened in the system
## browser. It sits last in PRIVACY, so focus order runs the switch, then the
## policy, then THE LEDGER, as the rows read.
func _add_policy_link(section: VBoxContainer) -> void:
	var link: Button = _button(
		Locale.active.t("ui.settings.privacyPolicy").to_upper(), GOLD)
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
	_language_toggle.grab_focus.call_deferred()
	_room.scroll().ensure_control_visible.call_deferred(_language_toggle)


## A labelled glass switch reading through a getter so it always restates the
## stored truth rather than a mirrored local.
func _toggle_row(label_text: String, getter: Callable, setter: Callable) -> LeadlightRow:
	var toggle: LeadlightToggle = LeadlightToggle.new(getter, setter)
	toggle.pressed.connect(func() -> void: _sfx.play(&"click"))
	return LeadlightRow.new(label_text, toggle, _shape)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()


## Scrim `gui_input` never receives keys; Escape / ui_cancel closes via the
## unhandled path — `_unhandled_input` so gamepad ui_cancel reaches it too.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


static func _button(text: String, accent: Color) -> Button:
	var button: LeadlightPane = LeadlightPane.new(text)
	button.accent = accent
	button.lit = false
	return button


static func _small_button() -> Button:
	var button: LeadlightPane = LeadlightPane.new("", StageShape.IDENTITY, LeadlightGlassBox.Shape.RECT)
	button.custom_minimum_size = Vector2(76.0, RunStyle.hit_floor(26.0))
	button.set_px(12)
	return button


## A dim wrapped line under a control: the language defer note, the
## diagnostics notice and note, and the ledger's warning.
static func _note(text: String) -> Label:
	var note: Label = Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_override("font", GlassStyle.face(GlassStyle.ALEGREYA_400))
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	return note


static func _tracked_font(path: String, glyph_spacing: int) -> FontVariation:
	var tracked: FontVariation = FontVariation.new()
	tracked.base_font = GlassStyle.face(path)
	tracked.spacing_glyph = glyph_spacing
	return tracked
