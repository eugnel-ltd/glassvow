extends RefCounted
## Act II's light mask (#660 II.3): one small picture over the plan that the
## water and the masonry read (`city_water.gdshader`, `masonry.gdshader`), so
## the land's light costs one texture and no lights.
##
## - R, the masonry's footprint: each texel's share under a deck (four
##   samples), so the water washes along every wall's foot.
## - G, the lamps' pools on the decks round each lantern.
## - B, the lamps' reflections: a column from each lantern's foot toward the
##   journey camera (it looks along -z), as a light over still water is seen.
##
## Built on the land's worker from plain arrays: the decks' triangles as built
## and the lanterns' anchors.
const WIDTH: int = 256
const HEIGHT: int = 168
## How far past the land's bounds the mask reaches.
const MARGIN: float = 4.0
const POOL_RADIUS: float = 1.5
const COLUMN_LENGTH: float = 2.4
const COLUMN_WIDTH: float = .22
## The footprint's samples in a texel (a 2 x 2 grid), each a quarter of it.
const SAMPLES: Array[Vector2] = [Vector2(.25, .25), Vector2(.75, .25), Vector2(.25, .75), Vector2(.75, .75)]

## The plan the mask covers: x, z, width, depth (`mask_rect` in the shaders).
var rect: Rect2 = Rect2()
var image: Image


## Paints the mask over `bounds` from `footprints` (each deck's triangles, in
## threes) and the lanterns' `lamps` (their flames, in land space).
func build(bounds: Rect2, footprints: Array, lamps: PackedVector3Array) -> void:
	rect = bounds.grow(MARGIN)
	var data: PackedByteArray = PackedByteArray()
	data.resize(WIDTH * HEIGHT * 3)
	data.fill(0)
	var texel: Vector2 = rect.size / Vector2(WIDTH, HEIGHT)
	for faces: PackedVector3Array in footprints:
		_footprint(data, faces, texel)
	for lamp: Vector3 in lamps:
		_lamp(data, lamp, texel)
	image = Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_RGB8, data)


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)


## Sets the mask on `material` (a masonry or water material).
func bind(material: Material, mask: Texture2D) -> void:
	if material is ShaderMaterial:
		var shaded: ShaderMaterial = material
		shaded.set_shader_parameter("city_mask", mask)
		shaded.set_shader_parameter("mask_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


func _footprint(data: PackedByteArray, faces: PackedVector3Array, texel: Vector2) -> void:
	for i: int in range(0, faces.size() - 2, 3):
		var a: Vector2 = Vector2(faces[i].x, faces[i].z)
		var b: Vector2 = Vector2(faces[i + 1].x, faces[i + 1].z)
		var c: Vector2 = Vector2(faces[i + 2].x, faces[i + 2].z)
		var low: Vector2 = (a.min(b).min(c) - rect.position) / texel
		var high: Vector2 = (a.max(b).max(c) - rect.position) / texel
		for row: int in range(maxi(0, floori(low.y)), mini(HEIGHT - 1, ceili(high.y)) + 1):
			for column: int in range(maxi(0, floori(low.x)), mini(WIDTH - 1, ceili(high.x)) + 1):
				var index: int = (row * WIDTH + column) * 3
				if data[index] == 255:
					continue
				var covered: int = 0
				for sample: Vector2 in SAMPLES:
					var at: Vector2 = rect.position + (Vector2(column, row) + sample) * texel
					if Geometry2D.point_is_inside_triangle(at, a, b, c):
						covered += 1
				# A texel's quarters may be covered by different triangles.
				data[index] = mini(255, data[index] + covered * 64)


func _lamp(data: PackedByteArray, lamp: Vector3, texel: Vector2) -> void:
	var reach: float = maxf(POOL_RADIUS, COLUMN_LENGTH)
	var low: Vector2 = (Vector2(lamp.x, lamp.z) - Vector2(reach, reach) - rect.position) / texel
	var high: Vector2 = (Vector2(lamp.x, lamp.z) + Vector2(reach, reach) - rect.position) / texel
	for row: int in range(maxi(0, floori(low.y)), mini(HEIGHT - 1, ceili(high.y)) + 1):
		for column: int in range(maxi(0, floori(low.x)), mini(WIDTH - 1, ceili(high.x)) + 1):
			var at: Vector2 = rect.position + (Vector2(column, row) + Vector2(.5, .5)) * texel
			var offset: Vector2 = at - Vector2(lamp.x, lamp.z)
			var pool: float = exp(-offset.length_squared() / (POOL_RADIUS * POOL_RADIUS * .35))
			_raise(data, column, row, 1, pool)
			# The reflection runs from the lantern's foot toward the camera (+z),
			# fading with distance.
			var along: float = offset.y
			var column_light: float = exp(-pow(offset.x / COLUMN_WIDTH, 2.0)) \
				* smoothstep(-.4, .2, along) * (1.0 - smoothstep(.4, COLUMN_LENGTH, along))
			_raise(data, column, row, 2, column_light)


static func _raise(data: PackedByteArray, column: int, row: int, channel: int, value: float) -> void:
	var index: int = (row * WIDTH + column) * 3 + channel
	data[index] = maxi(data[index], clampi(roundi(value * 255.0), 0, 255))
