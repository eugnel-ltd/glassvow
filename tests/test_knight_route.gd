extends RefCounted
## #212 lane 3: the route, its production continuation and the simulator.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Wiring: GDScript = preload("res://tests/test_scene_wiring.gd")
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const RUN_PATH: String = "user://test_knight_run_v2.json"
const VIGIL_PATH: String = "user://test_knight_vigil_v2.json"
const SEED: int = 21203


class InterruptMain extends Main:
	var interrupt_run: bool = false
	var interrupt_vigil: bool = false
	var save_error: bool = false

	func _store_run() -> bool:
		var path: String = _run_save_path
		if interrupt_run:
			_run_save_path = RUN_PATH + "/blocked"
		var ok: bool = super._store_run()
		_run_save_path = path
		return ok

	func _store_vigil() -> bool:
		return false if interrupt_vigil else super._store_vigil()

	func _show_save_error(detail: String) -> void:
		save_error = true
		super._show_save_error(detail)


static func _check(fails: Array[String], ok: Variant, what: String) -> void:
	if ok != true:
		fails.append("knight route: " + what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var was_live: bool = RewardRules.mythics_live
	RewardRules.mythics_live = true
	_dormant(content, fails, 2)
	_forced_event(content, fails)
	_aid_choice(content, fails)
	_scene_completion(content, fails)
	_interrupted_scene(content, fails)
	_interrupted_aid(content, fails)
	_vigil_retry(content, fails)
	_failed_title_reload(content, fails)
	_staging_failure(content, fails)
	_deferrals(content, fails)
	_simulator(content, fails)
	_new_run_snapshot(content, fails)
	RewardRules.mythics_live = false
	_dormant(content, fails, 5)
	RewardRules.mythics_live = was_live
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _dormant(content: ContentDB, fails: Array[String], vow: int) -> void:
	for step: int in range(3):
		var baseline: RunState = RunState.new_run(content, SEED, "dormant", {"vow": vow})
		var run_state: RunState = RunState.new_run(content, SEED, "dormant",
			{"vow": vow, "knight": step})
		_check(fails, not run_state.quest_scratch.has("knight")
			and not run_state.quest_scratch.has("seenEvents"), "dormant snapshot changed")
		# A carried snapshot must also stay dormant when O6 is switched off.
		run_state.quest_scratch["knight"] = {"step": step, "met": false}
		var main: InterruptMain = _main(content, run_state)
		main._show_event()
		_check(fails, main._route_screen is EventScreen and run_state.pending_scene == null,
			"dormant Vow %d step %d staged a scene" % [vow, step])
		var expected: String = main.game.rewards.roll_event(baseline)
		_check(fails, run_state.quest_scratch.get("eventNode") == expected
			and run_state.rng_state() == baseline.rng_state(), "dormant event/RNG changed")
		run_state.quest_scratch["eventNode"] = "woundedKnight"
		main._on_event_choice("0", "woundedKnight")
		main.game.quests.finish_knight_meeting(run_state, "knight-3")
		_check(fails, not main._vigil.scenes_seen.has("knight-1") and _mythics(run_state) == 0,
			"dormant route progressed or granted")
		_dispose(main)


static func _forced_event(content: ContentDB, fails: Array[String]) -> void:
	var run_state: RunState = _run(content, 0)
	var rewards: RewardRules = RewardRules.new(content)
	var cursor: int = run_state.rng_state()
	_check(fails, rewards.roll_event(run_state) == "woundedKnight"
		and run_state.rng_state() == cursor, "step 0 was not forced without a draw")
	_check(fails, run_state.quest_scratch["knight"]["met"], "forced meeting was not marked")
	for i: int in range(content.events.size() * 2):
		_check(fails, rewards.roll_event(run_state) != "woundedKnight",
			"the Knight repeated in the same run at roll %d" % i)
	for step: int in [1, 2, 3]:
		var later: RunState = _run(content, step)
		_check(fails, later.quest_scratch["seenEvents"].has("woundedKnight"),
			"the later run did not exclude the living Knight")
		for _i: int in range(content.events.size() * 2):
			_check(fails, rewards.roll_event(later) != "woundedKnight", "no-repeat reset lost the Knight")


static func _aid_choice(content: ContentDB, fails: Array[String]) -> void:
	for choice: int in range(3):
		var main: InterruptMain = _main(content, _run(content, 0))
		main._show_event()
		main._on_event_choice(str(choice), "woundedKnight")
		var disk: VigilState = SaveService.load_vigil(VIGIL_PATH)
		_check(fails, disk.scenes_seen.has("knight-1") == (choice == 0),
			"choice %d wrote the wrong once-flag" % choice)
		_check(fails, main.game.run.quest_scratch["knight"]["step"] == 0,
			"meeting one advanced the run-start snapshot")
		_dispose(main)


static func _scene_completion(content: ContentDB, fails: Array[String]) -> void:
	for step: int in [1, 2]:
		var main: InterruptMain = _main(content, _run(content, step))
		var cursor: int = main.game.run.rng_state()
		main._show_event()
		var scene_id: String = "knight-%d" % (step + 1)
		_check(fails, _playing(main, scene_id) and not main.game.run.quest_scratch.has("eventNode")
			and main.game.run.rng_state() == cursor, "scene did not branch before the event roll")
		var staged: RunState = SaveService.load_run(content, RUN_PATH)
		_check(fails, staged != null and staged.pending_scene != null
			and not WorldMap.from_dict(staged.map).is_cleared(3), "staging lost the uncleared node")
		Wiring._drive(main)
		var disk: RunState = SaveService.load_run(content, RUN_PATH)
		_check(fails, disk != null and disk.pending_scene == null
			and WorldMap.from_dict(disk.map).is_cleared(3)
			and disk.pending_hollow_route == null and not disk.quest_scratch.has("eventNode")
			and _mythics(disk) == step - 1, "completion did not persist node, grant and continuation together")
		_check(fails, SaveService.load_vigil(VIGIL_PATH).scenes_seen.has(scene_id), "completion flag missing")
		_check(fails, main._map_screen is WorldMapScreen and main._map.at == 3,
			"completion did not return to the correct map node")
		main.game.quests.finish_knight_meeting(main.game.run, scene_id)
		_check(fails, _mythics(main.game.run) == step - 1, "replayed completion duplicated the grant")
		if step == 2:
			main.game.run.player.deck = main.game.run.player.deck.filter(
				func(card: CardInst) -> bool: return card.id != &"bankedFire")
			main.game.quests.finish_knight_meeting(main.game.run, scene_id)
			_check(fails, _mythics(main.game.run) == 0, "removing the card reopened the spent slot")
		_check(fails, main.game.quests.stage_knight_scene(main.game.run).is_empty(), "second meeting in one run")
		_dispose(main)


static func _interrupted_scene(content: ContentDB, fails: Array[String]) -> void:
	for step: int in [1, 2]:
		var main: InterruptMain = _main(content, _run(content, step))
		main._show_event()
		Wiring._wake(main)
		(main._route_screen as ScenePlayer)._process(0.016)
		var cursor_save: RunState = SaveService.load_run(content, RUN_PATH)
		_check(fails, cursor_save.pending_scene.get("cursor") == 1, "scene cursor did not persist")
		# The second store fails after the real Vigil store: model a process death there.
		main.interrupt_run = true
		main._on_scene_finished()
		var disk: RunState = SaveService.load_run(content, RUN_PATH)
		var vigil: VigilState = SaveService.load_vigil(VIGIL_PATH)
		var scene_id: String = "knight-%d" % (step + 1)
		_check(fails, main.save_error and vigil.scenes_seen.has(scene_id)
			and disk.pending_scene != null and _mythics(disk) == 0
			and not WorldMap.from_dict(disk.map).is_cleared(3), "interruption window was not reproduced")
		_dispose(main)
		var resumed: InterruptMain = _main(content, null, false)
		resumed._vigil = vigil
		resumed._continue_run(disk)
		Wiring._wake(resumed)
		_check(fails, _playing(resumed, scene_id), "resume discarded a scene whose Vigil flag already holds")
		Wiring._drive(resumed)
		var complete: RunState = SaveService.load_run(content, RUN_PATH)
		_check(fails, complete.pending_scene == null and WorldMap.from_dict(complete.map).is_cleared(3)
			and _mythics(complete) == step - 1, "interrupted scene did not finish exactly once")
		resumed.game.quests.finish_knight_meeting(complete, scene_id)
		_check(fails, _mythics(complete) == step - 1, "replay added a second mythic")
		_dispose(resumed)


static func _interrupted_aid(content: ContentDB, fails: Array[String]) -> void:
	var main: InterruptMain = _main(content, _run(content, 0))
	main._show_event()
	main.interrupt_run = true
	main._on_event_choice("0", "woundedKnight")
	var disk: RunState = SaveService.load_run(content, RUN_PATH)
	var vigil: VigilState = SaveService.load_vigil(VIGIL_PATH)
	_check(fails, main.save_error and vigil.scenes_seen.has("knight-1")
		and not disk.quest_scratch.has("eventChoice"), "Aid interruption did not leave the event replayable")
	_dispose(main)
	var resumed: InterruptMain = _main(content, disk, false)
	resumed._vigil = vigil
	resumed._show_event()
	resumed._on_event_choice("0", "woundedKnight")
	_check(fails, resumed._vigil.scenes_seen.count("knight-1") == 1
		and SaveService.load_run(content, RUN_PATH).quest_scratch.get("eventChoice") == 0,
		"Aid replay did not preserve one flag and one choice")
	_dispose(resumed)


## Use the production error screen's signal and Retry handler. Fail each store
## separately, then reload both files at every boundary.
static func _vigil_retry(content: ContentDB, fails: Array[String]) -> void:
	for step: int in [0, 1, 2]:
		var main: InterruptMain = _main(content, _run(content, step))
		main._vigil.scenes_seen.append("opening")
		main._store_vigil()
		main._show_event()
		var before: Dictionary = main.game.run.to_dict()
		var expected: RunState = main._load_run()
		if step == 0:
			var ops: Array = content.events["woundedKnight"]["choices"][0]["ops"]
			main.game.rewards.apply_event_ops(expected, ops)
		main.interrupt_vigil = true
		if step == 0:
			main._on_event_choice("0", "woundedKnight")
		else:
			Wiring._drive(main)
		var flag: String = "knight-%d" % (step + 1)
		_check(fails, main.save_error and main._choice_screen is ChoiceScreen,
			"Vigil failure did not show the actual error screen at " + flag)
		_check(fails, main._load_run().to_dict() == before
			and not main._load_vigil().scenes_seen.has(flag), "Vigil failure wrote a partial run at " + flag)
		_restart_checkpoint(content, step, fails)
		for _attempt: int in range(2):
			_answer_error(main, "retry", fails)
			_check(fails, main._choice_screen is ChoiceScreen
				and main._load_run().to_dict() == before
				and not main._load_vigil().scenes_seen.has(flag), "failed Retry escaped or wrote the run at " + flag)
		main.interrupt_vigil = false
		main.interrupt_run = true
		_answer_error(main, "retry", fails)
		_check(fails, main._choice_screen is ChoiceScreen
			and main._load_vigil().scenes_seen.count(flag) == 1
			and main._load_run().to_dict() == before, "Vigil-then-run boundary was lost at " + flag)
		_restart_checkpoint(content, step, fails)
		main.interrupt_run = false
		_answer_error(main, "retry", fails)
		var disk: RunState = main._load_run()
		_check(fails, main._load_vigil().scenes_seen.count(flag) == 1, "Retry lost the flag at " + flag)
		if step == 0:
			_check(fails, disk.quest_scratch.get("eventStory", {}).get("phase") == "result"
				and main._route_screen is EventScreen and (main._route_screen as EventScreen).beat == "c0"
				and disk.player.hp == expected.player.hp and disk.player.relics == expected.player.relics
				and disk.rng_state() == expected.rng_state(), "Retry repeated Aid or lost its result")
		else:
			_check(fails, disk.pending_scene == null and WorldMap.from_dict(disk.map).is_cleared(3)
				and _mythics(disk) == step - 1 and not disk.quest_scratch.has("eventNode")
				and disk.pending_hollow_route == null, "Retry lost scene completion at " + flag)
		_dispose(main)
		var resumed: InterruptMain = _main(content, null, false)
		resumed._vigil = resumed._load_vigil()
		resumed._continue_run(disk)
		if step == 0:
			_check(fails, (resumed._route_screen as EventScreen).beat == "c0", "restart offered Aid again")
			resumed._on_event_story_continue()
			resumed._on_event_story_continue()
		else:
			resumed.game.quests.finish_knight_meeting(resumed.game.run, flag)
		_check(fails, WorldMap.from_dict(resumed._load_run().map).is_cleared(3)
			and _mythics(resumed.game.run) == maxi(0, step - 1), "restart lost the node or duplicated the grant")
		_dispose(resumed)


static func _restart_checkpoint(content: ContentDB, step: int, fails: Array[String]) -> void:
	var resumed: InterruptMain = _main(content, null, false)
	resumed._vigil = resumed._load_vigil()
	resumed._continue_run(resumed._load_run())
	if step == 0:
		_check(fails, resumed._route_screen is EventScreen
			and (resumed._route_screen as EventScreen).beat.is_empty()
			and not resumed.game.run.quest_scratch.has("eventChoice"), "restart retained a partial Aid grant")
	else:
		_check(fails, _playing(resumed, "knight-%d" % (step + 1))
			and not resumed._map.is_cleared(3) and _mythics(resumed.game.run) == 0,
			"restart lost the pending meeting before run commit")
	_dispose(resumed)


static func _failed_title_reload(content: ContentDB, fails: Array[String]) -> void:
	for step: int in [0, 1, 2]:
		for boundary: String in ["vigil", "run"]:
			var main: InterruptMain = _main(content, _run(content, step))
			main._vigil.scenes_seen.append("opening")
			main._store_vigil()
			main._show_event()
			var before: Dictionary = main._load_run().to_dict()
			main.interrupt_vigil = boundary == "vigil"
			main.interrupt_run = boundary == "run"
			if step == 0:
				main._on_event_choice("0", "woundedKnight")
			else:
				main._on_scene_finished()
			_answer_error(main, "title", fails)
			var flag: String = "knight-%d" % (step + 1)
			_check(fails, main._choice_screen is TitleScreen
				and main._load_run().to_dict() == before
				and main._vigil.scenes_seen.has(flag) == (boundary == "run"),
				"Title retained uncommitted state at %s/%s" % [flag, boundary])
			main.interrupt_vigil = false
			main.interrupt_run = false
			main._on_title_choice("continue", main._load_run())
			if step == 0:
				main._on_event_choice("0", "woundedKnight")
				_check(fails, main._load_run().player.hp == int(float(str(before["player"]["hp"]))) - 8
					and main._load_run().player.relics.size() == before["player"]["relics"].size() + 1,
					"Title/reload repeated Aid")
			else:
				_check(fails, _playing(main, flag), "Title/reload dropped the pending scene")
				Wiring._drive(main)
				_check(fails, main._load_run().pending_scene == null
					and WorldMap.from_dict(main._load_run().map).is_cleared(3)
					and _mythics(main._load_run()) == step - 1, "Title/reload lost scene completion")
			_check(fails, main._load_vigil().scenes_seen.count(flag) == 1, "Title/reload lost the flag")
			_dispose(main)


static func _answer_error(main: Main, id: String, fails: Array[String]) -> void:
	if main._choice_screen is ChoiceScreen:
		main._choice_screen.emit_signal("chosen", id)
	else:
		_check(fails, false, "no production error choice for " + id)


static func _staging_failure(content: ContentDB, fails: Array[String]) -> void:
	var main: InterruptMain = _main(content, _run(content, 1))
	main.interrupt_run = true
	main._show_event()
	_check(fails, main.save_error and main.game.run.pending_scene == null
		and not main.game.run.quest_scratch["knight"]["met"]
		and not main.game.run.quest_scratch.has("eventNode"), "failed staging did not undo its state")
	main.interrupt_run = false
	main._show_event()
	_check(fails, _playing(main, "knight-2"), "failed staging could not retry")
	_dispose(main)


static func _deferrals(content: ContentDB, fails: Array[String]) -> void:
	for extra: String in ["slot", "silvering"]:
		var main: InterruptMain = _main(content, _run(content, 2))
		if extra == "slot":
			main.game.run.quest_scratch["mythic"] = {"id": "silvering", "via": "elite"}
		else:
			main.game.run.player.deck.append(CardInst.new(main.game.run.next_uid(), &"silvering", false))
		main._show_event()
		_check(fails, main._route_screen is EventScreen and main.game.run.pending_scene == null
			and not main.game.run.quest_scratch["knight"]["met"], "used slot did not defer knight-3")
		main.game.quests.finish_knight_meeting(main.game.run, "knight-3")
		_check(fails, not main.game.run.player.deck.any(
			func(card: CardInst) -> bool: return card.id == &"bankedFire"), "used slot still granted Banked Fire")
		_dispose(main)
	for step: int in [0, 1, 2]:
		var main: InterruptMain = _main(content, _run(content, step))
		main.game.run.pending_hollow = {"nodeId": main._map.current().id, "type": "event",
			"meeting": 0, "paid": false, "deferred": false, "answer": ""}
		main._stage_hollow_exit()
		_check(fails, main._route_screen is EventScreen and main.game.run.pending_scene == null,
			"Lamplighter exit staged a Knight scene")
		_check(fails, main.game.run.quest_scratch["knight"]["met"] == (step == 0),
			"Lamplighter exit consumed the later meeting")
		if step == 0:
			_check(fails, main.game.run.quest_scratch.get("eventNode") == "woundedKnight",
				"Lamplighter exit did not allow the forced first event")
		else:
			main._complete_node_state()
			main.game.run.quest_scratch.erase("eventNode")
			main._show_event()
			_check(fails, _playing(main, "knight-%d" % (step + 1)), "later event did not take the deferred meeting")
		_dispose(main)


static func _simulator(content: ContentDB, fails: Array[String]) -> void:
	for step: int in [0, 1, 2]:
		var run_state: RunState = _run(content, step)
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		var vigil: VigilState = VigilState.blank()
		var cursor: int = run_state.rng_state()
		# A scene must finish even when an event lookup would be impossible.
		var events: Dictionary = content.events
		if step > 0:
			content.events = {}
		Sim._resolve_event(game, vigil)
		content.events = events
		_check(fails, _mythics(run_state) == (1 if step == 2 else 0)
			and (step == 0 or run_state.rng_state() == cursor),
			"simulator step %d failed or a scene drew RNG" % step)
		if step > 0:
			_check(fails, vigil.scenes_seen.has("knight-%d" % (step + 1)), "simulator did not record scene progress")


static func _new_run_snapshot(content: ContentDB, fails: Array[String]) -> void:
	var main: InterruptMain = _main(content, null)
	main._vigil.scenes_seen.append_array(["opening", "knight-1", "knight-2", "knight-3"])
	main._forced_seed = SEED
	main._new_run({"vow": 3})
	_check(fails, main.game.run.quest_scratch["knight"] == {"step": 3, "met": false},
		"production run start did not snapshot the Vigil flags")
	_check(fails, SaveService.load_run(content, RUN_PATH).quest_scratch["knight"]["step"] == 3,
		"production run start did not persist the route snapshot")
	_check(fails, main.game.quests.stage_knight_scene(main.game.run).is_empty(), "completed route played again")
	_dispose(main)


static func _run(content: ContentDB, step: int) -> RunState:
	return RunState.new_run(content, SEED, "knight-route", {"vow": 3, "knight": step})


static func _main(content: ContentDB, run_state: RunState, wipe: bool = true) -> InterruptMain:
	if wipe:
		TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	var main: InterruptMain = InterruptMain.new()
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
	if run_state != null:
		var walk: WorldMap = WorldMap.slice()
		walk.at = 3
		walk.nodes[3].type = "event"
		run_state.node_id = walk.nodes[3].id
		run_state.map = walk.to_dict()
		main.game = GlassvowGame.new(content, run_state)
		main._map = walk
	return main


static func _playing(main: Main, id: String) -> bool:
	return main._route_screen is ScenePlayer and (main._route_screen as ScenePlayer)._script.id == id


static func _mythics(run_state: RunState) -> int:
	return run_state.player.deck.filter(func(card: CardInst) -> bool:
		return card.id in [&"bankedFire", &"silvering", &"unbrokenFlame", &"unbowed", &"knownRoad", &"cleanBreak"]).size()


static func _dispose(main: Main) -> void:
	Wiring._dispose(main)
