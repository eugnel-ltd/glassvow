extends RefCounted
## Remember setup across fresh Preferences/Main instances, while the current
## profile and catalogue remain the authority. Every file is test-owned.

const RUN_PATH: String = "user://test_departure_memory_run_v2.json"
const VIGIL_PATH: String = "user://test_departure_memory_vigil_v2.json"
const PREFS_PATH: String = "user://test_departure_memory_settings.cfg"
const BLOCKED_PATH: String = "user://test_departure_memory_blocked"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func run(fails: Array[String]) -> void:
	var standin: Preferences = Preferences.new()
	if not standin.has_method("remember_departure") or not standin.has_method("last_departure"):
		fails.append("departure persistence: Preferences has no remembered departure contract")
		return
	var previous: Preferences = Preferences.active
	_cleanup()
	_settings_round_trip(fails)
	_malformed_settings(fails)
	var content: ContentDB = ContentDB.load_full()
	_across_launches(fails, content)
	_current_entitlements(fails, content)
	_without_a_gift(fails, content)
	_failed_checkpoint_and_retry(fails, content)
	Preferences.active = previous
	_cleanup()


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("departure persistence: %s" % what)


static func _last(preferences: Preferences) -> Dictionary:
	var value: Variant = preferences.call("last_departure")
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _preferences(fails: Array[String], setup: Variant = null) -> Preferences:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("privacy", "diagnostics_enabled", false)
	config.set_value("future", "setting", "preserve me")
	if setup != null:
		config.set_value("departure", "setup", setup)
	_check(fails, config.save(PREFS_PATH) == OK, "could not seed scratch settings")
	var preferences: Preferences = Preferences.read_from_disk(PREFS_PATH, PREFS_PATH + ".legacy")
	Preferences.active = preferences
	return preferences


static func _settings_round_trip(fails: Array[String]) -> void:
	var preferences: Preferences = _preferences(fails)
	preferences.call("remember_departure", "duskblade", 1, "beacon")
	var again: Preferences = Preferences.read_from_disk(PREFS_PATH, PREFS_PATH + ".legacy")
	var wanted: Dictionary = {"aspect": "duskblade", "vow": 1, "art": "beacon"}
	_check(fails, _last(again) == wanted, "stable setup choices did not survive disk reload")
	var copy: Dictionary = _last(again)
	copy["aspect"] = "ashwarden"
	_check(fails, _last(again) == wanted, "caller mutated the stored choice through its getter")
	var config: ConfigFile = ConfigFile.new()
	_check(fails, config.load(PREFS_PATH) == OK, "settings stopped loading")
	var settings_preserved: bool = config.get_value("future", "setting", "") == "preserve me" \
		and config.get_value("privacy", "diagnostics_enabled", true) == false
	_check(fails, settings_preserved,
		"remembering setup discarded other settings or diagnostics opt-out")
	var stored_setup_matches: bool = config.get_value("departure", "setup", {}) == wanted
	_check(fails, stored_setup_matches,
		"stored setup contains an index, seed, run ID, boon or unlock authority")
	var memory: Preferences = Preferences.new()
	memory._path = PREFS_PATH + ".standin"
	memory.call("remember_departure", "duskblade", 0, "flare")
	_check(fails, not FileAccess.file_exists(memory._path), "in-memory stand-in wrote settings")


static func _malformed_settings(fails: Array[String]) -> void:
	var bad: Array = [
		"duskblade", [], {}, {"aspect": "duskblade", "vow": 0},
		{"aspect": 0, "vow": 0, "art": "flare"},
		{"aspect": "duskblade", "vow": "1", "art": "flare"},
		{"aspect": "duskblade", "vow": 1.0, "art": "flare"},
		{"aspect": "duskblade", "vow": true, "art": "flare"},
		{"aspect": "duskblade", "vow": -1, "art": "flare"},
		{"aspect": "duskblade", "vow": 0, "art": []},
		{"aspect": "", "vow": 0, "art": "flare"},
		{"aspect": "duskblade", "vow": 0, "art": "flare", "seed": 661},
	]
	for value: Variant in bad:
		var preferences: Preferences = _preferences(fails, value)
		var before: String = FileAccess.get_file_as_string(PREFS_PATH)
		_check(fails, _last(preferences).is_empty(), "malformed setup was accepted: %s" % str(value))
		_check(fails, FileAccess.get_file_as_string(PREFS_PATH) == before,
			"reading malformed optional setup rewrote settings")


