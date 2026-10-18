extends RefCounted
## #544 A4 review repair: a pile snapshot must follow the resolved definition
## even when playing the Unbroken power leaves the top discard UID unchanged.

class _Renderer:
	extends RefCounted
	signal released
	var hold: bool = false
	var waiting: bool = false
	var texts: Array[String] = []
	var words: Dictionary = {}

	func render(jobs: Array) -> Array:
		if hold:
			waiting = true
			await released
			waiting = false
		var out: Array = []
		for job: CardFaces._Job in jobs:
			var text: String = str(job.definition["text"])
			texts.append(text)
			out.append(snapshot(text))
		return out

	func snapshot(text: String) -> CardFaces.Face:
		var face: CardFaces.Face = CardFaces.Face.new()
		face.picture = ImageTexture.create_from_image(
			Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
		words[face.picture.get_instance_id()] = text
		return face

	func shown(hud: HudBar) -> String:
		var picture: Texture2D = hud._discard_pile.stack.face_texture()
		return str(words.get(picture.get_instance_id(), "")) if picture != null else ""


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	for language: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(language)
		var content: ContentDB = ContentDB.load_full(false)
		Locale.active.hydrate_content(content)
		for aspect: int in [1, 0]:
			for id: String in ["warCry", "tithe"]:
				_live_top(content, aspect, id, fails)
		_stale_bake(content, fails)
		_seen_snapshot(content, fails)
		Locale.active.restore_content()
	CardFaces.use_renderer(Callable())
	CardFaces.forget()
	Locale.active = previous


static func _check(fails: Array[String], condition: bool, what: String) -> void:
	if not condition:
		fails.append("class rider discard top: " + what)


static func _game(content: ContentDB, aspect: int) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 54404, "rider-discard-top", {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	game.cb.hand.clear()
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.player.energy = 20
	return game


static func _play_unbroken(game: GlassvowGame) -> CardInst:
	var mythic: CardInst = CardInst.new(game.run.next_uid(), &"unbrokenFlame")
	game.cb.hand.append(mythic)
	return mythic


## Actual CombatScreen drain: POWER_CONSUMED leaves the same shared card on
## top. The plain face is a real handoff snapshot seam, not an empty cache.
static func _live_top(content: ContentDB, aspect: int, id: String, fails: Array[String]) -> void:
	CardFaces.forget()
	var render: _Renderer = _Renderer.new()
	CardFaces.use_renderer(render.render)
	var game: GlassvowGame = _game(content, aspect)
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), id == "tithe")
	game.cb.discard.append(card)
	var plain: String = str(game.rules.card_data(card, game.run, game.cb)["text"])
	var full: String = str(game.rules.card_data(card)["text"])
	screen._top.face_ready(card.uid, render.snapshot(plain))
	screen._top.arrive(card.uid)
	_check(fails, render.shown(screen._hud) == plain, "opening snapshot missed the ordinary class text")
	var mythic: CardInst = _play_unbroken(game)
	screen._sync_all()
	_check(fails, screen.request_play(mythic.uid, null) and game.cb.unbroken,
		"actual Unbroken power did not play")
	_check(fails, game.cb.discard[-1].uid == card.uid and screen._hud.discard_top_uid() == card.uid,
		"Unbroken power changed the top discard UID")
	_check(fails, render.shown(screen._hud) == full,
		"same-UID discard snapshot hid the live Unbroken rider on " + id)
	var baked: int = render.texts.size()
	for _repeat: int in range(8):
		screen._top.settle(card.uid)
	_check(fails, render.texts.size() == baked, "an unchanged live definition rebaked on steady settles")
	# The original locked suite proves the real new-combat lifetime. Here the
	# same-UID seam is held fixed to discriminate the reverse projection too.
	game.cb.unbroken = false
	screen._on_busy_changed(false)
	_check(fails, render.shown(screen._hud) == plain,
		"same-UID discard snapshot kept the rider after the bypass cleared")
	for _repeat: int in range(8):
		screen._top.settle(card.uid)
	_check(fails, render.texts.size() == (2 if aspect == 1 else 0),
		"class projection did not bake only its two changed definitions")
	tree.root.remove_child(screen)
	screen.free()
	CardFaces.forget()


## A requested full face may land after its context has already returned to
## plain. It must not overwrite the cached current face on the same UID.
static func _stale_bake(content: ContentDB, fails: Array[String]) -> void:
	CardFaces.forget()
	var render: _Renderer = _Renderer.new()
	CardFaces.use_renderer(render.render)
	var game: GlassvowGame = _game(content, 1)
	var card: CardInst = CardInst.new(game.run.next_uid(), &"warCry")
	game.cb.discard.append(card)
	var top: DiscardTop = DiscardTop.new(func(_uid: int) -> CardInst: return card,
		func(inst: CardInst) -> Dictionary: return game.rules.card_data(inst, game.run, game.cb))
	var hud: HudBar = HudBar.new(true, true, false)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(hud)
	top.show_on(hud, null)
	top.arrive(card.uid)
	var plain: String = str(game.rules.card_data(card, game.run, game.cb)["text"])
	_check(fails, render.shown(hud) == plain, "plain cache did not land before the delayed transition")
	render.hold = true
	var mythic: CardInst = _play_unbroken(game)
	game.apply({"t": "playCard", "uid": mythic.uid, "target": null})
	top.settle(card.uid)
	_check(fails, render.waiting, "changed same-UID definition never requested its new face")
	game.cb.unbroken = false
	top.settle(card.uid)
	_check(fails, render.shown(hud) == plain, "clearing the bypass failed to reuse the current plain cache")
	if render.waiting:
		render.released.emit()
	_check(fails, render.shown(hud) == plain, "a stale in-flight Unbroken face overwrote the cleared projection")
	for _repeat: int in range(8):
		top.settle(card.uid)
	_check(fails, render.texts.size() == 2, "steady settles rendered beyond the two distinct definitions")
	tree.root.remove_child(hud)
	hud.free()
	CardFaces.forget()


## A handoff waiting in _seen belongs to the definition it was taken from.
## Arrival after a projection change must not wear that obsolete snapshot.
static func _seen_snapshot(content: ContentDB, fails: Array[String]) -> void:
	CardFaces.forget()
	var render: _Renderer = _Renderer.new()
	CardFaces.use_renderer(render.render)
	var game: GlassvowGame = _game(content, 1)
	var card: CardInst = CardInst.new(game.run.next_uid(), &"tithe")
	game.cb.discard.append(card)
	var top: DiscardTop = DiscardTop.new(func(_uid: int) -> CardInst: return card,
		func(inst: CardInst) -> Dictionary: return game.rules.card_data(inst, game.run, game.cb))
	var hud: HudBar = HudBar.new(true, true, false)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(hud)
	top.show_on(hud, null)
	var plain: String = str(game.rules.card_data(card, game.run, game.cb)["text"])
	top.face_ready(card.uid, render.snapshot(plain))
	var mythic: CardInst = _play_unbroken(game)
	game.apply({"t": "playCard", "uid": mythic.uid, "target": null})
	top.arrive(card.uid)
	_check(fails, render.shown(hud) == str(game.rules.card_data(card)["text"]),
		"arrival reused a seen snapshot from the obsolete class projection")
	tree.root.remove_child(hud)
	hud.free()
	CardFaces.forget()
