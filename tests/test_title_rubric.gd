extends RefCounted
## The title at the rubric's floor (docs/commercial-rubric.md; #655, open
## decision 1 of docs/design/2026-10-03-title-rooms): every functional text is
## at least 18 px at 1180×820 and on desktop, and the kit's 14 on a phone, as it
## is drawn (the carved deeds lie on the road, so they are set larger to stand
## at the floor; the build number alone is exempt, the one waiver in that
## spec's §14), and the larger type still sits whole: on the stage, the deeds
## uncut by their slabs (the longest Roman counts are set tighter, never
## smaller), nothing on the title over anything else, and no word, pane or
## consent line under the lantern's hit, at every shape, in both languages, in
## every state the title shows (the consent line owed with a saved run too).
## Every word and the Rekindle pane take a tap at the rubric's 60 px at pad and
## on desktop (the touch floor's 44 on a phone) where they are drawn, and no
## two taps overlap (rooms spec §7 item 8).

const FLOOR: int = 18
const PHONE_FLOOR: int = 14
const STATES: Array[String] = ["fresh", "consent", "saved", "vigil", "saved-consent", "vigil-consent"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("title_rubric: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		for shape: StringName in StageShape.REFERENCES:
			for state: String in STATES:
				var screen: TitleScreen = _title(shape, state)
				var where: String = "%s %s %s" % [code, shape, state]
				_type_floor(fails, screen, where,
					PHONE_FLOOR if LeadlightTokens.is_phone(shape) else FLOOR)
				_sits_whole(fails, screen, where)
				_nothing_over_anything(fails, screen, where)
				_taps(fails, screen, where, LeadlightTokens.is_phone(shape))
				screen.free()
	Locale.active = previous


## The quiet words' and the Rekindle pane's taps: 60 px tall at pad and on
## desktop, the visuals unmoved; a phone's at the touch floor; none over another.
static func _taps(fails: Array[String], screen: TitleScreen, where: String, phone: bool) -> void:
	var tall: float = 44.0 if phone else 60.0
	var hits: Dictionary = {}
	for id: String in screen._words:
		var word: LeadlightWord = screen._words[id]
		if word.visible:
			hits["word %s" % id] = Rect2(word.position + word.hit_rect().position, word.hit_rect().size)
	if screen._secondary != null:
		var pane: LeadlightPane = screen._secondary
		hits["Rekindle pane"] = Rect2(pane.position + pane.hit_rect().position, pane.hit_rect().size)
	var names: Array = hits.keys()
	for i: int in names.size():
		var hit: Rect2 = hits[names[i]]
		_check(fails, hit.size.y >= tall - 0.5, "%s: %s takes a tap %d px tall, under %d" % [
			where, names[i], int(hit.size.y), int(tall)])
		for j: int in range(i + 1, names.size()):
			var other: Rect2 = hits[names[j]]
			_check(fails, not hit.grow(-0.5).intersects(other.grow(-0.5)),
				"%s: the taps of %s and %s overlap" % [where, names[i], names[j]])


## Every text the player reads or taps on the title, by name, with the size it
## stands at as drawn.
static func _texts(screen: TitleScreen) -> Dictionary:
	var out: Dictionary = {}
	for id: String in screen._words:
		var word: Control = screen._words[id]
		if word.visible:
			out["word %s" % id] = float(word.get_theme_font_size("font_size"))
	if screen._secondary != null:
		out["Rekindle pane"] = float(screen._secondary.get_theme_font_size("font_size"))
	out["plaque"] = float(screen._plaque.title_label().get_theme_font_size("font_size"))
	if screen._plaque._sub_row.visible:
		out["plaque sub-line"] = float(screen._plaque._sub.get_theme_font_size("font_size"))
	for i: int in screen._slabs.size():
		# Lying on the road foreshortens them: what counts is the drawn height.
		out["deeds slab %d" % i] = screen._slabs[i].drawn_px()
	if screen._consent != null:
		for name: String in ["DiagnosticsLine", "DiagnosticsNote", "PrivacyPolicyWord", "DiagnosticsToggle"]:
			var node: Control = screen._consent.find_child(name, true, false) as Control
			if node != null:
				out[name] = float(node.get_theme_font_size("font_size"))
	return out


static func _type_floor(fails: Array[String], screen: TitleScreen, where: String, floor_px: int) -> void:
	var texts: Dictionary = _texts(screen)
	for name: String in texts:
		var px: float = texts[name]
		_check(fails, px >= float(floor_px) - 0.01, "%s: the %s stands %.1f px, under the %d px floor" % [
			where, name, px, floor_px])
	# The one waiver: the build number is not read, only reported.
	_check(fails, screen._version.get_theme_font_size("font_size") < floor_px,
		"%s: the build number grew; the waiver in the spec's §14 no longer describes it" % where)


static func _sits_whole(fails: Array[String], screen: TitleScreen, where: String) -> void:
	var stage: Rect2 = Rect2(Vector2.ZERO, screen.size)
	var hit: Rect2 = screen.lantern.hit_rect()
	hit.position += screen.lantern.position
	var taps: Array[Control] = []
	for id: String in screen._words:
		taps.append(screen._words[id])
	if screen._secondary != null:
		taps.append(screen._secondary)
	for tap: Control in taps:
		var rect: Rect2 = Rect2(tap.position, tap.size)
		_check(fails, stage.encloses(rect), "%s: %s runs off the stage (%s)" % [where, tap.text, rect])
		_check(fails, not rect.intersects(hit),
			"%s: a tap on %s can land on the lantern (%s against %s)" % [where, tap.text, rect, hit])
		# The pick itself: the viewport asks the lantern, which answers by its body.
		_check(fails, not screen.lantern._has_point(rect.get_center() - screen.lantern.position),
			"%s: the lantern takes a tap on the middle of %s" % [where, tap.text])
	_check(fails, screen.lantern._has_point(screen.lantern.glass_centre()),
		"%s: the lantern no longer takes a tap on its glass" % where)
	var plaque: Rect2 = Rect2(screen._plaque.position, screen._plaque.size)
	var ring_top: float = screen.lantern.position.y + screen.lantern.size.y * LeadlightLantern.RING_TOP_UV
	_check(fails, plaque.end.y <= ring_top + 0.5, "%s: the plaque reaches the lantern's chain" % where)
	for slab: LeadlightInscription in screen._slabs:
		for line: String in slab.lines:
			var text: String = slab.carved_text(line)
			var wide: float = slab.carved_width(text)
			_check(fails, wide <= slab.size.x, "%s: the deed '%s' is cut by its slab (%d > %d)" % [
				where, text, int(wide), int(slab.size.x)])
		var carved: Rect2 = _carved(slab)
		_check(fails, stage.encloses(carved), "%s: the deeds run off the stage (%s)" % [where, carved])
		_check(fails, not carved.intersects(_version(screen)),
			"%s: the deeds run into the build number" % where)
	if screen._consent != null:
		var row: Rect2 = Rect2(screen._consent.position, screen._consent.size)
		_check(fails, stage.encloses(row), "%s: the consent line runs off the stage (%s)" % [where, row])
		_check(fails, not row.intersects(hit),
			"%s: the consent line reaches under the lantern (%s against %s)" % [where, row, hit])


## Nothing the title shows stands on anything else: the words, the Rekindle
## pane, the plaque, the wordmark, the rose, the carved deeds as drawn and the
## consent line (at the 44 px touch floor its switch and link stand at on a
## touch screen, taller than on this desktop runner).
static func _nothing_over_anything(fails: Array[String], screen: TitleScreen, where: String) -> void:
	var pieces: Dictionary = {}
	for id: String in screen._words:
		var word: Control = screen._words[id]
		if word.visible and id != "dev":
			pieces[word.text] = Rect2(word.position, word.size)
	if screen._secondary != null:
		pieces["Rekindle pane"] = Rect2(screen._secondary.position, screen._secondary.size)
	# The plaque from the top of its name's ink: its line box carries room for
	# accents above the capitals, and the rose may stand over that.
	var plaque: Rect2 = Rect2(screen._plaque.position, screen._plaque.size)
	var name: Label = screen._plaque.title_label()
	var ink_top: float = name.position.y + LeadlightPlaque.ink_span(name).x
	pieces["plaque"] = Rect2(plaque.position + Vector2(0.0, ink_top), plaque.size - Vector2(0.0, ink_top))
	pieces["wordmark"] = Rect2(screen._wordmark.position, screen._wordmark.size)
	# The rose's glass: its frame art leaves a clear margin round the window
	# (the drawn disc is about 0.76 of the control's half-side in the stills).
	var rose: Rect2 = Rect2(screen.rose.position, screen.rose.size)
	pieces["rose"] = rose.grow(-rose.size.x * 0.12)
	for i: int in screen._slabs.size():
		pieces["deeds slab %d" % i] = _carved(screen._slabs[i])
	if screen._consent != null:
		pieces["consent line"] = _consent_on_touch(screen)
	var names: Array = pieces.keys()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = pieces[names[i]]
			var b: Rect2 = pieces[names[j]]
			_check(fails, not a.intersects(b), "%s: the %s stands on the %s (%s against %s)" % [
				where, names[i], names[j], a, b])


## A slab's carved letters as drawn, on the stage.
static func _carved(slab: LeadlightInscription) -> Rect2:
	var drawn: Rect2 = slab.drawn_rect()
	drawn.position += slab.position
	return drawn


static func _version(screen: TitleScreen) -> Rect2:
	return Rect2(screen._version.position, screen._version.get_combined_minimum_size())


## The title as Main builds it for `state`, the longest deeds a Vigil can carve
## (a four-figure Roman count) included.
static func _title(shape: StringName, state: String) -> TitleScreen:
	var choices: Array[Dictionary] = []
	var saved: bool = state.begins_with("saved") or state.begins_with("vigil")
	if saved:
		choices.append({"id": "continue", "label": Locale.active.t("ui.menu.backToRoad")})
	for row: Array in [["begin", "ui.menu.rekindle"], ["vigil", "ui.menu.theVigil"],
			["help", "ui.menu.howToPlay"], ["settings", "ui.menu.settings"],
			["credits", "ui.menu.credits"], ["quit", "ui.menu.quit"]]:
		choices.append({"id": row[0], "label": Locale.active.t(str(row[1]))})
	var context: Dictionary = {"shape": String(shape), "choices": choices,
		"brand": Locale.active.t("ui.brand.title"), "version": "1.0.0",
		"ask_consent": state.ends_with("consent")}
	if saved:
		context["sub"] = Locale.active.t("ui.hud.actWaystone", {"act": 2, "n": 4})
	if state.begins_with("vigil"):
		var n: Callable = LeadlightNumerals.carved
		var stats: String = Locale.active.t("ui.brand.stats",
			{"runs": n.call(3888), "wins": n.call(388), "slain": n.call(3888)})
		var lines: Array[String] = []
		for part: String in stats.split(" · "):
			lines.append(Main._carve(part))
		lines.append(Main._carve(Locale.active.t("ui.brand.secrets", {"n": n.call(388)}).trim_prefix(" · ")))
		context["deeds"] = lines
	var screen: TitleScreen = TitleScreen.new(context, null, Preferences.new())
	screen.size = Vector2(StageShape.REFERENCES[shape])
	screen._layout()
	return screen


## The consent line as it stands on a touch screen, where its switch and link
## are at the 44 px touch floor, taller than on this desktop runner: a row that
## stands at the foot rises by the difference to stay on the stage; one that
## stands in the sky grows down.
static func _consent_on_touch(screen: TitleScreen) -> Rect2:
	var row: Rect2 = Rect2(screen._consent.position, screen._consent.size)
	var line: Label = screen._consent.find_child("DiagnosticsLine", true, false) as Label
	if line == null:
		return row
	var px: int = line.get_theme_font_size("font_size")
	var font: Font = line.get_theme_font("font")
	var whole: float = font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var lines: int = ceili(whole / line.custom_minimum_size.x)
	var pitch: float = font.get_height(px) + float(line.get_theme_constant("line_spacing"))
	var tall: float = float(lines) * pitch + float(screen._consent.get_theme_constant("separation")) + 44.0
	if tall <= row.size.y:
		return row
	if row.get_center().y > screen.size.y * 0.5:
		# The layout's own rule, at that height: from its seat, or risen to stay on the stage.
		var spec: TitleScreen.Layout = TitleScreen.Layout.for_shape(screen.shape)
		var k: float = screen.size.y / spec.ref_h
		row.position.y = minf(spec.consent.y * k, screen.size.y - tall - 6.0 * k)
	row.size.y = tall
	return row
