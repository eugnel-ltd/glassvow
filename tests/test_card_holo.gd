extends RefCounted
## Card holograms (#657, the owner's picks of 14 Oct 2026): the recipe map
## gives each front tier its own hologram and leaves the starter bare, every
## back wears the lit panes on its OWN knobs whatever the card's rarity, a back
## entry's knobs are validated, the cards wear what the map says (the rare's
## shine steps aside; a picture turn hands the hologram back), and the motion
## signal calibrates, clamps, holds still under Reduce Motion, survives a
## missing sensor and lets the gyroscope's twist decay home; it polls no sensor
## under Reduce Motion, doubts iOS readings already in the screen's axes, and
## lets the pointer light the cards on a touchscreen laptop.

const SH: String = "res://presentation/cards/holo/"


static func run(fails: Array[String]) -> void:
	_fronts_by_tier(fails)
	_backs_by_knobs(fails)
	_holo_pile_takes_no_glint(fails)
	_crystal_stands_above(fails)
	_back_knobs_validated(fails)
	_cards_wear_the_map(fails)
	_crop_uv(fails)
	_calibration(fails)
	_clamp(fails)
	_reduce_motion(fails)
	_missing_sensor(fails)
	_gyro_twist(fails)
	_lean_matches_the_slab(fails)
	_screen_axes(fails)
	_still_polls_no_sensor(fails)
	_ios_axes_doubt(fails)
	_pointer_lights(fails)


static func _fronts_by_tier(fails: Array[String]) -> void:
	var want: Dictionary = {
		"starter": "", "common": SH + "front_common_rim.gdshader",
		"uncommon": SH + "front_uncommon_frame.gdshader",
		"rare": SH + "front_rare_glass.gdshader",
		"special": SH + "front_special_oil.gdshader",
	}
	var seen: Dictionary = {}
	for rarity: String in want:
		var mat: ShaderMaterial = CardHolo.material_for({"rarity": rarity, "type": "skill"})
		var got: String = mat.shader.resource_path if mat != null else ""
		if got != want[rarity]:
			fails.append("holo: %s wears '%s', want '%s'" % [rarity, got, want[rarity]])
		if got != "" and seen.has(got):
			fails.append("holo: %s shares its hologram with %s" % [rarity, seen[got]])
		seen[got] = rarity
	# Every rarity a card in the content carries is decided here: a tier the
	# map has never heard of would silently ship bare.
	var cards: Dictionary = ContentDB.load_full(false).cards
	for id: Variant in cards:
		var row: Dictionary = cards[id]
		var rarity: String = str(row.get("rarity", ""))
		if not want.has(rarity):
			fails.append("holo: card %s has rarity '%s', which the map does not decide" % [id, rarity])
	# A rarity no card wears yet (a relic's boss, the undesigned mythic) wears
	# nothing until its first card lands.
	for rarity: String in ["boss", "mythic", ""]:
		if CardHolo.material_for({"rarity": rarity}) != null:
			fails.append("holo: rarity '%s' wears a hologram before any card needs one" % rarity)


static func _backs_by_knobs(fails: Array[String]) -> void:
	var cat: CardBackCatalogue = CardBackCatalogue.shipped()
	var knob_sets: Array[Dictionary] = []
	for id: String in cat.ids():
		var data: Dictionary = cat.card_data(id)
		var knobs: Dictionary = data.get("holo", {})
		if knobs.is_empty():
			fails.append("holo: back %s has no knobs of its own" % id)
			continue
		if data.get("surface") != "plastic":
			fails.append("holo: back %s still wears the %s finish under its hologram"
				% [id, str(data.get("surface"))])
		for k: Dictionary in knob_sets:
			if k == knobs:
				fails.append("holo: back %s shares another back's knobs" % id)
		knob_sets.append(knobs)
		# A back looks the same whatever the card's rarity.
		for rarity: String in ["", "starter", "rare", "special"]:
			var probe: Dictionary = data.duplicate()
			probe["rarity"] = rarity
			var mat: ShaderMaterial = CardHolo.material_for(probe)
			if mat == null or mat.shader != CardHolo.BACK_SHADER:
				fails.append("holo: back %s at rarity '%s' does not wear the lit panes" % [id, rarity])
				continue
			for key: String in knobs:
				if mat.get_shader_parameter(key) != knobs[key]:
					fails.append("holo: back %s's %s reads %s, want %s"
						% [id, key, str(mat.get_shader_parameter(key)), str(knobs[key])])
	if knob_sets.size() != 3:
		fails.append("holo: %d backs carry knobs, want the three shipped" % knob_sets.size())
	if CardHolo.material_for({"back": "x.png"}) != null:
		fails.append("holo: a back with no knobs wears a hologram")


