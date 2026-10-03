extends RefCounted
## The road the title stands on (docs/design/2026-10-03-title-rooms §2.1, §4.3,
## §7 item 12, §11.1). With no walk the eye is exactly where it always was,
## so the door, the road and the lamps project as shipped; a walk carries the
## eye on down the road (the lamps pass); and a world that inherits another
## continues it, projecting every point and every mote where the other does.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("title_world: %s" % what)


static func run(fails: Array[String]) -> void:
	_still_where_it_was(fails)
	_the_lamps_pass(fails)
	_inherit(fails)


static func _world() -> TitleWorld:
	var world: TitleWorld = TitleWorld.new()
	world.size = Vector2(1180.0, 820.0)
	return world


## With walk 0 the chased eye and look are the shipped targets exactly.
static func _still_where_it_was(fails: Array[String]) -> void:
	var world: TitleWorld = _world()
	world._time = 3.7
	world._step_camera(1.0)
	var eye_z: float = 10.0 + sin(world._time * TitleWorld.BREATH_Z_RATE) * TitleWorld.BREATH_Z
	_check(fails, is_equal_approx(world._cam.z, eye_z) and is_equal_approx(world._look.z, -6.0),
		"with no walk the eye is not where it was (%.4f, %.4f)" % [world._cam.z, world._look.z])
	var fresh: TitleWorld = _world()
	fresh._time = 3.7
	fresh.walk = 1.0
	fresh.walk = 0.0
	fresh._step_camera(1.0)
	for points: Array[Vector3] in [world._door_world, world._road_world, world._lanterns]:
		for p: Vector3 in points:
			_check(fails, world._project(p).is_equal_approx(fresh._project(p)),
				"a walk taken back leaves the road projected elsewhere")
	world.free()
	fresh.free()


## Walking on brings the near lamps closer: lower and further out on the stage.
static func _the_lamps_pass(fails: Array[String]) -> void:
	var still: TitleWorld = _world()
	var on: TitleWorld = _world()
	on.walk = TitleWorld.WALK_MAX
	for world: TitleWorld in [still, on]:
		world._step_camera(1.0)
	_check(fails, is_equal_approx(on._cam.z, still._cam.z - TitleWorld.WALK_MAX),
		"the walk does not carry the eye on down the road")
	var lamp: Vector3 = still._lanterns[2]
	var near: Vector3 = on._project(lamp)
	var far: Vector3 = still._project(lamp)
	_check(fails, near.z < far.z and absf(near.x - 590.0) > absf(far.x - 590.0),
		"walking on does not bring the lamps nearer")
	still.free()
	on.free()


static func _inherit(fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	var source: TitleWorld = _world()
	for _i: int in range(120):
		source._process(1.0 / 60.0)
	source.walk = 0.8
	var heir: TitleWorld = _world()
	heir.inherit(source)
	_check(fails, is_equal_approx(heir._time, source._time) and is_equal_approx(heir.walk, source.walk),
		"an inheriting world does not keep the road's clock and walk")
	for points: Array[Vector3] in [source._door_world, source._road_world, source._lanterns]:
		for p: Vector3 in points:
			_check(fails, heir._project(p).is_equal_approx(source._project(p)),
				"an inheriting world projects the road elsewhere")
	_check(fails, heir._main == source._main and heir._accent == source._accent
			and heir._weather == source._weather,
		"an inheriting world restarts the motes and the weather")
	var unmoved: TitleWorld = _world()
	_check(fails, heir._main != unmoved._main, "the motes never moved, so inheriting proves nothing")
	unmoved.free()
	source.free()
	heir.free()
	Preferences.active = kept
