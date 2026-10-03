extends RefCounted
## Card backs (issue #657, PR 1): the catalogue is valid content, the choice
## round-trips through settings.cfg and falls back to the default when unknown
## or locked, the unlocks read real Vigil state (through the save's own load
## path) and never write it, the grant list is read when the Vigil carries one,
## and the bake cache is dropped exactly when the catalogue or the choice
## changes. Paths are test-owned; nothing here can touch real settings or saves.

const TEST_SETTINGS: String = "user://test_card_backs_settings.cfg"
const TEST_LEGACY: String = "user://test_card_backs_audio.cfg"
const TEST_VIGIL: String = "user://test_card_backs_vigil.json"
const ROSE: String = "res://presentation/cards/backs/rose.gdshader"
const ECLIPSE: String = "res://presentation/cards/backs/eclipse.gdshader"
const VAULT_ART: String = "res://assets/art/piles/draw.png"


static func run(fails: Array[String]) -> void:
	_cleanup()
	CardBacks.use_catalogue(null)
	_shipped_catalogue_is_valid(fails)
	_malformed_catalogues_refused(fails)
	_backs_build_their_pictures(fails)
	_preference_round_trip(fails)
	_chosen_falls_back(fails)
	_unlocks_read_the_saved_vigil(fails)
	_grant_list_is_read(fails)
	_bake_cache_invalidation(fails)
	_lab_wears_the_catalogue(fails)
	CardBacks.use_catalogue(null)
	_cleanup()


static func _shipped_catalogue_is_valid(fails: Array[String]) -> void:
	var parsed: Variant = CardBackCatalogue.load_file(CardBackCatalogue.PATH)
	if not parsed is CardBackCatalogue:
		fails.append("card backs: shipped catalogue refused: %s" % str(parsed))
		return
	var cat: CardBackCatalogue = parsed
	if _names(cat.ids()) != "vault,rose,eclipse":
		fails.append("card backs: shipped ids %s, want vault, rose, eclipse" % _names(cat.ids()))
	if cat.default_id != "vault":
		fails.append("card backs: the starter back is %s, want vault" % cat.default_id)
	var pictures: Dictionary = {"vault": VAULT_ART, "rose": ROSE, "eclipse": ECLIPSE}
	var surfaces: Dictionary = {"vault": "aurora", "rose": "prism", "eclipse": "gilt"}
	for id: String in pictures:
		var data: Dictionary = cat.card_data(id)
		if data.get("back") != pictures[id] or data.get("surface") != surfaces[id]:
			fails.append("card backs: %s builds %s, want %s on %s"
				% [id, str(data), pictures[id], surfaces[id]])
	if not load(VAULT_ART) is Texture2D:
		fails.append("card backs: the Vault painting does not load as a texture")
	for path: String in [ROSE, ECLIPSE]:
		var shader: Shader = load(path)
		if shader == null:
			fails.append("card backs: %s does not load as a shader" % path)
			continue
		var names: Array[String] = []
		for uniform: Dictionary in shader.get_shader_uniform_list():
			names.append(str(uniform.get("name", "")))
		if not names.has("card"):
			fails.append("card backs: %s has no `card` uniform for CardView to size" % path)
		if _reads_time(shader.code):
			fails.append("card backs: %s reads TIME, but a resting face is frozen" % path)


