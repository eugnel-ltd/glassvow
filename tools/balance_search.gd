extends RefCounted
## Flame readout 8's search player: the same pilot off the board (routes, rewards,
## shops, potions), a stronger player on it. Each turn it enumerates the legal
## lines of plays, kindles and the Art on a detached copy of the fight, through
## the combat rules' own functions, and plays the line its one-turn evaluation
## ranks highest: HP spared this enemy phase, damage, kills, Stagger, and the
## ways' verbs (Shatter, Kindle, Cracked). It reads no build commitment, so every
## arm plays alike (flame lock §11).
##
## Honest play: a line ends at the play that draws or rolls the run RNG, so the
## search never reads a card it has not drawn; the player re-plans once that
## play has resolved. Intents and the blow forecast are the ones the greedy pilot
## already reads. The baseline's own turn is always a candidate: the search plays
## it whenever no searched line beats it, so a turn never scores below greedy's.
const Pilot: GDScript = preload("res://tools/balance_pilot.gd")
const VERSION: String = "s1"
## Lines evaluated per plan (a line is any prefix of plays: the turn may end there).
const LINE_CAP: int = 2000
## Re-plans per turn after a draw; a guard, never reached in practice.
const REPLAN_GUARD: int = 16
const WIN: float = 1.0e6
const DEATH: float = -1.0e6
## The evaluation's own weights, in the policy's currency (one point is one point
## of damage dealt at `combat.loss`). HP and damage reuse the policy's weights;
## these four are the search's, the same for every arm.
const KILL: float = 20.0
const STAGGER: float = 15.0
## Each Shatter, Kindle and stack of Cracked this turn: the ways' verbs (lock §6).
const EXPRESSION: float = 2.0
## The share of a status's catalogue worth that one turn's setup counts.
const SETUP_SHARE: float = 0.5
const EXPRESSION_STATS: Array[String] = ["shatters", "kindles", "cracked"]
## Foe statuses that weaken the foe (setup on the board), and hero statuses that
## harm the hero (never counted as setup).
const FOE_SETUP: Array[String] = ["vulnerable", "weak", "poison"]
const HERO_HARM: Array[String] = ["vulnerable", "weak", "frail", "poison"]

## Telemetry for tests and the readout: lines evaluated and plans made since
## `reset_counters`, plans the baseline's turn won, and actions refused live.
static var lines: int = 0
static var plans: int = 0
static var greedy_plans: int = 0
static var refused: int = 0


## A fight as some line of the turn leaves it: a detached run and combat, and
## whether the line's last action drew or rolled the RNG (the line ends there).
class Position:
	var run: RunState
	var cb: CombatState
	var revealed: bool = false

	func _init(run_state: RunState, combat: CombatState) -> void:
		run = run_state
		cb = combat


## One turn's search: the turn's start (read, never written) and the best line.
class Turn:
	var rules: CombatRules
	var content: ContentDB
	var start: Position
	var start_stats: Dictionary = {}
	var start_blow: int = 0
	var seen: Dictionary = {}
	var lines: int = 0
	var best: Array[Dictionary] = []
	var value: float = -INF
	var reopen: bool = false


## What a turn's search decided: the line, its value, whether it ended at a draw
## (re-plan once it resolves), and whether the baseline's turn won instead.
class Plan:
	var actions: Array[Dictionary] = []
	var value: float = -INF
	var reopen: bool = false
	var greedy: bool = false
	var lines: int = 0


static func reset_counters() -> void:
	lines = 0
	plans = 0
	greedy_plans = 0
	refused = 0


## One combat turn, potions first as the greedy pilot drinks them.
static func play_turn(game: GlassvowGame) -> void:
	Pilot._use_potions(game)
	for _guard: int in range(REPLAN_GUARD):
		if game.cb.over:
			return
		var plan: Plan = plan_turn(game)
		if plan.greedy:
			Pilot.play_hand(game)
			return
		for action: Dictionary in plan.actions:
			if not execute(game, action):
				refused += 1
				return
			if game.cb.over:
				return
		if not plan.reopen or plan.actions.is_empty():
			return


