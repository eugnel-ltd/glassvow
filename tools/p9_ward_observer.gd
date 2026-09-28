class_name P9WardObserver
extends RefCounted
## Observation-only H11 readout. Event order supplies the application source boundary.

const VERSION: String = "p9-w0-v2-h11-player-dusk-enemy-smolder-observer-v1"
const COUNT_KEY: String = "h11PlayerDuskEnemySmolderApplications"
const SOURCE_BOUNDARIES: Array[String] = [
	"turn", "endTurn", "enemyAct", "intent", "art", "potion", "die", "shatter",
	"smolderJump", "combatEnd",
]


static func observe(events: Array, aspect: int) -> Dictionary:
	var counts: Dictionary = {}
	var player_card_source: String = ""
	for event_v: Variant in events:
		if typeof(event_v) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_v
		var kind: String = str(event.get("t", ""))
		if kind == "play":
			player_card_source = str(event.get("id", ""))
			continue
		if SOURCE_BOUNDARIES.has(kind):
			player_card_source = ""
			continue
		if aspect != 0 or player_card_source.is_empty() or kind != "status":
			continue
		if str(event.get("id", "")) != "poison" \
				or int(float(str(event.get("n", 0)))) <= 0 \
				or typeof(event.get("who")) != TYPE_INT:
			continue
		_bump(counts, COUNT_KEY)
	return counts


static func _bump(counts: Dictionary, key: String) -> void:
	counts[key] = int(float(str(counts.get(key, 0)))) + 1
