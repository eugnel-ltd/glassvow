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
# Conservative circles enclosing the exported X/Z bounds at every yaw.
const PROFILES: Dictionary = {
	"conifer": Vector2(2.50, 6.40),
	"conifer-wind": Vector2(2.70, 5.50),
	"conifer-snag": Vector2(2.40, 5.30),
	"ash-bramble": Vector2(2.10, .90),
	"ash-fern": Vector2(1.30, .60),
	"slate-shard": Vector2(1.20, 2.20),
	"slate-scree": Vector2(2.20, .50),
	"conifer-spire": Vector2(1.80, 6.40),
	"ash-heath": Vector2(2.1, 1.05),
	"slate-ridge": Vector2(2.25, 1.10),
	"ash-copse": Vector2(1.65, 1.30),
	"slate-bank": Vector2(1.90, 1.70),
	"memorial": Vector2(0.55, 1.95),
	"amber-arch": Vector2(2.65, 5.50),
	"lantern-post": Vector2(0.35, 1.70),
	"bridge-banner": Vector2(0.40, 1.60),
}

## Where each lamp-carrying kind holds its flame (the lantern glass's centre),
## in the model's space; `lantern-post` follows `living_kit.py`'s
## `LANTERN_GLASS_Z`, the gateway its two hanging lamps.
const LAMP_ANCHORS: Dictionary = {
	"amber-arch": [Vector3(-2.30, 2.21, 0.46), Vector3(2.30, 2.21, 0.46)],
	"lantern-post": [Vector3(0.0, 1.38, 0.0)],
}
## Lanterns along the roads: about one stone post per `LANTERN_SPACING` metres
## of road (one on any road of `LANTERN_SHORTEST` or more), spread evenly along
## it, `LANTERN_OFFSET` off the centreline on alternating sides, and never two
## within `LANTERN_GAP` (junctions and parallel roads share).
const LANTERN_SPACING: float = 9.0
const LANTERN_SHORTEST: float = 4.0
const LANTERN_OFFSET: float = 1.3
const LANTERN_GAP: float = 6.0
## Banners on the bridges: one every `BANNER_SPACING` metres of deck raised
## over the river, hung clear of the parapet stones and the masonry below them
## (`BANNER_OFFSET` off the deck's centreline), on the side facing the journey
## camera (whose yaw never turns): the far side's would hang behind the deck.
const BANNER_SPACING: float = 3.5
const BANNER_OFFSET: float = 1.0
const BANNER_HEIGHT: float = 0.30

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
## is ready, and the woodland's impostor atlas with them (`ImpostorAtlas`:
## ready, or unable to load; the foliage kinds it draws load no scene). Every
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
	var done: bool = _hold_next(wait) and ImpostorAtlas.prepare_step(wait)
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


## The kinds whose scenes the kit holds: all but the foliage the woodland
## draws as impostors.
static func _scene_kinds() -> Array:
	return PROFILES.keys().filter(func(kind: String) -> bool:
		return not ImpostorAtlas.KIT_KINDS.has(kind))


static func _request(kind: String) -> void:
	var path: String = _path(kind)
	if not _requested.has(path):
		_requested[path] = true
		ResourceLoader.load_threaded_request(path, "PackedScene", false, _cache_mode(kind))


static func _cache_mode(kind: String) -> ResourceLoader.CacheMode:
	return ResourceLoader.CACHE_MODE_REUSE if kind == ARCH else ResourceLoader.CACHE_MODE_IGNORE


static func _path(kind: String) -> String:
	return "res://assets/art/map-journey/%s.glb" % kind


