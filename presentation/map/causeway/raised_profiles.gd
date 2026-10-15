extends RefCounted
## The raised roads' heights, fitted to the ordinary roads round them so that
## the pilgrim always has a walking body (2.12 m) over his head (#660 II.3,
## the junction-headroom probe of II.2's review).
##
## - **Junctions.** A raised road keeps level with its bridgehead's pad until
##   it has left every ordinary road that shares the pad (`landing`), and those
##   roads stay level with the pad as far (`Landform.pad_landings`): where the
##   two decks overlap in plan they are one landing, never a ramp hanging over
##   a road.
## - **Crossings.** An ordinary road under a raised one is graded no higher
##   than a walking body under its arch (`ceiling`), down to the water's dry
##   margin; where that is not low enough the raised road climbs higher
##   (`lift`), at no more than its grade.
const Paths = preload("res://presentation/map/landscape/road_paths.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
const Levels = preload("res://presentation/map/causeway/levels.gd")
const Profile = preload("res://presentation/map/causeway/arch_profile.gd")
## The walking body every deck keeps clear over a walker.
const HEADROOM: float = 2.12
## Kept over `HEADROOM` against the fitted decks' blending.
const SPARE: float = .15
## How far past a raised deck's edge a road still counts as under it, when
## its landing and the ceiling over the ordinary roads are planned: the deck's
## walls and the walking line's turn round a waystone. A lift answers only for
## what stands under the deck and its walls (`LIFT_REACH`); its edge masonry
## keeps clear of the walking corridors by its own rule (`edges.gd`).
const REACH: float = .35
const LIFT_REACH: float = .3
## The lowest an ordinary road may pass: the archive's 0.58 m dry margin over
## the water.
const DRY_FLOOR: float = Presets.WATER + .58
## A raised road climbs at this grade (a flight's steepest is 0.52) to at most
## `RISE` over its landings, easing into it over its last `EASE`.
const GRADE: float = .52
## Where a lift must climb faster than `GRADE` from a landing, it may climb at
## this (a short, steep flight), rather than leave a step at the landing.
const LIFT_GRADE: float = .7
const RISE: float = 2.2
const EASE: float = .25
## The scan's step along the roads.
const STEP: float = .2
## Half a raised road's sample spacing: a lift's cone stands this much of its
## grade over the station it answers for.
const SAMPLE_SLACK: float = .4


## One raised road: its sampled line (heights set by `heights`), stations and
## its landing lengths at its start and end.
class Raised extends RefCounted:
	var key: String = ""
	var points: PackedVector3Array = []
	var stations: PackedFloat32Array = []
	var total: float = 0.0
	var landing: Vector2 = Vector2.ZERO
	var pads: PackedFloat32Array = []
	## The ordinary roads leaving each end's node, sampled every `STEP`.
	var partners: Array = [[], []]
	## The plan the road and every road under it can stand in.
	var reach: Rect2 = Rect2()

	## The deck's height `station` metres along, between samples.
	func height_at(station: float) -> float:
		for i: int in range(1, stations.size()):
			if station <= stations[i]:
				var t: float = inverse_lerp(stations[i - 1], stations[i], station)
				return lerpf(points[i - 1].y, points[i].y, clampf(t, 0, 1))
		return points[-1].y

	func in_landing(station: float) -> bool:
		return station <= landing.x or total - station <= landing.y


var raised: Dictionary = {}
var _style: Dictionary = {}
var _levels: Levels


## A deck's half width: 0.92 m, widening to 1.29 m into each node's landing.
static func half_width(station: float, total: float) -> float:
	return .92 + .37 * (1 - smoothstep(.4, 1.5, minf(station, total - station)))


## Before the ordinary roads are graded: samples every raised road, finds how
## long each landing must stay level, and gives `levels` its pads' landings and
## the ceiling over its ordinary roads. `edges` and `lines` are the record's,
## in the same order.
func plan(edges: Dictionary, lines: Array[PackedVector3Array], spacing: float, levels: Levels,
		style: Dictionary) -> void:
	_style = style
	_levels = levels
	levels.identify_passages(lines)
	var keys: Array = edges.keys()
	for index: int in range(keys.size()):
		if not _is_raised(lines[index]):
			continue
		var road: Raised = Raised.new()
		road.key = keys[index]
		road.points = Paths.sample(lines[index], spacing)
		road.stations = _stations(road.points)
		road.total = road.stations[-1]
		var low: Vector2 = Vector2(INF, INF)
		var high: Vector2 = -low
		for p: Vector3 in road.points:
			low = low.min(Vector2(p.x, p.z))
			high = high.max(Vector2(p.x, p.z))
		road.reach = Rect2(low, high - low).grow(half_width(0, 1) + maxf(REACH, LIFT_REACH))
		var edge: Dictionary = edges[road.key]
		road.partners = [_partners(road, lines, edges, keys, str(edge["from"])),
			_partners(road, lines, edges, keys, str(edge["to"]))]
		road.landing = Vector2(_landing(road, false), _landing(road, true))
		road.pads = PackedFloat32Array([levels.upland(road.points[0].x, road.points[0].z),
			levels.upland(road.points[-1].x, road.points[-1].z)])
		_heights(road)
		raised[road.key] = road
	levels.landing_floor = landing_floor
	levels.ceiling = ceiling


## The least an ordinary road may be graded at (x, z): its pad's height on a
## road leaving a raised road's node, as far from the pad as that raised road
## stays level (`landing`); -INF elsewhere.
func landing_floor(x: float, z: float) -> float:
	var at: Vector2 = Vector2(x, z)
	var result: float = -INF
	for road: Raised in raised.values():
		for end: int in range(2):
			var pad: Vector3 = road.points[0] if end == 0 else road.points[-1]
			var reach: float = road.landing.x if end == 0 else road.landing.y
			if at.distance_to(Vector2(pad.x, pad.z)) > reach:
				continue
			for line: PackedVector3Array in road.partners[end]:
				if _on_line(line, at):
					result = maxf(result, road.pads[end])
					break
	return result


## The highest an ordinary road may be graded at (x, z): a walking body and
## `SPARE` under every raised arch over it, never below `DRY_FLOOR`; INF where
## no raised road passes over.
func ceiling(x: float, z: float) -> float:
	var at: Vector2 = Vector2(x, z)
	var result: float = INF
	for road: Raised in raised.values():
		if not road.reach.has_point(at):
			continue
		var nearest: Vector2 = _nearest(road, at)
		var station: float = nearest.y
		if road.in_landing(station) or nearest.x > half_width(station, road.total) + REACH:
			continue
		result = minf(result, maxf(DRY_FLOOR, _soffit(road, station) - HEADROOM - SPARE))
	return result


## After the ordinary roads are graded (`lower`: their lines, sampled every
## `STEP`; their graded heights are read from `levels`): where an ordinary road still stands too high under a
## raised one, the raised road climbs to keep the walking body there, its
## samples raised to the cone of its grade round that station (so the deck
## between two samples clears it too), never within a landing.
func lift(lower: Array[PackedVector3Array]) -> void:
	for road: Raised in raised.values():
		var needs: Array[Vector2] = []
		for line: PackedVector3Array in lower:
			for p: Vector3 in line:
				if not road.reach.has_point(Vector2(p.x, p.z)):
					continue
				var nearest: Vector2 = _nearest(road, Vector2(p.x, p.z))
				var station: float = nearest.y
				if road.in_landing(station) or nearest.x > half_width(station, road.total) + LIFT_REACH:
					continue
				var depth: float = road.height_at(station) - _soffit(road, station)
				var needed: float = _levels.height(p.x, p.z) + HEADROOM + SPARE + depth
				if needed > road.height_at(station):
					needs.append(Vector2(station, needed))
		for need: Vector2 in needs:
			for i: int in range(road.points.size()):
				if road.in_landing(road.stations[i]):
					continue
				var cone: float = need.y + LIFT_GRADE * (SAMPLE_SLACK - absf(road.stations[i] - need.x))
				road.points[i].y = maxf(road.points[i].y, cone)
		if not needs.is_empty():
			_ease(road, LIFT_GRADE)


func _is_raised(line: PackedVector3Array) -> bool:
	for p: Vector3 in line:
		if p.y > .3:
			return true
	return false


static func _stations(points: PackedVector3Array) -> PackedFloat32Array:
	var lengths: PackedFloat32Array = [0]
	for i: int in range(1, points.size()):
		lengths.append(lengths[-1] + Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length())
	return lengths


## How far from its `node` end the raised road must stay level: past the last
## station where an ordinary road leaving the same node is still under its
## deck (within its half width and `REACH`), and at least the bridgehead's.
func _landing(road: Raised, from_end: bool) -> float:
	var partners: Array = road.partners[1 if from_end else 0]
	var fine: PackedVector3Array = Paths.sample(road.points, STEP)
	var stations: PackedFloat32Array = _stations(fine)
	var total: float = stations[-1]
	var last: float = 0.0
	for i: int in range(fine.size()):
		var station: float = total - stations[i] if from_end else stations[i]
		if station > total * .5 - .4:
			continue
		var reach: float = half_width(station, total) + REACH
		var here: Vector2 = Vector2(fine[i].x, fine[i].z)
		for line: PackedVector3Array in partners:
			for p: Vector3 in (line as PackedVector3Array):
				if Vector2(p.x, p.z).distance_to(here) < reach:
					last = maxf(last, station)
	return clampf(last + STEP, Levels.HEAD_LANDING, maxf(Levels.HEAD_LANDING, total * .5 - .4))


## The ordinary roads leaving `node`, sampled every `STEP`.
func _partners(road: Raised, lines: Array[PackedVector3Array], edges: Dictionary, keys: Array,
		node: String) -> Array:
	var partners: Array = []
	for index: int in range(keys.size()):
		var edge: Dictionary = edges[keys[index]]
		if keys[index] == road.key or _is_raised(lines[index]):
			continue
		if str(edge["from"]) == node or str(edge["to"]) == node:
			partners.append(Paths.sample(lines[index], STEP))
	return partners


## Whether `at` lies on `line` (within a centimetre).
static func _on_line(line: PackedVector3Array, at: Vector2) -> bool:
	for i: int in range(line.size() - 1):
		var a: Vector2 = Vector2(line[i].x, line[i].z)
		var b: Vector2 = Vector2(line[i + 1].x, line[i + 1].z)
		if Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) < .01:
			return true
	return false


