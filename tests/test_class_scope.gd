extends RefCounted
## #543: 1.0 is the Duskblade. Every production entry admits a new Duskblade run
## and no Ashwarden run; the refusal lands before any seed, save write or
## abandonment; an existing Ashwarden v2 save still loads, plays to its end and
## is followed by a Duskblade; the Vigil, the Dawn and Help never promise the
## deferred class. The fixture is a mid-run Ashwarden save written by the
## pre-#543 save path, holding the Ashfall Art, a Smolderphial and Virulence.

const RUN_PATH: String = "user://test_class_scope_run_v2.json"
const VIGIL_PATH: String = "user://test_class_scope_vigil_v2.json"
const ASH_FIXTURE: String = "res://tests/fixtures/ashwarden_v2_run.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const DUSK: int = 0
const ASH: int = 1


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("class_scope: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_policy(content, fails)
	_policy_follows_the_data(fails)
	_fresh_title_begins_duskblade(content, fails)
	_earned_aspect2_is_no_choice(content, fails)
	_embark_offers_no_ashwarden(content, fails)
	_embark_refuses_ashwarden(content, fails)
	_new_run_refuses_ashwarden(content, fails)
	_begin_anew_refuses_before_abandonment(content, fails)
	_result_continue_begins_duskblade(content, fails)
	_one_construction_path(fails)
	_ashwarden_save_plays_to_its_end(content, fails)
	_keeper_hides_ashfall_from_duskblade(content, fails)
	_vigil_promises_no_ashwarden(content, fails)
	_help_promises_no_ashwarden(fails)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _policy(content: ContentDB, fails: Array[String]) -> void:
	_check(fails, ClassScope.admits(content, DUSK, []), "a blank profile may not start the Duskblade")
	_check(fails, not ClassScope.admits(content, ASH, []), "a blank profile may start the Ashwarden")
	_check(fails, not ClassScope.admits(content, ASH, ["aspect2"]),
		"an earned aspect2 admits the deferred Ashwarden")
	_check(fails, not ClassScope.admits(content, 2, ["aspect2"])
			and not ClassScope.admits(content, -1, []), "an unknown aspect index is admitted")
	_check(fails, ClassScope.admitted(content, ["aspect2"]) == [DUSK],
		"admitted classes are not exactly the Duskblade")
	_check(fails, ClassScope.withheld_unlocks(content) == ["aspect2"],
		"aspect2 is not the one withheld unlock")
	_check(fails, not ClassScope.shows_deed(content, "ashSermon"),
		"the Vigil shows the Sermon of Ash no offered class can pursue")
	for id: String in ["paneBreaker", "lanternFed", "firstDawn", "hundredShards"]:
		_check(fails, ClassScope.shows_deed(content, id), "the Vigil hides %s" % id)
	# The class keeps its canonical row and index: saves, shades and monuments
	# that name it still resolve.
	var ash: Dictionary = content.aspects[ASH] if content.aspects.size() == 2 else {}
	_check(fails, str(ash.get("id", "")) == "ashwarden",
		"the Ashwarden row moved or left content")


## 1.1 flips one field: the same policy then admits the Ashwarden to a profile
## that earned it, and still refuses one that did not.
static func _policy_follows_the_data(fails: Array[String]) -> void:
	var open: ContentDB = ContentDB.load_full(false)
	var ash: Dictionary = open.aspects[ASH]
	ash.erase("deferred")
	_check(fails, ClassScope.admits(open, ASH, ["aspect2"]),
		"an undeferred Ashwarden is refused to a profile that earned it")
	_check(fails, not ClassScope.admits(open, ASH, []),
		"an undeferred Ashwarden is admitted without its unlock")
	_check(fails, ClassScope.withheld_unlocks(open).is_empty()
			and ClassScope.shows_deed(open, "ashSermon"),
		"an undeferred Ashwarden still withholds its unlock or its deed")


static func _fresh_title_begins_duskblade(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._show_title()
	main._on_title_choice("begin", null)
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"fresh title 續火 did not begin a Duskblade run")
	_dispose(main)


## A profile that earned aspect2 but never saw the opening has no real class
## choice now, so it takes run 1's path: straight into the opening, as Duskblade.
static func _earned_aspect2_is_no_choice(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._vigil.unlocks.append("aspect2")
	main._show_title()
	main._on_title_choice("begin", null)
	_check(fails, not (main._route_screen is EmbarkScreen),
		"an earned but deferred aspect2 still opened Embark")
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"an earned aspect2 profile did not begin a Duskblade run")
	_dispose(main)


static func _embark_offers_no_ashwarden(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._vigil.unlocks.append("aspect2")
	main._vigil.scenes_seen.append("opening")
	main._embark_aspect = ASH  # a stale selection from an older build
	main._show_title()
	main._on_title_choice("begin", null)
	var screen: EmbarkScreen = main._route_screen as EmbarkScreen
	_check(fails, screen != null, "a returning profile did not reach Embark")
	if screen != null:
		_check(fails, screen._aspect_cards.is_empty() and screen._aspect_row == null,
			"Embark offered a class picker with only the Duskblade admitted")
		_check(fails, screen._selected_aspect == DUSK, "Embark selected the Ashwarden")
		screen._begin.pressed.emit()
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"Embark's Begin did not start a Duskblade run")
	_dispose(main)


static func _embark_refuses_ashwarden(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._vigil.unlocks.append("aspect2")
	main._vigil.scenes_seen.append("opening")
	main._on_embark_begin(ASH, 0)
	_check(fails, main.game == null, "a direct Ashwarden begin created a run")
	_check(fails, not FileAccess.file_exists(RUN_PATH), "a refused Ashwarden begin wrote a save")
	_check(fails, main._route_screen is EmbarkScreen and main._embark_aspect == DUSK,
		"a refused Ashwarden begin did not return to Embark on the Duskblade")
	_dispose(main)


## `_new_run` is where the title, Embark, Begin Anew, the result screen and the
## capture shortcuts (`--map`, `--fight=`, `--enter=`, `--shop`, `--dawn`,
## `--onboard=`) all construct, so its refusal covers each of them.
static func _new_run_refuses_ashwarden(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._vigil.unlocks.append("aspect2")
	main._new_run({"aspect": ASH, "vow": 0})
	_check(fails, main.game == null and not FileAccess.file_exists(RUN_PATH),
		"_new_run constructed or stored an Ashwarden run")
	main._new_run()
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"the shortcuts' default _new_run() is not a Duskblade run")
	_dispose(main)


static func _begin_anew_refuses_before_abandonment(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	var saved: RunState = RunState.new_run(content, 54301, "run-dusk-543")
	saved.map = WorldMap.benchmark(saved).to_dict()
	_check(fails, SaveService.store(saved, RUN_PATH), "could not seed the saved run")
	var before: String = FileAccess.get_file_as_string(RUN_PATH)
	main._vigil.unlocks.append("aspect2")
	main._vigil.scenes_seen.append("opening")
	main._embark_aspect = ASH  # stale: set before the class was deferred
	main._on_begin_anew("begin")
	_check(fails, FileAccess.get_file_as_string(RUN_PATH) == before,
		"a refused Begin Anew changed the saved run")
	_check(fails, not FileAccess.file_exists(VIGIL_PATH) and main._vigil.runs_played == 0,
		"a refused Begin Anew recorded the old run as abandoned")
	_check(fails, main.game == null, "a refused Begin Anew started a run")
	_dispose(main)


static func _result_continue_begins_duskblade(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = _main(content)
	main._vigil.unlocks.append("aspect2")
	main._vigil.scenes_seen.append("opening")
	main._embark_aspect = ASH
	main._run_over = true
	main._on_result_continue()
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"the result screen's next run is not a Duskblade")
	_dispose(main)


## No second, unchecked way to build a fresh run: Main calls the factory once,
## inside `_new_run`, after the gate.
static func _one_construction_path(fails: Array[String]) -> void:
	var source: String = FileAccess.get_file_as_string("res://application/main.gd")
	_check(fails, source.count("RunState.new_run(") == 1,
		"main.gd constructs a fresh run outside _new_run")
	var start: int = source.find("func _new_run(")
	var gate: int = source.find("_admits_new_run(", start)
	var factory: int = source.find("RunState.new_run(", start)
	_check(fails, start >= 0 and gate > start and gate < factory,
		"_new_run builds the run before the class gate")


static func _ashwarden_save_plays_to_its_end(content: ContentDB, fails: Array[String]) -> void:
	var bytes: String = FileAccess.get_file_as_string(ASH_FIXTURE)
	var main: Main = _main(content)
	var f: FileAccess = FileAccess.open(RUN_PATH, FileAccess.WRITE)
	f.store_string(bytes)
	f.close()
	main._vigil.unlocks.append("aspect2")
	main._vigil.scenes_seen.append("opening")
	main._show_title()
	var saved: RunState = main._load_run()
	_check(fails, saved != null and saved.aspect == ASH and saved.art == &"ashfall"
			and saved.player.potions[0] == "venom",
		"the Ashwarden fixture did not load as itself")
	_check(fails, FileAccess.get_file_as_string(RUN_PATH) == bytes,
		"showing the title rewrote the Ashwarden save")
	# The lantern is the title's primary action: with a saved run it is Back to
	# the Road, named on the plaque that belongs to it.
	var title: TitleScreen = main._choice_screen as TitleScreen
	_check(fails, title != null and title.primary_id() == "continue"
			and title.plaque_text().to_lower() == Locale.active.t("ui.menu.backToRoad").to_lower(),
		"the title does not offer the Ashwarden run back")
	if saved == null:
		_dispose(main)
		return
	main._on_title_choice("continue", saved)
	_check(fails, main.game != null and main.game.run.aspect == ASH
			and main.game.run.run_id == "run-ashwarden-543",
		"Continue did not resume the Ashwarden as itself")
	var on_disk: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, on_disk != null and on_disk.aspect == ASH
			and on_disk.run_id == "run-ashwarden-543",
		"resuming replaced or re-classed the Ashwarden save")
	# Its first dawn: the Vigil earns aspect2 history, and the Dawn announces
	# nothing about a class this build does not offer.
	main._vigil.unlocks.clear()
	main.game.run.pending_run_end = {"outcome": "win", "bequestAnswered": true}
	main._on_terminal_commit("")
	_check(fails, main._vigil.unlocks.has("aspect2"),
		"the first dawn no longer records the earned aspect2")
	var dawn: Variant = main.game.run.pending_dawn if main.game != null else null
	_check(fails, typeof(dawn) == TYPE_DICTIONARY, "the Ashwarden win owed no Dawn")
	if typeof(dawn) != TYPE_DICTIONARY:
		_dispose(main)
		return
	var owed: Dictionary = dawn
	var events: Array = owed["events"]
	for ev_v: Variant in events:
		var ev: Dictionary = ev_v
		_check(fails, not str(ev.get("title", "")).to_lower().contains("aspect")
				and not str(ev.get("title", "")).contains("Ashwarden"),
			"the Dawn announced the deferred class: %s" % str(ev.get("title", "")))
	owed["cursor"] = events.size()
	main._finish_dawn()
	_check(fails, main.game == null and not FileAccess.file_exists(RUN_PATH),
		"the finished Ashwarden run was not closed")
	main._on_title_choice("begin", null)
	var embark: EmbarkScreen = main._route_screen as EmbarkScreen
	if embark != null:
		embark._begin.pressed.emit()
	_check(fails, main.game != null and main.game.run.aspect == DUSK,
		"the run after the Ashwarden is not a Duskblade")
	_dispose(main)


static func _keeper_hides_ashfall_from_duskblade(content: ContentDB, fails: Array[String]) -> void:
	for aspect: int in [DUSK, ASH]:
		var main: Main = _main(content)
		var rs: RunState = RunState.new_run(content, 54302 + aspect, "run-keeper-%d" % aspect,
			{"aspect": aspect, "unlocks": ["lamplighter", "phials"],
				"reveals": ["lamplighter", "phials"]})
		rs.map = WorldMap.benchmark(rs).to_dict()
		rs.pending_lamplighter = true
		main.game = GlassvowGame.new(content, rs)
		main._map = WorldMap.from_dict(rs.map)
		main._show_lamplighter()
		var screen: LamplighterScreen = main._route_screen as LamplighterScreen
		_check(fails, screen != null, "the Keeper did not open for aspect %d" % aspect)
		if screen != null:
			_check(fails, screen._arts.has("ashfall") == (aspect == ASH),
				"the Keeper's Arts for aspect %d mis-handle Ashfall" % aspect)
			var boons: Array = main.game.run.quest_scratch["lamplighterOffer"]["boons"]
			_check(fails, aspect == ASH or not boons.has("venomPouch"),
				"the Keeper offered the Duskblade the Pouch of Ash")
			if aspect == DUSK:
				main._on_lamplighter_confirmed(str(boons[0]), &"ashfall")
				_check(fails, main.game.run.art == &"flare" and main.game.run.pending_lamplighter,
					"the Keeper accepted Ashfall for the Duskblade")
		_dispose(main)


static func _vigil_promises_no_ashwarden(content: ContentDB, fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	var screen: VigilScreen = VigilScreen.new(vigil, content)
	var texts: PackedStringArray = []
	for label: Label in _labels(screen):
		texts.append(label.text)
	var joined: String = "\n".join(texts)
	_check(fails, not joined.contains(Locale.active.t("ui.vigil.ashwarden")),
		"the Vigil still promises the Ashwarden")
	_check(fails, not joined.contains(str(content.deeds["ashSermon"].get("name", ""))),
		"the Vigil still lists the Sermon of Ash")
	var first_dawn: String = str(content.deeds["firstDawn"].get("desc", ""))
	_check(fails, texts.has(first_dawn),
		"The First Dawn does not read as its bare description")
	_check(fails, joined.contains(str(content.deeds["paneBreaker"].get("name", ""))),
		"the Vigil lost a pursuable deed")
	screen.free()


static func _help_promises_no_ashwarden(fails: Array[String]) -> void:
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT), "zh-Hant did not load")
	var en_body: String = en.t("ui.help.vigilBody")
	var zh_body: String = zh.t("ui.help.vigilBody")
	_check(fails, not en_body.is_empty() and not en_body.contains("Ashwarden")
			and not en_body.contains("aspect"), "en Help still promises the Ashwarden")
	_check(fails, not zh_body.is_empty() and not zh_body.contains("灰衛")
			and not zh_body.contains("面向"), "zh-Hant Help still promises the Ashwarden")


static func _labels(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	for child: Node in node.find_children("*", "Label", true, false):
		out.append(child as Label)
	return out


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
