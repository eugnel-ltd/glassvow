extends RefCounted
## The map's film grain (R3.1, `MapFilmGrain`): the map's display draws the
## grain itself from a tiled white-noise texture, with the TransitionLayer
## grain's strength, jumps and rate, each cell of the screen reading the tile
## from its own place; Reduce Motion takes it away; the display fades with its
## screen; and Main shows one grain a frame on the map route: the map's own at
## rest, the TransitionLayer's under a room, a sheet or a transition leaf.

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


## One byte of white noise a display pixel: flat across its range, its
## neighbours uncorrelated, and the same tile on every call.
static func _noise(fails: Array[String]) -> void:
	var image: Image = MapFilmGrain.noise().get_image()
	var side: int = MapFilmGrain.TILE
	_check(fails, image.get_width() == side and image.get_height() == side
			and image.get_format() == Image.FORMAT_R8,
		"the noise is a %d px one-channel tile" % side)
	var bytes: PackedByteArray = image.get_data()
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
	var products: float = 0.0
	var squares: float = 0.0
	for y: int in range(side):
		for x: int in range(side - 1):
			var a: float = bytes[y * side + x] / 255.0 - mean
			var b: float = bytes[y * side + x + 1] / 255.0 - mean
			products += a * b
			squares += a * a
	_check(fails, absf(products / squares) < 0.02,
		"neighbouring grains are uncorrelated (r %.3f)" % (products / squares))
	_check(fails, MapFilmGrain.noise() == MapFilmGrain.noise(), "the tile is made once")


## The display carries the grain at the TransitionLayer grain's strength, jumps
## and rate, and drops it under Reduce Motion.
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
	var step_s: float = grain.get_shader_parameter("step_s")
	var jumps: PackedVector2Array = grain.get_shader_parameter("jumps")
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT)
			and is_equal_approx(step_s, TransitionLayer.GRAIN_STEP)
			and jumps == PackedVector2Array(TransitionLayer.GRAIN_JUMPS),
		"the grain has the TransitionLayer grain's strength, jumps and rate")
	Preferences.active.reduce_motion = true
	scene._process(0.0)
	_check(fails, _amount(grain) == 0.0, "Reduce Motion takes the grain away")
	Preferences.active.reduce_motion = false
	scene._process(0.0)
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT),
		"the grain comes back when motion does")
	scene.set_grain(false)
	_check(fails, _amount(grain) == 0.0, "the screen can take the map's grain off")
	scene.set_grain(true)
	_check(fails, is_equal_approx(_amount(grain), TransitionLayer.GRAIN_AMOUNT),
		"and give it back")
	Preferences.active.reduce_motion = true
	scene.set_grain(true)
	_check(fails, _amount(grain) == 0.0, "giving it back under Reduce Motion shows none")
	Preferences.active.reduce_motion = false
	# The land fades with its screen (TransitionLayer.screen_in): the display
	# blends like any canvas item rather than writing over what is beneath.
	var modes: String = grain.shader.code.get_slice("render_mode", 1).get_slice(";", 0)
	_check(fails, not modes.contains("blend_disabled") and not modes.contains("blend_add"),
		"the display blends with its screen's modulate")
	scene.free()
	Preferences.active.reduce_motion = true
	var still: MapScene = MapScene.new()
	_check(fails, _amount(still._display.material as ShaderMaterial) == 0.0,
		"a map made under Reduce Motion starts without grain")
	still.free()
	Preferences.active.reduce_motion = reduced


## Each tile-sized cell of the screen reads the tile from its own place, the
## shader's floor(fract(cell.x * cell_x + cell.y * cell_y) * TILE): on a 4K
## screen (and a jump past its edge) no two cells share a place, and cells that
## touch sit far apart on the tile, so the grain has no period.
static func _cells(fails: Array[String]) -> void:
	var grain: ShaderMaterial = MapFilmGrain.material(true)
	var cell_x: Vector2 = grain.get_shader_parameter("cell_x")
	var cell_y: Vector2 = grain.get_shader_parameter("cell_y")
	var side: float = float(MapFilmGrain.TILE)
	var places: Dictionary = {}
	var nearest: float = side
	var span: int = ceili(3840.0 / side) + 1
	for cy: int in range(-1, span):
		for cx: int in range(-1, span):
			var at: Vector2 = cell_x * cx + cell_y * cy
			var place: Vector2 = (at - at.floor()) * side
			places[Vector2i(place.floor())] = true
			for other: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var there: Vector2 = cell_x * (cx + other.x) + cell_y * (cy + other.y)
				var apart: Vector2 = ((there - there.floor()) * side - place).abs()
				apart = Vector2(minf(apart.x, side - apart.x), minf(apart.y, side - apart.y))
				nearest = minf(nearest, apart.length())
	_check(fails, places.size() == (span + 1) * (span + 1),
		"every cell of a 4K screen reads the tile from its own place")
	_check(fails, nearest >= 16.0,
		"touching cells read the tile at least 16 texels apart (%.1f)" % nearest)


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
