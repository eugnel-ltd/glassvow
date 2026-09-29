extends RefCounted
## The combat HUD's lantern, read live (flame lock §5 and §9; the presentation
## half of lock PR 4). The rules' own numbers are tests/test_flame_lantern.gd's;
## these pin what the presenter shows of them: the Art's tooltip quotes the
## fight's price, as the lantern's quality has moved it, and the ring draws one
## pip per Ember the lantern can hold, however high a Steady flame and a Crown of
## Cinders have raised the cap. Visual proof, before and after at the pad and
## phone shapes, is docs/design/2026-09-29-dusk-flame/hud/art-price-pips-pad.png
## and art-price-pips-phone.png.

const FlameLantern: GDScript = preload("res://tests/test_flame_lantern.gd")

## The shipped calibration's cap, and cost knobs with a Soot price distinct from
## a True one so a tip that read the wrong knob shows: Flare (3) costs 5 at Soot
## and 2 at True.
const SOOT_ART_COST: int = 2
const TRUE_ART_COST: int = 1
const STEADY_CAP: int = 2
const CROWN_CAP: int = 12
const KNOBS: Dictionary = {
	"sootLeak": 1, "sootArtCost": SOOT_ART_COST, "steadyCap": STEADY_CAP,
	"steadyFirstGain": 1, "trueArtCost": TRUE_ART_COST,
}
const SEED: int = 58601
const NO_RELICS: Array[String] = []
const CROWN: Array[String] = ["crownOfCinders"]
## Where a pip sits, pinned as the lantern has always drawn it: the centre of
## the 104 box, the ring's radius and the arc's ends.
const RING_CENTRE: Vector2 = Vector2(52.0, 52.0)
const RING_RADIUS: float = 50.0
const ARC_FROM: float = -140.0
const ARC_TO: float = 140.0
const EPS: float = 0.001


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_lantern_hud: %s" % what)


static func run(fails: Array[String]) -> void:
	_art_price_by_tier(fails)
	_art_price_follows_the_run_art(fails)
	_art_price_is_read_each_time(fails)
	_ring_follows_the_cap(fails)
	_ring_is_born_unlit(fails)
	_combat_draws_every_pip(fails)


# ---------------------------------------------------------------- the Art's price

## A fight begun on `deck`'s tier, on a real combat screen.
static func _screen(content: ContentDB, deck: Array, relics: Array[String] = NO_RELICS,
		art: StringName = &"") -> CombatScreen:
	var run_state: RunState = RunState.new_run(content, SEED, "lantern-hud")
	var removed: Array = deck[1]
	for id_v: Variant in removed:
		for card: CardInst in run_state.player.deck:
			if String(card.id) == str(id_v):
				run_state.player.deck.erase(card)
				break
	var added: Array = deck[2]
	for id_v: Variant in added:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(str(id_v)), false))
	run_state.player.relics.append_array(relics)
	if art != &"":
		run_state.art = art
	var screen: CombatScreen = CombatScreen.new(GlassvowGame.new(content, run_state))
	screen.seq.instant = true
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	screen.start_encounter(["sporeling"], "normal", "lantern hud")
	return screen


## The tip's lead, as the locale writes it for a price.
static func _lead(art: Dictionary, price: int) -> String:
	return Locale.active.t("ui.combat.lanternLead", {"embers": price, "text": str(art.get("text", ""))})


static func _tip_body(screen: CombatScreen) -> String:
	return str(screen._lantern_tip().get("body", ""))


static func _art(content: ContentDB, id: String) -> Dictionary:
	var art: Dictionary = content.arts[id]
	return art


