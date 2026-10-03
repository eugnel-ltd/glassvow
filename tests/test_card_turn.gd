extends RefCounted
## Turning a card over (issue #657, PR 3): one pose maths for both renderers,
## CardView.turn's two renderers and its rest, the back plate a bake dresses a
## card in, the pre-warm's bake and warmer, and every fight's load paying for
## them with the back the player wears.
##
## The bakes run on a fake render step (CardBacks.use_renderer): the suite is
## headless, where no frame is ever drawn. That the two renderers put the card
## in the same place, and that rest is restored to the texel, is measured
## windowed by tools/check_card_turn.gd; the turn sheet (`--turns`) shows it.

const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const PICTURE_UNIFORMS: Array[String] = [
	"back_tex", "pose", "lens", "rect", "half_card", "radius", "thick", "side"]


static func run(fails: Array[String]) -> void:
	CardBacks.use_catalogue(null)
	var content: ContentDB = ContentDB.load_full()
	_pose_maths(fails)
	_footprint(fails)
	_picture_shader(fails)
	_plate_of_a_bake(fails)
	var render: _FakeRender = _FakeRender.new()
	CardBacks.use_renderer(render.render)
	await _prewarm(fails, render)
	await _turns(fails, content)
	await _turn_without_a_back(fails, content)
	await _each_fight_prewarms(fails, content, render)
	CardBacks.use_renderer(Callable())
	CardBacks.use_catalogue(null)


static func _pose_maths(fails: Array[String]) -> void:
	# One Euler convention: the slab's own, so a pose and the slab agree.
	var node: Node3D = Node3D.new()
	for yp: Vector2 in [Vector2(35.0, -10.0), Vector2(100.0, -14.0), Vector2(-60.0, 7.0)]:
		node.rotation_degrees = Vector3(yp.y, yp.x, 0.0)
		if not CardTurn.pose(yp.x, yp.y).is_equal_approx(node.basis):
			fails.append("card turn: pose(%s) is not the slab's rotation_degrees basis" % str(yp))
	node.free()
	if not CardTurn.is_rest(CardTurn.pose(0.0, 0.0)) or CardTurn.is_rest(CardTurn.pose(1.0, 0.0)):
		fails.append("card turn: rest is not exactly the zero pose")
	var down: Basis = CardTurn.pose(180.0, 0.0)
	if not (down * Vector3.RIGHT).is_equal_approx(Vector3.LEFT) \
			or not (down * Vector3.BACK).is_equal_approx(Vector3.FORWARD) \
			or not (down * Vector3.UP).is_equal_approx(Vector3.UP):
		fails.append("card turn: yaw 180 does not lay the card face down about its vertical axis")


static func _footprint(fails: Array[String]) -> void:
	var at_rest: Vector2 = CardTurn.footprint(Basis.IDENTITY)
	var at_sixty: Vector2 = CardTurn.footprint(CardTurn.pose(60.0, 0.0))
	var edge_on: Vector2 = CardTurn.footprint(CardTurn.pose(90.0, 0.0))
	var pitched: Vector2 = CardTurn.footprint(CardTurn.pose(0.0, 60.0))
	if not at_rest.is_equal_approx(Vector2.ONE):
		fails.append("card turn: the shadow under a resting card is %s, not whole" % str(at_rest))
	if not at_sixty.is_equal_approx(Vector2(0.5, 1.0)) or not pitched.is_equal_approx(Vector2(1.0, 0.5)):
		fails.append("card turn: the shadow does not narrow with the card (%s, %s)"
			% [str(at_sixty), str(pitched)])
	if not edge_on.is_equal_approx(Vector2(CardTurn.MIN_FOOTPRINT, 1.0)):
		fails.append("card turn: the shadow of an edge-on card is %s" % str(edge_on))


