extends RefCounted
## Where Act I's woodland stands (R3.1, issue #660): the kit's own foliage,
## and a packed fill of trees and undergrowth everywhere the land has room,
## drawn as impostor cards (`impostor_wood.gd`).
##
## Presentation only, deterministic from fixed seeds and the land itself, as
## the kit's own planting is. The rules, all measured on the ground or on the
## journey camera's picture plane (`MapJourneyCameraContract.projected_plane`):
## - a trunk stands off the road and its verge, a shrub may stand on the verge
##   (distances from the road's centreline, past the edge of its worn core);
## - nothing stands in the river, on a bridge, its ramps or abutments, on a
##   waystone or the kit's stones, lamps, arch and shrines;
## - a crown may overhang a verge, but never hides a road's centreline, a
##   bridge deck, a lamp's flame, the gateway arch or a memorial shrine that
##   stands behind it, nor a waystone's seat, its stone or its touch square
##   (`seat_square`);
## - a crown that does not fit is tried smaller once (undergrowth twice, then
##   as the low fern), so the big crowns stand where there is room: between
##   the road loops and toward the frame's edge.
## Every rule reads grids made once per land (the candidate masks: the ground's
## water and clearances, the roads' distance field the ground paints with, and
## the picture plane's protected depths) rather than the land's geometry, so
## a candidate costs a few array reads.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const River = preload("res://presentation/map/landscape/river.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")

## The ground grid (metres per cell) and its flags.
const CELL: float = 0.5
const WET: int = 1
const NO_TREE: int = 2
const NO_SHRUB: int = 4
## The picture-plane grid: fine cells (metres), and fine cells per coarse cell.
const FINE: float = 0.25
const COARSE: int = 4
## Road clearance from the centreline: the worn core is about 0.6 m either
## side, its verge about 1 m.
const TREE_ROAD: float = 1.15
const SHRUB_ROAD: float = 0.8
## The half-width of a road's lane kept in sight on the picture plane, and
## how far apart along the road it is sampled.
const LANE: float = 0.3
const LANE_STEP: float = 0.4
## Bridges (`Terrain` meta `bridge_chains`, raised where a chain's weight is
## past `DECK_WEIGHT`): no tree within `DECK_CLEAR` of a deck's centreline, no
## shrub within `DECK_SHRUB`, and the deck and parapets kept in sight
## `DECK_SIGHT` either side.
const DECK_WEIGHT: float = 0.3
const DECK_CLEAR: float = 1.9
const DECK_SHRUB: float = 1.5
const DECK_SIGHT: float = 1.0
const ABUTMENT_CLEAR: float = 2.6
## A waystone: no plant on its stone, and the stone's body kept in sight above
## its seat on the picture plane.
const SEAT_CLEAR: float = 1.2
const STONE_RISE: float = 1.0
## How far behind protected content a card must stand (metres of depth).
const DEPTH_MARGIN: float = 0.15
## Fill lattices (metres) and seeds.
const TREE_SPACING: float = 2.0
const SHRUB_SPACING: float = 1.1
const TREE_SEED: int = 7741
const SHRUB_SEED: int = 7743
## Crown scale (the art direction's 0.7 to 1.4 for trees). A candidate is
## tried large first (from `TRY_FROM` of the range up; the dark conifers
## larger, the crimson crowns across the whole range, so the red stays a
## share of the wood), then at `SHRINK` of that, never below the range: the
## big crowns stand where there is room.
const TREE_SCALE: Vector2 = Vector2(0.7, 1.4)
const SHRUB_SCALE: Vector2 = Vector2(0.55, 1.25)
const TRY_FROM: float = 0.3
const TRY_FROM_KIND: Dictionary = {"conifer": 0.55, "conifer-spire": 0.55, "conifer-wind": 0.4,
	"ember-oak": 0.0, "ember-round": 0.0}
