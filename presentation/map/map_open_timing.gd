class_name MapOpenTiming
extends RefCounted
## Phase clock for one `Main._show_map`, read by `tools/bench_map_open.gd`
## (`--map --map-timing`). Off unless that bench turns it on: the player path
## pays one clock read and one bool test per phase, and never prints.

static var enabled: bool = false
static var _phases: Dictionary[String, int] = {}
static var _started: int = 0


static func now() -> int:
	return Time.get_ticks_usec()


## Opens a record for one map open and drops the previous one.
static func begin() -> void:
	if not enabled:
		return
	_phases.clear()
	_started = now()


## Adds the time since `since` (a `now()` reading) to `phase`.
static func add(phase: String, since: int) -> void:
	if not enabled:
		return
	_phases[phase] = _phases.get(phase, 0) + now() - since


## Closes the record: `total` is the time since `begin`.
static func finish() -> void:
	if not enabled:
		return
	_phases["total"] = now() - _started


## The last record in milliseconds, one entry per phase and `total`.
static func report() -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	for phase: String in _phases:
		out[phase] = _phases[phase] / 1000.0
	return out
