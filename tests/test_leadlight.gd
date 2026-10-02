extends RefCounted
## Leadlight, the interface kit: the tokens still ARE the shipped values, the
## rite obeys the one-tap and Reduce Motion rules, and the lead-cut geometry is
## what the components draw (docs/design/2026-10-02-opening-start §7, §8).


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_leadlight: %s" % what)


static func run(fails: Array[String]) -> void:
	_aliases_are_the_shipped_values(fails)
	_theme_delegates(fails)
	_tracking(fails)
	_rite_runs_holds_and_skips(fails)
	_rite_lands_whole_under_reduce_motion(fails)
	_shapes(fails)
	_numerals(fails)


## The aliasing must not have moved a single colour: these literals are the
## values RunStyle and GlassStyle carried before the kit existed.
static func _aliases_are_the_shipped_values(fails: Array[String]) -> void:
	var pins: Array[Array] = [
		["RunStyle.GOLD", RunStyle.GOLD, Color("#f2c14e")],
		["RunStyle.GOLD_DIM", RunStyle.GOLD_DIM, Color("#9c7c34")],
		["RunStyle.INK", RunStyle.INK, Color("#0b0e1a")],
		["RunStyle.PARCHMENT", RunStyle.PARCHMENT, Color("#e8dfc8")],
		["RunStyle.TEXT", RunStyle.TEXT, Color("#d7dcea")],
		["RunStyle.TEXT_DIM", RunStyle.TEXT_DIM, Color("#8b93ad")],
		["RunStyle.PANEL", RunStyle.PANEL, Color(0.055, 0.071, 0.133, 0.86)],
		["RunStyle.PANEL_LINE", RunStyle.PANEL_LINE, Color(Color("#f2c14e"), 0.28)],
		["RunStyle.DANGER", RunStyle.DANGER, Color("#ff8d8d")],
		["GlassStyle.NIGHT_TOP", GlassStyle.NIGHT_TOP, Color(0.07, 0.08, 0.15)],
		["GlassStyle.NIGHT_MID", GlassStyle.NIGHT_MID, Color(0.035, 0.045, 0.095)],
		["GlassStyle.NIGHT_BOT", GlassStyle.NIGHT_BOT, Color(0.015, 0.02, 0.045)],
		["GlassStyle.GLASS", GlassStyle.GLASS, Color(0.56, 0.82, 1.0)],
		["GlassStyle.EMBER", GlassStyle.EMBER, Color(1.0, 0.60, 0.30)],
		["GlassStyle.GOLD", GlassStyle.GOLD, Color("#f2c14e")],
		["GlassStyle.INK", GlassStyle.INK, Color(0.10, 0.12, 0.19)],
		["GlassStyle.TEXT", GlassStyle.TEXT, Color(0.86, 0.90, 1.0)],
		["GlassStyle.TEXT_DIM", GlassStyle.TEXT_DIM, Color(0.58, 0.64, 0.80)],
		["GlassStyle.HP_RED", GlassStyle.HP_RED, Color(0.85, 0.33, 0.32)],
	]
	for pin: Array in pins:
		var got: Color = pin[1]
		var want: Color = pin[2]
		_check(fails, got.is_equal_approx(want), "%s moved: %s, want %s" % [pin[0], got, want])


static func _theme_delegates(fails: Array[String]) -> void:
	var theme: Theme = GlassStyle.theme()
	_check(fails, theme != null and theme.has_stylebox("focus", "Button"),
		"GlassStyle.theme() no longer yields the canonical Theme")
	var ring: StyleBox = theme.get_stylebox("focus", "Button") if theme != null else null
	_check(fails, ring is StyleBoxFlat and not (ring as StyleBoxFlat).draw_center,
		"the Button focus box is not the shared lantern ring")


static func _tracking(fails: Array[String]) -> void:
	_check(fails, LeadlightTokens.tracking(LeadlightTokens.ROLE_PRIMARY, 24, false) == 4,
		"primary at 24px tracks 0.16em → 4px")
	_check(fails, LeadlightTokens.tracking(LeadlightTokens.ROLE_PRIMARY, 24, true) == 10,
		"primary at 24px tracks 0.42em in zh-Hant → 10px")
	_check(fails, LeadlightTokens.size_for(LeadlightTokens.SIZE_PLAQUE, &"phone-landscape") == 17
		and LeadlightTokens.size_for(LeadlightTokens.SIZE_PLAQUE, &"pad-landscape") == 24,
		"plaque size per shape")
	var face: FontVariation = LeadlightTokens.font(LeadlightTokens.ROLE_LABEL, 15)
	_check(fails, face != null and face.has_char("琉".unicode_at(0)),
		"a Leadlight face lost the Noto Serif TC fallback")


