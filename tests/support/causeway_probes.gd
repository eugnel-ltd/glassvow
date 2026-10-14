extends RefCounted
@warning_ignore_start("unsafe_call_argument")
## The archive's Act II geometry probes (`tools/map_workshop/act2/deck_audit.gd`,
## `bridge_walkway_audit.gd`, `common/mesh_probe.gd`; 7d64678b), ported to read
## the causeways the land actually drew (`presentation/map/causeway/routes.gd`).
## Both sample every route's walking line every 0.2 m against the rendered
## triangles, never the surface queries that built them.

## Vertical samples against a mesh's triangles, indexed in one-metre cells.
class MeshProbe extends RefCounted:
	var cells: Dictionary = {}

	func build(mesh: Mesh) -> void:
		var faces: PackedVector3Array = mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i + 1]
			var c: Vector3 = faces[i + 2]
			if absf(Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z))) < .0000001:
				continue
			var lo: Vector2 = Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var hi: Vector2 = Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			var triangle: Array[Vector3] = [a, b, c]
			for x: int in range(floori(lo.x), floori(hi.x) + 1):
				for z: int in range(floori(lo.y), floori(hi.y) + 1):
					var key: Vector2i = Vector2i(x, z)
					if not cells.has(key):
						cells[key] = []
					cells[key].append(triangle)

	func heights(at: Vector2) -> PackedFloat32Array:
		var result: PackedFloat32Array = []
		for triangle: Array[Vector3] in cells.get(Vector2i(floori(at.x), floori(at.y)), []):
			var a: Vector3 = triangle[0]
			var b: Vector3 = triangle[1]
			var c: Vector3 = triangle[2]
			var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
			var ac: Vector2 = Vector2(c.x - a.x, c.z - a.z)
			var delta: Vector2 = at - Vector2(a.x, a.z)
			var denominator: float = ab.cross(ac)
			var u: float = delta.cross(ac) / denominator
			var v: float = ab.cross(delta) / denominator
			if u >= -.00001 and v >= -.00001 and u + v <= 1.00001:
				result.append(a.y * (1 - u - v) + b.y * u + c.y * v)
		return result


## A route's line at the probes' fixed density.
static func stations(source: PackedVector3Array, spacing: float = .2) -> PackedVector3Array:
	if source.is_empty():
		return PackedVector3Array()
	var result: PackedVector3Array = [source[0]]
	for i: int in range(1, source.size()):
		var count: int = maxi(1, ceili(source[i - 1].distance_to(source[i]) / spacing))
		for station: int in range(1, count + 1):
			result.append(source[i - 1].lerp(source[i], float(station) / count))
	return result


static func _probes(meshes: Array[ArrayMesh]) -> Array[MeshProbe]:
	var out: Array[MeshProbe] = []
	for mesh: ArrayMesh in meshes:
		var probe: MeshProbe = MeshProbe.new()
		probe.build(mesh)
		out.append(probe)
	return out


## Deck coverage: every route sample, at seven offsets across 1.2 m, finds a
## rendered deck triangle under it. Returns the sample and miss counts, the
## first misses and the greatest height difference from the route.
static func deck_coverage(routes: Node3D) -> Dictionary:
	var decks: Array[MeshProbe] = _probes(routes.deck_meshes)
	var samples: int = 0
	var missing: int = 0
	var worst: float = 0.0
	var failures: Array = []
	var sampled: Dictionary = routes.sampled_routes
	for key: String in sampled:
		var points: PackedVector3Array = stations(sampled[key])
		for i: int in range(points.size()):
			var p: Vector3 = points[i]
			var forward: Vector3 = points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
			var side: Vector2 = Vector2(-forward.z, forward.x).normalized()
			for lateral: int in range(-3, 4):
				var at: Vector2 = Vector2(p.x, p.z) + side * lateral * .2
				var found: PackedFloat32Array = PackedFloat32Array()
				for probe: MeshProbe in decks:
					found.append_array(probe.heights(at))
				samples += 1
				if found.is_empty():
					missing += 1
					if failures.size() < 8:
						failures.append([key, at])
					continue
				var error: float = INF
				for height: float in found:
					error = minf(error, absf(height - p.y - .022))
				worst = maxf(worst, error)
	return {"samples": samples, "missing": missing, "first_failures": failures, "worst_height": worst}


## Obstruction: no added masonry (edges, parapets, piers) stands in a walking
## body 2.12 m tall over the rendered deck, at five offsets across a 1.5 m
## corridor of every route. Returns the sample and hit counts and the first hits.
static func obstruction(routes: Node3D) -> Dictionary:
	var obstacles: Array[MeshProbe] = _probes(routes.decoration_meshes)
	var floors: Array[MeshProbe] = _probes(routes.deck_meshes)
	var tested: int = 0
	var hits: int = 0
	var examples: Array = []
	var sampled: Dictionary = routes.sampled_routes
	for key: String in sampled:
		var points: PackedVector3Array = stations(sampled[key])
		for i: int in range(points.size()):
			var point: Vector3 = points[i]
			var delta: Vector3 = points[mini(i + 1, points.size() - 1)] - points[maxi(0, i - 1)]
			var side: Vector2 = Vector2(-delta.z, delta.x).normalized()
			for offset: float in [-.75, -.5, 0.0, .5, .75]:
				var at: Vector2 = Vector2(point.x, point.z) + side * offset
				var floor_height: float = point.y + .022
				for probe: MeshProbe in floors:
					for height: float in probe.heights(at):
						if absf(height - point.y) < .4:
							floor_height = maxf(floor_height, height)
				tested += 1
				var part: int = -1
				var obstacle: float = 0.0
				for index: int in range(obstacles.size()):
					for height: float in obstacles[index].heights(at):
						if height > floor_height + .04 and height < floor_height + 2.12:
							part = index
							obstacle = height
							break
					if part >= 0:
						break
				if part >= 0:
					hits += 1
					if examples.size() < 8:
						examples.append([key, at, floor_height, part, obstacle])
	return {"samples": tested, "hits": hits, "examples": examples}
