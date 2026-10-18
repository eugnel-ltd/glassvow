extends RefCounted
## #212 lane 6: the simulator observes mythic safety without enabling O6.
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")

static func _check(fails: Array[String], ok: Variant, message: String) -> void:
	if ok != true:
		fails.append("mythic read: " + message)

static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	Pilot.select(Pilot.VERSION)
	Pilot.apply_policy({})
	Pilot.set_modes(false, false)
	Pilot.set_ban(PackedStringArray())
	for upgraded: bool in [false, true]:
		_pilot_cards(content, upgraded, fails)
		_silvering(content, upgraded, fails)
		_known_road(content, upgraded, fails)
	_claim(content, fails)
	var opts: Dictionary = Sim._options(PackedStringArray(["--mythic=natural", "--vow=5"]))
	_check(fails, not opts.has("error"), "the CLI must accept an explicit natural-drop read")
	if opts.has("error"):
		return
	for arm: String in ["control", "bankedFire", "silvering", "unbrokenFlame", "unbowed", "knownRoad", "cleanBreak"]:
		var forced: Dictionary = Sim._options(PackedStringArray(["--mythic=" + arm, "--vow=3"]))
		_check(fails, not forced.has("error"), "the CLI rejected declared arm " + arm)
	_check(fails, Sim._options(PackedStringArray(["--mythic=unknown", "--vow=3"])).has("error"),
		"unknown mythic ids must fail closed")
	_check(fails, Sim._options(PackedStringArray(["--mythic=silvering", "--vow=2"])).has("error"),
		"forcing a mythic below Vow 3 must be refused")
	_observation(content, fails)
	_replay(content, fails)

static func _fight(content: ContentDB, id: String, upgraded: bool = false) -> GlassvowGame:
	var state: RunState = RunState.new_run(content, 21206, "mythic-pilot", {"vow": 3})
	state.player.deck = [CardInst.new(state.next_uid(), StringName(id), upgraded)]
	var game: GlassvowGame = GlassvowGame.new(content, state)
	game.apply({"t": "startCombat", "enemies": ["sporeling", "sporeling"], "kind": "elite"})
	game.cb.draw.clear()
	game.cb.discard.clear()
	game.cb.hand = [state.player.deck[0].combat_copy()]
	game.cb.player.energy = 3
	game.cb.player.hp = 99
	for enemy: EnemyCombatant in game.cb.enemies:
		enemy.hp = 999
		enemy.block = 0
		enemy.staggered = false
		enemy.move_key = &"spit"
	return game

static func _pilot_cards(content: ContentDB, upgraded: bool, fails: Array[String]) -> void:
	for pair: Array in [["bankedFire", "banked"], ["unbrokenFlame", "unbroken"],
			["knownRoad", "known_road"], ["cleanBreak", "clean_break"]]:
		var game: GlassvowGame = _fight(content, str(pair[0]), upgraded)
		Pilot.play_hand(game)
		_check(fails, game.cb.get(StringName(str(pair[1]))) == true,
			"pilot did not play %s (upgraded=%s)" % [pair[0], upgraded])
	var standing: GlassvowGame = _fight(content, "unbowed", upgraded)
	Pilot.play_hand(standing)
	_check(fails, standing.cb.exhaust.is_empty() and standing.cb.hand.size() == 1,
		"pilot Kindled its passive Unbowed (upgraded=%s)" % upgraded)

static func _silvering(content: ContentDB, upgraded: bool, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "silvering", upgraded)
	game.cb.enemies[0].statuses["str"] = 1
	game.cb.enemies[1].statuses["str"] = 9
	var before: int = game.run.rng_state()
	Pilot.play_hand(game)
	_check(fails, not game.cb.enemies[0].flags.has(CombatRules.SILVERED)
		and game.cb.enemies[1].flags.has(CombatRules.SILVERED),
		"Silvering did not target the largest incoming hit (upgraded=%s)" % upgraded)
	_check(fails, game.run.rng_state() == before, "Silvering target selection moved RNG")
	var preview: Dictionary = game.rules.preview_enemy_dmg(game.cb, game.cb.enemies[0], game.run)
	_check(fails, Pilot._incoming(game) == int(float(str(preview["dmg"]))) * int(float(str(preview["times"]))),
		"incoming forecast still counts a Silvered attack")

