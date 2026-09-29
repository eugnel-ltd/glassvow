extends RefCounted
## The pilot's play policy, one rule for every arm (flame readout 5, from the
## cross-model review of the Flame core and readout 3's Edge notes). Each row
## is a counterexample set up by hand against sporelings so nothing but the rule
## decides it: a lethal turn is judged by the HP loss each play spares, Ward and
## Dimmed together; an aimed card weighs every foe; a special that strikes is
## worth its damage; the Art never prices a better Ember card out of the
## lantern; Cracked and Fervor go on before the hit; Dimmed counts like Ward.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.apply_policy({})
	_dimmed_spares_a_lethal_turn(content, fails)
	_dim_the_glass_finds_the_striker(content, fails)
	_tremor_takes_the_kill(content, fails)
	_strike_specials_are_worth_their_damage(content, fails)
	_the_art_waits_for_a_better_ember_card(content, fails)
	_setup_before_the_hit(content, fails)
	_dimmed_counts_like_ward(content, fails)
	Pilot.apply_policy({})


## HP 22, 1 energy, a 28-damage blow coming, Ward and Dim the Glass in hand:
## Ward leaves 23 to take and the hero dies; Dimmed cuts the blow to 21.
static func _dimmed_spares_a_lethal_turn(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, [{"hp": 30, "move": "spit", "statuses": {"str": 24}}],
		["defend", "dimTheGlass"], 22, 1)
	if Pilot._incoming(game) != 28:
		fails.append("pilot play: the lethal row must forecast 28, got %d" % Pilot._incoming(game))
		return
	var pick: Dictionary = Pilot._pick_play(game)
	if _card_id(game, pick) != "dimTheGlass" or pick.get("target") != 0:
		fails.append("pilot play: a lethal turn must play Dim the Glass on the striker, got %s" % pick)
		return
	Pilot._play_cards(game)
	game.apply({"t": "endTurn"})
	if game.cb.over or game.cb.player.hp != 1:
		fails.append("pilot play: Dimmed must leave the hero on 1 HP, got %d" % game.cb.player.hp)


## Dim the Glass goes to the foe about to strike, not to the weakest foe,
## which is only growing.
static func _dim_the_glass_finds_the_striker(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, [{"hp": 5, "move": "grow"}, {"hp": 15, "move": "spit"}],
		["dimTheGlass"], 60, 3)
	var pick: Dictionary = Pilot._pick_play(game)
	if _card_id(game, pick) != "dimTheGlass" or pick.get("target") != 1:
		fails.append("pilot play: Dim the Glass must aim at the striker, got %s" % pick)


## Tremor on the HP-10 foe deals 9 and kills nothing; on the Cracked HP-12 foe
## each hit is (3 + 2) x 1.5 = 7, so 21 kills it.
static func _tremor_takes_the_kill(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, [{"hp": 10, "move": "grow"},
		{"hp": 12, "move": "grow", "statuses": {"vulnerable": 1}}], ["tremor"], 60, 1)
	var pick: Dictionary = Pilot._pick_play(game)
	if _card_id(game, pick) != "tremor" or pick.get("target") != 1:
		fails.append("pilot play: Tremor must take the kill on the Cracked foe, got %s" % pick)
		return
	Pilot._play_cards(game)
	if game.cb.enemies[1].hp > 0:
		fails.append("pilot play: Tremor must kill the Cracked foe, left %d HP" % game.cb.enemies[1].hp)


## A strike special is worth its damage, each hit counted: an upgrade that adds
## damage adds that much score, and the adaptive arm keeps each card.
static func _strike_specials_are_worth_their_damage(content: ContentDB, fails: Array[String]) -> void:
	var deltas: Dictionary = {"cleft": 3.0, "totality": 4.0, "tremor": 3.0}
	for id: String in deltas:
		var base: float = Pilot.catalogue_card_score(content, 0, id)
		var upgraded: float = Pilot.catalogue_card_score(content, 0, id, true)
		var delta: float = deltas[id]
		if not is_equal_approx(upgraded - base, delta):
			fails.append("pilot play: %s's upgrade must add %.1f, got %.3f (%.3f to %.3f)"
				% [id, delta, upgraded - base, base, upgraded])
		if not Pilot.accepts_card_reward(Pilot.build_card_score(content, 0, id)):
			fails.append("pilot play: the adaptive arm must keep %s, score %.3f under %.3f"
				% [id, Pilot.build_card_score(content, 0, id), Pilot.card_decline_threshold])


## With 3 Embers, Flare (3) would leave Ember Eye (2) unpayable, and Ember Eye
## outranks it: the Eye goes first and the Art waits, so Tremor lands on
## Cracked glass for (3 + 2) x 1.5 = 7 a hit, 21 against Flare-then-Tremor's
## 18. With 5 Embers both are paid, the Art first, and so with 4 when a True
## lantern makes the Art cost 2 (the pilot reads the fight's price); with no
## Ember card in hand the Art fires as before.
static func _the_art_waits_for_a_better_ember_card(content: ContentDB, fails: Array[String]) -> void:
	var rows: Array = [[3, ["emberEye", "tremor"], ["emberEye", "tremor"], 21, 0],
		[5, ["emberEye", "tremor"], ["art", "emberEye", "tremor"], 30, 0],
		[4, ["emberEye", "tremor"], ["art", "emberEye", "tremor"], 30, -1],
		[3, ["strike"], ["art", "strike"], 15, 0]]
	for row_v: Variant in rows:
		var row: Array = row_v
		var embers: int = row[0]
		var hand: Array = row[1]
		var expected_v: Array = row[2]
		var expected: Array[String] = []
		expected.assign(expected_v)
		var damage: int = row[3]
		var game: GlassvowGame = _fight(content, [{"hp": 40, "move": "grow"}], hand, 60, 1, embers)
		game.cb.art_cost_delta = row[4]
		var order: Array[String] = _turn(game)
		var dealt: int = 40 - game.cb.enemies[0].hp
		if order != expected or dealt != damage:
			fails.append("pilot play: %d Embers with %s played %s for %d, expected %s for %d"
				% [embers, hand, order, dealt, expected, damage])


