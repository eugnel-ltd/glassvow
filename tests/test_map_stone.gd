extends RefCounted
## Act I's stone (R3.3, issue #660), held where the headless suite can hold
## it: the stone's shader (three samplers, none anisotropic, the renderer's
## shared shadow pipeline, nothing that moves), the packed pieces (each kind's
## triangle budget, its own cell of the atlas, the outcrops inside the kit's
## footprints), and on a built land: the ravine's cliff pieces (on both banks
## of both rivers, faces to the water, feet under it, clear of the bridges and
## the waystones), the merged draws, the islands' composed groups, the
## gravestones and the ruins, and the ruins drawn as cards that cast into the
## floor's bake, and never sway; no ruin hiding a road, a waystone or what the
## kit keeps in sight; and a land built twice placed the same both times.

const Stone = preload("res://presentation/map/landscape/land_stone.gd")
const Cliffs = preload("res://presentation/map/landscape/ravine_cliffs.gd")
const Islands = preload("res://presentation/map/landscape/land_islands.gd")
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Sight = preload("res://presentation/map/landscape/wood_sight.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const SEED: int = 717
## Seeds whose lands main placed rocks over the water on (R3.3 found two to
## five a land): every outcrop stays off it on each.
const MORE_SEEDS: Array[int] = [1, 2, 3]
## Each family's triangle budget (`outcrops.py`, `cliffs.py`).
const OUTCROP_TRIANGLES: Vector2i = Vector2i(800, 1500)
const CLIFF_TRIANGLES: Vector2i = Vector2i(900, 1200)
## Road samples (metres apart) and the height of a waystone's top, where its
## token is drawn, for the ruins' sight.
const ROAD_STEP: float = 0.5
const WAYSTONE_TOP: float = 1.0


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_stone: %s" % what)


static func run(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	_shader(fails)
	_pieces(fails)
	var content: ContentDB = ContentDB.load_full()
	var first: String = ""
	for seed_value: int in [SEED] + MORE_SEEDS:
		var screen: WorldMapScreen = _open(content, seed_value)
		var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
		var built: bool = land != null and land.is_built() and land.kit.stone != null
		_check(fails, built, "Act I's land is built with its stone (seed %d)" % seed_value)
		if built:
			var seats: PackedVector3Array = []
			for base: Node3D in land.journey.bases:
				seats.append(base.position)
			_cliffs(fails, land, seats, seed_value)
			_dry(fails, land, seed_value)
			_unhidden(fails, land, seats, seed_value)
		if built and seed_value == SEED:
			_draws(fails, land)
			_islands(fails, land)
			_ruins(fails, land)
			first = _digest(land)
		_close(screen)
	_determinism(fails, content, first)


static func _open(content: ContentDB, seed_value: int) -> WorldMapScreen:
	var run_state: RunState = RunState.new_run(content, seed_value, "run-map-stone")
	var screen: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(run_state, content), content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.size = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	screen.set_shape(StageShape.IDENTITY)
	screen.refresh(run_state)
	return screen


static func _close(screen: WorldMapScreen) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


## The same seed builds the same land: every kit placement, every stone piece
## and every woodland card, the second time as the first.
static func _determinism(fails: Array[String], content: ContentDB, first: String) -> void:
	if first.is_empty():
		return
	var screen: WorldMapScreen = _open(content, SEED)
	var land: MapJourneyLandscape = screen._map_scene.journey_landscape()
	var again: String = _digest(land) if land != null and land.is_built() and land.kit.stone != null else ""
	_check(fails, again == first,
		"seed %d's land places every stone, ruin and woodland card the same when built again" % SEED)
	_close(screen)


## A digest of a land's placements: the kit's, the stone's pieces and the
## woodland's cards (the ruins among them).
static func _digest(land: MapJourneyLandscape) -> String:
	var parts: PackedStringArray = []
	for item: Dictionary in land.kit.placed:
		parts.append("kit %s %s %s %s" % [item["kind"], item["position"], item["scale"], item["yaw"]])
	for item: Dictionary in land.kit.stone.placed:
		parts.append("stone %s %s" % [item["kind"], item["transform"]])
	var planting: Planting = land.wood.planting
	for i: int in range(planting.kinds.size()):
		parts.append("card %s %s %d %s" % [planting.kinds[i], planting.bases[i], planting.tiles[i], planting.scales[i]])
	return "\n".join(parts).sha256_text()


## Three samplers, none anisotropic (the A12's slots); no vertex stage of its
## own, so it casts through the renderer's shared shadow pipeline; nothing
## that moves (Reduce Motion has nothing to hold).
static func _shader(fails: Array[String]) -> void:
	var code: String = (load("res://presentation/map/landscape/stone.gdshader") as Shader).code
	var samplers: PackedStringArray = []
	for line: String in code.split("\n"):
		if line.begins_with("uniform sampler2D"):
			samplers.append(line)
	_check(fails, samplers.size() == 3 and not "".join(samplers).contains("anisotropic"),
		"the stone binds three samplers, none anisotropic")
	_check(fails, not code.contains("void vertex(") and not code.contains("TIME"),
		"the stone has no vertex stage of its own and nothing that moves")
	var paint: String = (load("res://presentation/map/landscape/floor_paint.gdshader") as Shader).code
	_check(fails, paint.contains("uniform sampler2D strata") and paint.contains("f.scarp"),
		"the floor's bake lays the strata on the steep banks")


## Every kind packed, with tangents for its normals; within its family's
## budget; in a cell of the atlas no other kind's reaches; the outcrops inside
## the footprint the kit places them by.
static func _pieces(fails: Array[String]) -> void:
	_check(fails, Stone.prepare_step(true) and not Stone.failed and Stone.material() != null,
		"the stone's pieces and atlas load")
	if Stone.failed:
		return
	var budgets: bool = true
	var cells: Array[Rect2] = []
	var apart: bool = true
	var inside: bool = true
	for kind: String in Array(Stone.OUTCROPS) + Array(Stone.CLIFFS):
		var arrays: Array = Stone._pieces.arrays.get(kind, [])
		if arrays.is_empty():
			budgets = false
			continue
		var triangles: int = Stone.piece_triangles(kind)
		var budget: Vector2i = OUTCROP_TRIANGLES if Stone.OUTCROPS.has(kind) else CLIFF_TRIANGLES
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		budgets = budgets and triangles >= budget.x and triangles <= budget.y and tangents.size() == points.size() * 4
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var cell: Rect2 = Rect2(uvs[0], Vector2.ZERO)
		for uv: Vector2 in uvs:
			cell = cell.expand(uv)
		for other: Rect2 in cells:
			apart = apart and not other.grow(-0.001).intersects(cell.grow(-0.001))
		cells.append(cell)
		if Stone.OUTCROPS.has(kind):
			var profile: Vector2 = MapJourneyLandscape.Kit.PROFILES[kind]
			var reach: float = 0.0
			for point: Vector3 in points:
				reach = maxf(reach, Vector2(point.x, point.z).length())
			inside = inside and reach <= profile.x * 1.05 and Stone.extent(kind).end.y <= profile.y * 1.1
	_check(fails, budgets, "every stone kind is packed with its tangents, within its family's triangle budget")
	_check(fails, apart and cells.size() == 11, "each kind keeps to its own cell of the atlas")
	_check(fails, inside, "every outcrop stands inside the footprint the kit places it by")


## The cliffs: on both banks of both rivers; each face turned to its river's
## line, its origin `ORIGIN` from it at the rim, its foot under the water,
## never shrunk, never below the journey camera's slab; none by a bridge deck,
## an abutment or a waystone, or past the land's near and far edges (where its
## foot would hang below the land).
static func _cliffs(fails: Array[String], land: MapJourneyLandscape, seats: PackedVector3Array, seed_value: int) -> void:
	var banks: Dictionary = {}
	var faced: bool = true
	var footed: bool = true
	var clear: bool = true
	var decks: PackedVector3Array = Cliffs._decks(land.terrain)
	var far_edge: float = maxf(-land.terrain.river_half_length, land.terrain.bounds.position.y) + Cliffs.EDGE
	var near_edge: float = minf(land.terrain.river_half_length, land.terrain.bounds.end.y) - Cliffs.NEAR_EDGE
	var inside: bool = true
	for item: Dictionary in land.kit.stone.placed:
		var kind: String = item["kind"]
		if not Stone.CLIFFS.has(kind):
			continue
		var pose: Transform3D = item["transform"]
		var at: Vector3 = pose.origin
		var cut: float = MapRavine.CUTS[0] if absf(at.x - River.centre(at.z, MapRavine.CUTS[0])) \
			< absf(at.x - River.centre(at.z, MapRavine.CUTS[1])) else MapRavine.CUTS[1]
		var line: float = River.centre(at.z, cut)
		var side: int = 1 if at.x > line else -1
		banks["%s %d" % [cut, side]] = int(str(banks.get("%s %d" % [cut, side], 0))) + 1
		var face: Vector3 = pose.basis.z.normalized()
		var size: float = pose.basis.get_scale().x
		faced = faced and face.x * -side > 0.85 and absf(absf(at.x - line) - Cliffs.ORIGIN) < 0.35
		# The piece's own lowest point, from its packed mesh.
		var foot: float = at.y + Stone.extent(kind).position.y * size
		footed = footed and size >= 0.999 and foot <= River.LEVEL - Cliffs.FOOT + 0.01 \
			and foot >= MapJourneyCameraContract.LAND_LOW
		for deck: Vector3 in decks:
			clear = clear and Vector2(at.x, at.z).distance_to(Vector2(deck.x, deck.z)) >= Cliffs.DECK_CLEAR
		for seat: Vector3 in seats:
			clear = clear and Vector2(at.x, at.z).distance_to(Vector2(seat.x, seat.z)) >= Cliffs.SEAT_CLEAR
		# The rule spaces pieces along the line; a piece's origin stands off it
		# square to the line, so up to a metre along z either way.
		inside = inside and at.z >= far_edge - 1.0 and at.z <= near_edge + 1.0
	var each: bool = banks.size() == 4
	for bank: String in banks:
		each = each and int(str(banks[bank])) >= 4
	_check(fails, each, "the cliffs line both banks of both rivers (seed %d: %s)" % [seed_value, banks])
	_check(fails, faced, "every cliff piece faces the water from its bank, at the rim (seed %d)" % seed_value)
	_check(fails, footed, "every cliff piece's foot reaches under the water, never shrunk, inside the camera's slab (seed %d)" % seed_value)
	_check(fails, clear, "no cliff piece stands by a bridge deck or a waystone (seed %d)" % seed_value)
	_check(fails, inside, "no cliff piece stands past the land's near or far edge (seed %d)" % seed_value)


## One merged draw a cell, all on the stone's material, casting (into the
## floor's bake); their triangles every piece's; every outcrop's circle kept
## off the rivers' water but for its reach over the bank.
static func _draws(fails: Array[String], land: MapJourneyLandscape) -> void:
	var stone: Stone = land.kit.stone
	var cells: Dictionary = {}
	var expected: int = 0
	var outcrops: int = 0
	for item: Dictionary in stone.placed:
		var pose: Transform3D = item["transform"]
		var at: Vector3 = pose.origin
		cells[Vector2i(floori(at.x / Stone.CELL), floori(at.z / Stone.CELL))] = true
		expected += Stone.piece_triangles(str(item["kind"]))
		outcrops += 1 if Stone.OUTCROPS.has(str(item["kind"])) else 0
	var placed_rocks: int = 0
	for item: Dictionary in land.kit.placed:
		placed_rocks += 1 if MapJourneyLandscape.Kit.is_rock(str(item["kind"])) else 0
	var drawn: int = 0
	var shared: bool = true
	for draw: MeshInstance3D in stone.draws:
		drawn += draw.mesh.surface_get_array_index_len(0) / 3
		shared = shared and draw.material_override == Stone.material() \
			and draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_check(fails, outcrops == placed_rocks and outcrops > 0,
		"every outcrop the kit placed is drawn by the stone (%d of %d)" % [outcrops, placed_rocks])
	_check(fails, stone.draws.size() == cells.size() and shared and drawn == expected and stone.triangles == expected,
		"the stone draws once a cell on its one material, casting, every piece's triangles (%d draws, %d triangles)" % [
			stone.draws.size(), drawn])


## No ruin's card hides what the woodland keeps in sight, on the land as
## placed: no road (sampled along its line), waystone or token (the stone's
## top) stands behind a ruin's silhouette; and, in the kit's own order
## (`kit.gd` `_unhidden`), no shrine, gateway, rock or standing ruin was
## placed behind the card of a ruin placed before it.
static func _unhidden(fails: Array[String], land: MapJourneyLandscape, seats: PackedVector3Array, seed_value: int) -> void:
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	var toward: Vector3 = Vector3(0, sin(pitch), cos(pitch))
	var sight: Sight = Sight.new()
	sight.begin(land.terrain.bounds)
	var kept: PackedVector3Array = []
	for line: PackedVector3Array in land.terrain.lines:
		for i: int in range(line.size() - 1):
			var steps: int = maxi(1, ceili(line[i].distance_to(line[i + 1]) / ROAD_STEP))
			for step: int in range(steps):
				kept.append(line[i].lerp(line[i + 1], float(step) / steps))
	for seat: Vector3 in seats:
		kept.append(seat)
		kept.append(seat + Vector3.UP * WAYSTONE_TOP)
	var ruins: int = 0
	var seen_hidden: int = 0
	var items_hidden: int = 0
	var placed: Array = land.kit.placed
	for h: int in range(placed.size()):
		var kind: String = placed[h]["kind"]
		if not Atlas.RUINS.has(kind) or not Atlas.by_kind.has(kind):
			continue
		ruins += 1
		var base: Vector3 = placed[h]["position"]
		var scale_value: float = float(str(placed[h]["scale"]))
		var tile: int = Atlas.tile_for(kind, float(str(placed[h]["yaw"])))
		var cover: Rect2 = Atlas.rect(tile, base, scale_value)
		var front: float = base.dot(toward) + Atlas.shift(tile) * scale_value
		for q: Vector3 in kept:
			if q.dot(toward) < front and _under(tile, cover, MapJourneyCameraContract.projected_plane(q)):
				seen_hidden += 1
		for t: int in range(h + 1, placed.size()):
			var later: Dictionary = placed[t]
			var area: Array = Planting.protected_area(sight, later)
			if area.is_empty():
				continue
			var kept_rect: Rect2 = area[0]
			var kept_depth: float = area[1]
			if front + Sight.DEPTH_MARGIN > kept_depth and cover.intersects(kept_rect):
				items_hidden += 1
	_check(fails, ruins > 0 and seen_hidden == 0,
		"no ruin's card hides a road, a waystone or its token (seed %d: %d points behind %d ruins)" % [
			seed_value, seen_hidden, ruins])
	_check(fails, items_hidden == 0,
		"no shrine, gateway, rock or standing ruin stands behind a ruin's card (seed %d: %d)" % [seed_value, items_hidden])


## Whether a picture-plane point lies under a tile's silhouette at `cover`
## (`ImpostorAtlas.spans`: per row of the card, the span its picture covers).
static func _under(tile: int, cover: Rect2, at: Vector2) -> bool:
	if not cover.has_point(at):
		return false
	var rows: PackedVector2Array = Atlas.spans[tile]
	var row: int = mini(rows.size() - 1, floori((at.y - cover.position.y) / (cover.size.y / rows.size())))
	var x: float = (at.x - cover.position.x) / cover.size.x
	return rows[row].x <= rows[row].y and x >= rows[row].x and x <= rows[row].y


## Every outcrop's circle kept off the rivers' water but for its reach over
## the bank (`kit.gd` `ROCK_WATER`).
static func _dry(fails: Array[String], land: MapJourneyLandscape, seed_value: int) -> void:
	var water: float = River.HALF_WIDTH * River.CHANNEL
	var wet: int = 0
	for item: Dictionary in land.kit.placed:
		if not MapJourneyLandscape.Kit.is_rock(str(item["kind"])):
			continue
		var at: Vector3 = item["position"]
		if River.distance(at.x, at.z) * River.CHANNEL \
				< water + float(str(item["radius"])) * MapJourneyLandscape.Kit.ROCK_WATER - 0.001:
			wet += 1
	_check(fails, wet == 0, "no outcrop reaches over the rivers' water (seed %d: %d do)" % [seed_value, wet])


## Each island between the road loops is anchored: an outcrop near its pole,
## with a conifer and gravestones round it.
static func _islands(fails: Array[String], land: MapJourneyLandscape) -> void:
	var found: Array[Dictionary] = Islands.find(land.terrain)
	var anchored: int = 0
	var groups: int = mini(found.size(), MapJourneyLandscape.Kit.ISLAND_GROUPS)
	for island: Dictionary in found.slice(0, groups):
		var pole: Vector3 = island["centre"]
		var rock: bool = false
		var grave: bool = false
		for item: Dictionary in land.kit.placed:
			var at: Vector3 = item["position"]
			var near: bool = Vector2(pole.x, pole.z).distance_to(Vector2(at.x, at.z)) < 4.5
			rock = rock or (near and MapJourneyLandscape.Kit.is_rock(str(item["kind"])))
			grave = grave or (near and Atlas.GRAVES.has(str(item["kind"])))
		anchored += 1 if rock and grave else 0
	_check(fails, groups > 0 and anchored * 4 >= groups * 3,
		"the islands between the road loops are anchored by an outcrop and gravestones (%d of %d)" % [anchored, groups])


## Gravestones and broken walls stand where the kit places them, every one
## drawn as a card at the kit's scale (the kit places a ruin only where its
## card hides nothing the woodland keeps in sight, `kit.gd` `_in_sight`); the
## standing ones cast into the floor's bake through their cards.
static func _ruins(fails: Array[String], land: MapJourneyLandscape) -> void:
	var graves: int = 0
	var beyond: int = 0
	var poles: Array[Dictionary] = Islands.find(land.terrain)
	var walls: int = 0
	var placed_ruins: int = 0
	var off_roads: bool = true
	for item: Dictionary in land.kit.placed:
		var kind: String = item["kind"]
		if Atlas.GRAVES.has(kind):
			graves += 1
			var grave_at: Vector3 = item["position"]
			var on_island: bool = false
			for island: Dictionary in poles.slice(0, MapJourneyLandscape.Kit.ISLAND_GROUPS):
				var pole: Vector3 = island["centre"]
				on_island = on_island or Vector2(pole.x, pole.z).distance_to(Vector2(grave_at.x, grave_at.z)) < 4.5
			beyond += 0 if on_island else 1
		placed_ruins += 1 if Planting.STONES.has(kind) else 0
		if Atlas.WALLS.has(kind):
			walls += 1
			var at: Vector3 = item["position"]
			var road: float = land.terrain.distance_to_roads(at)
			off_roads = off_roads and road >= MapJourneyLandscape.Kit.RUIN_ROAD.x and road <= MapJourneyLandscape.Kit.RUIN_ROAD.y
	var planting: Planting = land.wood.planting
	var carded: int = 0
	var casting: int = 0
	var whole: bool = true
	var rigid: bool = true
	for i: int in range(planting.kinds.size()):
		if not Planting.STONES.has(planting.kinds[i]):
			continue
		carded += 1
		casting += 1 if Planting.casts(planting.kinds[i]) else 0
		whole = whole and planting.from_kit[i] == 1
		rigid = rigid and MapJourneyLandscape.ImpostorWood.card_colour(planting.kinds[i], planting.bases[i], planting.tiles[i]).a == 0.0
	var cards: int = 0
	for i: int in range(planting.kinds.size()):
		cards += 1 if Planting.casts(planting.kinds[i]) else 0
	_check(fails, graves >= 6 and graves <= MapJourneyLandscape.Kit.GRAVES_MOST + 3 * MapJourneyLandscape.Kit.ISLAND_GROUPS,
		"gravestones are scattered by the shrines, the verges and the islands (%d)" % graves)
	_check(fails, beyond >= 6, "gravestones stand by the shrines and the verges, not only on the islands (%d)" % beyond)
	var by_shrines: int = 0
	for item: Dictionary in land.kit.placed:
		if not Atlas.GRAVES.has(str(item["kind"])):
			continue
		var grave_at: Vector3 = item["position"]
		for other: Dictionary in land.kit.placed:
			var shrine: Vector3 = other["position"]
			if str(other["kind"]) == "memorial" and Vector2(shrine.x, shrine.z).distance_to(Vector2(grave_at.x, grave_at.z)) < 3.2:
				by_shrines += 1
				break
	_check(fails, by_shrines >= 3, "gravestones stand beside the memorial shrines (%d)" % by_shrines)
	_check(fails, walls >= 1 and walls <= MapJourneyLandscape.Kit.RUIN_SITES and off_roads,
		"a few broken walls stand a little off the roads (%d)" % walls)
	_check(fails, whole and carded == placed_ruins and carded > 0,
		"every ruin is drawn as a card where the kit placed it (%d of %d)" % [carded, placed_ruins])
	_check(fails, land.forest_floor.plan.caster_count == cards and casting > 0,
		"the standing ruins cast into the floor's bake through their cards")
	_check(fails, rigid and carded > 0, "no ruin's card sways: its base sits at the card's top")
