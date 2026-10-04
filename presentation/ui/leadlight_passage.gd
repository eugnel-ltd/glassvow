class_name LeadlightPassage
extends Control
## The lantern carries you into a room (docs/design/2026-10-03-title-rooms §2,
## §5): one passage, owned by Main, for every room the title opens and every
## room opened in a run. On arrival the title's furniture goes, the lantern is
## lowered along a short arc to the seat (bottom left), the word that was tapped
## rides to the room's crown and becomes it, the veil rises, and the room is
## lit by the lantern's light as it reaches it (the room's own lanes). On
## leaving it all folds back into the flame with a flare, the crown rides back
## to its word, and the word keeps a short afterglow.
##
## Input is never held: the room takes a press from its first frame, a press
## lands an arrival (one on the veil is swallowed; a second tap where the first
## landed, within 300 ms, acts on nothing), and a departure never blocks: the
## leaving room is inert from its first frame and any press lands it. Captures
## and the headless suite (`instant`) land everything on the frame it starts.
## Under Reduce Motion the change is the transition layer's 150 ms cross-fade
## of the frame before it, the lantern landed beneath it coming in from the
## fade's middle; with nothing copied, the room fades over 150 ms.
##
## What the word crosses waits for it: on arrival the room's content under its
## flight rises once it has passed, and on leaving it sets off only once the
## content behind its path is dark, so it never runs through lit text. Every
## departure answers on the frame Return is tapped.

const SWING_FROM: float = 0.38
const AFTERGLOW_FROM: float = 0.36
## The word's flight to the crown, from the tap: it lifts off at once and
## settles into the crown, never outrunning the title's furniture as it goes.
const GHOST_TIME: float = 0.42
const GHOST_CURVE: Vector2i = LeadlightMotion.SETTLE_OUT
## Return comes in once the lantern is nearly seated, never under it in flight.
const SEAT_FROM: float = 0.36
const SEAT_IN: float = 0.16
## On leaving, the lantern sets off home this long after the tap (BREATH).
const LANTERN_BACK_FROM: float = 0.04
## The least time a piece of the title's furniture takes to come back.
const FURNITURE_IN: float = 0.14
## How fast the furniture the word lifts through as it sets off goes (three
## frames), and how soon after the tap the word must reach it to count.
const CROSSED_GONE: float = 0.05
const CROSSED_BEFORE: float = 0.1
const GUARD_TIME: float = 0.3
const GUARD_RADIUS: Vector2 = Vector2(64.0, 44.0)
const POOL_SEATED: float = 0.15
const SINK_TIME: float = 0.16
const DISMISS_TIME: float = 0.18
const SINK_SCALE: float = 0.985
const DEPART: StringName = &"depart"
const RETURN: StringName = &"return"
const SINK: StringName = &"sink"
const LINGER: StringName = &"linger"
const DISMISS: StringName = &"dismiss"


class Arrival:
	var host: LeadlightRoomHost
	var t: float = 0.0
	var word: Control = null
	var ghost: LeadlightGhostWord = null
	## Reduce Motion with nothing copied: the room fades up.
	var fade: bool = false
	## The title's furniture the word lifts through as it sets off (its
	## neighbours): gone in a few frames, before it is there. Found once the
	## room is laid out.
	var crossed: Dictionary = {}
	var crossed_found: bool = false


## Something on its way out: a room (depart, or sinking under a question, or
## lingering over a language reopen), a yes-or-stay sheet, or the title alone
## coming home after a question.
class Leaving:
	var kind: StringName
	var node: Control = null
	var t: float = 0.0
	## Whether the lent title comes home with it.
	var title: bool = false
	var word: Control = null
	var ghost: LeadlightGhostWord = null
	var fade: bool = false
	var order: Array[CanvasItem] = []
	## When each piece of furniture may come back: once the word riding home
	## has passed it (seconds from the tap; 0 when the word never crosses it).
	var holds: Array[float] = []
	var glowed: bool = false
	## A sheet's exit curve (a yes-or-stay sheet's EXIT; the run menu folding
	## as a room opens over it answers at once).
	var curve: Vector2i = LeadlightMotion.EXIT


