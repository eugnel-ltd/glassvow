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
##           only on the anti-aliased rim and the cost gem (real in the live
##           turn, a decal in the picture turn) — and on the light: the live
##           turn's finish answers the angle, the picture's is a still.
##   DOWN    face down (180, 0): each render against the bake it shows.
##   REST    a card turned to each pose by each renderer and back to rest is
##           the card as built: every pixel of it on the canvas and every
##           texel of its stage, max delta 0.
##
## The table shadow is hidden in the target: it is the same scaled panel under
## both renderers, and its soft alpha would only blur the silhouettes compared.
##
## Exit 0 when every AGREE row stays within MIN_IOU and MAX_MEAN_DELTA and
## every REST row is exact; 1 otherwise. --out= writes the rows.

const MIN_IOU: float = 0.985
const MAX_MEAN_DELTA: float = 24.0    # of 255, colour where both renders cover
const SETTLE_FRAMES: int = 3
const REST_CARD: String = "strike"

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
		var rested: bool = await _rest()
		ok = ok and rested
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
			if is_equal_approx(pose.x, 180.0) and is_equal_approx(pose.y, 0.0):
				var to_live: Dictionary = _compare(live, bake)
				var to_picture: Dictionary = _compare(picture, bake)
				_row("DOWN %s live_vs_bake iou=%.4f mean_delta=%.1f picture_vs_bake iou=%.4f mean_delta=%.1f max=%d" % [
					back_id, to_live["iou"], to_live["mean"], to_picture["iou"],
					to_picture["mean"], to_picture["max"]])
		target.queue_free()
		return ok

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
