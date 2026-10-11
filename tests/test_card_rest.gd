extends RefCounted
## A resting card lets its stage go (issue #657 PR 6, CardView's LETTING THE
## STAGE GO): a resting hand holds each card's last frame and neither of its
## offscreen passes; a card that must draw — a pointer on it, a live turn —
## builds them again in that same call, and lets them go once it is back at
## rest; a card that does not release (a bake's) never does. A rebuild wears
## the materials the card was built with and makes none, and the fight holds
## every one of them that the engine would otherwise free with its last
## wearer (CardTurn.hold_for_fight). A card freed while released takes what
## its passes drew with it.
##
## The frame is kept by a fake keeper (CardView.use_keeper): the suite is
## headless, where no frame is ever drawn and no RenderingDevice copies. That
## the copy is the stage's frame texel for texel, that the swaps show nothing,
## and that nothing compiles, is measured windowed by tools/check_card_rest.gd.

const TurnTests: GDScript = preload("res://tests/test_card_turn.gd")
const HAND: Array[StringName] = [&"strike", &"defend", &"novaflare"]
## Process frames a card may take to settle back to rest after a pointer, at
## the headless runner's pace.
const SETTLE_LIMIT_MS: int = 5000


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var keeper: _Keeper = _Keeper.new()
	CardView.use_keeper(keeper.keep)
	await _hand_rests_without_stages(fails, content, keeper)
	await _touch_builds_the_stage(fails, content)
	await _back_at_rest_lets_go(fails, content, keeper)
	await _live_turn_builds_it(fails, content)
	await _woken_before_the_draw(fails, content)
	await _a_card_that_keeps_its_stage(fails, content, keeper)
	await _offering_rests_without_stages(fails, content)
	await _rebuild_wears_what_the_fight_holds(fails, content)
	await _freed_while_released(fails, content)
	CardView.use_keeper(Callable())


## Every card of a resting hand holds its kept frame and no pass: the picture
## wears the frame, and no SubViewport stands under the hand.
static func _hand_rests_without_stages(fails: Array[String], content: ContentDB,
		keeper: _Keeper) -> void:
	var hand: HandView = _hand()
	var cards: Array[CardView] = _deal(hand, content)
	await _frames(4)
	for card: CardView in cards:
		var kept: Texture2D = card.stage_texture()
		if card.has_stage() or not keeper.made.has(kept) or card._display.texture != kept:
			fails.append("card rest: a resting hand card %s holds its stage (kept frame worn: %s)"
				% [card.card_id, str(card._display.texture == kept and keeper.made.has(kept))])
	var passes: int = hand.find_children("*", "SubViewport", true, false).size()
	if passes != 0:
		fails.append("card rest: a resting hand holds %d SubViewports, want 0" % passes)
	hand.queue_free()
	await _frames(1)


