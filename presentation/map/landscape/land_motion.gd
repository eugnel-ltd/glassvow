extends RefCounted
## The journey land's living motion (R2 step 3): foliage sway, banners, embers
## and ash. One switch for all of it, which `MapScene` turns off under Reduce
## Motion; lantern flicker and the water keep their own cadence (D2).
##
## Materials register here once (they are shared process-wide through the
## kit's templates); nodes read `enabled`.

static var enabled: bool = true
static var _materials: Array[ShaderMaterial] = []


static func register(material: ShaderMaterial) -> void:
	material.set_shader_parameter("motion", 1.0 if enabled else 0.0)
	_materials.append(material)


## Turns the land's motion on or off; cheap to call every frame.
static func apply(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("motion", 1.0 if on else 0.0)
