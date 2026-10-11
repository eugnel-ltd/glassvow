extends SceneTree
## Windowed proof of a resting card letting its stage go (CardView, LETTING
## THE STAGE GO; issue #657 PR 6). The suite proves the decisions on a fake
## keeper, because a headless run never draws; this proves the real copy, the
## real rebuild and what they put on screen.
##
## Not a test: `tests/run_all.gd` only discovers `res://tests/test_*.gd`. It
## needs a real renderer, so it refuses `--headless` (exit 2). It boots the
## game on the map (the Development profile), deals a five-card deck whose
## opening hand is all of it — a rare (the foil finish and the gilt shine), an
## uncommon, a common and two starters (the plain finish) — and opens the
## bench fight on it (duskfang, elite). Run it at a fixed frame rate, so that
## two builds take the same steps on the same frames and their frames can be
## compared one to one (`tools/diff_frames.py`):
##
##   godot --path . --fixed-fps 60 -s res://tools/check_card_rest.gd -- \
##     --map --seed=1 --vp=1180x820 [--shape=phone-landscape] \
##     [--locale=zh-Hant] [--hand-only] [--out=<dir>]
##
## `--hand-only` hides everything but the hand, and every card's gilt shine
## (it runs on TIME), from the fight's load on, so a frame holds the cards and
## nothing else. The script is the same on any build; what it checks of the
## release runs only where the card can let its stage go (`has_stage`).
##
## `--resting` takes no fight: it waits for whatever screen the boot opened to
## settle — the reward's offering (`--reward`), the Night Stall's rack
## (`--shop`) — and runs REST, TOUCH and BACK over the cards it shows
## (`--hand-only` then keeps the cards alone on screen):
##
##   godot --path . --fixed-fps 60 -s res://tools/check_card_rest.gd -- \
##     --shop --vp=1180x820 --resting [--hand-only] [--out=<dir>]
##
##   REST     the hand at rest holds no stage: no card has its passes, no
##            SubViewport stands under the hand.
##   TOUCH    a pointer on a resting card builds its stage in that same call.
##   BACK     once the pointer leaves and the card settles, it lets its stage
##            go again, and the frame after the release is the frame before.
##   TURN     a live turn builds the stage; the card turned back to rest lets
##            it go.
##   PLAY     a released card plays (a strike at the foe, a defend to the
##            discard) and the deck reshuffles and deals again.
##   SWAP     a rebuild with nothing moved: the frame before it (the kept
##            frame), the frame the rebuilt stage first draws and the frame
##            after it lets go again are one frame, pixel for pixel, and the
##            frame it keeps the second time is the first, texel for texel.
##   COMPILE  no surface, draw or specialisation pipeline is compiled from
##            the fight's load frame to the end.
##
## Exit 0 when every check holds, 1 otherwise. --out= writes the rows and
## the frames (`<step>.png`), named alike on every build.

const MONITORS: Array[int] = [
	Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]
