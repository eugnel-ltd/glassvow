extends SceneTree
## Frame-time probe for the #577 lantern flame: the flame lab (the production
## combat HUD, lit through `HudBar.show_flame`) at one shape, with the flame on
## or off, uncapped. A component diagnostic for the HUD's budget, not release
## evidence.
##
##   godot --path . -s res://tools/bench_flame.gd -- --shape=phone-landscape \
##       --scale=3 --flame=on --pose=true-lantern --inspect=off [--stress=100]
##
## FlameLab reads its own arguments (--shape, --flame, --pose, --inspect); this probe
## sizes the window to the shape's stage at --scale, turns vsync off, lets the
## lab settle, then samples. It reports the MEDIAN and p95, never the mean, of
## the whole-frame interval (uncapped, so not quantised by presentation), the
## window's CPU render time and the frame's CPU setup time. The window's GPU
## timer is printed too; Metal reports a flat zero, and that zero is not free.
##
## `--stress=N` adds N more HUD-sized lanterns carrying the same material (or
## none, with --flame=off), so the cost of N flames stands clear of the noise
## and one flame's is the difference over N.
##
## Not a test: `tests/run_all.gd` never discovers it. Never run it --headless;
## the dummy renderer measures nothing.

const WARMUP_FRAMES: int = 240
const WARMUP_SECONDS: float = 3.0
const SAMPLE_FRAMES: int = 1200

var _args: Dictionary = {}
var _lab: FlameLab
var _frame: int = 0
var _started_us: int = 0
var _last_us: int = 0
var _wall: Array[float] = []
var _cpu: Array[float] = []
var _setup: Array[float] = []
var _gpu: Array[float] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[pair[0]] = pair[1] if pair.size() > 1 else ""
	var shape: StringName = StringName(str(_args.get("shape", StageShape.IDENTITY)))
	var stage: Vector2i = StageShape.REFERENCES.get(shape, StageShape.REFERENCES[StageShape.IDENTITY])
	var scale: int = maxi(1, int(str(_args.get("scale", "1"))))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = stage
	DisplayServer.window_set_size(stage * scale)
	_lab = FlameLab.new()
	root.add_child(_lab)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_started_us = Time.get_ticks_usec()


## N more lanterns, each the HUD's art at the HUD's size for this shape, in a
## grid over the stage. They carry the lab's one material, so they burn the
## same reading the HUD lantern does. Called on the first frame: the lab builds
## its HUD in `_ready`, which a SceneTree script's `_initialize` runs before.
func _add_stress(n: int) -> void:
	var art: TextureRect = _lab.hud_lantern_art()
	var side: float = art.get_global_rect().size.x
	if side < 8.0:
		printerr("bench_flame: the HUD lantern has no size yet (%s)" % side)
		quit(1)
		return
	print("bench_flame: %d stress lantern(s), %.1f stage px each" % [n, side])
	var stage: Vector2 = Vector2(root.content_scale_size)
	var cols: int = maxi(1, int(stage.x / side))
	for i: int in range(n):
		var lantern: TextureRect = TextureRect.new()
		lantern.texture = art.texture
		lantern.texture_filter = art.texture_filter
		lantern.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lantern.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lantern.size = Vector2(side, side)
		lantern.position = Vector2(float(i % cols), float(i / cols % int(stage.y / side))) * side
		lantern.material = art.material
		_lab.add_child(lantern)


func _process(_delta: float) -> bool:
	_frame += 1
	var stress: int = int(str(_args.get("stress", "0")))
	if _frame == 2 and stress > 0:
		_add_stress(stress)
	var now_us: int = Time.get_ticks_usec()
	if _frame <= WARMUP_FRAMES or float(now_us - _started_us) < WARMUP_SECONDS * 1000000.0:
		_last_us = now_us
		return false
	var rid: RID = root.get_viewport_rid()
	_wall.append(float(now_us - _last_us) / 1000.0)
	_last_us = now_us
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_setup.append(RenderingServer.get_frame_setup_time_cpu())
	if _wall.size() < SAMPLE_FRAMES:
		return false
	var report: Dictionary = {
		"shape": str(_args.get("shape", StageShape.IDENTITY)),
		"window": "%dx%d" % [root.size.x, root.size.y],
		"flame": str(_args.get("flame", "on")), "stress": int(str(_args.get("stress", "0"))),
		"frames": _wall.size(), "adapter": RenderingServer.get_video_adapter_name(),
	}
	_summarise(report, "wall", _wall)
	_summarise(report, "cpu", _cpu)
	_summarise(report, "setup", _setup)
	_summarise(report, "gpu", _gpu)
	print("BENCH " + JSON.stringify(report))
	return true


func _summarise(report: Dictionary, key: String, samples: Array[float]) -> void:
	var values: Array[float] = samples.duplicate()
	values.sort()
	report[key + "_med"] = snappedf(values[values.size() / 2], 0.0001)
	report[key + "_p95"] = snappedf(values[int(float(values.size()) * 0.95)], 0.0001)
