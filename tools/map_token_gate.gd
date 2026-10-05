extends SceneTree
## The waystone tokens' gate in the rendered picture (#679). Mounts the
## production map screen in the lean profile phones and pads draw, walks
## `--steps` nodes in so every state stands on the land, and at each zoom stop
## of the act (Act I's Close, Journey and Whole act; the painted acts' four
## camera stops) captures the window and measures every token in it:
##
## - glyph against disc at least 4.5:1 for the actionable states (open,
##   current) and 3:1 for the rest (walked, cold);
## - at the edge, in every 30° sector, the better of rim against land and disc
##   against land at least 3:1, the land sampled 2–6 px beyond the token.
##
## Land is what the token stands on: another token, a bounty pill and a quest
## lens are not land, so their pixels are left out of a sector; a sector with
## too little land left is not judged, nor a token with too few sectors
## ("crowded"), a quarter of its face under another token or a pill
## ("covered"), or its centre outside the window ("off frame"). The glyph is told from the disc by a
## second capture with every glyph hidden, the land held still between the two.
## Contrast is WCAG's ratio of relative luminance. `tests/test_map_tokens.gd`
## proves the same gate from the token's own colours, against any land.
##
##   godot --path . -s res://tools/map_token_gate.gd -- --act-index=0 --seed=1 \
##     --shape=phone-landscape --output=<dir> [--steps=2]
##
## Prints a TOKEN row per measured token and one TOKEN_GATE summary, saves each
## stop's capture as <dir>/a<act>-s<seed>-<shape>-<stop>.png, and exits 1 when
## a token fails. Needs a window: never `--headless`.

const ACTIONABLE_MIN: float = 4.5
const QUIET_MIN: float = 3.0
const EDGE_MIN: float = 3.0
const LAND_NEAR: float = 2.0
const LAND_FAR: float = 6.0
const SECTORS: int = 12
## A sector is judged on at least this many land pixels; a token on at least
## this many sectors.
const SECTOR_PIXELS: int = 6
const JUDGED_SECTORS: int = 4
## How far a pixel must change when the glyphs are hidden to count as glyph.
const GLYPH_STEP: float = 0.06

var _act: int = 0
var _seed: int = 1
var _shape: StringName = &"pad-landscape"
var _steps: int = 2
var _output: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--act-index="):
			_act = int(value)
		elif arg.begins_with("--seed="):
			_seed = int(value)
		elif arg.begins_with("--shape="):
			_shape = StringName(value)
		elif arg.begins_with("--steps="):
			_steps = int(value)
		elif arg.begins_with("--output="):
			_output = value
	if DisplayServer.get_name() == "headless" or _output.is_empty() \
			or not StageShape.SHIPPING.has(_shape) or _act < 0 or _act > 3:
		push_error("map_token_gate needs a window, --output, a shipping shape and act index 0–3")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	MapScene.lean_override = 1
	# As Main does: the woodland keeps the shown shape's touch squares clear.
	MapJourneyLandscape.ImpostorWood.Planting.stage_shape = _shape
	var dimensions: Vector2i = StageShape.REFERENCES[_shape]
	DisplayServer.window_set_size(dimensions)
	root.size = dimensions
	root.content_scale_size = dimensions
	Locale.active = Locale.new(&"en")
	var content: ContentDB = ContentDB.load_full()
	Locale.active.hydrate_content(content)
	var run: RunState = RunState.new_run(content, _seed)
	run.act = _act
	var world_map: WorldMap = WorldMap.for_run(run, content)
	for step: int in range(_steps):
		var next: Array[int] = world_map.reachable()
		if not next.is_empty():
			world_map.enter(next[0])
			world_map.clear_current()
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content, _shape, _act)
	root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(dimensions)
	screen.refresh(run)
	screen.set_survey_retired(true)
	var waited: int = 0
	while screen.landscape_pending() and waited < 3000:
		await process_frame
		waited += 1
	for frame: int in range(30):
		await process_frame
	var failed: int = 0
	var measured: int = 0
	var skipped: Dictionary = {}
	var worst: Dictionary = {}
	for stop: String in _stops():
		_set_stop(screen, stop)
		for frame: int in range(20):
			await process_frame
		var pictures: Array[Image] = await _capture(screen)
		var picture: Image = pictures[0]
		var bare: Image = pictures[1]
		picture.save_png(_output.path_join("a%d-s%d-%s-%s.png" % [_act, _seed, _shape, stop]))
		var tokens: Array[Dictionary] = _tokens(screen)
		for token: Dictionary in tokens:
			var row: Dictionary = _measure(token, tokens, picture, bare)
			row["stop"] = stop
			if not row["judged"]:
				var so_far: int = skipped.get(row["why"], 0)
				skipped[row["why"]] = so_far + 1
				continue
			measured += 1
			if not row["pass"]:
				failed += 1
			if worst.is_empty() or row["margin"] < worst["margin"]:
				worst = row
			print("TOKEN ", JSON.stringify(row))
	print("TOKEN_GATE ", JSON.stringify({"act": _act + 1, "seed": _seed, "shape": _shape,
		"measured": measured, "failed": failed, "skipped": skipped, "worst": worst}))
	quit(1 if failed > 0 or measured == 0 else 0)


