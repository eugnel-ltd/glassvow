extends RefCounted
## Stagecraft — the dialogue and cutscene layer over ScenePlayer. Directions
## fail closed; the stage folds to any cursor exactly as a playthrough built
## it; every authored actor, mood and effect target is registered; the pane
## and busts stay inside the frame at every shipping shape; the typed reveal
## paces CJK slower than Latin and breathes at stops; effects never fire where
## a line is not played live; and the opening keeps one Keeper body on screen.
## The flame's lines (flame lock §10): the Keeper names what the lantern burns
## as it is lit; the road's whispers play once each, after the won fight that
## read the change; and the codex shows the colours seen steady.

const SHAPES: Array[StringName] = [
	&"pad-landscape", &"desktop-landscape", &"phone-landscape",
]
const RUN_PATH: String = "user://test_stagecraft_flame_run_v2.json"
const VIGIL_PATH: String = "user://test_stagecraft_flame_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
## Starters plus these read Steady blue-white with a violet fringe (§4).
const STEADY_FRINGED: Array[String] = [
	"uppercut", "quakeblow", "warCry", "oblivionStrike", "limitBreak",
]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("stagecraft: %s" % what)


static func run(fails: Array[String]) -> void:
	_directions_fail_closed(fails)
	_fold_is_order_exact(fails)
	_actor_book(fails)
	_actor_book_fails_closed(fails)
	_scenes_cast_is_registered(fails)
	_names_resolve(fails)
	_pane_geometry(fails)
	_bust_geometry(fails)
	_reveal_pacing(fails)
	_capture_fires_nothing(fails)
	_opening_keeps_one_body(fails)
	_pool_rows(fails)
	_reel_covers_the_vocabulary(fails)
	_opening_names_the_lantern(fails)
	_flame_whispers(fails)
	_flame_lines_play_once(fails)
	_codex_in_the_help(fails)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


static func _line_scene(line: Dictionary, beat_extra: Dictionary = {}) -> Variant:
	var beat: Dictionary = {"motion": "hold", "lines": [line]}
	beat.merge(beat_extra)
	return SceneScript.parse_scene("stagecraft-fixture", {"beats": [beat]})


static func _directions_fail_closed(fails: Array[String]) -> void:
	var bad_lines: Array[Dictionary] = [
		{"key": "k", "style": "yodel"},
		{"key": "k", "enter": ["keeper"]},
		{"key": "k", "enter": ["keeper@balcony"]},
		{"key": "k", "enter": [{"id": "", "at": "left"}]},
		{"key": "k", "enter": [7]},
		{"key": "k", "exit": [""]},
		{"key": "k", "moods": ["tender"]},
		{"key": "k", "moods": {"keeper": ""}},
		{"key": "k", "fx": ["confetti"]},
		{"key": "k", "fx": ["slash@keeper"]},
		{"key": "k", "fx": ["hop@"]},
	]
	for line: Dictionary in bad_lines:
		_check(fails, typeof(_line_scene(line)) == TYPE_STRING,
			"accepted a malformed line %s" % str(line))
	for beat_extra: Dictionary in [{"transition": "wipe"}, {"ambient": "rain"},
			{"grade": "sepia"}]:
		_check(fails, typeof(_line_scene({"key": "k"}, beat_extra)) == TYPE_STRING,
			"accepted a malformed beat %s" % str(beat_extra))
	var good: Variant = _line_scene({"key": "k", "speaker": "keeper", "style": "shout",
		"enter": ["hero@left", {"id": "keeper", "at": "right", "mood": "tender"}],
		"exit": ["lamplighter"], "moods": {"hero": "default"},
		"fx": ["hop@keeper", "impact", "crack"], "sfx": "hit", "focus": "keeper"},
		{"transition": "wake", "ambient": "embers", "grade": "hearth"})
	_check(fails, good is SceneScript, "rejected a well-formed direction set: %s" % str(good))
	if good is SceneScript:
		var script: SceneScript = good
		var enters: Array = script.lines[0]["enter"]
		_check(fails, enters.size() == 2 and str(enters[1]["mood"]) == "tender",
			"enter shorthand and object forms did not normalise alike")
		var arrival: StringName = script.beats[0]["transition"]
		_check(fails, arrival == &"wake", "beat transition did not survive parsing")
	var plain: Variant = _line_scene({"key": "k"})
	var ambient: StringName = &""
	if plain is SceneScript:
		var plain_script: SceneScript = plain
		ambient = plain_script.beats[0]["ambient"]
	_check(fails, ambient == &"none", "a v1 beat did not default its stagecraft")


