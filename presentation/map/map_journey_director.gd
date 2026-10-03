class_name MapJourneyDirector
extends RefCounted
## What `WorldMapScreen` does differently on the journey land (Act I): the 55°
## camera's two framings, the pilgrim who carries the Flame, waystone seats on
## the 3D stones, and the walk along the graded road. The screen keeps every
## rule of play (what is reachable, what a tap chooses, when a node is
## entered); this only decides where things are drawn and how the camera moves.

## Where the 2D waystone sits on its 3D stone: the engraved face, not the
## stone's foot (the native workshop's seat).
const PIN_LIFT: Vector3 = Vector3(0.0, 0.48, 0.14)

var screen: WorldMapScreen
var view: MapJourneyView = MapJourneyView.new()
var flame: Color = LanternFlame.COLOUR[Flame.TIER_KINDLING]
## The waystones the camera frames (the pose's members), which the
## tilt-shift's sharp band follows; empty in Whole act.
var focus_members: Array[int] = []
var _from_pose: Dictionary = {}
var _to_pose: Dictionary = {}


func _init(host: WorldMapScreen) -> void:
	screen = host


## Whether the screen is showing the journey land right now.
func active() -> bool:
	return screen._map_scene != null and screen._layout_result != null \
		and screen._map_scene.journey_landscape() != null \
		and screen._map_scene.journey_landscape().journey != null


func land() -> MapJourneyLandscape:
	return screen._map_scene.journey_landscape()


