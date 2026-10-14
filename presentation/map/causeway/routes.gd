extends Node3D
## Every route of the record as fitted masonry: a paved deck on piers and
## arches, its edge masonry and parapets, its flights of steps and its pier
## buttresses. Ordinary and raised decks stay separate surfaces, so a raised
## road passes over an ordinary one. The archive's `common/fitted_routes.gd`
## (7d64678b) on the fast layout's record, without its ruin approaches (II.4)
## or its study's height profiles.
##
## Builds only its own subtree and reads nothing back from the renderer, so it
## runs on a worker with the land outside the tree.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Paths = preload("res://presentation/map/landscape/road_paths.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
const Levels = preload("res://presentation/map/causeway/levels.gd")
const Profile = preload("res://presentation/map/causeway/arch_profile.gd")
const Smooth = preload("res://presentation/map/causeway/smooth_surfaces.gd")
const Landing = preload("res://presentation/map/causeway/landing_surfaces.gd")
const FlightGrade = preload("res://presentation/map/causeway/flight_grade.gd")
const Edges = preload("res://presentation/map/causeway/edges.gd")
const Stairs = preload("res://presentation/map/causeway/stairs.gd")
const Piers = preload("res://presentation/map/causeway/piers.gd")
## A raised road keeps a level landing this long at each end, its
## bridgehead's (`Levels.HEAD_LANDING`), before it climbs.
const LANDING: float = Levels.HEAD_LANDING
## A raised road climbs from its bridgeheads at this grade (a flight's steepest
## is 0.52) to at most `RAISED_RISE` over them, easing into it over its last
## `EASE`.
const RAISED_GRADE: float = .52
const RAISED_RISE: float = 2.2
const EASE: float = .25

var levels: Levels = Levels.new()
var style: Dictionary = Presets.drowned_city()
## A build given up ends at its next stage (`Meshes.Pacing.stopped`).
var pacing: Meshes.Pacing = null
var failure: String = ""
## The record's centrelines, its node anchors seated on the decks, and each
## route's sampled walking line, by edge id.
var lines: Array[PackedVector3Array] = []
var anchors: Dictionary = {}
var sampled_routes: Dictionary = {}
## The deck surfaces (ordinary, then raised) and what was drawn from them: the
## decks and their treads (walked on), and the added masonry (never walked).
var fields: Array[Smooth] = []
var deck_meshes: Array[ArrayMesh] = []
var decoration_meshes: Array[ArrayMesh] = []
var build_timings_ms: Dictionary = {}
var _stage_started: int = 0
## Each deck's triangles as built, held only until its edges are drawn.
var _deck_faces: Array[PackedVector3Array] = []


