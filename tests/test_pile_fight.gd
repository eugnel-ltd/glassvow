extends RefCounted
## The piles of real cards in a real fight, its drain running in real time
## (issue #657, PR 5): the counts the piles show are the domain's at every
## rest, through a deal, a reshuffle, a kindle and a Skip mid-stream; the
## discard's top is the last card discarded; a kindle's ash is bumped once; a
## Skip tap racing a play or an End Turn loses and doubles nothing; a pile tap
## during a flight or a reshuffle takes nothing; the inspector shows cards on
## baked faces; and a screen freed mid-flight resumes nothing.
##
## Headless, nothing renders and nothing bakes, so the faces are the decision
## (which card is on top), not the pixels; stills check the pixels.

## The errors that matter while a freed screen's timers run out: the suite's
## own guard sees only script errors, and a coroutine resumed on a freed
## object is logged as a plain error.
class _Errors:
	extends Logger
	var seen: Array[String] = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		var detail: String = rationale if rationale != "" else code
		# The headless renderer's own complaints (a null material) are not the
		# screen's doing; a resumed coroutine and any script error are.
		if error_type != ERROR_TYPE_SCRIPT and not detail.contains("after await"):
			return
		_mutex.lock()
		seen.append("%s:%d %s %s" % [file, line, function, detail])
		_mutex.unlock()


static func run(fails: Array[String]) -> void:
	var was_still: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	await _counts_and_top(fails)
	await _kindle_bumps_once(fails, false)
	await _kindle_bumps_once(fails, true)
	await _skip_races(fails, false)
	await _skip_races(fails, true)
	await _pile_tap_takes_nothing(fails)
	await _inspector_shows_cards(fails)
	await _freed_mid_flight(fails)
	Preferences.active.reduce_motion = was_still


## Through two plays, three end turns (the third reshuffles the discard into
## the draw pile) and a tap mid-stream, every rest shows the domain's counts
## and the domain's last discard on top; a deal walks the draw pile down one
## card at a time.
static func _counts_and_top(fails: Array[String]) -> void:
	var screen: CombatScreen = await _open(12345)
	if screen == null:
		fails.append("pile fight: no fight to play")
		return
	var game: GlassvowGame = screen.game
	_check_rest(fails, screen, "the opening")
	# The top a discard shows as the pile answers each card that lands on it.
	var tops: Array[int] = []
	screen._hud.pile_bumped.connect(func(which: StringName) -> void:
		if which == &"discard":
			tops.append(screen._hud.discard_top_uid()))
	var skill: int = _playable(game, "skill", false)
	var attack: int = _playable(game, "attack", false)
	if skill < 0 or attack < 0:
		fails.append("pile fight: the opening hand holds no skill and attack to play")
	if skill >= 0:
		var played: int = _played(game)
		_drag_play(screen, skill)
		await _idle(screen)
		if _played(game) != played + 1 or screen._hand.has_card(skill):
			fails.append("pile fight: the skill was not played")
		if tops != [skill]:
			fails.append("pile fight: the discard answered the skill with %s on top" % str(tops))
		_check_rest(fails, screen, "a skill")
	if attack >= 0:
		# The struck card is the discard's top as its blow resolves: when its
		# own toDiscard has been handled, before the drain goes idle.
		var resolved: Array[bool] = [false]
		var handle: Callable = screen.seq.handler
		screen.seq.handler = func(ev: Dictionary) -> void:
			await handle.call(ev)
			if ev["t"] == EventTypes.TO_DISCARD and ev.get("uid", -1) == attack:
				resolved[0] = screen._hud.discard_top_uid() == attack
		screen.request_play(attack, screen._first_living())
		await _idle(screen)
		screen.seq.handler = handle
		if not resolved[0]:
			fails.append("pile fight: a struck card did not top the discard as its blow resolved")
		await _idle(screen)
		_check_rest(fails, screen, "a strike")
	var walk: Array[int] = []
	var streamed: bool = false
	for turn: int in range(3):
		if game.cb.over:
			break
		var last_held: int = game.cb.hand[-1].uid if not game.cb.hand.is_empty() else -1
		tops.clear()
		screen._on_end_turn_pressed()
		while screen.seq.is_busy():
			walk.append(screen._hud.pile_count(&"draw"))
			var stream: PileStream = screen._hud._stream
			if stream != null and is_instance_valid(stream) and not streamed:
				streamed = true
				var tap: InputEventMouseButton = InputEventMouseButton.new()
				tap.button_index = MOUSE_BUTTON_LEFT
				tap.pressed = true
				stream._input(tap)
				await _wait(PileStream.SKIP_TIME + 0.05)
				if is_instance_valid(stream) and not stream.done():
					fails.append("pile fight: a tap did not complete the reshuffle in 150 ms")
			await _frames(1)
		await _idle(screen)
		if last_held >= 0 and (tops.is_empty() or tops[0] != last_held):
			fails.append("pile fight: the end of turn %d answered with %s on top, want %d"
				% [turn + 1, str(tops), last_held])
		_check_rest(fails, screen, "end turn %d" % (turn + 1))
		if turn == 0:
			# The redraw: the pile loses its cards one at a time, never jumps.
			for i: int in range(1, walk.size()):
				if walk[i] > walk[i - 1] or walk[i - 1] - walk[i] > 1:
					fails.append("pile fight: the deal walked the draw pile %s" % str(walk))
					break
		walk.clear()
	if not streamed and not game.cb.over:
		fails.append("pile fight: three turns of a 10-card deck did not reshuffle")
	await _close(screen)


