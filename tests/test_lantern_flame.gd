extends RefCounted
## #577 lock PR 5: the Flame on the HUD, reward and shop lanterns. The reading is
## the domain's (`EventTypes.FLAME`); these pin what presentation does with it:
## the controller's targets and its tween, the HUD lantern it lights, the combat
## screen that forwards it, the reward and shop lanterns main feeds after a
## pick, and the reading main takes at an event's deck change. Visual proof is in
## docs/design/2026-09-29-dusk-flame/hud/.

const PoolCallers: GDScript = preload("res://tests/test_pool_callers.gd")
const EPS: float = 0.0001

const KINDLING: Dictionary = {"t": &"flame", "tier": "KINDLING", "dominant": "",
	"fringe": "", "shares": {"shatter": 0.34, "lantern": 0.33, "edge": 0.33}}
const STEADY_SHATTER_EDGE: Dictionary = {"t": &"flame", "tier": "STEADY",
	"dominant": "shatter", "fringe": "edge",
	"shares": {"shatter": 0.63, "lantern": 0.12, "edge": 0.25}}
const TRUE_LANTERN: Dictionary = {"t": &"flame", "tier": "TRUE", "dominant": "lantern",
	"fringe": "", "shares": {"shatter": 0.08, "lantern": 0.84, "edge": 0.08}}
const SOOT: Dictionary = {"t": &"flame", "tier": "SOOT", "dominant": "shatter",
	"fringe": "lantern", "shares": {"shatter": 0.34, "lantern": 0.33, "edge": 0.33}}
const STEADY_EDGE: Dictionary = {"t": &"flame", "tier": "STEADY", "dominant": "edge",
	"fringe": "", "shares": {"shatter": 0.20, "lantern": 0.20, "edge": 0.60}}


## A route screen that can show the flame, standing in for one that carries a
## lantern: it keeps every reading it is handed.
class LanternSpy:
	extends Control

	var seen: Array[Dictionary] = []

	func show_flame(event: Dictionary, _instant: bool = false) -> void:
		seen.append(event)


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_lantern_flame: %s" % what)


static func run(fails: Array[String]) -> void:
	_targets(fails)
	_undeclared_tiers(fails)
	_retargets_not_snaps(fails)
	_hud_lantern(fails)
	_run_lantern_seat(fails)
	_combat_forwards(fails)
	_reward_and_shop(fails)
	_event_deck_changes(fails)


# ---------------------------------------------------------------- controller

## What the shader is told, read back off the material.
static func _inputs(flame: LanternFlame) -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["dominant_colour", "fringe_colour", "fringe_amount", "stability",
			"height", "shape_weights", "painted"]:
		out[key] = flame.material.get_shader_parameter(key)
	return out


## One reading's inputs, from the controller's own tables.
static func _want(dominant: Color, fringe: Color, amount: float, stability: float,
		height: float, shape: Vector4, painted: float) -> Dictionary:
	return {"dominant_colour": dominant, "fringe_colour": fringe, "fringe_amount": amount,
		"stability": stability, "height": height, "shape_weights": shape,
		"painted": painted}


## Equal inputs. A fringe's colour only counts while the fringe shows: one that
## leaves keeps its colour at no strength, one that arrives takes its colour
## from the start (`LanternFlame._retarget`), and neither is seen.
static func _same(got: Dictionary, want: Dictionary) -> bool:
	var fringe_shows: bool = float(str(want.get("fringe_amount", 1.0))) > EPS
	for key: String in want:
		if key == "fringe_colour" and not fringe_shows:
			continue
		var a: Variant = got.get(key)
		var b: Variant = want[key]
		if typeof(a) != typeof(b):
			return false
		match typeof(b):
			TYPE_FLOAT:
				var fa: float = a
				var fb: float = b
				if absf(fa - fb) > EPS:
					return false
			TYPE_COLOR:
				var ca: Color = a
				var cb: Color = b
				if not ca.is_equal_approx(cb):
					return false
			TYPE_VECTOR4:
				var va: Vector4 = a
				var vb: Vector4 = b
				if not va.is_equal_approx(vb):
					return false
	return true


