extends RefCounted
## What the floor's bake needs from a land (R3.2, issue #660), worked out on
## the land's worker as it is built, so the bake's frames on the main thread
## only hand buffers over (`floor_bake.gd`): every lamp, the woodland's
## shadow cards turned to the key light, the plants' and the stones' reach for
## the floor's 2D pass (`floor_fields.gd`), and the heights the ground spans.
## Reads the land's own records (the planting, the kit's placements, the
## waystones' seats); nothing here reads back from the renderer.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Stone = preload("res://presentation/map/landscape/land_stone.gd")

## Texels a metre of the floor's 2D pass.
const FIELD_TEXELS_PER_M: float = 8.0
## The most lamps the floor's shaders take (`floor_ground.gdshaderinc`).
const MOST_LAMPS: int = 48
## Each reach: (channel weights r, g, b) at a radius in metres, per kind of
## base. r the woodland's litter, g the rocks' grit, b contact occlusion.
const TREE_REACH: Vector4 = Vector4(0.3, 0.0, 0.0, 1.25)
const TREE_FOOT: Vector4 = Vector4(0.0, 0.0, 0.55, 0.75)
const SHRUB_REACH: Vector4 = Vector4(0.1, 0.0, 0.0, 0.9)
const SHRUB_FOOT: Vector4 = Vector4(0.0, 0.0, 0.3, 0.5)
## A shrub's own shade: a soft dark round the crown's size, its centre this
## share of its height away from the key along the ground.
const SHRUB_SHADE: Vector4 = Vector4(0.0, 0.0, 0.32, 0.55)
const ROCK_REACH: Vector4 = Vector4(0.0, 0.6, 0.0, 1.0)
const ROCK_FOOT: Vector4 = Vector4(0.0, 0.0, 0.6, 0.85)
const STONE_FOOT: Vector4 = Vector4(0.0, 0.0, 0.5, 0.55)
## A waystone's seat: the ground rises round it wider and softer than round a
## stone, so no water stands or rut lies wet under its token
## (`floor_ground.gdshaderinc`, `drained`).
const SEAT_FOOT: Vector4 = Vector4(0.0, 0.0, 0.42, 1.2)
## The kit's kinds that stand on the land as stones, posts and shrines, by
## the radius (metres at scale 1) their foot darkens.
const FOOTS: Dictionary = {"memorial": 0.8, "lantern-post": 0.45,
	"conifer-snag": 0.7}

var lamps: PackedVector4Array = PackedVector4Array()
## The leafy shadow cards: one MultiMesh instance a tree (transform, colour
## and custom data, 20 floats each). Undergrowth casts none: its cards, all
## turned one way, laid it down as a field of parallel dashes; each shrub
## darkens the ground under and behind it in the 2D pass instead
## (`SHRUB_SHADE`).
var casters: PackedFloat32Array = PackedFloat32Array()
var caster_count: int = 0
## The 2D pass's stamps: one MultiMesh instance each (2D transform and colour,
## 12 floats each), in the pass's texels.
var stamps: PackedFloat32Array = PackedFloat32Array()
var stamp_count: int = 0
var field_size: Vector2i = Vector2i.ZERO
var bounds: Rect2 = Rect2()
## The least and the greatest height of the ground.
var ground: Vector2 = Vector2.ZERO
var timings_ms: Dictionary = {}


## Works the plan out for `land` once its wood, kit, lamps and waystones are
## built, the key light turned `key_rotation` (degrees).
func build(land: MapJourneyLandscape, key_rotation: Vector3) -> void:
	var started: int = Time.get_ticks_usec()
	bounds = land.terrain.bounds
	ground = land.terrain.ground_heights()
	field_size = Vector2i(ceili(bounds.size.x * FIELD_TEXELS_PER_M), ceili(bounds.size.y * FIELD_TEXELS_PER_M))
	if land.lamps != null:
		var anchors: PackedVector3Array = land.lamps.anchors
		for i: int in range(mini(anchors.size(), MOST_LAMPS)):
			lamps.append(Vector4(anchors[i].x, anchors[i].y, anchors[i].z, 0.0))
	if land.wood != null:
		_cards(land.wood.planting, key_rotation)
		_plant_stamps(land.wood.planting, key_rotation)
	if land.kit != null:
		_kit_stamps(land.kit.placed)
	if land.journey != null:
		for base: Node3D in land.journey.bases:
			_stamp(base.position, SEAT_FOOT)
	timings_ms["plan"] = (Time.get_ticks_usec() - started) / 1000.0


## The direction the key light comes from, level with the ground.
static func toward_key(key_rotation: Vector3) -> Vector3:
	var basis: Basis = Basis.from_euler(key_rotation * (PI / 180.0))
	var back: Vector3 = basis.z
	return Vector3(back.x, 0.0, back.z).normalized()


