extends RefCounted
## The card flights (issue #657, PR 4; the motion spec's Draw, Play,
## End-of-turn discard and Exhaust rows): the spec's numbers, the deal's arc
## on the stage's own height, a tap landing the deal, Reduce Motion's column,
## where a leaving card lands, a retired card that will not turn, and a real
## fight: the hand's order after a deal, and input while cards fly (no play
## lost, none made twice).
##
## The flights run on real tweens, so the checks wait real time with margin
## (the suite is headless: nothing renders, everything moves). How the
## flights look is checked in frame bursts, not here.

const PILE: Rect2 = Rect2(Vector2(20.0, 700.0), Vector2(58.0, 83.0))
const TO: Rect2 = Rect2(Vector2(1000.0, 680.0), Vector2(58.0, 83.0))


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var was_still: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	_spec(fails)
	_next_for(fails)
	await _retired_card_does_not_turn(fails, content)
	await _arc_follows_the_stage(fails, content)
	await _tap_lands_the_deal(fails, content)
	await _leaving(fails, content)
	await _reduce_motion(fails, content)
	Preferences.active.reduce_motion = false
	await _fight(fails)
	Preferences.active.reduce_motion = was_still


static func _spec(fails: Array[String]) -> void:
	var gaps: Dictionary[int, float] = {1: 0.0, 2: 0.09, 5: 0.09, 6: 0.075, 9: 0.05, 12: 0.04, 20: 0.04}
	for n: int in gaps:
		var want: float = gaps[n]
		if not is_equal_approx(CardFlight.stagger(n), want):
			fails.append("card flights: a wave of %d staggers %.3f s, want %.3f" % [
				n, CardFlight.stagger(n), want])
	if not is_equal_approx(4.0 * CardFlight.stagger(5) + CardFlight.DEAL_TIME, 0.78):
		fails.append("card flights: a five-card deal does not take 0.78 s")
	if not is_equal_approx(4.0 * CardFlight.SWEEP_STAGGER + CardFlight.DISCARD_TIME, 0.46):
		fails.append("card flights: a five-card end of turn does not take 0.46 s")
	# The turn: face down until 0.12, face up from 0.78, never back again.
	var last: float = 181.0
	for i: int in range(101):
		var t: float = float(i) / 100.0
		var yaw: float = CardFlight.yaw(t)
		if yaw > last + 0.0001:
			fails.append("card flights: the deal's turn goes back at t=%.2f" % t)
			break
		last = yaw
	if CardFlight.yaw(0.12) != 180.0 or CardFlight.yaw(0.78) != 0.0 \
			or not is_equal_approx(CardFlight.yaw(0.45), 90.0):
		fails.append("card flights: the deal does not turn over between 0.12 and 0.78")
	if CardFlight.pitch(0.0) != 0.0 or not is_zero_approx(CardFlight.pitch(1.0)) \
			or not is_equal_approx(CardFlight.pitch(0.5), -14.0):
		fails.append("card flights: the deal's pitch is not -14 sin(pi t)")
	if CardFlight.travel(0.0) != 0.0 or CardFlight.travel(CardFlight.lift_share()) != 0.0 \
			or CardFlight.travel(1.0) != 1.0:
		fails.append("card flights: the path does not wait out the lift-off and end at the seat")
	if CardFlight.lift(0.0) != 0.0 or not is_equal_approx(CardFlight.lift(1.0), 6.0):
		fails.append("card flights: the card does not rise 6 px off the pile")
	var peak: float = 0.0
	for i: int in range(101):
		peak = maxf(peak, CardFlight.grow(float(i) / 100.0))
	if peak <= 1.01 or CardFlight.grow(1.0) != 1.0:
		fails.append("card flights: the growth does not overshoot the seat and settle (peak %.3f)" % peak)
	for uid: int in [3, 17, 4242]:
		var j: float = CardFlight.jitter(uid, 0)
		if j < -1.0 or j > 1.0 or j != CardFlight.jitter(uid, 0):
			fails.append("card flights: card %d's jitter is not a fixed share in [-1, 1]" % uid)
	if CardFlight.jitter(3, 0) == CardFlight.jitter(3, 1) and CardFlight.jitter(3, 1) == CardFlight.jitter(3, 2):
		fails.append("card flights: a card's jitters do not differ by quantity")


