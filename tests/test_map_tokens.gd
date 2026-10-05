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
## - The hierarchy: the gold of a lit rim (open, current) at least 1.2 times the
##   luminance of a quiet one (walked, cold), and a quiet rim no wider on screen
##   than a lit one.
## - The map screen gives each stone the state its node is in, and the glyph is
##   drawn in that state's tone.
##
## `tools/map_token_gate.gd` measures the same gate in the rendered picture,
## which is where the draw path itself is proved; the suite has no renderer.

const EDGE_MIN: float = 3.0
const ACTIONABLE_MIN: float = 4.5
const QUIET_MIN: float = 3.0
const RIM_PX_MIN: float = 2.0
## How much brighter the dimmest lit rim must be than the brightest quiet one.
const LIT_OVER_QUIET: float = 1.2
## [reachable, cleared, current] -> the state the stone must wear.
const CASES: Array = [
	[true, false, false, &"open"],
	[false, true, true, &"current"],
	[false, false, true, &"current"],
	[false, true, false, &"walked"],
	[false, false, false, &"cold"],
]
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
	var kinds: Array[String] = GlassWaystone.GLYPH_KINDS.duplicate()
	kinds.append("act4")
	var bad: Array[String] = []
	var worst_edge: float = INF
	var worst_glyph: Dictionary = {}
	var dimmest_lit: float = INF
	var brightest_quiet: float = 0.0
	for kind: String in kinds:
		for case: Array in CASES:
			var stone: GlassWaystone = _stone(kind, case)
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
				if state in [GlassWaystone.OPEN, GlassWaystone.CURRENT]:
					dimmest_lit = minf(dimmest_lit, _lum(rim))
				else:
					brightest_quiet = maxf(brightest_quiet, _lum(rim))
				var edge: float = _worst_land(rim, pane)
				worst_edge = minf(worst_edge, edge)
				if edge < EDGE_MIN:
					bad.append("%s edge %.2f:1 on its worst land (rim %.2f:1 on its pane)" % [
						name, edge, _ratio(rim, pane)])
			stone.free()
	_check(fails, bad.is_empty(), "every token holds its own contrast on any land: %s" % [bad.slice(0, 4)])
	_check(fails, worst_edge >= EDGE_MIN and worst_glyph.size() == 4,
		"the edge's worst land is %.2f:1; glyphs on their panes %s" % [worst_edge, worst_glyph])
	_check(fails, dimmest_lit >= LIT_OVER_QUIET * brightest_quiet,
		"a lit rim is the brightest on the map: its luminance %.3f against a quiet rim's %.3f (%.2f times, at least %.1f)" % [
			dimmest_lit, brightest_quiet, dimmest_lit / maxf(brightest_quiet, 0.0001), LIT_OVER_QUIET])


## Each state's rim width in stage px at each shipping shape, the stone drawn
## at the shape's waystone scale as `WorldMapScreen` lays it out: every rim at
## least `RIM_PX_MIN`, and no quiet rim wider than a lit one.
static func _rim_on_screen(fails: Array[String]) -> void:
	var widths: Dictionary = {}
	var bad: Array[String] = []
	for shape: StringName in StageShape.SHIPPING:
		var layout: Dictionary = LayoutBook.resolve(&"map", shape)
		var scale: float = LayoutBook.num(layout.get("scale"), 0.36)
		var narrowest_lit: float = INF
		var widest_quiet: float = 0.0
		var row: Dictionary = {}
		for case: Array in CASES:
			var stone: GlassWaystone = _stone("monster", case)
			stone.set_touch_min(LayoutBook.num(layout.get("touch"), 0.0), scale)
			var state: StringName = stone.token_state()
			var px: float = stone.rim_width() * scale
			row[state] = snappedf(px, 0.01)
			if px < RIM_PX_MIN - 0.001:
				bad.append("%s %s rim %.2f px" % [shape, state, px])
			if state in [GlassWaystone.OPEN, GlassWaystone.CURRENT]:
				narrowest_lit = minf(narrowest_lit, px)
			else:
				widest_quiet = maxf(widest_quiet, px)
			stone.free()
		if widest_quiet > narrowest_lit + 0.001:
			bad.append("%s quiet rim %.2f px wider than the lit %.2f" % [shape, widest_quiet, narrowest_lit])
		widths[shape] = row
	_check(fails, bad.is_empty(), "every rim is at least %.0f px on screen, a quiet one no wider than a lit one: %s %s" % [
		RIM_PX_MIN, bad, widths])


## A stone of `kind` in the state `case` names, through `set_state`.
static func _stone(kind: String, case: Array) -> GlassWaystone:
	var stone: GlassWaystone = GlassWaystone.new(0, kind, 30.0, "")
	var reachable: bool = case[0]
	var cleared: bool = case[1]
	var current: bool = case[2]
	stone.set_state(reachable, cleared, current)
	return stone


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
