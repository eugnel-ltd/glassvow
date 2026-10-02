class_name TitleLampChain
extends Control
## The lamplighter chain on the painted road: a warm glow over each roadside
## lantern of the title painting (assets/art/title-background/background.png),
## catching pair by pair from the nearest to the sealed door as `progress`
## runs, then burning softly. Positions are in the painting's own pixels and
## mapped through the same cover fit the painting is drawn with.

const ART_SIZE: Vector2 = Vector2(1536.0, 1024.0)
## Near to far: (x, y, glow radius) in painting px, left then right of a pair.
const PAIRS: Array[Array] = [
	[Vector3(90, 770, 64), Vector3(1414, 775, 64)],
	[Vector3(320, 680, 36), Vector3(1202, 690, 36)],
	[Vector3(482, 644, 24), Vector3(1052, 648, 24)],
	[Vector3(559, 628, 17), Vector3(965, 632, 17)],
	[Vector3(611, 620, 13), Vector3(929, 619, 13)],
	[Vector3(646, 612, 10), Vector3(898, 610, 10)],
	[Vector3(671, 606, 8), Vector3(873, 604, 8)],
	[Vector3(690, 602, 7), Vector3(855, 600, 7)],
]
const WARM: Color = Color("#ffa04d")

var progress: float = 1.0:
	set(value):
		progress = value
		queue_redraw()
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Where a painting pixel lands on a stage of `stage` size (cover fit, centred).
static func to_stage(art_px: Vector2, stage: Vector2) -> Vector2:
	var k: float = maxf(stage.x / ART_SIZE.x, stage.y / ART_SIZE.y)
	return (stage - ART_SIZE * k) * 0.5 + art_px * k


static func scale_for(stage: Vector2) -> float:
	return maxf(stage.x / ART_SIZE.x, stage.y / ART_SIZE.y)


func _process(delta: float) -> void:
	if LeadlightMotion.reduced():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var disc: Texture2D = SkyField.disc()
	var k: float = scale_for(size)
	for i: int in PAIRS.size():
		var lit: float = LeadlightMotion.chain(progress, i, PAIRS.size())
		if lit <= 0.001:
			continue
		for j: int in range(2):
			var lamp: Vector3 = PAIRS[i][j]
			var at: Vector2 = to_stage(Vector2(lamp.x, lamp.y), size)
			var flicker: float = 1.0 + 0.06 * sin(_time * 7.3 + float(i * 2 + j) * 1.7)
			var r: float = lamp.z * k * flicker
			# The catch flares a little before it settles.
			var flare: float = 1.0 + 0.6 * (1.0 - absf(lit * 2.0 - 1.0)) * float(lit < 1.0)
			draw_texture_rect(disc, Rect2(at - Vector2(r, r) * 2.2 * flare, Vector2(r, r) * 4.4 * flare),
				false, Color(WARM, 0.22 * lit))
			draw_texture_rect(disc, Rect2(at - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4),
				false, Color(Color("#ffd28a"), 0.55 * lit))
