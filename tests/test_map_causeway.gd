extends RefCounted
@warning_ignore_start("unsafe_call_argument", "unsafe_cast")
## Act II's causeways on still water (`MapCausewayLandscape`, #660 II.2): the
## archive's approved Act II revived on the production layout, behind the dev
## flag only. For each of the camera contract's seeds the land draws the same
## layout record the painted Act II binds, covers every route with a deck,
## stands no added masonry in a walking corridor (the archive's probes,
## `support/causeway_probes.gd`), seats every waystone on a deck and frames
## Journey and Whole act inside the contract at the three landscape shapes.
## The pilgrim walks the decks; the water lies 1.18 m under the deck datum,
## deep in the ravines' channels under high bridges; the build runs paced.

const Probes = preload("res://tests/support/causeway_probes.gd")
const Presets = preload("res://presentation/map/causeway/presets.gd")
const Levels = preload("res://presentation/map/causeway/levels.gd")
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const SEEDS: Array[int] = [1, 4, 42, 717, 17634]
const SHAPES: Array[StringName] = [&"phone-landscape", &"pad-landscape", &"desktop-landscape"]
const ACT: int = 1


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_causeway: %s" % what)


static func run(fails: Array[String]) -> void:
	_dev_flag(fails)
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()
	_check(fails, MapJourneyProfile.enable_dev("2").is_empty(), "--journey-act=2 adds Act II's row")
	var content: ContentDB = ContentDB.load_full()
	for seed_value: int in SEEDS:
		_seed(fails, content, seed_value)
	_paced(fails, content)
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()


## Without the flag players see the painted Act II; the flag names an act by
## its number and is refused, never clamped, for an act without a dev land.
static func _dev_flag(fails: Array[String]) -> void:
	MapJourneyProfile.rows = MapJourneyProfile.default_rows()
	_check(fails, not MapJourneyProfile.has(ACT), "without the flag Act II keeps the painted landscape")
	for refused: String in ["1", "3", "0", "02", "two", ""]:
		_check(fails, not MapJourneyProfile.enable_dev(refused).is_empty()
				and MapJourneyProfile.rows.size() == 1,
			"--journey-act=%s is refused and adds no row" % refused)
	_check(fails, MapJourneyProfile.enable_dev("2").is_empty() and MapJourneyProfile.has(ACT)
			and MapJourneyProfile.land_class(ACT) == MapCausewayLandscape
			and not MapJourneyProfile.warms(ACT)
			and MapJourneyProfile.gate_id(ACT) == MapLandscapeAssets.GATES[ACT]
			and MapJourneyProfile.threshold_id(ACT).is_empty()
			and MapJourneyProfile.land_class(0) == MapJourneyLandscape,
		"--journey-act=2 gives Act II the causeways, at its own gate, unwarmed; Act I keeps its row")


static func _seed(fails: Array[String], content: ContentDB, seed_value: int) -> void:
	var run: RunState = RunState.new_run(content, seed_value, "run-map-causeway")
	run.act = ACT
	var screen: WorldMapScreen = _screen(content, run)
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	var built: bool = land is MapCausewayLandscape and land.is_built() and land.failure.is_empty()
	_check(fails, built, "seed %d: Act II binds the causeways: %s" % [seed_value,
		land.failure if land != null else "no journey land"])
	if not built:
		_free(screen)
		return
	var routes: Node3D = land.terrain.causeways
	_same_layout(fails, content, run, screen, seed_value)
	_decks(fails, routes, seed_value)
	_seats(fails, screen, land, seed_value)
	_water(fails, land, seed_value)
	_high_bridges(fails, routes, seed_value)
	_camera(fails, screen, land, seed_value)
	if seed_value == SEEDS[0]:
		_walk(fails, screen, land, run)
	_free(screen)


