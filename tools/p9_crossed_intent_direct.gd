extends SceneTree
## Raw-only research emitter for p9-crossed-intent-direct-v2.

const PROTOCOL_ID: String = "p9-crossed-intent-direct-v2"
const SOURCE_HEAD: String = "c28ae38824f7ba2168b573002ab8b90dadd5bde1"
const ANCHORS: Array[String] = [
	"A01-natural-third-turn-consume", "A02-natural-explicit-decline",
	"A03-stable-tie-and-own-modifiers", "A04-equal-threat-null",
	"A05-impure-move-null", "A06-staggered-at-commit-null", "A07-ash-exact-null",
	"A08-death-before-consume", "A09-death-after-consume", "A10-upgraded-consumer",
	"A11-stagger-before-consume", "A12-stagger-after-consume", "A13-combat-end-clear",
	"A14-ramp-vow-omen-modifiers", "A15-warding-charm-modifier", "A16-defeat-clear",
]
const ARMS: Array[String] = ["O", "P", "C", "PC"]
const SEEDS: Array[int] = [
	17500, 17513, 17532, 17533, 17534, 17535, 17536, 17537,
	17538, 17539, 17540, 17541, 17542, 17543, 17544, 17545,
]


func _initialize() -> void:
	var args: Dictionary = _args()
	var output: String = str(args.get("output", ""))
	var result: Dictionary = {
		"schemaVersion": 1, "protocol": {}, "runtime": {}, "rows": [],
		"predicateProbes": [], "acquisition": {}, "mechanicalFault": null, "errors": [],
	}
	if output.is_empty() or str(args.get("protocol", "")).is_empty():
		_fail(result, "ARGS", "--protocol and --output are required", output)
		return
	var protocol_path: String = str(args["protocol"])
	var protocol_text: String = FileAccess.get_file_as_string(protocol_path)
	var protocol_v: Variant = JSON.parse_string(protocol_text)
	if typeof(protocol_v) != TYPE_DICTIONARY or str(protocol_v.get("id", "")) != PROTOCOL_ID:
		_fail(result, "PROTOCOL", "protocol is missing, malformed, or has the wrong id", output)
		return
	result["protocol"] = {"id": PROTOCOL_ID, "path": protocol_path,
		"sha256": _sha_bytes(protocol_text.to_utf8_buffer())}
	result["runtime"] = _runtime_provenance()
	var content: ContentDB = ContentDB.load_full(false)
	if content == null:
		_fail(result, "CONTENT", "full content did not load", output)
		return
	result["predicateProbes"] = _predicate_probes(content)
	result["acquisition"] = _acquisition()
	var rows: Array = []
	for anchor_i: int in range(ANCHORS.size()):
		for arm_i: int in range(ARMS.size()):
			rows.append(_row(content, anchor_i, arm_i))
	result["rows"] = rows
	_write(output, result)
	quit(0)


func _args() -> Dictionary:
	var out: Dictionary = {}
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < argv.size():
		if argv[i] == "--protocol" or argv[i] == "--output":
			if i + 1 < argv.size():
				out[argv[i].trim_prefix("--")] = argv[i + 1]
			i += 2
		else:
			i += 1
	return out