## The best line from the live state, without touching it.
static func plan_turn(game: GlassvowGame) -> Plan:
	plans += 1
	var turn: Turn = Turn.new()
	turn.rules = game.rules
	turn.content = game.content
	turn.start = Position.new(game.run, game.cb)
	turn.start_stats = game.run.stats.duplicate()
	turn.start_blow = _blow(game.rules, game.run, game.cb)
	var empty: Array[Dictionary] = []
	_search(turn, _copy(turn.start), empty)
	var sandbox: GlassvowGame = GlassvowGame.new(game.content, clone_run(game.run))
	sandbox.cb = clone_combat(game.cb)
	Pilot.play_hand(sandbox)
	var baseline: float = evaluate(turn, Position.new(sandbox.run, sandbox.cb))
	var plan: Plan = Plan.new()
	plan.greedy = baseline >= turn.value
	plan.actions = turn.best
	plan.value = maxf(baseline, turn.value)
	plan.reopen = turn.reopen
	plan.lines = turn.lines
	if plan.greedy:
		greedy_plans += 1
	lines += turn.lines
	return plan


## Plays one planned action on the live game; false when it is not legal there.
static func execute(game: GlassvowGame, action: Dictionary) -> bool:
	if not legal(game.rules, game.run, game.cb, action):
		return false
	game.apply(action)
	return true


static func legal(rules: CombatRules, run: RunState, cb: CombatState, action: Dictionary) -> bool:
	var uid: int = _int(action.get("uid", -1))
	match str(action["t"]):
		"playCard":
			var card: CardInst = _in_hand(cb, uid)
			return card != null and rules.can_play(run, cb, card, action["target"])
		"kindleFromHand":
			return rules.can_kindle(run, cb, _in_hand(cb, uid))
		"useArt":
			return rules.can_use_art(run, cb)
	return false


## Depth-first over every line: each position is evaluated as the turn's end,
## then extended by each legal action, identical cards and transposed orders once.
static func _search(turn: Turn, at: Position, path: Array[Dictionary]) -> void:
	if turn.lines >= LINE_CAP:
		return
	turn.lines += 1
	var value: float = evaluate(turn, at)
	if value > turn.value:
		turn.value = value
		turn.best = path.duplicate()
		turn.reopen = at.revealed
	if at.revealed or at.cb.over:
		return
	for action: Dictionary in _actions(turn, at):
		var child: Position = _copy(at)
		if not _apply(turn.rules, child, action):
			continue
		var key: String = _key(child)
		if turn.seen.has(key):
			continue
		turn.seen[key] = true
		var next: Array[Dictionary] = path.duplicate()
		next.append(action)
		_search(turn, child, next)


## The position's legal actions: each distinct card at each legal target, the
## kindle the greedy pilot would choose, and the Art.
static func _actions(turn: Turn, at: Position) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tried: Dictionary = {}
	for card: CardInst in at.cb.hand:
		var signature: String = _signature(card)
		if tried.has(signature):
			continue
		tried[signature] = true
		var targets: Array[Variant] = [null]
		if str(turn.rules.card_data(card).get("target", "")) == "enemy":
			targets.clear()
			for e: EnemyCombatant in at.cb.living_enemies():
				targets.append(e.idx)
		for target: Variant in targets:
			if turn.rules.can_play(at.run, at.cb, card, target):
				out.append({"t": "playCard", "uid": card.uid, "target": target})
	var kindle: CardInst = Pilot.worst_card(at.run, turn.content, at.cb.hand, true)
	if kindle != null and turn.rules.can_kindle(at.run, at.cb, kindle):
		out.append({"t": "kindleFromHand", "uid": kindle.uid})
	if turn.rules.can_use_art(at.run, at.cb):
		out.append({"t": "useArt"})
	return out


## The same dispatch as GlassvowGame.apply for the three commands a turn plays.
## Marks the position revealed when the action drew or moved the run RNG.
static func _apply(rules: CombatRules, at: Position, action: Dictionary) -> bool:
	if not legal(rules, at.run, at.cb, action):
		return false
	var rng_before: int = at.run.rng_state()
	var draw_before: int = at.cb.draw.size()
	var uid: int = _int(action.get("uid", -1))
	match str(action["t"]):
		"playCard":
			rules.play_card(at.run, at.cb, uid, action["target"])
		"kindleFromHand":
			rules.kindle_from_hand(at.run, at.cb, uid)
		"useArt":
			rules.use_art(at.run, at.cb)
	at.revealed = at.run.rng_state() != rng_before or at.cb.draw.size() != draw_before
	return true


