extends RefCounted
## #146: Web Dev exposes one read-only browser acceptance projection without
## turning the composition root into a command or persistence adapter.

const MAIN_PATH: String = "res://application/main.gd"
const SEAM_PATH: String = "res://application/web_acceptance.gd"
const SAVE_PATH: String = "user://test_web_acceptance_run.json"


class AcceptanceSpy extends WebAcceptance:
	var observed_path: String = ""
	var checkpoints: int = 0
	var publications: Array[Dictionary] = []

	func observe_route(_rebuilder: Callable, _game: GlassvowGame, _content: ContentDB,
			durable_path: String) -> void:
		observed_path = durable_path

	func observe_checkpoint(_rebuilder: Callable, _game: GlassvowGame,
			_content: ContentDB, durable_path: String) -> void:
		observed_path = durable_path
		checkpoints += 1

	func _publish(route: String, live_run: RunState, _content: ContentDB,
			durable_path: String) -> void:
		publications.append({
			"route": route,
			"liveRunId": live_run.run_id if live_run != null else null,
			"durablePath": durable_path,
		})


static func run(fails: Array[String]) -> void:
	_source_contract(fails)
	_indexed_db_ack_contract(fails)
	_coordinator_model_contract(fails)
	_checkpoint_contract(fails)
	_path_binding_contract(fails)
	_last_route_wins_contract(fails)
	_projection_contract(fails)
	SaveService.clear_run("", SAVE_PATH)


static func _source_contract(fails: Array[String]) -> void:
	var main: String = FileAccess.get_file_as_string(MAIN_PATH)
	var seam: String = FileAccess.get_file_as_string(SEAM_PATH)
	if not seam.contains('OS.has_feature("web_dev")'):
		fails.append("web acceptance guard: projection is not restricted to web_dev")
	var publish: String = _function_body(seam, "_publish")
	var guard_at: int = publish.find('OS.has_feature("web_dev")')
	var bridge_at: int = publish.find("_publish_plain(pending)")
	if guard_at < 0 or bridge_at < 0 or guard_at > bridge_at:
		fails.append("web acceptance guard: JavaScriptBridge is reachable before the web_dev guard")
	var publish_plain: String = _function_body(seam, "_publish_plain")
	if not publish_plain.contains("var serialized: String = JSON.stringify(projection)"):
		fails.append("web acceptance bridge: projection is not serialized before JavaScript marshalling")
	if not publish_plain.contains('JavaScriptBridge.get_interface("JSON")'):
		fails.append("web acceptance bridge: JavaScript JSON interface is missing")
	if not publish_plain.contains("window[GLOBAL_NAME] = js_json.parse(serialized)"):
		fails.append("web acceptance bridge: global is not assigned a parsed plain JavaScript object")
	if publish_plain.contains("window.set(") \
			or publish_plain.contains("window[GLOBAL_NAME] = projection_for("):
		fails.append("web acceptance bridge: Dictionary is marshalled directly to the JavaScript global")
	if not seam.contains("SaveService.load_run(content, durable_path)"):
		fails.append("web acceptance durable read: projection does not independently load the save")
	if main.contains("JavaScriptBridge"):
		fails.append("web acceptance boundary: Main accesses JavaScriptBridge directly")
	var ready: String = _function_body(main, "_ready")
	if ready.find('OS.has_feature("web_dev")') < 0 \
			or ready.find('OS.has_feature("web_dev")') > ready.find("WebAcceptance.new()"):
		fails.append("web acceptance allocation: helper exists outside web_dev")
	if not _function_body(main, "_remember_route").contains(
			"_web_acceptance.observe_route(rebuilder, game, content, _run_save_path)"):
		fails.append("web acceptance path: Main does not publish from its live injected save path")
	if not seam.contains('call_deferred("_publish_if_current"'):
		fails.append("web acceptance readiness: projection publishes before route construction returns")
	if not seam.contains("if generation != _publish_generation:"):
		fails.append("web acceptance ordering mutation: stale deferred routes are not rejected")