func _row(content: ContentDB, anchor_i: int, arm_i: int) -> Dictionary:
	var anchor: String = ANCHORS[anchor_i]
	var arm: String = ARMS[arm_i]
	var seed: int = SEEDS[anchor_i]
	var producer: bool = arm == "P" or arm == "PC"
	var consumer: bool = arm == "C" or arm == "PC"
	var aspect: int = 1 if anchor_i == 6 else 0
	var run: RunState = RunState.new_run(content, seed, "crossed-%d" % seed,
		{"aspect": aspect, "reveals": []})
	if producer:
		run.player.relics.append("crossedThreads")
	if anchor_i == 13:
		run.vow = 2
		run.omens = ["thinGlass"]
	if anchor_i == 14:
		run.player.relics.append("wardingCharm")
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var natural: bool = anchor_i <= 1
	if natural:
		run.player.deck = []
		game.apply({"t": "startCombat", "enemies": ["duskfang", "sporeling"], "kind": "normal"})
		game.apply({"t": "endTurn"})
	else:
		game.cb = _direct_combat(content, anchor_i)
	var cb: CombatState = game.cb
	var allocated_candidate: CardInst = CardInst.new(run.next_uid(), &"crossedIntent", anchor_i == 9)
	var candidate: CardInst = allocated_candidate if consumer else null
	var invariant_card: CardInst = _invariant_card(anchor_i)
	var cursor: int = 0
	var commands: Array = []
	var checkpoints: Array = []
	checkpoints.append(_checkpoint(game, "beforeCommitment", cursor))
	cursor = cb.queue.size()
	if natural:
		game.apply({"t": "endTurn"})
	else:
		game.rules._form_crossed_link(run, cb)
	checkpoints.append(_checkpoint(game, "afterCommitment", cursor))
	cursor = cb.queue.size()
	if consumer:
		cb.hand.append(candidate)
	if invariant_card != null:
		cb.hand.append(invariant_card)
	cb.player.energy = maxi(cb.player.energy, 3)
	var setup_snapshot: Dictionary = _setup(game, natural, anchor_i)
	var playable: Variant = game.rules.can_play(run, cb, candidate, null) if candidate != null else null
	checkpoints.append(_checkpoint(game, "afterPlayabilityProbe", cursor,
		{"playable": playable}))
	cursor = cb.queue.size()
	var planned: Array = _commands(anchor_i, arm, candidate, invariant_card)
	var command_ordinal: int = 0
	for cmd_v: Variant in planned:
		var cmd: Dictionary = cmd_v
		command_ordinal += 1
		var attempted: bool = true
		var events: Array[Dictionary] = game.apply(cmd)
		var accepted: Variant = game.last_ret if str(cmd.get("t", "")) == "playCard" else null
		commands.append({"ordinal": command_ordinal, "command": cmd.duplicate(true),
			"type": str(cmd.get("t", "")), "attempted": attempted,
			"accepted": accepted, "returnValue": game.last_ret, "events": events.duplicate(true)})
		checkpoints.append(_checkpoint(game,
			"afterCommand:%d:%s" % [command_ordinal, str(cmd.get("t", ""))], cursor,
			{"commandOrdinal": command_ordinal}))
		cursor = cb.queue.size()
	checkpoints.append(_checkpoint(game, "beforeEnemyPhase", cursor))
	cursor = cb.queue.size()
	var hp_before: Array = cb.enemies.map(func(e: EnemyCombatant) -> int: return e.hp)
	var history_before: Array = cb.enemies.map(func(e: EnemyCombatant) -> Array: return e.last_moves.duplicate())
	var attempted_end: bool = not cb.over
	var enemy_events: Array = game.apply({"t": "endTurn"}) if attempted_end else []
	command_ordinal += 1
	commands.append({"ordinal": command_ordinal, "command": {"t": "endTurn"},
		"type": "endTurn", "attempted": attempted_end, "accepted": null,
		"returnValue": game.last_ret if attempted_end else null,
		"events": enemy_events.duplicate(true)})
	var action_i: int = 0
	var action_trace: Array = []
	for event_i: int in range(enemy_events.size()):
		var event: Dictionary = enemy_events[event_i]
		if event.get("t") == EventTypes.ENEMY_ACT or event.get("t") == EventTypes.STAGGERED:
			action_i += 1
			var action_enemy: int = int(float(str(event.get("idx", -1))))
			action_trace.append({"actionOrdinal": action_i, "eventIndex": event_i,
				"eventType": str(event.get("t", "")), "enemyIndex": action_enemy})
	checkpoints.append(_checkpoint(game, "afterCommand:%d:endTurn" % command_ordinal,
		cursor, {"commandOrdinal": command_ordinal}))
	cursor = cb.queue.size()
	checkpoints.append(_checkpoint(game, "afterEnemyPhase", cursor,
		{"actionOrdinal": action_i, "enemyIndex": _last_action_enemy(enemy_events),
			"hpBefore": hp_before, "historyBefore": history_before,
			"actionTrace": action_trace}))
	cursor = cb.queue.size()
	checkpoints.append(_checkpoint(game, "afterFreshIntents", cursor))
	return {
		"rowId": 90600 + anchor_i * 4 + arm_i, "seed": seed, "anchorId": anchor,
		"arm": arm, "factors": {"P": producer, "C": consumer},
		"setup": setup_snapshot, "playability": playable,
		"commands": commands, "checkpoints": checkpoints,
	}


