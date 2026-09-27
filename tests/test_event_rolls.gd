extends RefCounted
## A rolled event choice narrates its outcome (the gambler's bones): the
## landed branch is persisted by id, shown as its own beat in the live
## locale, survives a resume without re-rolling, and continues on once.

const RUN_PATH: String = "user://test_event_rolls_run_v2.json"
const VIGIL_PATH: String = "user://test_event_rolls_vigil_v2.json"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("event_rolls: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for seed_value: int in [35601, 35602, 35603, 35604]:
		_gambler_roll(fails, content, seed_value)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _gambler_roll(fails: Array[String], content: ContentDB, seed_value: int) -> void:
	SaveService.clear(RUN_PATH)
	var run_state: RunState = RunState.new_run(content, seed_value, "run-event-rolls")
	var map: WorldMap = WorldMap.slice()
	map.at = 3
	map.nodes[3].type = "event"
	run_state.node_id = map.nodes[3].id
	run_state.map = map.to_dict()
	run_state.quest_scratch["eventNode"] = "gambler"
	run_state.player.gold = 200
	var main: Main = _main(content)
	main._continue_run(run_state)
	main._on_event_choice("0", "gambler")
	var story_v: Variant = main.game.run.quest_scratch.get("eventStory")
	_check(fails, typeof(story_v) == TYPE_DICTIONARY,
		"seed %d: the bet left no roll beat owed" % seed_value)
	if typeof(story_v) != TYPE_DICTIONARY:
		_dispose(main)
		return
	var story: Dictionary = story_v
	var roll: String = str(story.get("roll", ""))
	_check(fails, str(story.get("phase", "")) == "roll" and roll in ["win", "lose"],
		"seed %d: the owed beat is not the landed roll (%s)" % [seed_value, str(story)])
	var gold: int = main.game.run.player.gold
	_check(fails, gold == (270 if roll == "win" else 160),
		"seed %d: %s left %d gold" % [seed_value, roll, gold])
	var narration: String = main._event_roll_text("gambler", 0, roll)
	var screen: EventScreen = main._route_screen as EventScreen
	_check(fails, not narration.is_empty() and screen != null
			and screen._result_log == narration and screen._completed,
		"seed %d: the %s roll was not narrated" % [seed_value, roll])
	_check(fails, screen != null and screen.beat == "roll-%s" % roll,
		"seed %d: the roll beat is not staged as roll-%s" % [seed_value, roll])
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_dispose(main)
	var resumed: Main = _main(content)
	resumed._continue_run(loaded)
	_check(fails, resumed.game.run.player.gold == gold,
		"seed %d: resume re-rolled the bones" % seed_value)
	var again: EventScreen = resumed._route_screen as EventScreen
	_check(fails, again != null and again._result_log == narration,
		"seed %d: resume dropped the narrated roll" % seed_value)
	resumed._on_event_story_continue()
	_check(fails, not resumed.game.run.quest_scratch.has("eventStory")
			and not resumed.game.run.quest_scratch.has("eventRoll"),
		"seed %d: continuing past the roll kept it owed" % seed_value)
	_check(fails, resumed.game.run.player.gold == gold,
		"seed %d: continuing re-applied the bet" % seed_value)
	_dispose(resumed)


static func _main(content: ContentDB) -> Main:
	var main: Main = Main.new()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
	main._vigil = VigilState.blank()
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
