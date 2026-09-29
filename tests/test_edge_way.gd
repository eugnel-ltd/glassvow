extends RefCounted
## Flame lock PR 6 (docs/design/2026-09-29-dusk-flame, §6.2 and §6.3): the Edge
## way's seven cards through the combat rules, the Crown of the Eclipse, the
## deed Fault in the Glass, pool membership per wave and per aspect, the Edge
## affinity data and the copy in both catalogues. tests/test_pool_hygiene.gd
## sweeps the actual offers (rewards, shops, events, boss and random relics).

const CARDS: Array[String] = [
	"splinterCut", "dimTheGlass", "cleft", "eclipseStep", "tremor", "totality", "emberEye",
]
const CROWN: String = "crownOfTheEclipse"
const DEED: String = "faultInGlass"
const HP: int = 200


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_splinter_cut(content, fails)
	_dim_the_glass(content, fails)
	_cleft(content, fails)
	_eclipse_step(content, fails)
	_tremor(content, fails)
	_totality(content, fails)
	_ember_eye(content, fails)
	_crown(content, fails)
	_only_the_player_cracks_enemies(fails)
	_deed(content, fails)
	_pools(content, fails)
	_affinity(content, fails)
	_copy(fails)


## A seeded Duskblade fight with every foe at 200 HP, no Ward, no statuses and
## a facet gauge too deep to shatter, so each number below is the card's alone.
static func _fight(content: ContentDB, tag: String, foes: int = 1) -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 60600, "edge-%s" % tag, {"aspect": 0})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	var ids: Array = []
	for _i: int in range(foes):
		ids.append("sporeling")
	game.apply({"t": "startCombat", "enemies": ids, "kind": "normal"})
	for foe: EnemyCombatant in game.cb.enemies:
		foe.max_hp = HP
		foe.hp = HP
		foe.block = 0
		foe.statuses.clear()
		foe.facet_max = 99
		foe.move_key = &"spit"
	game.cb.player.statuses.clear()
	return game


## Play a fresh copy of `id` from the hand; true when the rules accepted it.
static func _play(game: GlassvowGame, id: String, target: Variant, up: bool = false) -> bool:
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), up)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	game.apply({"t": "playCard", "uid": card.uid, "target": target})
	return game.last_ret == true


static func _status(statuses: Dictionary, id: String) -> int:
	return int(float(str(statuses.get(id, 0))))


static func _stat(game: GlassvowGame, key: String) -> int:
	return int(float(str(game.run.stats.get(key, 0))))


static func _splinter_cut(content: ContentDB, fails: Array[String]) -> void:
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "splinter-%s" % up)
		var foe: EnemyCombatant = game.cb.enemies[0]
		_play(game, "splinterCut", 0, up)
		var damage: int = 7 if up else 5
		var cracked: int = 2 if up else 1
		if HP - foe.hp != damage or _status(foe.statuses, "vulnerable") != cracked \
				or _stat(game, "cracked") != cracked:
			fails.append("Splinter Cut (up %s): expected %d damage and %d Cracked, got %d and %d"
				% [up, damage, cracked, HP - foe.hp, _status(foe.statuses, "vulnerable")])


static func _dim_the_glass(content: ContentDB, fails: Array[String]) -> void:
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "dim-%s" % up)
		var foe: EnemyCombatant = game.cb.enemies[0]
		var hand: int = game.cb.hand.size()
		game.cb.player.energy = 3
		var card: CardInst = CardInst.new(game.run.next_uid(), &"dimTheGlass", up)
		game.cb.hand.append(card)
		game.apply({"t": "playCard", "uid": card.uid, "target": 0})
		var spent: int = 3 - game.cb.player.energy
		if _status(foe.statuses, "weak") != 2 or game.cb.hand.size() != hand + 1 \
				or spent != (0 if up else 1):
			fails.append("Dim the Glass (up %s): expected 2 Dimmed, a card drawn, %d Energy; got %d, hand %d -> %d, %d"
				% [up, 0 if up else 1, _status(foe.statuses, "weak"), hand,
					game.cb.hand.size(), spent])


