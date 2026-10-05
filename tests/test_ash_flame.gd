extends RefCounted
## #544 A2, the Ashwarden's ways in content (docs/design/2026-10-05-ash-flame).
## The flame's mechanism is the Duskblade's and is tested in test_flame*.gd;
## this file pins what the Ashwarden's content makes of it, on the real content:
##
## - the content row against the lock: §6.1's affinity and relics, §6.4's
##   crowns and capstones, §4's constants (the Duskblade's shipped values, the
##   lantern included), the soot crown, §6.3's exclusions, and the class still
##   deferred;
## - §4's eight worked examples, row by row, computed by `Flame.read`;
## - recognition at the boss (§7), reading the Ashwarden's own ways and crowns;
## - like calls to like, leaning on the Ashwarden's own ways;
## - the reading at combat start and the fight's lit way.

const Recognition: GDScript = preload("res://tests/test_flame_recognition.gd")
const ASHWARDEN: int = 1
const WAYS: Array[String] = ["smolder", "hand", "endure"]
const DUSK_WAYS: Array[String] = ["shatter", "lantern", "edge"]
## §6.1, card by card and relic by relic; weights are 1.0 unless ½.
const AFFINITY: Dictionary = {
	"smolder": {"smother": 0.5, "venomStrike": 1.0, "toxicMist": 1.0, "annihilate": 1.0,
		"catalyst": 1.0, "virulence": 1.0, "ashenChoir": 1.0},
	"hand": {"firstSpark": 1.0, "preparation": 1.0, "quickSlash": 1.0, "sidestep": 0.5,
		"deflect": 0.5, "surge": 1.0, "phantomBlades": 1.0, "offering": 1.0, "tithe": 1.0,
		"nightSight": 1.0, "emberdance": 0.5},
	"endure": {"smother": 0.5, "sidestep": 0.5, "deflect": 0.5, "bulwark": 1.0, "fortify": 1.0,
		"ironSkin": 1.0, "leechBlade": 1.0, "aegis": 1.0, "bastion": 1.0, "regrowth": 1.0,
		"devour": 1.0, "flawlessForm": 1.0, "emberdance": 0.5},
}
const RELICS: Dictionary = {
	"smolder": {"smolderingCoal": 1.0},
	"hand": {"verdantBranch": 1.0, "travelersPack": 0.5},
	"endure": {"basaltIdol": 1.0, "wardingCharm": 1.0, "gravebloom": 0.5, "silkFan": 0.5,
		"sunBlossom": 0.5},
}
## §6.4 and §7's crownOf. One crown a way and no alternates: each of the four
## crowns left in the Ashwarden's boss pool belongs to one way (or to Soot), so
## an alternate would offer another way's crown; a held crown falls back to the
## draw (§7).
const CROWNS: Dictionary = {
	"smolder": "crownOfCinders", "hand": "crownOfTithes", "endure": "crownOfTheHearth",
}
const CAPSTONES: Dictionary = {
	"smolder": ["catalyst", "virulence"], "hand": ["phantomBlades", "offering"],
	"endure": ["bastion", "flawlessForm"],
}
## §6.3: the Shatter-only glass, the relics that pay on facets and Shatters, and
## Beacon; added to the exclusions the Ashwarden already had, which stay.
const EXCLUDED: Dictionary = {
	"cards": ["splinterCut", "dimTheGlass", "cleft", "eclipseStep", "tremor", "totality",
		"emberEye", "spall", "hearthfall", "uppercut", "quakeblow", "oblivionStrike",
		"limitBreak", "resonantLance"],
	"relics": ["crownOfTheEclipse", "shatterersCrown", "bellOfEndings", "prismCharm"],
	"arts": ["beacon"],
}
## The four crowns the Ashwarden's boss pool holds once §6.3 is applied (§6.4).
const BOSS_POOL: Array = ["crownOfCinders", "hollowCrown", "crownOfTithes", "crownOfTheHearth"]

