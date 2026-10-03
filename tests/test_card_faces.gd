extends RefCounted
## Baked card faces (issue #657, PR 2): the deck overlay and every deck picker
## draw one baked face per distinct card and stand at most one live card in,
## under the pointer. The suite proves the bake's job rules (one bake per
## distinct card, at most PER_FRAME a frame, in the order asked; a cache hit
## at once; a locale, oversample or `forget` dropping the cache and any bake
## in flight; an asker that leaves), that a baked card wears what the live card
## draws at rest, the grid's one-live rule and its picks over touch and mouse,
## and that a 30-card ChoiceScreen builds no live card at all.
##
## The bakes run on a fake render step (CardFaces.use_renderer): the suite is
## headless, where no frame is ever drawn. What the live step renders, and that
## it is the live card's pixels, is proved windowed by
## tools/check_card_faces.gd.

const DECK_ROWS: int = 30


static func run(fails: Array[String]) -> void:
	CardFaces.use_renderer(Callable())
	CardFaces.forget()
	var content: ContentDB = ContentDB.load_full()
	_keys(fails, content)
	_one_bake_per_distinct_card(fails, content)
	_forgetting(fails, content)
	_askers_that_leave(fails, content)
	_live_render_headless(fails, content)
	_baked_card_wears_the_rest_look(fails, content)
	_grid_keeps_one_live_card(fails, content)
	_choice_screen_builds_no_live_card(fails, content)
	CardFaces.use_renderer(Callable())
	CardFaces.forget()


static func _keys(fails: Array[String], content: ContentDB) -> void:
	var strike: Dictionary = content.card(&"strike")
	var a: String = CardFaces.key_of(CardInst.new(1, &"strike"), strike, 1)
	var b: String = CardFaces.key_of(CardInst.new(2, &"strike"), strike, 1)
	var up: String = CardFaces.key_of(CardInst.new(3, &"strike", true), strike, 1)
	var dear: String = CardFaces.key_of(CardInst.new(4, &"strike"), strike, 2)
	var renamed_row: Dictionary = strike.duplicate(true)
	renamed_row["name"] = "Other"
	var renamed: String = CardFaces.key_of(CardInst.new(5, &"strike"), renamed_row, 1)
	if a != b:
		fails.append("card faces: two copies of one card have different faces")
	if a == up or a == dear or a == renamed:
		fails.append("card faces: an upgrade, a cost or a name change shares a face")


static func _one_bake_per_distinct_card(fails: Array[String], content: ContentDB) -> void:
	CardFaces.forget()
	var render: _FakeRender = _FakeRender.new()
	CardFaces.use_renderer(render.render)
	var host: Control = _host()
	var cards: Array[BakedCard] = [
		_card(content, &"strike"), _card(content, &"strike"),
		_card(content, &"defend"), _card(content, &"strike", true)]
	for card: BakedCard in cards:
		_add(host, card)
	render.drain()
	var want: Array[String] = [
		_key(content, &"strike"), _key(content, &"defend"), _key(content, &"strike", true)]
	if render.keys != want:
		fails.append("card faces: baked %s, want one bake per distinct card in order %s"
			% [str(render.keys), str(want)])
	if render.batches.any(func(n: int) -> bool: return n > CardFaces.PER_FRAME):
		fails.append("card faces: a frame baked %s cards, more than PER_FRAME"
			% str(render.batches))
	if cards.any(func(c: BakedCard) -> bool: return c.face() == null or c.modulate.a != 0.0):
		fails.append("card faces: a card did not wear its landed face, or skipped its fade-in")
	if cards[0].face() != cards[1].face() or cards[0].face() == cards[2].face():
		fails.append("card faces: two copies of a card do not share their face")
	if CardFaces.count() != 3 or _live_cards(host) != 0:
		fails.append("card faces: %d faces cached and %d live cards, want 3 and 0"
			% [CardFaces.count(), _live_cards(host)])
	# A card already baked is worn at once, with no fade and no bake.
	var again: BakedCard = _card(content, &"defend")
	_add(host, again)
	if again.face() != cards[2].face() or again.modulate.a != 1.0 or render.keys.size() != 3:
		fails.append("card faces: a cached face was baked again or faded in")
	host.free()


