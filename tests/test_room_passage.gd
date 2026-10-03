extends RefCounted
## The lantern carries you into a room (docs/design/2026-10-03-title-rooms §2,
## §5, §11.1; #655: "it's currently 0s transit means no good"). Each room the
## title opens is entered through Main's `_on_title_pick` as a tap delivers it,
## in a real tree, with the passage stepped by hand at 60 fps:
##
## - the room is the modal on the tap frame and takes a press on the next; the
##   lantern is at the seat and the room settled at its arrival time;
## - a press on the veil while it arrives lands it and never closes it; after
##   it a tap on the veil closes on release, and a wheel tick or a drag never;
## - a second tap where the first landed, inside 300 ms, acts on nothing and
##   lands the arrival; at 320 ms it acts;
## - on leaving, the modal is gone on the same frame, the title takes a tap on
##   the next, the room is freed by 450 ms; a route reset or another room's
##   word mid-exit frees it at once;
## - Reduce Motion with nothing to copy fades the room over 150 ms; `instant`
##   and the headless renderer land it whole;
## - one `roomOpen` and one `roomClose` a round trip, and no `click`;
## - the language reopen keeps the modal a SettingsPanel with no second sound,
##   and Erase's Cancel and Erase Everything land on the title.
##
## Mutation proof (PR): with the passage's guard removed from `_input`, the
## +120 and +280 ms cases fail; with `depart` freeing the room at once, the
## leaving-room case fails; with the veil closing on press, the veil cases fail.

const SUITE: String = "res://tests/test_room_passage.gd"
const RUN_PATH: String = "user://test_room_passage_run_v2.json"
const VIGIL_PATH: String = "user://test_room_passage_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const STEP: float = 1.0 / 60.0
const VEIL_AT: Vector2 = Vector2(1160.0, 40.0)
## The rooms the title opens over itself, and how long each takes to arrive.
const ROOMS: Dictionary = {"settings": 0.52, "help": 0.52}


class QuietMain extends Main:
	func _ready() -> void:
		pass


## Every cue the rooms ask for, by id (owed cues included).
class SpyBus extends SfxBus:
	var heard: Array[StringName] = []

	func play(id: StringName, gain: float = SOURCE_GAIN) -> void:
		heard.append(id)

	func play_owed(id: StringName, fallback: StringName = &"", gain: float = SOURCE_GAIN) -> void:
		heard.append(id)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("room_passage: %s" % what)


static func run(fails: Array[String]) -> void:
	_arc_is_lowered(fails)
	TreeSuite.spawn(fails, SUITE)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## The lantern is lowered to the seat, not slid: its path dips below the chord.
static func _arc_is_lowered(fails: Array[String]) -> void:
	var home: Rect2 = Rect2(380.0, 423.0, 420.0, 420.0)
	var seat: Rect2 = Rect2(-6.0, 588.0, 220.0, 220.0)
	_check(fails, LeadlightSeat.path(home, seat, 0.0).is_equal_approx(home)
			and LeadlightSeat.path(home, seat, 1.0).is_equal_approx(seat),
		"the lantern's arc does not run from home to the seat")
	var mid: Rect2 = LeadlightSeat.path(home, seat, 0.5)
	var chord: float = lerpf(home.get_center().y, seat.get_center().y, 0.5)
	_check(fails, mid.get_center().y > chord and mid.size.x < home.size.x and mid.size.x > seat.size.x,
		"the lantern is slid along the chord, not lowered to the hand")


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.language = String(Locale.CODE_EN)
	Preferences.active.diagnostics_notice_seen = true
	var content: ContentDB = ContentDB.load_full()
	for room: String in ROOMS:
		await _arrival(fails, tree, host, content, room)
		await _veil(fails, tree, host, content, room)
		for at: float in [0.12, 0.28, 0.32]:
			await _double_tap(fails, tree, host, content, room, at)
		await _leaving(fails, tree, host, content, room)
		await _reduced(fails, tree, host, content, room)
		await _instant(fails, tree, host, content, room)
		await _sound(fails, tree, host, content, room)
	await _settings_paths(fails, tree, host, content)
	Preferences.active = kept


# ---------------------------------------------------------------- the paths

