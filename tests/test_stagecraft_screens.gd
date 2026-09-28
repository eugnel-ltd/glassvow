extends RefCounted
## Stagecraft beyond the scripted scenes: foes that speak in battle, the
## Hollow Lamplighter's price, and the road events. Staging data fails closed
## and matches real content; the screens keep every contract their callers
## and older tests read; and the pane lays its text out even when it is placed
## before the screen enters the tree (the Hollow regression).

static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("stagecraft_screens: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_pane_places_out_of_tree(fails)
	_battle_lines_match_content(fails, content)
	_battle_lines_fail_closed(fails)
	_hollow_two_shot(fails, content)
	_event_staging_matches_content(fails, content)
	_event_screen_contract(fails, content)
	_battle_dialogue_holds_the_fight(fails)


## While a foe speaks, the advance keys belong to its pane: Space and Enter
## neither pick nor play a card, and E does not end the turn beneath it.
static func _battle_dialogue_holds_the_fight(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, 56503))
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling", "sporeling"], "normal", "stagecraft-keys")
	_check(fails, screen._dialogue._sfx != null,
		"a combat screen that owns its bus handed its foes' voices none")
	var turn: int = game.cb.turn
	var hand: int = game.cb.hand.size()
	var lantern: Vector2 = screen._hud.lantern_rect().get_center()
	_check(fails, not screen._tip_at(lantern).is_empty(),
		"the lantern offers no tip to gate (fixture)")
	screen._dialogue.visible = true
	_check(fails, screen._tip_at(lantern).is_empty(),
		"a tip can pop over a speaking foe's pane")
	_check(fails, screen._dialogue.speaking(), "a shown pane does not count as speaking")
	for key: Key in [KEY_SPACE, KEY_ENTER, KEY_SPACE, KEY_E, KEY_A, KEY_RIGHT]:
		_check(fails, not screen._combat_key(key),
			"key %s reached the fight while a foe spoke" % OS.get_keycode_string(key))
	_check(fails, screen._selected_uid < 0 and game.cb.hand.size() == hand
			and game.cb.turn == turn and not screen.seq.is_busy(),
		"the fight moved beneath a speaking foe")
	screen._dialogue.visible = false
	_check(fails, screen._combat_key(KEY_SPACE) and screen._selected_uid >= 0,
		"the hand did not answer Space once the foe fell silent")
	tree.root.remove_child(screen)
	screen.free()


static func _pane_places_out_of_tree(fails: Array[String]) -> void:
	var box: DialogueBox = DialogueBox.new()
	box.show_line("A line long enough to wrap if the pane were never laid out.",
		"", StageDirection.STYLE_SPEECH, RunStyle.GOLD, &"left", true)
	box.place(Rect2(40.0, 600.0, 900.0, 150.0))
	_check(fails, box.line_label().visible_characters_behavior
			== TextServer.VC_CHARS_AFTER_SHAPING,
		"the reveal trims before shaping, so the wrap reflows as it types")
	_check(fails, box.line_label().size.x > 600.0,
		"a pane placed before the tree kept a collapsed text column (%.0f px)"
			% box.line_label().size.x)
	box.free()


