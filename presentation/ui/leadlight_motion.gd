class_name LeadlightMotion
extends RefCounted
## Leadlight's motion vocabulary (docs/design/2026-10-02-opening-start §7, §8.2).
##
## Motion is ceremony, never friction: every helper here reads Reduce Motion in
## this one place, and under it a state lands whole — an opacity change of at
## most REDUCED_FADE, never a travel, a scale or a wait.

const TICK: float = 0.09
const QUICK: float = 0.18
const SETTLE: float = 0.32
const CEREMONY: float = 0.6
const RITE_MAX: float = 3.0
const SKIP: float = 0.12
const REDUCED_FADE: float = 0.15
## How far an entering element rises into place.
const RISE: float = 12.0
## The press: down to this scale, with a flare.
const PRESS_SCALE: float = 0.97

## Curves as Tween (transition, ease) pairs.
const REVEAL: Vector2i = Vector2i(Tween.TRANS_QUINT, Tween.EASE_OUT)
const EXIT: Vector2i = Vector2i(Tween.TRANS_CUBIC, Tween.EASE_IN)
const BREATH: Vector2i = Vector2i(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
const CATCH: Vector2i = Vector2i(Tween.TRANS_BACK, Tween.EASE_OUT)
const SETTLE_OUT: Vector2i = Vector2i(Tween.TRANS_CUBIC, Tween.EASE_OUT)
const IN_OUT: Vector2i = Vector2i(Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)


static func reduced() -> bool:
	return Preferences.active != null and Preferences.active.reduce_motion


## Eased progress 0..1 at `t` (0..1) on a curve. Pure.
static func ease_on(t: float, curve: Vector2i) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	var eased: float = Tween.interpolate_value(0.0, 1.0, clamped, 1.0,
		curve.x as Tween.TransitionType, curve.y as Tween.EaseType)
	return eased


## The `t` (0..1) at which `curve` has eased to `eased` (0..1): `ease_on`'s
## inverse, for a curve that only rises. Pure.
static func inverse_on(eased: float, curve: Vector2i) -> float:
	var target: float = clampf(eased, 0.0, 1.0)
	var lo: float = 0.0
	var hi: float = 1.0
	for _i: int in range(24):
		var mid: float = (lo + hi) * 0.5
		if ease_on(mid, curve) < target:
			lo = mid
		else:
			hi = mid
	return hi


## Fade an element in, rising RISE px into its seat. Returns the tween, or null
## when nothing needs to move (already shown, or Reduce Motion with `instant`).
static func enter(node: CanvasItem, delay: float = 0.0, time: float = SETTLE) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween: Tween = node.create_tween()
	if reduced():
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, REDUCED_FADE).set_delay(delay)
		return tween
	node.modulate.a = 0.0
	tween.set_parallel()
	tween.tween_property(node, "modulate:a", 1.0, time).set_delay(delay) \
		.set_trans(REVEAL.x as Tween.TransitionType).set_ease(REVEAL.y as Tween.EaseType)
	if node is Control:
		var control: Control = node as Control
		var seat: float = control.position.y
		control.position.y = seat + RISE
		tween.tween_property(control, "position:y", seat, time).set_delay(delay) \
			.set_trans(REVEAL.x as Tween.TransitionType).set_ease(REVEAL.y as Tween.EaseType)
	return tween


## Fade an element out. Reduce Motion: a short fade only.
static func exit(node: CanvasItem, time: float = SETTLE) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, REDUCED_FADE if reduced() else time) \
		.set_trans(EXIT.x as Tween.TransitionType).set_ease(EXIT.y as Tween.EaseType)
	return tween


## The press: a short dip and return. Under Reduce Motion nothing scales.
static func press(control: Control) -> Tween:
	if control == null or not control.is_inside_tree() or reduced():
		return null
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * PRESS_SCALE, TICK) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, QUICK) \
		.set_trans(CATCH.x as Tween.TransitionType).set_ease(CATCH.y as Tween.EaseType)
	return tween


## Tween a focus amount (0..1) on a node's `focus_glow` property, if it has one.
static func focus(node: Object, on: bool) -> Tween:
	if not (node is Node) or not "focus_glow" in node:
		return null
	var target: float = 1.0 if on else 0.0
	if reduced() or not (node as Node).is_inside_tree():
		node.set("focus_glow", target)
		return null
	var tween: Tween = (node as Node).create_tween()
	tween.tween_property(node, "focus_glow", target, QUICK) \
		.set_trans(SETTLE_OUT.x as Tween.TransitionType).set_ease(SETTLE_OUT.y as Tween.EaseType)
	return tween


## A chain of `count` lights catching one after another as `progress` runs
## 0..1: light `index` (0 first) is how lit? Each catches over its own slice,
## overlapping the next a little, so the light walks rather than steps. Pure.
static func chain(progress: float, index: int, count: int) -> float:
	if progress >= 1.0:
		return 1.0
	var span: float = 1.0 / float(maxi(count, 1))
	return clampf((progress - float(index) * span * 0.85) / (span * 1.6), 0.0, 1.0)


## A slow breath, -1..1, for anything that idles (the flame's pool). Still
## under Reduce Motion. Pure in `time`.
static func breath(time: float, period: float = 2.8) -> float:
	if reduced():
		return 0.0
	return sin(time * TAU / period)
