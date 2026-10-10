extends RefCounted
## The piles of real cards (issue #657, PR 5; §4 of
## docs/design/2026-10-03-cards-real-objects/README.md), one part at a time:
## the thickness law and the stack it draws, the life at rest and Reduce
## Motion's column, the reshuffle stream's timing and its Skip, the counts the
## drain shows while events are still to come, the discard's face-up top, and
## a dealt card's seat under a scaled ancestor. The fights these parts serve
## are tests/test_pile_fight.gd. How the piles look is checked in stills.

const PILE: Rect2 = Rect2(Vector2(20.0, 700.0), Vector2(58.0, 83.0))


static func run(fails: Array[String]) -> void:
	var was_still: bool = Preferences.active.reduce_motion
	Preferences.active.reduce_motion = false
	_thickness(fails)
	_stack_follows_count(fails)
	await _life_at_rest(fails)
	_glint_fills(fails)
	_stream_timing(fails)
	await _stream_skip(fails)
	_pending_counts(fails)
	_discard_top(fails)
	await _seat_under_scale(fails)
	Preferences.active.reduce_motion = was_still


## 1 px a card to ten, then 0.35 px, capped at 14; one sliver a pixel.
static func _thickness(fails: Array[String]) -> void:
	var want: Dictionary[int, float] = {0: 0.0, 1: 1.0, 5: 5.0, 10: 10.0, 11: 10.35,
		20: 13.5, 40: 14.0, 99: 14.0}
	for n: int in want:
		if not is_equal_approx(PileStack.thickness(n), want[n]):
			fails.append("piles: %d cards stand %.2f px, want %.2f" % [
				n, PileStack.thickness(n), want[n]])
	for n: int in [1, 5, 10, 40, 99]:
		var s: int = PileStack.slivers(n)
		if s != roundi(PileStack.thickness(n)) or s < 1 or s > PileStack.MAX_SLIVERS:
			fails.append("piles: %d cards show %d slivers" % [n, s])
	if PileStack.slivers(0) != 0:
		fails.append("piles: an empty pile shows slivers")


## The stack's top card rises by the pile's thickness over its base, so a
## dealt card leaves from where the top is and a spent one lands there.
static func _stack_follows_count(fails: Array[String]) -> void:
	var stack: PileStack = PileStack.new(PileStack.Kind.DRAW)
	stack.card = Vector2(58.0, 83.0)
	stack.base = Vector2(48.0, 82.0)
	var base_top: float = stack.top_rect(0).position.y
	for n: int in [1, 5, 10, 40, 99]:
		stack.set_count(n)
		var rise: float = base_top - stack.top_rect().position.y
		if not is_equal_approx(rise, PileStack.thickness(n)) or stack.count != n:
			fails.append("piles: the top of %d cards rises %.2f px, want %.2f" % [
				n, rise, PileStack.thickness(n)])
	stack.set_count(-3)
	if stack.count != 0:
		fails.append("piles: a pile counts below zero")
	# The discard: a card named without its face keeps the picture it had.
	var discard: PileStack = PileStack.new(PileStack.Kind.DISCARD)
	var first: ImageTexture = ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
	discard.set_face(7, first, 0.05, Vector2(1.0, 2.0))
	discard.set_face(9, null, 0.02)
	if discard.face_uid() != 9 or discard.face_texture() != first \
			or not is_equal_approx(discard.top_rotation(), 0.05):
		fails.append("piles: a top named without its face does not keep the old picture")
	discard.set_flipped(true)
	if not is_zero_approx(discard.top_rotation()):
		fails.append("piles: a discard turned over for the reshuffle still lies at its face's angle")
	discard.clear_face()
	if discard.face_uid() != -1 or discard.face_texture() != null:
		fails.append("piles: a cleared discard keeps its top")
	stack.free()
	discard.free()


## The glint crosses the draw pile once every 9 s and the ash rim breathes
## between 0.45 and 0.65 over 3.2 s; under Reduce Motion neither moves.
static func _life_at_rest(fails: Array[String]) -> void:
	for t: float in [3.0, 5.0, 8.9]:
		if not is_nan(PileStack.glint_at(t)):
			fails.append("piles: the glint is on the card %.1f s into its cycle" % t)
	var last: float = -2.0
	for i: int in range(1, 14):
		var b: float = PileStack.glint_at(float(i) * 0.1)
		if is_nan(b) or b < last or b < -1.0 or b > 1.0:
			fails.append("piles: the glint does not sweep the card at %.1f s" % (float(i) * 0.1))
			break
		last = b
	if not is_equal_approx(PileStack.glint_at(9.7), PileStack.glint_at(0.7)):
		fails.append("piles: the glint does not come round every 9 s")
	var host: Control = _host()
	var draw: PileStack = _stack(host, PileStack.Kind.DRAW)
	var ash: PileStack = _stack(host, PileStack.Kind.ASHES)
	var alphas: Array[float] = []
	var lit: bool = false
	for i: int in range(40):
		draw._process(0.1)
		ash._process(0.1)
		alphas.append(ash._glow.modulate.a)
		lit = lit or not is_nan(draw._glow.band)
	var low: float = alphas.min()
	var high: float = alphas.max()
	if not lit or low < PileStack.RIM_LOW - 0.001 or high > PileStack.RIM_HIGH + 0.001 \
			or high - low < 0.15:
		fails.append("piles: at rest the glint never crosses (%s) or the rim breathes %.2f-%.2f"
			% [str(lit), low, high])
	Preferences.active.reduce_motion = true
	var held: Array[float] = []
	for i: int in range(40):
		draw._process(0.1)
		ash._process(0.1)
		held.append(ash._glow.modulate.a)
		if not is_nan(draw._glow.band):
			fails.append("piles: under Reduce Motion the glint still crosses the draw pile")
			break
	if held.max() - held.min() > 0.0001:
		fails.append("piles: under Reduce Motion the ash rim still breathes")
	Preferences.active.reduce_motion = false
	host.queue_free()
	await _frames(1)


