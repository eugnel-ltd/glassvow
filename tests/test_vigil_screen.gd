extends RefCounted
## The Vigil as the hearth hall (docs/design/2026-10-03-title-rooms §4.1,
## §11.1). Laid out at every shape and every flex stage a device gives, in
## both languages, fresh, mid-way and full, on each of its looks (the full
## Vigil with the pane holding the longest dawn memory selected and thirty
## whispers heard):
##
## - the seat stands on the stage where its rule says, and every content rect
##   lies on the stage and clear of it (the phone soft-lock fixed);
## - every tap is at least 60×60 at pad and desktop and 44×44 on a phone, and
##   every text at least 18 px at pad and desktop; no web-modal panel remains;
## - progress prints as whole numbers ("2 / 5", never "2/3.0");
## - zh-Hant joins a deed's rewards with "、" and carves its counts in Chinese
##   numerals;
## - the first music cue is the Rose Window's when the Vigil opens on the rose,
##   and comes only once Main has connected (`announce`);
## - `Replay` exists, shows and has a size only when all six panes are whole;
## - the reading glass holds every archived memory in full, under the
##   inscription, and a dormant or armed pane's name gives nothing away;
## - in zh-Hant every Chinese character the hall sets is one the shipped
##   (subset) faces carry: a fresh Vigil's zero counts never draw as tofu.

