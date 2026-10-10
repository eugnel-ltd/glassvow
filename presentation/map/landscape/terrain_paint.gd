extends RefCounted
## A world-sized distance field integrates earth roads into the actual land.
const LandStone = preload("res://presentation/map/landscape/land_stone.gd")
const WIDTH: int = 1536
const HEIGHT: int = 960
const ShaderSource: Shader = preload("res://presentation/map/landscape/terrain_paint.gdshader")
const Paths = preload("res://presentation/map/landscape/road_paths.gd")

## The parameters the ground's paint holds when the bridge decks copy it:
## `create`'s own, and the river and profile values `Terrain` sets on it.
const DECK_SHARED: PackedStringArray = ["world_bounds", "route_distance", "habitat",
	"river_cuts", "channel", "lite"]


## The bridge decks' paint: `source`'s shader and shared values, with the deck
## flag. Not `Resource.duplicate`, which lists a ShaderMaterial's properties and
## so asks the renderer for the shader's uniforms, waiting for the main thread
## while the land builds on a worker.
static func deck_variant(source: ShaderMaterial) -> ShaderMaterial:
	var deck: ShaderMaterial = ShaderMaterial.new()
	deck.shader = source.shader
	for key: String in DECK_SHARED:
		var value: Variant = source.get_shader_parameter(key)
		if value != null:
			deck.set_shader_parameter(key, value)
	deck.set_shader_parameter("bridge_surface", true)
	return deck


