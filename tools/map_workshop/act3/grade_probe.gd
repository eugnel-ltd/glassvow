extends SceneTree
## Reuse an exact routed sample to falsify passage feasibility without rerouting.
func _initialize() -> void:
	var sample_path: String = ""
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="):
			sample_path = arg.trim_prefix("--sample=")
		elif arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sample_path))
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/map/map-quality-v2.json"))
	quality["spatial_profile"] = sample["spatial_profile"].duplicate(true)
	quality["spatial_profile"]["passage"] = {"headroom_m": 2.45,
		"deck_depth_m": .65, "maximum_grade": .55, "landing_m": 1.0}
	var routes: Dictionary = sample["edges"].duplicate(true)
	for edge: Dictionary in routes.values():
		for point: Array in edge["centerline"]:
			point[1] = 0.0
	var report: Dictionary = MapGradeSeparation.apply(routes, quality)
	report["source_layout_digest"] = sample["layout_digest"]
	report["quality_digest"] = MapLayoutCanonical.digest(quality)
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ARCHITECTURAL_GRADE_PROBE ok=", report.get("ok"), " report=", output)
	quit(0 if report.get("ok") == true else 1)
