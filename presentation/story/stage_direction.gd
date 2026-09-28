class_name StageDirection
extends RefCounted
## Stagecraft vocabulary for scripted scenes: who stands where, which glass is
## lit, how a line is spoken, and which effects punctuate it. Pure data — the
## parser validates `content/scenes.json` against it and `fold` rebuilds the
## stage at any cursor, so a resumed or captured scene stands exactly as a
## played-through one did (07-scenes §1: persistence-gated advance).
##
## Directions ride on lines, never on extra steps, so the saved cursor keeps
## meaning "line index" and no save migration is owed.

## How a line is delivered. `speech` is the default for a named speaker and
## `narration` for none; the rest are authored choices.
const STYLE_SPEECH: StringName = &"speech"
const STYLE_NARRATION: StringName = &"narration"
const STYLE_SHOUT: StringName = &"shout"
const STYLE_WHISPER: StringName = &"whisper"
const STYLE_CHORUS: StringName = &"chorus"
const STYLE_TITLE: StringName = &"title"
const STYLES: Array[StringName] = [
	STYLE_SPEECH, STYLE_NARRATION, STYLE_SHOUT, STYLE_WHISPER,
	STYLE_CHORUS, STYLE_TITLE,
]

## Portrait seats, left to right. `left`/`right` are the classic pair; the
## outer seats let a third and fourth voice stand without crowding.
const SLOTS: Array[StringName] = [
	&"far-left", &"left", &"centre", &"right", &"far-right",
]
## Horizontal seat centres as a fraction of stage width.
const SLOT_X: Dictionary[StringName, float] = {
	&"far-left": 0.08, &"left": 0.20, &"centre": 0.50,
	&"right": 0.80, &"far-right": 0.92,
}

## One-shot effects a line may fire when it is presented live. Resume and
## capture never replay them: an effect is an event, not a state.
const FX: Array[StringName] = [
	&"shake", &"quake", &"flash", &"flash-ember", &"flash-cold", &"flash-blood",
	&"impact", &"slash", &"crack", &"shatter", &"kindle", &"rays", &"pulse",
	&"hop", &"recoil", &"dim",
]
## Effects that may name an actor (`recoil@lamplighter`). The rest are
## screen-wide and ignore a target.
const ACTOR_FX: Array[StringName] = [&"hop", &"recoil", &"shake", &"kindle"]

## Beat-level presentation.
const TRANSITIONS: Array[StringName] = [
	&"cut", &"fade", &"black", &"white", &"flash", &"wake",
]
const AMBIENTS: Array[StringName] = [
	&"none", &"embers", &"ash", &"motes", &"snow-glass",
]
const GRADES: Array[StringName] = [
	&"none", &"hearth", &"cold", &"dusk", &"inverted",
]

const CLEAR_ALL: String = "*"


## The style a line is actually delivered in.
static func style_of(line: Dictionary) -> StringName:
	var authored: String = str(line.get("style", ""))
	if not authored.is_empty():
		return StringName(authored)
	return STYLE_NARRATION if str(line.get("speaker", "")).is_empty() else STYLE_SPEECH


## Validate and normalise one line's directions onto `out`. Returns "" on
## success or the failure message. `where` names the line for the message.
static func parse_line(raw: Dictionary, out: Dictionary, where: String) -> String:
	var style: String = str(raw.get("style", "")).strip_edges()
	if not style.is_empty():
		if not STYLES.has(StringName(style)):
			return "%s has unknown style '%s'" % [where, style]
		out["style"] = style
	for field: String in ["mood", "sfx", "focus"]:
		var value: String = str(raw.get(field, "")).strip_edges()
		if not value.is_empty():
			out[field] = value
	if raw.has("enter"):
		var enters: Variant = _enters(raw["enter"], where)
		if typeof(enters) == TYPE_STRING:
			return enters
		out["enter"] = enters
	if raw.has("exit"):
		var exits: Variant = _names(raw["exit"], where, "exit")
		if typeof(exits) == TYPE_STRING:
			return exits
		out["exit"] = exits
	if raw.has("moods"):
		var moods_v: Variant = raw["moods"]
		if typeof(moods_v) != TYPE_DICTIONARY:
			return "%s moods is not an object" % where
		var moods_raw: Dictionary = moods_v
		var moods: Dictionary = {}
		for id_v: Variant in moods_raw:
			var id: String = str(id_v).strip_edges()
			var mood: String = str(moods_raw[id_v]).strip_edges()
			if id.is_empty() or mood.is_empty():
				return "%s has an empty moods entry" % where
			moods[id] = mood
		out["moods"] = moods
	if raw.has("fx"):
		var fx: Variant = _fx(raw["fx"], where)
		if typeof(fx) == TYPE_STRING:
			return fx
		out["fx"] = fx
	return ""


## Validate a beat's presentation fields onto `out`.
static func parse_beat(raw: Dictionary, out: Dictionary, where: String) -> String:
	var checks: Array = [
		["transition", TRANSITIONS, &"cut"],
		["ambient", AMBIENTS, &"none"],
		["grade", GRADES, &"none"],
	]
	for check: Array in checks:
		var field: String = check[0]
		var allowed: Array[StringName] = check[1]
		var value: String = str(raw.get(field, "")).strip_edges()
		if value.is_empty():
			out[field] = check[2]
			continue
		if not allowed.has(StringName(value)):
			return "%s has unknown %s '%s'" % [where, field, value]
		out[field] = StringName(value)
	return ""


