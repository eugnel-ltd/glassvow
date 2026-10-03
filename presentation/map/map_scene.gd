class_name MapScene
extends Control
## Compiled 3D landscape, projected waystones and camera input for one act.
## The generator owns every node, route and landmark transform. Rest allows
## three render warm-up frames, then freezes until input or content changes.

const OVERSAMPLE: float = 1.0
## The stage's scale on a phone or tablet (`lean_profile`), where the journey
## land is fill-rate bound on the A12.
const LEAN_OVERSAMPLE: float = 0.75
const VP_MAX: int = 2048
## The stage's size while the scene is off the tree.
const PARKED_STAGE: Vector2i = Vector2i(2, 2)
const THRESHOLD_XZ: Vector2 = Vector2(-41.3, 6.5)
## Clears the fixed boss with the new landmark silhouettes at every zoom.
const TERMINUS_XZ: Vector2 = Vector2(43.0, 0.0)
var _scatter_salt: int = 0
var _salt_dirty: bool = false
const TAP_SLOP: float = 12.0
const FLING_DAMP: float = 0.06
const FLING_MAX: float = 48.0
## Box separation must beat a scenery rule's threshold by this much before the
## exact polygon test is skipped (`_scenery_rejection`).
const _BOX_SLACK_M: float = 0.01

signal surface_tapped(screen: Vector2)
## A wheel or pinch on the journey camera, which has two framings rather than
## zoom stops: `outward` asks for Whole act, inward for Journey.
signal journey_zoom_requested(outward: bool)
## The journey land finished building on its worker and is now drawn.
signal landscape_ready

var _stage: SubViewport
var _display: TextureRect
var _rig: MapCameraRig
var _key: DirectionalLight3D
var _world: Node3D
var _landscape_assets: MapLandscapeAssets
## Resolves an act's catalogue from its act index; the shared per-act copy in
## production. A field so a test can hand the binder a catalogue that resolves
## only in part, which no shipped act does.
var _landscape_source: Callable = MapLandscapeAssets.for_act
var _landscape: MapLandscape
## Build the journey land on the worker pool (the game) rather than on the
## calling thread (tests, tools and captures, which want a bound map at once).
static var journey_async: bool = false
## The last journey land built, kept across screens of the same act: a screen
## rebuilt for the same layout, catalogue and salt re-parents it for free.
static var _journey_kept: MapJourneyLandscape = null
static var _journey_kept_key: String = ""
var _journey_pending: bool = false
var _journey_key: String = ""
var _journey_data: Dictionary = {}
var _rest_tick: int = 0
var _node_states: Dictionary = {}
var _live: bool = false
var _settle_frames: int = 0
var _asset_profiles: MapAssetProfiles
var _active_profile_digest: String = ""
var _active_profiles: Dictionary = {}
var _terminus_id: String = ""
var _threshold_id: String = ""
## Flat list of segment endpoints (a, b, a, b, ...) in world XZ, handed down by
## the screen that owns the graph. MapScene stays instantiable without one.
var _road_segments: PackedVector3Array = PackedVector3Array()
var _waylights: Dictionary[String, MapWaylightTracer] = {}
var _layout_result: MapLayoutResult = null
var _layout_diagnostics: Dictionary = {}
var _layout_failure: Dictionary = {}
## The bound act INDEX, 0-based (Act I is 0); -1 until the first bind. `--act=` is
## the act NUMBER and never reaches here untranslated (`ActFlag`).
var _act: int = -1
var _dragging: bool = false
var _lock_input: bool = false
var _dragged: float = 0.0
var _fling: Vector2 = Vector2.ZERO
var _last_velocity: Vector2 = Vector2.ZERO
## The last binding this process made, shared with the next map screen that
## binds the same layout (#621): a return from a fight, event, shop or rest then
## skips the scenery filter and the landscape geometry. A binding is a pure
## function of the compiled result, the catalogue, the salt and the quality
## registry: the first three are the key, and the registry is compared in full.
## One entry: a new act or run replaces it.
## Everything in it is read-only once stored.
static var _bound_key: String = ""
static var _bound: Dictionary = {}


## `act_index` is the act to bind first. A screen that knows its act passes it,
## so it never decodes Act I's artwork only to swap it out.
func _init(act_index: int = 0) -> void:
	name = "MapScene"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = SubViewport.new()
	_stage.name = "MapStage"
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.size = Vector2i(64, 64)
	_stage.msaa_3d = Viewport.MSAA_DISABLED if lean_profile() else Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_stage)
	_world = Node3D.new()
	_world.name = "MapWorld"
	_stage.add_child(_world)
	_rig = MapCameraRig.new()
	_world.add_child(_rig)
	_add_key(_world)
	_add_environment(_world)
	_display = TextureRect.new()
	_display.name = "MapDisplay"
	_display.texture = _stage.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	# SubViewport child controls resolve full-rect anchors in backing pixels at a
	# HiDPI content scale. Keep the display in this Control's canvas and size it
	# from the resolved rect in `_fit` instead.
	_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)
	process_priority = -1
	set_process(true)
	set_act(act_index)


func _ready() -> void:
	_rig.get_camera().current = true
	_fit()
	resized.connect(_fit)


## Off the tree, as when its screen is kept between visits (`MapScreenKeep`),
## the stage draws nothing, so it hands back its render buffers (the colour,
## the 4x MSAA and the depth of a stage-sized view); `_fit` sizes them again
## as the scene returns.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_landscape()
	elif what == NOTIFICATION_EXIT_TREE:
		_stage.size = PARKED_STAGE
	elif what == NOTIFICATION_ENTER_TREE and is_node_ready():
		_fit()