## A kindled card burns to the ash, and the EXHAUST that follows it in the
## batch finds it already there: the ash pile is bumped once, not twice (the
## behaviour #657 PR 4 changed), with or without Reduce Motion.
static func _kindle_bumps_once(fails: Array[String], still: bool) -> void:
	var screen: CombatScreen = await _open(777)
	if screen == null:
		return
	Preferences.active.reduce_motion = still
	var bumps: Array[StringName] = []
	screen._hud.pile_bumped.connect(func(which: StringName) -> void: bumps.append(which))
	var uid: int = screen.game.cb.hand[0].uid
	if not screen.request_kindle(uid):
		fails.append("pile fight: the kindle was refused")
	await _idle(screen)
	var ash: int = bumps.count(&"ashes")
	if ash != 1:
		fails.append("pile fight: a kindle bumped the ash %d times%s" % [
			ash, " under Reduce Motion" if still else ""])
	_check_rest(fails, screen, "a kindle%s" % (" under Reduce Motion" if still else ""))
	Preferences.active.reduce_motion = false
	await _close(screen)


## A tap that lands the opening deal, in the same frame as a play or an End
## Turn: one card played once (or one turn ended), every card landed face up
## in its seat, the piles the domain's.
static func _skip_races(fails: Array[String], end_turn: bool) -> void:
	var screen: CombatScreen = await _open(4242, false)
	if screen == null:
		return
	var game: GlassvowGame = screen.game
	var hand: HandView = screen._hand
	var waited: int = 0
	while hand._dealing.size() < game.cb.hand.size() and waited < 60:
		await _frames(1)
		waited += 1
	var played: int = _played(game)
	var turn: int = game.cb.turn
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	hand._input(tap)
	var what: String = "an End Turn"
	var dealt_again: bool = false
	if end_turn:
		screen._on_end_turn_pressed()
		# The tap landed the opening deal; the next turn's is dealt in full.
		while screen.seq.is_busy():
			for f: HandView._Flight in hand._dealing.values():
				dealt_again = dealt_again or not f.skipped
			await _frames(1)
		if not dealt_again and not game.cb.over:
			fails.append("pile fight: a tap racing an End Turn skipped the next turn's deal too")
	else:
		what = "a play"
		var skill: int = _playable(game, "skill", false)
		if skill < 0 or not screen.request_play(skill, null):
			fails.append("pile fight: no play to race the tap with")
	await _idle(screen)
	if end_turn and game.cb.turn != turn + 1 and not game.cb.over:
		fails.append("pile fight: a tap racing an End Turn ended %d turns" % (game.cb.turn - turn))
	if not end_turn and _played(game) != played + 1:
		fails.append("pile fight: a tap racing a play played %d cards" % (_played(game) - played))
	var order: Array[int] = []
	for c: CardInst in game.cb.hand:
		order.append(c.uid)
	if hand.uids() != order:
		fails.append("pile fight: after a tap racing %s the hand is %s, want %s"
			% [what, str(hand.uids()), str(order)])
	for uid: int in order:
		var view: CardView = hand.card_view(uid)
		if hand._dealing.has(uid) or not CardTurn.is_rest(view._pose) \
				or not view.position.is_equal_approx(view.home_position):
			fails.append("pile fight: after a tap racing %s card %d is not face up in its seat"
				% [what, uid])
	_check_rest(fails, screen, "a tap racing %s" % what)
	await _close(screen)


