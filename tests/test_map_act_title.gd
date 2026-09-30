extends RefCounted
## #578: the map title bar names the act whose geometry is drawn.
##
## `--map --act=N` dresses the scenery in another act (`Main._forced_act_index`,
## already an act INDEX by the time it reaches the screen) while the run stays in
## its own act. The title bar is bound to the same act as the scenery, so it must
## never fall back to the run's act, including when a shape re-pick re-seats the
## screen through `refresh`.

const RUN_PATH: String = "user://test_map_act_title_run_v2.json"
const VIGIL_PATH: String = "user://test_map_act_title_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("map_act_title: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_check(fails, content.acts.size() >= 2, "the pack carries at least two acts")
	if content.acts.size() < 2:
		return
	_check(fails, _region_of(content, 0) != _region_of(content, 1),
		"the two acts have different names, so the title can tell them apart")
	_unforced_title_names_the_run_act(fails, content)
	_forced_title_names_the_drawn_act(fails, content)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## The region clause of an act's title bar, upper-cased the way the screen does.
static func _region_of(content: ContentDB, act_index: int) -> String:
	return str(content.acts[act_index].get("name", "")).to_upper()


static func _unforced_title_names_the_run_act(fails: Array[String],
		content: ContentDB) -> void:
	var main: Main = _map_main(content, -1)
	var title: String = main._map_screen._title_label.text
	_check(fails, title.contains(_region_of(content, main.game.run.act)),
		"without --act the title names the run's own act, got '%s'" % title)
	_dispose(main)


static func _forced_title_names_the_drawn_act(fails: Array[String],
		content: ContentDB) -> void:
	var forced: int = 1
	var main: Main = _map_main(content, forced)
	var screen: WorldMapScreen = main._map_screen
	_check(fails, main.game.run.act != forced,
		"the run stays in its own act while the scenery is dressed")
	_check(fails, screen._map_scene.get_act() == forced,
		"the forced act's scenery is drawn")
	var title: String = screen._title_label.text
	_check(fails, title.contains(_region_of(content, forced)),
		"the title names the drawn act, got '%s'" % title)
	_check(fails, not title.contains(_region_of(content, main.game.run.act)),
		"the title does not name the run's act, got '%s'" % title)
	# A shape re-pick re-seats the screen through `refresh`; the act must hold.
	for shape: StringName in StageShape.REFERENCES:
		if shape == screen.shape:
			continue
		screen.set_shape(shape)
		title = screen._title_label.text
		_check(fails, screen._map_scene.get_act() == forced
				and title.contains(_region_of(content, forced)),
			"after a re-pick to %s the title and scenery still name act %d, got '%s'"
				% [shape, forced, title])
	_dispose(main)


## A `Main` standing on the map of a fresh run, with `forced_act_index` set the way
## `--map --act=N` sets it (`-1` is the flag's absence).
static func _map_main(content: ContentDB, forced_act_index: int) -> Main:
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
	main._forced_seed = 57800
	main._forced_act_index = forced_act_index
	main._vigil.scenes_seen.append("opening")
	main._new_run()
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