const SHRINK: float = 0.72
## The near band along the land's south edge (metres): denser, larger crowns,
## so foreground crowns frame the bottom of the view.
const NEAR_BAND: float = 9.0
## How much of a planted crown keeps other trunks and shrubs off its own.
const TRUNK_GAP: float = 0.85
const SHRUB_UNDER_TREE: float = 0.35
## How likely a fill tree is a conifer, before the groves' swing (the kit's
## own conifers, and conifers' slimmer crowns fitting where broadleaf do not,
## bring the woodland to about two in five).
const CONIFER_SHARE: float = 0.2
## Undergrowth that fits nowhere else on a verge: the low fern.
const LOW_SHRUB: String = "ash-fern"
## The undergrowth the fill plants, by share.
const UNDERGROWTH: Dictionary = {"olive-heath": 0.3, "dark-copse": 0.22, "ash-heath": 0.16,
	"ash-copse": 0.12, "ash-bramble": 0.1, "ash-fern": 0.1}
## The kit's own undergrowth, repainted in part (same model, same footprint):
## a share of its red heath drawn olive, of its red copse dark.
const KIT_REPAINT: Dictionary = {"ash-heath": ["olive-heath", 0.55], "ash-copse": ["dark-copse", 0.5]}
## Which kinds are trees (casting, standing trunk-first).
const TREES: PackedStringArray = ["conifer", "conifer-spire", "conifer-wind", "ember-oak",
	"ember-round", "rust-oak", "amber-round"]

## What was planted, one entry per plant.
var kinds: PackedStringArray = []
var tiles: PackedInt32Array = []
var bases: PackedVector3Array = []
var scales: PackedFloat32Array = []
var from_kit: PackedByteArray = []
## Why candidates were turned away, by rule (probes and tests).
var rejected: Dictionary = {}

var _terrain: Terrain
var _origin: Vector2
var _columns: int = 0
var _rows: int = 0
var _ground: PackedByteArray = []
var _route: PackedFloat32Array = []
var _route_size: Vector2i = Vector2i.ZERO
var _route_scale: Vector2 = Vector2.ONE
var _toward: Vector3
var _pitch_sin: float
## The picture-plane grid: per fine and coarse cell, the least depth of what
## it protects (INF where nothing).
var _plane_origin: Vector2
var _fine_columns: int = 0
var _fine_rows: int = 0
var _fine: PackedFloat32Array = []
var _coarse_columns: int = 0
var _coarse: PackedFloat32Array = []


## Plants the land: the kit's foliage where it stands, then the fill.
## `seats` are the waystones' seats on the rendered surface.
func plant(kit: Node3D, terrain: Terrain, seats: PackedVector3Array) -> void:
	_begin(terrain)
	_mask_water()
	_mask_structures(kit, seats)
	_protect(kit, seats)
	_adopt(kit)
	_fill_trees()
	_fill_shrubs()


func _begin(terrain: Terrain) -> void:
	_terrain = terrain
	var bounds: Rect2 = terrain.bounds
	_origin = bounds.position
	_columns = ceili(bounds.size.x / CELL)
	_rows = ceili(bounds.size.y / CELL)
	_ground.resize(_columns * _rows)
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	_pitch_sin = sin(pitch)
	_toward = Vector3(0, _pitch_sin, cos(pitch))
	# The roads' distance field the ground paints with (8 texels a metre,
	# exact within about a metre of every road on the ground).
	var ground: MeshInstance3D = terrain.get_node_or_null("Quiet sculpted ground") as MeshInstance3D
	var paint: Material = ground.material_override if ground != null else null
	if paint != null and paint.has_meta("distance_image"):
		var image: Image = paint.get_meta("distance_image")
		_route = image.get_data().to_float32_array()
		_route_size = image.get_size()
		_route_scale = Vector2(_route_size) / bounds.size
	# The picture plane over the land, from the tallest thing protected above
	# the far edge to the near edge.
	_plane_origin = Vector2(bounds.position.x, bounds.position.y * _pitch_sin - 8.0)
	_fine_columns = ceili(bounds.size.x / FINE) + 1
	_fine_rows = ceili((bounds.size.y * _pitch_sin + 10.0) / FINE) + 1
	_fine.resize(_fine_columns * _fine_rows)
	_fine.fill(INF)
	_coarse_columns = ceili(float(_fine_columns) / COARSE)
	_coarse.resize(_coarse_columns * ceili(float(_fine_rows) / COARSE))
	_coarse.fill(INF)