## The glint draws only what the canvas can fill: at 0.681 of its sweep a
## corner clips a sliver three points all but in a line, which draw_polygon
## refuses with an error (seen once in the top-menu deck's stills, #657 PR 5b).
## Mid-card both halves of the band are drawn.
static func _glint_fills(fails: Array[String]) -> void:
	var stack: PileStack = PileStack.new(PileStack.Kind.DRAW)
	stack.card = Vector2(CardView.CARD_W / CardView.CARD_H, 1.0) * DeckStack.LAW_CARD_H
	for band: float in [-0.681, 0.681]:
		for piece: PackedVector2Array in stack.glint_pieces(band):
			if Geometry2D.triangulate_polygon(piece).is_empty():
				fails.append("piles: the glint at %.3f draws a sliver the canvas cannot fill" % band)
	if stack.glint_pieces(0.0).size() != 2:
		fails.append("piles: mid-card the glint draws %d pieces, want its two halves"
			% stack.glint_pieces(0.0).size())
	stack.free()


## Eight cards at most, one every 0.6 s * 0.35 / n, the last landing 0.6 s in;
## the first turns face down in the first 40% of its flight.
static func _stream_timing(fails: Array[String]) -> void:
	for n: int in [1, 3, 8, 10, 30]:
		var shown: int = PileStream.shown(n)
		var last_lands: float = PileStream.stagger(n) * float(shown - 1) + PileStream.flight(n)
		if shown != mini(n, 8) or not is_equal_approx(PileStream.stagger(n), 0.21 / float(shown)) \
				or absf(last_lands - 0.6) > 0.0001:
			fails.append("piles: a reshuffle of %d flies %d, the last landing at %.3f s" % [
				n, shown, last_lands])
		if PileStream.moved(shown, n) != n or PileStream.moved(0, n) != 0:
			fails.append("piles: a reshuffle of %d does not walk the counts all the way" % n)
	if PileStream.yaw(0.0) != 0.0 or PileStream.yaw(0.4) != 180.0 \
			or not is_equal_approx(PileStream.yaw(0.2), 90.0):
		fails.append("piles: the reshuffle's first card does not turn over in its first 40%")


## A stream lands every card and is done 0.12 s after the last (the deck
## squared); a tap completes it within 150 ms.
static func _stream_skip(fails: Array[String]) -> void:
	var host: Control = _host()
	var to: Callable = func() -> Rect2: return Rect2(Vector2(900.0, 700.0), PILE.size)
	for skipped: bool in [false, true]:
		var stream: PileStream = PileStream.new(10, PILE, to, null, null, 820.0)
		var left: Array[int] = []
		var landed: Array[int] = []
		stream.left.connect(func(k: int) -> void: left.append(k))
		stream.landed.connect(func(k: int) -> void: landed.append(k))
		host.add_child(stream)
		stream.set_process(false)    # stepped by hand
		stream._step(0.05)
		if skipped:
			var tap: InputEventScreenTouch = InputEventScreenTouch.new()
			tap.pressed = true
			stream._input(tap)
			stream._step(0.149)
			if stream.done():
				fails.append("piles: a skipped reshuffle completes before 150 ms")
			stream._step(0.002)
			if not stream.done() or landed.size() != 8 or left.size() != 8:
				fails.append("piles: a tap does not complete the reshuffle in 150 ms (%d landed)"
					% landed.size())
		else:
			stream._step(0.5)
			if landed.size() == 8:
				fails.append("piles: the reshuffle lands its last card before 0.6 s")
			stream._step(0.06)
			if landed != [0, 1, 2, 3, 4, 5, 6, 7] or left != landed or stream.done():
				fails.append("piles: the reshuffle's cards do not land in turn, once each")
			stream._step(PileStack.JOG_TIME + 0.001)
			if not stream.done():
				fails.append("piles: the reshuffle is not done once the deck is squared")
		stream.queue_free()
	host.queue_free()
	await _frames(1)


