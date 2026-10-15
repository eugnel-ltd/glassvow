extends Node3D
## Act II's still water: one sheet at the archive's water level
## (`Presets.WATER`), reaching past the frame, drawn as the city's water
## (`city_water.gdshader`, #660 II.3): its depth in the ravines' channels, the
## wash at the masonry's feet and the lamps' reflections come from the land's
## light mask (`city_mask.gd`, bound once the lanterns stand). It moves only
## while the land's motion is on (`LandMotion`), so Reduce Motion holds it.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
const CityKit = preload("res://presentation/map/causeway/city_kit.gd")
const LandMotion = preload("res://presentation/map/landscape/land_motion.gd")
## The sheet runs this far past the land's bounds, beyond any frame.
const MARGIN: float = 40.0

var material: ShaderMaterial
var clock_time: float = 0.0


func build(bounds: Rect2) -> void:
	name = "Still water"
	material = CityKit.water()
	var sheet: SurfaceTool = SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach: Rect2 = bounds.grow(MARGIN)
	var corners: Array[Vector3] = [Vector3(reach.position.x, Presets.WATER, reach.position.y),
		Vector3(reach.end.x, Presets.WATER, reach.position.y), Vector3(reach.end.x, Presets.WATER, reach.end.y),
		Vector3(reach.position.x, Presets.WATER, reach.end.y)]
	# Every vertex faces up: the sheet is flat.
	sheet.set_normal(Vector3.UP)
	Meshes.triangle(sheet, corners[0], corners[2], corners[3])
	Meshes.triangle(sheet, corners[0], corners[1], corners[2])
	var water: MeshInstance3D = Meshes.node(self, Meshes.committed(sheet.commit()), material, "Water sheet")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_time(seconds: float) -> void:
	clock_time = seconds
	material.set_shader_parameter("flow_time", seconds)


func _process(delta: float) -> void:
	if LandMotion.enabled:
		set_time(clock_time + delta)
