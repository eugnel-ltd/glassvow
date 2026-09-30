extends RefCounted
## #621: a return to the map reuses the act's decoded catalogue, the canonical
## input and the scenery binding, and draws exactly what a fresh bind draws.
## Only one act is kept, and nothing a screen does can edit what it shares.

static func run(fails: Array[String]) -> void:
	_one_catalogue_per_act(fails)
	_rebind_leaves_the_shared_catalogue_whole(fails)
	_return_reuses_the_binding(fails)


static func _one_catalogue_per_act(fails: Array[String]) -> void:
	var first: MapLandscapeAssets = MapLandscapeAssets.for_act(1)
	_check(fails, first.failure.is_empty() and first.act == 1, "Act II resolves whole")
	_check(fails, MapLandscapeAssets.for_act(1) == first,
		"a second request for one act decodes nothing")
	var released: WeakRef = weakref(first)
	first = null
	var other: MapLandscapeAssets = MapLandscapeAssets.for_act(2)
	_check(fails, other.act == 2 and released.get_ref() == null,
		"moving to another act releases the previous act's catalogue")
	_check(fails, MapLandscapeAssets.for_act(2) == other, "the new act is the one kept")


static func _rebind_leaves_the_shared_catalogue_whole(fails: Array[String]) -> void:
	var shared: MapLandscapeAssets = MapLandscapeAssets.for_act(0)
	var profiles: Dictionary = shared.profiles.duplicate(true)
	var scene: MapScene = MapScene.new(0)
	_check(fails, scene.active_asset_resources() == shared.resources,
		"a scene binds the act's shared catalogue")
	# A salt change rebinds the same act, which drops the scene's profiles.
	scene.set_scatter_salt(4242)
	scene.set_act(0)
	_check(fails, MapLandscapeAssets.for_act(0) == shared and shared.profiles == profiles,
		"rebinding a scene leaves the shared profiles whole")
	_check(fails, not scene.layout_asset_bundle().is_empty(), "the rebound scene has its profiles")
	scene.free()


static func _return_reuses_the_binding(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "run-map-open-cache")
	var world_map: WorldMap = WorldMap.for_run(run, content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	# The first screen binds from nothing, as the first open of a run does.
	MapScene._bound_key = ""
	MapScene._bound = {}
	var fresh: WorldMapScreen = WorldMapScreen.new(world_map, content, &"pad-landscape", run.act)
	tree.root.add_child(fresh)
	fresh.refresh(run)
	var again: WorldMapScreen = WorldMapScreen.new(world_map, content, &"pad-landscape", run.act)
	tree.root.add_child(again)
	again.refresh(run)
	_check(fails, fresh.layout_result() != null and again.layout_result() != null,
		"both screens bind")
	if fresh.layout_result() == null or again.layout_result() == null:
		return
	_check(fails, again.layout_digest() == fresh.layout_digest()
			and again.layout_input_digest() == fresh.layout_input_digest(),
		"a return binds the same layout and scenery")
	var fresh_binding: Dictionary = fresh.layout_diagnostics()["live_binding"]
	var again_binding: Dictionary = again.layout_diagnostics()["live_binding"]
	_check(fails, again_binding == fresh_binding, "a return reports the same scenery decisions")
	var first_land: MapLandscape = fresh._map_scene._landscape
	var second_land: MapLandscape = again._map_scene._landscape
	_check(fails, _placement(second_land) == _placement(first_land),
		"a return places the same landscape nodes in the same order")
	var road: MeshInstance3D = second_land.get_node("Bridge masonry") as MeshInstance3D
	_check(fails, road.mesh == (first_land.get_node("Bridge masonry") as MeshInstance3D).mesh,
		"a return reuses the road geometry instead of rebuilding it")
	_check(fails, second_land.ledges == first_land.ledges,
		"a return keeps the seeded ledges")
	# Another run's salt is another binding.
	var other_run: RunState = RunState.new_run(content, 1, "run-map-open-cache-other")
	var other: WorldMapScreen = WorldMapScreen.new(WorldMap.for_run(other_run, content),
		content, &"pad-landscape", other_run.act)
	tree.root.add_child(other)
	other.refresh(other_run)
	var other_road: MeshInstance3D = other._map_scene._landscape.get_node(
		"Bridge masonry") as MeshInstance3D
	_check(fails, other.layout_digest() != fresh.layout_digest()
			and other_road.mesh != road.mesh,
		"another run binds and builds its own landscape")
	for screen: WorldMapScreen in [fresh, again, other]:
		tree.root.remove_child(screen)
		screen.free()


## Every landscape child by name and class, with its transform and mesh bounds or
## its instance transforms.
static func _placement(land: MapLandscape) -> Array:
	var out: Array = []
	for child: Node in land.get_children():
		var row: Array = [String(child.name).get_slice("@", 0), child.get_class()]
		if child is MeshInstance3D:
			var mesh: Mesh = (child as MeshInstance3D).mesh
			row.append_array([(child as MeshInstance3D).transform,
				mesh.get_aabb() if mesh != null else AABB()])
		elif child is MultiMeshInstance3D:
			var multi: MultiMesh = (child as MultiMeshInstance3D).multimesh
			row.append(multi.instance_count)
			for i: int in range(multi.instance_count):
				row.append(multi.get_instance_transform(i))
		out.append(row)
	return out


static func _check(fails: Array[String], ok: bool, label: String) -> void:
	if not ok:
		fails.append("map open cache: " + label)