## A FLAME event drives every input to its tier's and way's value: colour,
## fringe (colour and strength), stability, height and the way's figure.
static func _targets(fails: Array[String]) -> void:
	var flame: LanternFlame = LanternFlame.new()
	flame.show_event(STEADY_SHATTER_EDGE)
	flame.advance(LanternFlame.TWEEN_TIME)
	_check(fails, _same(_inputs(flame), _want(LanternFlame.COLOUR["shatter"],
			LanternFlame.COLOUR["edge"], LanternFlame.fringe_amount_for(0.25),
			LanternFlame.TIER_STABILITY[Flame.TIER_STEADY],
			LanternFlame.TIER_HEIGHT[Flame.TIER_STEADY], LanternFlame.WAY_SHAPE["shatter"], 0.0)),
		"Steady Shatter with an Edge fringe did not reach its inputs: %s" % _inputs(flame))
	_check(fails, is_equal_approx(LanternFlame.fringe_amount_for(0.25), LanternFlame.FRINGE_FLOOR)
			and LanternFlame.fringe_amount_for(0.24) == 0.0
			and is_equal_approx(LanternFlame.fringe_amount_for(0.40), 1.0),
		"a fringe shows from fringeMin at its floor and is full by 0.40")
	flame.show_event(TRUE_LANTERN)
	flame.advance(LanternFlame.TWEEN_TIME)
	var inputs: Dictionary = _inputs(flame)
	_check(fails, _same(inputs, _want(LanternFlame.COLOUR["lantern"], LanternFlame.COLOUR["lantern"],
			0.0, 1.0, 1.0, LanternFlame.WAY_SHAPE["lantern"], 0.0)),
		"True Lantern did not reach its inputs: %s" % inputs)
	_check(fails, flame.light_now().is_equal_approx(LanternFlame.COLOUR["lantern"]),
		"a declared flame throws its way's light")
	flame.free()


## Kindling burns as the lantern is painted and throws the HUD's own amber;
## Soot burns plain and dust-brown whatever its shares and fringe say.
static func _undeclared_tiers(fails: Array[String]) -> void:
	var flame: LanternFlame = LanternFlame.new()
	var kindling: Dictionary = _want(LanternFlame.COLOUR[Flame.TIER_KINDLING],
		LanternFlame.COLOUR[Flame.TIER_KINDLING], 0.0, 0.40, 0.55, LanternFlame.PLAIN_SHAPE, 1.0)
	_check(fails, _same(_inputs(flame), kindling),
		"a flame that has heard nothing is not Kindling: %s" % _inputs(flame))
	_check(fails, flame.light_now().is_equal_approx(LanternFlame.PAINTED_LIGHT),
		"Kindling does not throw the painted lantern's light")
	flame.show_event(SOOT, true)
	var inputs: Dictionary = _inputs(flame)
	_check(fails, _same(inputs, _want(LanternFlame.COLOUR[Flame.TIER_SOOT],
			LanternFlame.COLOUR[Flame.TIER_SOOT], 0.0, 0.0, 0.46, LanternFlame.PLAIN_SHAPE, 0.0)),
		"Soot did not burn plain and dust-brown: %s" % inputs)
	flame.show_event({"tier": "NOT-A-TIER", "dominant": "shatter"}, true)
	_check(fails, _same(_inputs(flame), kindling), "an unknown tier does not fall back to Kindling")
	flame.free()


