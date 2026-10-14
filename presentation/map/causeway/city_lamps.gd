extends Node3D
## Act II's jade lanterns (#660 II.3): a stone post with a lantern at the
## landing of every waystone, where the north star and the archive's painting
## hang them. Each stands on the landing's deck, off the pilgrim's every
## walking route and waiting place (`CLEAR`), on the side of the node with the
## most room; a node with no such room has none. The
## posts are masonry (`trim`); the lanterns' glass glows jade; their flames are
## the land's lamps (`lamps.gd`), and their pools and reflections are painted
## into the light mask (`city_mask.gd`), so no lantern adds a light.
##
## Built off the tree on the land's worker; reads nothing back from the
## renderer.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const BoxBatch = preload("res://presentation/map/causeway/box_batch.gd")
## How far from its waystone a lantern stands, the directions tried round it,
## and the room it keeps from every road's line (a walking body and the post).
const RADIUS: float = 1.08
const DIRECTIONS: int = 12
const CLEAR: float = .98
## The deck a post stands on must reach this far past it (the deck's own edge
## masonry stands outside the deck).
const FOOTING: float = .2
## The post's proportions (metres) and where its flame burns over the deck.
const POST: Vector3 = Vector3(.2, .92, .2)
const CAP: Vector3 = Vector3(.3, .07, .3)
const LANTERN: Vector3 = Vector3(.17, .22, .17)
const FLAME_HEIGHT: float = 1.1
const GLASS: Color = Color(0.32, 1.0, 0.66)

## Each lantern's flame centre, in land space.
var anchors: PackedVector3Array = PackedVector3Array()


## Places a lantern at each of `seats` (the waystones on their decks), clear of
## every line of `routes` (the pilgrim's walking routes) and of every place he
## waits (`waits`), on a deck of `fields`, and draws the posts with `trim`.
func build(seats: Array, routes: Array, waits: Array, fields: Array, trim: Material) -> void:
	name = "Lanterns"
	var posts: SurfaceTool = SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass: SurfaceTool = SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone: BoxBatch = BoxBatch.new(posts)
	var lights: BoxBatch = BoxBatch.new(glass)
	# Each route's plan, grown by the reach a lantern's test looks over: a seat
	# tests only the routes that pass near it.
	var reach: float = RADIUS + CLEAR + .1
	var plans: Array[Rect2] = []
	for line: PackedVector3Array in routes:
		var plan: Rect2 = Rect2(Vector2(line[0].x, line[0].z), Vector2.ZERO) if not line.is_empty() else Rect2()
		for p: Vector3 in line:
			plan = plan.expand(Vector2(p.x, p.z))
		plans.append(plan.grow(reach))
	for seat: Vector3 in seats:
		var near: Array[PackedVector3Array] = []
		for i: int in range(routes.size()):
			if plans[i].has_point(Vector2(seat.x, seat.z)):
				near.append(routes[i])
		var at: Vector3 = _site(seat, near, waits, fields)
		if not at.is_finite():
			continue
		stone.append(Transform3D(Basis.from_scale(POST), at + Vector3.UP * POST.y * .5))
		stone.append(Transform3D(Basis.from_scale(CAP), at + Vector3.UP * (POST.y + CAP.y * .5)))
		lights.append(Transform3D(Basis.from_scale(LANTERN), at + Vector3.UP * FLAME_HEIGHT))
		anchors.append(at + Vector3.UP * FLAME_HEIGHT)
	if anchors.is_empty():
		return
	var lit: StandardMaterial3D = StandardMaterial3D.new()
	lit.albedo_color = Color(0.05, 0.12, 0.09)
	lit.emission_enabled = true
	lit.emission = GLASS
	lit.emission_energy_multiplier = 1.6
	Meshes.node(self, Meshes.finish(posts), trim, "Lantern posts").cast_shadow = \
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Meshes.node(self, Meshes.finish(glass), lit, "Lantern glass").cast_shadow = \
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Where a lantern by `seat` stands: the direction round it whose foot is
## furthest from every road's line, on a deck; INF when none has the room.
func _site(seat: Vector3, routes: Array, waits: Array, fields: Array) -> Vector3:
	var best: Vector3 = Vector3.INF
	var room: float = CLEAR
	for k: int in range(DIRECTIONS):
		var angle: float = TAU * k / DIRECTIONS
		var foot: Vector2 = Vector2(seat.x, seat.z) + Vector2(cos(angle), sin(angle)) * RADIUS
		var clearance: float = INF
		for line: PackedVector3Array in routes:
			clearance = minf(clearance, _distance(line, foot))
		for wait: Vector3 in waits:
			clearance = minf(clearance, Vector2(wait.x, wait.z).distance_to(foot))
		if clearance < room:
			continue
		for field: RefCounted in fields:
			var query: Dictionary = field.field(foot)
			var inside: float = query["distance"]
			var height: float = query["height"]
			if inside <= -FOOTING and absf(height - seat.y) < .35:
				best = Vector3(foot.x, height - .022, foot.y)
				room = clearance
				break
	return best


static func _distance(line: PackedVector3Array, at: Vector2) -> float:
	var best: float = INF
	for i: int in range(line.size() - 1):
		var a: Vector2 = Vector2(line[i].x, line[i].z)
		var b: Vector2 = Vector2(line[i + 1].x, line[i + 1].z)
		best = minf(best, Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at))
	return best
