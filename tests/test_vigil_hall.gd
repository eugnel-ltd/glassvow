extends RefCounted
## The hearth hall's framing (docs/design/2026-10-03-title-rooms §4.1, §5.2,
## §11.1). VigilHall.frame is a pure rule; at every shape and every flex stage
## a device gives:
##
## - every look's framing covers the stage, and so does every frame of the
##   turn west (V1: the hall slid in from 0.08 W), the turn east (V3: slid
##   out) and every look change (V4: a blend of two framings), sampled at
##   t = 0, 0.25, 0.5, 0.75 and 1;
## - the Keeper stands whole on the stage on the Deeds look, his hem on it, and
##   never in the column the deeds or the epitaphs stand in;
## - on the Rose look the plate's own painted window lies inside the
##   Emberglass rose, so the hall never shows two windows;
## - a phone's looks keep the plate at 0.55 stage px a plate px or more (it has
##   no mipmaps), and the Keeper's measured seat is the cutout's.

const STAGES: Array[Array] = [
	[&"pad-landscape", Vector2(1180, 820)], [&"desktop-landscape", Vector2(1458, 820)],
	[&"phone-landscape", Vector2(844, 390)], [&"phone-landscape", Vector2(845, 390)],
	[&"phone-landscape", Vector2(844, 443)], [&"pad-landscape", Vector2(1180, 885)],
	[&"pad-landscape", Vector2(1180, 824)], [&"desktop-landscape", Vector2(1458, 911)],
]
const LOOKS: Array[StringName] = [VigilHall.DEEDS, VigilHall.ROSE, VigilHall.EPITAPHS]
const TS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("vigil_hall: %s" % what)


static func run(fails: Array[String]) -> void:
	_the_keeper_is_the_cutout(fails)
	for entry: Array in STAGES:
		var shape: StringName = entry[0]
		var stage: Vector2 = entry[1]
		var where: String = "%s %dx%d" % [shape, int(stage.x), int(stage.y)]
		_covers(fails, shape, stage, where)
		_keeper_clear(fails, shape, stage, where)
		_one_window(fails, shape, stage, where)
	_the_rule_worked(fails)


## Every framing, every turn and every blend of two framings covers the stage.
static func _covers(fails: Array[String], shape: StringName, stage: Vector2, where: String) -> void:
	for look: StringName in LOOKS:
		var xf: Transform2D = VigilHall.frame(stage, look, shape)
		_check(fails, _covered(xf, stage), "%s: the %s look leaves the stage uncovered" % [where, look])
		for t: float in TS:
			for slide: float in [-VigilHall.TURN * stage.x * (1.0 - t), -VigilHall.TURN * stage.x * t]:
				var turned: Transform2D = VigilHall.covering(stage, xf.get_scale().x, xf.origin + Vector2(slide, 0.0))
				_check(fails, _covered(turned, stage),
					"%s: the %s look turned by %.0f px leaves the stage uncovered" % [where, look, slide])
			for other: StringName in LOOKS:
				var to: Transform2D = VigilHall.frame(stage, other, shape)
				var s: float = lerpf(xf.get_scale().x, to.get_scale().x, t)
				var blend: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, xf.origin.lerp(to.origin, t))
				_check(fails, _covered(blend, stage),
					"%s: the change from %s to %s leaves the stage uncovered at t %.2f" % [where, look, other, t])
		if LeadlightTokens.is_phone(shape):
			_check(fails, xf.get_scale().x >= 0.55,
				"%s: the %s look draws the plate at %.3f, under 0.55" % [where, look, xf.get_scale().x])


static func _covered(xf: Transform2D, stage: Vector2) -> bool:
	var plate: Rect2 = xf * Rect2(Vector2.ZERO, VigilHall.PLATE_SIZE)
	return plate.grow(0.01).encloses(Rect2(Vector2.ZERO, stage))


