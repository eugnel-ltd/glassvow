extends Node3D
## Placement study shared by grey masses and their authored asset replacements.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const AssetLights = preload("res://presentation/map/landscape/asset_lights.gd")
const AssetSurfaces = preload("res://presentation/map/landscape/asset_surfaces.gd")
const Envelope = preload("res://presentation/map/landscape/foliage_envelope.gd")
const GroundContacts = preload("res://presentation/map/landscape/ground_contacts.gd")
const GatewaySites = preload("res://presentation/map/landscape/gateway_sites.gd")
const Terrain = preload("res://presentation/map/landscape/terrain.gd")
const ImpostorAtlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const LandStone = preload("res://presentation/map/landscape/land_stone.gd")
const Islands = preload("res://presentation/map/landscape/land_islands.gd")
const RavineCliffs = preload("res://presentation/map/landscape/ravine_cliffs.gd")
const StaticScenery = preload("res://presentation/map/landscape/static_scenery.gd")
const Bridges = preload("res://presentation/map/landscape/bridge_geometry.gd")
const Planting = preload("res://presentation/map/landscape/wood_planting.gd")
const Sight = preload("res://presentation/map/landscape/wood_sight.gd")
const River = preload("res://presentation/map/landscape/river.gd")
var tree_envelopes: Dictionary = {}
var material_pool: Dictionary = {}
var asset_scenes: Dictionary = {}
var use_static_batches: bool = false
var static_scenery: Node3D
var planting_bounds: Rect2 = Rect2(-43,-23,86,46)
var query_us: int = 0
var road_query_us: int = 0
var query_count: int = 0
var contacts: GroundContacts
var placed: Array[Dictionary] = []
var neighbours: RefCounted = preload("res://presentation/map/landscape/placement_neighbours.gd").new()
var placed_nodes: Array[Node3D] = []
var terrain: Terrain
var anchors: PackedVector3Array
var failure: String = ""
var build_complete: bool = false
var replay_timings: Dictionary = {}
var hero_override: String = ""
## The granite outcrops and the ravine's cliffs, drawn in a few merged meshes
## (R3.3); null in a grey study or where the stone cannot load.
var stone: LandStone = null
## How long each of R3.3's stages took on the worker (ms; probes).
var stone_timings: Dictionary = {}
## What the woodland must leave in sight (`wood_planting.gd`), built at the
## first ruin the kit places and kept up with every placement after it, and
## every ruin's card placed so far: [picture-plane Rect2, the depth it hides
## from] (`_unhidden`).
var _sight: Sight = null
var _cards: Array = []
## How many gravestones the verges and the shrines hold so far (`GRAVES_MOST`).
var _graves_placed: int = 0
## The islands (`Islands.find`), found on the worker pool while the arch, the
## heroes and the lanterns go in (`_seek_islands`), and that search's task (-1
## when none is under way) and its own time (ms); `searched_in_turn` when the
## pool had no thread to spare and the build searched on its own thread.
var _islands_found: Array[Dictionary] = []
var _island_task: int = -1
var _island_search_ms: float = 0.0
var searched_in_turn: bool = false
## How long gathering the stone took on its worker (ms; `gather_stone`).
var _stone_gather_ms: float = 0.0
# Conservative circles enclosing the exported X/Z bounds at every yaw.
const PROFILES: Dictionary = {
	"conifer": Vector2(2.50, 6.40),
	"conifer-wind": Vector2(2.70, 5.50),
	"conifer-snag": Vector2(2.40, 5.30),
	"ash-bramble": Vector2(2.10, .90),
	"ash-fern": Vector2(1.30, .60),
	"granite-shard": Vector2(1.20, 2.20),
	"rubble-scree": Vector2(1.00, .45),
	"conifer-spire": Vector2(1.80, 6.40),
	"ash-heath": Vector2(2.1, 1.05),
	"granite-ridge": Vector2(2.25, 1.10),
	"ash-copse": Vector2(1.65, 1.30),
	"granite-bank": Vector2(1.90, 1.70),
	"granite-tor": Vector2(1.90, 2.45),
	"granite-boulder": Vector2(1.10, 0.95),
	"grave-arched": Vector2(0.45, 1.05),
	"grave-cross": Vector2(0.45, 1.30),
	"grave-broken": Vector2(0.85, 0.75),
	"grave-tablet": Vector2(1.15, 0.75),
	"wall-run": Vector2(1.80, 1.75),
	"wall-corner": Vector2(2.30, 1.75),
	"wall-pier": Vector2(2.00, 2.25),
	"rubble-blocks": Vector2(0.90, .50),
	"rubble-mossy": Vector2(0.85, .45),
	"memorial": Vector2(0.55, 1.95),
	"amber-arch": Vector2(2.65, 5.50),
	"lantern-post": Vector2(0.35, 1.70),
	"bridge-banner": Vector2(0.40, 1.60),
	"bridge-pier": Vector2(0.36, 1.25),
}

## Where each lamp-carrying kind holds its flame (the lantern glass's centre),
## in the model's space; `lantern-post` follows `living_kit.py`'s
## `LANTERN_GLASS_Z`, the gateway its two hanging lamps.
const LAMP_ANCHORS: Dictionary = {
	"amber-arch": [Vector3(-2.30, 2.21, 0.46), Vector3(2.30, 2.21, 0.46)],
	"lantern-post": [Vector3(0.0, 1.38, 0.0)],
	"bridge-pier": [Vector3(0.0, 1.02, 0.0)],
}
## Lanterns along the roads: about one stone post per `LANTERN_SPACING` metres
## of road (one on any road of `LANTERN_SHORTEST` or more), spread evenly along
## it, `LANTERN_OFFSET` off the centreline on alternating sides, and never two
## within `LANTERN_GAP` (junctions and parallel roads share).
const LANTERN_SPACING: float = 9.0
const LANTERN_SHORTEST: float = 4.0
const LANTERN_OFFSET: float = 1.3
const LANTERN_GAP: float = 6.0
## The bridges' set pieces (R3.5), along every stretch of deck raised over
## the river: a flame pier standing out of each parapet at both ends of the
## stretch and evenly between, at most `PIER_SPACING` metres apart, and halfway
## between each pair, on the side facing the journey camera (whose yaw never
## turns; the far side's would hang behind the deck), a banner hung against the
## parapet's outer face (`BANNER_OFFSET` off the deck's centreline, its bar
## `BANNER_HEIGHT` above the deck, `BANNER_SCALE` the R2 cloth's drop).
const PIER_SPACING: float = 3.6
const BANNER_OFFSET: float = 0.95
const BANNER_HEIGHT: float = 0.28
const BANNER_SCALE: float = 1.35
## Where the bridges' dressing begins in `placed` (`_bridge_dressing`).
var _dressing_from: int = 0

