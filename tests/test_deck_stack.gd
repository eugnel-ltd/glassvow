extends RefCounted
## The top-menu deck as a stack (issue #657, PR 5b; §4's "Top-menu deck" in
## docs/design/2026-10-03-cards-real-objects/README.md): its card and the
## thickness law scaled to it, its top card held as the deck deepens, the
## painting until a back is baked and the back it follows after, its glint
## half a cycle from the draw pile's and stilled by Reduce Motion, and the two
## buttons that wear it, counting and opening what they did. Main's bake of
## the back outside a fight is tests/test_card_turn.gd's; how it looks is
## checked in stills.

const SIDES: Array[float] = [56.0, 42.0]


static func run(fails: Array[String]) -> void:
	var was_still: bool = Preferences.active.reduce_motion
	var was_wearing: String = CardTurn.wearing()
	Preferences.active.reduce_motion = false
	CardBacks.use_catalogue(null)
	var render: _FakeRender = _FakeRender.new()
	CardBacks.use_renderer(render.render)
	_size_and_law(fails)
	await _follows_the_back(fails)
	await _glints_apart(fails)
	await _run_hud_deck(fails)
	await _combat_seal(fails)
	CardBacks.use_renderer(Callable())
	CardBacks.use_catalogue(null)
	CardTurn._wearing = was_wearing
	Preferences.active.reduce_motion = was_still


## A 36 x 51 card on the pad's 56 px square, scaled with the square; the
## thickness is the law's, scaled by the same factor; the top card stays
## TOP_PX under the square's top whatever the count, and the deck deepens
## under it.
static func _size_and_law(fails: Array[String]) -> void:
	for side: float in SIDES:
		var deck: DeckStack = DeckStack.new(side, null)
		# The button under it takes the tap: nothing in the stack may.
		for node: Control in [deck, deck.painting, deck.stack, deck.stack._glow]:
			if node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				fails.append("deck stack: %s takes the pointer from the deck button" % node.get_class())
		var k: float = deck.stack.scale.x
		var card: Vector2 = deck.stack.card * k
		var want: Vector2 = Vector2(36.0, 51.0) * side / DeckStack.ICON_SIDE
		if absf(card.x - want.x) > 0.25 or absf(card.y - want.y) > 0.01:
			fails.append("deck stack: a %d px square stands a %s card, want %s" % [
				side, str(card), str(want)])
		var law: float = want.y / (HudBar.PILE_BOX.x * HudBar.PILE_CARD_H)
		for n: int in [1, 10, 20, 30, 40, 99]:
			deck.set_count(n)
			var top: Rect2 = deck.stack.top_rect()
			var top_y: float = top.position.y * k
			var depth: float = (deck.stack.base.y + deck.stack.card.y * 0.5) * k - top.end.y * k
			var held: float = DeckStack.TOP_PX * side / DeckStack.ICON_SIDE
			if absf(top_y - held) > 0.001 or absf(depth - PileStack.thickness(n) * law) > 0.001 \
					or deck.stack.count != n:
				fails.append("deck stack: %d cards on a %d px square: top at %.2f (want %.2f), %.2f deep (want %.2f)"
					% [n, side, top_y, held, depth, PileStack.thickness(n) * law])
		deck.free()


## The painting until the table's back is baked; then the back, followed
## through a change of back: the painting again while the new one waits for
## its bake, then the new one. Never a blank.
static func _follows_the_back(fails: Array[String]) -> void:
	var host: Control = _host()
	var prefs: Preferences = Preferences.new()
	var art: Texture2D = HudBar.icon("ui/deck")
	CardTurn._wearing = ""
	var deck: DeckStack = DeckStack.new(56.0, art)
	host.add_child(deck)
	if not deck.painting.visible or deck.stack.visible or deck.painting.texture != art \
			or deck.worn() != null:
		fails.append("deck stack: with no back baked it does not show the painting")
	await CardTurn.prewarm(host, "vault")
	deck._process(0.0)
	var vault: CardBacks.Baked = CardTurn.back()
	if vault == null or deck.worn() != vault or deck.stack.back_texture() != vault.stage \
			or not deck.stack.visible or deck.painting.visible:
		fails.append("deck stack: a baked back is not worn in place of the painting")
	# A change of back drops the old bake: the painting until the new one lands.
	CardBacks.choose(prefs, "rose")
	deck._process(0.0)
	if not deck.painting.visible or deck.stack.visible or deck.worn() != null:
		fails.append("deck stack: a change of back waiting for its bake shows a blank or the old back")
	await CardTurn.prewarm(host, "rose")
	deck._process(0.0)
	var rose: CardBacks.Baked = CardTurn.back()
	if rose == null or rose == vault or deck.worn() != rose \
			or deck.stack.back_texture() != rose.stage or deck.painting.visible:
		fails.append("deck stack: the stack does not follow the change of back")
	# A stack built after the bake wears it from its first frame.
	var late: DeckStack = DeckStack.new(42.0, art)
	if late.worn() != rose or late.painting.visible:
		fails.append("deck stack: a stack built after the bake starts on the painting")
	late.free()
	host.queue_free()
	await _frames(1)


