class_name EventSequencer
extends RefCounted
## Await-pump over GameEvent batches (plan M5): one event at a time, in
## order; the screen locks input while the pump is busy. The engine mutates
## state to the END of a batch before events return, so handlers must render
## from event-carried fields — live state is only safe once `busy_changed`
## goes false.
##
## `instant` (headless tests) makes the whole drain synchronous: handlers
## must not execute any `await` when it is set.

signal busy_changed(busy: bool)

## func(ev: Dictionary) -> void; may await tweens/timers when not instant.
var handler: Callable
var instant: bool = false
var _queue: Array[Dictionary] = []
var _busy: bool = false


func is_busy() -> bool:
	return _busy


## How many events of type `t` this one heads, counting itself. A wave of draws
## is paced by how big the wave is (`drawBatchSchedule`, pile-chrome.js:58), and
## a handler that only ever sees one event at a time cannot know that without
## asking. Only meaningful from inside `handler`, where the current event has
## already left the queue.
func run_length(t: StringName) -> int:
	var n: int = 1
	for ev: Dictionary in _queue:
		if ev["t"] != t:
			break
		n += 1
	return n


## The type of the first event still queued that is one of `types` and
## carries this card's `uid`, or &"" for none. A played card's own events
## follow it in the same batch, so its handler can see where the card is going
## (its discard, its exhaust or the power it becomes) before it gets there.
func next_for(uid: int, types: Array[StringName]) -> StringName:
	for ev: Dictionary in _queue:
		var t: StringName = ev["t"]
		if types.has(t) and ev.get("uid", -1) == uid:
			return t
	return &""


## How the events still queued will change a pile's count, by the time the
## batch is drained: the domain has already moved its cards, so the screen
## shows a pile as the domain left it less this, and a pile counts only what
## has happened on screen. A draw takes one from the draw pile and a reshuffle
## moves the discard into it; a card sent to the discard (played, swept at the
## end of a turn or added there) adds one to it; a burnt one adds one to the
## ash. `pile` is &"draw", &"discard" or &"ashes". A card in `flying` is on
## its way there already and is counted by whoever flies it, so its own event
## here is not counted again.
func pile_change(pile: StringName, flying: Array[int] = []) -> int:
	var n: int = 0
	for ev: Dictionary in _queue:
		var t: StringName = ev["t"]
		var uid: int = ev.get("uid", -1)
		match t:
			EventTypes.DRAW:
				n -= 1 if pile == &"draw" else 0
			EventTypes.RESHUFFLE:
				var moved: int = ev.get("n", 0)
				n += moved if pile == &"draw" else (-moved if pile == &"discard" else 0)
			EventTypes.TO_DISCARD:
				n += 1 if pile == &"discard" and not flying.has(uid) else 0
			EventTypes.DISCARD_HAND:
				if pile == &"discard":
					for each: Variant in ev.get("uids", []):
						var swept: int = each
						n += 0 if flying.has(swept) else 1
			EventTypes.EXHAUST:
				n += 1 if pile == &"ashes" and not flying.has(uid) else 0
			&"addCard":
				n += 1 if pile == &"discard" and str(ev.get("where", "")) == "discard" else 0
	return n


func enqueue(events: Array[Dictionary]) -> void:
	_queue.append_array(events)
	if not _busy:
		_pump()


func _pump() -> void:
	_busy = true
	busy_changed.emit(true)
	while not _queue.is_empty():
		var ev: Dictionary = _queue.pop_front()
		if instant:
			handler.call(ev)  # coroutine with no taken awaits completes inline
		else:
			await handler.call(ev)
	_busy = false
	busy_changed.emit(false)