## The kit scene the worker places as a scene (the arch), held for the process
## so a build on a worker only ever reads the resource cache (an uncached
## `load` from a worker thread can return null in Godot 4.7.2).
static var _held: Array[PackedScene] = []
## How many of `PROFILES`' scenes are ready so far, in its order.
static var _held_kinds: int = 0
## The kit's scenes asked of the loader's threads, by path.
static var _requested: Dictionary = {}
## The scene the build places as itself; every other kind is drawn from its
## static template (`static_scenery.gd`).
const ARCH: String = "amber-arch"


## How long holding the kit and readying the woodland's atlas has taken on the
## main thread, waits included (benches and probes).
static var preload_ms: float = 0.0


## Readies every kit scene now (a map opening, tests and tools).
static func preload_scenes() -> void:
	while not preload_step(true):
		pass


## Readies the next kit scene on the main thread and answers whether every one
## is ready, and the woodland's impostor atlas and the stone with them
## (`ImpostorAtlas`, `LandStone`: ready, or unable to load; the foliage kinds
## the atlas draws load no scene). Their textures load one at a time, the
## stone's only once the atlas's are taken, so no two of their uploads overlap
## (`ImpostorAtlas.Take`). Every
## step's main-thread time counts in `preload_ms`. A batched kind is loaded as its own
## copy, so its static template takes the meshes without reading them back
## from the renderer; the arch is loaded through the cache and held, as the
## worker loads it there. Stepped
## (the journey prefetch under the title, one scene per frame), the scenes load
## on the loader's threads, the next one asked for as this one is taken, so
## their meshes reach the GPU a scene per frame rather than together; a step
## takes its scene once it has loaded. `wait`ing (a map opening now), a scene
## not asked for loads here, and one being loaded is waited for while the
## renderer is kept in step, as the engine's own wait does, but without running
## the deferred calls that wait would run in the middle of a frame.
static func preload_step(wait: bool = false) -> bool:
	var started: int = Time.get_ticks_usec()
	ImpostorAtlas.request()
	var done: bool = _hold_next(wait) and ImpostorAtlas.prepare_step(wait) and LandStone.prepare_step(wait)
	preload_ms += (Time.get_ticks_usec() - started) / 1000.0
	return done


## Holds the next kit scene; true once every one is held.
static func _hold_next(wait: bool) -> bool:
	var kinds: Array = _scene_kinds()
	if _held_kinds >= kinds.size():
		return true
	Meshes.prepare_unit_box()
	var kind: String = kinds[_held_kinds]
	var path: String = _path(kind)
	if not wait:
		for ahead: int in range(_held_kinds, mini(_held_kinds + 2, kinds.size())):
			_request(str(kinds[ahead]))
	var scene: PackedScene = null
	if _requested.has(path):
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not wait:
				return false
			RenderingServer.force_sync()
			OS.delay_usec(500)
		scene = ResourceLoader.load_threaded_get(path) as PackedScene
	else:
		scene = ResourceLoader.load(path, "PackedScene", _cache_mode(kind)) as PackedScene
	_held_kinds += 1
	var failure: String = "Cannot load " + path if scene == null else ""
	if scene != null and kind == ARCH:
		_held.append(scene)
	elif scene != null:
		failure = preload("res://presentation/map/landscape/static_scenery.gd") \
			.prepare_template(path, kind, scene)
	if not failure.is_empty():
		push_error("Journey kit: " + failure)
	return _held_kinds >= kinds.size()


## The kinds whose scenes the kit holds: all but those drawn elsewhere (the
## woodland's and the ruins' impostors, the stone).
static func _scene_kinds() -> Array:
	return PROFILES.keys().filter(func(kind: String) -> bool:
		return not StaticScenery.drawn_elsewhere(kind))


## Whether `kind` is one of the granite outcrops (`land_stone.gd`).
static func is_rock(kind: String) -> bool:
	return LandStone.OUTCROPS.has(kind)


## A rock, or the rubble that lies round rocks.
static func _stony(kind: String) -> bool:
	return is_rock(kind) or kind.begins_with("rubble-")


static func _request(kind: String) -> void:
	var path: String = _path(kind)
	if not _requested.has(path):
		_requested[path] = true
		ResourceLoader.load_threaded_request(path, "PackedScene", false, _cache_mode(kind))


static func _cache_mode(kind: String) -> ResourceLoader.CacheMode:
	return ResourceLoader.CACHE_MODE_REUSE if kind == ARCH else ResourceLoader.CACHE_MODE_IGNORE


static func _path(kind: String) -> String:
	return "res://assets/art/map-journey/%s.glb" % kind


