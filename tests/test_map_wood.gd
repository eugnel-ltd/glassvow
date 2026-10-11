extends RefCounted
## Act I's woodland as impostor cards (R3.1, issue #660) on the production
## path: the baked atlas and how it loads, where the wood stands (off the
## roads, the river, the bridges and the stones), what every card leaves in
## sight (a road's centreline, a bridge deck, a lamp's flame, the river's water,
## a rock's body, a waystone's touch square), its mix of kinds by plants and by
## the canopy each shows, its crown sizes, its draws and their sway, and the
## clip slab it must fit.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Landform = preload("res://presentation/map/landscape/landform.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const SEED: int = 717


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_wood: %s" % what)


static func run(fails: Array[String]) -> void:
	MapJourneyLandscape.Kit.preload_scenes()
	_atlas(fails)
	_pages(fails)
	_loading(fails)
	_squares(fails)
	_slab(fails)
	# Unset, the planting keeps the widest touch square clear (the phone's);
	# the pad's narrower square is planted and checked on a land of its own.
	_land(fails, &"", true)
	_land(fails, &"pad-landscape", false)


## Builds Act I's land with the woodland planted for `shape`'s touch square and
## checks it; `everything` adds the mix and the draws, which no shape changes.
static func _land(fails: Array[String], shape: StringName, everything: bool) -> void:
	var kept: StringName = Planting.stage_shape
	Planting.stage_shape = shape
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
		"Act I's land is built with its woodland (shape '%s')" % shape)
	if land != null and land.is_built() and land.wood != null:
		var seats: PackedVector3Array = []
		for base: Node3D in land.journey.bases:
			seats.append(base.position)
		_ground(fails, land, seats)
		_picture(fails, land, seats)
		if everything:
			_mix(fails, land)
			_draws(fails, land)
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()
	Planting.stage_shape = kept


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


## The decision every card's shaders make: a tile's instance data
## (`Atlas.custom`), read back as `impostor.gdshader` and `floor_caster.gdshader`
## read it (the page is the whole part of the rect's top), finds that tile's
## own picture on its page of the atlas, the silhouette the packer recorded for
## it, row for row. The atlas is two pages, a layer each, and both hold tiles.
static func _pages(fails: Array[String]) -> void:
	var albedo: TextureLayered = null
	if Atlas.ready():
		albedo = Atlas.material.get_shader_parameter("atlas_albedo")
	var picture: Image = Image.load_from_file(Atlas.ALBEDO_PATH)
	var paged: bool = albedo != null and picture != null and albedo.get_layers() == 2 \
		and picture.get_width() == albedo.get_width() and picture.get_height() == 2 * albedo.get_height()
	_check(fails, paged, "the woodland's atlas is two pages of its picture, a layer each")
	if not paged:
		return
	picture.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = picture.get_data()
	var width: int = picture.get_width()
	var page_h: int = albedo.get_height()
	var pages_used: Dictionary = {}
	var wrong: PackedStringArray = []
	for tile: int in range(Atlas.uv.size()):
		var custom: Vector4 = Atlas.custom(tile)
		var page: int = floori(custom.y)
		pages_used[page] = true
		var corner: Vector2i = Vector2i(roundi(custom.x * width), page * page_h + roundi((custom.y - page) * page_h))
		var extent: Vector2i = Vector2i(roundi(custom.z * width), roundi(custom.w * page_h))
		if page < 0 or page > 1 or not _silhouette_matches(data, width, corner, extent, Atlas.spans[tile]):
			wrong.append("%s (page %d)" % [Atlas.tile_kinds[tile], page])
	_check(fails, wrong.is_empty() and pages_used.size() == 2,
		"every tile's card samples its own picture on its page, and both pages hold tiles (wrong: %s)" % ", ".join(wrong))


