extends RefCounted
## The setting-out as one departure (build 18 play report: "The setup page
## please be immersive", "seems repeated the choices"). One DepartureScreen
## carries Embark's choice, the Lamplighter's gift and the lantern art as beats
## in one place, never a screen swap; the gift's answer flows into the
## opening or the departure staging; "set out as before" carries this
## session's class, vow and art; and every beat fits the stage at every shape
## in both languages.

const RUN_PATH: String = "user://test_departure_run_v2.json"
const VIGIL_PATH: String = "user://test_departure_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("departure: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_one_place_from_embark_to_the_road(fails, content)
	_set_out_as_before(fails, content)
	_beats_fit_the_stage(fails, content)
	_escape_on_the_first_beat(fails, content)
	_no_back_once_answered(fails, content)
	_title_forgets_setting_out(fails, content)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## A returning player with the Lamplighter met and a vow to choose: Embark,
## the gift and the art are beats of the one screen, and the last answer
## sets out on the road (the departure staging), not straight to the map.
static func _one_place_from_embark_to_the_road(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	main._vigil.unlocks.append("lamplighter")
	main._vigil.vow_unlocked = 1
	main._show_title()
	main._on_title_choice("begin", null)
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	_check(fails, departure != null and departure.beat == DepartureScreen.BEAT_A,
		"a returning profile did not open the departure at Embark")
	if departure == null:
		_dispose(main)
		return
	departure.primary().pressed.emit()
	_check(fails, main.game != null and main.game.run.pending_lamplighter,
		"setting out did not create the run with the Lamplighter owed")
	_check(fails, main._route_screen == departure and departure.beat == DepartureScreen.BEAT_B,
		"the gift did not rise in the same place (the screen was swapped)")
	departure.primary().pressed.emit()
	_check(fails, departure.beat == DepartureScreen.BEAT_C, "a chosen boon did not move on to the art")
	departure.primary().pressed.emit()
	_check(fails, not main.game.run.pending_lamplighter and main.game.run.art != &"",
		"lighting the way did not take the gift and the art")
	_check(fails, main._route_screen is DepartureStaging or main._map_screen != null,
		"the departure's last answer did not set out on the road")
	_check(fails, main._last_setup.size() == 3, "the session did not remember this setting-out")
	_dispose(main)


## Later the same session: Embark offers setting out as before, which carries
## the class and vow, and the art once the gift is chosen.
static func _set_out_as_before(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	main._vigil.unlocks.append("lamplighter")
	main._vigil.vow_unlocked = 1
	main._last_setup = {"aspect": 0, "vow": 1, "art": &"beacon"}
	main._show_embark()
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	var same: LeadlightPane = departure.find_child("SetOutAsBefore", true, false) as LeadlightPane \
		if departure != null else null
	_check(fails, same != null, "a second setting-out this session offers no 'as before'")
	if same == null:
		_dispose(main)
		return
	same.pressed.emit()
	_check(fails, main.game != null and main.game.run.vow == 1, "'as before' did not carry the vow")
	_check(fails, departure.beat == DepartureScreen.BEAT_B, "'as before' skipped the gift")
	departure.primary().pressed.emit()
	_check(fails, main.game.run.art == &"beacon" and not main.game.run.pending_lamplighter,
		"'as before' did not carry the art once the gift was chosen")
	_dispose(main)


## Every beat, in the busiest case (both classes, three vows, a saved run,
## 'as before'), stays on the stage and clear of the lantern's glass.
static func _beats_fit_the_stage(fails: Array[String], content: ContentDB) -> void:
	var previous: Locale = Locale.active
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		Locale.active.hydrate_content(content)
		for shape: StringName in StageShape.REFERENCES:
			for beat: String in ["embark", "gift", "art"]:
				var screen: DepartureScreen = DepartureScreen.new(shape)
				if beat == "embark":
					screen.show_embark(content.aspects, content.vows, true, 3, true, 0, 1,
						{"aspect": 0, "vow": 1, "art": "flare"}, true)
				else:
					var aspect: Dictionary = content.aspects[0]
					screen.show_gift(aspect, content.boons, content.arts, content.boons.keys().slice(0, 3),
						StringName(str(content.arts.keys()[0])))
					if beat == "art":
						screen._boon = str(screen._boon_ids[0])
						screen._enter(DepartureScreen.BEAT_C, &"urgent")
				screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
				screen.size = Vector2(StageShape.REFERENCES[shape])
				screen._layout()
				var column: Rect2 = Rect2(screen._column.position, Vector2(screen._column.size.x, screen.beat_height()))
				var art: Rect2 = Rect2(screen.lantern.position, screen.lantern.size)
				var glass: Rect2 = Rect2(art.position + art.size * Vector2(0.30, 0.42), art.size * Vector2(0.40, 0.40))
				_check(fails, Rect2(Vector2.ZERO, screen.size).encloses(column),
					"%s %s %s: the beat runs off the stage (%s)" % [code, shape, beat, column])
				_check(fails, not column.intersects(glass),
					"%s %s %s: the beat lands on the lantern's glass" % [code, shape, beat])
				screen.free()
	Locale.active = previous


## Escape on the first beat goes back to the title (desktop and keyboard; Back
## is on screen); the gift and the art have no Back, so it does nothing there.
static func _escape_on_the_first_beat(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _main(content)
	main._vigil.scenes_seen.append("opening")
	main._vigil.unlocks.append("lamplighter")
	main._show_title()
	main._on_title_choice("begin", null)
	var departure: DepartureScreen = main._route_screen as DepartureScreen
	_check(fails, departure != null and departure.beat == DepartureScreen.BEAT_A,
		"Rekindle did not open the departure at its first beat")
	if departure == null:
		_dispose(main)
		return
	departure._unhandled_input(_cancel())
	_check(fails, main._choice_screen is TitleScreen and main._route_screen == null,
		"Escape on the departure's first beat did not return to the title")
	main._on_title_choice("begin", null)
	departure = main._route_screen as DepartureScreen
	if departure != null:
		departure.primary().pressed.emit()
		_check(fails, departure.beat == DepartureScreen.BEAT_B, "setting out did not reach the gift")
		var backs: Array[int] = [0]
		departure.back_requested.connect(func() -> void: backs[0] += 1)
		departure._unhandled_input(_cancel())
		_check(fails, backs[0] == 0 and main._route_screen == departure,
			"Escape on the gift went back, which has no Back")
	_dispose(main)


## Once the first beat is answered the road is being set out on (Main floods
## from the lantern for 0.48 s, then routes the run): neither Escape nor Back
## goes back, which would show the title only for the run to be routed over it,
## and a second Set Out sets out nothing.
static func _no_back_once_answered(fails: Array[String], content: ContentDB) -> void:
	var screen: DepartureScreen = DepartureScreen.new()
	screen.show_embark(content.aspects, content.vows, false, 0, false, 0, 0, {}, false)
	var backs: Array[int] = [0]
	var set_outs: Array[int] = [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)
	screen.embark_chosen.connect(func(_aspect: int, _vow: int) -> void: set_outs[0] += 1)
	screen.primary().pressed.emit()
	_check(fails, set_outs[0] == 1 and screen.beat == DepartureScreen.BEAT_A,
		"Set Out did not answer the first beat")
	screen._unhandled_input(_cancel())
	(screen.find_child("Back", true, false) as BaseButton).pressed.emit()
	_check(fails, backs[0] == 0, "Escape or Back after Set Out still goes back, into the flood")
	screen.primary().pressed.emit()
	_check(fails, set_outs[0] == 1, "a second Set Out set out again")
	screen.free()


## A departure left before its gift is answered must not leave the next title
## owing the road its opening.
static func _title_forgets_setting_out(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _main(content)
	main._setting_out = true
	main._show_title()
	_check(fails, not main._setting_out, "the title kept a stale setting-out from a departure")
	_dispose(main)


static func _cancel() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


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