## The river and its wet banks: a row's cells within a few metres of each
## ravine's line are checked (everything else is dry), and every wet cell
## wets its neighbours, since the banks fall steeply within a cell.
func _mask_water() -> void:
	var half_length: float = _terrain.river_half_length
	var reach: float = River.HALF_WIDTH * River.CHANNEL + CELL
	var bank: float = 2.6 * River.CHANNEL
	var wet: PackedInt32Array = []
	for row: int in range(_rows):
		var z: float = _origin.y + (row + 0.5) * CELL
		for cut: float in MapRavine.CUTS:
			var centre: float = River.centre(z, cut)
			var first: int = maxi(0, floori((centre - reach - _origin.x) / CELL))
			var last: int = mini(_columns - 1, floori((centre + reach - _origin.x) / CELL))
			for column: int in range(first, last + 1):
				var x: float = _origin.x + (column + 0.5) * CELL
				if absf(x - centre) < bank or (absf(z) < half_length
						and _terrain.surface_height(x, z) <= River.LEVEL + 0.2):
					wet.append(row * _columns + column)
	for index: int in wet:
		var row: int = index / _columns
		var column: int = index % _columns
		for r: int in range(maxi(0, row - 1), mini(_rows, row + 2)):
			for c: int in range(maxi(0, column - 1), mini(_columns, column + 2)):
				_ground[r * _columns + c] |= WET


## Raised roads (bridges and their ramps), abutments, waystones and every
## kit placement that is not foliage keep plants off their ground.
func _mask_structures(kit: Node3D, seats: PackedVector3Array) -> void:
	for deck: Vector3 in _decks(1.5):
		_stamp(deck.x, deck.z, DECK_CLEAR, DECK_SHRUB)
	var abutments: PackedVector2Array = _terrain.landform.get("abutments")
	for pad: Vector2 in abutments:
		_stamp(pad.x, pad.y, ABUTMENT_CLEAR, ABUTMENT_CLEAR)
	for seat: Vector3 in seats:
		_stamp(seat.x, seat.z, SEAT_CLEAR, SEAT_CLEAR)
	var placed: Array = kit.get("placed")
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		if Atlas.KIT_KINDS.has(kind):
			continue
		var at: Vector3 = item["position"]
		var reach: float = float(str(item["radius"]))
		# A rock's or a post's circle encloses it at every turn: undergrowth
		# may grow at its foot, trunks stand a little off.
		_stamp(at.x, at.z, reach * 0.75 + 0.9, reach * 0.45 + 0.25)


