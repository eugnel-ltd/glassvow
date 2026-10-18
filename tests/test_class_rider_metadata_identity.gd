extends RefCounted
## #544 A4 owns four display maps and sixteen existing localized text leaves.
## Unrelated catalogue/locale additions remain free to evolve. The immutable
## whole-catalogue historical reconstruction is retained in the delivery proof.

const OldCopy: GDScript = preload("res://tests/test_class_rider_printing.gd")
const LivePins: GDScript = preload("res://tests/test_balance_catalogue.gd")
const WORDS: Dictionary = {
	"lantern": {"en": " Amber flame: gain 1 Ember.", "zh-Hant": "金黃之火：獲得 1 點餘燼。"},
	"edge": {"en": " Blood-moon flame: gain #3# Ward.", "zh-Hant": "血月之火：獲得 #3# 點護光。"},
}
const PRE_A4_ROWS: Dictionary = {
	"preparation": {
		"type": "skill",
		"rarity": "common",
		"cost": 0,
		"target": "self",
		"vfx": "fire",
		"exhaust": true,
		"effects": [
			{
				"kind": "draw",
				"n": 2
			},
			{
				"kind": "ember",
				"n": 1,
				"lit": "lantern"
			}
		],
		"up": {
			"exhaust": false,
			"effects": [
				{
					"kind": "draw",
					"n": 2
				},
				{
					"kind": "ember",
					"n": 1,
					"lit": "lantern"
				}
			],
			"text": "Draw 2 cards. Amber flame: gain 1 Ember."
		},
		"name": "Tinder",
		"text": "Draw 2 cards. Kindle. Amber flame: gain 1 Ember."
	},
	"surge": {
		"type": "skill",
		"rarity": "uncommon",
		"cost": 0,
		"target": "self",
		"vfx": "fire",
		"exhaust": true,
		"effects": [
			{
				"kind": "energy",
				"n": 1
			},
			{
				"kind": "draw",
				"n": 1
			},
			{
				"kind": "ember",
				"n": 1,
				"lit": "lantern"
			}
		],
		"up": {
			"effects": [
				{
					"kind": "energy",
					"n": 2
				},
				{
					"kind": "draw",
					"n": 1
				},
				{
					"kind": "ember",
					"n": 1,
					"lit": "lantern"
				}
			],
			"text": "Gain 2 Energy. Draw 1 card. Kindle. Amber flame: gain 1 Ember."
		},
		"name": "Struck Match",
		"text": "Gain 1 Energy. Draw 1 card. Kindle. Amber flame: gain 1 Ember."
	},
	"tithe": {
		"type": "skill",
		"rarity": "uncommon",
		"cost": 1,
		"target": "self",
		"locked": "lanternFed",
		"vfx": "fire",
		"effects": [
			{
				"kind": "ember",
				"n": 2
			},
			{
				"kind": "draw",
				"n": 1
			},
			{
				"kind": "ember",
				"n": 1,
				"lit": "lantern"
			}
		],
		"up": {
			"effects": [
				{
					"kind": "ember",
					"n": 3
				},
				{
					"kind": "draw",
					"n": 1
				},
				{
					"kind": "ember",
					"n": 1,
					"lit": "lantern"
				}
			],
			"text": "Gain 3 Embers. Draw 1 card. Amber flame: gain 1 Ember."
		},
		"name": "Tithe of Panes",
		"text": "Gain 2 Embers. Draw 1 card. Amber flame: gain 1 Ember."
	},
	"warCry": {
		"type": "skill",
		"rarity": "uncommon",
		"cost": 1,
		"target": "allEnemies",
		"vfx": "void",
		"effects": [
			{
				"kind": "status",
				"who": "allEnemies",
				"id": "weak",
				"n": 1
			},
			{
				"kind": "status",
				"who": "allEnemies",
				"id": "vulnerable",
				"n": 1
			},
			{
				"kind": "block",
				"n": 3,
				"lit": "edge"
			}
		],
		"up": {
			"effects": [
				{
					"kind": "status",
					"who": "allEnemies",
					"id": "weak",
					"n": 2
				},
				{
					"kind": "status",
					"who": "allEnemies",
					"id": "vulnerable",
					"n": 2
				},
				{
					"kind": "block",
					"n": 3,
					"lit": "edge"
				}
			],
			"text": "Apply 2 Dimmed and 2 Cracked to ALL enemies. Blood-moon flame: gain #3# Ward."
		},
		"name": "Shatterhymn",
		"text": "Apply 1 Dimmed and 1 Cracked to ALL enemies. Blood-moon flame: gain #3# Ward."
	}
}
const CANDIDATE: String = "user://test-class-rider-metadata-identity.json"


