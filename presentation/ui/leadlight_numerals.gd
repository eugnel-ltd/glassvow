class_name LeadlightNumerals
extends RefCounted
## Numerals for carved text: the Vigil's deeds are cut in stone, so English
## counts are Roman and zh-Hant counts are Chinese. Pure. Counts Roman cannot
## carve (zero, or past 3999) fall back to Arabic digits.

const ROMAN: Array[Array] = [
	[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
	[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"],
]
const HAN_DIGITS: String = "零一二三四五六七八九"
const HAN_UNITS: Array[String] = ["", "十", "百", "千"]


static func roman(n: int) -> String:
	if n <= 0 or n > 3999:
		return str(n)
	var out: String = ""
	var rest: int = n
	for pair: Array in ROMAN:
		var value: int = pair[0]
		var glyph: String = pair[1]
		while rest >= value:
			out += glyph
			rest -= value
	return out


## Chinese numerals as written, not read digit by digit: 十二, 二百一十四,
## 一千零五, 三萬二千. Zero is 零.
static func hanzi(n: int) -> String:
	if n == 0:
		return "零"
	if n < 0 or n >= 100000000:
		return str(n)
	if n >= 10000:
		var high: int = n / 10000
		var low: int = n % 10000
		var head: String = hanzi(high) + "萬"
		if low == 0:
			return head
		return head + ("零" if low < 1000 else "") + _below_ten_thousand(low, false)
	return _below_ten_thousand(n, true)


static func _below_ten_thousand(n: int, leading: bool) -> String:
	var out: String = ""
	var pending_zero: bool = false
	var started: bool = false
	for place: int in [3, 2, 1, 0]:
		var unit: int = int(pow(10.0, float(place)))
		var digit: int = (n / unit) % 10
		if digit == 0:
			if started:
				pending_zero = true
			continue
		if pending_zero:
			out += "零"
			pending_zero = false
		# 十二, not 一十二, when ten leads the whole number.
		if not (digit == 1 and place == 1 and not started and leading):
			out += HAN_DIGITS[digit]
		out += HAN_UNITS[place]
		started = true
	return out


## A count in the active script's carved numerals.
static func carved(n: int) -> String:
	return hanzi(n) if LeadlightTokens.is_zh() else roman(n)


## The Chinese numerals the shipped zh-Hant faces do not carry: they are
## subset to the locale's own text (tools/subset_noto_serif_tc.py), which
## never writes these (found in #655 PR C).
const UNDRAWN: String = "零千萬"


## A count in carved numerals the shipped faces can draw: in figures where the
## numerals would need a character they do not carry (zh-Hant's zero, its
## thousands; English has no Roman zero and already writes it so).
static func carved_drawn(n: int) -> String:
	var text: String = carved(n)
	for c: String in UNDRAWN:
		if text.contains(c):
			return str(n)
	return text