## A tap on a pile while a card flies, and while the reshuffle streams: the
## inspector shows the domain's pile and leaves its order alone, the tap lands
## the flight or completes the stream, and nothing is played, lost or counted
## twice.
static func _pile_tap_takes_nothing(fails: Array[String]) -> void:
	var screen: CombatScreen = await _open(12345)
	if screen == null:
		return
	var game: GlassvowGame = screen.game
	var played: int = _played(game)
	var skill: int = _playable(game, "skill", false)
	if skill >= 0:
		_drag_play(screen, skill)
		var piles: Array = _order_of(game.cb)
		_tap_pile(screen, &"draw")
		if _order_of(game.cb) != piles:
			fails.append("pile fight: a pile tap during a flight reordered the domain's piles")
		if screen._hand.sent(skill) and not screen._hand._leaving.is_empty():
			fails.append("pile fight: a pile tap did not land the card in flight")
		_check_inspector(fails, screen, game.cb.draw, "the draw pile mid-flight")
		await _idle(screen)
		screen._close_inspector()
		if _played(game) != played + 1:
			fails.append("pile fight: a pile tap during a flight played %d cards"
				% (_played(game) - played - 1))
		_check_rest(fails, screen, "a pile tap during a flight")
	# Turns until the reshuffle streams, and a tap on the discard meanwhile.
	var tapped: bool = false
	for _turn: int in range(4):
		if game.cb.over or tapped:
			break
		screen._on_end_turn_pressed()
		while screen.seq.is_busy() and not tapped:
			var stream: PileStream = screen._hud._stream
			if stream != null and is_instance_valid(stream):
				tapped = true
				var piles: Array = _order_of(game.cb)
				_tap_pile(screen, &"discard")
				_tap_pile(screen, &"draw")
				if _order_of(game.cb) != piles:
					fails.append("pile fight: a pile tap during the reshuffle reordered the domain's piles")
				_check_inspector(fails, screen, game.cb.draw, "the draw pile mid-reshuffle")
				await _wait(PileStream.SKIP_TIME + 0.05)
				if is_instance_valid(stream) and not stream.done():
					fails.append("pile fight: a pile tap did not complete the reshuffle")
			await _frames(1)
		await _idle(screen)
		screen._close_inspector()
	if tapped:
		_check_rest(fails, screen, "a pile tap during the reshuffle")
	await _close(screen)


