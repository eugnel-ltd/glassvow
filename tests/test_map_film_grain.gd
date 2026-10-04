extends RefCounted
## The map's film grain (R3.1, `MapFilmGrain`): the map's display draws the
## grain itself from a tiled white-noise texture, with the TransitionLayer
## grain's strength, jumps and rate, repeating only every 2048 pixels; Reduce
## Motion takes it away; the display fades with its screen; and Main shows one
## grain a frame on the map route: the map's own at rest, the TransitionLayer's
## under a room, a sheet or a transition leaf.

const RUN_PATH: String = "user://test_map_film_grain_run_v2.json"
const VIGIL_PATH: String = "user://test_map_film_grain_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("map_film_grain: %s" % what)


static func run(fails: Array[String]) -> void:
	_noise(fails)
	_display(fails)
	_cells(fails)
	_map_route(fails)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


## One byte of white noise a display pixel, SIDE pixels a side: flat across its
## range, its neighbours uncorrelated, and the same noise on every call.
static func _noise(fails: Array[String]) -> void:
	var image: Image = MapFilmGrain.noise().get_image()
	var side: int = MapFilmGrain.SIDE
	_check(fails, image.get_width() == side and image.get_height() == side
			and image.get_format() == Image.FORMAT_R8,
		"the noise is a %d px one-channel texture" % side)
	# A window across four cells' borders.
	var bytes: PackedByteArray = image.get_region(Rect2i(128, 128, 512, 512)).get_data()
	var bins: PackedInt32Array = PackedInt32Array()
	bins.resize(16)
	var total: float = 0.0
	for value: int in bytes:
		bins[value >> 4] += 1
		total += value
	var mean: float = total / bytes.size() / 255.0
	var flat: bool = true
	for count: int in bins:
		flat = flat and absf(float(count) / bytes.size() - 1.0 / 16.0) < 0.006
	_check(fails, absf(mean - 0.5) < 0.01 and flat,
		"the noise is flat across its range (mean %.3f)" % mean)
	var r: float = _correlation(image, Vector2i(1, 0), mean)
	_check(fails, absf(r) < 0.02, "neighbouring grains are uncorrelated (r %.3f)" % r)
	_check(fails, MapFilmGrain.noise() == MapFilmGrain.noise(), "the noise is made once")


## Correlation of the noise with itself `lag` pixels on, over a sample of rows.
static func _correlation(image: Image, lag: Vector2i, mean: float) -> float:
	var data: PackedByteArray = image.get_data()
	var side: int = image.get_width()
	var products: float = 0.0
	var squares: float = 0.0
	for y: int in range(0, side - lag.y, 7):
		for x: int in range(0, side - lag.x, 5):
			var a: float = data[y * side + x] / 255.0 - mean
			var b: float = data[(y + lag.y) * side + x + lag.x] / 255.0 - mean
			products += a * b
			squares += a * a
	return products / squares