static func _fold_is_order_exact(fails: Array[String]) -> void:
	var lines: Array[Dictionary] = [
		{"key": "a", "enter": [{"id": "hero", "at": "left"},
			{"id": "keeper", "at": "right", "mood": "offering"}]},
		{"key": "b", "speaker": "keeper", "mood": "tender"},
		{"key": "c", "speaker": "lamplighter",
			"enter": [{"id": "lamplighter", "at": "right"}], "moods": {"hero": "grave"}},
		{"key": "d", "exit": ["*"]},
	]
	var at0: Dictionary = StageDirection.fold(lines, 0)
	var cast0: Array[Dictionary] = at0["cast"]
	_check(fails, cast0.size() == 2 and str(cast0[0]["id"]) == "hero"
			and str(cast0[1]["mood"]) == "offering",
		"fold at 0 did not seat the pair in seat order")
	_check(fails, str(at0["focus"]) == "", "narration lit someone")
	var at1: Dictionary = StageDirection.fold(lines, 1)
	var cast1: Array[Dictionary] = at1["cast"]
	_check(fails, str(cast1[1]["mood"]) == "tender" and str(at1["focus"]) == "keeper",
		"the speaker's own mood or light did not land")
	var at2: Dictionary = StageDirection.fold(lines, 2)
	var cast2: Array[Dictionary] = at2["cast"]
	var ids: Array[String] = []
	for seat: Dictionary in cast2:
		ids.append(str(seat["id"]))
	_check(fails, ids == ["hero", "lamplighter"],
		"a new body did not take the seat (got %s)" % str(ids))
	_check(fails, str(cast2[0]["mood"]) == "grave", "a listener's mood did not land")
	var at3: Dictionary = StageDirection.fold(lines, 3)
	var cast3: Array[Dictionary] = at3["cast"]
	_check(fails, cast3.is_empty(), "exit * left someone standing")


static func _actor_book(fails: Array[String]) -> void:
	var book: ActorBook = ActorBook.shared()
	for id: String in ["keeper", "lamplighter", "queue", "hero"]:
		_check(fails, book.has(id), "the registry lost %s" % id)
	var keeper: Dictionary = book.resolve("keeper", "default")
	var keeper_exact: bool = keeper["exact"]
	_check(fails, str(keeper["path"]).ends_with("meta/keeper.png") and keeper_exact,
		"the Keeper's default portrait is not the shipped hearth figure")
	var revealed: Dictionary = book.resolve("keeper", "revealed")
	var revealed_rim: StringName = revealed["rim"]
	_check(fails, str(revealed["path"]).ends_with("enemies/eternalKeeper.png")
			and revealed_rim == &"left",
		"the revealed Keeper is not the shipped boss form lit from the wrong side")
	var beckon: Dictionary = book.resolve("keeper", "beckon")
	var beckon_exact: bool = beckon["exact"]
	var beckon_art: String = "res://assets/art/portraits/keeper-beckon.png"
	if ResourceLoader.exists(beckon_art):
		_check(fails, str(beckon["path"]) == beckon_art and beckon_exact,
			"a landed mood portrait was not used")
	else:
		_check(fails, str(beckon["path"]).ends_with("enemies/eternalKeeper.png")
				and not beckon_exact,
			"a missing mood did not fall back along its chain")
	var unknown: Dictionary = book.resolve("keeper", "no-such-mood")
	_check(fails, str(unknown["path"]).ends_with("meta/keeper.png"),
		"an undeclared mood did not stand as the default")
	_check(fails, str(book.resolve("hero", "", "ashwarden")["path"])
			.ends_with("heroes/ashwarden.png"), "the hero did not wear the run's aspect")
	_check(fails, str(book.resolve("hero", "", "")["path"])
			.ends_with("heroes/%s.png" % ActorBook.HERO_FALLBACK),
		"the hero did not fall back outside a run")
	for id: String in book.actors:
		_check(fails, not str(book.resolve(id, "default", "duskblade")["path"]).is_empty()
				or id == "queue",
			"%s has no drawable default" % id)


