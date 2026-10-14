extends SceneTree
## Stills of the card holograms (#657) on the real Main, windowed. Not a test:
## `tests/run_all.gd` only discovers `res://tests/test_*.gd`, and this needs a
## real renderer (it refuses `--headless`, exit 2).
##
##   godot --path . --position 40,40 -s res://tools/capture_holo.gd -- \
##     --map --seed=1 --vp=1180x820 [--shape=phone-landscape] [--locale=zh-Hant] \
##     --what=fight|dawn [--back=vault|rose|eclipse] --out=<dir>
##
## fight  deals a five-card deck whose opening hand is all of it, one card of
##        each front tier (starter, common, uncommon, rare, special), opens the
##        bench fight on it (duskfang, elite), stands eight more cards in the
##        draw pile and shoots the hand and the piles at three holds of the motion signal (HoloMotion.hold): leaning
##        left and away, flat, leaning right and toward.
## dawn   a fresh run's Dawn with one event, the back `--back` earned, shot at
##        the same three holds.
##
## In a fight the table wears `--back` (the Lancet by default), baked in place.
## Each still is `<out>/<what>-<i>.png`, i = 0, 1, 2.

const HAND: Array[StringName] = [&"strike", &"quickSlash", &"tempest", &"oblivionStrike", &"hex"]
const HOLDS: Array[Vector2] = [Vector2(-0.9, -0.6), Vector2(0.0, 0.0), Vector2(0.9, 0.6)]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("capture_holo: needs a real renderer; run it without --headless")
		quit(2)
		return
	var out: String = ""
	var what: String = "fight"
	var back: String = "vault"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--what="):
			what = arg.trim_prefix("--what=")
		elif arg.begins_with("--back="):
			back = arg.trim_prefix("--back=")
	var main: Main = (load("res://application/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var shooter: Shooter = Shooter.new(main, out, what, back)
	shooter.finished.connect(func(ok: bool) -> void: quit(0 if ok else 1))
	root.add_child(shooter)


class Shooter:
	extends Node
	signal finished(ok: bool)

	var _main: Main
	var _out: String
	var _what: String
	var _back: String

	func _init(main: Main, out: String, what: String, back: String) -> void:
		_main = main
		_out = out
		_what = what
		_back = back

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func _run() -> void:
		DirAccess.make_dir_recursive_absolute(_out)
		await _frames(240)
		if _what == "dawn":
			_main.game.run.pending_dawn = {"events": [{"kind": "back", "back": _back,
				"title": Locale.active.t("ui.back.%s.name" % _back),
				"body": Locale.active.t("ui.dawn.backBody")}], "cursor": 0}
			_main._show_dawn()
			await _frames(720)    # past the reveal's turn
		else:
			_deal()
			_main._start_fight(PackedStringArray(["duskfang"]), "elite")
			await _frames(60)
			# The table wears `--back` (every pile follows CardTurn.back), and
			# the draw pile, emptied by the opening hand, is given a stack to
			# wear it on (a capture's stand-in, never a fight's state).
			CardTurn.prewarm(_main, _back)
			for _i: int in range(8):
				_main.game.cb.draw.append(CardInst.new(_main.game.run.next_uid(), &"strike", false))
			_main._screen._push_hud()
			await _frames(360)
		# Whatever the desktop's pointer is over, no card is hovered in a still.
		for node: Node in _main.find_children("", "CardView", true, false):
			var card: CardView = node
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.point_away()
		await _frames(90)
		for i: int in range(HOLDS.size()):
			HoloMotion.hold(HOLDS[i])
			await _frames(4)
			await RenderingServer.frame_post_draw
			var path: String = "%s/%s-%d.png" % [_out, _what, i]
			get_tree().root.get_texture().get_image().save_png(path)
			print("CAPTURE_HOLO %s hold=%s" % [path, str(HOLDS[i])])
		HoloMotion.hold(null)
		finished.emit(true)

	func _deal() -> void:
		var run: RunState = _main.game.run
		var deck: Array[CardInst] = []
		for id: StringName in HAND:
			deck.append(CardInst.new(run.next_uid(), id, false))
		run.player.deck = deck

	func _frames(n: int) -> void:
		for _i: int in range(n):
			await get_tree().process_frame
