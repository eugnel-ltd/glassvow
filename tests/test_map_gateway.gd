extends RefCounted
## The gateway arch faces the journey camera (#660; the owner's leave,
## 14 Oct 2026), held on Act I's land at seeds 717 and 1–3:
##
## - it stands within `GatewaySites.FACING_MOST` of facing the camera, on a
##   road, its piers off every other road and every waystone's seat, its
##   footings and its apron of flags under it;
## - no waystone stands in front of it within the stone's reserve: the arch
##   may stand in front of a waystone's base, never behind or beside one;
## - every waystone it stands in front of keeps its pin whole and tappable at
##   the phone's and the pad's shape: the token is drawn above the land, and a
##   tap anywhere on its pane picks that waystone through the map's own tap
##   path (`WorldMapScreen.pick_node_at`), which no scenery can intercept;
## - turning it moves no other kit placement: seed 717 built with the turn off
##   places everything else the same.
##
## The rendered token's contrast over the arch is `tools/map_token_gate.gd`'s.

const Sites = preload("res://presentation/map/landscape/gateway_sites.gd")
const SEEDS: Array[int] = [717, 1, 2, 3]
const SHAPES: Array[StringName] = [&"phone-landscape", &"pad-landscape"]
## A tap is tried at the pane's centre and at this share of its radius round it.
const PANE_SHARE: float = 0.7
const TAPS: int = 8


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_gateway: %s" % what)