## §7 for the Ashwarden, as test_flame_recognition.gd's TABLE: [label, starters
## removed, cards added, relics held, tier, slot-1 crown, slot-2 crown]. The
## starter is Ash Bite ×4, Defend ×3 (clear), Smother ×2 (½ Smolder, ½ Endure)
## and First Spark (Hand): N = 3, one third each.
const RECOGNITION: Array = [
	["start", [], [], [], "KINDLING", "", ""],
	["steady smolder", [], ["venomStrike", "venomStrike"], [], "STEADY", "crownOfCinders", ""],
	["steady smolder, endure fringe", [],
		["venomStrike", "venomStrike", "bulwark", "toxicMist", "annihilate"], [],
		"STEADY", "crownOfCinders", "crownOfTheHearth"],
	["true smolder", ["firstSpark"], ["venomStrike", "venomStrike", "toxicMist"], [],
		"TRUE", "crownOfCinders", ""],
	["steady hand", [], ["preparation", "surge"], [], "STEADY", "crownOfTithes", ""],
	["steady hand, endure fringe", [],
		["preparation", "surge", "quickSlash", "offering", "bulwark"], [],
		"STEADY", "crownOfTithes", "crownOfTheHearth"],
	["true hand", ["smother", "smother"], ["preparation", "surge", "quickSlash", "offering"], [],
		"TRUE", "crownOfTithes", ""],
	["steady endure", [], ["bulwark", "fortify"], [], "STEADY", "crownOfTheHearth", ""],
	["steady endure, hand fringe", [],
		["bulwark", "fortify", "ironSkin", "aegis", "preparation"], [],
		"STEADY", "crownOfTheHearth", "crownOfTithes"],
	["true endure", ["firstSpark"], ["bulwark", "fortify", "ironSkin"], [],
		"TRUE", "crownOfTheHearth", ""],
	["soot", [], ["venomStrike", "preparation", "bulwark"], [], "SOOT", "hollowCrown", ""],
	# No alternates: a held crown's slot is the draw's.
	["steady smolder, cinders held", [], ["venomStrike", "venomStrike"], ["crownOfCinders"],
		"STEADY", "", ""],
	["steady smolder, endure fringe, cinders held", [],
		["venomStrike", "venomStrike", "bulwark", "toxicMist", "annihilate"], ["crownOfCinders"],
		"STEADY", "", "crownOfTheHearth"],
	["true hand, tithes held", ["smother", "smother"],
		["preparation", "surge", "quickSlash", "offering"], ["crownOfTithes"], "TRUE", "", ""],
	["soot, the hollow crown held", [], ["venomStrike", "preparation", "bulwark"],
		["hollowCrown"], "SOOT", "", ""],
	# Each class reads only its own ways: glass that is Steady Shatter for the
	# Duskblade is clear for the Ashwarden, which stays Kindling, recognised by
	# nothing.
	["the Duskblade's glass", [], ["uppercut", "quakeblow", "oblivionStrike", "limitBreak"], [],
		"KINDLING", "", ""],
]
## The draws `_sweep` makes over one pool: enough that a clear entry is drawn
## about eighty times, so a measured lift sits within about 2% of its weight.
const SWEEP: int = 4000
const TOLERANCE: float = 0.05


## `_draw`'s one draw, at a chosen point of [0, 1): sweeping it reads the pick's
## weights exactly, with no sampling noise.
class SweepRng:
	extends Rng

	var at: float = 0.0

	func _init() -> void:
		super(0)

	func next() -> float:
		return at


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_content_row(content, fails)
	_worked_examples(content, fails)
	_recognition(content, fails)
	_like_calls_to_like(content, fails)
	_read_at_combat_start(content, fails)


static func _num(value: Variant) -> float:
	return float(str(value))


static func _ash(content: ContentDB, tag: String) -> RunState:
	return RunState.new_run(content, 4243, "ash-flame-%s" % tag, {"aspect": ASHWARDEN})


static func _add(run: RunState, ids: Array) -> void:
	for id_v: Variant in ids:
		run.player.deck.append(CardInst.new(run.next_uid(), StringName(str(id_v)), false))


static func _remove(run: RunState, id: String) -> void:
	for card: CardInst in run.player.deck:
		if String(card.id) == id:
			run.player.deck.erase(card)
			return


