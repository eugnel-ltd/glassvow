extends RefCounted
## #544 A7 regression: an Ash reading must not spend the Duskblade's line.
## Committed before production edits; this fixture remains immutable.

static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var vigil: VigilState = VigilState.blank()
	var ash: RunState = RunState.new_run(content, 544, "a7-ash-steady", {"aspect": 1})
	var row: Dictionary = PoolBeats.draw(ash, vigil, content,
		FlameLines.SLOT_STEADY, FlameLines.SLOT_STEADY)
	if str(row.get("id", "")) != "flame.ashwarden.steady" \
			or LineTable.text(row, true) != "灰下的火，認得你了。" \
			or LineTable.text(row, false) != "Under the ash, the fire knows you now.":
		fails.append("A7: an Ash Steady reading selected %s (%s), instead of its Ash line" % [
			str(row.get("id", "")), LineTable.text(row, false)])
	if ash.pool_draws.has("flame.steady"):
		fails.append("A7: the Ash reading consumed the Duskblade Steady once id")
