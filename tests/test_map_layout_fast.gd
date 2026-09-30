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
## Geometry digest (node anchors and routed edges) per "seed/act number",
## recorded by tools/probe_map_fast_layout.gd in a separate process. A change
## here is a deliberate layout change and belongs in its own commit.
const GOLDEN_GEOMETRY: Dictionary = {
	"1/1": "428ba54522f352c883b678caceb0cd972a3c4e20c2e8095fc41fcd82f2061c4c",
	"1/2": "2a615ca50974444c7a2d2aad05beb801925a84f5fae646d7c31cb3d1d4ad6d24",
	"1/3": "2a615ca50974444c7a2d2aad05beb801925a84f5fae646d7c31cb3d1d4ad6d24",
	"1/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"42/1": "73bc81221af38b5d001a0b0d5a8c79b75003f404cb6faf95349503afe9b5832a",
	"42/2": "02759e7f2cf7d250bd82832e3b7506e1ba41a54e1d0ac1154d11e52ab00da3a1",
	"42/3": "02759e7f2cf7d250bd82832e3b7506e1ba41a54e1d0ac1154d11e52ab00da3a1",
	"42/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"717/1": "f07d202dc4161fdad95e6420083c246fbc2160fc4e4332e20e0fd09d82588d61",
	"717/2": "c9a4f5d6b930861ac7f30c700658c61e404024674578fc0dd2ab6a5d6d4dee63",
	"717/3": "c9a4f5d6b930861ac7f30c700658c61e404024674578fc0dd2ab6a5d6d4dee63",
	"717/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"17634/1": "fc8cfc5500a8f6713ee203b9104179e0cdd280d0591fb594b85cc4d7c19d07f0",
	"17634/2": "fc8cfc5500a8f6713ee203b9104179e0cdd280d0591fb594b85cc4d7c19d07f0",
	"17634/3": "fc8cfc5500a8f6713ee203b9104179e0cdd280d0591fb594b85cc4d7c19d07f0",
	"17634/4": "28ede9f07c4005d86dfa1d259ff5f2db3e882558de845541db366d2549f8aa02",
	"543001/1": "72d61c708644d198548761075f97c83844c31051d50ce5246c87aae7b969b511",
	"543001/2": "5c9107452eb0b120b01ed1ad4591cbbe54b0b8bb5cfbe21e86f17670b6072536",
	"543001/3": "5c9107452eb0b120b01ed1ad4591cbbe54b0b8bb5cfbe21e86f17670b6072536",
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
	var zoom: float = MapCameraRig.ZOOM_STOPS[MapCameraRig.DEFAULT_STOP]
	var tilt: float = deg_to_rad(absf(MapCameraRig.TILT_DEGREES))
	var needed: float = (2.0 * ink + clearance) / (shortest / zoom * sin(tilt))
	_check(fails, MapLayoutFast.LANE_GAP_M >= needed
			and MapLayoutFast.LANE_GAP_M - needed < 0.01,
		"LANE_GAP_M %.4f matches the registry's default-zoom phone clearance %.4f"
			% [MapLayoutFast.LANE_GAP_M, needed])
	var along: float = (2.0 * ink + clearance) / (shortest / zoom)
	_check(fails, MapLayoutFast.ROW_GAP_M >= along
			and MapLayoutFast.ROW_GAP_M - along < 0.01,
		"ROW_GAP_M %.4f matches the same clearance along the journey %.4f"
			% [MapLayoutFast.ROW_GAP_M, along])
	_check(fails, absf(MapLayoutFast.COT_TILT - 1.0 / tan(tilt)) < 1e-9,
		"COT_TILT is the camera tilt's cotangent")


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
	_check_geometry(fails, label, input, data, quality)
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
## journey order, same-row lanes spaced and clear of every hero zone.
static func _check_geometry(fails: Array[String], label: String,
		input: MapLayoutInput, data: Dictionary, quality: Dictionary) -> void:
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
	var by_row: Dictionary = {}
	for node: Dictionary in nodes:
		var id: String = str(node["id"])
		var anchor: Vector3 = _v3(anchors[id])
		var limit: Dictionary = bounds[id]
		_check(fails, anchor.x >= float(limit["min_x"]) - epsilon
				and anchor.x <= float(limit["max_x"]) + epsilon
				and anchor.z >= float(limit["min_z"]) - epsilon
				and anchor.z <= float(limit["max_z"]) + epsilon,
			"%s node %s stays inside its legal envelope" % [label, id])
		var row: int = int(node["row"])
		if not by_row.has(row):
			by_row[row] = []
		by_row[row].append([int(node["col"]), anchor.z])
	for row_v: Variant in by_row:
		var lanes: Array = by_row[row_v]
		lanes.sort()
		for i: int in range(lanes.size() - 1):
			if int(lanes[i + 1][0]) - int(lanes[i][0]) == 1:
				_check(fails, float(lanes[i + 1][1]) - float(lanes[i][1])
						>= MapLayoutFast.LANE_GAP_M - epsilon,
					"%s row %d lanes %d and %d are spaced" % [label, int(row_v),
						int(lanes[i][0]), int(lanes[i + 1][0])])
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
			if MapLayoutFast._exempt(str(node["type"]), role):
				continue
			var padding: float = float(quality["geometry"][
				"%s_protected_zone" % role]["padding_m"])
			_check(fails, MapQualityEvaluator._polygon_distance(rect,
					MapQualityEvaluator._poly(zone["polygon"])) >= padding - epsilon,
				"%s node %s keeps clear of %s" % [label, id, zone_id])


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
