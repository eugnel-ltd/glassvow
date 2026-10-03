class_name MapTiltShift
extends RefCounted
## The journey land's tilt-shift (R2 step 2): a sharp band across the frame
## through the framed group of waystones, soft above and below, drawn on the
## stage's display. A screen band rather than depth of field: it never blurs a
## tall object standing mid-frame, and it measured free on the A12 where depth
## of field lost frames (`docs/design/2026-10-02-map-living-land/r2-plan.md`
## §3.1). Off in Whole act, and never on the painted acts.

const SHADER: Shader = preload("res://presentation/map/map_tilt_shift.gdshader")
## The band never narrows below this share of the frame's height. Once the
## player pans any of the framed group off screen, the band follows the members
## still on screen but no wider than `MAX_BAND` and with its middle held within
## `MIDDLE` (a member at the very edge may leave it); with none on screen it is
## the narrowest band about the middle. The sharp band stays where the player
## is looking.
const MIN_BAND: float = 0.52
const MAX_BAND: float = 0.7
const MIDDLE: Vector2 = Vector2(0.3, 0.7)
## How far past the band (a share of the height) the blur reaches full.
const FEATHER: float = 0.16
## The full blur's radius in display pixels at the identity shape's height
## (820 px); other shapes scale with their height.
const STRENGTH_PX: float = 7.0
const IDENTITY_HEIGHT: float = 820.0


## The sharp band as (top, bottom) in px of a frame `height` tall: every y in
## `seats_y` with `margin` to spare, never narrower than `MIN_BAND`; see
## `MIN_BAND` for seats off the frame.
static func band(seats_y: PackedFloat32Array, height: float, margin: float) -> Vector2:
	if height <= 0.0:
		return Vector2.ZERO
	var top: float = INF
	var bottom: float = -INF
	var hidden: bool = seats_y.is_empty()
	for y: float in seats_y:
		if y < 0.0 or y > height:
			hidden = true
			continue
		top = minf(top, y)
		bottom = maxf(bottom, y)
	if top > bottom:
		top = height * 0.5
		bottom = top
	var half: float = maxf((bottom - top) * 0.5 + margin, MIN_BAND * height * 0.5)
	var middle: float = (top + bottom) * 0.5
	if hidden:
		half = minf(half, MAX_BAND * height * 0.5)
		middle = clampf(middle, MIDDLE.x * height, MIDDLE.y * height)
	return Vector2(clampf(middle - half, 0.0, height), clampf(middle + half, 0.0, height))


static func material() -> ShaderMaterial:
	var out: ShaderMaterial = ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("feather", FEATHER)
	return out
