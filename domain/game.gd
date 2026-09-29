class_name GlassvowGame
extends RefCounted
## Facade: apply(cmd) -> Array[Dictionary] GameEvents (SKILL §2).
## Command "t" values mirror the recorded web trace op names verbatim
## (playCard, endTurn, kindleFromHand, useArt, usePotion, startCombat,
## addCardToDeck) so the fixture replayer is a passthrough.

const Incentives: GDScript = preload("res://tools/vow_incentives.gd")


var content: ContentDB
var rules: CombatRules
var rewards: RewardRules
var quests: QuestRules
var run: RunState
var cb: CombatState = null
## Return value of the last op (web playCard/usePotion return bool).
var last_ret: Variant = null
## The deck (sorted card ids) behind the last FLAME reading.
var _flame_deck: PackedStringArray = PackedStringArray()
var _flame_read: bool = false
## The last FLAME reading; a new or resumed run starts from the starter deck's.
var _flame_before: Dictionary = FlameLines.START
## The line slots the readings since `take_flame_lines` have owed, in order.
var _flame_owed: Array[String] = []


func _init(content_db: ContentDB, run_state: RunState) -> void:
	content = content_db
	rules = CombatRules.new(content_db)
	rewards = RewardRules.new(content_db)
	quests = QuestRules.new(content_db)
	run = run_state
	# #211: James signed A as drafted. Vow 0 is identity; higher vows overlay.
	Incentives.apply(rewards, Incentives.shipping(), run.vow)


## Post-combat rewards (not a queued-event op; the app layer calls this after
## a won fight, mirroring the web recorder's genCombatRewards call).
func gen_combat_rewards(kind: String, affix: StringName = &"") -> Dictionary:
	return rewards.gen_combat_rewards(run, kind, affix)


func apply(cmd: Dictionary) -> Array[Dictionary]:
	var t: String = str(cmd.get("t", ""))
	last_ret = null
	var q_before: int = cb.queue.size() if cb != null else 0
	match t:
		"startCombat":
			var enemies: Array = cmd.get("enemies", [])
			var kind: StringName = StringName(str(cmd.get("kind", "normal")))
			var affix_v: Variant = cmd.get("affix")
			var affix: StringName = &"" if affix_v == null else StringName(str(affix_v))
			cb = rules.start_combat(run, enemies, kind, affix)
			q_before = 0
		"playCard":
			var uid: int = cmd.get("uid", 0)
			var target_v: Variant = cmd.get("target")
			last_ret = rules.play_card(run, cb, uid, target_v)
		"endTurn":
			rules.end_turn(run, cb)
		"kindleFromHand":
			# The recorded traces carry ret:null for these ops — the web recorder
			# only captures playCard's return — so last_ret stays null here.
			var kindle_uid: int = cmd.get("uid", 0)
			rules.kindle_from_hand(run, cb, kindle_uid)
		"useArt":
			rules.use_art(run, cb)
		"usePotion":
			var slot: int = cmd.get("slot", 0)
			var potion_target: Variant = cmd.get("target")
			last_ret = rules.use_potion(run, cb, slot, potion_target)
		"addCardToDeck":
			var card_id: StringName = StringName(str(cmd.get("cardId", "")))
			run.player.deck.append(CardInst.new(run.next_uid(), card_id, false))
		_:
			push_error("GlassvowGame.apply: unknown command %s" % t)
	var out: Array[Dictionary] = []
	if cb != null:
		for k: int in range(q_before, cb.queue.size()):
			out.append(cb.queue[k])
	out.append_array(flame_events(t == "startCombat"))
	return out


## Flame lock §4: the lantern is read at every deck change and at combat start
## (`force`), never while a fight is live, and only for an aspect with ways.
## Returns the FLAME event when the deck changed since the last reading. The
## reading rides on `apply`'s events, never on the combat log, so a deck the
## application edits directly (rewards, shops, events) is read by the next
## command or by calling this at that read point.
func flame_events(force: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not force and cb != null and not cb.over:
		return out
	if Flame.ways(content, run.aspect).is_empty():
		return out
	var deck: PackedStringArray = PackedStringArray()
	for card: CardInst in run.player.deck:
		deck.append(String(card.id))
	deck.sort()
	if not force and _flame_read and deck == _flame_deck:
		return out
	_flame_deck = deck
	_flame_read = true
	var event: Dictionary = {"t": EventTypes.FLAME}
	event.merge(Flame.read(content, run))
	for slot: String in FlameLines.owed(_flame_before, event):
		if not _flame_owed.has(slot):
			_flame_owed.append(slot)
	_flame_before = event
	out.append(event)
	return out


## Flame lock §10: the line slots the readings since the last call have owed,
## in the order they play. The caller's once gates decide which are unheard.
func take_flame_lines() -> Array[String]:
	var out: Array[String] = _flame_owed
	_flame_owed = []
	return out