static func _next_for(fails: Array[String]) -> void:
	var seq: EventSequencer = EventSequencer.new()
	seq._queue = [
		{"t": EventTypes.ENERGY, "n": 2},
		{"t": EventTypes.TO_DISCARD, "uid": 8},
		{"t": EventTypes.EXHAUST, "uid": 7},
	] as Array[Dictionary]
	var kinds: Array[StringName] = [EventTypes.TO_DISCARD, EventTypes.EXHAUST, EventTypes.POWER_CONSUMED]
	if seq.next_for(7, kinds) != EventTypes.EXHAUST or seq.next_for(8, kinds) != EventTypes.TO_DISCARD \
			or seq.next_for(9, kinds) != &"":
		fails.append("card flights: the sequencer does not see where a played card goes next")


static func _retired_card_does_not_turn(fails: Array[String], content: ContentDB) -> void:
	var host: Control = _host()
	var card: CardView = CardView.new(CardInst.new(1, &"defend"), content.card(&"defend"), 1)
	host.add_child(card)
	card.retire()
	card.turn(120.0, -10.0, false)
	card.turn(60.0, 0.0, true)
	if not CardTurn.is_rest(card._pose) or card._display.material != null \
			or card._back_plate != null:
		fails.append("card flights: a retired card still turns")
	host.queue_free()
	await _frames(1)


## The arc peaks at DEAL_ARC of the stage's own height: a phone's deal bows
## a 390 px stage by 35 px, a pad's 820 px stage by 74.
static func _arc_follows_the_stage(fails: Array[String], content: ContentDB) -> void:
	for h: float in [390.0, 820.0]:
		var hand: HandView = _hand(content, 1, h)
		var uid: int = hand.uids()[0]
		hand.deal_in(uid, PILE)
		var f: HandView._Flight = hand._dealing[uid]
		f.tween.kill()
		var view: CardView = hand.card_view(uid)
		var t: float = 0.32    # the path's own midpoint, near enough: bow ~1
		hand._deal_step(t, f)
		var e: float = CardFlight.travel(t)
		var seat: Vector2 = hand.global_position + view.home_position + view.size * 0.5
		var chord: Vector2 = (PILE.get_center() - Vector2(0.0, CardFlight.lift(t))).lerp(seat, e)
		var want: float = h * CardFlight.DEAL_ARC * CardFlight.arc(e)
		var rise: float = chord.y - view.global_centre().y
		if absf(rise - want) > 0.5 or absf(view.global_centre().x - chord.x) > 0.5:
			fails.append("card flights: the arc on a %d px stage rises %.1f px, want %.1f" % [
				int(h), rise, want])
		hand._deal_step(0.0, f)
		if view.global_centre().distance_to(PILE.get_center()) > 0.5 \
				or not is_equal_approx(CardView.CARD_W * view.scale.x, PILE.size.x):
			fails.append("card flights: a dealt card does not leave from the pile's top card")
		if not view._pose.is_equal_approx(CardTurn.pose(180.0, 0.0)):
			fails.append("card flights: a dealt card does not leave the pile face down")
		hand.queue_free()
		await _frames(1)