static func _picture_shader(fails: Array[String]) -> void:
	var names: Array[String] = []
	for uniform: Dictionary in CardTurn.PICTURE_SHADER.get_shader_uniform_list():
		names.append(str(uniform.get("name", "")))
	for want: String in PICTURE_UNIFORMS:
		if not names.has(want):
			fails.append("card turn: the picture turn's shader has no `%s` uniform" % want)
	# Code, not commentary: the header says what it does not read.
	var token: RegEx = RegEx.create_from_string("\\b(TIME|SCREEN_TEXTURE|hint_screen_texture)\\b")
	for line: String in CardTurn.PICTURE_SHADER.code.split("\n"):
		if token.search(line.get_slice("//", 0)) != null:
			fails.append("card turn: the picture turn reads the time or the screen: %s" % line.strip_edges())
	var m: ShaderMaterial = CardTurn.picture(null, 9.0, Color.RED)
	if m.get_shader_parameter("lens") != CardView.lens() or m.get_shader_parameter("thick") != 9.0 \
			or m.get_shader_parameter("rect") != Vector2(CardView.CARD_W, CardView.CARD_H) \
				+ Vector2.ONE * CardView.PAD_3D * 2.0:
		fails.append("card turn: the picture turn is not framed as the card's stage is")


static func _plate_of_a_bake(fails: Array[String]) -> void:
	var back: CardView = CardBacks.build("rose")
	var inner: ImageTexture = _texture()
	var plate: ShaderMaterial = CardBacks.plate_of(back, inner)
	var face: ShaderMaterial = back.face_material()
	if plate == face or plate.shader != face.shader \
			or plate.get_shader_parameter("face_tex") != inner:
		fails.append("card turn: a bake's plate is not its own copy of the back's face over the baked face")
	for key: String in ["holo", "sheen", "tint", "ink", "relief", "mask", "art_rect"]:
		if plate.get_shader_parameter(key) != face.get_shader_parameter(key):
			fails.append("card turn: a bake's plate does not wear the back's `%s`" % key)
	back.free()


static func _prewarm(fails: Array[String], render: _FakeRender) -> void:
	var host: Control = _host()
	render.calls.clear()
	var warm: _Prewarm = _Prewarm.start(host, "rose")
	var warmers: Array[Node] = host.find_children("CardTurnWarmer", "TextureRect", false, false)
	if warmers.size() != 1:
		fails.append("card turn: the pre-warm drew %d warmers in its first frame, want 1" % warmers.size())
	else:
		var warmer: TextureRect = warmers[0]
		var m: ShaderMaterial = warmer.material as ShaderMaterial
		if m == null or m.shader != CardTurn.PICTURE_SHADER:
			fails.append("card turn: the warmer does not wear the picture turn's shader")
	if render.calls != [[host, "rose"]]:
		fails.append("card turn: the pre-warm baked %s, want the back it was given under the fight"
			% str(render.calls))
	await warm.finished()
	if CardTurn.wearing() != "rose" or CardTurn.back() == null \
			or CardTurn.back() != CardBacks.cached("rose"):
		fails.append("card turn: after the pre-warm the table does not wear its bake")
	await _frames(host, 2)
	if not host.find_children("CardTurnWarmer", "", false, false).is_empty():
		fails.append("card turn: the warmer outlived the pre-warm")
	# A second fight with the back already baked bakes nothing more.
	render.calls.clear()
	await _Prewarm.start(host, "rose").finished()
	if not render.calls.is_empty():
		fails.append("card turn: a fight whose back was baked baked it again")
	host.queue_free()
	await _frames(host, 1)


