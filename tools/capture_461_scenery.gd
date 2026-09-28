extends SceneTree
## Exact #529 matrix recapture for the locked #461 Stage 1 scenery slice.

const OUTPUT_ISSUE: int = 461
const LOCALE_CODE: StringName = &"en"
const SETTLE_FRAMES: int = 4
const ZOOM_STOP: int = 2
const SHIPPING_METHOD: String = "mobile"
const HARD_ZERO_IDS: PackedStringArray = [
	"edge_scenery_corridor_penetration_m",
	"node_scenery_silhouette_overlap_area_px2",
	"node_touch_scenery_silhouette_overlap_area_px2",
	"vigil_protected_zone_intrusion_count",
	"terminus_protected_zone_intrusion_count",
]
const CASES: Array[Dictionary] = [
	{
		"act": 0, "seed": 17634,
		"frames": [
			{"shape": &"pad-landscape", "pose": "opening"},
			{"shape": &"pad-landscape", "pose": "focused"},
			{"shape": &"phone-landscape", "pose": "opening"},
			{"shape": &"phone-landscape", "pose": "focused"},
		],
	},
	{
		"act": 0, "seed": 717,
		"frames": [
			{"shape": &"pad-landscape", "pose": "opening"},
			{"shape": &"pad-landscape", "pose": "focused"},
			{"shape": &"phone-landscape", "pose": "opening"},
			{"shape": &"phone-landscape", "pose": "focused"},
			{"shape": &"pad-landscape", "pose": "travel-midpoint"},
		],
	},
	{
		"act": 1, "seed": 717,
		"frames": [{"shape": &"pad-landscape", "pose": "opening"}],
	},
	{
		"act": 2, "seed": 717,
		"frames": [{"shape": &"phone-landscape", "pose": "focused"}],
	},
	{
		"act": 3, "seed": 717,
		"frames": [{"shape": &"pad-landscape", "pose": "focused"}],
	},
]

var _output_dir: String = ""
var _capture_head: String = ""
var _expected_manifest_sha256: String = ""
var _candidate_diff_sha256: String = ""
var _capture_command: String = ""
var _runtime_method: String = ""
var _shipping_method: String = ""
var _frames: Array[Dictionary] = []
var _compile_seconds: Array[Dictionary] = []
var _next_frame: int = 1
var _started_msec: int = 0


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	var parse_error: String = _parse_args()
	if not parse_error.is_empty():
		printerr("capture_461_scenery: " + parse_error)
		quit(2)
		return
	_runtime_method = str(RenderingServer.get_current_rendering_method())
	_shipping_method = str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", ""))
	if _shipping_method != SHIPPING_METHOD or _runtime_method != _shipping_method:
		printerr("capture_461_scenery: runtime %s does not match shipping %s" % [
			_runtime_method, _shipping_method])
		quit(2)
		return
	print("capture_461_scenery: runtime_rendering_method=%s source=RenderingServer" \
		% _runtime_method)
	var asset_manifest_path: String = MapMaterials.MANIFEST_PATH
	var manifest_sha256: String = FileAccess.get_sha256(asset_manifest_path)
	if manifest_sha256 != _expected_manifest_sha256:
		printerr("capture_461_scenery: asset manifest changed")
		quit(2)
		return
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		_absolute(_output_dir.path_join("raw")))
	if make_error != OK:
		printerr("capture_461_scenery: cannot create output: " + error_string(make_error))
		quit(2)
		return

	Locale.active = Locale.new(LOCALE_CODE)
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	for case: Dictionary in CASES:
		var capture_error: Error = await _capture_case(content, case)
		if capture_error != OK:
			quit(1)
			return
	var manifest: Dictionary = {
		"schema": 1, "issue": OUTPUT_ISSUE, "stage": 1,
		"capture_head": _capture_head,
		"base_head": _capture_head,
		"candidate_tracked_diff_sha256": _candidate_diff_sha256,
		"capture_command": _capture_command,
		"capture_command_rendering_override": false,
		"capture_runtime_seconds": float(
			Time.get_ticks_msec() - _started_msec) / 1000.0,
		"godot": Engine.get_version_info()["string"],
		"display_server": DisplayServer.get_name(),
		"rendering_method": _runtime_method,
		"rendering_method_source": "RenderingServer.get_current_rendering_method()",
		"shipping_rendering_method": _shipping_method,
		"asset_manifest": {
			"path": asset_manifest_path, "sha256": manifest_sha256,
		},
		"locale": String(LOCALE_CODE),
		"matrix_source": "docs/reviews/529/manifest.json",
		"comparison_source": "docs/reviews/461-scenery/manifest.json",
		"compiler_input_count": CASES.size(),
		"expected_frame_count": 12,
		"frame_count": _frames.size(),
		"compile_wall_clock": _compile_seconds,
		"frames": _frames,
	}
	var write_error: Error = _write_json(
		_absolute(_output_dir.path_join("manifest.json")), manifest)
	if write_error != OK:
		printerr("capture_461_scenery: manifest write failed: " + error_string(write_error))
		quit(1)
		return
	print("capture_461_scenery: %d frames, %d inputs -> %s" % [
		_frames.size(), CASES.size(), _absolute(_output_dir)])
	quit(0)