## `stone_later` leaves the stone's merge to the caller: `gather_stone` on the
## worker pool, beside the woodland's planting, then `finish_stone`
## (`MapJourneyLandscape`); otherwise the build merges it in place.
func build(surface: Terrain, points: PackedVector3Array, grey: bool, heroes: Dictionary = {}, cache: Resource = null,
		stone_later: bool = false) -> void:
	for kind: String in ["conifer","conifer-spire","conifer-wind","conifer-snag"]:
		var envelope: PackedVector2Array = Envelope.load_conifer(kind)
		if envelope.is_empty():
			failure = "Missing current tree envelope: " + kind
			return
		tree_envelopes[kind] = envelope
	terrain = surface
	anchors = points
	contacts = GroundContacts.new()
	add_child(contacts)
	contacts.begin(terrain)
	if use_static_batches and not grey:
		static_scenery=preload("res://presentation/map/landscape/static_scenery.gd").new()
		add_child(static_scenery)
	if cache != null and not cache.get("placements").is_empty():
		var replay_start: int = Time.get_ticks_usec()
		var rows: Array = cache.get("placements")
		var roles: Dictionary = cache.get("hero_roles")
		for i: int in range(rows.size()):
			var row: Dictionary = rows[i]
			var kind: String = row["kind"]
			if not PROFILES.has(kind):
				failure = "Unknown cached woodland asset: "+kind
				return
			var at: Vector3 = row["position"]
			_place(kind,at,float(str(row["scale"])),float(str(row["yaw"])),grey)
			if not failure.is_empty(): return
			if roles.has(str(i)): placed_nodes[-1].set_meta("hero_role",roles[str(i)])
		replay_timings["placements"]=(Time.get_ticks_usec()-replay_start)/1000.0
		replay_start=Time.get_ticks_usec()
		contacts.finish()
		replay_timings["contacts"]=(Time.get_ticks_usec()-replay_start)/1000.0
		replay_start=Time.get_ticks_usec()
		if static_scenery!=null: static_scenery.call("finish")
		_stone(grey)
		replay_timings["batches"]=(Time.get_ticks_usec()-replay_start)/1000.0
		build_complete = true
		return
	_seek_islands()
	# The gateway arch is dressing: a layout with no straight dry leg for it is
	# drawn without one rather than failing the map.
	_landmark(grey)
	for role: String in heroes:
		var hero: Dictionary = heroes[role]
		var kind: String = hero["asset_id"]
		if not PROFILES.has(kind):
			failure = "Unknown woodland hero: "+kind
			_join_islands()
			return
		var transform_data: Dictionary = hero["transform"]
		var origin: Array = transform_data["origin"]
		var at: Vector3 = Meshes.v3(origin)
		at.y = terrain.surface_height(at.x,at.z)
		_place(kind,at,float(str(transform_data["scale"][0])),float(str(transform_data["yaw_radians"])),grey)
		if not failure.is_empty():
			_join_islands()
			return
		placed_nodes[-1].set_meta("hero_role",role)
	_lanterns(grey)
	planting_bounds = Rect2(terrain.bounds.position+Vector2(5,7),terrain.bounds.size-Vector2(10,14))
	_timed("islands", _islands.bind(grey))
	_timed("ruins", _ruins.bind(grey))
	_timed("verge_graves", _verge_graves.bind(grey))
	var planting: Rect2 = planting_bounds
	var area_ratio: float = planting.get_area()/(86.0*46.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7401
	for family: String in ["conifer", "granite-bank", "ash-copse", "memorial"]:
		for i: int in range(ceili(1000*area_ratio)):
			# Establish the six substantial forms before any accent can occupy a gap.
			var kind: String = family
			if i % 2 == 1:
				kind = {"conifer":"conifer-spire", "granite-bank":"granite-ridge", "ash-copse":"ash-heath"}.get(family, family)
			var p: Vector3 = Vector3(rng.randf_range(planting.position.x, planting.end.x), 0, rng.randf_range(planting.position.y, planting.end.y))
			var scale_value: float = rng.randf_range(0.65, 1.05)
			if kind.begins_with("conifer"):
				scale_value = rng.randf_range(0.95, 1.35)
			elif kind.begins_with("ash-"):
				scale_value = rng.randf_range(0.85, 1.25)
			elif is_rock(kind):
				scale_value = rng.randf_range(1.0, 1.45)
			elif kind == "memorial" and i > ceili(200*area_ratio):
				continue
			# Broad groves leave breathing space between groups, rather than an
			# even carpet of individually spaced decorative objects.
			var grove: float = sin(p.x * 0.31 + p.z * 0.09) + cos(p.z * 0.41 - p.x * 0.12)
			if (kind.begins_with("conifer") or kind.begins_with("ash-")) and grove < -0.35:
				continue
			var profile: Vector2 = PROFILES[kind]
			var height: float = profile.y
			var radius: float = profile.x
			p.y = terrain.surface_height(p.x, p.z)
			if not clear(p, radius * scale_value, height * scale_value, kind):
				continue
			p.y = terrain.surface_height(p.x, p.z)
			if not terrain.is_dry(p):
				continue
			_place(kind, p, scale_value, rng.randf_range(-PI, PI), grey)
	# Before the undergrowth and the verges, which grow round them.
	_timed("shrine_graves", _shrine_graves.bind(grey))
	_undergrowth(grey)
	_verges(grey)
	_accents(grey)
	_bridge_dressing(grey)
	_face_gateway(grey)
	contacts.finish()
	if static_scenery!=null: static_scenery.call("finish")
	if stone_later:
		_begin_stone(grey)
	else:
		_timed("stone", _stone.bind(grey))
	if not grey:
		preload("res://presentation/map/landscape/terrain_paint.gd").bind_habitat(terrain,placed,terrain.lines,terrain.is_elevated,lamp_anchors())
	var counts: Dictionary = {}
	for item: Dictionary in placed:
		counts[item["kind"]] = int(str(counts.get(item["kind"],0))) + 1
	build_complete = true

## Stone lantern posts along the roads (R2 light). They go in right after the
## gateway and the heroes, before the woodland, so the groves leave them room
## (the woodland's placements move where a lantern now stands), and through the
## kit's own clearance, which keeps any non-conifer off the walking lane and out
## of every waystone's reserve.
func _lanterns(grey: bool) -> void:
	var profile: Vector2 = PROFILES["lantern-post"]
	var posts: Array[Vector2] = []
	var side: float = 1.0
	for line: PackedVector3Array in terrain.lines:
		var total: float = 0.0
		for i: int in range(line.size() - 1):
			total += Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z).length()
		if total < LANTERN_SHORTEST:
			continue
		var count: int = maxi(1, roundi(total / LANTERN_SPACING))
		var travelled: float = 0.0
		var next: float = total / count * 0.5
		for i: int in range(line.size() - 1):
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var run: Vector2 = Vector2(b.x - a.x, b.z - a.z)
			var length: float = run.length()
			while length > 0.0 and next <= travelled + length:
				var at: Vector3 = a.lerp(b, (next - travelled) / length)
				next += total / count
				side = -side
				var across: Vector2 = Vector2(-run.y, run.x) / length * side * LANTERN_OFFSET
				var p: Vector3 = Vector3(at.x + across.x, 0.0, at.z + across.y)
				p.y = terrain.surface_height(p.x, p.z)
				if terrain.is_elevated(at) or not terrain.is_dry(p) \
						or absf(p.y - terrain.route_height(at)) > 0.45:
					continue
				if posts.any(func(other: Vector2) -> bool:
						return other.distance_to(Vector2(p.x, p.z)) < LANTERN_GAP):
					continue
				if not clear(p, profile.x, profile.y, "lantern-post"):
					continue
				_place("lantern-post", p, 1.0, atan2(run.x, run.y), grey)
				posts.append(Vector2(p.x, p.z))
			travelled += length


## Piers and banners on the bridges over the river (R2 motion, R3.5). They are
## part of the bridge, not the ground, so they skip the ground clearance, and
## go in last: the undergrowth and verges draw from every placement before
## them, so placing them earlier would move the woodland. They keep clear of
## the roads' ends, where waystones and junctions stand.
func _bridge_dressing(grey: bool) -> void:
	_dressing_from = placed.size()
	var chains: Array = terrain.get_meta("bridge_chains", [])
	var field: RefCounted = terrain.get_meta("bridge_field", null)
	for chain: Dictionary in chains:
		var points: PackedVector3Array = chain["points"]
		var lengths: PackedFloat32Array = chain["lengths"]
		var weights: PackedFloat32Array = chain["weights"]
		var first: int = -1
		for i: int in range(points.size()):
			var over: bool = weights[i] >= 0.95 and terrain.stream_distance(points[i].x, points[i].z) <= 5.0 \
				and not terrain.lines.any(func(line: PackedVector3Array) -> bool:
					return _flat(points[i]).distance_to(_flat(line[0])) < 2.0 \
						or _flat(points[i]).distance_to(_flat(line[-1])) < 2.0)
			if over and first < 0:
				first = i
			if first >= 0 and (not over or i == points.size() - 1):
				_span(points, lengths, first, i if over else i - 1, field, grey)
				first = -1