## What the woodland may never hide on the picture plane.
func _protect(kit: Node3D, seats: PackedVector3Array) -> void:
	var lines: Array[PackedVector3Array] = _terrain.lines
	# A lane sample every `LANE_STEP`, each wide enough to meet the next.
	var half: Vector2 = Vector2(LANE + LANE_STEP * 0.5, (LANE + LANE_STEP * 0.5) * _pitch_sin)
	for line: PackedVector3Array in lines:
		for i: int in range(line.size() - 1):
			var steps: int = maxi(1, ceili(line[i].distance_to(line[i + 1]) / LANE_STEP))
			for step: int in range(steps + 1):
				var q: Vector3 = line[i].lerp(line[i + 1], float(step) / steps)
				var at: Vector2 = MapJourneyCameraContract.projected_plane(q)
				_protect_rect(Rect2(at - half, half * 2.0), q.dot(_toward))
	for deck: Vector3 in _decks(0.75):
		var at: Vector2 = MapJourneyCameraContract.projected_plane(deck)
		_protect_rect(Rect2(at.x - DECK_SIGHT, at.y - 0.9, DECK_SIGHT * 2.0, 1.6), deck.dot(_toward))
	# A seat's touch square, and the stone's body above it, are never covered
	# by a crown standing in front of the stone.
	var square: float = seat_square()
	for seat: Vector3 in seats:
		var at: Vector2 = MapJourneyCameraContract.projected_plane(seat)
		_protect_rect(Rect2(at.x - square * 0.5, at.y - square * 0.5 - STONE_RISE, square,
			square + STONE_RISE), seat.dot(_toward))
	for flame: Vector3 in kit.call("lamp_anchors"):
		var at: Vector2 = MapJourneyCameraContract.projected_plane(flame)
		_protect_rect(Rect2(at - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), flame.dot(_toward) - 0.2)
	var placed: Array = kit.get("placed")
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		var base: Vector3 = item["position"]
		var at: Vector2 = MapJourneyCameraContract.projected_plane(base)
		if kind == "amber-arch":
			_protect_rect(Rect2(at + Vector2(-2.9, -4.6), Vector2(5.8, 5.4)), base.dot(_toward) - 0.8)
		elif kind == "memorial":
			_protect_rect(Rect2(at + Vector2(-0.6, -1.8), Vector2(1.2, 2.2)), base.dot(_toward) - 0.5)


## The raised points of every bridge chain, about `step` metres apart.
func _decks(step: float) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for chain: Dictionary in _terrain.get_meta("bridge_chains", []):
		var points: PackedVector3Array = chain["points"]
		var weights: PackedFloat32Array = chain["weights"]
		for i: int in range(points.size() - 1):
			if maxf(weights[i], weights[i + 1]) < DECK_WEIGHT:
				continue
			var steps: int = maxi(1, ceili(points[i].distance_to(points[i + 1]) / step))
			for k: int in range(steps):
				out.append(points[i].lerp(points[i + 1], float(k) / steps))
	return out


## The picture-plane square (metres) a waystone's touch square covers at the
## Journey view on the reference shape (the iPad's, and the desktop's: 60 px
## of 820, 1.4 m). The phone's touch floor is 60 px of a 390 px stage, about
## 3 m of land: kept clear, it would empty a third of every view, so on the
## phone the pins' legibility rests on their measured contrast instead.
static func seat_square() -> float:
	var stage: Vector2 = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	return MapJourneyCameraContract.touch_size(stage) / stage.y * MapJourneyCameraContract.PREFERRED_ZOOM


## The kit's foliage becomes the woodland's where it stands; its trunks and
## shrubs keep the fill off them.
func _adopt(kit: Node3D) -> void:
	var placed: Array = kit.get("placed")
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		if not Atlas.KIT_KINDS.has(kind):
			continue
		var at: Vector3 = item["position"]
		var scale_value: float = float(str(item["scale"]))
		var radius: float = float(str(item["radius"]))
		if KIT_REPAINT.has(kind):
			var repaint: Array = KIT_REPAINT[kind]
			var share: float = repaint[1]
			if _hash(at) < share:
				kind = repaint[0]
		_add(kind, Atlas.tile_for(kind, float(str(item["yaw"]))), at, scale_value, true)
		if TREES.has(kind):
			_stamp(at.x, at.z, radius * 0.4, radius * SHRUB_UNDER_TREE * 0.5)
		else:
			_stamp(at.x, at.z, 0.0, radius * 0.3)


