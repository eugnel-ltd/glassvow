extends RefCounted
## A back earned by a lost run is still owed, without claiming a victory.
## The ledger hold and the reveal checkpoint may fail or be interrupted apart.

const RUN_PATH: String = "user://test_loss_back_run_v2.json"
const VIGIL_PATH: String = "user://test_loss_back_vigil_v2.json"
const BLOCKED_VIGIL: String = "user://test_loss_back_missing/test_vigil.json"
const BLOCKED_RUN: String = "user://test_loss_back_missing/test_run.json"
const Diff: GDScript = preload("res://tests/support/diff.gd")


class ProbeMain extends Main:
	var shown: DawnScreen = null
	var cues: Array[StringName] = []
	var errors: Array[String] = []
	var idle_count: int = 0

	func _show_route(screen: Control, _with_hud: bool = false,
			cue: StringName = &"", _entrance: bool = true) -> void:
		cues.append(cue)
		if is_instance_valid(shown):
			shown.free()
		shown = screen as DawnScreen
		if shown == null:
			screen.free()
			return
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		tree.root.add_child(shown)
		shown.set_process(false)

	func _show_save_error(detail_key: String) -> void:
		_save_error_detail = detail_key
		errors.append(detail_key)

	func _route_idle() -> void:
		idle_count += 1

	func dispose() -> void:
		if is_instance_valid(shown):
			shown.free()
		queue_free()


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var straight: ProbeMain = _main(content, true, "death", fails)
	var original_rng: int = straight.game.run.rng.get_state()
	straight._on_terminal_commit("commit")
	if not _owed(straight, "straight loss", fails):
		straight.dispose()
		TestProfile.wipe(RUN_PATH, VIGIL_PATH)
		return
	var expected_dawn: Dictionary = straight.game.run.pending_dawn.duplicate(true)
	var expected_vigil: Dictionary = straight._load_vigil().to_dict()
	var expected_rng: int = straight.game.run.rng.get_state()
	_check(expected_rng != original_rng, "fixture must exercise death's seeded epitaph", fails)
	_check(straight._deed("wins") == 0 and straight._deed("runs") == 1,
		"a lost run must not become a win", fails)
	_quiet(straight, fails)
	straight._finish_dawn()
	_check(straight.game != null and straight._load_run() != null,
		"unread back must keep its run checkpoint", fails)
	straight.dispose()
	for failures: int in [1, 3]:
		_retry(content, failures, expected_dawn, expected_vigil, expected_rng, fails)
	_restart_between_holds(content, expected_dawn, expected_vigil, expected_rng, fails)
	_cursor_and_close(content, expected_dawn, expected_vigil, fails)
	_no_award(content, "death", fails)
	_no_award(content, "abandon", fails)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _retry(content: ContentDB, failures: int, expected_dawn: Dictionary,
		expected_vigil: Dictionary, expected_rng: int, fails: Array[String]) -> void:
	var main: ProbeMain = _main(content, true, "death", fails)
	var accepted: VigilState = main._vigil
	var accepted_rng: Rng = main.game.run.rng
	var before_vigil: Dictionary = accepted.to_dict()
	var before_run: Dictionary = main.game.run.to_save_dict()
	var before_backs: Array[String] = CardBacks.catalogue().unlocked(accepted)
	main._vigil_save_path = BLOCKED_VIGIL
	main._on_terminal_commit("commit")
	for attempt: int in range(failures):
		_check(main.errors.size() == attempt + 1 and main.shown == null
			and main.idle_count == 0, "failed ledger hold must remain retryable", fails)
		_check(main._vigil == accepted and main._hints.main._vigil == accepted,
			"failed ledger hold must retain accepted reader aliases", fails)
		_same(accepted.to_dict(), before_vigil, "accepted ledger after failure", fails)
		_same(main.game.run.to_save_dict(), before_run, "run and RNG after failure", fails)
		_check(main.game.run.rng == accepted_rng,
			"failed ledger hold must retain accepted RNG alias", fails)
		_same(CardBacks.catalogue().unlocked(main._vigil), before_backs,
			"back reader after failure", fails)
		_same(SaveService.load_vigil(VIGIL_PATH).to_dict(), before_vigil,
			"durable ledger after failure", fails)
		if attempt + 1 < failures:
			main._on_save_error_choice("retry")
	main._vigil_save_path = VIGIL_PATH
	main._on_save_error_choice("retry")
	if _owed(main, "successful ledger retry", fails):
		_same(main.game.run.pending_dawn, expected_dawn, "retried back reveal", fails)
		_same(main._load_vigil().to_dict(), expected_vigil, "retried awards and once state", fails)
		_check(main.game.run.rng.get_state() == expected_rng,
			"retried death must consume its seeded lines only once", fails)
		_check(main.errors.size() == failures and main.cues.size() == 1,
			"successful retry must reveal once", fails)
	main.dispose()