## The inspector shows each pile's cards on baked faces, none live: the draw
## pile sorted, so it does not tell the draw order; the discard top down; an
## empty pile in words. Closing it lets every card go.
static func _inspector_shows_cards(fails: Array[String]) -> void:
	var screen: CombatScreen = await _open(12345)
	if screen == null:
		return
	var game: GlassvowGame = screen.game
	screen._show_pile(&"draw")
	var grid: CardGrid = screen._inspector_grid
	if grid == null or grid.cards().size() != game.cb.draw.size():
		fails.append("pile fight: the draw pile's inspector does not show its %d cards"
			% game.cb.draw.size())
	else:
		var keys: Array[String] = []
		for card: BakedCard in grid.cards():
			keys.append(String(card.inst.id))
			if card.live() != null:
				fails.append("pile fight: the inspector opened with a live card")
				break
		var sorted: Array[String] = keys.duplicate()
		sorted.sort()
		if keys != sorted:
			fails.append("pile fight: the draw pile's inspector tells the draw order %s" % str(keys))
	if not screen._inspector.visible:
		fails.append("pile fight: a pile tap did not open the inspector")
	screen._show_pile(&"discard")
	if screen._inspector_grid != null:
		fails.append("pile fight: an empty discard shows a grid of cards")
	screen._close_inspector()
	if screen._inspector_body != null or screen._inspector.visible:
		fails.append("pile fight: closing the inspector kept its cards")
	var skill: int = _playable(game, "skill", false)
	var attack: int = _playable(game, "attack", false)
	if skill >= 0 and attack >= 0:
		_drag_play(screen, skill)
		await _idle(screen)
		screen.request_play(attack, screen._first_living())
		await _idle(screen)
		screen._show_pile(&"discard")
		var top_first: Array[int] = []
		for card: BakedCard in screen._inspector_grid.cards():
			top_first.append(card.inst.uid)
		if top_first != [game.cb.discard[-1].uid, game.cb.discard[0].uid]:
			fails.append("pile fight: the discard's inspector is not top down %s" % str(top_first))
		screen._close_inspector()
	screen._show_deck()
	if screen._inspector_grid == null \
			or screen._inspector_grid.cards().size() != game.run.player.deck.size():
		fails.append("pile fight: the deck seal's inspector does not show the deck as cards")
	screen._close_inspector()
	await _close(screen)