static func _forgetting(fails: Array[String], content: ContentDB) -> void:
	CardFaces.forget()
	var render: _FakeRender = _FakeRender.new()
	CardFaces.use_renderer(render.render)
	var host: Control = _host()
	# A bake in flight when the cache is forgotten goes to nobody.
	var card: BakedCard = _card(content, &"strike")
	_add(host, card)
	CardFaces.forget()
	render.drain()
	if card.face() != null or CardFaces.count() != 0:
		fails.append("card faces: a bake asked for before forget() was handed out or kept")
	# A cached face is dropped by forget(), a locale change and an oversample change.
	var inst: CardInst = CardInst.new(1, &"strike")
	var row: Dictionary = content.card(&"strike")
	var before: Locale = Locale.active
	var scale: float = CardView.oversample
	var dropped: PackedStringArray = PackedStringArray()
	for change: String in ["forget", "locale", "oversample"]:
		_add(host, _card(content, &"strike"))
		render.drain()
		if CardFaces.cached(inst, row, 1) == null:
			fails.append("card faces: nothing was cached before the %s check" % change)
			continue
		match change:
			"forget": CardFaces.forget()
			"locale": Locale.active = Locale.new(Locale.CODE_ZH_HANT)
			"oversample": CardView.oversample = scale + 1.0
		if CardFaces.cached(inst, row, 1) == null and CardFaces.count() == 0:
			dropped.append(change)
		Locale.active = before
		CardView.oversample = scale
		CardFaces.forget()
	if dropped.size() != 3:
		fails.append("card faces: only %s dropped the cache, want forget, locale, oversample"
			% ", ".join(dropped))
	host.free()


static func _askers_that_leave(fails: Array[String], content: ContentDB) -> void:
	CardFaces.forget()
	var render: _FakeRender = _FakeRender.new()
	CardFaces.use_renderer(render.render)
	var errors: _ScriptErrors = _ScriptErrors.new()
	OS.add_logger(errors)
	var host: Control = _host()
	# A queued card whose only asker left is never baked.
	_add(host, _card(content, &"strike"))
	var gone: BakedCard = _card(content, &"defend")
	_add(host, gone)
	gone.free()
	render.drain()
	if render.keys != [_key(content, &"strike")]:
		fails.append("card faces: a card nobody waits for any more was baked (%s)"
			% str(render.keys))
	# The asker hosting a bake leaves mid-bake (the render gives nothing): the
	# other asker of that card gets a second try, and the face.
	CardFaces.forget()
	render.keys.clear()
	var owner: BakedCard = _card(content, &"eclipseSlash")
	var waiter: BakedCard = _card(content, &"eclipseSlash")
	_add(host, owner)
	_add(host, waiter)
	owner.free()
	render.fail = true
	render.open.emit()
	render.fail = false
	render.drain()
	if waiter.face() == null or render.keys.size() != 2:
		fails.append("card faces: after its host left, the waiter got %s after %d bakes"
			% [str(waiter.face()), render.keys.size()])
	OS.remove_logger(errors)
	if not errors.seen.is_empty():
		fails.append("card faces: askers leaving raised script errors: %s"
			% "; ".join(errors.seen))
	host.free()


## The live render step in a headless run can never be drawn: it gives nothing
## at once instead of waiting, builds no card, and leaves no job behind.
static func _live_render_headless(fails: Array[String], content: ContentDB) -> void:
	if DisplayServer.get_name() != "headless":
		return
	CardFaces.forget()
	CardFaces.use_renderer(Callable())
	var host: Control = _host()
	var card: BakedCard = _card(content, &"strike")
	_add(host, card)
	if card.face() != null or _live_cards(host) != 0 or not CardFaces._jobs.is_empty() \
			or CardFaces._pumping:
		fails.append("card faces: a headless bake waited, built a card or left a job behind")
	host.free()