func _direct_combat(content: ContentDB, anchor_i: int) -> CombatState:
	var specs: Array = [["sporeling", "spit"], ["thornling", "prick"]]
	if anchor_i == 2:
		specs = [["sporeling", "spit"], ["thornling", "prick"], ["sporeling", "spit"]]
	elif anchor_i == 3:
		specs = [["sporeling", "spit"], ["sporeling", "spit"]]
	elif anchor_i == 4:
		specs = [["gloomslime", "ooze"], ["sporeling", "spit"]]
	var cb: CombatState = CombatState.new()
	cb.turn = 2
	cb.player.hp = 64
	cb.player.max_hp = 64
	cb.player.energy_max = 3
	cb.player.energy = 3
	if anchor_i == 15:
		cb.player.hp = 1
	for i: int in range(specs.size()):
		var spec: Array = specs[i]
		var e: EnemyCombatant = EnemyCombatant.new()
		e.key = StringName(str(spec[0]))
		e.def = content.enemy(e.key)
		e.name = str(e.def.get("name", ""))
		e.idx = i
		e.max_hp = 20
		e.hp = 1 if anchor_i == 12 or ([7, 8].has(anchor_i) and i == 0) else 20
		e.facet_max = 2 if [10, 11].has(anchor_i) else 4
		e.move_key = StringName(str(spec[1]))
		if anchor_i == 5 and i == 1:
			e.staggered = true
		if anchor_i == 2 and i == 0:
			e.statuses["str"] = 2
		if anchor_i == 2 and i == 1:
			e.statuses["weak"] = 1
		if anchor_i == 13 and i == 0:
			e.flags["rampBonus"] = 2
		cb.enemies.append(e)
	return cb


func _commands(anchor_i: int, arm: String, candidate: CardInst,
		invariant_card: CardInst) -> Array:
	var out: Array = []
	var consume_pc_only: bool = [0, 2, 9].has(anchor_i)
	var consume_both: bool = [7, 8, 10, 11, 12, 13, 14, 15].has(anchor_i)
	var consume_before_invariant: bool = [8, 11, 12].has(anchor_i)
	var should_consume: bool = candidate != null and ((consume_pc_only and arm == "PC") or consume_both)
	if should_consume and consume_before_invariant:
		out.append({"t": "playCard", "uid": candidate.uid, "target": null})
	if invariant_card != null:
		out.append({"t": "playCard", "uid": invariant_card.uid,
			"target": null if invariant_card.id == &"cleave" else 0})
	if should_consume and not consume_before_invariant:
		out.append({"t": "playCard", "uid": candidate.uid, "target": null})
	return out


func _invariant_card(anchor_i: int) -> CardInst:
	var id: StringName = &""
	if [7, 8].has(anchor_i): id = &"strike"
	if [10, 11].has(anchor_i): id = &"chisel"
	if anchor_i == 12: id = &"cleave"
	return null if id == &"" else CardInst.new(99000 + anchor_i, id, false)


