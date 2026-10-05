extends RefCounted
## #544 P6: the bots play every Ashwarden verb (search `s2`, pilot `p9`).
##
## Probes: fixed Ashwarden fights whose best line is known and checked by hand
## below. The 1.1 instrument (`s2` with `p9`) must find each one; 1.0's (`s1` with
## `p8-d0-v3`) misses the three that turn on the hand-size payoff or on the draw's
## worth, the blind spot being fixed. s2 must stay honest: it never credits a
## payoff the draw itself dealt. Then the parts each finding rests on, one by one:
## the draw credit reads the multiset the cards came from, and the pilot values a
## hand-size payoff by its deck's hand and a rider its class cannot light at nothing.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Search: GDScript = preload("res://tools/balance_search.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const ASH: int = 1
const DUSK: int = 0


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.apply_policy({})
	_flags(fails)
	_probes(content, fails)
	_unseen_payoff(content, fails)
	_draw_worth(content, fails)
	_payoff_worth(content, fails)
	_riders(content, fails)
	Pilot.select(Pilot.VERSION)
	Search.select(Search.VERSION)
	Pilot.apply_policy({})


## The simulator names its bots: unnamed, 1.0's (`p8-d0-v3`, `s1`); `--pilot` and
## `--search` choose 1.1's, and the manifest says which; an unknown one, or a search
## player named for greedy play, is refused.
static func _flags(fails: Array[String]) -> void:
	var plain: Dictionary = Sim._options(PackedStringArray(["--play=search"]))
	var named: Dictionary = Sim._options(PackedStringArray(["--play=search", "--pilot=p9", "--search=s2"]))
	var manifest: Dictionary = Sim._manifest(named, "", {})
	var search: Dictionary = manifest.get("search", {})
	if [plain.get("pilot"), plain.get("search")] != ["p8-d0-v3", "s1"] \
			or [manifest.get("pilot"), search.get("version")] != ["p9", "s2"]:
		fails.append("balance bots: options %s and manifest %s name the wrong bots" % [plain, manifest])
	for bad: Array in [["--pilot=p10"], ["--play=search", "--search=s4"], ["--search=s2"]]:
		if not Sim._options(PackedStringArray(bad)).has("error"):
			fails.append("balance bots: the simulator accepts %s" % [bad])


## Each probe is one turn from a fixed position, played as the simulator plays it.
## s2/p9 finds every one; s1/p8-d0-v3 finds exactly those marked `s1`.
static func _probes(content: ContentDB, fails: Array[String]) -> void:
	for probe: Dictionary in _probe_table():
		var found: Dictionary = {}
		for bots: Array in [[Search.HAND_VERSION, Pilot.HAND_VERSION], [Search.VERSION, Pilot.VERSION]]:
			Search.select(str(bots[0]))
			Pilot.select(str(bots[1]))
			var game: GlassvowGame = _position(content, probe)
			Search.play_turn(game)
			found[bots[0]] = probe["found"].call(game)
		if not found[Search.HAND_VERSION]:
			fails.append("balance bots: s2/p9 misses the probe %s" % probe["name"])
		if found[Search.VERSION] != probe["s1"]:
			fails.append("balance bots: s1/p8-d0-v3 %s the probe %s"
				% ["finds" if found[Search.VERSION] else "misses", probe["name"]])


