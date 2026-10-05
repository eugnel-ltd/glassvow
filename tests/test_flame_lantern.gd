extends RefCounted
## Flame lock PR 4 (docs/design/2026-09-29-dusk-flame, §5): the lantern's
## quality by tier, through the combat rules. The flame read at combat start
## sets it for the whole fight: Soot leaks Embers at the end of each of your
## turns and makes the Art dearer; Steady raises the Ember cap and adds to each
## turn's first Ember gain; True is Steady with a cheaper Art, never below 1;
## Kindling keeps the plain lantern; the Ashwarden's lantern reads its own ways
## and its own knobs (#544 A2). Every number is a `flame.lantern` knob of the
## content, so these checks set their own values, distinct wherever a knob read
## in the wrong place would hide, instead of the shipped calibration.
## tests/test_balance_sim.gd holds the whole-run proof that every knob at zero
## replays the game from before.

const KNOBS: Array[String] = [
	"sootLeak", "sootArtCost", "steadyCap", "steadyFirstGain", "trueArtCost",
]
const TEST_KNOBS: Dictionary = {
	"sootLeak": 2, "sootArtCost": 1, "steadyCap": 3, "steadyFirstGain": 2, "trueArtCost": 1,
}
const ZERO_KNOBS: Dictionary = {
	"sootLeak": 0, "sootArtCost": 0, "steadyCap": 0, "steadyFirstGain": 0, "trueArtCost": 0,
}
## [label, starters removed, cards added, tier]: the lock's §4 worked decks.
const KINDLING_DECK: Array = ["the starter deck", [], [], "KINDLING"]
const SOOT_DECK: Array = ["two of each way", [], ["uppercut", "preparation", "warCry"], "SOOT"]
const STEADY_DECK: Array = ["three shatter in five", [], ["uppercut", "quakeblow"], "STEADY"]
const TRUE_DECK: Array = ["lantern alone", ["chisel", "eclipseSlash"],
	["preparation", "surge", "devour", "offering"], "TRUE"]
## The Ashwarden's own knobs, each unlike TEST_KNOBS, so a knob read from the
## Duskblade's row shows.
const ASH_KNOBS: Dictionary = {
	"sootLeak": 3, "sootArtCost": 2, "steadyCap": 5, "steadyFirstGain": 1, "trueArtCost": 2,
}
## The Ashwarden's decks (its starter: Ash Bite and Defend clear, Smother ×2 at
## ½ Smolder and ½ Endure, First Spark Hand): the Duskblade's glass is clear to
## it, so its Shatter deck stays Kindling.
const ASH_DECKS: Array = [
	["Ashwarden, the Duskblade's glass", [], ["uppercut", "quakeblow", "oblivionStrike", "limitBreak"],
		"KINDLING"],
	["Ashwarden soot", [], ["venomStrike", "preparation", "bulwark"], "SOOT"],
	["Ashwarden steady smolder", [], ["venomStrike", "venomStrike"], "STEADY"],
	["Ashwarden true hand", ["smother", "smother"], ["preparation", "surge", "quickSlash", "offering"],
		"TRUE"],
]
const HP: int = 500


static func run(fails: Array[String]) -> void:
	_knobs_are_content(fails)
	var content: ContentDB = _content(TEST_KNOBS)
	_kindling(content, fails)
	_soot(content, fails)
	_steady(content, fails)
	_true(content, fails)
	_true_floor(fails)
	_kept_all_fight(content, fails)
	_ashwarden(fails)
	_zero_knobs(fails)
	_nothing_saved(fails)


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


## The full catalogue with its Duskblade lantern knobs replaced by `knobs`.
static func _content(knobs: Dictionary) -> ContentDB:
	var content: ContentDB = ContentDB.load_full(false)
	var dusk: Dictionary = content.aspects[0]
	var flame: Dictionary = dusk["flame"]
	flame["lantern"] = knobs.duplicate()
	return content


