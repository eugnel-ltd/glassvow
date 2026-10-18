extends RefCounted
## The onboarding bench builds a real fight. It must pay the same card-back
## bake and shader hold as the normal fight entries before the encounter.

const TurnTests: GDScript = preload("res://tests/test_card_turn.gd")


static func run(fails: Array[String]) -> void:
	var prefs: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	Preferences.active.card_back = "eclipse"
	CardBacks.use_catalogue(null)
	var render: _Render = _Render.new()
	CardBacks.use_renderer(render.render)
	var main: Main = TurnTests._opened(ContentDB.load_full())
	# The map has finished its synchronous fake bake. Drop it so this entry
	# must pay its own load, rather than inheriting a warmed map by accident.
	CardBacks.use_catalogue(null)
	render.calls.clear()
	main._onboard_fight(PackedStringArray(["sporeling"]), "normal")
	_check_load(fails, main, render, "vault")
	# The same preference becomes eligible when the Vigil has earned it.
	main._vigil.deeds["wins"] = 1
	CardBacks.use_catalogue(null)
	render.calls.clear()
	main._onboard_fight(PackedStringArray(["sporeling"]), "normal")
	_check_load(fails, main, render, "eclipse")
	# A later onboarding fight shares that bake but owns its own shader hold.
	main._onboard_fight(PackedStringArray(["sporeling"]), "normal")
	if render.calls.size() != 1:
		fails.append("onboard prewarm: a cached back rendered again")
	_check_hold(fails, main._screen)
	Preferences.active = prefs
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
	CardBacks.use_renderer(Callable())
	CardBacks.use_catalogue(null)


static func _check_load(fails: Array[String], main: Main, render: _Render,
		id: String) -> void:
	if render.calls.size() != 1:
		fails.append("onboard prewarm: %s load rendered %d backs, want one"
			% [id, render.calls.size()])
	elif render.calls[0][0] != main._screen or render.calls[0][1] != id:
		fails.append("onboard prewarm: %s was not baked under the actual fight" % id)
	if CardTurn.wearing() != id or CardTurn.back() == null \
			or CardTurn.back() != CardBacks.cached(id):
		fails.append("onboard prewarm: the fight does not wear the chosen %s bake" % id)
	_check_hold(fails, main._screen)


static func _check_hold(fails: Array[String], screen: CombatScreen) -> void:
	var hold: Node = screen.get_node_or_null("CardShaderHold")
	if hold == null:
		fails.append("onboard prewarm: the actual fight has no shader hold")
		return
	var held: Array = hold.get("materials")
	var keys: Array[Dictionary] = []
	for material: Material in held:
		keys.append(TurnTests._shader_key(material))
	for material: Material in CardView.generated_materials():
		if not keys.has(TurnTests._shader_key(material)):
			fails.append("onboard prewarm: the fight does not retain a generated card material")


## Complete immediately: these checks observe entry dispatch and ownership,
## with no render timing, timer or process-frame deadline in the regression.
class _Render:
	extends RefCounted
	var calls: Array = []

	func render(host: Node, id: String, scale: float) -> CardBacks.Baked:
		calls.append([host, id])
		var out: CardBacks.Baked = CardBacks.Baked.new()
		out.stage = ImageTexture.create_from_image(
			Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		out.inner = ImageTexture.create_from_image(
			Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
		var back: CardView = CardBacks.build(id)
		out.plate = CardBacks.plate_of(back, out.inner)
		back.free()
		out.oversample = scale
		return out
