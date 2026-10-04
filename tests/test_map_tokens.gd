extends RefCounted
## The waystone tokens' gate (#679), from the token's own colours, so it holds
## on any land: the wood behind a stone today, the floor's moss and litter
## tomorrow.
##
## - Every state draws an opaque pane, rim and glyph: nothing of the land shows
##   through a token.
## - Glyph against pane at least 4.5:1 where the stone can be chosen or is stood
##   on (open, current) and 3:1 where it is quieted (walked, cold).
## - At the edge, the better of rim against land and pane against land at least
##   3:1 for every land from black to white, which needs the rim at 9:1 against
##   the pane. Checked at both ends of an open stone's throb.
## - The rim at least 2 px wide on screen at every shipping shape, so a whole
##   pixel lies inside it and shows its own colour.
## - The map screen gives each stone the state its node is in, and the glyph is
##   drawn in that state's tone.
##
## `tools/map_token_gate.gd` measures the same gate in the rendered picture,
## which is where the draw path itself is proved; the suite has no renderer.

const EDGE_MIN: float = 3.0
const ACTIONABLE_MIN: float = 4.5
const QUIET_MIN: float = 3.0
const RIM_PX_MIN: float = 2.0
## The throb's trough and its held peak (`GlassWaystone.PULSE_HELD`).
const PULSE_TROUGH: float = 3.0 * PI / 4.4


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_tokens: %s" % what)


static func run(fails: Array[String]) -> void:
	_looks(fails)
	_rim_on_screen(fails)
	_screen_states(fails)


## Every state of every kind, through `set_state` as the screen calls it.
static func _looks(fails: Array[String]) -> void:
	# [reachable, cleared, current] -> the state the stone must wear.
	var cases: Array = [
		[true, false, false, GlassWaystone.OPEN],
		[false, true, true, GlassWaystone.CURRENT],
		[false, false, true, GlassWaystone.CURRENT],
		[false, true, false, GlassWaystone.WALKED],
		[false, false, false, GlassWaystone.COLD],
	]
	var kinds: Array[String] = GlassWaystone.GLYPH_KINDS.duplicate()
	kinds.append("act4")
	var bad: Array[String] = []
	var worst_edge: float = INF
	var worst_glyph: Dictionary = {}
	for kind: String in kinds:
		for case: Array in cases:
			var stone: GlassWaystone = GlassWaystone.new(0, kind, 30.0, "")
			var reachable: bool = case[0]
			var cleared: bool = case[1]
			var current: bool = case[2]
			stone.set_state(reachable, cleared, current)
			var state: StringName = stone.token_state()
			var name: String = "%s %s" % [kind, state]
			if state != case[3]:
				bad.append("%s should be %s" % [name, case[3]])
			var glyph: Color = stone._glyph_art.modulate
			if glyph != GlassWaystone.GLYPH[state]:
				bad.append("%s draws its glyph in %s, not its state's %s" % [name, glyph, GlassWaystone.GLYPH[state]])
			var pane: Color = GlassWaystone.PANE
			var glyph_min: float = ACTIONABLE_MIN if state in [GlassWaystone.OPEN, GlassWaystone.CURRENT] else QUIET_MIN
			var glyph_ratio: float = _ratio(glyph, pane)
			var so_far: float = worst_glyph.get(state, INF)
			worst_glyph[state] = snappedf(minf(so_far, glyph_ratio), 0.01)
			if glyph_ratio < glyph_min:
				bad.append("%s glyph %.2f:1 on its pane, under %.1f" % [name, glyph_ratio, glyph_min])
			for pulse: float in [PULSE_TROUGH, GlassWaystone.PULSE_HELD]:
				stone._pulse = pulse
				var rim: Color = stone.rim_colour()
				if pane.a < 1.0 or rim.a < 1.0 or glyph.a < 1.0 or stone.modulate.a < 1.0:
					bad.append("%s lets the land through (pane %.2f, rim %.2f, glyph %.2f, stone %.2f)" % [
						name, pane.a, rim.a, glyph.a, stone.modulate.a])
				var edge: float = _worst_land(rim, pane)
				worst_edge = minf(worst_edge, edge)
				if edge < EDGE_MIN:
					bad.append("%s edge %.2f:1 on its worst land (rim %.2f:1 on its pane)" % [
						name, edge, _ratio(rim, pane)])
			stone.free()
	_check(fails, bad.is_empty(), "every token holds its own contrast on any land: %s" % [bad.slice(0, 4)])
	_check(fails, worst_edge >= EDGE_MIN and worst_glyph.size() == 4,
		"the edge's worst land is %.2f:1; glyphs on their panes %s" % [worst_edge, worst_glyph])


## The rim's width in stage px at each shipping shape's waystone scale.
static func _rim_on_screen(fails: Array[String]) -> void:
	var widths: Dictionary = {}
	for shape: StringName in StageShape.SHIPPING:
		var scale: float = LayoutBook.num(LayoutBook.resolve(&"map", shape).get("scale"), 0.36)
		widths[shape] = snappedf(GlassWaystone.RIM_W * scale, 0.01)
	var narrowest: float = INF
	for shape: StringName in widths:
		var width: float = widths[shape]
		narrowest = minf(narrowest, width)
	_check(fails, narrowest >= RIM_PX_MIN, "the rim is at least %.0f px on screen at every shape: %s" % [
		RIM_PX_MIN, widths])


## A run two steps in: the screen gives the stood-on stone, the open ones, the
## walked ones and the rest the state their nodes are in, and every state is
## on the map.
static func _screen_states(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = RunState.new_run(content, 1, "run-map-tokens")
	var world_map: WorldMap = WorldMap.for_run(run_state, content)
	for step: int in range(2):
		world_map.enter(world_map.reachable()[0])
		world_map.clear_current()
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.refresh(run_state)
	var live: Array[int] = world_map.reachable()
	var seen: Dictionary = {}
	var wrong: Array[String] = []
	for i: int in range(screen._waystones.size()):
		var stone: GlassWaystone = screen._waystones[i]
		var want: StringName = GlassWaystone.COLD
		if i == world_map.at:
			want = GlassWaystone.CURRENT
		elif live.has(i):
			want = GlassWaystone.OPEN
		elif world_map.is_cleared(i):
			want = GlassWaystone.WALKED
		seen[want] = true
		if stone.token_state() != want or stone._glyph_art.modulate != GlassWaystone.GLYPH[want]:
			wrong.append("%d is %s with a %s glyph, its node %s" % [i, stone.token_state(),
				stone._glyph_art.modulate, want])
	_check(fails, wrong.is_empty() and seen.size() == 4,
		"the screen gives each stone its node's state, and all four are on the map: %s %s" % [wrong.slice(0, 3), seen.keys()])
	tree.root.remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


## The edge's contrast on the land that suits the token least: the better of
## rim and pane against each land luminance from black to white, at its lowest.
static func _worst_land(rim: Color, pane: Color) -> float:
	var worst: float = INF
	for step: int in range(1001):
		var land: float = step / 1000.0
		worst = minf(worst, maxf(_lum_ratio(_lum(rim), land), _lum_ratio(_lum(pane), land)))
	return worst


static func _ratio(a: Color, b: Color) -> float:
	return _lum_ratio(_lum(a), _lum(b))


## WCAG's relative luminance of an sRGB colour.
static func _lum(c: Color) -> float:
	return c.srgb_to_linear().get_luminance()


static func _lum_ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)