func _fill_trees() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var area: Rect2 = _area()
	var near_edge: float = area.end.y - NEAR_BAND
	for z: float in _lattice(area.position.y, area.end.y, TREE_SPACING):
		for x: float in _lattice(area.position.x, area.end.x, TREE_SPACING):
			var px: float = x + rng.randf_range(-0.45, 0.45) * TREE_SPACING
			var pz: float = z + rng.randf_range(-0.45, 0.45) * TREE_SPACING
			var pick: float = rng.randf()
			var size_pick: float = rng.randf()
			var yaw: float = rng.randf_range(-PI, PI)
			var near: bool = pz > near_edge
			if not _ground_ok(px, pz, NO_TREE, TREE_ROAD):
				continue
			var kind: String = _tree_kind(px, pz, pick)
			var from: float = TRY_FROM_KIND.get(kind, TRY_FROM)
			var scale_value: float = _first_scale(TREE_SCALE, sqrt(size_pick) if near else size_pick, from)
			var base: Vector3 = Vector3(px, _terrain.surface_height(px, pz), pz)
			var tile: int = Atlas.tile_for(kind, yaw)
			if not _fits(tile, base, scale_value):
				scale_value = maxf(TREE_SCALE.x, scale_value * SHRINK)
				if not _fits(tile, base, scale_value):
					_reject("sight")
					continue
			_add(kind, tile, base, scale_value, false)
			var reach: float = Atlas.size[tile].x * 0.5 * scale_value
			_stamp(px, pz, reach * TRUNK_GAP, reach * SHRUB_UNDER_TREE)
	# The near band packs a second, offset lattice of trees.
	for z: float in _lattice(near_edge, area.end.y, TREE_SPACING):
		for x: float in _lattice(area.position.x + TREE_SPACING * 0.5, area.end.x, TREE_SPACING):
			var px: float = x + rng.randf_range(-0.3, 0.3) * TREE_SPACING
			var pz: float = z + rng.randf_range(-0.3, 0.3) * TREE_SPACING
			var kind: String = _tree_kind(px, pz, rng.randf())
			var scale_value: float = lerpf(1.0, TREE_SCALE.y, rng.randf())
			var yaw: float = rng.randf_range(-PI, PI)
			if not _ground_ok(px, pz, NO_TREE, TREE_ROAD):
				continue
			var base: Vector3 = Vector3(px, _terrain.surface_height(px, pz), pz)
			var tile: int = Atlas.tile_for(kind, yaw)
			if not _fits(tile, base, scale_value):
				_reject("sight")
				continue
			_add(kind, tile, base, scale_value, false)
			_stamp(px, pz, Atlas.size[tile].x * 0.5 * scale_value * TRUNK_GAP, 0.0)


## Dark conifers in groves, broadleaf crowns between them: crimson the most,
## rust and amber the rest.
func _tree_kind(x: float, z: float, pick: float) -> String:
	var mass: float = sin(x * 0.21 + z * 0.07) * 0.5 + cos(z * 0.17 - x * 0.11) * 0.5
	var conifer: float = clampf(CONIFER_SHARE + 0.25 * mass, 0.05, 0.6)
	if pick < conifer:
		var which: float = pick / conifer
		return "conifer" if which < 0.45 else ("conifer-spire" if which < 0.85 else "conifer-wind")
	var broad: float = (pick - conifer) / (1.0 - conifer)
	if broad < 0.26:
		return "ember-oak"
	if broad < 0.5:
		return "ember-round"
	return "rust-oak" if broad < 0.76 else "amber-round"


func _fill_shrubs() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SHRUB_SEED
	var area: Rect2 = _area()
	for z: float in _lattice(area.position.y, area.end.y, SHRUB_SPACING):
		for x: float in _lattice(area.position.x, area.end.x, SHRUB_SPACING):
			var px: float = x + rng.randf_range(-0.45, 0.45) * SHRUB_SPACING
			var pz: float = z + rng.randf_range(-0.45, 0.45) * SHRUB_SPACING
			var pick: float = rng.randf()
			var scale_value: float = _first_scale(SHRUB_SCALE, rng.randf(), TRY_FROM)
			var yaw: float = rng.randf_range(-PI, PI)
			if not _ground_ok(px, pz, NO_SHRUB, SHRUB_ROAD):
				continue
			var kind: String = _undergrowth(pick)
			var base: Vector3 = Vector3(px, _terrain.surface_height(px, pz), pz)
			var tile: int = Atlas.tile_for(kind, yaw)
			if not _fits(tile, base, scale_value):
				scale_value = maxf(SHRUB_SCALE.x, scale_value * SHRINK * SHRINK)
				if not _fits(tile, base, scale_value):
					kind = LOW_SHRUB
					tile = Atlas.tile_for(kind, yaw)
					if not _fits(tile, base, scale_value):
						_reject("sight")
						continue
			_add(kind, tile, base, scale_value, false)


