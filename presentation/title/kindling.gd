class_name TitleKindling
extends RefCounted
## The launch rite (docs/design/2026-10-02-opening-start §7 T1). One wordless
## shot: the ember breathes, the flame catches, the glass takes light, the
## light reaches out across the road while the lamplighter chain runs the
## roadside lanterns to the sealed door, and the wordmark is lit last.
##
##   0.0–0.4  the ember breathes        (first launch holds here for language)
##   0.3–1.5  the flame catches and the glass takes light, one rise
##   1.1–2.4  light reach + lamp chain, crossfading in under the glass
##   1.9–2.4  wordmark, words, rose      REVEAL
##
## The ember is the lantern's own flame (lantern_flame.gdshader, isolate),
## small and breathing from frame 0, growing until the glass takes it over.

const HOLD: float = 0.4
const LENGTH: float = 2.4
## How far the caught flame lights the road before the light reaches out.
const EMBER_REACH: float = 0.08


## The rite's one clock, linear: every ramp below is a function of the time
## itself, so no step hands over to another and nothing restarts.
const LINEAR: Vector2i = Vector2i(Tween.TRANS_LINEAR, Tween.EASE_IN)


## How lit the lantern is at `t` seconds: the ember breathes up to ~0.17 by the
## hold, then catches and takes the glass in one continuous rise. Two
## overlapping smoothsteps, so the rate never jumps (build 18: "the light up
## seems not too smooth" — a back-eased catch overshot and the next step
## pulled it back). Pure.
static func kindle_at(t: float) -> float:
	return 0.05 + 0.12 * smoothstep(0.0, HOLD, t) + 0.83 * smoothstep(0.3, 1.5, t)


## The light's reach over the road at `t`: the caught flame's small circle,
## crossfading into the full reach as the world is revealed. Pure.
static func reach_at(t: float) -> float:
	return EMBER_REACH * smoothstep(0.3, 1.0, t) + (1.0 - EMBER_REACH) * smoothstep(1.1, LENGTH, t)


## The world's lamplight, the chain and the lantern's pool at `t`: they begin
## while the glass is still taking light, not after it. Pure.
static func world_at(t: float) -> float:
	return smoothstep(1.1, LENGTH, t)


## `t` holds the targets: lantern, world, veil, chain, wordmark, words (Array of
## CanvasItem), rose and, optionally, sfx (the bus its cues play on).
static func build(t: Dictionary) -> LeadlightRite:
	var lantern: LeadlightLantern = t["lantern"]
	var world: TitleWorld = t["world"]
	var veil: TitleVeil = t["veil"]
	var chain: TitleLampChain = t["chain"]
	var wordmark: CanvasItem = t["wordmark"]
	var rose: LeadlightRose = t["rose"]
	var words: Array = t["words"]
	# Frame 0 is the boot splash: one small flame, nothing else. The lantern
	# comes up round it as it breathes.
	var kindle: Callable = func(p: float) -> void:
		var at: float = p * LENGTH
		lantern.kindle = kindle_at(at)
		lantern.presence = smoothstep(0.0, HOLD, at)
		veil.reach = reach_at(at)
		veil.strength = 1.0 - smoothstep(LENGTH - 0.45, LENGTH, at)
		var lit: float = world_at(at)
		world.lamplight = lit
		chain.progress = lit
		lantern.reach = lit
	var name_the_place: Callable = func(p: float) -> void:
		wordmark.modulate.a = p
		if rose != null:
			rose.glow = p
		for item_v: Variant in words:
			if item_v is CanvasItem:
				var item: CanvasItem = item_v
				item.modulate.a = p
	# Frame 0, before any step: night, every roadside lamp out, no reach.
	veil.reach = 0.0
	veil.strength = 1.0
	world.lamplight = 0.0
	chain.progress = 0.0
	lantern.reach = 0.0
	var rite: LeadlightRite = LeadlightRite.new()
	rite.step(0.0, LENGTH, kindle, LINEAR)
	rite.step(1.9, LENGTH, name_the_place, LeadlightMotion.REVEAL)
	var sfx: SfxBus = t.get("sfx", null)
	if sfx != null:
		# Commissioned cues with the ledger's fallbacks (docs/sfx-ledger.md).
		rite.at(HOLD, func() -> void: sfx.play_owed(&"kindleCatch", &"kindle"))
		rite.at(0.9, func() -> void: sfx.play_owed(&"glassTakesLight"))
	return rite