## The probes. The hero is an Ashwarden at 30 HP; one Sporeling stands opposite,
## its Spore Spit (4) raised by 36 Fervor to a 40-damage blow unless stated; the
## draw pile is all Defends unless stated, so what a draw brings is known. Phantom
## Blades deals 3 for each card left in hand once it is played.
static func _probe_table() -> Array[Dictionary]:
	return [
		# Draw, then Phantom Blades with the bigger hand. Energy 3. Tinder first leaves
		# Phantom Blades with five cards beside it, 15 damage, the Sporeling's 15 HP: the
		# fight is won. Phantom Blades first deals 12 (four beside it) and no kill. The
		# greedy turn blocks first (the blow is lethal) and never kills.
		{"name": "Tinder then Phantom Blades", "energy": 3, "foe": 15, "str": 36,
			"hand": ["preparation", "phantomBlades", "defend", "defend", "defend"], "s1": false,
			"found": func(game: GlassvowGame) -> bool: return game.cb.over and game.cb.result == "win"},
		# A Struck Match line into the payoff. Energy 0: only Struck Match can be played.
		# It gives 1 Energy and draws 1, and Phantom Blades then deals 3 x 4 = 12, the
		# Sporeling's 12 HP. The greedy turn spends the Energy on a Defend.
		{"name": "Struck Match then Phantom Blades", "energy": 0, "foe": 12, "str": 36,
			"hand": ["surge", "phantomBlades", "defend", "defend", "defend"], "s1": false,
			"found": func(game: GlassvowGame) -> bool: return game.cb.over and game.cb.result == "win"},
		# Stack Smolder, then Bellows (Catalyst, doubling a foe's Smolder). Energy 3, the
		# foe at 500 HP with 3 Smolder and no blow (it grows). Ashbite (2 Smolder) then
		# Bellows: 10 Smolder. Bellows first: 3 -> 6, then 8.
		{"name": "Ashbite then Bellows", "energy": 3, "foe": 500, "str": 0, "smolder": 3, "move": "grow",
			"hand": ["catalyst", "ashBite", "defend", "defend", "defend"], "s1": true,
			"found": func(game: GlassvowGame) -> bool:
				return int(float(str(game.cb.enemies[0].statuses.get("poison", 0)))) == 10},
		# The draw's worth, with no payoff. Energy 2, the foe at 500 HP and no blow; the
		# draw pile all Emberbites (1 Energy: 4 damage, 4 Smolder). Tinder first deals two
		# Emberbites and the Energy pays for both: 8 damage, 8 Smolder. Ashbite first
		# spends the Energy (6 damage, 2 Smolder) and the Emberbites Tinder then deals go
		# unpaid. The greedy turn plays Ashbite first: it scores it above Tinder.
		{"name": "Tinder before Ashbite", "energy": 2, "foe": 500, "str": 0, "move": "grow",
			"hand": ["ashBite", "preparation", "defend", "defend", "defend"], "s1": false,
			"pile": ["venomStrike", "venomStrike", "venomStrike", "venomStrike", "venomStrike", "venomStrike"],
			"found": func(game: GlassvowGame) -> bool: return _first_play(game) == "preparation"},
	]


## The id of the first card the turn played.
static func _first_play(game: GlassvowGame) -> String:
	for event: Dictionary in game.cb.queue:
		if event.get("t") == EventTypes.PLAY:
			return str(event.get("id", ""))
	return ""


## Honest play: a line that ends at a draw never counts a payoff the draw itself
## dealt. Tinder (Energy 3, hand Tinder and four Defends) would deal Phantom Blades
## from the top of the pile, and with the hand it leaves Phantom Blades deals
## 3 x 5 = 15, the Sporeling's 15 HP. The player has not seen it, so no line is
## credited the win: s2's best line scores under WIN.
static func _unseen_payoff(content: ContentDB, fails: Array[String]) -> void:
	Search.select(Search.HAND_VERSION)
	Pilot.select(Pilot.HAND_VERSION)
	var game: GlassvowGame = _position(content, {"energy": 3, "foe": 15, "str": 36,
		"hand": ["preparation", "defend", "defend", "defend", "defend"],
		"pile": ["defend", "defend", "defend", "defend", "defend", "phantomBlades"]})
	var plan: Search.Plan = Search.plan_turn(game)
	if plan.value >= Search.WIN:
		fails.append("balance bots: s2 credits Phantom Blades before drawing it (plan %s, %f)"
			% [plan.actions, plan.value])


## An Ashwarden's fight on its first turn, rebuilt to the probe's position.
static func _position(content: ContentDB, probe: Dictionary) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 12000, "probe", {"aspect": ASH})
	run_state.player.potions = ["", "", ""]
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var cb: CombatState = game.cb
	var hand: Array = probe["hand"]
	cb.hand = _cards(run_state, hand)
	var pile: Array = probe.get("pile", ["defend", "defend", "defend", "defend", "defend", "defend"])
	cb.draw = _cards(run_state, pile)
	cb.discard = _cards(run_state, [])
	cb.exhaust = _cards(run_state, [])
	cb.embers = 0
	cb.player.hp = 30
	run_state.player.hp = 30
	cb.player.block = 0
	cb.player.statuses = {}
	cb.player.energy = int(float(str(probe["energy"])))
	var foe: EnemyCombatant = cb.enemies[0]
	foe.hp = int(float(str(probe["foe"])))
	foe.max_hp = foe.hp
	foe.block = 0
	foe.statuses = {}
	var fervor: int = int(float(str(probe["str"])))
	var smolder: int = int(float(str(probe.get("smolder", 0))))
	if fervor > 0:
		foe.statuses["str"] = fervor
	if smolder > 0:
		foe.statuses["poison"] = smolder
	foe.move_key = StringName(str(probe.get("move", "spit")))
	return game


static func _cards(run_state: RunState, ids: Array) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for id_v: Variant in ids:
		out.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	return out


