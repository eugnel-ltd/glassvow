class_name MapTiltShift
extends RefCounted
## The journey land's tilt-shift (R2 step 2): a sharp band across the frame
## through the framed group of waystones, soft above and below, drawn on the
## stage's display. A screen band rather than depth of field: it never blurs a
## tall object standing mid-frame, and it measured free on the A12 where depth
## of field lost frames (`docs/design/2026-10-02-map-living-land/r2-plan.md`
## §3.1). Off in Whole act, and never on the painted acts.

const SHADER: Shader = preload("res://presentation/map/map_tilt_shift.gdshader")
## The band never narrows below this share of the frame's height.
const MIN_BAND: float = 0.34
## How far past the band (a share of the height) the blur reaches full.
const FEATHER: float = 0.16
## The full blur's radius in display pixels at the identity shape's height
## (820 px); other shapes scale with their height.
const STRENGTH_PX: float = 7.0
const IDENTITY_HEIGHT: float = 820.0


## The sharp band as (top, bottom) in px of a frame `height` tall: every y in
## `seats_y` with `margin` to spare, widened about its middle to `MIN_BAND`.
static func band(seats_y: PackedFloat32Array, height: float, margin: float) -> Vector2:
	if seats_y.is_empty() or height <= 0.0:
		return Vector2(0.0, maxf(height, 0.0))
	var top: float = INF
	var bottom: float = -INF
	for y: float in seats_y:
		top = minf(top, y)
		bottom = maxf(bottom, y)
	top -= margin
	bottom += margin
	var short: float = MIN_BAND * height - (bottom - top)
	if short > 0.0:
		top -= short * 0.5
		bottom += short * 0.5
	return Vector2(clampf(top, 0.0, height), clampf(bottom, 0.0, height))


static func material() -> ShaderMaterial:
	var out: ShaderMaterial = ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("feather", FEATHER)
	return out
