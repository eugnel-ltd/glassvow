extends RefCounted
## Flame readout 10's flame-aware adaptive arm, A_lit
## (docs/design/2026-09-29-dusk-flame/readouts/readout-10.md): an adaptive build
## that reads its own lantern before each build decision. While the lantern burns
## a way's colour, Steady or True, it values that way's glass `litLean` times and
## other coloured glass `litOff` times, and a rider lit by that way counts in
## full; at Kindling or Soot it chooses as arm A does. Arm A never reads it.

const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const LIT_POLICY: Dictionary = {"litLean": Pilot.LIT_LEAN, "litOff": Pilot.LIT_OFF}
## Clear glass with Splinter Cut's own definition: the same catalogue score, no way.
const TWIN: String = "adaptiveLitClearTwin"
## Two Splinter Cuts beside the starters read Steady Edge.
const STEADY: Array = ["splinterCut", "splinterCut"]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	content.cards[TWIN] = content.cards["splinterCut"].duplicate(true)
	_sees_the_flame(content, fails)
	_leans_on_the_lit_way(content, fails)
	_riders_count_in_full(content, fails)
	_arm_a_is_untouched(content, fails)
	_simulator_arm(fails)
	Pilot.apply_policy({})


## Starters, plus `extra`: the starters alone read Kindling, two Splinter Cuts
## read Steady Edge, two of each way read Soot.
static func _run(content: ContentDB, extra: Array) -> RunState:
	var run_state: RunState = RunState.new_run(content, 61000, "adaptive-lit", {"aspect": 0})
	for id: String in extra:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
	return run_state


static func _decks() -> Dictionary:
	return {"KINDLING": [], "STEADY": STEADY,
		"SOOT": ["splinterCut", "splinterCut", "spall", "spall", "hearthfall", "hearthfall"]}


static func _sees_the_flame(content: ContentDB, fails: Array[String]) -> void:
	var decks: Dictionary = _decks()
	var expected: Dictionary = {"KINDLING": "", "STEADY": "edge", "SOOT": ""}
	for tier: String in decks:
		var deck: Array = decks[tier]
		var run_state: RunState = _run(content, deck)
		if str(Flame.read(content, run_state)["tier"]) != tier:
			fails.append("A_lit: the %s deck must read %s" % [decks[tier], tier])
		Pilot.apply_policy(LIT_POLICY)
		Pilot.see_flame(content, run_state)
		if Pilot.lit != str(expected[tier]):
			fails.append("A_lit: at %s it must see the lit way '%s', saw '%s'" % [tier, expected[tier], Pilot.lit])