static func _actor_book_fails_closed(fails: Array[String]) -> void:
	var base: Dictionary = {"portraits": {"default": "res://assets/art/meta/keeper.png"}}
	var bad: Array[Dictionary] = [
		{"side": "up"}, {"faces": "down"}, {"rim": "above"}, {"tint": "not-a-colour"},
		{"crop": [0.0, 0.0, 1.0]}, {"crop": [0.5, 0.5, 0.8, 0.8]},
		{"portraits": {"tender": "res://assets/art/meta/keeper.png"}},
		{"portraits": {"default": "res://content/scenes.json"}},
		{"portraits": {"default": "res://assets/art/meta/keeper.png",
			"x": {"art": "res://assets/art/meta/keeper.png", "fallback": "ghost"}}},
	]
	for patch: Dictionary in bad:
		var row: Dictionary = base.duplicate(true)
		row.merge(patch, true)
		_check(fails, typeof(ActorBook.parse({"actors": {"x": row}})) == TYPE_STRING,
			"the registry accepted %s" % str(patch))
	_check(fails, ActorBook.parse({"actors": {"x": base}}) is ActorBook,
		"the registry rejected a minimal actor")


## Every body, mood and effect target a scene names must be registered, or it
## plays as nothing at all — the silent failure this pins.
static func _scenes_cast_is_registered(fails: Array[String]) -> void:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		_check(fails, false, "scenes did not load")
		return
	var book: ActorBook = ActorBook.shared()
	var scenes: Dictionary = loaded
	var staged: int = 0
	for scene_id: Variant in scenes:
		var script: SceneScript = scenes[scene_id]
		for line: Dictionary in script.lines:
			var where: String = "%s/%s" % [scene_id, line["key"]]
			var speaker: String = str(line.get("speaker", ""))
			if not speaker.is_empty():
				_check(fails, book.has(speaker), "%s speaker %s is unregistered" % [where, speaker])
			var moods: Array[Array] = []
			var enters: Array = line.get("enter", [])
			for enter_v: Variant in enters:
				var enter: Dictionary = enter_v
				staged += 1
				_check(fails, book.has(str(enter["id"])),
					"%s enters unregistered %s" % [where, enter["id"]])
				moods.append([str(enter["id"]), str(enter.get("mood", ""))])
			if line.has("mood"):
				moods.append([speaker, str(line["mood"])])
			var listed: Dictionary = line.get("moods", {})
			for id: Variant in listed:
				moods.append([str(id), str(listed[id])])
			for pair: Array in moods:
				var mood: String = pair[1]
				if mood.is_empty() or not book.has(str(pair[0])):
					continue
				_check(fails, book.moods(str(pair[0])).has(mood),
					"%s asks %s for undeclared mood %s" % [where, pair[0], mood])
			var fx_list: Array = line.get("fx", [])
			for fx_v: Variant in fx_list:
				var target: String = StageDirection.fx_target(str(fx_v))
				_check(fails, target.is_empty() or book.has(target),
					"%s aims %s at unregistered %s" % [where, fx_v, target])
	_check(fails, staged > 0, "no scene stages a single body")


static func _names_resolve(fails: Array[String]) -> void:
	var book: ActorBook = ActorBook.shared()
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT), "zh-Hant catalogue did not load")
	for id: String in book.actors:
		var key: String = book.name_key(id)
		if key.is_empty():
			continue
		_check(fails, en.t(key) != key, "en did not resolve %s" % key)
		_check(fails, zh.t(key) != key, "zh-Hant did not resolve %s" % key)


