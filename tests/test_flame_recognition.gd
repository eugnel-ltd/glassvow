extends RefCounted
## Flame lock §7, recognition at the boss (docs/design/2026-09-29-dusk-flame):
## the crown table by tier, dominant way and fringe; held crowns and their
## alternates. The boss relics are drawn as they always were, whatever the
## flame: the crowns take their slots and the draws that are not a placed crown
## fill the rest in drawn order, so a flame change moves only the slots the rule
## names and never the run's cursor. The harness (`_case`) takes the aspect: the
## Ashwarden's own table, on its own ways and crowns, is test_ash_flame.gd's
## (#544 A2).

const SEEDS: int = 60

## [label, starters removed, cards added, relics held, tier, slot-1 crown, slot-2 crown]
const TABLE: Array = [
	["start", [], [], [], "KINDLING", "", ""],
	["too little glass", ["eclipseSlash", "firstSpark"], [], [], "KINDLING", "", ""],
	["kindling with a fringe", [], ["uppercut", "quakeblow", "warCry"], [], "KINDLING", "", ""],
	["steady shatter", [], ["uppercut", "quakeblow"], [], "STEADY", "shatterersCrown", ""],
	["steady shatter, edge fringe", [],
		["uppercut", "quakeblow", "warCry", "oblivionStrike", "limitBreak"], [],
		"STEADY", "shatterersCrown", "crownOfTheEclipse"],
	["true shatter", ["eclipseSlash", "firstSpark"],
		["uppercut", "quakeblow", "warCry", "oblivionStrike", "limitBreak"], [],
		"TRUE", "shatterersCrown", ""],
	["steady lantern, shatter fringe", ["eclipseSlash"],
		["preparation", "surge", "devour", "uppercut"], [],
		"STEADY", "crownOfCinders", "shatterersCrown"],
	["true lantern", ["chisel", "eclipseSlash"], ["preparation", "surge", "devour", "offering"], [],
		"TRUE", "crownOfCinders", ""],
	["steady edge, lantern fringe", ["chisel"], ["warCry", "cleft", "executioner", "preparation"],
		[], "STEADY", "crownOfTheEclipse", "crownOfCinders"],
	["true edge", ["chisel", "firstSpark"], ["warCry", "cleft", "executioner", "totality"], [],
		"TRUE", "crownOfTheEclipse", ""],
	["soot", [], ["uppercut", "preparation", "warCry"], [], "SOOT", "hollowCrown", ""],
	# Held crowns: crownOf walks the alternates; a slot with none left draws.
	["true lantern, cinders held", ["chisel", "eclipseSlash"],
		["preparation", "surge", "devour", "offering"], ["crownOfCinders"],
		"TRUE", "crownOfTheHearth", ""],
	["true lantern, cinders and hearth held", ["chisel", "eclipseSlash"],
		["preparation", "surge", "devour", "offering"], ["crownOfCinders", "crownOfTheHearth"],
		"TRUE", "crownOfTithes", ""],
	["true lantern, every lantern crown held", ["chisel", "eclipseSlash"],
		["preparation", "surge", "devour", "offering"],
		["crownOfCinders", "crownOfTheHearth", "crownOfTithes"], "TRUE", "", ""],
	["steady shatter, its crown held", [], ["uppercut", "quakeblow"], ["shatterersCrown"],
		"STEADY", "", ""],
	["true edge, its crown held", ["chisel", "firstSpark"],
		["warCry", "cleft", "executioner", "totality"], ["crownOfTheEclipse"], "TRUE", "", ""],
	["soot, the hollow crown held", [], ["uppercut", "preparation", "warCry"], ["hollowCrown"],
		"SOOT", "", ""],
	# The next act, same rule: a hybrid that took Cinders is offered the Hearth
	# and still its fringe's crown; one that took the fringe's crown is not.
	["act 2 hybrid, cinders taken", ["eclipseSlash"], ["preparation", "surge", "devour", "uppercut"],
		["crownOfCinders"], "STEADY", "crownOfTheHearth", "shatterersCrown"],
	["act 2 hybrid, fringe crown taken", ["eclipseSlash"],
		["preparation", "surge", "devour", "uppercut"], ["shatterersCrown"],
		"STEADY", "crownOfCinders", ""],
	# A thin boss pool: the crowns still lead, the offer only shrinks.
	["two left, soot", [], ["uppercut", "preparation", "warCry"],
		["crownOfCinders", "crownOfTheHearth", "crownOfTithes", "crownOfTheEclipse"],
		"SOOT", "hollowCrown", ""],
	["one left, the fringe crown", ["chisel"], ["warCry", "cleft", "executioner", "preparation"],
		["hollowCrown", "crownOfTheHearth", "crownOfTithes", "shatterersCrown", "crownOfTheEclipse"],
		"STEADY", "", "crownOfCinders"],
	["none left", [], ["uppercut", "quakeblow"],
		["crownOfCinders", "hollowCrown", "crownOfTithes", "shatterersCrown", "crownOfTheHearth",
			"crownOfTheEclipse"],
		"STEADY", "", ""],
]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rules: RewardRules = RewardRules.new(content)
	for row_v: Variant in TABLE:
		_case(content, rules, row_v, fails)