## The road's heights: level with each pad over its landing (the ordinary
## roads leaving the pad stand there too), then climbing at `GRADE` (the
## archive's soft start), easing into `RISE` over the bridgeheads.
func _heights(road: Raised) -> void:
	for i: int in range(road.points.size()):
		var p: Vector3 = road.points[i]
		var station: float = road.stations[i]
		var run: float = maxf(0, minf(station - road.landing.x, road.total - station - road.landing.y))
		var rise: float = GRADE * (run - .15 * (1.0 - exp(-run / .15)))
		var knee: float = RISE - EASE
		if rise > knee:
			var ease: float = clampf((rise - knee) / (2.0 * EASE), 0, 1)
			rise = knee + EASE * ease * (2 - ease)
		# Over a ravine's crown the datum rises under the road: past its landings
		# the road climbs with it, but never faster than its grade from a pad.
		var height: float = minf(_levels.deck_base(p.x, p.z) + Levels.BRIDGEHEAD + rise, minf(
			road.pads[0] + GRADE * maxf(0, station - road.landing.x),
			road.pads[1] + GRADE * maxf(0, road.total - station - road.landing.y)))
		if station <= road.landing.x:
			height = road.pads[0]
		elif road.total - station <= road.landing.y:
			height = road.pads[1]
		road.points[i].y = height
	_ease(road)