static func _pane_geometry(fails: Array[String]) -> void:
	for stage_shape: StringName in SHAPES:
		var view: Vector2 = Vector2(StageShape.REFERENCES[stage_shape])
		var frame: Rect2 = Rect2(Vector2.ZERO, view)
		var band: float = view.y * (0.05 if stage_shape == &"phone-landscape" else 0.08)
		var pane: Rect2 = DialogueBox.box_rect(view, stage_shape, StageDirection.STYLE_SPEECH)
		_check(fails, frame.encloses(pane), "%s pane leaves the frame" % stage_shape)
		_check(fails, pane.end.y <= view.y - band,
			"%s pane sinks into the caption band" % stage_shape)
		_check(fails, pane.position.y >= view.y * 0.5,
			"%s pane climbs into the upper half" % stage_shape)
		_check(fails, pane.size.x >= view.x * 0.6,
			"%s pane is too narrow to read (%.0f)" % [stage_shape, pane.size.x])
		var title: Rect2 = DialogueBox.box_rect(view, stage_shape, StageDirection.STYLE_TITLE)
		_check(fails, frame.encloses(title) and title.end.y <= view.y - band,
			"%s title card leaves the frame" % stage_shape)
		if stage_shape != &"phone-landscape":
			var docked: Rect2 = DialogueBox.box_rect(view, stage_shape,
				StageDirection.STYLE_SPEECH, HearthFigure.SEAT_LEFT)
			_check(fails, docked.end.x <= view.x * HearthFigure.SEAT_LEFT,
				"%s pane does not keep clear of the hearth seat" % stage_shape)
			_check(fails, docked.size.x >= 480.0,
				"%s docked pane is too narrow" % stage_shape)


static func _bust_geometry(fails: Array[String]) -> void:
	var book: ActorBook = ActorBook.shared()
	for stage_shape: StringName in SHAPES:
		var view: Vector2 = Vector2(StageShape.REFERENCES[stage_shape])
		var band: float = view.y * (0.05 if stage_shape == &"phone-landscape" else 0.08)
		var pane: Rect2 = DialogueBox.box_rect(view, stage_shape, StageDirection.STYLE_SPEECH)
		for id: String in ["keeper", "lamplighter", "hero"]:
			var path: String = str(book.resolve(id, "default", "duskblade")["path"])
			var tex: Texture2D = load(path) as Texture2D
			if tex == null:
				_check(fails, false, "%s default art did not load" % id)
				continue
			var crop: Rect2 = book.crop(id)
			var aspect: float = tex.get_size().x * crop.size.x \
				/ maxf(tex.get_size().y * crop.size.y, 1.0)
			for at: StringName in [&"left", &"right"]:
				var bust: Rect2 = PortraitStage.bust_rect(view, stage_shape, at, aspect)
				_check(fails, bust.position.y >= band,
					"%s %s %s bust's head is under the letterbox" % [stage_shape, id, at])
				_check(fails, bust.end.y > pane.position.y,
					"%s %s %s bust floats above the pane" % [stage_shape, id, at])
			var left: Rect2 = PortraitStage.bust_rect(view, stage_shape, &"left", aspect)
			var right: Rect2 = PortraitStage.bust_rect(view, stage_shape, &"right", aspect)
			_check(fails, left.end.x <= right.position.x + 1.0,
				"%s %s two-shot overlaps itself" % [stage_shape, id])


static func _reveal_pacing(fails: Array[String]) -> void:
	var box: DialogueBox = DialogueBox.new()
	var tint: Color = RunStyle.GOLD
	box.show_line("abcdefghij", "", StageDirection.STYLE_SPEECH, tint, &"left", false)
	var latin: float = box.type_time()
	_check(fails, not box.is_complete() and box.line_label().visible_characters == 0,
		"a live line did not start hidden")
	box.show_line("一二三四五六七八九十", "", StageDirection.STYLE_SPEECH, tint, &"left", false)
	var cjk: float = box.type_time()
	_check(fails, cjk > latin * 1.5, "CJK does not type slower than Latin (%.2f vs %.2f)"
		% [cjk, latin])
	box.show_line("abcde fghij", "", StageDirection.STYLE_SPEECH, tint, &"left", false)
	var plain: float = box.type_time()
	box.show_line("abcde.fghij", "", StageDirection.STYLE_SPEECH, tint, &"left", false)
	_check(fails, box.type_time() >= plain + DialogueBox.PAUSE_STOP * 0.9,
		"a full stop does not breathe")
	var steps: int = 0
	while not box.advance_type(0.05) and steps < 200:
		steps += 1
	_check(fails, box.is_complete() and box.line_label().visible_characters == -1,
		"the reveal never landed the whole line")
	box.show_line("NOW!", "", StageDirection.STYLE_SHOUT, tint, &"left", false)
	_check(fails, box.is_complete(), "a shout typed instead of landing at once")
	box.reduce_motion = true
	box.show_line("abcdefghij", "", StageDirection.STYLE_SPEECH, tint, &"left", false)
	_check(fails, box.is_complete(), "reduced motion still typed the line")
	box.free()