func get_rig() -> MapCameraRig:
	return _rig


func get_stage() -> SubViewport:
	return _stage


func get_key() -> DirectionalLight3D:
	return _key


func get_act() -> int:
	return _act


## Cosmetic seed; the next bind rebuilds scenery without advancing game RNG.
func set_scatter_salt(salt: int) -> void:
	if salt == _scatter_salt:
		return
	_scatter_salt = salt
	_salt_dirty = true


func active_asset_paths() -> PackedStringArray:
	return _landscape_assets.paths.duplicate() if _landscape_assets != null else PackedStringArray()


func active_asset_resources() -> Array[Resource]:
	return _landscape_assets.resources.duplicate() if _landscape_assets != null else []


func asset_profile_digest() -> String:
	return _active_profile_digest


func layout_asset_bundle() -> Dictionary:
	if _active_profile_digest.is_empty() or _active_profiles.is_empty():
		return {}
	return {
		"profiles": _active_profiles.duplicate(true),
		"digest": _active_profile_digest,
	}


func layout_hero_contract() -> Dictionary:
	return hero_contract(_asset_profiles, _active_profiles, _terminus_id, _threshold_id)


## The heroes' anchors and protected zones for a catalogue's profiles: the
## act's gate at `TERMINUS_XZ` and, when the act has one, the Vigil at
## `THRESHOLD_XZ`. Static, so the journey prefetch builds the same contract
## without a scene.
static func hero_contract(registry: MapAssetProfiles, profiles: Dictionary,
		terminus_id: String, threshold_id: String) -> Dictionary:
	if terminus_id.is_empty() or not profiles.has(terminus_id):
		return {}
	var anchors: Dictionary = {}
	var zones: Dictionary = {}
	_add_hero_contract(registry, profiles, anchors, zones, "terminus", terminus_id,
		Vector3(TERMINUS_XZ.x, 0.0, TERMINUS_XZ.y))
	if not threshold_id.is_empty() and profiles.has(threshold_id):
		_add_hero_contract(registry, profiles, anchors, zones, "vigil", threshold_id,
			Vector3(THRESHOLD_XZ.x, 0.0, THRESHOLD_XZ.y))
	return {
		"schema_version": MapLayoutInput.HERO_ANCHOR_SCHEMA_VERSION,
		"anchors": MapLayoutCanonical.ordered_dictionary(anchors),
		"protected_zones": MapLayoutCanonical.ordered_dictionary(zones),
	}


func layout_digest() -> String:
	return "" if _layout_result == null else _layout_result.digest()


func layout_input_digest() -> String:
	return "" if _layout_result == null else str(
		_layout_result.to_dict().get("input_digest", ""))


func layout_diagnostics() -> Dictionary:
	return _layout_diagnostics.duplicate(true)


func layout_failure() -> Dictionary:
	return _layout_failure.duplicate(true)


func road_segments() -> PackedVector3Array:
	return _road_segments.duplicate()


func set_waylight_states(states: Dictionary) -> bool:
	var ids: Array[String] = MapLayoutCanonical.sorted_keys(_waylights)
	if MapLayoutCanonical.sorted_keys(states) != ids:
		return false
	for edge_id: String in ids:
		var tracer: MapWaylightTracer = _waylights[edge_id]
		var state: StringName = StringName(str(states[edge_id]))
		if not tracer.can_set_route_state(state):
			return false
	var changed: bool = false
	for edge_id: String in ids:
		var tracer: MapWaylightTracer = _waylights[edge_id]
		var state: StringName = StringName(str(states[edge_id]))
		changed = changed or tracer.route_state() != state
		if not tracer.set_route_state(state):
			return false
	if changed:
		_repaint()
	return true


static func _add_hero_contract(registry: MapAssetProfiles, profiles: Dictionary,
		anchors: Dictionary, zones: Dictionary, role: String,
		profile_id: String, position: Vector3) -> void:
	var profile: Dictionary = profiles[profile_id]
	var yaw_degrees: float = registry.fixed_yaw(profile)
	var scale: Vector3 = Vector3.ONE * registry.default_scale(profile)
	var polygon: PackedVector2Array = registry.transformed_footprint(
		profile, position, yaw_degrees, scale)
	if polygon.is_empty():
		return
	var plain: Array = []
	for point: Vector2 in polygon:
		plain.append([point.x, point.y])
	anchors[role] = {
		"asset_id": profile_id, "profile_id": profile_id,
		"position": _a3(position), "yaw_radians": deg_to_rad(yaw_degrees),
		"scale": _a3(scale),
	}
	zones["%s-zone" % role] = {"role": role, "polygon": plain}


## Bind this act's grade + ramp bands. `MapRegions.for_act` is the only
## palette source; content theme is not consulted. Re-arms freeze so the
## new look paints once. `act_index` is 0-based.
func set_act(act_index: int) -> void:
	var region: MapRegions = MapRegions.for_act(act_index)
	if region.act == _act and not _salt_dirty:
		return
	_act = region.act
	_deal_act(region)