## The Keeper whole on the stage at the hearth, and clear of the column.
static func _keeper_clear(fails: Array[String], shape: StringName, stage: Vector2, where: String) -> void:
	var deeds: Rect2 = VigilHall.keeper_on_stage(VigilHall.frame(stage, VigilHall.DEEDS, shape))
	_check(fails, deeds.position.x >= 0.0 and deeds.end.x <= stage.x
			and deeds.position.y + deeds.size.y * VigilHall.KEEPER_HOOD >= 0.0,
		"%s: the Keeper does not stand whole on the stage (%s)" % [where, deeds])
	# The sprite's foot is his hem (HearthFigure seats it on the plate's 861).
	_check(fails, deeds.end.y <= stage.y - 7.5, "%s: the Keeper's hem is off the stage (%.1f)" % [where, deeds.end.y])
	for look: StringName in [VigilHall.DEEDS, VigilHall.EPITAPHS]:
		var keeper: Rect2 = VigilHall.keeper_on_stage(VigilHall.frame(stage, look, shape))
		var column: Rect2 = VigilScreen.body_for(stage, look, shape)
		_check(fails, column.size.x > 0.0 and not column.intersects(keeper),
			"%s: the %s column (%s) stands on the Keeper (%s)" % [where, look, column, keeper])
		var hood: float = keeper.position.y + keeper.size.y * VigilHall.KEEPER_HOOD
		var room: float = VigilHall.HEAD_ROOM.y if LeadlightTokens.is_phone(shape) else VigilHall.HEAD_ROOM.x
		_check(fails, hood >= room - 0.5,
			"%s: the Keeper's hood is under the look panes or off the stage on the %s look (%.1f)" % [where, look, hood])


## On the Rose look the painted window lies inside the Emberglass rose.
static func _one_window(fails: Array[String], shape: StringName, stage: Vector2, where: String) -> void:
	var window: Vector3 = VigilHall.window_on_stage(VigilHall.frame(stage, VigilHall.ROSE, shape))
	var rose: Vector3 = VigilHall.rose_spot(shape)
	var reach: float = Vector2(window.x, window.y).distance_to(Vector2(rose.x, rose.y)) + window.z
	_check(fails, reach <= rose.z * VigilHall.WINDOW_IN_ROSE + 0.5,
		"%s: the painted window reaches %.1f px from the rose's centre, past its %.1f" % [
			where, reach, rose.z * VigilHall.WINDOW_IN_ROSE])


## The measured seat is HearthFigure's, with the cutout's own aspect.
static func _the_keeper_is_the_cutout(fails: Array[String]) -> void:
	var art: Texture2D = load(HearthFigure.ART) as Texture2D
	_check(fails, art != null and absf(art.get_size().x / art.get_size().y - VigilHall.KEEPER_ASPECT) < 0.001,
		"the Keeper's aspect is not the cutout's")
	var keeper: Rect2 = VigilHall.keeper_on_plate()
	_check(fails, absf(keeper.end.x - VigilHall.KEEPER_RIGHT) <= 2.0
			and absf(keeper.end.y - VigilHall.HEM) <= 2.0,
		"the Keeper's right edge and hem are not the seat's (%s)" % keeper)


## The spec's worked values (§4.1) at pad: scale 0.865, the Keeper at 908–1156.
static func _the_rule_worked(fails: Array[String]) -> void:
	var xf: Transform2D = VigilHall.frame(Vector2(1180, 820), VigilHall.DEEDS, &"pad-landscape")
	var keeper: Rect2 = VigilHall.keeper_on_stage(xf)
	_check(fails, absf(xf.get_scale().x - 0.865) < 0.001 and absf(keeper.position.x - 908.0) < 1.5
			and absf(keeper.end.x - 1156.0) < 1.5,
		"the pad Deeds framing is not the rule's (scale %.3f, Keeper %s)" % [xf.get_scale().x, keeper])
