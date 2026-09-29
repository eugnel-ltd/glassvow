extends RefCounted
## ScenePlayer: DawnScreen's handshake, lifted. A line is never shown before
## it is owed, skip is distinct from tap, and missing plates still play.

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scene_player: %s" % what)


static func run(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	_fresh_asks_once(fails, opening)
	_holds_without_confirm(fails, opening)
	_resume(fails, opening)
	_skip_distinct_from_tap(fails, opening)
	_skip_dwells_on_named_beat(fails, opening)
	_skip_floor_once_from_destination(fails, opening)
	_real_input_advances(fails, opening)
	_finished_once(fails)
	_missing_plates(fails, opening)
	_dwell_reads_the_line(fails, opening)
	_skip_lands_a_typing_line(fails, opening)


static func _fresh_asks_once(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 0, asked)
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l1"),
		"fresh player is not on line 0")
	_check(fails, _text(player, "Speaker") == Locale.active.t("ui.scene.speaker.keeper"),
		"line 0 lost its speaker")
	_check(fails, asked[0] == 1, "fresh player did not ask once (got %d)" % asked[0])
	player.free()


static func _holds_without_confirm(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 0, asked)
	player._process(10.0)
	_check(fails, asked[0] == 1, "unconfirmed wait asked again (got %d)" % asked[0])
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l1"),
		"cursor advanced without confirm")
	player.advance_confirmed()
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b1.l2"),
		"confirm did not reveal the next owed line")
	player._process(0.016)
	_check(fails, asked[0] == 2, "confirm did not ask for the next line")
	player.free()


