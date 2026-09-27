class_name StagecraftLab
extends Control
## Dev bench for scripted-scene stagecraft: the real ScenePlayer running a
## demo reel that walks every seat, mood fallback, delivery style and effect
## (kindle, crack, shatter, slash, impact, quake, shout, chorus, title card,
## a four-voice stage). Copy is borrowed from shipped scenes by key, so the
## reel reads in both locales and invents no canon — it is a bench, never a
## scene the game can queue.
##
##   godot --path . -- --stagecraft                       (loops the reel)
##   godot --path . -- --stagecraft --cursor=6 --freeze=0.12 --shot=/tmp/s.png
##
## `--freeze=SECONDS` steps the player's own clock that far into the line and
## stops it, so a one-shot effect can be photographed mid-flight.

const REEL: Dictionary = {"beats": [
	{"art": "res://assets/art/scenes/opening-hearth.png", "motion": "push-in",
		"transition": "fade", "ambient": "embers", "grade": "hearth", "lines": [
		{"key": "story.opening.b3.l1"},
		{"speaker": "keeper", "key": "story.opening.b2.l1",
			"enter": ["hero@left", "keeper@right:offering"], "fx": ["kindle@keeper"]},
		{"speaker": "keeper", "key": "story.opening.b2.l3", "mood": "tender"},
	]},
	{"art": "res://assets/art/scenes/act4-node5.png", "motion": "hold",
		"transition": "black", "ambient": "embers", "grade": "inverted", "lines": [
		{"speaker": "keeper", "key": "story.act4-node5.b1.l2", "mood": "revealed",
			"fx": ["flash-cold", "crack"]},
		{"speaker": "keeper", "key": "story.act4-node5.b1.l4", "mood": "beckon",
			"style": "whisper"},
	]},
	{"motion": "hold", "transition": "fade", "ambient": "ash", "grade": "dusk", "lines": [
		{"speaker": "lamplighter", "key": "story.lamplighter-m4.pre.l3",
			"enter": ["lamplighter@right:urgent"], "style": "shout",
			"fx": ["hop@lamplighter", "pulse"]},
		{"key": "story.lamplighter-m4.pre.l4", "fx": ["slash"]},
		{"speaker": "lamplighter", "key": "story.lamplighter-m3.post.l1",
			"mood": "wary", "fx": ["recoil@lamplighter", "impact"]},
		{"speaker": "queue", "key": "story.act4-node2.b1.l1", "style": "chorus",
			"enter": ["keeper@far-right:revealed", "lamplighter@right:grieving",
				"queue@centre"]},
	]},
	{"art": "res://assets/art/scenes/unsealing-mirror-queue.png", "motion": "hold",
		"transition": "white", "ambient": "snow-glass", "grade": "cold", "lines": [
		{"key": "story.unsealing.b3.l4", "exit": ["*"], "fx": ["shatter"]},
		{"key": "story.unsealing.b4.l1", "fx": ["quake"]},
	]},
	{"art": "res://assets/art/scenes/ascended.png", "motion": "linger",
		"transition": "white", "ambient": "motes", "lines": [
		{"key": "story.finale.b2.l4", "style": "title", "fx": ["flash", "rays"]},
	]},
]}

var _player: ScenePlayer
var _cursor: int = 0
var _freeze: float = -1.0


func _init(_content: Variant = null) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor="):
			_cursor = maxi(0, int(arg.trim_prefix("--cursor=")))
		elif arg.begins_with("--freeze="):
			_freeze = maxf(0.0, float(arg.trim_prefix("--freeze=")))


func _ready() -> void:
	_mount(_cursor)


static func reel() -> SceneScript:
	var built: Variant = SceneScript.parse_scene("stagecraft-reel", REEL)
	return built if built is SceneScript else null


func _mount(cursor: int) -> void:
	if _player != null:
		_player.queue_free()
	var script: SceneScript = reel()
	if script == null:
		push_error("stagecraft: the reel did not parse")
		return
	_player = ScenePlayer.new(script, clampi(cursor, 0, script.line_count() - 1),
		StageShape.IDENTITY, null, {}, "duskblade")
	_player.advance_requested.connect(func() -> void: _player.advance_confirmed())
	_player.finished.connect(func() -> void: _mount.call_deferred(0))
	add_child(_player)
	if _freeze >= 0.0:
		_player.set_process(false)
		var left: float = _freeze
		while left > 0.0:
			var step: float = minf(left, 1.0 / 60.0)
			_player._process(step)
			left -= step
