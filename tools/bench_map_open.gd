extends Node
## Map open-cost bench for #621 item 5: times whole `Main._show_map` calls with
## its own clock, from the call to a bound map and to the first frame drawn after
## it. Nothing on the player path is instrumented.
##
## Hosted by application/main.gd behind `--map --map-timing`, which starts a run
## on the map, then hands over here. For Act I and then Act II the bench drops
## the kept act (a cold open of the act, as after an act change), opens the map,
## reopens it twice the way a return from a fight does, and leaves it. It prints
## one `MAP_OPEN {json}` row per open and one `MAP_KEPT {json}` row per act: the
## video memory the kept act holds once the map is left, with the caches kept
## and after dropping them. Then it drops everything again, warms the act's
## landscape the way a run start or an act change does
## (`MapLandscapeAssets.prefetch`), waits for the worker without opening
## anything, and opens the map once more: a `MAP_WARM` row times the warm-up and
## its worst frame, and the `warmed` open row is what the player's first open of
## the act costs once the warm-up has finished. Last, an `early` open starts the
## warm-up and opens the map at once, as resuming a run onto its map does: the
## main thread decodes what the worker has not reached. Needs a real renderer
## (never --headless): the dummy renderer hides GPU stalls such as a mesh read
## back from the renderer.
##
##   tools/shot.sh --map --map-timing --seed=1 --shape=pad-landscape
##
## With `--shot=PATH` it stops after the first reopen of Act I and photographs
## that map instead, so a reopened map can be compared with a fresh one
## (`tools/shot.sh --map --shot=…`).

const REOPENS: int = 2
const SETTLE_FRAMES: int = 20
const IDLE_FRAMES: int = 60

var _host: Node = null
var _shot: String = ""


func _ready() -> void:
	_host = get_parent()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	_run.call_deferred()


func _run() -> void:
	await _frames(SETTLE_FRAMES)
	if not _shot.is_empty():
		await _open(1, 2, "reopen")
		await _frames(30)
		get_viewport().get_texture().get_image().save_png(_shot)
		print("shot saved: " + _shot)
		get_tree().quit(0)
		return
	await _time_act(1)
	var run: RunState = _host.game.run
	var content: ContentDB = _host.content
	run.start_next_act(content)
	_host._map = WorldMap.for_run(run, content)
	_host.game.quests.decorate_map(run, _host._map)
	run.map = _host._map.to_dict()
	await _time_act(run.act + 1)
	get_tree().quit(0)


## A cold open of `act` (its number), then the reopens, then what keeping it
## costs, then a warmed open and an early one.
func _time_act(act: int) -> void:
	_drop_kept()
	await _frames(SETTLE_FRAMES)
	for open: int in range(1, 2 + REOPENS):
		await _open(act, open, "cold" if open == 1 else "reopen")
	_host._clear_route()
	await _frames(SETTLE_FRAMES)
	var kept: float = _video_mib()
	_drop_kept()
	await _frames(SETTLE_FRAMES)
	var dropped: float = _video_mib()
	print("MAP_KEPT " + JSON.stringify({"act": act, "video_mib_kept": kept,
		"video_mib_dropped": dropped, "kept_mib": snappedf(kept - dropped, 0.1)}))
	await _warm(act)
	await _open(act, 2 + REOPENS, "warmed")
	_host._clear_route()
	_drop_kept()
	await _frames(SETTLE_FRAMES)
	var run: RunState = _host.game.run
	MapLandscapeAssets.prefetch(run.act)
	await _open(act, 3 + REOPENS, "early")
	_host._clear_route()
	await _frames(SETTLE_FRAMES)


## Warms the act's landscape as a run start or an act change does and waits for
## the worker, timing each frame meanwhile: the warm-up must not hitch. The
## worst of as many idle frames just before it is the control.
func _warm(act: int) -> void:
	var idle_ms: float = await _worst_frame(func() -> bool: return false, IDLE_FRAMES)
	var start: int = Time.get_ticks_usec()
	var run: RunState = _host.game.run
	MapLandscapeAssets.prefetch(run.act)
	var warming: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
	var worst_ms: float = await _worst_frame(
		func() -> bool: return warming == null or warming.is_done(), -1)
	print("MAP_WARM " + JSON.stringify({"act": act,
		"warm_ms": snappedf((Time.get_ticks_usec() - start) / 1000.0, 0.1),
		"worst_frame_ms": snappedf(worst_ms, 0.1),
		"idle_worst_frame_ms": snappedf(idle_ms, 0.1)}))
	await _frames(SETTLE_FRAMES)


## The longest frame until `done` answers true, or for `count` frames.
func _worst_frame(done: Callable, count: int) -> float:
	var worst_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	var frames: int = 0
	while not done.call() and frames != count:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now - last) / 1000.0)
		last = now
		frames += 1
	return worst_ms


func _open(act: int, open: int, kind: String) -> void:
	var start: int = Time.get_ticks_usec()
	_host._show_map()
	var total_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	await RenderingServer.frame_post_draw
	var frame_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	print("MAP_OPEN " + JSON.stringify({"act": act, "open": open, "kind": kind,
		"seed": _host.game.run.seed, "total_ms": snappedf(total_ms, 0.1),
		"frame_ms": snappedf(frame_ms, 0.1), "video_mib": _video_mib()}))
	await _frames(SETTLE_FRAMES)


## Forgets every per-act cache, so the next open decodes and binds from nothing.
func _drop_kept() -> void:
	MapLandscapeAssets.release()
	MapScene._bound = {}
	MapScene._bound_key = ""
	WorldMapScreen._input_kept = null
	WorldMapScreen._input_sources = []


func _video_mib() -> float:
	return snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
