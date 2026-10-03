extends RefCounted
## Act I's journey land (`MapJourneyLandscape`, revived from the September
## rebuild) on the production path: it draws MapLayoutFast's record without
## changing it, seats every waystone on the compiled anchor, keeps the pins
## where the stones stand, frames Journey and Whole act inside the contract,
## walks the pilgrim along the graded road and renders at its rest cadence.
## The painted landscape's own contract (Acts II–IV) is test_map_compose.gd.

const SEED: int = 717


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_map_journey: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, SEED, "run-map-journey")
	var screen: WorldMapScreen = _screen(content, run, WorldMap.for_run(run, content))
	var scene: MapScene = screen._map_scene
	var land: MapJourneyLandscape = scene.journey_landscape()
	_check(fails, land != null and land.is_built() and land.failure.is_empty(),
		"Act I binds the journey land: %s" % (land.failure if land != null else "none"))
	if land == null or not land.is_built():
		_free(screen)
		return
	_same_layout(fails, content, run, screen)
	_seats(fails, screen, land)
	_lamps(fails, screen, land)
	_framing(fails, screen)
	_clip_slab(fails, screen, land)
	_focus_band(fails, screen)
	_whole_act(fails, screen)
	_walk(fails, screen, land, content, run)
	_rest_cadence(fails, scene)
	_living_motion(fails, scene, land)
	_reduce_motion(fails, scene, land)
	_shadow_proxies(fails)
	_act_switch(fails, screen, run)
	_free(screen)


static func _screen(content: ContentDB, run: RunState, map: WorldMap) -> WorldMapScreen:
	var screen: WorldMapScreen = WorldMapScreen.new(map, content)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	_mount(screen, StageShape.IDENTITY)
	screen.refresh(run)
	return screen


static func _free(screen: WorldMapScreen) -> void:
	screen.get_parent().remove_child(screen)
	screen.free()
	MapScene.release_kept_journey()


## The land is presentation only: the record the screen binds is the one the
## painted landscape binds for the same input.
static func _same_layout(fails: Array[String], content: ContentDB, run: RunState,
		screen: WorldMapScreen) -> void:
	MapScene.journey_enabled = false
	var painted: WorldMapScreen = _screen(content, run, screen.map)
	MapScene.journey_enabled = true
	_check(fails, painted._map_scene.journey_landscape() == null
			and painted.layout_digest() == screen.layout_digest()
			and painted.layout_input_digest() == screen.layout_input_digest(),
		"the journey land leaves the layout record and its digests unchanged")
	painted.get_parent().remove_child(painted)
	painted.free()


## Every waystone stands on its compiled anchor (same X/Z, height from the
## land), and the pin is drawn where the stone stands and picks its node.
static func _seats(fails: Array[String], screen: WorldMapScreen,
		land: MapJourneyLandscape) -> void:
	var anchors: PackedVector3Array = screen._ordered_layout_anchors()
	var seated: bool = anchors.size() == screen.map.nodes.size()
	for i: int in range(anchors.size()):
		var seat: Vector3 = land.seat(screen.map.nodes[i].id, Vector3.INF)
		seated = seated and seat.is_finite() and is_equal_approx(seat.x, anchors[i].x) \
			and is_equal_approx(seat.z, anchors[i].z)
	_check(fails, seated, "every waystone stands on its compiled anchor's X/Z")
	var pins: PackedVector3Array = screen._journey.pin_seats(anchors)
	var seats: PackedVector2Array = screen.projected_seats()
	_check(fails, seats == screen._map_scene.project_anchors(pins),
		"the pins project from the stones they stand on")
	for i: int in screen.map.reachable():
		_check(fails, screen.pick_node_at(seats[i]) == i,
			"a tap on reachable waystone %d picks it" % i)