## The target is read as the card strikes: a Cracked foe takes the hit at x1.5,
## one more Cracked and gives the hand 1 Fervor, even if the hit kills it.
static func _cleft(content: ContentDB, fails: Array[String]) -> void:
	var clean: GlassvowGame = _fight(content, "cleft-clean")
	_play(clean, "cleft", 0)
	var foe: EnemyCombatant = clean.cb.enemies[0]
	if HP - foe.hp != 8 or _status(foe.statuses, "vulnerable") != 0 \
			or _status(clean.cb.player.statuses, "str") != 0:
		fails.append("Cleft on clean glass: expected 8 damage and nothing more, got %d, %s, %s"
			% [HP - foe.hp, foe.statuses, clean.cb.player.statuses])
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "cleft-cracked-%s" % up)
		var target: EnemyCombatant = game.cb.enemies[0]
		game.rules.add_status_enemy(game.cb, target, "vulnerable", 1)
		_play(game, "cleft", 0, up)
		var damage: int = 16 if up else 12
		if HP - target.hp != damage or _status(target.statuses, "vulnerable") != 2 \
				or _status(game.cb.player.statuses, "str") != 1 or _stat(game, "cracked") != 1:
			fails.append("Cleft (up %s) on Cracked glass: expected %d damage, 2 Cracked, 1 Fervor; got %d, %s, %s"
				% [up, damage, HP - target.hp, target.statuses, game.cb.player.statuses])
	var kill: GlassvowGame = _fight(content, "cleft-kill", 2)
	var doomed: EnemyCombatant = kill.cb.enemies[0]
	doomed.hp = 5
	kill.rules.add_status_enemy(kill.cb, doomed, "vulnerable", 1)
	_play(kill, "cleft", 0)
	if doomed.hp > 0 or kill.cb.over or _status(kill.cb.player.statuses, "str") != 1 \
			or not doomed.statuses.is_empty():
		fails.append("Cleft killing Cracked glass: expected the kill and 1 Fervor, got hp %d, %s"
			% [doomed.hp, kill.cb.player.statuses])


## The enemy about to strike you is the first living, unstaggered foe whose
## intent deals damage; with none, only the Ward lands.
static func _eclipse_step(content: ContentDB, fails: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"label": "first attacker", "moves": [&"grow", &"spit", &"spit"], "stagger": -1, "hit": 1},
		{"label": "staggered attacker", "moves": [&"grow", &"spit", &"spit"], "stagger": 1, "hit": 2},
		{"label": "no attacker", "moves": [&"grow", &"grow", &"grow"], "stagger": -1, "hit": -1},
	]
	for case: Dictionary in cases:
		var game: GlassvowGame = _fight(content, "step-%s" % case["label"], 3)
		var moves: Array = case["moves"]
		for i: int in range(3):
			game.cb.enemies[i].move_key = moves[i]
		var stagger: int = case["stagger"]
		if stagger >= 0:
			game.cb.enemies[stagger].staggered = true
		_play(game, "eclipseStep", null)
		var cracked: Array[int] = []
		for foe: EnemyCombatant in game.cb.enemies:
			cracked.append(_status(foe.statuses, "vulnerable"))
		var hit: int = case["hit"]
		var ok: bool = game.cb.player.block == 5 and _stat(game, "cracked") == (1 if hit >= 0 else 0)
		for i: int in range(3):
			ok = ok and cracked[i] == (1 if i == hit else 0)
		if not ok:
			fails.append("Eclipse Step (%s): expected 5 Ward and Cracked on foe %d, got %d Ward and %s"
				% [case["label"], hit, game.cb.player.block, cracked])
	var upgraded: GlassvowGame = _fight(content, "step-up")
	_play(upgraded, "eclipseStep", null, true)
	if upgraded.cb.player.block != 8 or _status(upgraded.cb.enemies[0].statuses, "vulnerable") != 1:
		fails.append("Eclipse Step+: expected 8 Ward and 1 Cracked, got %d and %s"
			% [upgraded.cb.player.block, upgraded.cb.enemies[0].statuses])