## The turn as it would end here, scored against the turn's start.
static func evaluate(turn: Turn, at: Position) -> float:
	var cb: CombatState = at.cb
	var start: CombatState = turn.start.cb
	if cb.over:
		return WIN + float(cb.player.hp) if cb.result == "win" else DEATH
	var left: int = cb.player.hp - _blow(turn.rules, at.run, cb)
	if left <= 0:
		return DEATH * 0.5 + float(left)
	var urgent: bool = turn.start_blow * 2 >= start.player.hp
	var value: float = -float(start.player.hp - left) \
		* Pilot._w("combat", "blockUrgent" if urgent else "blockNormal")
	var dusk: bool = at.run.aspect == 0
	for e: EnemyCombatant in cb.enemies:
		var before: EnemyCombatant = start.enemies[e.idx]
		if before.hp <= 0:
			continue
		value += float(before.hp - maxi(0, e.hp)) * Pilot._w("combat", "loss")
		if e.hp <= 0:
			value += KILL
			continue
		if e.staggered and not before.staggered:
			value += STAGGER
		if e.chips > before.chips:
			value += Pilot._w("combat", "chip") * float(e.chips - before.chips) / float(e.facet_max)
		for id: String in FOE_SETUP:
			value += _gain(id, before.statuses, e.statuses, dusk)
	for id_v: Variant in cb.player.statuses:
		var id: String = str(id_v)
		if not HERO_HARM.has(id):
			value += _gain(id, start.player.statuses, cb.player.statuses, dusk)
	value += float(cb.embers - start.embers) * Pilot._w("card", "ember")
	for key: String in EXPRESSION_STATS:
		value += EXPRESSION * float(_int(at.run.stats.get(key, 0)) - _int(turn.start_stats.get(key, 0)))
	return value


## SETUP_SHARE of the catalogue worth of the stacks a status gained this turn.
static func _gain(id: String, before: Dictionary, after: Dictionary, dusk: bool) -> float:
	var gained: int = _int(after.get(id, 0)) - _int(before.get(id, 0))
	return SETUP_SHARE * Pilot._status_value(id, gained, dusk) if gained > 0 else 0.0


## The HP the coming enemy phase would take: the greedy pilot's forecast less Ward.
static func _blow(rules: CombatRules, run: RunState, cb: CombatState) -> int:
	var incoming: int = Pilot.incoming_on(rules, run, cb)
	return maxi(0, incoming - cb.player.block)


static func _int(value: Variant) -> int:
	return int(float(str(value)))


static func _copy(at: Position) -> Position:
	return Position.new(clone_run(at.run), clone_combat(at.cb))


static func _in_hand(cb: CombatState, uid: int) -> CardInst:
	for card: CardInst in cb.hand:
		if card.uid == uid:
			return card
	return null


static func _signature(card: CardInst) -> String:
	return "%s/%d/%d" % [card.id, int(card.up), card.bonus]


## Everything a later action or the evaluation reads, so two orders that reach
## the same position are searched once.
static func _key(at: Position) -> String:
	var cb: CombatState = at.cb
	var hand: Array[String] = []
	for card: CardInst in cb.hand:
		hand.append(_signature(card))
	hand.sort()
	var foes: Array = []
	for e: EnemyCombatant in cb.enemies:
		foes.append([e.hp, e.block, e.chips, e.facet_max, e.staggered, e.move_key, e.statuses, e.flags])
	var stats: Array[int] = []
	for key: String in ["shatters", "kindles", "cracked", "embersSpent", "embersGained"]:
		stats.append(_int(at.run.stats.get(key, 0)))
	return str([hand, foes, stats, cb.player.hp, cb.player.block, cb.player.energy,
		cb.player.statuses, cb.embers, cb.kindles_this_turn, cb.kindled_turn, cb.art_used_turn,
		cb.first_card_played, cb.counters_played, cb.counters_attacks, cb.first_gain_turn,
		cb.draw.size(), cb.prism_procd, at.run.rng_state(), at.run.player.potions])


