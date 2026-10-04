extends SceneTree
## Windowed proof of the card back baker (presentation/cards/card_backs.gd,
## issue #657): what the live render step makes, what it costs, and that it
## is the card. The suite proves the bake's job rules on a fake render step,
## because a headless run never draws a frame; this proves the real one.
##
## Not a test: `tests/run_all.gd` only discovers `res://tests/test_*.gd`. It
## needs a real renderer, so it refuses `--headless` (exit 2):
##
##   godot --path . -s res://tools/check_card_back_bake.gd -- --out=<dir>
##
## For every back in the catalogue, in a fresh process:
##
##   BAKE      the first bake's wall time, its longest frame (the first-use
##             shader compile stalls the draw it lands in), the frames it
##             spanned, the video memory it holds once its host has taken the
##             hidden card away, and a cached repeat;
##   KEPT      the bake's card stays under its host, hidden, both passes
##             frozen, and leaves with it (CardView.retire);
##   SAME      the bake's stage against a live card's, settled for 12 frames:
##             every RGBA channel of every texel, rim, corners and alpha too;
##   EDGE      what the stage's alpha edge is: the share of partly covered
##             texels whose colour exceeds their coverage (0 means the colour is
##             premultiplied by coverage), and at 1/4 and 1/8 scale (mip levels
##             2 and 3) how much darker the rim composites with the canvas's
##             default straight blend than with a premultiplied one;
##   SHARED    two bakes asked for at once build one card and get one bake.
##
## Exit 0 when every back bakes, matches its live card within MAX_DELTA on
## every channel, its card is kept as KEPT says, and the shared bake builds
## once; 1 otherwise. --out= also
## writes the rows and a still: live cards over their bakes, then each bake at
## 1/4 and 1/8 with mipmaps, straight blend left of premultiplied.

const MAX_DELTA: int = 2           # of 255, per channel, bake against live
const SETTLE_FRAMES: int = 12
const BACKDROP: Color = Color(0.043, 0.055, 0.102)

var _out: String = ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_card_back_bake: needs a real renderer; run it without --headless")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	var probe: Probe = Probe.new(_out)
	probe.finished.connect(func(ok: bool) -> void: quit(0 if ok else 1))
	root.add_child(probe)


