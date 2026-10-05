extends RefCounted
## #544 A3, the Ashwarden's way stats counted (docs/design/2026-10-05-ash-flame
## §6.4, §10 and §12).
##
## - `smolderKills`: an enemy whose killing blow is Smolder's tick, the enemy
##   phase's HIT_ENEMY marked `poison` and `dead`, which is also what the
##   simulator's per-fight `smolderKills` counts. Every enemy's tick is its own
##   blow, so two enemies dying to Smolder in one phase count two. A card's
##   blow on an enemy that carries Smolder is not a Smolder kill, and a finale
##   handoff kills no one.
## - `drawn`: every card the hand takes beyond the turn's own deal, whether a
##   card, relic, potion or the Art drew it. Night Sight's and the Traveller's
##   Pack's cards ride on the deal and count where the hand took them; a draw a
##   full hand refuses is not a card drawn, and Kindling never counts.
##
## Both fold into the Vigil; the Sermon of Ash progresses on the product path;
## `drawn` is additive to the v2 run and Vigil saves.

const ASH_FIXTURE: String = "res://tests/fixtures/ashwarden_v2_run.json"
const ASHWARDEN: int = 1
const SERMON: String = "ashSermon"
const SERMON_UNLOCKS: Array = ["card:ashenChoir", "relic:smolderingCoal"]
## The lock's way stats for the Ashwarden (§6, §10).
const WAY_STATS: Dictionary = {"smolder": "smolderKills", "hand": "drawn", "endure": "perfects"}


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_smolder_kills(content, fails)
	_handoff_is_no_kill(content, fails)
	_drawn(content, fails)
	_drawn_beside_the_deal(content, fails)
	_sermon_of_ash(content, fails)
	_v2_saves_load_drawn_at_zero(content, fails)
	_class_file(content, fails)


## An Ashwarden fight opened through `apply`. The Ashen Core, the Ashwarden's
## starting relic, has put 3 Smolder on every enemy.
static func _fight(content: ContentDB, tag: String, enemies: Array, kind: String = "normal",
		relics: Array[String] = [], omen: String = "") -> GlassvowGame:
	var run_state: RunState = RunState.new_run(content, 54400, "ash-stats-%s" % tag,
		{"aspect": ASHWARDEN})
	run_state.player.relics.append_array(relics)
	if not omen.is_empty():
		run_state.omens[0] = omen
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": enemies, "kind": kind})
	return game