## A seeded fight against one sporeling too deep to kill or shatter and with no
## statuses on either side, so every Ember below is the lantern's own. The
## combat start must read the deck's tier (an aspect without ways reads none).
static func _fight(content: ContentDB, deck: Array, fails: Array[String], aspect: int = 0,
		relics: Array[String] = []) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 51500, "lantern-%s" % deck[0],
		{"aspect": aspect})
	for id_v: Variant in deck[1]:
		for card: CardInst in run_state.player.deck:
			if String(card.id) == str(id_v):
				run_state.player.deck.erase(card)
				break
	for id_v: Variant in deck[2]:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	run_state.player.relics.append_array(relics)
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var tiers: Array = []
	for event: Dictionary in game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"}):
		if event.get("t") == EventTypes.FLAME:
			tiers.append(str(event["tier"]))
	var expected: Array = [str(deck[3])]
	if tiers != expected:
		fails.append("lantern %s: combat start read %s, expected %s" % [deck[0], tiers, expected])
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.max_hp = HP
	foe.hp = HP
	foe.block = 0
	foe.statuses.clear()
	foe.facet_max = 99
	game.cb.player.statuses.clear()
	return game


## The EMBER deltas among `events`, in order.
static func _embers(events: Array[Dictionary]) -> Array:
	var out: Array = []
	for event: Dictionary in events:
		if event.get("t") == EventTypes.EMBER:
			out.append(_ji(event["n"]))
	return out


static func _stat(game: GlassvowGame, key: String) -> int:
	return _ji(game.run.stats.get(key, 0))


## The run's Art at its content price.
static func _base_cost(game: GlassvowGame) -> int:
	var art: Dictionary = game.content.arts[String(game.run.art)]
	return _ji(art["cost"])


static func _plain_cap() -> int:
	return CombatState.new().ember_cap


## The plain lantern: the cap, the Art's price and every gain as they were, and
## no Ember lost at the end of a turn.
static func _expect_plain(game: GlassvowGame, label: String, fails: Array[String]) -> void:
	var cb: CombatState = game.cb
	if cb.ember_cap != _plain_cap() or game.rules.art_cost(game.run, cb) != _base_cost(game):
		fails.append("lantern %s: cap %d and Art %d must stay %d and %d" % [label, cb.ember_cap,
			game.rules.art_cost(game.run, cb), _plain_cap(), _base_cost(game)])
	cb.embers = 3
	var events: Array[Dictionary] = game.apply({"t": "endTurn"})
	if cb.embers != 3 or not _embers(events).is_empty():
		fails.append("lantern %s: nothing may leak at the end of a turn, got %s" % [label, _embers(events)])
	if game.rules.gain_embers(game.run, cb, 1) != 1 or cb.embers != 4:
		fails.append("lantern %s: a turn's first gain must carry no bonus" % label)


