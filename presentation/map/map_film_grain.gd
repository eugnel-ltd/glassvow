class_name MapFilmGrain
extends RefCounted
## The film grain on the map (R3.1), drawn by the map's own display
## (`map_display.gdshader`) rather than by `TransitionLayer`, whose grain copies
## the whole screen to overlay it: on the A12 that copy and overlay cost 3.25 ms
## a frame at the Journey rest (`docs/design/2026-10-02-map-living-land/r3/`).
## It keeps that grain's identity: one grain per display pixel, the same overlay
## strength, the same whole-pixel jumps at the same rate, and none under Reduce
## Motion. The noise is a fixed tile, so every capture of the same frame grains
## it the same way; each tile-sized cell of the screen reads it from its own
## place, so no two neighbouring cells repeat each other. Main decides which
## grain a frame shows (`Main._sync_map_grain`): this one while only the map,
## its HUD and its pins are on screen, the TransitionLayer's under a room, a
## sheet or a transition leaf, so the land is grained once.

const SHADER: Shader = preload("res://presentation/map/map_display.gdshader")
## The noise tile's side in display pixels.
const TILE: int = 256
const SEED: int = 3101
## Where each cell reads the tile: the fractional parts of cell.x * CELL_X +
## cell.y * CELL_Y, in tiles. Two irrational steps (the plastic number's R2
## pair and sqrt 2, sqrt 3) place every cell of a 4K screen apart from every
## other, nearest neighbours at least 32 texels apart on the tile.
const CELL_X: Vector2 = Vector2(0.7548776662, 0.5698402910)
const CELL_Y: Vector2 = Vector2(0.4142135624, 0.7320508076)

static var _noise: ImageTexture = null


## The display's material, its grain shown or not (`show`).
static func material(shown: bool) -> ShaderMaterial:
	var out: ShaderMaterial = ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("noise", noise())
	out.set_shader_parameter("step_s", TransitionLayer.GRAIN_STEP)
	out.set_shader_parameter("jumps", PackedVector2Array(TransitionLayer.GRAIN_JUMPS))
	out.set_shader_parameter("cell_x", CELL_X)
	out.set_shader_parameter("cell_y", CELL_Y)
	show(out, shown)
	return out


## Shows the grain, or takes it off as Reduce Motion asks.
static func show(display: ShaderMaterial, shown: bool) -> void:
	display.set_shader_parameter("amount", TransitionLayer.GRAIN_AMOUNT if shown else 0.0)


## The white-noise tile, one byte a pixel, made once per process.
static func noise() -> Texture2D:
	if _noise == null:
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = SEED
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(TILE * TILE)
		for at: int in range(0, TILE * TILE, 4):
			bytes.encode_u32(at, random.randi())
		_noise = ImageTexture.create_from_image(
			Image.create_from_data(TILE, TILE, false, Image.FORMAT_R8, bytes))
	return _noise