## Bind an act's materials and geometry from the CURRENT salt.
##
## Split out of `set_act` because the salt changes without the act changing,
## and that is the ordinary case rather than an odd one: a second run also
## starts in Act I. `set_act` no-ops on an unchanged act, so on its own it
## would leave the new run standing in the previous run's wood.
func _deal_act(_region: MapRegions) -> void:
	var setting: WorldEnvironment = _world.get_node("MapEnvironment") as WorldEnvironment
	_painted_light(_key, setting.environment)
	_key.light_color = MapRegions.LAND_KEY[_act]
	setting.environment.ambient_light_color = MapRegions.LAND_AMBIENT[_act]
	if is_journey_act():
		MapJourneyLandscape.light(_key, setting.environment)
	else:
		_rig.leave_journey()
	if is_node_ready():
		_fit()
	_salt_dirty = false
	_bind_asset_geometry()
	_repaint()


func project_pins(nodes: Array[MapNode]) -> PackedVector2Array:
	return _projection().seats(nodes)


func project_anchors(anchors: PackedVector3Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var projection: MapPinProjection = _projection()
	for anchor: Vector3 in anchors:
		out.append(projection.to_screen(anchor))
	return out


func hit_test(screen: Vector2) -> Vector3:
	return _projection().hit_world(screen)


## Among pins whose projected seat is within `radius` px of `screen`, pick the
## one whose world-anchor is nearest the ground hit. Empty / miss → −1.
func pin_at(screen: Vector2, nodes: Array[MapNode], radius: float) -> int:
	var seats: PackedVector2Array = project_pins(nodes)
	var world: Vector3 = hit_test(screen)
	var best: int = -1
	var best_d: float = INF
	for i: int in range(nodes.size()):
		if i >= seats.size() or seats[i].distance_to(screen) > radius:
			continue
		var d: float = MapPinProjection.world_anchor(nodes[i]).distance_to(world)
		if d < best_d:
			best = i
			best_d = d
	return best


func anchor_at(screen: Vector2, anchors: PackedVector3Array, radius: float) -> int:
	var seats: PackedVector2Array = project_anchors(anchors)
	var world: Vector3 = hit_test(screen)
	var best: int = -1
	var best_d: float = INF
	for i: int in range(anchors.size()):
		if i >= seats.size() or seats[i].distance_to(screen) > radius:
			continue
		var distance: float = anchors[i].distance_to(world)
		if distance < best_d:
			best = i
			best_d = distance
	return best


func set_lock_input(on: bool) -> void:
	_lock_input = on
	if on:
		_dragging = false
		_fling = Vector2.ZERO


func is_moving() -> bool:
	return _dragging or _fling.length() > 0.02


func _projection() -> MapPinProjection:
	var view: Vector2i = _stage.size
	return MapPinProjection.new(_rig.get_camera(), size, Vector2(view))


func is_live() -> bool:
	return _live


func set_live(on: bool) -> void:
	_live = on
	_settle_frames = 0 if on else 3
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _repaint() -> void:
	if not _live:
		set_live(false)


func _gui_input(event: InputEvent) -> void:
	if _lock_input:
		accept_event()
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		if button.pressed and button.button_index in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var inward: int = -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if _rig.journey_mode:
				journey_zoom_requested.emit(inward > 0)
			else:
				_rig.nudge_zoom(inward)
			set_live(false)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_on_press(button.pressed, button.position)
			accept_event()
		return
	var pinch: InputEventMagnifyGesture = event as InputEventMagnifyGesture
	if pinch != null and _rig.journey_mode and absf(pinch.factor - 1.0) > 0.02:
		journey_zoom_requested.emit(pinch.factor < 1.0)
		accept_event()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		_on_drag(motion.relative, motion.velocity)
		accept_event()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_on_press(touch.pressed, touch.position)
		accept_event()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _dragging:
		_on_drag(drag.relative, drag.velocity)
		accept_event()


func _on_press(pressed: bool, screen: Vector2) -> void:
	if pressed:
		_dragging = true
		_dragged = 0.0
		_fling = Vector2.ZERO
		_last_velocity = Vector2.ZERO
		set_live(true)
		return
	var tap: bool = _dragged <= TAP_SLOP
	_dragging = false
	if tap:
		_fling = Vector2.ZERO
		set_live(false)
		surface_tapped.emit(screen)
		return
	_fling = _screen_to_world(_last_velocity).limit_length(FLING_MAX)
	if _fling.length() <= 0.02:
		_fling = Vector2.ZERO
		set_live(false)


func _on_drag(relative: Vector2, velocity: Vector2) -> void:
	_dragged += relative.length()
	_last_velocity = velocity
	_rig.pan_screen(relative, _view_height())


func _screen_to_world(delta_px: Vector2) -> Vector2:
	var k: float = _rig.get_camera().size / maxf(_view_height(), 1.0)
	var tilt: float = absf(_rig.get_camera().rotation.x)
	return Vector2(-delta_px.x * k, -delta_px.y * k / sin(tilt))


func _process(delta: float) -> void:
	if not _abandoned.is_empty():
		reap()
	if _journey_pending:
		_poll_journey()
	if not _live and _settle_frames > 0:
		_settle_frames -= 1
		if _settle_frames == 0:
			_stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif not _live and _settle_frames == 0:
		_rest_cadence()
	if _dragging or _lock_input:
		return
	if _fling.length() > 0.02:
		_rig.pan_world(_fling * delta)
		_fling *= pow(FLING_DAMP, delta)
		if not is_live():
			set_live(true)
		return
	if _fling != Vector2.ZERO:
		_fling = Vector2.ZERO
		set_live(false)


func _fit() -> void:
	_rig.get_camera().current = true
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_display.position = Vector2.ZERO
	_display.size = size
	var scale: float = LEAN_OVERSAMPLE if lean_profile() and is_journey_act() else OVERSAMPLE
	var next: Vector2i = Vector2i(
			mini(maxi(int(size.x * scale), 1), VP_MAX),
			mini(maxi(int(size.y * scale), 1), VP_MAX))
	if _stage.size == next:
		return
	_stage.size = next
	if not is_live():
		set_live(false)


func _view_height() -> float:
	return float(_stage.size.y) if _stage.size.y > 0 else maxf(size.y, 1.0)


func _add_key(world: Node3D) -> void:
	_key = DirectionalLight3D.new()
	_key.name = "MapKey"
	_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	world.add_child(_key)


func _add_environment(world: Node3D) -> void:
	var environment: Environment = Environment.new()
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "MapEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)
	_painted_light(_key, environment)


## The painted acts' key and environment. `_deal_act` re-applies it on every act
## change, so leaving Act I's journey light never leaves it behind.
static func _painted_light(key: DirectionalLight3D, environment: Environment) -> void:
	key.rotation_degrees = Vector3(-47, -34, 0)
	key.light_color = Color("f2e7cd")
	key.light_energy = 1.1
	key.light_specular = 0.5
	key.shadow_enabled = true
	key.shadow_opacity = 1.0
	key.directional_shadow_max_distance = 110
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11242c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("98b1c2")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("304852")
	environment.fog_light_energy = 0.45
	environment.fog_density = 0.0015


func _placement_footprint(candidate: Dictionary) -> PackedVector2Array:
	return _footprint_of(candidate, _asset_profiles, _active_profiles)


static func _footprint_of(candidate: Dictionary, registry: MapAssetProfiles,
		profiles: Dictionary) -> PackedVector2Array:
	var placement: Dictionary = candidate["placement"]
	var transform: Dictionary = placement["transform"]
	var profile_id: String = str(placement["profile_id"])
	if not profiles.has(profile_id):
		return PackedVector2Array()
	var profile: Dictionary = profiles[profile_id]
	return registry.transformed_footprint(
		profile, _v3(transform["origin"]),
		rad_to_deg(MapLayoutCanonical.float_value(transform["yaw_radians"])),
		_v3(transform["scale"]))


## Resolve the active act's landscape catalogue and hand its profiles on.
##
## Every act, 0-3, declares a set in `MapLandscapeAssets` (its scenery, a gate
## and, for Act I, the Vigil), so a set that resolves only in part is a defect and
## never work in progress. It `push_error`s naming the act and how many of the
## declared assets resolved, records the layout failure and returns before
## anything is bound, so the result is no landscape rather than a plausible half
## of one. Before this the scene said nothing and the screen above it could only
## report that profiles were unavailable, so a missing asset read as a broken
## renderer (#450, #451).
##
## #451 also asked for a second case, an act nobody has authored yet, kept on
## placeholders with a warning. That case ended with the placeholder renderer
## (`7fc07f66`): an act either declares a set or does not exist, so there is no
## warning path left to keep. An act added to `LayoutBook.ACTS` without a matching
## `MapLandscapeAssets` entry is caught by `tests/test_map_asset_shortfall.gd`.
func _bind_asset_geometry() -> void:
	_release_landscape()
	_clear_waylights()
	_layout_result = null
	_layout_diagnostics.clear()
	_layout_failure.clear()
	_road_segments.clear()
	# Rebound, not cleared: the dictionary belongs to the shared catalogue.
	_active_profiles = {}
	_active_profile_digest = ""
	_terminus_id = ""
	_threshold_id = ""
	MapPinProjection.set_scenery([])
	_landscape_assets = _landscape_source.call(_act)
	if not _landscape_assets.failure.is_empty():
		push_error("MapScene: " + _landscape_assets.shortfall())
		_fail_layout(_landscape_assets.failure)
		return
	_asset_profiles = _landscape_assets.registry
	_active_profiles = _landscape_assets.profiles
	_active_profile_digest = _landscape_assets.digest
	_terminus_id = MapLandscapeAssets.GATES[_act]
	_threshold_id = "vigil" if _act == 0 else ""
	_repaint()


func bind_layout(compiled: MapLayoutResult, quality: Dictionary) -> MapLayoutResult:
	if compiled == null:
		return _fail_layout("compiled result is null")
	if _active_profiles.is_empty() or layout_hero_contract().is_empty():
		return _fail_layout("active map asset profiles are incomplete")
	var key: String = "|".join([compiled.digest(), _active_profile_digest, str(_scatter_salt)])
	var kept: bool = key == _bound_key and quality == _bound["quality"]
	var bound: Dictionary = _bound if kept else {}
	var data: Dictionary = bound["data"] if kept else compiled.identity_dict()
	_release_landscape()
	_landscape = MapJourneyLandscape.new() if is_journey_act() else MapLandscape.new()
	if not is_journey_act():
		_world.add_child(_landscape)
	_landscape.prepare(data, _landscape_assets, _scatter_salt)
	if kept:
		_landscape.bake = bound["bake"]
	else:
		bound = _filter_scenery(data, quality)
		if bound.is_empty():
			return _fail_layout("filtered result is invalid")
	var final_result: MapLayoutResult = bound["result"]
	var edges: Dictionary = data["edges"]
	if not _bind_waylights(edges):
		return _fail_layout("compiled edge cannot configure a bounded waylight")
	_layout_result = final_result
	_layout_failure.clear()
	_road_segments = _flatten_edges(edges)
	var scenery: Dictionary = data["scenery_instances"]
	var rejections: Array[Dictionary] = bound["rejections"]
	_layout_diagnostics = {
		"status": "BOUND",
		"input_digest": str(data["input_digest"]),
		"layout_digest": final_result.digest(),
		"candidate_count": bound["candidate_count"],
		"accepted_count": scenery.size(),
		"rejected_count": rejections.size(),
		"scenery_instances": scenery,
		"rejections": rejections,
	}
	if is_journey_act():
		if not _bind_journey(key, data):
			return null
	else:
		_landscape.build(data)
	if not kept:
		bound["bake"] = _landscape.bake
		bound["quality"] = quality.duplicate(true)
		_bound_key = key
		_bound = bound
	_repaint()
	return final_result


func _filter_scenery(data: Dictionary, quality: Dictionary) -> Dictionary:
	return scenery_binding(data, _landscape, _asset_profiles, _active_profiles,
		layout_hero_contract(), quality)


## Deals `land`'s seeded scenery candidates (`land` prepared for `data`) and
## keeps the ones clear of the land edge, the node reserves, the road corridors
## and the heroes. Writes the survivors into `data` and returns the binding
## `bind_layout` keeps: `data`, the filtered `result`, `candidate_count` and
## `rejections`. Empty when the result is invalid. Static over plain inputs, so
## the journey prefetch binds on its worker exactly as a screen binds
## (`keep_binding`).
static func scenery_binding(data: Dictionary, land: MapLandscape, registry: MapAssetProfiles,
		profiles: Dictionary, contract: Dictionary, quality: Dictionary) -> Dictionary:
	var candidates: Dictionary = land.candidates()
	var accepted: Dictionary = {}
	var accepted_footprints: Array[Dictionary] = []
	var rejections: Array[Dictionary] = []
	var reserves: Dictionary = _scenery_reserves(data, contract, quality,
		_selection_reserve(quality))
	for candidate_id: String in MapLayoutCanonical.sorted_keys(candidates):
		var candidate: Dictionary = candidates[candidate_id]
		var footprint: PackedVector2Array = _footprint_of(candidate, registry, profiles)
		if not land.supports(footprint):
			rejections.append({"candidate_id": candidate_id, "reason": "land edge", "blocker_id": "terrain"})
			continue
		var selection: PackedVector2Array = _selection_of(candidate, footprint, profiles)
		var physical: Dictionary = _shape(footprint)
		var rejection: Dictionary = _scenery_rejection(
			_shape(selection), physical, accepted_footprints, reserves)
		if not rejection.is_empty():
			rejection["candidate_id"] = candidate_id
			rejections.append(rejection)
			continue
		accepted[candidate_id] = candidate["placement"]
		accepted_footprints.append(physical)
	data["scenery_instances"] = MapLayoutCanonical.ordered_dictionary(accepted)
	var result: MapLayoutResult = MapLayoutResult.create(data)
	if result == null:
		return {}
	return {"data": data, "result": result, "candidate_count": candidates.size(),
		"rejections": rejections}


func _fail_layout(reason: String) -> MapLayoutResult:
	_layout_result = null
	_layout_failure = {
		"kind": "compiled_layout", "id": "live_map", "reason": reason,
	}
	_layout_diagnostics = {"status": "FAILED", "failure": _layout_failure.duplicate(true)}
	_road_segments = PackedVector3Array()
	_clear_waylights()
	_release_landscape()
	_repaint()
	return null


func _flatten_edges(edges: Dictionary) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var points: Array = edge["centerline"]
		for i: int in range(points.size() - 1):
			out.append(_v3(points[i]))
			out.append(_v3(points[i + 1]))
	return out


func _bind_waylights(edges: Dictionary) -> bool:
	_clear_waylights()
	var index: int = 0
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var tracer: MapWaylightTracer = MapWaylightTracer.new()
		tracer.name = "Waylight%03d" % index
		if not tracer.configure_route(edge, MapWaylightTracer.STATE_COLD):
			tracer.free()
			_clear_waylights()
			return false
		# The journey land carries the road's state on its own lamps and glass.
		tracer.visible = not is_journey_act()
		_world.add_child(tracer)
		_waylights[edge_id] = tracer
		index += 1
	return true


func _clear_waylights() -> void:
	for tracer: MapWaylightTracer in _waylights.values():
		tracer.free()
	_waylights.clear()


## Everything a scenery candidate is tested against, resolved once per bind:
## node reserves, road-and-waylight corridors (segment by segment) and hero
## zones, each with the distance below which it rejects, in the order the
## rejection is reported.
static func _scenery_reserves(data: Dictionary, contract: Dictionary,
		quality: Dictionary, selection_half: Vector2) -> Dictionary:
	var epsilon: float = MapLayoutCanonical.float_value(quality["epsilon"]["world_m"])
	var nodes: Array[Dictionary] = []
	var anchors: Dictionary = data["node_anchors"]
	for node_id: String in MapLayoutCanonical.sorted_keys(anchors):
		var shape: Dictionary = _shape(
			MapQualityEvaluator._rect(_xz(anchors[node_id]), selection_half))
		shape["id"] = node_id
		nodes.append(shape)
	var road_clearance: float = MapLayoutCanonical.float_value(
		quality["geometry"]["road_corridor"]["world_clearance_m"])
	var roads: Array[Dictionary] = []
	var edges: Dictionary = data["edges"]
	for edge_id: String in MapLayoutCanonical.sorted_keys(edges):
		var edge: Dictionary = edges[edge_id]
		var reserve: float = MapLayoutCanonical.float_value(edge["corridor_width"]) \
			* 0.5 + road_clearance
		var points: Array = edge["centerline"]
		var segments: Array[Dictionary] = []
		for i: int in range(points.size() - 1):
			segments.append(_shape(PackedVector2Array([_xz(points[i]), _xz(points[i + 1])])))
		roads.append({"id": edge_id, "reserve": reserve,
			"box": _union_box(segments), "segments": segments})
	var zones: Array[Dictionary] = []
	var zone_rows: Dictionary = contract["protected_zones"]
	for zone_id: String in MapLayoutCanonical.sorted_keys(zone_rows):
		var zone: Dictionary = zone_rows[zone_id]
		var geometry_id: String = "%s_protected_zone" % str(zone["role"])
		var geometry: Dictionary = quality["geometry"]
		var shape: Dictionary = _shape(MapQualityEvaluator._poly(zone["polygon"]))
		shape["id"] = zone_id
		shape["padding"] = MapLayoutCanonical.float_value(geometry[geometry_id]["padding_m"]) \
			if geometry.has(geometry_id) else NAN
		zones.append(shape)
	return {"epsilon": epsilon, "nodes": nodes, "roads": roads, "zones": zones}


## The first rule a candidate breaks, or {} when it may stand. Each exact
## polygon test runs only when the two bounding boxes are close enough for it
## to fire: box separation is a lower bound on the true distance, and
## `_BOX_SLACK_M` keeps float rounding in the exact test from ever mattering.
## The decision and its reported blocker are therefore those of the full scan.
static func _scenery_rejection(footprint: Dictionary, physical: Dictionary,
		accepted: Array[Dictionary], reserves: Dictionary) -> Dictionary:
	var polygon: PackedVector2Array = footprint["points"]
	if polygon.is_empty():
		return {"reason": "invalid transformed footprint", "blocker_id": "profile"}
	var box: Vector4 = footprint["box"]
	var epsilon: float = reserves["epsilon"]
	for node: Dictionary in reserves["nodes"]:
		var node_box: Vector4 = node["box"]
		var node_rect: PackedVector2Array = node["points"]
		if _box_gap(box, node_box) <= epsilon + _BOX_SLACK_M \
				and MapQualityEvaluator._polygon_distance(polygon, node_rect) <= epsilon:
			return {"reason": "node reserve", "blocker_id": node["id"]}
	for road: Dictionary in reserves["roads"]:
		var reserve: float = road["reserve"]
		var road_box: Vector4 = road["box"]
		if _box_gap(box, road_box) > reserve + _BOX_SLACK_M:
			continue
		for segment: Dictionary in road["segments"]:
			var ends: PackedVector2Array = segment["points"]
			var segment_box: Vector4 = segment["box"]
			if _box_gap(box, segment_box) <= reserve + _BOX_SLACK_M \
					and MapQualityEvaluator._segment_polygon(ends[0], ends[1],
						polygon) < reserve - epsilon:
				return {"reason": "road and waylight corridor", "blocker_id": road["id"]}
	for zone: Dictionary in reserves["zones"]:
		var padding: float = zone["padding"]
		if is_nan(padding):
			return {"reason": "unknown hero protected zone", "blocker_id": zone["id"]}
		var zone_box: Vector4 = zone["box"]
		var zone_polygon: PackedVector2Array = zone["points"]
		if _box_gap(box, zone_box) <= padding + _BOX_SLACK_M \
				and MapQualityEvaluator._polygon_distance(polygon, zone_polygon) \
					< padding - epsilon:
			return {"reason": "hero protected zone", "blocker_id": zone["id"]}
	# Canopies may overlap one another, as in a grove. Physical footprints
	# remain disjoint; the full projected reserve above protects all gameplay.
	var physical_box: Vector4 = physical["box"]
	var physical_points: PackedVector2Array = physical["points"]
	for prior: Dictionary in accepted:
		var prior_box: Vector4 = prior["box"]
		var prior_points: PackedVector2Array = prior["points"]
		if _box_gap(physical_box, prior_box) <= epsilon + _BOX_SLACK_M \
				and MapQualityEvaluator._polygon_distance(physical_points,
					prior_points) <= epsilon:
			return {"reason": "accepted scenery footprint", "blocker_id": "scenery"}
	return {}


## A point set with its bounding box (min x, min z, max x, max z). The box is
## taken from the points themselves, so it is exact at their precision.
static func _shape(points: PackedVector2Array) -> Dictionary:
	var box: Vector4 = Vector4(INF, INF, -INF, -INF)
	for point: Vector2 in points:
		box = Vector4(minf(box.x, point.x), minf(box.y, point.y),
			maxf(box.z, point.x), maxf(box.w, point.y))
	return {"points": points, "box": box}


static func _union_box(shapes: Array[Dictionary]) -> Vector4:
	var out: Vector4 = Vector4(INF, INF, -INF, -INF)
	for shape: Dictionary in shapes:
		var box: Vector4 = shape["box"]
		out = Vector4(minf(out.x, box.x), minf(out.y, box.y),
			maxf(out.z, box.z), maxf(out.w, box.w))
	return out


## Separation of two boxes along the axis where they are furthest apart; zero
## when they overlap. Never more than the distance between anything inside them.
static func _box_gap(a: Vector4, b: Vector4) -> float:
	return maxf(maxf(a.x - b.z, b.x - a.z), maxf(maxf(a.y - b.w, b.y - a.w), 0.0))


static func _a3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var row: Array = value
	return Vector3(
		MapLayoutCanonical.float_value(row[0]),
		MapLayoutCanonical.float_value(row[1]),
		MapLayoutCanonical.float_value(row[2]))


static func _xz(value: Variant) -> Vector2:
	var point: Vector3 = _v3(value)
	return Vector2(point.x, point.z)


func set_node_states(states: Dictionary) -> void:
	_node_states = states.duplicate()
	if _landscape != null and not _journey_pending:
		_landscape.set_node_states(states)
		_repaint()


func _selection_footprint(candidate: Dictionary, footprint: PackedVector2Array) -> PackedVector2Array:
	return _selection_of(candidate, footprint, _active_profiles)


static func _selection_of(candidate: Dictionary, footprint: PackedVector2Array,
		profiles: Dictionary) -> PackedVector2Array:
	var placement: Dictionary = candidate["placement"]
	var profile: Dictionary = profiles[str(placement["profile_id"])]
	var transform: Dictionary = placement["transform"]
	var height: float = MapLayoutCanonical.float_value(profile["grounded_height"]) * _v3(transform["scale"]).y
	# AABB extrusion is the evaluator's conservative silhouette. Project it back
	# onto Y=0: all camera poses differ only by translation and uniform scale.
	var offset: Vector2 = Vector2(0, -height / tan(deg_to_rad(absf(MapCameraRig.TILT_DEGREES))))
	var points: PackedVector2Array = footprint.duplicate()
	for point: Vector2 in footprint:
		points.append(point + offset)
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[-1]):
		hull.remove_at(hull.size() - 1)
	return hull


