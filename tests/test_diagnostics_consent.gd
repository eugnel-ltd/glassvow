extends RefCounted
## #415 posture B: the crash-diagnostics switch. Before Sentry starts, the main
## loop reads the same file and key that the Settings row writes; the row
## carries the switch, its next-launch note and a once-only notice; the copy is
## paired in both catalogues. Every path is test-owned, and the loop is only
## ever handed a stand-in `start`, so no suite run can start the real SDK.

const TEST_PATH: String = "user://test_415_settings.cfg"
const TEST_LEGACY: String = "user://test_415_audio.cfg"
const MISSING_PATH: String = "user://test_415_missing.cfg"

## The owner's copy (task contract, 2026-09-29) plus the row's heading and
## next-launch note. The label renders uppercase, as every panel label does.
const COPY: Dictionary = {
	"ui.settings.privacy": ["Privacy", "私隱"],
	"ui.settings.diagnostics": ["Send Crash Diagnostics", "傳送當機診斷資料"],
	"ui.settings.diagnosticsNote": ["Takes effect on the next launch.", "將於下次啟動遊戲時生效。"],
	# One sentence per line, so neither 「設定」 nor "Settings." can wrap apart.
	"ui.settings.diagnosticsNotice": [
		"Crash diagnostics are sent to help fix bugs.\nYou can switch this off in Settings.",
		"為修正錯誤，遊戲會傳送當機診斷資料。\n你可在「設定」中關閉。",
	],
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("diagnostics_consent: %s" % what)


static func run(fails: Array[String]) -> void:
	_cleanup()
	_loop_starts_only_when_enabled(fails)
	_reader_matches_preferences(fails)
	_loop_wiring(fails)
	_settings_row_and_notice(fails)
	_catalogue_copy(fails)
	_cleanup()


## The gate end to end through the real file: Settings writes the choice with
## the Preferences writer, and the loop reads it with its own default reader.
static func _loop_starts_only_when_enabled(fails: Array[String]) -> void:
	var calls: Array[int] = [0]
	var start: Callable = func() -> void: calls[0] += 1
	_check(fails, GlassvowMainLoop.start_if_enabled(start, MISSING_PATH) and calls[0] == 1,
		"a fresh install (no settings file) did not start diagnostics")
	var prefs: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	prefs.set_diagnostics_enabled(false)
	calls[0] = 0
	_check(fails, not GlassvowMainLoop.start_if_enabled(start, TEST_PATH),
		"the loop reported a start with diagnostics switched off")
	_check(fails, calls[0] == 0, "the loop started Sentry with diagnostics switched off")
	prefs.set_diagnostics_enabled(true)
	_check(fails, GlassvowMainLoop.start_if_enabled(start, TEST_PATH) and calls[0] == 1,
		"switching diagnostics back on did not start them")


## Both readers share one decode, so the Settings row and the loop can never
## disagree — including on a value that is not a bool. The loop's read has no
## side effect: it creates no file.
static func _reader_matches_preferences(fails: Array[String]) -> void:
	_check(fails, Preferences.read_diagnostics_enabled(MISSING_PATH),
		"a missing settings file did not read as the default (on)")
	_check(fails, not FileAccess.file_exists(MISSING_PATH),
		"the loop's read created a settings file")
	var config: ConfigFile = ConfigFile.new()
	config.set_value(Preferences.PRIVACY_SECTION, Preferences.DIAGNOSTICS_KEY, "false")
	config.save(TEST_PATH)
	var prefs: Preferences = Preferences.read_from_disk(TEST_PATH, TEST_LEGACY)
	_check(fails, prefs.diagnostics_enabled == Preferences.read_diagnostics_enabled(TEST_PATH),
		"Preferences and the loop disagree on a malformed value")


## `start_if_enabled` guards nothing unless the loop asks it: the one SDK
## init in first-party code must be the `start` the gate is handed.
static func _loop_wiring(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/sentry_loop.gd")
	var init_at: int = source.find("SentrySDK.init(")
	_check(fails, init_at >= 0 and source.find("SentrySDK.init(", init_at + 1) < 0,
		"the loop does not have exactly one SentrySDK.init call")
	var line_start: int = source.rfind("\n", init_at) + 1
	var line_end: int = source.find("\n", init_at)
	var line: String = source.substr(line_start, line_end - line_start)
	_check(fails, line.contains("start_if_enabled(func() -> void: SentrySDK.init(_configure))"),
		"SentrySDK.init is not reached through start_if_enabled")


## The row writes the switch; the notice appears in the first panel only and
## is recorded as shown; the note is always there. Built in both languages.
static func _settings_row_and_notice(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	var index: int = 0
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		var prefs: Preferences = Preferences.new()
		var first: SettingsPanel = SettingsPanel.new(prefs)
		var notice: Label = first.find_child("DiagnosticsNotice", true, false) as Label
		_check(fails, notice != null and notice.text == str(COPY["ui.settings.diagnosticsNotice"][index]),
			"%s: the first panel did not carry the notice" % code)
		_check(fails, prefs.diagnostics_notice_seen,
			"%s: the notice was not recorded as shown" % code)
		var toggle: Button = _diagnostics_toggle(first)
		_check(fails, toggle != null and toggle.text == Locale.active.t("ui.settings.on").to_upper(),
			"%s: the switch did not read ON by default" % code)
		if toggle != null:
			toggle.pressed.emit()
			_check(fails, not prefs.diagnostics_enabled
					and toggle.text == Locale.active.t("ui.settings.off").to_upper(),
				"%s: pressing the switch did not turn diagnostics off" % code)
		first.free()
		var again: SettingsPanel = SettingsPanel.new(prefs)
		_check(fails, again.find_child("DiagnosticsNotice", true, false) == null,
			"%s: the notice came back on a second panel" % code)
		var note: Label = again.find_child("DiagnosticsNote", true, false) as Label
		_check(fails, note != null and note.text == str(COPY["ui.settings.diagnosticsNote"][index]),
			"%s: the next-launch note is missing" % code)
		again.free()
		index += 1
	Locale.active = previous


static func _diagnostics_toggle(panel: SettingsPanel) -> Button:
	var row: Node = panel.find_child("DiagnosticsRow", true, false)
	if row == null:
		return null
	for child: Node in row.get_children():
		if child is Button:
			return child as Button
	return null


## Through the production lookup, so a zh key missing from its catalogue
## (which would fall back to English) fails here too.
static func _catalogue_copy(fails: Array[String]) -> void:
	var index: int = 0
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		var catalogue: Locale = Locale.new(code)
		for key: String in COPY:
			_check(fails, catalogue.t(key) == str(COPY[key][index]),
				"%s drifted in %s" % [key, code])
		index += 1


static func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_LEGACY, MISSING_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