## The shipped Duskblade content declares exactly the five knobs, each a whole
## number of at least 0 (the name says which way the Art's price moves).
static func _knobs_are_content(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var dusk: Dictionary = content.aspects[0]
	var flame: Dictionary = dusk.get("flame", {})
	var lantern_v: Variant = flame.get("lantern")
	if typeof(lantern_v) != TYPE_DICTIONARY:
		fails.append("lantern content: aspects[0].flame.lantern must be a dictionary")
		return
	var lantern: Dictionary = lantern_v
	var keys: Array = lantern.keys()
	keys.sort()
	var expected: Array = []
	expected.append_array(KNOBS)
	expected.sort()
	if keys != expected:
		fails.append("lantern content: the knobs must be %s, got %s" % [expected, keys])
	for key: String in KNOBS:
		var value: Variant = lantern.get(key)
		var number: float = float(str(value)) \
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else -1.0
		if number < 0.0 or number != floorf(number):
			fails.append("lantern content: %s must be a whole number of at least 0, got %s"
				% [key, value])


static func _kindling(content: ContentDB, fails: Array[String]) -> void:
	_expect_plain(_fight(content, KINDLING_DECK, fails), "kindling", fails)


## Soot: `sootLeak` Embers lost as each of your turns ends, before the foe acts,
## never below 0 and never counted as spent or gained; the Art `sootArtCost`
## dearer; no cap or gain bonus.
static func _soot(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, SOOT_DECK, fails)
	var cb: CombatState = game.cb
	var cost: int = _base_cost(game)
	var spent: int = _stat(game, "embersSpent")
	var gained: int = _stat(game, "embersGained")
	if cb.ember_cap != _plain_cap():
		fails.append("lantern soot: the cap must stay %d, got %d" % [_plain_cap(), cb.ember_cap])
	cb.embers = 3
	var events: Array[Dictionary] = game.apply({"t": "endTurn"})
	var kinds: Array = []
	for event: Dictionary in events:
		kinds.append(event.get("t"))
	var leak_at: int = kinds.find(EventTypes.EMBER)
	if cb.embers != 1 or _embers(events) != [-2] or leak_at < kinds.find(EventTypes.END_TURN) \
			or leak_at > kinds.find(EventTypes.ENEMY_ACT):
		fails.append("lantern soot: 3 Embers must leak 2 as the turn ends, before the foe acts, got %d %s"
			% [cb.embers, kinds])
	if _stat(game, "embersSpent") != spent or _stat(game, "embersGained") != gained:
		fails.append("lantern soot: leaked Embers are lost, neither spent nor gained")
	cb.embers = 1
	events = game.apply({"t": "endTurn"})
	if cb.embers != 0 or _embers(events) != [-1]:
		fails.append("lantern soot: a leak larger than the lantern empties it, got %d %s"
			% [cb.embers, _embers(events)])
	events = game.apply({"t": "endTurn"})
	if cb.embers != 0 or not _embers(events).is_empty():
		fails.append("lantern soot: an empty lantern leaks nothing, got %d %s"
			% [cb.embers, _embers(events)])
	if game.rules.art_cost(game.run, cb) != cost + 1:
		fails.append("lantern soot: the Art must cost %d, got %d"
			% [cost + 1, game.rules.art_cost(game.run, cb)])
	cb.embers = cost
	if game.rules.can_use_art(game.run, cb):
		fails.append("lantern soot: the Art's content price no longer pays for it")
	cb.embers = cost + 1
	game.apply({"t": "useArt"})
	if cb.embers != 0 or _stat(game, "embersSpent") != spent + cost + 1:
		fails.append("lantern soot: the Art must spend %d Embers, left %d spent %d"
			% [cost + 1, cb.embers, _stat(game, "embersSpent") - spent])
	if game.rules.gain_embers(game.run, cb, 1) != 1:
		fails.append("lantern soot: a turn's first gain carries no bonus")


## Steady: the cap `steadyCap` higher (on top of the Crown of Cinders' own), and
## the first Ember gain of each turn `steadyFirstGain` larger, once per turn,
## before the cap takes its share; the tally counts only what the lantern
## caught. No leak, and the Art at its content price.
static func _steady(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, STEADY_DECK, fails)
	var cb: CombatState = game.cb
	if cb.ember_cap != _plain_cap() + 3 or game.rules.art_cost(game.run, cb) != _base_cost(game):
		fails.append("lantern steady: cap %d and Art %d, expected %d and %d" % [cb.ember_cap,
			game.rules.art_cost(game.run, cb), _plain_cap() + 3, _base_cost(game)])
	cb.embers = 0
	var gained: int = _stat(game, "embersGained")
	var events: Array[Dictionary] = game.apply({"t": "kindleFromHand", "uid": cb.hand[0].uid})
	if cb.embers != 3 or _embers(events) != [3]:
		fails.append("lantern steady: a kindle as the turn's first gain must catch 3, got %d %s"
			% [cb.embers, _embers(events)])
	if game.rules.gain_embers(game.run, cb, 1) != 1 or cb.embers != 4:
		fails.append("lantern steady: only the first gain of a turn carries the bonus")
	events = game.apply({"t": "endTurn"})
	if cb.embers != 4 or not _embers(events).is_empty():
		fails.append("lantern steady: a Steady lantern must not leak, got %d %s"
			% [cb.embers, _embers(events)])
	if game.rules.gain_embers(game.run, cb, 2) != 4 or cb.embers != 8:
		fails.append("lantern steady: every turn's first gain carries the bonus, got %d" % cb.embers)
	game.apply({"t": "endTurn"})
	cb.embers = cb.ember_cap - 1
	if game.rules.gain_embers(game.run, cb, 1) != 1 or cb.embers != cb.ember_cap \
			or game.rules.gain_embers(game.run, cb, 1) != 0:
		fails.append("lantern steady: the cap takes its share of the bonus, got %d of %d"
			% [cb.embers, cb.ember_cap])
	if _stat(game, "embersGained") != gained + 3 + 1 + 4 + 1:
		fails.append("lantern steady: embersGained must count the %d Embers caught, got %d"
			% [3 + 1 + 4 + 1, _stat(game, "embersGained") - gained])
	var crowned: Array[String] = ["crownOfCinders"]
	var crown_cap: int = _fight(content, KINDLING_DECK, fails, 0, crowned).cb.ember_cap
	var steady_crown: int = _fight(content, STEADY_DECK, fails, 0, crowned).cb.ember_cap
	if crown_cap == _plain_cap() or steady_crown != crown_cap + 3:
		fails.append("lantern steady: the bonus adds to the Crown of Cinders' cap %d, got %d"
			% [crown_cap, steady_crown])


## True: all of Steady, and the Art `trueArtCost` cheaper.
static func _true(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, TRUE_DECK, fails)
	var cb: CombatState = game.cb
	var cost: int = _base_cost(game) - 1
	if cb.ember_cap != _plain_cap() + 3 or game.rules.art_cost(game.run, cb) != cost:
		fails.append("lantern true: cap %d and Art %d, expected %d and %d" % [cb.ember_cap,
			game.rules.art_cost(game.run, cb), _plain_cap() + 3, cost])
	cb.embers = 0
	if game.rules.gain_embers(game.run, cb, 1) != 3 or game.rules.gain_embers(game.run, cb, 1) != 1:
		fails.append("lantern true: the first gain of a turn carries Steady's bonus, once")
	cb.embers = cost
	var spent: int = _stat(game, "embersSpent")
	game.apply({"t": "useArt"})
	if cb.embers != 0 or _stat(game, "embersSpent") != spent + cost:
		fails.append("lantern true: the Art must spend %d Embers" % cost)
	cb.embers = 3
	var events: Array[Dictionary] = game.apply({"t": "endTurn"})
	if cb.embers != 3 or not _embers(events).is_empty():
		fails.append("lantern true: a True lantern must not leak, got %s" % [_embers(events)])


## A discount larger than the price leaves the Art at 1, and an Art that costs
## less than 1 is never raised by that floor.
static func _true_floor(fails: Array[String]) -> void:
	var knobs: Dictionary = ZERO_KNOBS.duplicate()
	knobs["trueArtCost"] = 5
	var content: ContentDB = _content(knobs)
	var game: GlassvowGame = _fight(content, TRUE_DECK, fails)
	if game.rules.art_cost(game.run, game.cb) != 1:
		fails.append("lantern true: the Art never costs less than 1, got %d"
			% game.rules.art_cost(game.run, game.cb))
	game.cb.embers = 1
	game.apply({"t": "useArt"})
	if game.cb.embers != 0 or game.cb.art_used_turn != game.cb.turn:
		fails.append("lantern true: one Ember must pay for the Art at its floor")
	content.arts["lanternTestFreeArt"] = {"cost": 0, "effects": []}
	game.run.art = &"lanternTestFreeArt"
	if game.rules.art_cost(game.run, game.cb) != 0:
		fails.append("lantern true: the floor must not raise a free Art, got %d"
			% game.rules.art_cost(game.run, game.cb))


## The tier a combat keeps: a deck that turns pure mid-fight does not relight
## the lantern until the next combat start reads it.
static func _kept_all_fight(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, SOOT_DECK, fails)
	for id: String in ["chisel", "eclipseSlash", "uppercut", "warCry"]:
		for card: CardInst in game.run.player.deck:
			if String(card.id) == id:
				game.run.player.deck.erase(card)
				break
	for id: String in ["surge", "devour", "offering"]:
		game.run.player.deck.append(CardInst.new(game.run.next_uid(), StringName(id), false))
	if str(Flame.read(content, game.run)["tier"]) != Flame.TIER_TRUE:
		fails.append("lantern kept: the mid-fight deck must read True, got %s"
			% Flame.read(content, game.run)["tier"])
	var cb: CombatState = game.cb
	cb.embers = 3
	game.apply({"t": "endTurn"})
	if cb.embers != 1 or cb.ember_cap != _plain_cap() \
			or game.rules.art_cost(game.run, cb) != _base_cost(game) + 1:
		fails.append("lantern kept: the fight must keep its Soot lantern, embers %d cap %d Art %d"
			% [cb.embers, cb.ember_cap, game.rules.art_cost(game.run, cb)])


## The Ashwarden's lantern reads its own ways and its own knobs (#544 A2): a deck
## of the Duskblade's glass keeps the plain lantern, and each of its own tiers
## sets the fight's lantern from the Ashwarden's `flame.lantern`, never the
## Duskblade's.
static func _ashwarden(fails: Array[String]) -> void:
	var content: ContentDB = _content(TEST_KNOBS)
	var ash: Dictionary = content.aspects[1]
	var flame: Dictionary = ash["flame"]
	flame["lantern"] = ASH_KNOBS.duplicate()
	_expect_plain(_fight(content, ASH_DECKS[0], fails, 1), str(ASH_DECKS[0][0]), fails)
	for deck_v: Variant in ASH_DECKS.slice(1):
		var deck: Array = deck_v
		var cb: CombatState = _fight(content, deck, fails, 1).cb
		var tier: String = str(deck[3])
		var lit: bool = tier != Flame.TIER_SOOT
		var want: Array[int] = [
			ASH_KNOBS["sootLeak"] if not lit else 0,
			_plain_cap() + (ASH_KNOBS["steadyCap"] if lit else 0),
			ASH_KNOBS["steadyFirstGain"] if lit else 0,
			ASH_KNOBS["sootArtCost"] if not lit
				else (-ASH_KNOBS["trueArtCost"] if tier == Flame.TIER_TRUE else 0),
		]
		var got: Array[int] = [cb.ember_leak, cb.ember_cap, cb.first_gain_bonus, cb.art_cost_delta]
		if got != want:
			fails.append("lantern %s: leak, cap, first gain and Art delta must be %s, got %s"
				% [deck[0], want, got])


## Every knob at 0 is the plain lantern at every tier.
static func _zero_knobs(fails: Array[String]) -> void:
	var content: ContentDB = _content(ZERO_KNOBS)
	for deck: Array in [SOOT_DECK, STEADY_DECK, TRUE_DECK]:
		_expect_plain(_fight(content, deck, fails), "zero knobs, %s" % deck[0], fails)


## The tier is derived, never saved: a fight with a leaking, dearer lantern
## leaves the run's save envelope and stats with exactly the keys that the same
## fight with every knob at zero leaves.
static func _nothing_saved(fails: Array[String]) -> void:
	var saves: Array[Dictionary] = []
	for knobs: Dictionary in [ZERO_KNOBS, TEST_KNOBS]:
		var game: GlassvowGame = _fight(_content(knobs), SOOT_DECK, fails)
		game.cb.embers = 6
		game.apply({"t": "useArt"})
		game.apply({"t": "endTurn"})
		saves.append(game.run.to_save_dict())
	var stats: Array[Dictionary] = []
	for save: Dictionary in saves:
		stats.append(save["stats"])
	if saves[0].keys() != saves[1].keys() or stats[0].keys() != stats[1].keys():
		fails.append("lantern save: the lantern must add nothing to the save, got %s and %s"
			% [saves[1].keys(), stats[1].keys()])
