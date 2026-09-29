extends RefCounted
## #346 gate: the suite never reads or writes the player's real save.
##
## PR #346 recorded that one stray run save in `user://` made four suites diverge
## (26 failures). The suites that snapshotted, moved or rewrote the player's files
## to defend themselves were the same hazard from the other side: a kill part-way
## left a real pilgrimage moved aside, overwritten or gone. `TestProfile`
## (`tests/support/test_profile.gd`) is how a suite stays clear of them — it binds
## a `Main` to a scratch pair, or moves `user://` into a sandbox for the few suites
## whose subject IS the player's profile — and this census is what makes that
## binding rather than advice.
##
## It is a grep over `tests/`, so it sees only what a script spells out. Four rules:
##
##  1. No script names the player's files: not their paths, not their file names.
##  2. No script calls a `SaveService` or `Preferences` entry point without saying
##     which file, because the default is the player's.
##  3. Every function that builds a `Main` installs a profile after it (`Main`
##     starts on the player's paths), unless the script runs inside a sandbox.
##  4. A script that reaches the player's paths through `TestProfile`, or boots the
##     real `Main._ready`, runs inside a sandbox.
##
## Each rule is proved against synthetic sources every run, so a pattern that stops
## matching cannot turn the census vacuous. The two scripts that may name the
## player's files are this census, which has to spell out what it hunts for, and
## the helper that owns them.

const TESTS_ROOT: String = "res://tests"
const ALLOWED: PackedStringArray = [
	"res://tests/test_suite_isolation.gd",
	"res://tests/support/test_profile.gd",
]
## Where the path argument sits, counting from 1. A call that stops short of it
## takes the default, which is the player's file.
const SAVE_ENTRY_POINTS: Dictionary = {
	"store": 2, "load_run": 2, "clear_run": 2,
	"store_vigil": 2, "load_vigil": 1, "clear": 1, "clear_vigil": 1,
}
## `Preferences.read_from_disk(path, legacy_audio_path)`: both default to the player's.
const PREFERENCES_ARGUMENTS: int = 2
const INSTALLERS: PackedStringArray = [
	"TestProfile.install(", ".install_profile(", "select_profile", "apply_dev_scenario(",
]
## The suite has well over this many scripts; fewer means the census read nothing.
const FLOOR_OF_SCRIPTS: int = 60
const PROBE: String = "suite_isolation_probe"
## Said once after the findings, so a failure carries its own way out.
const REMEDY: String = "bind a scratch profile with TestProfile.install, or run inside TestProfile.in_sandbox (docs/dev-tools.md, \"The test suite never touches the player's profile\")"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("suite isolation: %s" % what)


static func run(fails: Array[String]) -> void:
	_rules_detect_what_they_claim(fails)
	_helper_contract(fails)
	_sandbox_moves_user_dir(fails)
	_suite_is_clean(fails)


# ---------------------------------------------------------------- the census

static func _suite_is_clean(fails: Array[String]) -> void:
	var paths: Array[String] = _scripts(TESTS_ROOT)
	_check(fails, paths.size() >= FLOOR_OF_SCRIPTS,
		"only %d scripts found under tests/; the census would pass without reading the suite"
			% paths.size())
	var found: bool = false
	for path: String in paths:
		if ALLOWED.has(path):
			continue
		for finding: String in scan(path, FileAccess.get_file_as_string(path)):
			fails.append("suite isolation: %s" % finding)
			found = true
	if found:
		fails.append("suite isolation: to fix these, %s" % REMEDY)


## Every finding in one script, each naming `path:line`.
static func scan(path: String, source: String) -> Array[String]:
	var kept: PackedStringArray = PackedStringArray()
	var code: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		var views: Array[String] = _views(line)
		kept.append(views[0])
		code.append(views[1])
	var code_text: String = "\n".join(code)
	var sandboxed: bool = code_text.contains("TestProfile.in_sandbox(")
	var out: Array[String] = []
	_name_findings(path, kept, code, out)
	_default_path_findings(path, code_text, out)
	if not sandboxed:
		_main_findings(path, code, kept, out)
		_sandbox_findings(path, code_text, out)
	return out


