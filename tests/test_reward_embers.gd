extends RefCounted
## RewardEmbers as the shipped reward screen (2026-09-30). Pins the contract
## Main's `_show_pending_reward` relies on: the announcements settle themselves
## through the entrance as `claimed` in gold, phial, relic order; the offering is
## the one decision; `finished` is always last; a reward resumed with
## `pendingReward.taken` partly true never claims a slot twice; walking on past an
## unanswered offering asks first; at every shipping shape each card, spoil,
## rules line, word and the heading stands inside the stage and below the run
## HUD; and the rebuild after the phial-rack answer resumes settled instead of
## breaking the husk a second time.

const PoolCallers: GDScript = preload("res://tests/test_pool_callers.gd")

const FULL: Dictionary = {"gold": 22, "cards": ["flurry", "surge", "fortify"],
	"potion": "healing", "relic": "emberHeart"}
## Longer than the whole entrance (SIT + BLAZE + BURST + the last card's rise).
const SETTLE: float = 5.0


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_announces_then_picks(fails, content)
	_resume_claims_nothing_twice(fails, content)
	_walk_on_asks_first(fails, content)
	_main_banks_every_slot(fails, content)
	_full_rack_walk_on(fails, content)
	_full_rack_mid_entrance(fails, content)
	_heading_names_the_fight(fails, content)
	_shapes_contain(fails, content)


static func _check(fails: Array[String], ok: bool, msg: String) -> void:
	if not ok:
		fails.append("test_reward_embers: " + msg)


## An Ember in the tree, its signals written to `log` as "what:id" / "finished".
static func _screen(content: ContentDB, reward: Dictionary, log: Array[String]) -> RewardEmbers:
	var screen: RewardEmbers = RewardEmbers.new(reward.duplicate(true), content, "elite",
		208.0, StageShape.IDENTITY, true)
	screen.claimed.connect(func(what: StringName, id: String) -> void:
		log.append("%s:%s" % [what, id]))
	screen.finished.connect(func() -> void: log.append("finished"))
	# The suite runs inside `_initialize`, before the root is in the tree, so
	# `_ready` has to be run by hand, as the scene tests do; the entrance is
	# then driven by `advance` rather than by frames.
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._ready()
	return screen


static func _announces_then_picks(fails: Array[String], content: ContentDB) -> void:
	var log: Array[String] = []
	var screen: RewardEmbers = _screen(content, FULL, log)
	screen.advance(RewardEmbers.SIT + RewardEmbers.BLAZE)
	_check(fails, log.is_empty() and not screen._settled,
		"something was claimed before the husk broke")
	screen.advance(SETTLE)
	_check(fails, log == ["gold:", "potion:healing", "relic:emberHeart"],
		"the entrance did not announce gold, phial, relic in order: %s" % [log])
	# The player's pick arrives the way a click does: CardView's release.
	screen._cards[1].released_at.emit(9101, Vector2.ZERO)
	screen._cards[0].released_at.emit(9100, Vector2.ZERO)
	screen._walk_word.pressed.emit()
	_check(fails, log == ["gold:", "potion:healing", "relic:emberHeart", "card:surge",
			"finished"],
		"pick then walk on did not claim once and finish last: %s" % [log])
	_check(fails, screen._confirm == null and not screen._skip_word.visible
			and screen._card_keys.all(func(k: Button) -> bool: return k.disabled),
		"an answered offering still offered a pick or a skip")
	screen.free()