var sfx: SfxBus = null
## Land every passage on the frame it starts (captures, the headless suite).
var instant: bool = false
## A suite steps the passage by hand (`advance`) in the headless renderer,
## which otherwise lands every passage at once.
var stepped: bool = false
var shape: StringName = StageShape.IDENTITY

## The title lent to the rooms, and the word that opened the last of them.
var _title: TitleScreen = null
var _word: Control = null
## The room open now, whose light follows the lantern every frame.
var _open: LeadlightRoomHost = null
var _arrival: Arrival = null
var _leaving: Array[Leaving] = []
## The double-tap guard: where the opening tap landed and how long it holds.
var _guard_at: Vector2 = Vector2.INF
var _guard_left: float = 0.0
var _press_at: Vector2 = Vector2.INF
## Under Reduce Motion, the lantern landed beneath the cross-fade and how far
## into it: it comes in from the fade's middle.
var _faded_lantern: LeadlightLantern = null
var _faded_t: float = -1.0


func _init(bus: SfxBus = null) -> void:
	name = "LeadlightPassage"
	sfx = bus
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the rooms (200) and the seated lantern (205): the word in flight.
	z_index = 210


# ---------------------------------------------------------------- the rooms

## `host` arrives. `title`, when there is one, lends its lantern; `word_id` is
## the title word that opened it. `faded`: a Reduce Motion cross-fade of the
## frame before is on screen. `landed`: the room is built already arrived (the
## language reopen), silently.
func arrive(host: LeadlightRoomHost, title: TitleScreen = null, word_id: String = "",
		faded: bool = false, landed: bool = false) -> void:
	land_arrival()
	# A sheet folding away (the run menu the room opens over) keeps its exit.
	_land_leaving(false)
	_lantern_whole()
	_open = host
	var lend: bool = title != null and is_instance_valid(title)
	host.lend_seat(lend)
	host.title = title if lend else null
	var word: Control = title.word(word_id) if lend else null
	if lend:
		_title = title
		_title.lend()
		if word != null:
			_word = word
	if not landed and sfx != null and not host.opening_cue().is_empty():
		sfx.play_owed(host.opening_cue(), &"click")
	_guard_at = _press_at
	_guard_left = GUARD_TIME if _guard_at != Vector2.INF else 0.0
	var a: Arrival = Arrival.new()
	a.host = host
	a.word = word
	_arrival = a
	host.arriving = true
	_give_focus.call_deferred(host)
	if instant or landed or (LeadlightMotion.reduced() and faded) or not is_inside_tree():
		_finish_arrival()
		if lend and faded and LeadlightMotion.reduced() and not (instant or landed) and is_inside_tree():
			_lantern_after_fade(title.lantern)
		return
	if LeadlightMotion.reduced():
		# Nothing was copied to cross-fade from: the room fades up over the
		# road, the lantern already at the seat, in REDUCED_FADE.
		a.fade = true
		_apply_arrival(a, host.arrival_time())
		host.modulate.a = 0.0
		return
	if word != null:
		a.ghost = _ghost(word, host.crown())
		word.modulate.a = 0.0
		if a.ghost != null:
			host.ghost_clear = _ghost_clear.bind(a)
	_apply_arrival(a, 0.0)


## `host` leaves (any close path). The title, when lent, comes back at once:
## it takes input from the next frame while the lantern goes home.
func depart(host: LeadlightRoomHost, faded: bool = false) -> void:
	if _arrival != null and _arrival.host == host:
		_finish_arrival()
	host.make_inert()
	if _open == host:
		_open = null
	if sfx != null:
		sfx.play_owed(&"roomClose", &"click")
	_lantern_whole()
	var entry: Leaving = _entry(DEPART, host)
	entry.title = lent_title() != null
	entry.word = _word if entry.title else null
	var lantern: LeadlightLantern = _title.lantern if entry.title else null
	if entry.title:
		_title.begin_return()
	if instant or (LeadlightMotion.reduced() and faded) or not is_inside_tree():
		_finish_leaving(entry, false)
		if lantern != null and faded and LeadlightMotion.reduced() and not instant and is_inside_tree():
			_lantern_after_fade(lantern)
		return
	if LeadlightMotion.reduced():
		entry.fade = true
		_return_title_now(entry)
		_leaving.append(entry)
		return
	if entry.word != null:
		entry.ghost = _ghost(host.crown(), entry.word)
		entry.word.modulate.a = 0.0
		if host.crown() != null:
			host.crown().modulate.a = 0.0
	_furniture_order(entry)
	_leaving.append(entry)
	_apply_leaving(entry, 0.0)