## Two shimmering systems never stack: a draw pile whose top back wears its
## hologram takes no glint; one whose back has none keeps it.
static func _holo_pile_takes_no_glint(fails: Array[String]) -> void:
	var stage: ImageTexture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var knobs: Dictionary = CardBackCatalogue.shipped().card_data("vault").get("holo", {})
	var at: float = -1.0
	for i: int in range(90):
		if not is_nan(PileStack.glint_at(i * 0.1)):
			at = i * 0.1
			break
	for holo: bool in [false, true]:
		var pile: PileStack = PileStack.new(PileStack.Kind.DRAW)
		pile.set_count(5)
		pile.wear_back(stage, knobs if holo else {})
		pile._t = at
		pile._process(0.0)
		var band: float = pile._glow.band
		if holo and (not pile.has_holo_top() or not is_nan(band)):
			fails.append("holo: a draw pile wearing its back's hologram still glints (band %s)" % band)
		if not holo and (pile.has_holo_top() or is_nan(band)):
			fails.append("holo: a draw pile with no back hologram lost its glint")
		pile.free()


## The cost crystal stands above every front's hologram (owner, 14 Oct 2026):
## each recipe's every write to COLOR lays the picture back over the
## crystal's footprint (`holo_gem_keep`), and that footprint is CardView's own
## stone: its centre where GEM_AT stands it, its inradius the HEX's half-width.
static func _crystal_stands_above(fails: Array[String]) -> void:
	for recipe: String in CardHolo.FRONTS:
		var sh: Shader = CardHolo.FRONTS[recipe]
		var writes: int = 0
		for line: String in sh.code.split("\n"):
			if line.strip_edges().begins_with("COLOR ="):
				writes += 1
				if not line.contains("holo_gem_keep("):
					fails.append("holo: %s writes COLOR without laying the crystal back: %s"
						% [recipe, line.strip_edges()])
		if writes == 0:
			fails.append("holo: %s never writes COLOR" % recipe)
	var common: String = FileAccess.get_file_as_string(SH + "holo_common.gdshaderinc")
	var at: Vector2 = Vector2(CardView.GEM_AT.x + CardView.CARD_W * 0.5,
		CardView.CARD_H * 0.5 - CardView.GEM_AT.y)
	var half: float = absf((CardView.HEX[1] as Vector2).x) * CardView.GEM
	var want_c: String = "const vec2 HOLO_GEM_C = vec2(%.1f, %.1f);" % [at.x, at.y]
	var want_in: String = "const float HOLO_GEM_IN = %.2f;" % half
	if not common.contains(want_c) or not common.contains(want_in):
		fails.append("holo: the crystal's footprint is not CardView's stone (want '%s' and '%s')"
			% [want_c, want_in])


static func _back_knobs_validated(fails: Array[String]) -> void:
	var ok: Variant = CardHolo.parse_back_knobs({"band_mode": 2, "centre": [76, 104],
		"palette": [1, 0.8, 0.45], "strength": 1})
	var good: Dictionary = ok if typeof(ok) == TYPE_DICTIONARY else {}
	if good.get("centre") != Vector2(76, 104) or good.get("palette") != Color(1.0, 0.8, 0.45) \
			or typeof(good.get("band_mode")) != TYPE_INT or good.get("strength") != 1.0:
		fails.append("holo: good knobs parse as %s" % str(ok))
	for bad: Variant in [[], {}, {"shine": 1.0}, {"strength": "high"},
			{"centre": [1, 2, 3]}, {"palette": [1, 1]}, {"band_mode": 3},
			{"band_mode": 1.5}, {"palette": [1, "x", 1]}]:
		if not CardHolo.parse_back_knobs(bad) is String:
			fails.append("holo: knobs %s were accepted" % str(bad))
	var doc: Dictionary = {"v": 1, "default": "vault", "backs": {"vault": {
		"art": "res://assets/art/backs/vault.png", "surface": "plastic",
		"holo": {"glow": 1}, "unlock": {"kind": "default"}}}}
	if not CardBackCatalogue.parse(doc) is String:
		fails.append("holo: a catalogue with an unknown knob was accepted")


