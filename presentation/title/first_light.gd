class_name FirstLight
extends RefCounted
## First launch asks two things, in the world (docs/design/2026-10-02-opening-
## start §9). The language is two glass panes on the title itself; this builds
## the other: one sentence and one switch for crash diagnostics, set where the
## deeds will one day be carved. Existing keys only: the switch writes
## `Preferences.set_diagnostics_enabled` (default on, posture B), and the
## title records `diagnostics_notice_seen` once the line is lit on screen
## (TitleScreen._record_consent_shown), as the Settings notice does when shown.


## `width` is the row's own width: the sentence wraps inside it. An autowrapping
## label given no width measures its height at zero width, which made the row
## hundreds of pixels tall and put the switch, centred on it, off the stage.
## The sentence reads first across the whole width, then the switch, the policy
## and (once the switch is changed) the note on one line under it: at the
## rubric's 18 px the sentence wraps less that way, and the row stays on the stage.
static func consent_row(preferences: Preferences, stage_shape: StringName,
		width: float = 300.0, open_url: Callable = Callable(OS, "shell_open")) -> VBoxContainer:
	var row: VBoxContainer = VBoxContainer.new()
	row.name = "FirstLightConsent"
	row.add_theme_constant_override("separation", 2)
	var px: int = LeadlightTokens.size_for(LeadlightTokens.SIZE_CAPTION, stage_shape)
	var line: Label = Label.new()
	line.name = "DiagnosticsLine"
	line.text = Locale.active.t("ui.firstLight.diagnostics")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = balanced_width(line.text, px, width)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	line.add_theme_font_size_override("font_size", px)
	line.add_theme_color_override("font_color", Color("#c3c8d9"))
	line.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	line.add_theme_constant_override("outline_size", 4)
	# Alegreya's line box is tall: closed up, two lines and the switch's row at
	# the touch floor fit under the words on a phone.
	line.add_theme_constant_override("line_spacing", -roundi(float(px) * 0.3))
	row.add_child(line)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	row.add_child(controls)
	var toggle: LeadlightToggle = LeadlightToggle.new(
		func() -> bool: return preferences.diagnostics_enabled,
		func(on: bool) -> void: preferences.set_diagnostics_enabled(on))
	toggle.name = "DiagnosticsToggle"
	# Its ON / OFF is the switch's state in words: functional text on the
	# title, so at the caption's size like the sentence (#655).
	toggle.set_px(px)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(toggle)
	var policy: LeadlightWord = LeadlightWord.new(Locale.active.t("ui.settings.privacyPolicy"), stage_shape)
	policy.name = "PrivacyPolicyWord"
	policy.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	policy.add_theme_font_size_override("font_size", px)
	policy.add_theme_color_override("font_color", LeadlightTokens.GOLD_DIM)
	policy.custom_minimum_size.y = RunStyle.hit_floor(22.0)
	policy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	policy.pressed.connect(func() -> void:
		open_url.call(PrivacyPolicy.url_for(Locale.active.code)))
	controls.add_child(policy)
	var note: Label = Label.new()
	note.name = "DiagnosticsNote"
	note.text = Locale.active.t("ui.settings.diagnosticsNote")
	note.visible = false
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.add_theme_font_override("font", LeadlightTokens.font(LeadlightTokens.ROLE_READ, px))
	note.add_theme_font_size_override("font_size", px)
	note.add_theme_color_override("font_color", LeadlightTokens.TEXT_DIM)
	note.add_theme_color_override("font_outline_color", Color(LeadlightTokens.VOID, 0.8))
	note.add_theme_constant_override("outline_size", 4)
	controls.add_child(note)
	# A change waits for the next launch (the main loop reads the switch before
	# Sentry starts), so say so the moment the player changes it.
	toggle.pressed.connect(func() -> void: note.visible = true)
	return row


## Where a zh-Hant line may end by choice: after its own punctuation.
const ZH_PAUSES: String = "，、；：。"


## The width that sets `text` (reading role, `px`) in as few lines as `width`
## allows, each about as long as the others: no last word left alone ("mended."
## under a full line). zh-Hant, which may break between any two characters,
## breaks at a pause instead (after "，"), never inside a word such as 資料.
static func balanced_width(text: String, px: int, width: float) -> float:
	var font: Font = LeadlightTokens.font(LeadlightTokens.ROLE_READ, px)
	var whole: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var lines: int = maxi(1, ceili(whole / width))
	if lines == 2:
		var pause: float = _pause_width(text, font, px, width)
		if pause > 0.0:
			return pause
	return minf(width, whole / float(lines) + float(px) * 2.0)


## For a two-line zh-Hant sentence: the width whose first line ends exactly at
## the pause that best balances the two lines (each fitting `width`), so the
## next character no longer fits it; 0 when the text has no such pause.
static func _pause_width(text: String, font: Font, px: int, width: float) -> float:
	var best: float = 0.0
	var best_gap: float = INF
	for at: int in range(text.length() - 1):
		if not ZH_PAUSES.contains(text[at]):
			continue
		var first: float = font.get_string_size(text.substr(0, at + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var rest: float = font.get_string_size(text.substr(at + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		# The first line must be the longer: a wider box would pull the second
		# line's opening characters up after the pause.
		if first > width or rest > first:
			continue
		var gap: float = first - rest
		if gap < best_gap:
			best_gap = gap
			best = first + 1.0
	return best
