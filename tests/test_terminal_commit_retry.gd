extends RefCounted
## A failed winning fold leaves the accepted Vigil and its readers unchanged.
## Retry and a reconstructed process both owe the complete original Dawn.

const RUN_PATH: String = "user://test_terminal_retry_run_v2.json"
const VIGIL_PATH: String = "user://test_terminal_retry_vigil_v2.json"
const BLOCKED_PATH: String = "user://test_terminal_retry_missing_dir/vigil.json"
const Diff: GDScript = preload("res://tests/support/diff.gd")


class ProbeMain extends Main:
	var dawn_shown: int = 0
	var errors: Array[String] = []
	var title_shown: int = 0

	func _show_dawn() -> void:
		dawn_shown += 1

	func _show_save_error(detail_key: String) -> void:
		_save_error_detail = detail_key
		errors.append(detail_key)

	func _show_title() -> void:
		title_shown += 1


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var straight: ProbeMain = _main(content, fails)
	straight._on_terminal_commit("commit")
	if typeof(straight.game.run.pending_dawn) != TYPE_DICTIONARY:
		fails.append("terminal Retry: straight commit did not produce a Dawn")
		straight.free()
		TestProfile.wipe(RUN_PATH, VIGIL_PATH)
		return
	var expected_dawn: Dictionary = straight.game.run.pending_dawn.duplicate(true)
	var expected_vigil: Dictionary = straight._load_vigil().to_dict()
	var kinds: Array[String] = []
	for event: Dictionary in expected_dawn["events"]:
		kinds.append(str(event["kind"]))
	for kind: String in ["whisper", "quest", "shard", "unlock", "back", "memory"]:
		if not kinds.has(kind):
			fails.append("terminal Retry: fixture did not earn %s" % kind)
	straight.free()
	for failures: int in [1, 3]:
		_retry(content, failures, expected_dawn, expected_vigil, fails)
	_restart_after_failure(content, expected_dawn, expected_vigil, fails)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _retry(content: ContentDB, failures: int, expected_dawn: Dictionary,
		expected_vigil: Dictionary, fails: Array[String]) -> void:
	var main: ProbeMain = _main(content, fails)
	var accepted: VigilState = main._vigil
	var before_vigil: Dictionary = accepted.to_dict()
	var game: GlassvowGame = main.game
	var before_run: Dictionary = game.run.to_save_dict()
	var before_backs: Array[String] = CardBacks.catalogue().unlocked(accepted)
	main._vigil_save_path = BLOCKED_PATH
	main._on_terminal_commit("commit")
	for attempt: int in range(failures):
		if main.errors.size() != attempt + 1 or main.dawn_shown != 0 \
				or main.title_shown != 0:
			fails.append("terminal Retry: failed attempt lost its pending error route")
		if main._vigil != accepted or main._hints.main._vigil != accepted:
			fails.append("terminal Retry: failed attempt replaced the accepted reader handle")
		_same(accepted.to_dict(), before_vigil, "accepted alias after failure", fails)
		_same(main._vigil.to_dict(), before_vigil, "Main ledger after failure", fails)
		_same(CardBacks.catalogue().unlocked(main._vigil), before_backs,
			"back reader after failure", fails)
		if main._deed("wins") != 0 or main.game != game:
			fails.append("terminal Retry: failed attempt changed deed/game readers")
		_same(game.run.to_save_dict(), before_run, "run/RNG after failure", fails)
		_same(SaveService.load_vigil(VIGIL_PATH).to_dict(), before_vigil,
			"durable ledger after failure", fails)
		if attempt + 1 < failures:
			main._on_save_error_choice("retry")
	main._vigil_save_path = VIGIL_PATH
	main._on_save_error_choice("retry")
	if main.dawn_shown != 1 or main.errors.size() != failures or main.title_shown != 0:
		fails.append("terminal Retry: successful retry did not show one Dawn")
	_same(game.run.pending_dawn, expected_dawn, "retried Dawn", fails)
	_same(main._load_vigil().to_dict(), expected_vigil, "retried durable awards", fails)
	var loaded: RunState = main._load_run()
	if loaded == null:
		fails.append("terminal Retry: successful Dawn checkpoint did not load")
	else:
		_same(loaded.pending_dawn, expected_dawn, "persisted retried Dawn", fails)
	if main._deed("wins") != 1 or main.game.run.pending_run_end != null:
		fails.append("terminal Retry: winning fold was duplicated or left pending")
	main.free()


static func _restart_after_failure(content: ContentDB, expected_dawn: Dictionary,
		expected_vigil: Dictionary, fails: Array[String]) -> void:
	var interrupted: ProbeMain = _main(content, fails)
	interrupted._vigil_save_path = BLOCKED_PATH
	interrupted._on_terminal_commit("commit")
	interrupted.free()
	var restarted: ProbeMain = ProbeMain.new()
	TestProfile.install(restarted, RUN_PATH, VIGIL_PATH)
	restarted.content = content
	restarted._vigil = restarted._load_vigil()
	var saved: RunState = restarted._load_run()
	if saved == null:
		fails.append("terminal Retry: interrupted run checkpoint did not load")
	else:
		restarted._continue_run(saved)
		_same(restarted.game.run.pending_dawn, expected_dawn, "restarted Dawn", fails)
		_same(restarted._load_vigil().to_dict(), expected_vigil, "restarted awards", fails)
		if restarted.dawn_shown != 1 or not restarted.errors.is_empty():
			fails.append("terminal Retry: restarted terminal did not show one Dawn")
	restarted.free()


static func _main(content: ContentDB, fails: Array[String]) -> ProbeMain:
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	var main: ProbeMain = ProbeMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	main._vigil.scenes_seen.append("opening")
	if not main._store_vigil():
		fails.append("terminal Retry: could not seed accepted Vigil")
	var run: RunState = RunState.new_run(content, 717, "run-terminal-retry", {
		"quests": main._vigil.quests,
	})
	run.quests["ownShade"] = {"state": "complete", "progress": 3, "memory": {}}
	run.stats["slain"] = 7
	run.pending_run_end = {"outcome": "win", "bequestAnswered": true}
	main.game = GlassvowGame.new(content, run)
	main._map = WorldMap.benchmark(run)
	run.map = main._map.to_dict()
	if not main._store_run():
		fails.append("terminal Retry: could not seed terminal run")
	return main


static func _same(actual: Variant, expected: Variant, label: String,
		fails: Array[String]) -> void:
	var difference: String = Diff.deep_eq(StateBuild.jsonish(actual), StateBuild.jsonish(expected))
	if not difference.is_empty():
		fails.append("terminal Retry: %s differs at %s" % [label, difference])
