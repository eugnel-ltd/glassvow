extends Node3D
## Act II's still water: one flat-shaded sheet at the archive's water level
## (`Presets.WATER`), reaching past the frame, darkened into a deep channel
## along each of the layout's two ravines (`MapRavine`). A placeholder for
## II.3's city water; it reads no screen texture and samples nothing.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
## The archive's drowned-city water colours (`water/presets.gd`).
const OPEN: Color = Color("386368")
const DEEP: Color = Color("15333f")
## The sheet runs this far past the land's bounds, beyond any frame.
const MARGIN: float = 40.0
## A channel is fully deep within the ravine's half width of its centre line
## and fades to open water over `CHANNEL_FADE` beyond; it is drawn in strips
## `CHANNEL_ROW` long, a hair over the sheet.
const CHANNEL_FADE: float = 1.6
const CHANNEL_ROW: float = 1.0
const CHANNEL_LIFT: float = .004


func build(bounds: Rect2) -> void:
	name = "Still water"
	var material: StandardMaterial3D = Meshes.material(Color.WHITE, .48)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.metallic_specular = .22
	var sheet: SurfaceTool = SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach: Rect2 = bounds.grow(MARGIN)
	var corners: Array[Vector3] = [Vector3(reach.position.x, Presets.WATER, reach.position.y),
		Vector3(reach.end.x, Presets.WATER, reach.position.y), Vector3(reach.end.x, Presets.WATER, reach.end.y),
		Vector3(reach.position.x, Presets.WATER, reach.end.y)]
	# Every vertex faces up: the sheet is flat.
	sheet.set_normal(Vector3.UP)
	Meshes.triangle(sheet, corners[0], corners[2], corners[3], OPEN)
	Meshes.triangle(sheet, corners[0], corners[1], corners[2], OPEN)
	for cut: float in MapRavine.CUTS:
		_channel(sheet, cut, reach)
	var water: MeshInstance3D = Meshes.node(self, Meshes.committed(sheet.commit()), material, "Water sheet")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## One ravine's channel: a strip along its wandering centre line, deep in the
## middle and open water at its edges, so it joins the sheet without a seam.
func _channel(sheet: SurfaceTool, cut: float, reach: Rect2) -> void:
	var offsets: Array[float] = []
	var shades: Array[Color] = []
	var half: float = MapRavine.HALF_WIDTH
	for across: float in [-half - CHANNEL_FADE, -half, half, half + CHANNEL_FADE]:
		offsets.append(across)
		shades.append(DEEP if absf(across) <= half else OPEN)
	var rows: int = ceili(reach.size.y / CHANNEL_ROW)
	var y: float = Presets.WATER + CHANNEL_LIFT
	for row: int in range(rows):
		var z0: float = reach.position.y + row * CHANNEL_ROW
		var z1: float = z0 + CHANNEL_ROW
		var c0: float = MapRavine.centre(cut, z0)
		var c1: float = MapRavine.centre(cut, z1)
		for i: int in range(offsets.size() - 1):
			var a: Vector3 = Vector3(c0 + offsets[i], y, z0)
			var b: Vector3 = Vector3(c0 + offsets[i + 1], y, z0)
			var c: Vector3 = Vector3(c1 + offsets[i + 1], y, z1)
			var d: Vector3 = Vector3(c1 + offsets[i], y, z1)
			_vertex(sheet, a, shades[i])
			_vertex(sheet, c, shades[i + 1])
			_vertex(sheet, d, shades[i])
			_vertex(sheet, a, shades[i])
			_vertex(sheet, b, shades[i + 1])
			_vertex(sheet, c, shades[i + 1])


static func _vertex(sheet: SurfaceTool, at: Vector3, colour: Color) -> void:
	sheet.set_color(colour)
	sheet.add_vertex(at)
