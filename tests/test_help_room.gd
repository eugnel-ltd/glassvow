extends RefCounted
## How to Play is seven panes of one window (docs/design/2026-10-03-title-rooms
## §4.2, §11.1). It opens on the first page, scrolled to its top, with focus on
## that page's pane (it used to open past its own title, pulled to a button at
## the foot); each pane shows its own page; at pad every page fits its glass
## without scrolling, in both languages; the Flame codex stands under the
## Lantern's rules, a flame beside each line, and nothing before a colour is
## seen; a phone's numerals show the lit section's name beside them. The room
## is built with its lit page only, each other page on its first showing.

const SUITE: String = "res://tests/test_help_room.gd"
const RUN_PATH: String = "user://test_help_room_run_v2.json"
const VIGIL_PATH: String = "user://test_help_room_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


class QuietMain extends Main:
	func _ready() -> void:
		pass


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("help_room: %s" % what)


static func run(fails: Array[String]) -> void:
	_names(fails)
	_pages_built_on_showing(fails)
	TreeSuite.spawn(fails, SUITE)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## A pane's name is its title up to the dash, in both scripts.
static func _names(fails: Array[String]) -> void:
	_check(fails, HelpScreen.short_title("The Vigil — What Death Leaves Behind") == "The Vigil",
		"the English title is not cut at its dash")
	_check(fails, HelpScreen.short_title("守夜——死亡留下之物") == "守夜", "the zh-Hant title is not cut at its dash")
	_check(fails, HelpScreen.short_title("Combat") == "Combat", "a title with no dash is cut")


## The tap frame shapes one page, not seven (§11.6): a page stays empty until
## its section is first shown, and is whole from then on.
static func _pages_built_on_showing(fails: Array[String]) -> void:
	var help: HelpScreen = HelpScreen.new(&"pad-landscape")
	var room: LeadlightRoom = help.room()
	for id: StringName in HelpScreen.SECTION_IDS:
		var built: bool = room.page(id).get_child_count() > 0
		_check(fails, built == (id == &"road"), "the %s page was %s with the room" % [
			id, "built" if built else "not built"])
	room.select(&"combat")
	_check(fails, room.page(&"combat").find_child("Body", false, false) != null,
		"the Combat page was not built on showing")
	room.select(&"road")
	_check(fails, room.page(&"combat").get_child_count() > 0, "a shown page was emptied when left")
	help.free()


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	var kept_locale: Locale = Locale.active
	Preferences.active = Preferences.new()
	Preferences.active.diagnostics_notice_seen = true
	var content: ContentDB = ContentDB.load_full()
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		Preferences.active.language = String(code)
		await _opens_on_its_first_page(fails, tree, host, content, code)
		await _pages_fit(fails, tree, host, code)
	Locale.active = Locale.new(Locale.CODE_EN)
	await _coda(fails, tree, host, content)
	await _phone(fails, tree, host)
	Locale.active = kept_locale
	Preferences.active = kept


static func _opens_on_its_first_page(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, code: StringName) -> void:
	var main: Main = _boot(content)
	host.add_child(main)
	main._title_kindled = true
	main._show_title()
	await _frames(tree, 3)
	var title: TitleScreen = main._choice_screen as TitleScreen
	var word: Control = title.word("help")
	await _tap(tree, host, word.get_global_rect().get_center())
	var help: HelpScreen = main._modal as HelpScreen
	_check(fails, help != null, "%s: How to Play did not open from its word" % code)
	if help != null:
		await _frames(tree, 2)
		var room: LeadlightRoom = help.room()
		_check(fails, room.selected() == &"road" and room.scroll().scroll_vertical == 0,
			"%s: How to Play did not open on its first page at the top" % code)
		_check(fails, room.tab(&"road").has_focus(), "%s: focus is not on the first page's pane" % code)
		for id: StringName in HelpScreen.SECTION_IDS:
			await _tap(tree, host, room.tab(id).get_global_rect().get_center())
			_check(fails, room.selected() == id and room.page(id).visible,
				"%s: the %s pane does not show its page" % [code, id])
	main._clear_route()
	host.remove_child(main)
	main.queue_free()
	await tree.process_frame