## Capture and resume (a player built mid-scene) stand the stage without
## playing a single effect; a line reached live plays its own.
static func _capture_fires_nothing(fails: Array[String]) -> void:
	var node5: SceneScript = _script("act4-node5")
	if node5 == null:
		_check(fails, false, "act4-node5 did not load")
		return
	var still: ScenePlayer = _player(node5, 1, true)
	_check(fails, not still._director.front_fx.active(), "a capture fired the crack")
	_check(fails, still._director.stage.has_actor("keeper")
			and still._director.stage.has_actor("hero"),
		"a capture did not stand the two-shot")
	var keeper: StagePortrait = still._director.stage.portrait("keeper")
	_check(fails, keeper != null and keeper.mood == "revealed" and keeper.lit(),
		"the revealed Keeper is not lit in its own mood")
	var hero: StagePortrait = still._director.stage.portrait("hero")
	_check(fails, hero != null and not hero.lit(), "the listener is lit")
	still.free()
	var resumed: ScenePlayer = _player(node5, 1, false)
	_check(fails, not resumed._director.front_fx.active(),
		"a resumed line replayed its effects")
	_check(fails, resumed._director.stage.has_actor("keeper"),
		"a resumed line did not stand its cast")
	resumed.free()
	var live: ScenePlayer = _player(node5, 0, false)
	live.advance_confirmed()
	live._process(0.016)
	_check(fails, live._director.front_fx.active(), "a live line did not play its effects")
	for _i: int in range(90):
		live._process(1.0 / 60.0)
	var revealed: StagePortrait = live._director.stage.portrait("keeper")
	_check(fails, revealed != null and revealed.mood == "revealed"
			and is_equal_approx(revealed._sprite.modulate.a, 1.0)
			and not revealed._prev.visible,
		"the revealed Keeper stayed see-through after its crossfade")
	live.free()


