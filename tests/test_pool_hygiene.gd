extends RefCounted
## Flame lock §6.1 pool hygiene: the Duskblade is never offered the Ashwarden's
## Smolder glass (card rewards, shop cards and relics, boss relics, event cards,
## random relics) while the Ashwarden keeps all of it, and the Ashwarden is never
## offered the Duskblade's Edge cards and crown (lock PR 6) while the Duskblade
## keeps them; the draw count per offer does not move; checkpoints saved before
## the exclusion still validate. #543 carries the same rule to the Smolderphial,
## the Keeper's Pouch of Ash and the Ashfall Art: a Duskblade is never offered
## glass its blocked Smolder would leave dead.

const SEEDS: int = 300
const HEROES: Array[String] = ["the Duskblade", "the Ashwarden"]


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var offered: Array[Dictionary] = [_offered(content, 0), _offered(content, 1)]
	for aspect: int in [0, 1]:
		for id: String in _excluded(content, aspect):
			if offered[aspect].has(id):
				fails.append("pool hygiene: %s was offered excluded %s" % [HEROES[aspect], id])
			if not offered[1 - aspect].has(id):
				fails.append("pool hygiene: %s was never offered %s in %d seeds"
					% [HEROES[1 - aspect], id, SEEDS])
	_draw_counts_unchanged(fails)
	_old_checkpoints_validate(fails)
	_omissions_validate(fails)
	_smolder_glass_hygiene(content, fails)


static func _excluded(content: ContentDB, aspect: int = 0) -> Array[String]:
	var out: Array[String] = []
	var row: Dictionary = content.aspects[aspect]
	var excludes: Dictionary = row.get("excludes", {})
	for kind: String in ["cards", "relics", "potions"]:
		for id_v: Variant in excludes.get(kind, []):
			out.append(str(id_v))
	return out


## Every pool wave revealed and every deed done, so each excluded id is live.
static func _run(content: ContentDB, seed: int, aspect: int) -> RunState:
	var unlocks: Array = []
	for deed_v: Variant in content.deeds.values():
		var deed: Dictionary = deed_v
		var unlocked: Array = deed.get("unlocks", [])
		unlocks.append_array(unlocked)
	return RunState.new_run(content, 7000 + seed, "hygiene-%d-%d" % [aspect, seed],
		{"aspect": aspect, "reveals": content.reveal_ids.duplicate(), "unlocks": unlocks})


static func _offered(content: ContentDB, aspect: int) -> Dictionary:
	var seen: Dictionary = {}
	var rules: RewardRules = RewardRules.new(content)
	for seed: int in range(SEEDS):
		var run_state: RunState = _run(content, seed, aspect)
		var ids: Array = []
		for kind: String in ["normal", "elite", "boss"]:
			var reward: Dictionary = rules.gen_combat_rewards(run_state, kind)
			var cards: Array = reward["cards"]
			ids.append_array(cards)
			ids.append(reward["relic"])
			ids.append(reward.get("relic2"))
			ids.append(reward["potion"])
		var stock: Dictionary = rules.gen_shop(run_state)
		for category: String in ["cards", "relics", "potions"]:
			for row_v: Variant in stock[category]:
				var row: Dictionary = row_v
				ids.append(row["id"])
		ids.append_array(rules.roll_boss_relics(run_state))
		ids.append_array(rules.roll_event_cards(run_state, 5))
		ids.append(rules.claim_treasure(run_state)["relic"])
		for id_v: Variant in ids:
			if id_v != null:
				seen[str(id_v)] = true
	return seen


## The Duskblade's cursor moves exactly as it did before the exclusion for
## every offer whose draw count is fixed (shop, combat reward, treasure, boss).
static func _draw_counts_unchanged(fails: Array[String]) -> void:
	var hygienic: ContentDB = ContentDB.load_full(false)
	var open: ContentDB = ContentDB.load_full(false)
	var open_dusk: Dictionary = open.aspects[0]
	open_dusk.erase("excludes")
	var with_rules: RewardRules = RewardRules.new(hygienic)
	var open_rules: RewardRules = RewardRules.new(open)
	for seed: int in range(40):
		var a: RunState = _run(hygienic, seed, 0)
		var b: RunState = _run(open, seed, 0)
		var cursors: Array[String] = []
		with_rules.gen_shop(a)
		open_rules.gen_shop(b)
		cursors.append("shop %d/%d" % [a.rng_state(), b.rng_state()])
		with_rules.gen_combat_rewards(a, "elite")
		open_rules.gen_combat_rewards(b, "elite")
		cursors.append("elite %d/%d" % [a.rng_state(), b.rng_state()])
		with_rules.claim_treasure(a)
		open_rules.claim_treasure(b)
		cursors.append("treasure %d/%d" % [a.rng_state(), b.rng_state()])
		with_rules.roll_boss_relics(a)
		open_rules.roll_boss_relics(b)
		cursors.append("boss %d/%d" % [a.rng_state(), b.rng_state()])
		if a.rng_state() != b.rng_state():
			fails.append("pool hygiene: seed %d moved the draw count: %s" % [seed, cursors])
			return