## At pad every page stands whole in its glass: no page taller than the scroll.
static func _pages_fit(fails: Array[String], tree: SceneTree, host: SubViewport, code: StringName) -> void:
	var codex: Array[Dictionary] = _codex_rows()
	var help: HelpScreen = HelpScreen.new(&"pad-landscape", null, codex)
	host.add_child(help)
	await _frames(tree, 3)
	var room: LeadlightRoom = help.room()
	for id: StringName in HelpScreen.SECTION_IDS:
		room.select(id)
		await _frames(tree, 2)
		var tall: float = room.page(id).get_combined_minimum_size().y
		var glass: float = room.scroll().size.y
		_check(fails, tall <= glass + 0.5, "%s: the %s page needs %d px of a %d px glass" % [
			code, id, int(tall), int(glass)])
	help.queue_free()
	await tree.process_frame


static func _coda(fails: Array[String], tree: SceneTree, host: SubViewport, content: ContentDB) -> void:
	var bare: HelpScreen = HelpScreen.new()
	bare.room().select(&"lantern")
	_check(fails, bare.find_child("Coda", true, false) == null, "the codex showed before a colour was seen")
	bare.free()
	var rows: Array[Dictionary] = _codex_rows(content)
	var help: HelpScreen = HelpScreen.new(&"pad-landscape", null, rows)
	host.add_child(help)
	help.room().select(&"lantern")
	await _frames(tree, 2)
	var coda: RichTextLabel = help.find_child("Coda", true, false) as RichTextLabel
	_check(fails, coda != null and coda.get_parent().get_parent() == help.room().page(&"lantern"),
		"the codex is not on the Lantern's page")
	if coda != null:
		var flames: HelpScreen.CodaFlames = coda.find_child("CodaFlames", false, false) as HelpScreen.CodaFlames
		_check(fails, flames != null and flames.colours.size() == rows.size(),
			"the codex lines do not each stand beside a flame")
		if flames != null and rows.size() > 0:
			_check(fails, flames.colours[0] == HelpScreen.codex_colour(rows[0]),
				"a codex flame is not the colour its line describes")
		_check(fails, coda.text.count("\n") == rows.size() - 1, "the codex is not one colour to a line")
	help.queue_free()
	await tree.process_frame


static func _phone(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var help: HelpScreen = HelpScreen.new(&"phone-landscape")
	host.add_child(help)
	await _frames(tree, 2)
	var room: LeadlightRoom = help.room()
	var name_line: Label = room.find_child("SectionName", true, false) as Label
	_check(fails, room.tab(&"road").text == LeadlightNumerals.carved(1),
		"a phone's pane is not its numeral")
	_check(fails, name_line != null and name_line.text == HelpScreen.short_title(Locale.active.t("ui.help.roadTitle")),
		"a phone does not show the lit section's name beside the numerals")
	room.step_section(1)
	_check(fails, room.selected() == &"combat" and name_line != null
			and name_line.text == Locale.active.t("ui.help.combatTitle"),
		"a phone's swipe did not turn to the next section and name it")
	var pane: LeadlightPane = room.tab(&"road")
	_check(fails, pane.size.x >= 60.0 - 0.5 and pane.size.y >= 44.0 - 0.5,
		"a phone's numeral pane is under 60×44 (%s)" % pane.size)
	help.queue_free()
	await tree.process_frame


static func _codex_rows(content: ContentDB = null) -> Array[Dictionary]:
	var table: Array = content.line_table if content != null else ContentDB.load_full(false).line_table
	var rows: Array[Dictionary] = []
	for id: String in ["codex.lantern.shatter", "codex.lantern.edge", "codex.lantern.lantern"]:
		var row: Dictionary = LineTable.row_by_id(table, id)
		if not row.is_empty():
			rows.append(row)
	return rows


static func _boot(content: ContentDB) -> Main:
	LeadlightFocus.keyed = false
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = QuietMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._vigil.scenes_seen.append("opening")
	return main


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame


static func _tap(tree: SceneTree, host: SubViewport, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	host.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.position = at
		event.global_position = at
		host.push_input(event, true)
		await tree.process_frame
	await _frames(tree, 2)
