class_name FirstLight
extends RefCounted
## First launch asks two things, in the world (docs/design/2026-10-02-opening-
## start §9). The language is two glass panes on the title itself; this builds
## the other: one sentence and one switch for crash diagnostics, set where the
## deeds will one day be carved. Existing keys only: the switch writes
## `Preferences.set_diagnostics_enabled` (default on, posture B) and showing it
## records `diagnostics_notice_seen`, exactly as the Settings notice does.


static func consent_row(preferences: Preferences, stage_shape: StringName,
		open_url: Callable = Callable(OS, "shell_open")) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "FirstLightConsent"
	row.add_theme_constant_override("separation", 12)
	var toggle: LeadlightToggle = LeadlightToggle.new(
		func() -> bool: return preferences.diagnostics_enabled,
		func(on: bool) -> void: preferences.set_diagnostics_enabled(on))
	toggle.name = "DiagnosticsToggle"
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(toggle)
	var words: VBoxContainer = VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_CAPTION, stage_shape) + 1
	var line: Label = Label.new()
	line.name = "DiagnosticsLine"
	line.text = Locale.active.t("ui.firstLight.diagnostics")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	line.add_theme_font_size_override("font_size", px)
	line.add_theme_color_override("font_color", Color("#c3c8d9"))
	line.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	line.add_theme_constant_override("outline_size", 4)
	words.add_child(line)
	var note: Label = Label.new()
	note.name = "DiagnosticsNote"
	note.text = Locale.active.t("ui.settings.diagnosticsNote")
	note.visible = false
	note.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px - 1))
	note.add_theme_font_size_override("font_size", px - 1)
	note.add_theme_color_override("font_color", LeadlightTokens.TEXT_DIM)
	words.add_child(note)
	var policy: LeadlightWord = LeadlightWord.new(Locale.active.t("ui.settings.privacyPolicy"), stage_shape)
	policy.name = "PrivacyPolicyWord"
	policy.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	policy.add_theme_font_size_override("font_size", px)
	policy.add_theme_color_override("font_color", LeadlightTokens.GOLD_DIM)
	policy.custom_minimum_size.y = RunStyle.hit_floor(22.0)
	policy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	policy.pressed.connect(func() -> void:
		open_url.call(PrivacyPolicy.url_for(Locale.active.code)))
	words.add_child(policy)
	# A change waits for the next launch (the main loop reads the switch before
	# Sentry starts), so say so the moment the player changes it.
	toggle.pressed.connect(func() -> void: note.visible = true)
	return row
