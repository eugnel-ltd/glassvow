extends RefCounted
## #360 gate: every tooling boot runs on the isolated Development profile unless
## it names `--production-save`, so a `tools/shot.sh` or `tools/live.sh` session
## leaves the player's run and Vigil alone.
##
## Two legs, because neither is enough on its own. The flag leg feeds every flag
## `Main._ready` parses to the excluded boot and reads back what Main is bound
## to — run path, Vigil path and the Vigil that was loaded — which is the only
## proof available for a flag that stores nothing at start-up. The boot leg runs
## the real `Main._ready` over sentinels standing at the player's paths and
## proves they came back byte-for-byte, which is what shows the profile is
## installed BEFORE the first store: a field assertion cannot claim that.
##
## Both legs run inside `TestProfile.in_sandbox`. They plant sentinels at the
## player's paths and boot the real `_ready`, which reads and creates the settings
## file, so `user://` has to be nobody's while they do.

const MAIN_PATH: String = "res://application/main.gd"
const PRODUCTION_FLAG: String = "--production-save"
const SENTINEL_RUN_ID: String = "run-sentinel-360"
const SENTINEL_SCENE: String = "sentinel-360"
## Only the Development Vigil carries this, so a Main that bound the paths but
## kept the Vigil it started with is caught.
const DEV_MARK: String = "dev-mark-360"
## The flags #360 names that store a checkpoint before the first frame.
const WRITING_BOOTS: Array[String] = [
	"--fight=duskfang", "--map", "--enter=0", "--dawn", "--onboard=map-select",
]
## The flag that reads a checkpoint instead: it must not find the player's.
const RESUME_BOOT: String = "--resume"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("dev boot profile: %s" % what)


static func run(fails: Array[String]) -> void:
	var boot: GDScript = load(DevTools.BOOT) as GDScript
	if boot == null:
		fails.append("dev boot profile: boot handler did not load")
		return
	TestProfile.in_sandbox(fails, _legs.bind(boot, fails))