static func _cards_wear_the_map(fails: Array[String]) -> void:
	var cards: Dictionary = ContentDB.load_full(false).cards
	var by: Dictionary = {}
	for id: Variant in cards:
		var row: Dictionary = cards[id]
		by[str(row.get("rarity", ""))] = str(id)
	for rarity: String in ["starter", "rare"]:
		var id: String = by[rarity]
		var data: Dictionary = cards[id]
		var view: CardView = CardView.new(CardInst.new(1, StringName(id)), data, 1)
		var picture: CanvasItem = _picture(view)
		var mat: Material = picture.material if picture != null else null
		if rarity == "starter" and mat != null:
			fails.append("holo: a starter's picture wears %s" % str(mat))
		if rarity == "rare":
			if not mat is ShaderMaterial \
					or (mat as ShaderMaterial).shader.resource_path != SH + "front_rare_glass.gdshader":
				fails.append("holo: a rare's picture wears %s, not its cut glass" % str(mat))
			if view.has_shine():
				fails.append("holo: a rare wearing its hologram still runs the gilt shine")
			# The picture turn borrows the picture, then hands the hologram back.
			view.turn(60.0, 0.0, false)
			view.turn(0.0, 0.0, false)
			if picture.material != mat:
				fails.append("holo: after a picture turn the rare wears %s" % str(picture.material))
		view.free()


## The card's picture: the stage render on the canvas.
static func _picture(view: CardView) -> CanvasItem:
	for child: Node in view.get_children():
		if child is TextureRect and (child as TextureRect).texture is ViewportTexture:
			return child
	return null


static func _crop_uv(fails: Array[String]) -> void:
	# A crop 8 texels in from each side of a 200-texel stage, drawn past its
	# edges: its UV runs from -8/184 to 1 + 8/184, which is the stage's 0..1.
	var uv: Vector4 = CardHolo.crop_uv(Vector2(184.0, 248.0), 8.0)
	var lo: Vector2 = (Vector2(-8.0 / 184.0, -8.0 / 248.0) - Vector2(uv.x, uv.y)) / Vector2(uv.z, uv.w)
	var hi: Vector2 = (Vector2(192.0 / 184.0, 256.0 / 248.0) - Vector2(uv.x, uv.y)) / Vector2(uv.z, uv.w)
	if not lo.is_zero_approx() or not hi.is_equal_approx(Vector2.ONE):
		fails.append("holo: a crop's UV maps the stage to %s..%s, want 0..1" % [str(lo), str(hi)])


static func _hold(m: HoloMotion, g: Vector3, w: Vector3, secs: float) -> Vector2:
	var out: Vector2 = Vector2.ZERO
	for _i: int in range(int(secs * 60.0)):
		out = m.update(g, w, null, false, 1.0 / 60.0)
	return out


const FLAT: Vector3 = Vector3(0.0, 0.0, -9.81)
const UPRIGHT: Vector3 = Vector3(0.0, -9.81, 0.0)


static func _calibration(fails: Array[String]) -> void:
	# The first reading is the player's own hold: a pad propped at 30 degrees
	# reads flat.
	var m: HoloMotion = HoloMotion.new()
	var propped: Vector3 = FLAT.rotated(Vector3.RIGHT, deg_to_rad(30.0))
	var o: Vector2 = _hold(m, propped, Vector3.ZERO, 1.0)
	if o.length() > 0.01:
		fails.append("holo: the resting hold reads %s, want centre" % str(o))
	# A 10 degree lean from it reads at once...
	var lean: Vector3 = propped.rotated(Vector3.RIGHT, deg_to_rad(10.0))
	o = _hold(m, lean, Vector3.ZERO, 0.5)
	if absf(o.y) < 0.5:
		fails.append("holo: a 10 degree lean reads %s, want over half a throw" % str(o))
	# ...and a hold kept is re-centred within seconds (6 s time constant).
	o = _hold(m, lean, Vector3.ZERO, 18.0)
	if o.length() > 0.1:
		fails.append("holo: a kept lean still reads %s after 18 s, want re-centred" % str(o))
	m.recentre()
	o = _hold(m, propped, Vector3.ZERO, 0.5)
	if o.length() > 0.01:
		fails.append("holo: after a re-centre the new hold reads %s" % str(o))


