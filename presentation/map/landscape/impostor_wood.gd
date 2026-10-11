extends Node3D
## Act I's woodland drawn as fixed-view impostors (R3.1, issue #660): one card
## per plant (`impostor_atlas.gd`), planted by `wood_planting.gd`, drawn
## through MultiMesh one draw per `CELL` metres of land with each draw's cards
## nearest first, so depth rejects what the cards hide and the costly ground
## beneath them is never shaded. The trees' shadows come from opaque
## shadow-only cones (conifers) and eggs (broadleaf crowns); the undergrowth
## casts none (`StaticScenery.NO_SHADOW`).
##
## Built off the tree on the land's worker: only node, MultiMesh and buffer
## set-up here, nothing that reads back from the renderer.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const CELL: float = 16.0
## Each broadleaf kind's crown for its shadow: centre height and radii at
## scale 1 (`tools/map_atelier/journey/impostors/bake_impostors.gd` `CROWNS`).
const CROWNS: Dictionary = {
	"ember-oak": [3.5, Vector3(2.3, 1.45, 2.3)], "rust-oak": [3.5, Vector3(2.3, 1.45, 2.3)],
	"ember-round": [2.6, Vector3(1.7, 1.2, 1.7)], "amber-round": [2.6, Vector3(1.7, 1.2, 1.7)],
}
## A conifer's shadow cone: radius against the card's width.
const CONE_WIDTH: float = 0.4

var planting: Planting
var timings_ms: Dictionary = {}
var cards: Array[MultiMeshInstance3D] = []
var casters: Array[MultiMeshInstance3D] = []


## Plants the woodland round `kit`'s placements on `terrain` and builds its
## draws. `seats` are the waystones' seats.
func build(kit: Node3D, terrain: Terrain, seats: PackedVector3Array) -> void:
	name = "Impostor wood"
	var started: int = Time.get_ticks_usec()
	planting = Planting.new()
	planting.plant(kit, terrain, seats)
	timings_ms["plant"] = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	var order: PackedInt32Array = _nearest_first()
	_build_cards(order)
	_build_casters()
	timings_ms["draws"] = (Time.get_ticks_usec() - started) / 1000.0


## Every plant's index, nearest the camera first (a native sort on keys that
## carry the depth above the index).
func _nearest_first() -> PackedInt32Array:
	var keys: PackedInt64Array = []
	for i: int in range(planting.bases.size()):
		keys.append((int((200.0 - planting.depth(i)) * 1000.0) << 20) | i)
	keys.sort()
	var out: PackedInt32Array = []
	for key: int in keys:
		out.append(key & 0xFFFFF)
	return out


## The cards, one MultiMesh per cell, each instance's transform, tint and tile
## (its page and rect, `Atlas.custom`) written straight into its buffer.
func _build_cards(order: PackedInt32Array) -> void:
	var buckets: Dictionary = {}
	for i: int in order:
		var base: Vector3 = planting.bases[i]
		var key: Vector2i = Vector2i(floori(base.x / CELL), floori(base.z / CELL))
		var list: PackedInt32Array = buckets.get(key, PackedInt32Array())
		list.append(i)
		buckets[key] = list
	for key: Vector2i in buckets:
		var list: PackedInt32Array = buckets[key]
		var buffer: PackedFloat32Array = []
		buffer.resize(list.size() * 20)
		var at: int = 0
		for i: int in list:
			var tile: int = planting.tiles[i]
			var pose: Transform3D = Atlas.card_transform(tile, planting.bases[i], planting.scales[i])
			var rect: Vector4 = Atlas.custom(tile)
			_write(buffer, at, pose, card_colour(planting.kinds[i], planting.bases[i], tile), rect)
			at += 20
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = Atlas.card
		multi.instance_count = list.size()
		multi.buffer = buffer
		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.name = "Wood cards %d %d" % [key.x, key.y]
		draw.multimesh = multi
		draw.material_override = Atlas.material
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(draw)
		cards.append(draw)


## A MultiMesh instance's 20 floats: the transform's three rows, the colour and
## the custom data.
static func _write(buffer: PackedFloat32Array, at: int, pose: Transform3D, colour: Color,
		custom: Vector4) -> void:
	var b: Basis = pose.basis
	for row: int in range(3):
		buffer[at + row * 4] = b.x[row]
		buffer[at + row * 4 + 1] = b.y[row]
		buffer[at + row * 4 + 2] = b.z[row]
		buffer[at + row * 4 + 3] = pose.origin[row]
	buffer[at + 12] = colour.r
	buffer[at + 13] = colour.g
	buffer[at + 14] = colour.b
	buffer[at + 15] = colour.a
	buffer[at + 16] = custom.x
	buffer[at + 17] = custom.y
	buffer[at + 18] = custom.z
	buffer[at + 19] = custom.w


## The ruins' tint (R3.3): their baked granite and moss as they are, a stone
## lighter or darker by where it stands.
const STONE_TINT: Array = [Color(0.9, 0.9, 0.92), Color(1.05, 1.04, 1.0)]