## One raised stretch of a deck, `first` to `last` along its centreline: its
## piers, both sides, and its banners, the camera's side.
func _span(points: PackedVector3Array, lengths: PackedFloat32Array, first: int, last: int,
		field: RefCounted, grey: bool) -> void:
	var run: float = lengths[last] - lengths[first]
	if run < 1.0:
		return
	var gaps: int = maxi(1, ceili(run / PIER_SPACING))
	for k: int in range(gaps * 2 + 1):
		var pose: Array = _along(points, lengths, first, last, lengths[first] + run * k / (gaps * 2.0))
		var middle: Vector3 = pose[0]
		var forward: Vector3 = pose[1]
		var across: Vector3 = forward.cross(Vector3.UP).normalized()
		if across.z < 0.0:
			across = -across
		if k % 2 == 0:
			for sign_value: float in [-1.0, 1.0]:
				var at: Vector3 = middle + across * Bridges.PARAPET_OFFSET * sign_value
				at.y = _deck(field, at, middle.y)
				if _on_parapet(field, at, across * sign_value) and _free_on_bridge("bridge-pier", at, 1.0):
					_place("bridge-pier", at, 1.0, atan2(forward.x, forward.z), grey)
		elif across.z >= 0.5:
			var cloth: Vector3 = middle + across * BANNER_OFFSET
			cloth.y = _deck(field, middle, middle.y) + BANNER_HEIGHT
			if _free_on_bridge("bridge-banner", cloth, PIER_SPACING * 0.5):
				_place("bridge-banner", cloth, BANNER_SCALE, atan2(across.x, across.z), grey)


## Whether `at` is on a parapet's line: at its deck's edge, with no deck
## beyond it (`outward`), as the parapet's own wall stands (`Bridges`); where
## two decks fork, one road's edge lies on the other's walking lane.
static func _on_parapet(field: RefCounted, at: Vector3, outward: Vector3) -> bool:
	if field == null:
		return true
	var here: Dictionary = field.call("field", Vector2(at.x, at.z))
	var beyond: Vector3 = at + outward * 0.22
	var there: Dictionary = field.call("field", Vector2(beyond.x, beyond.z))
	return float(str(here["distance"])) > -0.2 and float(str(there["distance"])) >= 0.0


## Roads that share a bridgehead share their deck there: a piece one road's
## stretch has already set within `apart` metres stands for both.
func _free_on_bridge(kind: String, at: Vector3, apart: float) -> bool:
	for index: int in range(_dressing_from, placed.size()):
		var item: Dictionary = placed[index]
		var other: Vector3 = item["position"]
		if str(item["kind"]) == kind and _flat(other).distance_to(_flat(at)) < apart:
			return false
	return true


## The centreline's point `s` metres along and its heading, within `first` to
## `last`.
static func _along(points: PackedVector3Array, lengths: PackedFloat32Array, first: int, last: int,
		s: float) -> Array:
	var i: int = first
	while i < last - 1 and lengths[i + 1] < s:
		i += 1
	var j: int = mini(i + 1, last)
	if j == i:
		i = maxi(first, i - 1)
	var t: float = clampf((s - lengths[i]) / maxf(0.0001, lengths[j] - lengths[i]), 0.0, 1.0)
	var forward: Vector3 = points[j] - points[i]
	forward.y = 0.0
	return [points[i].lerp(points[j], t), forward.normalized()]


## The deck's walking height at `at`, from the bridges' field where it has one.
static func _deck(field: RefCounted, at: Vector3, fallback: float) -> float:
	if field == null:
		return fallback
	var sample: Dictionary = field.call("field", Vector2(at.x, at.z))
	return float(str(sample["height"])) if float(str(sample["distance"])) < 0.3 else fallback


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## Every lamp's flame centre on the land: the gateway's two and each post's.
func lamp_anchors() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for item: Dictionary in placed:
		out.append_array(_lamps_of(item))
	return out


## The lamps one placement carries, in land space.
static func _lamps_of(item: Dictionary) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var kind: String = item["kind"]
	if not LAMP_ANCHORS.has(kind):
		return out
	var scale_value: float = float(str(item["scale"]))
	var at: Vector3 = item["position"]
	var pose: Transform3D = Transform3D(
		Basis(Vector3.UP, float(str(item["yaw"]))).scaled(Vector3.ONE * scale_value), at)
	for local: Vector3 in LAMP_ANCHORS[kind]:
		out.append(pose * local)
	return out


## The grid of what the woodland must leave in sight, as the kit built it for
## its ruins over every placement (`_in_sight`); null where it built none. The
## woodland plants against it (`wood_planting.gd` `_protect`).
func woodland_sight() -> Sight:
	return _sight


func _landmark(grey: bool) -> void:
	var site: Dictionary = GatewaySites.choose(terrain, anchors)
	if site.is_empty():
		return
	var at: Vector3 = site["position"]
	var yaw: float = float(str(site["yaw"]))
	if not grey:
		var ground: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
		var paint: ShaderMaterial = ground.material_override as ShaderMaterial
		paint.set_shader_parameter("gateway_position", Vector2(at.x, at.z))
	_place("amber-arch", at, 1.0, yaw, grey)
	_companion("memorial", at + Vector3(-4, 0, -1), 1.0, -0.2, grey)
	_companion("granite-bank", at + Vector3(4, 0, 1), 1.15, 0.5, grey)
	_companion("granite-bank", at + Vector3(6, 0, -6), 1.20, -0.35, grey)
	_companion("granite-ridge", at + Vector3(-7, 0, -7), 1.10, 0.4, grey)
	_companion("conifer", at + Vector3(-5, 0, -7), 1.2, 0.7, grey)
	_companion("conifer-spire", at + Vector3(1, 0, -8), 1.15, -0.4, grey)
	_companion("conifer", at + Vector3(6, 0, -5), 1.05, 0.3, grey)

## Islands between the road loops anchored by a composed group (R3.3; the
## islands, `land_islands.gd`, largest first, at most `ISLAND_GROUPS`): an
## outcrop at the island's pole (the largest that fits of a tor, where there
## is room, a bank and a boulder), a conifer behind it, shrubs round it and
## gravestones either side of it (in front, a card would hide the rock), each
## near its mark where the kit's clearance allows. Before the woodland's
## families, which grow round them.
const ISLAND_GROUPS: int = 8
const TOR_ROOM: float = 2.5
const BANK_ROOM: float = 1.6


