class_name RulesText
extends Control
## The card's rules paragraph, drawn rather than laid out by a Label.
##
## The benchmark styles three runs inside one sentence (styles.css .card-text):
##   plain     #C6CCDF, Alegreya 400
##   .val      #E8DFC8, Alegreya 700 — the numbers, wrapped in @…@ or #…#
##   .kw       the card's type tint, with `border-bottom: 1px dotted tint@60%`
##
## RichTextLabel covers the first two and not the third: its [u] draws a solid
## rule in the text's own colour, with no dotted variant and no way to drop the
## alpha independently. Patching one in from outside needs per-run rectangles,
## which RichTextLabel does not expose — and after wrapping they cannot be
## recomputed reliably. So this measures and draws the paragraph itself, which
## costs one greedy wrap loop and buys exact control over all three runs.

const KIND_PLAIN: int = 0
const KIND_VALUE: int = 1
const KIND_KEYWORD: int = 2

## Six terms read their description from the hydrated status catalogue. The
## map is semantic rather than surface text, so a live language switch cannot
## disconnect a translated dotted rule from its status.
const KEYWORD_STATUS: Dictionary = {
	"vulnerable": "vulnerable", "weak": "weak", "frail": "frail",
	"poison": "poison", "str": "str", "dex": "dex",
}


static func keyword_key(surface: String) -> String:
	_refresh_keyword_cache()
	return str(_keyword_keys.get(surface, ""))


static func keyword_status(surface: String) -> String:
	return str(KEYWORD_STATUS.get(keyword_key(surface), ""))


static func keyword_text(surface: String) -> String:
	var key: String = keyword_key(surface)
	if key.is_empty():
		return surface
	var path: String = "ui.keywords.%s" % key
	var found: String = Locale.active.t(path)
	return found if found != path else surface



## CSS `dotted` at 1px is a 1px dot every 2px.
const DOT_W: float = 1.0
const DOT_STEP: float = 2.0
const UNDERLINE_DROP: float = 2.0

## Derived from the active catalogue. The signature is the term content rather
## than the locale code: catalogue mutation and a live switch both invalidate
## it, while identical content avoids pointless rebuilding.
static var _keyword_signature: String = ""
static var _keyword_surfaces: Array[String] = []
static var _keyword_keys: Dictionary = {}

var plain_color: Color = Color(0.776, 0.800, 0.875)
var value_color: Color = Color(0.910, 0.875, 0.784)
var keyword_color: Color = Color(1, 1, 1)
var font_size: int = 13
var line_height: float = 17.0

var _font_plain: Font
var _font_bold: Font
var _tokens: Array = []          # [{text:String, kind:int}]
var _lines: Array = []           # [[{text, kind, w, space, brk, space_w}]] after wrapping
var _line_widths: PackedFloat32Array = PackedFloat32Array()


func _init(text: String, tint: Color, plain: Font, bold: Font, size: int,
		leading: float) -> void:
	keyword_color = tint
	_font_plain = plain
	_font_bold = bold
	font_size = size
	line_height = leading
	_tokens = tokenize(text)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _refresh_keyword_cache() -> void:
	var terms: Dictionary = Locale.active.keyword_terms()
	var signature: String = JSON.stringify(terms)
	if signature == _keyword_signature:
		return
	_keyword_signature = signature
	_keyword_surfaces.clear()
	_keyword_keys.clear()
	for key_v: Variant in terms:
		var key: String = str(key_v)
		var surfaces: Array = terms[key_v]
		for surface_v: Variant in surfaces:
			var surface: String = str(surface_v)
			if _keyword_keys.has(surface):
				continue
			_keyword_keys[surface] = key
			_keyword_surfaces.append(surface)
	_keyword_surfaces.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length() if a.length() != b.length() else a < b)


## Split rules text into styled runs. Numbers first — a marker never contains a
## keyword, so the two passes cannot overlap.
static func tokenize(text: String) -> Array:
	var out: Array = []
	var buf: String = ""
	var i: int = 0
	while i < text.length():
		var ch: String = text[i]
		if ch == "@" or ch == "#":
			var close: int = text.find(ch, i + 1)
			if close > i:
				if buf != "":
					out.append({"text": buf, "kind": KIND_PLAIN})
					buf = ""
				out.append({
					"text": text.substr(i + 1, close - i - 1), "kind": KIND_VALUE})
				i = close + 1
				continue
		buf += ch
		i += 1
	if buf != "":
		out.append({"text": buf, "kind": KIND_PLAIN})
	# Then split the plain runs on keywords.
	var split: Array = []
	for tok: Dictionary in out:
		var tok_kind: int = tok["kind"]
		if tok_kind != KIND_PLAIN:
			split.append(tok)
			continue
		split.append_array(_split_keywords(str(tok["text"])))
	return split