static func _indexed_db_ack_contract(fails: Array[String]) -> void:
	var seam: String = FileAccess.get_file_as_string(SEAM_PATH)
	var publish: String = _function_body(seam, "_publish")
	var begin_ack: String = _function_body(seam, "_begin_indexed_db_ack")
	var pending_at: int = publish.find("_publish_plain(pending)")
	var ack_at: int = publish.find("_begin_indexed_db_ack(generation)")
	if pending_at < 0 or ack_at < 0 or pending_at > ack_at:
		fails.append("web acceptance IndexedDB ack: current ready=false is not published before sync")
	var process: String = _function_body(seam, "_process")
	var request_at: int = process.find("JavaScriptBridge.force_fs_sync()")
	var await_at: int = process.find("const error = await candidate")
	if request_at < 0 or await_at < 0 or request_at > await_at:
		fails.append("web acceptance IndexedDB ack: coordinated sync is not requested and awaited")
	if seam.contains("FS.syncfs") or seam.contains("GodotFS.sync()"):
		fails.append("web acceptance IndexedDB ack: an uncoordinated sync primitive is used")
	if not begin_ack.contains('typeof GodotFS !== "object"') \
			or not begin_ack.contains('GodotFS.is_persistent() !== 1') \
			or not begin_ack.contains('typeof GodotFS._syncing !== "boolean"') \
			or not begin_ack.contains('typeof GodotOS !== "object"'):
		fails.append("web acceptance IndexedDB ack: runtime sync features are not checked")
	if not process.contains("if (error)"):
		fails.append("web acceptance IndexedDB ack: resolved sync errors are discarded")
	var resolved_at: int = process.find("const error = await candidate")
	var idle_at: int = process.find("while (GodotFS._syncing)", resolved_at)
	if resolved_at < 0 or idle_at < 0 or resolved_at > idle_at:
		fails.append("web acceptance IndexedDB ack: resolved sync is not confirmed idle")
	if not process.contains('resolvedWhileSyncing ? "REQUEST" : "ACK"'):
		fails.append("web acceptance IndexedDB ack: early-resolved sync is not re-requested")
	if not process.contains("attempt < 120") \
			or not process.contains('throw new Error("coordinated sync did not start")'):
		fails.append("web acceptance IndexedDB ack: promise identity poll is not bounded fail-closed")
	if not process.contains("GodotOS.__glassvow_acceptance === state") \
			or not begin_ack.contains("GodotOS.__glassvow_acceptance === state"):
		fails.append("web acceptance IndexedDB ack: overlapping generations are not coalesced")
	if not begin_ack.contains("console.error") or not process.contains("console.error"):
		fails.append("web acceptance IndexedDB ack: sync errors are not reported fail-closed")
	if not process.contains('_publish_plain(ready_dictionary)'):
		fails.append("web acceptance IndexedDB ack: success does not publish ready=true")
	if seam.contains("create_callback"):
		fails.append("web acceptance IndexedDB ack: browser-callable request command is exposed")
	if not seam.contains("JavaScriptBridge.eval(source, false)"):
		fails.append("web acceptance IndexedDB ack: async closure is not evaluated non-globally")
	if not seam.contains("Godot 4.7.1-stable (a13da4feb)"):
		fails.append("web acceptance IndexedDB ack: engine source contract is not pinned")