## The cast standing on stage once line `cursor` is presented, in seat order,
## plus who is lit. Every direction from line 0 through `cursor` is applied in
## order — exits, then entrances, then mood changes, then the speaker's own
## mood — so any cursor reproduces the stage a live playthrough built.
static func fold(lines: Array[Dictionary], cursor: int) -> Dictionary:
	var cast: Dictionary = {}  # id -> {"at": StringName, "mood": String}
	var last: int = mini(cursor, lines.size() - 1)
	for i: int in range(last + 1):
		_apply(cast, lines[i])
	var ordered: Array[Dictionary] = []
	for slot: StringName in SLOTS:
		for id: String in cast:
			var seat: Dictionary = cast[id]
			if seat["at"] == slot:
				ordered.append({"id": id, "at": slot, "mood": str(seat["mood"])})
	var focus: String = ""
	if last >= 0:
		var line: Dictionary = lines[last]
		focus = str(line.get("focus", line.get("speaker", "")))
		if focus == "none" or not cast.has(focus):
			focus = ""
	return {"cast": ordered, "focus": focus}


static func _apply(cast: Dictionary, line: Dictionary) -> void:
	var exits: Array = line.get("exit", [])
	for id_v: Variant in exits:
		var id: String = str(id_v)
		if id == CLEAR_ALL:
			cast.clear()
		else:
			cast.erase(id)
	var enters: Array = line.get("enter", [])
	for enter_v: Variant in enters:
		var enter: Dictionary = enter_v
		var id: String = str(enter["id"])
		var slot: StringName = StringName(str(enter["at"]))
		# One body per seat: whoever held it steps off.
		for other: String in cast.keys():
			var seat: Dictionary = cast[other]
			if other != id and seat["at"] == slot:
				cast.erase(other)
		var mood: String = str(enter.get("mood", ""))
		if mood.is_empty() and cast.has(id):
			var held: Dictionary = cast[id]
			mood = str(held["mood"])
		cast[id] = {"at": slot, "mood": mood}
	var moods: Dictionary = line.get("moods", {})
	for id_v: Variant in moods:
		var id: String = str(id_v)
		if cast.has(id):
			var seat: Dictionary = cast[id]
			seat["mood"] = str(moods[id_v])
	var speaker: String = str(line.get("speaker", ""))
	var own: String = str(line.get("mood", ""))
	if not own.is_empty() and cast.has(speaker):
		var seat: Dictionary = cast[speaker]
		seat["mood"] = own


## `"keeper@right"`, `"keeper@right:offering"` or
## `{"id": "keeper", "at": "right", "mood": "offering"}`.
static func _enters(raw: Variant, where: String) -> Variant:
	var items: Array = raw if typeof(raw) == TYPE_ARRAY else [raw]
	var out: Array[Dictionary] = []
	for item: Variant in items:
		var entry: Dictionary = {}
		if typeof(item) == TYPE_STRING:
			var text: String = str(item).strip_edges()
			var at_i: int = text.find("@")
			if at_i <= 0:
				return "%s enter '%s' names no seat" % [where, text]
			entry["id"] = text.substr(0, at_i)
			var rest: String = text.substr(at_i + 1)
			var mood_i: int = rest.find(":")
			if mood_i >= 0:
				entry["mood"] = rest.substr(mood_i + 1)
				rest = rest.substr(0, mood_i)
			entry["at"] = rest
		elif typeof(item) == TYPE_DICTIONARY:
			var d: Dictionary = item
			entry["id"] = str(d.get("id", "")).strip_edges()
			entry["at"] = str(d.get("at", "")).strip_edges()
			var mood: String = str(d.get("mood", "")).strip_edges()
			if not mood.is_empty():
				entry["mood"] = mood
		else:
			return "%s enter entry is not a string or object" % where
		if str(entry["id"]).is_empty():
			return "%s enter entry has no actor" % where
		if not SLOTS.has(StringName(str(entry["at"]))):
			return "%s enter '%s' has unknown seat '%s'" % [
				where, entry["id"], entry["at"]]
		out.append(entry)
	return out


static func _names(raw: Variant, where: String, field: String) -> Variant:
	var items: Array = raw if typeof(raw) == TYPE_ARRAY else [raw]
	var out: Array[String] = []
	for item: Variant in items:
		var name: String = str(item).strip_edges()
		if name.is_empty():
			return "%s has an empty %s entry" % [where, field]
		out.append(name)
	return out


## `"crack"` or `"recoil@lamplighter"`.
static func _fx(raw: Variant, where: String) -> Variant:
	var items: Array = raw if typeof(raw) == TYPE_ARRAY else [raw]
	var out: Array[String] = []
	for item: Variant in items:
		var text: String = str(item).strip_edges()
		var at_i: int = text.find("@")
		var fx_name: String = text if at_i < 0 else text.substr(0, at_i)
		if not FX.has(StringName(fx_name)):
			return "%s has unknown fx '%s'" % [where, fx_name]
		if at_i >= 0:
			if not ACTOR_FX.has(StringName(fx_name)):
				return "%s fx '%s' cannot target an actor" % [where, fx_name]
			if text.substr(at_i + 1).is_empty():
				return "%s fx '%s' names an empty target" % [where, text]
		out.append(text)
	return out


static func fx_name(entry: String) -> StringName:
	var at_i: int = entry.find("@")
	return StringName(entry if at_i < 0 else entry.substr(0, at_i))


static func fx_target(entry: String) -> String:
	var at_i: int = entry.find("@")
	return "" if at_i < 0 else entry.substr(at_i + 1)