static func _malformed_catalogues_refused(fails: Array[String]) -> void:
	var good: Dictionary = {"v": 1, "default": "vault", "backs": {
		"vault": {"art": VAULT_ART, "surface": "aurora", "unlock": {"kind": "default"}},
		"rose": {"shader": ROSE, "surface": "prism", "unlock": {"kind": "shards", "at": 1}},
	}}
	if not CardBackCatalogue.parse(good) is CardBackCatalogue:
		fails.append("card backs: a minimal good catalogue was refused: %s"
			% str(CardBackCatalogue.parse(good)))
	var cases: Dictionary = {
		"root not an object": [],
		"wrong version": _with(good, ["v"], 2),
		"no backs": _with(good, ["backs"], {}),
		"default not a back": _with(good, ["default"], "missing"),
		"default locked": _with(good, ["backs", "vault", "unlock"], {"kind": "grant"}),
		"second default kind": _with(good, ["backs", "rose", "unlock"], {"kind": "default"}),
		"art and shader": _with(good, ["backs", "rose", "art"], VAULT_ART),
		"neither picture": _with(good, ["backs", "rose", "shader"], ""),
		"missing art": _with(good, ["backs", "vault", "art"], "res://nope.png"),
		"shader as art": _with(good, ["backs", "vault", "art"], ROSE),
		"art as shader": _with(good, ["backs", "rose", "shader"], VAULT_ART),
		"unknown surface": _with(good, ["backs", "rose", "surface"], "velour"),
		"unknown kind": _with(good, ["backs", "rose", "unlock"], {"kind": "quest"}),
		"unknown deed": _with(good, ["backs", "rose", "unlock"],
			{"kind": "deed", "deed": "victories", "at": 1}),
		"deed at zero": _with(good, ["backs", "rose", "unlock"],
			{"kind": "deed", "deed": "wins", "at": 0}),
		"fractional count": _with(good, ["backs", "rose", "unlock"],
			{"kind": "deed", "deed": "wins", "at": 1.5}),
		"more shards than quests": _with(good, ["backs", "rose", "unlock"],
			{"kind": "shards", "at": VigilState.QUEST_IDS.size() + 1}),
		"id not an identifier": _renamed(good, "rose", "back:rose"),
	}
	for label: String in cases:
		var result: Variant = CardBackCatalogue.parse(cases[label])
		if not result is String:
			fails.append("card backs: catalogue with %s was accepted" % label)


static func _backs_build_their_pictures(fails: Array[String]) -> void:
	var rose: CardView = CardBacks.build("rose")
	var plate: ColorRect = null
	for node: Node in rose.find_children("", "ColorRect", true, false):
		var rect: ColorRect = node
		var material: ShaderMaterial = rect.material as ShaderMaterial
		if material != null and material.shader != null and material.shader.resource_path == ROSE:
			plate = rect
	if plate == null:
		fails.append("card backs: the Rose back built no shader plate")
	else:
		var card_px: Variant = (plate.material as ShaderMaterial).get_shader_parameter("card")
		if card_px != Vector2(CardView.CARD_W, CardView.CARD_H):
			fails.append("card backs: the plate was sized %s, not the card" % str(card_px))
	rose.free()
	var vault: CardView = CardBacks.build("vault")
	var painted: bool = false
	for node: Node in vault.find_children("", "TextureRect", true, false):
		var rect: TextureRect = node
		var crop: AtlasTexture = rect.texture as AtlasTexture
		painted = painted or (crop != null and crop.atlas.resource_path == VAULT_ART)
	if not painted:
		fails.append("card backs: the Vault back did not wear the draw painting")
	vault.free()


static func _preference_round_trip(fails: Array[String]) -> void:
	_cleanup()
	var prefs: Preferences = Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY)
	if prefs.card_back != "":
		fails.append("card backs: a fresh profile already holds a choice '%s'" % prefs.card_back)
	CardBacks.choose(prefs, "rose")
	var again: Preferences = Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY)
	if again.card_back != "rose":
		fails.append("card backs: the choice did not survive a reload ('%s')" % again.card_back)
	var file: ConfigFile = ConfigFile.new()
	file.load(TEST_SETTINGS)
	if file.get_value("cosmetics", "card_back", "") != "rose":
		fails.append("card backs: the settings file does not hold [cosmetics] card_back")
	# An older build's file has no [cosmetics]; a hand-edited one may hold junk.
	file.erase_section("cosmetics")
	file.save(TEST_SETTINGS)
	if Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY).card_back != "":
		fails.append("card backs: a file without [cosmetics] did not read as no choice")
	file.set_value("cosmetics", "card_back", 7)
	file.save(TEST_SETTINGS)
	if Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY).card_back != "":
		fails.append("card backs: a non-string card_back was not read as no choice")
	if Preferences.read_from_disk(TEST_SETTINGS, TEST_LEGACY).volume(Preferences.MUSIC) \
			!= Preferences.DEFAULT_MUSIC:
		fails.append("card backs: the cosmetics section disturbed the audio settings")