## What the queue still holds is taken back from the domain's counts, and a
## card already in the air is counted by its flight, not twice.
static func _pending_counts(fails: Array[String]) -> void:
	var seq: EventSequencer = EventSequencer.new()
	seq._queue = [
		{"t": EventTypes.DRAW, "uid": 1},
		{"t": EventTypes.RESHUFFLE, "n": 6},
		{"t": EventTypes.DRAW, "uid": 2},
		{"t": EventTypes.TO_DISCARD, "uid": 5},
		{"t": EventTypes.DISCARD_HAND, "uids": [11, 12, 13]},
		{"t": EventTypes.EXHAUST, "uid": 9},
		{"t": &"addCard", "id": "wound", "where": "discard"},
		{"t": &"addCard", "id": "wound", "where": "hand"},
	] as Array[Dictionary]
	var got: Array[int] = [seq.pile_change(&"draw"), seq.pile_change(&"discard"),
		seq.pile_change(&"ashes"), seq.pile_change(&"discard", [5, 12]),
		seq.pile_change(&"ashes", [9])]
	if got != [4, -1, 1, -3, 0]:
		fails.append("piles: the queue's pile changes are %s, want [4, -1, 1, -3, 0]" % str(got))


## The discard's top: named as the card arrives, wearing the face it handed
## on (even before it arrived), a cached one, or a bake; settled on the
## domain's last discard when the drain is idle.
static func _discard_top(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var cards: Dictionary[int, CardInst] = {}
	for uid: int in [3, 4, 5]:
		cards[uid] = CardInst.new(uid, &"defend")
	var top: DiscardTop = DiscardTop.new(func(uid: int) -> CardInst: return cards.get(uid),
		func(c: CardInst) -> Dictionary: return content.card(c.id))
	var hud: HudBar = HudBar.new(true, true, false)
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	top.show_on(hud, null)
	var face: CardFaces.Face = CardFaces.Face.new()
	face.picture = ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
	top.face_ready(4, face)     # a struck card's, before it reaches the pile
	if hud.discard_top_uid() != -1:
		fails.append("piles: a face handed on before its card arrived took the top")
	top.arrive(4)
	if hud.discard_top_uid() != 4 or hud._discard_pile.stack.face_texture() != face.picture \
			or not is_equal_approx(hud._discard_pile.stack.top_rotation(),
				CardFlight.landing_rot(4, false)):
		fails.append("piles: an arrived card is not the top, in its own face at its landing angle")
	# No face yet: named at once, the old picture kept, a bake asked for.
	var asked: Array[String] = []
	CardFaces.use_renderer(func(jobs: Array) -> Array:
		for job: CardFaces._Job in jobs:
			asked.append(str(job.inst.uid))
		return [])
	top.arrive(3, true)
	await _frames(2)
	if hud.discard_top_uid() != 3 or hud._discard_pile.stack.face_texture() != face.picture \
			or not asked.has("3"):
		fails.append("piles: a top with no face is not named at once with a bake asked (%s)"
			% str(asked))
	top.settle(5)
	if top.uid != 5 or hud.discard_top_uid() != 5:
		fails.append("piles: the idle drain does not settle the top on the last discard")
	top.settle(-1)
	if hud.discard_top_uid() != -1:
		fails.append("piles: the idle drain leaves a top on an empty discard")
	CardFaces.use_renderer(Callable())
	CardFaces.forget()
	hud.queue_free()


## A dealt card is aimed at its seat through the hand's own transform, so it
## lands there under a scaled ancestor too.
static func _seat_under_scale(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var outer: Control = _host()
	outer.position = Vector2(30.0, 40.0)
	outer.scale = Vector2(0.5, 0.5)
	var hand: HandView = HandView.new()
	hand.position = Vector2(140.0, 600.0)
	hand.size = Vector2(900.0, 260.0)
	outer.add_child(hand)
	for i: int in range(3):
		hand.add_card(CardInst.new(100 + i, &"defend"), content.card(&"defend"), 1)
	await _frames(1)
	var uid: int = hand.uids()[1]
	var view: CardView = hand.card_view(uid)
	var seat: Vector2 = hand.get_global_transform() * (view.home_position + view.size * 0.5)
	if hand.seat_centre(uid).distance_to(seat) > 0.01:
		fails.append("piles: a seat is placed off the hand's own transform")
	hand.deal_in(uid, PILE)
	var f: HandView._Flight = hand._dealing[uid]
	f.tween.kill()
	hand._deal_step(1.0, f)
	if view.global_centre().distance_to(seat) > 0.5:
		fails.append("piles: under a scaled ancestor a dealt card lands %.1f px off its seat"
			% view.global_centre().distance_to(seat))
	outer.queue_free()
	await _frames(1)


static func _stack(host: Control, kind: PileStack.Kind) -> PileStack:
	var stack: PileStack = PileStack.new(kind)
	stack.card = Vector2(58.0, 83.0)
	stack.base = Vector2(48.0, 82.0)
	stack.set_count(10)
	host.add_child(stack)
	stack.set_process(false)    # stepped by hand
	return stack


static func _host() -> Control:
	var host: Control = Control.new()
	host.size = Vector2(1180.0, 820.0)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


static func _frames(n: int) -> void:
	for _i: int in range(n):
		await (Engine.get_main_loop() as SceneTree).process_frame
