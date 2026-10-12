extends RefCounted
## The paced floor bake's waits (#682, FloorBake `SETTLE_S`): a bake that may
## wait neither switches the soft key (the warm draw) nor draws its first real
## tile until the pipelines the draw before it queued have compiled (a canary
## task on each queue of the worker pool, then `SETTLE_S`), and it holds no
## frame while it waits; a bake that may not wait (a map waiting for its land)
## goes straight on. The draws themselves, and that no step holds the main
## thread, are the windowed proof's (tools/check_floor_bake.gd); here the bake
## has no views, so its steps draw nothing.

const Bake = preload("res://presentation/map/landscape/floor_bake.gd")
## The most one call may hold the main thread while the bake waits (ms).
const CALL_LIMIT_MS: float = 20.0
## Process frames a wait may take at the headless runner's pace.
const FRAME_LIMIT: int = 2000


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_floor_bake_gate: %s" % what)


static func run(fails: Array[String]) -> void:
	await _paced_waits(fails)
	_unpaced_goes_on(fails)


## A bake standing at `step`, its views stood in for: only the mask view is
## touched by the steps run here.
static func _bake(step: Bake.Step, may_wait: bool) -> Bake:
	var bake: Bake = Bake.new(null, null, true)
	bake.may_wait = may_wait
	bake.step = step
	bake._mask_view = SubViewport.new()
	return bake


static func _let_go(bake: Bake) -> void:
	var mask: SubViewport = bake._mask_view
	bake.cancel()
	mask.free()


## Each wait spans frames and at least `SETTLE_S`, records no step, holds no
## frame, and ends in the step it guards.
static func _paced_waits(fails: Array[String]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bake: Bake = _bake(Bake.Step.WARM, true)
	for guarded: Bake.Step in [Bake.Step.WARM, Bake.Step.FIELDS]:
		var steps: int = bake._steps_ms.size()
		var started: int = Time.get_ticks_msec()
		var calls: int = 0
		var held_ms: float = 0.0
		while bake.step == guarded and calls < FRAME_LIMIT:
			var before: int = Time.get_ticks_usec()
			bake.advance()
			held_ms = maxf(held_ms, (Time.get_ticks_usec() - before) / 1000.0)
			calls += 1
			await tree.process_frame
		var waited_ms: int = Time.get_ticks_msec() - started
		var name: String = Bake.Step.keys()[guarded]
		_check(fails, waited_ms >= roundi(Bake.SETTLE_S * 1000.0) and calls > 2,
			"a paced bake at %s waits for the pipelines (%d ms over %d calls, want >= %d ms)" % [
				name, waited_ms, calls, roundi(Bake.SETTLE_S * 1000.0)])
		_check(fails, bake._steps_ms.size() == steps + 1,
			"a paced bake at %s runs its step once, after the wait (%d steps)" % [name, bake._steps_ms.size() - steps])
		_check(fails, held_ms < CALL_LIMIT_MS,
			"a paced bake at %s holds no frame while it waits (longest call %.1f ms)" % [name, held_ms])
	_check(fails, bake.step == Bake.Step.TILES and bake._soft_set,
		"after both waits the soft key is set and the first tile is drawn (%s)" % Bake.Step.keys()[bake.step])
	_let_go(bake)
	_check(fails, not bake._soft_set and bake._canaries.is_empty(),
		"a bake let go puts the soft key back and hands its canaries on")


## A bake that may not wait switches the soft key and draws its first tile in
## the next two calls.
static func _unpaced_goes_on(fails: Array[String]) -> void:
	var bake: Bake = _bake(Bake.Step.WARM, false)
	bake.advance()
	var warmed: bool = bake.step == Bake.Step.FIELDS and bake._soft_set
	bake.advance()
	_check(fails, warmed and bake.step == Bake.Step.TILES and bake._canaries.is_empty(),
		"a bake that may not wait warms and draws its first tile without waiting (%s)" % Bake.Step.keys()[bake.step])
	_let_go(bake)