static func _clamp(fails: Array[String]) -> void:
	var m: HoloMotion = HoloMotion.new()
	_hold(m, FLAT, Vector3.ZERO, 0.2)
	var steep: Vector3 = FLAT.rotated(Vector3.UP, deg_to_rad(80.0))
	var o: Vector2 = m.step(steep, Vector3.ZERO, 1.0 / 60.0)
	if absf(o.x) > 1.0 or absf(o.x) < 0.99:
		fails.append("holo: an 80 degree lean reads %s, want the full throw and no more" % str(o))
	var m2: HoloMotion = HoloMotion.new()
	_hold(m2, FLAT, Vector3.ZERO, 0.2)
	o = m2.step(FLAT.rotated(Vector3.UP, deg_to_rad(16.0)), Vector3.ZERO, 1.0 / 60.0)
	if absf(o.x) < 0.8:
		fails.append("holo: a 16 degree lean reads %s, want nearly the full throw" % str(o))
	var m3: HoloMotion = HoloMotion.new()
	_hold(m3, FLAT, Vector3.ZERO, 0.2)
	o = m3.step(FLAT.rotated(Vector3.UP, deg_to_rad(0.4)), Vector3.ZERO, 1.0 / 60.0)
	if not o.is_zero_approx():
		fails.append("holo: a 0.4 degree tremor reads %s, want the deadzone" % str(o))
	if HoloMotion.lean_of(Vector2(0.8, -0.9), Vector2(0.7, -0.6), false) != Vector2(1.0, -1.0):
		fails.append("holo: a held card's lean plus the device's is not clamped to the throw")


static func _reduce_motion(fails: Array[String]) -> void:
	var m: HoloMotion = HoloMotion.new()
	_hold(m, FLAT, Vector3.ZERO, 0.2)
	var o: Vector2 = m.update(FLAT.rotated(Vector3.UP, 0.3), Vector3(0, 2, 0), Vector2(1, 1), true, 1.0 / 60.0)
	if o != HoloMotion.STILL_POSE or m.source != HoloMotion.Source.STILL:
		fails.append("holo: under Reduce Motion the signal reads %s, want the still pose" % str(o))
	if HoloMotion.lean_of(Vector2(-1, 1), Vector2(0.5, 0.5), true) != HoloMotion.STILL_POSE:
		fails.append("holo: under Reduce Motion a held card's lean still moves its foil")


static func _missing_sensor(fails: Array[String]) -> void:
	var m: HoloMotion = HoloMotion.new()
	m.tilt = Vector2(0.6, 0.6)
	var o: Vector2 = _hold(m, Vector3.ZERO, Vector3(0.0, 3.0, 0.0), 1.0)
	if m.source != HoloMotion.Source.NONE or o.length() > 0.01:
		fails.append("holo: no sensor and no pointer reads %s (%d), want neutral" % [str(o), m.source])
	for _i: int in range(60):
		o = m.update(Vector3(NAN, 0, 0), Vector3.ZERO, Vector2(2.0, 0.0), false, 1.0 / 60.0)
	if m.source != HoloMotion.Source.POINTER or absf(o.x - HoloMotion.POINTER_GAIN) > 0.01:
		fails.append("holo: a broken sensor with a pointer reads %s, want the pointer's drift" % str(o))


