extends SceneTree
## Windowed proof of the card turn (CardView.turn and CardTurn, issue #657):
## that the live turn and the picture turn put the card in the same place, and
## that a turned card comes back to rest as the card it was built as. The suite
## proves the turn's state on a headless tree; this proves what it renders.
##
## Not a test: `tests/run_all.gd` only discovers `res://tests/test_*.gd`. It
## needs a real renderer, so it refuses `--headless` (exit 2):
##
##   godot --path . -s res://tools/check_card_turn.gd -- --out=<dir> [--card=bastion]
##
## Each card is drawn alone into a transparent target at the 2x oversample, so
## its stage lands texel for pixel. For every back in the catalogue, worn as
## the table's back through CardTurn.prewarm as a fight wears it:
##
##   AGREE   at each turned pose of the turn sheet (CardTurnSheet.POSES), the
##           live and the picture renders of one card: how many pixels one
##           covers and the other does not (alpha either side of 1/2), the
##           IoU of the two silhouettes, and the mean colour difference where
##           both cover. They share the pose maths and the slab, so they part
##           only on the rim's edge pixels and the cost gem (real in the live
##           turn, a decal in the picture turn) — and on the light: the live
##           turn's finish answers the angle, the picture's is a still.
##   DOWN    face down (180, 0): each render against the bake it shows.
##   EDGE    the default back's rows only: of the rows where the rim is the
##           card's outer edge, the share with a partly covered pixel just
##           outside it, each renderer's. The live stage multisamples; the
##           picture turn smooths its rim to match.
##   TINT    the unplayable dim (CardView's modulate) on a turned card: the
##           picture turn carries it as the live turn's canvas draw does.
##
## Then, once:
##
##   MIRROR  a back that reads one way round only (the default bake with a
##           block painted into its upper right), face down: each render
##           against that bake and against its mirror image.
##   HELD    a card under the pointer, tilted and lifted, turned by each
##           renderer: AGREE's numbers, for its tilt over the pose.
##   REST    a card turned to each pose by each renderer and back to rest is
##           the card as built: every pixel of it on the canvas and every
##           texel of its stage, max delta 0.
##   NOBACK  no back baked: the picture turn's far face is clear, as the live
##           turn's slab is without its plate, so it covers no more than the
##           live turn does.
##
## The table shadow is hidden in the target: it is the same scaled panel under
## both renderers, and its soft alpha would only blur the silhouettes compared.
##
## Exit 0 when every row passes its bound (the constants below) and every REST
## row is exact; 1 otherwise. --out= writes the rows.

const MIN_IOU: float = 0.985
const MAX_MEAN_DELTA: float = 24.0    # of 255, colour where both renders cover
## DOWN: each face-down render against the bake, mean colour of 255.
const DOWN_MAX_MEAN: float = 2.0
## MIRROR: the face-down render against the marked bake, mean colour of 255,
## and how many times nearer the bake it must be than the bake's mirror.
const MIRROR_MAX_MEAN: float = 4.0
const MIRROR_MARGIN: float = 4.0
const MARK: Color = Color(1.0, 0.0, 1.0)
## EDGE: the picture turn's share of softened rim-edge rows, at least this
## part of the live turn's, wherever the live turn shows 40 such rows or more.
const MIN_SOFT_SHARE: float = 0.6
## HELD: the pointer's tilt (degrees about x and y) and the hover's full lift.
const HELD_TILT: Vector2 = Vector2(5.0, -6.0)
## NOBACK: how many pixels more the picture turn may cover than the live one.
const NO_BACK_SLACK: int = 100
const SETTLE_FRAMES: int = 3
const REST_CARD: String = "strike"
## CardView's unplayable tint (`_apply_tint`).
const UNPLAYABLE: Color = Color(0.6, 0.6, 0.6, 0.8)

var _out: String = ""
var _card_id: String = CardTurnSheet.DEFAULT_CARD


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_card_turn: needs a real renderer; run it without --headless")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--card="):
			_card_id = arg.trim_prefix("--card=")
	CardView.oversample = 2.0
	var probe: Probe = Probe.new(_out, _card_id)
	probe.finished.connect(func(ok: bool) -> void: quit(0 if ok else 1))
	root.add_child(probe)


