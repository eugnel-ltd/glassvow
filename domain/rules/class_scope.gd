class_name ClassScope
extends RefCounted
## Which classes this build offers a new pilgrimage (issue #543).
##
## 1.0 is the Duskblade; the Ashwarden returns in 1.1 (docs/release-roadmap.md).
## A deferred aspect row carries `"deferred": true` and stays in content with
## its canonical index, so a saved run, a monument's shade or a bequest that
## names it still loads as itself. Deferral only stops a new run starting as it
## and stops the game promising it. It never erases an earned unlock: the
## `aspect2` a first dawn grants is kept, and admits the Ashwarden again the
## build that stops deferring it.
##
## One policy, several call sites: Main asks `admits` before any new run's seed
## or save and before Begin Anew abandons the old run; Embark shows only
## `admitted`; the Vigil and the Dawn hide `withheld_unlocks` and any deed no
## offered class can pursue.


## Whether the build offers `aspect` at all, earned or not.
static func is_offered(content: ContentDB, aspect: int) -> bool:
	if content.aspects.is_empty():
		return aspect == 0  # slice content: RunState falls back to `content.player`
	if aspect < 0 or aspect >= content.aspects.size() \
			or typeof(content.aspects[aspect]) != TYPE_DICTIONARY:
		return false
	var row: Dictionary = content.aspects[aspect]
	return row.get("deferred", false) != true


## Whether a new run may start as `aspect` for a profile holding `unlocks`.
static func admits(content: ContentDB, aspect: int, unlocks: Array) -> bool:
	if not is_offered(content, aspect):
		return false
	if content.aspects.is_empty():
		return true
	var row: Dictionary = content.aspects[aspect]
	var unlock: String = str(row.get("unlock", ""))
	return unlock.is_empty() or unlocks.has(unlock)


## The canonical aspect indices a new run may start as, in content order.
static func admitted(content: ContentDB, unlocks: Array) -> Array[int]:
	var out: Array[int] = []
	for index: int in range(maxi(1, content.aspects.size())):
		if admits(content, index, unlocks):
			out.append(index)
	return out


## The unlock ids that would open a deferred class. They stay in the Vigil as
## earned history; nothing announces or offers them while the class is deferred.
static func withheld_unlocks(content: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for index: int in range(content.aspects.size()):
		if is_offered(content, index) or typeof(content.aspects[index]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = content.aspects[index]
		var unlock: String = str(row.get("unlock", ""))
		if not unlock.is_empty():
			out.append(unlock)
	return out


## Whether some offered class can pursue the deed. A deed every offered class
## excludes (its `excludes.deeds`) would sit in the Vigil at 0 for ever.
static func shows_deed(content: ContentDB, deed_id: String) -> bool:
	if content.aspects.is_empty():
		return true
	for index: int in range(content.aspects.size()):
		if not is_offered(content, index):
			continue
		var row: Dictionary = content.aspects[index]
		var excludes_v: Variant = row.get("excludes", {})
		var excluded: Array = []
		if typeof(excludes_v) == TYPE_DICTIONARY:
			var excludes: Dictionary = excludes_v
			var deeds_v: Variant = excludes.get("deeds", [])
			if typeof(deeds_v) == TYPE_ARRAY:
				excluded = deeds_v
		if not excluded.has(deed_id):
			return true
	return false
