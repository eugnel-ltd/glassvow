extends RefCounted
## #461 locked slice: post-route compiler-owned scenery placement.

const Binding = preload("res://domain/map_layout/map_layout_input_binding.gd")
const CORPUS: Array[Array] = [
	[717, 0], [17634, 0],
	[717, 1], [17634, 1],
	[717, 2], [17634, 2],
	[717, 3],
]
const HARD_ZERO_IDS: PackedStringArray = [
	"edge_scenery_corridor_penetration_m",
	"node_scenery_silhouette_overlap_area_px2",
	"node_touch_scenery_silhouette_overlap_area_px2",
	"vigil_protected_zone_intrusion_count",
	"terminus_protected_zone_intrusion_count",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_layout_scenery: %s" % what)


static func run(fails: Array[String]) -> void:
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	var authored_zones: Dictionary = {}
	for row: Dictionary in quality["zones"]:
		authored_zones[str(row["id"])] = true
	var content: ContentDB = ContentDB.load_full()
	var scene: MapScene = MapScene.new()
	var replay_checked: bool = false
	for fixture: Array in CORPUS:
		var seed: int = fixture[0]
		var act: int = fixture[1]
		var label: String = "Act %d seed %d" % [act + 1, seed]
		scene.set_scatter_salt(seed)
		scene.set_act(act)
		var assets: Dictionary = scene.layout_asset_bundle()
		var heroes: Dictionary = scene.layout_hero_contract()
		var run_state: RunState = RunState.new_run(content, seed,
			"map-scenery-%d-%d" % [seed, act])
		run_state.act = act
		var world: WorldMap = WorldMap.for_run(run_state, content)
		var bound: Dictionary = Binding.bind(world, act)
		var bound_ok_v: Variant = bound.get("ok", false)
		var bound_ok: bool = bound_ok_v is bool and bound_ok_v
		_check(fails, bound_ok,
			"%s binds production graph records" % label)
		if not bound_ok:
			continue
		var nodes: Array = bound["nodes"]
		var edges: Array = bound["edges"]
		var input: MapLayoutInput = _input(
			nodes, edges, seed, act, heroes, quality, assets)
		var compiled: Dictionary = MapLayoutCompiler.compile(input, quality, assets)
		var result_v: Variant = compiled.get("result", null)
		_check(fails, str(compiled.get("status", "")) == MapLayoutCompiler.COMPILED
				and result_v is MapLayoutResult,
			"%s compiles with scenery: %s" % [label, compiled.get("failure", {})])
		if not result_v is MapLayoutResult:
			continue
		var result: MapLayoutResult = result_v
		var serial: Dictionary = result.to_dict()
		var scenery: Dictionary = serial["scenery_instances"]
		var count: int = scenery.size()
		var zone_counts: Dictionary = {}
		var all_real_zones: bool = true
		for placement_id: String in MapLayoutCanonical.sorted_keys(scenery):
			var placement: Dictionary = scenery[placement_id]
			var zone_id: String = str(placement["semantic_zone"])
			all_real_zones = all_real_zones and authored_zones.has(zone_id)
			zone_counts[zone_id] = MapLayoutCanonical.int_value(
				zone_counts.get(zone_id, 0)) + 1
		var max_zone_count: int = 0
		for value_v: Variant in zone_counts.values():
			max_zone_count = maxi(max_zone_count,
				MapLayoutCanonical.int_value(value_v))
		_check(fails, count > 0,
			"%s compiler result owns non-empty scenery before renderer bind" % label)
		_check(fails, act == 3 or count >= 14,
			"%s generated density stays at or above 14 (got %d)" % [label, count])
		_check(fails, count <= 24 and float(max_zone_count) / float(count) <= 0.6,
			"%s stays at or below 24 and below the 60%% per-zone ceiling: %s" \
			% [label, zone_counts])
		_check(fails, all_real_zones and (act == 3 or zone_counts.size() >= 3),
			"%s uses authored zone IDs and at least three generated zones: %s" \
			% [label, zone_counts])
		var hard: Dictionary = serial["hard_measurements"]
		for metric_id: String in HARD_ZERO_IDS:
			_check(fails, hard.has(metric_id)
					and MapLayoutCanonical.float_value(hard[metric_id]) == 0.0,
				"%s keeps %s at zero across governed profiles" % [label, metric_id])
		if not replay_checked:
			var replay_anchors: Dictionary = serial["node_anchors"]
			var replay_edges: Dictionary = serial["edges"]
			var replay: Dictionary = MapLayoutCompiler._scenery_instances(
				input, input.to_dict(), replay_anchors, replay_edges,
				assets, quality)
			var replay_ok_v: Variant = replay.get("ok", false)
			var replay_ok: bool = replay_ok_v is bool and replay_ok_v
			var replay_placements: Dictionary = replay.get("placements", {})
			_check(fails, replay_ok and replay_placements == scenery
					and replay_placements.keys() == scenery.keys(),
				"same exact inputs reproduce scenery key order and transforms")
			replay_checked = true
		var rendered: MapLayoutResult = scene.bind_layout(result, quality)
		var live: Dictionary = scene.layout_diagnostics()
		var live_scenery: Dictionary = live.get("scenery_instances", {})
		_check(fails, rendered == result and rendered.digest() == result.digest()
				and live_scenery == scenery
				and MapLayoutCanonical.int_value(
					live.get("compiled_scenery_count", -1)) == count,
			"%s renderer preserves compiled scenery and layout identity" % label)
		var scenery_order_digest: String = MapLayoutCanonical.digest(
			[scenery.keys(), scenery])
		print("SCENERY_CORPUS act=%d seed=%d count=%d zones=%s digest=%s scenery_order_digest=%s" % [
			act + 1, seed, count, str(zone_counts), result.digest(),
			scenery_order_digest])
	_renderer_has_no_scenery_authority(fails, scene)
	scene.free()


static func _renderer_has_no_scenery_authority(fails: Array[String],
		scene: MapScene) -> void:
	var forbidden_method: StringName = StringName("_scenery_" + "candidates")
	var scene_source: String = FileAccess.get_file_as_string(
		"res://presentation/map/map_scene.gd")
	_check(fails, not scene.has_method(forbidden_method)
			and not scene_source.contains("func " + str(forbidden_method))
			and not scene_source.contains("_scenery_" + "rejection"),
		"MapScene has no scenery candidate or rejection authority")
	var forbidden_zone: String = "existing" + "-seat"
	var presentation_dir: DirAccess = DirAccess.open("res://presentation/map")
	var found_forbidden_zone: bool = false
	if presentation_dir != null:
		presentation_dir.list_dir_begin()
		var name: String = presentation_dir.get_next()
		while name != "":
			if not presentation_dir.current_is_dir() and name.ends_with(".gd"):
				found_forbidden_zone = found_forbidden_zone or FileAccess.get_file_as_string(
					"res://presentation/map/%s" % name).contains(forbidden_zone)
			name = presentation_dir.get_next()
		presentation_dir.list_dir_end()
	_check(fails, not found_forbidden_zone,
		"the retired renderer-side semantic-zone literal is absent")


static func _input(nodes: Array, edges: Array, seed: int, act: int,
		heroes: Dictionary, quality: Dictionary, assets: Dictionary) -> MapLayoutInput:
	return MapLayoutInput.from_dict({
		"schema_version": MapLayoutInput.SCHEMA_VERSION,
		"generator_schema": "map-compiler-v2",
		"generator_version": MapLayoutCompiler.VERSION,
		"nodes": nodes,
		"edges": edges,
		"act": act,
		"run_seed": seed,
		"scenery_seed": seed + WorldMapScreen.SCENERY_SEED_OFFSET,
		"asset_profile_digest": assets["digest"],
		"camera_profile_digest": MapQualityEvaluator.camera_registry(
			nodes, quality, edges)["digest"],
		"hero_anchor_contract": heroes,
		"quality_registry_digest": MapLayoutCanonical.digest(quality),
	})