static func _restart_between_holds(content: ContentDB, expected_dawn: Dictionary,
		expected_vigil: Dictionary, expected_rng: int, fails: Array[String]) -> void:
	var interrupted: ProbeMain = _main(content, true, "death", fails)
	interrupted._run_save_path = BLOCKED_RUN
	interrupted._on_terminal_commit("commit")
	_check(interrupted.shown == null and interrupted.errors.size() == 1,
		"failed reveal hold must not show the back ahead of its checkpoint", fails)
	_same(interrupted._load_vigil().to_dict(), expected_vigil,
		"awards held before interruption", fails)
	var previous: RunState = SaveService.load_run(content, RUN_PATH)
	_check(previous != null and previous.pending_run_end != null
		and previous.pending_dawn == null, "interruption fixture must retain old terminal run", fails)
	interrupted.dispose()
	var restarted: ProbeMain = _restart(content, fails)
	if restarted.game != null:
		# The player confirms the restored death screen; the held ledger must
		# still supply its exact owed delta rather than recomputing an empty one.
		restarted._on_terminal_commit("commit")
		if _owed(restarted, "restart after ledger hold", fails):
			_same(restarted.game.run.pending_dawn, expected_dawn, "recovered back reveal", fails)
			_same(restarted._load_vigil().to_dict(), expected_vigil,
				"recovered awards and once state", fails)
			_check(restarted.game.run.rng.get_state() == expected_rng,
				"recovered death must retain the post-fold RNG cursor", fails)
			_quiet(restarted, fails)
	restarted.dispose()


static func _cursor_and_close(content: ContentDB, expected_dawn: Dictionary,
		expected_vigil: Dictionary, fails: Array[String]) -> void:
	var main: ProbeMain = _restart(content, fails)
	if main.game == null:
		main.dispose()
		return
	main._route_run()
	if not _owed(main, "restored owed reveal", fails):
		main.dispose()
		return
	_same(main.game.run.pending_dawn, expected_dawn, "persisted owed reveal", fails)
	main._run_save_path = BLOCKED_RUN
	main._on_dawn_advance(main.shown)
	_check(main.shown._cursor == 0, "failed cursor hold must not reveal the next beat", fails)
	var old: RunState = SaveService.load_run(content, RUN_PATH)
	_check(old != null and int(float(str(old.pending_dawn["cursor"]))) == 0,
		"failed cursor hold must retain the durable owed beat", fails)
	main._run_save_path = RUN_PATH
	main._on_save_error_choice("retry")
	_check(main.shown != null and main.shown._cursor == 1,
		"cursor Retry must resume after the held beat", fails)
	main.dispose()
	var done: ProbeMain = _restart(content, fails)
	if done.game != null:
		done._route_run()
		_check(done.shown != null and done.shown._cursor == 1,
			"process restart must not replay the acknowledged back", fails)
		_quiet(done, fails)
		_same(done._load_vigil().to_dict(), expected_vigil,
			"cursor and restart must not reapply awards", fails)
		done._finish_dawn()
		_check(done.game == null and done._load_run() == null and done.idle_count == 1,
			"acknowledged back must close the lost run", fails)
		_same(done._load_vigil().to_dict(), expected_vigil, "closed lost run ledger", fails)
	done.dispose()