## Setup before the hit, on one durable foe. Splinter Cut cracks it first, so
## Cleft lands for 8 x 1.5 = 12 and its rider (17 in all, where Cleft first
## dealt 13), and Quarry Maul for 18 (23, where the old order dealt 17); Cleft's
## Fervor goes before Tremor, whose three hits then deal (3 + 2 + 1) x 1.5 = 9
## each (44, where Tremor before Cleft dealt 38). The last two are readout 3's
## fixed hands.
static func _setup_before_the_hit(content: ContentDB, fails: Array[String]) -> void:
	var rows: Array = [[["cleft", "splinterCut"], 2, ["splinterCut", "cleft"], 17],
		[["heavyBlow", "splinterCut", "strike"], 3, ["splinterCut", "heavyBlow"], 23],
		[["cleft", "tremor", "splinterCut"], 3, ["splinterCut", "cleft", "tremor"], 44]]
	for row_v: Variant in rows:
		var row: Array = row_v
		var hand: Array = row[0]
		var energy: int = row[1]
		var expected_v: Array = row[2]
		var expected: Array[String] = []
		expected.assign(expected_v)
		var damage: int = row[3]
		var game: GlassvowGame = _fight(content, [{"hp": 60, "move": "grow"}], hand, 60, energy)
		var order: Array[String] = _turn(game)
		var dealt: int = 60 - game.cb.enemies[0].hp
		if order != expected or dealt != damage:
			fails.append("pilot play: %s played %s for %d, expected %s for %d"
				% [hand, order, dealt, expected, damage])


## Dimmed counts like Ward against the coming blow, not only in a lethal turn:
## against a 12 blow Dim the Glass spares 3 (12 to 9), worth what 3 Ward is
## worth; against a foe that does not strike it spares nothing.
static func _dimmed_counts_like_ward(content: ContentDB, fails: Array[String]) -> void:
	var scores: Array[float] = []
	for foe: Dictionary in [{"hp": 40, "move": "grow"}, {"hp": 40, "move": "spit", "statuses": {"str": 8}}]:
		var game: GlassvowGame = _fight(content, [foe], ["dimTheGlass"], 60, 1)
		var card: CardInst = game.cb.hand[0]
		scores.append(Pilot._combat_score(game, card, game.rules.card_data(card), 0, {},
			Pilot._incoming(game), true))
	var worth: float = 3.0 * Pilot._w("combat", "blockNormal")
	if not is_equal_approx(scores[1] - scores[0], worth):
		fails.append("pilot play: Dimmed against a 12 blow must add %.3f, added %.3f"
			% [worth, scores[1] - scores[0]])


## One pilot turn; the Art ("art") and the cards it played, in order.
static func _turn(game: GlassvowGame) -> Array[String]:
	var mark: int = game.cb.queue.size()
	Pilot.play_turn(game)
	var order: Array[String] = []
	for event: Dictionary in game.cb.queue.slice(mark):
		if event.get("t") == EventTypes.ART:
			order.append("art")
		elif event.get("t") == EventTypes.PLAY:
			order.append(str(event.get("id", "")))
	return order


## A Duskblade fight against sporelings with the row's numbers set by hand: the
## hand (nothing left to draw), HP, energy and Embers; each foe's HP, intent and
## statuses, three facets, no Ward.
static func _fight(content: ContentDB, foes: Array, hand: Array, hp: int, energy: int,
		embers: int = 0) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 12000, "pilot-play", {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var ids: Array[String] = []
	for _foe: Variant in foes:
		ids.append("sporeling")
	game.apply({"t": "startCombat", "enemies": ids, "kind": "normal"})
	var cb: CombatState = game.cb
	cb.draw.clear()
	cb.discard.clear()
	cb.hand.clear()
	for id_v: Variant in hand:
		cb.hand.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	cb.player.hp = hp
	cb.player.energy = energy
	cb.player.block = 0
	cb.embers = embers
	for i: int in range(foes.size()):
		var foe: Dictionary = foes[i]
		var e: EnemyCombatant = cb.enemies[i]
		var statuses: Dictionary = foe.get("statuses", {})
		var foe_hp: int = foe["hp"]
		e.hp = foe_hp
		e.block = 0
		e.chips = 0
		e.facet_max = 3
		e.staggered = false
		e.move_key = StringName(str(foe["move"]))
		e.statuses = statuses.duplicate()
	return game


static func _card_id(game: GlassvowGame, pick: Dictionary) -> String:
	var uid: int = pick.get("uid", -1)
	for card: CardInst in game.cb.hand:
		if card.uid == uid:
			return String(card.id)
	return ""
