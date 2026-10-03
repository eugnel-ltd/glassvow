extends RefCounted
## Reads the production layout record (MapLayoutFast's `identity_dict`) into the
## journey landscape's source. The record is never edited: this is a copy for
## drawing only.
##
## Two adaptations, both on the copy:
##
## - **Centrelines.** MapLayoutFast routes each road as a cubic sampled every
##   2 m or less. The journey landscape grew up on long straight legs; its
##   gateway chooser needs a straight dry leg of 3 m and every road query scans
##   each leg. A Ramer–Douglas–Peucker pass at `TOLERANCE_M` keeps every road
##   within 12 cm of the record (a deck's height counts four times, so ramps
##   keep their shape) and leaves seed 1 with about a third of the points.
## - **Heroes.** The record's protected zones hold the Vigil and the act's gate,
##   which have no journey model yet. Each is dressed with a journey landmark
##   standing at the zone's own origin, inside the zone the layout reserved.

const TOLERANCE_M: float = 0.12
const HEIGHT_WEIGHT: float = 4.0
const HERO_KIT: Dictionary = {
	"vigil": {"asset_id": "memorial", "scale": 1.3},
	"terminus": {"asset_id": "memorial", "scale": 1.6},
}


static func from_layout(data: Dictionary) -> Dictionary:
	var raw_anchors: Dictionary = data["node_anchors"]
	var anchors: Dictionary = raw_anchors.duplicate(true)
	var edges: Dictionary = {}
	var raw_edges: Dictionary = data["edges"]
	for id: String in MapLayoutCanonical.sorted_keys(raw_edges):
		var raw_edge: Dictionary = raw_edges[id]
		var edge: Dictionary = raw_edge.duplicate(true)
		var line: Array = edge["centerline"]
		edge["centerline"] = simplify(line)
		edges[id] = edge
	var heroes: Dictionary = {}
	var placements: Dictionary = data.get("hero_placements", {})
	for role: String in MapLayoutCanonical.sorted_keys(placements):
		if not HERO_KIT.has(role):
			continue
		var placement: Dictionary = placements[role]
		var kit: Dictionary = HERO_KIT[role]
		var size: float = kit["scale"]
		var pose: Dictionary = placement["transform"]
		var origin: Array = pose["origin"]
		heroes[role] = {"asset_id": kit["asset_id"], "transform": {
			"origin": origin.duplicate(), "scale": [size, size, size],
			"yaw_radians": MapLayoutCanonical.float_value(pose["yaw_radians"])}}
	return {"anchors": anchors, "edges": edges, "heroes": heroes}


## The record's points `[x, y, z]`, simplified; both ends are always kept.
static func simplify(points: Array) -> Array:
	if points.size() < 3:
		return points.duplicate(true)
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var spans: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not spans.is_empty():
		var span: Vector2i = spans.pop_back()
		var a: Vector3 = MapLandscape.v3(points[span.x])
		var b: Vector3 = MapLandscape.v3(points[span.y])
		var worst: int = -1
		var worst_d: float = TOLERANCE_M
		for i: int in range(span.x + 1, span.y):
			var d: float = _deviation(MapLandscape.v3(points[i]), a, b)
			if d > worst_d:
				worst = i
				worst_d = d
		if worst >= 0:
			keep[worst] = 1
			spans.append(Vector2i(span.x, worst))
			spans.append(Vector2i(worst, span.y))
	var out: Array = []
	for i: int in range(points.size()):
		if keep[i] == 1:
			var point: Array = points[i]
			out.append(point.duplicate())
	return out


static func _deviation(p: Vector3, a: Vector3, b: Vector3) -> float:
	var flat_a: Vector2 = Vector2(a.x, a.z)
	var flat_b: Vector2 = Vector2(b.x, b.z)
	var flat_p: Vector2 = Vector2(p.x, p.z)
	var along: Vector2 = flat_b - flat_a
	var length_sq: float = along.length_squared()
	var t: float = 0.0 if length_sq <= 0.0 else clampf((flat_p - flat_a).dot(along) / length_sq, 0.0, 1.0)
	var across: float = flat_p.distance_to(flat_a + along * t)
	return across + absf(p.y - lerpf(a.y, b.y, t)) * HEIGHT_WEIGHT