## The display carries the grain at the TransitionLayer grain's strength, jumps
## and rate, drops it under Reduce Motion, and blends only while it fades.
static func _display(fails: Array[String]) -> void:
	var reduced: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	var scene: MapScene = MapScene.new()
	var grain: ShaderMaterial = scene._display.material as ShaderMaterial
	if grain == null:
		_check(fails, false, "the map's display draws the film grain")
		scene.free()
		Preferences.active.reduce_motion = reduced
		return
	var noise: Texture2D = grain.get_shader_parameter("noise")
	_check(fails, grain.shader == MapFilmGrain.SHADER and noise == MapFilmGrain.noise(),
		"the map's display draws the film grain")
	var wrap: int = grain.get_shader_parameter("wrap")
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT)
			and wrap == MapFilmGrain.SIDE - 1,
		"the grain has the TransitionLayer grain's strength over the whole noise")
	# The grain jumps as the TransitionLayer grain does: to the next of its
	# jumps every GRAIN_STEP, through all of them, in whole pixels.
	var seen: Array[Vector2i] = [_jitter(grain)]
	for i: int in range(TransitionLayer.GRAIN_JUMPS.size()):
		scene._process(TransitionLayer.GRAIN_STEP * 0.5)
		_check(fails, _jitter(grain) == seen[-1] or i == 0,
			"the grain holds still between jumps")
		scene._process(TransitionLayer.GRAIN_STEP * 0.5)
		seen.append(_jitter(grain))
	var expected: Array[Vector2i] = []
	for i: int in range(TransitionLayer.GRAIN_JUMPS.size() + 1):
		var jump: Vector2 = TransitionLayer.GRAIN_JUMPS[i % TransitionLayer.GRAIN_JUMPS.size()]
		expected.append(Vector2i(jump))
	_check(fails, seen == expected,
		"the grain jumps through the TransitionLayer grain's jumps at its rate")
	Preferences.active.reduce_motion = true
	scene._process(0.0)
	_check(fails, _amount(grain) == 0.0, "Reduce Motion takes the grain away")
	Preferences.active.reduce_motion = false
	scene._process(0.0)
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT),
		"the grain comes back when motion does")
	scene.set_grain(false)
	_check(fails, _amount(grain) == 0.0, "the screen can take the map's grain off")
	var held: Vector2i = _jitter(grain)
	scene._process(TransitionLayer.GRAIN_STEP * 3.0)
	_check(fails, _jitter(grain) == held, "a grain that is off does not move")
	scene.set_grain(true)
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT),
		"and give it back")
	Preferences.active.reduce_motion = true
	scene.set_grain(true)
	_check(fails, _amount(grain) == 0.0, "giving it back under Reduce Motion shows none")
	Preferences.active.reduce_motion = false
	scene.set_grain(true)
	_blend(fails, scene, grain)
	scene.free()
	Preferences.active.reduce_motion = true
	var still: MapScene = MapScene.new()
	_check(fails, _amount(still._display.material as ShaderMaterial) == 0.0,
		"a map made under Reduce Motion starts without grain")
	still.free()
	Preferences.active.reduce_motion = reduced


## Each cell of the noise reads the white-noise cell from its own place, so
## the grain has no period short of SIDE: no two cells share a place, cells
## that touch (across the texture's wrap too) sit far apart on it, and the
## noise one cell on, across or down, is uncorrelated with itself.
static func _cells(fails: Array[String]) -> void:
	var cells: int = MapFilmGrain.CELLS
	var side: float = float(MapFilmGrain.TILE)
	var places: Dictionary = {}
	var nearest: float = side
	for cy: int in range(cells):
		for cx: int in range(cells):
			var place: Vector2i = MapFilmGrain.place(Vector2i(cx, cy))
			places[place] = true
			for other: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var next: Vector2i = Vector2i(posmod(cx + other.x, cells), posmod(cy + other.y, cells))
				var apart: Vector2 = Vector2(MapFilmGrain.place(next) - place).abs()
				apart = Vector2(minf(apart.x, side - apart.x), minf(apart.y, side - apart.y))
				nearest = minf(nearest, apart.length())
	_check(fails, places.size() == cells * cells, "every cell reads the noise from its own place")
	_check(fails, nearest >= 16.0,
		"touching cells read the noise at least 16 texels apart (%.1f)" % nearest)
	var image: Image = MapFilmGrain.noise().get_image()
	var worst: float = 0.0
	for lag: Vector2i in [Vector2i(MapFilmGrain.TILE, 0), Vector2i(0, MapFilmGrain.TILE),
			Vector2i(MapFilmGrain.TILE, MapFilmGrain.TILE)]:
		worst = maxf(worst, absf(_correlation(image, lag, 0.5)))
	_check(fails, worst < 0.02, "the noise does not repeat a cell on (r %.3f)" % worst)