## Three hits, each reading Cracked for itself; Faultline, the card whose
## special Tremor shares, keeps its single hit.
static func _tremor(content: ContentDB, fails: Array[String]) -> void:
	var rows: Array[Dictionary] = [
		{"id": "tremor", "up": false, "cracked": false, "damage": 9, "hits": 3},
		{"id": "tremor", "up": false, "cracked": true, "damage": 21, "hits": 3},
		{"id": "tremor", "up": true, "cracked": false, "damage": 12, "hits": 3},
		{"id": "tremor", "up": true, "cracked": true, "damage": 27, "hits": 3},
		{"id": "executioner", "up": false, "cracked": false, "damage": 8, "hits": 1},
		{"id": "executioner", "up": false, "cracked": true, "damage": 21, "hits": 1},
	]
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var id: String = str(row["id"])
		var up: bool = row["up"]
		var game: GlassvowGame = _fight(content, "tremor-%d" % i)
		var foe: EnemyCombatant = game.cb.enemies[0]
		if row["cracked"]:
			game.rules.add_status_enemy(game.cb, foe, "vulnerable", 1)
		var start: int = game.cb.queue.size()
		_play(game, id, 0, up)
		var hits: int = 0
		for k: int in range(start, game.cb.queue.size()):
			if game.cb.queue[k].get("t") == EventTypes.HIT_ENEMY:
				hits += 1
		var preview: Variant = game.rules.preview_play(game.cb,
			CardInst.new(0, StringName(id), up), 0, game.run)
		var total: int = int(float(str(preview.get("total", -1)))) \
			if typeof(preview) == TYPE_DICTIONARY else -1
		if HP - foe.hp != row["damage"] or hits != row["hits"] or total != row["damage"]:
			fails.append("%s: expected %d damage in %d hits (preview too), got %d in %d, preview %d"
				% [row, row["damage"], row["hits"], HP - foe.hp, hits, total])


## The hit lands first (x1.5 on Cracked glass), then the Cracked doubles; the
## doubling is Cracked the player applies.
static func _totality(content: ContentDB, fails: Array[String]) -> void:
	for up: bool in [false, true]:
		var base: int = 18 if up else 14
		var clean: GlassvowGame = _fight(content, "totality-clean-%s" % up)
		_play(clean, "totality", 0, up)
		var bare: EnemyCombatant = clean.cb.enemies[0]
		if HP - bare.hp != base or _status(bare.statuses, "vulnerable") != 0:
			fails.append("Totality (up %s) on clean glass: expected %d damage and no Cracked, got %d, %s"
				% [up, base, HP - bare.hp, bare.statuses])
		var game: GlassvowGame = _fight(content, "totality-cracked-%s" % up)
		var foe: EnemyCombatant = game.cb.enemies[0]
		game.rules.add_status_enemy(game.cb, foe, "vulnerable", 2)
		_play(game, "totality", 0, up)
		var damage: int = int(floorf(float(base) * 1.5))
		if HP - foe.hp != damage or _status(foe.statuses, "vulnerable") != 4 \
				or _stat(game, "cracked") != 2:
			fails.append("Totality (up %s) on 2 Cracked: expected %d damage, then 4 Cracked; got %d, %s"
				% [up, damage, HP - foe.hp, foe.statuses])


