extends RefCounted
## The title as a place (docs/design/2026-10-02-opening-start, Concept A): the
## lantern is the primary action and names the route it takes, the launch rite
## obeys the one-tap and Reduce Motion rules, first launch holds at the ember
## for the language and records the consent notice, and the wordmark is the
## authored raster for each locale that has one.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_title_screen: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous_locale: Locale = Locale.active
	var previous_prefs: Preferences = Preferences.active
	Locale.active = Locale.new(Locale.CODE_EN)
	Preferences.active = Preferences.new()
	_primary_follows_the_save(fails)
	_rite_one_tap(fails)
	_rite_reduce_motion(fails)
	_first_launch(fails)
	_wordmark(fails)
	_leaving(fails)
	Locale.active = previous_locale
	Preferences.active = previous_prefs


static func _choices(saved: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if saved:
		rows.append({"id": "continue", "label": "Back to the Road"})
	for id: String in ["begin", "vigil", "help", "settings", "credits", "quit"]:
		rows.append({"id": id, "label": id})
	return rows


static func _screen(context: Dictionary) -> TitleScreen:
	var screen: TitleScreen = TitleScreen.new(context)
	screen.size = Vector2(1180, 820)
	return screen


static func _primary_follows_the_save(fails: Array[String]) -> void:
	var saved: TitleScreen = _screen({"choices": _choices(true), "sub": "Act 2 · Waystone 4"})
	_check(fails, saved.primary_id() == "continue" and saved.plaque_text() == "BACK TO THE ROAD",
		"a saved run puts Back to the Road on the lantern")
	_check(fails, saved.offers("begin") and saved.offers("settings") and saved.offers("quit"),
		"a saved run still offers Rekindle and the utilities")
	var picked: Array[String] = []
	saved.chosen.connect(func(id: String) -> void: picked.append(id))
	saved.lantern.pressed.emit()
	_check(fails, picked == ["continue"], "the lantern takes the saved run's route")
	saved.free()
	var fresh: TitleScreen = _screen({"choices": _choices(false)})
	_check(fails, fresh.primary_id() == "begin" and fresh.plaque_text() == "BEGIN",
		"a fresh install puts the begin route on the lantern")
	fresh.free()


## The first tap of a rite completes it and chooses nothing.
static func _rite_one_tap(fails: Array[String]) -> void:
	Preferences.active.reduce_motion = false
	var screen: TitleScreen = _screen({"choices": _choices(true), "rite": true})
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.kindle_now()
	_check(fails, screen.rite != null and screen.rite.is_running(), "the first title kindles")
	var picked: Array[String] = []
	screen.chosen.connect(func(id: String) -> void: picked.append(id))
	screen.lantern.pressed.emit()
	_check(fails, picked.is_empty() and screen.rite.is_done(),
		"a tap during the rite lands it and chooses nothing")
	_check(fails, is_equal_approx(screen.lantern.kindle, 1.0) and is_equal_approx(screen.world.lamplight, 1.0),
		"a landed rite leaves the lantern lit and every roadside lamp burning")
	screen.lantern.pressed.emit()
	_check(fails, picked == ["continue"], "after the rite the lantern chooses")
	screen.queue_free()


static func _rite_reduce_motion(fails: Array[String]) -> void:
	Preferences.active.reduce_motion = true
	var screen: TitleScreen = _screen({"choices": _choices(false), "rite": true})
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.kindle_now()
	_check(fails, screen.rite != null and screen.rite.is_done()
			and is_equal_approx(screen.lantern.kindle, 1.0),
		"Reduce Motion lands the title whole, with no wait")
	screen.queue_free()
	Preferences.active.reduce_motion = false


static func _first_launch(fails: Array[String]) -> void:
	var prefs: Preferences = Preferences.new()
	var screen: TitleScreen = TitleScreen.new({"choices": _choices(false), "rite": true,
		"ask_language": true, "language_default": "zh-Hant", "ask_consent": true}, null, prefs)
	screen.size = Vector2(1180, 820)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.kindle_now()
	_check(fails, screen.rite != null, "first launch kindles")
	if screen.rite == null:
		screen.queue_free()
		return
	screen.rite.advance(2.0)
	_check(fails, screen.rite.held(), "first launch holds the rite at the ember for the language")
	_check(fails, not prefs.diagnostics_notice_seen,
		"a consent line held unlit at the ember must not record the notice")
	_check(fails, screen.find_child("FirstLightConsent", true, false) != null
			and screen.find_child("DiagnosticsToggle", true, false) is Button,
		"the consent line carries its switch")
	var picked: Array[StringName] = []
	screen.language_chosen.connect(func(code: StringName) -> void: picked.append(code))
	var chosen: Array[String] = []
	screen.chosen.connect(func(id: String) -> void: chosen.append(id))
	screen.lantern.pressed.emit()
	_check(fails, picked == [&"zh-Hant"] and chosen.is_empty(),
		"the flame tapped at the ember accepts the pre-lit language and starts nothing")
	screen.resume_after_language()
	screen.rite.advance(5.0)
	_check(fails, screen.rite.is_done(), "the rite runs on once the language is answered")
	_check(fails, prefs.diagnostics_notice_seen, "the consent line, lit, records the notice")
	screen.queue_free()


## Moved from test_locale (the title was ChoiceScreen's variant until
## 2026-10-02): each authored raster paints at every shipping shape.
static func _wordmark(fails: Array[String]) -> void:
	for row: Array in [["GLASSVOW", TitleScreen.WORDMARK_EN, "pad-landscape"],
			["琉璃誓言", TitleScreen.WORDMARK_ZH, "pad-landscape"],
			["琉璃誓言", TitleScreen.WORDMARK_ZH, "phone-landscape"]]:
		var screen: TitleScreen = _screen({"choices": _choices(false), "brand": row[0], "shape": row[2]})
		var art: TextureRect = null
		for node: Node in screen.find_children("", "TextureRect", false, false):
			if (node as TextureRect).texture == load(str(row[1])):
				art = node as TextureRect
		_check(fails, art != null, "%s paints its authored wordmark at %s" % [row[0], row[2]])
		screen.free()
	var other: TitleScreen = _screen({"choices": _choices(false), "brand": "GLASVOGT"})
	var label: Label = null
	for node: Node in other.find_children("", "Label", false, false):
		if (node as Label).text == "GLASVOGT":
			label = node as Label
	_check(fails, label != null and label.get_theme_font("font").has_char("誓".unicode_at(0)),
		"a locale with no authored raster paints its catalogue title in the display face")
	other.free()


## Once the lantern's route is taken the title takes no other choice, and a
## tap hurries the light carrying it away.
static func _leaving(fails: Array[String]) -> void:
	var screen: TitleScreen = _screen({"choices": _choices(true)})
	var picked: Array[String] = []
	screen.chosen.connect(func(id: String) -> void: picked.append(id))
	var hurried: Array[bool] = [false]
	screen.hurry.connect(func() -> void: hurried[0] = true)
	screen.leave()
	screen.lantern.pressed.emit()
	var settings: Button = screen._words["settings"]
	settings.pressed.emit()
	_check(fails, picked.is_empty(), "a leaving title takes no further choice")
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	screen._on_catcher_input(tap)
	_check(fails, hurried[0], "a tap on a leaving title hurries its transition")
	screen.free()