## Each tree's silhouette, and each standing ruin's (R3.3: the gravestones
## and the walls), its own atlas tile, the picture above its base, on an
## upright card at its base, turned to face the key light.
func _cards(planting: Planting, key_rotation: Vector3) -> void:
	var normal: Vector3 = toward_key(key_rotation)
	var across: Vector3 = Vector3(normal.z, 0.0, -normal.x)
	var bases: PackedVector3Array = planting.bases
	var tiles: PackedInt32Array = planting.tiles
	var scales: PackedFloat32Array = planting.scales
	var trees: PackedInt32Array = PackedInt32Array()
	for i: int in range(bases.size()):
		if Planting.casts(planting.kinds[i]):
			trees.append(i)
	caster_count = trees.size()
	casters.resize(caster_count * 20)
	for k: int in range(caster_count):
		var i: int = trees[k]
		var tile: int = tiles[i]
		var s: float = scales[i]
		var height: float = Atlas.top[tile] * s
		var corner: Vector3 = bases[i] + Vector3.UP * height + across * Atlas.low[tile].x * s
		var at: int = k * 20
		var x_axis: Vector3 = across * Atlas.size[tile].x * s
		var y_axis: Vector3 = Vector3.DOWN * height
		for row: int in range(3):
			casters[at + row * 4] = x_axis[row]
			casters[at + row * 4 + 1] = y_axis[row]
			casters[at + row * 4 + 2] = normal[row]
			casters[at + row * 4 + 3] = corner[row]
		var rect: Vector4 = Atlas.uv[tile]
		casters[at + 12] = 0.0
		casters[at + 13] = 0.0
		casters[at + 14] = 0.0
		casters[at + 15] = -Atlas.low[tile].y / Atlas.size[tile].y
		casters[at + 16] = rect.x
		casters[at + 17] = rect.y
		casters[at + 18] = rect.z
		casters[at + 19] = rect.w


func _plant_stamps(planting: Planting, key_rotation: Vector3) -> void:
	var away: Vector3 = -toward_key(key_rotation) / tan(deg_to_rad(-key_rotation.x))
	var bases: PackedVector3Array = planting.bases
	var kinds: PackedStringArray = planting.kinds
	var tiles: PackedInt32Array = planting.tiles
	var scales: PackedFloat32Array = planting.scales
	for i: int in range(bases.size()):
		var s: float = scales[i]
		var tile: int = tiles[i]
		var crown: float = Atlas.size[tile].x * 0.5 * s
		if Planting.TREES.has(kinds[i]):
			_stamp(bases[i], Vector4(TREE_REACH.x, 0.0, 0.0, TREE_REACH.w * crown))
			_stamp(bases[i], Vector4(0.0, 0.0, TREE_FOOT.z, TREE_FOOT.w * s))
		elif Planting.STONES.has(kinds[i]):
			# A ruin: grey grit round it and a dark foot, no litter.
			_stamp(bases[i], Vector4(0.0, ROCK_REACH.y * 0.6, 0.0, crown + ROCK_REACH.w * 0.6))
			_stamp(bases[i], Vector4(0.0, 0.0, STONE_FOOT.z, crown * 0.8 + STONE_FOOT.w * s))
		else:
			_stamp(bases[i], Vector4(SHRUB_REACH.x, 0.0, 0.0, SHRUB_REACH.w * crown))
			_stamp(bases[i], Vector4(0.0, 0.0, SHRUB_FOOT.z, SHRUB_FOOT.w * s))
			_stamp(bases[i] + away * Atlas.top[tile] * s * SHRUB_SHADE.w,
				Vector4(0.0, 0.0, SHRUB_SHADE.z, crown))


## The kit's stones, posts, shrines and the arch's feet (its plants are the
## wood's, drawn as cards and stamped with them).
func _kit_stamps(placed: Array[Dictionary]) -> void:
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		var at: Vector3 = item["position"]
		var radius: float = float(str(item["radius"]))
		var s: float = float(str(item["scale"]))
		if Stone.OUTCROPS.has(kind):
			_stamp(at, Vector4(0.0, ROCK_REACH.y, 0.0, radius + ROCK_REACH.w))
			_stamp(at, Vector4(0.0, 0.0, ROCK_FOOT.z, radius * ROCK_FOOT.w))
		elif kind == "amber-arch":
			var yaw: float = float(str(item["yaw"]))
			for side: float in [-1.0, 1.0]:
				_stamp(at + Vector3(side * 1.65, 0.0, 0.0).rotated(Vector3.UP, yaw) * s,
					Vector4(0.0, 0.0, STONE_FOOT.z, 1.1 * s))
		elif FOOTS.has(kind):
			_stamp(at, Vector4(0.0, 0.0, STONE_FOOT.z, float(str(FOOTS[kind])) * s))


## One additive stamp: weights `reach.xyz` fading to nothing at `reach.w`
## metres round `at`.
func _stamp(at: Vector3, reach: Vector4) -> void:
	var centre: Vector2 = (Vector2(at.x, at.z) - bounds.position) * FIELD_TEXELS_PER_M
	var span: float = reach.w * 2.0 * FIELD_TEXELS_PER_M
	stamps.append_array([span, 0.0, 0.0, centre.x, 0.0, span, 0.0, centre.y,
		reach.x, reach.y, reach.z, 1.0])
	stamp_count += 1
