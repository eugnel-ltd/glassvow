extends RefCounted
## The ordinary settings owner must survive synthetic departures on the
## Development profile, including onboarding that deliberately plays story flow.

const Memory: GDScript = preload("res://tests/test_departure_persistence.gd")
const ACCEPTED: Dictionary = {"aspect": "duskblade", "vow": 1, "art": "beacon"}


static func run(fails: Array[String]) -> void:
	var previous: Preferences = Preferences.active
	TestProfile.in_sandbox(fails, _cases.bind(fails))
	Preferences.active = previous


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("departure memory profile: %s" % what)


static func _cases(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var kernel: ScenarioKernel = ScenarioKernel.new(content)
	for mode: String in ["map-select", "future-tool", "installed-development"]:
		_development_start(mode, content, kernel, fails)
	_resumed_development_gift(content, kernel, fails)
	_production_opt_out(content, kernel, fails)
	kernel.clear_profile()
	Memory._cleanup()


static func _development_start(
	mode: String, content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	kernel.clear_profile()
	Memory._preferences(fails, ACCEPTED)
	var accepted_bytes: String = FileAccess.get_file_as_string(Memory.PREFS_PATH)
	var main: Main = Memory._main(content, false, 0)
	if mode == "map-select":
		main._boot_args = PackedStringArray(["--onboard=map-select"])
	elif mode == "future-tool":
		main._boot_args = PackedStringArray(["--future-tool"])
	else:
		main._boot_args = PackedStringArray([DevTools.PRODUCTION_SAVE_FLAG])
	main.select_profile(main._boot_args)
	if mode == "installed-development":
		# A later Scenario/profile installation remains authoritative even when
		# the initial selector was explicitly allowed to keep the player profile.
		main.install_profile(kernel.run_path, kernel.vigil_path)
	main._forced_seed = 66171
	if mode == "map-select":
		main._boot_onboard("map-select")
	else:
		main._vigil.scenes_seen.append("opening")
		main._new_run()
	_check(fails, main._story_flow(), "%s did not exercise a story-flow start" % mode)
	_check(fails, main._run_save_path == kernel.run_path
		and main._vigil_save_path == kernel.vigil_path,
		"%s did not install the real Development profile" % mode)
	var saved: RunState = main._load_run()
	_check(fails, saved != null and saved.seed == 66171 and not saved.pending_lamplighter,
		"%s did not accept its synthetic no-gift checkpoint" % mode)
	_check(fails, FileAccess.get_file_as_string(Memory.PREFS_PATH) == accepted_bytes,
		"%s overwrote the player's accepted departure preference bytes" % mode)
	Memory._dispose(main)


static func _resumed_development_gift(
	content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	kernel.clear_profile()
	Memory._preferences(fails, ACCEPTED)
	var accepted_bytes: String = FileAccess.get_file_as_string(Memory.PREFS_PATH)
	var first: Main = Memory._main(content, false, 0)
	first._boot_args = PackedStringArray(["--onboard=map-select"])
	first.select_profile(first._boot_args)
	first._vigil.unlocks.append("lamplighter")
	first._forced_seed = 66172
	first._boot_onboard("map-select")
	var pending: RunState = first._load_run()
	_check(fails, pending != null and pending.pending_lamplighter,
		"Development start did not leave a real resumable gift")
	Memory._dispose(first)
	if pending == null:
		return
	Preferences.active = Preferences.read_from_disk(Memory.PREFS_PATH, Memory.PREFS_PATH + ".legacy")
	var resumed: Main = Memory._main(content, false, 0)
	resumed._boot_args = PackedStringArray(["--resume"])
	resumed.select_profile(resumed._boot_args)
	resumed.game = GlassvowGame.new(content, pending)
	resumed._map = WorldMap.from_dict(pending.map)
	_check(fails, resumed._story_flow() and resumed._remember_setup_for_run.is_empty(),
		"fresh Development Main did not exercise the resumed-gift marker")
	resumed._show_lamplighter()
	var offers: Array = resumed.game.run.quest_scratch.get("lamplighterOffer", {}).get("boons", [])
	_check(fails, not offers.is_empty(), "resumed Development gift has no real offer")
	if not offers.is_empty():
		resumed._on_lamplighter_confirmed(str(offers[0]), &"beacon")
		var saved: RunState = resumed._load_run()
		_check(fails, saved != null and saved.seed == 66172 and not saved.pending_lamplighter,
			"resumed Development gift was not durably accepted with its original seed")
		_check(fails, FileAccess.get_file_as_string(Memory.PREFS_PATH) == accepted_bytes,
			"resumed Development gift overwrote the player's accepted departure preference bytes")
	Memory._dispose(resumed)


static func _production_opt_out(
	content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	kernel.clear_profile()
	Memory._preferences(fails, ACCEPTED)
	var main: Main = Memory._main(content, false, 0)
	main._boot_args = PackedStringArray(["--onboard=map-select", DevTools.PRODUCTION_SAVE_FLAG])
	main.select_profile(main._boot_args)
	_check(fails, main._run_save_path == Memory.RUN_PATH and main._vigil_save_path == Memory.VIGIL_PATH,
		"explicit production opt-out did not preserve the installed player stand-in")
	main._forced_seed = 66173
	main._boot_onboard("map-select")
	var opt_out_remembered: bool = Memory._last(Preferences.active) \
		== {"aspect": "duskblade", "vow": 0, "art": "flare"}
	_check(fails, opt_out_remembered,
		"explicit production opt-out failed to remember its accepted player departure")
	var saved: RunState = main._load_run()
	_check(fails, saved != null and saved.seed == 66173,
		"explicit production opt-out changed new-run seed allocation")
	Memory._dispose(main)