static func _chosen_falls_back(fails: Array[String]) -> void:
	var blank: VigilState = VigilState.blank()
	var earned: VigilState = _vigil({"shards": ["paleOnes"], "wins": 1})
	var prefs: Preferences = Preferences.new()
	var vigils: Dictionary = {"blank": blank, "earned": earned, "none": null}
	var expect: Array = [
		["", "blank", "vault"], ["nonsense", "earned", "vault"],
		["rose", "blank", "vault"], ["eclipse", "blank", "vault"], ["rose", "none", "vault"],
		["rose", "earned", "rose"], ["eclipse", "earned", "eclipse"], ["vault", "earned", "vault"],
	]
	for row: Array in expect:
		prefs.card_back = row[0]
		var vigil: VigilState = vigils[row[1]]
		var got: String = CardBacks.chosen(prefs, vigil)
		if got != row[2]:
			fails.append("card backs: chose '%s' with a %s Vigil and wore %s, want %s"
				% [row[0], row[1], got, row[2]])
	if CardBacks.chosen(null, earned) != "vault":
		fails.append("card backs: no preferences did not wear the default")


static func _unlocks_read_the_saved_vigil(fails: Array[String]) -> void:
	var cat: CardBackCatalogue = CardBacks.catalogue()
	var expect: Array = [
		[{}, ["vault"]],
		[{"shards": ["paleOnes"]}, ["vault", "rose"]],
		[{"wins": 1}, ["vault", "eclipse"]],
		[{"shards": ["ownShade", "usurper"], "wins": 3}, ["vault", "rose", "eclipse"]],
		# The load path drops a shard from no known quest, so it earns nothing.
		[{"shards": ["notAQuest"]}, ["vault"]],
		[{"slain": 40, "runs": 9}, ["vault"]],
	]
	for row: Array in expect:
		var planted: Dictionary = row[0]
		var vigil: VigilState = _vigil(planted)
		var before: Dictionary = vigil.to_dict()
		var got: String = _names(cat.unlocked(vigil))
		var wanted: Array = row[1]
		var want: String = ",".join(PackedStringArray(wanted))
		if got != want:
			fails.append("card backs: Vigil %s unlocked %s, want %s" % [planted, got, want])
		if vigil.to_dict() != before:
			fails.append("card backs: reading unlocks wrote to the Vigil (%s)" % planted)


static func _grant_list_is_read(fails: Array[String]) -> void:
	var with_grant: Dictionary = {"v": 1, "default": "vault", "backs": {
		"vault": {"art": VAULT_ART, "surface": "aurora", "unlock": {"kind": "default"}},
		"rose": {"shader": ROSE, "surface": "prism", "unlock": {"kind": "shards", "at": 1}},
		"sigil": {"shader": ECLIPSE, "surface": "gilt", "unlock": {"kind": "grant"}},
	}}
	var cat: CardBackCatalogue = CardBackCatalogue.parse(with_grant)
	if not CardBackCatalogue.granted(VigilState.blank()).is_empty():
		fails.append("card backs: today's VigilState read a grant list it does not have")
	# Tomorrow's VigilState: the additive list, as the domain will declare it.
	var future: GDScript = GDScript.new()
	future.source_code = "extends VigilState\nvar card_backs: Array[String] = []\n"
	if future.reload() != OK:
		fails.append("card backs: could not stand up a Vigil with a grant list")
		return
	var vigil: VigilState = future.new()
	if cat.is_unlocked("sigil", vigil):
		fails.append("card backs: a grant-only back unlocked with no grant")
	var grants: Array[String] = ["sigil", "rose"]
	vigil.set(CardBackCatalogue.GRANT_FIELD, grants)
	if not cat.is_unlocked("sigil", vigil) or not cat.is_unlocked("rose", vigil):
		fails.append("card backs: a granted back stayed locked")
	if _names(cat.unlocked(vigil)) != "vault,rose,sigil":
		fails.append("card backs: granted unlocks read %s" % _names(cat.unlocked(vigil)))


