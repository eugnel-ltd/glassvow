extends RefCounted
## Select a straight, dry route passage; piers and projected body stay clear.

## The arch's height and its piers' offset either side of the road (metres).
const ARCH_HEIGHT: float = 5.5
const PIER_OFFSET: float = 1.70
## How far a face-on arch may turn from facing the journey camera, whose yaw
## never turns (`MapJourneyCameraContract`): about 30°.
const FACING_MOST: float = PI / 6.0
## Spacing of the spots a face-on arch is tried at along a straight leg, and
## how far from either end of it (metres).
const FACING_STEP: float = 0.5
## How far a face-on arch's piers stand off a waystone's seat (metres): the
## woodland's clearance round a seat (`wood_planting.gd` `SEAT_CLEAR`, 1.2)
## and half a pier's footing.
const SEAT_ROOM: float = 1.8


static func choose(terrain: Node3D, anchors: PackedVector3Array, resolve_height: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var score: float = INF
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			if not _straight(a, b):
				continue
			var forward: Vector3 = (b - a).normalized()
			var side: Vector3 = Vector3.UP.cross(forward)
			var yaw: float = _yaw(forward)
			var half: Vector2 = _half(forward, side)
			for fraction: float in [0.25, 0.4, 0.5, 0.6, 0.75]:
				var p: Vector3 = a.lerp(b, fraction)
				if not _passage(terrain, p, side):
					continue
				var available: bool = true
				for anchor: Vector3 in anchors:
					if _reserved(p - anchor, half):
						available = false
				if not available:
					continue
				var candidate: float = _score(p, yaw)
				if candidate < score:
					score = candidate
					p.y = terrain.surface_height(p.x,p.z) if resolve_height else 0.0
					best = {"position": p, "yaw": yaw}
	return best


## A site where the arch faces the journey camera (#660; the owner's leave,
## 14 Oct 2026): on a straight dry leg within `FACING_MOST` of running up the
## screen, by the same passage rules as `choose`. Such legs lead to waystones,
## so the arch may stand in front of a waystone (nearer the camera, its whole
## depth before the seat), its piers `SEAT_ROOM` off the seat; the waystone's
## pin is drawn above the land, so the stone's base is all it hides. Behind or
## beside a waystone, the reserve `choose` keeps still holds. `clear` says
## whether the arch at a position and yaw stands clear of everything placed
## round it. Empty when no leg has such a site.
static func facing(terrain: Node3D, anchors: PackedVector3Array, clear: Callable) -> Dictionary:
	var best: Dictionary = {}
	var score: float = INF
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			if not _straight(a, b):
				continue
			var forward: Vector3 = (b - a).normalized()
			var yaw: float = _yaw(forward)
			if absf(yaw) > FACING_MOST:
				continue
			var side: Vector3 = Vector3.UP.cross(forward)
			var half: Vector2 = _half(forward, side)
			var length: float = a.distance_to(b)
			var along: float = FACING_STEP
			while along <= length - FACING_STEP:
				var p: Vector3 = a.lerp(b, along / length)
				along += FACING_STEP
				if not _passage(terrain, p, side) or not _before_seats(p, side, half, anchors):
					continue
				var candidate: float = _score(p, yaw)
				if candidate >= score:
					continue
				p.y = terrain.surface_height(p.x, p.z)
				if clear.call(p, yaw):
					score = candidate
					best = {"position": p, "yaw": yaw}
	return best


## A leg the arch can stand on: at least 3 m, level and low.
static func _straight(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) >= 3 and absf(a.y - b.y) <= 0.03 and a.y <= 0.12


## The arch's yaw over a road running along `forward`, within ±90°.
static func _yaw(forward: Vector3) -> float:
	var yaw: float = atan2(forward.x, forward.z)
	if yaw > PI / 2:
		yaw -= PI
	elif yaw < -PI / 2:
		yaw += PI
	return yaw


## The arch's half extents across x and along z, over a road along `forward`.
static func _half(forward: Vector3, side: Vector3) -> Vector2:
	return Vector2(absf(side.x) * 2.65 + absf(forward.x) * 0.70, absf(side.z) * 2.65 + absf(forward.z) * 0.70)


## Off the streams, and no other road under either pier.
static func _passage(terrain: Node3D, p: Vector3, side: Vector3) -> bool:
	if terrain.stream_distance(p.x, p.z) < 5:
		return false
	for sign_value: float in [-1, 1]:
		if terrain.distance_to_roads(p + side * sign_value * PIER_OFFSET) < 1.62:
			return false
	return true


## Whether the arch, `delta` from a waystone, would stand within the stone's
## reserve: its projected body over the stone and its pin.
static func _reserved(delta: Vector3, half: Vector2) -> bool:
	return absf(delta.x) < half.x + 1.2 and delta.z > -half.y - 1.3 \
		and delta.z < half.y + ARCH_HEIGHT / tan(deg_to_rad(MapJourneyCameraContract.PITCH)) + 1.3


## Whether a face-on arch at `p` leaves every waystone as the owner's leave
## allows: outside its reserve, or wholly in front of its seat with both piers
## `SEAT_ROOM` off it.
static func _before_seats(p: Vector3, side: Vector3, half: Vector2, anchors: PackedVector3Array) -> bool:
	for anchor: Vector3 in anchors:
		var delta: Vector3 = p - anchor
		if not _reserved(delta, half):
			continue
		if delta.z <= half.y:
			return false
		for sign_value: float in [-1, 1]:
			var pier: Vector3 = p + side * sign_value * PIER_OFFSET - anchor
			if Vector2(pier.x, pier.z).length() < SEAT_ROOM:
				return false
	return true


## The sample's early lower journey is the authored focal region.
static func _score(p: Vector3, yaw: float) -> float:
	return p.distance_to(Vector3(-20, 0, 14)) + absf(yaw) * 2
