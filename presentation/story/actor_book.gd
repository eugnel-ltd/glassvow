class_name ActorBook
extends RefCounted
## Who can stand on a scripted scene's stage: display name, home seat, glass
## tint, the crop that turns a full-figure cutout into a portrait bust, and one
## portrait per mood (`content/actors.json`).
##
## Every mood portrait shares its actor's canvas and framing — they are
## image-to-image variants of the shipped figure — so one crop serves them
## all and a mood swap reads as the same body shifting, never a redraw. A mood
## whose art has not landed yet falls back along its `fallback` chain to the
## actor's default, and `resolve` says so; the stage then carries the mood in
## light and posture instead (PortraitStage.MOOD_LOOKS). Dropping the file at
## its ledgered path is the whole art integration — no code change.

const PATH: String = "res://content/actors.json"
const DEFAULT_MOOD: String = "default"
## The player's own figure is the run's chosen aspect, resolved at play time.
const HERO_TOKEN: String = "@hero"
const HERO_ART: String = "res://assets/art/heroes/%s.png"
const HERO_FALLBACK: String = "duskblade"
const SIDES: Array[StringName] = [&"left", &"centre", &"right"]

static var _shared: ActorBook = null

var actors: Dictionary = {}


## The shipped registry, parsed once. A malformed file yields an empty book —
## scenes still play as voices without bodies rather than failing to mount.
static func shared() -> ActorBook:
	if _shared != null:
		return _shared
	var loaded: Variant = load_file(PATH)
	_shared = loaded if loaded is ActorBook else ActorBook.new()
	return _shared


static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return _fail("actors: missing %s" % path)
	return parse(JSON.parse_string(FileAccess.get_file_as_string(path)))


