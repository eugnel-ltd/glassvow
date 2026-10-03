extends SceneTree
## The deck overlay's cost (issue #657, PR 2): the video memory the top-menu
## deck view holds while it is open, and the frames that open and close it.
##
## It drives the real overlay (`Main._show_run_deck`, `Main._close_overlay`)
## over a run on the map, so the same bench measures any tree that has them.
## It needs a real renderer, so it refuses `--headless` (exit 2):
##
##   godot --path . -s res://tools/bench_deck_view.gd -- --map --seed=1 \
##     --shape=pad-landscape [--out=<file stem>]
##
## The deck is the starter deck (10 cards) and then 30 cards: the starter
## plus twenty distinct player cards in id order, every third upgraded, so
## the 30-card view is the worst case for a cache of distinct faces. For each
## size, after the map has settled, it opens and closes the overlay ROUNDS
## times and prints one `DECK {json}` row per open. The first open of each size
## is a cold one: a tree with a face cache (CardFaces) has it dropped first.
##
##   vram_closed_mib     video memory with the overlay closed, before it opens
##   vram_open_mib       above that, once the open overlay has settled
##   vram_peak_mib       the most it held above that while opening
##   vram_after_mib      above that, once the overlay is closed again (what
##                       stays: first-use allocations, or a face cache)
##   open_call_ms        the open call itself (the overlay is built in it)
##   open_frames         frames from the open to the last change in video
##                       memory (the last live card or bake to come or go)
##   open_worst_ms, open_p50_ms, open_over_20, open_over_33
##                       frame times over the OPEN_FRAMES after the open
##   close_call_ms, close_worst_ms, close_p50_ms
##                       the same for the close, over CLOSE_FRAMES
##   viewports_open      SubViewports in the tree once the open view settled
##
## The deck is grown in memory on the Development profile (any launch with an
## argument runs there) and never saved. --out= also writes the rows to
## <stem>.jsonl. A device build attaches `Probe` to the running Main instead.

const ROUNDS: int = 3
## Between opens: a time and some frames, so an unthrottled window settles too.
const SETTLE_SECONDS: float = 1.0
const SETTLE_FRAMES: int = 60
const OPEN_FRAMES: int = 120
const CLOSE_FRAMES: int = 60
const SIZES: Array[int] = [10, 30]
const FACES: String = "res://presentation/cards/card_faces.gd"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("bench_deck_view: needs a real renderer; run it without --headless")
		quit(2)
		return
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var main_scene: PackedScene = load("res://application/main.tscn") as PackedScene
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	var probe: Probe = Probe.new(main, out)
	probe.finished.connect(func() -> void: quit(0))
	root.add_child(probe)