## Two Embers are the price: fewer and the card cannot be played, as the Art
## cannot. Paid, it cracks every foe and burns (Kindle gives one Ember back).
static func _ember_eye(content: ContentDB, fails: Array[String]) -> void:
	var poor: GlassvowGame = _fight(content, "eye-poor", 2)
	poor.cb.embers = 1
	var card: CardInst = CardInst.new(poor.run.next_uid(), &"emberEye", false)
	poor.cb.hand.append(card)
	if poor.rules.can_play(poor.run, poor.cb, card, null) \
			or poor.rules.play_card(poor.run, poor.cb, card.uid, null) \
			or poor.cb.embers != 1 or not poor.cb.hand.has(card):
		fails.append("Ember Eye: one Ember must leave it unplayable and untouched")
	for up: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "eye-%s" % up, 2)
		game.cb.embers = 2
		var energy: int = maxi(game.cb.player.energy, 3)
		var spent: int = _stat(game, "embersSpent")
		var played: bool = _play(game, "emberEye", null, up)
		var cracked: int = 3 if up else 2
		var ok: bool = played and game.cb.embers == 1 and game.cb.player.energy == energy \
			and _stat(game, "embersSpent") == spent + 2 and _stat(game, "cracked") == 2 * cracked
		for foe: EnemyCombatant in game.cb.enemies:
			ok = ok and _status(foe.statuses, "vulnerable") == cracked
		var burned: bool = false
		for held: CardInst in game.cb.exhaust:
			burned = burned or held.id == &"emberEye"
		if not ok or not burned:
			fails.append("Ember Eye (up %s): expected 2 Embers spent, %d Cracked on both foes, Kindled; got embers %d, %s / %s"
				% [up, cracked, game.cb.embers, game.cb.enemies[0].statuses,
					game.cb.enemies[1].statuses])


## Held, the crown stops the enemy's Cracked from wearing off at the end of its
## action; its Dimmed and the player's own Cracked still wear off.
static func _crown(content: ContentDB, fails: Array[String]) -> void:
	for crowned: bool in [false, true]:
		var game: GlassvowGame = _fight(content, "crown-%s" % crowned)
		if crowned:
			game.run.player.relics.append(CROWN)
		var foe: EnemyCombatant = game.cb.enemies[0]
		foe.move_key = &"grow"
		_play(game, "eclipseSlash", 0)
		game.rules.add_status_enemy(game.cb, foe, "weak", 2)
		game.rules.add_status_player(game.cb, "vulnerable", 1)
		for _turn: int in range(3):
			foe.move_key = &"grow"
			game.apply({"t": "endTurn"})
		var cracked: int = _status(foe.statuses, "vulnerable")
		if cracked != (1 if crowned else 0) or _status(foe.statuses, "weak") != 0 \
				or _status(game.cb.player.statuses, "vulnerable") != 0:
			fails.append("Crown of the Eclipse (held %s): after three turns expected foe Cracked %d, got %s; player %s"
				% [crowned, 1 if crowned else 0, foe.statuses, game.cb.player.statuses])