class Probe:
	extends Node
	signal finished(ok: bool)

	var _out: String = ""
	var _card_id: String = ""
	var _rows: PackedStringArray = PackedStringArray()
	var _catalog: Dictionary = {}

	func _init(out: String, card_id: String) -> void:
		_out = out
		_card_id = card_id

	func _ready() -> void:
		_catalog = CardLab.load_catalog(ContentDB.load_full())
		_row("RUN %s card=%s oversample=%.1f adapter=%s" % [
			Engine.get_version_info()["string"], _card_id, CardView.oversample,
			RenderingServer.get_video_adapter_name()])
		_run.call_deferred()

	func _row(text: String) -> void:
		print(text)
		_rows.append(text)

	func _frames(n: int) -> void:
		for _i: int in range(n):
			await get_tree().process_frame

	func _run() -> void:
		await _frames(10)
		var ok: bool = true
		for id: String in CardBacks.catalogue().ids():
			await CardTurn.prewarm(self, id)
			if CardTurn.back() == null:
				_row("FAIL %s did not bake" % id)
				ok = false
				continue
			var agreed: bool = await _agree(id)
			ok = ok and agreed
		ok = await _mirror() and ok
		ok = await _held() and ok
		ok = await _rest() and ok
		ok = await _no_back() and ok
		_row("RESULT %s" % ("PASS" if ok else "FAIL"))
		_write()
		finished.emit(ok)

	## A transparent target holding one card, its stage on the target's grid.
	func _target(card_id: String) -> Array:
		var target: SubViewport = SubViewport.new()
		target.transparent_bg = true
		var rect: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) \
			+ Vector2.ONE * CardView.PAD_3D * 2.0
		target.size = Vector2i(rect * CardView.oversample)
		target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var holder: Control = Control.new()
		holder.scale = Vector2.ONE * CardView.oversample
		target.add_child(holder)
		var data: Dictionary = _catalog.get(card_id, {})
		var cost_v: Variant = data.get("cost")
		var card: CardView = CardView.new(CardInst.new(1, StringName(card_id)), data,
			0 if cost_v == null else int(float(str(cost_v))))
		card.position = Vector2.ONE * CardView.PAD_3D
		holder.add_child(card)
		add_child(target)
		# The table shadow is the same panel under both renderers; see the header.
		card._shadow.visible = false
		return [target, card]

	func _agree(back_id: String) -> bool:
		var made: Array = _target(_card_id)
		var target: SubViewport = made[0]
		var card: CardView = made[1]
		await _frames(SETTLE_FRAMES + 2)
		var ok: bool = true
		var bake: Image = CardTurn.back().stage.get_image()
		if bake.has_mipmaps():
			bake.clear_mipmaps()
		for pose: Vector2 in CardTurnSheet.POSES:
			if CardTurn.is_rest(CardTurn.pose(pose.x, pose.y)):
				continue
			card.turn(pose.x, pose.y, true)
			await _frames(SETTLE_FRAMES)
			var live: Image = target.get_texture().get_image()
			card.turn(pose.x, pose.y, false)
			await _frames(SETTLE_FRAMES)
			var picture: Image = target.get_texture().get_image()
			var cmp: Dictionary = _compare(live, picture)
			var good: bool = cmp["iou"] >= MIN_IOU and cmp["mean"] <= MAX_MEAN_DELTA
			ok = ok and good
			_row("AGREE %s yaw=%d pitch=%d iou=%.4f coverage_differs=%d of %d mean_delta=%.1f %s" % [
				back_id, roundi(pose.x), roundi(pose.y), cmp["iou"], cmp["differs"],
				cmp["covered"], cmp["mean"], "ok" if good else "FAIL"])
			if back_id == CardBacks.catalogue().default_id:
				ok = _edge(pose, live, picture, card._side) and ok
				if pose == CardTurnSheet.POSES[1]:
					ok = await _tint(target, card, pose) and ok
			if is_equal_approx(pose.x, 180.0) and is_equal_approx(pose.y, 0.0):
				var to_live: Dictionary = _compare(live, bake)
				var to_picture: Dictionary = _compare(picture, bake)
				var down: bool = to_live["mean"] <= DOWN_MAX_MEAN and to_picture["mean"] <= DOWN_MAX_MEAN
				ok = ok and down
				_row("DOWN %s live_vs_bake iou=%.4f mean_delta=%.1f picture_vs_bake iou=%.4f mean_delta=%.1f max=%d %s" % [
					back_id, to_live["iou"], to_live["mean"], to_picture["iou"],
					to_picture["mean"], to_picture["max"], "ok" if down else "FAIL"])
		target.queue_free()
		return ok

	## The rim's outer edge, softened as the live stage's multisampling does.
	func _edge(pose: Vector2, live: Image, picture: Image, side: Color) -> bool:
		var by_live: Vector2i = _soft_edge(live, side)
		var by_picture: Vector2i = _soft_edge(picture, side)
		var live_share: float = float(by_live.x) / float(maxi(by_live.y, 1))
		var picture_share: float = float(by_picture.x) / float(maxi(by_picture.y, 1))
		var good: bool = by_live.y < 40 or picture_share >= live_share * MIN_SOFT_SHARE
		_row("EDGE yaw=%d pitch=%d live_soft=%d of %d picture_soft=%d of %d %s" % [
			roundi(pose.x), roundi(pose.y), by_live.x, by_live.y, by_picture.x, by_picture.y,
			"ok" if good else "FAIL"])
		return good

	## Rows whose outermost opaque pixel, from either side, is the rim's colour,
	## and of those the ones with a partly covered pixel just outside it.
	static func _soft_edge(img: Image, side: Color) -> Vector2i:
		var w: int = img.get_width()
		var soft: int = 0
		var rows: int = 0
		for y: int in range(img.get_height()):
			for from_left: bool in [true, false]:
				var x: int = 0 if from_left else w - 1
				var step: int = 1 if from_left else -1
				while x >= 0 and x < w and img.get_pixel(x, y).a <= 0.94:
					x += step
				if x < 0 or x >= w:
					continue
				var c: Color = img.get_pixel(x, y)
				if absf(c.r - side.r) + absf(c.g - side.g) + absf(c.b - side.b) > 0.16:
					continue
				rows += 1
				for k: int in [1, 2]:
					var out: int = x - step * k
					if out >= 0 and out < w:
						var a: float = img.get_pixel(out, y).a
						if a > 0.06 and a < 0.94:
							soft += 1
							break
		return Vector2i(soft, rows)

	## A back that reads one way round only, face down by each renderer: it
	## must show the block where the bake has it, never mirrored.
	func _mirror() -> bool:
		var id: String = CardBacks.catalogue().default_id
		await CardTurn.prewarm(self, id)
		var marked: CardBacks.Baked = _marked(CardTurn.back())
		# Worn through the bake's own seam, so the table wears it as a fight would.
		CardBacks.use_catalogue(null)
		CardBacks.use_renderer(func(_host: Node, _id: String, _scale: float) -> CardBacks.Baked:
			return marked)
		await CardTurn.prewarm(self, id)
		CardBacks.use_renderer(Callable())
		var made: Array = _target(_card_id)
		var target: SubViewport = made[0]
		var card: CardView = made[1]
		await _frames(SETTLE_FRAMES + 2)
		var want: Image = marked.stage.get_image()
		var mirrored: Image = want.duplicate() as Image
		mirrored.flip_x()
		var ok: bool = CardTurn.back() == marked
		var parts: PackedStringArray = PackedStringArray()
		for live: bool in [true, false]:
			card.turn(180.0, 0.0, live)
			await _frames(SETTLE_FRAMES)
			var got: Image = target.get_texture().get_image()
			var same: float = _compare(got, want)["mean"]
			var other: float = _compare(got, mirrored)["mean"]
			ok = ok and same <= MIRROR_MAX_MEAN and same * MIRROR_MARGIN < other
			parts.append("%s same=%.1f mirrored=%.1f" % ["live" if live else "picture", same, other])
		_row("MIRROR %s %s" % [" ".join(parts), "ok" if ok else "FAIL"])
		CardBacks.use_catalogue(null)
		target.queue_free()
		return ok

	## `real` with a block of MARK in its upper right, on the stage the
	## picture turn draws and on the face the plate wears alike.
	static func _marked(real: CardBacks.Baked) -> CardBacks.Baked:
		# The block, in card px from the card's centre: x right, y up.
		var block: Rect2 = Rect2(CardView.CARD_W * 0.12, CardView.CARD_H * 0.12,
			CardView.CARD_W * 0.28, CardView.CARD_H * 0.26)
		var stage: Image = real.stage.get_image()
		var inner: Image = real.inner.get_image()
		for img: Image in [stage, inner]:
			if img.has_mipmaps():
				img.clear_mipmaps()
			var centre: Vector2 = Vector2(img.get_size()) * 0.5 / real.oversample
			var at: Vector2 = centre + Vector2(block.position.x, -block.end.y)
			img.fill_rect(Rect2i(Vector2i((at * real.oversample).round()),
				Vector2i((block.size * real.oversample).round())), MARK)
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.stage = ImageTexture.create_from_image(stage)
		out.inner = ImageTexture.create_from_image(inner)
		out.plate = real.plate.duplicate() as ShaderMaterial
		out.plate.set_shader_parameter("face_tex", out.inner)
		out.oversample = real.oversample
		return out

	## A card under the pointer, tilted and lifted, turned by each renderer.
	func _held() -> bool:
		await CardTurn.prewarm(self, CardBacks.catalogue().default_id)
		var made: Array = _target(_card_id)
		var target: SubViewport = made[0]
		var card: CardView = made[1]
		await _frames(SETTLE_FRAMES + 2)
		card._tilt = HELD_TILT
		card._lift = CardView.MAX_LIFT
		card._apply_transform()
		var ok: bool = true
		for pose: Vector2 in [CardTurnSheet.POSES[2], CardTurnSheet.POSES[4]]:
			card.turn(pose.x, pose.y, true)
			await _frames(SETTLE_FRAMES)
			var live: Image = target.get_texture().get_image()
			card.turn(pose.x, pose.y, false)
			await _frames(SETTLE_FRAMES)
			var cmp: Dictionary = _compare(live, target.get_texture().get_image())
			var good: bool = cmp["iou"] >= MIN_IOU and cmp["mean"] <= MAX_MEAN_DELTA
			ok = ok and good
			_row("HELD yaw=%d pitch=%d tilt=%s lift=%.0f iou=%.4f coverage_differs=%d of %d mean_delta=%.1f %s" % [
				roundi(pose.x), roundi(pose.y), str(HELD_TILT), CardView.MAX_LIFT, cmp["iou"],
				cmp["differs"], cmp["covered"], cmp["mean"], "ok" if good else "FAIL"])
		target.queue_free()
		return ok

	## No back baked: the picture turn shows its far face clear, so it covers
	## no more of the target than the live turn does without its plate.
	func _no_back() -> bool:
		CardBacks.use_catalogue(null)
		var made: Array = _target(_card_id)
		var target: SubViewport = made[0]
		var card: CardView = made[1]
		await _frames(SETTLE_FRAMES + 2)
		var ok: bool = CardTurn.back() == null
		for pose: Vector2 in [CardTurnSheet.POSES[4], CardTurnSheet.POSES[5]]:
			var covered: Array[int] = []
			for live: bool in [true, false]:
				card.turn(pose.x, pose.y, live)
				await _frames(SETTLE_FRAMES)
				covered.append(_covered(target.get_texture().get_image()))
			var good: bool = covered[1] <= covered[0] + NO_BACK_SLACK
			ok = ok and good
			_row("NOBACK yaw=%d pitch=%d live_covered=%d picture_covered=%d %s" % [
				roundi(pose.x), roundi(pose.y), covered[0], covered[1], "ok" if good else "FAIL"])
		target.queue_free()
		return ok

	## The unplayable dim on a turned card, through both renderers.
	func _tint(target: SubViewport, card: CardView, pose: Vector2) -> bool:
		card.modulate = UNPLAYABLE
		card.turn(pose.x, pose.y, true)
		await _frames(SETTLE_FRAMES)
		var live: Image = target.get_texture().get_image()
		card.turn(pose.x, pose.y, false)
		await _frames(SETTLE_FRAMES)
		var cmp: Dictionary = _compare(live, target.get_texture().get_image())
		card.modulate = Color.WHITE
		var good: bool = cmp["iou"] >= MIN_IOU and cmp["mean"] <= MAX_MEAN_DELTA
		_row("TINT yaw=%d pitch=%d modulate=%s iou=%.4f mean_delta=%.1f %s" % [
			roundi(pose.x), roundi(pose.y), str(UNPLAYABLE), cmp["iou"], cmp["mean"],
			"ok" if good else "FAIL"])
		return good

	func _rest() -> bool:
		var made: Array = _target(REST_CARD)
		var target: SubViewport = made[0]
		var card: CardView = made[1]
		await _frames(SETTLE_FRAMES + 2)
		var canvas0: Image = target.get_texture().get_image()
		var stage0: Image = card.stage_texture().get_image()
		var ok: bool = true
		for live: bool in [true, false]:
			for pose: Vector2 in CardTurnSheet.POSES:
				card.turn(pose.x, pose.y, live)
				await _frames(SETTLE_FRAMES)
				card.turn(0.0, 0.0, live)
				await _frames(SETTLE_FRAMES)
				var canvas: Dictionary = _compare(canvas0, target.get_texture().get_image())
				var stage: Dictionary = _compare(stage0, card.stage_texture().get_image())
				var exact: bool = canvas["max"] == 0 and stage["max"] == 0
				ok = ok and exact
				_row("REST %s yaw=%d pitch=%d canvas_max=%d stage_max=%d %s" % [
					"live" if live else "picture", roundi(pose.x), roundi(pose.y),
					canvas["max"], stage["max"], "ok" if exact else "FAIL"])
		target.queue_free()
		return ok

	## The pixels a render covers: alpha past 1/2.
	static func _covered(img: Image) -> int:
		var n: int = 0
		for y: int in range(img.get_height()):
			for x: int in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.5:
					n += 1
		return n

	## Two renders of one size: the silhouettes (alpha past 1/2) and the colour.
	static func _compare(a: Image, b: Image) -> Dictionary:
		var w: int = mini(a.get_width(), b.get_width())
		var h: int = mini(a.get_height(), b.get_height())
		var either: int = 0
		var both: int = 0
		var sum: float = 0.0
		var most: int = 0
		for y: int in range(h):
			for x: int in range(w):
				var ca: Color = a.get_pixel(x, y)
				var cb: Color = b.get_pixel(x, y)
				most = maxi(most, roundi(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)),
					maxf(absf(ca.b - cb.b), absf(ca.a - cb.a))) * 255.0))
				var in_a: bool = ca.a > 0.5
				var in_b: bool = cb.a > 0.5
				if in_a or in_b:
					either += 1
				if in_a and in_b:
					both += 1
					sum += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
		return {"iou": float(both) / float(maxi(either, 1)), "differs": either - both,
			"covered": either, "mean": sum / float(maxi(both, 1)) * 255.0, "max": most}

	func _write() -> void:
		if _out == "":
			return
		DirAccess.make_dir_recursive_absolute(_out)
		var f: FileAccess = FileAccess.open(_out.path_join("card-turn-rows.txt"), FileAccess.WRITE)
		if f == null:
			printerr("check_card_turn: cannot write to %s" % _out)
			return
		f.store_string("\n".join(_rows) + "\n")