static func _split_keywords(text: String) -> Array:
	var out: Array = []
	_refresh_keyword_cache()
	var plain_at: int = 0
	var at: int = 0
	while at < text.length():
		var matched: String = ""
		for surface: String in _keyword_surfaces:
			if text.substr(at, surface.length()) == surface \
					and _surface_boundary(text, at, surface):
				matched = surface
				break
		if matched.is_empty():
			at += 1
			continue
		if at > plain_at:
			out.append({"text": text.substr(plain_at, at - plain_at),
				"kind": KIND_PLAIN})
		out.append({"text": matched, "kind": KIND_KEYWORD})
		at += matched.length()
		plain_at = at
	if plain_at < text.length():
		out.append({"text": text.substr(plain_at), "kind": KIND_PLAIN})
	return out


static func _surface_boundary(text: String, at: int, surface: String) -> bool:
	if not _is_ascii_word(surface):
		return true
	var before_ok: bool = at == 0 or not _is_ascii_word_char(text[at - 1])
	var after: int = at + surface.length()
	return before_ok and (after == text.length() or not _is_ascii_word_char(text[after]))


static func _is_ascii_word(text: String) -> bool:
	for i: int in range(text.length()):
		if not _is_ascii_word_char(text[i]):
			return false
	return not text.is_empty()


static func _is_ascii_word_char(ch: String) -> bool:
	if ch.length() != 1:
		return false
	var codepoint: int = ch.unicode_at(0)
	return codepoint >= 48 and codepoint <= 57 \
		or codepoint >= 65 and codepoint <= 90 \
		or codepoint >= 97 and codepoint <= 122 \
		or codepoint == 95


func _font_for(kind: int) -> Font:
	return _font_bold if kind == KIND_VALUE else _font_plain


func _color_for(kind: int) -> Color:
	match kind:
		KIND_VALUE:
			return value_color
		KIND_KEYWORD:
			return keyword_color
		_:
			return plain_color


## Ideographs, kana and fullwidth forms. Chinese text carries no spaces, so each
## of these is its own break opportunity; the em dash and ellipsis are typeset
## full-width in zh-Hant and are treated the same way.
static func _is_cjk(c: String) -> bool:
	var cp: int = c.unicode_at(0)
	return (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF) \
		or (cp >= 0x3000 and cp <= 0x30FF) or (cp >= 0xFF00 and cp <= 0xFFEF) \
		or cp == 0x2014 or cp == 0x2026


## Kinsoku: closing marks stay on the line of the character they follow.
static func _no_break_before(c: String) -> bool:
	return "。、，．：；！？」』）】》".contains(c)


## Kinsoku: opening brackets stay on the line of the character they open.
static func _no_break_after(c: String) -> bool:
	return "「『（【《".contains(c)


## A break between two adjacent characters with no space between them. It needs
## a CJK character on at least one side, so Latin text keeps its space-only
## breaks, and neither kinsoku rule may forbid it.
static func _may_break_between(before: String, after: String) -> bool:
	if not (_is_cjk(before) or _is_cjk(after)):
		return false
	return not _no_break_after(before) and not _no_break_before(after)


