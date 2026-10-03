extends Node3D
## Native land and roads derived from the compiled route topology.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Paint = preload("res://presentation/map/landscape/terrain_paint.gd")
const River = preload("res://presentation/map/landscape/river.gd")
var bounds: Rect2 = Rect2(-48,-30,96,60)
var river_half_length: float = 35.0
var restored: bool = false
var failure: String = ""
var lines: Array[PackedVector3Array] = []
var source_edges: Dictionary = {}
var anchors: Dictionary = {}
var road_segments: int = 0
var bridge_spans: int = 0
var greybox: bool = true
var height_cache: Dictionary = {}
var build_timings_ms: Dictionary = {}
## `distance_to_roads`: grid cell and the distance it answers exactly within.
const ROAD_CELL_M: float = 6.0
const ROAD_REACH_M: float = 6.0
var _segment_cells: Dictionary = {}
var _grid: PackedFloat32Array = PackedFloat32Array()
var _columns: int = 0
var _rows: int = 0
var _baked: Array = []
var _bake_lock: Mutex = Mutex.new()
var _heights_task: int = -1
var _heights_started: int = 0
var landform: RefCounted = preload("res://presentation/map/landscape/landform.gd").new()
const CELL: float = .5
const WATER: float = River.LEVEL

## The whole build on the calling thread: `prepare`, the heights, then `finish`.
func build(sample: Dictionary, grey: bool, extent: Rect2 = Rect2(-48,-30,96,60)) -> void:
	prepare(sample, grey, extent)
	start_heights()
	finish_heights()
	finish()


## Reads the source and fixes the landform; cheap, on the calling thread.
func prepare(sample: Dictionary, grey: bool, extent: Rect2 = Rect2(-48,-30,96,60)) -> void:
	var lo: Vector2 = (extent.position/CELL).floor()*CELL
	var hi: Vector2 = (extent.end/CELL).ceil()*CELL
	bounds = Rect2(lo,hi-lo)
	river_half_length = maxf(absf(lo.y),absf(hi.y))
	set_meta("world_bounds",bounds)
	greybox = grey
	source_edges = sample["edges"]
	anchors = sample["anchors"]
	for edge: Dictionary in source_edges.values():
		var points: PackedVector3Array = []
		for point: Array in edge["centerline"]:
			points.append(Meshes.v3(point))
		lines.append(points)
	var source_points: PackedVector3Array = []
	for raw: Array in anchors.values():
		source_points.append(Meshes.v3(raw))
	var gateway: Dictionary = preload("res://presentation/map/landscape/gateway_sites.gd").choose(self,source_points,false)
	if not gateway.is_empty():
		var at: Vector3 = gateway["position"]
		landform.terrace_centre = Vector2(at.x,at.z)
	var started: int = Time.get_ticks_msec()
	landform.setup(lines)
	build_timings_ms["landform"] = Time.get_ticks_msec()-started


## The land's meshes, roads, bridges and rivers. Touches only this node's own
## subtree, so it may run on a worker while the node is outside the tree.
func finish() -> void:
	var started: int = Time.get_ticks_msec()
	_land()
	build_timings_ms["ground"] = Time.get_ticks_msec()-started
	started = Time.get_ticks_msec()
	_roads()
	build_timings_ms["roads"] = Time.get_ticks_msec()-started
	started = Time.get_ticks_msec()
	for cut: float in MapRavine.CUTS:
		var river: River = River.new()
		river.cut = cut
		add_child(river)
		river.build(self)
	build_timings_ms["river"] = Time.get_ticks_msec()-started


## Distance from `p` to the nearest road centreline (XZ). Exact within
## `ROAD_REACH_M`; beyond it the answer is only "at least `ROAD_REACH_M`", which
## is all every caller asks (their thresholds are a few metres). Segments are
## found through a grid built once, so a query reads a few cells rather than
## every road.
func distance_to_roads(p: Vector3) -> float:
	if _segment_cells.is_empty():
		_index_roads()
	var q: Vector2 = Vector2(p.x, p.z)
	var best: float = ROAD_REACH_M
	var cx: int = floori(q.x / ROAD_CELL_M)
	var cz: int = floori(q.y / ROAD_CELL_M)
	for x: int in range(cx - 1, cx + 2):
		for z: int in range(cz - 1, cz + 2):
			var bucket: PackedVector4Array = _segment_cells.get(Vector2i(x, z), PackedVector4Array())
			for seg: Vector4 in bucket:
				var a: Vector2 = Vector2(seg.x, seg.y)
				var b: Vector2 = Vector2(seg.z, seg.w)
				best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return best