static func _tap_lands_the_deal(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand(content, 5)
	var uids: Array[int] = hand.uids()
	for i: int in range(uids.size()):
		hand.deal_in(uids[i], PILE, float(i) * hand.deal_gap(uids.size()))
	await _wait(0.1)
	if hand._dealing.size() != 5 or not hand.is_processing_input():
		fails.append("card flights: a deal in the air does not listen for a tap")
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	hand._input(tap)
	if hand.deal_gap(5) != 0.0:
		fails.append("card flights: after a tap the rest of the wave still waits its stagger")
	# A card the wave deals after the tap lands with it.
	hand.add_card(CardInst.new(150, &"defend"), content.card(&"defend"), 1)
	hand.deal_in(150, PILE)
	await _wait(CardFlight.SKIP_LAND + 0.05)
	if not hand._dealing.is_empty():
		fails.append("card flights: %d cards still in the air 120 ms after a tap" % hand._dealing.size())
	for uid: int in hand.uids():
		var view: CardView = hand.card_view(uid)
		if not CardTurn.is_rest(view._pose) or view._display.material != null \
				or not view.position.is_equal_approx(view.home_position) \
				or not is_equal_approx(view.rotation, view.home_rotation) \
				or not view.scale.is_equal_approx(view.rest_scale()):
			fails.append("card flights: card %d was not landed face up in its seat by the tap" % uid)
	if hand.deal_gap(5) != CardFlight.DEAL_STAGGER or hand.is_processing_input():
		fails.append("card flights: a landed deal still skips the next wave or listens for taps")
	# A touch lands it too.
	hand.deal_in(uids[0], PILE)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	hand._input(touch)
	await _wait(CardFlight.SKIP_LAND + 0.05)
	if not hand._dealing.is_empty():
		fails.append("card flights: a touch does not land the deal")
	hand.queue_free()
	await _frames(1)


static func _leaving(fails: Array[String], content: ContentDB) -> void:
	var hand: HandView = _hand(content, 4)
	var uids: Array[int] = hand.uids()
	var arrived: Array[int] = []
	var seconds: float = hand.spend_to(uids[0], TO, HandView.Leave.DISCARD, 0.0,
		func() -> void: arrived.append(uids[0]))
	var swept: float = hand.spend_to(uids[1], TO, HandView.Leave.SWEEP, 0.1,
		func() -> void: arrived.append(uids[1]))
	var burnt: float = hand.spend_to(uids[2], TO, HandView.Leave.BURN, 0.0,
		func() -> void: arrived.append(uids[2]))
	if not is_equal_approx(seconds, 0.26) or not is_equal_approx(swept, 0.36) \
			or not is_equal_approx(burnt, 0.2):
		fails.append("card flights: leaving takes %.2f / %.2f / %.2f s, want 0.26 / 0.36 / 0.2"
			% [seconds, swept, burnt])
	if hand.has_card(uids[0]) or not hand.sent(uids[0]) or hand.uids().size() != 1:
		fails.append("card flights: a leaving card is still in the fan, or not on its way")
	var views: Array[CardView] = []
	for i: int in range(3):
		views.append(hand.get_children().filter(
			func(n: Node) -> bool: return n is CardView and (n as CardView).uid == uids[i])[0])
	if hand.card_at(views[0].global_centre()) == uids[0]:
		fails.append("card flights: a card on its way to a pile still answers the pointer")
	await _wait(0.45)
	if arrived != [uids[2], uids[0], uids[1]]:
		fails.append("card flights: the piles heard arrivals %s, want each card once as it lands"
			% str(arrived))
	for i: int in range(3):
		if views[i].global_centre().distance_to(TO.get_center()) > 3.0 * 1.5:
			fails.append("card flights: card %d did not land on the pile's top card" % uids[i])
	if not CardTurn.is_rest(views[0]._pose) or absf(rad_to_deg(views[0].rotation)) > 3.0001:
		fails.append("card flights: a played card does not land face up within 3 degrees")
	if absf(rad_to_deg(views[1].rotation)) > 5.0001:
		fails.append("card flights: the end of a turn lands a card more than 5 degrees loose")
	if not views[2]._pose.is_equal_approx(CardTurn.pose(180.0, 0.0)) \
			or not views[2]._display.modulate.is_equal_approx(CardFlight.CHAR) \
			or views[2].find_child("Rim", false, false) == null:
		fails.append("card flights: an exhausted card does not land face down, charred, its rim alight")
	# Held on the pile while the hand's box moves under it.
	hand.position += Vector2(60.0, 0.0)
	await _frames(2)
	if views[0].global_centre().distance_to(TO.get_center()) > 0.5:
		fails.append("card flights: a landed card moves with the hand's box")
	await _wait(CardFlight.EMBER_COOL + CardFlight.HANDOFF_FADE)
	for i: int in range(3):
		if is_instance_valid(views[i]) and views[i].is_inside_tree() or hand.sent(uids[i]):
			fails.append("card flights: card %d did not hand over to its pile" % uids[i])
	# A tap lands a leaving card at once.
	arrived.clear()
	hand.spend_to(uids[3], TO, HandView.Leave.DISCARD, 0.0, func() -> void: arrived.append(1))
	hand.skip()
	if arrived != [1]:
		fails.append("card flights: a tap does not land a leaving card at once")
	# An attack thrown at a foe reaches the foe, shrunk as it is.
	hand.add_card(CardInst.new(160, &"strike"), content.card(&"strike"), 1)
	await _frames(1)
	var thrown: CardView = hand.card_view(160)
	var foe: Vector2 = Vector2(820.0, 300.0)
	var reached: Array[Vector2] = []
	thrown.tree_exiting.connect(func() -> void: reached.append(thrown.global_centre()))
	hand.strike_to(160, foe)
	await _wait(HandView.STRIKE_FLIGHT + 0.1)
	if reached.size() != 1 or reached[0].distance_to(foe) > 0.5:
		fails.append("card flights: a struck card ended at %s, not on its foe %s" % [str(reached), str(foe)])
	hand.queue_free()
	await _frames(1)


static func _reduce_motion(fails: Array[String], content: ContentDB) -> void:
	Preferences.active.reduce_motion = true
	var hand: HandView = _hand(content, 3)
	if hand.deal_gap(3) != CardFlight.RM_STAGGER or hand.deal_gap(1) != 0.0:
		fails.append("card flights: Reduce Motion's draws are not 40 ms apart")
	var uid: int = hand.uids()[0]
	var view: CardView = hand.card_view(uid)
	view.set_playable(false)
	hand.deal_in(uid, PILE)
	var moved: bool = false
	var last_a: float = -1.0
	for _i: int in range(40):
		if view._display.material != null or not CardTurn.is_rest(view._pose) \
				or not is_equal_approx(view.rotation, view.home_rotation) \
				or not is_equal_approx(view.position.x, view.home_position.x) \
				or view.position.y < view.home_position.y - 0.001 \
				or view.position.y > view.home_position.y + CardFlight.RM_RISE + 0.001 \
				or view.modulate.a < last_a - 0.0001:
			moved = true
		last_a = view.modulate.a
		if not hand._dealing.has(uid):
			break
		await _frames(1)
	if moved:
		fails.append("card flights: under Reduce Motion a drawn card moves, turns or fades out")
	await _wait(CardFlight.RM_FADE)
	if hand._dealing.has(uid) or not view.position.is_equal_approx(view.home_position) \
			or not is_equal_approx(view.modulate.a, 0.8):
		fails.append("card flights: under Reduce Motion a drawn card does not settle in its seat at its tint")
	var leaving: CardView = hand.card_view(hand.uids()[1])
	var burning: CardView = hand.card_view(hand.uids()[2])
	var at: Vector2 = leaving.global_centre()
	var arrived: Array[int] = []
	var seconds: float = hand.spend_to(leaving.uid, TO, HandView.Leave.SWEEP, 0.2,
		func() -> void: arrived.append(1))
	hand.spend_to(burning.uid, TO, HandView.Leave.BURN, 0.0, func() -> void: arrived.append(2))
	if not is_equal_approx(seconds, CardFlight.RM_FADE):
		fails.append("card flights: under Reduce Motion a leaving card waits or flies")
	if burning.find_child("Rim", false, false) == null:
		fails.append("card flights: under Reduce Motion an exhausted card has no ember rim")
	await _frames(3)
	if leaving.global_centre().distance_to(at) > 0.001 or not CardTurn.is_rest(burning._pose):
		fails.append("card flights: under Reduce Motion a leaving card moves or turns")
	await _wait(CardFlight.RM_FADE + 0.05)
	if not arrived.is_empty() or is_instance_valid(leaving) and leaving.is_inside_tree():
		fails.append("card flights: under Reduce Motion a leaving card reaches its pile")
	Preferences.active.reduce_motion = false
	hand.queue_free()
	await _frames(1)


## A real fight, its drain running in real time: the redraw keeps the hand's
## order and lands every card in its seat, and input while cards fly plays
## each card once.
static func _fight(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_slice()
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, 12345))
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling", "sporeling"], "normal", "flights")
	screen._on_end_turn_pressed()
	if game.cb.over:
		fails.append("card flights: the fight ended before the redraw")
		tree.root.remove_child(screen)
		screen.free()
		return
	var hand: HandView = screen._hand
	var order: Array[int] = []
	for c: CardInst in game.cb.hand:
		order.append(c.uid)
	if hand.uids() != order or hand._dealing.size() != order.size():
		fails.append("card flights: the redraw's hand is %s dealing %d, want %s all in the air"
			% [str(hand.uids()), hand._dealing.size(), str(order)])
	await _wait(CardFlight.DEAL_TIME + 0.15)
	for uid: int in order:
		var view: CardView = hand.card_view(uid)
		if hand._dealing.has(uid) or not view.position.is_equal_approx(view.home_position) \
				or not CardTurn.is_rest(view._pose):
			fails.append("card flights: card %d did not land face up in its seat" % uid)
	screen.seq.instant = false
	var played: int = _played(game)
	var skill: int = _playable(game, "skill")
	var other: int = -1
	for c: CardInst in game.cb.hand:
		if c.uid != skill and game.rules.can_play(game.run, game.cb, c,
				0 if str(game.rules.card_data(c).get("target", "")) == "enemy" else null):
			other = c.uid
			break
	if skill < 0 or other < 0:
		fails.append("card flights: the redraw holds no skill and second playable card")
	else:
		_play(screen, skill)
		if not screen.seq.is_busy() or hand.has_card(skill) or not hand.sent(skill) \
				or game.cb.hand.size() != order.size() - 1:
			fails.append("card flights: a played skill did not leave for the discard by its flight")
		# Input while it flies and the drain runs: nothing plays, nothing twice.
		_play(screen, other)
		var again: bool = screen.request_play(skill, null)
		if again or not hand.has_card(other) or game.cb.hand.size() != order.size() - 1:
			fails.append("card flights: input while a card flies played something")
		await _idle(screen)
		screen.request_play(skill, null)
		await _idle(screen)
		if _played(game) != played + 1:
			fails.append("card flights: a card already played played again")
		# A card still being dealt takes no press; landed, it plays once.
		var tapped: Array[int] = []
		hand.card_tapped.connect(func(u: int) -> void: tapped.append(u))
		hand.deal_in(other, screen._hud.pile_card(&"draw"))
		var at: Vector2 = hand.card_view(other).global_centre()
		hand._on_card_pressed_at(other, at)
		hand._on_card_released_at(other, at)
		if hand._drag_uid != -1 or not tapped.is_empty():
			fails.append("card flights: a press on a card still in the air took it")
		await _wait(CardFlight.DEAL_TIME + 0.1)
		_play(screen, other)
		await _idle(screen)
		if hand.has_card(other) or game.cb.hand.size() != order.size() - 2 \
				or _played(game) != played + 2:
			fails.append("card flights: two plays through flights did not play exactly two cards")
	await _wait(CardFlight.HANDOFF_HOLD + CardFlight.HANDOFF_FADE + 0.1)
	tree.root.remove_child(screen)
	screen.free()


