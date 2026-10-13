extends RefCounted
## Act I's river (R3.4, issue #660), held where the headless suite can hold
## it: both river shaders draw the one water of `river_water.gdshaderinc`, and
## each keeps its sampler slots. The lean river, which phones and tablets draw,
## binds the bathymetry alone and reads neither the screen nor the depth (the
## A12's slots and its cost); the desktop's adds only those two reads. The
## water's look is proven by the stills, not here.

const SHARED: String = "res://presentation/map/landscape/river_water.gdshaderinc"
const LEAN: String = "res://presentation/map/landscape/river_lite.gdshader"
const FULL: String = "res://presentation/map/landscape/river.gdshader"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_river: %s" % what)


static func run(fails: Array[String]) -> void:
	var shared: String = FileAccess.get_file_as_string(SHARED)
	_check(fails, shared.contains("vec3 river_colour(") and shared.contains("vec3 river_vertex("),
		"the shared water defines the colour and the vertex waves")
	_check(fails, not shared.contains("TIME"), "the water moves only on flow_time, which river.gd drives")
	for path: String in [LEAN, FULL]:
		var code: String = (load(path) as Shader).code
		_check(fails, code.contains("#include \"%s\"" % SHARED) and code.contains("river_colour(")
			and code.contains("river_vertex("), "%s draws the shared water" % path.get_file())
	_samplers(fails, LEAN, shared, ["bathymetry"])
	_samplers(fails, FULL, shared, ["bathymetry", "scene_colour", "scene_depth"])
	var lean: String = (load(LEAN) as Shader).code + shared
	_check(fails, not lean.contains("hint_screen_texture") and not lean.contains("hint_depth_texture"),
		"the lean river reads neither the screen nor the depth")


## The samplers `path` binds with the shared water, by name, and none
## anisotropic.
static func _samplers(fails: Array[String], path: String, shared: String, expected: Array) -> void:
	var names: Array = []
	var lines: String = ""
	for line: String in ((load(path) as Shader).code + "\n" + shared).split("\n"):
		if line.begins_with("uniform sampler2D"):
			names.append(line.get_slice(" ", 2).get_slice(":", 0).strip_edges())
			lines += line
	names.sort()
	var wanted: Array = expected.duplicate()
	wanted.sort()
	_check(fails, names == wanted and not lines.contains("anisotropic"),
		"%s binds %s, none anisotropic (binds %s)" % [path.get_file(), wanted, names])