## The settled frame, every throb held at its peak, then the same frame with
## every glyph hidden. The land is held still between the two, so they differ
## only where a glyph was drawn.
func _capture(screen: WorldMapScreen) -> Array[Image]:
	screen._layout_waystones()
	screen._push_bands(true)
	for stone: GlassWaystone in screen._waystones:
		stone.set_process(false)
		stone._pulse = GlassWaystone.PULSE_HELD
		stone.queue_redraw()
	screen._map_scene.set_live(true)
	for frame: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	screen._map_scene.set_live(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	for stone: GlassWaystone in screen._waystones:
		stone._glyph_art.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare: Image = root.get_texture().get_image()
	for stone: GlassWaystone in screen._waystones:
		stone._glyph_art.visible = true
	return [picture, bare]


## Act I's journey levels, or the painted acts' camera stops.
func _stops() -> PackedStringArray:
	if _act == 0:
		return PackedStringArray(["close", "journey", "whole"])
	var out: PackedStringArray = []
	for i: int in range(MapCameraRig.ZOOM_STOPS.size()):
		out.append("stop%d" % i)
	return out


func _set_stop(screen: WorldMapScreen, stop: String) -> void:
	if stop.begins_with("stop"):
		screen._map_scene.get_rig().set_zoom_stop(int(stop.trim_prefix("stop")))
		screen._invalidate_projection()
		return
	var level: MapJourneyView.Level = MapJourneyView.Level.JOURNEY
	if stop == "close":
		level = MapJourneyView.Level.CLOSE
	elif stop == "whole":
		level = MapJourneyView.Level.WHOLE
	screen._journey.view.level = level
	screen._journey.frame(screen.map.at)


## Every visible token in window pixels: its centre, its outer radius, its
## rim's width (the band inside the outer radius), its disc's radius, the places that are not land around it (bounty pills, the quest
## lens), and its state.
func _tokens(screen: WorldMapScreen) -> Array[Dictionary]:
	var stretch: Transform2D = root.get_stretch_transform()
	var out: Array[Dictionary] = []
	for stone: GlassWaystone in screen._waystones:
		if not stone.is_visible_in_tree():
			continue
		var to_window: Transform2D = stretch * stone.get_global_transform_with_canvas()
		var unit: float = to_window.get_scale().x
		var centre: Vector2 = to_window * (stone._pad + Vector2(GlassWaystone.WIDTH, GlassWaystone.EMBLEM_H) * 0.5)
		var radius: float = stone.pane_radius()
		var lenses: Array[Vector3] = []
		if stone.quest_marked:
			var lens: Vector2 = to_window * (stone._pad + Vector2(GlassWaystone.WIDTH, GlassWaystone.EMBLEM_H) * 0.5
				+ Vector2(radius, -radius) * 0.78)
			lenses.append(Vector3(lens.x, lens.y, 13.0 * unit))
		var pills: Array[Rect2] = []
		if stone.has_chip():
			for flip: bool in [false, true]:
				var rect: Rect2 = stone.chip_rect(flip)
				pills.append(to_window * rect)
		out.append({"index": stone.index, "kind": stone.kind, "state": stone.token_state(),
			"centre": centre, "radius": radius * unit, "rim": stone.rim_width() * unit,
			"disc": (radius - stone.rim_width()) * unit,
			"lenses": lenses, "pills": pills})
	return out


func _measure(token: Dictionary, tokens: Array[Dictionary], picture: Image, bare: Image) -> Dictionary:
	var centre: Vector2 = token["centre"]
	var radius: float = token["radius"]
	var rim_w: float = token["rim"]
	var disc_r: float = token["disc"]
	# The rim's core: its middle, 0.6 px in from either anti-aliased side, and
	# never narrower than a pixel.
	var rim_mid: float = radius - rim_w * 0.5
	var rim_core: float = maxf(rim_w * 0.5 - 0.6, 0.5)
	var w: int = picture.get_width()
	var h: int = picture.get_height()
	var disc_l: PackedFloat32Array = []
	var glyph_l: PackedFloat32Array = []
	var rim_l: PackedFloat32Array = []
	var land: Array[PackedFloat32Array] = []
	land.resize(SECTORS)
	for s: int in range(SECTORS):
		land[s] = PackedFloat32Array()
	var disc_area: int = 0
	var disc_hidden: int = 0
	var reach: int = ceili(radius + LAND_FAR + 1.0)
	for y: int in range(floori(centre.y) - reach, ceili(centre.y) + reach + 1):
		for x: int in range(floori(centre.x) - reach, ceili(centre.x) + reach + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var at: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = at.distance_to(centre)
			if d > radius + LAND_FAR:
				continue
			var inside: bool = d <= disc_r - 1.5
			disc_area += 1 if inside else 0
			if _not_land(at, token, tokens):
				disc_hidden += 1 if inside else 0
				continue
			var lum: float = _luminance(picture.get_pixel(x, y))
			if d >= radius + LAND_NEAR:
				var sector: int = int(fposmod((at - centre).angle(), TAU) / TAU * SECTORS) % SECTORS
				land[sector].append(lum)
			elif absf(d - rim_mid) <= rim_core:
				rim_l.append(lum)
			elif inside:
				var plain: Color = bare.get_pixel(x, y)
				var drawn: Color = picture.get_pixel(x, y)
				var step: float = absf(drawn.r - plain.r) + absf(drawn.g - plain.g) + absf(drawn.b - plain.b)
				if step >= GLYPH_STEP:
					glyph_l.append(lum)
				disc_l.append(_luminance(plain))
	var row: Dictionary = {"index": token["index"], "kind": token["kind"], "state": token["state"],
		"at": [roundi(centre.x), roundi(centre.y)], "radius": snappedf(radius, 0.01), "judged": false}
	if centre.x < 0.0 or centre.y < 0.0 or centre.x > w or centre.y > h:
		row["why"] = "off frame"
		return row
	var judged_sectors: int = 0
	for s: int in range(SECTORS):
		judged_sectors += 1 if land[s].size() >= SECTOR_PIXELS else 0
	if disc_hidden * 4 > disc_area:
		row["why"] = "covered"
		return row
	if disc_l.is_empty() or rim_l.is_empty() or judged_sectors < JUDGED_SECTORS:
		row["why"] = "crowded"
		return row
	var disc: float = _median(disc_l)
	var rim: float = _median(rim_l)
	# A glyph that changes nothing when hidden is no glyph: it reads as the disc.
	var glyph: float = disc if glyph_l.is_empty() else _percentile(glyph_l, 0.9)
	var glyph_ratio: float = _ratio(glyph, disc)
	var edge_worst: float = INF
	for s: int in range(SECTORS):
		if land[s].size() >= SECTOR_PIXELS:
			var ground: float = _median(land[s])
			edge_worst = minf(edge_worst, maxf(_ratio(rim, ground), _ratio(disc, ground)))
	var glyph_min: float = ACTIONABLE_MIN if token["state"] in ["open", "current"] else QUIET_MIN
	row["judged"] = true
	row["glyph_vs_disc"] = snappedf(glyph_ratio, 0.01)
	row["glyph_min"] = glyph_min
	row["edge_worst_sector"] = snappedf(edge_worst, 0.01)
	row["sectors"] = judged_sectors
	row["disc_l"] = snappedf(disc, 0.0001)
	row["rim_l"] = snappedf(rim, 0.0001)
	row["glyph_l"] = snappedf(glyph, 0.0001)
	row["pass"] = glyph_ratio >= glyph_min and edge_worst >= EDGE_MIN
	row["margin"] = snappedf(minf(glyph_ratio / glyph_min, edge_worst / EDGE_MIN), 0.001)
	return row


## Another token, a bounty pill, a quest lens: not the land this token stands on.
func _not_land(at: Vector2, token: Dictionary, tokens: Array[Dictionary]) -> bool:
	for other: Dictionary in tokens:
		var lenses: Array[Vector3] = other["lenses"]
		for lens: Vector3 in lenses:
			if at.distance_to(Vector2(lens.x, lens.y)) <= lens.z:
				return true
		var pills: Array[Rect2] = other["pills"]
		for pill: Rect2 in pills:
			if pill.grow(1.0).has_point(at):
				return true
		if other != token:
			var centre: Vector2 = other["centre"]
			var reach: float = other["radius"]
			if at.distance_to(centre) <= reach + 1.5:
				return true
	return false


static func _luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


static func _median(values: PackedFloat32Array) -> float:
	return _percentile(values, 0.5)


static func _percentile(values: PackedFloat32Array, share: float) -> float:
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi(share * (sorted.size() - 1)), 0, sorted.size() - 1)]
