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


## The cards, one MultiMesh per cell, each instance's transform, tint and atlas
## rect written straight into its buffer.
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
			var tint: Color = tint_for(planting.kinds[i], planting.bases[i])
			var rect: Vector4 = Atlas.uv[tile]
			_write(buffer, at, pose, Color(tint.r, tint.g, tint.b,
				-Atlas.low[tile].y / Atlas.size[tile].y), rect)
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


## A plant's tint: each kind's own range, varied by where it stands.
static func tint_for(kind: String, base: Vector3) -> Color:
	var h: float = Planting._hash(base)
	var g: float = fposmod(h * 7.13, 1.0)
	if kind.begins_with("conifer"):
		return Color(0.82, 1.04, 0.84) * (0.85 + 0.3 * g)
	if kind == "ember-oak" or kind == "ember-round":
		# Crimson to ember orange, as the target's crowns run.
		return Color(1.04, 0.74, 0.88).lerp(Color(1.22, 0.98, 0.82), h * h * h) * (0.85 + 0.28 * g)
	if kind == "rust-oak" or kind == "amber-round":
		return Color(1, 1, 1) * (0.85 + 0.3 * g)
	return Color(1.0, 0.9, 0.95) * (0.88 + 0.24 * g)


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
