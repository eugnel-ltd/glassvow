class_name MapFilmGrain
extends RefCounted
## The film grain on the map (R3.1), drawn by the map's own display
## (`map_display.gdshaderinc`) rather than by `TransitionLayer`, whose grain copies
## the whole screen to overlay it: on the A12 that copy and overlay cost 3.25 ms
## a frame at the Journey rest (`docs/design/2026-10-02-map-living-land/r3/`).
## It keeps that grain's identity: one grain per display pixel, the same overlay
## strength, the same whole-pixel jumps at the same rate, and none under Reduce
## Motion. The noise is fixed, so every capture of the same frame grains it the
## same way: one white-noise cell, laid CELLS x CELLS times into one texture,
## each copy read from its own place, so neighbouring cells never repeat each
## other and the whole repeats only every SIDE pixels. Whatever is the same for
## every pixel is worked out here, not in the shader: the cells' places (once)
## and the jump (`jump`, every GRAIN_STEP), because the A12 is bound by shader
## arithmetic at the map's rest. For the same reason the display covers the
## screen without blending (SHADER) and blends only while its screen fades
## (FADE_SHADER, `blend`). Main decides which grain a frame shows
## (`Main._sync_map_grain`): this one while only the map, its HUD and its pins
## are on screen, the TransitionLayer's under a room, a sheet or a transition
## leaf, so the land is grained once.

const SHADER: Shader = preload("res://presentation/map/map_display.gdshader")
const FADE_SHADER: Shader = preload("res://presentation/map/map_display_fade.gdshader")
## One white-noise cell's side, and the cells a side in the noise the display
## reads: SIDE display pixels a side (4 MiB, one byte a pixel), so the grain
## repeats at most once across a phone's or the iPad's width. SIDE is a power
## of two: the shader wraps with a mask.
const TILE: int = 256
const CELLS: int = 8
const SIDE: int = TILE * CELLS
const SEED: int = 3101
## Where each cell reads the white-noise cell: the fractional parts of
## cell.x * CELL_X + cell.y * CELL_Y, in cells. Two irrational steps (the
## plastic number's R2 pair and sqrt 2, sqrt 3) place every cell apart from
## every other, neighbours at least 32 texels apart.
const CELL_X: Vector2 = Vector2(0.7548776662, 0.5698402910)
const CELL_Y: Vector2 = Vector2(0.4142135624, 0.7320508076)

static var _noise: ImageTexture = null


## The display's material, its grain shown or not (`show`).
static func material(shown: bool) -> ShaderMaterial:
	var out: ShaderMaterial = ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("noise", noise())
	out.set_shader_parameter("wrap", SIDE - 1)
	set_jump(out, 0)
	show(out, shown)
	return out


## Which of TransitionLayer.GRAIN_JUMPS the grain stands at after `seconds` of
## grain time: the next one every GRAIN_STEP, as that grain moves.
static func jump(seconds: float) -> int:
	return int(seconds / TransitionLayer.GRAIN_STEP) % TransitionLayer.GRAIN_JUMPS.size()


## Moves the grain to jump `index` (whole display pixels).
static func set_jump(display: ShaderMaterial, index: int) -> void:
	display.set_shader_parameter("jitter", Vector2i(TransitionLayer.GRAIN_JUMPS[index]))


## Blends the display with its screen while the screen fades (`faded`), and
## writes it over the screen opaque otherwise. The material keeps its values.
static func blend(display: ShaderMaterial, faded: bool) -> void:
	display.shader = FADE_SHADER if faded else SHADER


## Shows the grain, or takes it off as Reduce Motion asks.
static func show(display: ShaderMaterial, shown: bool) -> void:
	display.set_shader_parameter("amount", TransitionLayer.GRAIN_AMOUNT if shown else 0.0)


## The noise the display reads, one byte a pixel, made once per process.
static func noise() -> Texture2D:
	if _noise == null:
		var cell: Image = _white_cell()
		var out: Image = Image.create(SIDE, SIDE, false, Image.FORMAT_R8)
		for cy: int in range(CELLS):
			for cx: int in range(CELLS):
				_lay(out, cell, Vector2i(cx, cy) * TILE, place(Vector2i(cx, cy)))
		_noise = ImageTexture.create_from_image(out)
	return _noise


## Where cell `at` of the noise reads the white-noise cell, in its texels.
static func place(at: Vector2i) -> Vector2i:
	var turn: Vector2 = CELL_X * at.x + CELL_Y * at.y
	return Vector2i(((turn - turn.floor()) * TILE).floor())


static func _white_cell() -> Image:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = SEED
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(TILE * TILE)
	for at: int in range(0, TILE * TILE, 4):
		bytes.encode_u32(at, random.randi())
	return Image.create_from_data(TILE, TILE, false, Image.FORMAT_R8, bytes)


## Lays `cell` into `out` at `origin`, its texel (x, y) reading the cell at
## (x, y) + `from`, wrapped: four rectangles.
static func _lay(out: Image, cell: Image, origin: Vector2i, from: Vector2i) -> void:
	for part: Rect2i in [Rect2i(from, Vector2i(TILE, TILE) - from),
			Rect2i(Vector2i(0, from.y), Vector2i(from.x, TILE - from.y)),
			Rect2i(Vector2i(from.x, 0), Vector2i(TILE - from.x, from.y)),
			Rect2i(Vector2i.ZERO, from)]:
		if part.size.x > 0 and part.size.y > 0:
			var to: Vector2i = Vector2i(posmod(part.position.x - from.x, TILE),
				posmod(part.position.y - from.y, TILE))
			out.blit_rect(cell, part, origin + to)