## A screen freed while its drain waits out a deal's stagger, while a card
## flies to the discard with its face still to bake, and while the reshuffle
## streams: nothing resumes on it, and nothing is logged.
static func _freed_mid_flight(fails: Array[String]) -> void:
	var errors: _Errors = _Errors.new()
	OS.add_logger(errors)
	# Bakes land a few frames late, as on a device: after the screen is gone.
	CardFaces.use_renderer(func(jobs: Array) -> Array:
		await _frames(3)
		var out: Array = []
		for _job: Variant in jobs:
			var face: CardFaces.Face = CardFaces.Face.new()
			face.picture = ImageTexture.create_from_image(
				Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
			out.append(face)
		return out)
	for when: String in ["deal", "flight", "reshuffle"]:
		var screen: CombatScreen = await _open(12345)
		if screen == null:
			continue
		var game: GlassvowGame = screen.game
		var caught: bool = false
		match when:
			"deal":
				screen._on_end_turn_pressed()
				for _i: int in range(600):
					if screen._hand._dealing.size() >= 2 and screen.seq.is_busy():
						caught = true
						break
					await _frames(1)
			"flight":
				var attack: int = _playable(game, "attack", false)
				var skill: int = _playable(game, "skill", false)
				if attack >= 0 and skill >= 0:
					screen.request_play(attack, screen._first_living())
					await _idle(screen)
					_drag_play(screen, skill)
					await _frames(2)
					caught = screen._hand.sent(skill)
			"reshuffle":
				for _turn: int in range(4):
					if game.cb.over or caught:
						break
					screen._on_end_turn_pressed()
					while screen.seq.is_busy() and not caught:
						caught = screen._hud._stream != null
						if not caught:
							await _frames(1)
					if not caught:
						await _idle(screen)
		if not caught:
			fails.append("pile fight: the screen was never caught mid-%s" % when)
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		tree.root.remove_child(screen)
		screen.free()
		await _wait(1.6)
	OS.remove_logger(errors)
	CardFaces.use_renderer(Callable())
	CardFaces.forget()
	for line: String in errors.seen:
		fails.append("pile fight: a screen freed mid-flight logged: %s" % line)


## The order of every pile the domain holds, by uid.
static func _order_of(cb: CombatState) -> Array:
	var out: Array = []
	for pile: Array[CardInst] in [cb.draw, cb.discard, cb.exhaust, cb.hand]:
		var uids: Array[int] = []
		for c: CardInst in pile:
			uids.append(c.uid)
		out.append(uids)
	return out


## At rest: every pile shows the domain's count, and the discard's top is the
## domain's last discard.
static func _check_rest(fails: Array[String], screen: CombatScreen, after: String) -> void:
	var cb: CombatState = screen.game.cb
	var hud: HudBar = screen._hud
	var shown: Array[int] = [hud.pile_count(&"draw"), hud.pile_count(&"discard"),
		hud.pile_count(&"ashes")]
	var held: Array[int] = [cb.draw.size(), cb.discard.size(), cb.exhaust.size()]
	if shown != held:
		fails.append("pile fight: after %s the piles show %s, the domain holds %s"
			% [after, str(shown), str(held)])
	var top: int = cb.discard[-1].uid if not cb.discard.is_empty() else -1
	if hud.discard_top_uid() != top:
		fails.append("pile fight: after %s the discard shows card %d on top, want %d"
			% [after, hud.discard_top_uid(), top])


static func _check_inspector(fails: Array[String], screen: CombatScreen,
		pile: Array[CardInst], what: String) -> void:
	var want: Array[int] = []
	for c: CardInst in pile:
		want.append(c.uid)
	var got: Array[int] = []
	if screen._inspector_grid != null:
		for card: BakedCard in screen._inspector_grid.cards():
			got.append(card.inst.uid)
	want.sort()
	got.sort()
	if not screen._inspector.visible or got != want:
		fails.append("pile fight: a tap on %s shows %s, want %s" % [what, str(got), str(want)])


## A tap on a pile, as a finger makes it: the tap is heard by whatever is in
## the air, and the pile's button opens the inspector.
static func _tap_pile(screen: CombatScreen, which: StringName) -> void:
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	screen._hand._input(tap)
	var stream: PileStream = screen._hud._stream
	if stream != null and is_instance_valid(stream):
		stream._input(tap)
	screen._hud.pile_pressed.emit(which)


static func _open(seed: int, settle: bool = true) -> CombatScreen:
	var content: ContentDB = ContentDB.load_slice()
	var game: GlassvowGame = GlassvowGame.new(content, RunState.new_run(content, seed))
	var screen: CombatScreen = CombatScreen.new(game)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling", "sporeling"], "normal", "piles")
	if game.cb == null or game.cb.over:
		tree.root.remove_child(screen)
		screen.free()
		return null
	await _frames(1)
	if settle:
		await _wait(CardFlight.DEAL_TIME + 0.6)
	return screen


static func _close(screen: CombatScreen) -> void:
	await _wait(CardFlight.EMBER_COOL + CardFlight.HANDOFF_FADE + 0.1)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.remove_child(screen)
	screen.free()
	await _frames(1)


## Play a card the way a player does: dragged from its seat to above the hand.
static func _drag_play(screen: CombatScreen, uid: int) -> void:
	var hand: HandView = screen._hand
	var view: CardView = hand.card_view(uid)
	var at: Vector2 = view.global_centre()
	var above: Vector2 = Vector2(at.x, hand.get_global_rect().position.y - 60.0)
	hand._on_card_pressed_at(uid, at)
	hand._on_card_moved_to(uid, above)
	hand._on_card_released_at(uid, above)


## A card of `type` the hand can play now: a skill that needs no foe (it is
## dragged), an attack that does (it is aimed at the first living one).
static func _playable(game: GlassvowGame, type: String, exhaust: bool) -> int:
	for c: CardInst in game.cb.hand:
		var d: Dictionary = game.rules.card_data(c)
		var aimed: bool = str(d.get("target", "")) == "enemy"
		var burns: bool = d.get("exhaust", false) == true
		if str(d.get("type", "")) == type and burns == exhaust and aimed == (type == "attack") \
				and game.rules.can_play(game.run, game.cb, c, 0 if aimed else null):
			return c.uid
	return -1


static func _played(game: GlassvowGame) -> int:
	var n: int = game.run.stats.get("cardsPlayed", 0)
	return n


static func _idle(screen: CombatScreen) -> void:
	var until: int = Time.get_ticks_msec() + 10000
	while screen.seq.is_busy() and Time.get_ticks_msec() < until:
		await _frames(1)
	await _wait(CardFlight.HANDOFF_HOLD + CardFlight.HANDOFF_FADE + 0.15)


static func _wait(seconds: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


static func _frames(n: int) -> void:
	for _i: int in range(n):
		await (Engine.get_main_loop() as SceneTree).process_frame