## Rule 1. The identifiers are looked for in code only, because a script may quote
## them when it asserts on the source of another file; the file names are looked
## for wherever they are written, comments aside.
static func _name_findings(path: String, kept: PackedStringArray, code: PackedStringArray,
		out: Array[String]) -> void:
	var identifiers: RegEx = RegEx.create_from_string(
		"SaveService\\.(RUN_PATH|VIGIL_PATH)\\b|Preferences\\.(PATH|LEGACY_AUDIO_PATH)\\b")
	var file_names: RegEx = RegEx.create_from_string(
		"glassvow_(run|vigil)_v2|(?<![A-Za-z0-9_])(settings|audio)\\.cfg")
	for i: int in range(code.size()):
		var hit: RegExMatch = identifiers.search(code[i])
		if hit != null:
			out.append("%s:%d names the player's path %s" % [path, i + 1, hit.get_string()])
		hit = file_names.search(kept[i])
		if hit != null:
			out.append("%s:%d names the player's file %s" % [path, i + 1, hit.get_string()])


## Rule 2.
static func _default_path_findings(path: String, code_text: String,
		out: Array[String]) -> void:
	var calls: RegEx = RegEx.create_from_string("(SaveService|Preferences)\\.(\\w+)\\(")
	for hit: RegExMatch in calls.search_all(code_text):
		var owner_name: String = hit.get_string(1)
		var entry: String = hit.get_string(2)
		var wanted: int = 0
		if owner_name == "SaveService":
			if not SAVE_ENTRY_POINTS.has(entry):
				out.append("%s:%d calls SaveService.%s, which this census cannot place a path in; teach SAVE_ENTRY_POINTS"
					% [path, _line_of(code_text, hit.get_start()), entry])
				continue
			wanted = SAVE_ENTRY_POINTS[entry]
		elif entry == "read_from_disk":
			wanted = PREFERENCES_ARGUMENTS
		else:
			continue
		var given: int = _argument_count(code_text, hit.get_end())
		if given < wanted:
			out.append("%s:%d calls %s.%s with %d of %d arguments, so it takes the player's file"
				% [path, _line_of(code_text, hit.get_start()), owner_name, entry, given, wanted])


## Rule 3: each `Main` is followed, in its own function and before the next `Main`,
## by something that installs a profile on it.
static func _main_findings(path: String, code: PackedStringArray, kept: PackedStringArray,
		out: Array[String]) -> void:
	for body: Dictionary in _functions(code, kept):
		var first: int = body["first"]
		var code_text: String = str(body["code"])
		var kept_text: String = str(body["kept"])
		var births: Array[int] = _positions(code_text, "Main.new(")
		for i: int in range(births.size()):
			var to: int = births[i + 1] if i + 1 < births.size() else kept_text.length()
			if _has_installer(kept_text.substr(births[i], to - births[i])):
				continue
			out.append("%s:%d builds a Main in %s() and never installs a profile after it"
				% [path, first + code_text.substr(0, births[i]).count("\n"),
					str(body["name"])])


## Rule 4.
static func _sandbox_findings(path: String, code_text: String, out: Array[String]) -> void:
	for marker: String in ["TestProfile.production_run_path(",
			"TestProfile.production_vigil_path(", "_boot_args"]:
		var at: int = code_text.find(marker)
		if at >= 0:
			out.append("%s:%d uses %s outside a sandbox" % [path, _line_of(code_text, at), marker])


# ------------------------------------------------------- rules against samples