static func _no_award(content: ContentDB, outcome: String, fails: Array[String]) -> void:
	var main: ProbeMain = _main(content, false, outcome, fails)
	main._on_terminal_commit("commit")
	_check(main.game == null and main.shown == null and main.idle_count == 1
		and main._load_run() == null, "%s without an earned back must retain its normal exit" % outcome, fails)
	_check(main._deed("wins") == 0, "non-winning exit must not add a win", fails)
	main.dispose()


static func _quiet(main: ProbeMain, fails: Array[String]) -> void:
	_check(main.shown != null and not main.cues.has(&"victory"),
		"loss back reveal must not play the victory cue", fails)
	if main.shown == null:
		return
	var text: Array[String] = []
	_visible_text(main.shown, text)
	_check(not text.has(Locale.active.t("ui.dawn.title"))
		and not text.has(Locale.active.t("ui.dawn.subtitle")),
		"loss back reveal must not claim ascent", fails)
	_check(not main.shown._stats_grid.visible,
		"back-only reveal must not repeat winning-run stats", fails)
	_check(main.shown._confetti == null and main.shown._flash == null
		and main.shown._sun_t < 0.0 and not main.shown._sun.visible,
		"loss back reveal must not run victory celebration or sunrise", fails)
	for texture: TextureRect in main.shown.find_children("*", "TextureRect", true, false):
		_check(not texture.is_visible_in_tree() or texture.texture == null
			or texture.texture.resource_path != DawnScreen.ARRIVED,
			"loss back reveal must not display ascended art", fails)
	var event: Dictionary = main.game.run.pending_dawn["events"][0]
	_check(str(event["title"]) == Locale.active.t("ui.back.rose.name")
		and str(event["body"]) == Locale.active.t("ui.dawn.backBody"),
		"loss back reveal must retain the existing localized back words", fails)


static func _visible_text(node: Node, out: Array[String]) -> void:
	if node is Control and not (node as Control).visible:
		return
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		_visible_text(child, out)


static func _owed(main: ProbeMain, label: String, fails: Array[String]) -> bool:
	if main.game == null or typeof(main.game.run.pending_dawn) != TYPE_DICTIONARY:
		fails.append("loss back reveal: %s discarded the earned back without a reveal" % label)
		return false
	var events: Array = main.game.run.pending_dawn["events"]
	_check(events.size() == 1 and str(events[0].get("kind")) == "back"
		and str(events[0].get("back")) == "rose", "%s must owe only the actually earned Rose back" % label, fails)
	_check(main.shown != null and main.game.run.pending_run_end == null,
		"%s must route the durable reveal before closing" % label, fails)
	return true


static func _main(content: ContentDB, award: bool, outcome: String,
		fails: Array[String]) -> ProbeMain:
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	var main: ProbeMain = ProbeMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	main._vigil.scenes_seen.append("opening")
	_check(main._store_vigil(), "could not seed accepted ledger", fails)
	var run: RunState = RunState.new_run(content, 717, "run-loss-back", {"quests": main._vigil.quests})
	if award:
		run.quests["ownShade"] = {"state": "complete", "progress": 3, "memory": {}}
	run.stats["slain"] = 7
	run.pending_run_end = {"outcome": outcome, "bequestAnswered": true}
	main.game = GlassvowGame.new(content, run)
	main._map = WorldMap.benchmark(run)
	run.map = main._map.to_dict()
	_check(main._store_run(), "could not seed terminal run", fails)
	return main


static func _restart(content: ContentDB, fails: Array[String]) -> ProbeMain:
	var main: ProbeMain = ProbeMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	main._vigil = main._load_vigil()
	var saved: RunState = main._load_run()
	_check(saved != null, "restart must load the held terminal checkpoint", fails)
	if saved != null:
		main.game = GlassvowGame.new(content, saved)
		main._map = WorldMap.from_dict(saved.map)
	return main


static func _same(actual: Variant, expected: Variant, label: String,
		fails: Array[String]) -> void:
	var difference: String = Diff.deep_eq(StateBuild.jsonish(actual), StateBuild.jsonish(expected))
	_check(difference.is_empty(), "%s differs at %s" % [label, difference], fails)


static func _check(ok: bool, message: String, fails: Array[String]) -> void:
	if not ok:
		fails.append("loss back reveal: %s" % message)
