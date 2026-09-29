extends RefCounted
## `--act=` is an act NUMBER counted from 1, and `ActFlag.parse` is the one place
## it becomes the 0-based act index (#451). Every valid number maps to its index;
## everything else is refused with the convention in the message, never clamped
## to the nearest act the way the three parsers it replaced did.


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_act_flag: %s" % what)


## The act index a parse result carries, or -1 when it carries an error instead.
static func _index(parsed: Dictionary) -> int:
	var act_index: int = parsed.get("act_index", -1)
	return act_index


static func run(fails: Array[String]) -> void:
	_translation(fails)
	_refusals(fails)


static func _translation(fails: Array[String]) -> void:
	# Literal spot checks, independent of the formula the loop below repeats.
	_check(fails, _index(ActFlag.parse("1")) == 0, "--act=1 is Act I, act index 0")
	_check(fails, _index(ActFlag.parse("4")) == 3, "--act=4 is Act IV, act index 3")
	_check(fails, LayoutBook.ACTS == 4,
		"the spot checks above assume four acts; the flag follows LayoutBook.ACTS")
	for act_number: int in range(1, LayoutBook.ACTS + 1):
		var parsed: Dictionary = ActFlag.parse(str(act_number))
		_check(fails, not parsed.has("error") and _index(parsed) == act_number - 1,
			"act number %d translates to act index %d" % [act_number, act_number - 1])
		_check(fails, ActFlag.number_of(_index(parsed)) == act_number,
			"act number %d survives the round trip through its index" % act_number)


static func _refusals(fails: Array[String]) -> void:
	var refused: PackedStringArray = PackedStringArray([
		"0", "5", "-1", "-0", "", "abc", "I", "IV", "1.5", "4.0", "1e0",
		" 1", "1 ", "+1", "01", "0x2", "99999999999999999999",
	])
	for text: String in refused:
		var parsed: Dictionary = ActFlag.parse(text)
		_check(fails, parsed.has("error") and not parsed.has("act_index"),
			"'%s' is refused, not clamped to a neighbouring act" % text)
		var message: String = str(parsed.get("error", ""))
		_check(fails, message.contains("counted from 1")
				and message.contains("--act=1 is Act I")
				and message.contains("up to %d" % LayoutBook.ACTS)
				and message.contains("'%s'" % text),
			"'%s' is refused with the convention and the value: %s" % [text, message])