static func _selection_reserve(quality: Dictionary) -> Vector2:
	var calibration: Dictionary = quality["calibration"]["shipping_touch_waystone"]
	var radius: float = MapLayoutCanonical.float_value(calibration["ink_radius_px"]) * MapLayoutCanonical.float_value(calibration["default_layout_scale"])
	for rule: Dictionary in quality["hard"]:
		if str(rule["id"]) == "node_ink_clearance_px":
			radius += MapLayoutCanonical.float_value(rule["limit"])
	radius = maxf(radius, MapQualityEvaluator._touch_size_px(quality) * 0.5)
	var pixels_per_metre: float = INF
	var shapes: Dictionary = quality["profiles"]["shapes"]
	for shape: Array in shapes.values():
		for zoom: float in quality["profiles"]["zoom_stops_m"]:
			pixels_per_metre = minf(pixels_per_metre, MapLayoutCanonical.float_value(shape[1]) / zoom)
	var half: float = radius / pixels_per_metre
	return Vector2(half, half / sin(deg_to_rad(absf(MapCameraRig.TILT_DEGREES))))


## How many display frames pass between two renders of a land that moves at
## rest (the journey's water, flame and pilgrim): every other frame (30 Hz on a
## 60 Hz display), every fourth under Reduce Motion. A painted act, which does
## not move at rest, stays frozen (`UPDATE_ONCE`, then nothing).
const REST_EVERY: int = 2
const REST_EVERY_REDUCED: int = 4


