extends RefCounted
## The lantern is the button, and its words are part of it (build 18 play
## report: "I keep tapping the text above but doesn't work"). A real tap,
## hit-tested by the viewport, at the plaque's name, at its sub-line or at the
## flame takes the same route. The first title of a session beckons; an idle
## title raises one ember to the plaque.

const RUN_PATH: String = "user://test_title_reach_run_v2.json"
const VIGIL_PATH: String = "user://test_title_reach_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("title_reach: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var flame: String = _tap_route(fails, content, &"flame")
	_check(fails, not flame.is_empty(), "a tap at the flame took no route")
	for where: StringName in [&"plaque", &"sub", &"gap"]:
		var route: String = _tap_route(fails, content, where)
		_check(fails, route == flame,
			"a tap at the %s took %s, the flame takes %s" % [where, route, flame])
	_beckons(fails)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## Back to the Road from a fresh Main with a saved run: tap `where` and name
## the route Main lands on. The runner works before the tree runs (no viewport
## input), so the tap is picked as Godot's GUI picks it — the last-drawn
## visible control containing the point that does not ignore the mouse — and
## pressed if it is a button. A plaque of mouse-ignoring labels over the title
## picks the title itself, which is how the plaque's taps used to die.
static func _tap_route(fails: Array[String], content: ContentDB, where: StringName) -> String:
	var main: Main = _main(content)
	var seeded: RunState = RunState.new_run(content, 65001, "run-reach")
	seeded.map = WorldMap.benchmark(seeded).to_dict()
	_check(fails, SaveService.store(seeded, RUN_PATH), "could not seed the saved run")
	main._title_kindled = true
	main._show_title()
	var title: TitleScreen = main._choice_screen as TitleScreen
	if title == null or title.primary_id() != "continue":
		_check(fails, false, "the saved run did not put Back to the Road on the lantern")
		_dispose(main)
		return ""
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2.ZERO
	title.size = Vector2(StageShape.REFERENCES[&"pad-landscape"])
	title._layout()
	var at: Vector2 = _point(title, where)
	_check(fails, Rect2(Vector2.ZERO, title.size).has_point(at), "%s is off the stage" % where)
	var ids: Array[String] = []
	title.chosen.connect(func(id: String) -> void: ids.append(id))
	var hit: Control = _pick(title, at, Vector2.ZERO)
	if hit is BaseButton:
		(hit as BaseButton).pressed.emit()
	_check(fails, ids == ["continue"], "a tap at the %s picked %s and chose %s" % [
		where, hit.name if hit != null else "nothing", ids])
	var route: String = ""
	var landed: Control = main._map_screen if main._map_screen != null else main._route_screen
	if landed != null:
		var script: Script = landed.get_script()
		if script != null:
			route = script.resource_path.get_file()
	_dispose(main)
	return route


## Godot's GUI pick, for a tree that is not running: children last-drawn
## first, depth first; a visible control that does not ignore the mouse and
## holds the point is the hit.
static func _pick(node: Control, at: Vector2, origin: Vector2) -> Control:
	if not node.visible:
		return null
	var here: Vector2 = origin + node.position
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child: Control = node.get_child(i) as Control
		if child == null:
			continue
		var found: Control = _pick(child, at, here)
		if found != null:
			return found
	if node.mouse_filter != Control.MOUSE_FILTER_IGNORE and Rect2(here, node.size).has_point(at):
		return node
	return null


static func _point(title: TitleScreen, where: StringName) -> Vector2:
	var plaque: LeadlightPlaque = title._plaque
	var name_rect: Rect2 = Rect2(plaque.position + plaque.title_label().position, plaque.title_label().size)
	match where:
		&"plaque":
			return name_rect.get_center()
		&"sub":
			var row: Control = plaque._sub.get_parent() as Control
			return plaque.position + row.position + plaque._sub.position + plaque._sub.size * 0.5
		&"gap":
			# Between the plaque and the lantern's hook.
			return Vector2(name_rect.get_center().x,
				(plaque.position.y + plaque.size.y + title.lantern.position.y) * 0.5)
	return title.lantern.position + title.lantern.glass_centre()


static func _beckons(fails: Array[String]) -> void:
	var first: TitleScreen = TitleScreen.new({"shape": "pad-landscape", "beckon": true,
		"choices": [{"id": "begin", "label": "Rekindle"}]})
	first.kindle_now()
	var beckon: TitleBeckon = first._beckon
	_check(fails, beckon.beckoning(), "the first title of a session does not beckon")
	beckon._process(TitleBeckon.PULSE * 0.5)
	_check(fails, first.lantern.flare > 0.5 and first._plaque.glow > 0.5,
		"the beckon's breath does not brighten the flame and the plaque together")
	beckon._process(TitleBeckon.PULSE * 2.0)
	_check(fails, not beckon.beckoning() and first.lantern.flare == 0.0,
		"the beckon did not settle after two breaths")
	beckon.touched()
	beckon._process(TitleBeckon.IDLE - 0.5)
	_check(fails, not beckon.rising(), "the ember rose before the title was idle")
	beckon.touched()
	beckon._process(TitleBeckon.IDLE - 0.5)
	_check(fails, not beckon.rising(), "input did not reset the idle count")
	beckon._process(1.0)
	_check(fails, beckon.rising(), "an idle title raised no ember to the plaque")
	beckon._process(TitleBeckon.RISE + 0.1)
	_check(fails, not beckon.rising(), "the ember never arrived")
	beckon._process(TitleBeckon.IDLE + 1.0)
	_check(fails, not beckon.rising(), "one idle spell raised a second ember")
	first.free()
	var later: TitleScreen = TitleScreen.new({"shape": "pad-landscape",
		"choices": [{"id": "begin", "label": "Rekindle"}]})
	later.kindle_now()
	_check(fails, not later._beckon.beckoning(), "a later title of the session beckoned again")
	later.free()


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
