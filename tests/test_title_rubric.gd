extends RefCounted
## The title at the rubric's floor (docs/commercial-rubric.md; #655, open
## decision 1 of docs/design/2026-10-03-title-rooms): every functional text is
## at least 18 px at 1180×820 and on desktop (the build number alone is exempt,
## a waiver recorded in that spec's §14), and the larger type still sits
## whole: on the stage, the deeds uncut by their slabs (the longest Roman counts
## are set tighter, never smaller), and no word, pane or consent line under the
## lantern's hit, at every shape, in both languages, in every state the title
## shows.

const FLOOR: int = 18
const STATES: Array[String] = ["fresh", "consent", "saved", "vigil"]


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
				if not LeadlightTokens.is_phone(shape):
					_type_floor(fails, screen, where)
				_sits_whole(fails, screen, where)
				screen.free()
	Locale.active = previous


## Every text the player reads or taps on the title, by name, with its size.
static func _texts(screen: TitleScreen) -> Dictionary:
	var out: Dictionary = {}
	for id: String in screen._words:
		var word: Control = screen._words[id]
		out["word %s" % id] = word.get_theme_font_size("font_size")
	if screen._secondary != null:
		out["Rekindle pane"] = screen._secondary.get_theme_font_size("font_size")
	out["plaque"] = screen._plaque.title_label().get_theme_font_size("font_size")
	if screen._plaque._sub_row.visible:
		out["plaque sub-line"] = screen._plaque._sub.get_theme_font_size("font_size")
	for i: int in screen._slabs.size():
		out["deeds slab %d" % i] = screen._slabs[i]._px
	if screen._consent != null:
		for name: String in ["DiagnosticsLine", "DiagnosticsNote", "PrivacyPolicyWord"]:
			var node: Control = screen._consent.find_child(name, true, false) as Control
			if node != null:
				out[name] = node.get_theme_font_size("font_size")
	return out


static func _type_floor(fails: Array[String], screen: TitleScreen, where: String) -> void:
	var texts: Dictionary = _texts(screen)
	for name: String in texts:
		var px: int = texts[name]
		_check(fails, px >= FLOOR, "%s: the %s is %d px, under the %d px floor" % [where, name, px, FLOOR])
	# The one waiver: the build number is not read, only reported.
	_check(fails, screen._version.get_theme_font_size("font_size") < FLOOR,
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
			var centre: float = slab.position.x + slab.size.x * 0.5
			_check(fails, centre - wide * 0.5 >= 0.0 and centre + wide * 0.5 <= stage.size.x,
				"%s: the deed '%s' runs off the stage" % [where, text])
		_check(fails, slab.position.y + slab.size.y <= stage.size.y + 0.5,
			"%s: the deeds run below the stage" % where)
	if screen._consent != null:
		var row: Rect2 = Rect2(screen._consent.position, screen._consent.size)
		_check(fails, stage.encloses(row), "%s: the consent line runs off the stage (%s)" % [where, row])
		_check(fails, not row.intersects(hit),
			"%s: the consent line reaches under the lantern (%s against %s)" % [where, row, hit])
		_consent_on_touch(fails, screen, where)


## The title as Main builds it for `state`, the longest deeds a Vigil can carve
## (a four-figure Roman count) included.
static func _title(shape: StringName, state: String) -> TitleScreen:
	var choices: Array[Dictionary] = []
	var saved: bool = state == "saved" or state == "vigil"
	if saved:
		choices.append({"id": "continue", "label": Locale.active.t("ui.menu.backToRoad")})
	for row: Array in [["begin", "ui.menu.rekindle"], ["vigil", "ui.menu.theVigil"],
			["help", "ui.menu.howToPlay"], ["settings", "ui.menu.settings"],
			["credits", "ui.menu.credits"], ["quit", "ui.menu.quit"]]:
		choices.append({"id": row[0], "label": Locale.active.t(str(row[1]))})
	var context: Dictionary = {"shape": String(shape), "choices": choices,
		"brand": Locale.active.t("ui.brand.title"), "version": "1.0.0",
		"ask_consent": state == "consent"}
	if saved:
		context["sub"] = Locale.active.t("ui.hud.actWaystone", {"act": 2, "n": 4})
	if state == "vigil":
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


## On a touch screen the switch and the link stand at the 44 px touch floor,
## taller than on this desktop runner: the row, risen to stay on the stage at
## that height, must still clear the words above it.
static func _consent_on_touch(fails: Array[String], screen: TitleScreen, where: String) -> void:
	var line: Label = screen._consent.find_child("DiagnosticsLine", true, false) as Label
	if line == null:
		return
	var px: int = line.get_theme_font_size("font_size")
	var font: Font = line.get_theme_font("font")
	var whole: float = font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var lines: int = ceili(whole / line.custom_minimum_size.x)
	var pitch: float = font.get_height(px) + float(line.get_theme_constant("line_spacing"))
	var tall: float = float(lines) * pitch + float(screen._consent.get_theme_constant("separation")) + 44.0
	var spec: TitleScreen.Layout = TitleScreen.Layout.for_shape(screen.shape)
	var k: float = screen.size.y / spec.ref_h
	var top: float = minf(spec.consent.y * k, screen.size.y - tall - 6.0 * k)
	for id: String in screen._words:
		var word: Control = screen._words[id]
		if word.position.x + word.size.x < screen.size.x * 0.5:
			_check(fails, word.position.y + word.size.y <= top + 0.5,
				"%s: at the touch floor the consent line (top %d) runs into %s (bottom %d)" % [
					where, int(top), word.text, int(word.position.y + word.size.y)])
