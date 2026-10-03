extends Node
## Map trace probe (developer tool; never shipped: `tools/map_*` is excluded from
## every store preset). It holds the map's rest in one mode or several so frame
## intervals can be read in the game and a Metal System Trace can be recorded
## from outside over a steady state; it can also photograph the map.
##
## Not wired into `application/main.gd`: `tools/map_trace/qa_patch.py` copies it
## into a measuring worktree as `tools/qa_map_trace_probe.gd` (a name the store
## presets pack, so a QA build carries it) and adds the two flags below to that
## worktree's `main.gd`. See docs/dev-tools.md, "Map trace".
##
##   --map --map-trace-probe [--map-lean] [--map-steps=2] --seed=1 --shape=pad-landscape
##
## User arguments:
##   --probe-nonce=<n>      echoed in every row; a batch keeps only its own rows
##   --holds=cadence,live,walk   the modes to hold, in order (default cadence):
##                          cadence = the production rest (the stage every second
##                          frame); live = every view of the map rendered every
##                          frame, forced after every other script's _process
##                          (WorldMapScreen puts a still map back to rest each
##                          frame, so `set_live(true)` alone does not hold);
##                          walk = the pilgrim's walk to the lowest-numbered open
##                          waystone, as a tap on it starts it, held for the
##                          walk's frames (not the arrival frame, which builds
##                          the room the walk opens); that room ends the run,
##                          so hold it last
##   --hold-frames=<n>      frames per rest hold (default 600)
##   --linger=<s>           seconds to stay at the cadence rest after the holds,
##                          for a device screenshot (default 0)
##   --probe-view=whole|river   frame Whole act, or the ravine, before holding
##   --probe-grain=off      take the map's grain off (and the TransitionLayer's)
##   --probe-rm             Reduce Motion, in memory only (nothing is saved)
##   --probe-shot=<png>     photograph the settled map, print PINS, and quit
##   --probe-seq=<n>        with --probe-shot, photograph n frames in a row
##                          (<png> becomes <png>-NN.png) with their times
##   --trace-kill=<what>    hide one part for the whole run: shadows, kit,
##                          ground, land, glow, band, grain, display, hud
## Rows go to user://trace_probe.jsonl (flushed per row) and to stdout with the
## prefix TRACE_PROBE. The start row carries BUILD, the commit `qa_patch.py`
## stamps in when it arms a measuring worktree ("+dirty" when tracked files
## other than the armed `main.gd` differ from it), so every row names its build.

const BUILD: String = "unstamped"
const ROW_PATH: String = "user://trace_probe.jsonl"
const WALK_FRAMES_MAX: int = 3000
const SETTLE_FRAMES: int = 180
const MISSED_MS: float = 25.0

var _host: Node = null
var _rows: FileAccess = null
var _scene: MapScene = null
var _force_live: bool = false


func _ready() -> void:
	process_priority = 1000
	_host = get_parent()
	_rows = FileAccess.open(ROW_PATH, FileAccess.WRITE)
	_row({"probe": "start", "build": BUILD, "adapter": RenderingServer.get_video_adapter_name(),
		"method": RenderingServer.get_current_rendering_method(),
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"args": OS.get_cmdline_user_args()})
	if _flag("--probe-rm"):
		Preferences.active.reduce_motion = true
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.substr(name.length() + 1)
	return fallback


func _flag(name: String) -> bool:
	return name in OS.get_cmdline_user_args()


func _row(data: Dictionary) -> void:
	data["nonce"] = _arg("--probe-nonce", "")
	data["t_ms"] = Time.get_ticks_msec()
	var line: String = JSON.stringify(data)
	print("TRACE_PROBE " + line)
	if _rows != null:
		_rows.store_line(line)
		_rows.flush()