## #334's rule, kept under the two-shot: the seated figure is the wide shot,
## the portrait the close-up, never both at once.
static func _opening_keeps_one_body(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	for cursor: int in range(opening.line_count()):
		var player: ScenePlayer = _player(opening, cursor, true)
		var figure: HearthFigure = player.find_child(HearthFigure.NAME, true, false) as HearthFigure
		var seated: bool = figure != null and figure.visible
		var portrait: bool = player._director.stage.has_actor("keeper")
		_check(fails, seated != portrait,
			"opening cursor %d shows %s" % [cursor,
				"two Keepers" if seated else "no Keeper"])
		var beat_i: int = opening.lines[cursor]["beat"]
		_check(fails, portrait == (beat_i == 1),
			"opening cursor %d is not the two-shot only on beat ②" % cursor)
		player.free()


static func _pool_rows(fails: Array[String]) -> void:
	var echo: ScenePlayer = ScenePlayer.new(SceneScript.pool_beat(""), 0,
		StageShape.IDENTITY, null, {"speaker": "walker", "en": "An echo.", "zh": "迴聲。"})
	echo.instant = true
	echo._ready()
	_check(fails, echo._copy.style == StageDirection.STYLE_WHISPER,
		"a walker's echo is not whispered")
	_check(fails, echo._speaker.text.is_empty(), "a walker's echo grew a name")
	_check(fails, echo._director.stage.standing().is_empty(), "a walker's echo grew a body")
	echo.free()
	var hearth: ScenePlayer = ScenePlayer.new(SceneScript.pool_beat(""), 0,
		StageShape.IDENTITY, null, {"speaker": "keeper", "en": "Rest.", "zh": "歇歇。"})
	hearth.instant = true
	hearth._ready()
	_check(fails, hearth._director.stage.has_actor("keeper"),
		"a Keeper pool line did not seat the Keeper")
	_check(fails, hearth._speaker.text == Locale.active.t("ui.scene.speaker.keeper"),
		"a Keeper pool line lost its name")
	hearth.free()


static func _reel_covers_the_vocabulary(fails: Array[String]) -> void:
	var reel: SceneScript = StagecraftLab.reel()
	_check(fails, reel != null, "the stagecraft reel does not parse")
	if reel == null:
		return
	var styles: Dictionary = {}
	var fx_seen: Dictionary = {}
	for line: Dictionary in reel.lines:
		styles[StageDirection.style_of(line)] = true
		var fx_list: Array = line.get("fx", [])
		for fx_v: Variant in fx_list:
			fx_seen[StageDirection.fx_name(str(fx_v))] = true
	for style: StringName in StageDirection.STYLES:
		_check(fails, styles.has(style), "the reel never shows style %s" % style)
	for fx: StringName in [&"kindle", &"crack", &"shatter", &"slash", &"impact",
			&"quake", &"hop", &"recoil", &"rays", &"flash"]:
		_check(fails, fx_seen.has(fx), "the reel never shows fx %s" % fx)


## The lantern is lit on 「帶上這個」: the Keeper's next line, in the same
## two-shot, is the only rule the player is ever given.
static func _opening_names_the_lantern(fails: Array[String]) -> void:
	var opening: SceneScript = _script("opening")
	if opening == null:
		_check(fails, false, "opening did not load")
		return
	var lit: int = -1
	for i: int in range(opening.line_count()):
		var fx_list: Array = opening.lines[i].get("fx", [])
		if fx_list.has("kindle@keeper"):
			lit = i
	_check(fails, lit >= 0 and lit + 1 < opening.line_count(),
		"the opening never kindles the lantern")
	if lit < 0 or lit + 1 >= opening.line_count():
		return
	var line: Dictionary = opening.lines[lit + 1]
	var line_beat: int = line["beat"]
	var lit_beat: int = opening.lines[lit]["beat"]
	_check(fails, str(line.get("key", "")) == "story.opening.b2.lantern"
			and str(line.get("speaker", "")) == "keeper" and line_beat == lit_beat,
		"the Keeper does not name what the lantern burns as it is lit")
	var player: ScenePlayer = _player(opening, lit + 1, true)
	_check(fails, player._copy.line_label().text == Locale.active.t("story.opening.b2.lantern")
			and player._director.stage.has_actor("keeper"),
		"the lantern's line is not the Keeper's, in the two-shot")
	player.free()


## The road's lines are heard, not seen: whispered, nameless, no body.
static func _flame_whispers(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	for slot: String in FlameLines.SPOKEN:
		var row: Dictionary = LineTable.row_by_id(content.line_table, slot)
		_check(fails, str(row.get("slot", "")) == slot, "no line answers %s" % slot)
		var whisper: ScenePlayer = ScenePlayer.new(SceneScript.pool_beat("", slot), 0,
			StageShape.IDENTITY, null, row)
		whisper.instant = true
		whisper._ready()
		_check(fails, whisper._copy.style == StageDirection.STYLE_WHISPER
				and whisper._speaker.text.is_empty()
				and whisper._director.stage.standing().is_empty(),
			"%s is not a whisper on an empty stage" % slot)
		_check(fails, whisper._copy.line_label().text
				== LineTable.text(row, Locale.active.code == Locale.CODE_ZH_HANT),
			"%s does not speak its row" % slot)
		whisper.free()


## After the won fight that read the first Steady (with its fringe), the two
## whispers play in turn, each once, then the reward; a later return to Steady
## replays nothing. A fall and a run-ending win keep the whispers owed, though
## the codex keeps the colour.
static func _flame_lines_play_once(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = _flame_main(content, "monster", 0)
	main.game.flame_events(true)
	main._on_combat_over("win")
	_check(fails, _flame_playing(main, "line:flame.steady")
			and main.game.run.pending_reward != null,
		"the first Steady did not whisper after its fight, before the reward")
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, loaded != null and typeof(loaded.pending_scene) == TYPE_DICTIONARY
			and str(loaded.pending_scene.get("id", "")) == "line:flame.steady",
		"the owed whisper is not a save the load contract accepts")
	main._on_scene_finished()
	_check(fails, _flame_playing(main, "line:flame.fringe"),
		"the fringe's whisper did not follow the first Steady's")
	main._on_scene_finished()
	_check(fails, main.game.run.pending_scene == null and main._reward_screen != null
			and main._vigil.scenes_seen.has("line:flame.steady")
			and main._vigil.scenes_seen.has("line:flame.fringe"),
		"the whispers did not hand on to the reward, heard")
	var run_state: RunState = main.game.run
	run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"empower", false))
	main.game.flame_events(true)
	run_state.player.deck.pop_back()
	main.game.flame_events(true)
	main._on_combat_over("win")
	_check(fails, main.game.run.pending_scene == null and main._reward_screen != null
			and run_state.pool_draws.count(FlameLines.SLOT_STEADY) == 1,
		"a second Steady in the run whispered again")
	_flame_dispose(main)
	var fallen: Main = _flame_main(content, "monster", 0)
	fallen.game.flame_events(true)
	fallen._on_combat_over("lose")
	_check(fails, not fallen.game.run.pool_beats.has(FlameLines.SLOT_STEADY)
			and fallen.game.run.pool_beats.has("codex.lantern.shatter")
			and not _flame_playing(fallen, "line:flame.steady"),
		"a fall spent the whisper, or lost the colour it saw")
	_flame_dispose(fallen)
	var ended: Main = _flame_main(content, "boss", 2)
	ended.game.flame_events(true)
	ended._on_combat_over("win")
	_check(fails, not ended.game.run.pool_beats.has(FlameLines.SLOT_STEADY)
			and ended.game.run.pool_beats.has("codex.lantern.shatter")
			and not _flame_playing(ended, "line:flame.steady"),
		"a run-ending win whispered to a walker who walks no further")
	_flame_dispose(ended)