static func _play(game: GlassvowGame, id: String, target: Variant) -> void:
	var card: CardInst = CardInst.new(game.run.next_uid(), StringName(id), false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(game.cb.player.energy, 3)
	game.apply({"t": "playCard", "uid": card.uid, "target": target})


static func _stat(run_state: RunState, key: String) -> int:
	return int(float(str(run_state.stats.get(key, -1))))


## The Smolder ticks of `events` that killed: the simulator's definition.
static func _lethal_ticks(events: Array[Dictionary]) -> int:
	var n: int = 0
	for ev: Dictionary in events:
		if ev.get("t") == EventTypes.HIT_ENEMY and ev.get("poison", false) and ev.get("dead", false):
			n += 1
	return n


## Two enemies die to their own ticks in one enemy phase: two kills, each its
## own HIT_ENEMY. The third, carrying Smolder too, is then killed by a card:
## not a Smolder kill, though `slain` counts it.
static func _smolder_kills(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "kills", ["sporeling", "sporeling", "sporeling"])
	var hp: Array[int] = [3, 2, 200]
	for i: int in range(3):
		var enemy: EnemyCombatant = game.cb.enemies[i]
		enemy.max_hp = maxi(enemy.max_hp, hp[i])
		enemy.hp = hp[i]
		if int(float(str(enemy.statuses.get("poison", 0)))) != 3:
			fails.append("ash way stats: the Ashen Core should open with 3 Smolder, got %s"
				% enemy.statuses)
	var events: Array[Dictionary] = game.apply({"t": "endTurn"})
	if _stat(game.run, "smolderKills") != 2 or _lethal_ticks(events) != 2 \
			or _stat(game.run, "slain") != 2:
		fails.append("ash way stats: two Smolder deaths in one phase expected 2 kills, got %d (%d lethal ticks, %d slain)"
			% [_stat(game.run, "smolderKills"), _lethal_ticks(events), _stat(game.run, "slain")])
	var last: EnemyCombatant = game.cb.enemies[2]
	if game.cb.over or last.hp <= 0 or int(float(str(last.statuses.get("poison", 0)))) <= 0:
		fails.append("ash way stats: the third sporeling should stand, smouldering")
		return
	last.hp = 1
	last.block = 0
	_play(game, "ashBite", 2)
	if not game.cb.over or game.cb.result != "win":
		fails.append("ash way stats: Ashbite should have won the fight")
	if _stat(game.run, "smolderKills") != 2 or _stat(game.run, "slain") != 3:
		fails.append("ash way stats: a card's kill on a smouldering enemy is no Smolder kill, got %d kills, %d slain"
			% [_stat(game.run, "smolderKills"), _stat(game.run, "slain")])


## A tick that would kill a finale boss hands the fight off instead: no one is
## slain, so no Smolder kill.
static func _handoff_is_no_kill(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "handoff", ["eternalKeeper"], "boss")
	var foe: EnemyCombatant = game.cb.enemies[0]
	foe.hp = 3
	foe.block = 0
	foe.statuses["poison"] = 8
	game.apply({"t": "endTurn"})
	if not game.cb.finale_handoff or _stat(game.run, "smolderKills") != 0 \
			or _stat(game.run, "slain") != 0:
		fails.append("ash way stats: a finale handoff counts no Smolder kill (handoff %s, %d kills, %d slain)"
			% [game.cb.finale_handoff, _stat(game.run, "smolderKills"), _stat(game.run, "slain")])


## One fight, step by step. The deal is not drawn; Tinder's two, Struck Match's
## one, the Art's two and the potion's are, the last only as far as the hand has
## room; a Kindle is not, until the Verdant Branch draws for it; Night Sight's
## extra card on the next deal is. The Vigil folds the run's tally.
static func _drawn(content: ContentDB, fails: Array[String]) -> void:
	var game: GlassvowGame = _fight(content, "drawn", ["sporeling"])
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.max_hp = 500
	enemy.hp = 500
	var pile: Array[CardInst] = []
	for _i: int in range(40):
		pile.append(CardInst.new(game.run.next_uid(), &"defend", false))
	game.cb.draw = pile
	game.run.art = &"stoke"
	game.run.player.potions[0] = "swift"
	var steps: Array = [
		["the deal", 5, 0, 0],
		["Tinder", 7, 2, 0],
		["Struck Match", 8, 3, 0],
		["a Kindle", 7, 3, 1],
		["the Art", 9, 5, 1],
		["Inkdraught into a hand of nine", 10, 6, 1],
		["the next deal", 5, 6, 1],
		["the Verdant Branch on a Kindle", 5, 7, 2],
		["Night Sight's deal", 6, 8, 2],
	]
	for step_v: Variant in steps:
		var step: Array = step_v
		var label: String = str(step[0])
		match label:
			"Tinder": _play(game, "preparation", null)
			"Struck Match": _play(game, "surge", null)
			"a Kindle", "the Verdant Branch on a Kindle":
				game.apply({"t": "kindleFromHand", "uid": game.cb.hand[0].uid})
			"the Art":
				game.cb.embers = game.cb.ember_cap
				game.apply({"t": "useArt"})
			"Inkdraught into a hand of nine": game.apply({"t": "usePotion", "slot": 0})
			"the next deal":
				game.apply({"t": "endTurn"})
				game.run.player.relics.append("verdantBranch")
			"Night Sight's deal":
				_play(game, "nightSight", null)
				game.apply({"t": "endTurn"})
		var want: Array[int] = [step[1], step[2], step[3]]
		var got: Array[int] = [game.cb.hand.size(), _stat(game.run, "drawn"),
			_stat(game.run, "kindles")]
		if got != want:
			fails.append("ash way stats: after %s expected hand, drawn, kindles %s; got %s"
				% [label, want, got])
	var vigil: VigilState = VigilState.blank()
	if not vigil.commit_run(game.run, "death", content) \
			or int(float(str(vigil.deeds.get("drawn", -1)))) != 8:
		fails.append("ash way stats: the Vigil should fold drawn 8, got %s" % vigil.deeds.get("drawn"))


## The deal is the turn's own five, less what the act's omen takes; the
## Traveller's Pack's two first-turn cards beyond it are drawn.
static func _drawn_beside_the_deal(content: ContentDB, fails: Array[String]) -> void:
	var pack: Array[String] = ["travelersPack"]
	# [label, relics, omen, hand dealt, drawn]
	var cases: Array = [
		["the plain deal", [], "", 5, 0],
		["the Ember Wind's deal", [], "emberWind", 4, 0],
		["the Traveller's Pack", pack, "", 7, 2],
		["the Traveller's Pack under the Ember Wind", pack, "emberWind", 6, 2],
	]
	for case_v: Variant in cases:
		var case: Array = case_v
		var label: String = str(case[0])
		var listed: Array = case[1]
		var relics: Array[String] = []
		relics.assign(listed)
		var dealt: int = case[3]
		var drawn: int = case[4]
		var game: GlassvowGame = _fight(content, "deal-%s" % label, ["sporeling"], "normal",
			relics, str(case[2]))
		if game.cb.hand.size() != dealt or _stat(game.run, "drawn") != drawn:
			fails.append("ash way stats: %s expected hand %d, drawn %d; got %d, %d"
				% [label, dealt, drawn, game.cb.hand.size(), _stat(game.run, "drawn")])


## The Sermon of Ash on the product path: Ashwarden fights played through
## `apply`, each won by the Ashen Core's Smolder ticking the last enemy dead,
## and every run folded by `VigilState.commit_run` as the game ends a run. Nine
## kills in one run leave the deed short; the tenth, in the next, unlocks it.
## Each fight is won without a scratch, so the Endure way's `perfects` counts it.
static func _sermon_of_ash(content: ContentDB, fails: Array[String]) -> void:
	var deed: Dictionary = content.deeds.get(SERMON, {})
	if str(deed.get("stat", "")) != "smolderKills" or int(float(str(deed.get("n", 0)))) != 10 \
			or deed.get("unlocks", []) != SERMON_UNLOCKS:
		fails.append("ash way stats: Sermon of Ash expected smolderKills x10 unlocking %s, got %s"
			% [SERMON_UNLOCKS, deed])
		return
	var vigil: VigilState = VigilState.blank()
	var runs: Array[int] = [9, 1]
	for r: int in range(runs.size()):
		var run_state: RunState = RunState.new_run(content, 54410 + r, "ash-sermon-%d" % r,
			{"aspect": ASHWARDEN})
		var game: GlassvowGame = GlassvowGame.new(content, run_state)
		for f: int in range(runs[r]):
			game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
			var enemy: EnemyCombatant = game.cb.enemies[0]
			enemy.hp = 3
			var events: Array[Dictionary] = game.apply({"t": "endTurn"})
			if game.cb.result != "win" or _lethal_ticks(events) != 1:
				fails.append("ash way stats: run %d fight %d should be won by the Smolder tick" % [r, f])
				return
		if _stat(run_state, "smolderKills") != runs[r] or _stat(run_state, "perfects") != runs[r]:
			fails.append("ash way stats: run %d expected %d Smolder kills and perfect fights, got %d, %d"
				% [r, runs[r], _stat(run_state, "smolderKills"), _stat(run_state, "perfects")])
		if not vigil.commit_run(run_state, "death", content):
			fails.append("ash way stats: the Vigil refused run %d" % r)
			return
		var total: int = int(float(str(vigil.deeds.get("smolderKills", -1))))
		var unlocked: bool = vigil.unlocks.has(SERMON_UNLOCKS[0]) and vigil.unlocks.has(SERMON_UNLOCKS[1])
		if total != 9 + r or unlocked != (r == 1):
			fails.append("ash way stats: after run %d expected %d Smolder kills, unlocked %s; got %d, %s"
				% [r, 9 + r, r == 1, total, vigil.unlocks])


## A real v2 Ashwarden save written before `drawn` loads it at zero and saves
## as v2; a current save round-trips it. An older v2 Vigil loads its counter at
## zero.
static func _v2_saves_load_drawn_at_zero(content: ContentDB, fails: Array[String]) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASH_FIXTURE))
	if typeof(raw) != TYPE_DICTIONARY:
		fails.append("ash way stats: %s did not parse" % ASH_FIXTURE)
		return
	var save: Dictionary = raw
	var saved_stats: Dictionary = save.get("stats", {})
	if int(float(str(save.get("v", -1)))) != 2 or saved_stats.has("drawn") \
			or not saved_stats.has("smolderKills"):
		fails.append("ash way stats: the fixture must be a v2 save from before drawn")
		return
	var loaded: RunState = RunState.from_save_dict(save, content)
	if loaded == null:
		fails.append("ash way stats: a v2 save without drawn must load")
		return
	var again: Dictionary = loaded.to_save_dict()
	if _stat(loaded, "drawn") != 0 or int(float(str(again.get("v", -1)))) != 2:
		fails.append("ash way stats: an older v2 save must load drawn at 0 and save as v2, got %s"
			% loaded.stats)
	loaded.stats["drawn"] = 11
	var current: RunState = RunState.from_save_dict(loaded.to_save_dict(), content)
	if current == null or _stat(current, "drawn") != 11:
		fails.append("ash way stats: a current save must round-trip drawn")
	var vigil: VigilState = VigilState.blank()
	vigil.deeds["drawn"] = 6
	var vigil_save: Dictionary = vigil.to_dict()
	var older: Dictionary = vigil_save.duplicate(true)
	var older_deeds: Dictionary = older["deeds"]
	older_deeds.erase("drawn")
	var old_vigil: VigilState = VigilState.from_dict(older)
	var new_vigil: VigilState = VigilState.from_dict(vigil_save)
	if old_vigil == null or int(float(str(old_vigil.deeds.get("drawn", -1)))) != 0 \
			or new_vigil == null or int(float(str(new_vigil.deeds.get("drawn", -1)))) != 6 \
			or int(float(str(vigil_save.get("v", -1)))) != 2:
		fails.append("ash way stats: an older v2 Vigil must load drawn at 0, and a current one round-trip")


