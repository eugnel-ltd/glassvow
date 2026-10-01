extends RefCounted
@warning_ignore_start("unsafe_call_argument")
## The production map layout (docs/map/production-layout.md): every Act and
## seed binds a complete, playable, deterministic layout through the live
## WorldMapScreen without ever reaching Map Compiler v2.

const RUN_PATH: String = "user://test_map_layout_fast_run_v2.json"
const VIGIL_PATH: String = "user://test_map_layout_fast_vigil_v2.json"
## Loose regression guard for CI hosts; tools/probe_map_fast_layout.gd holds
## the 200 ms budget on the evidence host.
const GENERATE_GUARD_MS: float = 1000.0
const SEEDS: Array[int] = [1, 42, 717, 17634, 543001]
## A pair of waystones may stay close at the farthest zoom only when both stand
## within this many metres of a ravine's centre line.
const RAVINE_CROWDED_M: float = 4.0
## The most waystones a map may stand on a ravine's pier.
const MAX_PIERS: int = 4
## Geometry digest (node anchors and routed edges) per "seed/act number",
## recorded by tools/probe_map_fast_layout.gd in a separate process. A change
## here is a deliberate layout change and belongs in its own commit.
const GOLDEN_GEOMETRY: Dictionary = {
	"1/1": "21a655653a1e645b050de71ee41f1baa636db70edb065c370781f528187e6dd8",
	"1/2": "f547670ffc0058cc84c1c15fd6a177b2f3e160052723c874f0aa4533cf781b9d",
	"1/3": "f547670ffc0058cc84c1c15fd6a177b2f3e160052723c874f0aa4533cf781b9d",
	"1/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"42/1": "1c3dea8c17286a3e5cd5884a6e6cb2adf7e3062c1fd6ee158a291c8667dfe175",
	"42/2": "4c7a0810c2b6c926405a7724b22172b9ed07b29eccd72e9e21aa7b7e01b4f5c6",
	"42/3": "4c7a0810c2b6c926405a7724b22172b9ed07b29eccd72e9e21aa7b7e01b4f5c6",
	"42/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"717/1": "c06075b97e34bfd3704fec71f2f04777b597d095eb6fe28dd6565f76c04bb26e",
	"717/2": "f8e82d96e543ba85c1b8386e88779f77acb995845fbe34932a2ca4f9f76acd05",
	"717/3": "f8e82d96e543ba85c1b8386e88779f77acb995845fbe34932a2ca4f9f76acd05",
	"717/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"17634/1": "728d82b09cb0c13e0580a40308a5456283b25ec94c0375c0ef9dee78f6711d34",
	"17634/2": "728d82b09cb0c13e0580a40308a5456283b25ec94c0375c0ef9dee78f6711d34",
	"17634/3": "728d82b09cb0c13e0580a40308a5456283b25ec94c0375c0ef9dee78f6711d34",
	"17634/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"543001/1": "94b85aa5bd94496390ed887731aa6521b2901e78cc2b47c2a9ee7ec724261112",
	"543001/2": "689db14b9ba21ec01e62b761645370edbbb36cbe15653d8e9a20b285f38ba757",
	"543001/3": "689db14b9ba21ec01e62b761645370edbbb36cbe15653d8e9a20b285f38ba757",
	"543001/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
}

## What the live screen handed its generator, and how long the call took.
static var _inputs: Array[MapLayoutInput] = []
static var _assets: Dictionary = {}
static var _generate_ms: float = 0.0


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_fast: %s" % what)


static func run(fails: Array[String]) -> void:
	_policy_defaults(fails)
	_constants_follow_the_registry(fails)
	_three_crossing_roads_are_reported(fails)
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/map/map-quality-v2.json"))
	var content: ContentDB = ContentDB.load_full()
	var dispatches: int = MapLayoutPolicy.compiler_dispatches
	for seed_value: int in SEEDS:
		for act: int in range(4):
			_live_layout(fails, content, quality, seed_value, act)
	_check(fails, MapLayoutPolicy.compiler_dispatches == dispatches,
		"no production map binding dispatched to the compiler")
	_main_route_never_compiles(fails, content)
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _policy_defaults(fails: Array[String]) -> void:
	_check(fails, not MapLayoutPolicy.compiler_requested(),
		"the shipped project does not opt into the compiler")
	var fast: Dictionary = MapLayoutPolicy.generator_fields(false)
	var compiler: Dictionary = MapLayoutPolicy.generator_fields(true)
	_check(fails, fast["generator_version"] == MapLayoutFast.VERSION
			and compiler["generator_version"] == MapLayoutCompiler.VERSION
			and compiler["generator_schema"] == MapLayoutPolicy.COMPILER_SCHEMA,
		"each generator writes its own identity into the canonical input")