static func _resume(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(opening, 6, asked, done)
	_check(fails, _text(player, "Line") == Locale.active.t("story.opening.b3.l1"),
		"resumed cursor is not on the owed line")
	_check(fails, _text(player, "Speaker") == "", "resumed narration grew a speaker")
	_check(fails, done[0] == 0, "a mid-scene resume fired finished")
	player.free()


## 07-scenes §1: a tap lands a line still typing (提前完成 reveal) and only a
## tap on a standing line steps (即時推進) — one tap never costs a line the
## player has not seen whole, and never moves more than one.
static func _skip_distinct_from_tap(fails: Array[String], opening: SceneScript) -> void:
	var tapped: Array[int] = [0]
	var tap: ScenePlayer = ScenePlayer.new(opening, 0)
	tap.advance_requested.connect(func() -> void: tapped[0] += 1)
	tap._ready()
	tap._press(true)
	tap._process(0.05)
	tap._press(false)
	_check(fails, tapped[0] == 0, "a tap mid-reveal stepped past a line still typing")
	_check(fails, is_equal_approx(tap._copy.modulate.a, 1.0), "a tap did not land the line")
	_check(fails, tap._copy.is_complete() and tap._line.visible_characters == -1,
		"a tap left the line half-typed")
	_check(fails, tap._beat == ScenePlayer.BEAT_WAIT, "a tap did not stand the line")
	tap._press(true)
	tap._press(false)
	_check(fails, tapped[0] == 1, "a tap on a standing line did not ask")
	tap.advance_confirmed()
	_check(fails, tap._beat == ScenePlayer.BEAT_REVEAL,
		"a tap left skip armed (next line was instant)")
	tap.free()
	var skipped: Array[int] = [0]
	var hold: ScenePlayer = ScenePlayer.new(opening, 0)
	hold.advance_requested.connect(func() -> void: skipped[0] += 1)
	hold._ready()
	hold._process(ScenePlayer.REVEAL_TIME + 0.01)
	hold._press(true)
	hold._process(ScenePlayer.SKIP_HOLD)
	_check(fails, skipped[0] == 1, "a skip hold did not ask")
	_check(fails, hold._skipping, "a skip hold did not arm skip")
	hold._press(false)
	hold.advance_confirmed()
	_check(fails, hold._beat == ScenePlayer.BEAT_WAIT,
		"skip did not land the next line standing")
	hold.free()


static func _skip_dwells_on_named_beat(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(opening, 0)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	player._process(ScenePlayer.REVEAL_TIME + 0.01)
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD)
	_check(fails, player.skipped, "skip hold did not mark skipped")
	player._press(false)
	# Beat ① line 1 still uses the 40 ms skip wait.
	player.advance_confirmed()
	player._process(ScenePlayer.SKIP_WAIT + 0.01)
	_check(fails, asked[0] == 2, "beat ① skip wait did not ask (got %d)" % asked[0])
	# Beat ② holds ~1 s so the destination is named under skip.
	player.advance_confirmed()
	player._process(0.5)
	_check(fails, asked[0] == 2, "beat ② skip asked before the 1 s floor")
	player._process(0.6)
	_check(fails, asked[0] == 3, "beat ② skip did not ask after the 1 s floor")
	player.free()


## Hold-skip that arms on beat ② itself must still owe the 1 s floor (the
## emit-on-arm path used to skip it), and later lines of that beat must not
## stack another 1 s — the design is a per-beat floor on the destination.
static func _skip_floor_once_from_destination(
		fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(opening, 2)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	_settle(player)
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD)
	_check(fails, player._skipping, "hold from beat ② did not arm skip")
	_check(fails, asked[0] == 0,
		"hold-skip on beat ② asked on arm, bypassing the destination floor")
	player._process(0.30)
	_check(fails, asked[0] == 0,
		"hold-skip on beat ② asked before the 1 s floor (got %d)" % asked[0])
	player._process(0.20)
	_check(fails, asked[0] == 1,
		"hold-skip on beat ② did not ask after the 1 s floor (got %d)" % asked[0])
	player._press(false)
	player.advance_confirmed()
	player._process(ScenePlayer.SKIP_WAIT + 0.01)
	_check(fails, asked[0] == 2,
		"later lines of beat ② stacked another floor (got %d)" % asked[0])
	player.free()


## `_press` is an implementation detail. Click, Space and Enter have to reach
## it through `_gui_input` / `_unhandled_key_input` or the suite stays green
## with a player that cannot be driven.
static func _real_input_advances(fails: Array[String], opening: SceneScript) -> void:
	_check(fails, _ask_via_input(opening, _mouse_tap()) == 1,
		"a real mouse click did not ask")
	_check(fails, _ask_via_input(opening, _key_tap(KEY_SPACE)) == 1,
		"a real Space key did not ask")
	_check(fails, _ask_via_input(opening, _key_tap(KEY_ENTER)) == 1,
		"a real Enter key did not ask")


static func _finished_once(fails: Array[String]) -> void:
	var short: SceneScript = _script("unsealing-short")
	if short == null:
		_check(fails, false, "unsealing-short did not load")
		return
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(short, 0, asked, done)
	_check(fails, done[0] == 0, "finished fired before the last confirm")
	player.advance_confirmed()
	_check(fails, done[0] == 1, "finished did not fire on the last confirm")
	player.advance_confirmed()
	_check(fails, done[0] == 1, "finished fired more than once")
	player.free()


## A beat whose art is missing must still draw and still finish. The fixture
## names a path that cannot exist rather than borrowing the real opening: that
## borrowed version passed only while the plates were unrendered, and #310
## shipping them inverted it. The behaviour under test does not depend on which
## art happens to be on disk today, so neither should the test.
static func _missing_plates(fails: Array[String], opening: SceneScript) -> void:
	var raw: Dictionary = {"beats": [{
		"art": "res://assets/art/scenes/__no_such_plate__.png",
		"motion": "hold",
		"lines": [{"key": "story.opening.b1.l1"}],
	}]}
	var built: Variant = SceneScript.parse_scene("missing-plate-fixture", raw)
	if not (built is SceneScript):
		_check(fails, false, "missing-plate fixture did not parse: %s" % str(built))
		return
	var script: SceneScript = built
	var asked: Array[int] = [0]
	var done: Array[int] = [0]
	var player: ScenePlayer = _live(script, 0, asked, done)
	var plate: TextureRect = player.find_child("Plate", true, false) as TextureRect
	_check(fails, plate != null and plate.texture == null,
		"absent plates did not degrade to an empty plate")
	var steps: int = 0
	while done[0] == 0 and steps < script.line_count() + 1:
		player.advance_confirmed()
		player._process(0.016)
		steps += 1
	_check(fails, done[0] == 1, "a no-plate scene did not finish")
	player.free()
	_check(fails, opening.line_count() > 0, "the real opening script is empty")


## A long line must hold longer than a short one, and a hands-off player must
## never be walked past a line the reveal has only just settled.
static func _dwell_reads_the_line(fails: Array[String], opening: SceneScript) -> void:
	var player: ScenePlayer = ScenePlayer.new(opening, 0)
	player._ready()
	var line: Label = player.find_child("Line", true, false) as Label
	if line == null:
		_check(fails, false, "no line label to pace")
		player.free()
		return
	line.text = "12345678"
	var short_dwell: float = player._dwell()
	line.text = "123456789012345678901234567890"
	var long_dwell: float = player._dwell()
	_check(fails, long_dwell > short_dwell + 1.0,
		"dwell does not scale with the line (%.2f vs %.2f)" % [short_dwell, long_dwell])
	_check(fails, short_dwell > ScenePlayer.REVEAL_TIME,
		"a settled line is owed less dwell than its own reveal (%.2f)" % short_dwell)
	_check(fails, is_equal_approx(short_dwell,
		ScenePlayer.DWELL_BASE + ScenePlayer.DWELL_PER_CHAR * 8.0),
		"dwell is not base + per-character")
	player.free()
	var asked: Array[int] = [0]
	var waiting: ScenePlayer = ScenePlayer.new(opening, 0)
	waiting.instant = false
	waiting.advance_requested.connect(func() -> void: asked[0] += 1)
	waiting._ready()
	var paced: Label = waiting.find_child("Line", true, false) as Label
	if paced == null:
		_check(fails, false, "no line label to wait on")
		waiting.free()
		return
	paced.text = "12345678"
	waiting._process(ScenePlayer.REVEAL_TIME + 0.01)
	_check(fails, asked[0] == 0, "asked during reveal before dwell")
	waiting._process(short_dwell - 0.08)
	_check(fails, asked[0] == 0,
		"asked before a short line's dwell elapsed")
	waiting._process(0.16)
	_check(fails, asked[0] == 1,
		"did not ask after a short line's dwell elapsed")
	waiting.free()


## Let the owed line finish typing, and no more: the wait starts fresh.
static func _settle(player: ScenePlayer) -> void:
	var steps: int = 0
	while player._beat == ScenePlayer.BEAT_REVEAL and steps < 400:
		player._process(0.02)
		steps += 1


## Holding from the very first frame of a line lands it whole at the arm,
## and the fast-forward then steps on the short skip wait.
static func _skip_lands_a_typing_line(fails: Array[String], opening: SceneScript) -> void:
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(opening, 0)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	player._press(true)
	player._process(ScenePlayer.SKIP_HOLD)
	_check(fails, player._skipping and player._beat == ScenePlayer.BEAT_WAIT,
		"a skip that armed mid-reveal left the line typing")
	_check(fails, player._line.visible_characters == -1,
		"a skip that armed mid-reveal did not land the whole line")
	player._process(ScenePlayer.SKIP_WAIT + 0.01)
	_check(fails, asked[0] == 1, "a skip that armed mid-reveal did not step")
	player.free()


static func _live(script: SceneScript, cursor: int, asked: Array[int],
		done: Array[int] = []) -> ScenePlayer:
	var player: ScenePlayer = ScenePlayer.new(script, cursor)
	player.instant = true
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	if not done.is_empty():
		player.finished.connect(func() -> void: done[0] += 1)
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


static func _text(player: ScenePlayer, node_name: String) -> String:
	var node: Label = player.find_child(node_name, true, false) as Label
	return node.text if node != null else ""


static func _ask_via_input(opening: SceneScript, events: Array[InputEvent]) -> int:
	var asked: Array[int] = [0]
	var player: ScenePlayer = ScenePlayer.new(opening, 0)
	player.advance_requested.connect(func() -> void: asked[0] += 1)
	player._ready()
	_settle(player)
	for event: InputEvent in events:
		if event is InputEventMouseButton:
			player._gui_input(event)
		else:
			player._unhandled_key_input(event)
	player.free()
	return asked[0]


static func _mouse_tap() -> Array[InputEvent]:
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	var events: Array[InputEvent] = []
	events.append(down)
	events.append(up)
	return events


static func _key_tap(keycode: Key) -> Array[InputEvent]:
	var down: InputEventKey = InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	var up: InputEventKey = InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	var events: Array[InputEvent] = []
	events.append(down)
	events.append(up)
	return events
