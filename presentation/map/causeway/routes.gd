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
const RaisedProfiles = preload("res://presentation/map/causeway/raised_profiles.gd")
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
## Each deck's masonry under it (its arches' intrados and walls), and each
## deck's paving alone, by field (`fields`).
var underside_meshes: Array[ArrayMesh] = []
var level_decks: Array[ArrayMesh] = []
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
	var profiles: RaisedProfiles = RaisedProfiles.new()
	profiles.plan(edges, lines, spacing, levels, style)
	levels.setup(lines)
	var raw_anchors: Dictionary = sample["anchors"]
	for key: String in raw_anchors:
		var raw: Array = raw_anchors[key]
		var p: Vector3 = Meshes.v3(raw)
		p.y = levels.height(p.x, p.z) + .022
		anchors[key] = p
	var lower: Array[Dictionary] = []
	var upper: Array[Dictionary] = []
	var graded: Dictionary = {}
	var ordinary: Array[PackedVector3Array] = []
	var index: int = 0
	for key: String in edges:
		var line: PackedVector3Array = lines[index]
		index += 1
		if profiles.raised.has(key):
			continue
		var points: PackedVector3Array = Paths.sample(line, spacing)
		for i: int in range(points.size()):
			points[i].y = levels.height(points[i].x, points[i].z)
		graded[key] = points
		ordinary.append(Paths.sample(line, RaisedProfiles.STEP))
	profiles.lift(ordinary)
	for key: String in edges:
		var source_edge: Dictionary = edges[key]
		var raised: bool = profiles.raised.has(key)
		var points: PackedVector3Array = profiles.raised[key].points if raised else graded[key]
		var lengths: PackedFloat32Array = RaisedProfiles._stations(points)
		anchors[source_edge["from"]] = points[0] + Vector3.UP * .022
		anchors[source_edge["to"]] = points[-1] + Vector3.UP * .022
		sampled_routes[key] = points
		for i: int in range(points.size() - 1):
			var span: Dictionary = {"edge": key, "from": source_edge["from"], "to": source_edge["to"],
				"a": points[i], "b": points[i + 1], "wa": 1.0, "wb": 1.0,
				"half_a": RaisedProfiles.half_width(lengths[i], lengths[-1]), "half_b": RaisedProfiles.half_width(lengths[i + 1], lengths[-1]),
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
			landing.routes_apart = true
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
	level_decks.append(deck)
	Meshes.node(self, deck, paving, "Causeway deck")
	var under: ArrayMesh = Meshes.finish(sides)
	underside_meshes.append(under)
	Meshes.node(self, under, stone, "Causeway arches")


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
