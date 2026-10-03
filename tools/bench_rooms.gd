extends SceneTree
## Frame times for the title's rooms (#655 PR B, docs/design/2026-10-03-title-
## rooms §11.6). Boots the real Main on the Development profile of the
## checkout's isolated user dir (a saved run, as a returning player has),
## waits for the title to rest, measures it at rest, then for each room taps
## its word, holds in it and taps its Return, LAPS times, as a player does,
## through the engine's own input path. Every drawn frame is a row:
##
##   {"nonce", "label", "room", "lap", "phase": title|open|room|close, "i": the
##    frame's index from the tap (0 is the tap frame), "wall_ms" (from the last
##    frame's draw), "busy_ms" (the frame's own work, from its process step to
##    its draw: the number that compares when the wall is display-bound),
##    "cpu_ms" and "gpu_ms" (the viewport's measured render times)}
##
## and the run ends with one summary row per room: tap to first moved frame
## (from the tap to the tap frame's draw: the passage takes its first step in
## the tap frame's own process, after the input that opened it, and a capture
## at --fixed-fps 60 shows the veil darkening the stage by 6% on that frame),
## the tap frame, the passage's other frames (P95 and max), and the room at
## rest against the title at rest (P95, wall and CPU). The first lap of each
## room is the first opening this session (cold pipelines after an install),
## reported apart. On the Mac the wall interval is display-bound: the CPU and
## GPU render times are the comparable numbers.
##
##   GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --path . --position 40,40 \
##       --rendering-driver metal -s res://tools/bench_rooms.gd -- \
##       --shape=pad-landscape --locale=en --laps=20 --rest=5 --out=/abs/rows.jsonl
##
## On the iPad the `Bench` node below runs inside the QA app, attached to Main
## by a QA-only patch that never ships (kept beside the rows as evidence).
## Never --headless: a headless run draws nothing.

var _main: Main
var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var at: int = arg.find("=")
		_args[arg.substr(2, at - 2) if at > 0 else arg.trim_prefix("--")] = arg.substr(at + 1) if at > 0 else "true"
	var shape: StringName = StringName(str(_args.get("shape", "pad-landscape")))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
	DisplayServer.window_set_size(stage)
	Bench.seed_saved_run()
	_main = (load("res://application/main.tscn") as PackedScene).instantiate() as Main
	_main._boot_args = PackedStringArray(["--shape=%s" % shape, "--locale=%s" % str(_args.get("locale", "en"))])
	root.add_child(_main)
	_start.call_deferred()


func _start() -> void:
	for _i: int in range(4):
		await process_frame
	var preferences: Preferences = Preferences.new()
	preferences.language = str(_args.get("locale", "en"))
	preferences.diagnostics_notice_seen = true
	Preferences.active = preferences
	_main._title_kindled = true
	_main._show_title()
	var bench: Bench = Bench.new()
	bench.main = _main
	bench.laps = int(str(_args.get("laps", "20")))
	bench.room_rest = float(str(_args.get("rest", "5")))
	bench.title_rest = float(str(_args.get("title-rest", "5")))
	bench.hold = float(str(_args.get("hold", "1")))
	bench.label = "mac-%s-%s" % [str(_args.get("shape", "pad-landscape")), str(_args.get("locale", "en"))]
	bench.nonce = str(_args.get("nonce", "mac"))
	bench.out_path = str(_args.get("out", "user://bench_rooms.jsonl"))
	bench.done.connect(func() -> void: quit(0))
	_main.add_child(bench)


