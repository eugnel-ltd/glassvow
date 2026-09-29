extends RefCounted
## Flame lock §8, like calls to like (docs/design/2026-09-29-dusk-flame): once
## the flame is Steady or True, glass of the dominant way draws at `likeWeight`
## and glass of the fringe way at `fringeWeight`, in card rewards and in the
## shop's cards and relics. Kindling and Soot lean nowhere.
##
## What keeps replays deterministic is the run's shared cursor: every offer
## advances it by the same draws whatever the flame. A leaning shop pick is still
## one draw, and a card reward is rolled on a detached chain seeded from the
## cursor, so the weighting can lengthen that chain (a duplicate is drawn again)
## but never moves the cursor. Prices, gold, potions and the first card's rarity
## roll therefore never move with the flame, and a Kindling or Soot offer is
## exactly the offer from before the weighting, every pick a plain `pick_index`.

const SEEDS: int = 60
const SAMPLES: int = 10000
## The tolerance on a per-entry lift measured over SAMPLES offers. At these pool
## sizes every check sits about four standard errors or more inside it, while a
## missing lift (1.0 where 1.5 or 1.2 is due) or a lift at Kindling or Soot
## falls outside it.
const TOLERANCE: float = 0.15

## [label, starters removed, cards added, tier]. Every deck reads dominant
## edge with a lantern fringe, so the unlit decks would lean exactly as the lit
## one does if Kindling or Soot leaned at all.
const LIT: Array = ["steady edge, lantern fringe", ["chisel"],
	["warCry", "empower", "executioner", "preparation"], "STEADY"]
const KINDLING: Array = ["kindling edge, lantern fringe", [],
	["warCry", "empower", "preparation"], "KINDLING"]
const SOOT: Array = ["soot edge, lantern fringe", [],
	["warCry", "empower", "executioner", "preparation", "surge", "uppercut"], "SOOT"]
const TRUE_LANTERN: Array = ["true lantern", ["chisel", "eclipseSlash"],
	["preparation", "surge", "devour", "offering"], "TRUE"]
const STARTER: Array = ["starter", [], [], "KINDLING"]
## The combat rewards an offer sequence draws, after the shop.
const REWARDS: Array[String] = ["normal", "elite", "boss"]


## The rewards as they were before §8: every pick a plain `pick_index`, one
## uniform draw, whatever the flame. What an unlit offer must equal.
class PlainRewards:
	extends RewardRules

	func _draw(rng: Rng, _run: RunState, _kind: String, pool: Array, _lean: Dictionary) -> int:
		return rng.pick_index(pool.size())


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	for deck_v: Variant in [LIT, KINDLING, SOOT, TRUE_LANTERN, STARTER]:
		var deck: Array = deck_v
		var reading: Dictionary = Flame.read(content, _dusk(content, 0, deck))
		var fringe: String = "" if deck == TRUE_LANTERN or deck == STARTER else "lantern"
		if str(reading["tier"]) != str(deck[3]) \
				or (fringe != "" and (reading["dominant"] != "edge" or reading["fringe"] != fringe)):
			fails.append("like calls to like: %s reads %s" % [deck[0], reading])
			return
	_unlit_flames_lean_nowhere(content, fails)
	_lit_flames_keep_every_draw(content, fails)
	_the_lift(content, fails)


## Every pool wave revealed and every deed done, so each way's glass is live.
static func _dusk(content: ContentDB, seed: int, deck: Array, aspect: int = 0) -> RunState:
	var unlocks: Array = []
	for deed_v: Variant in content.deeds.values():
		var deed: Dictionary = deed_v
		var unlocked: Array = deed.get("unlocks", [])
		unlocks.append_array(unlocked)
	var run_state: RunState = RunState.new_run(content, 9000 + seed, "like-%d" % seed,
		{"aspect": aspect, "reveals": content.reveal_ids.duplicate(), "unlocks": unlocks})
	for id_v: Variant in deck[1]:
		for card: CardInst in run_state.player.deck:
			if String(card.id) == str(id_v):
				run_state.player.deck.erase(card)
				break
	for id_v: Variant in deck[2]:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	return run_state


## The shop, then a reward of each kind, one after another on the run's cursor:
## what each offer was, and where the cursor stood after it ("cursors") and after
## everything ("cursor").
static func _offers(rules: RewardRules, run_state: RunState, boss_relics: bool) -> Dictionary:
	var out: Dictionary = {"shop": rules.gen_shop(run_state)}
	var cursors: Dictionary = {"shop": run_state.rng_state()}
	for kind: String in REWARDS:
		out[kind] = rules.gen_combat_rewards(run_state, kind)
		cursors[kind] = run_state.rng_state()
	if boss_relics:
		out["crowns"] = rules.roll_boss_relics(run_state)
	out["cursors"] = cursors
	out["cursor"] = run_state.rng_state()
	return out


