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
##   and Erase's Cancel and Erase Everything land on the title;
## - the word in flight never runs through the room's lit content, nor on its
##   way back through the title's returning furniture; leaving answers on the
##   frame Return is tapped;
## - Enter lands an arrival and is spent on it; the title's idle ember is held
##   while it is lent and re-armed on its return; a lent title takes no key of
##   its own; the word a room was left back to glows (the afterglow);
## - under Reduce Motion's cross-fade the lantern comes in over its second half;
## - the run menu folds away under a room it opens, and a room in a run keeps
##   its seat without a lantern's hit through a change of shape.
##
## Mutation proof (PR): with the passage's guard removed from `_input`, the
## +120 and +280 ms cases fail; with `depart` freeing the room at once, the
## leaving-room case fails; with the veil closing on press, the veil cases fail.
## The later cases' proofs: docs/design/2026-10-03-title-rooms/evidence/.

const SUITE: String = "res://tests/test_room_passage.gd"
const RUN_PATH: String = "user://test_room_passage_run_v2.json"
const VIGIL_PATH: String = "user://test_room_passage_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const STEP: float = 1.0 / 60.0
const VEIL_AT: Vector2 = Vector2(1160.0, 40.0)
## The rooms the title opens over itself, and how long each takes to arrive.
const ROOMS: Dictionary = {"settings": 0.52, "help": 0.52, "credits": 0.60}
## A place (Credits) has no veil to tap: its bare road never closes it.
const PLACES: Array[String] = ["credits"]


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
	_flight_geometry(fails)
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


## Where a word in flight leaves a box it crosses, and the curve's inverse that
## turns it into a time.
static func _flight_geometry(fails: Array[String]) -> void:
	# Straight up through a box 40 tall, grown by the word's half height 5.
	var g: float = LeadlightGhostWord.leaves_at(Vector2(0.0, 100.0), Vector2.ZERO, Vector2(10.0, 5.0),
		Rect2(-20.0, 40.0, 40.0, 20.0))
	_check(fails, is_equal_approx(g, 0.65), "a word leaving a box it crosses is placed at %.3f, not 0.65" % g)
	_check(fails, LeadlightGhostWord.leaves_at(Vector2(0.0, 100.0), Vector2.ZERO, Vector2(10.0, 5.0),
			Rect2(50.0, 0.0, 10.0, 10.0)) < 0.0, "a word is held for a box it never crosses")
	for x: float in [0.1, 0.5, 0.9]:
		var back: float = LeadlightMotion.inverse_on(LeadlightMotion.ease_on(x, LeadlightMotion.REVEAL),
			LeadlightMotion.REVEAL)
		_check(fails, absf(back - x) < 0.001, "the curve's inverse misses %.2f (%.4f)" % [x, back])


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
		await _reduced_lantern(fails, tree, host, content, room)
		await _instant(fails, tree, host, content, room)
		await _sound(fails, tree, host, content, room)
		await _word_crosses_nothing_lit(fails, tree, host, content, room)
		await _enter_lands(fails, tree, host, content, room)
	await _lent_title(fails, tree, host, content)
	await _settings_paths(fails, tree, host, content)
	await _in_a_run(fails, tree, host, content)
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
	if PLACES.has(room):
		_check(fails, closed[0] == 0 and main._modal == modal, "%s: a tap on the bare road closed the place" % room)
	else:
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
	_check(fails, main._passage.carrying(), "%s: a leaving room is not carried by the passage" % room)
	await _step(tree, main, ceili(0.45 / STEP))
	await tree.process_frame
	_check(fails, leaving == null or not is_instance_valid(leaving), "%s: the room was not freed by 450 ms" % room)
	_check(fails, not main._passage.carrying(), "%s: the passage still carries a room that has left" % room)
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
		_check(fails, is_zero_approx(_word(main, room).modulate.a),
			"%s: %s left the opening word on the road beside its room" % [room, how])
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