static func _resume_claims_nothing_twice(fails: Array[String], content: ContentDB) -> void:
	# Main marks the saved slots right after adding the screen, as it resumes.
	var log: Array[String] = []
	var screen: RewardEmbers = _screen(content, FULL, log)
	for key: String in ["gold", "potion", "relic"]:
		screen.mark_taken(StringName(key))
	screen.advance(SETTLE)
	_check(fails, log.is_empty(), "a resumed reward re-claimed a banked slot: %s" % [log])
	_check(fails, screen._face_a.all(func(a: float) -> bool: return is_equal_approx(a, 1.0)),
		"a banked spoil was not shown as the player's")
	screen._skip_word.pressed.emit()
	screen._walk_word.pressed.emit()
	_check(fails, log == ["card:", "finished"],
		"Leave it then walk on did not answer the slot and finish: %s" % [log])
	screen.free()

	var done: Array[String] = []
	var answered: RewardEmbers = _screen(content, FULL, done)
	for key: String in ["gold", "potion", "relic", "card"]:
		answered.mark_taken(StringName(key))
	answered.advance(SETTLE)
	answered._cards[2].released_at.emit(9102, Vector2.ZERO)
	answered._walk_word.pressed.emit()
	_check(fails, done == ["finished"] and answered._confirm == null,
		"a fully resumed reward claimed again or asked to leave: %s" % [done])
	_check(fails, answered._card_dim.all(func(a: float) -> bool: return a < 0.5)
			and not answered._skip_word.visible,
		"a resumed answered offering still stood up for a pick")
	answered.free()


static func _walk_on_asks_first(fails: Array[String], content: ContentDB) -> void:
	var log: Array[String] = []
	var screen: RewardEmbers = _screen(content, FULL, log)
	screen.advance(SETTLE)
	log.clear()
	screen._walk_word.pressed.emit()
	_check(fails, screen._confirm != null and log.is_empty(),
		"walking on past the offering did not ask first")
	_check(fails, screen._card_keys.all(func(k: Button) -> bool:
			return k.focus_mode == Control.FOCUS_NONE),
		"the cards behind the confirm still took the keyboard")
	screen._confirm.answered.emit(false)
	_check(fails, screen._confirm == null and log.is_empty()
			and screen._card_keys[0].focus_mode == Control.FOCUS_ALL,
		"Stay did not hand the reward back untouched")
	screen.request_leave()
	screen._confirm.answered.emit(true)
	_check(fails, log == ["card:", "finished"],
		"Leave Them did not answer the slot and finish: %s" % [log])
	screen.free()

	# Walking on before the entrance reached the spoils banks them first.
	var early: Array[String] = []
	var hasty: RewardEmbers = _screen(content, FULL, early)
	hasty._skip()
	hasty._walk_word.pressed.emit()
	hasty.advance(SETTLE)
	_check(fails, early == ["card:", "gold:", "potion:healing", "relic:emberHeart",
			"finished"],
		"walking on early lost or repeated a spoil: %s" % [early])
	hasty.free()


## Through Main: the screen it builds is the embers, and every slot the entrance
## and the pick answer lands in `pendingReward.taken` and on the run.
static func _main_banks_every_slot(fails: Array[String], content: ContentDB) -> void:
	var main: Main = PoolCallers._on_map(content, 30930)
	var gold: int = main.game.run.player.gold
	var deck: int = main.game.run.player.deck.size()
	main.game.run.pending_reward = {"rewards": {"gold": 17, "cards": ["surge", "flurry"],
		"potion": null, "relic": null}, "taken": {"gold": false, "card": false,
		"potion": false, "relic": false}, "slain_enemy": {"id": "duskfang", "hue": 22}}
	main._show_pending_reward()
	var screen: RewardEmbers = main._reward_screen
	_check(fails, screen != null and is_equal_approx(screen.hue, 22.0)
			and screen.under_hud and screen.shape == main._shape,
		"Main did not build the embers in the dead enemy's hue under the HUD")
	if screen == null:
		PoolCallers._dispose(main)
		return
	# Main builds its screens off-tree in this fixture; the entrance needs one.
	main.remove_child(screen)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._ready()
	screen.advance(SETTLE)
	var taken: Dictionary = main.game.run.pending_reward["taken"]
	var gold_taken: bool = taken["gold"]
	var card_taken: bool = taken["card"]
	_check(fails, gold_taken and main.game.run.player.gold == gold + 17 and not card_taken,
		"the announced gold did not reach the run through Main")
	screen._cards[0].released_at.emit(9100, Vector2.ZERO)
	card_taken = taken["card"]
	_check(fails, card_taken and main.game.run.player.deck.size() == deck + 1
			and String(main.game.run.player.deck[-1].id) == "surge",
		"the picked card did not reach the deck through Main")
	screen._walk_word.pressed.emit()
	_check(fails, main.game.run.pending_reward == null,
		"walking on did not clear the pending reward")
	if is_instance_valid(screen):
		screen.free()
	PoolCallers._dispose(main)