func _checkpoint(game: GlassvowGame, name: String, cursor: int, extra: Dictionary = {}) -> Dictionary:
	var cb: CombatState = game.cb
	var events: Array = []
	for i: int in range(cursor, cb.queue.size()):
		events.append(cb.queue[i].duplicate(true))
	var enemies: Array = []
	var effective: Array = []
	for e: EnemyCombatant in cb.enemies:
		enemies.append({"key": String(e.key), "variantId": String(e.variant_id), "idx": e.idx,
			"name": e.name, "hp": e.hp, "maxHp": e.max_hp, "block": e.block,
			"statuses": e.statuses.duplicate(true), "staggered": e.staggered,
			"lastMoves": e.last_moves.duplicate(), "moveKey": String(e.move_key),
			"elite": e.elite, "boss": e.boss, "facetMax": e.facet_max,
			"chips": e.chips, "flags": e.flags.duplicate(true), "resolvedDef": e.def.duplicate(true)})
		effective.append({"idx": e.idx, "originalMoveKey": String(e.move_key),
			"effectiveMove": game.rules.effective_enemy_move(cb, e).duplicate(true),
			"effectiveDamagePreview": game.rules.preview_enemy_dmg(cb, e, game.run)})
	var out: Dictionary = {"name": name, "commandOrdinal": null, "actionOrdinal": null,
		"enemyIndex": null, "combatProjection": cb.to_dict(),
		"combatOmitted": {"queue": cb.queue.duplicate(true), "emberCap": cb.ember_cap,
			"artUsedTurn": cb.art_used_turn, "kindledTurn": cb.kindled_turn,
			"kindlesThisTurn": cb.kindles_this_turn, "pendingChipsActive": cb.pending_chips_active,
			"pendingChips": cb.pending_chips.duplicate(true), "countersPlayed": cb.counters_played,
			"countersAttacks": cb.counters_attacks, "firstCardPlayed": cb.first_card_played,
			"hpLost": cb.hp_lost, "prismProcd": cb.prism_procd,
			"finaleHandoff": cb.finale_handoff, "crossedIntent": cb.crossed_intent.duplicate(true)},
		"enemiesFull": enemies, "runSave": game.run.to_save_dict(), "runUid": game.run.uid,
		"rngState": game.run.rng_state(), "eventDelta": events,
		"effectiveIntents": effective, "liveLink": game.rules.live_crossed_link(cb)}
	out.merge(extra, true)
	return out


func _setup(game: GlassvowGame, natural: bool, anchor_i: int) -> Dictionary:
	var cb: CombatState = game.cb
	var enemies: Array = []
	for e: EnemyCombatant in cb.enemies:
		enemies.append({"id": String(e.key), "moveKey": String(e.move_key), "hp": e.hp,
			"maxHp": e.max_hp, "facetMax": e.facet_max, "chips": e.chips,
			"staggered": e.staggered, "statuses": e.statuses.duplicate(true),
			"flags": e.flags.duplicate(true)})
	return {"mode": "natural" if natural else "direct", "aspect": game.run.aspect,
		"turn": cb.turn, "enemies": enemies,
		"player": {"hp": cb.player.hp, "maxHp": cb.player.max_hp,
			"energy": cb.player.energy, "statuses": cb.player.statuses.duplicate(true)},
		"vow": game.run.vow, "omens": game.run.omens.duplicate(),
		"relics": game.run.player.relics.duplicate(),
		"hand": cb.hand.map(func(c: CardInst) -> Dictionary: return {"id": String(c.id), "up": c.up}),
		"invariantCards": ["strike"] if [7, 8].has(anchor_i) else (
			["chisel"] if [10, 11].has(anchor_i) else (["cleave"] if anchor_i == 12 else []))}


func _predicate_probes(content: ContentDB) -> Array:
	var specs: Array = [["block", "gloomslime", "harden"], ["heal", "deepmaw", "swallow"],
		["fx", "gloomslime", "ooze"], ["addCards", "rootheart", "entangle"],
		["ramp", "chaosHound", "bite"]]
	var rules: CombatRules = CombatRules.new(content)
	var out: Array = []
	for spec_v: Variant in specs:
		var spec: Array = spec_v
		var e: EnemyCombatant = _probe_enemy(content, str(spec[1]), str(spec[2]))
		out.append({"field": spec[0], "enemy": spec[1], "move": spec[2],
			"pairedPureMove": "sporeling/spit", "exchangeable": not rules._exchangeable_move(e).is_empty()})
	return out


func _probe_enemy(content: ContentDB, id: String, move: String) -> EnemyCombatant:
	var e: EnemyCombatant = EnemyCombatant.new()
	e.key = StringName(id); e.def = content.enemy(e.key); e.idx = 0
	e.hp = 20; e.max_hp = 20; e.move_key = StringName(move)
	return e


