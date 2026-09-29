class_name Flame
extends RefCounted
## The lantern burns what you carry (docs/design/2026-09-29-dusk-flame, §4).
## A pure reading of the deck's coloured glass against the run aspect's ways,
## derived from the deck and content only and never saved: the same function
## serves the game, the HUD and the simulator. Upgrades do not change affinity,
## relics never enter the mass, and curse or status cards (curses, wounds,
## burns, hexes, quest pages) are never coloured glass.

const TIER_SOOT: String = "SOOT"
const TIER_KINDLING: String = "KINDLING"
const TIER_STEADY: String = "STEADY"
const TIER_TRUE: String = "TRUE"
const UNCOLOURED_TYPES: Array[String] = ["curse", "status"]


## The aspect's ways in content order; empty when it declares none.
static func ways(content: ContentDB, aspect: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if aspect < 0 or aspect >= content.aspects.size() \
			or typeof(content.aspects[aspect]) != TYPE_DICTIONARY:
		return out
	var row: Dictionary = content.aspects[aspect]
	var rows_v: Variant = row.get("ways", [])
	if typeof(rows_v) != TYPE_ARRAY:
		return out
	var rows: Array = rows_v
	for way_v: Variant in rows:
		if typeof(way_v) == TYPE_DICTIONARY:
			out.append(way_v)
	return out


## {way id: weight} of a card under this aspect; empty for clear glass.
static func card_affinity(content: ContentDB, aspect: int, card_id: String) -> Dictionary:
	var out: Dictionary = {}
	for way: Dictionary in ways(content, aspect):
		var weight: float = _weight(way.get("affinity", {}), card_id)
		if weight > 0.0:
			out[str(way["id"])] = weight
	return out


## {way id: weight} of a relic under this aspect. A way's crowns carry its full
## weight, as §6.1 lists them among the way's relics.
static func relic_affinity(content: ContentDB, aspect: int, relic_id: String) -> Dictionary:
	var out: Dictionary = {}
	for way: Dictionary in ways(content, aspect):
		var weight: float = _weight(way.get("relics", {}), relic_id)
		var alts: Array = way.get("crownAlts", [])
		if str(way.get("crown", "")) == relic_id or alts.has(relic_id):
			weight = 1.0
		if weight > 0.0:
			out[str(way["id"])] = weight
	return out


## The lantern's reading of the run's deck: {aspect, dominant, fringe, tier,
## purity, shares, mass}. With no coloured glass (or no ways) nothing is
## declared: no dominant, no fringe, Kindling.
static func read(content: ContentDB, run: RunState) -> Dictionary:
	var rows: Array[Dictionary] = ways(content, run.aspect)
	var amounts: Array[float] = []
	amounts.resize(rows.size())
	amounts.fill(0.0)
	var mass: float = 0.0
	for card: CardInst in run.player.deck:
		var id: String = String(card.id)
		var definition: Dictionary = content.cards.get(id, {})
		if UNCOLOURED_TYPES.has(str(definition.get("type", ""))):
			continue
		for i: int in range(rows.size()):
			var weight: float = _weight(rows[i].get("affinity", {}), id)
			amounts[i] += weight
			mass += weight
	var shares: Dictionary = {}
	for i: int in range(rows.size()):
		shares[str(rows[i]["id"])] = amounts[i] / mass if mass > 0.0 else 0.0
	var reading: Dictionary = {
		"aspect": run.aspect, "dominant": "", "fringe": "", "tier": TIER_KINDLING,
		"purity": 0.0, "shares": shares, "mass": mass,
	}
	if mass <= 0.0:
		return reading
	var aspect_row: Dictionary = content.aspects[run.aspect]
	var constants: Dictionary = aspect_row.get("flame", {})
	var dominant: int = _largest(amounts, -1)
	var second: int = _largest(amounts, dominant)
	var purity: float = amounts[dominant] / mass
	reading["dominant"] = str(rows[dominant]["id"])
	reading["purity"] = purity
	if second >= 0 and amounts[second] / mass >= _constant(constants, "fringeMin"):
		reading["fringe"] = str(rows[second]["id"])
	reading["tier"] = _tier(constants, mass, purity)
	return reading


static func _tier(constants: Dictionary, mass: float, purity: float) -> String:
	if mass < _constant(constants, "minMass"):
		return TIER_KINDLING
	if purity >= _constant(constants, "trueMin"):
		return TIER_TRUE
	if purity >= _constant(constants, "steadyMin"):
		return TIER_STEADY
	if mass >= _constant(constants, "sootMass") and purity < _constant(constants, "sootMax"):
		return TIER_SOOT
	return TIER_KINDLING


## The index of the way with the most glass, skipping `except`; a tie keeps the
## earlier way in content order. -1 when no way is left.
static func _largest(amounts: Array[float], except: int) -> int:
	var best: int = -1
	for i: int in range(amounts.size()):
		if i != except and (best < 0 or amounts[i] > amounts[best]):
			best = i
	return best


static func _weight(table_v: Variant, id: String) -> float:
	if typeof(table_v) != TYPE_DICTIONARY:
		return 0.0
	var table: Dictionary = table_v
	return float(str(table.get(id, 0.0)))


static func _constant(constants: Dictionary, key: String) -> float:
	return float(str(constants.get(key, 0.0)))
