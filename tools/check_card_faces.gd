extends SceneTree
## Windowed proof of the baked card faces (presentation/cards/card_faces.gd,
## issue #657 PR 2): that the deck overlay's and the deck pickers' baked cards
## show the live cards' texels, and that pointing at them hands over to a live
## card and back unseen. The suite proves the bake's job rules on a fake frame,
## because a headless run never draws one; this proves the real one.
##
## Not a test: `tests/run_all.gd` only discovers `res://tests/test_*.gd`. It
## needs a real renderer, so it refuses `--headless` (exit 2). It boots the
## game on the map (the Development profile, as any launch with an argument),
## so the window, shape and language flags are the game's own. A Mac is a
## desktop, which is only ever given the pad or desktop composition: the phone
## needs its shape named, or an 844x390 window shows the desktop's letterboxed.
##
##   godot --path . -s res://tools/check_card_faces.gd -- --map --seed=1 \
##     --vp=1180x820 [--shape=phone-landscape] [--locale=zh-Hant] [--picker] \
##     [--out=<dir>]
##
## The run's deck is shown with a rare, a power, a free card, an upgraded card
## and the longest rules text first, then the starter deck, so the first rows
## on screen cover every kind of face: in the deck overlay, or with --picker in
## a deck picker (the stall's removal, which the rest's temper and an event's
## pick share), whose cards are larger and can be chosen. It opens on an empty
## cache, the session's first, and once every face has landed:
##
##   LIVE   no live card stands under the view: each bake's was freed.
##   SAME   for every card at least a third on screen, the frame with its
##          baked face against the frame with a live card standing in for it
##          at rest, over the card and its shadow's reach: every channel of
##          every pixel, within the card's tolerance (`_tolerance`).
##          A rare's gilt shine runs on TIME, so two frames never agree on it;
##          it is hidden on both sides of the comparison (it is the same node,
##          CardView.shine, on both). So are the map, the HUD and the film
##          grain, which move under the overlay's glass.
##   FIRST  the first frame the live card is drawn in, against the baked one:
##          the swap shows no empty or half-drawn frame.
##   BACK   a pointer visits the first card and leaves: a live card stood in,
##          sprang back and gave way, and the frame is the baked one again.
##   HANDOVER  the pointer goes straight from the first card to the second:
##          the first is still springing back (lifted, not snapped flat) on
##          the frame the second stands in, both give way, and the frame is
##          the baked one again.
##   ENTER  a card brought under a resting cursor (its enter alone, as a wheel
##          scroll gives it) stands in, and gives way when the cursor leaves.
##   TEXEL  for every distinct face, its picture against the same crop of a
##          settled live card's stage read back: every RGBA channel of every
##          texel, and nothing the stage drew lies outside the crop.
##
## Exit 0 when every check holds, 1 otherwise. --out= also writes the rows and
## four stills: the view, each compared card baked (top) over live (bottom),
## the cold open as it fills (a frame every few, until every face landed), and
## the handover's first frame.