## Play a card the way a player does: a card that needs a foe is aimed at the
## first living one (the aim's own path is not this PR's), any other is
## dragged from its seat to above the hand and let go there.
static func _play(screen: CombatScreen, uid: int) -> void:
	var hand: HandView = screen._hand
	var view: CardView = hand.card_view(uid)
	if view == null:
		return
	if view.target_kind == "enemy":
		screen.request_play(uid, screen._first_living())
		return
	var at: Vector2 = view.global_centre()
	var above: Vector2 = Vector2(at.x, hand.get_global_rect().position.y - 60.0)
	hand._on_card_pressed_at(uid, at)
	hand._on_card_moved_to(uid, above)
	hand._on_card_released_at(uid, above)


static func _playable(game: GlassvowGame, type: String) -> int:
	for c: CardInst in game.cb.hand:
		var d: Dictionary = game.rules.card_data(c)
		if str(d.get("type", "")) == type and str(d.get("target", "")) != "enemy" \
				and not d.get("exhaust", false) and game.rules.can_play(game.run, game.cb, c, null):
			return c.uid
	return -1


static func _played(game: GlassvowGame) -> int:
	var n: int = game.run.stats.get("cardsPlayed", 0)
	return n


static func _idle(screen: CombatScreen) -> void:
	var until: int = Time.get_ticks_msec() + 8000
	while screen.seq.is_busy() and Time.get_ticks_msec() < until:
		await _frames(1)
	await _wait(0.4)


static func _hand(content: ContentDB, n: int, stage_h: float = 820.0) -> HandView:
	var hand: HandView = HandView.new()
	hand.position = Vector2(140.0, 600.0)
	hand.size = Vector2(900.0, 260.0)
	hand.stage_h = stage_h
	(Engine.get_main_loop() as SceneTree).root.add_child(hand)
	for i: int in range(n):
		hand.add_card(CardInst.new(100 + i, &"defend"), content.card(&"defend"), 1)
	return hand


static func _host() -> Control:
	var host: Control = Control.new()
	host.size = Vector2(400.0, 400.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


static func _wait(seconds: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


static func _frames(n: int) -> void:
	for _i: int in range(n):
		await (Engine.get_main_loop() as SceneTree).process_frame