func _islands(grey: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7811
	var started: int = Time.get_ticks_usec()
	_join_islands()
	# The build's wait for the search, and the search's own time on its worker.
	stone_timings["island_search"] = (Time.get_ticks_usec() - started) / 1000.0
	stone_timings["island_search_worker"] = _island_search_ms
	for island: Dictionary in _islands_found.slice(0, ISLAND_GROUPS):
		var at: Vector3 = island["centre"]
		var room: float = float(str(island["clearance"]))
		var rock_scale: float = rng.randf_range(0.9, 1.05)
		var rock_yaw: float = rng.randf_range(-PI, PI)
		for rock: String in ["granite-tor", "granite-bank", "granite-boulder"]:
			if (rock == "granite-tor" and room < TOR_ROOM) or (rock == "granite-bank" and room < BANK_ROOM):
				continue
			if _near(rock, at, rock_scale, rock_yaw, grey):
				break
		_near("conifer" if rng.randf() < 0.6 else "conifer-spire",
			at + Vector3(rng.randf_range(-1.2, 1.2), 0.0, -2.8), rng.randf_range(0.95, 1.2), rng.randf_range(-PI, PI), grey)
		for i: int in range(3):
			var angle: float = rng.randf_range(-PI, PI)
			_near("ash-copse" if i == 1 else "ash-heath", at + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(1.8, 2.6),
				rng.randf_range(0.7, 0.95), angle, grey)
		for i: int in range(2 + rng.randi_range(0, 1)):
			var side: float = -1.0 if i % 2 == 0 else 1.0
			_near(_grave(rng), at + Vector3(side * rng.randf_range(2.6, 3.2), 0.0, rng.randf_range(-0.6, 1.2)),
				rng.randf_range(0.9, 1.05), rng.randf_range(-0.35, 0.35), grey, 1.2)


## Starts the island search on the worker pool (R3.3): it reads only the land
## (its roads' field and height grid, the rivers), which nothing changes while
## the kit's first placements go in, so `_islands` finds it done or nearly. The
## roads' index is built here first, so the search only reads it. On a pool
## with no thread to spare (`Terrain.pool_spares_threads`) it runs here.
func _seek_islands() -> void:
	terrain.distance_to_roads(Vector3.ZERO)
	if not Terrain.pool_spares_threads():
		searched_in_turn = true
		_find_islands()
		return
	_island_task = WorkerThreadPool.add_task(_find_islands, false, "Journey islands")


func _find_islands() -> void:
	var started: int = Time.get_ticks_usec()
	_islands_found = Islands.find(terrain)
	_island_search_ms = (Time.get_ticks_usec() - started) / 1000.0


## Waits for the island search, which every build ends (a task the pool ran is
## always waited for).
func _join_islands() -> void:
	if _island_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_island_task)
		_island_task = -1


## Gravestones (R3.3): short rows along the roads' verges, one every
## `GRAVE_SPACING` metres of road on alternating sides, `GRAVE_OFFSET` off the
## line, placed before the woodland's families (`_verge_graves`), and one
## beside each of up to `SHRINE_GRAVES` memorial shrines after them, of the
## first twice as many (`_shrine_graves`); at most `GRAVES_MOST` in all. Each
## faces the journey camera, a little turned.
const SHRINE_GRAVES: int = 8
const GRAVE_SPACING: float = 13.0
const GRAVE_OFFSET: Vector2 = Vector2(2.3, 3.1)
const GRAVE_ROW: float = 0.95
const GRAVES_MOST: int = 30