static func _turns(fails: Array[String], content: ContentDB) -> void:
	var host: Control = _host()
	var back: CardBacks.Baked = CardTurn.back()
	# A rare, so the shine's rule is seen.
	var card: CardView = _card(content, &"novaflare")
	host.add_child(card)
	await _frames(host, 3)
	var shine: Control = card._shine
	if shine == null:
		fails.append("card turn: the rare under test wears no shine")
		host.queue_free()
		return

	# The picture turn: the material on the picture, the slab untouched, and
	# nothing asked of the frozen stage.
	card._stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	card.turn(70.0, -10.0, false)
	var warp: ShaderMaterial = card._display.material as ShaderMaterial
	if warp == null or warp.shader != CardTurn.PICTURE_SHADER:
		fails.append("card turn: a picture turn did not warp the card's picture")
	elif not _basis(warp.get_shader_parameter("pose")).is_equal_approx(CardTurn.pose(70.0, -10.0)) \
			or warp.get_shader_parameter("back_tex") != back.stage \
			or warp.get_shader_parameter("thick") != card._thick:
		fails.append("card turn: the picture turn is not at the pose, on the table's back, at the slab's thickness")
	if not card._slab.basis.is_equal_approx(Basis.IDENTITY) or card._back_plate != null:
		fails.append("card turn: a picture turn moved the slab or built a plate")
	if card._stage.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		fails.append("card turn: a picture turn asked the frozen stage to render")
	if shine.visible or card.at_rest():
		fails.append("card turn: a turned card kept its resting shine, or reads as at rest")
	if not card._shadow.scale.is_equal_approx(CardTurn.footprint(CardTurn.pose(70.0, -10.0))):
		fails.append("card turn: the table shadow did not narrow with the turn")

	# The live turn, from the picture turn: the slab wears the same pose, its
	# plate wears the table's back under the card's own lamp, the stage renders.
	card.turn(140.0, -10.0, true)
	var plate: MeshInstance3D = card._back_plate
	if card._display.material != null:
		fails.append("card turn: a live turn left the picture warped")
	if not card._slab.basis.is_equal_approx(CardTurn.pose(140.0, -10.0)):
		fails.append("card turn: the live turn's slab is not at the pose the picture turn takes")
	if plate == null or plate.get_parent() != card._slab or not plate.visible:
		fails.append("card turn: the live turn built no back plate on the slab")
	else:
		var pm: ShaderMaterial = plate.material_override as ShaderMaterial
		if pm == back.plate or pm.get_shader_parameter("face_tex") != back.inner:
			fails.append("card turn: the plate does not wear its own copy of the table's back")
		if not card._lit.has(pm) or pm.get_shader_parameter("lamp") != card._lamp:
			fails.append("card turn: the card's lamp does not reach its back plate")
		if not plate.position.is_equal_approx(Vector3(0.0, 0.0,
				-card._thick * 0.5 - CardTurn.PLATE_GAP)):
			fails.append("card turn: the plate is not on the slab's far face")
	if card._stage.render_target_update_mode != SubViewport.UPDATE_ONCE:
		fails.append("card turn: a live turn did not render the stage at its pose")

	# Back to rest from a live turn: everything as built, the stage rendered
	# once more at rest.
	card._stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
	card.turn(0.0, 0.0, true)
	_check_rest(fails, card, shine, "a live turn")
	if card._stage.render_target_update_mode != SubViewport.UPDATE_ONCE:
		fails.append("card turn: a live turn back to rest did not render the stage at rest")

	# A live turn handed to the picture turn leaves the slab at rest for the
	# picture to warp.
	card.turn(100.0, -10.0, true)
	card.turn(100.0, -10.0, false)
	if not card._slab.basis.is_equal_approx(Basis.IDENTITY) or card._back_plate.visible:
		fails.append("card turn: a picture turn after a live one warps a turned stage")
	card.turn(0.0, 0.0, false)
	_check_rest(fails, card, shine, "a picture turn")
	host.queue_free()
	await _frames(host, 1)


static func _check_rest(fails: Array[String], card: CardView, shine: Control, after: String) -> void:
	if card._display.material != null or not card._slab.basis.is_equal_approx(Basis.IDENTITY) \
			or (card._back_plate != null and card._back_plate.visible):
		fails.append("card turn: after %s, rest left a material, a turned slab or a plate" % after)
	if not shine.visible or not card._shadow.scale.is_equal_approx(Vector2.ONE) or not card.at_rest():
		fails.append("card turn: after %s, rest did not bring back the shine and the whole shadow" % after)