## Each rule against a source it must flag and a source it must not. Without this
## a pattern that quietly stopped matching would leave the census green over a
## suite it no longer reads.
static func _rules_detect_what_they_claim(fails: Array[String]) -> void:
	var head: String = "static func f() -> void:\n"
	var install: String = "\tTestProfile.install(main)\n"
	var sandbox: String = "\tTestProfile.in_sandbox([], Callable())\n"
	var cases: Array[Dictionary] = [
		# rule 1
		{"name": "the run path constant", "want": "names the player's path",
			"source": head + "\tvar p: String = SaveService.RUN_PATH\n"},
		{"name": "the Vigil path constant", "want": "names the player's path",
			"source": head + "\tvar p: String = SaveService.VIGIL_PATH\n"},
		{"name": "the settings path constant", "want": "names the player's path",
			"source": head + "\tvar p: String = Preferences.PATH\n"},
		{"name": "the run file name", "want": "names the player's file",
			"source": head + "\tvar p: String = \"user://glassvow_run_v2.json\"\n"},
		{"name": "the settings file name", "want": "names the player's file",
			"source": head + "\tvar p: String = \"user://settings.cfg\"\n"},
		{"name": "scratch names are fine", "want": "",
			"source": head + "\tvar p: String = \"user://test_p41_settings.cfg\"\n\tvar q: String = \"user://glassvow_test_run_v2.json\"\n"},
		{"name": "a comment may say it", "want": "",
			"source": head + "\t# SaveService.RUN_PATH and user://settings.cfg\n\tpass\n"},
		{"name": "an assertion on another file's source may quote a constant", "want": "",
			"source": head + "\tvar ok: bool = \"x\".contains(\"SaveService.RUN_PATH\")\n"},
		# rule 2
		{"name": "store on the default", "want": "with 1 of 2 arguments",
			"source": head + "\tSaveService.store(r)\n"},
		{"name": "load_vigil on the default", "want": "with 0 of 1 arguments",
			"source": head + "\tSaveService.load_vigil()\n"},
		{"name": "clear on the default", "want": "with 0 of 1 arguments",
			"source": head + "\tSaveService.clear()\n"},
		{"name": "an argument list split over lines is counted", "want": "",
			"source": head + "\tSaveService.store(\n\t\tr,\n\t\t\"user://test_x.json\")\n"},
		{"name": "a comma inside a nested call is not an argument", "want": "with 1 of 2 arguments",
			"source": head + "\tSaveService.store(g(1, 2))\n"},
		{"name": "explicit scratch paths", "want": "",
			"source": head + "\tSaveService.store(r, \"user://test_x.json\")\n\tSaveService.clear_run(\"\", \"user://test_x.json\")\n"},
		{"name": "an entry point the census cannot place", "want": "cannot place a path",
			"source": head + "\tSaveService.purge(1)\n"},
		{"name": "preferences on the default", "want": "with 0 of 2 arguments",
			"source": head + "\tPreferences.read_from_disk()\n"},
		{"name": "preferences with one file", "want": "with 1 of 2 arguments",
			"source": head + "\tPreferences.read_from_disk(\"user://test_a.cfg\")\n"},
		{"name": "preferences with both files", "want": "",
			"source": head + "\tPreferences.read_from_disk(\"user://test_a.cfg\", \"user://test_b.cfg\")\n"},
		{"name": "the in-memory stand-in reads nothing", "want": "",
			"source": head + "\tvar p: Preferences = Preferences.new()\n"},
		# rule 3
		{"name": "a Main left on the default profile", "want": "never installs a profile",
			"source": head + "\tvar m: Main = Main.new()\n\tm._show_title()\n"},
		{"name": "a Main with the helper", "want": "",
			"source": head + "\tvar m: Main = Main.new()\n" + install},
		{"name": "an install before the Main does not count", "want": "never installs a profile",
			"source": head + install + "\tvar m: Main = Main.new()\n"},
		{"name": "every Main in a function needs its own install", "want": "never installs a profile",
			"source": head + "\tvar a: Main = Main.new()\n" + install + "\tvar b: Main = Main.new()\n"},
		{"name": "a Main adopting a profile directly", "want": "",
			"source": head + "\tvar m: Main = Main.new()\n\tm.install_profile(\"user://test_a.json\", \"user://test_b.json\")\n"},
		{"name": "a Main handed to the boot", "want": "",
			"source": head + "\tvar m: Main = Main.new()\n\tboot.call(\"select_profile\", m, args)\n"},
		{"name": "a multi-line signature is still one function", "want": "never installs a profile",
			"source": "static func f(\n\ta: int\n) -> void:\n\tvar m: Main = Main.new()\n"},
		{"name": "another function's install does not cover this one", "want": "never installs a profile",
			"source": head + "\tvar m: Main = Main.new()\n\n\nstatic func g() -> void:\n" + install},
		{"name": "a sandboxed script may build a Main on the defaults", "want": "",
			"source": head + sandbox + "\tvar m: Main = Main.new()\n"},
		# rule 4
		{"name": "the player's run path outside a sandbox", "want": "outside a sandbox",
			"source": head + "\tvar p: String = TestProfile.production_run_path()\n"},
		{"name": "the player's Vigil path outside a sandbox", "want": "outside a sandbox",
			"source": head + "\tvar p: String = TestProfile.production_vigil_path()\n"},
		{"name": "the player's path inside a sandbox", "want": "",
			"source": head + sandbox + "\tvar p: String = TestProfile.production_run_path()\n"},
		{"name": "booting _ready outside a sandbox", "want": "outside a sandbox",
			"source": head + "\tm._boot_args = a\n"},
		{"name": "booting _ready inside a sandbox", "want": "",
			"source": head + sandbox + "\tm._boot_args = a\n"},
	]
	for case: Dictionary in cases:
		var findings: Array[String] = scan("sample", str(case["source"]))
		var want: String = str(case["want"])
		var flagged: bool = false
		for finding: String in findings:
			flagged = flagged or (not want.is_empty() and finding.contains(want))
		if want.is_empty():
			_check(fails, findings.is_empty(),
				"rule sample '%s' was flagged: %s" % [case["name"], findings])
		else:
			_check(fails, flagged,
				"rule sample '%s' was not flagged with '%s' (got %s)" % [case["name"], want, findings])