static func _gyro_twist(fails: Array[String]) -> void:
	# Upright, a turn about gravity is invisible to it: only the gyroscope sees
	# it, and an 11.5 degree twist reads as a left-right lean.
	var m: HoloMotion = HoloMotion.new()
	_hold(m, UPRIGHT, Vector3.ZERO, 0.5)
	var o: Vector2 = _hold(m, UPRIGHT, UPRIGHT.normalized() * 0.5, 0.4)
	if absf(o.x) < 0.5 or absf(o.y) > 0.05:
		fails.append("holo: an upright twist reads %s, want a left-right lean" % str(o))
	# With no rate, the twist decays to centre.
	o = _hold(m, UPRIGHT, Vector3.ZERO, 30.0)
	if o.length() > 0.05:
		fails.append("holo: the twist reads %s 30 s after it stopped, want centre" % str(o))
	# A glitch is clamped to the budget; a non-finite rate is ignored.
	var m2: HoloMotion = HoloMotion.new()
	_hold(m2, UPRIGHT, Vector3.ZERO, 0.5)
	o = _hold(m2, UPRIGHT, UPRIGHT.normalized() * 1000.0, 1.0)
	if absf(o.x) > tanh(1.3) + 0.01:
		fails.append("holo: a gyro glitch reads %s, past the 16 degree budget" % str(o))
	var m3: HoloMotion = HoloMotion.new()
	o = _hold(m3, UPRIGHT, Vector3(NAN, 0.0, 0.0), 1.0)
	if o.length() > 0.01:
		fails.append("holo: a non-finite gyro reads %s, want ignored" % str(o))
	# No gyroscope at all: gravity alone still leans.
	var m4: HoloMotion = HoloMotion.new()
	_hold(m4, UPRIGHT, Vector3.ZERO, 0.5)
	o = m4.step(UPRIGHT.rotated(Vector3.RIGHT, deg_to_rad(10.0)), Vector3.ZERO, 1.0 / 60.0)
	if absf(o.y) < 0.55:
		fails.append("holo: upright with no gyro, a 10 degree pitch reads %s" % str(o))


## The device turned one way is the card's own slab turned the same way, so
## the two add: hold_pose writes rotation_degrees as (-n.y, -n.x) * MAX_TILT.
static func _lean_matches_the_slab(fails: Array[String]) -> void:
	var m: HoloMotion = HoloMotion.new()
	_hold(m, FLAT, Vector3.ZERO, 0.2)
	# A device turned +8 degrees about the screen's y axis sees gravity turned
	# the other way in its own frame.
	var o: Vector2 = m.step(FLAT.rotated(Vector3.UP, deg_to_rad(-8.0)), Vector3.ZERO, 1.0 / 60.0)
	var slab_y: float = -o.x * CardView.MAX_TILT
	if slab_y <= 0.0 or absf(o.y) > 0.01:
		fails.append("holo: a device turned +y reads %s, a slab turned %.1f degrees" % [str(o), slab_y])
	var m2: HoloMotion = HoloMotion.new()
	_hold(m2, FLAT, Vector3.ZERO, 0.2)
	o = m2.step(FLAT.rotated(Vector3.RIGHT, deg_to_rad(-8.0)), Vector3.ZERO, 1.0 / 60.0)
	var slab_x: float = -o.y * CardView.MAX_TILT
	if slab_x <= 0.0 or absf(o.x) > 0.01:
		fails.append("holo: a device turned +x reads %s, a slab turned %.1f degrees" % [str(o), slab_x])


static func _screen_axes(fails: Array[String]) -> void:
	# The iPad 8 upright on its stand, in portrait axes: gravity along +x.
	var raw: Vector3 = Vector3(9.81, 0.06, 0.12)
	var down: float = HoloMotion.landscape_of(raw, -1.0)
	var screen: Vector3 = HoloMotion.to_screen(raw, down)
	if down != 1.0 or not screen.is_equal_approx(Vector3(0.06, -9.81, 0.12)):
		fails.append("holo: the stand's reading maps to %s (%+.0f), want down the screen" % [str(screen), down])
	if HoloMotion.landscape_of(Vector3(-9.0, 0.0, -3.0), 1.0) != -1.0:
		fails.append("holo: the other landscape is not told by gravity")
	if HoloMotion.landscape_of(Vector3(0.5, 0.3, -9.8), -1.0) != -1.0:
		fails.append("holo: a pad lying flat forgot which landscape it was in")
	# Either way round, the map is a turn of the device's axes (a right-handed
	# rotation that keeps the glass's normal), so a lean keeps its handedness.
	var a: Vector3 = Vector3(0.3, -0.8, 0.5)
	var b: Vector3 = Vector3(-0.6, 0.1, 0.9)
	for d: float in [1.0, -1.0]:
		var crossed: Vector3 = HoloMotion.to_screen(a, d).cross(HoloMotion.to_screen(b, d))
		if not crossed.is_equal_approx(HoloMotion.to_screen(a.cross(b), d)) \
				or HoloMotion.to_screen(Vector3(0, 0, 1), d) != Vector3(0, 0, 1):
			fails.append("holo: the screen frame for landscape %+.0f is not a turn" % d)


