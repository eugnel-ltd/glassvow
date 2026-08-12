class_name WebAcceptance
extends Node
## Read-only Web Dev projection for the browser acceptance run. This object
## owns the complete JavaScript boundary; production exports never publish it.

const SCHEMA_VERSION: int = 1
const GLOBAL_NAME: String = "glassvowAcceptance"

var _publish_generation: int = 0
var _ready_json: String = ""
var _last_route: String = ""


func observe_route(rebuilder: Callable, game: GlassvowGame, content: ContentDB,
		durable_path: String) -> void:
	if not OS.has_feature("web_dev"):
		return
	var live_run: RunState = game.run if game != null else null
	_last_route = canonical_route(rebuilder)
	_queue_publish(_last_route, live_run, content, durable_path)


func observe_checkpoint(rebuilder: Callable, game: GlassvowGame, content: ContentDB,
		durable_path: String) -> void:
	if not OS.has_feature("web_dev"):
		return
	var live_run: RunState = game.run if game != null else null
	_publish_generation += 1
	var route: String = canonical_route(rebuilder) if rebuilder.is_valid() else _last_route
	_publish_if_current(_publish_generation, route, live_run, content, durable_path)


func _queue_publish(route: String, live_run: RunState, content: ContentDB,
		durable_path: String) -> void:
	_publish_generation += 1
	call_deferred("_publish_if_current", _publish_generation,
		route, live_run, content, durable_path)


func _publish_if_current(generation: int, route: String, live_run: RunState,
		content: ContentDB, durable_path: String) -> void:
	if generation != _publish_generation:
		return
	_publish(route, live_run, content, durable_path)


static func canonical_route(rebuilder: Callable) -> String:
	var method: String = String(rebuilder.get_method())
	if method.begins_with("_show_"):
		return method.trim_prefix("_show_")
	if method.begins_with("_resume_pending_"):
		return method.trim_prefix("_resume_pending_")
	return method.trim_prefix("_")


static func projection_for(route: String, live_run: RunState, content: ContentDB,
		durable_path: String = SaveService.RUN_PATH) -> Dictionary:
	var durable_run: RunState = SaveService.load_run(content, durable_path)
	var durable_json: Variant = null
	if durable_run != null:
		durable_json = JSON.stringify(durable_run.to_save_dict())
	return {
		"schemaVersion": SCHEMA_VERSION,
		"ready": true,
		"route": route,
		"liveRunId": live_run.run_id if live_run != null else null,
		"durableRunId": durable_run.run_id if durable_run != null else null,
		"durableSaveSha256": str(durable_json).sha256_text()
			if durable_json != null else null,
	}


func _publish(route: String, live_run: RunState, content: ContentDB,
		durable_path: String) -> void:
	if not OS.has_feature("web_dev"):
		return
	var generation: int = _publish_generation
	var pending: Dictionary = projection_for(route, live_run, content, durable_path)
	pending["ready"] = false
	var ready: Dictionary = pending.duplicate(true)
	ready["ready"] = true
	_publish_plain(pending)
	_ready_json = JSON.stringify(ready)
	_begin_indexed_db_ack(generation)
	set_process(true)


func _publish_plain(projection: Dictionary) -> void:
	var serialized: String = JSON.stringify(projection)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var js_json: JavaScriptObject = JavaScriptBridge.get_interface("JSON")
	if window != null and js_json != null:
		window[GLOBAL_NAME] = js_json.parse(serialized)


func _begin_indexed_db_ack(generation: int) -> void:
	var source: String = """
(() => {
	if (typeof GodotOS !== "object") {
		console.error("Glassvow IndexedDB acceptance sync failed: GodotOS is unavailable");
		return;
	}
	const state = GodotOS.__glassvow_acceptance = {
		generation: %d, status: "WAIT", baseline: GodotOS._fs_sync_promise, error: ""
	};
	(async () => {
		try {
			if (typeof GodotFS !== "object" || typeof GodotFS.is_persistent !== "function" ||
					GodotFS.is_persistent() !== 1 || typeof GodotFS._syncing !== "boolean") {
				throw new Error("Godot IndexedDB sync API is unavailable");
			}
			if (state.baseline != null && typeof state.baseline.then === "function") {
				await state.baseline;
			}
			for (let attempt = 0; attempt < 120 && GodotFS._syncing; attempt += 1)
				await new Promise((resolve) => requestAnimationFrame(resolve));
			if (GodotFS._syncing) throw new Error("IndexedDB sync did not become idle");
			if (GodotOS.__glassvow_acceptance === state) state.status = "REQUEST";
		} catch (error) {
			state.error = error instanceof Error ? error.message : String(error);
			state.status = "ERROR";
			console.error("Glassvow IndexedDB acceptance sync failed: " + state.error);
		}
	})();
})();
""" % generation
	JavaScriptBridge.eval(source, false)
	# Godot 4.7.1-stable (a13da4feb): force_fs_sync only requests OS_Web's
	# coordinated main-loop sync. Its distinct GodotOS promise is the ack.