static func _coordinator_model_contract(fails: Array[String]) -> void:
	var seam: Script = load(SEAM_PATH) as Script
	var state: Dictionary = {"generation": 3, "phase": "WAIT_IDLE", "action": "WAIT"}
	var trace: Array[Dictionary] = [
		{"generation": 1, "token": 1, "settled": true, "syncing": false, "error": ""},
		{"generation": 3, "token": 1, "settled": false, "syncing": true, "error": ""},
		{"generation": 3, "token": 1, "settled": true, "syncing": false, "error": "old"},
		{"generation": 3, "token": 2, "settled": true, "syncing": true, "error": ""},
		{"generation": 3, "token": 2, "settled": true, "syncing": false, "error": ""},
		{"generation": 3, "token": 3, "settled": true, "syncing": false, "error": ""},
	]
	var actions: Array[String] = []
	for snapshot: Dictionary in trace:
		state = seam.call("coordinator_transition", state, snapshot)
		actions.append(str(state.get("action", "WAIT")))
		state["action"] = "WAIT"
	var expected: Array[String] = ["WAIT", "WAIT", "REQUEST", "WAIT", "REQUEST", "WAIT"]
	if actions != expected:
		fails.append("web acceptance coordinator model: stale A or coalesced B/C can publish")
	state = seam.call("coordinator_transition", state,
		{"generation": 3, "token": 3, "settled": true, "syncing": false, "error": ""})
	if state.get("action") != "ACK":
		fails.append("web acceptance coordinator model: stable latest sync does not acknowledge")
	state = {"generation": 4, "phase": "WAIT_SETTLED", "baseline": 3, "action": "WAIT"}
	state = seam.call("coordinator_transition", state,
		{"generation": 4, "token": 4, "settled": true, "syncing": false, "error": "idb"})
	if state.get("action") != "ERROR":
		fails.append("web acceptance coordinator model: stable sync error can acknowledge")


static func _checkpoint_contract(fails: Array[String]) -> void:
	var main_source: String = FileAccess.get_file_as_string(MAIN_PATH)
	if main_source.count("SaveService.store(game.run") != 1:
		fails.append("web acceptance checkpoint: direct run stores do not have one wrapper")
	if main_source.count("_store_run()") != 33:
		fails.append("web acceptance checkpoint: audited run-save boundary count changed")
	var store_run: String = _function_body(main_source, "_store_run")
	if not store_run.contains("var stored: bool = SaveService.store(game.run, _run_save_path)") \
			or not store_run.contains("if stored and _web_acceptance != null:") \
			or not store_run.contains("_web_acceptance.observe_checkpoint("):
		fails.append("web acceptance checkpoint: successful stores do not notify the seam")
	for method: String in ["_on_save_error_choice", "_new_run", "_on_dawn_advance",
			"_on_reward_claimed", "_on_shop_choice", "_on_shop_remove",
			"_on_event_choice"]:
		if _function_body(main_source, method).contains("SaveService.store(game.run"):
			fails.append("web acceptance checkpoint: %s bypasses _store_run" % method)
	var content: ContentDB = ContentDB.load_full()
	var main: Main = Main.new()
	var spy: AcceptanceSpy = AcceptanceSpy.new()
	main.content = content
	main.game = GlassvowGame.new(content, RunState.new_run(content, 15311, "checkpoint-153"))
	main._route_rebuilder = Callable(main, "_show_map")
	main._web_acceptance = spy
	main._run_save_path = SAVE_PATH
	if not main._store_run() or spy.checkpoints != 1:
		fails.append("web acceptance checkpoint behaviour: successful store is not observed once")
	main._run_save_path = "user://missing-153/checkpoint.json"
	if main._store_run() or spy.checkpoints != 1:
		fails.append("web acceptance checkpoint behaviour: failed store was observed")
	main._web_acceptance = null
	spy.free()
	main.free()
	SaveService.clear_run("", SAVE_PATH)

static func _path_binding_contract(fails: Array[String]) -> void:
	var main: Main = Main.new()
	var spy: AcceptanceSpy = AcceptanceSpy.new()
	main._run_save_path = "user://superseded_web_acceptance_run.json"
	main._web_acceptance = spy
	main._run_save_path = SAVE_PATH
	main._remember_route(Callable(main, "_show_title"))
	if spy.observed_path != SAVE_PATH:
		fails.append("web acceptance path: route observation captured a stale save path")
	main._web_acceptance = null
	spy.free()
	main.free()


static func _last_route_wins_contract(fails: Array[String]) -> void:
	var spy: AcceptanceSpy = AcceptanceSpy.new()
	var content: ContentDB = ContentDB.load_full()
	var first: RunState = RunState.new_run(content, 14611, "first-run-146")
	var latest: RunState = RunState.new_run(content, 14612, "latest-run-146")
	spy._queue_publish("map", first, content, "user://first.json")
	spy._queue_publish("combat", latest, content, "user://latest.json")
	spy._publish_if_current(1, "map", first, content, "user://first.json")
	spy._publish_if_current(2, "combat", latest, content, "user://latest.json")
	var expected: Array[Dictionary] = [{
		"route": "combat",
		"liveRunId": "latest-run-146",
		"durablePath": "user://latest.json",
	}]
	if spy.publications != expected:
		fails.append("web acceptance ordering: stale route, run or path reached publication")
	spy.free()


