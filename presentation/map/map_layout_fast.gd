class_name MapLayoutFast
extends RefCounted
## The production world layout: bounded, search-free and deterministic.
##
## Every node stands on its authored lattice seat (row and column plus the
## run's own jitter, the same seat the compiler's first candidate proposes),
## moved off a hero's keep-out box or a ravine and spaced from its neighbours so
## their waystones clear each other at the farthest zoom on the phone
## (`MapLayoutFastSeating`).
##
## Every edge is one gently curved road, kept clear of the waystones and of the
## other roads, with the governed bridge where two must cross
## (`MapLayoutFastRoads`).
##
## The work is bounded: the seating's fixed sweeps and grids, and the roads' few
## passes over a fixed set of neighbouring roads. There is no search, no retry
## and no failure mode for a valid input. The geometry uses only IEEE arithmetic and
## square roots, never a transcendental function, so the same canonical input
## gives the same result digest on every device.
##
## Map Compiler v2 (`MapLayoutCompiler`) remains available as an authoring
## opt-in through `MapLayoutPolicy`; see docs/map/production-layout.md.

const COMPILED: String = MapLayoutCompiler.COMPILED
const SCHEMA: String = "map-fast-layout-v1"
const VERSION: String = "map-layout-fast-v1"
const SELECTED_CANDIDATE_ID: String = "fast/authored-lattice"

@warning_ignore_start("unsafe_call_argument")


static func compile(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = {
		"schema_version": 1, "version": VERSION,
		"input_digest": "" if input == null else input.digest(),
		"spaced_nodes": [], "displaced_nodes": {}, "unresolved_nodes": [],
		"bridges": [],
	}
	if input == null:
		return _failure(diagnostics, "input", "validated input is null")
	var source: Dictionary = input.to_dict()
	var nodes: Array = input.node_records()
	var edge_rows: Array = input.edge_records()
	var bounds: Dictionary = MapQualityEvaluator.node_candidate_bounds(
		nodes, edge_rows, quality)
	var half: Vector2 = _v2(quality["calibration"]["shipping_touch_waystone"][
		"node_pair_half_extent_m"])
	var seated: Dictionary = MapLayoutFastSeating.new(nodes, bounds, source, quality,
			assets, half).seat()
	var anchors: Dictionary = {}
	for node: Dictionary in nodes:
		var node_id: String = str(node["id"])
		var seat: Dictionary = seated[node_id]
		anchors[node_id] = seat["anchor"]
		if seat["status"] == "spaced":
			diagnostics["spaced_nodes"].append(node_id)
		elif seat["status"] == "displaced":
			diagnostics["displaced_nodes"][node_id] = seat["displacement_m"]
		elif seat["status"] == "unresolved":
			diagnostics["unresolved_nodes"].append(node_id)
	var roads: Dictionary = MapLayoutFastRoads.new(nodes, edge_rows, anchors, quality).route()
	var edges: Dictionary = roads["edges"]
	diagnostics["bridges"] = roads["bridges"]
	var result: MapLayoutResult = MapLayoutResult.create({
		"schema_version": MapLayoutResult.SCHEMA_VERSION,
		"generator_version": source["generator_version"],
		"node_anchors": MapLayoutCanonical.ordered_dictionary(anchors),
		"edges": MapLayoutCanonical.ordered_dictionary(edges),
		"hero_placements": _heroes(source),
		"scenery_instances": {},
		"hard_measurements": {},
		"soft_scores": {},
		"selected_restart_id": 0,
		"selected_candidate_id": SELECTED_CANDIDATE_ID,
		"input_digest": input.digest(),
	})
	if result == null:
		return _failure(diagnostics, "result_contract",
			"fast layout produced an invalid result")
	return {
		"status": COMPILED, "result": result, "report": {}, "failure": {},
		"diagnostics": MapLayoutCanonical.ordered_dictionary(diagnostics),
	}


static func _heroes(source: Dictionary) -> Dictionary:
	var anchors: Dictionary = source["hero_anchor_contract"]["anchors"]
	var out: Dictionary = {}
	for anchor_id: String in MapLayoutCanonical.sorted_keys(anchors):
		var anchor: Dictionary = anchors[anchor_id]
		out[anchor_id] = {
			"asset_id": anchor["asset_id"], "profile_id": anchor["profile_id"],
			"transform": {
				"origin": anchor["position"], "yaw_radians": anchor["yaw_radians"],
				"scale": anchor["scale"],
			},
		}
	return MapLayoutCanonical.ordered_dictionary(out)


static func _failure(diagnostics: Dictionary, id: String, reason: String) -> Dictionary:
	return {
		"status": MapLayoutCompiler.NO_FEASIBLE_NODE_ROUTE_LAYOUT,
		"result": null, "report": {},
		"failure": {"kind": "fast_layout", "id": id, "reason": reason},
		"diagnostics": MapLayoutCanonical.ordered_dictionary(diagnostics),
	}


static func _v2(value: Variant) -> Vector2:
	var row: Array = value
	return Vector2(_f(row[0]), _f(row[1]))


static func _f(value: Variant) -> float:
	return MapLayoutCanonical.float_value(value)