static func coordinator_action(snapshot: Dictionary, generation: int) -> String:
	if str(snapshot.get("generation", -1)).to_int() != generation:
		return "WAIT"
	var status: String = str(snapshot.get("status", "ERROR"))
	if status in ["REQUEST", "ACK", "ERROR"]:
		return status
	return "WAIT"


static func coordinator_transition(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(snapshot.get("generation", -1)).to_int() != str(state.get("generation", -2)).to_int():
		next["action"] = "WAIT"
		return next
	match str(state.get("phase", "WAIT_IDLE")):
		"WAIT_IDLE":
			if snapshot.get("settled", false) == true and not snapshot.get("syncing", true) == true:
				next["phase"] = "WAIT_NEW"
				next["baseline"] = str(snapshot.get("token", 0)).to_int()
				next["action"] = "REQUEST"
		"WAIT_NEW":
			if str(snapshot.get("token", 0)).to_int() != str(state.get("baseline", 0)).to_int():
				next["phase"] = "WAIT_SETTLED"
				next["saw_syncing"] = snapshot.get("syncing", false) == true
		"WAIT_SETTLED":
			if snapshot.get("settled", false) == true:
				if snapshot.get("syncing", false) == true:
					next["saw_syncing"] = true
				elif snapshot.get("saw_syncing", false) == true \
						or state.get("saw_syncing", false) == true:
					next["phase"] = "WAIT_IDLE"
				elif str(snapshot.get("error", "")) != "":
					next["action"] = "ERROR"
				else:
					next["action"] = "ACK"
	return next


func _process(_delta: float) -> void:
	var serialized: Variant = JavaScriptBridge.eval(
		"typeof GodotOS === 'object' && GodotOS.__glassvow_acceptance"
		+ " ? JSON.stringify(GodotOS.__glassvow_acceptance)"
		+ " : '{\"generation\":-1,\"status\":\"ERROR\"}'", false)
	var parsed: Variant = JSON.parse_string(str(serialized))
	var snapshot: Dictionary = parsed if parsed is Dictionary else {}
	match coordinator_action(snapshot, _publish_generation):
		"REQUEST":
			JavaScriptBridge.eval("""
(() => {
	const state = GodotOS.__glassvow_acceptance;
	state.status = "SYNCING";
	state.baseline = GodotOS._fs_sync_promise;
})();
""", false)
			JavaScriptBridge.force_fs_sync()
			JavaScriptBridge.eval("""
(async () => {
	const state = GodotOS.__glassvow_acceptance;
	try {
		let candidate = null;
		for (let attempt = 0; attempt < 120; attempt += 1) {
			candidate = GodotOS._fs_sync_promise;
			if (candidate !== state.baseline && candidate != null &&
					typeof candidate.then === "function") break;
			await new Promise((resolve) => requestAnimationFrame(resolve));
		}
		if (candidate === state.baseline) throw new Error("coordinated sync did not start");
		const error = await candidate;
		const resolvedWhileSyncing = GodotFS._syncing;
		while (GodotFS._syncing) await new Promise((resolve) => requestAnimationFrame(resolve));
		if (error) throw new Error("acceptance sync failed: " + error);
		if (GodotOS.__glassvow_acceptance === state)
			state.status = resolvedWhileSyncing ? "REQUEST" : "ACK";
	} catch (error) {
		state.error = error instanceof Error ? error.message : String(error);
		state.status = "ERROR";
		console.error("Glassvow IndexedDB acceptance sync failed: " + state.error);
	}
})();
""", false)
		"ACK":
			var ready_projection: Variant = JSON.parse_string(_ready_json)
			if ready_projection is Dictionary:
				var ready_dictionary: Dictionary = ready_projection
				_publish_plain(ready_dictionary)
			set_process(false)
		"ERROR":
			set_process(false)