# ------------------------------------------------------------ the helper itself

static func _helper_contract(fails: Array[String]) -> void:
	for path: String in [TestProfile.RUN_PATH, TestProfile.VIGIL_PATH,
			"user://test_scene_wiring_run_v2.json", "user://glassvow_test_act4_run_v2.json"]:
		_check(fails, TestProfile.is_scratch(path), "%s is not scratch" % path)
	for path: String in [
			SaveService.RUN_PATH, SaveService.VIGIL_PATH, Preferences.PATH,
			Preferences.LEGACY_AUDIO_PATH, ScenarioKernel.RUN_PATH, ScenarioKernel.VIGIL_PATH,
			"user://../test_escape.json", "res://test_res.json", "test_relative.json"]:
		_check(fails, not TestProfile.is_scratch(path), "%s counts as scratch" % path)
	for path: String in [
			SaveService.RUN_PATH, SaveService.VIGIL_PATH, Preferences.PATH,
			Preferences.LEGACY_AUDIO_PATH]:
		_check(fails, TestProfile.is_production(path),
			"%s is not recognised as the player's" % path)
	for path: String in [TestProfile.RUN_PATH, ScenarioKernel.RUN_PATH, ScenarioKernel.VIGIL_PATH]:
		_check(fails, not TestProfile.is_production(path), "%s is taken for the player's" % path)
	# A request for anything but two scratch paths binds the shared pair instead.
	_check(fails, TestProfile.binding_for("user://test_a.json", "user://test_b.json")
			== PackedStringArray(["user://test_a.json", "user://test_b.json"]),
		"two scratch paths were not bound as asked")
	var shared: PackedStringArray = PackedStringArray(
		[TestProfile.RUN_PATH, TestProfile.VIGIL_PATH])
	_check(fails, TestProfile.binding_for(SaveService.RUN_PATH, "user://test_b.json") == shared,
		"the player's run path was bound instead of the shared scratch pair")
	_check(fails, TestProfile.binding_for("user://test_a.json", SaveService.VIGIL_PATH) == shared,
		"the player's Vigil path was bound instead of the shared scratch pair")
	# The player's paths are shown to a sandbox and to nothing else.
	_check(fails, TestProfile.reveal(SaveService.RUN_PATH, true) == SaveService.RUN_PATH,
		"a sandbox was not shown the player's path")
	_check(fails, not TestProfile.reveal(SaveService.RUN_PATH, false).begins_with("user://glassvow"),
		"the player's path was shown outside a sandbox")
	_check(fails, not TestProfile.is_sandboxed(), "a sandbox was left open by an earlier suite")
	_install_binds_a_main(fails)


