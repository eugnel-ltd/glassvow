extends RefCounted
## #621: a return to the map reuses the act's decoded catalogue, the canonical
## input and the scenery binding, and draws exactly what a fresh bind draws.
## Only one act is kept, and nothing a screen does can edit what it shares.
## The painted landscape (Acts II–IV) reuses its baked road and ledges; Act I's
## journey land (#660) is itself kept, so a return draws the land already built.

static func run(fails: Array[String]) -> void:
	_one_catalogue_per_act(fails)
	_rebind_leaves_the_shared_catalogue_whole(fails)
	_return_reuses_the_binding(fails)
	_journey_return_reuses_the_land(fails)


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


## Act II, a painted act: Act I draws the journey land, which has no painted
## road (`_journey_return_reuses_the_land`).
static func _return_reuses_the_binding(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "run-map-open-cache")
	run.act = 1
	var world_map: WorldMap = WorldMap.for_run(run, content)
	# The first screen binds from nothing, as the first open of a run does.
	MapScene._bound_key = ""
	MapScene._bound = {}
	var fresh: WorldMapScreen = _open(world_map, content, run)
	var again: WorldMapScreen = _open(world_map, content, run)
	var screens: Array[WorldMapScreen] = [fresh, again]
	_check(fails, fresh.layout_result() != null and again.layout_result() != null,
		"both screens bind")
	_check(fails, fresh._map_scene.journey_landscape() == null
			and again._map_scene.journey_landscape() == null,
		"Act II draws the painted landscape")
	if fresh.layout_result() == null or again.layout_result() == null \
			or fresh._map_scene.journey_landscape() != null:
		_close(screens)
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
	var road: Mesh = _road(second_land)
	_check(fails, road != null and road == _road(first_land),
		"a return reuses the road geometry instead of rebuilding it")
	_check(fails, second_land.ledges == first_land.ledges,
		"a return keeps the seeded ledges")
	# Another run's salt is another binding.
	var other_run: RunState = RunState.new_run(content, 1, "run-map-open-cache-other")
	other_run.act = 1
	var other: WorldMapScreen = _open(WorldMap.for_run(other_run, content), content, other_run)
	screens.append(other)
	var other_road: Mesh = _road(other._map_scene._landscape)
	_check(fails, other.layout_digest() != fresh.layout_digest()
			and other_road != null and other_road != road,
		"another run binds and builds its own landscape")
	_close(screens)


## Act I: a return binds the same layout and scenery and draws the journey land
## the first screen built. Leaving the map frees the screen but only detaches
## its land, which is kept for the act (`MapScene._journey_kept`); the next
## screen of that layout, catalogue and salt draws it instead of building
## another. Another run's salt builds its own. The title's warm land, its
## adoption and a screen replaced while it still draws the land are
## test_map_title_road.gd.
static func _journey_return_reuses_the_land(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 717, "run-map-open-cache")
	var world_map: WorldMap = WorldMap.for_run(run, content)
	MapScene._bound_key = ""
	MapScene._bound = {}
	MapScene.release_kept_journey()
	var fresh: WorldMapScreen = _open(world_map, content, run)
	var land: MapJourneyLandscape = fresh._map_scene.journey_landscape()
	_check(fails, fresh.layout_result() != null and land != null and land.is_built()
			and land.failure.is_empty(),
		"Act I binds and draws the journey land")
	if fresh.layout_result() == null or land == null or not land.is_built():
		_close([fresh])
		MapScene.release_kept_journey()
		return
	var layout: String = fresh.layout_digest()
	var input: String = fresh.layout_input_digest()
	var binding: Dictionary = fresh.layout_diagnostics()["live_binding"]
	var terrain: Node = land.terrain
	_close([fresh])
	_check(fails, is_instance_valid(land) and land.get_parent() == null
			and MapScene._journey_kept == land,
		"leaving the map keeps its journey land, off the tree")
	var again: WorldMapScreen = _open(world_map, content, run)
	var screens: Array[WorldMapScreen] = [again]
	_check(fails, again.layout_digest() == layout and again.layout_input_digest() == input,
		"a return binds the same layout and scenery")
	var again_binding: Dictionary = again.layout_diagnostics()["live_binding"]
	_check(fails, again_binding == binding, "a return reports the same scenery decisions")
	_check(fails, again._map_scene.journey_landscape() == land and is_instance_valid(land)
			and land.terrain == terrain and land.is_built() and not again.landscape_pending(),
		"a return draws the land the first screen built, without building another")
	var other_run: RunState = RunState.new_run(content, 1, "run-map-open-cache-other")
	var other: WorldMapScreen = _open(WorldMap.for_run(other_run, content), content, other_run)
	screens.append(other)
	var other_land: MapJourneyLandscape = other._map_scene.journey_landscape()
	_check(fails, other.layout_digest() != layout and other_land != null
			and other_land.is_built() and other_land != land,
		"another run binds and builds its own journey land")
	_close(screens)
	MapScene.release_kept_journey()


## A map screen for `run`'s act on the pad shape, bound as a map open binds it.
static func _open(world_map: WorldMap, content: ContentDB, run: RunState) -> WorldMapScreen:
	var screen: WorldMapScreen = WorldMapScreen.new(world_map, content, &"pad-landscape", run.act)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.refresh(run)
	return screen


static func _close(screens: Array[WorldMapScreen]) -> void:
	for screen: WorldMapScreen in screens:
		screen.get_parent().remove_child(screen)
		screen.free()


## The painted land's bridge-masonry mesh, the last of the road's baked meshes.
static func _road(land: MapLandscape) -> Mesh:
	var node: MeshInstance3D = land.get_node_or_null("Bridge masonry") as MeshInstance3D
	return node.mesh if node != null else null


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