## Raises the road wherever it would fall faster than `grade` towards a higher
## sample, so a lift eases out at the road's grade.
## A landing keeps its pad's height: a lift too steep to reach from it
## leaves the road steeper there instead (its flights fit the grade).
func _ease(road: Raised, grade: float = GRADE) -> void:
	for i: int in range(1, road.points.size()):
		var run: float = road.stations[i] - road.stations[i - 1]
		if not road.in_landing(road.stations[i]):
			road.points[i].y = maxf(road.points[i].y, road.points[i - 1].y - grade * run)
	for i: int in range(road.points.size() - 2, -1, -1):
		var run: float = road.stations[i + 1] - road.stations[i]
		if not road.in_landing(road.stations[i]):
			road.points[i].y = maxf(road.points[i].y, road.points[i + 1].y - grade * run)


func _soffit(road: Raised, station: float) -> float:
	return Profile.soffit(road.height_at(station), station, road.total, true, _style)


## The plan distance from `at` to the road's line and the station there.
static func _nearest(road: Raised, at: Vector2) -> Vector2:
	var best: float = INF
	var station: float = 0.0
	for i: int in range(road.points.size() - 1):
		var a: Vector2 = Vector2(road.points[i].x, road.points[i].z)
		var b: Vector2 = Vector2(road.points[i + 1].x, road.points[i + 1].z)
		var t: float = clampf((at - a).dot(b - a) / maxf(.000001, a.distance_squared_to(b)), 0, 1)
		var distance: float = at.distance_to(a.lerp(b, t))
		if distance < best:
			best = distance
			station = lerpf(road.stations[i], road.stations[i + 1], t)
	return Vector2(best, station)