static func _legs(boot: GDScript, fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_flag_leg(boot, content, fails)
	_boot_leg(content, fails)


# ---------------------------------------------------------------- flag leg

static func _flag_leg(boot: GDScript, content: ContentDB, fails: Array[String]) -> void:
	var kernel: ScenarioKernel = ScenarioKernel.new(content)
	kernel.clear_profile()
	var dev_vigil: VigilState = VigilState.blank()
	dev_vigil.scenes_seen.append(DEV_MARK)
	if not SaveService.store_vigil(dev_vigil, kernel.vigil_path):
		fails.append("dev boot profile: could not seed the Development Vigil")
		return
	for flag: String in _parsed_flags(fails):
		_selects(boot, kernel, PackedStringArray([flag]), true, fails)
		_selects(boot, kernel, PackedStringArray([flag, PRODUCTION_FLAG]), false, fails)
	# A player's plain launch carries no argument, and the opt-out alone says
	# nothing about which tool it is for: both keep the production profile.
	_selects(boot, kernel, PackedStringArray(), false, fails)
	_selects(boot, kernel, PackedStringArray([PRODUCTION_FLAG]), false, fails)
	_scenario_stays_isolated(boot, content, kernel, fails)
	kernel.clear_profile()


## Every flag `Main._ready` parses, read out of its source so a flag added later
## is covered without anyone remembering this file. Guarded against matching
## nothing (a renamed function would otherwise leave the leg vacuous) and against
## missing any flag #360 names.
static func _parsed_flags(fails: Array[String]) -> PackedStringArray:
	var source: String = FileAccess.get_file_as_string(MAIN_PATH)
	var start: int = source.find("\nfunc _ready(")
	var finish: int = source.find("\nfunc ", start + 1)
	var found: PackedStringArray = PackedStringArray()
	if start < 0 or finish < 0:
		fails.append("dev boot profile: Main._ready was not found in the source")
		return found
	var pattern: RegEx = RegEx.create_from_string("\"(--[a-z][a-z0-9-]*)(=?)")
	var seen: Dictionary = {}
	for hit: RegExMatch in pattern.search_all(source.substr(start, finish - start)):
		var flag: String = hit.get_string(1)
		if hit.get_string(2) == "=":
			flag += "=x"
		if not seen.has(flag):
			seen[flag] = true
			found.append(flag)
	for named: String in [
		"--fight=x", "--map", "--enter=x", "--dawn", "--onboard=x", "--scene=x",
		"--stagecraft", "--shop", "--resume", "--shot=x",
	]:
		_check(fails, found.has(named),
			"Main._ready no longer parses %s, or this leg cannot see it" % named)
	return found


## One boot's arguments, handed to the excluded boot as a fresh Main would
## receive them: where does it end up bound, and whose Vigil did it load?
static func _selects(
	boot: GDScript, kernel: ScenarioKernel, args: PackedStringArray, dev: bool,
	fails: Array[String]
) -> void:
	var host: Main = Main.new()
	host._vigil = VigilState.blank()
	boot.call("select_profile", host, args)
	var tag: String = " ".join(args) if not args.is_empty() else "(no arguments)"
	var want_run: String = kernel.run_path if dev else TestProfile.production_run_path()
	var want_vigil: String = kernel.vigil_path if dev else TestProfile.production_vigil_path()
	_check(fails, host._run_save_path == want_run,
		"%s bound the run to %s, wanted %s" % [tag, host._run_save_path, want_run])
	_check(fails, host._vigil_save_path == want_vigil,
		"%s bound the Vigil to %s, wanted %s" % [tag, host._vigil_save_path, want_vigil])
	_check(fails, host._vigil.scenes_seen.has(DEV_MARK) == dev,
		"%s %s the Development Vigil" % [tag, "did not load" if dev else "leaked"])
	host.free()


## A Scenario is built into the Development files by construction, so the
## production opt-out cannot pull it onto the player's: `apply` lands it there
## either way.
static func _scenario_stays_isolated(
	boot: GDScript, content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = "en"
	Locale.active = Locale.new(Locale.CODE_EN)
	var reference: String = JSON.stringify({
		"id": "custom", "revision": 1, "build": "t", "seed": 36001,
		"locale": "en", "shape": "pad-landscape", "overrides": {},
	})
	var args: PackedStringArray = PackedStringArray([
		"--scenario=%s" % reference, PRODUCTION_FLAG,
	])
	var host: Main = _bare_main(content)
	boot.call("select_profile", host, args)
	boot.call("apply", host, args)
	_check(fails, host.last_dev_error.is_empty(),
		"the Scenario boot failed: %s" % host.last_dev_error)
	_check(fails, host._run_save_path == kernel.run_path
			and host._vigil_save_path == kernel.vigil_path,
		"a Scenario named with %s did not stay on the Development profile" % PRODUCTION_FLAG)
	kernel.clear_profile()
	host.free()
	Locale.active = previous_locale
	Preferences.active = previous_preferences


# ---------------------------------------------------------------- boot leg

## The real `Main._ready`, over sentinels standing in for the player's files.
## `Main._ready` replaces the process-wide language handles, and the suites after
## this one expect what they had — so those come back too, along with the gate
## this leg forces open.
static func _boot_leg(content: ContentDB, fails: Array[String]) -> void:
	var previous_locale: Locale = Locale.active
	var previous_preferences: Preferences = Preferences.active
	var previous_gate: Variant = DevTools.forced
	var kernel: ScenarioKernel = ScenarioKernel.new(content)
	DevTools.forced = true
	for flag: String in WRITING_BOOTS:
		_writing_boot(flag, content, kernel, fails)
	_resuming_boot(content, kernel, fails)
	_production_boot("the production opt-out", PackedStringArray(
		["--map", PRODUCTION_FLAG]), true, content, kernel, fails)
	# A store build has no boot handler: an argument it happens to carry must
	# never move the player onto another profile.
	_production_boot("a closed gate", PackedStringArray(["--map"]), false,
		content, kernel, fails)
	kernel.clear_profile()
	DevTools.forced = previous_gate
	Preferences.active = previous_preferences
	Locale.active = previous_locale


## Every case starts from fresh sentinels and an empty Development profile, so a
## boot that leaks cannot be blamed for the boots after it.
static func _reset(content: ContentDB, kernel: ScenarioKernel, fails: Array[String]) -> void:
	kernel.clear_profile()
	_check(fails, _poison(content), "could not seed the production sentinels")


## A boot that stores a checkpoint at start-up: it lands in the Development
## profile, resumable, and the player's pair is untouched.
static func _writing_boot(
	flag: String, content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	_reset(content, kernel, fails)
	var run_mark: String = _digest(TestProfile.production_run_path())
	var vigil_mark: String = _digest(TestProfile.production_vigil_path())
	var main: Main = _boot(PackedStringArray([flag]))
	_check(fails, main._run_save_path == kernel.run_path,
		"%s did not bind the run to the Development profile" % flag)
	_check(fails, main._vigil_save_path == kernel.vigil_path,
		"%s did not bind the Vigil to the Development profile" % flag)
	_intact(flag, run_mark, vigil_mark, fails)
	_check(fails, SaveService.load_run(content, kernel.run_path) != null,
		"%s left no resumable checkpoint in the Development profile" % flag)
	if flag.begins_with("--onboard="):
		_onboard_dismissal(flag, kernel, main, run_mark, vigil_mark, fails)
	_dispose(main)


## The Vigil half of `--onboard=`, and the way it failed: one dismissal reaches
## `main._store_vigil()`, which used to retire the opening and the first-run
## hints in the developer's real Vigil.
static func _onboard_dismissal(
	flag: String, kernel: ScenarioKernel, main: Main,
	run_mark: String, vigil_mark: String, fails: Array[String]
) -> void:
	_check(fails, main._hints.record_dismiss(HintGuide.MAP_SELECT),
		"%s: the hint dismissal was refused" % flag)
	_intact("%s dismissal" % flag, run_mark, vigil_mark, fails)
	var stored: VigilState = SaveService.load_vigil(kernel.vigil_path)
	_check(fails, stored.hints_seen.has(HintGuide.MAP_SELECT)
			and stored.scenes_seen.has("opening"),
		"%s: the dismissal did not land in the Development Vigil" % flag)


## A boot that reads a checkpoint: it must not find the player's run.
static func _resuming_boot(
	content: ContentDB, kernel: ScenarioKernel, fails: Array[String]
) -> void:
	_reset(content, kernel, fails)
	var run_mark: String = _digest(TestProfile.production_run_path())
	var vigil_mark: String = _digest(TestProfile.production_vigil_path())
	var main: Main = _boot(PackedStringArray([RESUME_BOOT]))
	_check(fails, main.game == null,
		"%s resumed a run although the Development profile holds none" % RESUME_BOOT)
	_intact(RESUME_BOOT, run_mark, vigil_mark, fails)
	_dispose(main)


## The controls: a boot that must land on the player's files, so the assertions
## above cannot pass merely because nothing ever wrote anywhere. The player's
## sentinel run is replaced and the Development profile is left empty.
static func _production_boot(
	why: String, args: PackedStringArray, gate: bool, content: ContentDB,
	kernel: ScenarioKernel, fails: Array[String]
) -> void:
	_reset(content, kernel, fails)
	var before: String = _digest(TestProfile.production_run_path())
	DevTools.forced = gate
	var main: Main = _boot(args)
	DevTools.forced = true
	_check(fails, main._run_save_path == TestProfile.production_run_path()
			and main._vigil_save_path == TestProfile.production_vigil_path(),
		"%s did not keep the production paths" % why)
	_check(fails, _digest(TestProfile.production_run_path()) != before,
		"%s did not write the production run" % why)
	_check(fails, not FileAccess.file_exists(kernel.run_path),
		"%s still wrote the Development run" % why)
	_dispose(main)


## The player's pair is byte-for-byte what the sentinels were.
static func _intact(
	tag: String, run_mark: String, vigil_mark: String, fails: Array[String]
) -> void:
	_check(fails, _digest(TestProfile.production_run_path()) == run_mark,
		"%s changed the production run" % tag)
	_check(fails, _digest(TestProfile.production_vigil_path()) == vigil_mark,
		"%s changed the production Vigil" % tag)


# ---------------------------------------------------------------- fixtures

## A Main that has not booted: `Main.new()` never runs `_ready`, so the fields a
## route needs are supplied the way the other Main-driving suites supply them.
static func _bare_main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._vigil = VigilState.blank()
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	return main


## The real `Main._ready`, run on the given arguments with nothing else faked but
## the map compiler, which the other suites fake for the same reason (the real
## one searches for minutes). Suites run inside the runner's `_initialize`,
## before the tree has started, so no node is ever inside a tree here and the
## engine never delivers `_ready`: it is called directly, as `test_bespoke_staging`
## does for its nodes. A route that then reaches for `get_tree()` (the transition
## timers) logs an engine error and stops; every store the assertions rely on has
## happened by then, so that noise is expected and harmless.
static func _boot(args: PackedStringArray) -> Main:
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main._boot_args = args
	main._ready()
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


## Distinguishable, not merely present: a bypassed load answers with this run id
## and a bypassed store or clear moves these bytes.
static func _poison(content: ContentDB) -> bool:
	var run: RunState = RunState.new_run(content, 3600360, SENTINEL_RUN_ID)
	run.map = WorldMap.benchmark(run).to_dict()
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append(SENTINEL_SCENE)
	return SaveService.store(run, TestProfile.production_run_path()) \
		and SaveService.store_vigil(vigil, TestProfile.production_vigil_path())


static func _digest(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "%s:%d" % [FileAccess.get_sha256(path), FileAccess.get_file_as_bytes(path).size()]