## The display covers the screen opaque at rest, without blending (the A12's
## saving), and blends while anything up the tree fades it, as a screen's
## entrance does (TransitionLayer.screen_in), so the land fades with its screen.
## The material keeps its values across the switch.
static func _blend(fails: Array[String], scene: MapScene, grain: ShaderMaterial) -> void:
	_check(fails, _modes(MapFilmGrain.SHADER).contains("blend_disabled")
			and not _modes(MapFilmGrain.FADE_SHADER).contains("blend_"),
		"the display has an opaque shader and a blending one")
	var screen: Control = Control.new()
	screen.add_child(scene)
	scene._sync_blend()
	_check(fails, grain.shader == MapFilmGrain.SHADER, "at rest the display writes opaque")
	screen.modulate.a = 0.5
	scene._sync_blend()
	var noise: Texture2D = grain.get_shader_parameter("noise")
	_check(fails, grain.shader == MapFilmGrain.FADE_SHADER
			and is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT)
			and noise == MapFilmGrain.noise(),
		"a fading screen makes the display blend, its grain kept")
	screen.modulate.a = 1.0
	scene._display.self_modulate.a = 0.0
	scene._sync_blend()
	_check(fails, grain.shader == MapFilmGrain.FADE_SHADER, "the display's own fade blends too")
	scene._display.self_modulate.a = 1.0
	scene._sync_blend()
	_check(fails, grain.shader == MapFilmGrain.SHADER, "the faded screen back at full is opaque again")
	screen.remove_child(scene)
	screen.free()


static func _modes(shader: Shader) -> String:
	return shader.code.get_slice("render_mode", 1).get_slice(";", 0)


static func _jitter(grain: ShaderMaterial) -> Vector2i:
	var jitter: Vector2i = grain.get_shader_parameter("jitter")
	return jitter


static func _amount(grain: ShaderMaterial) -> float:
	var amount: float = grain.get_shader_parameter("amount")
	return amount


## Main: on the map route the TransitionLayer's grain (the screen reader) is
## off and the map grains its land; a room or sheet over the map, or a
## transition leaf crossing it, hands the grain to the TransitionLayer and takes
## the map's off, and back when it goes; under Reduce Motion neither shows; the
## next route turns the TransitionLayer's grain on.
static func _map_route(fails: Array[String]) -> void:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = ContentDB.load_full()
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._forced_seed = 31010
	main._vigil.scenes_seen.append("opening")
	main._transitions.set_grain(true)
	main._new_run()
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	_check(fails, main._map_screen != null and not main._transitions._grain.visible,
		"the TransitionLayer's grain is off while the map shows")
	if main._map_screen == null:
		return
	var land: ShaderMaterial = main._map_screen._map_scene._display.material as ShaderMaterial
	_check(fails, _amount(land) > 0.0, "the map grains its own land at rest")
	main._show_run_deck()
	main._sync_map_grain()
	_check(fails, main._transitions._grain.visible and _amount(land) == 0.0,
		"a room over the map takes the TransitionLayer's grain, and the land's goes")
	Preferences.active.reduce_motion = true
	main._sync_map_grain()
	_check(fails, not main._transitions._grain.visible and _amount(land) == 0.0,
		"under Reduce Motion a room over the map shows no grain")
	Preferences.active.reduce_motion = false
	main._close_overlay()
	main._sync_map_grain()
	_check(fails, not main._transitions._grain.visible and _amount(land) > 0.0,
		"closing the room gives the grain back to the map")
	main._transitions._plate.visible = true
	main._sync_map_grain()
	_check(fails, main._transitions._grain.visible and _amount(land) == 0.0,
		"a transition leaf over the map is grained by the TransitionLayer")
	main._transitions._plate.visible = false
	main._sync_map_grain()
	_check(fails, not main._transitions._grain.visible and _amount(land) > 0.0,
		"the map's grain comes back when the leaf ends")
	main._show_route(Control.new())
	_check(fails, main._transitions._grain.visible,
		"the next route turns the TransitionLayer's grain back on")
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