## s2's draw credit is the expected worth of the cards drawn, from the multiset each
## came from: two of three from a draw pile of two Strikes (all of it), the third
## from the discard pile shuffled in (a Defend and an Ashbite). The Ashbite (cost
## 2) is worth nothing with less than 2 Energy, and a card never counts below 0.
## The Energy is shared: with 1 Energy left the three are expected to cost 2.5 (the
## Ashbite costs nothing it cannot be paid for), so they count at two fifths; with
## 4 they cost 3.5 and count in full.
static func _draw_worth(content: ContentDB, fails: Array[String]) -> void:
	Pilot.select(Pilot.HAND_VERSION)
	var game: GlassvowGame = _position(content, _probe_table()[0])
	game.cb.player.energy = 1
	var turn: Search.Turn = Search.Turn.new()
	turn.rules = game.rules
	turn.content = content
	var at: Search.Position = Search.Position.new(game.run, game.cb)
	at.drawn = 3
	at.pile = _cards(game.run, ["strike", "strike"])
	at.spare = _cards(game.run, ["defend", "ashBite"])
	var strike: float = Pilot.catalogue_card_score(content, ASH, "strike")
	var defend: float = Pilot.catalogue_card_score(content, ASH, "defend")
	var expected: float = 2.0 * strike + 1.0 * (defend + 0.0) / 2.0
	var shared: float = Search._draw_worth(turn, at, at)
	game.cb.player.energy = 4
	var ashbite: float = Pilot.catalogue_card_score(content, ASH, "ashBite")
	var full: float = Search._draw_worth(turn, at, at)
	var paid: float = 2.0 * strike + (defend + ashbite) / 2.0
	if absf(shared - expected * 1.0 / 2.5) > 1.0e-6 or absf(full - paid) > 1.0e-6 \
			or strike <= 0.0 or defend <= 0.0:
		fails.append("balance bots: draw worth %f and %f, expected %f and %f"
			% [shared, full, expected / 2.5, paid])
	at.drawn = 0
	if Search._draw_worth(turn, at, at) != 0.0:
		fails.append("balance bots: a line that drew nothing earns draw credit")


## p8-d0-v3 values Phantom Blades at the flat `leech` weight. p9 values it at 3 for
## each card beside it in the hand the deck deals: five with the Ashwarden's starter
## (First Spark draws one and leaves the hand), more as draw cards join the deck.
static func _payoff_worth(content: ContentDB, fails: Array[String]) -> void:
	var run_state: RunState = RunState.new_run(content, 12000, "payoff", {"aspect": ASH})
	var starter: float = Pilot.expected_hand(content, run_state.player.deck)
	Pilot.select(Pilot.VERSION)
	Pilot.see_flame(content, run_state)
	var flat: float = Pilot.catalogue_card_score(content, ASH, "phantomBlades")
	Pilot.select(Pilot.HAND_VERSION)
	Pilot.see_flame(content, run_state)
	var lean: float = Pilot.catalogue_card_score(content, ASH, "phantomBlades")
	for _i: int in range(3):
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), &"preparation", false))
	Pilot.see_flame(content, run_state)
	var fed: float = Pilot.catalogue_card_score(content, ASH, "phantomBlades")
	var base: float = float(str(Pilot._group("card")["rarity"]["rare"])) - 1.0  # a rare at 1 Energy
	var hand: float = 5.0 + 3.0 * 5.0 / 13.0
	var seen: float = float(str(Pilot.hand))
	var leech: float = Pilot._w("special", "leech")
	if starter != 5.0 or absf(flat - (base + leech)) > 1.0e-6 \
			or absf(lean - (base + 3.0 * 4.0)) > 1.0e-6 \
			or absf(seen - hand) > 1.0e-6 or absf(fed - (base + 3.0 * (hand - 1.0))) > 1.0e-6:
		fails.append("balance bots: Phantom Blades p8 %f, p9 %f, p9 with three Tinders %f (hand %f)"
			% [flat, lean, fed, seen])
	Pilot.select(Pilot.VERSION)
	Pilot.see_flame(content, run_state)
	if Pilot.catalogue_card_score(content, ASH, "phantomBlades") != flat:
		fails.append("balance bots: p8-d0-v3's Phantom Blades moved with the deck")


## A lit rider of a way the class does not have: p8-d0-v3 counts it at
## `crackedShare`, p9 at 0. Tinder's amber Ember is the Duskblade's Lantern's: the
## Ashwarden declares no ways, so p9 drops it there and keeps it for the Duskblade.
static func _riders(content: ContentDB, fails: Array[String]) -> void:
	var scores: Dictionary = {}
	for version: String in Pilot.VERSIONS:
		Pilot.select(version)
		for aspect: int in [DUSK, ASH]:
			scores["%s/%d" % [version, aspect]] = Pilot.catalogue_card_score(content, aspect, "preparation")
	var rider: float = Pilot._w("card", "ember") * Pilot._w("special", "crackedShare")
	var ash_drop: float = float(str(scores["p8-d0-v3/%d" % ASH])) - float(str(scores["p9/%d" % ASH]))
	if scores["p9/%d" % DUSK] != scores["p8-d0-v3/%d" % DUSK] or absf(ash_drop - rider) > 1.0e-6:
		fails.append("balance bots: Tinder's rider scores %s" % scores)