## Walking on at once banks every spoil in one go, and a phial with the rack
## full asks which phial it replaces. The reward is not over until that is
## answered: the answer rebuilds the reward, and walking on from there ends it.
static func _full_rack_walk_on(fails: Array[String], content: ContentDB) -> void:
	var main: Main = PoolCallers._on_map(content, 30931)
	var rack: Array = main.game.run.player.potions
	for slot: int in range(rack.size()):
		rack[slot] = "fire"
	main.game.run.pending_reward = {"rewards": {"gold": 5, "cards": [],
		"potion": "healing", "relic": null}, "taken": {"gold": false, "card": false,
		"potion": false, "relic": false}, "slain_enemy": {}}
	main._show_pending_reward()
	var screen: RewardEmbers = _root(main)
	screen._walk_word.pressed.emit()
	_check(fails, main.game.run.pending_reward != null and main._choice_screen != null,
		"walking on past a full phial rack ended the reward over its open question")
	if main._choice_screen == null or main.game.run.pending_reward == null:
		PoolCallers._dispose(main)
		return
	main._choice_screen.emit_signal(&"chosen", "0")
	var taken: Dictionary = main.game.run.pending_reward["taken"]
	var potion_taken: bool = taken["potion"]
	_check(fails, potion_taken and String(main.game.run.player.potions[0]) == "healing"
			and main._reward_screen != null and main._reward_screen != screen,
		"answering the phial rack did not bank the phial and rebuild the reward")
	var again: RewardEmbers = _root(main)
	_check(fails, _is_quiet(again),
		"the rebuild after the phial answer played the entrance again")
	again._walk_word.pressed.emit()
	_check(fails, main.game.run.pending_reward == null,
		"walking on from the rebuilt reward did not end it")
	for node: RewardEmbers in [screen, again]:
		if is_instance_valid(node):
			node.free()
	PoolCallers._dispose(main)


## The phial-rack question can arrive DURING the entrance: the phial is
## announced before the relic. The answer rebuilds the screen settled, and the
## relic the entrance had not reached yet is banked by that settling, once.
static func _full_rack_mid_entrance(fails: Array[String], content: ContentDB) -> void:
	var main: Main = PoolCallers._on_map(content, 30932)
	var rack: Array = main.game.run.player.potions
	for slot: int in range(rack.size()):
		rack[slot] = "fire"
	var relics: int = main.game.run.player.relics.count("warFetish")
	var gold: int = main.game.run.player.gold
	main.game.run.pending_reward = {"rewards": {"gold": 7, "cards": ["surge"],
		"potion": "healing", "relic": "warFetish"}, "taken": {"gold": false,
		"card": false, "potion": false, "relic": false}, "slain_enemy": {}}
	main._show_pending_reward()
	var screen: RewardEmbers = _root(main)
	# Past the phial's beat (the second, 0.05 s after the gold's) and short of
	# the relic's (0.05 s after that).
	screen.advance(RewardEmbers.SIT + RewardEmbers.BLAZE + RewardEmbers.BURST * 0.66 + 0.07)
	var taken: Dictionary = main.game.run.pending_reward["taken"]
	var relic_early: bool = taken["relic"]
	_check(fails, main._choice_screen != null and not relic_early,
		"the fixture did not stop on the phial question before the relic: %s" % [taken])
	if main._choice_screen == null:
		PoolCallers._dispose(main)
		return
	main._choice_screen.emit_signal(&"chosen", "discard")
	var again: RewardEmbers = main._reward_screen
	var relic_taken: bool = taken["relic"]
	_check(fails, again != null and again != screen and _is_quiet(again),
		"the rebuild after a mid-entrance phial answer did not resume settled")
	_check(fails, relic_taken
			and main.game.run.player.relics.count("warFetish") == relics + 1
			and main.game.run.player.gold == gold + 7,
		"the settled rebuild lost or doubled the spoils the entrance had not reached")
	for node: RewardEmbers in [screen, again]:
		if is_instance_valid(node):
			node.free()
	PoolCallers._dispose(main)