## R2 light: lanterns along the roads, each off the walking lane and clear of
## every waystone; one flame per lamp; at most four real lamp lights, without
## shadows, given to the lamps nearest the pilgrim.
static func _lamps(fails: Array[String], screen: WorldMapScreen,
		land: MapJourneyLandscape) -> void:
	var posts: Array[Vector3] = []
	for item: Dictionary in land.kit.placed:
		if str(item["kind"]) == "lantern-post":
			posts.append(item["position"])
	_check(fails, posts.size() >= 10, "lanterns stand along the roads (%d)" % posts.size())
	var anchors: PackedVector3Array = screen._ordered_layout_anchors()
	var clear: bool = true
	for p: Vector3 in posts:
		clear = clear and land.terrain.distance_to_roads(p) >= 1.2
		for i: int in range(anchors.size()):
			var seat: Vector3 = land.seat(screen.map.nodes[i].id, anchors[i])
			clear = clear and Vector2(p.x - seat.x, p.z - seat.z).length() >= 1.5
	_check(fails, clear, "every lantern stands off the walking lane and clear of every waystone")
	var lamps: MapJourneyLandscape.Lamps = land.lamps
	_check(fails, lamps.anchors.size() == posts.size() + 2
			and lamps.flames.multimesh.instance_count == lamps.anchors.size(),
		"one flame for each lantern and each of the gateway's two lamps")
	land.focus_lamps(lamps.anchors[0])
	var lit: PackedVector3Array = lamps.lit()
	var real: int = 0 if MapScene.lean_profile() else MapJourneyLandscape.Lamps.REAL_LIGHTS
	var nearest: bool = lit.size() == mini(real, lamps.anchors.size())
	for p: Vector3 in lamps.anchors:
		if not lit.has(p) and not lit.is_empty():
			nearest = nearest and p.distance_to(lamps.anchors[0]) >= lit[-1].distance_to(lamps.anchors[0]) - 0.001
	var shadowless: bool = true
	for light: OmniLight3D in lamps.lights:
		shadowless = shadowless and not light.shadow_enabled
	_check(fails, nearest and shadowless,
		"the four shadowless lamp lights go to the lamps nearest the focus")
	var lean_was: int = MapScene.lean_override
	MapScene.lean_override = 1
	var lean_lamps: MapJourneyLandscape.Lamps = MapJourneyLandscape.Lamps.new()
	lean_lamps.build(lamps.anchors)
	_check(fails, lean_lamps.lights.is_empty()
			and lean_lamps.flames.multimesh.instance_count == lamps.anchors.size(),
		"phones and tablets keep every flame and give no lamp a real light")
	lean_lamps.free()
	MapScene.lean_override = lean_was


## Journey frames the pilgrim's stone and its next stones on the journey camera,
## every one inside the stage and on its own touch square.
static func _framing(fails: Array[String], screen: WorldMapScreen) -> void:
	var rig: MapCameraRig = screen._map_scene.get_rig()
	_check(fails, rig.journey_mode
			and is_equal_approx(rig.get_camera().rotation_degrees.x, -MapJourneyCameraContract.PITCH)
			and rig.zoom_stop == MapCameraRig.DEFAULT_STOP,
		"Act I opens on the journey camera's Journey framing")
	_check(fails, rig.get_camera().size >= MapJourneyCameraContract.PREFERRED_ZOOM - 0.01,
		"the Journey view holds the road round the framed stones (%.1f m)" % rig.get_camera().size)
	var stage: Vector2 = Vector2(StageShape.REFERENCES[StageShape.IDENTITY])
	var touch: float = MapJourneyCameraContract.touch_size(stage)
	var seats: PackedVector2Array = screen.projected_seats()
	var pose: Dictionary = screen._journey.pose_for(screen.map.at)
	var members: Array = pose.get("members", [])
	var inside: bool = not members.is_empty()
	for k: int in range(members.size()):
		var a: Vector2 = seats[int(str(members[k]))]
		inside = inside and Rect2(Vector2.ZERO, stage).has_point(a)
		for m: int in range(k + 1, members.size()):
			var delta: Vector2 = (a - seats[int(str(members[m]))]).abs()
			inside = inside and maxf(delta.x, delta.y) >= touch - 0.5
	_check(fails, inside, "the framed waystones are on screen and on their own touch squares")