## The content row against the lock, way by way.
static func _content_row(content: ContentDB, fails: Array[String]) -> void:
	var ash: Dictionary = content.aspects[ASHWARDEN]
	var dusk: Dictionary = content.aspects[0]
	var ways: Array[Dictionary] = Flame.ways(content, ASHWARDEN)
	var ids: Array[String] = []
	for way: Dictionary in ways:
		ids.append(str(way.get("id", "")))
	if str(ash.get("id", "")) != "ashwarden" or ids != WAYS:
		fails.append("ash flame content: the Ashwarden's ways must be %s in content order, got %s"
			% [WAYS, ids])
		return
	for way: Dictionary in ways:
		var id: String = str(way["id"])
		if way.get("affinity", {}) != AFFINITY[id] or way.get("relics", {}) != RELICS[id]:
			fails.append("ash flame content: %s's affinity or relics are not §6.1's: %s / %s"
				% [id, way.get("affinity"), way.get("relics")])
		if str(way.get("crown", "")) != CROWNS[id] or way.has("crownAlts"):
			fails.append("ash flame content: %s's crown must be %s alone, got %s %s"
				% [id, CROWNS[id], way.get("crown"), way.get("crownAlts", [])])
		if way.get("capstones", []) != CAPSTONES[id]:
			fails.append("ash flame content: %s's capstones must be %s, got %s"
				% [id, CAPSTONES[id], way.get("capstones")])
	if ash.get("flame") != dusk.get("flame"):
		fails.append("ash flame content: the flame must be the Duskblade's shipped values (§4), got %s"
			% ash.get("flame"))
	if str(ash.get("sootCrown", "")) != "hollowCrown":
		fails.append("ash flame content: the soot crown must be hollowCrown")
	if ash.get("deferred") != true or _num(ash.get("handSize")) != 5.0:
		fails.append("ash flame content: the Ashwarden stays deferred, its hand 5 (#544 decision 10)")
	var excludes: Dictionary = ash.get("excludes", {})
	for kind: String in EXCLUDED:
		if excludes.get(kind, []) != EXCLUDED[kind]:
			fails.append("ash flame content: excludes.%s must be %s, got %s"
				% [kind, EXCLUDED[kind], excludes.get(kind, [])])
	var rules: RewardRules = RewardRules.new(content)
	var offered: Array = rules.offer_relics(_ash(content, "pool"), "boss")
	if offered != BOSS_POOL:
		fails.append("ash flame content: the Ashwarden's boss pool must be %s, got %s"
			% [BOSS_POOL, offered])
	# Way ids are unique across classes, and each class's glass names only its
	# own ways.
	for id: String in WAYS:
		if DUSK_WAYS.has(id):
			fails.append("ash flame content: way id %s is the Duskblade's" % id)
	for card_id: String in content.cards:
		for pair: Array in [[0, DUSK_WAYS], [ASHWARDEN, WAYS]]:
			var aspect: int = pair[0]
			var own: Array[String] = pair[1]
			for way_v: Variant in Flame.card_affinity(content, aspect, card_id):
				if not own.has(str(way_v)):
					fails.append("ash flame content: aspect %d reads %s as %s glass"
						% [aspect, card_id, way_v])


static func _expect(fails: Array[String], label: String, reading: Dictionary, mass: float,
		shares: Array[float], dominant: String, fringe: String, tier: String) -> void:
	var got: Dictionary = reading["shares"]
	var top: float = shares.max()
	var shares_ok: bool = got.size() == WAYS.size()
	for i: int in range(WAYS.size()):
		shares_ok = shares_ok and got.has(WAYS[i]) and is_equal_approx(_num(got[WAYS[i]]), shares[i])
	if not is_equal_approx(_num(reading["mass"]), mass) or not shares_ok \
			or str(reading["dominant"]) != dominant or str(reading["fringe"]) != fringe \
			or str(reading["tier"]) != tier \
			or not is_equal_approx(_num(reading["purity"]), top):
		fails.append("ash flame %s: expected N=%s shares=%s %s/%s %s, got %s"
			% [label, mass, shares, dominant, fringe, tier, reading])