## What a baked card lays at rest is what the live card draws: its stock's own
## shadow, the picture at the stage's rect, and the gilt shine on a rare only.
static func _baked_card_wears_the_rest_look(fails: Array[String], content: ContentDB) -> void:
	CardFaces.forget()
	var host: Control = _host()
	for id: StringName in [&"oblivionStrike", &"strike"]:
		var row: Dictionary = content.card(id)
		var live: CardView = CardView.new(CardInst.new(1, id), row, _cost(row))
		host.add_child(live)
		var face: CardFaces.Face = CardFaces.Face.new()
		face.picture = _texture()
		face.shadow = live.rest_shadow()
		face.shine = live.has_shine()
		var baked: BakedCard = BakedCard.new(CardInst.new(2, id), row, _cost(row))
		baked._wear(face)
		var live_sb: StyleBoxFlat = live._shadow_sb
		var shadow: Panel = baked.get_child(0) as Panel
		var sb: StyleBoxFlat = shadow.get_theme_stylebox("panel") as StyleBoxFlat
		if sb.shadow_size != live_sb.shadow_size or sb.shadow_color != live_sb.shadow_color \
				or sb.shadow_offset != live_sb.shadow_offset \
				or sb.corner_radius_top_left != live_sb.corner_radius_top_left:
			fails.append("card faces: %s's baked shadow is not its live shadow at rest" % id)
		var shown: TextureRect = baked.get_child(1) as TextureRect
		var live_display: TextureRect = null
		for child: Node in live.get_children():
			if child is TextureRect:
				live_display = child
		if shown == null or live_display == null or shown.position != live_display.position \
				or shown.size != live_display.size or shown.stretch_mode != live_display.stretch_mode:
			fails.append("card faces: %s's baked picture is not laid where the live stage is" % id)
		var shines: int = baked.find_children("", "ColorRect", false, false).size()
		if shines != (1 if id == &"oblivionStrike" else 0) or face.shine != (shines == 1):
			fails.append("card faces: %s wears %d shines, want one on a rare only" % [id, shines])
		baked.free()
		_free_card(live)
	host.free()


static func _grid_keeps_one_live_card(fails: Array[String], content: ContentDB) -> void:
	CardFaces.forget()
	var render: _FakeRender = _FakeRender.new()
	CardFaces.use_renderer(render.render)
	var host: Control = _host()
	var rows: Array[Dictionary] = [
		_row(content, &"strike", "a"), _row(content, &"defend", "b"),
		_row(content, &"eclipseSlash", "c", true)]
	var grid: CardGrid = CardGrid.new(rows, 16.0)
	host.add_child(grid)
	_ready_all(grid)
	render.drain()
	var picks: Array[String] = []
	grid.picked.connect(func(id: String) -> void: picks.append(id))
	var cards: Array[BakedCard] = grid.cards()
	var at: Vector2 = Vector2(40.0, 60.0)
	# A finger on the first card stands it in live; the touch screen's emulated
	# mouse for the same contact changes nothing.
	_touch(cards[0], true, at)
	_mouse_button(cards[0], true, InputEvent.DEVICE_ID_EMULATION)
	if cards[0].live() == null or _live_cards(grid) != 1:
		fails.append("card faces: a finger on a card did not stand exactly one live card in")
	_mouse_button(cards[0], false, InputEvent.DEVICE_ID_EMULATION)
	_touch(cards[0], false, at)
	if picks != ["a"]:
		fails.append("card faces: one tap picked %s, want [a]" % str(picks))
	# A mouse reaching the second card drops the first at once.
	_mouse_motion(cards[1], at)
	if cards[0].live() != null or cards[1].live() == null or _live_cards(grid) != 1:
		fails.append("card faces: two cards stood live at once, or the new one did not")
	# Leaving: the live card springs back to rest, then the face returns.
	cards[1].notification(Control.NOTIFICATION_MOUSE_EXIT)
	var live: CardView = cards[1].live()
	if live == null:
		fails.append("card faces: the live card was dropped before it came to rest")
	else:
		# No frame runs in the suite: step the spring by hand, and end the edge
		# glint's quarter-second fade, a tween that only steps in a running tree.
		for _i: int in range(600):
			if not live.is_processing():
				break
			live._process(1.0 / 30.0)
		cards[1]._process(1.0 / 30.0)
		if cards[1].live() == null:
			fails.append("card faces: the live card gave way before its glint had faded")
		if live._light_tw != null:
			live._light_tw.kill()
		cards[1]._process(1.0 / 30.0)
		if cards[1].live() != null or not cards[1].get_child(1).visible:
			fails.append("card faces: a settled live card did not give way to its face")
	# A shown-only card takes the pointer but is never picked.
	_mouse_button(cards[2], true, 0)
	_mouse_button(cards[2], false, 0)
	if picks != ["a"]:
		fails.append("card faces: a disabled card was picked (%s)" % str(picks))
	host.free()


