extends RefCounted
## First launch through Main, not the still harness (PR #650 review): a fresh
## profile meets the language at the ember; answering it rebuilds the title,
## and that title still offers the diagnostics consent line; the notice is
## recorded only once the line is lit, after which Settings has no notice left
## to show. Building the first title must never spend it.

const RUN_PATH: String = "user://test_first_launch_flow_run_v2.json"
const VIGIL_PATH: String = "user://test_first_launch_flow_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("first_launch_flow: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous_prefs: Preferences = Preferences.active
	var previous_locale: Locale = Locale.active
	# A fresh, non-persistent profile: no language chosen, notice unseen.
	Preferences.active = Preferences.new()
	Locale.active = Locale.new(Preferences.active.effective_language())
	_language_then_consent(fails)
	Preferences.active = previous_prefs
	Locale.active = previous_locale
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _language_then_consent(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _main(content)
	main._show_title()
	var first: TitleScreen = main._choice_screen as TitleScreen
	_check(fails, first != null, "a fresh profile did not reach the title")
	if first == null:
		_dispose(main)
		return
	_check(fails, first._language.size() == 2, "a fresh profile was not asked its language")
	_check(fails, not Preferences.active.diagnostics_notice_seen,
		"building the first title spent the diagnostics notice")
	first.kindle_now()
	first.rite.advance(2.0)
	_check(fails, first.rite.held() and not Preferences.active.diagnostics_notice_seen,
		"the title held at the ember for the language spent the notice unlit")
	var lit_code: StringName = &""
	for pane: LeadlightPane in first._language:
		if pane.lit:
			lit_code = pane.get_meta(&"code")
	# The flame tapped at the ember accepts the pre-lit language through Main.
	first.lantern.pressed.emit()
	_check(fails, Preferences.active.language == String(lit_code),
		"choosing the language did not persist it (%s)" % Preferences.active.language)
	var rebuilt: TitleScreen = main._choice_screen as TitleScreen
	_check(fails, rebuilt != null and rebuilt != first,
		"choosing the language did not rebuild the title")
	if rebuilt == null or rebuilt == first:
		_dispose(main)
		return
	_check(fails, rebuilt._language.is_empty(), "the rebuilt title asked the language again")
	_check(fails, rebuilt.find_child("FirstLightConsent", true, false) != null,
		"the title rebuilt in the chosen language does not offer the consent line")
	_check(fails, not Preferences.active.diagnostics_notice_seen,
		"the rebuilt title spent the notice before lighting its line")
	rebuilt.kindle_now()
	rebuilt.rite.advance(5.0)
	_check(fails, rebuilt.rite.is_done() and Preferences.active.diagnostics_notice_seen,
		"the consent line, lit by the reveal, did not record the notice")
	var panel: SettingsPanel = SettingsPanel.new(Preferences.active)
	_check(fails, panel.find_child("DiagnosticsNotice", true, false) == null,
		"Settings still shows the notice after the title showed the consent line")
	panel.free()
	_dispose(main)


static func _main(content: ContentDB) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