func _rest_cadence() -> void:
	var land: MapJourneyLandscape = journey_landscape()
	if land == null or _journey_pending or not land.is_built():
		return
	_rest_tick += 1
	var every: int = REST_EVERY_REDUCED if Preferences.active.reduce_motion else REST_EVERY
	if _rest_tick % every == 0:
		_stage.render_target_update_mode = SubViewport.UPDATE_ONCE


## The lean profile for phones and tablets (A12 floor): the stage draws without
## MSAA, the journey land's stage at `LEAN_OVERSAMPLE`, and its ground without
## fine noise. Measured on the iPad 8 (docs/design/2026-10-02-map-living-land).
static var lean_override: int = -1


static func lean_profile() -> bool:
	return lean_override == 1 if lean_override >= 0 else OS.has_feature("mobile")


## Whether Act I is drawn as the journey land. Always on in the game; a test of
## the painted landscape's own contract (which Acts II–IV keep) may turn it off.
static var journey_enabled: bool = true


## Whether this act is drawn as the journey woodland (`MapJourneyLandscape`).
## Act I only; the other acts keep the painted landscape.
func is_journey_act() -> bool:
	return _act == 0 and journey_enabled


func journey_landscape() -> MapJourneyLandscape:
	return _landscape as MapJourneyLandscape


