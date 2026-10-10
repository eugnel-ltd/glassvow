extends RefCounted
## Where the ravine's cliff pieces stand (R3.3, issue #660): along both banks
## of each river (`MapRavine.CUTS`), a piece every `STEP` of its own width,
## its face turned to the water and its lip at the bank's rim, so the ravine
## reads as a gorge of stepped strata (`land_stone.gd` draws them).
##
## The rule, deterministic from the land itself:
## - a piece's origin stands `ORIGIN` from the river's line, square to it, at
##   the rim's height (the ground `RIM` from the line);
## - no piece within `EDGE` of the land's far edge or `NEAR_EDGE` of its near
##   edge, `DECK_CLEAR` of a
##   raised bridge deck, `ABUTMENT_CLEAR` of an abutment, `SEAT_CLEAR` of a
##   waystone's seat, or `ROAD_CLEAR` of a road at its rim;
## - its kind by the bank: the bend piece on the outside of a bend, the low
##   step where the rim stands low over the water, the tall wall where it
##   stands high, else a wall, a notched wall or a buttress by a hash;
## - scaled evenly, never smaller, so its foot always reaches below the water;
##   and none whose foot would sink below the journey camera's slab
##   (`MapJourneyCameraContract.LAND_LOW`).

const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const Stone = preload("res://presentation/map/landscape/land_stone.gd")
const ORIGIN: float = 2.15
const RIM: float = 2.6
## How much of a piece's width the next one starts along (they overlap).
const STEP: float = 0.82
## How deep a piece reaches below its rim at scale 1 (`cliffs.py` `BASE`), and
## how far below the water its foot must reach.
const REACH: float = 4.0
const FOOT: float = 0.5
const DECK_CLEAR: float = 3.0
const DECK_WEIGHT: float = 0.3
const ABUTMENT_CLEAR: float = 3.5
const SEAT_CLEAR: float = 3.0
const ROAD_CLEAR: float = 2.0
## How far inside the land's far edge the first piece stands, and inside its
## near edge (toward the camera) the last: no piece shows past the land's
## edge, where its foot would hang below the ground. At the near edge the
## camera sees under the land, so the last piece keeps back as far again as
## its foot reaches below the rim on the picture: at most 5.3 m (a rim 2.5 m
## up, the water's level and `FOOT`) over the tangent of
## `MapJourneyCameraContract.PITCH`, 40 degrees.
const EDGE: float = 2.5
const NEAR_EDGE: float = 8.9
## The rim's height over the water below which a bank takes the low step, and
## above which the tall wall.
const LOW_RIM: float = 2.6
const HIGH_RIM: float = 4.6
## How sharply the line must bend (its second derivative, per metre) for the
## outside bank to take the bend piece.
const BEND: float = 0.04


## The cliff pieces of `terrain`'s rivers, clear of the seats `seats`:
## [kind, Transform3D] pairs.
static func plan(terrain: Terrain, seats: PackedVector3Array) -> Array:
	var decks: PackedVector3Array = _decks(terrain)
	var abutments: PackedVector2Array = terrain.landform.get("abutments")
	var bounds: Rect2 = terrain.bounds
	var first: float = maxf(-terrain.river_half_length, bounds.position.y) + EDGE
	var last: float = minf(terrain.river_half_length, bounds.end.y) - NEAR_EDGE
	var out: Array = []
	for cut: float in MapRavine.CUTS:
		for side: float in [-1.0, 1.0]:
			var z: float = first
			while z <= last:
				var kind: String = _kind(terrain, cut, side, z)
				var width: float = maxf(Stone.extent(kind).size.x, 2.0)
				var pose: Transform3D = _pose(terrain, cut, side, z)
				var foot: float = pose.origin.y + Stone.extent(kind).position.y * pose.basis.get_scale().y
				if _clear(terrain, pose.origin, decks, abutments, seats) and foot >= MapJourneyCameraContract.LAND_LOW:
					out.append([kind, pose])
				z += width * STEP
	return out


## The pose of a piece on bank `side` of the river `cut` at `z`: its face
## (+Z) toward the water, its x along the river, its origin at the rim.
static func _pose(terrain: Terrain, cut: float, side: float, z: float) -> Transform3D:
	var slope: float = (River.centre(z + 0.5, cut) - River.centre(z - 0.5, cut))
	var outward: Vector3 = Vector3(1.0, 0.0, -slope).normalized()
	var line: Vector3 = Vector3(River.centre(z, cut), 0.0, z)
	var face: Vector3 = -outward * side
	var along: Vector3 = Vector3.UP.cross(face)
	var rim_at: Vector3 = line + outward * side * RIM
	var rim: float = terrain.surface_height(rim_at.x, rim_at.z)
	var size: float = maxf(1.0, (rim - River.LEVEL + FOOT) / REACH)
	var origin: Vector3 = line + outward * side * ORIGIN
	origin.y = rim
	return Transform3D(Basis(along, Vector3.UP, face).scaled(Vector3.ONE * size), origin)


static func _kind(terrain: Terrain, cut: float, side: float, z: float) -> String:
	var bend: float = River.centre(z + 1.0, cut) - 2.0 * River.centre(z, cut) + River.centre(z - 1.0, cut)
	var rim_at: float = River.centre(z, cut) + side * RIM
	var over: float = terrain.surface_height(rim_at, z) - River.LEVEL
	if -signf(bend) == side and absf(bend) > BEND:
		return "cliff-bend"
	if over < LOW_RIM:
		return "cliff-step"
	if over > HIGH_RIM:
		return "cliff-tall"
	var h: float = absf(sin(z * 12.9898 + cut * 78.233 + side * 37.719)) * 43758.5453
	h -= floorf(h)
	return "cliff-wall" if h < 0.45 else ("cliff-notch" if h < 0.7 else "cliff-buttress")


static func _clear(terrain: Terrain, at: Vector3, decks: PackedVector3Array,
		abutments: PackedVector2Array, seats: PackedVector3Array) -> bool:
	var flat: Vector2 = Vector2(at.x, at.z)
	for deck: Vector3 in decks:
		if flat.distance_to(Vector2(deck.x, deck.z)) < DECK_CLEAR:
			return false
	for pad: Vector2 in abutments:
		if flat.distance_to(pad) < ABUTMENT_CLEAR:
			return false
	for seat: Vector3 in seats:
		if flat.distance_to(Vector2(seat.x, seat.z)) < SEAT_CLEAR:
			return false
	return terrain.distance_to_roads(at) >= ROAD_CLEAR


## Every raised point of every bridge chain.
static func _decks(terrain: Terrain) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for chain: Dictionary in terrain.get_meta("bridge_chains", []):
		var points: PackedVector3Array = chain["points"]
		var weights: PackedFloat32Array = chain["weights"]
		for i: int in range(points.size()):
			if weights[i] >= DECK_WEIGHT:
				out.append(points[i])
	return out