func _acquisition() -> Dictionary:
	var queries: Array = []
	for path: String in ["base", "unlockAppend", "candidateOff", "preCandidate"]:
		for aspect: int in range(2):
			var content: ContentDB = ContentDB.load_full(false)
			var run: RunState = RunState.new_run(content, 18000 + aspect, "acq-%s-%d" % [path, aspect],
				{"aspect": aspect, "reveals": null})
			if path != "base":
				content.card_pools["common"].erase("crossedIntent")
				content.relic_pools["uncommon"].erase("crossedThreads")
			if path == "unlockAppend":
				run.unlocks = ["card:crossedIntent", "relic:crossedThreads"]
			elif path == "candidateOff" or path == "preCandidate":
				content.cards.erase("crossedIntent"); content.relics.erase("crossedThreads")
				run.unlocks = []
			var rewards: RewardRules = RewardRules.new(content)
			for query_v: Variant in [["card", "common", "crossedIntent"],
					["relic", "uncommon", "crossedThreads"]]:
				var query: Array = query_v
				var kind: String = str(query[0])
				var tier: String = str(query[1])
				var identity: String = str(query[2])
				var before: int = run.rng_state()
				var values: Array = rewards.card_pool(run, tier) if kind == "card" \
					else rewards.relic_pool(run, tier)
				var source_pool: Array = content.card_pools.get(tier, []) if kind == "card" \
					else content.relic_pools.get(tier, [])
				queries.append({"path": path, "aspect": aspect, "poolKind": kind,
					"tier": tier, "identity": identity, "contents": values.duplicate(),
					"rngBefore": before, "rngAfter": run.rng_state(),
					"sourceMembership": {"definitionIndex": content.cards.keys().find(identity) \
						if kind == "card" else content.relics.keys().find(identity),
						"poolIndices": _indices(source_pool, identity),
						"resultIndices": _indices(values, identity),
						"unlockIndices": _indices(run.unlocks, "%s:%s" % [kind, identity])}})
	return {"queries": queries}


func _indices(values: Array, wanted: String) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(values.size()):
		if str(values[i]) == wanted: out.append(i)
	return out


func _runtime_provenance() -> Dictionary:
	var head_out: Array[String] = []
	OS.execute("git", ["rev-parse", "HEAD"], head_out, true)
	var actual_head: String = "".join(head_out).strip_edges()
	var status_out: Array[String] = []
	OS.execute("git", ["status", "--porcelain=v1"], status_out, true)
	var status: String = "".join(status_out)
	var staged: Array[String] = []
	OS.execute("git", ["diff", "--cached", "--name-only"], staged, true)
	var diff_out: Array[String] = []
	OS.execute("git", ["diff", "--cached", "--binary", "--full-index", "--no-ext-diff",
		SOURCE_HEAD, "--"], diff_out, true)
	var staged_diff: String = "".join(diff_out)
	var files_out: Array[String] = []
	OS.execute("git", ["ls-files", "--cached", "--others", "--exclude-standard"], files_out, true)
	var paths: PackedStringArray = "\n".join(files_out).split("\n", false)
	paths.sort()
	var tree: PackedByteArray = PackedByteArray()
	for path: String in paths:
		if FileAccess.file_exists(path):
			tree.append_array((path + "\t" + _sha_bytes(FileAccess.get_file_as_bytes(path)) + "\n").to_utf8_buffer())
	var status_lines: PackedStringArray = status.split("\n", false)
	var has_untracked: bool = false
	var has_unstaged: bool = false
	for line: String in status_lines:
		has_untracked = has_untracked or line.begins_with("??")
		has_unstaged = has_unstaged or (line.length() >= 2 and line[1] != " ")
	return {"head": actual_head, "sourceHeadExpected": SOURCE_HEAD,
		"godotVersion": Engine.get_version_info(),
		"treeSha256": _sha_bytes(tree),
		"emitterSha256": _sha_bytes(FileAccess.get_file_as_bytes("res://tools/p9_crossed_intent_direct.gd")),
		"diffSha256": _sha_bytes(staged_diff.to_utf8_buffer()),
		"statusPorcelain": status,
		"untrackedClean": not has_untracked, "unstagedClean": not has_unstaged,
		"stagedPaths": "\n".join(staged).split("\n", false)}


func _last_action_enemy(events: Array) -> Variant:
	for i: int in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[i]
		if event.get("t") == EventTypes.ENEMY_ACT or event.get("t") == EventTypes.STAGGERED:
			return event.get("idx")
	return null


func _sha_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()


func _write(path: String, result: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t") + "\n")


func _fail(result: Dictionary, code: String, message: String, output: String) -> void:
	result["mechanicalFault"] = {"code": code, "rowsWritten": 0,
		"scientificPayloadInspected": false}
	result["errors"] = [message]
	if not output.is_empty(): _write(output, result)
	push_error("%s: %s" % [code, message])
	quit(2)