## The class file names the lock's way stats for the Ashwarden, and every way
## stat it names is a run stat the Vigil folds when a run ends.
static func _class_file(content: ContentDB, fails: Array[String]) -> void:
	if BalanceClasses.way_stats("ashwarden") != WAY_STATS:
		fails.append("ash way stats: tools/balance_classes.json expected %s for the Ashwarden, got %s"
			% [WAY_STATS, BalanceClasses.way_stats("ashwarden")])
	var run_state: RunState = RunState.new_run(content, 54420, "ash-stats-fold", {"aspect": ASHWARDEN})
	var named: Array[String] = []
	for aspect: String in ["duskblade", "ashwarden"]:
		var stats: Dictionary = BalanceClasses.way_stats(aspect)
		for way_v: Variant in stats:
			var stat: String = str(stats[way_v])
			named.append(stat)
			if not run_state.stats.has(stat):
				fails.append("ash way stats: %s's way stat %s is not a run stat" % [aspect, stat])
			run_state.stats[stat] = 1
	var vigil: VigilState = VigilState.blank()
	vigil.commit_run(run_state, "death", content)
	for stat: String in named:
		if int(float(str(vigil.deeds.get(stat, -1)))) != 1:
			fails.append("ash way stats: the Vigil does not fold the way stat %s" % stat)