func _run() -> void:
	var screen: WorldMapScreen = null
	for _i: int in range(6000):
		await get_tree().process_frame
		var found: Variant = _host.get("_map_screen")
		if found is WorldMapScreen:
			screen = found
			if not screen.landscape_pending():
				break
	if screen == null:
		_row({"probe": "error", "why": "no map screen"})
		_finish(3)
		return
	_scene = screen._map_scene
	_view(screen, _arg("--probe-view", ""))
	await _frames(SETTLE_FRAMES)
	if _arg("--probe-grain", "") == "off":
		_host.get("_transitions").call("set_grain", false)
		MapFilmGrainOff.apply(_scene)
	_kill(_arg("--trace-kill", ""), screen)
	var shot: String = _arg("--probe-shot", "")
	if not shot.is_empty():
		await _frames(30)
		var count: int = int(_arg("--probe-seq", "0"))
		var times: Array[int] = []
		var images: Array[Image] = []
		for i: int in range(maxi(count, 1)):
			await RenderingServer.frame_post_draw
			times.append(Time.get_ticks_usec())
			images.append(get_viewport().get_texture().get_image())
		for i: int in range(images.size()):
			images[i].save_png(shot if count == 0 else "%s-%02d.png" % [shot.trim_suffix(".png"), i])
		_row({"probe": "shot", "path": shot, "pins": _pins(screen), "times_us": times,
			"band": [_scene.focus_band.x, _scene.focus_band.y]})
		print("PINS ", JSON.stringify(_pins(screen)))
		_finish(0)
		return
	var frames: int = int(_arg("--hold-frames", "600"))
	for mode: String in _arg("--holds", "cadence").split(",", false):
		await _hold(mode, frames, screen)
	_force_live = false
	_row({"probe": "holds_done"})
	await get_tree().create_timer(float(_arg("--linger", "0"))).timeout
	_finish(0)


func _view(screen: WorldMapScreen, view: String) -> void:
	var journey: MapJourneyDirector = screen._journey
	if view == "whole" and journey != null and journey.active():
		journey.view.level = MapJourneyView.Level.WHOLE
		journey.frame(screen.map.at)
	elif view == "river":
		var z: float = 4.0
		var cam: Camera3D = _scene.get_rig().get_camera()
		var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
		var h: float = MapJourneyCameraContract.HEIGHT
		cam.position = Vector3(MapRavine.centre(MapRavine.CUTS[1], z), h, z + h / tan(pitch))
		screen._invalidate_projection()
	_row({"probe": "view", "view": view if not view.is_empty() else "default"})


