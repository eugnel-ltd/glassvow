extends RefCounted
## The oval behind Back to the Road (docs/design/2026-10-03-title-rooms §6,
## #655: "the 'back to the road' i sometimes can see the oval"). It was the
## lantern's keyboard focus ring, shown to a touch player because every
## code-path `grab_focus()` with no argument shows focus, even on a control a
## tap left holding it hidden. Each path below is driven as a player drives it,
## with real taps and keys through the viewport, in a Main composed as the other
## suites compose it; after each, nothing under Main shows focus, the lantern
## does not, and the plaque's hairline is dark. A keyboard player keeps the
## ring, now a rim on the lantern's own silhouette.
##
## Focus needs nodes inside a running tree, so the paths run in `TreeSuite`.
## Mutation proof (PR): with `LeadlightFocus.give` reverted to a plain
## `grab_focus()` the suite fails paths a to h; with Main's `_input` removed it
## fails path k.

const SUITE: String = "res://tests/test_focus_modality.gd"
const RUN_PATH: String = "user://test_focus_modality_run_v2.json"
const VIGIL_PATH: String = "user://test_focus_modality_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


## Main without its boot: `_ready` reads the launch, the player's settings and
## a profile, none of which a suite may touch. Composed below as the other
## suites compose a Main, then put in the tree so its screens can hold focus.
class QuietMain extends Main:
	func _ready() -> void:
		pass


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("focus_modality: %s" % what)


static func run(fails: Array[String]) -> void:
	_modality_rules(fails)
	TreeSuite.spawn(fails, SUITE)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## The modality itself: keys and pads show focus, pointers and bare modifiers
## (a screenshot shortcut) do not.
static func _modality_rules(fails: Array[String]) -> void:
	var kept: bool = LeadlightFocus.keyed
	LeadlightFocus.keyed = false
	LeadlightFocus.note(_key(KEY_SHIFT, true))
	LeadlightFocus.note(_key(KEY_META, true))
	_check(fails, not LeadlightFocus.keyed, "a bare modifier counted as keyboard input")
	var chord: InputEventKey = _key(KEY_4, true)
	chord.meta_pressed = true
	chord.shift_pressed = true
	LeadlightFocus.note(chord)
	_check(fails, not LeadlightFocus.keyed, "a Cmd-Shift-4 screenshot chord counted as keyboard input")
	LeadlightFocus.note(_key(KEY_TAB, true))
	_check(fails, LeadlightFocus.keyed, "Tab did not count as keyboard input")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	LeadlightFocus.note(touch)
	_check(fails, not LeadlightFocus.keyed, "a touch did not return to pointer input")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.pressed = true
	LeadlightFocus.note(pad)
	_check(fails, LeadlightFocus.keyed, "a pad button did not count as keyed input")
	LeadlightFocus.keyed = kept


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = String(Locale.CODE_EN)
	Preferences.active.diagnostics_notice_seen = true
	var content: ContentDB = ContentDB.load_full()
	await _vigil_return(fails, tree, host, content)
	await _vigil_route_form(fails, tree, host, content)
	await _departure_back(fails, tree, host, content)
	await _begin_anew_stay(fails, tree, host, content)
	await _run_menu_title(fails, tree, host, content)
	await _rooms_closed_by_tap(fails, tree, host, content)
	await _rite_tap(fails, tree, host, content)
	await _bare_modifiers(fails, tree, host, content)
	await _keyboard_keeps_its_ring(fails, tree, host, content)
	await _key_then_touch(fails, tree, host, content)
	await _thaw_keeps_visibility(fails, tree, host, content)
	await _language_toggle_and_return(fails, tree, host, content)
	Preferences.active = kept


# ---------------------------------------------------------------- the paths

## (a) title, The Vigil, its Return, all by tap.
static func _vigil_return(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, false)
	await _tap(tree, host, _word(main, "vigil"))
	_check(fails, main._route_screen is VigilScreen, "(a) a tap on The Vigil did not open it")
	await _tap(tree, host, _button(main._route_screen, Locale.active.t("ui.vigil.return")))
	_check(fails, main._route_screen == null, "(a) the Vigil's Return did not return")
	_no_ring(fails, main, "(a) the Vigil's Return by tap")
	_dispose(main)