static func _battle_lines_match_content(fails: Array[String], content: ContentDB) -> void:
	var loaded: Variant = BattleDialogue.load_file(BattleDialogue.PATH)
	_check(fails, typeof(loaded) == TYPE_DICTIONARY, "battle-lines did not load: %s" % str(loaded))
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var rows: Dictionary = loaded
	_check(fails, not rows.is_empty(), "battle-lines stages nobody")
	var book: ActorBook = ActorBook.shared()
	for id_v: Variant in rows:
		var id: String = str(id_v)
		_check(fails, content.variants.has(id), "battle-lines stages unknown variant %s" % id)
		var row: Dictionary = rows[id_v]
		var actor: String = str(row["actor"])
		_check(fails, not str(book.resolve(actor, "default")["path"]).is_empty(),
			"%s speaks through %s, who has no drawable body" % [id, actor])
		var variant: Dictionary = content.variants.get(id, {})
		var said_v: Variant = variant.get("dialogue", [])
		var said: Array = said_v if typeof(said_v) == TYPE_ARRAY else []
		var intro: Array = row["intro"]
		_check(fails, intro.size() <= said.size(),
			"%s stages %d intro lines but speaks %d" % [id, intro.size(), said.size()])
		var death: Dictionary = row["death"]
		_check(fails, death.is_empty() or not str(variant.get("deathDialogue", "")).is_empty(),
			"%s stages a death line it never speaks" % id)
	for id_v: Variant in content.variants:
		var variant: Dictionary = content.variants[id_v]
		var lines_v: Variant = variant.get("dialogue", [])
		var lines: Array = lines_v if typeof(lines_v) == TYPE_ARRAY else []
		var speaks: bool = not lines.is_empty()
		speaks = speaks or not str(variant.get("deathDialogue", "")).is_empty()
		_check(fails, not speaks or rows.has(str(id_v)),
			"variant %s speaks in battle but is not staged" % id_v)


static func _battle_lines_fail_closed(fails: Array[String]) -> void:
	var book: ActorBook = ActorBook.shared()
	for bad: Variant in [
		{"speakers": {"x": {"actor": "nobody"}}},
		{"speakers": {"x": {"actor": "shade", "intro": [{"fx": ["confetti"]}]}}},
		{"speakers": {"x": {"actor": "shade", "death": {"style": "yodel"}}}},
		{"speakers": {"x": {"actor": "shade", "intro": {"fx": []}}}},
	]:
		_check(fails, typeof(BattleDialogue.parse(bad, book)) == TYPE_STRING,
			"battle-lines accepted %s" % str(bad))


static func _hollow_two_shot(fails: Array[String], content: ContentDB) -> void:
	var meetings: Array = content.quests["hollowLamplighter"].get("meetings", [])
	var meeting: Dictionary = meetings[2]
	var screen: HollowScreen = HollowScreen.new({"paid": false, "answer": ""},
		meeting, 3, meetings.size(), StageShape.IDENTITY, null, "ashwarden")
	_check(fails, screen._stage.has_actor("hero") and screen._stage.has_actor("lamplighter"),
		"the price is not a two-shot")
	var lamp: StagePortrait = screen._stage.portrait("lamplighter")
	_check(fails, lamp != null and lamp.mood == HollowScreen.MOOD_ASK and lamp.lit(),
		"the Lamplighter does not ask, lit")
	_check(fails, screen._ask.text == "“%s”" % str(meeting.get("ask", "")),
		"the ask is not the meeting's own line in the pane")
	_check(fails, screen._copy.speaker_label().text == Locale.active.t("ui.scene.speaker.lamplighter"),
		"the ask lost the Lamplighter's plaque")
	_check(fails, screen._continue.disabled and not screen._pay.disabled,
		"an unpaid price does not offer payment first")
	screen.show_error("ui.hollow.message.needGold")
	_check(fails, lamp.mood == HollowScreen.MOOD_REFUSED and not screen._error.text.is_empty(),
		"a refused price did not turn him wary with the reason shown")
	_check(fails, screen._ask.text == "“%s”" % str(meeting.get("cannot", "")),
		"a refused price is not answered in his own words")
	screen.set_paid(true, "ui.hollow.message.paneLit")
	_check(fails, lamp.mood == HollowScreen.MOOD_PAID and screen._error.text.is_empty()
			and not screen._continue.disabled,
		"a paid price did not settle into recognition and let you continue")
	_check(fails, screen._ask.text == "“%s”" % str(meeting.get("paid", "")),
		"a paid price is not answered in his own words")
	var resumed: HollowScreen = HollowScreen.new(
		{"paid": true, "answer": "ui.hollow.message.paneLit"},
		meeting, 3, meetings.size(), StageShape.IDENTITY, null, "ashwarden")
	_check(fails, resumed._ask.text == "“%s”" % str(meeting.get("paid", "")),
		"a resumed, paid meeting does not open on his answer")
	resumed.free()
	var first: Dictionary = meetings[0]
	var promised: HollowScreen = HollowScreen.new(
		{"paid": true, "deferred": true, "answer": "ui.hollow.message.emberDebt"},
		first, 1, meetings.size(), StageShape.IDENTITY, null, "ashwarden")
	_check(fails, promised._ask.text == "“%s”" % str(first.get("accepted", "")),
		"a promised price is not accepted in his own words")
	promised.free()
	screen.play_paid()
	_check(fails, screen._front.active(), "paying kindled nothing")
	screen.free()


