extends RefCounted
## Flame lock PR 2 (docs/design/2026-09-29-dusk-flame): the purity mirror of
## §4, the Duskblade ways data of §6.1, and the FLAME event's read points.

const WAYS: Array[String] = ["shatter", "lantern", "edge"]
const CONSTANTS: Array[String] = [
	"minMass", "steadyMin", "trueMin", "sootMass", "sootMax", "fringeMin",
]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_worked_examples(content, fails)
	_true_and_duo(content, fails)
	_what_never_counts(content, fails)
	_curse_affinity_is_ignored(fails)
	_way_less_aspects_read_neutral(content, fails)
	_ways_content_is_valid(content, fails)
	_flame_read_points(content, fails)
	_way_less_aspect_emits_nothing(content, fails)


static func _num(value: Variant) -> float:
	var number: float = value
	return number


static func _dusk(content: ContentDB, tag: String) -> RunState:
	return RunState.new_run(content, 4242, "flame-%s" % tag, {"aspect": 0})


static func _add(run: RunState, ids: Array[String]) -> void:
	for id: String in ids:
		run.player.deck.append(CardInst.new(run.next_uid(), StringName(id), false))


static func _remove(run: RunState, id: String) -> void:
	for card: CardInst in run.player.deck:
		if String(card.id) == id:
			run.player.deck.erase(card)
			return


static func _expect(fails: Array[String], label: String, reading: Dictionary, mass: float,
		shares: Array[float], dominant: String, fringe: String, tier: String) -> void:
	var got: Dictionary = reading["shares"]
	var shares_ok: bool = got.size() == WAYS.size()
	for i: int in range(WAYS.size()):
		shares_ok = shares_ok and got.has(WAYS[i]) \
			and is_equal_approx(_num(got[WAYS[i]]), shares[i])
	var top: float = shares.max()
	if not is_equal_approx(_num(reading["mass"]), mass) or not shares_ok \
			or str(reading["dominant"]) != dominant or str(reading["fringe"]) != fringe \
			or str(reading["tier"]) != tier \
			or not is_equal_approx(_num(reading["purity"]), top):
		fails.append("flame %s: expected N=%s shares=%s %s/%s %s, got %s"
			% [label, mass, shares, dominant, fringe, tier, reading])