## An Edge card against clear glass of equal catalogue score, the clear card
## offered first (a tie keeps the first): Steady Edge takes the Edge card; at
## Kindling and Soot A_lit takes what A takes, with A's every build score.
static func _leans_on_the_lit_way(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	if Pilot.catalogue_card_score(content, 0, TWIN) != Pilot.catalogue_card_score(content, 0, "splinterCut") \
			or not Flame.card_affinity(content, 0, TWIN).is_empty():
		fails.append("A_lit: the clear twin must score as Splinter Cut and carry no way")
	var offer: Array = [TWIN, "splinterCut"]
	var arm_a: String = Pilot.choose_card(offer, content, 0)
	if arm_a != TWIN:
		fails.append("A_lit: arm A must keep the first of two equal cards, took %s" % arm_a)
	var decks: Dictionary = _decks()
	var expected: Dictionary = {"KINDLING": TWIN, "STEADY": "splinterCut", "SOOT": TWIN}
	for tier: String in decks:
		Pilot.apply_policy(LIT_POLICY)
		var deck: Array = decks[tier]
		Pilot.see_flame(content, _run(content, deck))
		var taken: String = Pilot.choose_card(offer, content, 0)
		if taken != str(expected[tier]):
			fails.append("A_lit: at %s it must take %s, took %s" % [tier, expected[tier], taken])
		if tier != "STEADY":
			for id: String in ["strike", "splinterCut", "spall", "hearthfall", "chisel", TWIN]:
				for up: bool in [false, true]:
					if Pilot.build_card_score(content, 0, id, up) != Pilot.catalogue_card_score(content, 0, id, up):
						fails.append("A_lit: at %s %s must keep arm A's score" % [tier, id])
	Pilot.apply_policy(LIT_POLICY)
	Pilot.see_flame(content, _run(content, STEADY))
	# Under a blood-moon lantern: Edge glass leans in, other ways' glass leans
	# out, clear glass keeps its score.
	var scaled: Dictionary = {"strike": 1.0, "spall": Pilot.LIT_OFF, "hearthfall": Pilot.LIT_OFF}
	for id: String in scaled:
		var factor: float = scaled[id]
		var scaled_score: float = Pilot.build_card_score(content, 0, id)
		var base: float = Pilot.catalogue_card_score(content, 0, id)
		if not is_equal_approx(scaled_score, base * factor):
			fails.append("A_lit: Steady Edge must scale %s by %s" % [id, factor])


## A rider lit by the lantern's way counts in full; a rider of another way
## still counts at `crackedShare`, as arm A counts every rider.
static func _riders_count_in_full(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	var cut: Dictionary = content.cards["splinterCut"]
	var share: float = Pilot._w("special", "crackedShare")
	var ward: float = 3.0 * Pilot._w("card", "blockHeal")
	var full: float = Pilot.card_score(cut, 0, "splinterCut", "edge")
	var shared: float = Pilot.card_score(cut, 0, "splinterCut")
	if not is_equal_approx(full - shared, ward * (1.0 - share)):
		fails.append("A_lit: Splinter Cut's lit Ward must count in full under Edge")
	if Pilot.card_score(cut, 0, "splinterCut", "shatter") != Pilot.card_score(cut, 0, "splinterCut"):
		fails.append("A_lit: Splinter Cut's Edge rider must keep its share under Shatter")
	Pilot.apply_policy(LIT_POLICY)
	Pilot.see_flame(content, _run(content, STEADY))
	var leaned: float = Pilot.build_card_score(content, 0, "splinterCut")
	if not is_equal_approx(leaned, full * Pilot.LIT_LEAN):
		fails.append("A_lit: Steady Edge must score Splinter Cut with its rider in full, times litLean")


## Arm A has no `litLean`: it never sees the flame, so even a Steady deck keeps
## every build score and the seed-1000 digest of tests/test_balance_sim.gd.
static func _arm_a_is_untouched(content: ContentDB, fails: Array[String]) -> void:
	Pilot.apply_policy({})
	Pilot.see_flame(content, _run(content, STEADY))
	if not Pilot.lit.is_empty() or Pilot.build_card_score(content, 0, "splinterCut") \
			!= Pilot.catalogue_card_score(content, 0, "splinterCut"):
		fails.append("A_lit: arm A must never see the flame")
	if Pilot.policy_snapshot().has("litLean"):
		fails.append("A_lit: the default policy must not carry litLean")
	Pilot.apply_policy({"way": "edge", "litLean": 2.0})
	Pilot.see_flame(content, _run(content, STEADY))
	if not Pilot.lit.is_empty():
		fails.append("A_lit: a committed arm must never see the flame")


## `--build=lit` is the arm: its policy carries the lean, it takes no way, and
## its run replays.
static func _simulator_arm(fails: Array[String]) -> void:
	var opts: Dictionary = Sim._options(PackedStringArray(["--build=lit"]))
	var policy: Dictionary = Sim._policy(opts)
	if opts.has("error") or not is_equal_approx(float(str(policy.get("litLean", 0))), Pilot.LIT_LEAN) \
			or not is_equal_approx(float(str(policy.get("litOff", 0))), Pilot.LIT_OFF):
		fails.append("A_lit: --build=lit must carry litLean and litOff, got %s" % policy)
	if Sim._policy(Sim._options(PackedStringArray())).has("litLean"):
		fails.append("A_lit: the adaptive build must carry no litLean")
	if not Sim._options(PackedStringArray(["--build=lit", "--way=edge"])).has("error"):
		fails.append("A_lit: --build=lit must refuse a committed way")
	var content: ContentDB = ContentDB.load_full(false)
	var first: Dictionary = Sim.simulate(content, "duskblade", 12003, 0, PackedStringArray(), policy)
	var second: Dictionary = Sim.simulate(content, "duskblade", 12003, 0, PackedStringArray(), policy)
	if Sim.outcome_digest(first) != Sim.outcome_digest(second):
		fails.append("A_lit: a run must replay")