## §4's eight worked examples (Smolder / Hand / Endure), and the steadying that
## follows the last. A tie keeps the earlier way in content order.
static func _worked_examples(content: ContentDB, fails: Array[String]) -> void:
	var run: RunState = _ash(content, "worked")
	_expect(fails, "start", Flame.read(content, run), 3.0,
		[1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], "smolder", "hand", Flame.TIER_KINDLING)
	_add(run, ["venomStrike", "venomStrike"])
	_expect(fails, "+Emberbite +Emberbite", Flame.read(content, run), 5.0,
		[0.6, 0.2, 0.2], "smolder", "", Flame.TIER_STEADY)
	_add(run, ["bulwark"])
	_expect(fails, "+Glasswall", Flame.read(content, run), 6.0,
		[0.5, 1.0 / 6.0, 1.0 / 3.0], "smolder", "endure", Flame.TIER_KINDLING)
	_add(run, ["toxicMist", "annihilate"])
	_expect(fails, "+Ashcloud +Requiem", Flame.read(content, run), 8.0,
		[0.625, 0.125, 0.25], "smolder", "endure", Flame.TIER_STEADY)
	_remove(run, "bulwark")
	_expect(fails, "-Glasswall", Flame.read(content, run), 7.0,
		[5.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0], "smolder", "", Flame.TIER_STEADY)
	var scattered: RunState = _ash(content, "soot")
	_add(scattered, ["venomStrike", "preparation", "bulwark"])
	_expect(fails, "+Emberbite +Tinder +Glasswall", Flame.read(content, scattered), 6.0,
		[1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0], "smolder", "hand", Flame.TIER_SOOT)
	var hand: RunState = _ash(content, "hand")
	_add(hand, ["preparation", "surge"])
	_expect(fails, "+Tinder +Struck Match", Flame.read(content, hand), 5.0,
		[0.2, 0.6, 0.2], "hand", "", Flame.TIER_STEADY)
	_remove(hand, "smother")
	_expect(fails, "-Smother", Flame.read(content, hand), 4.0,
		[0.125, 0.75, 0.125], "hand", "", Flame.TIER_KINDLING)
	_add(hand, ["preparation"])
	_expect(fails, "-Smother +Tinder", Flame.read(content, hand), 5.0,
		[0.1, 0.8, 0.1], "hand", "", Flame.TIER_TRUE)


