extends SceneTree
## The floor bake's GPU half (R3.2, issue #660), on a real renderer: boots the
## game onto Act I's map, waits for its land and floor, and checks what the
## headless suite cannot (`tests/test_map_floor.gd` holds the rest):
## - the floor baked and drew every ground chunk, and the bake's views and
##   world are gone;
## - the lit picture is the land's size at its texels a metre with its full mip
##   chain, each level the mean (as light) of the one below; it has a picture
##   in it, and no seam where its tiles meet;
## - the mask's pools, phases and wet are in range, a phase per lamp;
## - the bake took a frame a pair of tiles and four more, and no step of it
##   held the main thread long; paced (the prefetch's, under a lit title), a
##   frame a tile and four more;
## - letting the land go frees the floor's textures.
## Exits 0 on a pass, 1 on a failure, 2 under `--headless` (no RenderingDevice).
## Pass the game's map flags after `--`, as the capture tools do:
##   godot --path . -s res://tools/check_floor_bake.gd -- --map --seed=1 --map-steps=2

const LandFloor = preload("res://presentation/map/landscape/land_floor.gd")
const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
## The most one step of the bake may hold the main thread (ms).
const STEP_LIMIT_MS: float = 40.0

var _fails: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("check_floor_bake: needs a real renderer (no --headless)")
		quit(2)
		return
	MapScene.lean_override = 1
	change_scene_to_file("res://application/main.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _run() -> void:
	var screen: WorldMapScreen = null
	for _i: int in range(6000):
		await process_frame
		var found: Variant = current_scene.get("_map_screen") if current_scene != null else null
		if found is WorldMapScreen and is_instance_valid(found):
			var candidate: WorldMapScreen = found
			if not candidate.landscape_pending():
				screen = candidate
				break
	if screen == null:
		_check(false, "the map opened with Act I's land")
		_finish()
		return
	for _i: int in range(12):
		await process_frame
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	var floor_node: LandFloor = land.forest_floor
	_check(floor_node.state == LandFloor.State.BAKED, "the floor baked (%s)" % floor_node.failure)
	if floor_node.state != LandFloor.State.BAKED:
		_finish()
		return
	var drawn: bool = true
	for chunk: MeshInstance3D in land.terrain.chunks:
		drawn = drawn and chunk.material_override == floor_node.material
	_check(drawn, "every ground chunk draws the baked floor")
	_check(root.get_node_or_null("Floor bake") == null, "the bake's views and world are freed")
	var bake: Dictionary = floor_node.timings_ms.get("bake", {})
	var steps: PackedFloat32Array = bake.get("steps_ms", PackedFloat32Array())
	var longest: float = 0.0
	for ms: float in steps:
		longest = maxf(longest, ms)
	var frames: int = int(str(bake.get("frames", 0)))
	var tiles: int = int(str(bake.get("tiles", 0)))
	_check(frames == ceili(tiles / float(Bake.TILES_A_FRAME)) + 4 and longest < STEP_LIMIT_MS,
		"the bake spans its frames (%d) and no step holds the main thread past %d ms (%.1f)" % [
			frames, STEP_LIMIT_MS, longest])
	var rids: Array[RID] = floor_node._rids.duplicate()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	var bounds: Rect2 = floor_node.plan.bounds
	var size: Vector2i = Vector2i(ceili(bounds.size.x * Bake.LIT_TEXELS_PER_M), ceili(bounds.size.y * Bake.LIT_TEXELS_PER_M))
	var format: RDTextureFormat = rd.texture_get_format(rids[0])
	_check(format.width == size.x and format.height == size.y and format.mipmaps == Bake.mip_count(size),
		"the lit picture is %dx%d with %d levels" % [format.width, format.height, format.mipmaps])
	var data: PackedByteArray = rd.texture_get_data(rids[0], 0)
	var level0: Image = _level(data, size, 0)
	var level1: Image = _level(data, size, 1)
	_check(_spread(level0) > 0.02, "the lit picture has a picture in it")
	_check(_means(level0, level1) < 0.02, "a mip level is the mean, as light, of the one below")
	_check(_seams(level0, Bake.tiles(size, Bake.TILE_LIMIT)) < 2.5, "no seam where the tiles meet")
	var paced: Bake = Bake.new(land, floor_node.plan, true)
	var paced_steps: int = 0
	while not paced.advance():
		paced_steps += 1
		await process_frame
	var paced_longest: float = 0.0
	for ms: float in paced.timings.get("steps_ms", PackedFloat32Array()):
		paced_longest = maxf(paced_longest, ms)
	_check(paced.step == Bake.Step.DONE and int(str(paced.timings.get("frames", 0))) == tiles + 4
		and paced_longest < STEP_LIMIT_MS,
		"paced, the bake takes a frame a tile and four more (%d), no step past %d ms (%.1f)" % [
			int(str(paced.timings.get("frames", 0))), STEP_LIMIT_MS, paced_longest])
	paced.cancel()
	var mask_size: Vector2i = Vector2i(ceili(bounds.size.x * Bake.MASK_TEXELS_PER_M), ceili(bounds.size.y * Bake.MASK_TEXELS_PER_M))
	var mask: Image = Image.create_from_data(mask_size.x, mask_size.y, false, Image.FORMAT_RGBA8,
		rd.texture_get_data(rids[1], 0).slice(0, mask_size.x * mask_size.y * 4))
	_mask(mask, floor_node.plan.lamps.size())
	current_scene.call("_clear_route")
	var keep: Variant = current_scene.get("_map_keep")
	if keep is MapScreenKeep:
		var kept: MapScreenKeep = keep
		kept.release()
	MapJourneyPrefetch.release()
	for _i: int in range(4):
		await process_frame
	_check(not rd.texture_is_valid(rids[0]) and not rd.texture_is_valid(rids[1]),
		"letting the land go frees the floor's textures")
	_finish()


func _finish() -> void:
	print("FLOOR_BAKE_CHECK %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)


static func _level(data: PackedByteArray, size: Vector2i, level: int) -> Image:
	var offset: int = 0
	for k: int in range(level):
		var s: Vector2i = Bake.mip_size(size, k)
		offset += s.x * s.y * 4
	var at: Vector2i = Bake.mip_size(size, level)
	return Image.create_from_data(at.x, at.y, false, Image.FORMAT_RGBA8, data.slice(offset, offset + at.x * at.y * 4))


static func _light(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


## The spread of the picture's light, sampled.
static func _spread(image: Image) -> float:
	var values: PackedFloat32Array = PackedFloat32Array()
	for y: int in range(0, image.get_height(), 37):
		for x: int in range(0, image.get_width(), 41):
			values.append(image.get_pixel(x, y).get_luminance())
	values.sort()
	return values[int(values.size() * 0.9)] - values[int(values.size() * 0.1)]


## The worst gap, as light, between a level-1 texel and its four below.
static func _means(below: Image, above: Image) -> float:
	var worst: float = 0.0
	for y: int in range(3, above.get_height() - 3, 29):
		for x: int in range(3, above.get_width() - 3, 31):
			var mean: float = 0.0
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				mean += _light(below.get_pixel(x * 2 + d.x, y * 2 + d.y).g) * 0.25
			worst = maxf(worst, absf(mean - _light(above.get_pixel(x, y).g)))
	return worst


## How much more the picture changes across a tile's edge than across the
## columns and rows beside it (1 is no seam at all).
static func _seams(image: Image, tiles: Array[Rect2i]) -> float:
	var worst: float = 1.0
	for tile: Rect2i in tiles:
		if tile.position.x > 0:
			worst = maxf(worst, _step(image, tile.position.x, true) / maxf(_step(image, tile.position.x - 3, true), 0.002))
		if tile.position.y > 0:
			worst = maxf(worst, _step(image, tile.position.y, false) / maxf(_step(image, tile.position.y - 3, false), 0.002))
	return worst


static func _step(image: Image, at: int, column: bool) -> float:
	var sum: float = 0.0
	var count: int = image.get_height() if column else image.get_width()
	for i: int in range(count):
		var a: Color = image.get_pixel(at - 1, i) if column else image.get_pixel(i, at - 1)
		var b: Color = image.get_pixel(at, i) if column else image.get_pixel(i, at)
		sum += absf(a.get_luminance() - b.get_luminance())
	return sum / count


func _mask(mask: Image, lamps: int) -> void:
	var phases: Dictionary = {}
	var pools: int = 0
	var wet: int = 0
	for y: int in range(0, mask.get_height(), 2):
		for x: int in range(0, mask.get_width(), 2):
			var c: Color = mask.get_pixel(x, y)
			if c.r > 0.5:
				pools += 1
				phases[roundi(c.g * 255.0)] = true
			wet += 1 if c.b > 0.9 else 0
	_check(pools > lamps * 4 and phases.size() >= mini(lamps, 8),
		"the mask holds a pool round the lamps, each with its flame's phase (%d phases)" % phases.size())
	_check(wet > 0, "the mask holds standing water")