## On screen, per channel, of 255. A face is the stage cropped to its reach,
## laid on the live stage's own quad (CardView.picture), so the canvas samples
## the same texels at the same points. A card drawn unscaled matches exactly.
## A scaled one is filtered between texels, and its UVs, interpolated over a
## wider range, can round a filter weight a step apart: one level, on a few
## edge pixels. Measured on this Mac (Metal), every reference shape, both
## locales, the overlay and the picker: 0 unscaled; scaled, at most 1, on at
## most 0.08 % of a card's pixels. A drift of the whole card, or of an edge by
## more than a level, fails. The texels themselves must match exactly.
const EXACT_DELTA: int = 0
const SCALED_DELTA: int = 1
## The share of a scaled card's pixels that may differ at all.
const SCALED_SHARE: float = 0.002
## A tooling window may run unthrottled, so a settle is a time and a few
## frames, never frames alone: past a face's fade-in and a card's first draws.
const SETTLE_SECONDS: float = 0.5
const SETTLE_FRAMES: int = 4
const LAND_SECONDS: float = 10.0   # the most the faces may take to land
## The cold open's still: a frame every STRIP_EVERY while the faces land.
const STRIP_EVERY: int = 3
const STRIP_MAX: int = 15
## How far the table shadow reaches past the card's right and bottom edges, in
## card px: the heaviest stock's blur plus its drop.
const REACH: Vector2 = Vector2(16.0, 26.0)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_card_faces: needs a real renderer; run it without --headless")
		quit(2)
		return
	var out: String = ""
	var picker: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--picker":
			picker = true
	var main: Node = (load("res://application/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	var probe: Probe = Probe.new(main, out, picker)
	probe.finished.connect(func(ok: bool) -> void: quit(0 if ok else 1))
	root.add_child(probe)


class Probe:
	extends Node
	signal finished(ok: bool)

	var _main: Node = null
	var _out: String = ""
	var _picker: bool = false
	var _rows: PackedStringArray = PackedStringArray()
	var _pairs: Array[Image] = []
	## The cold open as it fills.
	var _strip: Array[Image] = []
	## The frame a handover is caught in: the first card springing back beside
	## the second's live card.
	var _caught: Image = null

	func _init(main: Node, out: String, picker: bool) -> void:
		_main = main
		_out = out
		_picker = picker

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		await _settle()
		await _settle()
		_deal_the_deck()
		CardFaces.forget()
		var modal: Node = _open()
		var cards: Array[BakedCard] = []
		for node: Node in modal.find_children("", "BakedCard", true, false):
			cards.append(node as BakedCard)
		var until: int = Time.get_ticks_msec() + int(LAND_SECONDS * 1000.0)
		var frame_i: int = 0
		while Time.get_ticks_msec() < until:
			if cards.all(func(c: BakedCard) -> bool: return c.face() != null):
				break
			if frame_i % STRIP_EVERY == 0 and _strip.size() < STRIP_MAX:
				_strip.append(await _frame())
			else:
				await get_tree().process_frame
			frame_i += 1
		await _settle()
		_strip.append(await _frame())
		_row("RUN %s locale=%s shape=%s window=%s frame=%s view=%s cards=%d faces=%d" % [
			Engine.get_version_info()["string"], Locale.active.code, str(_main.get("_shape")),
			str(get_window().size), str(get_tree().root.get_texture().get_size()),
			"picker" if _picker else "overlay", cards.size(), CardFaces.count()])
		var ok: bool = cards.all(func(c: BakedCard) -> bool: return c.face() != null)
		if not ok:
			_row("FAIL a face never landed")
		var standing: int = _standing(modal)
		_row("LIVE %d live cards under the view once every face landed" % standing)
		ok = standing == 0 and ok
		var overlay: Image = await _frame()
		# The map, the HUD and the film grain move under the overlay's glass;
		# hidden for the comparison, they leave only the cards to differ.
		var hidden: Array[Node] = _hide_all_but(modal)
		for card: BakedCard in cards:
			_shine(card, false)
		await _settle()
		var baked: Image = await _frame()
		var view: Rect2 = _visible_rect(cards)
		var compared: int = 0
		for card: BakedCard in cards:
			# The scroll clips both sides alike: compare what shows of the card
			# and its reach, wherever at least a third of the card shows.
			if not _shows(card, view):
				continue
			var area: Rect2i = _area(card, Vector2(CardView.PAD_IN, CardView.PAD_IN),
				REACH).intersection(Rect2i(view))
			card.go_live()
			_shine(card.live(), false)
			var first: Image = await _frame()
			await _settle()
			var settled: Image = await _frame()
			card.go_rest()
			ok = _same("SAME", card, baked, settled, area) and ok
			ok = _same("FIRST", card, baked, first, area) and ok
			_pairs.append(baked.get_region(area))
			_pairs.append(settled.get_region(area))
			compared += 1
		if compared == 0:
			_row("FAIL no card showed")
			ok = false
		else:
			ok = await _round_trip(cards, baked, view) and ok
			ok = await _handover(cards, baked, view) and ok
			ok = await _enter(cards, view) and ok
		for card: BakedCard in cards:
			_shine(card, true)
		for node: Node in hidden:
			node.set("visible", true)
		ok = await _texels(cards) and ok
		_row("RESULT %s (%d cards compared)" % ["PASS" if ok else "FAIL", compared])
		_write(overlay)
		finished.emit(ok)

	## The view under test, opened: the deck overlay, or the stall's removal
	## picker over the same deck.
	func _open() -> Node:
		if not _picker:
			_main.call("_show_run_deck")
			return _main.get("_modal")
		var rows: Array[Dictionary] = []
		for row: Dictionary in _main.call("_deck_rows"):
			row["disabled"] = false
			rows.append(row)
		_main.call("_show_choice",
			Locale.active.t("ui.shop.cardRemoval.pickTitle").to_upper(),
			Locale.active.t("ui.shop.cardRemoval.confirmBody"), rows,
			func(_id: String) -> void: pass, {"overlay": true})
		return _main.get("_choice_screen")

	## The pointer goes straight from one card to the next: the first springs
	## back beside the second's live card rather than snapping flat, then both
	## give way to their faces.
	func _handover(cards: Array[BakedCard], baked: Image, view: Rect2) -> bool:
		var shown: Array[BakedCard] = []
		for each: BakedCard in cards:
			if _shows(each, view):
				shown.append(each)
		if shown.size() < 2:
			_row("HANDOVER skipped: fewer than two cards show")
			return true
		var a: BakedCard = shown[0]
		var b: BakedCard = shown[1]
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = Vector2(CardView.CARD_W * 0.8, CardView.CARD_H * 0.2)
		a._gui_input(motion)
		_shine(a.live(), false)
		await _settle()
		b._gui_input(motion)
		a.notification(Control.NOTIFICATION_MOUSE_EXIT)
		_shine(b.live(), false)
		var mid: Image = await _frame()
		var springing: bool = a.live() != null and not a.live().at_rest()
		_caught = mid.get_region(_area(a, Vector2(CardView.PAD_3D, CardView.PAD_3D),
			REACH).merge(_area(b, Vector2(CardView.PAD_3D, CardView.PAD_3D), REACH)))
		# The first comes to rest by itself beside the second, then the second
		# is left too.
		var t0: int = Time.get_ticks_msec()
		while a.live() != null and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
		var gave_way: int = Time.get_ticks_msec() - t0
		var t1: int = Time.get_ticks_msec()
		b.notification(Control.NOTIFICATION_MOUSE_EXIT)
		while b.live() != null and Time.get_ticks_msec() - t1 < 3000:
			await get_tree().process_frame
		_shine(a, false)
		_shine(b, false)
		await _settle()
		var after: Image = await _frame()
		_row("HANDOVER %s->%s springing=%s gave_way_ms=%d" % [a.inst.id, b.inst.id,
			str(springing), gave_way])
		var ok: bool = springing and a.live() == null and b.live() == null
		for card: BakedCard in [a, b]:
			var area: Rect2i = _area(card, Vector2(CardView.PAD_IN, CardView.PAD_IN),
				REACH).intersection(Rect2i(view))
			ok = _same("HANDOVER", card, baked, after, area) and ok
		return ok

	## A card brought under a resting cursor stands in on its enter alone.
	func _enter(cards: Array[BakedCard], view: Rect2) -> bool:
		var card: BakedCard = null
		for each: BakedCard in cards:
			if _shows(each, view):
				card = each
		card.notification(Control.NOTIFICATION_MOUSE_ENTER)
		var stood: bool = card.live() != null
		var t0: int = Time.get_ticks_msec()
		card.notification(Control.NOTIFICATION_MOUSE_EXIT)
		while card.live() != null and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
		_row("ENTER %s stood_live=%s gave_way=%s" % [card.inst.id, str(stood),
			str(card.live() == null)])
		_shine(card, false)
		return stood and card.live() == null

	## A pointer visits a card and leaves: the live card stands in, springs
	## back, and gives way to the face, which is the frame before the visit.
	func _round_trip(cards: Array[BakedCard], baked: Image, view: Rect2) -> bool:
		var card: BakedCard = null
		for each: BakedCard in cards:
			if _shows(each, view):
				card = each
				break
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = Vector2(CardView.CARD_W * 0.25, CardView.CARD_H * 0.3)
		card._gui_input(motion)
		_shine(card.live(), false)
		await _settle()
		var lifted: bool = card.live() != null
		var t0: int = Time.get_ticks_msec()
		card.notification(Control.NOTIFICATION_MOUSE_EXIT)
		while card.live() != null and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
		var gave_way: int = Time.get_ticks_msec() - t0
		# The face is back, its shine with it: hide that again, as for the rest.
		_shine(card, false)
		await _settle()
		var after: Image = await _frame()
		var area: Rect2i = _area(card, Vector2(CardView.PAD_IN, CardView.PAD_IN),
			REACH).intersection(Rect2i(view))
		_row("BACK %s stood_live=%s gave_way_ms=%d" % [card.inst.id, str(lifted), gave_way])
		return _same("BACK", card, baked, after, area) and lifted and card.live() == null

	## A rare, a power, a free card, an upgrade and the longest rules first.
	func _deal_the_deck() -> void:
		var run: RunState = _main.get("game").run
		var content: ContentDB = _main.get("content")
		var ids: Array = content.cards.keys()
		ids.sort()
		var picks: Array[CardInst] = []
		var want: Array[Callable] = [
			func(row: Dictionary) -> bool: return str(row.get("rarity", "")) == "rare",
			func(row: Dictionary) -> bool: return str(row.get("type", "")) == "power",
			func(row: Dictionary) -> bool: return row.get("cost") != null and float(str(row.get("cost"))) == 0.0,
			func(row: Dictionary) -> bool: return row.has("up") and str(row.get("rarity", "")) != "starter",
		]
		for rule: Callable in want:
			for id_v: Variant in ids:
				var row: Dictionary = content.cards[id_v]
				if ["attack", "skill", "power"].has(str(row.get("type", ""))) and rule.call(row):
					picks.append(CardInst.new(run.next_uid(), StringName(str(id_v)),
						row.has("up") and picks.size() == 3))
					break
		var longest: String = ""
		var most: int = -1
		for id_v: Variant in ids:
			var row: Dictionary = content.cards[id_v]
			var text: String = str(row.get("text", ""))
			if ["attack", "skill", "power"].has(str(row.get("type", ""))) and text.length() > most:
				longest = str(id_v)
				most = text.length()
		picks.append(CardInst.new(run.next_uid(), StringName(longest), false))
		var deck: Array[CardInst] = picks
		deck.append_array(run.player.deck)
		run.player.deck = deck

	func _same(kind: String, card: BakedCard, want: Image, got: Image, area: Rect2i) -> bool:
		var allowed: int = _tolerance(card)
		var worst: int = 0
		var differ: int = 0
		var over: int = 0
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var a: Color = want.get_pixel(x, y)
				var b: Color = got.get_pixel(x, y)
				var d: int = roundi(255.0 * maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)),
					absf(a.b - b.b)))
				worst = maxi(worst, d)
				differ += 1 if d > 0 else 0
				over += 1 if d > allowed else 0
		_row("%s %s%s scale=%.3f allowed=%d max_delta=%d px_differ=%d px_over=%d of %d" % [
			kind, card.inst.id, "+" if card.inst.up else "", _scale(card), allowed, worst,
			differ, over, area.get_area()])
		return worst <= allowed and float(differ) <= SCALED_SHARE * float(area.get_area())

	## How far a card's pixels may differ: nothing where it is drawn unscaled,
	## a filter's rounding where it is scaled.
	func _tolerance(card: Control) -> int:
		return EXACT_DELTA if is_equal_approx(_scale(card), 1.0) else SCALED_DELTA

	## The card's scale in the window's pixels.
	func _scale(card: Control) -> float:
		return (get_viewport().get_final_transform() \
			* card.get_global_transform_with_canvas()).get_scale().x

	## The live cards under `root` that are not on their way out.
	func _standing(root: Node) -> int:
		var n: int = 0
		for node: Node in root.find_children("", "CardView", true, false):
			n += 0 if node.is_queued_for_deletion() else 1
		return n

	## Every distinct face against a settled live card of it, texel by texel.
	func _texels(cards: Array[BakedCard]) -> bool:
		var ok: bool = true
		var seen: Dictionary = {}
		for card: BakedCard in cards:
			var face: CardFaces.Face = card.face()
			if face == null or seen.has(face):
				continue
			seen[face] = true
			var live: CardView = card.stand_in()
			live.visible = false
			add_child(live)
			await _settle()
			var stage: Image = live.stage_image()
			var want: Image = stage.get_region(CardFaces.crop_of(stage.get_size()))
			var drawn: Rect2i = stage.get_used_rect()
			live.queue_free()
			var got: Image = face.picture.get_image()
			var worst: int = 0
			for y: int in range(want.get_height()):
				for x: int in range(want.get_width()):
					var a: Color = want.get_pixel(x, y)
					var b: Color = got.get_pixel(x, y)
					worst = maxi(worst, roundi(255.0 * maxf(
						maxf(absf(a.r - b.r), absf(a.g - b.g)),
						maxf(absf(a.b - b.b), absf(a.a - b.a)))))
			# Nothing the stage drew may lie outside the crop.
			var kept: bool = CardFaces.crop_of(stage.get_size()).encloses(drawn)
			_row("TEXEL %s%s %s max_delta=%d (%dx%d of %dx%d, %s, %s)" % [card.inst.id,
				"+" if card.inst.up else "", face.picture.get_class(), worst,
				got.get_width(), got.get_height(), stage.get_width(), stage.get_height(),
				"same size" if got.get_size() == want.get_size() else "SIZE DIFFERS",
				"all drawn texels kept" if kept else "DRAWN TEXELS CUT"])
			ok = ok and worst == 0 and got.get_size() == want.get_size() and kept
		return ok

	## Where the card lands in the window's pixels, grown by `before` up and
	## left (the cost gem's reach) and `after` down and right (the shadow's).
	func _area(card: Control, before: Vector2, after: Vector2) -> Rect2i:
		var to_window: Transform2D = get_viewport().get_final_transform() \
			* card.get_global_transform_with_canvas()
		var lo: Vector2 = to_window * -before
		var hi: Vector2 = to_window * (Vector2(CardView.CARD_W, CardView.CARD_H) + after)
		return Rect2i(Vector2i(floori(lo.x), floori(lo.y)),
			Vector2i(ceili(hi.x - lo.x), ceili(hi.y - lo.y)))

	func _shows(card: BakedCard, view: Rect2) -> bool:
		var body: Rect2 = Rect2(_area(card, Vector2.ZERO, Vector2.ZERO))
		return body.intersection(view).get_area() >= body.get_area() / 3.0

	## The scroll's window, in the window's pixels.
	func _visible_rect(cards: Array[BakedCard]) -> Rect2:
		if cards.is_empty():
			return Rect2()
		var scroll: Control = cards[0].get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent() as Control
		var xf: Transform2D = get_viewport().get_final_transform() \
			* scroll.get_global_transform_with_canvas()
		return Rect2(xf * Vector2.ZERO, xf.basis_xform(scroll.size))

	func _hide_all_but(keep: Node) -> Array[Node]:
		var hidden: Array[Node] = []
		for node: Node in _main.get_children():
			if node != keep and (node is CanvasItem or node is CanvasLayer) \
					and node.get("visible") == true:
				node.set("visible", false)
				hidden.append(node)
		return hidden

	func _shine(card: Control, on: bool) -> void:
		if card == null:
			return
		for node: Node in card.find_children("", "ColorRect", false, false):
			(node as ColorRect).visible = on

	## The cold open, five frames to a row at half size, in order.
	func _write_strip(tag: String) -> void:
		if _strip.is_empty():
			return
		var w: int = _strip[0].get_width() / 2
		var h: int = _strip[0].get_height() / 2
		var across: int = mini(5, _strip.size())
		var down: int = ceili(float(_strip.size()) / float(across))
		var sheet: Image = Image.create(w * across, h * down, false, Image.FORMAT_RGBA8)
		for i: int in range(_strip.size()):
			var still: Image = _strip[i]
			still.convert(Image.FORMAT_RGBA8)
			still.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(still, Rect2i(0, 0, w, h), Vector2i(w * (i % across), h * (i / across)))
		sheet.save_png(_out.path_join("open-strip-%s.png" % tag))

	func _frame() -> Image:
		await RenderingServer.frame_post_draw
		return get_tree().root.get_texture().get_image()

	func _settle() -> void:
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		for _i: int in range(SETTLE_FRAMES):
			await get_tree().process_frame

	func _row(text: String) -> void:
		print(text)
		_rows.append(text)

	func _write(overlay: Image) -> void:
		if _out.is_empty():
			return
		DirAccess.make_dir_recursive_absolute(_out)
		var tag: String = "%s%s" % [Locale.active.code, "-picker" if _picker else ""]
		overlay.save_png(_out.path_join("overlay-%s.png" % tag))
		_write_strip(tag)
		if _caught != null:
			_caught.save_png(_out.path_join("handover-%s.png" % tag))
		if not _pairs.is_empty():
			var w: int = _pairs[0].get_width()
			var h: int = _pairs[0].get_height()
			var n: int = _pairs.size() / 2
			var sheet: Image = Image.create(w * n, h * 2, false, Image.FORMAT_RGBA8)
			for i: int in range(n):
				var top: Image = _pairs[i * 2]
				var bottom: Image = _pairs[i * 2 + 1]
				top.convert(Image.FORMAT_RGBA8)
				bottom.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i(w * i, 0))
				sheet.blit_rect(bottom, Rect2i(Vector2i.ZERO, bottom.get_size()), Vector2i(w * i, h))
			sheet.save_png(_out.path_join("baked-over-live-%s.png" % tag))
		var f: FileAccess = FileAccess.open(_out.path_join("rows-%s.txt" % tag), FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_rows) + "\n")
			f.close()