static func _screen(content: ContentDB, run: RunState, map: WorldMap = null) -> WorldMapScreen:
	var screen: WorldMapScreen = WorldMapScreen.new(map if map != null else WorldMap.for_run(run, content), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	screen.refresh(run)
	return screen


static func _mount(screen: WorldMapScreen, shape_name: StringName) -> void:
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(StageShape.REFERENCES[shape_name])
	screen.set_shape(shape_name)
	if screen._map_scene != null:
		screen._map_scene.size = screen.size
		screen._map_scene._fit()


static func _free(screen: WorldMapScreen) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


## The land is presentation only: the painted Act II binds the same record.
static func _same_layout(fails: Array[String], content: ContentDB, run: RunState,
		screen: WorldMapScreen, seed_value: int) -> void:
	MapScene.journey_enabled = false
	var painted: WorldMapScreen = _screen(content, run, screen.map)
	MapScene.journey_enabled = true
	_check(fails, painted._map_scene.journey_landscape() == null
			and painted.layout_digest() == screen.layout_digest()
			and painted.layout_input_digest() == screen.layout_input_digest(),
		"seed %d: the causeways leave the layout record and its digests unchanged" % seed_value)
	painted.get_parent().remove_child(painted)
	painted.free()


## Every route is a deck (seven offsets across 1.2 m find a rendered deck), and
## no edge masonry, parapet or pier stands in a walking corridor.
static func _decks(fails: Array[String], routes: Node3D, seed_value: int) -> void:
	_check(fails, routes.sampled_routes.size() == routes.lines.size() and routes.fields.size() == 2,
		"seed %d: every route is drawn, ordinary and raised decks apart" % seed_value)
	var coverage: Dictionary = Probes.deck_coverage(routes)
	_check(fails, int(coverage["samples"]) > 10000 and int(coverage["missing"]) == 0,
		"seed %d: a deck covers every route (%s)" % [seed_value, JSON.stringify(coverage)])
	var blocked: Dictionary = Probes.obstruction(routes)
	_check(fails, int(blocked["samples"]) > 10000 and int(blocked["hits"]) == 0,
		"seed %d: no added masonry stands in a walking corridor (%s)" % [seed_value, JSON.stringify(blocked)])


## Each waystone stands on its compiled anchor's X/Z, on a deck.
static func _seats(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape,
		seed_value: int) -> void:
	var anchors: PackedVector3Array = screen._ordered_layout_anchors()
	var seated: bool = anchors.size() == screen.map.nodes.size()
	for i: int in range(anchors.size()):
		var seat: Vector3 = land.seat(screen.map.nodes[i].id, Vector3.INF)
		var on_deck: bool = false
		for field: RefCounted in land.terrain.causeways.fields:
			var query: Dictionary = field.field(Vector2(seat.x, seat.z))
			var distance: float = query["distance"]
			var height: float = query["height"]
			on_deck = on_deck or (distance < 0 and absf(seat.y - height) < .2)
		seated = seated and seat.is_finite() and is_equal_approx(seat.x, anchors[i].x) \
			and is_equal_approx(seat.z, anchors[i].z) and on_deck
	_check(fails, seated, "seed %d: every waystone stands on its anchor, on a deck" % seed_value)


## One still sheet 1.18 m under the deck datum, under every deck, with a deep
## channel in each ravine; no ground is drawn.
static func _water(fails: Array[String], land: MapJourneyLandscape, seed_value: int) -> void:
	var sheet: MeshInstance3D = land.terrain.water.get_node("Water sheet") as MeshInstance3D
	var box: AABB = sheet.get_aabb()
	var lowest: float = INF
	for mesh: ArrayMesh in land.terrain.causeways.deck_meshes:
		lowest = minf(lowest, mesh.get_aabb().position.y)
	_check(fails, is_equal_approx(Presets.WATER, Presets.DATUM - 1.18)
			and absf(box.position.y - Presets.WATER) < .001 and box.size.y < .01
			and box.has_point(Vector3(0, Presets.WATER, 0)) and lowest > Presets.WATER + .5
			and land.terrain.chunks.is_empty(),
		"seed %d: one still sheet 1.18 m under the deck datum, under every deck" % seed_value)


## Every crossing of a ravine is a high bridge: the deck stands `RAVINE_RISE`
## over the channel's middle, or, where it passes under a raised road there or
## leaves a waystone by the channel, still well clear of the water. Every raised road keeps the archive's walking
## body (2.12 m) clear over the deck it crosses.
static func _high_bridges(fails: Array[String], routes: Node3D, seed_value: int) -> void:
	var crossings: int = 0
	var low: Array[Vector3] = []
	for line: PackedVector3Array in routes.sampled_routes.values():
		for i: int in range(line.size() - 1):
			for cut: float in MapRavine.CUTS:
				var a: float = line[i].x - MapRavine.centre(cut, line[i].z)
				var b: float = line[i + 1].x - MapRavine.centre(cut, line[i + 1].z)
				if signf(a) == signf(b):
					continue
				crossings += 1
				var deck: float = minf(line[i].y, line[i + 1].y)
				# Under a raised road, or leaving a waystone that stands by the
				# channel, the deck cannot reach the crown at a walkable incline.
				var under: bool = false
				for pass_at: Dictionary in routes.levels.cuts:
					var at: Vector2 = pass_at["at"]
					under = under or at.distance_to(Vector2(line[i].x, line[i].z)) < 3.0
				for anchor: Vector3 in routes.anchors.values():
					under = under or Vector2(anchor.x - line[i].x, anchor.z - line[i].z).length() < 2.5
				if deck < Presets.DATUM + Levels.RAVINE_RISE - .2 and not (under and deck > Presets.WATER + 1.5):
					low.append(line[i])
	_check(fails, crossings >= 4 and low.is_empty(),
		"seed %d: the ravines' %d crossings are high bridges over the channel (low: %s)" % [seed_value, crossings, low])
	var lower: RefCounted = routes.fields[0]
	var upper: RefCounted = routes.fields[1]
	var headroom: float = INF
	for cut: Dictionary in routes.levels.cuts:
		var at: Vector2 = cut["at"]
		var below: float = lower.field(at)["height"]
		var above: float = upper.field(at)["bottom"]
		headroom = minf(headroom, above - below)
	_check(fails, routes.levels.cuts.is_empty() or (headroom >= 2.12 and headroom < INF),
		"seed %d: each raised road clears the deck it crosses by a walking body (%.2f m)" % [seed_value, headroom])


## The journey camera's contract at each landscape shape: Journey frames the
## pilgrim's next stones on screen, each on its own touch square, inside the
## tilt-shift's sharp band; Whole act frames wider; the land lies in the slab.
static func _camera(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape,
		seed_value: int) -> void:
	var scene: MapScene = screen._map_scene
	var rig: MapCameraRig = scene.get_rig()
	for shape: StringName in SHAPES:
		_mount(screen, shape)
		screen._journey.frame(screen.map.at)
		screen._layout_waystones()
		var stage: Vector2 = Vector2(StageShape.REFERENCES[shape])
		var touch: float = MapJourneyCameraContract.touch_size(stage)
		var seats: PackedVector2Array = screen.projected_seats()
		var members: Array = screen._journey.pose_for(screen.map.at).get("members", [])
		var inside: bool = rig.journey_mode and not members.is_empty()
		for k: int in range(members.size()):
			var a: Vector2 = seats[int(str(members[k]))]
			inside = inside and Rect2(Vector2.ZERO, stage).has_point(a)
			for m: int in range(k + 1, members.size()):
				var delta: Vector2 = (a - seats[int(str(members[m]))]).abs()
				inside = inside and maxf(delta.x, delta.y) >= touch - 0.5
		var band: Vector2 = scene.focus_band
		var covered: bool = band.is_finite() and not screen._journey.focus_members.is_empty()
		for i: int in screen._journey.focus_members:
			covered = covered and seats[i].y >= band.x and seats[i].y <= band.y
		_check(fails, inside and covered,
			"seed %d: Journey frames its stones on screen, apart and in the sharp band at %s" % [seed_value, shape])
		var journey_size: float = rig.get_camera().size
		screen._journey.zoom(true)
		_check(fails, screen._journey.view.overview and rig.get_camera().size > journey_size,
			"seed %d: Whole act frames wider at %s" % [seed_value, shape])
		screen._journey.zoom(false)
	_mount(screen, StageShape.IDENTITY)
	screen._journey.frame(screen.map.at)
	var low: float = INF
	var high: float = -INF
	for node: Node in land.find_children("*", "GeometryInstance3D", true, false):
		var item: GeometryInstance3D = node as GeometryInstance3D
		var box: AABB = item.global_transform * item.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	_check(fails, low >= MapJourneyCameraContract.LAND_LOW and high <= MapJourneyCameraContract.LAND_HIGH,
		"seed %d: the causeways lie within the clip slab's heights (%.2f to %.2f m)" % [seed_value, low, high])


## The pilgrim waits beside its waystone and walks the decks to the next.
static func _walk(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape,
		run: RunState) -> void:
	var from_i: int = screen.map.reachable()[0]
	screen.map.enter(from_i)
	screen.map.clear_current()
	screen.refresh(run)
	var parked: Vector3 = screen.marker_world_position()
	_check(fails, parked.is_finite() and land.journey.walker.visible,
		"the pilgrim waits beside the current waystone")
	var walked: int = 0
	var on_decks: bool = true
	for to_i: int in screen.map.reachable():
		var route: PackedVector3Array = land.walking_route(screen.map.nodes[from_i].id, screen.map.nodes[to_i].id)
		on_decks = on_decks and route.size() >= 2
		for point: Vector3 in route:
			var best: float = INF
			for field: RefCounted in land.terrain.causeways.fields:
				var query: Dictionary = field.field(Vector2(point.x, point.z))
				var distance: float = query["distance"]
				var height: float = query["height"]
				if distance < 0:
					best = minf(best, absf(point.y - height))
			on_decks = on_decks and best < .01
		walked += 1
	_check(fails, walked > 0 and on_decks, "every walk from the pilgrim's stone lies on a deck")


## The build runs paced on a worker, as the prefetch runs it (its meshes handed
## to the renderer a few at a time), and a build given up ends as STOPPED.
static func _paced(fails: Array[String], content: ContentDB) -> void:
	var run: RunState = RunState.new_run(content, SEEDS[0], "run-map-causeway")
	run.act = ACT
	MapScene.journey_enabled = false
	var screen: WorldMapScreen = _screen(content, run)
	MapScene.journey_enabled = true
	var data: Dictionary = screen.layout_result().identity_dict()
	var assets: MapLandscapeAssets = screen._map_scene._landscape_assets
	Meshes.prepare_unit_box()
	for stop: bool in [false, true]:
		var land: MapCausewayLandscape = MapCausewayLandscape.new()
		land.prepare(data, assets, 0)
		var pacing: Meshes.Pacing = Meshes.Pacing.new()
		if stop:
			pacing.stop()
		var task: int = WorkerThreadPool.add_task(func() -> void:
			Meshes.pace(pacing)
			land.build_detached(data, pacing)
			Meshes.pace(null))
		WorkerThreadPool.wait_for_task_completion(task)
		if stop:
			_check(fails, land.failure == MapJourneyLandscape.STOPPED,
				"a causeway build given up ends as stopped")
		else:
			_check(fails, land.is_built() and land.failure.is_empty() and land.journey != null
					and int(land.timings_ms.get("total", -1)) >= 0,
				"the causeways build paced on a worker: %s" % land.failure)
		land.free()
	screen.get_parent().remove_child(screen)
	screen.free()