## §7 on the Ashwarden's table, through the Duskblade's recognition harness: the
## crowns lead their slots, every other slot is the draw's, and the run's cursor
## never moves with the flame.
static func _recognition(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	for row_v: Variant in RECOGNITION:
		Recognition._case(content, rules, row_v, fails, ASHWARDEN)


## Every pool wave revealed and every deed done, so each way's glass is live.
static func _open(content: ContentDB, tag: String, removed: Array, added: Array) -> RunState:
	var unlocks: Array = []
	for deed_v: Variant in content.deeds.values():
		var deed: Dictionary = deed_v
		var unlocked: Array = deed.get("unlocks", [])
		unlocks.append_array(unlocked)
	var run: RunState = RunState.new_run(content, 4244, "ash-like-%s" % tag,
		{"aspect": ASHWARDEN, "reveals": content.reveal_ids.duplicate(), "unlocks": unlocks})
	for id_v: Variant in removed:
		_remove(run, str(id_v))
	_add(run, added)
	return run


## Like calls to like on the Ashwarden's ways: the lean a reading asks for, and
## the weight each entry of the Ashwarden's own card and relic pools then takes
## in a pick, read by sweeping `_draw`'s one draw. Smolder glass leans by
## `likeWeight`, Endure glass by `fringeWeight`, the Smolder/Endure duo by both,
## a Hand/Endure duo by the Endure fringe alone, and Hand and clear glass not at
## all; Kindling and Soot lean nowhere.
static func _like_calls_to_like(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	var flame: Dictionary = content.aspects[ASHWARDEN]["flame"]
	var like: float = _num(flame["likeWeight"])
	var fringe: float = _num(flame["fringeWeight"])
	var lit: RunState = _open(content, "lit", [],
		["venomStrike", "venomStrike", "bulwark", "toxicMist", "annihilate"])
	var hand: RunState = _open(content, "hand", ["smother", "smother"],
		["preparation", "surge", "quickSlash", "offering"])
	var leans: Array = [
		["steady smolder, endure fringe", lit, {"smolder": like, "endure": fringe}],
		["true hand", hand, {"hand": like}],
		["start", _open(content, "start", [], []), {}],
		["soot", _open(content, "soot", [], ["venomStrike", "preparation", "bulwark"]), {}],
	]
	for case_v: Variant in leans:
		var case: Array = case_v
		var deck: RunState = case[1]
		for kind: String in ["cards", "relics"]:
			var lean: Dictionary = rules._lean(deck, kind)
			if lean != case[2]:
				fails.append("ash like calls to like: %s leans %s %s, expected %s"
					% [case[0], kind, lean, case[2]])
	var lean: Dictionary = {"smolder": like, "endure": fringe}
	var cards: Array = []
	var relics: Array = []
	for rarity: String in ["common", "uncommon", "rare"]:
		cards.append_array(rules.offer_cards(lit, rarity))
		relics.append_array(rules.offer_relics(lit, rarity))
	cards.append("smother")  # the duo seed, so the duo's product is read too
	var groups: Array = [
		["cards", cards, {"smolder": like, "endure": fringe, "smolder+endure": like * fringe,
			"hand": 1.0, "hand+endure": fringe}],
		["relics", relics, {"smolder": like, "endure": fringe, "hand": 1.0}],
	]
	for group_v: Variant in groups:
		var group: Array = group_v
		var pool: Array = group[1]
		var lifts: Dictionary = _lifts(content, rules, lit, str(group[0]), pool, lean)
		print("  ash like calls to like (steady smolder, endure fringe), %s per entry over clear: %s"
			% [group[0], lifts])
		var expected: Dictionary = group[2]
		for key: String in expected:
			if absf(_num(lifts.get(key, -1.0)) - _num(expected[key])) > TOLERANCE:
				fails.append("ash like calls to like: %s %s glass draws at %s, expected %.2f"
					% [group[0], key, lifts.get(key, "nothing"), expected[key]])
	for excluded_v: Variant in EXCLUDED["cards"] + EXCLUDED["relics"]:
		if cards.has(excluded_v) or relics.has(excluded_v):
			fails.append("ash like calls to like: the pool offers excluded %s" % excluded_v)


## Each group's draws per entry over clear glass's, sweeping the one draw of a
## pick from `pool` under `lean`. An entry's group is the ways it carries at
## least ½ of, joined in content order ("smolder", "hand+endure"), or "clear".
static func _lifts(content: ContentDB, rules: RewardRules, run: RunState, kind: String,
		pool: Array, lean: Dictionary) -> Dictionary:
	var rng: SweepRng = SweepRng.new()
	var hits: Array[int] = []
	hits.resize(pool.size())
	hits.fill(0)
	for k: int in range(SWEEP):
		rng.at = (float(k) + 0.5) / float(SWEEP)
		hits[rules._draw(rng, run, kind, pool, lean)] += 1
	var totals: Dictionary = {}
	var entries: Dictionary = {}
	for i: int in range(pool.size()):
		var id: String = str(pool[i])
		var affinity: Dictionary = Flame.relic_affinity(content, ASHWARDEN, id) if kind == "relics" \
			else Flame.card_affinity(content, ASHWARDEN, id)
		var taken: Array[String] = []
		for way_v: Variant in affinity:
			if _num(affinity[way_v]) >= 0.5:
				taken.append(str(way_v))
		var key: String = "+".join(PackedStringArray(taken)) if not taken.is_empty() else "clear"
		var total: int = totals.get(key, 0)
		var count: int = entries.get(key, 0)
		totals[key] = total + hits[i]
		entries[key] = count + 1
	var out: Dictionary = {}
	var clear_hits: int = totals.get("clear", 0)
	var clear_entries: int = entries.get("clear", 0)
	var clear: float = float(clear_hits) / maxf(1.0, float(clear_entries))
	for key: String in totals:
		var key_hits: int = totals[key]
		var key_entries: int = entries[key]
		out[key] = snappedf(float(key_hits) / float(key_entries) / clear, 0.001) \
			if clear > 0.0 else -1.0
	return out


## The lantern reads the Ashwarden's deck at every combat start, and a lit
## flame names the fight's lit way by the Ashwarden's own way id.
static func _read_at_combat_start(content: ContentDB, fails: Array[String]) -> void:
	var cases: Array = [
		["start", [], [], Flame.TIER_KINDLING, ""],
		["steady smolder", [], ["venomStrike", "venomStrike"], Flame.TIER_STEADY, "smolder"],
		["true hand", ["smother", "smother"], ["preparation", "surge", "quickSlash", "offering"],
			Flame.TIER_TRUE, "hand"],
		["steady endure", [], ["bulwark", "fortify"], Flame.TIER_STEADY, "endure"],
		["soot", [], ["venomStrike", "preparation", "bulwark"], Flame.TIER_SOOT, ""],
	]
	for case_v: Variant in cases:
		var case: Array = case_v
		var run: RunState = _ash(content, "combat-%s" % case[0])
		var removed: Array = case[1]
		var added: Array = case[2]
		for id_v: Variant in removed:
			_remove(run, str(id_v))
		_add(run, added)
		var game: GlassvowGame = GlassvowGame.new(content, run)
		var flames: Array[Dictionary] = []
		for event: Dictionary in game.apply(
				{"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"}):
			if event.get("t") == EventTypes.FLAME:
				flames.append(event)
		if flames.size() != 1 or str(flames[0]["tier"]) != str(case[3]) \
				or _num(flames[0]["aspect"]) != float(ASHWARDEN) or game.cb.lit_way != str(case[4]):
			fails.append("ash flame %s: combat start must read %s, lit way '%s'; got %s, lit way '%s'"
				% [case[0], case[3], case[4], flames, game.cb.lit_way])