static func _install_binds_a_main(fails: Array[String]) -> void:
	var run_path: String = "user://test_suite_isolation_run_v2.json"
	var vigil_path: String = "user://test_suite_isolation_vigil_v2.json"
	var main: Main = Main.new()
	main._vigil = VigilState.blank()
	main._vigil.whispers = 41
	TestProfile.install(main, run_path, vigil_path)
	_check(fails, main._run_save_path == run_path and main._vigil_save_path == vigil_path,
		"install did not bind both paths")
	_check(fails, main._vigil != null and main._vigil.whispers == 0,
		"install kept the Vigil the Main started with")
	main.free()
	TestProfile.wipe(run_path, vigil_path)


## The one claim the sandbox rests on: it really moves `user://`. If a later engine
## caches the directory this fails here, loudly, before four suites rely on it.
static func _sandbox_moves_user_dir(fails: Array[String]) -> void:
	var outside: String = OS.get_user_data_dir()
	var seen: Dictionary = {}
	TestProfile.in_sandbox(fails, _observe_sandbox.bind(outside, seen))
	var ran: bool = seen.get("ran", false)
	var moved: bool = seen.get("moved", false)
	var landed: bool = seen.get("landed", false)
	var open: bool = seen.get("open", false)
	var empty: bool = seen.get("empty", false)
	var run_shown: String = seen.get("run", "")
	var vigil_shown: String = seen.get("vigil", "")
	_check(fails, ran, "the sandbox body never ran")
	_check(fails, moved, "user:// did not move into a directory of its own")
	_check(fails, landed, "a write through user:// did not land in the sandbox")
	_check(fails, open, "the sandbox did not report itself open")
	_check(fails, empty, "the sandbox started with a save in it")
	_check(fails, run_shown == SaveService.RUN_PATH and vigil_shown == SaveService.VIGIL_PATH,
		"the sandbox was not shown the player's paths")
	_check(fails, OS.get_user_data_dir() == outside,
		"user:// did not come back to %s after the sandbox" % outside)
	_check(fails, not TestProfile.is_sandboxed(), "the sandbox is still open after it ended")
	_check(fails, not DirAccess.dir_exists_absolute(str(seen.get("inside", outside))),
		"the sandbox directory was not removed")
	_check(fails, not FileAccess.file_exists(outside.path_join(PROBE)),
		"a write made inside the sandbox reached %s" % outside)
	var nested: Array[String] = []
	TestProfile.in_sandbox(fails, _refuse_to_nest.bind(nested))
	_check(fails, nested.size() == 1, "a sandbox inside a sandbox was not refused")