## The bench itself: a Node, so the QA app can attach it to its own Main.
class Bench extends Node:
	signal done

	const ROOMS: Array[String] = ["settings", "help", "credits"]
	const TAP_WAIT: float = 3.0

	var main: Main
	var laps: int = 10
	## Seconds held in a room on its first lap (the room at rest), and on every lap.
	var room_rest: float = 30.0
	var hold: float = 3.0
	var title_rest: float = 30.0
	var label: String = "ipad"
	var nonce: String = ""
	var out_path: String = "user://bench_rooms.jsonl"
	var _file: FileAccess = null
	var _rows: Array[Dictionary] = []
	var _last_us: int = 0
	var _start_us: int = 0
	var _tap_us: int = 0
	var _room: String = ""
	var _lap: int = 0
	var _phase: String = ""
	var _index: int = 0
	## The tap's passage, armed at the release until the frame that acts on it.
	var _armed: String = ""
	var _viewport_rid: RID

	## A run in Act II in the Development profile: the title a returning player
	## sees (Back to the Road), before Main reads it.
	static func seed_saved_run() -> void:
		var content: ContentDB = ContentDB.load_full()
		var run: RunState = RunState.new_run(content, 65503, "bench-rooms")
		run.map = WorldMap.benchmark(run).to_dict()
		run.act = 1
		run.waystones_lit = 4
		SaveService.store(run, ScenarioKernel.RUN_PATH)
		var vigil: VigilState = VigilState.blank()
		vigil.scenes_seen.append("opening")
		vigil.runs_played = 3
		vigil.deeds["runs"] = 3
		SaveService.store_vigil(vigil, ScenarioKernel.VIGIL_PATH)

	func _ready() -> void:
		name = "RoomsBench"
		process_mode = Node.PROCESS_MODE_ALWAYS
		_file = FileAccess.open(out_path, FileAccess.WRITE)
		_viewport_rid = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
		RenderingServer.frame_post_draw.connect(_on_drawn)
		get_tree().process_frame.connect(func() -> void: _start_us = Time.get_ticks_usec())
		_write({"nonce": nonce, "label": label, "args": " ".join(OS.get_cmdline_user_args()),
			"start": Time.get_datetime_string_from_system()})
		_run.call_deferred()

	func _run() -> void:
		await _title_at_rest()
		_phase = "title"
		_room = ""
		_index = 0
		await _seconds(title_rest)
		for room: String in ROOMS:
			for lap: int in range(laps):
				_room = room
				_lap = lap
				await _tour(room, lap)
		_phase = ""
		_summarise()
		_write({"nonce": nonce, "probe": "done"})
		if _file != null:
			_file.flush()
		done.emit()

	func _title_at_rest() -> void:
		while not (main._choice_screen is TitleScreen):
			await get_tree().process_frame
		var title: TitleScreen = main._choice_screen
		while title.rite != null and not title.rite.is_done():
			await get_tree().process_frame
		await _seconds(2.0)

	## One lap: the word tapped, the room held, its Return tapped.
	func _tour(room: String, lap: int) -> void:
		var title: TitleScreen = main._choice_screen as TitleScreen
		var word: Control = title.word(room) if title != null else null
		if word == null:
			return
		await _tap(word.get_global_rect().get_center(), "open")
		var host: LeadlightRoomHost = main._modal as LeadlightRoomHost
		await _seconds((host.arrival_time() if host != null else 0.6) + 0.2)
		_phase = "room"
		_index = 0
		await _seconds(room_rest if lap == 0 else hold)
		host = main._modal as LeadlightRoomHost
		if host != null:
			await _tap(host.seat().word().get_global_rect().get_center(), "close")
			await _seconds(host.departure_time() + 0.2)
		_phase = "between"
		await _seconds(0.6)

	## A finger down, a frame, a finger up: the tap is timed from the release,
	## which is when a button acts. The engine flushes the event at the start of
	## the next frame; the tap frame (i 0) is the frame the room appears or
	## leaves on, found by the modal changing (`_process`). `at` is a stage
	## point: an input event arrives in the window's pixels, which a device
	## scales from the stage (the iPad 8 draws 1180×885 into 2160×1620). A tap
	## that has not acted in TAP_WAIT seconds is recorded and the lap goes on.
	## The release is parsed in a frame's process step and waits out the rest
	## of that frame (on iOS nearly a whole one, its present wait inside the
	## draw): the worst case, where a real finger lifts at any moment.
	func _tap(at: Vector2, phase: String) -> void:
		var screen: Vector2 = get_viewport().get_screen_transform() * at
		for pressed: bool in [true, false]:
			var touch: InputEventScreenTouch = InputEventScreenTouch.new()
			touch.index = 0
			touch.position = screen
			touch.pressed = pressed
			if not pressed:
				_armed = phase
				_tap_us = Time.get_ticks_usec()
			Input.parse_input_event(touch)
			await get_tree().process_frame
		var until: int = Time.get_ticks_msec() + roundi(TAP_WAIT * 1000.0)
		while not _armed.is_empty() and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		if not _armed.is_empty():
			_write({"nonce": nonce, "label": label, "room": _room, "lap": _lap, "error": "tap did not act",
				"phase": _armed, "at": [at.x, at.y], "screen": [screen.x, screen.y]})
			_armed = ""

	func _process(_delta: float) -> void:
		var acted: bool = (_armed == "open" and main._modal is LeadlightRoomHost) \
			or (_armed == "close" and main._modal == null)
		if acted:
			_phase = _armed
			_index = 0
			_armed = ""

	func _seconds(span: float) -> void:
		var until: int = Time.get_ticks_msec() + roundi(span * 1000.0)
		while Time.get_ticks_msec() < until:
			await get_tree().process_frame

	func _on_drawn() -> void:
		var now: int = Time.get_ticks_usec()
		if _last_us > 0 and _phase in ["title", "open", "room", "close"]:
			var row: Dictionary = {"nonce": nonce, "label": label, "room": _room, "lap": _lap,
				"phase": _phase, "i": _index, "wall_ms": float(now - _last_us) / 1000.0,
				"busy_ms": float(now - _start_us) / 1000.0,
				"cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid),
				"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid)}
			if _index <= 1 and (_phase == "open" or _phase == "close"):
				row["since_tap_ms"] = float(now - _tap_us) / 1000.0
			_rows.append(row)
			_write(row)
		_index += 1
		_last_us = now

	func _write(row: Dictionary) -> void:
		if _file != null:
			_file.store_line(JSON.stringify(row))

	## The §11.6 rows, per room: first lap apart from the rest.
	func _summarise() -> void:
		var title_wall: Array[float] = _pick("", "title", "wall_ms", false)
		var title_cpu: Array[float] = _pick("", "title", "cpu", false)
		for room: String in ROOMS:
			for first: bool in [true, false]:
				var out: Dictionary = {"nonce": nonce, "label": label, "summary": room,
					"laps": "first" if first else "rest"}
				var taps: Array[float] = []
				var tap_frames: Array[float] = []
				for row: Dictionary in _rows:
					if row["room"] != room or (_i(row, "lap") == 0) != first or row["phase"] != "open":
						continue
					if _i(row, "i") == 0:
						tap_frames.append(_f(row, "wall_ms"))
						taps.append(_f(row, "since_tap_ms"))
				out["tap_to_moved_ms"] = _stats(taps)
				out["tap_frame_ms"] = _stats(tap_frames)
				var passage: Array[float] = []
				for phase: String in ["open", "close"]:
					for row: Dictionary in _rows:
						if row["room"] == room and (_i(row, "lap") == 0) == first and row["phase"] == phase \
								and _i(row, "i") >= 1:
							passage.append(_f(row, "wall_ms"))
				out["passage_ms"] = _stats(passage)
				out["passage_cpu_ms"] = _stats(_pick(room, "open", "cpu", first) + _pick(room, "close", "cpu", first))
				if first:
					out["rest_wall_ms"] = _stats(_pick(room, "room", "wall_ms", true))
					out["rest_cpu_ms"] = _stats(_pick(room, "room", "cpu", true))
					out["title_rest_wall_ms"] = _stats(title_wall)
					out["title_rest_cpu_ms"] = _stats(title_cpu)
				_write(out)
				print(JSON.stringify(out))

	## A field of the rows of `room` (any, when empty) in `phase`; "cpu" is the
	## process and render CPU together.
	func _pick(room: String, phase: String, field: String, first: bool) -> Array[float]:
		var values: Array[float] = []
		for row: Dictionary in _rows:
			if row["phase"] != phase or (not room.is_empty() and row["room"] != room):
				continue
			if phase != "title" and (_i(row, "lap") == 0) != first:
				continue
			if phase != "room" and phase != "title" and _i(row, "i") < 1:
				continue
			var proc: float = row["busy_ms"]
			var render: float = row["cpu_ms"]
			var value: float = proc + render
			if field != "cpu":
				value = row[field]
			values.append(value)
		return values

	static func _stats(values: Array[float]) -> Dictionary:
		if values.is_empty():
			return {"n": 0}
		var sorted: Array[float] = values.duplicate()
		sorted.sort()
		return {"n": sorted.size(), "p50": snappedf(_quantile(sorted, 0.5), 0.01),
			"p95": snappedf(_quantile(sorted, 0.95), 0.01), "max": snappedf(sorted[sorted.size() - 1], 0.01)}

	static func _f(row: Dictionary, key: String) -> float:
		var value: float = row.get(key, 0.0)
		return value

	static func _i(row: Dictionary, key: String) -> int:
		var value: int = row.get(key, 0)
		return value

	static func _quantile(sorted: Array[float], q: float) -> float:
		return sorted[clampi(ceili(q * float(sorted.size())) - 1, 0, sorted.size() - 1)]
