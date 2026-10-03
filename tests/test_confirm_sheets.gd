extends RefCounted
## The four yes-or-stay questions ask through one LeadlightConfirm, and each
## answer does what it says (build 18 play report). Leave the Road was dead on
## the iPad: its Leave called SceneTree.quit(), which iOS ignores, because the
## Quit entries were gated on "not web" only. Quit is now offered only where the
## app may close itself (AppExit), and on a mobile build it is not offered.

const RUN_PATH: String = "user://test_confirm_sheets_run_v2.json"
const VIGIL_PATH: String = "user://test_confirm_sheets_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("confirm_sheets: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous: Variant = AppExit.forced
	var content: ContentDB = ContentDB.load_full()
	AppExit.forced = true
	_leave_the_road_from_the_map(fails, content)
	_abandon_and_erase(fails, content)
	_begin_anew_over_the_title(fails, content)
	_veil_tap_is_the_safe_answer(fails)
	AppExit.forced = false
	_no_dead_quit_on_mobile(fails, content)
	AppExit.forced = previous
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _leave_the_road_from_the_map(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, 61801)
	var quits: Array[int] = [0]
	main._quit = func() -> void: quits[0] += 1
	var map: WorldMapScreen = main._map_screen
	_check(fails, map != null, "the map did not mount")
	var sheet: LeadlightConfirm = _ask_to_leave(main)
	_check(fails, sheet != null, "Quit Game did not open the Leave the Road sheet")
	if sheet != null:
		sheet.stay().pressed.emit()
		_check(fails, main._modal == null and main._map_screen == map and quits[0] == 0,
			"Stay did not close the sheet back onto the map")
	sheet = _ask_to_leave(main)
	if sheet != null:
		sheet.action().pressed.emit()
		_check(fails, quits[0] == 1 and main._modal == null, "Leave did not leave")
	_dispose(main)


static func _ask_to_leave(main: Main) -> LeadlightConfirm:
	main._show_run_menu()
	var menu: RunMenuPanel = main._modal as RunMenuPanel
	if menu == null:
		return null
	var quit: Button = _button(menu, Locale.active.t("ui.menu.quitGame"))
	if quit == null:
		return null
	quit.pressed.emit()
	return main._modal as LeadlightConfirm


static func _abandon_and_erase(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, 61802)
	main._confirm_abandon()
	var abandon: LeadlightConfirm = main._modal as LeadlightConfirm
	_check(fails, abandon != null, "Abandon Run did not ask through the sheet")
	if abandon != null:
		abandon.stay().pressed.emit()
		_check(fails, main._modal == null and main.game.run.pending_run_end == null,
			"Stay on the Road did not keep the run")
	main._confirm_reset()
	var erase: LeadlightConfirm = main._modal as LeadlightConfirm
	_check(fails, erase != null, "Erase Everything did not ask through the sheet")
	if erase != null:
		erase.stay().pressed.emit()
		_check(fails, main._modal == null and main.game != null, "Cancel erased")
	main._confirm_abandon()
	abandon = main._modal as LeadlightConfirm
	if abandon != null:
		abandon.action().pressed.emit()
		_check(fails, main.game.run.pending_run_end != null, "Abandon Run did not abandon")
	_dispose(main)


static func _begin_anew_over_the_title(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _map_main(content, 61803)
	main._store_run()
	main.game = null
	main._map = null
	main._show_title()
	main._on_embark_begin(0, 0)
	var sheet: LeadlightConfirm = main._modal as LeadlightConfirm
	_check(fails, sheet != null and main._choice_screen is TitleScreen,
		"Begin Anew did not ask over the title")
	if sheet != null:
		sheet.stay().pressed.emit()
		_check(fails, main._modal == null and main._choice_screen is TitleScreen
				and main._load_run() != null,
			"Stay on the Road did not return to the title with the run kept")
	main._on_embark_begin(0, 0)
	sheet = main._modal as LeadlightConfirm
	if sheet != null:
		var old: String = main._load_run().run_id
		sheet.action().pressed.emit()
		_check(fails, main.game != null and main.game.run.run_id != old,
			"Begin Anew did not begin a new pilgrimage")
	_dispose(main)


static func _veil_tap_is_the_safe_answer(fails: Array[String]) -> void:
	var sheet: LeadlightConfirm = LeadlightConfirm.new("Leave the Road?", "The lantern keeps your place.",
		{"id": "yes", "label": "Leave"}, {"id": "no", "label": "Stay"})
	var got: Array[String] = []
	sheet.chosen.connect(func(id: String) -> void: got.append(id))
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	sheet._on_veil_input(tap)
	sheet.action().pressed.emit()
	_check(fails, got == ["no"], "a tap on the veil is not Stay, or a second answer got through: %s" % [got])
	sheet.free()


static func _no_dead_quit_on_mobile(fails: Array[String], content: ContentDB) -> void:
	var menu: RunMenuPanel = RunMenuPanel.new(&"pad-landscape", false, SfxBus.new())
	_check(fails, _button(menu, Locale.active.t("ui.menu.quitGame")) == null,
		"a mobile build still offers Quit Game, which iOS ignores")
	menu.free()
	var main: Main = _map_main(content, 61804)
	main.game = null
	main._map = null
	main._show_title()
	var title: TitleScreen = main._choice_screen as TitleScreen
	_check(fails, title != null and not title.offers("quit"),
		"a mobile title still offers Quit, which iOS ignores")
	_dispose(main)


static func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("", "Button", true, false):
		var button: Button = node as Button
		if button.text.to_lower() == text.to_lower():
			return button
	return null


static func _map_main(content: ContentDB, seed: int) -> Main:
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
	main._forced_seed = seed
	main._vigil.scenes_seen.append("opening")
	main._new_run()
	if main._route_screen is DepartureScreen:
		var offer: Dictionary = main.game.run.quest_scratch["lamplighterOffer"]
		main._on_lamplighter_confirmed(str(offer["boons"][0]), main.game.run.art)
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