## Where node `id`'s waystone stands in the drawn world: the journey stone's
## seat in Act I, the record's anchor elsewhere.
func seat_of(id: String, anchor: Vector3) -> Vector3:
	var journey: MapJourneyLandscape = journey_landscape()
	return journey.seat(id, anchor) if journey != null else anchor


## Draws the journey land for the bound layout: the kept land when it was built
## for `key`, otherwise a new build, on the worker pool when `journey_async`.
## False (and a failed layout) when the land cannot be built.
func _bind_journey(key: String, data: Dictionary) -> bool:
	var land: MapJourneyLandscape = _landscape as MapJourneyLandscape
	var kept: MapJourneyLandscape = _kept_for(key)
	if kept != null:
		land.free()
		land = kept
		_landscape = land
	elif journey_async:
		_journey_pending = true
		_journey_key = key
		_journey_data = data
		if MapJourneyPrefetch.busy():
			# The map is opening now: the prefetch's setup runs at once, and its
			# land is taken if it turns out to be this layout's (`_poll_journey`).
			MapJourneyPrefetch.hurry()
		else:
			land.start(data)
		return true
	else:
		land.build(data)
	if not land.failure.is_empty():
		_fail_layout(land.failure)
		return false
	_keep_journey(key, land)
	_world.add_child(land)
	land.set_node_states(_node_states)
	return true