## Whether the picture's cover in the rect at `corner` of `extent` texels has
## the silhouette `spans` (`pack_impostors.py` `spans`: per band of rows the
## first and last covered column, from coverage of at least a half).
static func _silhouette_matches(data: PackedByteArray, width: int, corner: Vector2i, extent: Vector2i,
		spans: PackedVector2Array) -> bool:
	var rows: int = spans.size()
	for r: int in range(rows):
		var from: int = corner.y + int(float(r * extent.y) / rows)
		var to: int = maxi(from + 1, corner.y + int(float((r + 1) * extent.y) / rows))
		var first: int = -1
		for x: int in range(extent.x):
			if _covered(data, width, corner.x + x, from, to):
				first = x
				break
		var expected: Vector2 = spans[r]
		if first < 0:
			if expected != Vector2(1.0, 0.0):
				return false
			continue
		var last: int = first
		for x: int in range(extent.x - 1, first - 1, -1):
			if _covered(data, width, corner.x + x, from, to):
				last = x
				break
		if absf(float(first) / extent.x - expected.x) > 0.001 or absf(float(last + 1) / extent.x - expected.y) > 0.001:
			return false
	return true


static func _covered(data: PackedByteArray, width: int, x: int, from: int, to: int) -> bool:
	for y: int in range(from, to):
		if data[(y * width + x) * 4 + 3] >= 128:
			return true
	return false


## The atlas's textures are taken from the loader once each (a second
## `load_threaded_get` of a path returns null), and a texture that cannot load
## ends the wait instead of holding the map's opening.
static func _loading(fails: Array[String]) -> void:
	var states: Dictionary = {"albedo": ResourceLoader.THREAD_LOAD_LOADED,
		"normal": ResourceLoader.THREAD_LOAD_IN_PROGRESS}
	var handed: Dictionary = {}
	var take: Atlas.Take = Atlas.Take.new(PackedStringArray(["albedo", "normal"]))
	take.ask = func(_path: String, _hint: String) -> bool:
		return true
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
	_one_at_a_time(fails)


## The kit's textures load one at a time (R3.3): a take asks the loader for a
## path only once the one before it is taken, so never more than one of its
## uploads is in flight, and overlapping uploads never take transfer workers of
## their own. The kit's two takes are this kind: the atlas's, and the stone's
## (`LandStone.prepare_step`), which `Kit.preload_step` begins only once the
## atlas's has settled.
static func _one_at_a_time(fails: Array[String]) -> void:
	var paths: PackedStringArray = ["a", "b", "c"]
	var asked: PackedStringArray = []
	var states: Dictionary = {"a": ResourceLoader.THREAD_LOAD_IN_PROGRESS,
		"b": ResourceLoader.THREAD_LOAD_IN_PROGRESS, "c": ResourceLoader.THREAD_LOAD_IN_PROGRESS}
	var take: Atlas.Take = Atlas.Take.new(paths)
	var most: Array[int] = [0]
	take.ask = func(path: String, _hint: String) -> bool:
		asked.append(path)
		most[0] = maxi(most[0], asked.size() - take.textures.size())
		return true
	take.status = func(path: String) -> int:
		return states[path]
	take.get_texture = func(_path: String) -> Variant:
		return ImageTexture.new()
	take.request()
	take.request()
	var waiting: bool = not take.step(false)
	var first: String = ",".join(asked)
	states["a"] = ResourceLoader.THREAD_LOAD_LOADED
	waiting = waiting and not take.step(false)
	var second: String = ",".join(asked)
	states["b"] = ResourceLoader.THREAD_LOAD_LOADED
	states["c"] = ResourceLoader.THREAD_LOAD_LOADED
	var settled: bool = take.step(false)
	_check(fails, waiting and settled and first == "a" and second == "a,b" and ",".join(asked) == "a,b,c"
			and most[0] == 1 and take.textures.size() == 3 and not take.failed,
		"a take asks for each texture only once the one before it is taken (asked: %s, then %s; most in flight %d)" % [
			first, second, most[0]])