## Settings sinks under the Erase confirm (S5): it fades and settles back, and
## the lantern stays at the seat for the answer.
func sink(host: LeadlightRoomHost, faded: bool = false) -> void:
	if _arrival != null and _arrival.host == host:
		_finish_arrival()
	host.make_inert()
	if _open == host:
		_open = null
	var entry: Leaving = _entry(SINK, host)
	if instant or faded or not is_inside_tree():
		_finish_leaving(entry, false)
		return
	host.pivot_offset = host.size * 0.5
	_leaving.append(entry)


## The confirm was answered Cancel (S6): the lantern goes home and the title's
## furniture comes back, the G2 lanes with no room to leave.
func return_title(faded: bool = false) -> void:
	var title: TitleScreen = lent_title()
	if title == null or not title.lent() or _open != null:
		return
	title.begin_return()
	var entry: Leaving = _entry(RETURN, null)
	entry.title = true
	entry.word = _word
	if instant or faded or LeadlightMotion.reduced() or not is_inside_tree():
		_finish_leaving(entry, false)
		return
	_furniture_order(entry)
	_leaving.append(entry)
	_apply_leaving(entry, 0.0)


## The language reopen (S8): the old room stays frozen on top and fades out
## over the rebuilt title and the new room, built landed beneath it.
func linger(host: LeadlightRoomHost) -> void:
	land_arrival()
	host.make_inert()
	if _open == host:
		_open = null
	_title = null
	_word = null
	host.z_index += 2
	var entry: Leaving = _entry(LINGER, host)
	if instant or not is_inside_tree():
		_finish_leaving(entry, false)
		return
	_leaving.append(entry)


## A yes-or-stay sheet leaves with its own exit (180 ms) instead of vanishing;
## the run menu folds the same way, answering at once (`curve`), when a room
## opens over it.
func dismiss(sheet: Control, faded: bool = false, curve: Vector2i = LeadlightMotion.EXIT) -> void:
	LeadlightRoomHost._ignore(sheet)
	var entry: Leaving = _entry(DISMISS, sheet)
	entry.fade = LeadlightMotion.reduced()
	entry.curve = curve
	if instant or (entry.fade and faded) or not is_inside_tree():
		_finish_leaving(entry, false)
		return
	_leaving.append(entry)


## The title lent to a room is about to go (a route change, the erase flood).
func release_title() -> void:
	_title = null
	_word = null


## Main's route reset: land and free everything held, but a language reopen's
## lingering room, which fades out over the rebuilt route.
func clear() -> void:
	land_arrival()
	_land_leaving()
	_lantern_whole()
	_title = null
	_word = null
	_open = null
	_guard_left = 0.0


func arriving() -> bool:
	return _arrival != null


func leaving() -> bool:
	for entry: Leaving in _leaving:
		if entry.kind != LINGER:
			return true
	return false


## Whether anything it carries is still on screen: a room arriving, or a room
## or sheet leaving or lingering. Main grains the map's whole screen while so.
func carrying() -> bool:
	return _arrival != null or not _leaving.is_empty()


func lent_title() -> TitleScreen:
	return _title if _title != null and is_instance_valid(_title) else null


static func _entry(kind: StringName, node: Control) -> Leaving:
	var entry: Leaving = Leaving.new()
	entry.kind = kind
	entry.node = node
	return entry


# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	advance(delta)


