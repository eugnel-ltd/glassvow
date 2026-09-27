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
##
## `--stagecraft-screen=` mounts a staged gameplay screen instead of the reel:
##   hollow[:paid|:refused]        the Lamplighter's price, meeting 3 of 5
##   event:<id>[:c0|:c1|:c2|:coda] a road event, its choice or a story beat
##   battle:<variant>[:death]      a foe's battle dialogue over the Act I stage

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
var _screen: String = ""
var _shape: StringName = StageShape.IDENTITY
var _content: ContentDB = null


func _init(content: Variant = null) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if content is ContentDB:
		_content = content
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cursor="):
			_cursor = maxi(0, int(arg.trim_prefix("--cursor=")))
		elif arg.begins_with("--freeze="):
			_freeze = maxf(0.0, float(arg.trim_prefix("--freeze=")))
		elif arg.begins_with("--stagecraft-screen="):
			_screen = arg.trim_prefix("--stagecraft-screen=")
		elif arg.begins_with("--shape="):
			var named: StringName = StringName(arg.trim_prefix("--shape="))
			if StageShape.REFERENCES.has(named):
				_shape = named


func _ready() -> void:
	if _screen.is_empty() or _content == null:
		_mount(_cursor)
		return
	var parts: PackedStringArray = _screen.split(":")
	var screen: Control = null
	if parts[0] == "hollow":
		screen = _hollow(parts[1] if parts.size() > 1 else "")
	elif parts[0] == "event" and parts.size() > 1:
		screen = _event(parts[1], parts[2] if parts.size() > 2 else "")
	elif parts[0] == "battle" and parts.size() > 1:
		_battle(parts[1], parts.size() > 2 and parts[2] == "death")
		return
	if screen == null:
		push_error("stagecraft: unknown screen '%s'" % _screen)
		return
	add_child(screen)
	_settle(screen)


func _hollow(state: String) -> Control:
	var meetings: Array = _content.quests["hollowLamplighter"].get("meetings", [])
	var meeting: Dictionary = meetings[2]
	var pending: Dictionary = {"paid": state == "paid",
		"answer": "ui.hollow.message.paneLit" if state == "paid" else ""}
	var screen: HollowScreen = HollowScreen.new(pending, meeting, 3, meetings.size(),
		_shape, null, "duskblade")
	if state == "refused":
		screen.show_error("ui.hollow.message.needGold")
	return screen


func _event(event_id: String, story_beat: String) -> Control:
	if not _content.events.has(event_id):
		return null
	var event: Dictionary = _content.events[event_id]
	if story_beat.is_empty():
		return EventScreen.new(event_id, event, "", true, false, _shape)
	var key: String = "story.event-%s.%s" % [event_id, story_beat]
	var screen: EventScreen = EventScreen.new(event_id, event, Locale.active.t(key),
		false, true, _shape)
	screen.beat = story_beat
	screen.play_beat()
	return screen


## The battle dialogue over a still of the Act I stage, speaking the
## variant's own lines. `--freeze` is honoured as for the other screens.
func _battle(variant_id: String, death: bool) -> void:
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = load("res://assets/art/stage/act1-backdrop.png") as Texture2D
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(backdrop)
	var dialogue: BattleDialogue = BattleDialogue.new()
	dialogue.shape = _shape
	add_child(dialogue)
	var variant: Dictionary = _content.variants.get(variant_id, {})
	var row: Dictionary = BattleDialogue.staging_for(variant_id)
	var entries: Array[Dictionary] = []
	if death:
		entries.append({"text": str(variant.get("deathDialogue", "")),
			"direction": row.get("death", {})})
	else:
		var intro: Array = row.get("intro", [])
		var lines_v: Variant = variant.get("dialogue", [])
		var lines: Array = lines_v if typeof(lines_v) == TYPE_ARRAY else []
		for i: int in range(lines.size()):
			entries.append({"text": str(lines[i]).replace("{aspect}", "Duskblade"),
				"direction": intro[i] if i < intro.size() else {}})
	dialogue.speak(variant_id, str(variant.get("name", variant_id)), entries)
	_settle(dialogue)


## A staged screen photographed after `--freeze` seconds of its own clock.
func _settle(screen: Control) -> void:
	if _freeze < 0.0:
		return
	screen.set_process(false)
	var left: float = _freeze
	while left > 0.0:
		var step: float = minf(left, 1.0 / 60.0)
		screen.call("_process", step)
		left -= step


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
		_shape, null, {}, "duskblade")
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