## Greedy wrap on word boundaries, keeping each word's style with it. Runs are
## split into words up front so a run can break across lines like plain text.
func _wrap(width: float) -> void:
	_lines = []
	_line_widths = PackedFloat32Array()
	# Walk the whole paragraph as one character stream, not each run separately.
	# A run boundary often falls mid-phrase ("Deal " | "4" | " damage."), and
	# splitting per run drops the space that *begins* the next one — "Deal
	# 4damage". A word takes the style of its first character.
	var words: Array = []
	var cur: String = ""
	var cur_kind: int = KIND_PLAIN
	for tok: Dictionary in _tokens:
		var kind: int = tok["kind"]
		var body: String = str(tok["text"])
		for ci: int in range(body.length()):
			var c: String = body[ci]
			if c == " ":
				if cur != "":
					words.append({"text": cur, "kind": cur_kind, "space": true,
						"brk": false})
					cur = ""
				continue
			# A word also ends where its STYLE ends, not only where a space is.
			# "Ward." is a keyword run followed by a plain one with no space
			# between them; taking the kind of the first character alone made it
			# one keyword word, which ran the dotted rule under the full stop and
			# made the glossary look up "Ward." — a key no glossary has. The
			# break carries `space: false`, so nothing is inserted between them.
			# Between CJK characters there is no space to break on, so a word
			# also ends where `_may_break_between` allows a break. `brk` marks
			# that opportunity: a break with nothing inserted. A keyword is never
			# cut inside, because the glossary and `keyword_at` look it up by the
			# word's whole text.
			if cur != "":
				var inside_keyword: bool = kind == KIND_KEYWORD and cur_kind == KIND_KEYWORD
				var brk: bool = not inside_keyword and _may_break_between(cur[-1], c)
				if kind != cur_kind or brk:
					words.append({"text": cur, "kind": cur_kind, "space": false,
						"brk": brk})
					cur = ""
			if cur == "":
				cur_kind = kind
			cur += c
	if cur != "":
		words.append({"text": cur, "kind": cur_kind, "space": false, "brk": false})

	# A space is the same width whatever word precedes it — it depends only on
	# the face and the size. Measure the two faces once instead of once per word.
	var space_plain: float = _font_plain.get_string_size(" ",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var space_bold: float = _font_bold.get_string_size(" ",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	for word: Dictionary in words:
		var wkind: int = word["kind"]
		word["w"] = _font_for(wkind).get_string_size(str(word["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		word["space_w"] = space_bold if wkind == KIND_VALUE else space_plain
	# Words that cannot be separated from their successor ("Ward" + ".", or an
	# opening bracket and the character it opens) travel together. Measuring the
	# first alone let the rest hang past the edge — a 3px full stop in English,
	# a whole clipped glyph in CJK — so a break is judged on the whole chain.
	var chain_w: Array[float] = []
	chain_w.resize(words.size())
	for wi: int in range(words.size() - 1, -1, -1):
		var tail: Dictionary = words[wi]
		var tail_w: float = tail["w"]
		var detached: bool = tail["space"] or tail["brk"] or wi == words.size() - 1
		chain_w[wi] = tail_w if detached else tail_w + chain_w[wi + 1]
	var line: Array = []
	var line_w: float = 0.0
	for wi: int in range(words.size()):
		var word: Dictionary = words[wi]
		var ww: float = word["w"]
		var space_w: float = word["space_w"]
		var has_space: bool = word["space"]
		# A line may only break where a space was, or where a CJK break
		# opportunity was. Splitting a word at its style boundary created
		# neighbours with no space between them ("Ward" + "."), and a greedy
		# wrap would happily strand the full stop on the next line.
		var can_break: bool = false
		if not line.is_empty():
			var prev: Dictionary = line[-1]
			can_break = prev["space"] or prev["brk"]
		if can_break and line_w + chain_w[wi] > width:
			_push_line(line, line_w)
			line = []
			line_w = 0.0
		line.append(word)
		line_w += ww + (space_w if has_space else 0.0)
	if not line.is_empty():
		_push_line(line, line_w)


## Close a line, dropping the last word's trailing space from the measured
## width. CSS hangs a space at a break rather than counting it into the line
## box, so counting it here would shove every wrapped line half a space left.
func _push_line(line: Array, w: float) -> void:
	var last: Dictionary = line[-1]
	var trailing: bool = last["space"]
	var space_w: float = last["space_w"]
	_lines.append(line)
	_line_widths.append(w - (space_w if trailing else 0.0))


func paragraph_height() -> float:
	return float(_lines.size()) * line_height


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_wrap(size.x)
		queue_redraw()


func _draw() -> void:
	if _lines.is_empty():
		_wrap(size.x)
	var ascent: float = _font_plain.get_ascent(font_size)
	# Centre the block vertically; the benchmark's .card-text is a flex centre.
	var y: float = (size.y - paragraph_height()) * 0.5 + ascent
	for li: int in range(_lines.size()):
		var line: Array = _lines[li]
		var x: float = (size.x - _line_widths[li]) * 0.5
		for word: Dictionary in line:
			var kind: int = word["kind"]
			var w: float = word["w"]
			draw_string(_font_for(kind), Vector2(x, y), str(word["text"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _color_for(kind))
			if kind == KIND_KEYWORD:
				_draw_dotted(x, y + UNDERLINE_DROP, w)
			var sp: float = word["space_w"]
			var draw_space: bool = word["space"]
			x += w + (sp if draw_space else 0.0)
		y += line_height


## Which keyword the point lands on, or "" for none.
##
## The benchmark can ask this of the DOM because each `.kw` is a real `<span>`
## with its own box. Here the paragraph draws itself, so the hit box has to be
## re-derived — by walking the SAME geometry `_draw` lays out, so the target is
## exactly the run that carries the dotted rule and never drifts from it.
##
## The box is the glyph run plus its leading, not just the ascent: aiming at a
## 13px word by its cap height alone is a worse target than the underline
## suggests.
func keyword_at(local: Vector2) -> String:
	if _lines.is_empty():
		_wrap(size.x)
	var ascent: float = _font_plain.get_ascent(font_size)
	var y: float = (size.y - paragraph_height()) * 0.5 + ascent
	for li: int in range(_lines.size()):
		var line: Array = _lines[li]
		var x: float = (size.x - _line_widths[li]) * 0.5
		var top: float = y - ascent
		for word: Dictionary in line:
			var kind: int = word["kind"]
			var w: float = word["w"]
			if kind == KIND_KEYWORD \
					and Rect2(x, top, w, line_height).has_point(local):
				return str(word["text"])
			var sp: float = word["space_w"]
			var draw_space: bool = word["space"]
			x += w + (sp if draw_space else 0.0)
		y += line_height
	return ""


## The benchmark's `border-bottom: 1px dotted tint@60%`.
func _draw_dotted(x: float, y: float, width: float) -> void:
	var col: Color = Color(keyword_color, 0.6)
	var dx: float = 0.0
	while dx < width:
		draw_rect(Rect2(x + dx, y, minf(DOT_W, width - dx), 1.0), col)
		dx += DOT_STEP