## The deck overlay at 30 cards: a grid of baked faces, and not one live card
## until a pointer asks for one.
static func _choice_screen_builds_no_live_card(fails: Array[String],
		content: ContentDB) -> void:
	CardFaces.forget()
	var render: _FakeRender = _FakeRender.new()
	CardFaces.use_renderer(render.render)
	var ids: Array = content.cards.keys()
	ids.sort()
	var choices: Array[Dictionary] = []
	for i: int in range(DECK_ROWS):
		var row: Dictionary = _row(content, StringName(str(ids[i % ids.size()])),
			"card:%d" % i, true)
		choices.append(row)
	choices.append({"id": "close", "label": "Close", "quiet": true})
	var screen: ChoiceScreen = ChoiceScreen.new("Deck", "30", choices,
		{"overlay": true, "cancel": "close"})
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_ready_all(screen)
	render.drain()
	var grid: CardGrid = screen._grid
	if grid == null or grid.cards().size() != DECK_ROWS:
		fails.append("card faces: the 30-card overlay has no grid of 30 cards")
	elif _live_cards(screen) != 0:
		fails.append("card faces: the 30-card overlay built %d live cards, want 0"
			% _live_cards(screen))
	elif grid.cards().any(func(c: BakedCard) -> bool: return c.face() == null):
		fails.append("card faces: a card in the overlay never wore its face")
	screen.free()


## The runner calls the suite before the tree starts, so nothing added to it
## is readied: a card asks for its face when this stands in for that.
static func _add(parent: Node, card: BakedCard) -> void:
	parent.add_child(card)
	card._ready()


static func _ready_all(root: Node) -> void:
	for node: Node in root.find_children("", "BakedCard", true, false):
		var card: BakedCard = node
		card._ready()


static func _host() -> Control:
	var host: Control = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


static func _card(content: ContentDB, id: StringName, up: bool = false) -> BakedCard:
	var row: Dictionary = content.card(id)
	return BakedCard.new(CardInst.new(1, id, up), row, _cost(row))


static func _key(content: ContentDB, id: StringName, up: bool = false) -> String:
	var row: Dictionary = content.card(id)
	return CardFaces.key_of(CardInst.new(1, id, up), row, _cost(row))


static func _row(content: ContentDB, id: StringName, choice: String,
		disabled: bool = false) -> Dictionary:
	return {"id": choice, "card": CardInst.new(1, id), "definition": content.card(id),
		"disabled": disabled}


static func _cost(row: Dictionary) -> int:
	var cost_v: Variant = row.get("cost")
	return 0 if cost_v == null else int(float(str(cost_v)))


static func _live_cards(root: Node) -> int:
	return root.find_children("", "CardView", true, false).size()


static func _texture() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))


static func _touch(card: BakedCard, pressed: bool, local: Vector2) -> void:
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.pressed = pressed
	ev.position = local
	card._gui_input(ev)


static func _mouse_button(card: BakedCard, pressed: bool, device: int) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.device = device
	card._gui_input(ev)


static func _mouse_motion(card: BakedCard, local: Vector2) -> void:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.position = local
	card._gui_input(ev)


static func _free_card(card: CardView) -> void:
	for surface: int in 3:
		card._slab.set_surface_override_material(surface, null)
	card.free()


## A render step the test opens by hand: each call records its cards, waits
## for `open`, then gives a face per card, or nothing while `fail` is set (the
## card's host left mid-bake).
class _FakeRender:
	extends RefCounted
	signal open
	var keys: Array[String] = []
	var batches: Array[int] = []
	var fail: bool = false
	var _waiting: int = 0

	func render(batch: Array) -> Array:
		batches.append(batch.size())
		for job: Variant in batch:
			keys.append(str(job.get("key")))
		_waiting += 1
		await open
		_waiting -= 1
		var out: Array = []
		for _job: Variant in batch:
			if fail:
				out.append(null)
				continue
			var face: CardFaces.Face = CardFaces.Face.new()
			face.picture = ImageTexture.create_from_image(
				Image.create(4, 4, false, Image.FORMAT_RGBA8))
			face.shadow = StyleBoxFlat.new()
			out.append(face)
		return out

	## Open every bake, including the ones each opening queues up.
	func drain() -> void:
		for _i: int in range(64):
			if _waiting == 0:
				return
			open.emit()


## The script errors the engine reports while this is registered.
class _ScriptErrors:
	extends Logger
	var seen: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			seen.append(code if rationale.is_empty() else rationale)

	func _log_message(_message: String, _error: bool) -> void:
		pass