## (b) the Vigil opened as a route from outside the title (the dev scenario's
## call), then its Return by tap: the title is rebuilt.
static func _vigil_route_form(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, false)
	main._show_vigil()
	await _frames(tree, 2)
	await _tap(tree, host, _button(main._route_screen, Locale.active.t("ui.vigil.return")))
	_no_ring(fails, main, "(b) the route-form Vigil's Return by tap")
	_dispose(main)


## (c) the lantern (Rekindle) to the departure, whose Back returns.
static func _departure_back(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, false)
	await _tap(tree, host, _title(main).lantern)
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	_check(fails, departure != null, "(c) the lantern did not open the departure")
	if departure != null:
		_check(fails, departure.primary() != null and not departure.primary().has_focus(true),
			"(c) the departure shows a touch player a ring on its first answer")
		await _tap(tree, host, departure.find_child("Back", true, false) as Control)
	_no_ring(fails, main, "(c) departure Back by tap")
	_dispose(main)


## (d) Begin Anew over a saved run, answered Stay on the Road.
static func _begin_anew_stay(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	await _tap(tree, host, _title(main)._secondary)
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	if departure != null:
		await _tap(tree, host, departure.primary())
	var sheet: LeadlightConfirm = main._modal as LeadlightConfirm
	_check(fails, sheet != null, "(d) setting out over a saved run did not ask Begin Anew")
	if sheet != null:
		_check(fails, sheet.stay().has_focus() and not sheet.stay().has_focus(true),
			"(d) the confirm's quiet answer is not focused hidden for a touch player")
		await _tap(tree, host, sheet.stay())
	_no_ring(fails, main, "(d) Begin Anew answered Stay on the Road by tap")
	_dispose(main)


## (e) the map's run menu, Return to Title.
static func _run_menu_title(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, false)
	main._new_run()
	if main._route_screen is DepartureScreen:
		var offer: Dictionary = main.game.run.quest_scratch["lamplighterOffer"]
		main._on_lamplighter_confirmed(str(offer["boons"][0]), main.game.run.art)
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	await _frames(tree, 2)
	main._show_run_menu()
	await _frames(tree, 2)
	await _tap(tree, host, _button(main._modal, Locale.active.t("ui.menu.returnTitle")))
	_no_ring(fails, main, "(e) the run menu's Return to Title by tap")
	_dispose(main)


## (g) Settings, How to Play and Credits, each opened and closed by tap.
static func _rooms_closed_by_tap(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	# How to Play's Fight On waits below the fold for a touch player: its veil.
	# Settings leaves by the seat's Return (docs/design/2026-10-03-title-rooms §2.2).
	var exits: Dictionary = {"settings": "ui.menu.return", "help": "", "credits": "ui.credits.close"}
	for room: String in ["settings", "help", "credits"]:
		var main: Main = await _boot(tree, host, content, true)
		await _tap(tree, host, _word(main, room))
		_check(fails, main._modal != null, "(g) a tap on %s opened nothing" % room)
		if main._modal == null:
			_dispose(main)
			continue
		_check(fails, _shown(main).is_empty(), "(g) %s opened showing focus to a touch player: %s" % [
			room, _shown(main)])
		var key: String = str(exits[room])
		if key.is_empty():
			await _tap_at(tree, host, Vector2(24.0, 24.0))
		else:
			await _tap(tree, host, _button(main._modal, Locale.active.t(key)))
		_check(fails, main._modal == null, "(g) %s did not close by tap" % room)
		_no_ring(fails, main, "(g) %s closed by tap" % room)
		_dispose(main)


## (h) a tap on the lantern's body while the launch rite runs completes it.
static func _rite_tap(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true, true)
	var title: TitleScreen = _title(main)
	_check(fails, title.rite != null and title.rite.is_running(), "(h) the launch rite is not running")
	await _tap(tree, host, title.lantern)
	_check(fails, title.rite == null or title.rite.is_done(), "(h) a tap on the lantern did not complete the rite")
	_no_ring(fails, main, "(h) a tap on the lantern during the rite")
	_dispose(main)


## (i) a bare Shift, and a Cmd-Shift-4 screenshot chord, show nothing.
static func _bare_modifiers(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	await _press(tree, host, _key(KEY_SHIFT, true))
	await _press(tree, host, _key(KEY_SHIFT, false))
	var chord: InputEventKey = _key(KEY_4, true)
	chord.meta_pressed = true
	chord.shift_pressed = true
	await _press(tree, host, chord)
	_no_ring(fails, main, "(i) a bare Shift and a screenshot chord")
	_dispose(main)


## (j) Tab on a cold title shows the lantern's rim and the plaque's hairline,
## and acts on nothing; after a tapped return (focus held hidden) Tab shows it
## in place; a keyboard round trip through Settings comes back still shown.
static func _keyboard_keeps_its_ring(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	var title: TitleScreen = _title(main)
	await _key_tap(tree, host, KEY_TAB)
	_check(fails, title.lantern.has_focus(true) and title._plaque.focused,
		"(j) Tab on the title does not show the lantern's focus and the plaque's hairline")
	await _key_tap(tree, host, KEY_ENTER)
	_check(fails, main.game != null, "(j) Enter on the shown lantern did not take the road")
	_dispose(main)
	main = await _boot(tree, host, content, true)
	await _tap(tree, host, _word(main, "vigil"))
	await _tap(tree, host, _button(main._route_screen, Locale.active.t("ui.vigil.return")))
	title = _title(main)
	await _key_tap(tree, host, KEY_ENTER)
	_check(fails, main._choice_screen == title and title.lantern.has_focus(true)
			and title._plaque.focused,
		"(j) the first key after a tapped return did not just show the lantern's held focus")
	var settings: Control = _word(main, "settings")
	settings.grab_focus()
	await _key_tap(tree, host, KEY_ENTER)
	_check(fails, main._modal is SettingsPanel, "(j) Enter on Settings did not open it")
	await _key_tap(tree, host, KEY_ESCAPE)
	_check(fails, main._modal == null and settings.has_focus(true),
		"(j) a keyboard player's Escape from Settings did not hand the ring back to Settings")
	_dispose(main)


## (k) a player who pressed one key and then plays by touch: Main reads the
## tap as a pointer again, so the title rebuilt after a tapped Vigil return
## shows no ring. Only Main's `_input` sees the tap (the title consumes keys
## alone), so this path fails if Main stops noting input.
static func _key_then_touch(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	await _key_tap(tree, host, KEY_TAB)
	_check(fails, LeadlightFocus.keyed and _title(main).lantern.has_focus(true),
		"(k) Tab did not read as a keyboard and show the lantern's focus")
	await _tap(tree, host, _word(main, "vigil"))
	_check(fails, not LeadlightFocus.keyed, "(k) a tap after a key was still read as a keyboard")
	await _tap(tree, host, _button(main._route_screen, Locale.active.t("ui.vigil.return")))
	_no_ring(fails, main, "(k) a key, then the Vigil and its Return by tap")
	_dispose(main)


## (l) A word's focus comes back from a room as it went in (§6.2 item 4),
## however the room was left: opened by tap and left by Escape, Settings holds
## its focus hidden; opened by the keyboard and left by a tap on Close, it shows
## it again.
static func _thaw_keeps_visibility(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	var settings: Control = _word(main, "settings")
	await _tap(tree, host, settings)
	_check(fails, main._modal is SettingsPanel, "(l) a tap on Settings did not open it")
	await _key_tap(tree, host, KEY_ESCAPE)
	_check(fails, main._modal == null and settings.has_focus() and not settings.has_focus(true),
		"(l) Settings opened by tap and left by Escape came back showing a ring")
	_dispose(main)
	main = await _boot(tree, host, content, true)
	settings = _word(main, "settings")
	await _key_tap(tree, host, KEY_TAB)
	settings.grab_focus()
	await _key_tap(tree, host, KEY_ENTER)
	_check(fails, main._modal is SettingsPanel, "(l) Enter on Settings did not open it")
	await _tap(tree, host, _button(main._modal, Locale.active.t("ui.menu.return")))
	_check(fails, main._modal == null and settings.has_focus(true),
		"(l) Settings opened by the keyboard and closed by a tap lost its ring")
	_dispose(main)


## (f) Settings by tap, the language toggled by tap (the title and the room
## are rebuilt in the other language), then the room's Close by tap. Last: it
## leaves the content hydrated in zh-Hant.
static func _language_toggle_and_return(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content, true)
	await _tap(tree, host, _word(main, "settings"))
	var panel: SettingsPanel = main._modal as SettingsPanel
	if panel == null:
		_check(fails, false, "(f) a tap on Settings opened no panel")
		_dispose(main)
		return
	panel._room.select(&"display")
	await _frames(tree, 2)
	await _tap(tree, host, panel._language_toggle)
	panel = main._modal as SettingsPanel
	_check(fails, panel != null and Locale.active.code == Locale.CODE_ZH_HANT,
		"(f) the language toggle did not reopen Settings in zh-Hant")
	if panel != null:
		_check(fails, _shown(main).is_empty(),
			"(f) the reopened Settings shows focus to a touch player: %s" % [_shown(main)])
		await _tap(tree, host, _button(panel, Locale.active.t("ui.menu.return")))
		_check(fails, main._modal == null, "(f) Settings' Return did not close it")
	_no_ring(fails, main, "(f) Settings, the language toggle and Close, by tap")
	_dispose(main)
	Locale.active.restore_content()
	Locale.active = Locale.new(Locale.CODE_EN)


# ---------------------------------------------------------------- the check

static func _no_ring(fails: Array[String], main: Main, path: String) -> void:
	var title: TitleScreen = _title(main)
	if title == null:
		_check(fails, false, "%s did not land on the title" % path)
		return
	_check(fails, not title.lantern.has_focus(true),
		"%s: the lantern shows its focus ring to a touch player" % path)
	_check(fails, not title._plaque.focused, "%s: the plaque's hairline is lit" % path)
	_check(fails, _shown(main).is_empty(), "%s: focus is shown on %s" % [path, _shown(main)])
	_check(fails, not LeadlightFocus.keyed, "%s: a touch player was read as on a keyboard" % path)


## Every button under Main showing focus.
static func _shown(main: Main) -> Array[String]:
	var out: Array[String] = []
	for node: Node in main.find_children("", "BaseButton", true, false):
		var button: BaseButton = node
		if button.has_focus(true):
			out.append(str(button.get_path()))
	return out


# ---------------------------------------------------------------- the stage

static func _boot(tree: SceneTree, host: SubViewport, content: ContentDB, saved: bool,
		rite: bool = false) -> Main:
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
	if saved:
		var run: RunState = RunState.new_run(content, 65601, "run-focus")
		run.map = WorldMap.benchmark(run).to_dict()
		SaveService.store(run, RUN_PATH)
	host.add_child(main)
	main._title_kindled = not rite
	main._show_title()
	await _frames(tree, 3)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	main.get_parent().remove_child(main)
	main.queue_free()


static func _title(main: Main) -> TitleScreen:
	return main._choice_screen as TitleScreen


static func _word(main: Main, id: String) -> Control:
	var title: TitleScreen = _title(main)
	if title == null or not title._words.has(id):
		return null
	var word: Control = title._words[id]
	return word


static func _button(under: Node, text: String) -> Button:
	if under == null:
		return null
	for node: Node in under.find_children("", "Button", true, false):
		var button: Button = node
		if button.is_visible_in_tree() and button.text.to_lower() == text.to_lower():
			return button
	return null


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame


## A finger down and up on `control`, as the viewport delivers it (the engine
## gives the button hidden focus and presses it), then long enough for the
## answer to land.
static func _tap(tree: SceneTree, host: SubViewport, control: Control) -> void:
	if control == null:
		return
	await _tap_at(tree, host, control.get_global_rect().get_center())


static func _tap_at(tree: SceneTree, host: SubViewport, at: Vector2) -> void:
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
	# A glass answer dips under the finger for a tick before it is acted on.
	await tree.create_timer(LeadlightMotion.TICK + 0.05).timeout
	await _frames(tree, 2)


static func _key(code: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


static func _key_tap(tree: SceneTree, host: SubViewport, code: Key) -> void:
	await _press(tree, host, _key(code, true))
	await _press(tree, host, _key(code, false))


static func _press(tree: SceneTree, host: SubViewport, event: InputEvent) -> void:
	host.push_input(event)
	await _frames(tree, 2)
