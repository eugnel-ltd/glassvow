extends RefCounted
## #544 decision 10: the turn's own deal is the class's `handSize`, a content
## field of each aspect row (docs/design/2026-10-05-ash-flame §6.5), wired by
## step A2. Both classes ship 5, so the wiring is neutral; a class whose row
## says otherwise is dealt that many every turn, the act's omen still changes
## the deal, and the cards a relic adds beside it are still `drawn`. A row
## without the field deals 5.

const ASPECTS: Array[int] = [0, 1]


static func run(fails: Array[String]) -> void:
	var shipped: ContentDB = ContentDB.load_full(false)
	for aspect: int in ASPECTS:
		var row: Dictionary = shipped.aspects[aspect]
		if int(float(str(row.get("handSize", -1)))) != 5:
			fails.append("hand size: aspect %d must ship a hand of 5, got %s"
				% [aspect, row.get("handSize")])
		# [handSize in the row (null: none), relics, omen, hand on turns 1 and 2, drawn]
		var cases: Array = [
			[5, [], "", [5, 5], 0],
			[4, [], "", [4, 4], 0],
			[7, [], "", [7, 7], 0],
			[7, [], "emberWind", [6, 6], 0],
			[6, ["travelersPack"], "", [8, 6], 2],
			[null, [], "", [5, 5], 0],
		]
		for case_v: Variant in cases:
			var case: Array = case_v
			_deal(aspect, case, fails)


## One fight of `aspect` on a content copy whose row carries the case's hand: the
## hand after the first deal and after the next turn's, and `drawn` after both.
static func _deal(aspect: int, case: Array, fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var row: Dictionary = content.aspects[aspect]
	if case[0] == null:
		row.erase("handSize")
	else:
		row["handSize"] = case[0]
	var run_state: RunState = RunState.new_run(content, 61700 + aspect, "hand-size",
		{"aspect": aspect})
	var relics: Array = case[1]
	for relic_v: Variant in relics:
		run_state.player.relics.append(str(relic_v))
	if not str(case[2]).is_empty():
		run_state.omens[0] = str(case[2])
	# Enough plain glass that no deal runs the piles dry.
	for _i: int in range(10):
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"defend", false))
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.max_hp = 500
	foe.hp = 500
	var hands: Array[int] = [game.cb.hand.size()]
	game.apply({"t": "endTurn"})
	hands.append(game.cb.hand.size())
	var want: Array = case[3]
	var want_drawn: int = case[4]
	var drawn: int = int(float(str(run_state.stats.get("drawn", 0))))
	if hands != want or drawn != want_drawn:
		fails.append("hand size: aspect %d, hand %s, relics %s, omen '%s': dealt %s, drawn %d, not %s, %d"
			% [aspect, case[0], relics, case[2], hands, drawn, want, want_drawn])
