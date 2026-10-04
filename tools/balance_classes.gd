class_name BalanceClasses
extends RefCounted
## What the balance tools know about a class that content does not hold
## (#544 P3). `tools/balance_classes.json` maps an aspect id to its `wayStats`:
## for each way, the run stat its play produces (the Duskblade's Shatter, Kindle
## and Cracked). The search player scores those stats as the ways' verbs and the
## simulator records their per-fight rates. Everything else about a class (way
## ids, affinities, crowns) is read from content, so a class that declares no
## ways needs no entry here, and a later class is one entry plus its content
## ways. `content/full-content.json` stays untouched: the 1.0 verdict is bound
## to its SHA-256 (docs/rc-bar.md P9).
const PATH: String = "res://tools/balance_classes.json"
static var _table: Dictionary = {}


## {way id: stat} for an aspect id; empty when the file does not list the class.
static func way_stats(aspect_id: String) -> Dictionary:
	if _table.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("balance_classes: %s is not a JSON object" % PATH)
			return {}
		_table = raw
	var row_v: Variant = _table.get(aspect_id, {})
	var row: Dictionary = row_v if typeof(row_v) == TYPE_DICTIONARY else {}
	var stats_v: Variant = row.get("wayStats", {})
	return stats_v if typeof(stats_v) == TYPE_DICTIONARY else {}


## The run stats of the aspect's ways, in content order. A content way the file
## gives no stat is an error, never a silent zero.
static func expression_stats(content: ContentDB, aspect: int) -> Array[String]:
	var out: Array[String] = []
	if aspect < 0 or aspect >= content.aspects.size():
		return out
	var stats: Dictionary = way_stats(str(content.aspects[aspect].get("id", "")))
	for way: Dictionary in Flame.ways(content, aspect):
		var id: String = str(way.get("id", ""))
		if not stats.has(id):
			push_error("balance_classes: no wayStats entry for way %s of %s" % [id,
				content.aspects[aspect].get("id", "")])
			continue
		out.append(str(stats[id]))
	return out