static func run(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	var content: ContentDB = ContentDB.load_full()
	var fronted: int = 0
	var turned: String = ""
	for seed_value: int in SEEDS:
		var screen: WorldMapScreen = _open(content, seed_value)
		var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
		var built: bool = land != null and land.is_built()
		_check(fails, built, "Act I's land is built (seed %d)" % seed_value)
		if built:
			var arch: Dictionary = _arch(land)
			_check(fails, not arch.is_empty(), "Act I's land has its gateway (seed %d)" % seed_value)
			if not arch.is_empty():
				_faces(fails, land, arch, seed_value)
				for seat: Vector3 in _fronted(land, arch):
					fronted += 1
					_pin(fails, screen, seat, seed_value)
			if seed_value == SEEDS[0]:
				turned = _others(land)
		_close(screen)
	_check(fails, fronted > 0, "at some seed the arch stands in front of a waystone, so its pin is tried")
	MapJourneyLandscape.Kit.face_gateway = false
	var screen: WorldMapScreen = _open(content, SEEDS[0])
	MapJourneyLandscape.Kit.face_gateway = true
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	var unturned: Dictionary = _arch(land) if land != null and land.is_built() else {}
	_check(fails, not unturned.is_empty() and absf(float(str(unturned["yaw"]))) > Sites.FACING_MOST,
		"without the turn, seed %d's gateway stands edge-on, as before the owner's leave" % SEEDS[0])
	_check(fails, not turned.is_empty() and land != null and _others(land) == turned,
		"turning the gateway moves no other kit placement (seed %d)" % SEEDS[0])
	_close(screen)


static func _open(content: ContentDB, seed_value: int) -> WorldMapScreen:
	var run_state: RunState = RunState.new_run(content, seed_value, "run-map-gateway")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(run_state, content), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.set_shape(StageShape.IDENTITY)
	screen.refresh(run_state)
	return screen


static func _close(screen: WorldMapScreen) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


static func _arch(land: MapJourneyLandscape) -> Dictionary:
	for item: Dictionary in land.kit.placed:
		if item["kind"] == MapJourneyLandscape.Kit.ARCH:
			return item
	return {}


## Every kit placement but the gateway, in order.
static func _others(land: MapJourneyLandscape) -> String:
	var parts: PackedStringArray = []
	for item: Dictionary in land.kit.placed:
		if item["kind"] != MapJourneyLandscape.Kit.ARCH:
			parts.append("%s %s %s %s" % [item["kind"], item["position"], item["scale"], item["yaw"]])
	return "\n".join(parts).sha256_text()


static func _faces(fails: Array[String], land: MapJourneyLandscape, arch: Dictionary, seed_value: int) -> void:
	var at: Vector3 = arch["position"]
	var yaw: float = float(str(arch["yaw"]))
	var terrain: MapJourneyLandscape.Terrain = land.terrain
	_check(fails, absf(yaw) <= Sites.FACING_MOST,
		"the gateway faces the camera within %.0f° (seed %d: %.1f°)" % [rad_to_deg(Sites.FACING_MOST), seed_value, rad_to_deg(yaw)])
	_check(fails, terrain.distance_to_roads(at) < 0.25, "the gateway stands over a road (seed %d)" % seed_value)
	var side: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	for sign_value: float in [-1, 1]:
		var pier: Vector3 = at + side * sign_value * Sites.PIER_OFFSET
		_check(fails, terrain.distance_to_roads(pier) >= 1.62, "no road runs under the gateway's piers (seed %d)" % seed_value)
		for seat: Vector3 in land.kit.anchors:
			_check(fails, Vector2(pier.x - seat.x, pier.z - seat.z).length() >= Sites.SEAT_ROOM,
				"the gateway's piers stand off every waystone's seat (seed %d)" % seed_value)
	var footing: Array = land.kit.contacts.get("_arch")
	var footed_at: Vector3 = footing[0] if not footing.is_empty() else Vector3.INF
	var footed_yaw: float = footing[2] if not footing.is_empty() else INF
	_check(fails, footed_at.is_equal_approx(at) and is_equal_approx(footed_yaw, yaw),
		"the gateway's footings stand under it (seed %d)" % seed_value)
	var ground: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
	var apron: Vector2 = (ground.material_override as ShaderMaterial).get_shader_parameter("gateway_position")
	_check(fails, apron.is_equal_approx(Vector2(at.x, at.z)), "the gateway's apron of flags lies under it (seed %d)" % seed_value)
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var half: Vector2 = Sites._half(forward, side)
	for seat: Vector3 in land.kit.anchors:
		var delta: Vector3 = at - seat
		_check(fails, not Sites._reserved(delta, half) or delta.z > half.y,
			"no waystone stands in front of the gateway within its reserve (seed %d)" % seed_value)


## The seats of the waystones the gateway stands in front of, within their
## reserve.
static func _fronted(land: MapJourneyLandscape, arch: Dictionary) -> PackedVector3Array:
	var at: Vector3 = arch["position"]
	var yaw: float = float(str(arch["yaw"]))
	var half: Vector2 = Sites._half(Vector3(sin(yaw), 0.0, cos(yaw)), Vector3(cos(yaw), 0.0, -sin(yaw)))
	var out: PackedVector3Array = []
	for seat: Vector3 in land.kit.anchors:
		if Sites._reserved(at - seat, half):
			out.append(seat)
	return out


## The pin of the waystone seated at `seat` at each shape, framed on it: drawn
## above the land and picked by a tap at its centre and across its pane.
static func _pin(fails: Array[String], screen: WorldMapScreen, seat: Vector3, seed_value: int) -> void:
	var pins: PackedVector3Array = screen._pin_anchors()
	var index: int = -1
	for i: int in range(pins.size()):
		if index < 0 or Vector2(pins[i].x - seat.x, pins[i].z - seat.z).length() \
				< Vector2(pins[index].x - seat.x, pins[index].z - seat.z).length():
			index = i
	var stone: GlassWaystone = screen._waystones[index]
	_check(fails, stone.visible and stone.get_parent() == screen._map_scene.get_parent()
		and stone.get_index() > screen._map_scene.get_index(),
		"the token of waystone %d is drawn above the land (seed %d)" % [index, seed_value])
	for shape: StringName in SHAPES:
		screen.size = Vector2(StageShape.REFERENCES[shape])
		screen.set_shape(shape)
		var centre: Vector2 = _frame(screen, index)
		var reach: float = stone.pane_radius() * stone.scale.x * PANE_SHARE
		var picked: bool = Rect2(Vector2.ZERO, screen.size).has_point(centre) and screen.pick_node_at(centre) == index
		for k: int in range(TAPS):
			picked = picked and screen.pick_node_at(centre + Vector2.from_angle(TAU * k / TAPS) * reach) == index
		_check(fails, picked, "a tap on waystone %d's pane picks it with the gateway before it (seed %d, %s; pane %.0f px)"
			% [index, seed_value, shape, reach / PANE_SHARE])


## Pans the journey camera until waystone `index`'s seat is mid-screen; where
## it now lies on the screen.
static func _frame(screen: WorldMapScreen, index: int) -> Vector2:
	var rig: MapCameraRig = screen._map_scene.get_rig()
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	for _pass: int in range(3):
		screen._invalidate_projection()
		var off: Vector2 = (screen.projected_seats()[index] - screen.size * 0.5) * rig.get_camera().size / screen.size.y
		rig.pan_world(Vector2(off.x, off.y / sin(pitch)))
	screen._invalidate_projection()
	screen._layout_waystones()
	return screen.projected_seats()[index]
