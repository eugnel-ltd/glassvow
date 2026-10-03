extends Node3D
## The land's lamps (R2 light): every lantern's flame, and the few real lights
## that follow the pilgrim. The pool of light under every lamp is painted into
## the ground (`terrain_paint.gd` `bind_habitat`), so the number of lanterns
## never adds a light to the frame.
##
## Built off the tree on the land's worker: only node, MultiMesh and material
## set-up here, nothing that reads back from the renderer.

const FLAME_SHADER: Shader = preload("res://presentation/map/landscape/flame.gdshader")
const FLIPBOOK: Texture2D = preload("res://assets/art/map-journey/textures/flame-flipbook.png")
## The Mobile renderer lights a mesh with at most eight omni lights; four lamps
## and the Flame leave room under that on every terrain chunk.
const REAL_LIGHTS: int = 4
const FLAME_SIZE: Vector2 = Vector2(.30, .44)
const LIGHT_COLOUR: Color = Color("ffa04a")
const LIGHT_ENERGY: float = 1.6
const LIGHT_RANGE: float = 4.2

## Every lamp's flame centre on the land, in this node's space.
var anchors: PackedVector3Array = PackedVector3Array()
var flames: MultiMeshInstance3D
var lights: Array[OmniLight3D] = []


func build(points: PackedVector3Array) -> void:
	name = "Lamps"
	anchors = points
	var card: QuadMesh = QuadMesh.new()
	card.size = FLAME_SIZE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("flipbook", FLIPBOOK)
	card.material = material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = card
	multi.instance_count = points.size()
	for i: int in range(points.size()):
		multi.set_instance_transform(i, Transform3D(Basis(), points[i]))
	flames = MultiMeshInstance3D.new()
	flames.name = "Lantern flames"
	flames.multimesh = multi
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flames)
	for i: int in range(REAL_LIGHTS):
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Lamp light %d" % i
		light.light_color = LIGHT_COLOUR
		light.light_energy = LIGHT_ENERGY
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		lights.append(light)


## Gives the real lights to the lamps nearest `at` (on the ground plane).
func focus(at: Vector3) -> void:
	var order: Array[int] = []
	for i: int in range(anchors.size()):
		order.append(i)
	var ground: Vector2 = Vector2(at.x, at.z)
	order.sort_custom(func(a: int, b: int) -> bool:
		return ground.distance_squared_to(Vector2(anchors[a].x, anchors[a].z)) \
			< ground.distance_squared_to(Vector2(anchors[b].x, anchors[b].z)))
	for k: int in range(lights.size()):
		lights[k].visible = k < order.size()
		if lights[k].visible:
			lights[k].position = anchors[order[k]]


## The lamps given real light, nearest first (tests and probes).
func lit() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for light: OmniLight3D in lights:
		if light.visible:
			out.append(light.position)
	return out


func _process(_delta: float) -> void:
	# The real lights breathe with their flames; under Reduce Motion too, since
	# lantern flicker is the one motion it keeps.
	var t: float = Time.get_ticks_msec() / 1000.0
	for k: int in range(lights.size()):
		var light: OmniLight3D = lights[k]
		if light.visible:
			var p: Vector3 = light.position
			light.light_energy = LIGHT_ENERGY * (0.9 + 0.1 * sin(t * 9.0 + p.x * 3.1 + p.z * 1.7))
