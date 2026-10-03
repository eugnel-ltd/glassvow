class_name CardBackCatalogue
extends RefCounted
## The card backs as content (`content/card-backs.json`), read by presentation
## only — the domain never sees a back. A back is a picture plus a CardSurface
## recipe: `art` (a painting on disk) or `shader` (a procedural canvas shader),
## and `surface`, so the stock, the edge, the shadow and the finish are the
## same system the fronts wear and a new back costs one entry.
##
## Each back also names the rule that unlocks it. The rules are pure reads of
## what the Vigil ledger already records, so earning a back writes nothing:
##
##   default            unlocked from the start (exactly the `default` back)
##   deed  {deed, at}   `vigil.deeds[deed] >= at`        (Eclipse: the first win)
##   shards {at}        `vigil.shards.size() >= at`      (Rose: the first shard)
##   grant              only through the Vigil's grant list, below
##
## The grant list is the seam for a back that no recorded deed can earn (a
## promotion, a one-off reward). VigilState has no such list yet; the day it
## gains the additive `cardBacks` list (the `dawnLeaves` precedent — never
## `unlocks`, which feeds the title's secrets count and the Dawn reveal), its
## field `card_backs` is read here with no change to this file. A granted back
## is unlocked whatever its own rule says.

const PATH: String = "res://content/card-backs.json"
const VERSION: int = 1
const UNLOCK_KINDS: Array[String] = ["default", "deed", "shards", "grant"]
## The VigilState field the grant list will live in (`cardBacks` on disk).
const GRANT_FIELD: StringName = &"card_backs"

## The back a player wears until they choose another, and the one every
## unknown or locked choice falls back to.
var default_id: String = ""
var _backs: Dictionary = {}          # id -> {back, surface, unlock}, file order


## The shipped catalogue, or an empty one if the file is unreadable. The suite
## guards the shipped file, so the empty case is a broken build, said loudly.
static func shipped() -> CardBackCatalogue:
	var parsed: Variant = load_file(PATH)
	if parsed is CardBackCatalogue:
		return parsed
	push_error(str(parsed))
	return CardBackCatalogue.new()


## Read and validate a catalogue file. Returns a CardBackCatalogue, or a String
## naming the first thing wrong with it.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return "card-backs: missing %s" % path
	return parse(JSON.parse_string(FileAccess.get_file_as_string(path)))


