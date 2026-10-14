extends RefCounted
## Continuous masonry along a deck's exposed edges: the outer course, the arch
## stones over each opening and the parapets (`pointed_parapets.gd`). The
## archive's `stone_bridge/edges.gd`: it reads surface queries, never chapter
## ids or game state, and leaves out every stretch where a rail would stand in
## another route's way (a shared join, a branch, a crossing route).
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Outline = preload("res://presentation/map/causeway/outline.gd")
const Parapets = preload("res://presentation/map/causeway/pointed_parapets.gd")
const BoxBatch = preload("res://presentation/map/causeway/box_batch.gd")
var blocks: SurfaceTool
var caps: SurfaceTool
var arch_stones: SurfaceTool
var stone_batch: BoxBatch
## Each deck's answers already asked for, by position: neighbouring stones ask
## at the same points (a piece's end is the next one's start).
var _asked: Dictionary = {}


## The masonry of `field`'s deck, whose triangles are `faces`; `other_fields`
## are every deck (this one included). Returns the meshes it drew under
## `parent`: the body, the coping and the arch stones.
func build(parent: Node3D, faces: PackedVector3Array, field: RefCounted,
		other_fields: Array, stone: Material, trim: Material, settings: Dictionary) -> Array[ArrayMesh]:
	blocks = SurfaceTool.new()
	caps = SurfaceTool.new()
	arch_stones = SurfaceTool.new()
	for surface: SurfaceTool in [blocks, caps, arch_stones]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone_batch = BoxBatch.new(arch_stones)
	var count: int = 0
	var accepted: Array[Dictionary] = []
	var boundary: Array[Dictionary] = []
	for edge: Dictionary in Outline.segments(faces):
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		var divisions: int = maxi(1, ceili(a.distance_to(b) / .20))
		for i: int in range(divisions):
			boundary.append({"a": a.lerp(b, float(i) / divisions), "b": a.lerp(b, float(i + 1) / divisions)})
	var openings: Array = settings.get("openings", [])
	var rail_width: float = settings["parapet_width"]
	for edge: Dictionary in boundary:
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		if a.distance_to(b) < .002:
			continue
		var at: Vector3 = (a + b) * .5
		var outward: Vector3 = Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		var left: float = _field(field, Vector2(at.x + outward.x * .1, at.z + outward.z * .1))["distance"]
		var right: float = _field(field, Vector2(at.x - outward.x * .1, at.z - outward.z * .1))["distance"]
		# A triangulation seam is not an exposed deck boundary.
		if left < -.03 and right < -.03:
			continue
		if left < right:
			outward = -outward
		var shared_join: bool = false
		for opening: Vector3 in openings:
			shared_join = shared_join or (Vector2(at.x - opening.x, at.z - opening.z).length() < 1.6
				and absf(at.y - opening.y) < .25)
		# The full coping must fit in the gap between branches. A valid deck
		# outline alone can surround a notch narrower than the rail itself.
		var outer: float = .14 + (rail_width + .12) * .5
		for endpoint: Vector3 in [a, at, b]:
			var probe_at: Vector3 = endpoint + outward * outer
			var own: Dictionary = _field(field, Vector2(probe_at.x, probe_at.z))
			var own_distance: float = own["distance"]
			var own_height: float = own["height"]
			shared_join = shared_join or (own_distance < -.025
				and _rail_obstructs(own_height, endpoint.y, settings))
		for other: RefCounted in other_fields:
			if other == field:
				continue
			for endpoint: Vector3 in [a, at, b]:
				var query: Dictionary = _field(other, Vector2(endpoint.x + outward.x * .08, endpoint.z + outward.z * .08))
				var distance: float = query["distance"]
				var height: float = query["height"]
				shared_join = shared_join or (distance <= .20
					and _rail_obstructs(height, endpoint.y, settings))
		if shared_join:
			continue
		accepted.append({"a": a, "b": b, "outward": outward})
		_piece(a, b, outward * .04 - Vector3.UP * (COURSE_DROP - .08), .34, .16)
		_arch_band(a, b, outward, field, other_fields, settings)
		count += 1
	Parapets.new().build(accepted, blocks, caps, other_fields, settings)
	var result: Array[ArrayMesh] = []
	if count > 0:
		for surface: SurfaceTool in [blocks, caps, arch_stones]:
			var finished: ArrayMesh = Meshes.finish(surface)
			result.append(finished)
			Meshes.node(parent, finished, stone if surface == blocks else trim, "Causeway edge masonry")
	return result


