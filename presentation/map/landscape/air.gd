extends Node3D
## What drifts in Act I's air (R2 step 3): embers rising from the lamps' warmth
## and ash settling through the Ashen Woods, in a box that follows the focus.
## Off, and hidden, under Reduce Motion (`LandMotion`). Two GPU particle
## systems, one draw each; built off the tree on the land's worker.

const SPARK: Shader = preload("res://presentation/map/landscape/spark.gdshader")
const LandMotion = preload("res://presentation/map/landscape/land_motion.gd")
const EMBERS: int = 90
const ASH: int = 140

var embers: GPUParticles3D
var ash: GPUParticles3D


func build() -> void:
	name = "Air"
	embers = _system("Embers", EMBERS, 5.0, 3.2,
		Vector3(8.0, 0.3, 6.0), Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.32, 0.0),
		Vector2(0.03, 0.06), Color(1.0, 0.55, 0.18), 2.6)
	ash = _system("Ash", ASH, 9.0, 1.0,
		Vector3(9.0, 3.5, 7.0), Vector3(0.0, 3.6, 0.0), Vector3(0.0, -0.16, 0.0),
		Vector2(0.028, 0.05), Color(0.56, 0.53, 0.52, 0.85), 1.0)


## Centres the drifting air on `at`.
func focus(at: Vector3) -> void:
	position = at


func _process(_delta: float) -> void:
	var on: bool = LandMotion.enabled
	if visible != on:
		visible = on
		embers.emitting = on
		ash.emitting = on


func _system(label: String, amount: int, lifetime: float, intensity: float,
		extents: Vector3, offset: Vector3, gravity: Vector3, size: Vector2,
		colour: Color, speed: float) -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 60.0
	process.initial_velocity_min = 0.1 * speed
	process.initial_velocity_max = 0.25 * speed
	process.gravity = gravity
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.turbulence_noise_scale = 4.0
	process.scale_min = size.x
	process.scale_max = size.y
	process.color = colour
	var fade: Gradient = Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	var mote: QuadMesh = QuadMesh.new()
	mote.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SPARK
	material.set_shader_parameter("intensity", intensity)
	mote.material = material
	var system: GPUParticles3D = GPUParticles3D.new()
	system.name = label
	system.amount = amount
	system.lifetime = lifetime
	# No preprocess: pre-simulating a lifetime of motes runs every step of it in
	# the land's first frame (a 133 ms frame on the iPad 8). The air fills in
	# over its first few seconds instead.
	system.preprocess = 0.0
	system.process_material = process
	system.draw_pass_1 = mote
	system.position = offset
	system.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system.visibility_aabb = AABB(-extents - Vector3(2, 2, 2), extents * 2.0 + Vector3(4, 6, 4))
	add_child(system)
	return system
