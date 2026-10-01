extends RefCounted
## Flame readout 9 (docs/design/2026-09-29-dusk-flame/readouts/readout-9.md):
## each way's payoff that only a committed deck collects. A card effect marked
## `lit` with a way's id resolves only while the lantern burns that way's colour,
## Steady or True, as the fight began (`CombatState.lit_way`, set once from the
## flame read at combat start). The rest of the card always resolves.

const Search: GDScript = preload("res://tools/balance_search.gd")
const HP: int = 200
## The shipped riders: card id -> [way, effect kind, amount]. Every `lit` effect
## in the catalogue is one of these, on the card and on its upgrade alike.
const RIDERS: Dictionary = {
	"eclipseSlash": ["edge", "block", 3],
	"splinterCut": ["edge", "block", 3],
	"dimTheGlass": ["edge", "block", 3],
	"warCry": ["edge", "block", 3],
	"chisel": ["shatter", "chip", 1],
	"spall": ["shatter", "chip", 1],
	"quakeblow": ["shatter", "chip", 1],
	"preparation": ["lantern", "ember", 1],
	"surge": ["lantern", "ember", 1],
	"hearthfall": ["lantern", "ember", 1],
	"tithe": ["lantern", "ember", 1],
}
## Two of these beside the starters read Steady in that way (3 of 5 coloured).
const LIGHTER: Dictionary = {"edge": "splinterCut", "shatter": "spall", "lantern": "hearthfall"}


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_lit_way(content, fails)
	_catalogue(content, fails)
	_riders(content, fails)
	_preview(content, fails)
	_validation(fails)
	_copy(content, fails)
	_search_copy(content, fails)


## A Duskblade fight against one foe at 200 HP with no Ward, no statuses and a
## facet gauge too deep to shatter; `extra` joins the starter deck before the
## combat starts, so the flame read at the start is that deck's.
static func _fight(content: ContentDB, tag: String, extra: Array) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 60900, "lit-%s" % tag, {"aspect": 0})
	for id: String in extra:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
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
	game.cb.player.block = 0
	game.cb.player.energy = 3
	game.cb.embers = 3
	# The Steady lantern's first-gain bonus is spent, so a rider's Ember is its own.
	game.cb.first_gain_turn = game.cb.turn
	return game


static func _n(value: Variant) -> int:
	return int(float(str(value)))


static func _lit(way: String) -> Array:
	return [LIGHTER[way], LIGHTER[way]] if not way.is_empty() else []


## The lit way follows the deck as the fight begins: none at Kindling (the
## starters alone) or Soot (two of each way), the way itself at Steady or True.
static func _lit_way(content: ContentDB, fails: Array[String]) -> void:
	var cases: Array = [
		["", []],
		["edge", ["splinterCut", "splinterCut"]],
		["shatter", ["spall", "spall"]],
		["lantern", ["hearthfall", "hearthfall"]],
		["edge", ["splinterCut", "splinterCut", "splinterCut", "splinterCut", "splinterCut",
			"splinterCut", "splinterCut", "splinterCut", "splinterCut"]],
		["", ["splinterCut", "splinterCut", "spall", "spall", "hearthfall", "hearthfall"]],
	]
	for i: int in range(cases.size()):
		var case: Array = cases[i]
		var deck: Array = case[1]
		var game: GlassvowGame = _fight(content, "way-%d" % i, deck)
		var tier: String = str(Flame.read(content, game.run)["tier"])
		if game.cb.lit_way != str(case[0]):
			fails.append("Lit way: a deck of starters + %s reads %s, expected lit way '%s', got '%s'"
				% [deck, tier, case[0], game.cb.lit_way])


## Every `lit` effect in the catalogue is a shipped rider, and every shipped
## rider is on its card and on the card's upgrade.
static func _catalogue(content: ContentDB, fails: Array[String]) -> void:
	var seen: Dictionary = {}
	for id_v: Variant in content.cards:
		var id: String = str(id_v)
		var definition: Dictionary = content.cards[id]
		var faces: Array = [definition]
		var up: Dictionary = definition.get("up", {})
		if up.has("effects"):
			faces.append(up)
		for face: Dictionary in faces:
			for fx_v: Variant in face.get("effects", []):
				var fx: Dictionary = fx_v
				if not fx.has("lit"):
					continue
				var expected: Array = RIDERS.get(id, [])
				if expected.is_empty() or [str(fx["lit"]), str(fx["kind"]), _n(fx["n"])] != expected:
					fails.append("Lit catalogue: unexpected rider on %s: %s" % [id, fx])
				seen[id] = _n(seen.get(id, 0)) + 1
	for id: String in RIDERS:
		var faces: int = 2 if content.cards[id].get("up", {}).has("effects") else 1
		if _n(seen.get(id, 0)) != faces:
			fails.append("Lit catalogue: %s carries its rider on %d of %d faces"
				% [id, _n(seen.get(id, 0)), faces])
		if Flame.card_affinity(content, 0, id).get(RIDERS[id][0], 0.0) != 1.0:
			fails.append("Lit catalogue: %s is not %s glass" % [id, RIDERS[id][0]])


