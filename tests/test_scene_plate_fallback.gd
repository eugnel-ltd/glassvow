extends RefCounted
## Until the Unlit Way plates land (#563) the ten Lamplighter scenes have no
## art of their own; they play over the current act's combat backdrop instead
## of the dark gradient. A beat that names art keeps it, and a player given no
## act keeps the graded ground.

const LAMP_SCENES: Array[String] = [
	"lamplighter-m1-pre", "lamplighter-m1-post", "lamplighter-m2-pre",
	"lamplighter-m2-post", "lamplighter-m3-pre", "lamplighter-m3-post",
	"lamplighter-m4-pre", "lamplighter-m4-post", "lamplighter-m5-pre",
	"lamplighter-m5-post",
]
const ACT_COUNT: int = 4


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scene_plate_fallback: %s" % what)


static func run(fails: Array[String]) -> void:
	_backdrop_paths(fails)
	_lamplighter_plays_over_the_act_backdrop(fails)
	_named_art_is_never_overridden(fails)
	_no_act_keeps_the_ground(fails)


static func _backdrop_paths(fails: Array[String]) -> void:
	for act: int in range(ACT_COUNT):
		_check(fails, ScenePlayer.stage_backdrop(act)
				== "res://assets/art/stage/act%d-backdrop.png" % (act + 1),
			"act index %d did not resolve to its own backdrop" % act)
	_check(fails, ScenePlayer.stage_backdrop(-1).is_empty(),
		"an unknown act resolved a backdrop")
	_check(fails, ScenePlayer.stage_backdrop(ACT_COUNT).is_empty(),
		"an act with no plate resolved a backdrop")


static func _lamplighter_plays_over_the_act_backdrop(fails: Array[String]) -> void:
	for scene_id: String in LAMP_SCENES:
		var script: SceneScript = _script(scene_id)
		if script == null:
			_check(fails, false, "%s did not load" % scene_id)
			continue
		_check(fails, str(script.beat_at(0).get("art", "")).is_empty(),
			"%s now names art; retire the fallback for it (#563)" % scene_id)
		for act: int in range(ACT_COUNT):
			var player: ScenePlayer = _live(script, 0, act)
			_check(fails, player._plate.visible and _plate_path(player)
					== "res://assets/art/stage/act%d-backdrop.png" % (act + 1),
				"%s in act index %d did not stand on that act's backdrop"
					% [scene_id, act])
			player.free()


static func _named_art_is_never_overridden(fails: Array[String]) -> void:
	# Opening beat 0 names the hearth plate; beat 1 names none and inherits it.
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	for cursor: int in range(opening.line_count()):
		var player: ScenePlayer = _live(opening, cursor, 2)
		_check(fails, _plate_path(player) == "res://assets/art/scenes/opening-hearth.png",
			"opening cursor %d lost its hearth plate to the act backdrop" % cursor)
		player.free()


static func _no_act_keeps_the_ground(fails: Array[String]) -> void:
	var script: SceneScript = _script("lamplighter-m1-pre")
	if script == null:
		_check(fails, false, "lamplighter-m1-pre did not load")
		return
	var player: ScenePlayer = _live(script, 0, -1)
	_check(fails, not player._plate.visible,
		"a player given no act still drew a plate")
	player.free()


static func _plate_path(player: ScenePlayer) -> String:
	return player._plate.texture.resource_path if player._plate.texture != null else ""


static func _live(script: SceneScript, cursor: int, act: int) -> ScenePlayer:
	var player: ScenePlayer = ScenePlayer.new(script, cursor)
	player.instant = true
	player.plate_act = act
	player._ready()
	player._process(0.016)
	return player


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	if found is SceneScript:
		return found
	return null