## A waystone's touch square on the picture plane is the shape's own: the
## pad's and the desktop's 60 px of 820 (1.4 m at the Journey zoom), the
## phone's 60 px of 390 (about 3 m), and until Main sets a shape, the widest.
static func _squares(fails: Array[String]) -> void:
	var kept: StringName = Planting.stage_shape
	var squares: PackedFloat64Array = []
	for shape: StringName in [&"pad-landscape", &"desktop-landscape", &"phone-landscape", &""]:
		Planting.stage_shape = shape
		squares.append(Planting.seat_square())
	Planting.stage_shape = kept
	_check(fails, is_equal_approx(squares[0], 60.0 / 820.0 * 19.2) and is_equal_approx(squares[1], squares[0])
			and is_equal_approx(squares[2], 60.0 / 390.0 * 19.2) and is_equal_approx(squares[3], squares[2]),
		"each shape keeps its own touch square clear, the widest until a shape is set (%s)" % [squares])


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


## Where the fill stands on the ground (the kit's own foliage stands where the
## kit placed it): dry; trunks off the roads and their verges, undergrowth off
## the roads; nothing on a bridge or a waystone.
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


## On the picture plane, every card, the kit's adopted foliage included: none
## hides a road's centreline, a bridge deck, a lamp's flame or the river's
## water behind it, nor covers a rock's body or a waystone's touch square and
## stone from in front. Checked against the land's own roads, bridges, lamps,
## rivers, rocks and seats, not the planting's grids.
static func _picture(fails: Array[String], land: MapJourneyLandscape, seats: PackedVector3Array) -> void:
	var planting: Planting = land.wood.planting
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	var toward: Vector3 = Vector3(0, sin(pitch), cos(pitch))
	# What must stay in sight, as picture-plane points with their depth, by
	# what they are, and bucketed by metre of picture x.
	var sights: Dictionary = {}
	for line: PackedVector3Array in land.terrain.lines:
		for i: int in range(line.size() - 1):
			var steps: int = maxi(1, ceili(line[i].distance_to(line[i + 1]) / 0.25))
			for step: int in range(steps + 1):
				_sight_point(sights, "a road's centreline", line[i].lerp(line[i + 1], float(step) / steps), toward)
	for deck: Vector3 in planting._decks(0.5):
		_sight_point(sights, "a bridge deck", deck, toward)
	for flame: Vector3 in land.kit.lamp_anchors():
		_sight_point(sights, "a lamp's flame", flame, toward)
	for cut: float in MapRavine.CUTS:
		var z: float = -land.terrain.river_half_length
		while z <= land.terrain.river_half_length:
			for across: float in [-0.75, 0.0, 0.75]:
				_sight_point(sights, "the river's water", Vector3(River.centre(z, cut) + across, River.LEVEL, z), toward)
			z += 0.25
	var rocks: int = 0
	for item: Dictionary in land.kit.placed:
		if not MapJourneyLandscape.Kit.is_rock(str(item["kind"])):
			continue
		rocks += 1
		var base: Vector3 = item["position"]
		var across: float = float(str(item["radius"])) * 0.5
		var height: float = float(str(item["height"]))
		for gx: float in [-across, 0.0, across]:
			for share: float in [0.35, 0.55, 0.75]:
				var point: Vector3 = base + Vector3(gx, height * share, 0.0)
				# A rock's body counts from its base's depth: what stands in
				# front of the rock covers it.
				var at: Vector2 = MapJourneyCameraContract.projected_plane(point)
				var bucket: Array = sights.get(floori(at.x), [])
				bucket.append(["a rock's body", at, base.dot(toward)])
				sights[floori(at.x)] = bucket
	var square: float = Planting.seat_square()
	var hidden: Dictionary = {}
	var covered: Array[String] = []
	for i: int in range(planting.kinds.size()):
		var tile: int = planting.tiles[i]
		var rect: Rect2 = Atlas.rect(tile, planting.bases[i], planting.scales[i])
		var depth: float = planting.depth(i)
		for key: int in range(floori(rect.position.x), floori(rect.end.x) + 1):
			for point: Array in sights.get(key, []):
				var what: String = point[0]
				var at: Vector2 = point[1]
				var behind: float = point[2]
				if behind < depth - 0.1 and _inside(tile, rect, at) and not hidden.has(what):
					hidden[what] = "%s%s at %s" % [planting.kinds[i], " (kit)" if planting.from_kit[i] == 1 else "",
						planting.bases[i]]
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
	_check(fails, hidden.is_empty() and rocks > 0,
		"no card hides a centreline, a deck, a flame, the water or a rock: %s" % [hidden])
	_check(fails, covered.is_empty(), "no crown covers a waystone's touch square or stone: %s" % [covered])