static func _known_road(content: ContentDB, upgraded: bool, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "knownRoad", upgraded)
	var weak: CardInst = CardInst.new(game.run.next_uid(), &"defend", false)
	var strong: CardInst = CardInst.new(game.run.next_uid(), &"chisel", true)
	game.cb.hand.clear()
	game.cb.staged = [weak]
	game.cb.draw = [strong]
	game.cb.known_road = true
	game.cb.player.energy = 0
	game.cb.embers = 0
	var before: int = game.run.rng_state()
	Pilot.play_hand(game)
	_check(fails, game.cb.staged.is_empty(), "Known Road's pending choice stalled the pilot")
	_check(fails, game.cb.draw.size() == 1 and game.cb.draw[0].uid == weak.uid,
		"Known Road did not choose the highest-scored card")
	_check(fails, game.run.rng_state() == before, "Known Road's pick moved RNG")

static func _claim(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "strike")
	var before: int = game.run.rng_state()
	Sim._claim_rewards(game, {"gold": 0, "cards": [], "mythic": "silvering"})
	var count: int = 0
	for card: CardInst in game.run.player.deck:
		count += 1 if card.id == &"silvering" else 0
	_check(fails, count == 1, "the simulator ignored a separate mythic Spoil")
	_check(fails, game.run.rng_state() == before, "claiming a mythic Spoil moved RNG")

static func _observation(content: ContentDB, fails: Array[String]) -> void:
	var live: bool = RewardRules.mythics_live
	RewardRules.mythics_live = true
	var game: GlassvowGame = _fight(content, "strike")
	game.rewards.mythic_rate = 1.0
	var first: Dictionary = Sim.call("mythic_rewards", game, "elite", &"")
	var second: Dictionary = Sim.call("mythic_rewards", game, "elite", &"")
	_check(fails, first["eligible"] == true and first["rate"] == 1.0 and not str(first["offer"]).is_empty(),
		"eligible attempts must be recorded before a successful roll closes the slot")
	_check(fails, second["eligible"] == false and str(second["offer"]).is_empty(),
		"a spent slot must not count as another eligible attempt")
	_check(fails, str(first["offer"]) != "unbrokenFlame", "pre-clear pool offered The Unbroken Flame")
	game.cb.embers = game.cb.ember_cap + 1
	game.cb.player.hp = -1
	game.cb.hand.clear()
	for i: int in range(11):
		game.cb.hand.append(CardInst.new(i + 1, &"strike", false))
	var faults: PackedStringArray = Sim.call("mythic_invariants", game)
	_check(fails, faults.size() >= 3, "the structural monitor ignored Ember, hand or HP overflow")
	RewardRules.mythics_live = live

static func _replay(content: ContentDB, fails: Array[String]) -> void:
	var before: bool = RewardRules.mythics_live
	var args: Array = [content, "duskblade", 9000, 3, PackedStringArray(), {}, false, false,
		{}, null, false, "mature", "greedy", Pilot.VERSION, "s1", "control"]
	# Keep the selected search instrument exactly as the simulator's default.
	args[14] = Sim._options(PackedStringArray())["search"]
	var first: Dictionary = Sim.callv("simulate", args)
	var second: Dictionary = Sim.callv("simulate", args)
	_check(fails, Sim.outcome_digest(first) == Sim.outcome_digest(second), "study seed replay changed digest")
	_check(fails, first["mythicStudy"]["violations"].is_empty(), "control read broke structural invariants")
	_check(fails, RewardRules.mythics_live == before, "a research read leaked its O6 override")