func _arch_band(a: Vector3, b: Vector3, outward: Vector3, field: RefCounted,
		other_fields: Array, settings: Dictionary) -> void:
	# The deck outline can be straight above an entire arch. Sample the
	# intrados separately; joining only deck endpoints draws a false diagonal.
	var floor_level: float = settings["arch_floor"]
	var divisions: int = maxi(1, ceili(a.distance_to(b) / .20))
	for i: int in range(divisions):
		var pa: Vector3 = a.lerp(b, float(i) / divisions)
		var pb: Vector3 = a.lerp(b, float(i + 1) / divisions)
		var low_a: float = _field(field, Vector2(pa.x, pa.z))["bottom"]
		var low_b: float = _field(field, Vector2(pb.x, pb.z))["bottom"]
		if minf(low_a, low_b) <= floor_level or absf(low_a - low_b) > .65:
			continue
		# Voussoirs project beyond the structural underside. Keep their full
		# width clear of a neighbouring rising route, including before crossings.
		var obstructs: bool = false
		for endpoint: Vector3 in [pa, (pa + pb) * .5, pb]:
			for offset: float in [-.075, .04, .155]:
				var at: Vector3 = endpoint + outward * offset
				for other: RefCounted in other_fields:
					if other == field:
						continue
					var query: Dictionary = _field(other, Vector2(at.x, at.z))
					var floor_height: float = query["height"]
					var distance: float = query["distance"]
					obstructs = obstructs or (distance <= .025
						and minf(low_a, low_b) - .01 < floor_height + 2.45
						and maxf(low_a, low_b) + .25 > floor_height + .04)
		if obstructs:
			continue
		pa.y = low_a + .12
		pb.y = low_b + .12
		_piece(pa, pb, outward * .04, .23, .26, -.012)


## `deck`'s answer at `at`, asked once.
func _field(deck: RefCounted, at: Vector2) -> Dictionary:
	if not _asked.has(deck):
		_asked[deck] = {}
	var answers: Dictionary = _asked[deck]
	if not answers.has(at):
		answers[at] = deck.field(at)
	return answers[at]


func _piece(a: Vector3, b: Vector3, offset: Vector3, width: float, height: float, overlap: float = .008) -> void:
	var delta: Vector3 = b - a
	var run: float = maxf(.002, Vector2(delta.x, delta.z).length())
	var side: Vector3 = delta.cross(Vector3.UP).normalized()
	# Vertical sections shear with the slope: tilted boxes used to produce
	# a serrated coping silhouette where their rotated ends overlapped.
	var basis: Basis = Basis(side, Vector3.UP, -delta / run)
	stone_batch.append(Transform3D(basis.scaled_local(Vector3(width, height, maxf(.002, run + overlap))), (a + b) * .5 + offset))


## A rising route can cross a lower rail before reaching equal deck height.
## Test the edge masonry's full vertical extent, from the course under the
## deck (`COURSE_DROP`) to the parapet's coping, against that route's walking
## body, standing on a tread up to `TREAD_RISE` over that route's fitted
## surface. The archive tested from the deck up and from the surface: its
## crossings stood 4 m apart, where neither reached a body; the fast layout's
## short raised roads pass closer.
const COURSE_DROP: float = .24
const TREAD_RISE: float = .19
static func _rail_obstructs(other_height: float, deck_height: float, settings: Dictionary) -> bool:
	var wall: float = settings["parapet_height"]
	return other_height < deck_height + wall + .23 \
		and other_height + TREAD_RISE + 2.12 > deck_height - COURSE_DROP