## Move every passage on by `delta` seconds (a suite steps it by hand).
func advance(delta: float) -> void:
	_guard_left = maxf(_guard_left - delta, 0.0)
	if _faded_t >= 0.0:
		_faded_t += minf(delta, TransitionLayer.FADE_STEP_MAX)
		var half: float = LeadlightMotion.REDUCED_FADE * 0.5
		var shown: float = clampf((_faded_t - half) / LeadlightMotion.REDUCED_FADE, 0.0, 1.0)
		if _faded_lantern != null and is_instance_valid(_faded_lantern):
			_faded_lantern.presence = shown
		if shown >= 1.0:
			_lantern_whole()
	if _arrival != null:
		var a: Arrival = _arrival
		if not is_instance_valid(a.host):
			_arrival = null
		elif a.fade:
			a.t += minf(delta, TransitionLayer.FADE_STEP_MAX)
			a.host.modulate.a = clampf(a.t / LeadlightMotion.REDUCED_FADE, 0.0, 1.0)
			if a.t >= LeadlightMotion.REDUCED_FADE:
				_finish_arrival()
		else:
			a.t += delta
			_apply_arrival(a, a.t)
			if a.t >= a.host.arrival_time():
				_finish_arrival()
	for entry: Leaving in _leaving.duplicate():
		entry.t += minf(delta, TransitionLayer.FADE_STEP_MAX) if entry.fade else delta
		if _apply_leaving(entry, entry.t):
			_leaving.erase(entry)
			_finish_leaving(entry, true)
	if _open != null and is_instance_valid(_open) and _arrival == null:
		_hold_seat()


## Land the arrival now: every lane at its end.
func land_arrival() -> void:
	if _arrival != null:
		_finish_arrival()


## Land everything leaving but a language reopen's lingering room; with
## `sheets` false, a sheet's exit runs on too (it is inert already).
func _land_leaving(sheets: bool = true) -> void:
	for entry: Leaving in _leaving.duplicate():
		if entry.kind != LINGER and (sheets or entry.kind != DISMISS):
			_leaving.erase(entry)
			_finish_leaving(entry, false)


# ---------------------------------------------------------------- arrival

func _apply_arrival(a: Arrival, t: float) -> void:
	var host: LeadlightRoomHost = a.host
	host.veil().modulate.a = LeadlightMotion.ease_on(t / 0.32, LeadlightMotion.SETTLE_OUT)
	host.seat().modulate.a = LeadlightMotion.ease_on((t - SEAT_FROM) / SEAT_IN, LeadlightMotion.REVEAL)
	var title: TitleScreen = lent_title()
	if title != null:
		# Gone from the first frame, so the word in flight crosses none of it;
		# what it lifts through on its way goes in a few frames.
		if not a.crossed_found and t > 0.0 and a.ghost != null:
			a.crossed_found = true
			_find_crossed(a, title)
		var gone: float = 1.0 - LeadlightMotion.ease_on(t / 0.18, LeadlightMotion.SETTLE_OUT)
		var quick: float = 1.0 - LeadlightMotion.ease_on(t / CROSSED_GONE, LeadlightMotion.SETTLE_OUT)
		for item: CanvasItem in title.furniture(a.word, host.covers_wordmark()):
			item.modulate.a = quick if a.crossed.has(item) else gone
		# The word is the room's crown now, however it got there.
		if a.word != null and is_instance_valid(a.word):
			a.word.modulate.a = 0.0
		var p: float = LeadlightMotion.ease_on(t / 0.48, LeadlightMotion.IN_OUT)
		title.place_lantern(LeadlightSeat.path(title.home_rect(), _seat_art(), p))
		title.lantern.reach = lerpf(1.0, POOL_SEATED,
			LeadlightMotion.ease_on(t / 0.48, LeadlightMotion.SETTLE_OUT))
		# It swings on its chain as it is set down, and keeps swinging past
		# the room's arrival without holding anything up.
		if t >= SWING_FROM and t < host.arrival_time() and not title.lantern.swinging():
			title.lantern.swing()
	var crown: Control = host.crown()
	if a.ghost != null:
		a.ghost.fly(LeadlightMotion.ease_on(t / GHOST_TIME, GHOST_CURVE), a.word, crown)
		if crown != null:
			crown.modulate.a = 0.0
	elif crown != null:
		crown.modulate.a = LeadlightMotion.ease_on((t - 0.12) / 0.3, LeadlightMotion.REVEAL)
	host.arrive_at(t, _wick(), _colour())


## Every lane at its end; a landed arrival stops the swing it started early.
func _finish_arrival() -> void:
	var a: Arrival = _arrival
	_arrival = null
	if a == null or not is_instance_valid(a.host):
		return
	var host: LeadlightRoomHost = a.host
	var natural: bool = a.t >= host.arrival_time()
	host.arriving = false
	host.ghost_clear = Callable()
	_free(a.ghost)
	a.ghost = null
	_apply_arrival(a, host.arrival_time())
	host.rest(_wick(), _colour())
	host.modulate.a = 1.0
	if host.crown() != null:
		host.crown().modulate.a = 1.0
	var title: TitleScreen = lent_title()
	if title != null and not natural:
		title.lantern.settle()