static func _sight_point(sights: Dictionary, what: String, point: Vector3, toward: Vector3) -> void:
	var at: Vector2 = MapJourneyCameraContract.projected_plane(point)
	var bucket: Array = sights.get(floori(at.x), [])
	bucket.append([what, at, point.dot(toward)])
	sights[floori(at.x)] = bucket


## Whether picture-plane point `at` lies under the silhouette of `tile` drawn
## at `rect`.
static func _inside(tile: int, rect: Rect2, at: Vector2) -> bool:
	if not rect.has_point(at):
		return false
	var rows: PackedVector2Array = Atlas.spans[tile]
	var band: int = clampi(floori((at.y - rect.position.y) / rect.size.y * rows.size()), 0, rows.size() - 1)
	var x: float = (at.x - rect.position.x) / rect.size.x
	return x >= rows[band].x and x <= rows[band].y


## The art direction's mix by plants: dark conifers 35 to 40% of the trees,
## crimson broadleaf at most 40%, rust and amber about 20%; most undergrowth
## olive and dark. By the canopy each shows (the front-most card over the
## whole land's picture): crimson leads the broadleaf, rust and amber stay a
## minority, the dark conifers carry a real share. Fill crowns at 0.7 to 1.4
## of their kind; the kit's own foliage kept where it fits, in a wood several
## times its size.
static func _mix(fails: Array[String], land: MapJourneyLandscape) -> void:
	var planting: Planting = land.wood.planting
	var counts: Dictionary = {}
	var kit_foliage: int = 0
	var scaled: bool = true
	for i: int in range(planting.kinds.size()):
		var family: String = _family(planting.kinds[i])
		counts[family] = int(str(counts.get(family, 0))) + 1
		kit_foliage += planting.from_kit[i]
		if planting.from_kit[i] == 0 and Planting.TREES.has(planting.kinds[i]):
			scaled = scaled and planting.scales[i] >= Planting.TREE_SCALE.x - 0.001 \
				and planting.scales[i] <= Planting.TREE_SCALE.y + 0.001
	var trees: float = int(str(counts.get("conifer", 0))) + int(str(counts.get("crimson", 0))) \
		+ int(str(counts.get("rust and amber", 0)))
	var ruins: int = 0
	for kind: String in planting.kinds:
		ruins += 1 if Planting.STONES.has(kind) else 0
	var undergrowth: float = planting.kinds.size() - trees - ruins
	var conifers: float = int(str(counts.get("conifer", 0))) / trees
	var crimson: float = int(str(counts.get("crimson", 0))) / trees
	var warm: float = int(str(counts.get("rust and amber", 0))) / trees
	var muted: float = int(str(counts.get("olive and dark", 0))) / undergrowth
	_check(fails, conifers >= 0.35 and conifers <= 0.40 and crimson <= 0.40 and warm >= 0.15 and warm <= 0.27
			and muted >= 0.5,
		"the woodland's mix by plants follows the art direction (conifers %.3f, crimson %.3f, rust and amber %.3f, olive and dark undergrowth %.3f)" % [
			conifers, crimson, warm, muted])
	var shown: Dictionary = _canopy(planting)
	var tree_area: float = float(str(shown.get("conifer", 0))) + float(str(shown.get("crimson", 0))) \
		+ float(str(shown.get("rust and amber", 0)))
	var conifer_shown: float = float(str(shown.get("conifer", 0))) / maxf(tree_area, 1.0)
	var crimson_shown: float = float(str(shown.get("crimson", 0))) / maxf(tree_area, 1.0)
	var warm_shown: float = float(str(shown.get("rust and amber", 0))) / maxf(tree_area, 1.0)
	_check(fails, crimson_shown >= 1.5 * warm_shown and warm_shown <= 0.25 and conifer_shown >= 0.2,
		"by the canopy it shows, crimson leads, rust and amber stay a minority and the conifers show (conifers %.3f, crimson %.3f, rust and amber %.3f)" % [
			conifer_shown, crimson_shown, warm_shown])
	var kit_placed: int = 0
	for item: Dictionary in land.kit.placed:
		kit_placed += 1 if Atlas.KIT_KINDS.has(str(item["kind"])) else 0
	var left_out: int = planting.rejected.get("kit sight", 0)
	_check(fails, kit_foliage + left_out == kit_placed and left_out * 10 < kit_placed
			and planting.kinds.size() >= kit_placed * 4,
		"the kit's foliage stays where it fits (%d of %d, %d left out), in a wood four times its size (%d)" % [
			kit_foliage, kit_placed, left_out, planting.kinds.size()])
	_check(fails, scaled, "every planted crown is 0.7 to 1.4 of its kind")