static func create(lines: Array[PackedVector3Array], _elevated: Callable, bounds: Rect2 = Rect2(-48,-30,96,60)) -> ShaderMaterial:
	# 8 texels a metre: the road's edge is a smooth distance, read bilinearly,
	# and a quarter of the archive's 16 cut its build by about three quarters.
	var width: int = ceili(bounds.size.x*8)
	var height: int = ceili(bounds.size.y*8)
	var values: PackedFloat32Array = []
	values.resize(width * height)
	values.fill(4.0)
	for source: PackedVector3Array in lines:
		var line: PackedVector3Array = Paths.soften(source)
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			var count: int = maxi(1, ceili(a.distance_to(b) / 0.3))
			var side: Vector3 = (b-a).cross(Vector3.UP).normalized()
			var bend: float = 0.025 * sin(a.x * 0.51 + a.z * 0.37)
			for step: int in range(count):
				var p: Vector3 = a.lerp(b, float(step) / count)
				var q: Vector3 = a.lerp(b, float(step + 1) / count)
				# Gentle asymmetric wear stays inside the original playable corridor.
				p += side * bend * sin(PI * float(step) / count)
				q += side * bend * sin(PI * float(step + 1) / count)
				# Paint continues onto banks and below the water. Elevated land
				# crossings keep their own deck rather than drawing a false junction.
				if (p.y+q.y)*.5 < .13:
					_stamp(values, Vector2(p.x,p.z), Vector2(q.x,q.z), bounds, width, height)
	var image: Image = Image.create_from_data(width, height, false, Image.FORMAT_RF, values.to_byte_array())
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ShaderSource
	material.set_shader_parameter("world_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
	material.set_shader_parameter("route_distance", ImageTexture.create_from_image(image))
	material.set_meta("distance_image", image)
	var empty: Image = Image.create(ceili(bounds.size.x*4),ceili(bounds.size.y*4),false,Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	material.set_shader_parameter("habitat",ImageTexture.create_from_image(empty))
	return material

static func _stamp(values: PackedFloat32Array, a: Vector2, b: Vector2, bounds: Rect2 = Rect2(-48,-30,96,60), width: int = WIDTH, height: int = HEIGHT) -> void:
	var lo: Vector2 = a.min(b) - Vector2.ONE * 1.25
	var hi: Vector2 = a.max(b) + Vector2.ONE * 1.25
	var x0: int = clampi(floori((lo.x - bounds.position.x) / bounds.size.x * width), 0, width - 1)
	var x1: int = clampi(ceili((hi.x - bounds.position.x) / bounds.size.x * width), 0, width - 1)
	var y0: int = clampi(floori((lo.y - bounds.position.y) / bounds.size.y * height), 0, height - 1)
	var y1: int = clampi(ceili((hi.y - bounds.position.y) / bounds.size.y * height), 0, height - 1)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var p: Vector2 = Vector2(bounds.position.x + (x + 0.5) * bounds.size.x / width, bounds.position.y + (y + 0.5) * bounds.size.y / height)
			var distance: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			var index: int = y * width + x
			values[index] = minf(values[index], distance)

## The habitat map the ground and decks read: red the woodland's reach, green the
## rock's, blue the dirt carried onto deck ends, alpha the pool of light under
## every lamp in `lamps` (R2 light; the shader flickers it).
static func bind_habitat(parent: Node3D, placements: Array[Dictionary], lines: Array[PackedVector3Array], elevated: Callable, lamps: PackedVector3Array = PackedVector3Array()) -> void:
	var bounds: Rect2 = parent.get_meta("world_bounds",Rect2(-48,-30,96,60))
	var map: Image = Image.create(ceili(bounds.size.x*4),ceili(bounds.size.y*4),false,Image.FORMAT_RGBA8)
	map.fill(Color(0, 0, 0, 0))
	for item: Dictionary in placements:
		var kind: String = str(item["kind"])
		var rock: bool = LandStone.OUTCROPS.has(kind)
		if not rock and not kind.begins_with("conifer") and not kind.begins_with("ash"):
			continue
		var at: Vector3 = item["position"]
		var radius: float = float(str(item["radius"])) + 2.2
		var centre: Vector2 = Vector2((at.x-bounds.position.x)*4,(at.z-bounds.position.y)*4)
		for y: int in range(maxi(0,floori(centre.y-radius*4)),mini(map.get_height(),ceili(centre.y+radius*4))):
			for x: int in range(maxi(0,floori(centre.x-radius*4)),mini(map.get_width(),ceili(centre.x+radius*4))):
				var influence: float = 1.0-smoothstep(.2,radius,Vector2(x+.5,y+.5).distance_to(centre)/4)
				var colour: Color = map.get_pixel(x,y)
				if rock:
					colour.g = maxf(colour.g,influence)
				else:
					colour.r = maxf(colour.r,influence)
				map.set_pixel(x,y,colour)
	# Dirt continues over the first stones at every real deck-to-earth boundary.
	for line: PackedVector3Array in lines:
		for i: int in range(line.size()-1):
			var steps: int = maxi(1,ceili(line[i].distance_to(line[i+1])/.25))
			for step: int in range(steps):
				var p: Vector3 = line[i].lerp(line[i+1],float(step)/steps)
				var q: Vector3 = line[i].lerp(line[i+1],float(step+1)/steps)
				if elevated.call(p) == elevated.call(q):
					continue
				var centre: Vector2 = Vector2((p.x+q.x)*.5-bounds.position.x,(p.z+q.z)*.5-bounds.position.y)*4
				for y: int in range(maxi(0,floori(centre.y-9)),mini(map.get_height(),ceili(centre.y+9))):
					for x: int in range(maxi(0,floori(centre.x-9)),mini(map.get_width(),ceili(centre.x+9))):
						var colour: Color = map.get_pixel(x,y)
						colour.b = maxf(colour.b,1.0-smoothstep(.45,2.2,Vector2(x+.5,y+.5).distance_to(centre)/4))
						map.set_pixel(x,y,colour)
	_paint_pools(map, bounds, lamps)
	var texture: ImageTexture = ImageTexture.create_from_image(map)
	for name: String in ["Quiet sculpted ground","Continuous bridge decks"]:
		var node: MeshInstance3D = parent.get_node_or_null(name) as MeshInstance3D
		if node != null:
			(node.material_override as ShaderMaterial).set_shader_parameter("habitat",texture)
			node.material_override.set_meta("habitat_image",map)


## Each lamp's pool: full under the lantern, gone by `POOL_RADIUS`, overlapping
## pools adding up to full.
const POOL_RADIUS: float = 3.4


static func _paint_pools(map: Image, bounds: Rect2, lamps: PackedVector3Array) -> void:
	for lamp: Vector3 in lamps:
		var centre: Vector2 = Vector2((lamp.x - bounds.position.x) * 4, (lamp.z - bounds.position.y) * 4)
		var reach: float = POOL_RADIUS * 4
		for y: int in range(maxi(0, floori(centre.y - reach)), mini(map.get_height(), ceili(centre.y + reach))):
			for x: int in range(maxi(0, floori(centre.x - reach)), mini(map.get_width(), ceili(centre.x + reach))):
				var near: float = 1.0 - Vector2(x + .5, y + .5).distance_to(centre) / reach
				if near <= 0.0:
					continue
				var colour: Color = map.get_pixel(x, y)
				colour.a = minf(1.0, colour.a + near * near)
				map.set_pixel(x, y, colour)