## Under Reduce Motion the shared signal holds the still pose and polls no
## sensor at all; with it off, the same frame polls them once.
static func _still_polls_no_sensor(fails: Array[String]) -> void:
	var prefs: Preferences = Preferences.active
	var forced: Variant = HoloMotion._forced
	var reads: Array[int] = [0]
	HoloMotion._forced = false
	HoloMotion._sensors = func() -> Array:
		reads[0] += 1
		return [FLAT, Vector3.ZERO]
	for reduce: bool in [true, false]:
		Preferences.active = Preferences.new()
		Preferences.active.reduce_motion = reduce
		reads[0] = 0
		HoloMotion._stepped = -2
		var t: Vector2 = HoloMotion.ambient(null, 1.0 / 60.0)
		if reduce and (reads[0] != 0 or t != HoloMotion.STILL_POSE):
			fails.append("holo: under Reduce Motion the signal polled the sensors %d times and reads %s"
				% [reads[0], str(t)])
		if not reduce and reads[0] != 1:
			fails.append("holo: with motion on, a frame polled the sensors %d times, want once" % reads[0])
	HoloMotion._sensors = Callable()
	HoloMotion._forced = forced
	HoloMotion._stepped = -2
	Preferences.active = prefs


## The iOS map is proven on the iPad 8 only (portrait axes; upright on its
## stand, gravity along +x). A reading already turned to the screen (gravity
## down the device's y) raises the doubt; the stand, a propped or flat pad
## and no sensor do not.
static func _ios_axes_doubt(fails: Array[String]) -> void:
	var calm: Dictionary = {
		"the stand": Vector3(9.81, 0.06, 0.12),
		"a pad propped at 45 degrees": Vector3(6.9, 0.1, -6.9),
		"a pad lying flat": Vector3(0.5, 0.3, -9.8),
		"no sensor": Vector3(0.2, 0.4, 0.0),
	}
	for label: String in calm:
		var m: HoloMotion = HoloMotion.new()
		var g: Vector3 = calm[label]
		var out: Array[Vector3] = m.from_portrait(g, Vector3.ZERO)
		if m.axes_doubt:
			fails.append("holo: %s raised the iOS axes doubt" % label)
		if label == "the stand" and not out[0].is_equal_approx(Vector3(0.06, -9.81, 0.12)):
			fails.append("holo: the stand's reading maps to %s, want down the screen" % str(out[0]))
	var turned: HoloMotion = HoloMotion.new()
	turned.from_portrait(Vector3(0.07, -9.80, 0.21), Vector3.ZERO)
	if not turned.axes_doubt:
		fails.append("holo: a reading already in the screen's axes raised no doubt")


## The pointer lights the cards on any desktop, a touchscreen laptop too, and
## never on a phone or pad (Android reports a mouse) or a touch-only screen.
static func _pointer_lights(fails: Array[String]) -> void:
	# [handheld, touchscreen, has_mouse, lights]
	var cases: Dictionary = {
		"a desktop": [false, false, true, true],
		"a touchscreen laptop": [false, true, true, true],
		"a touch-only desktop screen": [false, true, false, false],
		"a pad": [true, true, false, false],
		"an Android phone": [true, true, true, false],
	}
	for label: String in cases:
		var c: Array = cases[label]
		var handheld: bool = c[0]
		var touch: bool = c[1]
		var mouse: bool = c[2]
		var want: bool = c[3]
		if HoloMotion.pointer_lights(handheld, touch, mouse) != want:
			fails.append("holo: on %s the pointer lights %s, want %s" % [label, not want, want])