## A pointer on a released card builds both passes in the call, around the
## face, slab and camera the card kept: the face pass before the stage that
## samples it, both before the picture, which wears the live stage, and the
## plates reading the new face pass. Held, it keeps them.
static func _touch_builds_the_stage(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand()
	var card: CardView = _deal(hand, content)[0]
	await _frames(4)
	card.point_at(Vector2(CardView.CARD_W * 0.75, CardView.CARD_H * 0.25))
	if not card.has_stage():
		fails.append("card rest: a touched card has no stage")
		hand.queue_free()
		await _frames(1)
		return
	if card._display.texture != card._stage.get_texture():
		fails.append("card rest: a touched card's picture does not wear its live stage")
	if card._inner.render_target_update_mode != SubViewport.UPDATE_ALWAYS \
			or card._stage.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		fails.append("card rest: a touched card's passes do not draw every frame")
	if not (card._inner.get_index() < card._stage.get_index()
			and card._stage.get_index() < card._display.get_index()):
		fails.append("card rest: a rebuilt card's passes are not face, stage, then picture (%d, %d, %d)"
			% [card._inner.get_index(), card._stage.get_index(), card._display.get_index()])
	if card._content.get_parent() != card._inner or card._slab.get_parent() != card._stage \
			or card._cam.get_parent() != card._stage:
		fails.append("card rest: a rebuilt card's passes do not hold its own face, slab and camera")
	for i: int in [1, 2]:
		var plate: ShaderMaterial = card._slab.get_surface_override_material(i) as ShaderMaterial
		if plate.get_shader_parameter("face_tex") != card._inner.get_texture():
			fails.append("card rest: a rebuilt card's plate %d does not read its new face pass" % i)
	await _frames(6)
	if not card.has_stage():
		fails.append("card rest: a card held under the pointer let its stage go")
	hand.queue_free()
	await _frames(1)


## The pointer leaves: the card springs back to rest and then lets its stage
## go, wearing a new kept frame.
static func _back_at_rest_lets_go(fails: Array[String], content: ContentDB,
		keeper: _Keeper) -> void:
	var hand: HandView = _hand()
	var card: CardView = _deal(hand, content)[0]
	await _frames(4)
	card.point_at(Vector2(CardView.CARD_W * 0.2, CardView.CARD_H * 0.8))
	await _frames(3)
	var made: int = keeper.made.size()
	card.point_away()
	var t0: int = Time.get_ticks_msec()
	while card.is_processing() and Time.get_ticks_msec() - t0 < SETTLE_LIMIT_MS:
		await _frames(1)
	await _frames(2)
	if card.is_processing() or card.has_stage() or keeper.made.size() != made + 1 \
			or card._display.texture != keeper.made[-1]:
		fails.append("card rest: a card back at rest kept its stage (settled: %s, frames kept: %d)"
			% [str(not card.is_processing()), keeper.made.size() - made])
	hand.queue_free()
	await _frames(1)


## A live turn builds the stage and keeps it while the card lies turned; the
## card turned back to rest lets it go. A picture turn needs no stage.
static func _live_turn_builds_it(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand()
	var card: CardView = _deal(hand, content)[0]
	await _frames(4)
	card.turn(90.0, 0.0, false)
	if card.has_stage():
		fails.append("card rest: a picture turn built the stage")
	card.turn(0.0, 0.0, false)
	card.turn(120.0, -10.0, true)
	if not card.has_stage():
		fails.append("card rest: a live turn did not build the stage")
	await _frames(3)
	if not card.has_stage():
		fails.append("card rest: a card lying turned live let its stage go")
	card.turn(0.0, 0.0, true)
	await _frames(2)
	if card.has_stage():
		fails.append("card rest: a card turned back to rest kept its stage")
	hand.queue_free()
	await _frames(1)


## A card armed to let go and touched before the frame draws keeps its
## stage: the release waits for the frame, and looks again then.
static func _woken_before_the_draw(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand()
	var card: CardView = _deal(hand, content)[0]
	await _frames(4)
	card.turn(90.0, 0.0, true)
	await _frames(1)
	card.turn(0.0, 0.0, true)    # back at rest: armed for the next frame
	card.point_at(Vector2(CardView.CARD_W * 0.5, CardView.CARD_H * 0.5))
	await _frames(2)
	if not card.has_stage():
		fails.append("card rest: a card touched after it was armed to let go let its stage go")
	hand.queue_free()
	await _frames(1)


## A card that does not release keeps its passes: a plain card, and a bake's
## back card, which is read back through both of them.
static func _a_card_that_keeps_its_stage(fails: Array[String], content: ContentDB,
		keeper: _Keeper) -> void:
	var host: Control = _host()
	var plain: CardView = CardView.new(CardInst.new(1, &"strike"), content.card(&"strike"), 1)
	var back: CardView = CardBacks.build("vault")
	host.add_child(plain)
	host.add_child(back)
	var made: int = keeper.made.size()
	await _frames(5)
	if not plain.has_stage() or not back.has_stage() or keeper.made.size() != made:
		fails.append("card rest: a card that does not release let its stage go (plain %s, back %s)"
			% [str(not plain.has_stage()), str(not back.has_stage())])
	host.queue_free()
	await _frames(1)


## The reward's offering, the other place a live card rests while the player
## decides: each card the reward screen builds (RewardSpoils) lets its stage
## go at rest too.
static func _offering_rests_without_stages(fails: Array[String], content: ContentDB) -> void:
	var host: Control = _host()
	var offered: CardView = RewardSpoils.card(content, "strike", 9100, 1.17,
		func(_id: String) -> void: pass)
	host.add_child(offered)
	await _frames(5)
	if not offered.releases_at_rest or offered.has_stage():
		fails.append("card rest: a reward offering's card at rest holds its stage")
	host.queue_free()
	await _frames(1)


## THE STRUCTURAL GUARD for a rebuild. The rebuilt stage wears the very
## materials the card was built with: none is made, so no shader can be made
## again and no pipeline compiled for one. And the fight holds each of them
## for its life: a generated one (BaseMaterial3D, whose shader the engine frees
## with its last wearer) matches one the fight's load holds
## (CardTurn.hold_for_fight, on a real Main); a shader material wears a shader
## the card's script holds for the session.
static func _rebuild_wears_what_the_fight_holds(fails: Array[String],
		content: ContentDB) -> void:
	var held: Array[Dictionary] = _fight_holds(content)
	var script_held: Array[Shader] = [CardView.SURFACE_SHADER, CardView.GEM_SHADER]
	var hand: HandView = _hand()
	var cards: Array[CardView] = _deal(hand, content)
	var built: Dictionary = {}
	for card: CardView in cards:
		built[card] = TurnTests._stage_materials(card._stage)
	await _frames(4)
	for card: CardView in cards:
		if card.has_stage():
			fails.append("card rest: %s did not let its stage go before its rebuild" % card.card_id)
		card.point_at(Vector2(CardView.CARD_W * 0.5, CardView.CARD_H * 0.5))
		var worn: Array[Material] = TurnTests._stage_materials(card._stage)
		if worn != built[card]:
			fails.append("card rest: %s's rebuilt stage wears materials it was not built with"
				% card.card_id)
		for m: Material in worn:
			if m is BaseMaterial3D and not held.has(TurnTests._shader_key(m)):
				fails.append("card rest: %s's rebuilt stage wears a generated material the fight does not hold: %s"
					% [card.card_id, str(TurnTests._shader_key(m))])
			elif m is ShaderMaterial and not script_held.has((m as ShaderMaterial).shader):
				fails.append("card rest: %s's rebuilt stage wears a shader the card's script does not hold"
					% card.card_id)
	hand.queue_free()
	await _frames(1)


## The generated materials a real fight's load holds, by what picks their
## shader.
static func _fight_holds(content: ContentDB) -> Array[Dictionary]:
	var main: Main = TurnTests._opened(content)
	main._start_fight(PackedStringArray(["sporeling"]), "normal")
	var out: Array[Dictionary] = []
	var hold: Node = main._screen.get_node_or_null("CardShaderHold")
	if hold != null:
		var materials: Array = hold.get("materials")
		for m: Material in materials:
			out.append(TurnTests._shader_key(m))
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
	return out


## A card freed while it holds no passes takes its face, slab and camera with
## it: out of the tree, nothing else would.
static func _freed_while_released(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand()
	var card: CardView = _deal(hand, content)[0]
	await _frames(4)
	# Untyped: a typed slot cannot even be read once what it held is freed.
	var kept: Array = [card._content, card._slab, card._cam]
	var parented: int = 0
	for node: Node in [card._content, card._slab, card._cam]:
		parented += 1 if node.get_parent() != null else 0
	if card.has_stage() or parented != 0:
		fails.append("card rest: a released card's face, slab and camera are not out of the tree")
	hand.queue_free()
	await _frames(2)
	var left: int = 0
	for node: Variant in kept:
		left += 1 if is_instance_valid(node) else 0
	if left != 0:
		fails.append("card rest: a card freed while released left %d of its face, slab and camera behind"
			% left)


## A hand in the tree, as the fight lays it out.
static func _hand() -> HandView:
	var hand: HandView = HandView.new()
	hand.size = Vector2(800.0, 300.0)
	Engine.get_main_loop().root.add_child(hand)
	return hand


static func _deal(hand: HandView, content: ContentDB) -> Array[CardView]:
	var out: Array[CardView] = []
	for i: int in range(HAND.size()):
		out.append(hand.add_card(CardInst.new(i + 1, HAND[i]), content.card(HAND[i]), 1))
	return out


static func _host() -> Control:
	var host: Control = Control.new()
	host.size = Vector2(400.0, 400.0)
	Engine.get_main_loop().root.add_child(host)
	return host


static func _frames(n: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for _i: int in range(n):
		await tree.process_frame


## The keeper, faked: each frame kept is a fresh texture, remembered.
class _Keeper:
	extends RefCounted
	var made: Array[Texture2D] = []

	func keep(_stage: Texture2D) -> Texture2D:
		var kept: ImageTexture = ImageTexture.create_from_image(
			Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		made.append(kept)
		return kept
