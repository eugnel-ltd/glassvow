extends RefCounted
## Credits is the road onward (docs/design/2026-10-03-title-rooms §4.3, §11.1).
## At rest the roll drifts on its own after a still moment, never under Reduce
## Motion; a touch takes it over and it drifts again three seconds after; the
## eye's walk down the road never passes its two metres; the licences open in
## a glass of their own, built on first opening, and Return closes the glass
## before the room; no line carries a pack id; Act IV's titles are carved dots
## until the unsealing and the titles after it; the track now playing carries
## the flame. The held list is the music ledger's Act IV list. Every export
## packs the licence texts the credits read.

const SUITE: String = "res://tests/test_credits_roll.gd"
const STEP: float = 1.0 / 60.0
const LEDGER: String = "res://docs/music-ledger.md"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("credits_roll: %s" % what)


static func run(fails: Array[String]) -> void:
	_held_rows(fails)
	_now_playing(fails)
	_no_pack_ids(fails)
	_held_is_the_ledgers(fails)
	_walk_is_held(fails)
	_licences_ship(fails)
	TreeSuite.spawn(fails, SUITE)


## A file that is not an imported resource reaches a pack only through its
## preset's include filter: without it the iPad 8's Fonts glass read "licence
## file not found" for every family, and the engine glass lost Sentry's notice.
static func _licences_ship(fails: Array[String]) -> void:
	var presets: ConfigFile = ConfigFile.new()
	_check(fails, presets.load("res://export_presets.cfg") == OK, "export_presets.cfg does not load")
	var texts: Array[String] = [CreditsLicences.SENTRY_LICENCE]
	for entry: Dictionary in CreditsLicences.FONT_LICENCES:
		texts.append(str(entry["path"]))
	for section: String in presets.get_sections():
		if section.ends_with(".options"):
			continue
		var preset: String = str(presets.get_value(section, "name", section))
		var include: PackedStringArray = str(presets.get_value(section, "include_filter", "")).split(",", false)
		for path: String in texts:
			var packed: bool = false
			for pattern: String in include:
				packed = packed or path.trim_prefix("res://").match(pattern.strip_edges())
			_check(fails, packed, "the %s export leaves out %s" % [preset, path])


static func _held_rows(fails: Array[String]) -> void:
	var before: CreditsRoll = CreditsRoll.new(&"pad-landscape", false)
	var after: CreditsRoll = CreditsRoll.new(&"pad-landscape", true)
	for id: StringName in CreditsRoll.HELD_UNTIL_UNSEALING:
		var held: Label = before.find_child("Track_%s" % id, true, false) as Label
		var told: Label = after.find_child("Track_%s" % id, true, false) as Label
		_check(fails, held != null and held.text == CreditsRoll.HELD_MARK,
			"%s is told before the unsealing" % id)
		_check(fails, told != null and told.text != CreditsRoll.HELD_MARK and not told.text.is_empty(),
			"%s is still held after the unsealing" % id)
	var count: String = Locale.active.t("ui.credits.musicAttributionCount", {
		"count": CreditsRoll.wired_items(CreditsRoll._read_manifest(CreditsRoll.MUSIC_MANIFEST)).size()})
	_check(fails, _has_line(before, count), "the count line does not count the held titles")
	before.free()
	after.free()


static func _now_playing(fails: Array[String]) -> void:
	var playing: CreditsRoll = CreditsRoll.new(&"pad-landscape", true, &"title")
	_check(fails, playing.now_glyph != null and playing.now_glyph.get_parent()
			.find_child("Track_title", false, false) != null,
		"the track playing does not carry the flame")
	playing.free()
	var quiet: CreditsRoll = CreditsRoll.new(&"pad-landscape", false, &"act4Combat")
	_check(fails, quiet.now_glyph == null, "a held track playing shows its flame and so its place")
	quiet.free()
	var none: CreditsRoll = CreditsRoll.new()
	_check(fails, none.now_glyph == null, "a flame shows with nothing playing")
	none.free()


static func _no_pack_ids(fails: Array[String]) -> void:
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		var kept: Locale = Locale.active
		Locale.active = Locale.new(code)
		var credits: CreditsScreen = CreditsScreen.new()
		for node: Node in credits.find_children("*", "Label", true, false):
			var text: String = (node as Label).text
			_check(fails, not text.contains("stained-glass-v1") and not text.contains("ashglass-v1")
					and not text.contains("Ashglass Vigil"),
				"%s: a credits line shows a pack id or the theme line: %s" % [code, text])
		credits.free()
		Locale.active = kept


## The held titles are exactly the music ledger's Act IV cues in the manifest.
static func _held_is_the_ledgers(fails: Array[String]) -> void:
	var ledger: String = FileAccess.get_file_as_string(LEDGER)
	var listed: Array[Dictionary] = CreditsRoll.wired_items(CreditsRoll._read_manifest(CreditsRoll.MUSIC_MANIFEST))
	for item: Dictionary in listed:
		var id: String = str(item.get("id", ""))
		if id.begins_with("act4"):
			_check(fails, CreditsRoll.HELD_UNTIL_UNSEALING.has(StringName(id)),
				"the Act IV track %s is told before the unsealing" % id)
	for id: StringName in CreditsRoll.HELD_UNTIL_UNSEALING:
		var stem: String = ""
		for item: Dictionary in listed:
			if StringName(str(item.get("id", ""))) == id:
				stem = str(item.get("file", ""))
		_check(fails, not stem.is_empty() and ledger.contains(stem),
			"the held cue %s is not in the music ledger's Act IV list" % id)