static func _observe_sandbox(outside: String, seen: Dictionary) -> void:
	var inside: String = OS.get_user_data_dir()
	seen["ran"] = true
	seen["inside"] = inside
	seen["moved"] = inside != outside \
		and inside.get_file().begins_with(TestProfile.SANDBOX_PREFIX)
	seen["open"] = TestProfile.is_sandboxed()
	seen["run"] = TestProfile.production_run_path()
	seen["vigil"] = TestProfile.production_vigil_path()
	seen["empty"] = not FileAccess.file_exists(SaveService.RUN_PATH) \
		and not FileAccess.file_exists(SaveService.VIGIL_PATH) \
		and not FileAccess.file_exists(Preferences.PATH)
	var probe: FileAccess = FileAccess.open("user://%s" % PROBE, FileAccess.WRITE)
	if probe != null:
		probe.close()
	seen["landed"] = FileAccess.file_exists(inside.path_join(PROBE))


static func _refuse_to_nest(nested: Array[String]) -> void:
	TestProfile.in_sandbox(nested, Callable())


# ---------------------------------------------------------------- source views

## The line without its comment, twice: as written, and with the inside of every
## string blanked so an identifier pattern only ever matches code. The two have the
## same length, so an offset in one is an offset in the other.
static func _views(line: String) -> Array[String]:
	var kept: String = ""
	var blanked: String = ""
	var quote: String = ""
	var i: int = 0
	while i < line.length():
		var c: String = line[i]
		if quote.is_empty():
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
			kept += c
			blanked += c
		elif c == "\\" and i + 1 < line.length():
			kept += c + line[i + 1]
			blanked += "  "
			i += 1
		else:
			kept += c
			if c == quote:
				quote = ""
				blanked += c
			else:
				blanked += " "
		i += 1
	return [kept, blanked]


## Every `func` in a script: its name, the 1-based line it starts on, and its text in
## both views. A body ends at the next declaration at column 0, so the `) -> void:`
## that closes a multi-line signature does not cut one short.
static func _functions(code: PackedStringArray, kept: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start: int = -1
	var fname: String = ""
	for i: int in range(code.size() + 1):
		var line: String = code[i] if i < code.size() else ""
		if i < code.size() and not _declares(line):
			continue
		if start >= 0:
			out.append({"name": fname, "first": start + 1,
				"code": "\n".join(code.slice(start, i)), "kept": "\n".join(kept.slice(start, i))})
			start = -1
		if line.begins_with("func ") or line.begins_with("static func "):
			start = i
			fname = line.trim_prefix("static ").trim_prefix("func ").get_slice("(", 0)
	return out


static func _declares(line: String) -> bool:
	for opener: String in ["func ", "static func ", "var ", "static var ", "const ",
			"class ", "class_name ", "extends ", "signal ", "enum ", "@"]:
		if line.begins_with(opener):
			return true
	return false


static func _has_installer(text: String) -> bool:
	for installer: String in INSTALLERS:
		if text.contains(installer):
			return true
	return false


static func _positions(text: String, needle: String) -> Array[int]:
	var out: Array[int] = []
	var at: int = text.find(needle)
	while at >= 0:
		out.append(at)
		at = text.find(needle, at + needle.length())
	return out


static func _line_of(text: String, offset: int) -> int:
	return text.substr(0, offset).count("\n") + 1


## How many arguments the call whose `(` ends just before `from` was given, at the
## top level only: a comma inside a nested call or a list is not one.
static func _argument_count(text: String, from: int) -> int:
	var depth: int = 1
	var commas: int = 0
	var any: bool = false
	var i: int = from
	while i < text.length() and depth > 0:
		var c: String = text[i]
		if c == "(" or c == "[" or c == "{":
			depth += 1
			any = true
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
		elif c == "," and depth == 1:
			commas += 1
		elif c != " " and c != "\t" and c != "\n":
			any = true
		i += 1
	return commas + 1 if any else 0


static func _scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append("%s/%s" % [root, file])
	for sub: String in dir.get_directories():
		out.append_array(_scripts("%s/%s" % [root, sub]))
	out.sort()
	return out