## Frames a screen is given to settle before a resting run looks at it.
const SCREEN_SETTLE: int = 420
## The opening hand: the deck, one of each.
const RARE: StringName = &"novaflare"
const STARTERS: Array[StringName] = [&"strike", &"defend"]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_card_rest: needs a real renderer; run it without --headless")
		quit(2)
		return
	var out: String = ""
	var hand_only: bool = false
	var resting: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--hand-only":
			hand_only = true
		elif arg == "--resting":
			resting = true
	var main: Main = (load("res://application/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var probe: Probe = Probe.new(main, out, hand_only, resting)
	probe.finished.connect(func(ok: bool) -> void: quit(0 if ok else 1))
	root.add_child(probe)


class Probe:
	extends Node
	signal finished(ok: bool)

	var _main: Main = null
	var _out: String = ""
	var _hand_only: bool = false
	var _resting: bool = false
	var _rows: PackedStringArray = PackedStringArray()
	var _ok: bool = true
	var _at_load: PackedInt32Array = PackedInt32Array()
	var _frames: Dictionary = {}     # step -> Image

	func _init(main: Main, out: String, hand_only: bool, resting: bool) -> void:
		_main = main
		_out = out
		_hand_only = hand_only
		_resting = resting

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func _run() -> void:
		if _resting:
			await _resting_screen()
			_finish()
			return
		await _map_settled()
		_deal_the_deck()
		_main._start_fight(PackedStringArray(["duskfang"]), "elite")
		await get_tree().process_frame
		_at_load = _counts()
		_row("LOAD %s locale=%s shape=%s window=%s counters=%s vram=%.1f" % [
			Engine.get_version_info()["string"], Locale.active.code, str(_main._shape),
			str(get_window().size), str(_at_load), _vram()])
		if _hand_only:
			_hide_all_but([_hand()])
		await _idle(90)
		var cards: Array[CardView] = _cards()
		_row("HAND %s" % ", ".join(cards.map(func(c: CardView) -> String:
			return "%s(%s)" % [c.card_id, CardSurface.name_of(c.surface)])))
		await _shoot("01-rest")
		_rest_check("REST")
		_row("VRAM at rest, %d in hand: %.1f MiB" % [cards.size(), _vram()])
		var foil: CardView = _first(cards, func(c: CardView) -> bool: return c.has_shine())
		var plain: CardView = _first(cards, func(c: CardView) -> bool:
			return CardSurface.name_of(c.surface) == "plain")
		await _touch(foil)
		await _live_turn(plain)
		await _play()
		_main._screen._on_end_turn_pressed()
		await _idle(90)
		await _shoot("40-turn2-rest")
		_rest_check("REST after the reshuffle's deal")
		await _swap(_cards())
		_finish()

	## Any other screen a live card rests on, as the boot opened it.
	func _resting_screen() -> void:
		await _frames_of(SCREEN_SETTLE)
		var cards: Array[CardView] = _cards()
		_at_load = _counts()
		_row("SCREEN %s locale=%s shape=%s window=%s cards=%s counters=%s vram=%.1f" % [
			Engine.get_version_info()["string"], Locale.active.code, str(_main._shape),
			str(get_window().size), ", ".join(cards.map(func(c: CardView) -> String:
				return String(c.card_id))), str(_at_load), _vram()])
		if cards.is_empty():
			_check("SCREEN shows a card", false)
			return
		if _hand_only:
			var keeps: Array[Node] = []
			keeps.assign(cards)
			_hide_all_but(keeps)
			await _frames_of(2)
		await _shoot("01-rest")
		_rest_check("REST")
		await _touch(cards[0])
		await _shoot("40-rest-again")
		_rest_check("REST again")

	func _finish() -> void:
		var now: PackedInt32Array = _counts()
		var flat: bool = now[2] == _at_load[2] and now[3] == _at_load[3] and now[4] == _at_load[4]
		_row("COMPILE %s at the start, %s at the end: %s" % [str(_at_load), str(now),
			"flat" if flat else "COMPILED"])
		_ok = _ok and flat
		_row("RESULT %s" % ("PASS" if _ok else "FAIL"))
		_write()
		finished.emit(_ok)

	## A pointer on the card, held, then gone; the card springs back and, at
	## rest, lets its stage go again.
	func _touch(card: CardView) -> void:
		var at: Vector2 = Vector2(CardView.CARD_W * 0.75, CardView.CARD_H * 0.25)
		await _shoot("10-touch-before")
		card.point_at(at)
		_check("TOUCH %s builds its stage in the call" % card.card_id, _staged(card, true))
		await _shoot("11-touch-0")
		await _shoot("12-touch-1")
		await _shoot("13-touch-2")
		await _frames_of(3)
		await _shoot("14-touch-6")
		await _frames_of(20)
		await _shoot("15-touch-held")
		card.point_away()
		var settle: int = 0
		while card.is_processing() and settle < 600:
			await get_tree().process_frame
			settle += 1
		# The frame the stage draws its rest in, and the frame after it.
		await _shoot("16-back-settled")
		await _shoot("17-back-after")
		_check("BACK %s lets its stage go %d frames after the pointer left"
			% [card.card_id, settle], _staged(card, false))
		await _frames_of(30)
		await _shoot("18-back-rest")

	## A live turn over and back on a resting card.
	func _live_turn(card: CardView) -> void:
		await _shoot("20-turn-before")
		var steps: int = 24
		for i: int in range(1, steps + 1):
			card.turn(180.0 * float(i) / float(steps), -14.0 * sin(PI * float(i) / float(steps)), true)
			if i == 1:
				_check("TURN %s builds its stage" % card.card_id, _staged(card, true))
			if i in [6, 12, 18, 24]:
				await _shoot("21-turn-out-%02d" % i)
			else:
				await get_tree().process_frame
		for i: int in range(steps - 1, -1, -1):
			card.turn(180.0 * float(i) / float(steps), -14.0 * sin(PI * float(i) / float(steps)), true)
			if i in [12, 0]:
				await _shoot("22-turn-back-%02d" % i)
			else:
				await get_tree().process_frame
		await _shoot("23-turn-after")
		_check("TURN %s back at rest lets its stage go" % card.card_id, _staged(card, false))

	## A strike at the foe and a defend to the discard, from rest.
	func _play() -> void:
		var screen: CombatScreen = _main._screen
		for id: StringName in STARTERS:
			var card: CardView = _first(_cards(), func(c: CardView) -> bool: return c.card_id == id)
			if card == null:
				continue
			_check("PLAY %s from rest" % id, _staged(card, false))
			var target: Variant = 0 if card.target_kind == "enemy" else null
			var played: bool = screen.request_play(card.uid, target)
			_check("PLAY %s accepted" % id, played)
			for i: int in range(0, 24, 4):
				await _shoot("3%d-play-%s-%02d" % [STARTERS.find(id), id, i])
				await _frames_of(3)
			await _idle(30)

	## A rebuild with nothing moved, and the release after it: compared with
	## the hand alone on screen, as everything else moves.
	func _swap(cards: Array[CardView]) -> void:
		var card: CardView = _first(cards, func(c: CardView) -> bool: return c.has_shine())
		if card == null or not card.has_method("has_stage") or card.call("has_stage"):
			_row("SWAP skipped")
			return
		_hide_all_but([_hand()])
		_hand_only = true
		await _frames_of(2)
		var kept: Image = card.stage_texture().get_image()
		var before: Image = await _shoot("50-swap-kept")
		card.call("_draw_stage_once")
		var drawn: Image = await _shoot("51-swap-rebuilt")
		var after: Image = await _shoot("52-swap-released")
		_check("SWAP %s the rebuilt stage's first frame is the kept one" % card.card_id,
			_same(before, drawn))
		_check("SWAP %s the frame after it lets go again is the same" % card.card_id,
			_same(drawn, after))
		_check("SWAP %s lets its stage go again" % card.card_id, _staged(card, false))
		var again: Image = card.stage_texture().get_image()
		_check("SWAP %s kept the same frame twice, texel for texel" % card.card_id,
			_same(kept, again))

	func _rest_check(label: String) -> void:
		var cards: Array[CardView] = _cards()
		if cards.is_empty() or not cards[0].has_method("has_stage"):
			return
		var staged: Array = cards.filter(func(c: CardView) -> bool: return c.call("has_stage"))
		var passes: int = 0
		for card: CardView in cards:
			passes += card.find_children("*", "SubViewport", true, false).size()
		_check("%s: %d of %d cards hold a stage, %d SubViewports under them"
			% [label, staged.size(), cards.size(), passes], staged.is_empty() and passes == 0)

	func _staged(card: CardView, want: bool) -> bool:
		return not card.has_method("has_stage") or card.call("has_stage") == want

	func _check(label: String, ok: bool) -> void:
		_row("%s %s" % ["ok  " if ok else "FAIL", label])
		_ok = _ok and ok

	func _same(a: Image, b: Image) -> bool:
		if a.get_size() != b.get_size():
			return false
		a.convert(Image.FORMAT_RGBA8)
		b.convert(Image.FORMAT_RGBA8)
		return a.get_data() == b.get_data()

	## Five cards, so the opening hand is the whole deck.
	func _deal_the_deck() -> void:
		var run: RunState = _main.game.run
		var content: ContentDB = _main.content
		var ids: Array = content.cards.keys()
		ids.sort()
		var deck: Array[CardInst] = [CardInst.new(run.next_uid(), RARE, false)]
		for rarity: String in ["uncommon", "common"]:
			for id_v: Variant in ids:
				var row: Dictionary = content.cards[id_v]
				if str(row.get("rarity", "")) == rarity and str(row.get("type", "")) == "skill" \
						and row.get("cost") != null:
					deck.append(CardInst.new(run.next_uid(), StringName(str(id_v)), false))
					break
		for id: StringName in STARTERS:
			deck.append(CardInst.new(run.next_uid(), id, false))
		run.player.deck = deck

	func _map_settled() -> void:
		var calm: int = 0
		var waited: int = 0
		while calm < 30 and waited < 3600:
			await get_tree().process_frame
			waited += 1
			var map: WorldMapScreen = _main._map_screen
			var landed: bool = map != null and is_instance_valid(map) \
				and map.is_inside_tree() and not map.landscape_pending()
			calm = calm + 1 if landed else 0

	## The drain idle and nothing in the air, then `extra` frames.
	func _idle(extra: int) -> void:
		var screen: CombatScreen = _main._screen
		var waited: int = 0
		await get_tree().process_frame
		while waited < 1200:
			var hand: HandView = _hand()
			var busy: bool = screen.seq.is_busy() or not hand._dealing.is_empty() \
				or not hand._leaving.is_empty()
			var stream: PileStream = screen._hud._stream
			if not busy and (stream == null or not is_instance_valid(stream)):
				break
			await get_tree().process_frame
			waited += 1
		await _frames_of(extra)

	func _frames_of(n: int) -> void:
		for _i: int in range(n):
			await get_tree().process_frame

	## The frame drawn next, kept under `step`.
	func _shoot(step: String) -> Image:
		if _hand_only:
			for card: CardView in _cards():
				if card._shine != null:
					card._shine.visible = false
		await RenderingServer.frame_post_draw
		var image: Image = get_tree().root.get_texture().get_image()
		_frames[step] = image
		_row("SHOT %s counters=%s vram=%.1f" % [step, str(_counts()), _vram()])
		return image

	func _hand() -> HandView:
		return _main._screen._hand

	## The hand's cards; on a resting run, every card on screen.
	func _cards() -> Array[CardView]:
		var out: Array[CardView] = []
		if _resting:
			for node: Node in _main.find_children("", "CardView", true, false):
				if not node.is_queued_for_deletion() and (node as CanvasItem).is_visible_in_tree():
					out.append(node as CardView)
			return out
		var hand: HandView = _hand()
		for uid: int in hand.uids():
			out.append(hand.card_view(uid))
		return out

	func _first(cards: Array[CardView], pick: Callable) -> CardView:
		for card: CardView in cards:
			if pick.call(card):
				return card
		return null

	## Everything hidden but `keeps`, what is inside them and the path to them.
	func _hide_all_but(keeps: Array[Node]) -> void:
		var path: Dictionary = {}
		for keep: Node in keeps:
			var node: Node = keep
			while node != null:
				path[node] = true
				node = node.get_parent()
		for node: Node in path:
			if keeps.has(node):
				continue
			for child: Node in node.get_children():
				if not path.has(child) and (child is CanvasItem or child is CanvasLayer):
					child.set("visible", false)

	func _counts() -> PackedInt32Array:
		var out: PackedInt32Array = PackedInt32Array()
		for m: int in MONITORS:
			out.append(int(Performance.get_monitor(m)))
		return out

	func _vram() -> float:
		return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

	func _row(text: String) -> void:
		print(text)
		_rows.append(text)

	func _write() -> void:
		if _out.is_empty():
			return
		DirAccess.make_dir_recursive_absolute(_out)
		for step: String in _frames:
			var image: Image = _frames[step]
			image.save_png(_out.path_join("%s.png" % step))
		var f: FileAccess = FileAccess.open(_out.path_join("rows.txt"), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_rows) + "\n")
			f.close()