func _poll_journey() -> void:
	var land: MapJourneyLandscape = _landscape as MapJourneyLandscape
	if land == null:
		_journey_pending = false
		return
	if not land.is_started():
		# A prefetch was under way when this map bound: take its land when it
		# turns out to be this layout's, otherwise build our own.
		if MapJourneyPrefetch.busy():
			return
		var kept: MapJourneyLandscape = _kept_for(_journey_key)
		if kept != null:
			land.free()
			land = kept
			_landscape = land
		else:
			land.start(_journey_data)
			return
	elif not land.poll():
		return
	_journey_pending = false
	if not land.failure.is_empty():
		_fail_layout(land.failure)
		return
	_keep_journey(_journey_key, land)
	_world.add_child(land)
	land.set_node_states(_node_states)
	_repaint()
	landscape_ready.emit()


func landscape_pending() -> bool:
	return _journey_pending


## The kept land when it was kept for `key` and this screen may draw it: drawn
## by no screen, or by one on its way out. A screen replaced or let go is freed
## at the frame's end (`queue_free`: `Main._show_map`, `MapScreenKeep.take`),
## and the screen that replaces it binds in the same frame, so the leaving
## screen hands the land over now instead of a second build starting (a
## language change on the map, a run restored over a kept screen).
static func _kept_for(key: String) -> MapJourneyLandscape:
	if key != _journey_kept_key or not is_instance_valid(_journey_kept):
		return null
	var holder: Node = _journey_kept.get_parent()
	var leaving: bool = false
	var scene: MapScene = null
	while holder != null:
		leaving = leaving or holder.is_queued_for_deletion()
		if scene == null and holder is MapScene:
			scene = holder
		holder = holder.get_parent()
	if leaving and scene != null and scene._landscape == _journey_kept:
		scene._release_landscape()
	return _journey_kept if _journey_kept.get_parent() == null else null


