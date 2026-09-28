extends SceneTree
const Terrace = preload("res://presentation/map/map_terrace_route.gd")
const Surface = preload("res://tools/map_workshop/common/resolved_route_surface.gd")
func _initialize() -> void:
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/act3-spatial717-ordered.json"))
	var results: Dictionary = {}
	var failures: Array = []
	var edges: Dictionary = sample["edges"]
	for id: String in edges:
		var edge: Dictionary = edges[id]
		var line: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			line.append(Vector3(MapLayoutCanonical.float_value(point[0]),0,MapLayoutCanonical.float_value(point[2])))
		var a: float = _height(str(edge["from"]))
		var b: float = _height(str(edge["to"]))
		var result: Dictionary = Terrace.resolve(line,a,b,2.5)
		if result.get("ok") != true:
			failures.append({"id":id,"details":result})
			continue
		var resolved: PackedVector3Array = result["line"]
		var mesh: Dictionary = Surface.resolve(resolved,2.5,-1,.65)
		if mesh.get("ok") != true:
			failures.append({"id":id,"details":mesh})
		var points: Array = []
		for p: Vector3 in resolved:
			points.append([p.x,p.y,p.z])
		results[id] = {"centerline":points,"from":edge["from"],"to":edge["to"],"corridor_width":2.5}
	var quality: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/map/map-quality-v2.json"))
	quality["spatial_profile"] = sample["spatial_profile"].duplicate(true)
	quality["spatial_profile"]["passage"] = {"headroom_m":2.45,"deck_depth_m":.65,"maximum_grade":.55,"landing_m":1.0}
	var graded: Dictionary = MapGradeSeparation.apply(results,quality)
	var report: Dictionary = {"grade_result":graded,"source_layout_digest":sample["layout_digest"],
		"routes":results,"failures":failures,"scope":"terrace surfaces and centreline passage clearance; terrain and actual passage mesh outstanding"}
	var file: FileAccess = FileAccess.open("/tmp/act3-terrace-probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("TERRACE_PROBE routes=",results.size()," failures=",failures.size()," grade=",graded.get("ok"))
	quit(0 if failures.is_empty() and graded.get("ok") == true else 1)
func _height(id: String) -> float:
	var row: int = int(id.split(",")[0])
	return 0.0 if row < 4 else (.9 if row < 13 else 1.8)