static func _projection_contract(fails: Array[String]) -> void:
	var seam: Script = load(SEAM_PATH) as Script
	if seam == null or not seam.has_method("projection_for"):
		fails.append("web acceptance projection: helper or projection_for is missing")
		return
	var main: Main = Main.new()
	var routes: Dictionary = {
		"_show_title": "title", "_show_embark": "embark", "_show_vigil": "vigil",
		"_show_map": "map", "_show_rest": "rest", "_show_event": "event",
		"_show_treasure": "treasure", "_show_act4_entrance": "act4_entrance",
		"_show_shop": "shop", "_resume_pending_combat": "combat",
		"_show_pending_reward": "pending_reward", "_show_boss_relic": "boss_relic",
		"_show_run_end": "run_end", "_show_dawn": "dawn",
		"_show_monument": "monument", "_show_hollow": "hollow",
		"_show_lamplighter": "lamplighter",
	}
	var route_pattern: RegEx = RegEx.new()
	route_pattern.compile("_remember_route\\((_[a-z0-9_]+)")
	var callsites: Array[String] = []
	for result: RegExMatch in route_pattern.search_all(
			FileAccess.get_file_as_string(MAIN_PATH)):
		callsites.append(result.get_string(1))
	callsites.sort()
	var expected_callsites: Array = routes.keys()
	expected_callsites.sort()
	if callsites != expected_callsites:
		fails.append("web acceptance route: remembered constructors are not exhaustively audited")
	for method: String in routes:
		var callable: Callable = Callable(main, method)
		if method == "_show_vigil":
			callable = callable.bind(true)
		if seam.call("canonical_route", callable) != routes[method]:
			fails.append("web acceptance route: %s is not canonical" % method)
	main.free()
	var content: ContentDB = ContentDB.load_full()
	var live: RunState = RunState.new_run(content, 14601, "live-run-146")
	var durable: RunState = RunState.new_run(content, 14602, "durable-run-146")
	durable.player.gold = 146
	if not SaveService.store(durable, SAVE_PATH):
		fails.append("web acceptance fixture: durable run could not be stored")
		return
	var projection: Dictionary = seam.call(
		"projection_for", "map", live, content, SAVE_PATH)
	var keys: Array = projection.keys()
	keys.sort()
	var expected_keys: Array = [
		"durableRunId", "durableSaveSha256", "liveRunId",
		"ready", "route", "schemaVersion",
	]
	if keys != expected_keys:
		fails.append("web acceptance schema: projection keys are not exact: %s" % [keys])
	if projection.get("schemaVersion") != 1 \
			or projection.get("ready") != true or projection.get("route") != "map":
		fails.append("web acceptance schema: version, readiness or canonical route is wrong")
	if projection.get("liveRunId") != "live-run-146" \
			or projection.get("durableRunId") != "durable-run-146":
		fails.append("web acceptance durable read: live and independently loaded run IDs collapsed")
	var expected_loaded: RunState = SaveService.load_run(content, SAVE_PATH)
	var expected_digest: String = JSON.stringify(expected_loaded.to_save_dict()).sha256_text()
	if projection.get("durableSaveSha256") != expected_digest:
		fails.append("web acceptance durable read: digest is not the loaded canonical v2 save projection")
	SaveService.clear_run("", SAVE_PATH)
	var empty_projection: Dictionary = seam.call(
		"projection_for", "title", null, content, SAVE_PATH)
	if empty_projection.get("liveRunId", "missing") != null \
			or empty_projection.get("durableRunId", "missing") != null \
			or empty_projection.get("durableSaveSha256", "missing") != null:
		fails.append("web acceptance nulls: missing live or durable state is not explicit")


static func _function_body(source: String, function_name: String) -> String:
	var start: int = source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)
