extends SceneTree
## Frame-time probe for the title (docs/design/2026-10-02-opening-start §12):
## boots the production Main (so the same script measures any tree's title,
## before and after), uncapped, and reports the median and p95 — never the
## mean — of the whole-frame interval, the window's CPU render time and the
## frame's CPU setup time.
##
##   GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --path . --rendering-driver metal \
##       -s res://tools/bench_title.gd -- --shape=pad-landscape --phase=rest
##
## --phase=rest samples after a warm-up long enough to outlast the launch rite;
## --phase=rite samples the first 2.4 s from the first frame, rite and all.
## --vsync paces frames to the display as the game does (the rite's
## acceptance: no frame over 20 ms after the first); --rows=PATH writes every
## sampled frame as "index ms_since_start wall_ms" for a frame-time plot.
## Not a test; never run it --headless (the dummy renderer measures nothing).
## The boot carries arguments, so it runs on the Development profile.

const WARMUP_SECONDS: float = 4.0
const SAMPLE_FRAMES: int = 1500
const RITE_SECONDS: float = 2.4

var _args: Dictionary = {}
var _frame: int = 0
var _started_us: int = 0
var _last_us: int = 0
var _wall: Array[float] = []
var _cpu: Array[float] = []
var _setup: Array[float] = []
var _at: Array[float] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[pair[0]] = pair[1] if pair.size() > 1 else ""
	var shape: StringName = StringName(str(_args.get("shape", StageShape.IDENTITY)))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	DisplayServer.window_set_vsync_mode(_vsync())
	Engine.max_fps = 0
	DisplayServer.window_set_size(stage)
	var main: Node = (load("res://application/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_started_us = Time.get_ticks_usec()
	_last_us = _started_us


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame <= 2:
		# Main applies the player's vsync preference in its `_ready`; an
		# uncapped probe re-asserts its own setting once Main is up.
		DisplayServer.window_set_vsync_mode(_vsync())
	var now_us: int = Time.get_ticks_usec()
	var elapsed: float = float(now_us - _started_us) / 1000000.0
	var rite: bool = str(_args.get("phase", "rest")) == "rite"
	if not rite and elapsed < WARMUP_SECONDS:
		_last_us = now_us
		return false
	var rid: RID = root.get_viewport_rid()
	_wall.append(float(now_us - _last_us) / 1000.0)
	_at.append(float(now_us - _started_us) / 1000.0)
	_last_us = now_us
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_setup.append(RenderingServer.get_frame_setup_time_cpu())
	var done: bool = elapsed >= RITE_SECONDS if rite else _wall.size() >= SAMPLE_FRAMES
	if not done:
		return false
	var report: Dictionary = {
		"phase": "rite" if rite else "rest",
		"shape": str(_args.get("shape", StageShape.IDENTITY)),
		"window": "%dx%d" % [root.size.x, root.size.y],
		"frames": _wall.size(), "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
	}
	_summarise(report, "wall", _wall)
	_summarise(report, "cpu", _cpu)
	_summarise(report, "setup", _setup)
	# Interval 0 is the boot; interval 1 holds frame 0's render, where the
	# pipelines compile behind the splash (frame 0 IS the splash image). The
	# rite's acceptance counts every frame after that one.
	var after_first: Array[float] = _wall.slice(2)
	after_first.sort()
	report["wall_max_after_first"] = snappedf(after_first[after_first.size() - 1], 0.0001) \
		if not after_first.is_empty() else 0.0
	report["over_20ms_after_first"] = after_first.filter(func(ms: float) -> bool: return ms > 20.0).size()
	print("BENCH " + JSON.stringify(report))
	var rows_path: String = str(_args.get("rows", ""))
	if not rows_path.is_empty():
		var rows: FileAccess = FileAccess.open(rows_path, FileAccess.WRITE)
		if rows != null:
			for i: int in _wall.size():
				rows.store_line("%d %.2f %.3f" % [i, _at[i], _wall[i]])
	return true


func _vsync() -> DisplayServer.VSyncMode:
	return DisplayServer.VSYNC_ENABLED if _args.has("vsync") else DisplayServer.VSYNC_DISABLED


func _summarise(report: Dictionary, key: String, samples: Array[float]) -> void:
	var values: Array[float] = samples.duplicate()
	values.sort()
	report[key + "_med"] = snappedf(values[values.size() / 2], 0.0001)
	report[key + "_p95"] = snappedf(values[int(float(values.size()) * 0.95)], 0.0001)
	report[key + "_max"] = snappedf(values[values.size() - 1], 0.0001)