## X1: How to Play and Settings from the run menu over the map: the same rooms,
## the seat's word alone (no title lantern), one cue each way and no click,
## the map kept beneath.
static func _in_a_run(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	for room: StringName in [&"help", &"settings"]:
		var main: Main = await _boot(tree, host, content)
		main._forced_seed = 65702
		main._new_run()
		if main._route_screen is DepartureScreen:
			var offer: Dictionary = main.game.run.quest_scratch["lamplighterOffer"]
			main._on_lamplighter_confirmed(str(offer["boons"][0]), main.game.run.art)
		if main._map_screen == null or main._route_screen is DepartureStaging:
			main._show_map()
		await tree.process_frame
		var map: Control = main._map_screen
		main._show_run_menu()
		var spy: SpyBus = main._sfx_bus as SpyBus
		spy.heard.clear()
		var menu: RunMenuPanel = main._modal as RunMenuPanel
		if menu == null:
			_check(fails, false, "X1 %s: the run menu did not open" % room)
			_dispose(main)
			continue
		menu._request(room)
		var opened: LeadlightRoomHost = main._modal as LeadlightRoomHost
		_check(fails, opened != null and main._passage.lent_title() == null
				and not opened.seat().lantern_hit().visible,
			"X1 %s: the room in a run is not the room with the word alone" % room)
		await tree.process_frame
		_check(fails, is_instance_valid(menu) and menu.is_inside_tree() and menu.modulate.a > 0.5,
			"X1 %s: the run menu vanished on the tap instead of folding under the room" % room)
		if opened != null:
			# A change of shape rebuilds the room and its seat: still no lantern.
			opened.set_shape(&"phone-landscape")
			opened.set_shape(main._shape)
			_check(fails, not opened.seat().lantern_hit().visible,
				"X1 %s: a rebuilt seat in a run took an invisible lantern's tap back" % room)
		await _step(tree, main, 40)
		await tree.process_frame
		_check(fails, not is_instance_valid(menu), "X1 %s: the run menu outlived its fold" % room)
		if opened != null:
			opened.leave()
		await _step(tree, main, 40)
		_check(fails, main._modal == null and main._map_screen == map,
			"X1 %s: leaving did not return to the map as it was" % room)
		_check(fails, spy.heard.count(&"roomOpen") == 1 and spy.heard.count(&"roomClose") == 1
				and not spy.heard.has(&"click"),
			"X1 %s: the run menu's room was not one roomOpen and one roomClose: %s" % [room, spy.heard])
		_dispose(main)


## The word in flight never runs through what is lit: on arrival the room's
## content it crosses waits for it, and on leaving it sets off once the content
## behind it is dark and lands before the title's furniture is back. Leaving
## answers on the frame Return is tapped (EXIT's slow start held the room whole
## for eight frames).
static func _word_crosses_nothing_lit(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	var word: Control = _word(main, room)
	await _tap(tree, host, word)
	var modal: LeadlightRoomHost = main._modal as LeadlightRoomHost
	var settle: float = ROOMS[room]
	var furniture: Array = _title(main).furniture(word, true)
	for i: int in range(ceili(settle / STEP)):
		# The word lifts off through its neighbours as they go: from its third
		# frame nothing it crosses is lit.
		_crossing(fails, main, modal, room, "arriving", furniture if i >= 2 else [])
		await _step(tree, main, 1)
	await _step(tree, main, 6)
	await _tap(tree, host, modal.seat().word())
	await _step(tree, main, 2)
	var answered: float = modal.sheet().reach if modal.sheet() != null else 1.0
	if modal is CreditsScreen:
		for item: Node in (modal as CreditsScreen).roll().get_children():
			if item is Control:
				answered = minf(answered, (item as Control).modulate.a)
	_check(fails, answered < 0.8, "%s: two frames after Return the room stands whole (%.2f)" % [room, answered])
	for _i: int in range(30):
		_crossing(fails, main, modal, room, "leaving", furniture)
		await _step(tree, main, 1)
	_dispose(main)


## A lit thing (alpha over 0.2) the word in flight stands on, if any. The room
## is checked while it stands. A departure frees it, so it is passed untyped:
## a freed room handed to a typed parameter is a script error in the caller.
## The title's furniture is checked for as long as the word is in the air.
static func _crossing(fails: Array[String], main: Main, room_v: Variant, room: String,
		phase: String, furniture: Array) -> void:
	var flight: Rect2 = Rect2()
	for node: Node in main._passage.find_children("GhostWord", "", false, false):
		for label: Node in node.get_children():
			if label is Label and (label as Label).modulate.a > 0.05:
				var drawn: Rect2 = (label as Label).get_global_rect()
				flight = drawn if not flight.has_area() else flight.merge(drawn)
	if not flight.has_area():
		return
	var lit: Array[Control] = []
	var view: Rect2 = Rect2(Vector2(-1.0e6, -1.0e6), Vector2(2.0e6, 2.0e6))
	if is_instance_valid(room_v) and room_v is CreditsScreen:
		var credits: CreditsScreen = room_v
		view = credits.scroll().get_global_rect()
		for item: Node in credits.roll().get_children():
			if item is Control and item != credits.roll().head_gap and item != credits.roll().heading_node:
				lit.append(item as Control)
	elif is_instance_valid(room_v) and room_v is LeadlightRoomHost:
		var modal: LeadlightRoomHost = room_v
		lit.assign(modal.reveal_groups())
	for item: Control in lit:
		var rect: Rect2 = item.get_global_rect().intersection(view)
		if item.modulate.a > 0.2 and rect.grow(-2.0).intersects(flight):
			fails.append("room_passage: %s %s: the word in flight runs through %s, lit at %.2f" % [
				room, phase, item.name, item.modulate.a])
			return
	for item_v: Variant in furniture:
		if not is_instance_valid(item_v) or not (item_v is Control):
			continue
		var item: Control = item_v
		if item.visible and item.modulate.a > 0.2 \
				and item.get_global_rect().grow(-2.0).intersects(flight):
			fails.append("room_passage: %s %s: the word in flight runs through the title's %s, lit at %.2f" % [
				room, phase, item.get("text") if "text" in item else item.name, item.modulate.a])
			return


## Enter (or Space) lands an arrival and is spent on it: the room's focused
## first control is not pressed by it.
static func _enter_lands(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	var main: Main = await _boot(tree, host, content)
	await _tap(tree, host, _word(main, room))
	await _step(tree, main, 2)
	var first: BaseButton = (main._modal as LeadlightRoomHost).first_focus() as BaseButton
	var pressed: Array[int] = [0]
	if first != null:
		first.grab_focus(true)
		first.pressed.connect(func() -> void: pressed[0] += 1)
	var enter: InputEventAction = InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	host.push_input(enter, true)
	await tree.process_frame
	_check(fails, not main._passage.arriving(), "%s: Enter did not land the arrival" % room)
	_check(fails, pressed[0] == 0, "%s: the Enter that landed the arrival also pressed %s" % [room, first])
	_dispose(main)


## A title lent to a room: its idle ember is held (no ember flies to the plaque
## a second after the room closes) and re-armed on its return, it takes no key
## of its own (a key would skip a rite still running), and the word the room
## was left back to glows a moment.
static func _lent_title(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB) -> void:
	var main: Main = await _boot(tree, host, content)
	var title: TitleScreen = _title(main)
	await _tap(tree, host, _word(main, "settings"))
	_check(fails, not title._beckon._armed, "the idle ember still counts while a room is open")
	await _step(tree, main, 40)
	await _tap(tree, host, (main._modal as LeadlightRoomHost).seat().word())
	await _step(tree, main, ceili((LeadlightPassage.AFTERGLOW_FROM + 0.02) / STEP))
	var word: LeadlightWord = _word(main, "settings") as LeadlightWord
	_check(fails, word.glow > 0.5, "the word the room was left back to does not glow (%.2f)" % word.glow)
	await _step(tree, main, 10)
	_check(fails, title._beckon._armed and not title.lent(), "the idle ember is not re-armed on the title's return")
	_dispose(main)
	main = await _boot(tree, host, content, false)
	title = _title(main)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	title.lend()
	title._unhandled_input(key)
	_check(fails, title.rite != null and title.rite.is_running(), "a lent title took a key of its own")
	title.reclaim()
	title._unhandled_input(key)
	_check(fails, title.rite == null or not title.rite.is_running(),
		"the rite under the title ignores a key even when it is not lent (the case proves nothing)")
	_dispose(main)


## Under Reduce Motion a room lands whole beneath the cross-fade of the frame
## before, which still shows the lantern where it was: the lantern in its new
## place comes in from the fade's middle (75 to 225 ms), each way.
static func _reduced_lantern(fails: Array[String], tree: SceneTree, host: SubViewport,
		content: ContentDB, room: String) -> void:
	Preferences.active.reduce_motion = true
	var main: Main = await _boot(tree, host, content)
	var lantern: LeadlightLantern = _title(main).lantern
	# A frame to copy, as a renderer gives one.
	main._transitions.snapshot_source = func() -> Texture2D:
		return ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	await _tap(tree, host, _word(main, room))
	_check(fails, not main._passage.arriving() and lantern.presence < 0.05,
		"%s: under the cross-fade the seated lantern shows at once (%.2f)" % [room, lantern.presence])
	await _step(tree, main, 5)
	_check(fails, lantern.presence < 0.5, "%s: the seated lantern came in before the fade's middle" % room)
	await _step(tree, main, 10)
	_check(fails, is_equal_approx(lantern.presence, 1.0), "%s: the seated lantern is not whole by 250 ms" % room)
	await _tap(tree, host, (main._modal as LeadlightRoomHost).seat().word())
	_check(fails, lantern.presence < 0.05 and lantern.position.is_equal_approx(_title(main).home_rect().position),
		"%s: under the cross-fade the lantern shows home at once (%.2f)" % [room, lantern.presence])
	await _step(tree, main, 15)
	_check(fails, is_equal_approx(lantern.presence, 1.0), "%s: the lantern is not whole at home by 250 ms" % room)
	_dispose(main)
	Preferences.active.reduce_motion = false


# ---------------------------------------------------------------- the stage

## `kindled` false: the title's launch rite is running.
static func _boot(tree: SceneTree, host: SubViewport, content: ContentDB, kindled: bool = true) -> Main:
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
	main._title_kindled = kindled
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