static func _family(kind: String) -> String:
	if kind.begins_with("conifer"):
		return "conifer"
	if kind.begins_with("ember"):
		return "crimson"
	if kind == "rust-oak" or kind == "amber-round":
		return "rust and amber"
	if kind == "olive-heath" or kind == "dark-copse":
		return "olive and dark"
	return "red undergrowth"


## Picture-plane cells (half a metre) over the whole land each family shows
## in front: the canopy as the journey camera sees it.
static func _canopy(planting: Planting) -> Dictionary:
	const RES: float = 0.5
	var order: Array = range(planting.kinds.size())
	order.sort_custom(func(a: int, b: int) -> bool: return planting.depth(a) < planting.depth(b))
	var owner: Dictionary = {}
	for i: int in order:
		var tile: int = planting.tiles[i]
		var rect: Rect2 = Atlas.rect(tile, planting.bases[i], planting.scales[i])
		var y: float = (floorf(rect.position.y / RES) + 0.5) * RES
		while y < rect.end.y:
			var x: float = (floorf(rect.position.x / RES) + 0.5) * RES
			while x < rect.end.x:
				if _inside(tile, rect, Vector2(x, y)):
					owner[Vector2i(roundi(x / RES), roundi(y / RES))] = i
				x += RES
			y += RES
	var shown: Dictionary = {}
	for cell: Vector2i in owner:
		var family: String = _family(planting.kinds[owner[cell]])
		shown[family] = int(str(shown.get(family, 0))) + 1
	return shown


## One card per plant, nearest first in each draw, cut out by the atlas's one
## material and casting nothing; the trees' shadows from shadow-only casters.
static func _draws(fails: Array[String], land: MapJourneyLandscape) -> void:
	var planting: Planting = land.wood.planting
	var instances: int = 0
	var ordered: bool = true
	var posed: bool = true
	# What each plant's card should carry (its tile's page and rect), by where
	# the card stands.
	var expected: Dictionary = {}
	for i: int in range(planting.kinds.size()):
		var at_origin: Vector3 = Atlas.card_transform(planting.tiles[i], planting.bases[i], planting.scales[i]).origin
		var key: Vector3i = Vector3i((at_origin * 1000.0).round())
		var customs: Array = expected.get(key, [])
		customs.append(Atlas.custom(planting.tiles[i]))
		expected[key] = customs
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
			var customs: Array = expected.get(Vector3i((origin * 1000.0).round()), [])
			posed = posed and customs.has(custom)
	_check(fails, instances == planting.kinds.size() and posed,
		"one card per plant, each painted with its own tile at its page (%d cards, %d plants)" % [
			instances, planting.kinds.size()])
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