static func _turn_without_a_back(fails: Array[String], content: ContentDB) -> void:
	# No back baked (a lab that never pre-warmed): the card still turns, and
	# shows no back rather than failing.
	CardBacks.use_catalogue(null)
	var host: Control = _host()
	var card: CardView = _card(content, &"strike")
	host.add_child(card)
	await _frames(host, 3)
	card.turn(150.0, 0.0, true)
	card.turn(150.0, 0.0, false)
	if card._back_plate != null:
		fails.append("card turn: a live turn with no bake built a plate")
	var warp: ShaderMaterial = card._display.material as ShaderMaterial
	if warp == null or warp.get_shader_parameter("back_tex") != null:
		fails.append("card turn: a picture turn with no bake did not turn, or invented a back")
	host.queue_free()
	await _frames(host, 1)


static func _each_fight_prewarms(fails: Array[String], content: ContentDB,
		render: _FakeRender) -> void:
	var main: Main = _opened(content)
	var prefs: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.card_back = "eclipse"
	# A blank Vigil has not earned Eclipse: the table wears the default.
	CardBacks.use_catalogue(null)
	render.calls.clear()
	main._start_fight(PackedStringArray(["sporeling"]), "normal")
	await _frames(main, 2)
	if render.calls.size() != 1 or render.calls[0][0] != main._screen \
			or render.calls[0][1] != "vault":
		fails.append("card turn: the bench fight's load baked %s, want vault under the fight"
			% str(render.calls))
	# A Vigil with a win wears the chosen Eclipse, on the map's route too.
	main._vigil.deeds["wins"] = 1
	CardBacks.use_catalogue(null)
	render.calls.clear()
	main.game.run.pending_combat = "monster"
	main.game.run.pending_enemy_ids = ["sporeling"]
	main._resume_pending_combat()
	await _frames(main, 2)
	if render.calls.size() != 1 or render.calls[0][0] != main._screen \
			or render.calls[0][1] != "eclipse":
		fails.append("card turn: the route's fight load baked %s, want eclipse under the fight"
			% str(render.calls))
	Preferences.active = prefs
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


## A Main on a scratch profile with a fresh run on its map, out of the tree
## (a fight built there opens without its entrance).
static func _opened(content: ContentDB) -> Main:
	var main: Main = Main.new()
	TestProfile.install(main)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._forced_seed = 1
	main._vigil.scenes_seen.append("opening")
	main._new_run()
	if main._route_screen is DepartureStaging or main._map_screen == null:
		main._show_map()
	return main


static func _host() -> Control:
	var host: Control = Control.new()
	host.size = Vector2(400.0, 400.0)
	Engine.get_main_loop().root.add_child(host)
	return host


static func _card(content: ContentDB, id: StringName) -> CardView:
	var data: Dictionary = content.card(id)
	if data.is_empty():
		data = CardLab.load_catalog(content).get(String(id), {})
	return CardView.new(CardInst.new(1, id), data, 1)


static func _frames(_node: Node, n: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for _i: int in range(n):
		await tree.process_frame


static func _basis(value: Variant) -> Basis:
	if typeof(value) != TYPE_BASIS:
		return Basis()
	var b: Basis = value
	return b


static func _texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))


## The bake step, faked: each call is counted with its host and lands a frame
## later with the back's real plate over a stand-in face.
class _FakeRender:
	extends RefCounted
	var calls: Array = []

	func render(host: Node, id: String, scale: float) -> CardBacks.Baked:
		calls.append([host, id])
		await (Engine.get_main_loop() as SceneTree).process_frame
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.stage = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.inner = ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		var view: CardView = CardBacks.build(id)
		out.plate = CardBacks.plate_of(view, out.inner)
		view.free()
		out.oversample = scale
		return out


## One pre-warm, started without waiting, so the test can look at its first
## frame and then wait for it.
class _Prewarm:
	extends RefCounted
	signal done
	var _done: bool = false

	static func start(host: Node, id: String) -> _Prewarm:
		var p: _Prewarm = _Prewarm.new()
		p._run(host, id)
		return p

	func _run(host: Node, id: String) -> void:
		await CardTurn.prewarm(host, id)
		_done = true
		done.emit()

	func finished() -> void:
		if not _done:
			await done