func build(surface: Terrain, points: PackedVector3Array, grey: bool, heroes: Dictionary = {}, cache: Resource = null) -> void:
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
		replay_timings["batches"]=(Time.get_ticks_usec()-replay_start)/1000.0
		build_complete = true
		return
	# The gateway arch is dressing: a layout with no straight dry leg for it is
	# drawn without one rather than failing the map.
	_landmark(grey)
	for role: String in heroes:
		var hero: Dictionary = heroes[role]
		var kind: String = hero["asset_id"]
		if not PROFILES.has(kind):
			failure = "Unknown woodland hero: "+kind
			return
		var transform_data: Dictionary = hero["transform"]
		var origin: Array = transform_data["origin"]
		var at: Vector3 = Meshes.v3(origin)
		at.y = terrain.surface_height(at.x,at.z)
		_place(kind,at,float(str(transform_data["scale"][0])),float(str(transform_data["yaw_radians"])),grey)
		if not failure.is_empty(): return
		placed_nodes[-1].set_meta("hero_role",role)
	_lanterns(grey)
	planting_bounds = Rect2(terrain.bounds.position+Vector2(5,7),terrain.bounds.size-Vector2(10,14))
	var planting: Rect2 = planting_bounds
	var area_ratio: float = planting.get_area()/(86.0*46.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7401
	for family: String in ["conifer", "slate-bank", "ash-copse", "memorial"]:
		for i: int in range(ceili(1000*area_ratio)):
			# Establish the six substantial forms before any accent can occupy a gap.
			var kind: String = family
			if i % 2 == 1:
				kind = {"conifer":"conifer-spire", "slate-bank":"slate-ridge", "ash-copse":"ash-heath"}.get(family, family)
			var p: Vector3 = Vector3(rng.randf_range(planting.position.x, planting.end.x), 0, rng.randf_range(planting.position.y, planting.end.y))
			var scale_value: float = rng.randf_range(0.65, 1.05)
			if kind.begins_with("conifer"):
				scale_value = rng.randf_range(0.95, 1.35)
			elif kind.begins_with("ash-"):
				scale_value = rng.randf_range(0.85, 1.25)
			elif kind.begins_with("slate-"):
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
	_undergrowth(grey)
	_verges(grey)
	_accents(grey)
	_banners(grey)
	contacts.finish()
	if static_scenery!=null: static_scenery.call("finish")
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


## Banners hung from the bridge parapets over the river (R2 motion). They are
## part of the bridge, not the ground, so they skip the ground clearance, and
## go in last: the undergrowth and verges draw from every placement before
## them, so placing banners earlier would move the woodland. They keep clear of
## the roads' ends, where waystones and junctions stand.
func _banners(grey: bool) -> void:
	var chains: Array = terrain.get_meta("bridge_chains", [])
	for chain: Dictionary in chains:
		var points: PackedVector3Array = chain["points"]
		var lengths: PackedFloat32Array = chain["lengths"]
		var weights: PackedFloat32Array = chain["weights"]
		var next: float = 0.0
		for i: int in range(points.size() - 1):
			if lengths[i + 1] < next:
				continue
			var p: Vector3 = points[i]
			var q: Vector3 = points[i + 1]
			var middle: Vector3 = (p + q) * 0.5
			if minf(weights[i], weights[i + 1]) < 0.95 \
					or terrain.stream_distance(middle.x, middle.z) > 5.0 \
					or terrain.lines.any(func(line: PackedVector3Array) -> bool:
						return _flat(middle).distance_to(_flat(line[0])) < 2.0 \
							or _flat(middle).distance_to(_flat(line[-1])) < 2.0):
				continue
			var forward: Vector3 = (q - p).normalized()
			var across: Vector3 = forward.cross(Vector3.UP).normalized()
			if across.z < 0.0:
				across = -across
			if across.z < 0.5:
				continue
			var at: Vector3 = middle + across * BANNER_OFFSET + Vector3.UP * BANNER_HEIGHT
			_place("bridge-banner", at, 1.0, atan2(across.x, across.z), grey)
			next = lengths[i + 1] + BANNER_SPACING


static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## Every lamp's flame centre on the land: the gateway's two and each post's.
func lamp_anchors() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for item: Dictionary in placed:
		var kind: String = item["kind"]
		if not LAMP_ANCHORS.has(kind):
			continue
		var scale_value: float = float(str(item["scale"]))
		var at: Vector3 = item["position"]
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, float(str(item["yaw"]))).scaled(Vector3.ONE * scale_value), at)
		for local: Vector3 in LAMP_ANCHORS[kind]:
			out.append(pose * local)
	return out


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
	_companion("slate-bank", at + Vector3(4, 0, 1), 1.15, 0.5, grey)
	_companion("slate-bank", at + Vector3(6, 0, -6), 1.20, -0.35, grey)
	_companion("slate-ridge", at + Vector3(-7, 0, -7), 1.10, 0.4, grey)
	_companion("conifer", at + Vector3(-5, 0, -7), 1.2, 0.7, grey)
	_companion("conifer-spire", at + Vector3(1, 0, -8), 1.15, -0.4, grey)
	_companion("conifer", at + Vector3(6, 0, -5), 1.05, 0.3, grey)

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
		if not family.begins_with("conifer") and not family.begins_with("slate"):
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
	var limits: Dictionary = {"ash-fern":22,"ash-bramble":10,"slate-scree":7,"slate-shard":3,"conifer-wind":3,"conifer-snag":2}
	var counts: Dictionary = {}
	for group: Dictionary in groups:
		var family: String = str(group["kind"])
		if not family.begins_with("conifer") and not family.begins_with("slate"):
			continue
		var centre: Vector3 = group["position"]
		for kind: String in limits:
			var count: int = int(str(counts.get(kind,0)))
			if count >= int(str(limits[kind])):
				continue
			if kind.begins_with("conifer") and centre.distance_to(hero)<11:
				continue
			if kind.begins_with("slate") and not family.begins_with("slate"):
				continue
			for attempt: int in range(24):
				var angle: float = rng.randf_range(-PI,PI)
				var radius: float = rng.randf_range(1.4,3.6)
				if kind.begins_with("slate"):
					radius = rng.randf_range(3.0,5.5)
				if kind.begins_with("conifer"):
					radius = rng.randf_range(2.4,4.4)
				var p: Vector3 = centre+Vector3(cos(angle),0,sin(angle))*radius
				p.y = terrain.surface_height(p.x,p.z)
				var scale_value: float = rng.randf_range(.65,.85)
				if kind.begins_with("conifer"):
					scale_value = rng.randf_range(.90,1.05)
				var profile: Vector2 = PROFILES[kind]*scale_value
				if not planting_bounds.has_point(Vector2(p.x,p.z)) or not terrain.is_dry(p) or not clear(p,profile.x,profile.y,kind):
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

func _clear(p: Vector3, radius: float, height: float, kind: String) -> bool:
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
		elif (kind.begins_with("ash-") and str(placement["kind"]).begins_with("slate")) or (kind.begins_with("slate") and str(placement["kind"]).begins_with("ash-")):
			separation *= 0.50
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