func _index_roads() -> void:
	_segment_cells[Vector2i(1 << 20, 1 << 20)] = PackedVector4Array()
	for line: PackedVector3Array in lines:
		for i: int in range(line.size() - 1):
			var seg: Vector4 = Vector4(line[i].x, line[i].z, line[i + 1].x, line[i + 1].z)
			var lo: Vector2 = Vector2(minf(seg.x, seg.z), minf(seg.y, seg.w))
			var hi: Vector2 = Vector2(maxf(seg.x, seg.z), maxf(seg.y, seg.w))
			for x: int in range(floori(lo.x / ROAD_CELL_M), floori(hi.x / ROAD_CELL_M) + 1):
				for z: int in range(floori(lo.y / ROAD_CELL_M), floori(hi.y / ROAD_CELL_M) + 1):
					var key: Vector2i = Vector2i(x, z)
					var bucket: PackedVector4Array = _segment_cells.get(key, PackedVector4Array())
					bucket.append(seg)
					_segment_cells[key] = bucket

func stream_distance(x: float, z: float) -> float:
	return River.distance(x, z)

func height_at(x: float, z: float) -> float:
	var fx: float = (x - bounds.position.x) / CELL
	var fz: float = (z - bounds.position.y) / CELL
	var ix: int = roundi(fx)
	var iz: int = roundi(fz)
	if not _grid.is_empty() and absf(fx - ix) < 0.0001 and absf(fz - iz) < 0.0001 \
			and ix >= 0 and iz >= 0 and ix < _columns and iz < _rows:
		return _grid[ix * _rows + iz]
	var key: Vector2 = Vector2(x,z)
	if height_cache.has(key):
		return height_cache[key]
	var result: float = landform.height(x,z)
	height_cache[key] = result
	return result


## Every land vertex's height, once, side by side on the worker pool: one
## column per task (`start_heights`, `finish_heights`). `landform.height` is
## pure over data `setup` fixed, so the columns share nothing but what they
## read. Later surface queries on the lattice read this grid instead of
## re-solving the landform.
## `parallel` spreads the columns over the worker pool; a caller that is
## itself a pool task bakes them in turn (it may not wait on the pool).
func start_heights(parallel: bool = true) -> void:
	_heights_started = Time.get_ticks_msec()
	_columns = int(bounds.size.x / CELL) + 1
	_rows = int(bounds.size.y / CELL) + 1
	_baked.clear()
	_baked.resize(_columns)
	if not parallel:
		for ix: int in range(_columns):
			_bake_column(ix)
		return
	_heights_task = WorkerThreadPool.add_group_task(_bake_column, _columns, -1, true,
		"journey land heights")


func heights_ready() -> bool:
	return _heights_task < 0 or WorkerThreadPool.is_group_task_completed(_heights_task)


## Joins the height columns into the grid (waiting for them if need be).
func finish_heights() -> void:
	if _heights_task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_heights_task)
		_heights_task = -1
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize(_columns * _rows)
	for ix: int in range(_columns):
		var column: PackedFloat32Array = _baked[ix]
		for iz: int in range(_rows):
			grid[ix * _rows + iz] = column[iz]
	_baked.clear()
	_grid = grid
	build_timings_ms["heights"] = Time.get_ticks_msec() - _heights_started


func _bake_column(ix: int) -> void:
	var column: PackedFloat32Array = PackedFloat32Array()
	column.resize(_rows)
	var x: float = bounds.position.x + ix * CELL
	for iz: int in range(_rows):
		column[iz] = landform.height(x, bounds.position.y + iz * CELL)
	_bake_lock.lock()
	_baked[ix] = column
	_bake_lock.unlock()