## The bench itself, as a node, so a device build can attach it to its Main.
class Probe:
	extends Node
	signal finished

	var _main: Node = null
	var _out: String = ""
	var _rows: PackedStringArray = PackedStringArray()
	var _stamps: Array[int] = []
	var _vram: Array[float] = []

	func _init(main: Node, out: String) -> void:
		_main = main
		_out = out

	func _ready() -> void:
		set_process(false)
		_run.call_deferred()

	func _process(_delta: float) -> void:
		_stamps.append(Time.get_ticks_usec())
		_vram.append(_vram_mib())

	func _run() -> void:
		await _settle()
		var run: RunState = _main.get("game").run
		var starter: Array[CardInst] = run.player.deck.duplicate()
		_row("RUN %s display=%s window=%s starter=%d" % [
			Engine.get_version_info()["string"], DisplayServer.get_name(),
			str(get_window().size), starter.size()])
		for want: int in SIZES:
			_set_deck(run, starter, want)
			_forget_faces()
			for round_i: int in range(ROUNDS):
				await _settle()
				await _measure(run.player.deck.size(), round_i + 1)
		_write()
		finished.emit()

	## Each size's first open is a cold one: a tree that bakes its faces
	## (presentation/cards/card_faces.gd) drops them, one that does not is
	## left as it is.
	func _forget_faces() -> void:
		if ResourceLoader.exists(FACES):
			(load(FACES) as GDScript).call("forget")

	func _set_deck(run: RunState, starter: Array[CardInst], want: int) -> void:
		var deck: Array[CardInst] = starter.duplicate()
		var content: ContentDB = _main.get("content")
		var ids: Array = content.cards.keys()
		ids.sort()
		var taken: Dictionary = {}
		for card: CardInst in starter:
			taken[String(card.id)] = true
		var added: int = 0
		for id_v: Variant in ids:
			if deck.size() >= want:
				break
			var id: String = str(id_v)
			var row: Dictionary = content.cards[id]
			if taken.has(id) or not ["attack", "skill", "power"].has(str(row.get("type", ""))) \
					or not ["common", "uncommon", "rare"].has(str(row.get("rarity", ""))):
				continue
			var up: bool = added % 3 == 2 and row.has("up")
			deck.append(CardInst.new(run.next_uid(), StringName(id), up))
			added += 1
		run.player.deck = deck

	func _measure(deck_n: int, round_i: int) -> void:
		var closed: float = _vram_mib()
		var vp_closed: int = _count_viewports()
		_begin()
		var t0: int = Time.get_ticks_usec()
		_main.call("_show_run_deck")
		var open_call: float = (Time.get_ticks_usec() - t0) / 1000.0
		await _frames(OPEN_FRAMES)
		var open: Dictionary = _end(t0)
		var open_settled: float = _tail_mean(_vram, 10)
		var vp_open: int = _count_viewports()
		_begin()
		var t1: int = Time.get_ticks_usec()
		_main.call("_close_overlay")
		var close_call: float = (Time.get_ticks_usec() - t1) / 1000.0
		await _frames(CLOSE_FRAMES)
		var close: Dictionary = _end(t1)
		var after: float = _tail_mean(_vram, 10)
		var peak: float = open["peak"]
		var row: Dictionary = {
			"deck": deck_n, "round": round_i,
			"vram_closed_mib": snappedf(closed, 0.1),
			"vram_open_mib": snappedf(open_settled - closed, 0.1),
			"vram_peak_mib": snappedf(peak - closed, 0.1),
			"vram_after_mib": snappedf(after - closed, 0.1),
			"open_call_ms": snappedf(open_call, 0.1),
			"open_frames": open["settle"],
			"open_worst_ms": open["worst"], "open_p50_ms": open["p50"],
			"open_over_20": open["over_20"], "open_over_33": open["over_33"],
			"close_call_ms": snappedf(close_call, 0.1),
			"close_worst_ms": close["worst"], "close_p50_ms": close["p50"],
			"viewports_closed": vp_closed, "viewports_open": vp_open,
		}
		_row("DECK " + JSON.stringify(row))

	func _begin() -> void:
		_stamps.clear()
		_vram.clear()
		set_process(true)

	## Frame times from the call at `t0`; the first gap is the call's own frame.
	func _end(t0: int) -> Dictionary:
		set_process(false)
		var gaps: Array[float] = []
		var last: int = t0
		for stamp: int in _stamps:
			gaps.append((stamp - last) / 1000.0)
			last = stamp
		var sorted: Array[float] = gaps.duplicate()
		sorted.sort()
		var settle: int = 0
		for i: int in range(1, _vram.size()):
			if absf(_vram[i] - _vram[i - 1]) > 0.05:
				settle = i
		var peak: float = 0.0
		for v: float in _vram:
			peak = maxf(peak, v)
		var worst: float = 0.0
		var mid: float = 0.0
		if not sorted.is_empty():
			worst = sorted[sorted.size() - 1]
			mid = sorted[sorted.size() / 2]
		return {
			"worst": snappedf(worst, 0.1),
			"p50": snappedf(mid, 0.1),
			"over_20": gaps.filter(func(g: float) -> bool: return g > 20.0).size(),
			"over_33": gaps.filter(func(g: float) -> bool: return g > 33.4).size(),
			"settle": settle + 1,
			"peak": peak,
		}

	func _tail_mean(values: Array[float], n: int) -> float:
		var tail: Array[float] = values.slice(maxi(0, values.size() - n))
		var sum: float = 0.0
		for v: float in tail:
			sum += v
		return sum / maxf(1.0, float(tail.size()))

	func _count_viewports() -> int:
		return get_tree().root.find_children("", "SubViewport", true, false).size()

	func _vram_mib() -> float:
		return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	func _frames(n: int) -> void:
		for _i: int in range(n):
			await get_tree().process_frame

	func _settle() -> void:
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		await _frames(SETTLE_FRAMES)

	func _row(text: String) -> void:
		print(text)
		_rows.append(text)

	func _write() -> void:
		if _out.is_empty():
			return
		var f: FileAccess = FileAccess.open(_out + ".jsonl", FileAccess.WRITE)
		if f == null:
			return
		f.store_string("\n".join(_rows) + "\n")
		f.close()
