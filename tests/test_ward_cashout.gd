extends RefCounted
## STREAM B zero-row laws: the Ward gate, Dusk-only cash-out, pool scope and p9 policy.

const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const Policy: GDScript = preload("res://tools/balance_policy.gd")
const Sim: GDScript = preload("res://tools/balance_sim.gd")
const Cem: GDScript = preload("res://tools/balance_cem.gd")
const Observer: GDScript = preload("res://tools/p9_ward_observer.gd")


static func run(fails: Array[String]) -> void:
	_card_fixture(fails)
	_gate_and_preview(fails)
	_dusk_cashout(fails)
	_lethal_post_treatment_rng_divergence(fails)
	_ash_effect_is_inert(fails)
	_unknown_requirement_fails_closed(fails)
	_aspect_pool(fails)
	_pilot_identity_and_terms(fails)
	_sampler_extension_identity(fails)
	_null_card_comparator(fails)
	_h11_observer(fails)
	_locale_fixture(fails)
	_outcome_digest_excludes_observation(fails)


static func _check(condition: Variant, message: String, fails: Array[String]) -> void:
	if condition != true:
		fails.append("ward cash-out: %s" % message)


static func _ji(value: Variant) -> int:
	return int(float(str(value)))


static func _game(aspect: int, tag: String) -> GlassvowGame:
	var content: ContentDB = ContentDB.load_full(false)
	var run_state: RunState = RunState.new_run(content, 42190, tag, {"aspect": aspect})
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.hp = 100
	enemy.max_hp = 100
	enemy.block = 0
	game.cb.queue.clear()
	return game


static func _card(game: GlassvowGame) -> CardInst:
	var card: CardInst = CardInst.new(game.run.next_uid(), &"facetBurst", false)
	game.cb.hand.append(card)
	game.cb.player.energy = maxi(_ji(game.cb.player.energy), 1)
	return card