static func _event_staging_matches_content(fails: Array[String], content: ContentDB) -> void:
	var loaded: Variant = EventScreen.load_staging(EventScreen.STAGING_PATH)
	_check(fails, typeof(loaded) == TYPE_DICTIONARY, "event-staging did not load: %s" % str(loaded))
	if typeof(loaded) != TYPE_DICTIONARY:
		return
	var rows: Dictionary = loaded
	for id_v: Variant in content.events:
		_check(fails, rows.has(str(id_v)), "event %s has no staging" % id_v)
	var en: Locale = Locale.new(Locale.CODE_EN)
	for id_v: Variant in rows:
		var id: String = str(id_v)
		_check(fails, content.events.has(id), "event-staging names unknown event %s" % id)
		var row: Dictionary = rows[id_v]
		var beats: Dictionary = row.get("beats", {})
		for beat_v: Variant in beats:
			var beat: String = str(beat_v)
			if beat.begins_with("roll-"):
				_check(fails, _has_roll_text(content, id, beat.trim_prefix("roll-")),
					"%s stages roll %s that narrates nothing" % [id, beat])
				continue
			var key: String = "story.event-%s.%s" % [id, beat]
			_check(fails, en.t(key) != key, "%s stages beat %s that has no prose" % [id, beat])
	_check(fails, typeof(EventScreen.load_staging("res://content/__none__.json")) == TYPE_STRING,
		"a missing staging file did not fail")


static func _has_roll_text(content: ContentDB, event_id: String, roll_id: String) -> bool:
	var event: Dictionary = content.events.get(event_id, {})
	var choices: Array = event.get("choices", [])
	for row_v: Variant in choices:
		var row: Dictionary = row_v
		var ops: Array = row.get("ops", [])
		for op_v: Variant in ops:
			var op: Dictionary = op_v
			var branches: Array = op.get("roll", [])
			for branch_v: Variant in branches:
				var branch: Dictionary = branch_v
				if str(branch.get("id", "")) == roll_id \
						and not str(branch.get("text", "")).is_empty():
					return true
	return false


static func _event_screen_contract(fails: Array[String], content: ContentDB) -> void:
	var event: Dictionary = content.events["mirror"]
	var choosing: EventScreen = EventScreen.new("mirror", event)
	_check(fails, choosing._body.text == str(event.get("text", "")),
		"the pane does not carry the event's own prose")
	var choices: Array = event.get("choices", [])
	_check(fails, choosing._buttons.size() == choices.size(),
		"the choice window lost a choice")
	_check(fails, choosing._art.texture != null
			and choosing._art.texture.resource_path.ends_with("events/mirror.png"),
		"the event painting is not the plate")
	_check(fails, not choosing._front.active(), "choosing played an effect")
	choosing.free()
	var prose: String = Locale.active.t("story.event-mirror.c1")
	var result: EventScreen = EventScreen.new("mirror", event, prose, false, true)
	result.beat = "c1"
	_check(fails, result._body.text == prose and result._completed
			and result._buttons.size() == 1,
		"a story beat does not show its prose with one way on")
	_check(fails, not result._front.active(), "a resumed beat replayed its effect")
	result.play_beat()
	_check(fails, result._front.active() or Preferences.active.reduce_motion,
		"the mirror's shattering beat played nothing")
	result.free()