## Each kind's tint on its baked colours (linear, against the golden-hour key
## light and the stage's grade): a plant takes a colour between the pair, by
## where it stands and weighted toward the first (half the plants lie within a
## quarter of the way from it), at `BRIGHTNESS` of it. The spruce near
## black-green. The crimson crowns and the red undergrowth go scarlet to
## vermilion: green lifted above blue, because the key light is warm and the
## grade's contrast clips a dark channel to nothing, so a crown reads crimson
## unless its green clears the clip. Their first colour is a crown in shadow,
## their second a lit one, so the lit crowns stand out of a darker wood rather
## than merging into one mat. Rust and amber deep and dull so they stay a
## minority. The olive and dark undergrowth and the fern a dark, low-chroma
## olive-brown (blue lifted, so their lit tips stay olive, not yellow-green).
const TINTS: Dictionary = {
	"conifer": [Color(0.78, 1.0, 0.84), Color(0.7, 0.92, 0.8)],
	"conifer-spire": [Color(0.78, 1.0, 0.84), Color(0.7, 0.92, 0.8)],
	"conifer-wind": [Color(0.78, 1.0, 0.84), Color(0.7, 0.92, 0.8)],
	"ember-oak": [Color(0.12, 0.13, 0.13), Color(2.3, 2.6, 2.1)],
	"ember-round": [Color(0.12, 0.13, 0.13), Color(2.3, 2.6, 2.1)],
	"rust-oak": [Color(0.25, 0.3, 0.25), Color(0.55, 0.62, 0.5)],
	"amber-round": [Color(0.22, 0.2, 0.22), Color(0.48, 0.42, 0.44)],
	"olive-heath": [Color(0.54, 0.84, 1.3), Color(0.6, 0.92, 1.45)],
	"dark-copse": [Color(1.25, 1.0, 2.3), Color(1.35, 1.05, 2.5)],
	"ash-heath": [Color(0.14, 0.13, 0.15), Color(1.9, 1.85, 1.8)],
	"ash-copse": [Color(0.14, 0.13, 0.15), Color(1.9, 1.85, 1.8)],
	"ash-bramble": [Color(1.0, 0.78, 0.96), Color(1.0, 0.86, 0.9)],
	"ash-fern": [Color(0.3, 0.75, 0.22), Color(0.33, 0.8, 0.24)],
	"grave-arched": STONE_TINT, "grave-cross": STONE_TINT, "grave-broken": STONE_TINT,
	"grave-tablet": STONE_TINT, "wall-run": STONE_TINT, "wall-corner": STONE_TINT,
	"wall-pier": STONE_TINT, "rubble-blocks": STONE_TINT, "rubble-scree": STONE_TINT,
	"rubble-mossy": STONE_TINT,
}
const BRIGHTNESS: Vector2 = Vector2(0.65, 1.15)


## A card's instance colour: its tint, and where its model's base sits down
## the card (`impostor.gdshader` sways what stands above it). A ruin's sits at
## the card's top, so no part of a stone ever sways.
static func card_colour(kind: String, base: Vector3, tile: int) -> Color:
	var tint: Color = tint_for(kind, base)
	var foot: float = 0.0 if Planting.STONES.has(kind) else -Atlas.low[tile].y / Atlas.size[tile].y
	return Color(tint.r, tint.g, tint.b, foot)


## A plant's tint: its kind's pair, varied by where it stands.
static func tint_for(kind: String, base: Vector3) -> Color:
	var h: float = Planting._hash(base)
	var g: float = fposmod(h * 7.13, 1.0)
	var pair: Array = TINTS[kind]
	var low: Color = pair[0]
	var high: Color = pair[1]
	return low.lerp(high, h * h) * lerpf(BRIGHTNESS.x, BRIGHTNESS.y, g)


## The trees' shadow casters, one draw per cell and shape.
func _build_casters() -> void:
	var buckets: Dictionary = {}
	for i: int in range(planting.kinds.size()):
		var kind: String = planting.kinds[i]
		if not Planting.TREES.has(kind):
			continue
		var base: Vector3 = planting.bases[i]
		var broad: bool = CROWNS.has(kind)
		var key: Vector3i = Vector3i(floori(base.x / CELL), floori(base.z / CELL), 1 if broad else 0)
		var list: PackedInt32Array = buckets.get(key, PackedInt32Array())
		list.append(i)
		buckets[key] = list
	for key: Vector3i in buckets:
		var list: PackedInt32Array = buckets[key]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = Atlas.egg if key.z == 1 else Atlas.cone
		multi.instance_count = list.size()
		for k: int in range(list.size()):
			multi.set_instance_transform(k, _caster(list[k]))
		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.name = "Wood casters %d %d" % [key.x, key.y]
		draw.multimesh = multi
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(draw)
		casters.append(draw)


func _caster(i: int) -> Transform3D:
	var kind: String = planting.kinds[i]
	var base: Vector3 = planting.bases[i]
	var scale_value: float = planting.scales[i]
	if CROWNS.has(kind):
		var crown: Array = CROWNS[kind]
		var centre: float = crown[0]
		var radii: Vector3 = crown[1]
		return Transform3D(Basis.from_scale(radii * scale_value), base + Vector3.UP * centre * scale_value)
	var tile: int = planting.tiles[i]
	var height: float = Atlas.top[tile] * scale_value
	var radius: float = Atlas.size[tile].x * CONE_WIDTH * scale_value
	return Transform3D(Basis.from_scale(Vector3(radius, height * 0.5, radius)),
		base + Vector3.UP * height * 0.5)


## What the woodland holds (probes and tests).
func stats() -> Dictionary:
	var counts: Dictionary = {}
	var kit: int = 0
	for i: int in range(planting.kinds.size()):
		var kind: String = planting.kinds[i]
		var seen: int = counts.get(kind, 0)
		counts[kind] = seen + 1
		kit += planting.from_kit[i]
	return {"plants": planting.kinds.size(), "from_kit": kit, "counts": counts,
		"draws": cards.size(), "caster_draws": casters.size(), "rejected": planting.rejected,
		"timings_ms": timings_ms}