## In a fight the seal's glint starts half a cycle after the draw pile's, so
## the two never cross together, and each still crosses once a cycle; Reduce
## Motion stills the seal's.
static func _glints_apart(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new(true, true, false)
	Engine.get_main_loop().root.add_child(hud)
	hud.set_values(72, 72, 0, 0, 3, 3, 20, 5, 0, 5)
	var draw: PileStack = hud._draw_pile.stack
	var seal: PileStack = hud._deck_stack.stack
	var draw_lit: bool = false
	var seal_lit: bool = false
	for i: int in range(int(PileStack.GLINT_CYCLE * 2.0 / 0.05)):
		draw._process(0.05)
		seal._process(0.05)
		var d: bool = not is_nan(draw._glow.band)
		var s: bool = not is_nan(seal._glow.band)
		draw_lit = draw_lit or d
		seal_lit = seal_lit or s
		if d and s:
			fails.append("deck stack: the seal and the draw pile glint together %.2f s in"
				% (float(i + 1) * 0.05))
			break
	if not draw_lit or not seal_lit:
		fails.append("deck stack: in 18 s the draw pile glinted %s and the seal %s"
			% [str(draw_lit), str(seal_lit)])
	Preferences.active.reduce_motion = true
	for i: int in range(int(PileStack.GLINT_CYCLE / 0.05)):
		seal._process(0.05)
		if not is_nan(seal._glow.band):
			fails.append("deck stack: under Reduce Motion the seal still glints")
			break
	Preferences.active.reduce_motion = false
	hud.queue_free()
	await _frames(1)


## The run HUD's deck: the stack counts the run's deck, at every refresh and
## every shape, stands where the painting stood at that shape's size, and a
## tap still asks for the deck view.
static func _run_hud_deck(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run: RunState = RunState.new()
	# Three empty phial seats, as a run starts with: the bar's right side is
	# built when its seats are known.
	run.player.potions.assign(["", "", ""])
	for i: int in range(12):
		run.player.deck.append(CardInst.new(900 + i, &"strike"))
	for shape: StringName in [&"pad-landscape", &"phone-landscape"]:
		var hud: RunHud = RunHud.new(run, content, shape)
		Engine.get_main_loop().root.add_child(hud)
		var side: float = 42.0 if shape == &"phone-landscape" else 56.0
		var deck: DeckStack = hud._deck_stack
		if deck == null or deck.size != Vector2(side, side) \
				or not is_equal_approx(deck.stack.scale.x, DeckStack.scale_for(side)):
			fails.append("run hud deck: %s does not stand a %d px stack where the painting stood"
				% [shape, side])
			hud.queue_free()
			continue
		for n: int in [12, 13, 30, 7]:
			run.player.deck.clear()
			while run.player.deck.size() < n:
				run.player.deck.append(CardInst.new(900 + run.player.deck.size(), &"defend"))
			hud.refresh(run)
			if hud._deck_stack.stack.count != n or hud._deck_count.text != str(n):
				fails.append("run hud deck: %s counts %d on the stack and '%s' over it, want %d"
					% [shape, hud._deck_stack.stack.count, hud._deck_count.text, n])
		var asked: Array[int] = [0]
		hud.deck_requested.connect(func() -> void: asked[0] += 1)
		var button: Button = hud._deck_stack.get_parent() as Button
		if button == null:
			fails.append("run hud deck: %s's stack is not on the deck button" % shape)
		else:
			button.pressed.emit()
			if asked[0] != 1:
				fails.append("run hud deck: %s's tap asked for the deck %d times" % [shape, asked[0]])
		hud.queue_free()
	await _frames(1)


## The combat seal: the stack counts the cards still in the fight, draw, hand
## and discard and never the ash, as its number does, and a tap still opens
## the deck.
static func _combat_seal(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new(true, true, false)
	Engine.get_main_loop().root.add_child(hud)
	# Draw, discard, ash, hand.
	var rows: Array[Vector4i] = [Vector4i(10, 0, 0, 0), Vector4i(3, 4, 2, 5),
		Vector4i(0, 0, 7, 0), Vector4i(12, 9, 6, 5)]
	for c: Vector4i in rows:
		hud.set_values(72, 72, 0, 0, 3, 3, c.x, c.y, c.z, c.w)
		var want: int = c.x + c.y + c.w
		if hud._deck_stack.stack.count != want or hud._deck_count.text != str(want):
			fails.append("combat seal: draw %d, discard %d, ash %d, hand %d stand %d with '%s' over them, want %d"
				% [c.x, c.y, c.z, c.w, hud._deck_stack.stack.count, hud._deck_count.text, want])
	# Its top card 2 px under the button's top at every shape: the phone's bar
	# seats the button at the screen's edge.
	for shape: StringName in [&"pad-landscape", &"phone-landscape"]:
		var shaped: HudBar = HudBar.new(true, true, false, shape)
		var deck: DeckStack = shaped._deck_stack
		var k: float = deck.size.x / DeckStack.ICON_SIDE
		var top: float = deck.position.y + deck.stack.top_rect().position.y * deck.stack.scale.y
		if absf(top - 2.0 * k) > 0.001:
			fails.append("combat seal: on %s its top card stands %.2f px under the button's top, want %.2f"
				% [shape, top, 2.0 * k])
		shaped.free()
	var asked: Array[int] = [0]
	hud.deck_pressed.connect(func() -> void: asked[0] += 1)
	var button: Button = hud._deck_stack.get_parent() as Button
	if button == null:
		fails.append("combat seal: the stack is not on the deck button")
	else:
		button.pressed.emit()
		if asked[0] != 1:
			fails.append("combat seal: a tap asked for the deck %d times" % asked[0])
	hud.queue_free()
	await _frames(1)


static func _host() -> Control:
	var host: Control = Control.new()
	host.size = Vector2(200.0, 200.0)
	Engine.get_main_loop().root.add_child(host)
	return host


static func _frames(n: int) -> void:
	for _i: int in range(n):
		await (Engine.get_main_loop() as SceneTree).process_frame


## A bake with no GPU: the suite is headless and never draws a frame.
class _FakeRender:
	extends RefCounted

	func render(_host: Node, _id: String, scale: float) -> CardBacks.Baked:
		await (Engine.get_main_loop() as SceneTree).process_frame
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.stage = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.inner = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.oversample = scale
		return out
