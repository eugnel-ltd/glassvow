extends RefCounted
## Flame readout 7 (docs/design/2026-09-29-dusk-flame/readouts/readout-7.md):
## each way's own wall. Two Duskblade commons: Spall, Shatter's first common
## (its supply), and Hearthfall, the Lantern's blow paid in Embers alone (its
## payoff in Act 1). Each card through the combat rules, its pool, its
## affinity, the Ashwarden's exclusion and its copy in both catalogues.

const HP: int = 200


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_spall(content, fails)
	_hearthfall(content, fails)
	_pools(content, fails)
	_affinity(content, fails)
	_copy(content, fails)


## A seeded Duskblade fight against one foe at 200 HP, no Ward, no statuses and
## a facet gauge too deep to shatter, so each number below is the card's alone.
static func _fight(content: ContentDB, tag: String) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 60700, "walls-%s" % tag, {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.max_hp = HP
	foe.hp = HP
	foe.block = 0
	foe.statuses.clear()
	foe.facet_max = 99
	foe.chips = 0
	game.cb.player.statuses.clear()
	return game


static func _card(game: GlassvowGame, id: String, up: bool) -> CardInst:
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), up)
	game.cb.hand.append(card)
	return card


static func _stat(game: GlassvowGame, key: String) -> int:
	return int(float(str(game.run.stats.get(key, 0))))


## Spall strikes like Chisel, a common: 5 damage (8 upgraded), and the hit chips
## one Facet more than a plain blow, 2 in all.
static func _spall(content: ContentDB, fails: Array[String]) -> void:
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "spall-%s" % up)
		var foe: EnemyCombatant = game.cb.enemies[0]
		game.cb.player.energy = 3
		var card: CardInst = _card(game, "spall", up)
		game.apply({"t": "playCard", "uid": card.uid, "target": 0})
		var damage: int = 8 if up else 5
		if game.last_ret != true or HP - foe.hp != damage or foe.chips != 2 \
				or game.cb.player.energy != 2:
			fails.append("Spall (up %s): expected %d damage, 2 Facets chipped and 1 Energy; got %d, %d, %d"
				% [up, damage, HP - foe.hp, foe.chips, 3 - game.cb.player.energy])


## Hearthfall costs no Energy and 3 Embers: under 3 it cannot be played and
## nothing moves; with 3 it deals 16 (21 upgraded), empties those Embers into
## embersSpent and goes to the discard pile, not the fire.
static func _hearthfall(content: ContentDB, fails: Array[String]) -> void:
	var poor: GlassvowGame = _fight(content, "hearth-poor")
	poor.cb.embers = 2
	var held: CardInst = _card(poor, "hearthfall", false)
	if poor.rules.can_play(poor.run, poor.cb, held, 0) \
			or poor.rules.play_card(poor.run, poor.cb, held.uid, 0) \
			or poor.cb.embers != 2 or not poor.cb.hand.has(held) or poor.cb.enemies[0].hp != HP:
		fails.append("Hearthfall: two Embers must leave it unplayable and untouched")
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "hearth-%s" % up)
		var foe: EnemyCombatant = game.cb.enemies[0]
		game.cb.embers = 4
		game.cb.player.energy = 3
		var spent: int = _stat(game, "embersSpent")
		var card: CardInst = _card(game, "hearthfall", up)
		game.apply({"t": "playCard", "uid": card.uid, "target": 0})
		var damage: int = 21 if up else 16
		if game.last_ret != true or HP - foe.hp != damage or game.cb.embers != 1 \
				or game.cb.player.energy != 3 or _stat(game, "embersSpent") != spent + 3 \
				or not game.cb.discard.has(card) or game.cb.exhaust.has(card):
			fails.append("Hearthfall (up %s): expected %d damage, 3 Embers spent, no Energy, discarded; got %d, embers %d, energy %d"
				% [up, damage, HP - foe.hp, game.cb.embers, game.cb.player.energy])


## Both are commons of the base pool, offered to the Duskblade from a new Vigil
## and never to the Ashwarden.
static func _pools(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	var dusk: RunState = RunState.new_run(content, 61300, "walls-pool-dusk", {"aspect": 0})
	var ash: RunState = RunState.new_run(content, 61300, "walls-pool-ash", {"aspect": 1})
	for id: String in ["spall", "hearthfall"]:
		if str(content.cards[id].get("rarity", "")) != "common" \
				or not content.card_pools["common"].has(id) or content.pool_gate_cards.has(id):
			fails.append("Walls pools: %s must be an ungated common" % id)
		if not rules.offer_cards(dusk, "common").has(id):
			fails.append("Walls pools: a fresh Duskblade run must be offered %s" % id)
		if rules.offer_cards(ash, "common").has(id):
			fails.append("Walls pools: the Ashwarden must never be offered %s" % id)


## Spall is Shatter glass and Hearthfall Lantern glass, each at 1.0; with the
## starters, two Spalls light the Shatter flame and two Hearthfalls the Lantern's.
static func _affinity(content: ContentDB, fails: Array[String]) -> void:
	var expected: Dictionary = {"spall": "shatter", "hearthfall": "lantern"}
	for id: String in expected:
		var way: String = expected[id]
		if Flame.card_affinity(content, 0, id) != {way: 1.0}:
			fails.append("Walls affinity: %s expected {%s: 1.0}, got %s"
				% [id, way, Flame.card_affinity(content, 0, id)])
		var run_state: RunState = RunState.new_run(content, 61400, "walls-flame-%s" % id, {"aspect": 0})
		for _i: int in range(2):
			run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
		var reading: Dictionary = Flame.read(content, run_state)
		if str(reading["dominant"]) != way or str(reading["tier"]) != Flame.TIER_STEADY:
			fails.append("Walls affinity: starters + two %s must read Steady %s, got %s"
				% [id, way, reading])


## Each card is authored in both catalogues, and the zh-Hant copy is its own.
static func _copy(content: ContentDB, fails: Array[String]) -> void:
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	if zh.code != Locale.CODE_ZH_HANT:
		fails.append("Walls copy: the zh-Hant catalogue did not load")
		return
	for id: String in ["spall", "hearthfall"]:
		for leaf: String in ["name", "text", "textUp"]:
			var key: String = "content.cards.%s.%s" % [id, leaf]
			var english: String = en.t(key)
			var chinese: String = zh.t(key)
			if english == key or chinese == key or english == chinese:
				fails.append("Walls copy: %s is not authored in both catalogues (%s / %s)"
					% [key, english, chinese])
		if en.t("content.cards.%s.text" % id) != str(content.cards[id]["text"]):
			fails.append("Walls copy: the English catalogue and content disagree on %s" % id)