## Validate a parsed document. Everything a back needs to build is checked
## here, so a catalogue that parses can always be built and unlocked.
static func parse(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return "card-backs: root is not an object"
	var root: Dictionary = raw
	if _int_of(root.get("v")) != VERSION:
		return "card-backs: version is not %d" % VERSION
	var backs_v: Variant = root.get("backs")
	if typeof(backs_v) != TYPE_DICTIONARY:
		return "card-backs: backs is not an object"
	var backs: Dictionary = backs_v
	if backs.is_empty():
		return "card-backs: backs is empty"
	var out: CardBackCatalogue = CardBackCatalogue.new()
	for id_v: Variant in backs:
		var id: String = str(id_v)
		if not id.is_valid_ascii_identifier():
			return "card-backs: id '%s' is not a plain identifier" % id
		var row: Variant = _parse_back(id, backs[id_v])
		if row is String:
			return row
		out._backs[id] = row
	out.default_id = str(root.get("default", ""))
	if not out._backs.has(out.default_id):
		return "card-backs: default '%s' is not a back" % out.default_id
	for id: String in out.ids():
		var is_default_kind: bool = out._rule(id)["kind"] == "default"
		if is_default_kind != (id == out.default_id):
			return "card-backs: %s — only the default back unlocks by kind default" % id
	return out


static func _parse_back(id: String, value: Variant) -> Variant:
	var where: String = "card-backs: %s" % id
	if typeof(value) != TYPE_DICTIONARY:
		return "%s is not an object" % where
	var row: Dictionary = value
	var art: String = str(row.get("art", ""))
	var shader: String = str(row.get("shader", ""))
	if (art == "") == (shader == ""):
		return "%s needs exactly one of art and shader" % where
	if art != "" and not ResourceLoader.exists(art, "Texture2D"):
		return "%s art is not a texture: %s" % [where, art]
	# The type hint alone does not refuse an image named as a shader, so the
	# extension is checked too. Nothing is loaded here: a painted back costs
	# memory, and only the backs actually built should pay it.
	if shader != "" and (shader.get_extension() != "gdshader"
			or not ResourceLoader.exists(shader, "Shader")):
		return "%s shader is not a shader: %s" % [where, shader]
	var surface: String = str(row.get("surface", ""))
	if not CardSurface.RECIPES.has(surface):
		return "%s surface '%s' is not a recipe" % [where, surface]
	var unlock: Variant = _parse_unlock(row.get("unlock"))
	if unlock is String:
		return "%s unlock %s" % [where, unlock]
	return {"back": art if art != "" else shader, "surface": surface, "unlock": unlock}


static func _parse_unlock(value: Variant) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return "is not an object"
	var rule: Dictionary = value
	var kind: String = str(rule.get("kind", ""))
	match kind:
		"default", "grant":
			return {"kind": kind}
		"deed":
			var deed: String = str(rule.get("deed", ""))
			if not VigilState.DEFAULT_DEEDS.has(deed):
				return "names no Vigil deed: '%s'" % deed
			var at: int = _int_of(rule.get("at"))
			if at < 1:
				return "needs a whole count at >= 1"
			return {"kind": kind, "deed": deed, "at": at}
		"shards":
			var at: int = _int_of(rule.get("at"))
			if at < 1 or at > VigilState.QUEST_IDS.size():
				return "needs at between 1 and %d" % VigilState.QUEST_IDS.size()
			return {"kind": kind, "at": at}
	return "kind '%s' is not one of %s" % [kind, ", ".join(UNLOCK_KINDS)]


## A whole number from JSON (which parses every number as a float), or -1.
static func _int_of(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var whole: int = value
		return whole
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number == roundf(number):
			return int(number)
	return -1


## Every back, in the order the file lists them.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _backs:
		out.append(str(id))
	return out


func has(id: String) -> bool:
	return _backs.has(id)


## The CardView data that builds this back: its picture under `back` and its
## recipe under `surface`. Empty for an unknown id.
func card_data(id: String) -> Dictionary:
	if not _backs.has(id):
		return {}
	var row: Dictionary = _backs[id]
	return {"back": row["back"], "surface": row["surface"]}


## Whether `vigil` has earned this back. A null Vigil is a blank one: only the
## default is unlocked.
func is_unlocked(id: String, vigil: VigilState) -> bool:
	if not _backs.has(id):
		return false
	var rule: Dictionary = _rule(id)
	if rule["kind"] == "default":
		return true
	if vigil == null:
		return false
	if granted(vigil).has(id):
		return true
	match str(rule["kind"]):
		"deed":
			return _int_of(vigil.deeds.get(rule["deed"], 0)) >= _int_of(rule["at"])
		"shards":
			return vigil.shards.size() >= _int_of(rule["at"])
	return false


## The backs `vigil` has earned, in file order.
func unlocked(vigil: VigilState) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		if is_unlocked(id, vigil):
			out.append(id)
	return out


func _rule(id: String) -> Dictionary:
	var row: Dictionary = _backs[id]
	return row["unlock"]


## The Vigil's grant list, read and never written. Empty until VigilState
## carries the field (see the header); anything but a list reads as empty.
static func granted(vigil: VigilState) -> Array[String]:
	var out: Array[String] = []
	var list_v: Variant = vigil.get(GRANT_FIELD) if vigil != null else null
	if typeof(list_v) != TYPE_ARRAY:
		return out
	var list: Array = list_v
	for id: Variant in list:
		out.append(str(id))
	return out