## Each tier's tooltip leads with its own price: the content's at Kindling, the
## Art dearer at Soot, cheaper at True. The content price alone would read the
## same at all three, which is what the tip did before it asked the rules.
static func _art_price_by_tier(fails: Array[String]) -> void:
	var content: ContentDB = FlameLantern._content(KNOBS)
	var art: Dictionary = _art(content, "flare")
	var base: int = FlameLantern._ji(art["cost"])
	var soot_cost: int = base + SOOT_ART_COST
	var true_cost: int = base - TRUE_ART_COST
	_check(fails, soot_cost != base and true_cost != base and soot_cost != true_cost,
		"the tiers' prices must differ for this test to see a wrong one (%d %d %d)"
			% [soot_cost, base, true_cost])
	var cases: Array = [
		["Soot", FlameLantern.SOOT_DECK, soot_cost],
		["Kindling", FlameLantern.KINDLING_DECK, base],
		["True", FlameLantern.TRUE_DECK, true_cost],
	]
	for row: Array in cases:
		var label: String = row[0]
		var deck: Array = row[1]
		var want: int = row[2]
		var screen: CombatScreen = _screen(content, deck)
		var rules_price: int = screen.game.rules.art_cost(screen.game.run, screen.game.cb)
		_check(fails, rules_price == want,
			"%s: the rules' price is %d, expected %d" % [label, rules_price, want])
		var body: String = _tip_body(screen)
		_check(fails, body.begins_with(_lead(art, want)),
			"%s: the Art's tip does not lead with %d Embers: %s" % [label, want, body.left(60)])
		if want != base:
			_check(fails, not body.begins_with(_lead(art, base)),
				"%s: the Art's tip still quotes the content price %d" % [label, base])
		# Hovering the lantern, on the path the pointer takes, is that tip.
		var at: Vector2 = screen._hud.lantern_rect().get_center()
		_check(fails, str(screen._tip_at(at).get("body", "")) == body,
			"%s: the lantern's hover does not answer with the Art's tip" % label)
		screen.queue_free()


## The price is the run's Art's: the Lamplighter swaps Flare for another, and the
## lantern moves that one's price.
static func _art_price_follows_the_run_art(fails: Array[String]) -> void:
	var content: ContentDB = FlameLantern._content(KNOBS)
	var art: Dictionary = _art(content, "mendglass")
	var base: int = FlameLantern._ji(art["cost"])
	var cases: Array = [
		["Soot", FlameLantern.SOOT_DECK, base + SOOT_ART_COST],
		["True", FlameLantern.TRUE_DECK, base - TRUE_ART_COST],
	]
	for row: Array in cases:
		var label: String = row[0]
		var deck: Array = row[1]
		var want: int = row[2]
		var screen: CombatScreen = _screen(content, deck, NO_RELICS, &"mendglass")
		_check(fails, _tip_body(screen).begins_with(_lead(art, want)),
			"%s Mendglass: the tip does not lead with %d Embers" % [label, want])
		screen.queue_free()


## Nothing is copied when the fight opens: a price the rules move afterwards is
## the price the next ask shows.
static func _art_price_is_read_each_time(fails: Array[String]) -> void:
	var content: ContentDB = FlameLantern._content(KNOBS)
	var art: Dictionary = _art(content, "flare")
	var base: int = FlameLantern._ji(art["cost"])
	var screen: CombatScreen = _screen(content, FlameLantern.KINDLING_DECK)
	_check(fails, _tip_body(screen).begins_with(_lead(art, base)),
		"Kindling: the tip does not open on the content price %d" % base)
	screen.game.cb.art_cost_delta = 2
	_check(fails, _tip_body(screen).begins_with(_lead(art, base + 2)),
		"a price moved after the fight began is not the price the tip shows")
	screen.game.cb.art_cost_delta = -base - 2
	_check(fails, _tip_body(screen).begins_with(_lead(art, 1)),
		"a discount past the floor is not the rules' floor of 1 in the tip")
	screen.queue_free()


# ---------------------------------------------------------------- the pips

## The lantern's pips as they stand: their centres in the 104 box.
static func _shown(hud: HudBar) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for pip: TextureRect in hud._lantern_pips:
		if pip.visible:
			out.append(pip.position + pip.size * 0.5)
	return out


## The angle of a point on the ring, in degrees clockwise from straight up.
static func _degrees(centre: Vector2) -> float:
	var from_centre: Vector2 = centre - RING_CENTRE
	return rad_to_deg(atan2(from_centre.x, -from_centre.y))