static func _arrival(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	await _tap(tree, host, _word(main, room))
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	_check(fails, modal != null, "%s: no room on the tap frame" % room)
	if modal == null:
		_dispose(main)
		return
	_check(fails, main._passage.arriving() and title.lent(), "%s: the room arrived in one frame" % room)
	# The next frame: its own first control takes a press.
	await _step(tree, main, 1)
	var first: Control = modal.first_focus()
	var pressed: Array[int] = [0]
	if first is BaseButton:
		(first as BaseButton).button_down.connect(func() -> void: pressed[0] += 1)
	await _tap(tree, host, first)
	_check(fails, pressed[0] == 1, "%s: the room's first control took no press on frame 1" % room)
	_dispose(main)
	main = await _boot(tree, host, content)
	title = _title(main)
	await _tap(tree, host, _word(main, room))
	var settle: float = ROOMS[room]
	await _step(tree, main, ceili(settle / STEP) - 2)
	_check(fails, main._passage.arriving(), "%s: the room settled before its time" % room)
	await _step(tree, main, 3)
	_check(fails, not main._passage.arriving(), "%s: the room is not settled at %.2f s" % [room, settle])
	var seat: Dictionary = LeadlightSeat.for_stage(main._shape, Vector2(TreeSuite.STAGE))
	var art: Rect2 = seat["art"]
	var at: Rect2 = Rect2(title.lantern.position, title.lantern.size)
	_check(fails, at.position.distance_to(art.position) < 1.0 and absf(at.size.x - art.size.x) < 1.0,
		"%s: the lantern is not at the seat once the room settles (%s, seat %s)" % [room, at, art])
	_dispose(main)


static func _veil(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	await _tap(tree, host, _word(main, room))
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	var closed: Array[int] = [0]
	modal.closed.connect(func() -> void: closed[0] += 1)
	await _step(tree, main, 4)
	await _press(tree, host, VEIL_AT, true)
	_check(fails, not main._passage.arriving(), "%s: a veil press did not land the arrival" % room)
	await _press(tree, host, VEIL_AT, false)
	_check(fails, closed[0] == 0 and main._modal == modal, "%s: a veil press while arriving closed the room" % room)
	await _wheel(tree, host, VEIL_AT)
	_check(fails, closed[0] == 0, "%s: a wheel tick on the veil closed the room" % room)
	await _press(tree, host, VEIL_AT, true)
	await _drag(tree, host, VEIL_AT, VEIL_AT + Vector2(0.0, 40.0))
	await _press(tree, host, VEIL_AT + Vector2(0.0, 40.0), false)
	_check(fails, closed[0] == 0, "%s: a drag across the veil closed the room" % room)
	await _press(tree, host, VEIL_AT, true)
	_check(fails, closed[0] == 0, "%s: the veil closed on press, not release" % room)
	await _press(tree, host, VEIL_AT, false)
	_check(fails, closed[0] == 1 and main._modal == null, "%s: a tap on the veil did not close the room" % room)
	_dispose(main)


## A second tap where the first landed, `after` seconds later.
static func _double_tap(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String, after: float) -> void:
	var main: Main = await _boot(tree, host, content)
	var word: Control = _word(main, room)
	var point: Vector2 = word.get_global_rect().get_center()
	await _tap_at(tree, host, point)
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	await _step(tree, main, roundi(after / STEP))
	# Whatever of the room stands under the first tap's point counts presses.
	_move(host, point)
	await tree.process_frame
	var under: Control = host.gui_get_hovered_control()
	var presses: Array[int] = [0]
	if under != null:
		under.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				presses[0] += 1)
	var closed: Array[int] = [0]
	modal.closed.connect(func() -> void: closed[0] += 1)
	await _press(tree, host, point, true)
	await _press(tree, host, point, false)
	var swallowed: bool = presses[0] == 0 and closed[0] == 0
	if after < LeadlightPassage.GUARD_TIME:
		_check(fails, swallowed and not main._passage.arriving() and main._modal == modal,
			"%s: a second tap at +%d ms acted (%d presses on %s) or did not land the arrival" % [
				room, roundi(after * 1000.0), presses[0], under])
	else:
		_check(fails, not swallowed, "%s: a tap at +%d ms where the first landed acted on nothing" % [
			room, roundi(after * 1000.0)])
	_dispose(main)


static func _leaving(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	await _tap(tree, host, _word(main, room))
	await _step(tree, main, 40)
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	await _tap(tree, host, modal.seat().word())
	_check(fails, main._modal == null, "%s: Return left a modal behind" % room)
	_check(fails, is_instance_valid(modal) and main._passage.leaving(),
		"%s: the room vanished instead of leaving" % room)
	_check(fails, not title.lent(), "%s: the title is not back on the frame the room left" % room)
	await _step(tree, main, 1)
	# The title takes a tap on the next frame: Settings' word opens it again.
	await _tap(tree, host, _word(main, "settings"))
	_check(fails, main._modal is SettingsPanel and main._modal != modal,
		"%s: a room word tapped mid-exit did not open its room" % room)
	await tree.process_frame
	_check(fails, not is_instance_valid(modal), "%s: a room word tapped mid-exit left the old room" % room)
	await _tap(tree, host, (main._modal as LeadlightRoomHost).seat().word())
	modal = null
	var leaving: Node = _leaving_room(main)
	await _step(tree, main, ceili(0.45 / STEP))
	await tree.process_frame
	_check(fails, leaving == null or not is_instance_valid(leaving), "%s: the room was not freed by 450 ms" % room)
	_check(fails, title.lantern.position.is_equal_approx(title.home_rect().position),
		"%s: the lantern is not home once the room has left" % room)
	await _tap(tree, host, _word(main, room))
	await _step(tree, main, 40)
	await _tap(tree, host, (main._modal as LeadlightRoomHost).seat().word())
	leaving = _leaving_room(main)
	main._clear_route()
	await tree.process_frame
	_check(fails, leaving == null or not is_instance_valid(leaving),
		"%s: a route reset mid-exit did not free the leaving room" % room)
	_dispose(main)


static func _reduced(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	Preferences.active.reduce_motion = true
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	await _tap(tree, host, _word(main, room))
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	await _step(tree, main, 1)
	var alpha: float = modal.modulate.a
	_check(fails, alpha > 0.0 and alpha < 1.0, "%s: Reduce Motion cut the room in (alpha %.2f on frame 1)" % [room, alpha])
	await _step(tree, main, ceili(0.16 / STEP))
	_check(fails, not main._passage.arriving() and is_equal_approx(modal.modulate.a, 1.0),
		"%s: Reduce Motion's fade is not done by 160 ms" % room)
	var art: Rect2 = LeadlightSeat.for_stage(main._shape, Vector2(TreeSuite.STAGE))["art"]
	_check(fails, title.lantern.position.distance_to(art.position) < 1.0,
		"%s: under Reduce Motion the lantern travelled" % room)
	_dispose(main)
	Preferences.active.reduce_motion = false


static func _instant(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	for how: String in ["instant", "headless"]:
		var main: Main = await _boot(tree, host, content)
		if how == "instant":
			main._transitions.instant = true
		else:
			main._passage.stepped = false
		await _tap(tree, host, _word(main, room))
		var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
		_check(fails, modal != null and not main._passage.arriving() and is_equal_approx(modal.modulate.a, 1.0)
				and is_equal_approx(modal.veil().modulate.a, 1.0),
			"%s: %s did not land the room whole" % [room, how])
		_dispose(main)


static func _sound(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	var spy: SpyBus = main._sfx_bus as SpyBus
	spy.heard.clear()
	await _tap(tree, host, _word(main, room))
	await _step(tree, main, 40)
	await _tap(tree, host, (main._modal as LeadlightRoomHost).seat().word())
	await _step(tree, main, 30)
	_check(fails, spy.heard.count(&"roomOpen") == 1 and spy.heard.count(&"roomClose") == 1
			and not spy.heard.has(&"click"),
		"%s: a round trip was not one roomOpen and one roomClose with no click: %s" % [room, spy.heard])
	_dispose(main)


## Settings' own paths: the language reopen, and Erase answered both ways.
static func _settings_paths(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var spy: SpyBus = main._sfx_bus as SpyBus
	await _tap(tree, host, _word(main, "settings"))
	await _step(tree, main, 40)
	var panel: SettingsPanel = main._modal as SettingsPanel
	panel._room.select(&"display")
	await tree.process_frame
	spy.heard.clear()
	await _tap(tree, host, panel._language_toggle)
	_check(fails, main._modal is SettingsPanel and main._modal != panel,
		"the language reopen did not leave a SettingsPanel as the modal")
	_check(fails, not spy.heard.has(&"roomOpen"), "the language reopen played the room's sound again: %s" % [spy.heard])
	await _step(tree, main, ceili(0.16 / STEP))
	await tree.process_frame
	_check(fails, not is_instance_valid(panel), "the language reopen's old room lingered past 160 ms")
	_dispose(main)
	Locale.active.restore_content()
	Locale.active = Locale.new(Locale.CODE_EN)
	Preferences.active.language = String(Locale.CODE_EN)
	for answer: String in ["no", "yes"]:
		main = await _boot(tree, host, content)
		var title: TitleScreen = _title(main)
		await _tap(tree, host, _word(main, "settings"))
		await _step(tree, main, 40)
		panel = main._modal as SettingsPanel
		panel._room.select(&"ledger")
		await tree.process_frame
		await _tap(tree, host, _labelled(panel, Locale.active.t("ui.settings.eraseAll")))
		var sheet: LeadlightConfirm = main._modal as LeadlightConfirm
		_check(fails, sheet != null and title.lent(), "Erase did not ask over the seated lantern")
		if sheet == null:
			_dispose(main)
			continue
		var answer_button: Control = sheet.action()
		if answer == "no":
			answer_button = sheet.stay()
		await _tap(tree, host, answer_button)
		await _step(tree, main, 40)
		if answer == "no":
			_check(fails, main._choice_screen == title and not title.lent() and main._modal == null,
				"Erase's Cancel did not land on the same title")
		else:
			_check(fails, main._choice_screen is TitleScreen and main._choice_screen != title,
				"Erase Everything did not rebuild a fresh title")
		_dispose(main)


# ---------------------------------------------------------------- the stage

static func _boot(tree: SceneTree, host: SubViewport, content: ContentDB) -> Main:
	LeadlightFocus.keyed = false
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = QuietMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._transitions = TransitionLayer.new()
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SpyBus.new()
	main.add_child(main._sfx_bus)
	main._vigil.scenes_seen.append("opening")
	var run: RunState = RunState.new_run(content, 65701, "run-passage")
	run.map = WorldMap.benchmark(run).to_dict()
	SaveService.store(run, RUN_PATH)
	host.add_child(main)
	main._title_kindled = true
	# Stepped by hand: the suite owns the passage's clock.
	main._passage_node().stepped = true
	main._show_title()
	main._passage.set_process(false)
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
	return title.word(id) if title != null else null


static func _labelled(under: Node, text: String) -> Button:
	for node: Node in under.find_children("", "Button", true, false):
		var button: Button = node
		if button.is_visible_in_tree() and button.text.to_lower() == text.to_lower():
			return button
	return null


## The room the passage is carrying out, if any.
static func _leaving_room(main: Main) -> Node:
	for node: Node in main.get_children():
		if node is LeadlightRoomHost and node != main._modal:
			return node
	return null


## `count` frames at 60 fps on the passage's clock.
static func _step(tree: SceneTree, main: Main, count: int) -> void:
	for _i: int in range(maxi(count, 0)):
		main._passage.advance(STEP)
		await tree.process_frame


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame


static func _tap(tree: SceneTree, host: SubViewport, control: Control) -> void:
	if control == null:
		return
	await _tap_at(tree, host, control.get_global_rect().get_center())


## A finger down and up in one frame, as a quick tap arrives.
static func _tap_at(tree: SceneTree, host: SubViewport, at: Vector2) -> void:
	_move(host, at)
	for pressed: bool in [true, false]:
		host.push_input(_button(at, pressed, MOUSE_BUTTON_LEFT), true)
	await tree.process_frame
	# A glass answer dips under the finger for a tick before it is acted on.
	await tree.create_timer(LeadlightMotion.TICK + 0.05).timeout


static func _press(tree: SceneTree, host: SubViewport, at: Vector2, pressed: bool) -> void:
	_move(host, at)
	host.push_input(_button(at, pressed, MOUSE_BUTTON_LEFT), true)
	await tree.process_frame


static func _wheel(tree: SceneTree, host: SubViewport, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		host.push_input(_button(at, pressed, MOUSE_BUTTON_WHEEL_DOWN), true)
	await tree.process_frame


static func _drag(tree: SceneTree, host: SubViewport, from: Vector2, to: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = to
	motion.global_position = to
	motion.relative = to - from
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	host.push_input(motion, true)
	await tree.process_frame


static func _move(host: SubViewport, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	host.push_input(motion, true)


static func _button(at: Vector2, pressed: bool, index: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = index
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else 0) if pressed else 0
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event