static func _rite_runs_holds_and_skips(fails: Array[String]) -> void:
	var previous: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	var seen: Array[float] = [0.0, 0.0]
	var rite: LeadlightRite = LeadlightRite.new()
	rite.step(0.0, 1.0, func(p: float) -> void: seen[0] = p, Vector2i(Tween.TRANS_LINEAR, Tween.EASE_IN))
	rite.step(1.0, 2.0, func(p: float) -> void: seen[1] = p, Vector2i(Tween.TRANS_LINEAR, Tween.EASE_IN))
	var finished: Array[bool] = [false]
	rite.finished.connect(func() -> void: finished[0] = true)
	rite.start()
	rite.advance(0.5)
	_check(fails, is_equal_approx(seen[0], 0.5) and is_zero_approx(seen[1]),
		"half a second in: first step half, second untouched")
	rite.advance(5.0)
	_check(fails, is_equal_approx(seen[1], 1.0) and finished[0] and rite.is_done(),
		"advancing past the end lands and finishes")

	var held: LeadlightRite = LeadlightRite.new()
	var at: Array[float] = [0.0]
	held.step(0.0, 2.0, func(p: float) -> void: at[0] = p, Vector2i(Tween.TRANS_LINEAR, Tween.EASE_IN))
	held.hold_at(0.4).start()
	held.advance(3.0)
	_check(fails, held.held() and is_equal_approx(held.time(), 0.4),
		"a held rite waits at its hold")
	held.release()
	held.advance(3.0)
	_check(fails, held.is_done() and is_equal_approx(at[0], 1.0), "a released rite runs on")

	var skipped: LeadlightRite = LeadlightRite.new()
	var end: Array[float] = [0.0]
	skipped.step(0.0, 2.4, func(p: float) -> void: end[0] = p)
	skipped.start()
	skipped.advance(0.1)
	skipped.skip()
	_check(fails, is_equal_approx(end[0], 1.0) and skipped.is_done(),
		"one skip lands every step at its end")
	Preferences.active.reduce_motion = previous


static func _rite_lands_whole_under_reduce_motion(fails: Array[String]) -> void:
	var previous: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = true
	var end: Array[float] = [0.0]
	var rite: LeadlightRite = LeadlightRite.new()
	rite.step(0.0, 2.4, func(p: float) -> void: end[0] = p)
	rite.start()
	_check(fails, rite.is_done() and is_equal_approx(end[0], 1.0),
		"Reduce Motion: a rite lands whole on start, with no wait")
	_check(fails, is_zero_approx(LeadlightMotion.breath(1.3)), "Reduce Motion stills the breath")
	Preferences.active.reduce_motion = previous


static func _shapes(fails: Array[String]) -> void:
	var loz: PackedVector2Array = LeadlightShapes.lozenge(Rect2(0, 0, 100, 40), 12.0)
	_check(fails, loz.size() == 6 and loz[2] == Vector2(100, 20) and loz[5] == Vector2(0, 20),
		"lozenge points sit at the mid-height of both ends")
	var arch: PackedVector2Array = LeadlightShapes.arch(Rect2(0, 0, 200, 300), 0.3, 1.3, 10)
	var apex: float = 1e9
	for p: Vector2 in arch:
		apex = minf(apex, p.y)
	_check(fails, arch[0] == Vector2(0, 300) and arch[arch.size() - 1] == Vector2(200, 300)
		and is_zero_approx(apex), "arch stands on both jambs and peaks at the top")
	var lines: PackedVector2Array = LeadlightShapes.quarry(Rect2(10, 10, 120, 80), 24.0)
	var inside: bool = lines.size() > 0 and lines.size() % 2 == 0
	for p: Vector2 in lines:
		inside = inside and Rect2(9.9, 9.9, 120.2, 80.2).has_point(p)
	_check(fails, inside, "quarry leading stays inside its pane")


static func _numerals(fails: Array[String]) -> void:
	var roman: Dictionary = {1: "I", 4: "IV", 12: "XII", 214: "CCXIV", 1999: "MCMXCIX", 0: "0", 4000: "4000"}
	for n: int in roman:
		_check(fails, LeadlightNumerals.roman(n) == str(roman[n]),
			"roman(%d) = %s, want %s" % [n, LeadlightNumerals.roman(n), roman[n]])
	var han: Dictionary = {0: "零", 3: "三", 10: "十", 12: "十二", 20: "二十", 105: "一百零五",
		214: "二百一十四", 1005: "一千零五", 1010: "一千零一十", 32000: "三萬二千", 10001: "一萬零一"}
	for n: int in han:
		_check(fails, LeadlightNumerals.hanzi(n) == str(han[n]),
			"hanzi(%d) = %s, want %s" % [n, LeadlightNumerals.hanzi(n), han[n]])