## The furniture the word's flight to the crown reaches as it sets off
## (inside CROSSED_BEFORE): its neighbours. What it reaches later has dimmed
## by then on its own.
func _find_crossed(a: Arrival, title: TitleScreen) -> void:
	var crown: Control = a.host.crown()
	if crown == null or a.word == null or not is_instance_valid(a.word):
		return
	var from: Vector2 = a.word.get_global_rect().get_center()
	var to: Vector2 = crown.get_global_rect().get_center()
	for item: CanvasItem in title.furniture(a.word, a.host.covers_wordmark()):
		if not (item is Control):
			continue
		# Where it enters the item: where it leaves it on the flight reversed.
		var back: float = LeadlightGhostWord.leaves_at(to, from, a.ghost.half_extent(),
			(item as Control).get_global_rect())
		if back >= 0.0 and GHOST_TIME * LeadlightMotion.inverse_on(1.0 - back, GHOST_CURVE) < CROSSED_BEFORE:
			a.crossed[item] = true


## When the word in flight has passed `rect` (stage px), in seconds from the
## tap: the room's content there waits for it. 0 when it never crosses it.
func _ghost_clear(rect: Rect2, a: Arrival) -> float:
	var crown: Control = a.host.crown() if is_instance_valid(a.host) else null
	if a.ghost == null or crown == null or a.word == null or not is_instance_valid(a.word):
		return 0.0
	var g: float = LeadlightGhostWord.leaves_at(a.word.get_global_rect().get_center(),
		crown.get_global_rect().get_center(), a.ghost.half_extent(), rect)
	return GHOST_TIME * LeadlightMotion.inverse_on(g, GHOST_CURVE) if g > 0.0 else 0.0


## Under Reduce Motion `lantern` stands in its new place beneath the cross-fade
## of the frame before, which still shows it where it was: it comes in from the
## fade's middle, as the old one has half gone, over a fade's length (to 225
## ms), so the two never show at more than half each and no frame carries more
## of the change than the fade's own step (§2.7, as built; §11.5's cut gate).
func _lantern_after_fade(lantern: LeadlightLantern) -> void:
	_lantern_whole()
	_faded_lantern = lantern
	_faded_t = 0.0
	lantern.presence = 0.0


func _lantern_whole() -> void:
	if _faded_lantern != null and is_instance_valid(_faded_lantern):
		_faded_lantern.presence = 1.0
	_faded_lantern = null
	_faded_t = -1.0


func _give_focus(host: LeadlightRoomHost) -> void:
	if is_instance_valid(host) and host.is_inside_tree() and not host.left():
		LeadlightFocus.give(host.first_focus())


## While a room is open the lantern stands at the seat (on any shape the stage
## takes) and the room is lit by its live flame.
func _hold_seat() -> void:
	var title: TitleScreen = lent_title()
	if title != null:
		title.place_lantern(_seat_art())
	_open._light(_wick(), _colour())


# ---------------------------------------------------------------- leaving

## One leaving entry at `t`; true once it is done.
func _apply_leaving(entry: Leaving, t: float) -> bool:
	var node: Control = entry.node if is_instance_valid(entry.node) else null
	if entry.kind == SINK:
		var p: float = LeadlightMotion.ease_on(t / SINK_TIME, LeadlightMotion.EXIT)
		if node != null:
			node.modulate.a = 1.0 - p
			node.scale = Vector2.ONE * lerpf(1.0, SINK_SCALE, p)
		return t >= SINK_TIME
	if entry.kind == LINGER or (entry.fade and entry.kind != DISMISS):
		if node != null:
			node.modulate.a = 1.0 - clampf(t / LeadlightMotion.REDUCED_FADE, 0.0, 1.0)
		return t >= LeadlightMotion.REDUCED_FADE
	if entry.kind == DISMISS:
		var span: float = LeadlightMotion.REDUCED_FADE if entry.fade else DISMISS_TIME
		var q: float = clampf(t / span, 0.0, 1.0) if entry.fade \
			else LeadlightMotion.ease_on(t / span, entry.curve)
		if node != null:
			node.modulate.a = 1.0 - q
		return t >= span
	# A room leaving (depart) or the title alone coming home (return).
	var host: LeadlightRoomHost = node as LeadlightRoomHost
	var span_out: float = host.departure_time() if host != null else 0.40
	if host != null:
		# Every lane answers on the frame Return is tapped.
		host.leave_at(t, _wick(), _colour())
		host.veil().modulate.a = 1.0 - LeadlightMotion.ease_on(t / span_out, LeadlightMotion.SETTLE_OUT)
		host.seat().modulate.a = 1.0 - LeadlightMotion.ease_on(t / 0.16, LeadlightMotion.SETTLE_OUT)
	if entry.title:
		_return_lanes(entry, host, t, span_out)
	return t >= span_out