## Makes `land`, built for binding `key` (`MapJourneyPrefetch`), the kept land.
static func adopt_journey(key: String, land: MapJourneyLandscape) -> void:
	_keep_journey(key, land)


## Keeps `bound`, the binding `scenery_binding` made for `key` off any screen
## (the journey prefetch, on its worker), as the one the next screen of that
## layout, catalogue and salt takes; it carries `bake` and `quality` as
## `bind_layout` stores them.
static func keep_binding(key: String, bound: Dictionary) -> void:
	_bound_key = key
	_bound = bound


## Frees the kept journey land when it was kept for `key` and nothing draws it
## (a prefetch given up for another layout's).
static func release_journey(key: String) -> void:
	if key == _journey_kept_key:
		release_kept_journey()


## Lets go of the kept journey land: freed now when nothing draws it, else by
## the scene that draws it (the next map is not the journey act's, process
## exit, tests).
static func release_kept_journey() -> void:
	if is_instance_valid(_journey_kept) and _journey_kept.get_parent() == null:
		_journey_kept.free()
	# A land still building is left to `reap`: waiting on its worker here could
	# wait on a worker that waits on this thread.
	reap()
	_journey_kept = null
	_journey_kept_key = ""


static func _keep_journey(key: String, land: MapJourneyLandscape) -> void:
	if _journey_kept != land and is_instance_valid(_journey_kept) \
			and _journey_kept.get_parent() == null:
		_journey_kept.free()
	_journey_kept = land
	_journey_kept_key = key


## Lets go of the drawn land: the kept journey land is only detached, a land
## mid-build is joined first (a worker may still be writing into it), and any
## other land is freed.
func _release_landscape() -> void:
	if _landscape == null:
		return
	var land: MapJourneyLandscape = _landscape as MapJourneyLandscape
	_journey_pending = false
	if land != null and land == _journey_kept:
		if land.get_parent() != null:
			land.get_parent().remove_child(land)
	elif land != null and land.busy():
		abandon(land)
	else:
		_landscape.free()
	_landscape = null


## Lands given up while a worker still builds them, freed once it ends.
static var _abandoned: Array[MapJourneyLandscape] = []


static func abandon(land: MapJourneyLandscape) -> void:
	if land.get_parent() != null:
		land.get_parent().remove_child(land)
	_abandoned.append(land)


## Waits for every abandoned land's worker and frees the land (process exit).
static func join_abandoned() -> void:
	for land: MapJourneyLandscape in _abandoned:
		land.settle()
		land.free()
	_abandoned.clear()


## Frees the abandoned lands whose worker has ended. Any map's frame runs it.
static func reap() -> void:
	if _abandoned.is_empty():
		return
	for land: MapJourneyLandscape in _abandoned.duplicate():
		if not land.busy():
			land.settle()
			_abandoned.erase(land)
			land.free()