## Settled on arrival: every piece home, the heading and the faces lit, the
## cards up, and the clock stopped, so there is no frame of the break to replay.
static func _is_quiet(screen: RewardEmbers) -> bool:
	return screen._settled and is_equal_approx(screen._burst, 1.0) \
		and is_equal_approx(screen._head_a, 1.0) \
		and screen._face_a.all(func(a: float) -> bool: return is_equal_approx(a, 1.0)) \
		and screen._card_a.all(func(a: float) -> bool: return is_equal_approx(a, 1.0))


## The heading says which fight this was, in the rows screen's own keys, and
## it comes up with the blaze rather than before the husk has done anything.
static func _heading_names_the_fight(fails: Array[String], content: ContentDB) -> void:
	var keys: Dictionary = {"normal": "ui.reward.victory", "elite": "ui.reward.eliteSlain",
		"boss": "ui.reward.bossVanquished"}
	for kind: String in keys:
		var screen: RewardEmbers = RewardEmbers.new(FULL.duplicate(true), content, kind,
			22.0, StageShape.IDENTITY, true)
		_check(fails, screen._heading.text == Locale.active.t(str(keys[kind])),
			"%s: the heading reads %s" % [kind, screen._heading.text])
		screen.advance(RewardEmbers.SIT * 0.5)
		_check(fails, screen._heading.modulate.a == 0.0,
			"%s: the heading was up before the husk blazed" % kind)
		screen.settle()
		_check(fails, is_equal_approx(screen._heading.modulate.a, 1.0),
			"%s: the heading did not come up" % kind)
		screen.free()


## Main builds its screens off-tree in these fixtures; the entrance needs one.
static func _root(main: Main) -> RewardEmbers:
	var screen: RewardEmbers = main._reward_screen
	main.remove_child(screen)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen._ready()
	return screen


## Settled pose at each shipping shape: every card, spoil slab and word inside
## the stage, below the HUD's relic row, clear of the lantern's seat, and the
## spoils clear of the offering.
static func _shapes_contain(fails: Array[String], content: ContentDB) -> void:
	for shape: StringName in StageShape.SHIPPING:
		for reward: Dictionary in [FULL, {"gold": 9, "cards": [], "potion": "fire",
				"relic": "emberHeart"}]:
			var screen: RewardEmbers = RewardEmbers.new(reward.duplicate(true), content,
				"normal", 22.0, shape, true)
			screen.size = Vector2(StageShape.REFERENCES[shape])
			screen._burst = 1.0
			screen._place()
			_contain(fails, screen, shape)
			screen.free()