## The tilt-shift's sharp band covers every waystone the camera frames, at every
## landscape reference shape, and Whole act has none. Since R3.1 the band is
## drawn at the stage's resolution in a view of its own, and the screen's asking
## every frame re-applies nothing while the band stands still.
static func _focus_band(fails: Array[String], screen: WorldMapScreen) -> void:
	var scene: MapScene = screen._map_scene
	for shape: StringName in [&"phone-landscape", &"pad-landscape", &"desktop-landscape"]:
		_mount(screen, shape)
		screen._journey.frame(screen.map.at)
		screen._layout_waystones()
		var band: Vector2 = scene.focus_band
		var seats: PackedVector2Array = screen.projected_seats()
		var covered: bool = band.is_finite() and not screen._journey.focus_members.is_empty()
		for i: int in screen._journey.focus_members:
			covered = covered and seats[i].y >= band.x and seats[i].y <= band.y
		_check(fails, covered, "the sharp band covers every framed waystone at %s" % shape)
		_stage_resolution_band(fails, scene, shape)
	# Panned away: the band covers what is left on screen near the middle, and
	# with nothing on screen it is the narrowest band about the middle.
	var panned: Vector2 = MapTiltShift.band(PackedFloat32Array([-300.0, 40.0]), 820.0, 30.0)
	var away: Vector2 = MapTiltShift.band(PackedFloat32Array([-300.0, 1200.0]), 820.0, 30.0)
	_check(fails, (panned.x + panned.y) * 0.5 >= MapTiltShift.MIDDLE.x * 820.0 - 0.01
			and panned.y - panned.x <= MapTiltShift.MAX_BAND * 820.0 + 0.01
			and is_equal_approx(away.x + away.y, 820.0)
			and is_equal_approx(away.y - away.x, MapTiltShift.MIN_BAND * 820.0),
		"a group panned off screen leaves the sharp band where the player looks")
	_mount(screen, StageShape.IDENTITY)
	screen._journey.zoom(true)
	screen._layout_waystones()
	_check(fails, not scene.focus_band.is_finite()
			and scene._display.texture == scene.get_stage().get_texture()
			and scene._shift.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Whole act has no tilt-shift: the display draws the stage and the band's view rests")
	screen._journey.zoom(false)
	screen._layout_waystones()
	_check(fails, scene.focus_band.is_finite(), "looking closer brings the band back")


## The band's pass reads the stage texel for texel in its own view, which the
## stage is a child of (the engine draws a child view first, so the band never
## shows the last frame's stage); the display only upscales it. A band that has
## not moved is not applied again on the next frame.
static func _stage_resolution_band(fails: Array[String], scene: MapScene,
		shape: StringName) -> void:
	var shift: ShaderMaterial = scene._shift_rect.material as ShaderMaterial
	_check(fails, scene._display.texture == scene._shift.get_texture()
			and scene._shift.size == scene.get_stage().size
			and scene._shift_rect.size == Vector2(scene.get_stage().size)
			and scene.get_stage().get_parent() == scene._shift
			and scene._shift.disable_3d,
		"the band is drawn at the stage's size, after the stage, at %s" % shape)
	var band: Vector2 = shift.get_shader_parameter("band")
	var radius: float = shift.get_shader_parameter("radius_texels")
	_check(fails, band == scene.focus_band / scene.size.y
			and is_equal_approx(radius,
				MapTiltShift.STRENGTH_PX * scene.get_stage().size.y / MapTiltShift.IDENTITY_HEIGHT),
		"the band's uniforms are the band and its stage-texel radius at %s" % shape)
	var screen: WorldMapScreen = scene.get_parent() as WorldMapScreen
	shift.set_shader_parameter("band", Vector2(-1.0, -1.0))
	scene._shift.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen._layout_waystones()
	band = shift.get_shader_parameter("band")
	_check(fails, band == Vector2(-1.0, -1.0)
			and scene._shift.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"a band that has not moved is not applied again at %s" % shape)
	shift.set_shader_parameter("band", scene.focus_band / scene.size.y)


## Whole act is for looking: it frames the act, and a tap looks closer without
## choosing a waystone.
static func _whole_act(fails: Array[String], screen: WorldMapScreen) -> void:
	var rig: MapCameraRig = screen._map_scene.get_rig()
	var journey_size: float = rig.get_camera().size
	screen._journey.zoom(true)
	_check(fails, screen._journey.view.overview and rig.zoom_stop == MapCameraRig.ZOOM_STOPS.size() - 1
			and rig.get_camera().size > journey_size, "zooming out frames the whole act")
	var chosen: Array[int] = []
	var record: Callable = func(i: int) -> void: chosen.append(i)
	screen.node_chosen.connect(record)
	screen._on_surface_tapped(screen.projected_seats()[screen.map.reachable()[0]])
	screen.node_chosen.disconnect(record)
	_check(fails, not screen._journey.view.overview and chosen.is_empty()
			and not screen._travelling,
		"a tap on the whole act looks closer and chooses nothing")
	screen._journey.zoom(false)


## The pilgrim walks the road graded onto the land, from the stone it leaves to
## the stone it reaches, carrying the run's Flame; reduced motion places it.
static func _walk(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape,
		content: ContentDB, run: RunState) -> void:
	var from_i: int = screen.map.reachable()[0]
	screen.map.enter(from_i)
	screen.map.clear_current()
	screen.refresh(run)
	var parked: Vector3 = screen.marker_world_position()
	_check(fails, parked.is_finite() and land.journey.walker.visible
			and Vector2(parked.x - land.seat(screen.map.nodes[from_i].id, parked).x,
				parked.z - land.seat(screen.map.nodes[from_i].id, parked).z).length() < 1.5,
		"the pilgrim waits beside the current waystone")
	var lantern: LanternFlame = LanternFlame.new()
	lantern.show_event(Flame.read(content, run), true)
	_check(fails, land.journey.walker.flame.is_equal_approx(lantern.light_now()),
		"the pilgrim's lantern burns the run's Flame")
	lantern.free()
	var to_i: int = screen.map.reachable()[0]
	var from_id: String = screen.map.nodes[from_i].id
	var to_id: String = screen.map.nodes[to_i].id
	var route: PackedVector3Array = land.walking_route(from_id, to_id)
	_check(fails, route.size() >= 2, "a walkable route joins the two waystones")
	if route.size() < 2:
		return
	var duration: float = land.travel_duration(from_id, to_id)
	_check(fails, duration >= 0.7 and duration <= 4.5, "the walk takes 0.7 to 4.5 s")
	screen.map.at = to_i
	screen.set("_travel_from_i", from_i)
	screen.set("_travelling", true)
	for t: float in [0.0, 1.0]:
		screen.set("_travel_t", t)
		var at: Vector3 = screen.marker_world_position()
		var expected: Vector3 = route[0] if t == 0.0 else route[-1]
		_check(fails, at.distance_to(expected) < 0.05,
			"walk sample %.0f lies on the walking route" % t)
	screen.set("_travelling", false)
	screen.set("_travel_from_i", -1)
	screen.map.at = from_i


## At rest the land renders every `REST_EVERY` frames (30 Hz), every
## `REST_EVERY_REDUCED` under Reduce Motion: its water and lamps move. The
## tilt-shift's view renders exactly when the stage does.
static func _rest_cadence(fails: Array[String], scene: MapScene) -> void:
	var reduced: bool = Preferences.active.reduce_motion
	scene.set_focus_band(Vector2(scene.size.y * 0.3, scene.size.y * 0.7))
	for mode: bool in [false, true]:
		Preferences.active.reduce_motion = mode
		scene.set_live(false)
		for frame: int in range(3):
			scene._process(0.0)
		var renders: int = 0
		var together: bool = true
		for frame: int in range(8):
			scene.get_stage().render_target_update_mode = SubViewport.UPDATE_DISABLED
			scene._shift.render_target_update_mode = SubViewport.UPDATE_DISABLED
			scene._process(0.0)
			if scene.get_stage().render_target_update_mode == SubViewport.UPDATE_ONCE:
				renders += 1
			together = together and (scene._shift.render_target_update_mode
				== scene.get_stage().render_target_update_mode)
		var every: int = MapScene.REST_EVERY_REDUCED if mode else MapScene.REST_EVERY
		_check(fails, not scene.is_live() and renders == 8 / every,
			"at rest the land renders every %d frames (%s)" % [every, "reduced" if mode else "full"])
		_check(fails, together, "the band's view renders with the stage at rest (%s)"
			% ("reduced" if mode else "full"))
	scene.set_live(true)
	_check(fails, scene._shift.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
		"the band's view renders every frame while the land is live")
	scene.set_live(false)
	Preferences.active.reduce_motion = reduced


## R2 step 3: banners hang on the bridges, facing the camera and off the walking
## lane; the kit's foliage and the banners' cloth move under `LandMotion`; and
## Reduce Motion stills them and takes the embers and ash away (lantern flicker
## and the water keep their own cadence).
static func _living_motion(fails: Array[String], scene: MapScene,
		land: MapJourneyLandscape) -> void:
	var banners: Array[Dictionary] = []
	for item: Dictionary in land.kit.placed:
		if str(item["kind"]) == "bridge-banner":
			banners.append(item)
	var hung: bool = banners.size() >= 4
	for item: Dictionary in banners:
		var yaw: float = float(str(item["yaw"]))
		var at: Vector3 = item["position"]
		hung = hung and cos(yaw) >= 0.5 and land.terrain.distance_to_roads(at) >= 0.9
	_check(fails, hung, "banners hang outside the bridges, facing the camera (%d)" % banners.size())
	var swaying: int = 0
	var rippling: int = 0
	for node: Node in land.kit.find_children("*", "MultiMeshInstance3D", true, false):
		var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh
		for i: int in range(mesh.get_surface_count()):
			var material: ShaderMaterial = mesh.surface_get_material(i) as ShaderMaterial
			if material == null:
				continue
			if material.shader == preload("res://presentation/map/landscape/foliage.gdshader"):
				swaying += 1
			elif material.shader == preload("res://presentation/map/landscape/banner.gdshader"):
				rippling += 1
	_check(fails, swaying > 0 and rippling > 0, "the foliage sways and the banners ripple")
	_check(fails, land.air.embers.preprocess == 0.0 and land.air.ash.preprocess == 0.0,
		"the air fills in rather than pre-simulating in the land's first frame")
	var reduced: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	scene.set_live(false)
	_tick(scene, land)
	var moving: bool = MapJourneyLandscape.LandMotion.enabled and land.air.visible
	Preferences.active.reduce_motion = true
	_tick(scene, land)
	var still: bool = not MapJourneyLandscape.LandMotion.enabled and not land.air.visible \
		and not land.air.embers.emitting and not land.air.ash.emitting
	_check(fails, still, "Reduce Motion stills the foliage and banners and clears the air")
	Preferences.active.reduce_motion = false
	_tick(scene, land)
	_check(fails, moving and MapJourneyLandscape.LandMotion.enabled and land.air.visible,
		"the land moves without Reduce Motion, and again once it is off")
	Preferences.active.reduce_motion = reduced
	_tick(scene, land)


## Reduce Motion holds the whole land still from its first frame (R2's review
## notes): `LandMotion` follows the preference on a settle frame, not only at
## the first rest tick; the shaders that move under it (the flames' flipbook
## and flicker, the pools' flicker) read the one global switch; and the real
## lamp lights stop breathing with them. Only the water keeps its cadence.
static func _reduce_motion(fails: Array[String], scene: MapScene, land: MapJourneyLandscape) -> void:
	var reduced: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	MapJourneyLandscape.LandMotion.apply(true)
	scene.set_live(false)
	Preferences.active.reduce_motion = true
	scene._process(0.0)
	_check(fails, scene._settle_frames > 0 and not MapJourneyLandscape.LandMotion.enabled,
		"Reduce Motion stills the land on its settle frames")
	Preferences.active.reduce_motion = false
	scene._process(0.0)
	_check(fails, MapJourneyLandscape.LandMotion.enabled, "the land moves again once Reduce Motion is off")
	var declared: Variant = ProjectSettings.get_setting("shader_globals/" + str(MapJourneyLandscape.LandMotion.UNIFORM))
	var global: Dictionary = declared if declared is Dictionary else {}
	_check(fails, str(global.get("type", "")) == "float",
		"the land's motion is one global shader uniform")
	var sources: Dictionary = {
		"flames' flipbook": [preload("res://presentation/map/landscape/flame.gdshader"), "TIME * land_motion"],
		"flames' flicker": [preload("res://presentation/map/landscape/flame.gdshader"), "phase * 40.0) * land_motion"],
		"pools' flicker": [preload("res://presentation/map/landscape/terrain_paint.gdshader"), "TIME*1.9)*land_motion"],
		"foliage": [preload("res://presentation/map/landscape/foliage.gdshader"), "sway * land_motion"],
		"banners": [preload("res://presentation/map/landscape/banner.gdshader"), "wave * land_motion"],
	}
	for what: String in sources:
		var entry: Array = sources[what]
		var shader: Shader = entry[0]
		_check(fails, shader.code.contains("global uniform float land_motion;")
				and shader.code.contains(str(entry[1])),
			"the %s hold still with the land's motion" % what)
	var lean_was: int = MapScene.lean_override
	MapScene.lean_override = 0
	var lamps: MapJourneyLandscape.Lamps = MapJourneyLandscape.Lamps.new()
	lamps.build(land.lamps.anchors)
	lamps.focus(land.lamps.anchors[0])
	MapJourneyLandscape.LandMotion.apply(false)
	lamps._process(0.0)
	var steady: bool = not lamps.lights.is_empty()
	for light: OmniLight3D in lamps.lights:
		steady = steady and is_equal_approx(light.light_energy, MapJourneyLandscape.Lamps.LIGHT_ENERGY * 0.9)
	_check(fails, steady, "under Reduce Motion the real lamp lights hold steady")
	lamps.free()
	MapScene.lean_override = lean_was
	Preferences.active.reduce_motion = reduced
	MapJourneyLandscape.LandMotion.apply(not reduced)


## Runs the scene past its settle frames into the rest cadence.
static func _tick(scene: MapScene, land: MapJourneyLandscape) -> void:
	for frame: int in range(10):
		scene._process(0.0)
	land.air._process(0.0)


## Phones and tablets: a conifer's leafy mesh casts no shadow and one opaque
## shadow-only cone casts for it.
static func _shadow_proxies(fails: Array[String]) -> void:
	const Scenery = preload("res://presentation/map/landscape/static_scenery.gd")
	var scene: PackedScene = load("res://assets/art/map-journey/conifer.glb") as PackedScene
	var tree: Node3D = scene.instantiate() as Node3D
	preload("res://presentation/map/landscape/asset_surfaces.gd").prepare(tree, {})
	var parts: Array[Dictionary] = []
	Scenery._collect(tree, tree.transform.affine_inverse(), parts)
	tree.free()
	var leafy: int = parts.size()
	Scenery._proxy_shadows(parts)
	var proxies: int = 0
	var silent: bool = true
	for part: Dictionary in parts:
		if part["shadow"] == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			proxies += 1
		else:
			silent = silent and part["shadow"] == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(fails, leafy == 1 and parts.size() == 2 and proxies == 1 and silent,
		"a conifer casts through one shadow-only cone, not its cut-out foliage")


## The journey camera clips to the land's slab, which is also the reach of its
## directional shadow (an orthographic camera's shadow covers near to far), and
## the whole built land lies inside the heights that slab is cut for.
static func _clip_slab(fails: Array[String], screen: WorldMapScreen, land: MapJourneyLandscape) -> void:
	var camera: Camera3D = screen._map_scene.get_rig().get_camera()
	var depth: Vector2 = MapJourneyCameraContract.depth_range(camera.size)
	_check(fails, is_equal_approx(camera.near, depth.x) and is_equal_approx(camera.far, depth.y)
			and depth.x > 10.0 and depth.y < 100.0,
		"the Journey camera clips to the land's slab (%.1f to %.1f m)" % [camera.near, camera.far])
	var low: float = INF
	var high: float = -INF
	for node: Node in land.find_children("*", "GeometryInstance3D", true, false):
		var item: GeometryInstance3D = node as GeometryInstance3D
		var box: AABB = item.global_transform * item.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	_check(fails, low >= MapJourneyCameraContract.LAND_LOW and high <= MapJourneyCameraContract.LAND_HIGH,
		"the built land lies within the clip slab's heights (%.2f to %.2f m)" % [low, high])


## Leaving Act I gives the painted acts back their governed camera, and their
## own light: Act I's grade and bloom stay in Act I.
static func _act_switch(fails: Array[String], screen: WorldMapScreen, run: RunState) -> void:
	var environment: Environment = (screen._map_scene._world.get_node("MapEnvironment") as WorldEnvironment).environment
	_check(fails, environment.glow_enabled and environment.adjustment_enabled,
		"Act I's journey light grades and blooms")
	run.act = 1
	screen.refresh(run)
	_check(fails, not environment.glow_enabled and not environment.adjustment_enabled,
		"Act II's painted light neither grades nor blooms")
	_check(fails, not screen._map_scene.focus_band.is_finite()
			and screen._map_scene._display.texture == screen._map_scene.get_stage().get_texture(),
		"Act II has no tilt-shift")
	var rig: MapCameraRig = screen._map_scene.get_rig()
	_check(fails, not rig.journey_mode and screen._map_scene.journey_landscape() == null
			and is_equal_approx(rig.get_camera().rotation_degrees.x, MapCameraRig.TILT_DEGREES),
		"Act II draws the painted landscape on the governed camera")
	run.act = 0


static func _mount(screen: WorldMapScreen, shape_name: StringName) -> void:
	var reference: Vector2i = StageShape.REFERENCES[shape_name]
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(reference)
	screen.set_shape(shape_name)
	var scene: MapScene = screen._map_scene
	if scene == null:
		return
	scene.size = screen.size
	scene._fit()
