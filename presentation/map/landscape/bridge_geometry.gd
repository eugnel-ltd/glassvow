extends RefCounted
## Decks continue over conformed approaches instead of stopping at a threshold.
const Meshes = preload("res://presentation/map/landscape/mesh_tools.gd")
const Paths = preload("res://presentation/map/landscape/road_paths.gd")
const Surfaces = preload("res://presentation/map/landscape/bridge_surfaces.gd")
## The parapets' stone, lighter than the masonry below the deck so their
## coping catches the key (R3.5; a lane pick, owner re-pick open).
const PARAPET_TINT: Vector3 = Vector3(.095,.086,.083)

static func build(parent: Node3D, lines: Array[PackedVector3Array], elevated: Callable, paint: ShaderMaterial) -> int:
	var _t0: int = Time.get_ticks_msec()
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var masonry: SurfaceTool = SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spans: Array[Dictionary] = []
	var chains: Array[Dictionary] = []
	for line: PackedVector3Array in lines:
		var points: PackedVector3Array = Paths.sample(line)
		var distances: PackedFloat32Array = []
		var lengths: PackedFloat32Array = [0]
		distances.resize(points.size())
		distances.fill(10000)
		for i: int in range(points.size()):
			if i>0:
				lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
			if elevated.call(points[i]):
				distances[i] = 0
			elif i>0:
				distances[i] = minf(distances[i],distances[i-1]+lengths[i]-lengths[i-1])
		for i: int in range(points.size()-2,-1,-1):
			distances[i] = minf(distances[i],distances[i+1]+lengths[i+1]-lengths[i])
		var weights: PackedFloat32Array = []
		for distance: float in distances:
			weights.append(1.0-smoothstep(0,2.2,distance))
		var rises: PackedFloat32Array = weights.duplicate()
		# The bank transition also follows adjoining earth roads. Otherwise a
		# deck ending on a graph junction leaves an unsupported side entrance.
		for i: int in range(points.size()):
			var p: Vector3 = points[i]
			var bank: float = parent.stream_distance(p.x,p.z)
			weights[i] = maxf(weights[i],1.0-smoothstep(3.8,5.8,bank))
		# A bridgehead is one shared landing across every incident road. Its
		# paved approach reaches into each branch, so none enters a raised side.
		for i: int in range(points.size()):
			for pad: Vector2 in parent.landform.abutments:
				var distance: float = Vector2(points[i].x,points[i].z).distance_to(pad)
				weights[i] = maxf(weights[i],1.0-smoothstep(.5,3.5,distance))
		for i: int in range(points.size()):
			points[i].y = parent.bridge_height(points[i].x,points[i].z)
		var soffit: PackedFloat32Array = preload("res://presentation/map/landscape/bridge_structure.gd").profile(parent,points,weights)
		for i: int in range(points.size()-1):
			if maxf(weights[i],weights[i+1])<.001:
				continue
			# A small shared landing leaves room to walk around each waystone.
			# Burial-only remnants already sit within usable ground; widening
			# those almost-invisible spans would create stray lips on earth roads.
			var half_a: float = .8+.5*weights[i]*(1-smoothstep(.5,1.7,minf(lengths[i],lengths[-1]-lengths[i])))
			var half_b: float = .8+.5*weights[i+1]*(1-smoothstep(.5,1.7,minf(lengths[i+1],lengths[-1]-lengths[i+1])))
			spans.append({"a":points[i],"b":points[i+1],"wa":weights[i],"wb":weights[i+1],"raise_a":rises[i],"raise_b":rises[i+1],"half_a":half_a,"half_b":half_b,"s":lengths[i],"bottom_a":soffit[i],"bottom_b":soffit[i+1]})
		chains.append({"points":points,"lengths":lengths,"weights":weights})
	# The decks' sampled centrelines and how raised each point is, for what hangs
	# from the parapets (the kit's banners).
	parent.set_meta("bridge_chains", chains)
	if spans.is_empty():
		return 0
	parent.build_timings_ms["roads_chains"] = Time.get_ticks_msec() - _t0
	var surface: Surfaces = Surfaces.new()
	surface.setup(spans,Callable(parent,"surface_height"),Callable(parent,"bridge_height"))
	parent.build_timings_ms["roads_setup"] = Time.get_ticks_msec() - _t0
	surface.append(top,masonry)
	parent.build_timings_ms["roads_append"] = Time.get_ticks_msec() - _t0
	parent.set_meta("bridge_field",surface)
	# _stonework is appended to its own mesh so imported box formats cannot reset the barrel.
	var kerbs: SurfaceTool = SurfaceTool.new()
	kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stonework(kerbs,chains,surface,lines)
	parent.build_timings_ms["roads_stonework"] = Time.get_ticks_msec() - _t0
	var coursed: ShaderMaterial = ShaderMaterial.new()
	coursed.shader = preload("res://presentation/map/landscape/bridge_stone.gdshader")
	coursed.set_shader_parameter("tint",PARAPET_TINT)
	Meshes.node(parent,Meshes.committed(kerbs.commit()),coursed,"Bridge parapet stones")
	var deck_paint: ShaderMaterial = preload("res://presentation/map/landscape/terrain_paint.gd").deck_variant(paint)
	Meshes.node(parent,Meshes.finish(top),deck_paint,"Continuous bridge decks")
	var stone: ShaderMaterial = ShaderMaterial.new()
	stone.shader = preload("res://presentation/map/landscape/bridge_stone.gdshader")
	Meshes.node(parent,Meshes.finish(masonry),stone,"Joined bridge masonry")
	return spans.size()

