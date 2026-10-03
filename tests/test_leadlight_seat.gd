extends RefCounted
## The seat (docs/design/2026-10-03-title-rooms §2.2, §3.1, §11.1): the way back
## from every room stands where nothing can scroll it or push it off. On every
## shape and every flex stage a device can give, the seated lantern's body, the
## Return word and both hits lie on the stage; each hit is at least the room's
## floor (60×60 at pad and desktop, 44×44 on a phone); the word never stands
## on the lantern; and the two keep-clear rects hold them. The node seats its
## parts where the pure rule says.

const FLEX: Array[Array] = [
	[&"phone-landscape", Vector2(845.0, 390.0)], [&"phone-landscape", Vector2(844.0, 443.0)],
	[&"pad-landscape", Vector2(1180.0, 885.0)], [&"pad-landscape", Vector2(1180.0, 824.0)],
	[&"desktop-landscape", Vector2(1458.0, 911.0)],
]


## The rubric's tap floors (pad and desktop, phone), never the kit's tokens.
const HIT_FLOOR: Vector2i = Vector2i(60, 44)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("leadlight_seat: %s" % what)


static func run(fails: Array[String]) -> void:
	var stages: Array[Array] = []
	for shape_v: Variant in StageShape.REFERENCES:
		var shape: StringName = shape_v
		stages.append([shape, Vector2(StageShape.REFERENCES[shape])])
	stages.append_array(FLEX)
	for entry: Array in stages:
		var shape: StringName = entry[0]
		var stage: Vector2 = entry[1]
		_rule(fails, shape, stage)
		_node(fails, shape, stage)
	_pad_numbers(fails)


static func _rule(fails: Array[String], shape: StringName, stage: Vector2) -> void:
	var where: String = "%s %dx%d" % [shape, int(stage.x), int(stage.y)]
	var seat: Dictionary = LeadlightSeat.for_stage(shape, stage)
	var whole: Rect2 = Rect2(Vector2.ZERO, stage)
	var body: Rect2 = seat["lantern_hit"]
	var word: Rect2 = seat["word"]
	var floor_px: float = float(HIT_FLOOR.y if LeadlightTokens.is_phone(shape) else HIT_FLOOR.x)
	for part: Array in [["the lantern's body", body], ["the Return word", word]]:
		var rect: Rect2 = part[1]
		_check(fails, whole.encloses(rect), "%s: %s runs off the stage (%s)" % [where, part[0], rect])
		_check(fails, rect.size.x >= floor_px and rect.size.y >= floor_px,
			"%s: %s's hit is under %d px (%s)" % [where, part[0], int(floor_px), rect.size])
	_check(fails, not word.intersects(body), "%s: the word stands on the lantern" % where)
	var keep_lantern: Rect2 = seat["keep_lantern"]
	var keep_word: Rect2 = seat["keep_word"]
	_check(fails, keep_lantern.encloses(body), "%s: the lantern leaves its keep-clear rect" % where)
	_check(fails, keep_word.encloses(word), "%s: the word leaves its keep-clear rect" % where)
	var art: Rect2 = seat["art"]
	var wick: Vector2 = seat["wick"]
	_check(fails, art.has_point(wick) and whole.has_point(wick), "%s: the wick is off the lantern" % where)
	# Anchored to the stage's foot: a taller stage moves the seat down by as much.
	var lower: Dictionary = LeadlightSeat.for_stage(shape, stage + Vector2(0.0, 40.0))
	var moved: Rect2 = lower["word"]
	_check(fails, is_equal_approx(moved.position.y - word.position.y, 40.0)
			and is_equal_approx(moved.position.x, word.position.x),
		"%s: the seat is not anchored to the stage's bottom-left corner" % where)


static func _node(fails: Array[String], shape: StringName, stage: Vector2) -> void:
	var where: String = "%s %dx%d" % [shape, int(stage.x), int(stage.y)]
	var seat_node: LeadlightSeat = LeadlightSeat.new(shape)
	seat_node.size = stage
	seat_node._place()
	var rule: Dictionary = LeadlightSeat.for_stage(shape, stage)
	var rule_word: Rect2 = rule["word"]
	var rule_hit: Rect2 = rule["lantern_hit"]
	var word: Rect2 = Rect2(seat_node.word().position, seat_node.word().size)
	var hit: Rect2 = Rect2(seat_node.lantern_hit().position, seat_node.lantern_hit().size)
	_check(fails, word.is_equal_approx(rule_word), "%s: the word is not where the rule seats it" % where)
	_check(fails, hit.is_equal_approx(rule_hit),
		"%s: the lantern's hit is not where the rule seats it" % where)
	_check(fails, seat_node.word().text == Locale.active.t("ui.menu.return"),
		"%s: the way back does not read Return" % where)
	var presses: Array[int] = [0]
	seat_node.pressed.connect(func() -> void: presses[0] += 1)
	seat_node.word().pressed.emit()
	seat_node.lantern_hit().pressed.emit()
	_check(fails, presses[0] == 2, "%s: the word and the lantern are not the same way back" % where)
	seat_node.free()
	var alone: LeadlightSeat = LeadlightSeat.new(shape, false)
	_check(fails, not alone.lantern_hit().visible, "%s: a seat with no lantern still takes a tap there" % where)
	alone.free()


## The pad numbers as the spec draws them (§3.1).
static func _pad_numbers(fails: Array[String]) -> void:
	var pad: Dictionary = LeadlightSeat.for_stage(&"pad-landscape", Vector2(1180.0, 820.0))
	var wick: Vector2 = pad["wick"]
	_check(fails, wick.distance_to(Vector2(104.0, 761.0)) < 1.0, "the pad wick is not at (104, 761): %s" % wick)
	var pad_word: Rect2 = pad["word"]
	_check(fails, pad_word.is_equal_approx(Rect2(152.0, 742.0, 150.0, 64.0)),
		"the pad Return is not at (152, 742) 150×64")
	var phone: Dictionary = LeadlightSeat.for_stage(&"phone-landscape", Vector2(844.0, 390.0))
	var phone_wick: Vector2 = phone["wick"]
	_check(fails, phone_wick.distance_to(Vector2(62.0, 370.0)) < 1.0,
		"the phone wick is not at (62, 370): %s" % phone_wick)