static func _card_fixture(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var d: Dictionary = content.cards.get("facetBurst", {})
	_check(not d.is_empty(), "facetBurst is missing", fails)
	_check(str(d.get("type", "")) == "skill", "facetBurst must be a skill", fails)
	_check(str(d.get("aspect", "")) == "duskblade", "facetBurst must be Dusk-scoped", fails)
	_check(str(d.get("rarity", "")) == "uncommon" and _ji(d.get("cost", -1)) == 1,
		"facetBurst rarity/cost diverged", fails)
	_check(str(d.get("target", "")) == "enemy", "facetBurst must target one enemy", fails)
	var requires: Dictionary = d.get("requires", {})
	_check(requires.size() == 1 and _ji(requires.get("wardAtLeast", -1)) == 10,
		"facetBurst gate diverged", fails)
	var effects: Array = d.get("effects", [])
	var effect: Dictionary = effects[0] if effects.size() == 1 else {}
	_check(str(effect.get("kind", "")) == "wardBurst" and _ji(effect.get("spend", -1)) == 10
		and _ji(effect.get("per", -1)) == 2,
		"facetBurst base effect diverged", fails)
	var up: Dictionary = d.get("up", {})
	var up_effects: Array = up.get("effects", [])
	var up_effect: Dictionary = up_effects[0] if up_effects.size() == 1 else {}
	_check(str(up_effect.get("kind", "")) == "wardBurst"
		and _ji(up_effect.get("spend", -1)) == 10 and _ji(up_effect.get("per", -1)) == 3,
		"facetBurst upgrade effect diverged", fails)


static func _gate_and_preview(fails: Array[String]) -> void:
	var game: GlassvowGame = _game(0, "ward-gate")
	var card: CardInst = _card(game)
	game.cb.player.block = 9
	var rng_before: int = game.run.rng_state()
	_check(not game.rules.can_play(game.run, game.cb, card, 0),
		"gate allowed 9 Ward", fails)
	_check(game.rules.preview_play(game.cb, card, 0, game.run) == null,
		"preview did not mirror the blocked gate", fails)
	_check(game.run.rng_state() == rng_before,
		"underfunded requires.wardAtLeast moved the RNG cursor", fails)
	game.cb.player.block = 10
	_check(game.rules.can_play(game.run, game.cb, card, 0),
		"gate rejected exactly 10 Ward", fails)
	var preview_v: Variant = game.rules.preview_play(game.cb, card, 0, game.run)
	_check(typeof(preview_v) == TYPE_DICTIONARY, "preview missing at the threshold", fails)
	if typeof(preview_v) == TYPE_DICTIONARY:
		var preview: Dictionary = preview_v
		_check(_ji(preview.get("total", -1)) == 20 and _ji(preview.get("loss", -1)) == 20,
			"threshold preview must show deterministic 20 damage", fails)


static func _dusk_cashout(fails: Array[String]) -> void:
	var game: GlassvowGame = _game(0, "ward-dusk")
	var enemy: EnemyCombatant = game.cb.enemies[0]
	enemy.chips = enemy.facet_max - 1
	enemy.staggered = false
	enemy.statuses["vulnerable"] = 8
	game.cb.player.statuses["str"] = 99
	game.cb.player.statuses["weak"] = 1
	game.cb.player.block = 15
	var shatters_before: int = _ji(game.run.stats.get("shatters", 0))
	var rng_before: int = game.run.rng_state()
	var hp_before: int = enemy.hp
	var chips_before: int = enemy.chips
	var card: CardInst = _card(game)
	var played: bool = game.rules.play_card(game.run, game.cb, card.uid, 0)
	_check(played, "legal Dusk cash-out was not played", fails)
	_check(game.cb.player.block == 5, "cash-out did not spend exactly 10 Ward", fails)
	_check(hp_before - enemy.hp == 20,
		"cash-out damage was changed by Fervor, Dimmed or Cracked", fails)
	var ward_events: Array[Dictionary] = []
	for event: Dictionary in game.cb.queue:
		if str(event.get("t", "")) == "wardSpend":
			ward_events.append(event)
	_check(ward_events == [{"t": EventTypes.WARD_SPEND, "n": 10, "total": 5}],
		"cash-out must emit one exact wardSpend event", fails)
	_check(enemy.chips == chips_before, "cash-out produced a chip", fails)
	_check(not enemy.staggered and _ji(game.run.stats.get("shatters", 0)) == shatters_before,
		"cash-out produced a shatter or Stagger", fails)
	_check(game.run.rng_state() == rng_before, "cash-out moved the RNG cursor", fails)


static func _lethal_post_treatment_rng_divergence(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var run_state: RunState = RunState.new_run(content, 42192, "ward-lethal",
		{"aspect": 0})
	run_state.player.relics.append("reapersBell")
	var game: GlassvowGame = GlassvowGame.new(content, run_state)
	game.apply({"t": "startCombat", "enemies": ["sporeling", "sporeling", "sporeling"],
		"kind": "normal"})
	var target: EnemyCombatant = game.cb.enemies[0]
	target.hp = 20
	target.statuses["poison"] = 4
	for i: int in range(1, game.cb.enemies.size()):
		game.cb.enemies[i].hp = 50
	game.cb.player.block = 15
	game.cb.queue.clear()
	var card: CardInst = CardInst.new(game.run.next_uid(), &"facetBurst", false)
	var d: Dictionary = content.cards["facetBurst"]
	var fx: Dictionary = d["effects"][0]
	var rng_before: int = game.run.rng_state()
	game.rules._apply_effect(game.run, game.cb, card, d, fx, target)
	var event_types: Array[String] = []
	for event: Dictionary in game.cb.queue:
		event_types.append(str(event.get("t", "")))
	var ward_i: int = event_types.find("wardSpend")
	var death_i: int = event_types.find("die")
	var jump_i: int = event_types.find("smolderJump")
	var bell_i: int = -1
	for i: int in range(game.cb.queue.size()):
		var event: Dictionary = game.cb.queue[i]
		if str(event.get("t", "")) == "relicProc" and str(event.get("id", "")) == "reapersBell":
			bell_i = i
			break
	_check(game.cb.player.block == 5 and target.hp == 0,
		"lethal wardBurst was capped or did not mutate treatment state", fails)
	_check(ward_i >= 0 and death_i > ward_i and jump_i > death_i and bell_i > death_i,
		"first legitimate RNG divergence was not recorded as death.smolderJump with Reaper Bell", fails)
	_check(game.run.rng_state() != rng_before,
		"death-triggered Smolder jump did not consume its legitimate post-treatment RNG", fails)


static func _ash_effect_is_inert(fails: Array[String]) -> void:
	var game: GlassvowGame = _game(1, "ward-ash")
	var enemy: EnemyCombatant = game.cb.enemies[0]
	game.cb.player.block = 15
	enemy.chips = enemy.facet_max - 1
	enemy.staggered = false
	var card: CardInst = CardInst.new(game.run.next_uid(), &"facetBurst", false)
	var d: Dictionary = game.content.cards["facetBurst"]
	var fx: Dictionary = d["effects"][0]
	var block_before: int = game.cb.player.block
	var hp_before: int = enemy.hp
	var chips_before: int = enemy.chips
	var rng_before: int = game.run.rng_state()
	var stats_before: String = JSON.stringify(game.run.stats)
	var events_before: String = JSON.stringify(game.cb.queue)
	game.rules._apply_effect(game.run, game.cb, card, d, fx, enemy)
	_check(game.cb.player.block == block_before and enemy.hp == hp_before
		and enemy.chips == chips_before and not enemy.staggered,
		"Ash wardBurst wrote combat state", fails)
	_check(JSON.stringify(game.run.stats) == stats_before,
		"Ash wardBurst wrote run state", fails)
	_check(JSON.stringify(game.cb.queue) == events_before,
		"Ash wardBurst queued an event", fails)
	_check(game.run.rng_state() == rng_before, "Ash wardBurst moved the RNG cursor", fails)
	_check(game.rules.preview_play(game.cb, card, 0, game.run) == null,
		"Ash wardBurst previewed an inert effect", fails)


static func _unknown_requirement_fails_closed(fails: Array[String]) -> void:
	var game: GlassvowGame = _game(0, "ward-unknown-gate")
	var card: CardInst = _card(game)
	game.cb.player.block = 99
	var d: Dictionary = game.content.cards["facetBurst"]
	d["requires"] = {"futureGate": 1}
	_check(not game.rules.can_play(game.run, game.cb, card, 0),
		"runtime ignored an unknown requires key", fails)
	_check(game.rules.preview_play(game.cb, card, 0, game.run) == null,
		"preview ignored an unknown requires key", fails)
	var faults: Array[String] = []
	game.content.validate(faults)
	var found: bool = false
	for fault: String in faults:
		if fault.contains("facetBurst") and fault.contains("unknown key futureGate"):
			found = true
			break
	_check(found, "ContentDB did not report the unknown requires key", fails)


static func _aspect_pool(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	var rewards: RewardRules = RewardRules.new(content)
	var dusk: RunState = RunState.new_run(content, 42191, "ward-pool-dusk", {"aspect": 0})
	var ash: RunState = RunState.new_run(content, 42191, "ward-pool-ash", {"aspect": 1})
	var dusk_rng: int = dusk.rng_state()
	var ash_rng: int = ash.rng_state()
	_check(rewards.card_pool(dusk, "uncommon").has("facetBurst"),
		"Dusk uncommon pool omitted facetBurst", fails)
	_check(not rewards.card_pool(ash, "uncommon").has("facetBurst"),
		"Ash uncommon pool exposed facetBurst", fails)
	_check(rewards.card_pool(dusk, "common").has("brace")
		and rewards.card_pool(ash, "common").has("brace"),
		"aspect filtering changed an existing aspect-neutral card", fails)
	_check(dusk.rng_state() == dusk_rng and ash.rng_state() == ash_rng,
		"aspect pool filter moved an RNG cursor", fails)


static func _pilot_identity_and_terms(fails: Array[String]) -> void:
	Pilot.apply_policy({})
	var game: GlassvowGame = _game(0, "ward-pilot")
	var d: Dictionary = game.content.cards["facetBurst"]
	var card: CardInst = CardInst.new(game.run.next_uid(), &"facetBurst", false)
	var without_burst: Dictionary = d.duplicate(true)
	without_burst["effects"] = []
	var burst_value: float = Pilot.card_score(d, 0, "facetBurst") \
		- Pilot.card_score(without_burst, 0, "facetBurst")
	_check(is_equal_approx(burst_value, 20.0),
		"card_score did not value wardBurst as spend * per", fails)
	_check(Pilot.VERSION == "p9-w0-v2", "pilot identity is not p9-w0-v2", fails)
	_check(Pilot._advances_fight(d), "pilot does not recognise wardBurst as fight progress", fails)
	var scores: Array[float] = []
	for ward: int in [10, 11]:
		game.cb.player.block = ward
		var preview_v: Variant = game.rules.preview_play(game.cb, card, 0, game.run)
		var preview: Dictionary = preview_v if typeof(preview_v) == TYPE_DICTIONARY else {}
		scores.append(Pilot._combat_score(game, card, d, 0, preview, 5, 5 - ward, true))
	var expected_bonus: float = 20.0 * float(str(Policy.default()["combat"]["wardSurplus"]))
	_check(is_equal_approx(scores[1] - scores[0], expected_bonus),
		"surplus-Ward combat term did not apply its frozen weight", fails)


static func _sampler_extension_identity(fails: Array[String]) -> void:
	_check(Policy.SAMPLE_EXTENSION_IDENTITY == "p9-w0-v2-ward-surplus-extension-v1",
		"sampler extension identity drifted", fails)
	_check(JSON.stringify(Policy.sample_origin()).sha256_text()
		== "776e1394aba46d89480676b66ece395eadf63fe544413fa28e982e7ee17c1d44",
		"legacy sample_origin changed", fails)
	var expected_legacy: Array[String] = [
		"c1f5f2feff70fe24b7e5a787462139ac11bf3edfb7ea798d47fd6a4a9940ba07",
		"04b8ffa8154be00adaee280c8927f8407f1ff9928de6a7b858d15c74a496d455",
		"a50b44b961f8330ea1e5fa2c58192667951092a62cba1a990a02522293b94287",
	]
	var sampled: Array[Dictionary] = Policy.sample_range(215, 0, 3)
	for i: int in range(sampled.size()):
		var legacy: Dictionary = sampled[i].duplicate(true)
		var combat: Dictionary = legacy["combat"]
		combat.erase("wardSurplus")
		_check(JSON.stringify(legacy).sha256_text() == expected_legacy[i],
			"legacy sampler coordinate/order/consumption drifted at index %d" % i, fails)
		_check(float(str(sampled[i]["combat"].get("wardSurplus", 0.0))) > 0.0,
			"domain-separated wardSurplus was not appended at index %d" % i, fails)
	_check(sampled == Policy.sample_range(215, 0, 3),
		"domain-separated sampler extension is not deterministic", fails)
	var legacy_paths: PackedStringArray = Cem._legacy_mag_paths()
	_check(legacy_paths.size() == 98
		and JSON.stringify(Array(legacy_paths)).sha256_text()
			== "3bea1d187e2688466be7586a65e2f1a66514151f5c6cac853ccfb031fec729c7"
		and not legacy_paths.has("combat.wardSurplus")
		and Cem._extension_mag_paths() == PackedStringArray(["combat.wardSurplus"]),
		"CEM did not isolate the appended coordinate", fails)
	var legacy_rng: Rng = Rng.new(216)
	var mag_mu: Array[float] = []
	var mag_sd: Array[float] = []
	for _i: int in range(legacy_paths.size()):
		mag_mu.append(0.0)
		mag_sd.append(0.35)
	Cem._sample(legacy_rng, mag_mu, mag_sd, Cem.LOG_LO, Cem.LOG_HI)
	var thr_mu: Array[float] = []
	var thr_sd: Array[float] = []
	for i: int in range(Cem.THR.size()):
		thr_mu.append((Cem.THR_LO[i] + Cem.THR_HI[i]) / 2.0)
		thr_sd.append(0.15 * (Cem.THR_HI[i] - Cem.THR_LO[i]))
	Cem._sample_thr(legacy_rng, thr_mu, thr_sd)
	var legacy_state: int = legacy_rng.get_state()
	_check(legacy_state == 1113060262, "legacy CEM consumption changed", fails)
	var extension_rng: Rng = Policy.extension_rng("cem", [216, 0])
	extension_rng.next()
	_check(legacy_rng.get_state() == legacy_state,
		"extension stream consumed the legacy CEM stream", fails)


static func _null_card_comparator(fails: Array[String]) -> void:
	var candidate: ContentDB = ContentDB.load_full(false)
	var null_content: ContentDB = ContentDB.load_full(false)
	null_content.cards.erase("facetBurst")
	for tier_v: Variant in null_content.card_pools:
		var pool: Array = null_content.card_pools[str(tier_v)]
		pool.erase("facetBurst")
	var candidate_run: RunState = RunState.new_run(candidate, 42193, "null-card", {"aspect": 0})
	var null_run: RunState = RunState.new_run(null_content, 42193, "null-card", {"aspect": 0})
	var candidate_game: GlassvowGame = GlassvowGame.new(candidate, candidate_run)
	var null_game: GlassvowGame = GlassvowGame.new(null_content, null_run)
	for game: GlassvowGame in [candidate_game, null_game]:
		game.apply({"t": "startCombat", "enemies": ["sporeling"], "kind": "normal"})
		game.cb.queue.clear()
		game.cb.hand.clear()
		var strike: CardInst = CardInst.new(game.run.next_uid(), &"strike", false)
		game.cb.hand.append(strike)
		game.cb.player.energy = 3
		game.rules.play_card(game.run, game.cb, strike.uid, 0)
	_check(not null_content.cards.has("facetBurst")
		and not RewardRules.new(null_content).card_pool(null_run, "uncommon").has("facetBurst"),
		"explicit null-card comparator retained the destination", fails)
	_check(JSON.stringify(candidate_game.cb.queue) == JSON.stringify(null_game.cb.queue)
		and candidate_game.run.rng_state() == null_game.run.rng_state(),
		"absent destination changed the unchanged current-main combat/RNG prefix", fails)
	_check(Observer.observe(null_game.cb.queue, 0).is_empty(),
		"null-card comparator manufactured destination or H11 activation", fails)


static func _h11_observer(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_check(Observer.VERSION == "p9-w0-v2-h11-player-dusk-enemy-smolder-observer-v1",
		"H11 observer identity drifted", fails)
	_check(content.card_pools.get("common", []).has("venomStrike")
		and str(content.cards.get("venomStrike", {}).get("aspect", "")).is_empty(),
		"H11 repair altered shared-pool Smolder content", fails)
	var events: Array = [
		{"t": "play", "id": "venomStrike"},
		{"t": "status", "who": 0, "id": "poison", "n": 4},
		{"t": "die", "idx": 0},
		{"t": "status", "who": 1, "id": "poison", "n": 4},
		{"t": "smolderJump", "from": 0, "to": 1, "n": 4},
		{"t": "play", "id": "toxicMist"},
		{"t": "status", "who": 1, "id": "poison", "n": 3},
		{"t": "art", "id": "ashfall"},
		{"t": "status", "who": 1, "id": "poison", "n": 3},
		{"t": "play", "id": "annihilate"},
		{"t": "status", "who": "player", "id": "poison", "n": 3},
	]
	var before: String = JSON.stringify(events)
	var dusk_counts: Dictionary = Observer.observe(events, 0)
	var ash_counts: Dictionary = Observer.observe(events, 1)
	_check(_ji(dusk_counts.get(Observer.COUNT_KEY, 0)) == 2,
		"H11 observer did not count only player-card-origin Dusk enemy Smolder", fails)
	_check(ash_counts.is_empty(), "H11 observer counted an Ash application", fails)
	_check(JSON.stringify(events) == before, "H11 observer wrote its event input", fails)
	var game: GlassvowGame = _game(0, "ward-observer")
	var save_before: String = JSON.stringify(game.run.to_save_dict())
	var queue_before: String = JSON.stringify(game.cb.queue)
	var rng_before: int = game.run.rng_state()
	Observer.observe(game.cb.queue, game.run.aspect)
	_check(JSON.stringify(game.run.to_save_dict()) == save_before
		and JSON.stringify(game.cb.queue) == queue_before and game.run.rng_state() == rng_before,
		"H11 observer wrote state or consumed RNG", fails)


static func _locale_fixture(fails: Array[String]) -> void:
	var expected: Dictionary = {
		"res://locale/en.json": ["Facet Burst", "Spend #10# Ward. Deal @20@ damage.",
			"Spend #10# Ward. Deal @30@ damage."],
		"res://locale/zh-Hant.json": ["璃面破裂", "花費 #10# 點護光。造成 @20@ 點傷害。",
			"花費 #10# 點護光。造成 @30@ 點傷害。"],
	}
	for path: String in expected:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(raw) != TYPE_DICTIONARY:
			fails.append("ward cash-out: locale did not parse: %s" % path)
			continue
		var root: Dictionary = raw
		var row: Dictionary = root.get("content", {}).get("cards", {}).get("facetBurst", {})
		var values: Array = expected[path]
		_check([row.get("name"), row.get("text"), row.get("textUp")] == values,
			"locale hydration row diverged in %s" % path, fails)


static func _outcome_digest_excludes_observation(fails: Array[String]) -> void:
	var first: Dictionary = {"outcome": "win", "packageEvents": {"wardSpend": 1,
		Observer.COUNT_KEY: 1}}
	var second: Dictionary = {"outcome": "win", "packageEvents": {"wardSpend": 99,
		Observer.COUNT_KEY: 99}}
	_check(Sim.outcome_digest(first) == Sim.outcome_digest(second),
		"wardSpend observation entered outcomeDigest", fails)