## The parapets (R3.5): a continuous wall along each raised side, crenellated
## along its top as the owner's target's bridges are, in the masonry's own
## coursed stone. Each run overlaps the next a little so a bend leaves no gap,
## and every face is flat: the old stones' shared normals rounded them into
## pale pills under the key. Merlons alternate with crenels at `MERLON` metres.
const PARAPET_OFFSET: float = .755
const PARAPET_THICK: float = .16
const PARAPET_HEIGHT: float = .22
const MERLON: float = .43
const MERLON_SIZE: Vector3 = Vector3(.18,.14,.24)

static func _stonework(masonry: SurfaceTool, chains: Array[Dictionary], surface: Surfaces,
		lines: Array[PackedVector3Array]) -> void:
	for chain: Dictionary in chains:
		var points: PackedVector3Array = chain["points"]
		var lengths: PackedFloat32Array = chain["lengths"]
		var weights: PackedFloat32Array = chain["weights"]
		var start: int = -1
		var merlon: bool = true
		for i: int in range(points.size()-1):
			var middle: Vector3 = (points[i]+points[i+1])*.5
			var walled: bool = maxf(weights[i],weights[i+1])>=.72
			for line: PackedVector3Array in lines:
				if minf(Vector2(middle.x,middle.z).distance_to(Vector2(line[0].x,line[0].z)),Vector2(middle.x,middle.z).distance_to(Vector2(line[-1].x,line[-1].z)))<1.7:
					walled = false
			if not walled:
				start = -1
				continue
			if start<0:
				start = i
			# One wall piece a merlon's length, so a straight run is a few long
			# boxes rather than one per centreline sample.
			if lengths[i+1]-lengths[start]>=MERLON or i==points.size()-2:
				_piece(masonry,points[start],points[i+1],surface,merlon)
				merlon = not merlon
				start = i+1


## The parapet from `p` to `q` on both sides of the deck, where that side is the
## deck's edge, with a merlon on top when `merlon`.
static func _piece(masonry: SurfaceTool, p: Vector3, q: Vector3, surface: Surfaces, merlon: bool) -> void:
	var middle: Vector3 = (p+q)*.5
	var forward: Vector3 = (q-p).normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var run: float = Vector2(q.x-p.x,q.z-p.z).length()
	var basis: Basis = Basis(Vector3.UP,atan2(forward.x,forward.z))
	basis = basis*Basis(Vector3.RIGHT,-atan2(q.y-p.y,run))
	for sign_value: float in [-1,1]:
		var at: Vector3 = middle+side*PARAPET_OFFSET*sign_value
		var outside: Vector3 = at+side*.22*sign_value
		if Surfaces._number(surface.field(Vector2(outside.x,outside.z)),"distance")<0:
			continue
		at.y = Surfaces._number(surface.field(Vector2(at.x,at.z)),"height")+PARAPET_HEIGHT*.5-.02
		_box(masonry,Transform3D(basis.scaled_local(Vector3(PARAPET_THICK,PARAPET_HEIGHT+.04,run+.06)),at))
		if merlon:
			var top: Vector3 = at+basis.y.normalized()*(PARAPET_HEIGHT*.5+MERLON_SIZE.y*.5-.02)
			_box(masonry,Transform3D(basis.scaled_local(MERLON_SIZE),top))


## A unit cube's faces under `pose`, each with its own flat normal; not its
## underside, which stands on the deck or the wall and is never seen.
static func _box(surface: SurfaceTool, pose: Transform3D) -> void:
	for axis: int in range(3):
		for sign_value: float in [-1.0,1.0]:
			if axis==1 and sign_value<0:
				continue
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = sign_value
			var u: Vector3 = Vector3.ZERO
			u[(axis+1)%3] = 1.0
			var v: Vector3 = normal.cross(u)
			var corners: Array[Vector3] = []
			for c: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				corners.append(pose*((normal+u*c.x+v*c.y)*.5))
			var facing: Vector3 = (pose.basis*normal).normalized()
			surface.set_normal(facing)
			for k: int in [0,2,1,0,3,2]:
				surface.add_vertex(corners[k])
