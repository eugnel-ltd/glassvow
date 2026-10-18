extends RefCounted
## Explicit authoring previews can inspect a current card without rewriting
## the historical 61-card comparison sheet or mutating the live ContentDB.

const FIXTURE_SHA: String = "0120c3fd9ab6f6d382bdaf50a9cd8a504dab28c7b87d3147268ecf8de017161b"
const UNKNOWN: String = "no-such-current-preview-card"


class _TurnCapture:
	extends CardTurnSheet
	var seen: Array[Dictionary] = []

	func _card(data: Dictionary) -> CardView:
		seen.append(data.duplicate(true))
		return super._card(data)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var before: Dictionary = content.cards.duplicate(true)
	var oversample: float = CardView.oversample
	var wearing: String = CardTurn._wearing
	var locale: Locale = Locale.active
	Locale.active = Locale.new()
	_default_sheet(fails, content)
	_explicit_lab(fails, content)
	_explicit_studio(fails, content)
	_unknown_stays_unknown(fails, content)
	await _explicit_turn_sheet(fails, content)
	_check(fails, content.cards == before, "previews mutated the supplied ContentDB")
	_check(fails, FileAccess.get_sha256(CardLab.CATALOG_PATH) == FIXTURE_SHA,
		"previews changed the historical fixture bytes")
	CardView.oversample = oversample
	CardTurn._wearing = wearing
	Locale.active = locale


static func _default_sheet(fails: Array[String], content: ContentDB) -> void:
	_check(fails, FileAccess.get_sha256(CardLab.CATALOG_PATH) == FIXTURE_SHA,
		"the historical fixture no longer has its accepted identity")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CardLab.CATALOG_PATH))
	var expected: Dictionary = raw["cards"]
	var catalog: Dictionary = CardLab.load_catalog(content)
	_check(fails, expected.size() == 61, "the historical comparison is no longer 61 cards")
	_check(fails, not catalog.has("hearthfall"), "a current card leaked into the default catalogue")
	for id: Variant in expected:
		var same_row: bool = catalog.get(id) == expected[id]
		_check(fails, same_row, "default row %s changed" % str(id))
	var backs: Dictionary = CardLab.back_entries()
	_check(fails, catalog.size() == expected.size() + backs.size(),
		"the default catalogue gained or lost a row")
	for id: Variant in backs:
		var same_back: bool = catalog.get(id) == backs[id]
		_check(fails, same_back, "back entry %s changed" % str(id))
	var lab: CardLab = CardLab.new(content)
	_check(fails, lab._ordered.size() == 61, "the default sheet no longer draws 61 cards")
	lab.free()


static func _explicit_lab(fails: Array[String], content: ContentDB) -> void:
	var expected: Dictionary = content.cards["hearthfall"]
	var actual_hearthfall: bool = expected.get("name") == "Hearthfall" and expected.get("emberCost") == 3
	_check(fails, actual_hearthfall,
		"the regression did not load the actual current Hearthfall definition")
	var lab: CardLab = CardLab.new(content, PackedStringArray(["hearthfall"]))
	_check(fails, lab._ordered.size() == 1, "--cards=hearthfall did not build exactly one card")
	if lab._ordered.size() == 1:
		_check(fails, lab._ordered[0].card_id == &"hearthfall",
			"--cards=hearthfall built another card")
	var current_lab_row: bool = lab._catalog.get("hearthfall") == expected
	_check(fails, current_lab_row,
		"--cards=hearthfall did not use the current definition")
	# A shallow copy would share both nested effect and upgrade dictionaries.
	var row: Dictionary = lab._catalog.get("hearthfall", {})
	if not row.is_empty():
		var effects: Array = row.get("effects", [])
		if not effects.is_empty():
			var effect: Dictionary = effects[0]
			effect["n"] = -12345
		var upgraded: Dictionary = row.get("up", {})
		upgraded["text"] = "preview-only mutation"
		var independent_upgrade: bool = (content.cards["hearthfall"].get("up", {}).get("text")
			!= "preview-only mutation")
		_check(fails, independent_upgrade, "preview upgrade data aliases ContentDB")
		var source_effects: Array = content.cards["hearthfall"].get("effects", [])
		var independent_effect: bool = not source_effects.is_empty() and source_effects[0].get("n") != -12345
		_check(fails, independent_effect,
			"preview effect data aliases ContentDB")
	lab.free()


static func _explicit_studio(fails: Array[String], content: ContentDB) -> void:
	var studio: CardStudio = CardStudio.new(content, PackedStringArray(["hearthfall"]))
	_check(fails, studio._card_id == "hearthfall" and studio._card.card_id == &"hearthfall",
		"--studio=hearthfall silently selected another card")
	var current_studio_row: bool = studio._card_data() == content.cards["hearthfall"]
	_check(fails, current_studio_row,
		"--studio=hearthfall did not use the current definition")
	studio.free()


static func _unknown_stays_unknown(fails: Array[String], content: ContentDB) -> void:
	var lab: CardLab = CardLab.new(content, PackedStringArray([UNKNOWN]))
	_check(fails, lab._ordered.is_empty() and not lab._catalog.has(UNKNOWN),
		"an unknown explicit id produced an invented or fallback card")
	lab.free()


static func _explicit_turn_sheet(fails: Array[String], content: ContentDB) -> void:
	var sheet: _TurnCapture = _TurnCapture.new(content, "hearthfall")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var wanted: int = CardBacks.catalogue().ids().size() * 2 * CardTurnSheet.POSES.size()
	tree.root.add_child(sheet)
	# Each back warm advances a frame even on the headless path. Observe the
	# actual _ready route; no wall-clock sleep or mocked catalogue lookup.
	for _frame: int in range(30):
		if sheet.seen.size() == wanted:
			break
		await tree.process_frame
	_check(fails, sheet._card_id == "hearthfall", "--turns=hearthfall fell back to another card")
	_check(fails, sheet.seen.size() == wanted, "the explicit turn sheet did not finish every pose")
	for row: Dictionary in sheet.seen:
		var current_turn_row: bool = row == content.cards["hearthfall"]
		_check(fails, current_turn_row,
			"--turns=hearthfall did not use the current definition")
	sheet.queue_free()
	await tree.process_frame


static func _check(fails: Array[String], ok: bool, detail: String) -> void:
	if not ok:
		fails.append("current card previews: " + detail)