## The crown's rule is "the enemy's Cracked does not wear off"; it equals the
## lock's "the Cracked you apply" only while nothing but the player cracks an
## enemy. Every enemy-side Cracked in content targets the player.
static func _only_the_player_cracks_enemies(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var sources: Dictionary = {
		"enemies": content.enemies, "shadeKits": content.shade_kits,
		"omens": content.omens, "affixes": content.affixes,
		"variants": content.variants, "progression": content.progression,
	}
	var found: Array[String] = []
	for name: String in sources:
		_enemy_cracks(sources[name], name, found)
	if not found.is_empty():
		fails.append("Crown of the Eclipse: an enemy-side source cracks an enemy: %s" % [found])


static func _enemy_cracks(value: Variant, path: String, found: Array[String]) -> void:
	if typeof(value) == TYPE_ARRAY:
		var rows: Array = value
		for i: int in range(rows.size()):
			_enemy_cracks(rows[i], "%s[%d]" % [path, i], found)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var table: Dictionary = value
	if str(table.get("id", "")) == "vulnerable" and str(table.get("who", "player")) != "player":
		found.append(path)
	for key_v: Variant in table:
		var key: String = str(key_v)
		var child: Variant = table[key_v]
		if key.to_lower().ends_with("status") or key.to_lower().ends_with("statuses"):
			if typeof(child) == TYPE_DICTIONARY:
				var stack: Dictionary = child
				if stack.has("vulnerable"):
					found.append("%s.%s" % [path, key])
		_enemy_cracks(child, "%s.%s" % [path, key], found)


## The Vigil sums the Cracked of every run; at 40 the deed unlocks Totality and
## Ember Eye. The counter is additive to the v2 Vigil: an older save loads at 0.
static func _deed(content: ContentDB, fails: Array[String]) -> void:
	var deed: Dictionary = content.deeds.get(DEED, {})
	if str(deed.get("stat", "")) != "cracked" or int(float(str(deed.get("n", 0)))) != 40 \
			or deed.get("unlocks", []) != ["card:totality", "card:emberEye"]:
		fails.append("Fault in the Glass: expected cracked x40 unlocking Totality and Ember Eye, got %s"
			% deed)
		return
	var vigil: VigilState = VigilState.blank()
	var rows: Array[int] = [25, 15]
	for i: int in range(rows.size()):
		var run_state: RunState = RunState.new_run(content, 61000 + i, "edge-deed-%d" % i,
			{"aspect": 0})
		run_state.stats["cracked"] = rows[i]
		if not vigil.commit_run(run_state, "death", content):
			fails.append("Fault in the Glass: the Vigil refused run %d" % i)
			return
		var total: int = int(float(str(vigil.deeds.get("cracked", -1))))
		var unlocked: bool = vigil.unlocks.has("card:totality") and vigil.unlocks.has("card:emberEye")
		if total != 25 + 15 * i or unlocked != (i == 1):
			fails.append("Fault in the Glass: after run %d expected %d Cracked, unlocked %s; got %d, %s"
				% [i, 25 + 15 * i, i == 1, total, vigil.unlocks])
	var saved: Dictionary = vigil.to_dict()
	var older: Dictionary = saved.duplicate(true)
	var older_deeds: Dictionary = older["deeds"]
	older_deeds.erase("cracked")
	var old_vigil: VigilState = VigilState.from_dict(older)
	var current: VigilState = VigilState.from_dict(saved)
	if old_vigil == null or int(float(str(old_vigil.deeds.get("cracked", -1)))) != 0 \
			or current == null or int(float(str(current.deeds.get("cracked", -1)))) != 40 \
			or int(float(str(saved.get("v", -1)))) != VigilState.VERSION:
		fails.append("Fault in the Glass: the counter must load at 0 from an older v2 Vigil and round-trip")
	for id_v: Variant in content.deeds:
		if not VigilScreen.DEED_IDS.has(str(id_v)):
			fails.append("Fault in the Glass: the Vigil's deed list omits %s" % id_v)


## Base pool, wave 2, wave 3 and the deed each open exactly their own cards;
## with everything open, the Duskblade may draw all of it and the Ashwarden none.
static func _pools(content: ContentDB, fails: Array[String]) -> void:
	var gates: Dictionary = {
		"splinterCut": ["common", ""], "dimTheGlass": ["common", ""],
		"cleft": ["uncommon", ""], "eclipseStep": ["uncommon", ""],
		"tremor": ["uncommon", "poolWave2"], "emberEye": ["rare", "poolWave3"],
		"totality": ["rare", DEED],
	}
	var rules: RewardRules = RewardRules.new(content)
	var unlocks: Array = content.deeds[DEED]["unlocks"]
	var profiles: Dictionary = {
		"": {"aspect": 0},
		"poolWave2": {"aspect": 0, "reveals": ["poolWave2"]},
		"poolWave3": {"aspect": 0, "reveals": ["poolWave3"]},
		DEED: {"aspect": 0, "unlocks": unlocks},
	}
	for opened: String in profiles:
		var profile: Dictionary = profiles[opened]
		var run_state: RunState = RunState.new_run(content, 61100, "edge-pool-%s" % opened,
			profile)
		for id: String in gates:
			var row: Array = gates[id]
			var gate: String = str(row[1])
			var expected: bool = gate.is_empty() or gate == opened \
				or (opened == DEED and unlocks.has("card:%s" % id))
			if rules.offer_cards(run_state, str(row[0])).has(id) != expected:
				fails.append("Edge pools: with %s open, %s offered should be %s"
					% ["the base pool" if opened.is_empty() else opened, id, expected])
	for id: String in ["tremor", "emberEye"]:
		var wave: String = str(gates[id][1])
		var wave_row: Dictionary = content.progression["poolWaves"][wave]
		if str(content.pool_gate_cards.get(id, "")) != wave or not wave_row["cards"].has(id):
			fails.append("Edge pools: %s must be gated and listed in %s" % [id, wave])
	for aspect: int in [0, 1]:
		var open: RunState = RunState.new_run(content, 61101, "edge-open-%d" % aspect,
			{"aspect": aspect, "reveals": null, "unlocks": unlocks})
		var offered: Array = rules.offer_relics(open, "boss")
		for tier: String in ["common", "uncommon", "rare"]:
			offered.append_array(rules.offer_cards(open, tier))
		for id: String in CARDS + [CROWN]:
			if offered.has(id) != (aspect == 0):
				fails.append("Edge pools: %s offered to aspect %d should be %s"
					% [id, aspect, aspect == 0])


## The Edge way names its crown and capstone; every new card is Edge glass and
## Ember Eye is the Lantern/Edge duo. A deck built of it reads Edge.
static func _affinity(content: ContentDB, fails: Array[String]) -> void:
	var edge: Dictionary = Flame.ways(content, 0)[2]
	if str(edge.get("id", "")) != "edge" or str(edge.get("crown", "")) != CROWN \
			or edge.get("capstones", []) != ["totality"]:
		fails.append("Edge affinity: expected crown %s and capstone totality, got %s" % [CROWN, edge])
	for id: String in CARDS:
		var expected: Dictionary = {"lantern": 0.5, "edge": 0.5} if id == "emberEye" \
			else {"edge": 1.0}
		if Flame.card_affinity(content, 0, id) != expected:
			fails.append("Edge affinity: %s expected %s, got %s"
				% [id, expected, Flame.card_affinity(content, 0, id)])
	if Flame.relic_affinity(content, 0, CROWN) != {"edge": 1.0}:
		fails.append("Edge affinity: the crown must carry Edge at 1.0")
	var run_state: RunState = RunState.new_run(content, 61200, "edge-flame", {"aspect": 0})
	for id: String in ["splinterCut", "cleft"]:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
	var reading: Dictionary = Flame.read(content, run_state)
	if str(reading["dominant"]) != "edge" or str(reading["tier"]) != Flame.TIER_STEADY:
		fails.append("Edge affinity: starters + Splinter Cut + Cleft must read Steady Edge, got %s"
			% reading)


## Each new row is authored in both catalogues, and the zh-Hant copy is its own.
static func _copy(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rows: Array[Array] = []
	for id: String in CARDS:
		var leaves: Array[String] = ["name", "text"]
		if content.cards[id].get("up", {}).has("text"):
			leaves.append("textUp")
		rows.append(["cards", id, leaves])
	rows.append(["relics", CROWN, ["name", "text"]])
	rows.append(["deeds", DEED, ["name", "desc"]])
	var en: Locale = Locale.new(Locale.CODE_EN)
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	if zh.code != Locale.CODE_ZH_HANT:
		fails.append("Edge copy: the zh-Hant catalogue did not load")
		return
	for row: Array in rows:
		var leaves: Array = row[2]
		for leaf_v: Variant in leaves:
			var leaf: String = str(leaf_v)
			var key: String = "content.%s.%s.%s" % [row[0], row[1], leaf]
			var english: String = en.t(key)
			var chinese: String = zh.t(key)
			if english == key or chinese == key or english == chinese:
				fails.append("Edge copy: %s is not authored in both catalogues (%s / %s)"
					% [key, english, chinese])
