extends Node
## Map frame bench: what the map costs to draw at rest and while the pilgrim
## walks. Hosted by application/main.gd behind `--map --map-rest`, which starts a
## run on the map and hands over here.
##
##   tools/shot.sh --map --map-rest --seed=1 --shape=pad-landscape
##
## It opens the map, waits for Act I's journey land to finish building, settles,
## then samples REST_FRAMES frames at rest (the land renders at its rest
## cadence, `MapScene.REST_EVERY`) and every frame of one walk to the first
## reachable waystone. One `MAP_REST {json}` row: frame interval p50 and p95 for
## each, how many of the rest frames rendered the stage, the stage's and the
## shadow pass's draw calls and primitives (`viewport_get_render_info`, which
## the Mac can count although Metal gives no GPU timer), and video memory.
## Vsync is off while sampling. Needs a real renderer (never --headless).

const SETTLE_FRAMES: int = 60
const REST_FRAMES: int = 240
const WALK_LIMIT: int = 900

var _host: Node = null


func _ready() -> void:
	_host = get_parent()
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	_host._show_map()
	var screen: WorldMapScreen = _host._map_screen
	var waited: int = 0
	while screen.landscape_pending() and waited < 3000:
		await get_tree().process_frame
		waited += 1
	await _frames(SETTLE_FRAMES)
	var scene: MapScene = screen._map_scene
	var rid: RID = scene.get_stage().get_viewport_rid()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var stage: Vector2i = scene.get_stage().size
	var rest: Dictionary = await _sample(func() -> bool: return true, REST_FRAMES)
	var info: Dictionary = _render_info(rid)
	info["omni_lights"] = scene.find_children("*", "OmniLight3D", true, false).size()
	var reach: Array[int] = screen.map.reachable()
	var walk: Dictionary = {}
	if not reach.is_empty() and screen.choose(reach[0]):
		# The arrival frame routes to the encounter (Main builds its screen): it
		# is the encounter's cost, not the walk's, so it is left out.
		walk = await _sample(func() -> bool: return screen._travelling, WALK_LIMIT, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	print("MAP_REST " + JSON.stringify({"act": _host.game.run.act + 1,
		"seed": _host.game.run.seed, "stage": [stage.x, stage.y],
		"rest": rest, "walk": walk, "render": info,
		"video_mib": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_mib": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)}))
	get_tree().quit(0)


## Frame intervals while `going` answers true, at most `limit` frames; the
## first interval is reported apart (`first_ms`), and with `drop_last` the frame
## that ended the sampling is left out.
func _sample(going: Callable, limit: int, drop_last: bool = false) -> Dictionary:
	var intervals: Array[float] = []
	var last: int = Time.get_ticks_usec()
	while going.call() and intervals.size() < limit:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append((now - last) / 1000.0)
		last = now
	if drop_last and not intervals.is_empty():
		intervals.remove_at(intervals.size() - 1)
	if intervals.is_empty():
		return {}
	var first: float = intervals[0]
	intervals.sort()
	return {"frames": intervals.size(), "first_ms": snappedf(first, 0.01),
		"p50_ms": snappedf(intervals[intervals.size() / 2], 0.01),
		"p95_ms": snappedf(intervals[int(intervals.size() * 0.95)], 0.01),
		"max_ms": snappedf(intervals[-1], 0.01)}


func _render_info(rid: RID) -> Dictionary:
	var out: Dictionary = {}
	for kind: Array in [["stage", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE],
			["shadow", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW]]:
		var type: int = kind[1]
		out[str(kind[0]) + "_draw_calls"] = RenderingServer.viewport_get_render_info(rid, type,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		out[str(kind[0]) + "_primitives"] = RenderingServer.viewport_get_render_info(rid, type,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	return out


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