## One pip per Ember at every cap the lantern can reach, all on the ring the
## lantern has always had, spread evenly across the same arc, none touching the
## next: a higher cap spaces them closer rather than clipping the last.
static func _ring_follows_the_cap(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new()
	var held: int = 3
	for cap: int in [9, 10, 11, 12, 14, 15, 20, 12, 9, 14]:
		hud.set_lantern(held, false, cap)
		var pips: Array[Vector2] = _shown(hud)
		_check(fails, pips.size() == cap,
			"cap %d: the ring shows %d pips" % [cap, pips.size()])
		if pips.size() != cap:
			continue
		var step: float = (ARC_TO - ARC_FROM) / float(cap - 1)
		var nearest: float = INF
		for i: int in range(cap):
			var radius: float = pips[i].distance_to(RING_CENTRE)
			_check(fails, absf(radius - RING_RADIUS) < EPS,
				"cap %d: pip %d is %.2f from the lantern's centre, not on its ring" % [cap, i, radius])
			var want_angle: float = ARC_FROM + step * float(i)
			_check(fails, absf(_degrees(pips[i]) - want_angle) < EPS,
				"cap %d: pip %d is at %.2f degrees, not %.2f" % [cap, i, _degrees(pips[i]), want_angle])
			if i > 0:
				nearest = minf(nearest, pips[i].distance_to(pips[i - 1]))
			# The lit pips are the Embers held; the rest wait.
			var want_tone: Color = HudBar.LANTERN_PIP_LIT if i < held else HudBar.LANTERN_PIP_UNLIT
			_check(fails, hud._pip_target[i].is_equal_approx(want_tone),
				"cap %d: pip %d is not aimed at its %s tone" % [cap, i, "lit" if i < held else "unlit"])
		_check(fails, nearest >= HudBar.LANTERN_PIP_SIDE,
			"cap %d: neighbouring pips are %.2f apart, closer than a pip is wide" % [cap, nearest])
	hud.free()


## A pip the ring grows after the HUD is live is born in the tone every pip
## waits in, so it never fades in from white.
static func _ring_is_born_unlit(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new()
	var built: int = hud._lantern_pips.size()
	hud.set_lantern(0, false, built + 5)
	_check(fails, hud._lantern_pips.size() == built + 5,
		"the ring did not grow by the pips the cap added")
	for i: int in range(built, hud._lantern_pips.size()):
		var pip: TextureRect = hud._lantern_pips[i]
		_check(fails, pip.modulate.is_equal_approx(HudBar.LANTERN_PIP_UNLIT) and hud._pip_u[i] >= 1.0,
			"pip %d, added to a live HUD, is not born unlit" % i)
	hud.free()


## Through the combat screen with the fight's own state: the plain lantern, the
## Crown of Cinders' 12, and a True lantern with the Crown, 14.
static func _combat_draws_every_pip(fails: Array[String]) -> void:
	var content: ContentDB = FlameLantern._content(KNOBS)
	var cases: Array = [
		["plain", FlameLantern.KINDLING_DECK, NO_RELICS, FlameLantern._plain_cap()],
		["Crown of Cinders", FlameLantern.KINDLING_DECK, CROWN, CROWN_CAP],
		["True with the Crown of Cinders", FlameLantern.TRUE_DECK, CROWN, CROWN_CAP + STEADY_CAP],
	]
	for row: Array in cases:
		var label: String = row[0]
		var deck: Array = row[1]
		var relics: Array[String] = row[2]
		var want_cap: int = row[3]
		var screen: CombatScreen = _screen(content, deck, relics)
		var cap: int = screen.game.cb.ember_cap
		_check(fails, cap == want_cap,
			"%s: the lantern's cap is %d, expected %d" % [label, cap, want_cap])
		var drawn: int = _shown(screen._hud).size()
		_check(fails, drawn == cap,
			"%s: the HUD draws %d pips for a lantern that holds %d" % [label, drawn, cap])
		screen.queue_free()