func surface_height(x: float, z: float) -> float:
	# Match the actual two triangles of each land cell, not the curved source
	# function between vertices. Asset contacts must use the rendered surface.
	var base_x: float = bounds.position.x + floorf((x - bounds.position.x) / CELL) * CELL
	var base_z: float = bounds.position.y + floorf((z - bounds.position.y) / CELL) * CELL
	var u: float = (x - base_x) / CELL
	var v: float = (z - base_z) / CELL
	var h0: float = height_at(base_x, base_z)
	var h2: float = height_at(base_x + CELL, base_z + CELL)
	if v >= u:
		return h0 * (1 - v) + h2 * u + height_at(base_x, base_z + CELL) * (v - u)
	return h0 * (1 - u) + h2 * v + height_at(base_x + CELL, base_z) * (u - v)

func bridge_height(x: float, z: float) -> float:
	var height: float = landform.upland(x,z)
	height += .18*(1.0-smoothstep(.4,3.8,stream_distance(x,z)))
	var crown: float = 0
	for cut: Dictionary in landform.cuts:
		var centre: Vector2 = cut["at"]
		crown = maxf(crown,.75*(1.0-smoothstep(1.2,4.0,centre.distance_to(Vector2(x,z)))))
	return height+crown

func route_height(p: Vector3) -> float:
	if is_elevated(p):
		# Upper roads span the uncut upland; their clearance comes from the
		# actual valley below, rather than a short, excessively steep ramp.
		var bank: float = stream_distance(p.x,p.z)
		var crown: float = .18*(1.0-smoothstep(.4,3.8,bank))
		return landform.upland(p.x,p.z)+crown
	return surface_height(p.x,p.z)

func present(p: Vector3, upper: bool = false) -> Vector3:
	var height: float = route_height(p)
	var approach: bool = false
	for pad: Vector2 in landform.abutments:
		approach = approach or Vector2(p.x,p.z).distance_to(pad)<3.5
	if has_meta("bridge_field") and (upper or p.y>.015 or approach or stream_distance(p.x,p.z)<5.8):
		var field: RefCounted = get_meta("bridge_field")
		var value: Dictionary = field.field(Vector2(p.x,p.z))
		var distance: float = value["distance"]
		if distance<0:
			height = value["height"]
	return Vector3(p.x,height,p.z)

func is_dry(p: Vector3) -> bool:
	return not River.contains(p.x,p.z,river_half_length) or surface_height(p.x,p.z)>WATER+.20

func is_elevated(p: Vector3) -> bool:
	return p.y > 0.015 or stream_distance(p.x, p.z) < 3.8

## The land in chunks of `CHUNK_CELLS` square, so the camera and the shadow
## pass cull what they cannot see. Normals come from the height grid, not from
## each chunk's own triangles, so no seam shows where two chunks meet. Every
## chunk shares one material; the first keeps the name other parts look up.
const CHUNK_CELLS: int = 32


func _land() -> void:
	var _land_started: int = Time.get_ticks_msec()
	var columns: int = int(bounds.size.x/CELL)+1
	var rows: int = int(bounds.size.y/CELL)+1
	var meshes: Array[ArrayMesh] = []
	for cx: int in range(0, columns - 1, CHUNK_CELLS):
		for cz: int in range(0, rows - 1, CHUNK_CELLS):
			meshes.append(_land_chunk(cx, cz, mini(cx + CHUNK_CELLS, columns - 1),
				mini(cz + CHUNK_CELLS, rows - 1), rows))
	build_timings_ms["ground_heights"] = Time.get_ticks_msec() - _land_started
	var paint_started: int = Time.get_ticks_msec()
	var mat: StandardMaterial3D = Meshes.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	var ground_mat: Material = mat if greybox else Paint.create(lines, is_elevated, bounds)
	build_timings_ms["ground_paint"] = Time.get_ticks_msec() - paint_started
	if ground_mat is ShaderMaterial:
		ground_mat.set_shader_parameter("river_cuts",Vector2(MapRavine.CUTS[0],MapRavine.CUTS[1]))
		ground_mat.set_shader_parameter("channel",River.CHANNEL)
	for i: int in range(meshes.size()):
		Meshes.node(self, meshes[i], ground_mat, "Quiet sculpted ground" if i == 0 else "Ground chunk %d" % i)


