class_name TitleKindling
extends RefCounted
## The launch rite (docs/design/2026-10-02-opening-start §7 T1). One wordless
## shot: the ember breathes, the flame catches, the glass takes light, the
## light reaches out across the road while the lamplighter chain runs the
## roadside lanterns to the sealed door, and the wordmark is lit last.
##
##   0.0–0.4  ember breathes            (first launch holds here for language)
##   0.4–0.9  the flame catches          CATCH
##   0.9–1.5  the glass takes light      BREATH
##   1.3–2.4  light reach + lamp chain   REVEAL
##   1.9–2.4  wordmark, words, rose      REVEAL

const HOLD: float = 0.4
const LENGTH: float = 2.4


## `t` holds the targets: lantern, world, veil, chain, wordmark, words (Array of
## CanvasItem) and rose.
static func build(t: Dictionary) -> LeadlightRite:
	var lantern: LeadlightLantern = t["lantern"]
	var world: TitleWorld = t["world"]
	var veil: TitleVeil = t["veil"]
	var chain: TitleLampChain = t["chain"]
	var wordmark: CanvasItem = t["wordmark"]
	var rose: LeadlightRose = t["rose"]
	var words: Array = t["words"]
	var breathe: Callable = func(p: float) -> void:
		lantern.kindle = 0.05 + 0.1 * p
	# Each later step leaves the lantern alone until it begins, so the steps
	# hand the flame on rather than fighting over it.
	var catch_flame: Callable = func(p: float) -> void:
		if p > 0.0:
			lantern.kindle = 0.15 + 0.45 * p
	var take_light: Callable = func(p: float) -> void:
		if p > 0.0:
			lantern.kindle = 0.6 + 0.4 * p
	var light_reach: Callable = func(p: float) -> void:
		veil.reach = p
		veil.strength = 1.0 - smoothstep(0.82, 1.0, p)
		world.lamplight = p
		chain.progress = p
		lantern.reach = p
	var name_the_place: Callable = func(p: float) -> void:
		wordmark.modulate.a = p
		if rose != null:
			rose.glow = p
		for item_v: Variant in words:
			if item_v is CanvasItem:
				var item: CanvasItem = item_v
				item.modulate.a = p
	var rite: LeadlightRite = LeadlightRite.new()
	rite.step(0.0, HOLD, breathe, LeadlightMotion.BREATH)
	rite.step(HOLD, 0.9, catch_flame, LeadlightMotion.CATCH)
	rite.step(0.9, 1.5, take_light, LeadlightMotion.BREATH)
	rite.step(1.3, LENGTH, light_reach, LeadlightMotion.REVEAL)
	rite.step(1.9, LENGTH, name_the_place, LeadlightMotion.REVEAL)
	return rite
