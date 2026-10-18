extends RefCounted
## Grammar on the actual title and Vigil paths, with real content bound to
## Main. Earned deferred-class unlocks stay hidden; offering that class makes
## its existing unlock count again. Counts choose grammar before Roman carving.

## Raw runs, raw wins, then the expected ledger prefix in each language.
const COUNTS: Array[Array] = [
	[0, 0, "0 pilgrimages · 0 dawns", "0次朝聖 · 0次破曉"],
	[0, 1, "0 pilgrimages · I dawn", "0次朝聖 · 一次破曉"],
	[0, 2, "0 pilgrimages · II dawns", "0次朝聖 · 二次破曉"],
	[1, 0, "I pilgrimage · 0 dawns", "一次朝聖 · 0次破曉"],
	[1, 1, "I pilgrimage · I dawn", "一次朝聖 · 一次破曉"],
	[1, 2, "I pilgrimage · II dawns", "一次朝聖 · 二次破曉"],
	[2, 0, "II pilgrimages · 0 dawns", "二次朝聖 · 0次破曉"],
	[2, 1, "II pilgrimages · I dawn", "二次朝聖 · 一次破曉"],
	[2, 2, "II pilgrimages · II dawns", "二次朝聖 · 二次破曉"],
]
## Offered-class fixture?, earned unlock history, expected visible secrets.
const SECRET_CASES: Array[Array] = [
	[false, [], 0],
	[false, ["aspect2"], 0],
	[false, ["lamplighter"], 1],
	[false, ["aspect2", "lamplighter"], 1],
	[true, ["aspect2"], 1],
	[true, ["aspect2", "lamplighter"], 2],
]
const SECRETS_EN: Array[String] = ["", "I secret unearthed", "II secrets unearthed"]
const SECRETS_ZH: Array[String] = ["", "一個秘密已現", "二個秘密已現"]
const SLAIN_EN: Array[String] = ["", "I slain", "II slain"]
const SLAIN_ZH: Array[String] = ["", "一敵隕落", "二敵隕落"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("scoped_deed_count_grammar: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	var content: ContentDB = ContentDB.load_full()
	# Same fixture seam as test_class_scope: 1.1 offers the existing class row.
	var offered: ContentDB = ContentDB.load_full(false)
	var ash: Dictionary = offered.aspects[1]
	ash.erase("deferred")
	_check(fails, ClassScope.withheld_unlocks(content) == ["aspect2"],
		"shipping content must withhold only the earned Ashwarden unlock")
	_check(fails, ClassScope.withheld_unlocks(offered).is_empty(),
		"the explicitly offered-class fixture still withholds its unlock")
	var main: Main = Main.new()
	TestProfile.install(main)
	main.content = content
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		for counts: Array in COUNTS:
			_title(fails, main, content, offered, counts, code == Locale.CODE_ZH_HANT)
			_ledger(fails, content, counts, code == Locale.CODE_ZH_HANT)
	_check(fails, ClassScope.withheld_unlocks(content) == ["aspect2"],
		"the offered-class fixture changed shipping class scope")
	main.free()
	Locale.active = previous


static func _vigil(counts: Array) -> VigilState:
	var vigil: VigilState = VigilState.blank()
	vigil.deeds["runs"] = counts[0]
	vigil.deeds["wins"] = counts[1]
	return vigil


static func _title(fails: Array[String], main: Main, content: ContentDB,
		offered: ContentDB, counts: Array, zh: bool) -> void:
	var prefix: String = counts[3] if zh else counts[2]
	var parts: PackedStringArray = prefix.split(" · ")
	for scope: Array in SECRET_CASES:
		var class_offered: bool = scope[0]
		var earned: Array = scope[1]
		var secrets: int = scope[2]
		main.content = offered if class_offered else content
		for slain: int in range(3):
			var vigil: VigilState = _vigil(counts)
			vigil.deeds["slain"] = slain
			vigil.unlocks.assign(earned)
			var before: Dictionary = vigil.to_dict()
			main._vigil = vigil
			var expected: Array[String] = []
			if counts[0] > 0:
				expected.append(parts[0])
				if counts[1] > 0:
					expected.append(parts[1])
				if slain > 0:
					expected.append(SLAIN_ZH[slain] if zh else SLAIN_EN[slain])
				if secrets > 0:
					expected.append(SECRETS_ZH[secrets] if zh else SECRETS_EN[secrets])
			var actual: Array[String] = main._carved_deeds()
			var where: String = "%s title runs=%d wins=%d slain=%d earned=%s offered=%s" % [
				Locale.active.code, counts[0], counts[1], slain, earned, class_offered]
			_check(fails, actual == expected,
				"%s: expected %s, got %s" % [where, expected, actual])
			_check(fails, vigil.to_dict() == before, "%s changed the earned ledger" % where)


static func _ledger(fails: Array[String], content: ContentDB, counts: Array, zh: bool) -> void:
	for vow: int in [0, 2]:
		var vigil: VigilState = _vigil(counts)
		vigil.deeds["bestVow"] = vow
		var screen: VigilScreen = VigilScreen.new(vigil, content)
		var prefix: String = counts[3] if zh else counts[2]
		var suffix: String = " · 最深誓言：" if zh else " · deepest Vow: "
		var numeral: String = "二" if zh else "II"
		var expected: String = prefix + suffix + ("—" if vow == 0 else numeral)
		_check(fails, screen._ledger.text == expected,
			"%s Vigil runs=%d wins=%d vow=%d: expected '%s', got '%s'" % [
				Locale.active.code, counts[0], counts[1], vow, expected, screen._ledger.text])
		screen.free()