## Nothing snaps: a reading tweens from where the flame stands, and a second
## reading inside the tween turns the flame from where it has got to.
static func _retargets_not_snaps(fails: Array[String]) -> void:
	var flame: LanternFlame = LanternFlame.new()
	flame.pinned = true
	var start: Dictionary = _inputs(flame)
	flame.show_event(STEADY_SHATTER_EDGE)
	_check(fails, _same(_inputs(flame), start) and flame.tweening(),
		"a new reading snapped instead of starting a tween")
	flame.advance(LanternFlame.TWEEN_TIME * 0.5)
	var mid: Dictionary = _inputs(flame)
	var mid_height: float = mid["height"]
	_check(fails, mid_height > 0.55 + EPS and mid_height < 0.80 - EPS,
		"half a tween is not between Kindling and Steady (height %s)" % mid_height)
	flame.show_event(STEADY_EDGE)
	_check(fails, _same(_inputs(flame), mid),
		"a reading inside the tween snapped rather than turning from where the flame was")
	flame.advance(LanternFlame.TWEEN_TIME * 0.25)
	var turning: Dictionary = _inputs(flame)
	var shape_now: Vector4 = turning["shape_weights"]
	var shape_mid: Vector4 = mid["shape_weights"]
	_check(fails, shape_now.z > shape_mid.z + EPS and shape_now.z < 1.0 - EPS,
		"the retargeted tween did not move towards Edge by degrees (%s)" % shape_now)
	flame.advance(LanternFlame.TWEEN_TIME)
	_check(fails, not flame.tweening() and _same(_inputs(flame), _want(LanternFlame.COLOUR["edge"],
			LanternFlame.COLOUR["edge"], 0.0, 0.85, 0.80, LanternFlame.WAY_SHAPE["edge"], 0.0)),
		"the retargeted tween did not land on the new reading: %s" % _inputs(flame))
	flame.free()


# ---------------------------------------------------------------- the HUD

## The HUD keeps the painted lantern until a reading arrives, then puts the
## flame's material on its art and relights its glow; the count sits off the
## glass.
static func _hud_lantern(fails: Array[String]) -> void:
	var hud: HudBar = HudBar.new()
	_check(fails, hud._flame == null and hud._lantern_art.material == null,
		"the HUD lit its lantern before hearing a reading")
	hud.show_flame(STEADY_SHATTER_EDGE, true)
	_check(fails, hud._flame != null and hud._lantern_art.material == hud._flame.material,
		"show_flame did not put the flame's material on the lantern art")
	_check(fails, hud._lantern_glow.texture == LanternFlame.falloff()
			and hud._lantern_glow.self_modulate.is_equal_approx(LanternFlame.COLOUR["shatter"]),
		"the lantern's glow does not burn in the flame's light")
	_check(fails, _same(_inputs(hud._flame), _want(LanternFlame.COLOUR["shatter"],
			LanternFlame.COLOUR["edge"], LanternFlame.FRINGE_FLOOR, 0.85, 0.80,
			LanternFlame.WAY_SHAPE["shatter"], 0.0)),
		"an instant reading on the HUD was not drawn at once")
	var lit: LanternFlame = hud._flame
	hud.show_flame(KINDLING)
	_check(fails, hud._flame == lit and lit.tweening(),
		"a second reading relit the lantern instead of tweening its flame")
	# The count hangs under the foot: its box starts below the panes' box, so
	# no digit can cover the flame again (#577).
	var art_top: float = hud._lantern_art.position.y
	var glass_bottom: float = art_top + hud._lantern_art.size.y * 0.795
	_check(fails, hud._lantern_count.position.y >= glass_bottom,
		"the ember count overlaps the lantern's glass")
	hud.free()