## What a play leaves behind, for comparing a lit fight with an unlit one.
static func _after(content: ContentDB, tag: String, deck: Array, id: String, up: bool) -> Dictionary:
	var game: GlassvowGame = _fight(content, tag, deck)
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), up)
	game.cb.hand.append(card)
	var target: Variant = 0 if str(game.rules.card_data(card).get("target", "")) == "enemy" else null
	game.apply({"t": "playCard", "uid": card.uid, "target": target})
	var foe: EnemyCombatant = game.cb.enemies[0]
	return {"ok": game.last_ret == true, "block": game.cb.player.block, "chip": foe.chips,
		"ember": game.cb.embers, "hp": foe.hp, "energy": game.cb.player.energy,
		"cracked": _n(foe.statuses.get("vulnerable", 0)), "dimmed": _n(foe.statuses.get("weak", 0))}


## Each rider, played in a lantern lit by its own way, by another way and by
## none: only its own way's colour adds the rider, and nothing else changes.
static func _riders(content: ContentDB, fails: Array[String]) -> void:
	for id: String in RIDERS:
		var way: String = RIDERS[id][0]
		var kind: String = RIDERS[id][1]
		var other: String = "shatter" if way != "shatter" else "edge"
		for up: bool in [false, true]:
			var tag: String = "%s-%s" % [id, up]
			var plain: Dictionary = _after(content, tag + "-plain", [], id, up)
			var own: Dictionary = _after(content, tag + "-own", _lit(way), id, up)
			var foreign: Dictionary = _after(content, tag + "-other", _lit(other), id, up)
			if not plain["ok"] or not own["ok"] or not foreign["ok"]:
				fails.append("Lit riders: %s (up %s) could not be played" % [id, up])
				continue
			var gained: Dictionary = own.duplicate()
			gained[kind] = _n(gained[kind]) - _n(RIDERS[id][2])
			if gained != plain:
				fails.append("Lit riders: %s (up %s) in its own colour should add %d %s and nothing else: %s against %s"
					% [id, up, RIDERS[id][2], kind, own, plain])
			if foreign != plain:
				fails.append("Lit riders: %s (up %s) in a %s lantern should resolve as unlit: %s against %s"
					% [id, up, other, foreign, plain])


## The preview the pilot and the HUD read counts a lit Ward only in its colour.
static func _preview(content: ContentDB, fails: Array[String]) -> void:
	for deck: Array in [[], _lit("edge")]:
		var game: GlassvowGame = _fight(content, "preview-%d" % deck.size(), deck)
		var card: CardInst = CardInst.new(game.run.next_uid(), &"splinterCut", false)
		var preview: Dictionary = game.rules.preview_play(game.cb, card, 0, game.run)
		var expected: int = 3 if not deck.is_empty() else 0
		if _n(preview.get("block", -1)) != expected:
			fails.append("Lit preview: Splinter Cut previews %s Ward with lit way '%s', expected %d"
				% [preview.get("block"), game.cb.lit_way, expected])


## A `lit` effect must name a way some aspect declares.
static func _validation(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var spall: Dictionary = content.cards["spall"]
	var effects: Array = spall["effects"]
	effects.append({"kind": "block", "n": 1, "lit": "ember"})
	var faults: Array[String] = []
	content.validate(faults)
	if not faults.any(func(f: String) -> bool: return f.contains("lit by ember")):
		fails.append("Lit validation: a rider lit by an unknown way passed validation: %s" % [faults])


## Each rider's card is authored in both catalogues, and the English matches content.
static func _copy(content: ContentDB, fails: Array[String]) -> void:
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	var mark: Dictionary = {"edge": ["Blood-moon flame:", "血月之火："],
		"shatter": ["Frost-white flame:", "霜白之火："], "lantern": ["Amber flame:", "金黃之火："]}
	for id: String in RIDERS:
		var leaves: Array[String] = ["text"]
		if content.cards[id].get("up", {}).has("text"):
			leaves.append("textUp")
		for leaf: String in leaves:
			var key: String = "content.cards.%s.%s" % [id, leaf]
			var words: Array = mark[RIDERS[id][0]]
			if not en.t(key).contains(str(words[0])) or not zh.t(key).contains(str(words[1])):
				fails.append("Lit copy: %s does not name its flame in both catalogues (%s / %s)"
					% [key, en.t(key), zh.t(key)])
		if en.t("content.cards.%s.text" % id) != str(content.cards[id]["text"]):
			fails.append("Lit copy: the English catalogue and content disagree on %s" % id)


## The search player's copy of a fight keeps its lit way, so it plans the riders
## the live fight will resolve.
static func _search_copy(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "search", _lit("lantern"))
	var copy: CombatState = Search.clone_combat(game.cb)
	if copy.lit_way != "lantern" or game.cb.lit_way != "lantern":
		fails.append("Lit search: the search player's copy lost the lit way (%s / %s)"
			% [copy.lit_way, game.cb.lit_way])