## The starter, Kindling and Soot decks of the same seed are offered exactly the
## offer from before the weighting (every pick a plain `pick_index`), the cursor
## after each offer included; the Ashwarden, with no ways, whatever glass it
## carries.
static func _unlit_flames_lean_nowhere(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	var plain: RewardRules = PlainRewards.new(content)
	var coloured: Array = ["coloured", [], ["uppercut", "quakeblow", "oblivionStrike", "limitBreak",
		"warCry", "empower"], "KINDLING"]
	for seed: int in range(SEEDS):
		var starter: Dictionary = _offers(rules, _dusk(content, seed, STARTER), false)
		if starter != _offers(plain, _dusk(content, seed, STARTER), false):
			fails.append("like calls to like: the starter deck's offer is not the pre-weighting offer (seed %d)"
				% seed)
			return
		for deck: Array in [KINDLING, SOOT]:
			if _offers(rules, _dusk(content, seed, deck), false) != starter:
				fails.append("like calls to like: %s leaned (seed %d)" % [deck[0], seed])
				return
		var ash: Dictionary = _offers(rules, _dusk(content, seed, STARTER, 1), true)
		if _offers(rules, _dusk(content, seed, coloured, 1), true) != ash:
			fails.append("like calls to like: the Ashwarden's offers moved with its deck (seed %d)" % seed)
			return


## A lit flame changes which glass is drawn, never how far an offer moves the
## run's cursor: after the shop and after each reward the cursor of a Steady and
## of a True deck is the Kindling deck's, and what the pre-weighting draw leaves
## on the same deck; every price, the gold, potions and relics, the card count and
## the first card's rarity roll match too. A replay of the seed offers the same
## again. The weighting must also change the glass somewhere, or those matches
## would prove nothing.
static func _lit_flames_keep_every_draw(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	var plain: RewardRules = PlainRewards.new(content)
	var leaned: Dictionary = {}
	for seed: int in range(SEEDS):
		var unlit: Dictionary = _offers(rules, _dusk(content, seed, STARTER), false)
		for deck: Array in [LIT, TRUE_LANTERN]:
			var lit: Dictionary = _offers(rules, _dusk(content, seed, deck), false)
			var before: Dictionary = _offers(plain, _dusk(content, seed, deck), false)
			var problem: String = _same_draws(content, unlit, lit)
			if problem.is_empty():
				problem = _same_draws(content, before, lit)
			if problem.is_empty() and _offers(rules, _dusk(content, seed, deck), false) != lit:
				problem = "offered differently on a replay"
			if not problem.is_empty():
				fails.append("like calls to like: %s seed %d %s" % [deck[0], seed, problem])
				return
			if lit != before:
				leaned[str(deck[0])] = true
	for deck: Array in [LIT, TRUE_LANTERN]:
		if not leaned.has(str(deck[0])):
			fails.append("like calls to like: %s never drew other glass than the pre-weighting draw"
				% deck[0])


## What in `lit` must be as in `reference` (offers made with no weighting, or by
## the Kindling deck): the cursor after every offer, and everything but the glass.
static func _same_draws(content: ContentDB, reference: Dictionary, lit: Dictionary) -> String:
	var reference_cursors: Dictionary = reference["cursors"]
	var lit_cursors: Dictionary = lit["cursors"]
	for offer: String in lit_cursors:
		if lit_cursors[offer] != reference_cursors[offer]:
			return "moved the run's cursor after the %s offer" % offer
	var shop: Dictionary = lit["shop"].duplicate(true)
	var plain_shop: Dictionary = reference["shop"].duplicate(true)
	for category: String in ["cards", "relics"]:
		for stock: Dictionary in [shop, plain_shop]:
			for row_v: Variant in stock[category]:
				var row: Dictionary = row_v
				row.erase("id")
	if shop != plain_shop:
		return "moved a shop price, row or potion"
	for kind: String in REWARDS:
		var reward: Dictionary = lit[kind].duplicate(true)
		var plain: Dictionary = reference[kind].duplicate(true)
		var cards: Array = reward["cards"]
		var plain_cards: Array = plain["cards"]
		if cards.size() != plain_cards.size() or _rarity(content, cards[0]) != _rarity(content, plain_cards[0]):
			return "changed the %s reward's card count or first rarity" % kind
		reward.erase("cards")
		plain.erase("cards")
		if reward != plain:
			return "moved the %s reward's gold, potion or relic" % kind
	return ""


static func _rarity(content: ContentDB, id_v: Variant) -> String:
	return str(content.cards.get(str(id_v), {}).get("rarity", ""))


## The expected-frequency test. Over SAMPLES offers from one deck, one entry of
## the dominant way is drawn `likeWeight` times as often as one clear entry of
## the same pool, one of the fringe way `fringeWeight` times; Kindling and Soot
## draw both like clear glass. Measured on the shop's uncommon card slots and
## uncommon relic slot, and on the first card of a boss card reward.
static func _the_lift(content: ContentDB, fails: Array[String]) -> void:
	var dusk: Dictionary = content.aspects[0]
	var constants: Dictionary = dusk["flame"]
	var like: float = float(str(constants["likeWeight"]))
	var fringe: float = float(str(constants["fringeWeight"]))
	var excludes: Dictionary = dusk["excludes"]
	var excluded: Array = []
	for kind: String in ["cards", "relics"]:
		var ids: Array = excludes[kind]
		excluded.append_array(ids)
	var rules: RewardRules = RewardRules.new(content)
	var measured: Array[String] = []
	for deck: Array in [LIT, KINDLING, SOOT]:
		var run_state: RunState = _dusk(content, 0, deck)
		var card_pool: Array = rules.offer_cards(run_state, "uncommon")
		var relic_pool: Array = rules.offer_relics(run_state, "uncommon")
		var cards: Dictionary = {}
		var relics: Dictionary = {}
		for _i: int in range(SAMPLES):
			var stock: Dictionary = rules.gen_shop(run_state)
			for slot: int in [2, 3]:
				_tally(cards, stock["cards"][slot]["id"])
			for row_v: Variant in stock["relics"]:
				var row: Dictionary = row_v
				if relic_pool.has(row["id"]):
					_tally(relics, row["id"])
		var expect_like: float = like if deck == LIT else 1.0
		var expect_fringe: float = fringe if deck == LIT else 1.0
		var lifts: Array[float] = [
			_lift(content, cards, card_pool, false, "edge", "lantern"),
			_lift(content, cards, card_pool, false, "lantern", "edge"),
			_lift(content, relics, relic_pool, true, "edge", "lantern"),
			_lift(content, relics, relic_pool, true, "lantern", "edge"),
		]
		var expected: Array[float] = [expect_like, expect_fringe, expect_like, expect_fringe]
		if deck == LIT:
			var first: Dictionary = {}
			for _i: int in range(SAMPLES):
				_tally(first, rules.gen_combat_rewards(run_state, "boss")["cards"][0])
			var rares: Array = rules.offer_cards(run_state, "rare")
			lifts.append(_lift(content, first, rares, false, "edge", "lantern"))
			lifts.append(_lift(content, first, rares, false, "lantern", "edge"))
			expected.append_array([like, fringe])
			_hygienic(fails, str(deck[0]), first, excluded)
		_hygienic(fails, str(deck[0]), cards, excluded)
		_hygienic(fails, str(deck[0]), relics, excluded)
		measured.append("%s %s" % [deck[0], lifts.map(func(l: float) -> String: return "%.2f" % l)])
		for i: int in range(lifts.size()):
			if absf(lifts[i] - expected[i]) > TOLERANCE:
				fails.append("like calls to like: %s lift %d is %.3f, expected %.2f +- %.2f"
					% [deck[0], i, lifts[i], expected[i], TOLERANCE])
	print("  like calls to like (edge, lantern: shop cards, shop relics, boss reward): %s"
		% "; ".join(measured))


static func _tally(hits: Dictionary, id_v: Variant) -> void:
	var id: String = str(id_v)
	var count: int = hits.get(id, 0)
	hits[id] = count + 1


## The per-entry draw rate of glass with affinity to `way` (and none to `other`)
## over that of glass with affinity to neither, within one pool.
static func _lift(content: ContentDB, hits: Dictionary, pool: Array, relics: bool,
		way: String, other: String) -> float:
	var way_hits: int = 0
	var way_entries: int = 0
	var plain_hits: int = 0
	var plain_entries: int = 0
	for id_v: Variant in pool:
		var id: String = str(id_v)
		var affinity: Dictionary = Flame.relic_affinity(content, 0, id) if relics \
			else Flame.card_affinity(content, 0, id)
		var way_weight: float = affinity.get(way, 0.0)
		var other_weight: float = affinity.get(other, 0.0)
		var count: int = hits.get(id, 0)
		if way_weight >= 0.5 and other_weight < 0.5:
			way_hits += count
			way_entries += 1
		elif way_weight < 0.5 and other_weight < 0.5:
			plain_hits += count
			plain_entries += 1
	if way_entries == 0 or plain_entries == 0 or plain_hits == 0:
		return -1.0
	return (float(way_hits) / way_entries) / (float(plain_hits) / plain_entries)


## Pool hygiene holds at every tier: no excluded glass is ever drawn.
static func _hygienic(fails: Array[String], label: String, hits: Dictionary, excluded: Array) -> void:
	for id_v: Variant in excluded:
		if hits.has(str(id_v)):
			fails.append("like calls to like: %s was offered excluded %s" % [label, id_v])
