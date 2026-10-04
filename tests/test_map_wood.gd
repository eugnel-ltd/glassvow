extends RefCounted
## Act I's woodland as impostor cards (R3.1, issue #660) on the production
## path: the baked atlas and how it loads, where the wood stands (off the roads, the river, the
## bridges and the stones, and never hiding a road's centreline or covering a
## waystone's touch square), its mix of kinds and crown sizes, its draws and
## their sway, and the clip slab it must fit.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Landform = preload("res://presentation/map/landscape/landform.gd")
const SEED: int = 717


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_wood: %s" % what)


static func run(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	_atlas(fails)
	_loading(fails)
	_slab(fails)
	var content: ContentDB = ContentDB.load_full()
	var run_state: RunState = RunState.new_run(content, SEED, "run-map-wood")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(run_state, content), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.set_shape(StageShape.IDENTITY)
	screen.refresh(run_state)
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	_check(fails, land != null and land.is_built() and land.wood != null,
		"Act I's land is built with its woodland")
	if land != null and land.is_built() and land.wood != null:
		var seats: PackedVector3Array = []
		for base: Node3D in land.journey.bases:
			seats.append(base.position)
		_ground(fails, land, seats)
		_picture(fails, land, seats)
		_mix(fails, land)
		_draws(fails, land)
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


## Every kind the woodland plants has baked tiles inside the atlas, with a
## silhouette row per `span_m`; the kit loads no scene for the kinds drawn as
## cards.
static func _atlas(fails: Array[String]) -> void:
	_check(fails, Atlas.ready(), "the impostor atlas is ready once the kit is")
	var kinds: PackedStringArray = Planting.TREES.duplicate()
	kinds.append_array(PackedStringArray(Planting.UNDERGROWTH.keys()))
	kinds.append_array(Atlas.KIT_KINDS)
	var baked: bool = true
	for kind: String in kinds:
		var tiles: PackedInt32Array = Atlas.by_kind.get(kind, PackedInt32Array())
		baked = baked and not tiles.is_empty()
	_check(fails, baked, "every kind the woodland plants is baked")
	var inside: bool = Atlas.uv.size() == Atlas.tile_kinds.size()
	for tile: int in range(Atlas.uv.size()):
		var rect: Vector4 = Atlas.uv[tile]
		inside = inside and rect.x >= 0.0 and rect.y >= 0.0 and rect.x + rect.z <= 1.0001 \
			and rect.y + rect.w <= 1.0001 and Atlas.spans[tile].size() == roundi(Atlas.size[tile].y / Atlas.span_m)
	_check(fails, inside, "every tile lies inside the atlas with a silhouette row per span")
	var scenes: Array = MapJourneyLandscape.Kit._scene_kinds()
	var cards_only: bool = true
	for kind: String in Atlas.KIT_KINDS:
		cards_only = cards_only and not scenes.has(kind)
	_check(fails, cards_only and scenes.has("amber-arch") and scenes.has("conifer-snag"),
		"the kit loads no scene for the foliage drawn as cards")


## The atlas's textures are taken from the loader once each, whatever order
## they finish in (a second `load_threaded_get` of a path returns null), and a
## texture that cannot load ends the wait instead of holding the map's opening.
static func _loading(fails: Array[String]) -> void:
	var states: Dictionary = {"albedo": ResourceLoader.THREAD_LOAD_LOADED,
		"normal": ResourceLoader.THREAD_LOAD_IN_PROGRESS}
	var handed: Dictionary = {}
	var take: Atlas.Take = Atlas.Take.new(PackedStringArray(["albedo", "normal"]))
	take.status = func(path: String) -> int:
		return states[path]
	take.get_texture = func(path: String) -> Variant:
		if handed.has(path):
			return null
		handed[path] = true
		return ImageTexture.new()
	var first: bool = take.step(false)
	states["normal"] = ResourceLoader.THREAD_LOAD_LOADED
	var second: bool = take.step(false)
	_check(fails, not first and second and not take.failed and take.textures.size() == 2,
		"a texture taken while another still loads is kept for the next step")
	var broken: Atlas.Take = Atlas.Take.new(PackedStringArray(["albedo"]))
	broken.status = func(_path: String) -> int:
		return ResourceLoader.THREAD_LOAD_FAILED
	broken.get_texture = func(_path: String) -> Variant:
		return null
	_check(fails, broken.step(false) and broken.failed, "a texture that fails to load settles the take")
	var missing: Atlas.Take = Atlas.Take.new(PackedStringArray(["res://assets/art/map-journey/impostors/missing.png"]))
	missing.request()
	_check(fails, missing.failed and missing.step(true), "a missing atlas ends the wait at once")


## The land's slab (`MapJourneyCameraContract.LAND_HIGH`) holds the tallest
## crown the woodland can plant on the highest upland of any Act I land, not
## only of one fixture land.
static func _slab(fails: Array[String]) -> void:
	var landform: Landform = Landform.new()
	var highest: float = -INF
	var bounds: Rect2 = MapJourneyLandscape.MAP_BOUNDS
	var x: float = bounds.position.x
	while x <= bounds.end.x:
		var z: float = bounds.position.y
		while z <= bounds.end.y:
			highest = maxf(highest, landform.upland(x, z))
			z += 0.5
		x += 0.5
	var tallest: float = 0.0
	for top: float in Atlas.top:
		tallest = maxf(tallest, top)
	_check(fails, highest + tallest * Planting.TREE_SCALE.y <= MapJourneyCameraContract.LAND_HIGH,
		"the clip slab holds the tallest crown on the highest upland (%.2f + %.2f m)" % [highest, tallest * Planting.TREE_SCALE.y])


## Where the wood stands on the ground: dry; trunks off the roads and their
## verges, undergrowth off the roads; nothing on a bridge or a waystone.
static func _ground(fails: Array[String], land: MapJourneyLandscape, seats: PackedVector3Array) -> void:
	var planting: Planting = land.wood.planting
	var decks: PackedVector3Array = planting._decks(0.5)
	var bad: Array[String] = []
	for i: int in range(planting.kinds.size()):
		if planting.from_kit[i] == 1:
			continue
		var base: Vector3 = planting.bases[i]
		var tree: bool = Planting.TREES.has(planting.kinds[i])
		if not land.terrain.is_dry(base):
			bad.append("wet %s" % base)
		var road: float = land.terrain.distance_to_roads(base)
		var deck_reach: float = Planting.DECK_CLEAR if tree else Planting.DECK_SHRUB
		var on_deck: bool = false
		for deck: Vector3 in decks:
			on_deck = on_deck or Vector2(deck.x - base.x, deck.z - base.z).length() < deck_reach - 0.75
		if on_deck:
			bad.append("on a bridge %s" % base)
		elif road < (1.0 if tree else 0.6):
			bad.append("on a road %s (%.2f m)" % [base, road])
		for seat: Vector3 in seats:
			if Vector2(seat.x - base.x, seat.z - base.z).length() < Planting.SEAT_CLEAR - 0.36:
				bad.append("on a waystone %s" % base)
	_check(fails, bad.is_empty(), "the wood stands dry, off the roads, bridges and waystones: %s" % [bad.slice(0, 3)])


## On the picture plane: no planted card hides a road's centreline behind it,
## and none standing in front of a waystone covers its touch square or its
## stone. Checked against the roads and seats themselves, not the planting's
## own grids.
static func _picture(fails: Array[String], land: MapJourneyLandscape, seats: PackedVector3Array) -> void:
	var planting: Planting = land.wood.planting
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	var toward: Vector3 = Vector3(0, sin(pitch), cos(pitch))
	# Centreline samples every 0.25 m, bucketed by metre of picture x.
	var columns: Dictionary = {}
	for line: PackedVector3Array in land.terrain.lines:
		for i: int in range(line.size() - 1):
			var steps: int = maxi(1, ceili(line[i].distance_to(line[i + 1]) / 0.25))
			for step: int in range(steps + 1):
				var q: Vector3 = line[i].lerp(line[i + 1], float(step) / steps)
				var at: Vector2 = MapJourneyCameraContract.projected_plane(q)
				var key: int = floori(at.x)
				var bucket: PackedVector3Array = columns.get(key, PackedVector3Array())
				bucket.append(Vector3(at.x, at.y, q.dot(toward)))
				columns[key] = bucket
	var square: float = Planting.seat_square()
	var hidden: Array[String] = []
	var covered: Array[String] = []
	for i: int in range(planting.kinds.size()):
		if planting.from_kit[i] == 1:
			continue
		var tile: int = planting.tiles[i]
		var rect: Rect2 = Atlas.rect(tile, planting.bases[i], planting.scales[i])
		var depth: float = planting.depth(i)
		for key: int in range(floori(rect.position.x), floori(rect.end.x) + 1):
			for point: Vector3 in columns.get(key, PackedVector3Array()):
				if point.z < depth - 0.1 and _inside(tile, rect, Vector2(point.x, point.y)):
					hidden.append("%s at %s" % [planting.kinds[i], planting.bases[i]])
					break
		for seat: Vector3 in seats:
			if seat.dot(toward) >= depth - 0.05:
				continue
			var at: Vector2 = MapJourneyCameraContract.projected_plane(seat)
			var guard: Rect2 = Rect2(at.x - square * 0.5, at.y - square * 0.5 - Planting.STONE_RISE,
				square, square + Planting.STONE_RISE).grow(-0.15)
			if not guard.intersects(rect):
				continue
			var y: float = guard.position.y
			while y <= guard.end.y and covered.size() < 3:
				var x: float = guard.position.x
				while x <= guard.end.x:
					if _inside(tile, rect, Vector2(x, y)):
						covered.append("%s at %s" % [planting.kinds[i], planting.bases[i]])
						break
					x += 0.2
				y += 0.2
	_check(fails, hidden.is_empty(), "no crown hides a road's centreline: %s" % [hidden.slice(0, 3)])
	_check(fails, covered.is_empty(), "no crown covers a waystone's touch square or stone: %s" % [covered])


## Whether picture-plane point `at` lies under the silhouette of `tile` drawn
## at `rect`.
static func _inside(tile: int, rect: Rect2, at: Vector2) -> bool:
	if not rect.has_point(at):
		return false
	var rows: PackedVector2Array = Atlas.spans[tile]
	var band: int = clampi(floori((at.y - rect.position.y) / rect.size.y * rows.size()), 0, rows.size() - 1)
	var x: float = (at.x - rect.position.x) / rect.size.x
	return x >= rows[band].x and x <= rows[band].y


## The art direction's mix: dark conifers about two trees in five, crimson
## broadleaf at most two in five, rust and amber the rest; olive and dark
## undergrowth among the red; fill crowns at 0.7 to 1.4 of their kind; the
## kit's own foliage kept where it stood; several times R2's woodland.
static func _mix(fails: Array[String], land: MapJourneyLandscape) -> void:
	var planting: Planting = land.wood.planting
	var counts: Dictionary = {}
	var kit_foliage: int = 0
	var scaled: bool = true
	for i: int in range(planting.kinds.size()):
		var kind: String = planting.kinds[i]
		counts[kind] = int(str(counts.get(kind, 0))) + 1
		kit_foliage += planting.from_kit[i]
		if planting.from_kit[i] == 0 and Planting.TREES.has(kind):
			scaled = scaled and planting.scales[i] >= Planting.TREE_SCALE.x - 0.001 \
				and planting.scales[i] <= Planting.TREE_SCALE.y + 0.001
	var trees: float = 0.0
	for kind: String in Planting.TREES:
		trees += int(str(counts.get(kind, 0)))
	var conifers: float = int(str(counts.get("conifer", 0))) + int(str(counts.get("conifer-spire", 0))) \
		+ int(str(counts.get("conifer-wind", 0)))
	var crimson: float = int(str(counts.get("ember-oak", 0))) + int(str(counts.get("ember-round", 0)))
	var warm: float = int(str(counts.get("rust-oak", 0))) + int(str(counts.get("amber-round", 0)))
	var undergrowth: float = planting.kinds.size() - trees
	var muted: float = int(str(counts.get("olive-heath", 0))) + int(str(counts.get("dark-copse", 0)))
	var share: String = "conifers %.2f, crimson %.2f, rust and amber %.2f, olive and dark %.2f" % [
		conifers / trees, crimson / trees, warm / trees, muted / undergrowth]
	_check(fails, conifers / trees >= 0.33 and conifers / trees <= 0.46 and crimson / trees <= 0.4
			and warm / trees >= 0.15 and muted / undergrowth >= 0.35,
		"the woodland's mix follows the art direction (%s)" % share)
	var kit_placed: int = 0
	for item: Dictionary in land.kit.placed:
		kit_placed += 1 if Atlas.KIT_KINDS.has(str(item["kind"])) else 0
	_check(fails, kit_foliage == kit_placed and planting.kinds.size() >= kit_placed * 4,
		"the kit's foliage stays where it stood, in a wood four times its size (%d of %d)" % [
			planting.kinds.size(), kit_placed])
	_check(fails, scaled, "every planted crown is 0.7 to 1.4 of its kind")


## One card per plant, nearest first in each draw, cut out by the atlas's one
## material and casting nothing; the trees' shadows from shadow-only casters.
static func _draws(fails: Array[String], land: MapJourneyLandscape) -> void:
	var planting: Planting = land.wood.planting
	var instances: int = 0
	var ordered: bool = true
	var posed: bool = true
	for card: MultiMeshInstance3D in land.wood.cards:
		var multi: MultiMesh = card.multimesh
		instances += multi.instance_count
		ordered = ordered and card.material_override == Atlas.material \
			and card.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var buffer: PackedFloat32Array = multi.buffer
		var last: float = INF
		for k: int in range(multi.instance_count):
			# Godot's MultiMesh buffer: the transform's three rows, colour, custom.
			var at: int = k * 20
			var origin: Vector3 = Vector3(buffer[at + 3], buffer[at + 7], buffer[at + 11])
			var depth: float = origin.dot(Vector3(0, sin(deg_to_rad(MapJourneyCameraContract.PITCH)),
				cos(deg_to_rad(MapJourneyCameraContract.PITCH))))
			ordered = ordered and depth <= last + 0.002
			last = depth
			var custom: Vector4 = Vector4(buffer[at + 16], buffer[at + 17], buffer[at + 18], buffer[at + 19])
			posed = posed and Atlas.uv.has(custom)
	_check(fails, instances == planting.kinds.size() and posed,
		"one card per plant, each painted with its tile (%d cards, %d plants)" % [instances, planting.kinds.size()])
	_check(fails, ordered, "the cards draw nearest first, with the atlas material, casting nothing")
	var casting: bool = not land.wood.casters.is_empty()
	for caster: MultiMeshInstance3D in land.wood.casters:
		casting = casting and caster.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_check(fails, casting, "the trees cast through shadow-only casters")
	var shader: Shader = preload("res://presentation/map/landscape/impostor.gdshader")
	_check(fails, shader.code.contains("global uniform float land_motion;")
			and shader.code.contains("sway * land_motion"),
		"the cards sway with the land's motion, and hold still without it")
	var card: MultiMeshInstance3D = land.wood.cards[0]
	var first: PackedFloat32Array = card.multimesh.buffer
	var match_found: bool = false
	for i: int in range(planting.kinds.size()):
		var pose: Transform3D = Atlas.card_transform(planting.tiles[i], planting.bases[i], planting.scales[i])
		if pose.origin.is_equal_approx(Vector3(first[3], first[7], first[11])):
			match_found = is_equal_approx(pose.basis.x.x, first[0]) and is_equal_approx(pose.basis.y.y, first[5]) \
				and is_equal_approx(pose.basis.y.z, first[9]) and is_equal_approx(pose.basis.z.y, first[6])
			break
	_check(fails, match_found, "a card's buffer rows are its card transform's")