static func _across_launches(fails: Array[String], content: ContentDB) -> void:
	_preferences(fails)
	var first: Main = _main(content, true, 1)
	first._forced_seed = 66101
	first._show_embark()
	first._on_embark_begin(0, 1)
	_check(fails, _last(Preferences.active).is_empty(), "an unanswered gift replaced the previous setup")
	var offers: Array = first.game.run.quest_scratch.get("lamplighterOffer", {}).get("boons", [])
	_check(fails, not offers.is_empty(), "first departure has no real gift offer")
	if offers.is_empty():
		_dispose(first)
		return
	first._on_lamplighter_confirmed(str(offers[0]), &"beacon")
	var saved: Dictionary = _last(Preferences.active)
	_check(fails, saved == {"aspect": "duskblade", "vow": 1, "art": "beacon"},
		"accepted departure did not persist its actual setup")
	_dispose(first)
	Preferences.active = Preferences.read_from_disk(PREFS_PATH, PREFS_PATH + ".legacy")
	var second: Main = _main(content, true, 1)
	second._forced_seed = 66102
	_check(fails, second.game == null and second._last_setup.is_empty(),
		"fresh Main retained a run or session setup")
	second._show_embark()
	var screen: DepartureScreen = second._route_screen as DepartureScreen
	var same: BaseButton = screen.find_child("SetOutAsBefore", true, false) as BaseButton if screen != null else null
	_check(fails, same != null, "disk-backed setup was not offered by a fresh Main")
	if same == null:
		_dispose(second)
		return
	same.pressed.emit()
	_check(fails, second.game != null and second.game.run.vow == 1
		and second.game.run.seed == 66102 and second._forced_seed == 66102,
		"as-before changed fresh seed allocation or lost the vow")
	_check(fails, screen.beat == DepartureScreen.BEAT_B and second.game.run.pending_lamplighter,
		"persisted setup skipped the real gift")
	screen.primary().pressed.emit()
	_check(fails, second.game.run.art == &"beacon" and not second.game.run.pending_lamplighter,
		"fresh departure did not carry the qualifying art after choosing a gift")
	_dispose(second)


static func _current_entitlements(fails: Array[String], content: ContentDB) -> void:
	var rejected: Array[Dictionary] = [
		{"aspect": "unknown", "vow": 0, "art": "flare"},
		{"aspect": "ashwarden", "vow": 0, "art": "ashfall"},
		{"aspect": "duskblade", "vow": 2, "art": "beacon"},
		{"aspect": "duskblade", "vow": 0, "art": "unknown"},
		{"aspect": "duskblade", "vow": 0, "art": "ashfall"},
	]
	for value: Dictionary in rejected:
		_preferences(fails, value)
		var main: Main = _main(content, true, 1)
		# An earned unlock must not override this build's withheld class policy.
		main._vigil.unlocks.append("aspect2")
		main._show_embark()
		_check(fails, main._route_screen.find_child("SetOutAsBefore", true, false) == null,
			"unknown, withheld or locked setup was offered: %s" % str(value))
		_check(fails, main.game == null and not FileAccess.file_exists(RUN_PATH),
			"reading setup created a run")
		_check(fails, main._vigil.vow_unlocked == 1 and _last(Preferences.active) == value,
			"advisory setup changed unlock truth or silently rewrote an ineligible choice")
		_dispose(main)
	_preferences(fails, {"aspect": "duskblade", "vow": 0, "art": "beacon"})
	var without_keeper: Main = _main(content, false, 0)
	without_keeper._show_embark()
	_check(fails, without_keeper._route_screen.find_child("SetOutAsBefore", true, false) == null,
		"a remembered non-default art was offered without the Keeper")
	_dispose(without_keeper)


static func _without_a_gift(fails: Array[String], content: ContentDB) -> void:
	_preferences(fails)
	var main: Main = _main(content, false, 0)
	main._new_run({"aspect": 0, "vow": 0})
	_check(fails, _last(Preferences.active) == {"aspect": "duskblade", "vow": 0, "art": "flare"},
		"a durable departure without a gift was not remembered")
	_dispose(main)


static func _failed_checkpoint_and_retry(fails: Array[String], content: ContentDB) -> void:
	var old: Dictionary = {"aspect": "duskblade", "vow": 0, "art": "flare"}
	_preferences(fails, old)
	var accepted: String = FileAccess.get_file_as_string(PREFS_PATH)
	var main: Main = _main(content, false, 1)
	var blocked: String = ProjectSettings.globalize_path(BLOCKED_PATH)
	_check(fails, DirAccess.make_dir_absolute(blocked) == OK, "could not plant blocked checkpoint target")
	main._run_save_path = BLOCKED_PATH
	main._new_run({"aspect": 0, "vow": 1})
	_check(fails, _last(Preferences.active) == old
		and FileAccess.get_file_as_string(PREFS_PATH) == accepted,
		"failed run acceptance overwrote the last remembered departure")
	main._run_save_path = RUN_PATH
	main._on_save_error_choice("retry")
	var retry_remembered: bool = main._load_run() != null and _last(Preferences.active).get("vow", -1) == 1
	_check(fails, retry_remembered,
		"successful checkpoint retry did not remember the now-durable setup")
	_dispose(main)
	DirAccess.remove_absolute(blocked)


static func _main(content: ContentDB, keeper: bool, vow: int) -> Main:
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._vigil.scenes_seen.append("opening")
	main._vigil.vow_unlocked = vow
	if keeper:
		main._vigil.unlocks.append("lamplighter")
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


static func _cleanup() -> void:
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	for path: String in [PREFS_PATH, PREFS_PATH + ".legacy", PREFS_PATH + ".standin", PREFS_PATH + ".tmp", BLOCKED_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var blocked: String = ProjectSettings.globalize_path(BLOCKED_PATH)
	if DirAccess.dir_exists_absolute(blocked):
		DirAccess.remove_absolute(blocked)