## The title's half of G2: the lantern home with a flare, the furniture back
## nearest the lantern first once the room's content has gone, the crown riding
## back to its word once what lies behind its path is dark, and the word glows.
## The lantern rises on a sine, never the cubic's lag then whip.
func _return_lanes(entry: Leaving, host: LeadlightRoomHost, t: float, span: float) -> void:
	var title: TitleScreen = lent_title()
	if title == null:
		return
	var p: float = LeadlightMotion.ease_on((t - LANTERN_BACK_FROM) / (span - LANTERN_BACK_FROM),
		LeadlightMotion.BREATH)
	title.place_lantern(LeadlightSeat.path(title.home_rect(), _seat_art(), 1.0 - p))
	title.lantern.reach = lerpf(POOL_SEATED, 1.0, p)
	title.lantern.flare = 0.35 * sin(PI * clampf((t - (span - 0.2)) / 0.2, 0.0, 1.0))
	# Each piece takes at least FURNITURE_IN to come back, easing in (a quint's
	# first frame put the wordmark at half in one step behind How to Play).
	var stagger: float = minf(0.03, 0.08 / maxf(float(entry.order.size() - 1), 1.0))
	var back: float = host.furniture_returns_at() if host != null else 0.16
	for i: int in entry.order.size():
		var item: CanvasItem = entry.order[i]
		if is_instance_valid(item):
			var from: float = minf(maxf(back + stagger * float(i), entry.holds[i] if i < entry.holds.size() else 0.0),
				span - FURNITURE_IN)
			item.modulate.a = LeadlightMotion.ease_on((t - from) / (span - from), LeadlightMotion.SETTLE_OUT)
	var word: Control = entry.word if is_instance_valid(entry.word) else null
	if entry.ghost != null:
		var leaves: float = host.crown_leaves_at() if host != null else 0.0
		entry.ghost.fly(LeadlightMotion.ease_on((t - leaves) / (AFTERGLOW_FROM - leaves), LeadlightMotion.REVEAL),
			host.crown() if host != null else null, word)
	if t >= AFTERGLOW_FROM and not entry.glowed:
		entry.glowed = true
		_free(entry.ghost)
		entry.ghost = null
		if word != null:
			word.modulate.a = 1.0
			if word is LeadlightWord and t < span + 0.1:
				(word as LeadlightWord).afterglow()


func _finish_leaving(entry: Leaving, natural: bool) -> void:
	if entry.kind == DEPART or entry.kind == RETURN:
		if not entry.fade and entry.title:
			_apply_leaving(entry, 99.0)
		_free(entry.ghost)
		entry.ghost = null
		var word: Control = entry.word if is_instance_valid(entry.word) else null
		if word != null:
			word.modulate.a = 1.0
			if not natural and word is LeadlightWord:
				(word as LeadlightWord).quench()
		if entry.title:
			_return_title_now(entry)
	var node: Control = entry.node if is_instance_valid(entry.node) else null
	if node != null:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	entry.node = null


## The title back whole, its lantern home and lit as it rests.
func _return_title_now(entry: Leaving) -> void:
	var title: TitleScreen = lent_title()
	entry.title = false
	if title == null:
		return
	var host: LeadlightRoomHost = entry.node as LeadlightRoomHost if is_instance_valid(entry.node) else null
	if host != null:
		host.title_returns()
		host.title = null
	for item: CanvasItem in title.furniture(null, true):
		item.modulate.a = 1.0
	title.lantern.flare = 0.0
	title.lantern.reach = 1.0
	title.reclaim()
	_title = null


