class_name LeadlightRite
extends RefCounted
## A skippable timeline: the kindling, the first launch and the opening hand-off
## are rites (docs/design/2026-10-02-opening-start §7).
##
## A rite is a list of steps, each a span of seconds and a Callable that takes
## its eased progress 0..1. The owner drives it with `advance(delta)` from its
## own `_process`, so a test can step it by hand and a still is the same still
## every time. `skip()` lands every step at 1.0 — the one-tap rule. Under
## Reduce Motion `start()` lands it at once. A rite may `hold_at` a time (the
## language question waits there) until `release()`.

signal finished

var _steps: Array[Dictionary] = []
var _cues: Array[Dictionary] = []
var _time: float = 0.0
var _duration: float = 0.0
var _hold: float = -1.0
var _running: bool = false
var _done: bool = false


## Add a step over [from, to] seconds. `apply` receives eased progress 0..1.
func step(from: float, to: float, apply: Callable,
		curve: Vector2i = LeadlightMotion.REVEAL) -> LeadlightRite:
	_steps.append({"from": from, "to": maxf(to, from), "apply": apply, "curve": curve})
	_duration = maxf(_duration, to)
	return self


## Fire `cue` once when the clock passes `at` seconds (a sound). A skipped rite
## lands silently: cues still pending are dropped, never fired in a burst.
func at(time_s: float, cue: Callable) -> LeadlightRite:
	_cues.append({"at": time_s, "cue": cue, "fired": false})
	return self


## Pause the clock at `at` seconds until `release()`.
func hold_at(at: float) -> LeadlightRite:
	_hold = at
	return self


func release() -> void:
	_hold = -1.0


func held() -> bool:
	return _running and _hold >= 0.0 and _time >= _hold


func duration() -> float:
	return _duration


func time() -> float:
	return _time


func is_running() -> bool:
	return _running


func is_done() -> bool:
	return _done


func start() -> void:
	_time = 0.0
	_running = true
	_done = false
	_apply_all()
	if LeadlightMotion.reduced() and _hold < 0.0:
		skip()


func advance(delta: float) -> void:
	if not _running:
		return
	var limit: float = _hold if _hold >= 0.0 else _duration
	_time = minf(_time + maxf(delta, 0.0), maxf(limit, _time))
	_apply_all()
	for c: Dictionary in _cues:
		var due: float = c["at"]
		if not c["fired"] and _time >= due:
			c["fired"] = true
			var cue: Callable = c["cue"]
			if cue.is_valid():
				cue.call()
	if _time >= _duration and _hold < 0.0:
		_finish()


## Land every step at its end. A held rite is released first: skipping the
## kindling must never strand the language question half-built, so an owner
## that holds should not offer skip until it releases.
func skip() -> void:
	if _done:
		return
	_hold = -1.0
	_time = _duration
	_running = true
	for c: Dictionary in _cues:
		c["fired"] = true
	_apply_all()
	_finish()


## Re-apply every step at the current time (after anything else moved the
## targets, such as the title's frame-0 pipeline warm-up).
func refresh() -> void:
	_apply_all()


func _apply_all() -> void:
	for s: Dictionary in _steps:
		var from: float = s["from"]
		var to: float = s["to"]
		var raw: float = 1.0 if to <= from and _time >= from \
			else clampf((_time - from) / maxf(to - from, 0.0001), 0.0, 1.0)
		var apply: Callable = s["apply"]
		var curve: Vector2i = s["curve"]
		if apply.is_valid():
			apply.call(LeadlightMotion.ease_on(raw, curve))


func _finish() -> void:
	if _done:
		return
	_running = false
	_done = true
	finished.emit()
