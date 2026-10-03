class_name MapJourneyView
extends RefCounted
## Act I's camera: the journey rebuild's 55° Journey / Whole act framing
## (`MapJourneyCameraContract`), driven by the production screen.
##
## Journey frames the pilgrim's waystone and the waystones it may walk to next,
## as close as the contract lets every one of them keep its own ink and touch
## rectangle. Whole act frames every waystone and road; it is for looking, not
## choosing, so its waystones take no taps (a tap there returns to Journey).
## A group the contract cannot fit (a wide opening fan on a phone) keeps its
## nearest members and leaves the rest a pan away; it never shrinks a target.

const Contract = preload("res://presentation/map/map_journey_camera_contract.gd")
var overview: bool = false


## The waystones Journey frames from `focus` (-1 before the first step: the
## entrances). Indices into `map.nodes`.
static func group(map: WorldMap, focus: int) -> Array[int]:
	var out: Array[int] = []
	if focus >= 0 and focus < map.nodes.size():
		out.append(focus)
		for id: String in map.nodes[focus].next:
			for i: int in range(map.nodes.size()):
				if map.nodes[i].id == id:
					out.append(i)
		return out
	out.assign(map.reachable())
	return out


## The camera pose for `members` of `seats` on a `stage`-sized screen, or
## `{"ok": false}`. Whole act when `whole` (`members` ignored).
static func pose(seats: PackedVector3Array, members: Array[int], stage: Vector2,
		whole: bool, roads: PackedVector3Array = PackedVector3Array()) -> Dictionary:
	if seats.is_empty():
		return {"ok": false, "reason": "no seats"}
	var out: Dictionary
	if whole:
		var points: PackedVector3Array = seats.duplicate()
		points.append_array(roads)
		out = Contract.resolve(points, stage, true, PackedVector3Array(), Contract.MAIN_INSETS)
	else:
		var kept: Array[int] = members.duplicate()
		while true:
			var points: PackedVector3Array = PackedVector3Array()
			for i: int in kept:
				points.append(seats[i])
			out = Contract.resolve(points, stage, false, PackedVector3Array(), Contract.MAIN_INSETS)
			if out.get("ok", false) or kept.size() <= 1:
				break
			kept.remove_at(_farthest(seats, kept))
		out["members"] = kept
	if out.get("ok", false):
		var zoom: float = out["zoom"]
		var bounds: Rect2 = pan_bounds(stage, zoom)
		if not whole:
			var position: Vector3 = out["position"]
			position.x = clampf(position.x, bounds.position.x, bounds.end.x)
			position.z = clampf(position.z, bounds.position.y, bounds.end.y)
			out["position"] = position
		out["pan_bounds"] = bounds
	return out


## Camera XZ limits that keep a `zoom`-sized view over the drawn land
## (`MapJourneyLandscape.MAP_BOUNDS`), so a pan or a framing never shows past its
## edge. Where the view is wider than the land it is held at the land's middle.
static func pan_bounds(stage: Vector2, zoom: float) -> Rect2:
	var land: Rect2 = MapJourneyLandscape.MAP_BOUNDS
	var pitch: float = deg_to_rad(Contract.PITCH)
	var half: Vector2 = Vector2(zoom * stage.x / maxf(stage.y, 1.0), zoom / sin(pitch)) * 0.5
	var lo: Vector2 = land.position + half
	var hi: Vector2 = land.end - half
	if lo.x > hi.x:
		lo.x = land.get_center().x
		hi.x = lo.x
	if lo.y > hi.y:
		lo.y = land.get_center().y
		hi.y = lo.y
	var look: float = Contract.HEIGHT / tan(pitch)
	return Rect2(lo + Vector2(0.0, look), hi - lo)


## The member farthest from the first (the waystone the group is about).
static func _farthest(seats: PackedVector3Array, members: Array[int]) -> int:
	var origin: Vector3 = seats[members[0]]
	var worst: int = 1
	var worst_d: float = -1.0
	for k: int in range(1, members.size()):
		var d: float = origin.distance_squared_to(seats[members[k]])
		if d > worst_d:
			worst_d = d
			worst = k
	return worst