## The reward and shop lantern hangs where the combat lantern's seat says, at
## its size and inset, and always below the run HUD's chrome (whose collection
## ends where `chrome_bottom` says, however many relics it holds).
static func _run_lantern_seat(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	for shape: StringName in StageShape.SHIPPING:
		var lantern: RunLantern = RunLantern.new(shape)
		var seat: Dictionary = LayoutBook.resolve(&"chrome", shape, 0).get("lantern", {})
		var side: float = LayoutBook.num(seat.get("w"), RunLantern.NATURAL)
		_check(fails, is_equal_approx(lantern._hang.size.x, side)
				and is_equal_approx(lantern._hang.position.x, LayoutBook.num(seat.get("left"))),
			"%s: the run lantern is not the combat lantern's size and inset" % shape)
		_check(fails, lantern._hang.position.y >= RunHud.chrome_bottom(shape),
			"%s: the run lantern hangs into the run HUD's chrome" % shape)
		lantern.free()
		var hud: RunHud = RunHud.new(RunState.new_run(content, 1), content, shape)
		_check(fails, is_equal_approx(hud._collection.offset_bottom, RunHud.chrome_bottom(shape)),
			"%s: the run HUD's collection does not end where chrome_bottom says" % shape)
		hud.free()


## The combat screen forwards the start batch's reading at once, keeps it for a
## HUD rebuilt on a new shape, and tweens one that arrives through the pump.
## An aspect without ways never lights the HUD lantern.
static func _combat_forwards(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var run: RunState = RunState.new_run(content, 57701)
	var game: GlassvowGame = GlassvowGame.new(content, run)
	var screen: CombatScreen = CombatScreen.new(game)
	screen.seq.instant = true
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(screen)
	screen.start_encounter(["sporeling"], "normal", "flame")
	var reading: Dictionary = Flame.read(content, run)
	_check(fails, screen._hud._flame != null and not screen._hud._flame.tweening(),
		"the fight did not open on its reading, drawn at once")
	_check(fails, str(screen._flame_reading.get("tier", "")) == str(reading["tier"]),
		"the combat screen kept a different reading from the domain's")
	screen.set_shape(&"phone-landscape")
	_check(fails, screen._hud._flame != null
			and screen._hud._lantern_art.material == screen._hud._flame.material,
		"a HUD rebuilt for a new shape lost its flame")
	screen._handle_event(TRUE_LANTERN)
	_check(fails, screen._hud._flame.tweening() and screen._flame_reading == TRUE_LANTERN,
		"a FLAME through the pump did not tween the HUD's lantern")
	screen.queue_free()

	var ash_run: RunState = RunState.new_run(content, 57702, "", {"aspect": 1})
	var ash_game: GlassvowGame = GlassvowGame.new(content, ash_run)
	var ash: CombatScreen = CombatScreen.new(ash_game)
	ash.seq.instant = true
	tree.root.add_child(ash)
	ash.start_encounter(["sporeling"], "normal", "no ways")
	_check(fails, ash._hud._flame == null and ash._hud._lantern_art.material == null,
		"an aspect without ways lit the HUD lantern")
	ash.queue_free()


# ---------------------------------------------------------------- main

## Main reads the Flame where it edits the deck: the reward and shop lanterns
## open on the reading, drawn at once, and a card taken or bought turns them.
static func _reward_and_shop(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var main: Main = PoolCallers._on_map(content, 57703)
	var deck: Array[CardInst] = main.game.run.player.deck
	# The starter's one card of each way plus quakeblow: mass 4, still Kindling.
	deck.append(CardInst.new(main.game.run.next_uid(), &"quakeblow", false))
	main.game.run.pending_reward = {"rewards": {"gold": 10, "cards": ["uppercut"],
		"potion": null, "relic": null}, "taken": {}}
	main._show_pending_reward()
	var lantern: RunLantern = main._reward_screen._lantern
	var painted: float = lantern.flame.material.get_shader_parameter("painted") \
		if lantern != null else 0.0
	_check(fails, lantern != null and not lantern.flame.tweening()
			and is_equal_approx(painted, 1.0),
		"the reward lantern did not open on the Kindling reading, drawn at once")
	main._on_reward_claimed(&"card", "uppercut")
	_check(fails, lantern != null and lantern.flame.tweening(),
		"taking a card did not turn the reward lantern")
	if lantern != null:
		lantern.flame.advance(LanternFlame.TWEEN_TIME)
		_check(fails, lantern.flame.light_now().is_equal_approx(LanternFlame.COLOUR["shatter"]),
			"3/1/1 glass did not bring the reward lantern to Steady Shatter")

	main.game.run.player.gold = 1000
	main.game.run.quest_scratch["shopStock"] = {"cards": [{"id": "chisel", "price": 10}],
		"potions": [], "relics": [], "removeCost": 50}
	main._show_shop()
	var shop: ShopScreen = main._route_screen as ShopScreen
	var stall: RunLantern = shop._lantern if shop != null else null
	_check(fails, stall != null and not stall.flame.tweening()
			and stall.flame.light_now().is_equal_approx(LanternFlame.COLOUR["shatter"]),
		"the stall's lantern did not open on the run's reading")
	main._on_shop_choice("cards:0")
	_check(fails, stall != null and stall.flame.tweening(),
		"buying a card did not turn the stall's lantern")

	main.game.run.aspect = 1  # the Ashwarden declares no ways
	main._show_shop()
	var bare: ShopScreen = main._route_screen as ShopScreen
	_check(fails, bare != null and bare._lantern == null,
		"a stall for an aspect without ways grew a lantern")
	PoolCallers._dispose(main)


## Main reads the Flame at an event's deck changes too (lock §4: it answers on
## the spot), lantern or none: the event screens carry none, so the reading is
## taken all the same, and reaches a route screen only if that screen says it can
## show one. Two Kindling decks cross to Steady at an event: the Shrine's
## removal takes War Cry out of 3 shatter, 2 edge and 1 lantern glass, and an
## immediate op adds Quakeblow to 2 shatter, 1 edge and 1 lantern.
static func _event_deck_changes(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	var shrine: Dictionary = content.events["forgottenShrine"]
	var choices: Array = shrine["choices"]
	var offering: Dictionary = choices[1]
	offering["ops"] = [{"addCard": "quakeblow"}]
	for lantern: bool in [false, true]:
		var shown: String = "with a lantern" if lantern else "without one"
		_at_the_shrine(content, "the Shrine's removal %s" % shown, 57704,
			["uppercut", "quakeblow", "warCry"], 0, "warCry", lantern, fails)
		_at_the_shrine(content, "an immediate add %s" % shown, 57705,
			["uppercut"], 1, "", lantern, fails)


## One event, from a Kindling deck (`added` to the starters) to the Steady the
## choice, or the card `removed` from the deck by its pick, makes. The flame is
## read before the choice, as the screen before the event would have left it.
static func _at_the_shrine(content: ContentDB, label: String, seed: int, added: Array[String],
		choice: int, removed: String, lantern: bool, fails: Array[String]) -> void:
	var run_state: RunState = RunState.new_run(content, seed, "flame-event", {"aspect": 0})
	for id: String in added:
		run_state.player.deck.append(CardInst.new(run_state.next_uid(), StringName(id), false))
	var walk: WorldMap = WorldMap.slice()
	walk.at = 3
	walk.nodes[3].type = "event"
	run_state.node_id = walk.nodes[3].id
	run_state.map = walk.to_dict()
	run_state.quest_scratch["eventNode"] = "forgottenShrine"
	var main: Main = PoolCallers._main(content)
	main._continue_run(run_state)
	var before: Array[Dictionary] = main.game.flame_events()
	main.game.take_flame_lines()
	_check(fails, before.size() == 1 and str(before[0]["tier"]) == "KINDLING",
		"%s: the deck before the event must read Kindling, got %s" % [label, before])
	var spy: LanternSpy = null
	if lantern:
		spy = LanternSpy.new()
		main._route_screen = spy
		main.add_child(spy)
	main._on_event_choice(str(choice), "forgottenShrine")
	if not removed.is_empty():
		_check(fails, spy == null or spy.seen.is_empty(),
			"%s: a choice that changed no card read the flame" % label)
		var uid: int = -1
		for card: CardInst in run_state.player.deck:
			if String(card.id) == removed:
				uid = card.uid
		main._on_event_pick(str(uid), "remove")
	if spy != null:
		var tiers: Array = spy.seen.map(func(reading: Dictionary) -> String: return str(reading["tier"]))
		_check(fails, tiers == ["STEADY"],
			"%s: the lantern's route screen must be handed one Steady reading, got %s" % [label, tiers])
	# The lines first: a second reading would owe them itself.
	_check(fails, main.game.take_flame_lines()
			== [FlameLines.SLOT_STEADY, FlameLines.CODEX_PREFIX + "shatter"],
		"%s: the Steady crossed at the event owed no lines" % label)
	_check(fails, main.game.flame_events().is_empty(),
		"%s: the event left its deck change unread" % label)
	PoolCallers._dispose(main)
