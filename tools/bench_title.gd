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


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[pair[0]] = pair[1] if pair.size() > 1 else ""
	var shape: StringName = StringName(str(_args.get("shape", StageShape.IDENTITY)))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_size(stage)
	var main: Node = (load("res://application/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_started_us = Time.get_ticks_usec()
	_last_us = _started_us


func _process(_delta: float) -> bool:
	_frame += 1
	var now_us: int = Time.get_ticks_usec()
	var elapsed: float = float(now_us - _started_us) / 1000000.0
	var rite: bool = str(_args.get("phase", "rest")) == "rite"
	if not rite and elapsed < WARMUP_SECONDS:
		_last_us = now_us
		return false
	var rid: RID = root.get_viewport_rid()
	_wall.append(float(now_us - _last_us) / 1000.0)
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
	print("BENCH " + JSON.stringify(report))
	return true


func _summarise(report: Dictionary, key: String, samples: Array[float]) -> void:
	var values: Array[float] = samples.duplicate()
	values.sort()
	report[key + "_med"] = snappedf(values[values.size() / 2], 0.0001)
	report[key + "_p95"] = snappedf(values[int(float(values.size()) * 0.95)], 0.0001)
	report[key + "_max"] = snappedf(values[values.size() - 1], 0.0001)
