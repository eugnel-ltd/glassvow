extends Node
## Map open-cost bench for #621 item 5: times every `Main._show_map` by phase.
##
## Hosted by application/main.gd behind `--map --map-timing`, which starts a run
## on the map (the first open), then hands over here. The bench reopens the map
## the way a return from a fight does, moves the run into Act II and opens that
## act the same way, printing one `MAP_OPEN {json}` row per open. After each act
## it leaves the map and prints `MAP_KEPT`: video memory with the act's caches
## kept and after dropping them, which is what keeping an act costs in a fight.
## Needs a real renderer (never --headless):
##
##   tools/shot.sh --map --map-timing --seed=1 --shape=pad-landscape
##
## With `--shot=PATH` it stops after the first reopen of Act I and photographs
## that map instead, so a reopened map can be compared with a fresh one
## (`tools/shot.sh --map --shot=…`).

const REOPENS: int = 2
const SETTLE_FRAMES: int = 20

var _host: Node = null
var _shot: String = ""


func _ready() -> void:
	_host = get_parent()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
	_run.call_deferred()


func _run() -> void:
	# The boot's own open, inside `_new_run`, is the run's first map of Act I.
	_emit(1, 1)
	await _frames(SETTLE_FRAMES)
	for i: int in range(REOPENS):
		await _open(1, i + 2)
		if not _shot.is_empty():
			await _frames(30)
			get_viewport().get_texture().get_image().save_png(_shot)
			print("shot saved: " + _shot)
			get_tree().quit(0)
			return
	await _measure_kept(1)
	var run: RunState = _host.game.run
	var content: ContentDB = _host.content
	run.start_next_act(content)
	_host._map = WorldMap.for_run(run, content)
	_host.game.quests.decorate_map(run, _host._map)
	run.map = _host._map.to_dict()
	for i: int in range(1 + REOPENS):
		await _open(run.act + 1, i + 1)
	await _measure_kept(run.act + 1)
	get_tree().quit(0)


## What the kept act costs while another screen is up: leave the map, then drop
## the caches and measure again. The next open of the act starts cold.
func _measure_kept(act: int) -> void:
	_host._clear_route()
	await _frames(SETTLE_FRAMES)
	var kept: float = _video_mib()
	MapLandscapeAssets._kept = null
	MapScene._bound = {}
	MapScene._bound_key = ""
	WorldMapScreen._input_kept = null
	WorldMapScreen._input_sources = []
	await _frames(SETTLE_FRAMES)
	var dropped: float = _video_mib()
	print("MAP_KEPT " + JSON.stringify({"act": act, "video_mib_kept": kept,
		"video_mib_dropped": dropped, "kept_mib": snappedf(kept - dropped, 0.1)}))


func _open(act: int, open: int) -> void:
	_host._show_map()
	_emit(act, open)
	await _frames(SETTLE_FRAMES)


func _emit(act: int, open: int) -> void:
	var row: Dictionary = {"act": act, "open": open, "seed": _host.game.run.seed,
		"static_mib": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
		"video_mib": _video_mib()}
	var phases: Dictionary[String, float] = MapOpenTiming.report()
	for phase: String in phases:
		row[phase] = snappedf(phases[phase], 0.1)
	print("MAP_OPEN " + JSON.stringify(row))


func _video_mib() -> float:
	return snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)


func _frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