## §4 worked examples, row by row, with the Duskblade starters (chisel shatter,
## eclipseSlash edge, firstSpark lantern; everything else clear). A tie keeps
## the earlier way in content order (shatter, lantern, edge).
static func _worked_examples(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = _dusk(content, "worked")
	_expect(fails, "start", Flame.read(content, run), 3.0,
		[1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], "shatter", "lantern", Flame.TIER_KINDLING)
	_add(run, ["uppercut", "quakeblow"])
	_expect(fails, "+uppercut +quakeblow", Flame.read(content, run), 5.0,
		[0.6, 0.2, 0.2], "shatter", "", Flame.TIER_STEADY)
	_add(run, ["warCry"])
	_expect(fails, "+warCry", Flame.read(content, run), 6.0,
		[0.5, 1.0 / 6.0, 1.0 / 3.0], "shatter", "edge", Flame.TIER_KINDLING)
	_add(run, ["oblivionStrike", "limitBreak"])
	_expect(fails, "+oblivionStrike +limitBreak", Flame.read(content, run), 8.0,
		[0.625, 0.125, 0.25], "shatter", "edge", Flame.TIER_STEADY)
	_remove(run, "eclipseSlash")
	_expect(fails, "-eclipseSlash", Flame.read(content, run), 7.0,
		[5.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0], "shatter", "", Flame.TIER_STEADY)
	var scattered: RunState = _dusk(content, "soot")
	_add(scattered, ["uppercut", "preparation", "warCry"])
	_expect(fails, "two of each way", Flame.read(content, scattered), 6.0,
		[1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], "shatter", "lantern", Flame.TIER_SOOT)


static func _true_and_duo(content: ContentDB, fails: Array[String]) -> void:
	var pure: RunState = _dusk(content, "true")
	_add(pure, ["uppercut", "quakeblow", "warCry", "oblivionStrike", "limitBreak"])
	_remove(pure, "eclipseSlash")
	_remove(pure, "firstSpark")
	_expect(fails, "true", Flame.read(content, pure), 6.0,
		[5.0 / 6.0, 0.0, 1.0 / 6.0], "shatter", "", Flame.TIER_TRUE)
	var duo: RunState = _dusk(content, "duo")
	_add(duo, ["resonantLance"])
	_expect(fails, "duo resonantLance", Flame.read(content, duo), 4.0,
		[0.375, 0.25, 0.375], "shatter", "edge", Flame.TIER_KINDLING)


## Upgrades, relics, clear glass and curse or status cards never move the flame.
static func _what_never_counts(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = _dusk(content, "never")
	_add(run, ["uppercut", "quakeblow"])
	var before: Dictionary = Flame.read(content, run)
	for card: CardInst in run.player.deck:
		card.up = true
	for relic: String in ["bellOfEndings", "prismCharm", "crownOfCinders", "executionersSeal"]:
		run.player.relics.append(relic)
	_add(run, ["strike", "defend", "hex", "wound", "burn", "unreadablePage"])
	var after: Dictionary = Flame.read(content, run)
	if after != before:
		fails.append("flame: upgrades, relics, clear glass or curses moved the reading %s -> %s"
			% [before, after])


static func _curse_affinity_is_ignored(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var dusk: Dictionary = content.aspects[0]
	var shatter: Dictionary = dusk["ways"][0]
	var affinity: Dictionary = shatter["affinity"]
	affinity["hex"] = 1.0
	affinity["wound"] = 1.0
	var run: RunState = _dusk(content, "curse")
	var before: Dictionary = Flame.read(content, run)
	_add(run, ["hex", "wound"])
	if Flame.read(content, run) != before:
		fails.append("flame: a curse or status card counted as coloured glass")


static func _way_less_aspects_read_neutral(content: ContentDB, fails: Array[String]) -> void:
	var neutral: Dictionary = {"aspect": 1, "dominant": "", "fringe": "",
		"tier": Flame.TIER_KINDLING, "purity": 0.0, "shares": {}, "mass": 0.0}
	var ash: RunState = RunState.new_run(content, 4242, "flame-ash", {"aspect": 1})
	if Flame.read(content, ash) != neutral:
		fails.append("flame: Ashwarden (no ways) must read neutral, got %s" % Flame.read(content, ash))
	var slice: ContentDB = ContentDB.load_slice()
	var bare: RunState = RunState.new_run(slice, 4242, "flame-slice")
	neutral["aspect"] = 0
	if Flame.read(slice, bare) != neutral:
		fails.append("flame: content with no aspects must read neutral")
	if not Flame.ways(content, 7).is_empty() or not Flame.ways(content, -1).is_empty():
		fails.append("flame: an unknown aspect must declare no ways")
	var empty: RunState = _dusk(content, "empty")
	empty.player.deck.clear()
	var reading: Dictionary = Flame.read(content, empty)
	if str(reading["dominant"]) != "" or str(reading["tier"]) != Flame.TIER_KINDLING \
			or _num(reading["mass"]) != 0.0:
		fails.append("flame: a deck without coloured glass declares nothing, got %s" % reading)


## §6.1 as content: every id resolves, weights are 0.5 or 1.0 and total at most
## 1.0 per card or relic, crowns are boss relics, the §4 constants are present
## and ordered, and the Ashwarden declares nothing yet.
static func _ways_content_is_valid(content: ContentDB, fails: Array[String]) -> void:
	var ways: Array[Dictionary] = Flame.ways(content, 0)
	var ids: Array[String] = []
	for way: Dictionary in ways:
		ids.append(str(way.get("id", "")))
	if ids != WAYS:
		fails.append("ways content: Duskblade ways must be %s in content order, got %s" % [WAYS, ids])
	var card_totals: Dictionary = {}
	var relic_totals: Dictionary = {}
	for way: Dictionary in ways:
		var label: String = str(way.get("id", ""))
		_tally(fails, "%s card" % label, way.get("affinity", {}), content.cards, card_totals, true)
		_tally(fails, "%s relic" % label, way.get("relics", {}), content.relics, relic_totals, false)
		var crowns: Array = way.get("crownAlts", []).duplicate()
		if way.has("crown"):
			crowns.push_front(way["crown"])
		for crown_v: Variant in crowns:
			_boss_relic(fails, "%s crown" % label, str(crown_v), content)
		for capstone_v: Variant in way.get("capstones", []):
			var capstone: String = str(capstone_v)
			if not way.get("affinity", {}).has(capstone):
				fails.append("ways content: %s capstone %s carries no affinity" % [label, capstone])
	for totals: Dictionary in [card_totals, relic_totals]:
		for id_v: Variant in totals:
			if _num(totals[id_v]) > 1.0:
				fails.append("ways content: %s totals %s affinity" % [id_v, totals[id_v]])
	var dusk: Dictionary = content.aspects[0]
	_boss_relic(fails, "sootCrown", str(dusk.get("sootCrown", "")), content)
	var excludes: Dictionary = dusk.get("excludes", {})
	for id_v: Variant in excludes.get("cards", []):
		if not content.cards.has(str(id_v)) or card_totals.has(str(id_v)):
			fails.append("ways content: excluded card %s is unknown or coloured" % id_v)
	for id_v: Variant in excludes.get("relics", []):
		if not content.relics.has(str(id_v)) or relic_totals.has(str(id_v)):
			fails.append("ways content: excluded relic %s is unknown or coloured" % id_v)
	var constants: Dictionary = dusk.get("flame", {})
	for key: String in CONSTANTS:
		var value: Variant = constants.get(key)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			fails.append("ways content: flame.%s must be a number" % key)
			return
	if not (_num(constants["sootMax"]) <= _num(constants["steadyMin"])
			and _num(constants["steadyMin"]) < _num(constants["trueMin"])
			and _num(constants["trueMin"]) <= 1.0 and _num(constants["fringeMin"]) > 0.0):
		fails.append("ways content: flame thresholds out of order %s" % constants)
	if not Flame.ways(content, 1).is_empty():
		fails.append("ways content: the Ashwarden declares no ways until 1.1")


static func _tally(fails: Array[String], label: String, table_v: Variant, registry: Dictionary,
		totals: Dictionary, cards: bool) -> void:
	if typeof(table_v) != TYPE_DICTIONARY:
		fails.append("ways content: %s affinity must be a dictionary" % label)
		return
	var table: Dictionary = table_v
	for id_v: Variant in table:
		var id: String = str(id_v)
		var weight: float = float(str(table[id_v]))
		if not registry.has(id):
			fails.append("ways content: %s %s does not exist" % [label, id])
			continue
		if cards and Flame.UNCOLOURED_TYPES.has(str(registry[id].get("type", ""))):
			fails.append("ways content: %s %s is a curse or status card" % [label, id])
		if weight != 0.5 and weight != 1.0:
			fails.append("ways content: %s %s weight %s is not 0.5 or 1.0" % [label, id, weight])
		totals[id] = _num(totals.get(id, 0.0)) + weight


static func _boss_relic(fails: Array[String], label: String, id: String, content: ContentDB) -> void:
	if not content.relics.has(id) or str(content.relics[id].get("rarity", "")) != "boss":
		fails.append("ways content: %s %s is not a boss relic" % [label, id])


static func _flames(events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev: Dictionary in events:
		if ev.get("t") == EventTypes.FLAME:
			out.append(ev)
	return out


## §4 read points: combat start always; any deck change once no fight is live;
## never mid-combat; an upgrade (same id) is no change; the reading never enters
## the combat log.
static func _flame_read_points(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = _dusk(content, "events")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var start: Array[Dictionary] = _flames(game.apply(
		{"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"}))
	var keys: Array = ["t", "aspect", "dominant", "fringe", "tier", "purity", "shares", "mass"]
	if start.size() != 1 or start[0].keys() != keys or str(start[0]["tier"]) != Flame.TIER_KINDLING:
		fails.append("flame event: combat start must read once with %s, got %s" % [keys, start])
	for ev: Dictionary in game.cb.queue:
		if ev.get("t") == EventTypes.FLAME:
			fails.append("flame event: the reading entered the combat log")
	_add(run, ["uppercut"])
	if not _flames(game.apply({"t": "endTurn"})).is_empty() or not game.flame_events().is_empty():
		fails.append("flame event: a live fight must never read the flame")
	game.cb.over = true
	var after: Array[Dictionary] = _flames(game.apply({"t": "addCardToDeck", "cardId": "quakeblow"}))
	if after.size() != 1 or str(after[0]["tier"]) != Flame.TIER_STEADY \
			or _num(after[0]["mass"]) != 5.0:
		fails.append("flame event: the first command after the fight must read the new deck, got %s"
			% [after])
	if not game.flame_events().is_empty():
		fails.append("flame event: an unchanged deck must not read again")
	run.player.deck[0].up = true
	if not game.flame_events().is_empty():
		fails.append("flame event: an upgrade keeps the card id and is no deck change")
	_add(run, ["warCry"])
	var picked: Array[Dictionary] = game.flame_events()
	if picked.size() != 1 or str(picked[0]["tier"]) != Flame.TIER_KINDLING \
			or str(picked[0]["fringe"]) != "edge":
		fails.append("flame event: a deck edited outside a command must read on request, got %s"
			% [picked])
	_remove(run, "eclipseSlash")
	var removed: Array[Dictionary] = game.flame_events()
	if removed.size() != 1 or str(removed[0]["tier"]) != Flame.TIER_STEADY \
			or str(removed[0]["fringe"]) != "":
		fails.append("flame event: a removal must read (and steady the flame), got %s" % [removed])
	var again: Array[Dictionary] = _flames(game.apply(
		{"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"}))
	if again.size() != 1:
		fails.append("flame event: every combat start reads, changed deck or not")


static func _way_less_aspect_emits_nothing(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = RunState.new_run(content, 4242, "flame-ash-events", {"aspect": 1})
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var events: Array[Dictionary] = game.apply(
		{"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	game.cb.over = true
	events.append_array(game.apply({"t": "addCardToDeck", "cardId": "uppercut"}))
	if not _flames(events).is_empty():
		fails.append("flame event: an aspect without ways must emit nothing")