func _capture_case(content: ContentDB, case: Dictionary) -> Error:
	var act: int = MapLayoutCanonical.int_value(case["act"])
	var seed: int = MapLayoutCanonical.int_value(case["seed"])
	var specs: Array = case["frames"]
	var first: Dictionary = specs[0]
	var first_shape: StringName = StringName(str(first["shape"]))
	var run: RunState = RunState.new_run(content, seed, "capture-461-scenery-mobile")
	run.act = act
	var world: WorldMap = WorldMap.for_run(run, content)
	var rng_after_map: int = run.rng_state()
	if world.nodes.size() < 2:
		printerr("capture_461_scenery: act %d seed %d has no two-node path" % [
			act + 1, seed])
		return ERR_INVALID_DATA
	world.at = 1
	world.cleared = {0: true, 1: true}

	await _set_shape(first_shape)
	var screen: WorldMapScreen = WorldMapScreen.new(world, content, first_shape)
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.position = Vector2.ZERO
	screen.size = Vector2(StageShape.REFERENCES[first_shape])
	var compile_started: int = Time.get_ticks_msec()
	screen.refresh(run)
	await process_frame
	await process_frame
	var result: MapLayoutResult = screen.layout_result()
	if result == null:
		printerr("capture_461_scenery: compile failed for act %d seed %d: %s" % [
			act + 1, seed, screen.layout_failure()])
		root.remove_child(screen)
		screen.free()
		return ERR_INVALID_DATA
	var serial: Dictionary = result.to_dict()
	var scenery: Dictionary = serial["scenery_instances"]
	var zone_counts: Dictionary = {}
	for placement_v: Variant in scenery.values():
		var placement: Dictionary = placement_v
		var zone_id: String = str(placement["semantic_zone"])
		zone_counts[zone_id] = MapLayoutCanonical.int_value(
			zone_counts.get(zone_id, 0)) + 1
	var hard: Dictionary = serial["hard_measurements"]
	var hard_zero: Dictionary = {}
	for metric_id: String in HARD_ZERO_IDS:
		hard_zero[metric_id] = hard.get(metric_id)
	_compile_seconds.append({
		"act": act + 1, "seed": seed,
		"seconds": float(Time.get_ticks_msec() - compile_started) / 1000.0,
		"input_digest": screen.layout_input_digest(),
		"layout_digest": screen.layout_digest(),
		"scenery_count": scenery.size(),
		"zone_counts": MapLayoutCanonical.ordered_dictionary(zone_counts),
		"hard_zero_metrics": MapLayoutCanonical.ordered_dictionary(hard_zero),
	})
	screen.set_process(false)

	for spec_v: Variant in specs:
		var spec: Dictionary = spec_v
		var frame_error: Error = await _capture_frame(
			screen, run, world, act, seed, rng_after_map, spec)
		if frame_error != OK:
			root.remove_child(screen)
			screen.free()
			return frame_error
	root.remove_child(screen)
	screen.free()
	await process_frame
	return OK