static func _constants_follow_the_registry(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/map/map-quality-v2.json"))
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var clearance: float = 0.0
	for rule: Dictionary in quality["hard"]:
		if str(rule["id"]) == "node_ink_clearance_px":
			clearance = float(rule["limit"])
	var ink: float = float(calibration["ink_radius_px"]) \
		* float(calibration["default_layout_scale"])
	var shortest: float = INF
	for shape: Array in quality["profiles"]["shapes"].values():
		shortest = minf(shortest, float(shape[1]))
	var zoom: float = MapCameraRig.ZOOM_STOPS[MapCameraRig.ZOOM_STOPS.size() - 1]
	var tilt: float = deg_to_rad(absf(MapCameraRig.TILT_DEGREES))
	var along: float = shortest / zoom
	_check(fails, absf(MapLayoutFastSeating.FAR_PX_PER_M - along) < 1e-9,
		"FAR_PX_PER_M %.6f is the phone's pixels per metre at the farthest zoom %.6f"
			% [MapLayoutFastSeating.FAR_PX_PER_M, along])
	_check(fails, absf(MapLayoutFastSeating.FAR_PX_PER_M_LANE - along * sin(tilt)) < 1e-9,
		"FAR_PX_PER_M_LANE %.6f is the same across the journey under the tilt"
			% MapLayoutFastSeating.FAR_PX_PER_M_LANE)
	_check(fails, _pitch_matches(MapLayoutFastSeating.INK_PITCH_PX, _ink_pitch_px(quality)),
		"INK_PITCH_PX %.2f holds two inks and the ink clearance (%.2f px)"
			% [MapLayoutFastSeating.INK_PITCH_PX, _ink_pitch_px(quality)])
	_check(fails, _pitch_matches(MapLayoutFastSeating.TOUCH_PITCH_PX, _touch_px(quality)),
		"TOUCH_PITCH_PX %.2f holds one hit region (%.2f px)"
			% [MapLayoutFastSeating.TOUCH_PITCH_PX, _touch_px(quality)])
	_check(fails, absf(MapLayoutFastSeating.COT_TILT - 1.0 / tan(tilt)) < 1e-9,
		"COT_TILT is the camera tilt's cotangent")
	var worst: float = 0.0
	for step: int in range(-120, 121):
		var angle: float = float(step) * 0.173
		worst = maxf(worst, absf(MapRavine.sine(angle) - sin(angle)))
	_check(fails, worst < 1e-10, "the ravine's sine is within %s of the engine's" % str(worst))


## The registry's ink pitch at the least two nodes' ink centres may stand: two
## ink radii and the clearance, in pixels.
static func _ink_pitch_px(quality: Dictionary) -> float:
	var clearance: float = 0.0
	for rule: Dictionary in quality["hard"]:
		if str(rule["id"]) == "node_ink_clearance_px":
			clearance = float(rule["limit"])
	return 2.0 * _ink_radius_px(quality) + clearance


static func _touch_px(quality: Dictionary) -> float:
	return maxf(float(quality["calibration"]["shipping_touch_waystone"][
		"phone_touch_floor_px"]), 2.0 * _ink_radius_px(quality))


static func _ink_radius_px(quality: Dictionary) -> float:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	return float(calibration["ink_radius_px"]) * float(calibration["default_layout_scale"])


## A constant covers the registry's figure with less than a pixel to spare.
static func _pitch_matches(constant: float, needed: float) -> bool:
	return constant >= needed and constant - needed < 1.0


## Three roads that cross one another between the same two rows would need
## three levels; the lattice never makes them, so they are built by hand here.
static func _three_crossing_roads_are_reported(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/map/map-quality-v2.json"))
	var nodes: Array = []
	var anchors: Dictionary = {}
	for column: int in range(3):
		for row: int in range(2):
			var id: String = "%d,%d" % [row, column]
			nodes.append({"id": id, "row": row, "col": column})
			anchors[id] = [5.14 * float(row), 0.0, 6.0 * float(column)]
	var edges: Array = [{"id": "e0", "from": "0,0", "to": "1,2"},
		{"id": "e1", "from": "0,1", "to": "1,1"}, {"id": "e2", "from": "0,2", "to": "1,0"}]
	var roads: Dictionary = MapLayoutFastRoads.new(nodes, edges, anchors, quality).route()
	_check(fails, roads["bridges"].size() == 3 and roads["stacked"] == ["e1"],
		"three mutually crossing roads report the one that is above and below: %s"
			% [roads["stacked"]])


static func _live_layout(fails: Array[String], content: ContentDB,
		quality: Dictionary, seed_value: int, act: int) -> void:
	var label: String = "seed %d act %d" % [seed_value, act + 1]
	var run: RunState = RunState.new_run(content, seed_value, "test-fast-layout")
	run.act = act
	var world_map: WorldMap = WorldMap.for_run(run, content)
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content)
	screen._layout_compile = _capturing_generate
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	_inputs.clear()
	screen.refresh(run)
	var result: MapLayoutResult = screen.layout_result()
	_check(fails, result != null, "%s binds: %s" % [label,
		JSON.stringify(screen.layout_failure())])
	if result == null or _inputs.size() != 1:
		tree.root.remove_child(screen)
		screen.free()
		return
	_check(fails, _generate_ms < GENERATE_GUARD_MS,
		"%s lays out in %.1f ms" % [label, _generate_ms])
	var input: MapLayoutInput = _inputs[0]
	var data: Dictionary = result.identity_dict()
	_check(fails, str(data["generator_version"]) == MapLayoutFast.VERSION
			and not MapLayoutPolicy.is_compiler_input(input),
		"%s is laid out by MapLayoutFast" % label)
	_check_geometry(fails, label, input, data, quality, act <= 1)
	_check_determinism(fails, label, input, quality, result, seed_value, act)
	_check_playable(fails, label, screen, data, quality)
	tree.root.remove_child(screen)
	screen.free()


static func _capturing_generate(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	_inputs.append(input)
	_assets = assets
	var start: int = Time.get_ticks_usec()
	var packet: Dictionary = MapLayoutPolicy.generate(input, quality, assets)
	_generate_ms = float(Time.get_ticks_usec() - start) / 1000.0
	return packet


## Every node and edge, endpoints exact, inside the governed envelopes, in
## journey order, waystones spaced and clear of every hero zone. The roads' own
## rules cost seconds to measure, so they are checked for `roads_too` (Acts I
## and II; Acts II and III lay out identically, and Act IV has no crossing).
static func _check_geometry(fails: Array[String], label: String,
		input: MapLayoutInput, data: Dictionary, quality: Dictionary,
		roads_too: bool) -> void:
	var nodes: Array = input.node_records()
	var edges: Array = input.edge_records()
	var anchors: Dictionary = data["node_anchors"]
	var routed: Dictionary = data["edges"]
	_check(fails, anchors.size() == nodes.size() and routed.size() == edges.size(),
		"%s covers %d/%d nodes and %d/%d edges" % [label, anchors.size(),
			nodes.size(), routed.size(), edges.size()])
	var bounds: Dictionary = MapQualityEvaluator.node_candidate_bounds(
		nodes, edges, quality)
	var epsilon: float = float(quality["epsilon"]["world_m"])
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		var anchor: Vector3 = _v3(anchors[id])
		var limit: Dictionary = bounds[id]
		_check(fails, anchor.x >= float(limit["min_x"]) - epsilon
				and anchor.x <= float(limit["max_x"]) + epsilon
				and anchor.z >= float(limit["min_z"]) - epsilon
				and anchor.z <= float(limit["max_z"]) + epsilon,
			"%s node %s stays inside its legal envelope" % [label, id])
	_check_waystones(fails, label, nodes, anchors, quality)
	if roads_too:
		_check_roads(fails, label, input, data, quality)
	for edge: Dictionary in edges:
		var edge_id: String = str(edge["id"])
		var route: Dictionary = routed.get(edge_id, {})
		var line: Array = route.get("centerline", [])
		_check(fails, line.size() >= 2
				and line[0] == anchors[str(edge["from"])]
				and line[-1] == anchors[str(edge["to"])],
			"%s edge %s runs anchor to anchor" % [label, edge_id])
		_check(fails, _v3(anchors[str(edge["to"])]).x - _v3(anchors[str(edge["from"])]).x
				>= float(quality["geometry"]["row_lane_envelope"][
					"minimum_forward_progress_m"]) - epsilon,
			"%s edge %s moves forward along the journey" % [label, edge_id])
	var contract: Dictionary = input.to_dict()["hero_anchor_contract"]
	var zones: Dictionary = contract["protected_zones"]
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		var rect: PackedVector2Array = MapQualityEvaluator._node_world(
			_v3(anchors[id]), quality)
		for zone_id: String in MapLayoutCanonical.sorted_keys(zones):
			var zone: Dictionary = zones[zone_id]
			var role: String = str(zone["role"])
			if MapLayoutFastSeating.exempt(str(node["type"]), role):
				continue
			var padding: float = float(quality["geometry"][
				"%s_protected_zone" % role]["padding_m"])
			_check(fails, MapQualityEvaluator._polygon_distance(rect,
					MapQualityEvaluator._poly(zone["polygon"])) >= padding - epsilon,
				"%s node %s keeps clear of %s" % [label, id, zone_id])


## Waystones clear each other at the farthest zoom on the phone, and few stand
## on a ravine's pier. The two give way to each other only where both cannot
## hold: a pair may stay close only beside a ravine (its banks leave no room),
## and a waystone may stand on a pier only where spacing needed the ravine's
## ground or the layout reports no open point for it. The lattice itself puts
## seven to eleven waystones a map there.
static func _check_waystones(fails: Array[String], label: String, nodes: Array,
		anchors: Dictionary, quality: Dictionary) -> void:
	var ink_px: float = _ink_pitch_px(quality)
	var touch_px: float = _touch_px(quality)
	var epsilon_px: float = float(quality["epsilon"]["screen_px"])
	var ids: Array = anchors.keys()
	ids.sort()
	var piers: int = 0
	for i: int in range(ids.size()):
		var a: Vector3 = _v3(anchors[ids[i]])
		if MapRavine.holds(a.x, a.z, MapRavine.PIER_MARGIN):
			piers += 1
		for j: int in range(i + 1, ids.size()):
			var b: Vector3 = _v3(anchors[ids[j]])
			var along: float = absf(a.x - b.x) * MapLayoutFastSeating.FAR_PX_PER_M
			var across: float = absf(a.z - b.z) * MapLayoutFastSeating.FAR_PX_PER_M_LANE
			var apart: bool = sqrt(along * along + across * across) >= ink_px - epsilon_px \
				and (along >= touch_px - epsilon_px or across >= touch_px - epsilon_px)
			_check(fails, apart or (MapRavine.holds(a.x, a.z, RAVINE_CROWDED_M)
					and MapRavine.holds(b.x, b.z, RAVINE_CROWDED_M)),
				"%s waystones %s and %s clear each other at the farthest zoom"
					% [label, ids[i], ids[j]])
	_check(fails, piers <= MAX_PIERS, "%s %d waystones stand on a ravine's pier" % [label, piers])


## Roads keep clear of the waystones and of each other, and where two cross the
## upper one is bridged. The fast layout does not promise every governed road
## rule, and these bounds are what it keeps: no road within its corridor of a
## waystone it does not serve, no pair of roads close without crossing, at most
## one crossing per map where the roads are too short for the governed span
## (two ramps and the whole corridor overlap), and at most one pair of branches
## per map that read as one road at the farthest zoom.
static func _check_roads(fails: Array[String], label: String, input: MapLayoutInput,
		data: Dictionary, quality: Dictionary) -> void:
	var nodes: Array = input.node_records()
	var anchors: Dictionary = data["node_anchors"]
	var edges: Dictionary = data["edges"]
	var corridor: Dictionary = quality["geometry"]["road_corridor"]
	var reach: float = float(corridor["physical_half_width_m"]) \
		+ float(corridor["world_clearance_m"])
	var epsilon: float = float(quality["epsilon"]["world_m"])
	var grazed: Array[String] = []
	for edge_id: String in edges:
		var edge: Dictionary = edges[edge_id]
		var line: Array = edge["centerline"]
		var low: Vector2 = Vector2(INF, INF)
		var high: Vector2 = Vector2(-INF, -INF)
		for point: Variant in line:
			var xz: Vector2 = Vector2(_v3(point).x, _v3(point).z)
			low = Vector2(minf(low.x, xz.x), minf(low.y, xz.y))
			high = Vector2(maxf(high.x, xz.x), maxf(high.y, xz.y))
		for node: Dictionary in nodes:
			var node_id: String = str(node["id"])
			var at: Vector3 = _v3(anchors[node_id])
			if node_id == str(edge["from"]) or node_id == str(edge["to"]) \
					or at.x < low.x - reach - 1.0 or at.x > high.x + reach + 1.0 \
					or at.z < low.y - reach - 1.0 or at.z > high.y + reach + 1.0:
				continue
			var rect: PackedVector2Array = MapQualityEvaluator._node_world(at, quality)
			for i: int in range(line.size() - 1):
				var a: Vector3 = _v3(line[i])
				var b: Vector3 = _v3(line[i + 1])
				if reach - MapQualityEvaluator._segment_polygon(Vector2(a.x, a.z),
						Vector2(b.x, b.z), rect) > epsilon:
					grazed.append("%s past %s" % [edge_id, node_id])
					break
	_check(fails, grazed.is_empty(),
		"%s roads stay clear of the waystones they do not serve: %s" % [label, grazed])
	var diagnostics: Dictionary = MapLayoutFast.compile(input, quality, _assets)[
		"diagnostics"]
	_check(fails, diagnostics["stacked_roads"].is_empty(),
		"%s no road is above one road and below another: %s"
			% [label, diagnostics["stacked_roads"]])
	var grade: Dictionary = MapGradeSeparation.evaluate(edges, quality)
	var loose: int = 0
	var short: int = 0
	for violation: Dictionary in grade["violations"]:
		if str(violation["metric_id"]) != "unrelated_edge_intersection_count":
			continue
		if str(violation["world"]["reason"]) == "insufficient_vertical_clearance":
			short += 1
		else:
			loose += 1
	_check(fails, loose == 0, "%s no two roads run close without crossing" % label)
	_check(fails, short <= 1, "%s at most one crossing lacks the governed clearance (%d)"
		% [label, short])
	_check(fails, float(grade["hard_values"]["maximum_ramp_grade"])
			<= MapGradeSeparation.MAXIMUM_RAMP_GRADE + epsilon,
		"%s no ramp is steeper than the governed grade" % label)
	var phone: Vector2i = StageShape.REFERENCES[&"phone-landscape"]
	var profile: Dictionary = {"stage": [phone.x, phone.y],
		"zoom": MapCameraRig.ZOOM_STOPS[MapCameraRig.ZOOM_STOPS.size() - 1],
		"tilt": MapCameraRig.TILT_DEGREES, "height": MapCameraRig.CAM_HEIGHT,
		"pose": [0.0, 0.0], "id": "phone-landscape/far"}
	var hard: Dictionary = MapQualityEvaluator._index(quality["hard"])
	var fanout: Dictionary = MapQualityEvaluator._fanout(profile, input.edge_records(),
		edges, quality, hard)
	_check(fails, fanout["violations"].size() <= 1,
		"%s at most one pair of branches reads as one road at the farthest zoom (%d)"
			% [label, fanout["violations"].size()])


## Same input, same digest: twice in this process, from a reordered input, and
## against the geometry another process recorded.
static func _check_determinism(fails: Array[String], label: String,
		input: MapLayoutInput, quality: Dictionary, bound: MapLayoutResult,
		seed_value: int, act: int) -> void:
	var first: Dictionary = MapLayoutFast.compile(input, quality, _assets)
	var second: Dictionary = MapLayoutFast.compile(input, quality, _assets)
	var raw: Dictionary = input.to_dict()
	var nodes: Array = raw["nodes"]
	var edges: Array = raw["edges"]
	nodes.reverse()
	edges.reverse()
	var reordered: MapLayoutInput = MapLayoutInput.from_dict(raw)
	var third: Dictionary = MapLayoutFast.compile(reordered, quality, _assets)
	var a: MapLayoutResult = first["result"]
	var b: MapLayoutResult = second["result"]
	var c: MapLayoutResult = third["result"]
	_check(fails, a.digest() == b.digest() and a.digest() == c.digest(),
		"%s repeats one digest, whatever the input order" % label)
	var data: Dictionary = bound.identity_dict()
	var geometry: String = MapLayoutCanonical.digest({
		"node_anchors": data["node_anchors"], "edges": data["edges"]})
	var key: String = "%d/%d" % [seed_value, act + 1]
	_check(fails, GOLDEN_GEOMETRY.get(key, "") == geometry,
		"%s geometry %s matches the recorded %s" % [label, geometry,
			GOLDEN_GEOMETRY.get(key, "<missing>")])


## Every reachable waystone projects on screen and a tap on it picks it; every
## node has a safe focused camera pose at every shipping shape.
static func _check_playable(fails: Array[String], label: String,
		screen: WorldMapScreen, data: Dictionary, quality: Dictionary) -> void:
	var seats: PackedVector2Array = screen.projected_seats()
	_check(fails, seats.size() == screen.map.nodes.size(),
		"%s projects every waystone" % label)
	for i: int in screen.map.reachable():
		_check(fails, i < seats.size() and screen.pick_node_at(seats[i]) == i,
			"%s reachable waystone %d is tappable" % [label, i])
	var bound: Dictionary = MapLayoutInputBinding.bind(screen.map, screen._act)
	var envelopes: Dictionary = MapQualityEvaluator.node_candidate_bounds(
		bound["nodes"], bound["edges"], quality)
	var inset: float = MapQualityEvaluator.focused_touch_inset_px(quality)
	var anchors: Dictionary = data["node_anchors"]
	for shape: StringName in StageShape.SHIPPING:
		var stage: Vector2 = Vector2(StageShape.REFERENCES[shape])
		for node: MapNode in screen.map.nodes:
			var focus: Dictionary = MapCameraRig.resolve_leading(_v3(anchors[node.id]),
				stage, MapCameraRig.ZOOM_STOPS[MapCameraRig.DEFAULT_STOP], inset,
				MapQualityEvaluator.focused_anchor_envelope(node.id, envelopes))
			_check(fails, focus.get("ok", false) == true,
				"%s %s focuses %s: %s" % [label, shape, node.id,
					JSON.stringify(focus.get("failure", {}))])


## A player's map route, with no layout hook injected, binds the fast layout
## for a seed the compiler cannot lay out at all.
static func _main_route_never_compiles(fails: Array[String], content: ContentDB) -> void:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var dispatches: int = MapLayoutPolicy.compiler_dispatches
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	main._forced_seed = 1
	main._vigil.scenes_seen.append("opening")
	var start: int = Time.get_ticks_msec()
	main._new_run()
	if main._map_screen == null or main._route_screen is DepartureStaging:
		main._show_map()
	var elapsed: int = Time.get_ticks_msec() - start
	var screen: WorldMapScreen = main._map_screen
	var result: MapLayoutResult = screen.layout_result() if screen != null else null
	_check(fails, result != null
			and str(result.identity_dict()["generator_version"]) == MapLayoutFast.VERSION,
		"the map route binds the fast layout for seed 1")
	_check(fails, MapLayoutPolicy.compiler_dispatches == dispatches,
		"the map route never dispatches to the compiler")
	_check(fails, elapsed < 20000, "the map route is ready in %d ms" % elapsed)
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func _mount(screen: WorldMapScreen, shape_name: StringName) -> void:
	var reference: Vector2i = StageShape.REFERENCES[shape_name]
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(reference)
	screen.set_shape(shape_name)
	var scene: MapScene = screen._map_scene
	scene.size = screen.size
	scene._fit()


static func _v3(value: Variant) -> Vector3:
	var row: Array = value
	return Vector3(float(row[0]), float(row[1]), float(row[2]))