## A shop or event checkpoint saved before the exclusion (so holding excluded
## glass) must still validate on resume, or the route would quarantine.
static func _old_checkpoints_validate(fails: Array[String]) -> void:
	var hygienic: ContentDB = ContentDB.load_full(false)
	var open: ContentDB = ContentDB.load_full(false)
	var open_dusk: Dictionary = open.aspects[0]
	open_dusk.erase("excludes")
	var with_rules: RewardRules = RewardRules.new(hygienic)
	var open_rules: RewardRules = RewardRules.new(open)
	var excluded: Array[String] = _excluded(hygienic)
	var found: bool = false
	for seed: int in range(SEEDS):
		var saved_run: RunState = _run(open, seed, 0)
		var stock: Dictionary = open_rules.gen_shop(saved_run)
		var holds: bool = false
		for row_v: Variant in stock["cards"]:
			var row: Dictionary = row_v
			holds = holds or excluded.has(str(row["id"]))
		if not holds:
			continue
		found = true
		var resumed: RunState = _run(hygienic, seed, 0)
		if not with_rules.valid_shop_checkpoint(resumed, stock):
			fails.append("pool hygiene: a pre-exclusion shop checkpoint no longer validates")
		break
	if not found:
		fails.append("pool hygiene: no open shop held excluded glass in %d seeds" % SEEDS)
	var pending: Dictionary = {"kind": "card", "cards": ["venomStrike", "twinFangs"]}
	if not with_rules.valid_event_checkpoint(_run(hygienic, 0, 0), "library", pending):
		fails.append("pool hygiene: a pre-exclusion event pick no longer validates")


## Completeness follows the offers: once every relic the Duskblade can be offered
## is owned, a shop without that tier and a treasure paid in gold are valid,
## although the excluded Smoldering Coal is still unowned.
static func _omissions_validate(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rules: RewardRules = RewardRules.new(content)
	var run_state: RunState = _run(content, 1, 0)
	for tier: String in ["common", "uncommon", "rare"]:
		for id_v: Variant in rules.offer_relics(run_state, tier):
			if not run_state.player.relics.has(str(id_v)):
				run_state.player.relics.append(str(id_v))
	if run_state.player.relics.has("smolderingCoal") \
			or not rules.relic_pool(run_state, "uncommon").has("smolderingCoal"):
		fails.append("pool hygiene: the omission case needs Smoldering Coal live and unowned")
		return
	var stock: Dictionary = rules.gen_shop(run_state)
	if not stock["relics"].is_empty() or not rules.valid_shop_checkpoint(run_state, stock):
		fails.append("pool hygiene: a shop with every offerable relic owned must validate")
	var claim: Dictionary = rules.claim_treasure(run_state)
	if claim["relic"] != null or not rules.valid_treasure_checkpoint(run_state, claim):
		fails.append("pool hygiene: a gold treasure with every offerable relic owned must validate")


## The Keeper offers the Duskblade neither the Pouch of Ash (its Smolderphial)
## nor the Ashfall Art, and the Ashwarden both; a Duskblade shop or run saved
## holding that glass still loads, because validation reads the full catalogue.
static func _smolder_glass_hygiene(content: ContentDB, fails: Array[String]) -> void:
	var rules: RewardRules = RewardRules.new(content)
	var dusk: RunState = _run(content, 0, 0)
	var ash: RunState = _run(content, 0, 1)
	if rules.offer_boons(dusk).has("venomPouch") or not rules.offer_boons(ash).has("venomPouch"):
		fails.append("pool hygiene: the Pouch of Ash is not the Ashwarden's alone")
	if rules.offer_arts(dusk).has("ashfall") or not rules.offer_arts(ash).has("ashfall"):
		fails.append("pool hygiene: the Ashfall Art is not the Ashwarden's alone")
	if rules.offer_arts(dusk).size() != content.arts.size() - 1:
		fails.append("pool hygiene: the Duskblade lost an Art besides Ashfall")
	var stock: Dictionary = rules.gen_shop(dusk)
	var potions: Array = stock["potions"]
	var row: Dictionary = potions[0]
	row["id"] = "venom"
	if not rules.valid_shop_checkpoint(dusk, stock):
		fails.append("pool hygiene: a pre-#543 shop holding a Smolderphial no longer validates")
	dusk.art = &"ashfall"
	dusk.player.potions[0] = "venom"
	var reloaded: RunState = RunState.from_save_dict(dusk.to_save_dict(), content)
	if reloaded == null or reloaded.art != &"ashfall" or reloaded.player.potions[0] != "venom":
		fails.append("pool hygiene: a Duskblade saved with Ashfall and a Smolderphial no longer loads")
