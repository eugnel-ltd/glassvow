extends SceneTree
## Production map layout timing and digest probe (docs/map/production-layout.md).
##
##   godot --headless -s res://tools/probe_map_fast_layout.gd -- \
##       [--seeds=1,42,717,17634,543001] [--budget-ms=200]
##
## For every seed and every act it binds a live WorldMapScreen through the
## production path and prints one `DIGEST` line (seed, act, input digest,
## layout digest, geometry digest) and one `TIME` line. Two processes must
## print identical `DIGEST` lines; `diff <(grep ^DIGEST a) <(grep ^DIGEST b)`.
## Exits 1 when a layout fails to bind, uses the compiler, or its generator
## call exceeds the budget.

const DEFAULT_SEEDS: Array[int] = [1, 42, 717, 17634, 543001]

var _generate_usec: int = 0


func _initialize() -> void:
	var seeds: Array[int] = DEFAULT_SEEDS.duplicate()
	var budget_ms: float = 200.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds.clear()
			for part: String in arg.trim_prefix("--seeds=").split(",", false):
				if not part.is_valid_int():
					return _fail("Expected --seeds=<int,int,...>")
				seeds.append(int(part))
		elif arg.begins_with("--budget-ms=") and arg.get_slice("=", 1).is_valid_float():
			budget_ms = float(arg.get_slice("=", 1))
		else:
			return _fail("Unknown argument: " + arg)
	if MapLayoutPolicy.compiler_requested():
		return _fail("The compiler opt-in is set; this probe measures production")
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	var worst_ms: float = 0.0
	var worst_bind_ms: float = 0.0
	var cases: int = 0
	for seed_value: int in seeds:
		for act: int in range(4):
			var run: RunState = RunState.new_run(content, seed_value, "probe-fast-layout")
			run.act = act
			var world_map: WorldMap = WorldMap.for_run(run, content)
			var screen: WorldMapScreen = WorldMapScreen.new(world_map, content,
				&"pad-landscape")
			screen._layout_compile = _timed_generate
			root.add_child(screen)
			_generate_usec = -1
			var start: int = Time.get_ticks_usec()
			screen.refresh(run)
			var bind_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
			var result: MapLayoutResult = screen.layout_result()
			var generate_ms: float = float(_generate_usec) / 1000.0
			if result == null:
				return _fail("seed %d act %d did not bind: %s" % [seed_value, act + 1,
					JSON.stringify(screen.layout_failure())])
			var data: Dictionary = result.identity_dict()
			if str(data["generator_version"]) != MapLayoutFast.VERSION:
				return _fail("seed %d act %d was not laid out by MapLayoutFast" % [
					seed_value, act + 1])
			var geometry: String = MapLayoutCanonical.digest({
				"node_anchors": data["node_anchors"], "edges": data["edges"]})
			print("DIGEST seed=%d act=%d nodes=%d edges=%d input=%s layout=%s geometry=%s" % [
				seed_value, act + 1, data["node_anchors"].size(), data["edges"].size(),
				screen.layout_input_digest(), result.digest(), geometry])
			print("TIME seed=%d act=%d generate_ms=%.2f refresh_ms=%.2f scenery=%d" % [
				seed_value, act + 1, generate_ms, bind_ms,
				MapLayoutCanonical.int_value(
					screen._map_scene.layout_diagnostics().get("accepted_count", 0))])
			root.remove_child(screen)
			screen.free()
			worst_ms = maxf(worst_ms, generate_ms)
			worst_bind_ms = maxf(worst_bind_ms, bind_ms)
			cases += 1
			if generate_ms < 0.0 or generate_ms > budget_ms:
				return _fail("seed %d act %d generator took %.2f ms (budget %.0f ms)" % [
					seed_value, act + 1, generate_ms, budget_ms])
	if MapLayoutPolicy.compiler_dispatches != 0:
		return _fail("the production path dispatched to the compiler")
	print("fast layout OK (%d layouts, worst generate %.2f ms, worst refresh %.2f ms, budget %.0f ms)"
		% [cases, worst_ms, worst_bind_ms, budget_ms])
	quit(0)


func _timed_generate(input: MapLayoutInput, quality: Dictionary,
		assets: Dictionary) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var packet: Dictionary = MapLayoutPolicy.generate(input, quality, assets)
	_generate_usec = Time.get_ticks_usec() - start
	return packet


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