## The first scale a candidate tries: `pick` (0 to 1) over the top of `range`.
static func _first_scale(range: Vector2, pick: float, from: float) -> float:
	return lerpf(lerpf(range.x, range.y, from), range.y, pick)


## The undergrowth kind `pick` (0 to 1) falls on, by `UNDERGROWTH`'s shares.
static func _undergrowth(pick: float) -> String:
	for name: String in UNDERGROWTH:
		var share: float = UNDERGROWTH[name]
		if pick < share:
			return name
		pick -= share
	return LOW_SHRUB


## Where the fill may stand: the land less a metre's margin.
func _area() -> Rect2:
	return _terrain.bounds.grow(-1.0)


static func _lattice(from: float, to: float, spacing: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	var at: float = from + spacing * 0.5
	while at < to:
		out.append(at)
		at += spacing
	return out


## Whether a plant may stand at (x, z): dry, off `flag`'s masks, and at least
## `road` from a road's centreline.
func _ground_ok(x: float, z: float, flag: int, road: float) -> bool:
	var column: int = floori((x - _origin.x) / CELL)
	var row: int = floori((z - _origin.y) / CELL)
	if column < 0 or row < 0 or column >= _columns or row >= _rows:
		_reject("edge")
		return false
	var flags: int = _ground[row * _columns + column]
	if flags & WET:
		_reject("water")
		return false
	if flags & flag:
		_reject("clear")
		return false
	if road_distance(x, z) < road:
		_reject("road")
		return false
	return true


## Distance from (x, z) to the nearest road on the ground (from the ground
## paint's field; 4 m where no road is near).
func road_distance(x: float, z: float) -> float:
	if _route.is_empty():
		return INF
	var column: int = clampi(floori((x - _origin.x) * _route_scale.x), 0, _route_size.x - 1)
	var row: int = clampi(floori((z - _origin.y) * _route_scale.y), 0, _route_size.y - 1)
	return _route[row * _route_size.x + column]


## Whether a card of `tile` for a plant at `base`, at `scale`, hides nothing
## the picture plane protects: every protected cell under its silhouette lies
## in front of it.
func _fits(tile: int, base: Vector3, scale_value: float) -> bool:
	var rect: Rect2 = Atlas.rect(tile, base, scale_value)
	var limit: float = base.dot(_toward) + Atlas.shift(tile) * scale_value + DEPTH_MARGIN
	var coarse_size: float = FINE * COARSE
	var c0: int = maxi(0, floori((rect.position.x - _plane_origin.x) / coarse_size))
	var c1: int = mini(_coarse_columns - 1, floori((rect.end.x - _plane_origin.x) / coarse_size))
	var r0: int = maxi(0, floori((rect.position.y - _plane_origin.y) / coarse_size))
	var r1: int = mini(_coarse.size() / _coarse_columns - 1, floori((rect.end.y - _plane_origin.y) / coarse_size))
	for row: int in range(r0, r1 + 1):
		for column: int in range(c0, c1 + 1):
			if _coarse[row * _coarse_columns + column] >= limit:
				continue
			if not _fits_cell(tile, rect, limit, column, row):
				return false
	return true


## The fine cells of one coarse cell, under the card's silhouette.
func _fits_cell(tile: int, rect: Rect2, limit: float, coarse_column: int, coarse_row: int) -> bool:
	var rows: PackedVector2Array = Atlas.spans[tile]
	var row_height: float = rect.size.y / rows.size()
	var pad: float = FINE * 0.5 / rect.size.x
	for fy: int in range(coarse_row * COARSE, mini((coarse_row + 1) * COARSE, _fine_rows)):
		var y: float = _plane_origin.y + (fy + 0.5) * FINE
		var band: int = floori((y - rect.position.y) / row_height)
		if band < 0 or band >= rows.size():
			continue
		var span: Vector2 = rows[band]
		if span.x > span.y:
			continue
		for fx: int in range(coarse_column * COARSE, mini((coarse_column + 1) * COARSE, _fine_columns)):
			if _fine[fy * _fine_columns + fx] >= limit:
				continue
			var x: float = (_plane_origin.x + (fx + 0.5) * FINE - rect.position.x) / rect.size.x
			if x >= span.x - pad and x <= span.y + pad:
				return false
	return true


## Protects the picture plane's cells under `rect` down to `depth`.
func _protect_rect(rect: Rect2, depth: float) -> void:
	var c0: int = maxi(0, floori((rect.position.x - _plane_origin.x) / FINE))
	var c1: int = mini(_fine_columns - 1, floori((rect.end.x - _plane_origin.x) / FINE))
	var r0: int = maxi(0, floori((rect.position.y - _plane_origin.y) / FINE))
	var r1: int = mini(_fine_rows - 1, floori((rect.end.y - _plane_origin.y) / FINE))
	for row: int in range(r0, r1 + 1):
		for column: int in range(c0, c1 + 1):
			var index: int = row * _fine_columns + column
			if depth < _fine[index]:
				_fine[index] = depth
				var coarse: int = (row / COARSE) * _coarse_columns + column / COARSE
				_coarse[coarse] = minf(_coarse[coarse], depth)


## Keeps trees off the ground cells within `tree` of (x, z), and undergrowth
## off those within `shrub`.
func _stamp(x: float, z: float, tree: float, shrub: float) -> void:
	var radius: float = maxf(tree, shrub)
	var r0: int = maxi(0, floori((z - radius - _origin.y) / CELL))
	var r1: int = mini(_rows - 1, floori((z + radius - _origin.y) / CELL))
	for row: int in range(r0, r1 + 1):
		var dz: float = _origin.y + (row + 0.5) * CELL - z
		_stamp_row(row, x, tree * tree - dz * dz, NO_TREE)
		_stamp_row(row, x, shrub * shrub - dz * dz, NO_SHRUB)


## Sets `flag` on the row's cells whose centres lie within the chord of half
## width sqrt(`reach`) round `x` (nothing when `reach` is negative).
func _stamp_row(row: int, x: float, reach: float, flag: int) -> void:
	if reach < 0.0:
		return
	var half: float = sqrt(reach)
	var c0: int = maxi(0, ceili((x - half - _origin.x) / CELL - 0.5))
	var c1: int = mini(_columns - 1, floori((x + half - _origin.x) / CELL - 0.5))
	var at: int = row * _columns
	for column: int in range(c0, c1 + 1):
		_ground[at + column] |= flag


func _add(kind: String, tile: int, base: Vector3, scale_value: float, kit: bool) -> void:
	kinds.append(kind)
	tiles.append(tile)
	bases.append(base)
	scales.append(scale_value)
	from_kit.append(1 if kit else 0)


func _reject(reason: String) -> void:
	var seen: int = rejected.get(reason, 0)
	rejected[reason] = seen + 1


## A stable value in [0, 1) for a place on the land.
static func _hash(at: Vector3) -> float:
	var h: float = absf(sin(at.x * 12.9898 + at.z * 78.233)) * 43758.5453
	return h - floorf(h)


## How deep plant `index`'s card stands toward the camera.
func depth(index: int) -> float:
	return bases[index].dot(_toward) + Atlas.shift(tiles[index]) * scales[index]
