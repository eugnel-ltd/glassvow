extends RefCounted
## RulesText wraps CJK between characters (no spaces to break on) and leaves
## the space-only Latin wrap alone. Measured with the card's own faces.

const CARD_WIDTH: float = 128.0
const FONT_SIZE: int = 13
const EPSILON: float = 0.01
const ENGLISH: String = "Deal @7@ damage. Apply 1 Cracked. Blood-moon flame: gain #3# Ward."
const ZH_BARE: String = "對所有敵人施加黯淡與裂痕。張牌。燃燼。金黃之火：獲得「護光」，之後抽牌。"
const ZH_MIXED: String = "施加 2 層黯淡。抽 1 張牌。"
const CLOSING: String = "。、，：；！？」』）"
const OPENING: String = "「『（"


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_rules_text_wrap: %s" % what)


static func _wrapped(text: String, width: float) -> RulesText:
	var body: RulesText = RulesText.new(text, Color.WHITE,
		GlassStyle.face(GlassStyle.ALEGREYA_400), GlassStyle.face(GlassStyle.ALEGREYA_700),
		FONT_SIZE, 16.9)
	body._wrap(width)
	return body


## One line as drawn: words in order, a space only where one was kept. The
## last word's trailing space hangs, as it does in `_line_widths`.
static func _line_text(line: Array) -> String:
	var out: String = ""
	for word: Dictionary in line:
		out += str(word["text"])
		if word["space"]:
			out += " "
	return out.strip_edges(false, true)


static func _lines_of(body: RulesText) -> Array[String]:
	var out: Array[String] = []
	for line: Array in body._lines:
		out.append(_line_text(line))
	return out


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	var locale: Locale = Locale.new(Locale.CODE_EN)
	Locale.active = locale
	_english_unchanged(fails)
	locale.set_language(Locale.CODE_ZH_HANT)
	_chinese_wraps_between_characters(fails)
	_chinese_kinsoku(fails)
	_chinese_keywords_stay_whole(fails)
	_mixed_keeps_its_spaces(fails)
	Locale.active = previous


static func _english_unchanged(fails: Array[String]) -> void:
	var body: RulesText = _wrapped(ENGLISH, CARD_WIDTH)
	_check(fails, _lines_of(body) == (["Deal 7 damage. Apply 1", "Cracked. Blood-moon",
		"flame: gain 3 Ward."] as Array[String]),
		"English card text keeps its space-only line breaks")
	for width: float in body._line_widths:
		_check(fails, width <= CARD_WIDTH + EPSILON, "English line fits the card width")
	var last: Array = body._lines[-1]
	var ward: Dictionary = last[-2]
	var stop: Dictionary = last[-1]
	var ward_text: String = ward["text"]
	var stop_text: String = stop["text"]
	var ward_space: bool = ward["space"]
	var ward_brk: bool = ward["brk"]
	_check(fails, ward_text == "Ward" and stop_text == "." \
		and not ward_space and not ward_brk, "the full stop stays glued to Ward")
	# Narrow enough to break after every word: the stop still never leads a line.
	for line_text: String in _lines_of(_wrapped(ENGLISH, 60.0)):
		_check(fails, not line_text.begins_with("."), "English full stop never leads a line")
	body.free()


static func _chinese_wraps_between_characters(fails: Array[String]) -> void:
	var body: RulesText = _wrapped(ZH_BARE, CARD_WIDTH)
	_check(fails, body._lines.size() > 1, "a space-free zh-Hant run wraps onto several lines")
	for li: int in range(body._lines.size()):
		_check(fails, body._line_widths[li] <= CARD_WIDTH + EPSILON,
			"zh-Hant line %d fits the card width" % li)
	_check(fails, "".join(_lines_of(body)) == ZH_BARE,
		"wrapping neither drops nor inserts a character")
	body.free()


static func _chinese_kinsoku(fails: Array[String]) -> void:
	for text: String in [ZH_BARE, ZH_MIXED]:
		for width: float in [70.0, 78.0, 91.0, 104.0, 117.0, CARD_WIDTH]:
			var body: RulesText = _wrapped(text, width)
			var lines: Array[String] = _lines_of(body)
			for li: int in range(lines.size()):
				var line_text: String = lines[li]
				_check(fails, not CLOSING.contains(line_text[0]),
					"no line starts with a closing mark (width %d, line %d)" % [width, li])
				_check(fails, not OPENING.contains(line_text[-1]),
					"no line ends with an opening bracket (width %d, line %d)" % [width, li])
				_check(fails, body._line_widths[li] <= width + EPSILON,
					"zh-Hant line fits (width %d, line %d)" % [width, li])
			body.free()


static func _chinese_keywords_stay_whole(fails: Array[String]) -> void:
	var body: RulesText = _wrapped("獲得 #5# 點護光。施加 1 層陰燃。燃燼。", 52.0)
	var seen: Array[String] = []
	for line: Array in body._lines:
		for word: Dictionary in line:
			var kind: int = word["kind"]
			if kind == RulesText.KIND_KEYWORD:
				seen.append(str(word["text"]))
	_check(fails, seen == (["護光", "陰燃", "燃燼"] as Array[String]),
		"a keyword is never cut between its characters")
	body.free()


static func _mixed_keeps_its_spaces(fails: Array[String]) -> void:
	var body: RulesText = _wrapped(ZH_MIXED, CARD_WIDTH)
	var rebuilt: String = ""
	for line: Array in body._lines:
		for word: Dictionary in line:
			rebuilt += str(word["text"]) + (" " if word["space"] else "")
	_check(fails, rebuilt.strip_edges() == ZH_MIXED,
		"digits keep exactly the spaces around them")
	var spaced: Array[String] = []
	for line: Array in body._lines:
		for word: Dictionary in line:
			if word["space"]:
				spaced.append(str(word["text"]))
	_check(fails, spaced == (["加", "2", "抽", "1"] as Array[String]),
		"the digits and the characters beside them are the only spaced words")
	body.free()