func _furniture_order(entry: Leaving) -> void:
	var title: TitleScreen = lent_title()
	if title == null:
		return
	var home: Vector2 = title.home_rect().get_center()
	var items: Array[CanvasItem] = []
	var host: LeadlightRoomHost = entry.node as LeadlightRoomHost if is_instance_valid(entry.node) else null
	for item: CanvasItem in title.furniture(entry.word, host != null and host.covers_wordmark()):
		items.append(item)
	items.sort_custom(func(a: CanvasItem, b: CanvasItem) -> bool:
		return _centre_of(a).distance_to(home) < _centre_of(b).distance_to(home))
	entry.order = items
	entry.holds.clear()
	for item: CanvasItem in items:
		entry.holds.append(_passed_on_return(entry, host, item))


## When the word riding home from `host`'s crown has passed `item` (seconds
## from the tap), so the furniture it crosses comes back behind it; 0 when it
## never crosses it.
func _passed_on_return(entry: Leaving, host: LeadlightRoomHost, item: CanvasItem) -> float:
	var crown: Control = host.crown() if host != null else null
	if entry.ghost == null or crown == null or not (item is Control) or not is_instance_valid(entry.word):
		return 0.0
	var g: float = LeadlightGhostWord.leaves_at(crown.get_global_rect().get_center(),
		entry.word.get_global_rect().get_center(), entry.ghost.half_extent(), (item as Control).get_global_rect())
	if g <= 0.0:
		return 0.0
	var leaves: float = host.crown_leaves_at()
	return leaves + (AFTERGLOW_FROM - leaves) * LeadlightMotion.inverse_on(g, LeadlightMotion.REVEAL)


static func _centre_of(item: CanvasItem) -> Vector2:
	if item is Control:
		return (item as Control).get_global_rect().get_center()
	return Vector2.ZERO


func _ghost(from: Control, to: Control) -> LeadlightGhostWord:
	var ghost: LeadlightGhostWord = LeadlightGhostWord.between(from, to)
	if ghost != null:
		ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ghost)
	return ghost


static func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


# ---------------------------------------------------------------- the light

func _seat_art() -> Rect2:
	var seat: Dictionary = LeadlightSeat.for_stage(shape, _stage())
	var art: Rect2 = seat["art"]
	return art


func _stage() -> Vector2:
	if size.y > 0.0:
		return size
	var reference: Vector2i = StageShape.REFERENCES.get(shape, Vector2i(1180, 820))
	return Vector2(reference)


func _wick() -> Vector2:
	var title: TitleScreen = lent_title()
	if title != null:
		return title.wick_on_stage()
	# In a run there is no title lantern: the room is lit from the bottom-left.
	return Vector2(0.0, _stage().y)


func _colour() -> Color:
	var title: TitleScreen = lent_title()
	return title.lantern.light() if title != null else LeadlightTokens.EMBER


# ---------------------------------------------------------------- input

## A press lands what is moving: an arriving room (a second tap where the
## first landed, inside GUARD_TIME, acts on nothing), and every room leaving.
## Never consumed otherwise: the press acts where it lands.
func _input(event: InputEvent) -> void:
	var press: bool = _is_press(event)
	if press:
		_press_at = _position_of(event)
	elif event is InputEventKey and event.is_pressed():
		_press_at = Vector2.INF
	if press and _guard_left > 0.0 and _press_at.distance_to(_guard_at) <= _guard_radius():
		LeadlightFocus.note(event)
		get_viewport().set_input_as_handled()
		if _arrival != null:
			_arrival.host.swallow_press()
			_finish_arrival()
		return
	if _arrival != null:
		if press:
			_arrival.host.swallow_press()
			_finish_arrival()
		elif event.is_action_pressed(&"ui_accept"):
			LeadlightFocus.note(event)
			get_viewport().set_input_as_handled()
			_finish_arrival()
	if press and leaving():
		_land_leaving()


func _guard_radius() -> float:
	return GUARD_RADIUS.y if LeadlightTokens.is_phone(shape) else GUARD_RADIUS.x


static func _is_press(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		return button.pressed and button.button_index == MOUSE_BUTTON_LEFT
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	return touch != null and touch.pressed


static func _position_of(event: InputEvent) -> Vector2:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		return button.position
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	return touch.position if touch != null else Vector2.INF
