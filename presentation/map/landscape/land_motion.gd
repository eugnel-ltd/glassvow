extends RefCounted
## The journey land's living motion (R2 step 3): foliage and woodland sway,
## banners, embers and ash, the lantern flames' flipbook and flicker, and the
## pools of lamplight that flicker with them. One switch for all of it, which
## `MapScene` turns off under Reduce Motion before the land's first frame and
## on every frame after; only the water keeps its own cadence.
##
## The shaders read one global uniform (`land_motion`, declared in
## project.godot's shader globals), so a material never registers here and a
## land's materials are freed with it; nodes read `enabled`.

const UNIFORM: StringName = &"land_motion"

static var enabled: bool = true


## Turns the land's motion on or off; cheap to call every frame.
static func apply(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	RenderingServer.global_shader_parameter_set(UNIFORM, 1.0 if on else 0.0)