static func _contain(fails: Array[String], screen: RewardEmbers, shape: StringName) -> void:
	var stage: Rect2 = Rect2(Vector2(0.0, RunHud.relic_row_bottom(shape)),
		screen.size - Vector2(0.0, RunHud.relic_row_bottom(shape)))
	var seat: Dictionary = LayoutBook.resolve(&"chrome", shape, 0).get("lantern", {})
	var lantern: Rect2 = Rect2(LayoutBook.num(seat.get("left")),
		RunHud.chrome_bottom(shape) + RunLantern.GAP,
		LayoutBook.num(seat.get("w"), RunLantern.NATURAL),
		LayoutBook.num(seat.get("h"), RunLantern.NATURAL))
	var cards: Array[Rect2] = []
	for card: CardView in screen._cards:
		var pad: Control = card.get_parent()
		cards.append(Rect2(pad.position, pad.custom_minimum_size))
	var slabs: Array[Rect2] = []
	for i: int in range(screen._seat_rel.size()):
		var box: Rect2 = Rect2()
		var first: bool = true
		for p: Vector2 in RewardEmbers._slab(i, screen._seat):
			var at: Vector2 = screen._centre + screen._seat_rel[i] + p
			box = Rect2(at, Vector2.ZERO) if first else box.expand(at)
			first = false
		slabs.append(box)
	var words: Rect2 = Rect2(screen._bar.position, screen._bar.size)
	var head: Rect2 = Rect2(screen._heading.position, screen._heading.size)
	var rules: Array[Rect2] = _rules_rects(screen)
	var where: String = "%s with %d cards" % [shape, screen._cards.size()]
	_check(fails, rules.size() == 2, "%s: a relic or phial lost its rules line" % where)
	for r: Rect2 in cards + slabs + rules + [words, head]:
		_check(fails, stage.encloses(r.grow(-0.5)),
			"%s: %s runs outside the stage or under the HUD" % [where, r])
		_check(fails, not lantern.intersects(r),
			"%s: %s stands on the Flame's lantern" % [where, r])
	for slab: Rect2 in slabs:
		for card: Rect2 in cards:
			_check(fails, not slab.intersects(card),
				"%s: a spoil slab %s runs into a card %s" % [where, slab, card])
		_check(fails, not slab.intersects(head),
			"%s: the heading %s stands on a slab %s" % [where, head, slab])
	for rule: Rect2 in rules:
		for card: Rect2 in cards:
			_check(fails, not rule.intersects(card),
				"%s: a rules line %s runs into a card %s" % [where, rule, card])
		# On the column the wreckage rests in the fire, never through the words.
		if not screen._compact:
			for shard: Dictionary in screen._shards:
				var carries: int = shard["seat"]
				if carries < 0:
					var piece: Rect2 = _debris_rect(screen, shard)
					_check(fails, not rule.grow(-1.0).intersects(piece),
						"%s: wreckage %s rests across a rules line %s" % [where, piece, rule])
	# The legibility floor: on the pad the rules are the card's own body size,
	# and on the phone never under 13 pt.
	var floor_px: int = RewardEmbers.RULE_PX_COMPACT if screen._compact \
		else RewardEmbers.RULE_PX
	for label: Label in _rules_labels(screen):
		var px: int = label.get_theme_font_size("font_size")
		_check(fails, px >= floor_px and px >= 13,
			"%s: a rules line is %d px, under the legibility floor" % [where, px])
	_check(fails, screen._bar.get_combined_minimum_size().x <= words.size.x,
		"%s: the words do not fit their row" % where)


## Each spoil face's rules line, if it has one (gold has none).
static func _rules_labels(screen: RewardEmbers) -> Array[Label]:
	var out: Array[Label] = []
	for face: Control in screen._faces:
		for child: Node in face.get_children():
			var label: Label = child as Label
			if label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				out.append(label)
	return out


## The rules lines in screen px, as tall as the lines they wrap to.
static func _rules_rects(screen: RewardEmbers) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for label: Label in _rules_labels(screen):
		var face: Control = label.get_parent()
		var lines: int = mini(label.get_line_count(), label.max_lines_visible)
		var pitch: float = RewardEmbers.RULE_LINE_H_COMPACT if screen._compact \
			else RewardEmbers.RULE_LINE_H
		var tall: float = float(lines) * pitch
		out.append(Rect2(face.position + label.position, Vector2(label.size.x, tall)))
	return out


## A piece of wreckage at rest: at home, unspun, at its resting scale.
static func _debris_rect(screen: RewardEmbers, shard: Dictionary) -> Rect2:
	var at: Vector2 = screen._centre + screen._shard_at(shard)
	var box: Rect2 = Rect2(at, Vector2.ZERO)
	for p: Vector2 in shard["poly"]:
		box = box.expand(at + p * RewardEmbers.DEBRIS_SCALE)
	return box
