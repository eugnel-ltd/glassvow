extends RefCounted
## Exercise both membership branches of the existing structural guard while
## the real card keeps every material object across its release and rebuild.

const RestTests: GDScript = preload("res://tests/test_card_rest.gd")
const TurnTests: GDScript = preload("res://tests/test_card_turn.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var previous: Callable = CardView._keeper
	var keeper: _Keeper = _Keeper.new()
	CardView.use_keeper(keeper.keep)
	await _case(fails, content, "healthy before")
	await _case(fails, content, "generated")
	await _case(fails, content, "script")
	await _case(fails, content, "healthy after")
	CardView.use_keeper(previous)


static func _case(fails: Array[String], content: ContentDB, mode: String) -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var before: Array[Node] = root.get_children()
	# The real guard captures its baseline, then suspends before the rebuild.
	var probe: _GuardRun = _GuardRun.start(content)
	var hand: HandView = null
	var added: int = 0
	for child: Node in root.get_children():
		if child is HandView and not before.has(child):
			hand = child
			added += 1
	if probe.done or added != 1:
		fails.append("card rest membership: %s did not pause after one real hand's baseline" % mode)
		await probe.finished()
		return
	var card: CardView = hand.card_view(1)
	var built: Array[Material] = TurnTests._stage_materials(card._stage)
	card.tree_exiting.connect(probe.capture.bind(card))
	var expected: Array[String] = []
	if mode == "generated":
		var side: BaseMaterial3D = card._slab.get_surface_override_material(0) as BaseMaterial3D
		var was: Dictionary = TurnTests._shader_key(side)
		side.cull_mode = BaseMaterial3D.CULL_BACK
		if TurnTests._shader_key(side) == was:
			fails.append("card rest membership: generated injection did not change the retained material's shader key")
		expected.append("card rest: strike's rebuilt stage wears a generated material the fight does not hold: %s"
			% str(TurnTests._shader_key(side)))
	elif mode == "script":
		var face: ShaderMaterial = card._slab.get_surface_override_material(1) as ShaderMaterial
		var original: Shader = face.shader
		face.shader = original.duplicate() as Shader
		if face.shader == original or face.shader.code != original.code:
			fails.append("card rest membership: script injection did not use an unheld copy of the same shader")
		expected.append("card rest: strike's rebuilt stage wears a shader the card's script does not hold")
	await probe.finished()
	if probe.rebuilt.is_empty() or probe.rebuilt != built:
		fails.append("card rest membership: %s changed material identity across the real rebuild" % mode)
	# Exact equality also rejects the identity diagnostic and unrelated failures.
	if probe.diagnostics != expected:
		fails.append("card rest membership: %s guard diagnostics %s, want exactly %s"
			% [mode, str(probe.diagnostics), str(expected)])


class _GuardRun:
	extends RefCounted
	signal completed
	var done: bool = false
	var diagnostics: Array[String] = []
	var rebuilt: Array[Material] = []

	static func start(content: ContentDB) -> _GuardRun:
		var probe: _GuardRun = _GuardRun.new()
		probe._run(content)
		return probe

	func _run(content: ContentDB) -> void:
		await RestTests._rebuild_wears_what_the_fight_holds(diagnostics, content)
		done = true
		completed.emit()

	func capture(card: CardView) -> void:
		if card.has_stage():
			rebuilt = TurnTests._stage_materials(card._stage)

	func finished() -> void:
		if not done:
			await completed


class _Keeper:
	extends RefCounted

	func keep(_stage: Texture2D) -> Texture2D:
		return ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