func _shrine_graves(grey: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7853
	var shrines: int = 0
	var beside_shrines: int = 0
	for item: Dictionary in placed.duplicate():
		if str(item["kind"]) != "memorial" or shrines >= SHRINE_GRAVES * 2 or beside_shrines >= SHRINE_GRAVES \
				or _graves_placed >= GRAVES_MOST:
			continue
		shrines += 1
		var shrine: Vector3 = item["position"]
		var beside: float = -1.0 if shrines % 2 == 0 else 1.0
		if _near(_grave(rng), shrine + Vector3(beside * rng.randf_range(1.5, 2.1), 0.0, rng.randf_range(-0.6, 0.6)),
				rng.randf_range(0.85, 1.05), rng.randf_range(-0.4, 0.4), grey, 1.0):
			beside_shrines += 1
			_graves_placed += 1


func _verge_graves(grey: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7859
	var count: int = _graves_placed
	var side: float = 1.0
	for line: PackedVector3Array in terrain.lines:
		var travelled: float = 0.0
		var next: float = GRAVE_SPACING * 0.5
		for i: int in range(line.size() - 1):
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var run: Vector2 = Vector2(b.x - a.x, b.z - a.z)
			var length: float = run.length()
			while length > 0.0 and next <= travelled + length and count < GRAVES_MOST:
				var on: Vector3 = a.lerp(b, (next - travelled) / length)
				next += GRAVE_SPACING
				side = -side
				if terrain.is_elevated(on):
					continue
				var across: Vector2 = Vector2(-run.y, run.x) / length * side
				var row: Vector2 = run / length
				var offset: float = rng.randf_range(GRAVE_OFFSET.x, GRAVE_OFFSET.y)
				# Two a row: a third tips the land's tree mix (`test_map_wood`).
				for k: int in range(mini(2, GRAVES_MOST - count)):
					var along: float = (k - 0.5) * GRAVE_ROW
					var at: Vector3 = on + Vector3(across.x * offset + row.x * along, 0.0, across.y * offset + row.y * along)
					# A row's stone stands where its row puts it, or not at all.
					count += 1 if _near(_grave(rng), at, rng.randf_range(0.85, 1.05), rng.randf_range(-0.3, 0.3), grey, 0.5, 1) else 0
			travelled += length
	_graves_placed = count


func _grave(rng: RandomNumberGenerator) -> String:
	return ImpostorAtlas.GRAVES[rng.randi_range(0, ImpostorAtlas.GRAVES.size() - 1)]


## Ruins (R3.3): `RUIN_SITES` broken walls a few metres off the roads, each at
## least `RUIN_GAP` from the last, turned across the camera's view, with fallen
## blocks at their foot and a mossy mound beside them.
const RUIN_SITES: int = 4
const RUIN_GAP: float = 16.0
const RUIN_ROAD: Vector2 = Vector2(3.0, 5.5)
const RUIN_TRIES: int = 200


func _ruins(grey: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7867
	var sites: Array[Vector3] = []
	for attempt: int in range(RUIN_TRIES):
		if sites.size() >= RUIN_SITES:
			break
		var p: Vector3 = Vector3(rng.randf_range(planting_bounds.position.x, planting_bounds.end.x), 0.0,
			rng.randf_range(planting_bounds.position.y, planting_bounds.end.y))
		var yaw: float = rng.randf_range(-0.45, 0.45)
		if sites.any(func(other: Vector3) -> bool: return _flat(other).distance_to(_flat(p)) < RUIN_GAP):
			continue
		var road: float = terrain.distance_to_roads(p)
		if road < RUIN_ROAD.x or road > RUIN_ROAD.y:
			continue
		p.y = terrain.surface_height(p.x, p.z)
		var wall: String = ImpostorAtlas.WALLS[sites.size() % ImpostorAtlas.WALLS.size()]
		var profile: Vector2 = PROFILES[wall]
		if not terrain.is_dry(p) or not clear(p, profile.x, profile.y, wall) or not _in_sight(wall, p, 1.0, yaw):
			continue
		_place(wall, p, 1.0, yaw, grey)
		sites.append(p)
		_near("rubble-blocks", p + Vector3(rng.randf_range(-0.8, 0.8), 0.0, 1.3).rotated(Vector3.UP, yaw),
			rng.randf_range(0.85, 1.05), rng.randf_range(-PI, PI), grey, 1.0)
		_near("rubble-mossy", p + Vector3(2.4 * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, 0.8).rotated(Vector3.UP, yaw),
			rng.randf_range(0.85, 1.05), rng.randf_range(-PI, PI), grey, 1.5)


func _timed(stage: String, run: Callable) -> void:
	var started: int = Time.get_ticks_usec()
	run.call()
	stone_timings[stage] = (Time.get_ticks_usec() - started) / 1000.0


## Places `kind` at the first spot that is dry and clear: `target`, else one
## of `NEAR_TURNS` round it at half `reach`, else at `reach` (`rings` of them,
## the target the first); whether it was placed. A few tries, not a search:
## the land is built on a worker the opening map waits for.
const NEAR_TURNS: int = 6


func _near(kind: String, target: Vector3, scale_value: float, yaw: float, grey: bool, reach: float = 2.0,
		rings: int = 3) -> bool:
	var profile: Vector2 = PROFILES[kind] * scale_value
	for ring: int in range(rings):
		var radius: float = reach * ring * 0.5
		for k: int in range(1 if ring == 0 else NEAR_TURNS):
			var angle: float = TAU * (k + ring * 0.5) / NEAR_TURNS
			var p: Vector3 = target + Vector3(cos(angle), 0.0, sin(angle)) * radius
			p.y = terrain.surface_height(p.x, p.z)
			if terrain.is_dry(p) and _in_sight(kind, p, scale_value, yaw) and clear(p, profile.x, profile.y, kind):
				_place(kind, p, scale_value, yaw, grey)
				return true
	return false


## Whether a ruin of `kind` at `p` would be drawn: its card hides nothing the
## woodland keeps in sight (`wood_planting.gd` `protect_ground`,
## `protect_item`), and no earlier ruin's card hides it (`_unhidden`), so the
## kit places no ruin the woodland would leave out. Kinds the atlas has no
## tiles for (a grey study) always pass.
func _in_sight(kind: String, p: Vector3, scale_value: float, yaw: float) -> bool:
	if not ImpostorAtlas.RUINS.has(kind) or not ImpostorAtlas.by_kind.has(kind):
		return true
	if _sight == null:
		var started: int = Time.get_ticks_usec()
		_sight = Sight.new()
		_sight.begin(terrain.bounds)
		Planting.protect_ground(_sight, terrain, lamp_anchors(), anchors)
		for item: Dictionary in placed:
			Planting.protect_item(_sight, item)
		stone_timings["sight"] = (Time.get_ticks_usec() - started) / 1000.0
	return _sight.fits(ImpostorAtlas.tile_for(kind, yaw), p, scale_value) \
		and _unhidden({"kind": kind, "position": p, "scale": scale_value, "yaw": yaw})


## Whether `item` (a placement: kind, position, radius, height, scale, yaw)
## stands clear of every ruin's card placed so far, where it is something the
## woodland keeps in sight: a ruin is never placed in front of it, and it is
## never placed behind a ruin.
func _unhidden(item: Dictionary) -> bool:
	if _cards.is_empty():
		return true
	var area: Array = Planting.protected_area(_sight, item)
	if area.is_empty():
		return true
	var kept: Rect2 = area[0]
	var depth: float = area[1]
	for card: Array in _cards:
		var cover: Rect2 = card[0]
		var limit: float = card[1]
		if limit > depth and cover.intersects(kept):
			return false
	return true


## The granite outcrops the kit placed and the ravine's cliff pieces
## (`ravine_cliffs.gd`), merged and drawn (`land_stone.gd`).
func _stone(grey: bool) -> void:
	if _begin_stone(grey):
		gather_stone()
		stone.finish()


## Makes the land's stone node (R3.3); false in a grey study or where the stone
## cannot load.
func _begin_stone(grey: bool) -> bool:
	if grey or LandStone.failed:
		return false
	stone = LandStone.new()
	add_child(stone)
	return true


## Gathers the stone's pieces into its cells: the kit's outcrops and the
## ravine's cliffs. It reads only the kit's placements and the land, which
## nothing changes once the kit is built, so it may run on the worker pool
## beside the woodland's planting (`MapJourneyLandscape`). A stone that already
## holds its pieces (a replayed build makes it in place) is not gathered again.
func gather_stone() -> void:
	if stone == null or not stone.placed.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var poses: Array = []
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		if LandStone.draws_kind(kind):
			var scale_value: float = float(str(item["scale"]))
			var at: Vector3 = item["position"]
			poses.append([kind, Transform3D(Basis(Vector3.UP, float(str(item["yaw"]))).scaled(
				Vector3.ONE * scale_value), at)])
	poses.append_array(RavineCliffs.plan(terrain, anchors))
	stone.gather(poses)
	_stone_gather_ms = (Time.get_ticks_usec() - started) / 1000.0


## Commits the gathered stone into its draws, on the land's worker; `waited_ms`
## is how long the land waited for the gathering.
func finish_stone(waited_ms: float) -> void:
	if stone == null:
		return
	var started: int = Time.get_ticks_usec()
	stone.finish()
	stone_timings["stone"] = _stone_gather_ms
	stone_timings["stone_wait"] = waited_ms
	stone_timings["stone_finish"] = (Time.get_ticks_usec() - started) / 1000.0


func _companion(kind: String, target: Vector3, scale_value: float, yaw: float, grey: bool) -> void:
	var profile: Vector2 = PROFILES[kind] * scale_value
	var best: Vector3 = Vector3.INF
	var distance: float = INF
	for x: int in range(-8, 9):
		for z: int in range(-8, 9):
			var p: Vector3 = target + Vector3(x * 0.5, 0, z * 0.5)
			p.y = terrain.surface_height(p.x, p.z)
			if not terrain.is_dry(p) or not clear(p, profile.x, profile.y, kind):
				continue
			var candidate: float = p.distance_to(target)
			if candidate < distance:
				distance = candidate
				best = p
	if best.is_finite():
		_place(kind, best, scale_value, yaw, grey)

func _undergrowth(grey: bool) -> void:
	var groups: Array[Dictionary] = placed.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7523
	for group: Dictionary in groups:
		var family: String = str(group["kind"])
		if not family.begins_with("conifer") and not is_rock(family):
			continue
		var centre: Vector3 = group["position"]
		for i: int in range(12):
			var angle: float = rng.randf_range(-PI, PI)
			var p: Vector3 = centre + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(1.2, 3.0)
			p.y = terrain.surface_height(p.x, p.z)
			var kind: String = "ash-heath" if i % 3 != 0 else "ash-copse"
			var scale_value: float = rng.randf_range(0.65, 1.0)
			var profile: Vector2 = PROFILES[kind] * scale_value
			if terrain.is_dry(p) and clear(p, profile.x, profile.y, kind):
				_place(kind, p, scale_value, angle, grey)

func _verges(grey: bool) -> void:
	# Route-directed candidates use the narrow pockets missed by broad scatter.
	# Each short group leaves a gap; both sides retain the exact same road and
	# node-clearance checks as larger props.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7501
	for line: PackedVector3Array in terrain.lines:
		for index: int in range(line.size() - 1):
			var a: Vector3 = line[index]
			var b: Vector3 = line[index + 1]
			var direction: Vector3 = (b - a).normalized()
			var side: Vector3 = direction.cross(Vector3.UP).normalized()
			var count: int = maxi(1, ceili(a.distance_to(b) / 0.65))
			for step: int in range(count):
				var centre: Vector3 = a.lerp(b, (step + 0.5) / count)
				for sign_value: float in [-1, 1]:
					if sin(centre.x * 0.7 + centre.z * 0.6 + sign_value) < -0.35:
						continue
					var kind: String = "ash-heath" if rng.randf() < 0.55 else "ash-copse"
					var profile: Vector2 = PROFILES[kind]
					var scale_value: float = rng.randf_range(0.70, 1.05)
					var p: Vector3 = centre + side * sign_value * rng.randf_range(2.0, 3.2)
					p.y = terrain.surface_height(p.x, p.z)
					if not terrain.is_dry(p) or not clear(p, profile.x * scale_value, profile.y * scale_value, kind):
						continue
					_place(kind, p, scale_value, rng.randf_range(-PI, PI), grey)

func _accents(grey: bool) -> void:
	# Accent candidates only run after the complete woodland composition.
	# They cannot replace its canopies, shrubs, banks or their reserved space.
	var groups: Array[Dictionary] = placed.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7631
	var hero: Vector3 = groups[0]["position"] if not groups.is_empty() else Vector3.INF
	var limits: Dictionary = {"ash-fern":22,"ash-bramble":10,"rubble-scree":7,"granite-shard":3,"granite-boulder":5,"conifer-wind":3,"conifer-snag":2}
	var counts: Dictionary = {}
	for group: Dictionary in groups:
		var family: String = str(group["kind"])
		if not family.begins_with("conifer") and not is_rock(family):
			continue
		var centre: Vector3 = group["position"]
		for kind: String in limits:
			var count: int = int(str(counts.get(kind,0)))
			if count >= int(str(limits[kind])):
				continue
			if kind.begins_with("conifer") and centre.distance_to(hero)<11:
				continue
			if _stony(kind) and not is_rock(family):
				continue
			for attempt: int in range(24):
				var angle: float = rng.randf_range(-PI,PI)
				var radius: float = rng.randf_range(1.4,3.6)
				if _stony(kind):
					radius = rng.randf_range(3.0,5.5)
				if kind.begins_with("conifer"):
					radius = rng.randf_range(2.4,4.4)
				var p: Vector3 = centre+Vector3(cos(angle),0,sin(angle))*radius
				p.y = terrain.surface_height(p.x,p.z)
				var scale_value: float = rng.randf_range(.65,.85)
				if kind.begins_with("conifer"):
					scale_value = rng.randf_range(.90,1.05)
				var profile: Vector2 = PROFILES[kind]*scale_value
				if not planting_bounds.has_point(Vector2(p.x,p.z)) or not terrain.is_dry(p) or not clear(p,profile.x,profile.y,kind) \
						or not _in_sight(kind, p, scale_value, angle):
					continue
				_place(kind,p,scale_value,angle,grey)
				counts[kind] = count+1
				break

func clear(p: Vector3, radius: float, height: float, kind: String = "") -> bool:
	var started: int = Time.get_ticks_usec()
	var result: bool = _clear(p,radius,height,kind)
	query_us += Time.get_ticks_usec()-started
	query_count += 1
	return result

## How much of a rock's footprint circle must stand off the rivers' water
## (R3.3): the rest may reach over the bank, never the water.
const ROCK_WATER: float = 0.75


func _clear(p: Vector3, radius: float, height: float, kind: String) -> bool:
	if is_rock(kind) and River.distance(p.x, p.z) * River.CHANNEL < River.HALF_WIDTH * River.CHANNEL + radius * ROCK_WATER:
		return false
	if not _cards.is_empty() and (kind == "memorial" or kind == ARCH or is_rock(kind)) \
			and not _unhidden({"kind": kind, "position": p, "radius": radius, "height": height,
				"scale": radius / PROFILES[kind].x, "yaw": 0.0}):
		return false
	# Canopies may reach the shoulder; woody roots stay off the walking lane.
	var road_radius: float = radius
	if kind.begins_with("conifer"):
		road_radius *= 0.38
	elif kind.begins_with("ash-"):
		road_radius *= 0.65
	var road_started: int = Time.get_ticks_usec()
	var near_road: bool = terrain.distance_to_roads(p) < road_radius + 0.85
	road_query_us += Time.get_ticks_usec()-road_started
	if near_road:
		return false
	var silhouette: PackedVector2Array = []
	if kind.begins_with("conifer"):
		var profile: Vector2 = PROFILES[kind]
		for point: Vector2 in tree_envelopes[kind]:
			silhouette.append(point * (height / profile.y))
	# Out of every waystone's line of sight from the journey camera.
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	for point: Vector3 in anchors:
		var delta: Vector3 = p - point
		var projected_z: float = delta.z - (p.y - point.y) / tan(pitch)
		if absf(delta.x) < radius + 1.2 and projected_z > -radius - 1.3 and projected_z < radius + height / tan(pitch) + 1.3:
			if not kind.begins_with("conifer"):
				return false
			var projected: Vector2 = Vector2(-delta.x, -delta.z + (p.y - point.y) / tan(pitch))
			var reserve: PackedVector2Array = [projected + Vector2(-1.2,-1.3), projected + Vector2(1.2,-1.3), projected + Vector2(1.2,1.3), projected + Vector2(-1.2,1.3)]
			if not Geometry2D.intersect_polygons(silhouette, reserve).is_empty():
				return false
	for placement: Dictionary in neighbours.query(p,radius):
		var other: Vector3 = placement["position"]
		var separation: float = radius + float(str(placement["radius"]))
		# The same undergrowth overlap applies whichever member was placed first.
		# Canopies and shrubs can interleave; road/node reserves stay unchanged.
		if kind.begins_with("conifer") and str(placement["kind"]).begins_with("conifer"):
			separation *= 0.58
		elif kind.begins_with("ash-") and str(placement["kind"]).begins_with("ash-"):
			separation *= 0.38
		elif (kind.begins_with("ash-") and str(placement["kind"]).begins_with("conifer")) or (kind.begins_with("conifer") and str(placement["kind"]).begins_with("ash-")):
			separation *= 0.30
		elif (kind.begins_with("ash-") and is_rock(str(placement["kind"]))) or (is_rock(kind) and str(placement["kind"]).begins_with("ash-")):
			separation *= 0.50
		elif kind.begins_with("rubble-") and str(placement["kind"]).begins_with("wall-"):
			# A ruin's fallen blocks lie at its foot.
			separation *= 0.45
		if Vector2(other.x - p.x, other.z - p.z).length() < separation:
			return false
	return true

func _place(kind: String, p: Vector3, scale_value: float, yaw: float, grey: bool) -> void:
	var item: Node3D
	var path: String = "res://assets/art/map-journey/%s.glb" % kind
	if kind == "amber-arch" and not hero_override.is_empty():
		path = hero_override
	var batched: bool = static_scenery!=null and kind!="amber-arch"
	if batched:
		item=static_scenery.call("prepare",path,kind)
		if item==null:
			failure=static_scenery.get("failure")
			return
	elif not grey and StaticScenery.drawn_elsewhere(kind):
		item = Node3D.new()
		item.name = kind
	elif not grey:
		if not asset_scenes.has(path):
			if not ResourceLoader.exists(path):
				failure = "Missing imported workshop asset: " + path
				push_error(failure)
				return
			var loaded: PackedScene = load(path) as PackedScene
			if loaded == null:
				failure = "Cannot load workshop asset: " + path
				push_error(failure)
				return
			asset_scenes[path] = loaded
		var resource: PackedScene = asset_scenes[path]
		item = resource.instantiate() as Node3D
		var foliage_surfaces: int = AssetSurfaces.prepare(item,material_pool)
		if (kind.begins_with("conifer") or kind.begins_with("ash-")) and kind not in ["conifer-snag","ash-fern"] and foliage_surfaces == 0:
			failure = "No cut-out foliage surface prepared: " + kind
			item.free()
			return
		if kind == "amber-arch" and not hero_override.is_empty():
			if not AssetLights.attach_trial(item):
				failure = "Missing trial lamp attachment"
	else:
		var profile: Vector2 = PROFILES[kind]
		var height: float = profile.y
		var radius: float = profile.x
		item = Meshes.box(self, Vector3.ZERO, Vector3(radius * 1.6, height, radius), Meshes.material(Color("6c707c")), kind)
		(item as MeshInstance3D).mesh = (item as MeshInstance3D).mesh.duplicate() as Mesh
		item.position.y = height * 0.5
	var lift: float = item.position.y
	item.position = p + Vector3.UP * lift * scale_value
	item.scale = Vector3.ONE * scale_value
	item.rotation.y = yaw
	if not grey:
		# Configure imported subtrees before entering the live world. This avoids
		# submitting every intermediate transform/material to the renderer.
		add_child(item)
		if batched: static_scenery.call("register",item)
		contacts.place(kind, p, scale_value, yaw)
	var footprint: Vector2 = PROFILES[kind]
	placed_nodes.append(item)
	placed.append({"kind": kind, "position": p, "radius": footprint.x * scale_value, "height": footprint.y * scale_value, "scale":scale_value, "yaw":yaw})
	neighbours.add(placed[-1])
	if _sight != null:
		Planting.protect_item(_sight, placed[-1])
		if LAMP_ANCHORS.has(kind):
			Planting.protect_lamps(_sight, _lamps_of(placed[-1]))
		if ImpostorAtlas.RUINS.has(kind) and ImpostorAtlas.by_kind.has(kind):
			var tile: int = ImpostorAtlas.tile_for(kind, yaw)
			_cards.append([ImpostorAtlas.rect(tile, p, scale_value),
				_sight.depth(p) + ImpostorAtlas.shift(tile) * scale_value + Sight.DEPTH_MARGIN])


## A face-on gateway's clearance (`_gateway_clear`): round each pier's footing
## and along the lane through it (metres).
const GATEWAY_PIER: float = 0.85
const GATEWAY_LANE: float = 0.9
## How far the ground under either pier may lie from the ground under the
## arch's centre (metres); its footings fill the rest (`ground_contacts.gd`).
const GATEWAY_LEVEL: float = 0.2
## Whether the build turns the gateway to face the camera (`_face_gateway`);
## the suite turns it off to show the turn moves nothing else.
static var face_gateway: bool = true


## The gateway arch turned to face the journey camera (#660; the owner's leave,
## 14 Oct 2026). `_landmark` stood it on `GatewaySites.choose`'s passage, a
## road across the screen that shows it edge-on, and every other placement was
## made round it there; last of all, drawing no random numbers, it moves to the
## face-on site `GatewaySites.facing` finds clear of them (`_gateway_clear`),
## so none of them moves. Its companions and its terrace stay at the first
## site, and what the woodland keeps in sight there stays kept; its apron of
## flags, its footings and its lamps go with it, and the woodland keeps it in
## sight where it now stands. Where no leg has a face-on site it stays where
## it stood.
func _face_gateway(grey: bool) -> void:
	if not face_gateway:
		return
	var index: int = placed.find_custom(func(item: Dictionary) -> bool: return item["kind"] == ARCH)
	if index < 0:
		return
	var site: Dictionary = GatewaySites.facing(terrain, anchors, _gateway_clear.bind(placed[index]))
	if site.is_empty():
		return
	var at: Vector3 = site["position"]
	var yaw: float = float(str(site["yaw"]))
	var item: Dictionary = placed[index]
	var node: Node3D = placed_nodes[index]
	var was: Vector3 = item["position"]
	node.position = at + Vector3.UP * (node.position.y - was.y)
	node.rotation.y = yaw
	neighbours.remove(item)
	item["position"] = at
	item["yaw"] = yaw
	neighbours.add(item)
	if not grey:
		contacts.place(ARCH, at, float(str(item["scale"])), yaw)
		var ground: MeshInstance3D = terrain.get_node("Quiet sculpted ground") as MeshInstance3D
		(ground.material_override as ShaderMaterial).set_shader_parameter("gateway_position", Vector2(at.x, at.z))
	if _sight != null:
		Planting.protect_item(_sight, item)
		Planting.protect_lamps(_sight, _lamps_of(item))


## Whether the arch (`arch`, its placement) at `at`, turned to `yaw`, stands
## clear of every other placement: on dry ground level under both piers, no
## earlier ruin's card hiding it, no tree's trunk and nothing but undergrowth
## at either pier's footing, and nothing but foliage on its lane. Undergrowth
## may grow round a pier's foot; the woodland trims whatever foliage would
## hide the arch (`wood_planting.gd` `protected_area`).
func _gateway_clear(at: Vector3, yaw: float, arch: Dictionary) -> bool:
	var side: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	for pier: Vector3 in [at - side * GatewaySites.PIER_OFFSET, at + side * GatewaySites.PIER_OFFSET]:
		if not terrain.is_dry(pier) or absf(terrain.surface_height(pier.x, pier.z) - at.y) > GATEWAY_LEVEL:
			return false
	if not terrain.is_dry(at) or not _unhidden({"kind": ARCH, "position": at, "radius": arch["radius"],
			"height": arch["height"], "scale": arch["scale"], "yaw": yaw}):
		return false
	for other: Dictionary in neighbours.query(at, float(str(arch["radius"]))):
		var kind: String = other["kind"]
		if is_same(other, arch) or kind.begins_with("ash-"):
			continue
		var other_at: Vector3 = other["position"]
		var there: Vector2 = _flat(other_at)
		var tree: bool = kind.begins_with("conifer")
		# A tree's trunk, as `_clear` keeps it off the walking lane.
		var reach: float = float(str(other["radius"])) * (0.38 if tree else 1.0)
		if not tree and there.distance_to(_flat(at)) < GATEWAY_LANE + reach:
			return false
		for sign_value: float in [-1, 1]:
			if there.distance_to(_flat(at + side * sign_value * GatewaySites.PIER_OFFSET)) < GATEWAY_PIER + reach:
				return false
	return true