static func _walk_is_held(fails: Array[String]) -> void:
	var world: TitleWorld = TitleWorld.new()
	world.walk = 5.0
	_check(fails, is_equal_approx(world.walk, TitleWorld.WALK_MAX), "the walk passes its two metres")
	world.walk = -1.0
	_check(fails, is_zero_approx(world.walk), "the walk goes back past the title's own place")
	world.free()


static func _has_line(roll: CreditsRoll, text: String) -> bool:
	for label: Label in roll.lines:
		if label.text == text:
			return true
	return false


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Preferences = Preferences.active
	Preferences.active = Preferences.new()
	await _drift(fails, tree, host)
	Preferences.active.reduce_motion = true
	await _still_under_reduced_motion(fails, tree, host)
	Preferences.active.reduce_motion = false
	await _walk_with_the_roll(fails, tree, host)
	await _licence_glass(fails, tree, host)
	Preferences.active = kept


static func _credits(tree: SceneTree, host: SubViewport) -> CreditsScreen:
	var credits: CreditsScreen = CreditsScreen.new(&"pad-landscape")
	host.add_child(credits)
	credits.set_process(false)
	credits.set_process_input(false)
	for _i: int in range(3):
		await tree.process_frame
	credits.rest(Vector2.ZERO, Color.WHITE)
	return credits


static func _step(credits: CreditsScreen, seconds: float) -> void:
	for _i: int in range(roundi(seconds / STEP)):
		credits._process(STEP)


static func _drift(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var credits: CreditsScreen = await _credits(tree, host)
	_step(credits, 1.0)
	_check(fails, credits.scroll().scroll_vertical == 0, "the roll drifted before a still moment")
	_step(credits, 1.2)
	var drifted: int = credits.scroll().scroll_vertical
	_check(fails, drifted > 0, "the roll did not drift at rest")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	credits._input(touch)
	_step(credits, 2.8)
	_check(fails, credits.scroll().scroll_vertical == drifted, "the roll drifted under a touch")
	_step(credits, 0.5)
	_check(fails, credits.scroll().scroll_vertical > drifted, "the drift did not resume three seconds after a touch")
	credits.queue_free()
	await tree.process_frame


static func _still_under_reduced_motion(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var credits: CreditsScreen = await _credits(tree, host)
	_step(credits, 4.0)
	_check(fails, credits.scroll().scroll_vertical == 0, "the roll drifts under Reduce Motion")
	credits.queue_free()
	await tree.process_frame


## The eye walks on with the roll, as far as the roll goes and no further.
static func _walk_with_the_roll(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var title: TitleScreen = TitleScreen.new({"shape": "pad-landscape", "choices": []}, null, Preferences.new())
	host.add_child(title)
	var credits: CreditsScreen = await _credits(tree, host)
	credits.title = title
	credits.rest(Vector2.ZERO, Color.WHITE)
	_check(fails, is_equal_approx(title.world.walk, CreditsScreen.FIRST_STEP), "the first step was not taken")
	credits.scroll().scroll_vertical = 100000
	await tree.process_frame
	_step(credits, 0.1)
	_check(fails, title.world.walk > CreditsScreen.FIRST_STEP and title.world.walk <= TitleWorld.WALK_MAX,
		"the walk does not follow the roll within two metres (%.2f)" % title.world.walk)
	credits.title_returns()
	_check(fails, is_zero_approx(title.world.walk) and title.wordmark().z_index == 0,
		"the road and the wordmark are not the title's again once Credits leaves")
	credits.queue_free()
	title.queue_free()
	await tree.process_frame


static func _licence_glass(fails: Array[String], tree: SceneTree, host: SubViewport) -> void:
	var credits: CreditsScreen = await _credits(tree, host)
	var closed: Array[int] = [0]
	credits.closed.connect(func() -> void: closed[0] += 1)
	credits.roll().font_pane.pressed.emit()
	var glass: CreditsLicences.Glass = credits.open_licence()
	_check(fails, glass != null and glass.visible, "the font licences did not open in their own glass")
	var families: String = ""
	for node: Node in credits._font_licence_wrap.find_children("*", "Label", true, false):
		families += (node as Label).text + "\n"
	for entry: Dictionary in CreditsScreen.FONT_LICENCES:
		_check(fails, families.contains(str(entry["family"])), "the font glass misses %s" % entry["family"])
	credits.leave()
	_check(fails, credits.open_licence() == null and closed[0] == 0,
		"Return closed the credits before the licence glass")
	credits.leave()
	_check(fails, closed[0] == 1, "Return did not close the credits once the glass was shut")
	credits.queue_free()
	await tree.process_frame