## The proof itself, as a node, so a device build can attach it to the
## running game (the title) and read its rows back from user://.
class Probe:
	extends Control
	signal finished(ok: bool)

	var _out: String = ""
	var _rows: PackedStringArray = PackedStringArray()
	var _stamps: Array[int] = []          # usec at every process frame

	func _init(out: String) -> void:
		_out = out

	func _ready() -> void:
		var floor_rect: ColorRect = ColorRect.new()
		floor_rect.color = BACKDROP
		floor_rect.size = get_viewport_rect().size
		add_child(floor_rect)
		_row("RUN %s oversample=%.1f display=%s"
			% [Engine.get_version_info()["string"], CardView.oversample,
				DisplayServer.get_name()])
		_run.call_deferred()

	func _process(_delta: float) -> void:
		_stamps.append(Time.get_ticks_usec())

	func _row(text: String) -> void:
		print(text)
		_rows.append(text)

	func _frames(n: int) -> void:
		for _i: int in range(n):
			await get_tree().process_frame

	func _run() -> void:
		await _frames(30)
		var ok: bool = true
		var ids: Array[String] = CardBacks.catalogue().ids()
		var bakes: Dictionary = {}
		# Every bake first, each from a quiet frame, so no analysis below and
		# no freed card lands in a bake's frames or its memory reading.
		for id: String in ids:
			await _frames(5)
			var baked: CardBacks.Baked = await _timed_bake(id)
			if baked == null:
				_row("FAIL %s did not bake" % id)
				ok = false
				continue
			bakes[id] = baked
		for id: String in bakes:
			var baked: CardBacks.Baked = bakes[id]
			var same: bool = await _same_as_live(id, baked)
			ok = ok and same
			_edge(id, baked)
		var shared: bool = await _shared()
		ok = ok and shared
		await _still(ids, bakes)
		_row("RESULT %s" % ("PASS" if ok else "FAIL"))
		_write()
		finished.emit(ok)

	func _timed_bake(id: String) -> CardBacks.Baked:
		var vram_before: float = _vram_mib()
		# A host of its own, so the bake's card leaves before the reading.
		var host: Control = Control.new()
		add_child(host)
		var drawn: int = Engine.get_frames_drawn()
		var from: int = _stamps.size()
		var t0: int = Time.get_ticks_usec()
		var baked: CardBacks.Baked = await CardBacks.bake(host, id)
		var t1: int = Time.get_ticks_usec()
		var spanned: int = Engine.get_frames_drawn() - drawn
		await _frames(2)
		# Frame gaps that start after the bake was asked for: the frame it was
		# asked in began before it and is not its cost.
		var longest: float = 0.0
		for i: int in range(from + 1, _stamps.size()):
			longest = maxf(longest, (_stamps[i] - _stamps[i - 1]) / 1000.0)
		var t2: int = Time.get_ticks_usec()
		var again: CardBacks.Baked = await CardBacks.bake(host, id)
		var t3: int = Time.get_ticks_usec()
		var kept: bool = _kept(id, host)
		# What the bake holds, once its host has taken the hidden card away.
		host.queue_free()
		await _frames(SETTLE_FRAMES)
		var vram_after: float = _vram_mib()
		if baked != null:
			_row("BAKE %s wall_ms=%.1f longest_frame_ms=%.1f frames=%d cached_ms=%.3f same=%s stage=%dx%d inner=%dx%d vram_mib=+%.1f"
				% [id, (t1 - t0) / 1000.0, longest, spanned,
					(t3 - t2) / 1000.0, str(again == baked),
					baked.stage.get_width(), baked.stage.get_height(),
					baked.inner.get_width(), baked.inner.get_height(),
					vram_after - vram_before])
		return baked if kept else null

	## The bake's card under its host: one, hidden, both passes frozen.
	func _kept(id: String, host: Control) -> bool:
		var cards: Array[Node] = host.find_children("*", "CardView", false, false)
		var card: CardView = cards[0] as CardView if cards.size() == 1 else null
		var ok: bool = card != null and not card.visible \
			and card._inner.render_target_update_mode == SubViewport.UPDATE_DISABLED \
			and card._stage.render_target_update_mode == SubViewport.UPDATE_DISABLED
		_row("KEPT %s cards_under_host=%d hidden=%s passes_frozen=%s %s" % [id, cards.size(),
			str(card != null and not card.visible), str(ok), "ok" if ok else "FAIL"])
		return ok

	## A live card of the same back, settled, read back the same way.
	func _same_as_live(id: String, baked: CardBacks.Baked) -> bool:
		var live: CardView = CardBacks.build(id)
		live.position = Vector2(-4000.0, -4000.0)
		add_child(live)
		await _frames(SETTLE_FRAMES)
		var want: Image = live.stage_image()
		live.queue_free()
		var got: Image = baked.stage.get_image()
		got.clear_mipmaps()
		if want.get_size() != got.get_size():
			_row("FAIL %s stage is %s, the live card's %s" % [id, got.get_size(), want.get_size()])
			return false
		var worst: int = 0
		var over: int = 0
		for y: int in range(want.get_height()):
			for x: int in range(want.get_width()):
				var a: Color = want.get_pixel(x, y)
				var b: Color = got.get_pixel(x, y)
				var d: int = roundi(255.0 * maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)),
					maxf(absf(a.b - b.b), absf(a.a - b.a))))
				worst = maxi(worst, d)
				over += 1 if d > MAX_DELTA else 0
		_row("SAME %s max_delta=%d texels_over=%d of %d (rgba, whole stage)"
			% [id, worst, over, want.get_width() * want.get_height()])
		return worst <= MAX_DELTA

	## Is the edge premultiplied, and what does a small straight-alpha draw
	## cost the rim against a premultiplied one?
	func _edge(id: String, baked: CardBacks.Baked) -> void:
		var full: Image = _mip(baked.stage.get_image(), 0)
		var partial: int = 0
		var brighter: int = 0
		for y: int in range(full.get_height()):
			for x: int in range(full.get_width()):
				var c: Color = full.get_pixel(x, y)
				if c.a > 0.02 and c.a < 0.98:
					partial += 1
					if maxf(c.r, maxf(c.g, c.b)) > c.a + 2.0 / 255.0:
						brighter += 1
		var parts: PackedStringArray = PackedStringArray()
		for level: int in [2, 3]:
			var small: Image = _mip(baked.stage.get_image(), level)
			var rim: int = 0
			var sum: float = 0.0
			var worst: float = 0.0
			for y: int in range(small.get_height()):
				for x: int in range(small.get_width()):
					var c: Color = small.get_pixel(x, y)
					if c.a <= 0.02 or c.a >= 0.98:
						continue
					var straight: Color = c * c.a + BACKDROP * (1.0 - c.a)
					var premult: Color = c + BACKDROP * (1.0 - c.a)
					var d: float = 255.0 * (premult.get_luminance() - straight.get_luminance())
					rim += 1
					sum += d
					worst = maxf(worst, d)
			parts.append("1/%d rim_texels=%d darker_mean=%.1f darker_max=%.1f"
				% [1 << level, rim, sum / maxf(1.0, float(rim)), worst])
		_row("EDGE %s partial=%d colour_over_coverage=%d %s"
			% [id, partial, brighter, " ".join(parts)])

	## Two bakes of one back asked for at once build one card.
	func _shared() -> bool:
		CardBacks.use_catalogue(null)
		var id: String = CardBacks.catalogue().default_id
		var built: Array[int] = [0]
		var count: Callable = func(node: Node) -> void:
			if node is CardView:
				built[0] += 1
		child_entered_tree.connect(count)
		var got: Array = [null, null]
		var ask: Callable = func(slot: int) -> void:
			got[slot] = await CardBacks.bake(self, id)
		ask.call(0)
		ask.call(1)
		await _frames(CardBacks.BAKE_FRAMES + 4)
		child_entered_tree.disconnect(count)
		var ok: bool = built[0] == 1 and got[0] != null and got[0] == got[1]
		_row("SHARED %s cards_built=%d same=%s" % [id, built[0], str(got[0] != null and got[0] == got[1])])
		return ok

	func _still(ids: Array[String], bakes: Dictionary) -> void:
		var x: float = 40.0
		var blend: CanvasItemMaterial = CanvasItemMaterial.new()
		blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		var span: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H) \
			+ Vector2.ONE * 2.0 * CardView.PAD_3D
		for id: String in ids:
			if not bakes.has(id):
				continue
			var baked: CardBacks.Baked = bakes[id]
			var live: CardView = CardBacks.build(id)
			live.position = Vector2(x + CardView.PAD_3D, 40.0)
			add_child(live)
			_place(baked.stage, Vector2(x, 290.0), span, null)
			var small_x: float = x
			for level: int in [2, 3]:
				var size: Vector2 = span / float(1 << level)
				_place(baked.stage, Vector2(small_x, 560.0), size, null)
				_place(baked.stage, Vector2(small_x + size.x + 4.0, 560.0), size, blend)
				small_x += 2.0 * size.x + 16.0
			x += span.x + 30.0
		await _frames(SETTLE_FRAMES)
		if _out != "":
			get_viewport().get_texture().get_image().save_png(_out.path_join("card-back-bake.png"))

	func _place(texture: Texture2D, at: Vector2, size: Vector2,
			material_override: Material) -> void:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rect.material = material_override
		rect.position = at
		rect.size = size
		add_child(rect)

	func _write() -> void:
		if _out == "":
			return
		var file: FileAccess = FileAccess.open(_out.path_join("card-back-bake.txt"), FileAccess.WRITE)
		if file == null:
			printerr("check_card_back_bake: cannot write to %s" % _out)
			return
		for text: String in _rows:
			file.store_line(text)
		file.close()

	## One mip level of `image`, exactly the texels a mipmapped draw samples.
	static func _mip(image: Image, level: int) -> Image:
		var start: int = image.get_mipmap_offset(level)
		var end: int = image.get_data_size()
		if level < image.get_mipmap_count():
			end = image.get_mipmap_offset(level + 1)
		return Image.create_from_data(maxi(1, image.get_width() >> level),
			maxi(1, image.get_height() >> level), false, image.get_format(),
			image.get_data().slice(start, end))

	static func _vram_mib() -> float:
		return float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0
