class_name MapLandscape
extends RefCounted
## One bounded, route-derived terrain field. Built on layout changes, never on pan.
## R: distance to the road, G: regional mass, B: fine variation, A: contact.

const SIZE: Vector2i = Vector2i(512, 384)
const MIN: Vector2 = Vector2(-64.0, -48.0)
const EXTENT: Vector2 = Vector2(128.0, 96.0)
const REACH: float = 12.0
const METRES_PER_PIXEL: float = 0.25

static func bake(segments: PackedVector3Array, contacts: Array[Vector3],
		seed_value: int) -> Image:
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(SIZE.x * SIZE.y)
	distances.fill(REACH)
	for i: int in range(0, segments.size() - 1, 2):
		_stamp_distance(distances, Vector2(segments[i].x, segments[i].z),
			Vector2(segments[i + 1].x, segments[i + 1].z))
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.085
	noise.fractal_octaves = 3
	var image: Image = Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			var world: Vector2 = MIN + (Vector2(x, y) + Vector2.ONE * 0.5) * METRES_PER_PIXEL
			var broad: float = noise.get_noise_2d(world.x, world.y) * 0.5 + 0.5
			var fine: float = noise.get_noise_2d(world.x * 4.3, world.y * 4.3) * 0.5 + 0.5
			image.set_pixel(x, y, Color(distances[y * SIZE.x + x] / REACH, broad, fine, 1.0))
	# Only accepted, actually rendered scenery casts contact; rejected seats
	# cannot leave the old detached circular shadows behind.
	for contact: Vector3 in contacts:
		var centre: Vector2 = (Vector2(contact.x, contact.z) - MIN) / METRES_PER_PIXEL
		var radius: float = maxf(contact.y, 0.4) / METRES_PER_PIXEL
		for y: int in range(maxi(0, floori(centre.y - radius)), mini(SIZE.y, ceili(centre.y + radius))):
			for x: int in range(maxi(0, floori(centre.x - radius)), mini(SIZE.x, ceili(centre.x + radius))):
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(centre) / radius
				var colour: Color = image.get_pixel(x, y)
				colour.a = minf(colour.a, lerpf(0.45, 1.0, smoothstep(0.0, 1.0, d)))
				image.set_pixel(x, y, colour)
	return image

static func _stamp_distance(distances: PackedFloat32Array, a: Vector2, b: Vector2) -> void:
	var lo: Vector2i = Vector2i(((a.min(b) - Vector2.ONE * REACH - MIN) / METRES_PER_PIXEL).floor())
	var hi: Vector2i = Vector2i(((a.max(b) + Vector2.ONE * REACH - MIN) / METRES_PER_PIXEL).ceil())
	var delta: Vector2 = b - a
	var length_squared: float = maxf(delta.length_squared(), 0.000001)
	for y: int in range(maxi(0, lo.y), mini(SIZE.y, hi.y + 1)):
		for x: int in range(maxi(0, lo.x), mini(SIZE.x, hi.x + 1)):
			var p: Vector2 = MIN + (Vector2(x, y) + Vector2.ONE * 0.5) * METRES_PER_PIXEL
			var t: float = clampf((p - a).dot(delta) / length_squared, 0.0, 1.0)
			var index: int = y * SIZE.x + x
			distances[index] = minf(distances[index], p.distance_to(a + delta * t))