static func run(fails: Array[String]) -> void:
	var before: String = FileAccess.get_sha256(ContentDB.FULL_PATH)
	var raw_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(ContentDB.FULL_PATH))
	if typeof(raw_v) != TYPE_DICTIONARY:
		fails.append("rider metadata identity: live catalogue did not parse")
		return
	var raw: Dictionary = raw_v
	var cards: Dictionary = raw.get("cards", {})
	var without: Dictionary = raw.duplicate(true)
	var stripped_cards: Dictionary = without.get("cards", {})
	for id: String in ["preparation", "surge", "tithe", "warCry"]:
		var way: String = "edge" if id == "warCry" else "lantern"
		var row: Dictionary = cards.get(id, {})
		if row.get("litText", {}) != WORDS[way]:
			fails.append("rider metadata identity: %s is not the exact bilingual display map" % id)
		for language: String in OldCopy.COPY:
			var locale: Locale = Locale.new(StringName(language))
			for upgrade: int in range(2):
				var leaf: String = "textUp" if upgrade else "text"
				var full: String = OldCopy.COPY[language][id]["full"][upgrade]
				if locale.t("content.cards.%s.%s" % [id, leaf]) != full:
					fails.append("rider metadata identity: existing %s/%s/%s string changed"
						% [id, language, leaf])
				if not full.ends_with(str(WORDS[way][language]).strip_edges()):
					fails.append("rider metadata identity: %s/%s/%s map is not its existing suffix"
						% [id, language, leaf])
		var stripped: Dictionary = stripped_cards.get(id, {})
		stripped.erase("litText")
		if stripped != JSON.parse_string(JSON.stringify(PRE_A4_ROWS[id])):
			fails.append("rider metadata identity: existing %s catalogue fields changed" % id)
	var live: Dictionary = BalanceCatalogue.open({})
	var identity: Dictionary = _identity(fails, live, "live")
	if identity.is_empty():
		return
	if str(identity.get("contentFileSha256", "")) != LivePins.LIVE_FILE \
			or str(identity.get("contentSemanticSha256", "")) != LivePins.LIVE_SEMANTIC:
		fails.append("rider metadata identity: current-live guards do not identify all live JSON")
	# Only four display maps differ; the simulator must report their provenance,
	# even though gameplay is unchanged. Do not filter metadata from its hash.
	var removed: Dictionary = _candidate_identity(fails, without, "without display maps")
	var reserialized: Dictionary = _candidate_identity(fails, raw, "same complete JSON")
	# Compare two equally serialized candidates: JSON.parse_string normalizes
	# integer values to floats, independently of the metadata under test.
	if not removed.is_empty() and not reserialized.is_empty() \
			and removed.get("contentSemanticSha256", "") \
			== reserialized.get("contentSemanticSha256", ""):
		fails.append("rider metadata identity: all-JSON identity omitted the four display maps")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CANDIDATE))
	if FileAccess.get_sha256(ContentDB.FULL_PATH) != before:
		fails.append("rider metadata identity: candidate checks changed live content")


static func _candidate_identity(fails: Array[String], value: Dictionary, label: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(CANDIDATE, FileAccess.WRITE)
	if file == null:
		fails.append("rider metadata identity: cannot write " + label)
		return {}
	file.store_string(JSON.stringify(value))
	file.close()
	return _identity(fails, BalanceCatalogue.open({"content": CANDIDATE}), label)


static func _identity(fails: Array[String], opened: Dictionary, label: String) -> Dictionary:
	if opened.has("error"):
		fails.append("rider metadata identity: %s failed to open: %s" % [label, opened["error"]])
		return {}
	var identity: Dictionary = opened.get("identity", {})
	if str(identity.get("contentFileSha256", "")).length() != 64 \
			or str(identity.get("contentSemanticSha256", "")).length() != 64:
		fails.append("rider metadata identity: " + label + " omitted raw/all-JSON hashes")
		return {}
	return identity