static func _bake_cache_invalidation(fails: Array[String]) -> void:
	CardBacks.use_catalogue(null)
	var prefs: Preferences = Preferences.new()
	var at: float = CardView.oversample
	var bakes: Dictionary = {}
	for id: String in ["vault", "rose", "eclipse"]:
		var b: CardBacks.Baked = CardBacks.Baked.new()
		b.oversample = at
		bakes[id] = b
		CardBacks._bakes[id] = b
	if CardBacks.cached("rose") != bakes["rose"]:
		fails.append("card backs: a cached bake was not handed back")
	CardView.oversample = at + 1.0
	var at_other_scale: CardBacks.Baked = CardBacks.cached("rose")
	CardView.oversample = at
	if at_other_scale != null:
		fails.append("card backs: a bake was reused at another oversample")
	CardBacks.choose(prefs, "eclipse")
	if CardBacks.cached("eclipse") != bakes["eclipse"]:
		fails.append("card backs: choosing a back dropped its own bake")
	if CardBacks.cached("rose") != null or CardBacks.cached("vault") != null:
		fails.append("card backs: choosing a back kept the others' bakes")
	CardBacks.choose(prefs, "nonsense")
	if prefs.card_back != "eclipse" or CardBacks.cached("eclipse") == null:
		fails.append("card backs: an unknown choice was stored or dropped the bake")
	CardBacks.use_catalogue(CardBackCatalogue.shipped())
	if CardBacks.cached("eclipse") != null:
		fails.append("card backs: a catalogue change kept a bake made from the old one")
	CardBacks.use_catalogue(null)


static func _lab_wears_the_catalogue(fails: Array[String]) -> void:
	var entries: Dictionary = CardLab.back_entries()
	var keys: Array = entries.keys()
	if keys != ["back:vault", "back:rose", "back:eclipse"]:
		fails.append("card backs: the lab's backs are %s, want the catalogue's" % str(keys))
	for key: Variant in entries:
		var row: Dictionary = entries[key]
		var id: String = str(key).trim_prefix(CardLab.BACK_PREFIX)
		if row.get("rarity") != "back" \
				or row.get("back") != CardBacks.catalogue().card_data(id).get("back"):
			fails.append("card backs: lab entry %s does not wear the catalogue's back" % key)


## A Vigil as the game would load it: planted into the saved form on disk and
## read back through SaveService.load_vigil, so the unlocks see only what
## survives the real load path.
static func _vigil(planted: Dictionary) -> VigilState:
	var saved: Dictionary = VigilState.blank().to_dict()
	var deeds: Dictionary = saved["deeds"]
	for key: String in planted:
		if key == "shards":
			saved["shards"] = planted[key]
		else:
			deeds[key] = planted[key]
	var file: FileAccess = FileAccess.open(TEST_VIGIL, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	return SaveService.load_vigil(TEST_VIGIL)


## Whether shader code reads TIME, comments aside (the headers name it).
static func _reads_time(code: String) -> bool:
	var token: RegEx = RegEx.create_from_string("\\bTIME\\b")
	for line: String in code.split("\n"):
		if token.search(line.get_slice("//", 0)) != null:
			return true
	return false


static func _names(ids: Array[String]) -> String:
	return ",".join(PackedStringArray(ids))


## `doc` deep-copied with the value at `path` replaced.
static func _with(doc: Dictionary, path: Array, value: Variant) -> Dictionary:
	var out: Dictionary = doc.duplicate(true)
	var at: Dictionary = out
	for i: int in range(path.size() - 1):
		at = at[path[i]]
	at[path[path.size() - 1]] = value
	return out


static func _renamed(doc: Dictionary, from: String, to: String) -> Dictionary:
	var out: Dictionary = doc.duplicate(true)
	var backs: Dictionary = out["backs"]
	backs[to] = backs[from]
	backs.erase(from)
	return out


static func _cleanup() -> void:
	for path: String in [TEST_SETTINGS, TEST_LEGACY, TEST_VIGIL]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