## The waystones' seats on their stones, in `map.nodes` order.
func pin_seats(anchors: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in range(anchors.size()):
		out.append(land().seat(screen.map.nodes[i].id, anchors[i]) + PIN_LIFT)
	return out


## The pose framing `focus` (Journey, or Whole act when the view says so).
func pose_for(focus: int) -> Dictionary:
	var seats: PackedVector3Array = pin_seats(screen._ordered_layout_anchors())
	if seats.size() != screen.map.nodes.size():
		return {"ok": false}
	var stage: Vector2 = Vector2(StageShape.REFERENCES[screen.shape])
	var roads: PackedVector3Array = PackedVector3Array()
	if view.overview:
		for i: int in range(0, screen._map_scene.road_segments().size(), 6):
			roads.append(screen._map_scene.road_segments()[i])
	return MapJourneyView.pose(seats, MapJourneyView.group(screen.map, focus), stage,
		view.overview, roads, view.level == MapJourneyView.Level.CLOSE)


## Frames the pilgrim's waystone and seats the pilgrim there.
func frame(focus: int) -> void:
	var rig: MapCameraRig = screen._map_scene.get_rig()
	var pose: Dictionary = pose_for(focus)
	if not rig.apply_journey_pose(pose):
		push_error("MapJourneyDirector: no journey pose frames node %d" % focus)
	_follow(pose)
	park()
	screen._invalidate_projection()
	screen._map_scene.set_live(false)


func park() -> void:
	var at: int = screen.map.at
	var anchors: PackedVector3Array = screen._ordered_layout_anchors()
	if at < 0 or at >= screen.map.nodes.size():
		land().set_traveller(Vector3.INF, Vector3.INF, false)
		# Before the first step the lamps light the road out of the start.
		var next: Array[int] = screen.map.reachable()
		if not next.is_empty() and next[0] < anchors.size():
			land().focus_lamps(land().seat(screen.map.nodes[next[0]].id, anchors[next[0]]))
		return
	var id: String = screen.map.nodes[at].id
	var spot: Vector3 = land().parked(id, anchors[at]) if at < anchors.size() else Vector3.INF
	land().set_traveller(spot, spot, false)
	land().set_flame(flame)
	land().focus_lamps(spot)


## Wheel or pinch: one level outward (Close, Journey, Whole act) or inward.
func zoom(outward: bool) -> void:
	var next: int = clampi(int(view.level) + (1 if outward else -1), 0, 2)
	if screen._travelling or next == int(view.level):
		return
	view.level = next as MapJourneyView.Level
	frame(screen.map.at)


## A tap on Whole act looks closer at the nearest waystone's group; it never
## chooses one. True when the tap was taken that way.
func tap(at: Vector2) -> bool:
	if not view.overview:
		return false
	var seats: PackedVector2Array = screen.projected_seats()
	var best: int = -1
	var best_d: float = INF
	for i: int in range(seats.size()):
		var d: float = seats[i].distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = i
	view.overview = false
	frame(best if best >= 0 else screen.map.at)
	return true


## The walk from `from_i` to `to_i` begins: fix both ends of the camera move.
func begin_walk(to_i: int) -> float:
	view.overview = false
	var camera: Camera3D = screen._map_scene.get_rig().get_camera()
	_from_pose = {"position": camera.position, "zoom": camera.size}
	_to_pose = pose_for(to_i)
	if not _to_pose.get("ok", false):
		_to_pose = _from_pose
	_follow(_to_pose)
	var from_i: int = screen._travel_from_i
	if from_i < 0:
		return 0.0
	return land().travel_duration(screen.map.nodes[from_i].id, screen.map.nodes[to_i].id)


## Keeps the tilt-shift's sharp band on the framed group, at the seats the
## screen has just laid its pins out on (`WorldMapScreen._layout_waystones`).
func sync_focus_band(seats: PackedVector2Array) -> void:
	var scene: MapScene = screen._map_scene
	if view.overview or focus_members.is_empty():
		scene.set_focus_band(Vector2.INF)
		return
	var heights: PackedFloat32Array = PackedFloat32Array()
	for i: int in focus_members:
		if i < seats.size():
			heights.append(seats[i].y)
	var margin: float = MapJourneyCameraContract.touch_size(screen.size) * 0.6
	scene.set_focus_band(MapTiltShift.band(heights, scene.size.y, margin))


func _follow(pose: Dictionary) -> void:
	focus_members.clear()
	if view.overview or not pose.get("ok", false):
		return
	for member: Variant in pose.get("members", []):
		focus_members.append(int(str(member)))


## One step of the walk at progress `v` (0..1): camera and pilgrim.
func walk(v: float) -> void:
	var camera: Camera3D = screen._map_scene.get_rig().get_camera()
	if _from_pose.has("position") and _to_pose.has("position"):
		var a: Vector3 = _from_pose["position"]
		var b: Vector3 = _to_pose["position"]
		camera.position = a.lerp(b, v)
		var from_zoom: float = _from_pose["zoom"]
		var to_zoom: float = _to_pose["zoom"]
		camera.size = lerpf(from_zoom, to_zoom, v)
	var at: Vector3 = position(v)
	var ahead: Vector3 = position(minf(1.0, v + 0.005))
	land().set_traveller(at, ahead, true)
	screen._invalidate_projection()


func arrive() -> void:
	if _to_pose.get("ok", false):
		screen._map_scene.get_rig().apply_journey_pose(_to_pose)
	_from_pose = {}
	_to_pose = {}
	park()


## The pilgrim's world point at walk progress `v`, or parked when resting.
func position(v: float) -> Vector3:
	var to_i: int = screen.map.at
	var from_i: int = screen._travel_from_i
	if from_i >= 0 and to_i >= 0:
		var walked: Vector3 = land().travel_position(screen.map.nodes[from_i].id,
			screen.map.nodes[to_i].id, v)
		if walked.is_finite():
			return walked
	if to_i < 0 or to_i >= screen.map.nodes.size():
		return Vector3.INF
	var anchors: PackedVector3Array = screen._ordered_layout_anchors()
	return land().parked(screen.map.nodes[to_i].id, anchors[to_i]) if to_i < anchors.size() else Vector3.INF


## The run's Flame, as the lantern burns it: its declared way's colour, or the
## tier's when none is declared (`LanternFlame.show_event`).
func read_flame(content: ContentDB, run: RunState) -> void:
	if content == null or run == null:
		return
	var reading: Dictionary = Flame.read(content, run)
	var lantern: LanternFlame = LanternFlame.new()
	lantern.show_event(reading, true)
	flame = lantern.light_now()
	lantern.free()
	if active():
		land().set_flame(flame)