func _hold(mode: String, count: int, screen: WorldMapScreen) -> void:
	_force_live = mode == "live"
	await _frames(60)
	var walking: bool = mode == "walk"
	if walking:
		var open: Array[int] = screen.map.reachable()
		open.sort()
		if open.is_empty() or not screen.choose(open[0]):
			_row({"probe": "error", "why": "no walk", "open": open})
			return
		count = WALK_FRAMES_MAX
	var stage: SubViewport = _scene.get_stage()
	var rid: RID = stage.get_viewport_rid()
	var info: Dictionary = {}
	for kind: Array in [["stage", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE],
			["shadow", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW]]:
		var type: int = kind[1]
		info[str(kind[0]) + "_draw_calls"] = RenderingServer.viewport_get_render_info(rid, type,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		info[str(kind[0]) + "_primitives"] = RenderingServer.viewport_get_render_info(rid, type,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	_row({"probe": "hold_start", "mode": mode, "stage": [stage.size.x, stage.size.y],
		"display": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"band": _scene.focus_band.is_finite(), "render": info,
		"layer_grain": _layer_grain(), "map_grain": _map_grain(),
		"video_mib": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)})
	var intervals: Array[float] = []
	var process_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	while intervals.size() < count:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append((now - last) / 1000.0)
		last = now
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var travelling: Variant = screen.get("_travelling")
		if walking and travelling != true:
			# The arrival frame also builds the room the walk opens: not the walk.
			intervals.pop_back()
			break
	count = intervals.size()
	var total: float = 0.0
	var missed: int = 0
	for v: float in intervals:
		total += v
		missed += 1 if v > MISSED_MS else 0
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	_row({"probe": "hold_end", "mode": mode, "frames": count,
		"mean_ms": snappedf(total / count, 0.001), "missed": missed,
		"p50_ms": snappedf(sorted[count / 2], 0.01), "p95_ms": snappedf(sorted[int(count * 0.95)], 0.01),
		"max_ms": snappedf(sorted[-1], 0.01), "process_ms": snappedf(process_ms / count, 0.01)})


## Whether the TransitionLayer's screen-reading grain is on screen.
func _layer_grain() -> bool:
	var layer: Variant = _host.get("_transitions")
	if not layer is TransitionLayer:
		return false
	var transitions: TransitionLayer = layer
	return transitions._grain.visible


## The map's own grain strength (R3.1 on; -1 on a build without one).
func _map_grain() -> float:
	var grain: ShaderMaterial = _scene._display.material as ShaderMaterial
	if grain == null or grain.shader == null \
			or not grain.shader.resource_path.ends_with("map_display.gdshader"):
		return -1.0
	var amount: float = grain.get_shader_parameter("amount")
	return amount


## Live: every enabled view of the map renders this frame. Runs after every
## other script's _process (process_priority 1000), so nothing puts it back.
func _process(_delta: float) -> void:
	if not _force_live or _scene == null:
		return
	_scene.get_stage().render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# R3.1's tilt-shift view, while it draws (a build before it has none).
	var shift: SubViewport = _scene.get_node_or_null("MapTiltShiftView") as SubViewport
	if shift != null and shift.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		shift.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Each visible pin's centre and pane radius in the window's pixels, the space
## a capture is in (the stage shape's stretch included), as R2's pin-contrast
## measure reads them.
func _pins(screen: WorldMapScreen) -> Array:
	var pins: Array = []
	var stretch: Transform2D = get_viewport().get_stretch_transform()
	for stone: GlassWaystone in screen._waystones:
		if stone.visible:
			var to_window: Transform2D = stretch * stone.get_global_transform_with_canvas()
			var centre: Vector2 = to_window * (stone.size * 0.5)
			var radius: float = stone.pane_radius() * stretch.get_scale().x
			pins.append([centre.x, centre.y, radius])
	return pins


## Hides one part for the whole run, so its GPU time can be read off a trace.
func _kill(what: String, screen: WorldMapScreen) -> void:
	if what.is_empty():
		return
	var land: MapJourneyLandscape = _scene.journey_landscape()
	match what:
		"shadows":
			_scene.get_key().shadow_enabled = false
		"kit":
			land.kit.visible = false
		"land":
			land.visible = false
		"ground":
			for g: Node in land.terrain.find_children("*", "MeshInstance3D", false, false):
				if str(g.name).begins_with("Ground chunk") or str(g.name) == "Quiet sculpted ground":
					(g as Node3D).visible = false
		"glow":
			var setting: WorldEnvironment = _scene._world.get_node("MapEnvironment") as WorldEnvironment
			setting.environment.glow_enabled = false
		"band":
			# The director asks for the band every frame from its framed group.
			screen._journey.focus_members.clear()
		"grain":
			_host.get("_transitions").call("set_grain", false)
		"display":
			_scene._display.visible = false
		"hud":
			var hud: Variant = _host.get("_run_hud")
			if hud is CanvasItem:
				var item: CanvasItem = hud
				item.visible = false
	_row({"probe": "kill", "what": what})


func _finish(code: int) -> void:
	_row({"probe": "done", "code": code})
	if _rows != null:
		_rows.close()
	get_tree().quit(code)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


## Takes the map's own grain off, on builds that have one (R3.1 on); a no-op
## on builds whose grain is the TransitionLayer's alone.
class MapFilmGrainOff:
	static func apply(scene: MapScene) -> void:
		var grain: ShaderMaterial = scene._display.material as ShaderMaterial
		if grain != null and grain.shader != null \
				and grain.shader.resource_path.ends_with("map_display.gdshader"):
			grain.set_shader_parameter("amount", 0.0)