static func _dusk(content: ContentDB, seed: int, row: Array, aspect: int = 0) -> RunState:
	var run_state: RunState = RunState.new_run(content, 8000 + seed, "crown-%d" % seed,
		{"aspect": aspect})
	for id_v: Variant in row[1]:
		for card: CardInst in run_state.player.deck:
			if String(card.id) == str(id_v):
				run_state.player.deck.erase(card)
				break
	for id_v: Variant in row[2]:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	for id_v: Variant in row[3]:
		run_state.player.relics.append(str(id_v))
	return run_state


## The boss draw as it always stood: distinct relics from the offerable boss
## pool, three at most, on the run's cursor.
static func _drawn(rules: RewardRules, run_state: RunState) -> Array[String]:
	var available: Array[String] = []
	for id_v: Variant in rules.offer_relics(run_state, "boss"):
		if not run_state.player.relics.has(str(id_v)):
			available.append(str(id_v))
	var out: Array[String] = []
	while out.size() < mini(3, available.size()):
		var id: String = available[run_state.rng.pick_index(available.size())]
		if not out.has(id):
			out.append(id)
	return out


static func _case(content: ContentDB, rules: RewardRules, row_v: Variant, fails: Array[String],
		aspect: int = 0) -> void:
	var row: Array = row_v
	var label: String = str(row[0])
	var tier: String = str(Flame.read(content, _dusk(content, 0, row, aspect))["tier"])
	if tier != str(row[4]):
		fails.append("recognition %s: the deck reads %s, not %s" % [label, tier, row[4]])
		return
	var crowns: Array[String] = [str(row[5]), str(row[6])]
	var held: Array = row[3]
	for seed: int in range(SEEDS):
		var twin: RunState = _dusk(content, seed, row, aspect)
		var drawn: Array[String] = _drawn(rules, twin)
		var run_state: RunState = _dusk(content, seed, row, aspect)
		var offer: Array[String] = rules.roll_boss_relics(run_state)
		var problem: String = _judge(offer, drawn, crowns, held)
		if problem.is_empty() and run_state.rng_state() != twin.rng_state():
			problem = "the draws moved with the flame"
		if problem.is_empty() and rules.roll_boss_relics(_dusk(content, seed, row, aspect)) != offer:
			problem = "a replay of the seed offered differently"
		if not problem.is_empty():
			fails.append("recognition %s seed %d: %s (offer %s, drawn %s)"
				% [label, seed, problem, offer, drawn])
			return


## The rule, slot by slot: a crown the table names leads its slot (while the
## offer has that slot); every other slot is the next draw that is not a placed
## crown; nothing held and nothing twice.
static func _judge(offer: Array[String], drawn: Array[String], crowns: Array[String],
		held: Array) -> String:
	if offer.size() != drawn.size():
		return "the offer holds %d relics, not %d" % [offer.size(), drawn.size()]
	var placed: Array[String] = []
	for slot: int in range(mini(crowns.size(), offer.size())):
		if not crowns[slot].is_empty():
			placed.append(crowns[slot])
			if offer[slot] != crowns[slot]:
				return "slot %d is not %s" % [slot + 1, crowns[slot]]
	var rest: Array[String] = []
	for id: String in drawn:
		if not placed.has(id):
			rest.append(id)
	var filled: Array[String] = []
	for slot: int in range(offer.size()):
		if slot >= crowns.size() or crowns[slot].is_empty():
			filled.append(offer[slot])
	var expected: Array[String] = rest.duplicate()
	expected.resize(filled.size())
	if filled != expected:
		return "the drawn slots are %s, not the draws %s" % [filled, rest]
	for slot: int in range(offer.size()):
		if held.has(offer[slot]) or offer.find(offer[slot]) != slot:
			return "%s is held or offered twice" % offer[slot]
	return ""
