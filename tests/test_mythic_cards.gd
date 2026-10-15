extends RefCounted
## #212 lane 2: the six mythic rules (design §1, §7, §8.2). Each case plays a
## card in a live fight and checks the rule it breaks, its guard and its limits,
## including the two directed cases: Unbowed ends the Blood for Oil cycle, and the
## Known Road's pick leaves the RNG cursor where a normal draw leaves it.

const SEED: int = 21202


static func _check(fails: Array[String], ok: Variant, what: String) -> void:
	if ok != true:
		fails.append("mythic cards: " + what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_banked_fire(content, fails)
	_silvering(content, fails)
	_silvering_on_hit(fails)
	_silvering_keeper(content, fails)
	_unbroken_flame(content, fails)
	_unbowed(content, fails)
	_unbowed_ends_the_blood_cycle(content, fails)
	_known_road(content, fails)
	_known_road_short_pile(content, fails)
	_clean_break(content, fails)


## Banked Fire: a won fight stores the lantern's Embers; the next fight opens
## with them, up to its cap, and a restarted fight opens the same; a win without
## the card overwrites the store with 0.
static func _banked_fire(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var run_state: RunState = game.run
	var base: int = game.cb.embers
	run_state.quest_scratch[RewardRules.MYTHIC_SLOT] = {"id": "bankedFire", "via": "knight"}
	_play(game, _in_hand(game, "bankedFire"), null)
	_check(fails, game.last_ret == true and game.cb.banked, "Banked Fire did not mark the fight")
	game.cb.embers = 4
	game.rules._win_combat(run_state, game.cb)
	var slot: Dictionary = run_state.quest_scratch[RewardRules.MYTHIC_SLOT]
	_check(fails, slot.get("embers", -1) == 4, "the win stored %s Embers, not 4" % [slot.get("embers")])
	for attempt: int in range(2):
		_start(game)
		_check(fails, game.cb.embers == mini(base + 4, game.cb.ember_cap) and slot["embers"] == 4,
			"fight %d opened with %d Embers, the store reads %s" % [attempt, game.cb.embers, slot["embers"]])
	slot["embers"] = 50
	_start(game)
	_check(fails, game.cb.embers == game.cb.ember_cap, "a carry above the cap was not clamped")
	game.rules._win_combat(run_state, game.cb)
	_check(fails, slot["embers"] == 0, "a win without Banked Fire did not overwrite the store")


## Silvering: the chosen enemy's next move lands on itself, by its own Fervor,
## and you take nothing; a Staggered enemy keeps the mark until it acts.
static func _silvering(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var cb: CombatState = game.cb
	var e: EnemyCombatant = cb.enemies[0]
	e.hp = 99
	e.max_hp = 99
	e.statuses = {"str": 2}
	e.move_key = &"spit"
	_play(game, _in_hand(game, "silvering"), 0)
	_check(fails, game.last_ret == true and e.flags.has(CombatRules.SILVERED)
			and cb.exhaust.size() == 1 and cb.exhaust[0].id == &"silvering",
		"Silvering did not mark its target and Kindle")
	e.staggered = true
	game.apply({"t": "endTurn"})
	_check(fails, e.flags.has(CombatRules.SILVERED) and e.hp == 99,
		"a Staggered enemy spent its Silvering")
	var hp_before: int = cb.player.hp
	e.move_key = &"spit"
	var bonus: int = game.rules._challenge_mods(game.run)["enemyDmgBonus"]
	var expected: int = 4 + 2 + bonus
	game.rules.end_turn(game.run, cb)
	_check(fails, e.hp == 99 - expected and cb.player.hp == hp_before
			and not e.flags.has(CombatRules.SILVERED),
		"the turned blow: enemy %d (want %d), player %d (want %d)" % [e.hp, 99 - expected, cb.player.hp, hp_before])


## On-hit riders follow each blow. The affix replaces a matching omen value;
## ordinary hits still poison the player, then tick as the player's turn starts.
static func _silvering_on_hit(fails: Array[String]) -> void:
	for case: Dictionary in [
		{"label": "Cinder-Veined Crush", "affix": "cinderVeined", "omen": "", "n": 1, "times": 1},
		{"label": "Ashfall Crush", "affix": "", "omen": "ashfall", "n": 1, "times": 1},
		{"label": "overriding affix, two blows", "affix": "cinderVeined", "omen": "ashfall", "n": 1, "times": 2},
	]:
		var content: ContentDB = ContentDB.load_full()
		if case["times"] == 2:
			# Deliberately different values expose replacement versus addition.
			content.omens["ashfall"]["mods"]["playerHitApplies"]["poison"] = 3
		for mirrored: bool in [false, true]:
			var run_state: RunState = RunState.new_run(content, SEED, "silvering-on-hit")
			run_state.omens[run_state.act] = case["omen"]
			var game: GlassvowGame = GlassvowGame.new(content, run_state)
			game.apply({"t": "startCombat", "enemies": ["gravewarden"],
				"kind": "elite" if case["affix"] != "" else "normal", "affix": case["affix"]})
			var cb: CombatState = game.cb
			var e: EnemyCombatant = cb.enemies[0]
			e.hp = 99
			e.max_hp = 99
			e.statuses = {"thorns": 3}  # Remove Ashfall's starting Smolder.
			e.move_key = &"crush"
			e.def = e.def.duplicate(true)
			e.def["moves"]["crush"]["times"] = case["times"]
			cb.player.statuses = {"str": 7}
			cb.player.block = 0
			if mirrored:
				_play(game, _in_hand(game, "silvering"), 0)
			var hp_before: int = cb.player.hp
			var damage: int = (12 + game.rules._challenge_mods(run_state)["enemyDmgBonus"]) * case["times"]
			var poison: int = case["n"] * case["times"]
			var events: Array[Dictionary] = game.apply({"t": "endTurn"})
			var label: String = "%s, mirrored %s" % [case["label"], mirrored]
			var riders: int = 0
			for i: int in range(events.size()):
				var event: Dictionary = events[i]
				if event.get("t") != EventTypes.STATUS or event.get("id") != "poison":
					continue
				riders += 1
				_check(fails, event["who"] == (0 if mirrored else "player") and event["n"] == case["n"]
						and i > 0 and events[i - 1]["t"] == (EventTypes.HIT_ENEMY if mirrored else EventTypes.HIT_PLAYER),
					label + ": on-hit rider did not follow its blow with the merged value")
			_check(fails, riders == case["times"], "%s: got %d on-hit riders" % [label, riders])
			var player_statuses: Dictionary = {"str": 7}
			if not mirrored and poison > 1:
				player_statuses["poison"] = poison - 1
			_check(fails, e.statuses.get("poison", 0) == (poison if mirrored else 0)
					and cb.player.statuses == player_statuses,
				"%s: enemy statuses %s, player statuses %s" % [label, e.statuses, cb.player.statuses])
			_check(fails, e.hp == (99 - damage if mirrored else 99)
					and cb.player.hp == (hp_before if mirrored else hp_before - damage - poison),
				"%s: enemy HP %d, player HP %d" % [label, e.hp, cb.player.hp])


## Silvering on the Eternal Keeper: what it meant to lay on you lands on it, and
## a lethal self-hit still stops at 1 HP and hands the fight over.
static func _silvering_keeper(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, ["eternalKeeper"], "boss")
	var cb: CombatState = game.cb
	var keeper: EnemyCombatant = cb.enemies[0]
	keeper.hp = 400
	keeper.flags[CombatRules.SILVERED] = true
	keeper.move_key = &"kindWord"
	var hp_before: int = cb.player.hp
	game.rules.end_turn(game.run, cb)
	_check(fails, keeper.statuses.get("poison", 0) > 0 and not cb.player.statuses.has("poison")
			and cb.player.hp == hp_before and keeper.hp < 400,
		"the Keeper's Kind Word was not turned on itself")
	keeper.hp = 3
	keeper.statuses.erase("poison")
	keeper.flags[CombatRules.SILVERED] = true
	keeper.move_key = &"hearthBlow"
	game.rules.end_turn(game.run, cb)
	_check(fails, cb.finale_handoff and cb.over and keeper.hp == 1,
		"a lethal turned blow did not stop the Keeper at 1 HP")


## The Unbroken Flame: every way's `lit` effect resolves; the flame's own way and
## the lantern's quality stay as the fight began.
static func _unbroken_flame(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var cb: CombatState = game.cb
	cb.lit_way = ""
	var leak: int = cb.ember_leak
	var ways: Array[String] = []
	for way: Dictionary in Flame.ways(content, game.run.aspect):
		ways.append(str(way["id"]))
	for way: String in ways:
		_check(fails, not CombatRules.effect_lit(cb, {"lit": way}), "%s lit before the card" % way)
	_play(game, _in_hand(game, "unbrokenFlame"), null)
	for way: String in ways:
		_check(fails, CombatRules.effect_lit(cb, {"lit": way}), "%s did not light" % way)
	_check(fails, game.last_ret == true and cb.lit_way == "" and cb.ember_leak == leak,
		"the Unbroken Flame changed the flame's way or the lantern")


## Unbowed: the first fall stands at 0 HP and absorbs every loss until the end of
## the next turn, then falls; healing lifts the doom; Kindling it gives the
## protection up; a win sets HP to 1; it holds once a fight.
static func _unbowed(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var run_state: RunState = game.run
	var cb: CombatState = game.cb
	cb.draw.append(_card(run_state, "unbowed"))
	cb.player.hp = 5
	var turn: int = cb.turn
	game.rules.damage_player(run_state, cb, 10, "self")
	game.rules.damage_player(run_state, cb, 7, "self")
	_check(fails, cb.player.hp == 0 and not cb.over and cb.standing_until == turn + 1,
		"the fall did not stand until the next turn's end")
	_end_turn_quietly(game)
	_check(fails, not cb.over and cb.player.hp == 0, "the stand ended before its deadline")
	_end_turn_quietly(game)
	_check(fails, cb.over and cb.result == "loss", "a stand at 0 HP outlived its deadline")

	game = _fight(content)
	cb = game.cb
	cb.draw.append(_card(game.run, "unbowed"))
	cb.player.hp = 5
	game.rules.damage_player(game.run, cb, 10, "self")
	game.rules.heal_player(game.run, cb, 6)
	_end_turn_quietly(game)
	_end_turn_quietly(game)
	_check(fails, not cb.over and cb.player.hp == 6 and cb.standing_until == 0,
		"healing did not lift the doom")
	game.rules.damage_player(game.run, cb, 10, "self")
	_check(fails, cb.over and cb.result == "loss", "Unbowed held twice in one fight")

	game = _fight(content)
	cb = game.cb
	var kindled: CardInst = _in_hand(game, "unbowed")
	game.apply({"t": "kindleFromHand", "uid": kindled.uid})
	cb.player.hp = 5
	game.rules.damage_player(game.run, cb, 10, "self")
	_check(fails, cb.exhaust.has(kindled) and cb.over and cb.result == "loss",
		"a Kindled Unbowed still held")

	game = _fight(content)
	game.cb.draw.append(_card(game.run, "unbowed"))
	game.cb.player.hp = 5
	game.rules.damage_player(game.run, game.cb, 10, "self")
	game.run.player.relics.clear()  # the Ember Heart heals after the clamp
	game.rules._win_combat(game.run, game.cb)
	_check(fails, game.run.player.hp == 1, "a win while standing left %d HP" % game.run.player.hp)


## The directed case (§8.2): Unbowed, Blood for Oil and two Tinder+ in hand, no
## other card, 6 HP, 0 Energy. Blood for Oil is played until it is back in hand
## and refused. It is played exactly twice (6 to 3 HP, then the stand) for 4
## Energy. The 100-play bound fails the test; it is not a game rule.
static func _unbowed_ends_the_blood_cycle(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var run_state: RunState = game.run
	var cb: CombatState = game.cb
	cb.draw.clear()
	cb.discard.clear()
	cb.hand.clear()
	var blood: CardInst = _card(run_state, "bloodRite")
	var tinders: Array[CardInst] = [_card(run_state, "preparation", true), _card(run_state, "preparation", true)]
	cb.hand.append_array([_card(run_state, "unbowed"), blood, tinders[0], tinders[1]])
	cb.player.hp = 6
	cb.player.energy = 0
	var blood_plays: int = 0
	var gained: int = 0
	var ended: bool = false
	for _play_i: int in range(100):
		if cb.hand.has(blood):
			if not game.rules.can_play(run_state, cb, blood, null):
				ended = true
				break
			var before: int = cb.player.energy
			_play(game, blood, null)
			gained += cb.player.energy - before
			blood_plays += 1
			continue
		var tinder: CardInst = null
		for held: CardInst in tinders:
			if cb.hand.has(held):
				tinder = held
		if tinder == null:
			fails.append("mythic cards: the Blood for Oil harness stalled with no Tinder+ in hand")
			return
		_play(game, tinder, null)
	_check(fails, ended and blood_plays == 2 and gained == 4 and cb.player.hp == 0 and not cb.over
			and cb.standing_until > 0,
		"the cycle: ended %s, %d plays, %d Energy, %d HP" % [ended, blood_plays, gained, cb.player.hp])


## The Known Road: played, it stages each later deal; while the pick is pending
## the game takes nothing else; the pick then deals the hand.
static func _known_road(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content)
	var cb: CombatState = game.cb
	_play(game, _in_hand(game, "knownRoad"), null)
	_check(fails, game.last_ret == true and cb.known_road, "the Known Road did not take hold")
	_end_turn_quietly(game)
	_check(fails, cb.hand.is_empty() and cb.staged.size() == game.rules._hand_size(game.run),
		"the turn's deal was not staged: hand %d, staged %d" % [cb.hand.size(), cb.staged.size()])
	var kept: CardInst = _in_hand(game, "strike")
	cb.player.energy = 3
	cb.embers = cb.ember_cap
	var turn: int = cb.turn
	var deck: int = game.run.player.deck.size()
	var embers: int = cb.embers
	for cmd: Dictionary in [{"t": "playCard", "uid": kept.uid, "target": 0}, {"t": "endTurn"},
			{"t": "useArt"}, {"t": "kindleFromHand", "uid": kept.uid},
			{"t": "addCardToDeck", "cardId": "strike"}]:
		var events: Array[Dictionary] = game.apply(cmd)
		_check(fails, events.is_empty() and game.last_ret == false,
			"%s was taken while the pick was pending" % cmd["t"])
	_check(fails, cb.hand.has(kept) and cb.turn == turn and cb.embers == embers
			and game.run.player.deck.size() == deck,
		"a refused command still changed the fight")
	var staged: Array = _uids(cb.staged)
	game.apply({"t": "chooseHand", "uids": staged})
	_check(fails, game.last_ret == true and cb.staged.is_empty() and _uids(cb.hand).slice(1) == staged,
		"confirming the deal did not deal it")


## The directed case (§8.2): draw pile [A], discard [B, C], a deal of 2.
static func _known_road_short_pile(content: ContentDB, fails: Array[String]) -> void:
	var plain: Array = _short_pile(content)
	var plain_game: GlassvowGame = plain[0]
	plain_game.rules._draw_from_pile(plain_game.run, plain_game.cb, 2)
	var dealt: Array = _uids(plain_game.cb.hand)
	var cursor: int = plain_game.run.rng_state()

	var confirm: Array = _short_pile(content)
	var game: GlassvowGame = confirm[0]
	game.rules._draw_from_pile(game.run, game.cb, 2, true)
	_check(fails, game.cb.hand.is_empty() and _uids(game.cb.staged) == dealt,
		"the staged deal is not the normal deal")
	game.apply({"t": "chooseHand", "uids": _uids(game.cb.staged)})
	_check(fails, game.last_ret == true and _uids(game.cb.hand) == dealt and game.run.rng_state() == cursor,
		"confirming at once is not the normal draw")

	var swap: Array = _short_pile(content)
	game = swap[0]
	var a: CardInst = swap[1]
	var b: CardInst = swap[2]
	var c: CardInst = swap[3]
	game.rules._draw_from_pile(game.run, game.cb, 2, true)
	for wrong: Array in [[b.uid], [b.uid, b.uid], [b.uid, 999999], [a.uid, c.uid, b.uid]]:
		game.apply({"t": "chooseHand", "uids": wrong})
		_check(fails, game.last_ret == false and game.cb.staged.size() == 2,
			"the pick %s was taken" % [wrong])
	game.apply({"t": "chooseHand", "uids": [b.uid, c.uid]})
	var hand: Array = _uids(game.cb.hand)
	hand.sort()
	var want: Array = [b.uid, c.uid]
	want.sort()
	_check(fails, game.last_ret == true and hand == want and _uids(game.cb.draw) == [a.uid]
			and game.run.rng_state() == cursor,
		"picking {B, C}: hand %s, pile %s" % [hand, _uids(game.cb.draw)])

	game = _fight(content, [], "normal", SEED + 1)
	var cb: CombatState = game.cb
	cb.hand.clear()
	cb.discard.clear()
	var before: int = game.run.rng_state()
	game.rules._draw_from_pile(game.run, cb, 2, true)
	var from_pile: int = cb.draw[0].uid
	game.apply({"t": "chooseHand", "uids": [cb.staged[0].uid, from_pile]})
	_check(fails, game.last_ret == true and _uids(cb.hand).has(from_pile) and game.run.rng_state() == before,
		"a deal and pick from a full pile called the RNG")


## Clean Break: its shatter, and every later one this fight, adds no Facet; the
## adamant hold still holds once.
static func _clean_break(content: ContentDB, fails: Array[String]) -> void:
	for mythic: bool in [false, true]:
		var game: GlassvowGame = _fight(content)
		var e: EnemyCombatant = game.cb.enemies[0]
		e.hp = 999
		e.max_hp = 999
		e.block = 0
		var facets: int = e.facet_max
		e.chips = facets - 1
		_play(game, _in_hand(game, "cleanBreak" if mythic else "strike"), 0)
		var want: int = facets if mythic else facets + 1
		_check(fails, e.staggered and e.facet_max == want,
			"%s: shattered %s, Facets %d, want %d" % ["Clean Break" if mythic else "Edge",
				e.staggered, e.facet_max, want])
	var game: GlassvowGame = _fight(content)
	var cb: CombatState = game.cb
	var e: EnemyCombatant = cb.enemies[0]
	e.hp = 999
	e.flags["adamant"] = true
	cb.clean_break = true
	var facets: int = e.facet_max
	game.rules.apply_chips(game.run, cb, e, facets)
	_check(fails, e.flags.get("adamantSpent", false) and not e.staggered and e.facet_max == facets,
		"Clean Break skipped the adamant hold")
	game.rules.apply_chips(game.run, cb, e, facets)
	_check(fails, e.staggered and e.facet_max == facets, "the shatter after the hold added a Facet")


static func _fight(content: ContentDB, enemies: Array = [], kind: String = "normal",
		seed: int = SEED) -> GlassvowGame:
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, seed, "mythic-cards"))
	var group: Array = content.encounters[0]["weak"][0]
	game.apply({"t": "startCombat", "enemies": enemies if not enemies.is_empty() else [group[0]],
		"kind": kind})
	return game


## A new fight for the same run, as a restarted fight is built.
static func _start(game: GlassvowGame) -> void:
	game.apply({"t": "startCombat", "enemies": [game.cb.enemies[0].key], "kind": "normal"})


static func _card(run_state: RunState, id: String, up: bool = false) -> CardInst:
	return CardInst.new(run_state.next_uid(), StringName(id), up)


static func _in_hand(game: GlassvowGame, id: String) -> CardInst:
	var card: CardInst = _card(game.run, id)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	return card


static func _play(game: GlassvowGame, card: CardInst, target: Variant) -> void:
	game.apply({"t": "playCard", "uid": card.uid, "target": target})


## End the turn with every enemy Staggered, so only the rules under test act.
static func _end_turn_quietly(game: GlassvowGame) -> void:
	for e: EnemyCombatant in game.cb.enemies:
		e.staggered = true
	game.apply({"t": "endTurn"})


static func _uids(cards: Array[CardInst]) -> Array:
	var out: Array = []
	for card: CardInst in cards:
		out.append(card.uid)
	return out


## [game, A, B, C]: draw pile [A], discard [B, C], an empty hand.
static func _short_pile(content: ContentDB) -> Array:
	var game: GlassvowGame = _fight(content)
	var cb: CombatState = game.cb
	cb.hand.clear()
	cb.draw.clear()
	cb.discard.clear()
	var a: CardInst = _card(game.run, "strike")
	var b: CardInst = _card(game.run, "defend")
	var c: CardInst = _card(game.run, "chisel")
	cb.draw.append(a)
	cb.discard.append_array([b, c])
	return [game, a, b, c]