## The Lantern's entry gains the colours seen steady, under its rules, and
## nothing before one is seen.
static func _codex_in_the_help(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var bare: HelpScreen = HelpScreen.new()
	_check(fails, bare.find_child("Coda", true, false) == null,
		"the codex showed a colour before one was seen")
	bare.free()
	var rows: Array[Dictionary] = [
		LineTable.row_by_id(content.line_table, "codex.lantern.shatter"),
		LineTable.row_by_id(content.line_table, "codex.lantern.edge"),
	]
	var zh: bool = Locale.active.code == Locale.CODE_ZH_HANT
	var help: HelpScreen = HelpScreen.new(StageShape.IDENTITY, null, rows)
	var coda: RichTextLabel = help.find_child("Coda", true, false) as RichTextLabel
	_check(fails, coda != null and coda.text
			== LineTable.text(rows[0], zh) + "\n" + LineTable.text(rows[1], zh),
		"the codex did not show the colours seen steady, one to a line")
	if coda != null:
		var breath: Node = coda.get_parent()
		var body: RichTextLabel = help._column.get_child(breath.get_index() - 1) as RichTextLabel
		_check(fails, body != null and body.text == Locale.active.t("ui.help.lanternBody")
				.replace("<b>", "[b]").replace("</b>", "[/b]"),
			"the colours are not under the Lantern's rules")
	help.free()


static func _flame_main(content: ContentDB, kind: String, act: int) -> Main:
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._run_save_path = RUN_PATH
	main._vigil_save_path = VIGIL_PATH
	main._vigil = VigilState.blank()
	main._vigil.scenes_seen.append("opening")
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	var run_state: RunState = RunState.new_run(content, 57701, "run-577-flame", {"aspect": 0})
	run_state.act = act
	for id: String in STEADY_FRINGED:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
	var foe: String = "sovereign" if kind == "boss" else "sporeling"
	var map: WorldMap = WorldMap.new()
	map.nodes.append(MapNode.make(kind, [foe], 0))
	map.at = 0
	run_state.node_id = map.nodes[0].id
	run_state.map = map.to_dict()
	run_state.pending_combat = kind
	run_state.pending_enemy_ids = [foe]
	main.game = GlassvowGame.new(content, run_state)
	main._map = map
	main.game.cb = CombatState.new()
	main.game.cb.kind = &"boss" if kind == "boss" else &"normal"
	return main


static func _flame_playing(main: Main, scene_id: String) -> bool:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	return player != null and player._script.id == scene_id


static func _flame_dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()


static func _player(script: SceneScript, cursor: int, still: bool) -> ScenePlayer:
	var player: ScenePlayer = ScenePlayer.new(script, cursor)
	player.instant = still
	player._ready()
	player._process(0.016)
	return player


static func _script(scene_id: String) -> SceneScript:
	var loaded: Variant = SceneScript.load_all()
	if typeof(loaded) != TYPE_DICTIONARY:
		return null
	var scenes: Dictionary = loaded
	var found: Variant = scenes.get(scene_id)
	return found if found is SceneScript else null