const SUITE: String = "res://tests/test_vigil_screen.gd"
const Rubric: GDScript = preload("res://tests/test_rooms_rubric.gd")
const STATES: Array[String] = ["fresh", "mid", "full"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("vigil_screen: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_first_cue(fails, content)
	_replay_only_when_whole(fails, content)
	TreeSuite.spawn(fails, SUITE)


static func run_in_tree(tree: SceneTree, host: SubViewport, fails: Array[String]) -> void:
	var kept: Locale = Locale.active
	var content: ContentDB = ContentDB.load_full()
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		for entry: Array in Rubric.STAGES:
			var shape: StringName = entry[0]
			var stage: Vector2i = entry[1]
			host.size = stage
			for state: String in STATES:
				var vigil: VigilState = vigil_in(state, content)
				var screen: VigilScreen = VigilScreen.new(vigil, content, shape, false, null)
				screen.lend_seat(false)
				host.add_child(screen)
				screen.rest(Vector2.ZERO, LeadlightTokens.EMBER)
				await _frames(tree, 2)
				for look: StringName in [VigilHall.DEEDS, VigilHall.ROSE, VigilHall.EPITAPHS]:
					if not _show(screen, look):
						continue
					# The look whole at once: its change (V4) is the passage's to show.
					screen._finish_change()
					if look == VigilHall.ROSE and state == "full":
						screen.rose_view()._selected = _longest(screen.rose_view())
						screen.rose_view()._refresh_selection()
					await _frames(tree, 2)
					var where: String = "%s %dx%d %s %s" % [code, stage.x, stage.y, state, look]
					Rubric._rubric(fails, screen, shape, where)
					Rubric._clear_of_the_seat(fails, screen, shape, Vector2(stage), where)
					_figures(fails, screen, where)
					_nothing_overlaps(fails, screen, where)
					if look == VigilHall.ROSE and state == "full":
						_reading(fails, screen, where)
				if code == Locale.CODE_ZH_HANT and state == "mid":
					_carved_in_chinese(fails, screen, "%dx%d" % [stage.x, stage.y])
				if code == Locale.CODE_ZH_HANT and stage == Vector2i(1180, 820):
					_every_glyph_drawn(fails, screen, state)
				screen.queue_free()
				await tree.process_frame
	host.size = TreeSuite.STAGE
	Locale.active = kept


## A Vigil at `state`: fresh (nothing yet), mid (some deeds, three panes whole,
## one revealed, one armed, three epitaphs) or full (every deed, all six panes
## with every memory, the unsealing seen, thirty whispers, twelve epitaphs).
static func vigil_in(state: String, content: ContentDB) -> VigilState:
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append("opening")
	if state == "fresh":
		return vigil
	if state == "mid":
		for deed: Array in [["runs", 12], ["wins", 3], ["slain", 214], ["shatters", 15],
				["kindles", 11], ["perfects", 1], ["bestVow", 2]]:
			vigil.deeds[deed[0]] = deed[1]
		vigil.unlocks.assign(["emberglass", "aspect2"])
		vigil.shards.assign(["hollowLamplighter", "paleOnes", "usurper"])
		for id: String in ["hollowLamplighter", "paleOnes", "usurper"]:
			vigil.quests[id] = {"state": "complete", "progress": 3, "memory": {}}
		vigil.quests["unreadablePage"] = {"state": "revealed", "progress": 2, "memory": {}}
		vigil.quests["ownShade"] = {"state": "armed", "progress": 0, "memory": {}}
		vigil.whispers = 5
		vigil.defeat_epitaphs.assign(["pool.loss.e01", "pool.loss.e02", "pool.loss.e03"])
		return vigil
	for deed_v: Variant in content.deeds.values():
		var deed: Dictionary = deed_v
		vigil.deeds[str(deed.get("stat"))] = int(float(str(deed.get("n", 1))))
	vigil.deeds["runs"] = 41
	vigil.unlocks.assign(["emberglass", "aspect2", "lamplighter"])
	vigil.shards.assign(LeadlightRose.SHARDS)
	for id: String in LeadlightRose.SHARDS:
		var dawn: Array = []
		for part: String in ["p1", "p2", "p3", "p4", "done"]:
			var key: String = "story.dawn.%s.%s" % [id, part]
			if Locale.active.t(key) != key:
				dawn.append(key)
		vigil.quests[id] = {"state": "complete", "progress": 9, "memory": {"dawn": dawn}}
	vigil.scenes_seen.append("unsealing")
	vigil.whispers = 30
	for i: int in range(12):
		vigil.defeat_epitaphs.append("pool.loss.e%02d" % (i + 1))
	return vigil


static func _show(screen: VigilScreen, look: StringName) -> bool:
	if look == VigilHall.ROSE:
		if screen._rose_tab == null:
			return false
		screen._show_rose()
	elif look == VigilHall.EPITAPHS:
		if screen._epitaph_tab == null:
			return false
		screen._show_epitaphs()
	else:
		screen._show_deeds()
	return screen.look() == look


## The header's parts never stand on each other, nor the Replay pane on the
## reading glass.
static func _nothing_overlaps(fails: Array[String], screen: VigilScreen, where: String) -> void:
	# A label's box carries its line's spacing above and below its ink.
	var header: Array[Rect2] = [screen._crown.get_rect().grow_individual(0.0, -4.0, 0.0, -4.0),
		screen._ledger.get_rect().grow_individual(0.0, -4.0, 0.0, -4.0), screen._looks.get_rect()]
	var names: Array[String] = ["crown", "ledger", "look panes"]
	for i: int in header.size():
		for j: int in range(i + 1, header.size()):
			_check(fails, not header[i].intersects(header[j]),
				"%s: the %s stands on the %s (%s, %s)" % [where, names[i], names[j], header[i], header[j]])
	var view: RoseWindowView = screen.rose_view()
	if view != null and view.visible:
		var spot: Vector3 = VigilHall.rose_spot(screen.shape)
		var ledger: Rect2 = header[1]
		_check(fails, ledger.end.y <= spot.y - spot.z - 2.0 or ledger.position.x > spot.x + spot.z,
			"%s: the rose stands on the ledger (%s)" % [where, ledger])
		_check(fails, not ledger.intersects(view.glass().get_rect().grow_individual(0.0, -8.0, 0.0, 0.0)),
			"%s: the reading glass stands on the ledger (%s)" % [where, ledger])
	if view != null and view.visible and view.replay() != null:
		_check(fails, not view.replay().get_rect().intersects(view.glass().get_rect()),
			"%s: the Replay pane stands on the reading glass" % where)
	for rect: Rect2 in screen.content_rects():
		_check(fails, rect.end.y <= screen.size.y + 0.5, "%s: content runs off the stage's foot" % where)


## Every count on view is whole numbers either side of " / ".
static func _figures(fails: Array[String], screen: VigilScreen, where: String) -> void:
	var meter: RegEx = RegEx.create_from_string("^\\d+ / \\d+$")
	for node: Node in screen.find_children("", "Label", true, false):
		var label: Label = node
		if label.is_visible_in_tree() and label.text.contains("/") and label.text.length() < 12:
			_check(fails, meter.search(label.text) != null,
				"%s: a count reads '%s', not whole numbers" % [where, label.text])


## The pane with the longest memory: its name, its state, its inscription,
## then every memory in full, each its own paragraph; the whispers carved.
static func _reading(fails: Array[String], screen: VigilScreen, where: String) -> void:
	var view: RoseWindowView = screen.rose_view()
	var id: String = RoseWindowView.IDS[view._selected]
	var shown: PackedStringArray = PackedStringArray()
	for node: Node in view.glass().find_children("", "Label", true, false):
		shown.append((node as Label).text)
	var joined: String = "\n".join(shown)
	for key: Variant in view._record(id).get("memory", {}).get("dawn", []):
		_check(fails, shown.has(Locale.active.t(str(key))),
			"%s: the reading glass does not hold the memory %s in full" % [where, key])
	_check(fails, joined.contains(str(view._quest(id).get("inscription", "-"))),
		"%s: a memory hides the pane's inscription" % where)
	_check(fails, shown.has(Locale.active.t("ui.rose.finalWhisperMark")),
		"%s: thirty whispers do not end in the final mark" % where)
	_check(fails, shown.has(LeadlightNumerals.carved(24)),
		"%s: the whispers are not numbered in carved numerals" % where)


## zh-Hant: rewards joined with "、" and the ledger carved in Chinese numerals,
## set against their counter words as the title carves them ("十二次朝聖").
static func _carved_in_chinese(fails: Array[String], screen: VigilScreen, where: String) -> void:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in screen.find_children("", "Label", true, false):
		texts.append((node as Label).text)
	var joined: String = "\n".join(texts)
	_check(fails, joined.contains("→") and joined.contains("、") and not joined.contains(", "),
		"zh-Hant %s: a deed's rewards are not joined with 、" % where)
	_check(fails, screen._ledger.text.contains("十二") and screen._ledger.text.contains("三")
			and screen._ledger.text.contains("二"),
		"zh-Hant %s: the ledger is not carved in Chinese numerals (%s)" % [where, screen._ledger.text])
	_check(fails, screen._ledger.text.contains("十二次朝聖") and screen._ledger.text.contains(" · ")
			and not screen._ledger.text.contains(" 次"),
		"zh-Hant %s: the ledger's numerals do not stand against their counter words (%s)" % [
			where, screen._ledger.text])


## Every CJK character the hall sets in zh-Hant is in the shipped faces.
static func _every_glyph_drawn(fails: Array[String], screen: VigilScreen, state: String) -> void:
	var face: FontFile = load("res://assets/fonts/NotoSerifTC-SemiBold.woff2") as FontFile
	for node: Node in screen.find_children("", "Label", true, false):
		for c: String in (node as Label).text:
			var code: int = c.unicode_at(0)
			if code >= 0x3000 and code <= 0x9FFF and not face.has_char(code):
				_check(fails, false, "zh-Hant %s: '%s' in '%s' is not in the shipped faces" % [
					state, c, (node as Label).text.left(24)])


## The first cue is the look's, and only once Main asks for it.
static func _first_cue(fails: Array[String], content: ContentDB) -> void:
	for open_rose: bool in [false, true]:
		var heard: Array[StringName] = []
		var screen: VigilScreen = VigilScreen.new(vigil_in("mid", content), content,
			&"pad-landscape", open_rose)
		screen.cue_requested.connect(func(cue: StringName) -> void: heard.append(cue))
		_check(fails, heard.is_empty(), "the Vigil asked for its music before Main connected")
		screen.announce()
		var wanted: StringName = &"roseWindow" if open_rose else &"vigil"
		_check(fails, heard == [wanted], "opened %s, the Vigil's first cue is %s, not %s" % [
			"on the rose" if open_rose else "at the hearth", heard, wanted])
		screen.free()


## Replay the unsealing: present, shown and sized only with all six whole.
static func _replay_only_when_whole(fails: Array[String], content: ContentDB) -> void:
	for state: String in ["mid", "full"]:
		var screen: VigilScreen = VigilScreen.new(vigil_in(state, content), content,
			&"pad-landscape", true)
		var replay: Node = screen.find_child("Replay", true, false)
		if state == "full":
			_check(fails, replay is LeadlightPane and (replay as Control).visible
					and (replay as Control).size.x > 0.0 and (replay as Control).size.y > 0.0,
				"a whole rose has no visible Replay")
		else:
			_check(fails, replay == null, "a rose with dark panes offers Replay")
		screen.free()


static func _longest(view: RoseWindowView) -> int:
	var best: int = 0
	var most: int = -1
	for i: int in range(RoseWindowView.IDS.size()):
		var held: int = view._archived_dawn(view._record(RoseWindowView.IDS[i])).length()
		if held > most:
			most = held
			best = i
	return best


static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in range(count):
		await tree.process_frame