func build(sample: Dictionary) -> void:
	_stage_started = Time.get_ticks_msec()
	var materials: Dictionary = Presets.materials(style)
	var stone: Material = materials["body"]
	var trim: Material = materials["trim"]
	var paving: Material = materials["deck"]
	var edges: Dictionary = sample["edges"]
	var spacing: float = style["sample_spacing"]
	for edge: Dictionary in edges.values():
		var line: PackedVector3Array = []
		for value: Array in edge["centerline"]:
			line.append(Meshes.v3(value))
		lines.append(line)
	levels.setup(lines)
	var raw_anchors: Dictionary = sample["anchors"]
	for key: String in raw_anchors:
		var raw: Array = raw_anchors[key]
		var p: Vector3 = Meshes.v3(raw)
		p.y = levels.height(p.x, p.z) + .022
		anchors[key] = p
	var lower: Array[Dictionary] = []
	var upper: Array[Dictionary] = []
	var index: int = 0
	for key: String in edges:
		var source_edge: Dictionary = edges[key]
		var line: PackedVector3Array = lines[index]
		index += 1
		var raised: bool = false
		for p: Vector3 in line:
			raised = raised or p.y > .3
		var points: PackedVector3Array = Paths.sample(line, spacing)
		var lengths: PackedFloat32Array = [0]
		for i: int in range(1, points.size()):
			lengths.append(lengths[-1] + Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length())
		for i: int in range(points.size()):
			points[i].y = levels.deck_base(points[i].x, points[i].z) + Levels.BRIDGEHEAD \
				+ _rise(lengths[i], lengths[-1]) if raised else levels.height(points[i].x, points[i].z)
		anchors[source_edge["from"]] = points[0] + Vector3.UP * .022
		anchors[source_edge["to"]] = points[-1] + Vector3.UP * .022
		sampled_routes[key] = points
		for i: int in range(points.size() - 1):
			var span: Dictionary = {"edge": key, "from": source_edge["from"], "to": source_edge["to"],
				"a": points[i], "b": points[i + 1], "wa": 1.0, "wb": 1.0,
				"half_a": _half(lengths[i], lengths[-1]), "half_b": _half(lengths[i + 1], lengths[-1]),
				"s": lengths[i],
				"bottom_a": Profile.soffit(points[i].y, lengths[i], lengths[-1], raised, style),
				"bottom_b": Profile.soffit(points[i + 1].y, lengths[i + 1], lengths[-1], raised, style)}
			if raised:
				upper.append(span)
			else:
				lower.append(span)
	_mark("route_profiles")
	if _stopped():
		return
	var openings: Array = anchors.values()
	for cut: Dictionary in levels.cuts:
		var at: Vector2 = cut["at"]
		openings.append(Vector3(at.x, 0, at.y))
	var bed: float = style["bed"]
	for spans: Array[Dictionary] in [lower, upper]:
		if spans.is_empty():
			continue
		var field: Smooth = Smooth.new()
		if spans == upper and not fields.is_empty():
			var landing: Landing = Landing.new()
			landing.lower = fields[0]
			landing.pads = levels.abutments
			field = landing
		field.setup(spans, func(_x: float, _z: float) -> float: return bed)
		var grading: FlightGrade = FlightGrade.new()
		grading.prepare(field, {"openings": openings})
		field.stair_profile = grading
		fields.append(field)
		_deck(field, paving, stone)
		_mark("deck_%d" % (fields.size() - 1))
		if _stopped():
			return
	var settings: Dictionary = style.duplicate()
	settings["openings"] = []
	for i: int in range(fields.size()):
		decoration_meshes.append_array(Edges.new().build(self, _deck_faces[i], fields[i], fields,
			stone, trim, settings))
		_mark("edges_%d" % i)
		if _stopped():
			return
	var tread_settings: Dictionary = {"openings": openings, "tread_width": style["tread_width"]}
	for field: Smooth in fields:
		var treads: ArrayMesh = Stairs.new().build(self, field, trim, tread_settings)
		if treads != null:
			deck_meshes.append(treads)
	_deck_faces.clear()
	_mark("stairs")
	if _stopped():
		return
	decoration_meshes.append_array(Piers.build(self, fields, stone, trim, settings))
	_mark("piers")


## How far a raised road stands over the datum `station` metres along a route
## `total` long: level at its landings, then climbing at `RAISED_GRADE` (the
## archive's soft start) and easing into `RAISED_RISE`.
static func _rise(station: float, total: float) -> float:
	var run: float = maxf(0, minf(station, total - station) - LANDING)
	var rise: float = RAISED_GRADE * (run - .15 * (1.0 - exp(-run / .15)))
	var knee: float = RAISED_RISE - EASE
	if rise > knee:
		var ease: float = clampf((rise - knee) / (2.0 * EASE), 0, 1)
		rise = knee + EASE * ease * (2 - ease)
	return rise


## A deck's half width: 0.92 m, widening to 1.29 m into each node's landing.
static func _half(station: float, total: float) -> float:
	return .92 + .37 * (1 - smoothstep(.4, 1.5, minf(station, total - station)))


## Meshes `field`'s deck (paving) and the masonry under it (body). The deck's
## arrays are kept as built, so its outline is read without asking the renderer.
func _deck(field: Smooth, paving: Material, stone: Material) -> void:
	var top: SurfaceTool = SurfaceTool.new()
	var sides: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	field.append(top, sides)
	top.generate_normals()
	var deck: ArrayMesh = ArrayMesh.new()
	var arrays: Array = top.commit_to_arrays()
	deck.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_deck_faces.append(_unindexed(arrays))
	deck_meshes.append(Meshes.committed(deck))
	Meshes.node(self, deck, paving, "Causeway deck")
	Meshes.node(self, Meshes.finish(sides), stone, "Causeway arches")


static func _unindexed(arrays: Array) -> PackedVector3Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var held: Variant = arrays[Mesh.ARRAY_INDEX]
	if not held is PackedInt32Array:
		return vertices
	var indices: PackedInt32Array = held
	if indices.is_empty():
		return vertices
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in indices:
		faces.append(vertices[i])
	return faces


func _stopped() -> bool:
	if pacing == null or not pacing.stopped:
		return false
	failure = "Stopped"
	return true


func _mark(stage: String) -> void:
	var now: int = Time.get_ticks_msec()
	build_timings_ms[stage] = now - _stage_started
	_stage_started = now