## A detached copy of the run state the combat rules read or write; the rest is
## shared read-only (content-shaped fields the rules never write).
static func clone_run(run: RunState) -> RunState:
	var out: RunState = RunState.new()
	out.seed = run.seed
	out.run_id = run.run_id
	out.rng = Rng.new(run.rng_state())
	out.act = run.act
	out.aspect = run.aspect
	out.vow = run.vow
	out.art = run.art
	out.uid = run.uid
	out.omens = run.omens
	out.shards = run.shards
	out.monument = run.monument
	out.unlocks = run.unlocks.duplicate(true)
	out.quests = run.quests.duplicate(true)
	out.quest_scratch = run.quest_scratch.duplicate(true)
	out.quest_completions = run.quest_completions.duplicate(true)
	out.pending_hollow = _deep(run.pending_hollow)
	out.stats = run.stats.duplicate(true)
	var p: RunState.Player = RunState.Player.new()
	p.hp = run.player.hp
	p.max_hp = run.player.max_hp
	p.gold = run.player.gold
	p.energy_max = run.player.energy_max
	p.relics = run.player.relics.duplicate()
	p.potions = run.player.potions.duplicate()
	p.deck = run.player.deck.duplicate()
	out.player = p
	return out


static func clone_combat(cb: CombatState) -> CombatState:
	var out: CombatState = CombatState.new()
	out.kind = cb.kind
	out.affix = cb.affix
	out.turn = cb.turn
	out.over = cb.over
	out.result = cb.result
	var p: PlayerCombatant = PlayerCombatant.new()
	p.hp = cb.player.hp
	p.max_hp = cb.player.max_hp
	p.block = cb.player.block
	p.energy = cb.player.energy
	p.energy_max = cb.player.energy_max
	p.statuses = cb.player.statuses.duplicate()
	out.player = p
	for e: EnemyCombatant in cb.enemies:
		out.enemies.append(_clone_enemy(e))
	out.draw = _cards(cb.draw)
	out.hand = _cards(cb.hand)
	out.discard = _cards(cb.discard)
	out.exhaust = _cards(cb.exhaust)
	out.embers = cb.embers
	out.ember_cap = cb.ember_cap
	out.ember_leak = cb.ember_leak
	out.art_cost_delta = cb.art_cost_delta
	out.first_gain_bonus = cb.first_gain_bonus
	out.first_gain_turn = cb.first_gain_turn
	out.lit_way = cb.lit_way
	out.art_used_turn = cb.art_used_turn
	out.kindled_turn = cb.kindled_turn
	out.kindles_this_turn = cb.kindles_this_turn
	out.pending_chips_active = cb.pending_chips_active
	out.pending_chips = cb.pending_chips.duplicate(true)
	out.counters_played = cb.counters_played
	out.counters_attacks = cb.counters_attacks
	out.first_card_played = cb.first_card_played
	out.hp_lost = cb.hp_lost
	out.prism_procd = cb.prism_procd
	out.finale_handoff = cb.finale_handoff
	return out


static func _clone_enemy(e: EnemyCombatant) -> EnemyCombatant:
	var out: EnemyCombatant = EnemyCombatant.new()
	out.key = e.key
	out.variant_id = e.variant_id
	out.def = e.def
	out.idx = e.idx
	out.name = e.name
	out.hp = e.hp
	out.max_hp = e.max_hp
	out.block = e.block
	out.statuses = e.statuses.duplicate()
	out.staggered = e.staggered
	out.last_moves = e.last_moves.duplicate()
	out.move_key = e.move_key
	out.elite = e.elite
	out.boss = e.boss
	out.facet_max = e.facet_max
	out.chips = e.chips
	out.flags = e.flags.duplicate(true)
	return out


static func _cards(cards: Array[CardInst]) -> Array[CardInst]:
	var out: Array[CardInst] = []
	for card: CardInst in cards:
		var copy: CardInst = CardInst.new(card.uid, card.id, card.up)
		copy.bonus = card.bonus
		out.append(copy)
	return out


static func _deep(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value