func _land_chunk(x0: int, z0: int, x1: int, z1: int, rows: int) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: int = z1 - z0 + 1
	for ix: int in range(x0, x1 + 1):
		for iz: int in range(z0, z1 + 1):
			var x: float = bounds.position.x+ix*CELL
			var z: float = bounds.position.y+iz*CELL
			var shade: float = .96+.05*sin(x*.22+z*.15)
			var colour: Color = Color("555663") if greybox else Color("302b30")
			var left: float = _grid[maxi(ix - 1, 0) * rows + iz]
			var right: float = _grid[mini(ix + 1, _columns - 1) * rows + iz]
			var near: float = _grid[ix * rows + maxi(iz - 1, 0)]
			var far: float = _grid[ix * rows + mini(iz + 1, rows - 1)]
			surface.set_color(colour*shade)
			surface.set_normal(Vector3(left - right, 2.0 * CELL, near - far).normalized())
			surface.add_vertex(Vector3(x,_grid[ix * rows + iz],z))
	for ix: int in range(x1 - x0):
		for iz: int in range(z1 - z0):
			var first: int = ix*span+iz
			for index: int in [first,first+span+1,first+1,first,first+span,first+span+1]:
				surface.add_index(index)
	return surface.commit()


func _roads() -> void:
	if not greybox:
		var ground: MeshInstance3D = get_node("Quiet sculpted ground") as MeshInstance3D
		bridge_spans = preload("res://presentation/map/landscape/bridge_geometry.gd").build(self,lines,is_elevated,ground.material_override as ShaderMaterial)
		for line: PackedVector3Array in lines:
			road_segments += line.size()-1
		return
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bridge: SurfaceTool = SurfaceTool.new()
	bridge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocks: BoxMesh = BoxMesh.new()
	blocks.size = Vector3.ONE
	for line: PackedVector3Array in lines:
		for i: int in range(line.size() - 1):
			road_segments += 1
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var side: Vector3 = (b - a).cross(Vector3.UP).normalized()
			var slices: int = maxi(1, ceili(a.distance_to(b) / 0.6))
			for step: int in range(slices):
				var p: Vector3 = a.lerp(b, float(step) / slices) + Vector3.UP * 0.022
				var q: Vector3 = a.lerp(b, float(step + 1) / slices) + Vector3.UP * 0.022
				var middle: Vector3 = (p + q) * 0.5
				var elevated: bool = is_elevated(middle)
				var half: float = 0.72
				if greybox or elevated:
					Meshes.triangle(top, p - side * half, q - side * half, q + side * half)
					Meshes.triangle(top, p - side * half, q + side * half, p + side * half)
				if elevated:
					bridge_spans += 1
					var basis: Basis = Basis(Vector3.UP, atan2((b - a).x, (b - a).z))
					var forward: Vector3 = (q - p).normalized()
					var right: Vector3 = Vector3.UP.cross(forward).normalized()
					var normal: Vector3 = forward.cross(right)
					var deck_basis: Basis = Basis(right, normal, forward)
					# Match the road slope and keep the whole top face below its ribbon.
					bridge.append_from(blocks, 0, Transform3D(deck_basis.scaled_local(Vector3(1.6, 0.4, p.distance_to(q) + 0.02)), middle - normal * 0.23))
					if step % 4 == 0:
						bridge.append_from(blocks, 0, Transform3D(basis.scaled_local(Vector3(1.25, 1.25, 0.45)), middle - Vector3.UP * 0.83))
					for sign_value: float in [-1, 1]:
						bridge.append_from(blocks, 0, Transform3D(deck_basis.scaled_local(Vector3(0.17, 0.26, p.distance_to(q))), middle + side * sign_value * 0.82 + normal * 0.12))
		for p: Vector3 in line:
			if not greybox and not is_elevated(p + Vector3.UP * 0.022):
				continue
			for i: int in range(16):
				var a: float = i * TAU / 16.0
				var b: float = (i + 1) * TAU / 16.0
				var centre: Vector3 = p + Vector3.UP * 0.023
				Meshes.triangle(top, centre, centre + Vector3(cos(a), 0, sin(a)) * 0.72,
					centre + Vector3(cos(b), 0, sin(b)) * 0.72)
	var mat: StandardMaterial3D = Meshes.material(Color("98938b") if greybox else Color("62584f"))
	Meshes.node(self, Meshes.finish(top), mat, "Compiled roads").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if bridge_spans > 0:
		Meshes.node(self, Meshes.finish(bridge), Meshes.material(Color("65616b")), "Supported bridge spans")