func _capture_frame(
		screen: WorldMapScreen, run: RunState, world: WorldMap,
		act: int, seed: int, rng_after_map: int, spec: Dictionary
) -> Error:
	var shape: StringName = StringName(str(spec["shape"]))
	var pose: String = str(spec["pose"])
	var viewport: Vector2i = StageShape.REFERENCES[shape]
	await _set_shape(shape)
	screen.set_shape(shape)
	screen.size = Vector2(viewport)
	screen.refresh(run)
	await process_frame
	var scene: MapScene = screen._map_scene
	if scene == null:
		return ERR_DOES_NOT_EXIST
	scene._fit()
	var rig: MapCameraRig = scene.get_rig()
	rig.set_zoom_stop(ZOOM_STOP)
	var travel_edge: String = ""
	var travel_world: Vector3 = Vector3.INF
	if pose == "opening":
		rig.set_camera_xz(MapCameraRig.DEFAULT_XZ)
	elif pose == "focused":
		screen.refresh(run)
	elif pose == "travel-midpoint":
		screen.refresh(run)
		screen.set("_travel_from_i", 0)
		screen.set("_travelling", true)
		screen.set("_travel_t", 0.5)
		travel_edge = MapLayoutInput.edge_id(world.nodes[0].id, world.nodes[1].id)
		travel_world = screen.marker_world_position()
	else:
		return ERR_INVALID_PARAMETER
	scene._fit()
	screen._layout_waystones()
	screen._push_bands(true)
	scene.set_live(true)
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null or image.get_width() != viewport.x \
			or image.get_height() != viewport.y:
		return ERR_INVALID_DATA
	var filename: String = "act-%02d_seed-%08d_shape-%s_zoom-02-20_pose-%s_locale-en.png" % [
		act + 1, seed, String(shape), pose]
	var relative: String = "raw/" + filename
	var save_error: Error = image.save_png(_absolute(_output_dir.path_join(relative)))
	if save_error != OK:
		return save_error
	var assets: Array[String] = []
	for path: String in scene.active_asset_paths():
		assets.append(path)
	assets.sort()
	var route_counts: Dictionary = {"cold": 0, "open": 0, "walked": 0}
	for state_v: Variant in screen._route_states().values():
		var state: String = str(state_v)
		route_counts[state] = MapLayoutCanonical.int_value(
			route_counts.get(state, 0)) + 1
	var camera: Vector2 = rig.camera_xz()
	var scenery: Dictionary = screen.layout_result().to_dict()["scenery_instances"]
	var frame: Dictionary = {
		"frame_id": "F%03d" % _next_frame, "file": relative,
		"act": act + 1, "act_index": act, "seed": seed,
		"generated_act": act < 3, "shape": String(shape),
		"viewport": {"width": viewport.x, "height": viewport.y},
		"zoom_stop": ZOOM_STOP, "zoom_size": MapCameraRig.ZOOM_STOPS[ZOOM_STOP],
		"pose": pose, "camera_xz": {"x": camera.x, "z": camera.y},
		"locale": String(LOCALE_CODE), "map_region": world.region,
		"map_at": world.at, "node_count": world.nodes.size(),
		"reachable_count": world.reachable().size(),
		"rng_state_after_map": rng_after_map, "active_asset_paths": assets,
		"input_digest": screen.layout_input_digest(),
		"layout_digest": screen.layout_digest(),
		"route_state_counts": route_counts, "waylight_count": scene._waylights.size(),
		"scenery_count": scenery.size(),
	}
	if pose == "travel-midpoint":
		frame["travel_edge"] = travel_edge
		frame["travel_progress"] = 0.5
		frame["travel_world"] = {
			"x": travel_world.x, "y": travel_world.y, "z": travel_world.z}
	_frames.append(frame)
	_next_frame += 1
	scene.set_live(false)
	if pose == "travel-midpoint":
		screen.set("_travelling", false)
		screen.set("_travel_from_i", -1)
	await process_frame
	print("capture_461_scenery: " + filename)
	return OK


func _set_shape(shape: StringName) -> void:
	var size: Vector2i = StageShape.REFERENCES[shape]
	DisplayServer.window_set_size(size)
	root.size = size
	root.content_scale_size = size
	await process_frame
	await process_frame


func _parse_args() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_output_dir = arg.trim_prefix("--output=")
		elif arg.begins_with("--capture-head="):
			_capture_head = arg.trim_prefix("--capture-head=").to_lower()
		elif arg.begins_with("--asset-manifest-sha256="):
			_expected_manifest_sha256 = arg.trim_prefix(
				"--asset-manifest-sha256=").to_lower()
		elif arg.begins_with("--candidate-diff-sha256="):
			_candidate_diff_sha256 = arg.trim_prefix(
				"--candidate-diff-sha256=").to_lower()
		elif arg.begins_with("--capture-command="):
			_capture_command = arg.trim_prefix("--capture-command=")
	if _output_dir.is_empty():
		return "missing --output=PATH"
	if _capture_head.length() != 40 or _expected_manifest_sha256.length() != 64:
		return "capture head or asset manifest digest is malformed"
	if _candidate_diff_sha256.length() != 64 or _capture_command.is_empty():
		return "candidate diff or capture command is missing"
	return ""


func _write_json(path: String, value: Variant) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()
	return OK


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) \
		if path.begins_with("res://") or path.begins_with("user://") else path