static func parse(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("actors: root is not an object")
	var root: Dictionary = raw
	var actors_v: Variant = root.get("actors")
	if typeof(actors_v) != TYPE_DICTIONARY:
		return _fail("actors: missing actors object")
	var book: ActorBook = ActorBook.new()
	var table: Dictionary = actors_v
	for id_v: Variant in table:
		var id: String = str(id_v)
		var built: Variant = _actor(id, table[id_v])
		if typeof(built) == TYPE_STRING:
			return built
		book.actors[id] = built
	return book


func has(id: String) -> bool:
	return actors.has(id)


func name_key(id: String) -> String:
	return str(_row(id).get("name", ""))


func side(id: String) -> StringName:
	return StringName(str(_row(id).get("side", "right")))


## Which way the source art looks. The stage mirrors a figure seated on the
## other half so every portrait faces the conversation.
func faces(id: String) -> StringName:
	return StringName(str(_row(id).get("faces", "left")))


func tint(id: String) -> Color:
	return _row(id).get("tint", RunStyle.GOLD)


func crop(id: String) -> Rect2:
	return _row(id).get("crop", Rect2(0.0, 0.0, 1.0, 1.0))


func moods(id: String) -> PackedStringArray:
	var portraits: Dictionary = _row(id).get("portraits", {})
	return PackedStringArray(portraits.keys())


## The portrait to draw for `id` in `mood`. `exact` is false when the mood's
## own art is absent and a fallback stands in; `path` is empty only when the
## actor has no drawable art at all (a voice without a body).
func resolve(id: String, mood: String, hero: String = "") -> Dictionary:
	var portraits: Dictionary = _row(id).get("portraits", {})
	var want: String = mood if portraits.has(mood) else DEFAULT_MOOD
	var at: String = want
	var seen: Dictionary = {}
	while not at.is_empty() and not seen.has(at) and portraits.has(at):
		seen[at] = true
		var entry: Dictionary = portraits[at]
		var path: String = str(entry["art"])
		if path == HERO_TOKEN:
			path = HERO_ART % (hero if not hero.is_empty() else HERO_FALLBACK)
		if ResourceLoader.exists(path):
			return {
				"path": path,
				"mood": want,
				"exact": at == want,
				"rim": StringName(str(entry.get("rim", _row(id).get("rim", "right")))),
			}
		at = str(entry.get("fallback", DEFAULT_MOOD if at != DEFAULT_MOOD else ""))
	return {"path": "", "mood": want, "exact": false, "rim": &"right"}


func _row(id: String) -> Dictionary:
	var row: Variant = actors.get(id, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


static func _actor(id: String, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("actors: %s is not an object" % id)
	var row: Dictionary = raw
	var out: Dictionary = {"name": str(row.get("name", "")).strip_edges()}
	var seat: String = str(row.get("side", "right"))
	if not SIDES.has(StringName(seat)):
		return _fail("actors: %s has unknown side '%s'" % [id, seat])
	out["side"] = seat
	var facing: String = str(row.get("faces", "left"))
	if facing != "left" and facing != "right":
		return _fail("actors: %s faces '%s'" % [id, facing])
	out["faces"] = facing
	var rim: String = str(row.get("rim", "right"))
	if rim != "left" and rim != "right":
		return _fail("actors: %s has rim '%s'" % [id, rim])
	out["rim"] = rim
	var tint_text: String = str(row.get("tint", "#f2c14e"))
	if not Color.html_is_valid(tint_text):
		return _fail("actors: %s has tint '%s'" % [id, tint_text])
	out["tint"] = Color.html(tint_text)
	var crop_v: Variant = row.get("crop", [0.0, 0.0, 1.0, 1.0])
	if typeof(crop_v) != TYPE_ARRAY:
		return _fail("actors: %s crop is not [x, y, w, h]" % id)
	var c: Array = crop_v
	if c.size() != 4:
		return _fail("actors: %s crop is not [x, y, w, h]" % id)
	var crop_rect: Rect2 = Rect2(float(str(c[0])), float(str(c[1])),
		float(str(c[2])), float(str(c[3])))
	if crop_rect.position.x < 0.0 or crop_rect.position.y < 0.0 \
			or crop_rect.size.x <= 0.0 or crop_rect.size.y <= 0.0 \
			or crop_rect.end.x > 1.0001 or crop_rect.end.y > 1.0001:
		return _fail("actors: %s crop leaves the canvas" % id)
	out["crop"] = crop_rect
	var portraits_v: Variant = row.get("portraits")
	if typeof(portraits_v) != TYPE_DICTIONARY:
		return _fail("actors: %s has no portraits" % id)
	var portraits_raw: Dictionary = portraits_v
	if not portraits_raw.has(DEFAULT_MOOD):
		return _fail("actors: %s has no default portrait" % id)
	var portraits: Dictionary = {}
	for mood_v: Variant in portraits_raw:
		var mood: String = str(mood_v)
		var entry_v: Variant = portraits_raw[mood_v]
		var entry: Dictionary = {}
		if typeof(entry_v) == TYPE_STRING:
			entry["art"] = str(entry_v)
		elif typeof(entry_v) == TYPE_DICTIONARY:
			var d: Dictionary = entry_v
			entry["art"] = str(d.get("art", ""))
			for field: String in ["fallback", "rim"]:
				if d.has(field):
					entry[field] = str(d[field])
		else:
			return _fail("actors: %s mood %s is not a path or object" % [id, mood])
		var art: String = str(entry["art"])
		if art != HERO_TOKEN and not art.begins_with("res://assets/art/"):
			return _fail("actors: %s mood %s art '%s' is outside assets/art" % [id, mood, art])
		if entry.has("fallback") and not portraits_raw.has(entry["fallback"]):
			return _fail("actors: %s mood %s falls back to undeclared '%s'"
				% [id, mood, entry["fallback"]])
		if entry.has("rim") and entry["rim"] != "left" and entry["rim"] != "right":
			return _fail("actors: %s mood %s has rim '%s'" % [id, mood, entry["rim"]])
		portraits[mood] = entry
	out["portraits"] = portraits
	return out


static func _fail(message: String) -> String:
	push_error(message)
	return message
