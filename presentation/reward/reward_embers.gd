class_name RewardEmbers
extends Control
## CONCEPT 「燼」— THE EMBERS. The reward is not handed to you by a menu. It is
## what you broke, still in the colour of the thing you broke it out of.
##
## THE ARGUMENT. Every reward screen in the genre has the same hole in it: the
## fight ends, the fight vanishes, and an unrelated panel slides in carrying
## numbers. Nothing on it came from anywhere. Here the screen OPENS on the husk
## the enemy died as — GlassGem's own cut, its own dead colours — the cracks
## take light, and it comes apart. The spoils are the three biggest pieces. The
## gold was its light. Nothing arrives from off-screen because nothing needs to.
##
## WHAT THIS BUYS THAT ART CANNOT. The palette is the ENEMY'S hue, straight off
## `art.hue` in content. Duskfang pays out at 22 degrees, a glass construct pays
## out cold, and the two produce visibly different reward screens with no second
## asset drawn and no second code path. A whole axis of variety for one float —
## and variety the player feels without ever being able to name it.
##
## ── WHAT MAKES IT GLASS, which is the whole of the second pass ────────────
##
## THE FRACTURE EDGE IS THE BRIGHTEST PART. This is the one optical fact that
## decides whether a shape reads as broken glass or as a polygon someone filled
## in. A cut edge gathers light along its whole length and throws it at you; the
## body is comparatively dark. The first version drew a uniform 1.6px outline
## and that is exactly what a vector shape looks like.
##
## AND IT IS BRIGHT UNEVENLY. A uniform bright outline is only a second kind of
## sticker. Each edge is lit by where it FACES: the rim is drawn per-edge, its
## width and heat set by that edge's outward normal against the real light in
## the scene. Edges turned toward the bed blaze and thicken, edges turned away
## go to a dark line. That single term is what makes a flat polygon read as a
## solid with a near side and a far side.
##
## THE LIGHT IS IN THE SCENE, NOT IN A CONSTANT. Every rim, every body glow and
## every ember is lit from the bed where the husk fell — one position, and every
## piece computes its own direction to it. Which is also why the pieces near the
## bed are the hot ones and the pieces thrown clear are nearly cold, for free.
##
## THINGS MUST REST ON SOMETHING. Wreckage floating in black is not wreckage.
## There is a floor: a horizon of ember light where the husk came down, debris
## lying along it, and the offering standing IN FRONT of it — so the cards are
## backlit by the thing they were cut out of.
##
## Angle and position, never TIME — the rule card_surface.gdshader works under.
## Once the break has settled nothing here animates; every value is geometry
## against a light, so the screen at rest is still a material.
##
## THE HUE. A reward Dictionary does not carry the enemy's hue, so it is a
## constructor argument: main reads it off `pendingReward.slain_enemy.hue`, the
## `art.hue` of the biggest body in the fight. Given nothing (an older save) it
## falls back to ember, and the concept still works, it just stops being about
## the fight you had.
##
## SHIPPED 2026-09-30 as the game's reward (`Main._show_pending_reward`), under
## the run HUD, with the Flame's lantern, the leave-confirm, keyboard focus and
## a phone set-out of its own (`RewardEmbersPhone`). `RewardScreen` stays as the
## lab's `rows` concept.

## The player has taken something. `id` is "" for gold, which has no content id
## — and ALSO for the card slot when the offering is declined, which is a real
## outcome and not a missing value: "Leave it", and walking on without picking,
## both arrive as `claimed(&"card", "")`. Whatever wires this up has to read an
## empty card id as "no card", never as "not answered yet".
##
## Every spoil is announced exactly once. Walking on before the husk has
## finished coming apart banks whatever the entrance had not reached yet and
## THEN says it is finished — staging never decides what the player keeps — and
## a spoil already settled by `mark_taken` is never announced again.
signal claimed(what: StringName, id: String)
## The screen is done with. Always last: every `claimed` for this reward has
## already been emitted by the time this fires.
signal finished()

const EMBER_HUE: float = 22.0        # the fallback: lantern-fire, Duskfang's own

## THE HUSK. GlassGem's cut, at the size a thing that just died should be. The
## silhouette is reproduced rather than imported because GlassGem is a live
## combat node with its own state contract; what is wanted here is its SHAPE.
const HUSK_R: Vector2 = Vector2(126.0, 146.0)
const HUSK_AT: Vector2 = Vector2(0.0, -46.0)

## The break: six facets, each split, is twelve pieces — enough to read as
## shattered, few enough that every piece is still a shape and not a speck.
const RING: int = 6
const SPLIT: int = 2
const THROW: float = 2.15

## Where everything comes to rest, as offsets from the screen's centre.
const SEAT: Vector2 = Vector2(198.0, 128.0)
const SEAT_GAP: float = 40.0
const SEAT_Y: float = -272.0
## No offering: the one announcement drops toward the fire and the chrome comes
## up under it. Held at the full set-out, a gold-only win is a slab at the top,
## a fire in the middle and three hundred empty pixels of nothing — the layout
## has to contract with the haul or the thin case reads as broken.
const SEAT_Y_LEAN: float = -188.0
const LEAN_FOOT: float = 188.0
## What hangs below the rack: the take line, then the word row under it.
const FOOT_REACH: float = 72.0
## How far a seat slab reaches above its own centre, as a fraction of SEAT —
## `_slab`'s highest vertex, with a little over for the spin.
const SEAT_RISE: float = 0.58
const ART_H: float = 74.0
## The bed: where the husk came down, and the only light in the scene. It gets
## its own band. Parked behind the rack its hot core sat squarely under three
## opaque cards — the brightest thing on the screen, invisible, with only the
## dim outer throw showing past the edges. A light source has to be somewhere
## you can see it lighting things.
const BED_Y: float = -46.0
const BED_W: float = 1080.0
const BED_H: float = 216.0

const CARD_W_OUT: float = 178.0
const CARD_GAP: float = 22.0
const CARD_Y: float = 26.0           # top of the rack — it stands IN the bed
const CARD_RISE: float = 30.0

const COMPACT_ART: float = 50.0     # a phone face's art, beside its words
const FLOOR_GAP: float = 6.0

const SIT: float = 0.18              # the husk, whole, before anything
const BLAZE: float = 0.10            # the cracks taking light
const BURST: float = 0.46            # it coming apart
const COOL: float = 0.40             # white-hot fracture -> the item's colour
const CARD_IN: float = 0.28
const DEBRIS_A: float = 0.90
## A card not taken, once the offering has been answered.
const PASSED_A: float = 0.14

const TEXT: Color = Color(0.902, 0.914, 0.949)
const TEXT_DIM: Color = Color(0.600, 0.628, 0.706)
const GOLD: Color = Color(0.949, 0.757, 0.306)
const NIGHT: Color = Color(0.012, 0.015, 0.032)

var reward: Dictionary = {}
var content: ContentDB
var encounter_kind: String = "normal"
var hue: float = EMBER_HUE
## The stage shape the set-out is composed for. Re-seated by `set_shape`.
var shape: StringName = StageShape.IDENTITY
## True on the route, where the run HUD stands over this screen: the set-out
## then keeps clear of the HUD's top bar and its first relic row.
var under_hud: bool = false
## WHAT THE SCREEN MAY NOT DRAW INTO. This screen does not get the whole canvas.
## In the viewer the lab's control strip lies across the top; in the game the
## run HUD does (`under_hud`). The set-out is a column of fixed heights, so told
## what is eating an edge it can move OFF that edge — which is the whole
## difference between a layout that is wrong and a layout you simply cannot see.
var safe_top: float = 0.0
var safe_bottom: float = 0.0

## Every piece: a polygon in husk-local coordinates plus where it ends up.
## `seat` is -1 for debris, otherwise the spoil index it carries.
var _shards: Array[Dictionary] = []
var _burst: float = 0.0
var _cool: float = 0.0
var _blaze: float = 0.0
## The bed is LIGHT and the wreckage is MATTER, so they cannot share a layer.
## Light has to be additive — drawn with normal alpha it can only ever pull the
## black toward its own colour, which is why the first bed read as a stain. The
## shards stay on a normal-blend layer above it, because a shard has to be able
## to occlude the glow it is lying in or it stops being a thing.
var _bed: Control = null
var _bed_tex: Array[GradientTexture2D] = []
var _motes: RewardKit = null
var _mote_node: GPUParticles2D = null
var _field: Control = null           # the wreckage; draws, takes no input
var _plate: Control = null
var _spoils: Array[Dictionary] = []
## One flag per announcement, so there is a single place that knows whether a
## spoil has already gone to the run — whether it got there by the entrance
## reaching it, by the player walking on early, or by a resume arriving with it
## already banked.
var _banked: Array[bool] = []
var _card_ids: Array[String] = []
var _cards: Array[CardView] = []
## One focusable key per card for the keyboard and the pad; it ignores the
## mouse, so the card keeps its lamp.
var _card_keys: Array[Button] = []
var _faces: Array[Control] = []
var _faces_seat: Vector2 = Vector2.ZERO
var _faces_compact: bool = false
var _picked: bool = false
var _left: bool = false
var _lean: bool = false
var _take_line: Label = null
var _bar: HBoxContainer = null
var _skip_word: Button = null
var _walk_word: Button = null
var _rack: Control = null            # the offering's bounds, for the hint
var _lantern: RunLantern = null
var _confirm: RewardLeaveConfirm = null
var _t: float = 0.0                  # the entrance clock
var _settled: bool = false
var _centre: Vector2 = Vector2.ZERO

## The resolved set-out, rebuilt by `_place`; offsets from `_centre`.
var _compact: bool = false
var _k: float = 1.0                  # the husk, the throw and the bed
var _card_scale: float = CARD_W_OUT / CardView.CARD_W
var _card_gap: float = CARD_GAP
var _seat: Vector2 = SEAT
var _husk_at: Vector2 = HUSK_AT
var _bed_y: float = BED_Y
var _seat_rel: Array[Vector2] = []
var _card_rel: Array[Vector2] = []
var _foot_y: float = 0.0             # the rack's floor, in screen px
var _foot_x: Vector2 = Vector2.ZERO  # the span the take line and words sit in
## Entrance state per piece, so a re-seat mid-entrance still lands it home.
var _face_a: Array[float] = []
var _card_a: Array[float] = []
var _card_rise: Array[float] = []
var _card_dim: Array[float] = []


func _init(reward_ref: Dictionary, content_ref: ContentDB,
		kind: String = "normal", enemy_hue: float = -1.0,
		stage_shape: StringName = StageShape.IDENTITY, run_hud: bool = false) -> void:
	reward = reward_ref
	content = content_ref
	encounter_kind = kind
	hue = EMBER_HUE if enemy_hue < 0.0 else enemy_hue
	shape = stage_shape if StageShape.REFERENCES.has(stage_shape) else StageShape.IDENTITY
	under_hud = run_hud
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spoils = RewardSpoils.list(reward, content)
	_banked.resize(_spoils.size())
	_card_ids = RewardSpoils.card_ids(reward)
	_lean = _card_ids.is_empty()
	_face_a.resize(_spoils.size())
	_face_a.fill(0.0)
	for _i: int in range(_card_ids.size()):
		_card_a.append(0.0)
		_card_rise.append(CARD_RISE)
		_card_dim.append(1.0)
	_read_shape()

	var ground: ColorRect = ColorRect.new()
	ground.color = NIGHT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_bed = Control.new()
	_bed.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bed.material = add
	_bed_tex = [
		RewardKit.radial(_hue_at(0.80, 0.42)),   # the long throw across the floor
		RewardKit.radial(_hue_at(0.62, 0.78)),   # the body of the fire
		RewardKit.radial(_hue_at(0.34, 1.00)),   # the core it fell into
	]
	_bed.draw.connect(_draw_bed)
	add_child(_bed)

	_field = Control.new()
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.draw.connect(_draw_field)
	add_child(_field)

	_build_plate()
	# 「燼」means embers, and until now there were none — the bed was a glow with
	# nothing coming off it. These rise through the wreckage, so the fire reads
	# as still burning rather than as a light source parked behind the scene.
	var motes: Control = Control.new()
	motes.set_anchors_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(motes)
	_motes = RewardKit.new(motes)


## The shape's numbers: the offering's card from the layout book's `reward`
## scope (the width a human measures, 178 on the pad and 135 on the phone), and
## whether this is the phone's set-out.
func _read_shape() -> void:
	_compact = shape == &"phone-landscape"
	var book: Dictionary = LayoutBook.resolve(&"reward", shape)
	_card_scale = LayoutBook.num(book.get("w"), CARD_W_OUT) / CardView.CARD_W
	_card_gap = LayoutBook.num(book.get("gap"), CARD_GAP) if _compact else CARD_GAP
	_k = RewardEmbersPhone.K if _compact else 1.0


func _hue_at(sat: float, val: float) -> Color:
	return Color.from_hsv(fmod(hue, 360.0) / 360.0, sat, val)


## The bed, in screen coordinates — the light everything on this screen is lit
## by. One position, so no piece can disagree with another about where it is.
func _light() -> Vector2:
	return _centre + Vector2(_husk_at.x, _bed_y)


# ---------------------------------------------------------------- the break

## Rebuilt with the set-out: where a piece lands is a fact about the stage it
## lands on, and the phone's break is the same break at half the size.
func _build_shards() -> void:
	_shards.clear()
	var outline: PackedVector2Array = _husk_outline()
	var wedge: int = 0
	for i: int in range(RING):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % RING]
		for s: int in range(SPLIT):
			var t0: float = float(s) / float(SPLIT)
			var t1: float = float(s + 1) / float(SPLIT)
			var poly: PackedVector2Array = PackedVector2Array([
				Vector2.ZERO, a.lerp(b, t0), a.lerp(b, t1),
			])
			# Every wedge thrown the SAME multiple lands the debris on a clock
			# face. The golden-ratio walk gives each piece its own distance and
			# stays reproducible, so a shot of this screen is the same tomorrow.
			var mid: Vector2 = (poly[1] + poly[2]) * 0.5
			var jitter: float = fmod(float(wedge) * 0.6180339887 + 0.17, 1.0)
			var far: float = THROW * (0.70 + 1.30 * jitter)
			# ...and everything FALLS. Pieces settle onto the bed rather than
			# holding whatever height they were thrown to, which is the other
			# half of why the first pass read as shapes floating in a void.
			var land: Vector2 = _husk_at + mid * far
			# Pulled hard onto the bed line. Wreckage scattered evenly through the
			# air between two other bands is not wreckage, it is confetti — it has
			# to lie in the fire it came out of, and be SILHOUETTED by it.
			land.y = lerpf(land.y, _bed_y + (jitter - 0.40) * 46.0 * _k, 0.88)
			# Wide, but not off the edge: a piece clipped by the frame stops being
			# wreckage and becomes a rendering artefact.
			land.x = _husk_at.x + (land.x - _husk_at.x) * 1.06
			if size.x > 0.0:
				land.x = clampf(land.x, 24.0 - _centre.x, size.x - 24.0 - _centre.x)
				land.y = minf(land.y, size.y - 16.0 - HUSK_R.y * 0.5 * _k - _centre.y)
			_shards.append({
				"poly": poly,
				"home": land,
				"seat": -1,
				"spin": (jitter - 0.5) * 1.3,
				"lit": 0.32 + 0.5 * float((i * SPLIT + s) % 3) / 2.0,
			})
			wedge += 1
	# The seats are their OWN pieces, not promoted wedges. A wedge is a thin
	# triangle running to a point at the husk's centre; scaling one up until it
	# could carry a 198px item makes a spike, not a plate.
	for i: int in range(_seat_rel.size()):
		_shards.append({
			"poly": _slab(i, _seat),
			"home": _seat_rel[i],
			"seat": i,
			"spin": (fmod(float(i) * 0.6180339887 + 0.31, 1.0) - 0.5) * 0.34,
			"lit": 0.70 + 0.14 * float(i % 2),
		})


## A slab of the husk big enough to set something on. Five points rather than
## four so no edge is parallel to its opposite and it never reads as a card.
static func _slab(i: int, box: Vector2 = SEAT) -> PackedVector2Array:
	var j: float = fmod(float(i) * 0.7548776662, 1.0) - 0.5    # -0.5 .. 0.5
	# Six points with two of them driven hard off the box: a shard has corners
	# that overshoot and corners that cave in, and a pentagon whose vertices all
	# sit near the bounding box is a rounded rectangle wearing a hat.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-0.54 - 0.10 * j, -0.30 + 0.16 * j),
		Vector2(-0.22 + 0.14 * j, -0.54),
		Vector2(0.50, -0.42 - 0.12 * j),
		Vector2(0.58 + 0.08 * j, 0.24 - 0.10 * j),
		Vector2(0.06 - 0.18 * j, 0.56),
		Vector2(-0.44 + 0.10 * j, 0.34 + 0.14 * j),
	])
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * box)
	return out


func _husk_outline() -> PackedVector2Array:
	# GlassGem's cut: crown point, shoulders, lower corners, cutlet point.
	var r: Vector2 = HUSK_R * _k
	return PackedVector2Array([
		Vector2(0.0, -r.y),
		Vector2(r.x, -r.y * 0.28),
		Vector2(r.x * 0.52, r.y * 0.58),
		Vector2(0.0, r.y),
		Vector2(-r.x * 0.52, r.y * 0.58),
		Vector2(-r.x, -r.y * 0.28),
	])


func _seat_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n: int = _spoils.size()
	var span: float = float(n) * SEAT.x + float(maxi(0, n - 1)) * SEAT_GAP
	for i: int in range(n):
		out.append(Vector2(-span * 0.5 + SEAT.x * 0.5
			+ float(i) * (SEAT.x + SEAT_GAP),
			SEAT_Y_LEAN if _lean else SEAT_Y))
	return out


# ---------------------------------------------------------------- the draw

func _draw_field() -> void:
	for shard: Dictionary in _shards:
		_draw_shard(shard)


## The bed: where the husk came down, and the only light in the scene. Drawn as
## stacked ellipses rather than one gradient so it has a hot core and a long
## cool throw — a bank of embers, not a lamp.
func _draw_bed() -> void:
	var at: Vector2 = _light()
	var heat: float = 0.24 + 0.76 * _burst
	var w: float = BED_W * _k
	var h: float = BED_H * _k
	# THREE SMOOTH LAYERS, not a stack of hard ellipses. Concentric draw_circles
	# band — nine of them is nine visible rings, which is a target, not a fire.
	# A radial gradient is one smooth falloff per layer and three of them nest
	# into a hot core with a long cool throw. They are also built ONCE: rebuilt
	# per frame this allocates three textures every redraw of the burst.
	_bed.draw_texture_rect(_bed_tex[0],
		_bed_rect(at, w, h), false, Color(1, 1, 1, 0.78 * heat))
	_bed.draw_texture_rect(_bed_tex[1],
		_bed_rect(at, w * 0.46, h * 0.52), false,
		Color(1, 1, 1, 0.70 * heat))
	_bed.draw_texture_rect(_bed_tex[2],
		_bed_rect(at, w * 0.17, h * 0.20), false,
		Color(1, 1, 1, 0.88 * heat))


static func _bed_rect(at: Vector2, w: float, h: float) -> Rect2:
	return Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))


## One piece of the enemy. Body, the light caught in its middle, then the rim —
## and the rim is the whole trick: drawn EDGE BY EDGE, each one's width and heat
## set by whether it faces the bed. A uniform outline is a vector shape however
## bright it is; this is what gives a flat polygon a near side and a far side.
func _draw_shard(shard: Dictionary) -> void:
	var seat: int = shard["seat"]
	var at: Vector2 = _centre + _shard_at(shard)
	var spin_at: float = shard["spin"]
	var spin: float = spin_at * (1.0 - _burst)
	var lit: float = shard["lit"]
	var scale: float = lerpf(1.0, 0.60, _burst) if seat < 0 \
		else lerpf(0.22, 1.0, _burst)

	# How near this piece is to the bed decides how hot it still is. Nothing
	# says "cooling" like the far pieces being the dead ones.
	var to_light: Vector2 = _light() - at
	var near: float = clampf(1.0 - to_light.length() / (620.0 * _k), 0.0, 1.0)
	var dir: Vector2 = to_light.normalized()

	# Glass this dark is read entirely off its edges. Giving the body a mid
	# value tries to describe the piece twice and succeeds at neither: it is too
	# dark to be a colour and too light to be a silhouette, which is precisely
	# the brown-paper look. It goes near-black, and the fracture carries it.
	var tone: Color = _hue_at(0.70, 0.06 + 0.13 * lit + 0.22 * near)
	var hot: Color = _hue_at(0.30, 1.0)
	if seat >= 0:
		# A seat cools out of the husk's hue into the item's own — the whole
		# claim of the concept in one lerp: this piece WAS the enemy, and is
		# now yours.
		var mine: Color = _spoils[seat]["tone"]
		tone = tone.lerp(Color(mine.r * 0.50, mine.g * 0.50, mine.b * 0.50), _cool)
		hot = hot.lerp(mine, _cool * 0.85)
	# Freshly broken glass is white at the cut and settles into its colour.
	var fresh: float = (1.0 - _cool) * _burst
	hot = hot.lerp(Color(1.0, 0.97, 0.92), fresh * 0.75)
	# THE BLAZE, before anything has moved. At _burst 0 every piece is still
	# stacked in the husk, so the shard edges ARE the crack lines — driving the
	# rim with it lights the fractures from inside a still-whole stone, which is
	# the one beat that makes the break read as a thing failing rather than a
	# transition playing. It dies as the pieces separate, because by then the
	# cracks have become edges and there is nothing left to crack.
	var flare: float = _blaze * (1.0 - _burst)
	hot = hot.lerp(Color(1.0, 0.98, 0.94), flare * 0.8)

	var alpha: float = 1.0 if seat >= 0 else lerpf(1.0, DEBRIS_A, _burst)
	var pts: PackedVector2Array = PackedVector2Array()
	var src: PackedVector2Array = shard["poly"]
	for p: Vector2 in src:
		pts.append(at + p.rotated(spin) * scale)

	# Body, then the light gathered in its middle: glass is not evenly lit
	# through, it pools where the piece is thickest.
	_field.draw_colored_polygon(pts, Color(tone, alpha * 0.88))
	# The inner glow is inset AND pushed toward the light. Centred, it reads as
	# a shape with a hole in it; shifted, the bright region crowds the lit edge
	# and the piece reads as something light is entering from one side.
	var core: PackedVector2Array = PackedVector2Array()
	var shift: Vector2 = dir * 13.0 * scale * _k
	for p: Vector2 in pts:
		core.append(at.lerp(p, 0.60) + shift)
	_field.draw_colored_polygon(core,
		Color(hot, alpha * (0.14 + 0.42 * near) * (0.30 + 0.70 * _cool)))

	# THE FRACTURE. Per edge, lit by its own facing against the bed.
	var n: int = pts.size()
	for i: int in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var edge: Vector2 = b - a
		if edge.length() < 0.5:
			continue
		# Outward normal: the shard is wound consistently, so one orthogonal is
		# always the one pointing away from the centroid.
		var outward: Vector2 = edge.orthogonal().normalized()
		if outward.dot(((a + b) * 0.5) - at) < 0.0:
			outward = -outward
		var facing: float = maxf(0.0, outward.dot(dir))
		var w: float = (1.0 + 5.6 * facing * (0.45 + 0.55 * near)) \
			* (1.0 + flare * 1.7) * sqrt(_k)
		var glow: float = facing * (0.30 + 0.70 * near)
		# A fracture's brightness is a SURFACE reflection, not transmission —
		# so the hotter an edge is lit, the whiter it goes, whatever colour the
		# glass is. Keeping the rim in the body's own hue was the other reason
		# these read as cut paper: coloured glass with a coloured outline is a
		# sticker, and one white edge is what turns it into a solid.
		var edge_col: Color = hot.lerp(Color(1.0, 0.98, 0.95),
			facing * 0.70 + flare * 0.25)
		_field.draw_line(a, b, Color(edge_col,
			clampf(alpha * (0.20 + 0.80 * glow) + flare * 0.85, 0.0, 1.0)), w)


## Where a piece is right now: still in the husk at 0, at its resting place at
## 1, and thrown a little past it in between so the break has some weight.
func _shard_at(shard: Dictionary) -> Vector2:
	var home: Vector2 = shard["home"]
	var over: float = sin(_burst * PI) * 0.16
	return _husk_at.lerp(home, _burst) \
		+ (home - _husk_at).normalized() * over * 64.0 * _k


# ---------------------------------------------------------------- the face

func _build_plate() -> void:
	_plate = Control.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_rack = Control.new()
	_rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_rack)
	for i: int in range(_card_ids.size()):
		var card: CardView = RewardSpoils.card(content, _card_ids[i],
			9100 + i, _card_scale, _take_card)
		var seat: Control = RewardSpoils.pedestal(card, _card_scale)
		seat.modulate.a = 0.0
		_plate.add_child(seat)
		_cards.append(card)
		var key: Button = _focus_key(_card_ids[i])
		seat.add_child(key)
		_card_keys.append(key)

	if not _card_ids.is_empty():
		_take_line = _caption(Locale.active.t("ui.reward.onePiece"), 13, TEXT_DIM, 3)
		_take_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_plate.add_child(_take_line)

	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 30)
	_plate.add_child(_bar)
	if not _card_ids.is_empty():
		_skip_word = _word(Locale.active.t("ui.reward.leaveIt"), _skip)
		_bar.add_child(_skip_word)
	_walk_word = _word(Locale.active.t("ui.reward.walkOn"), _on_walk_on)
	_bar.add_child(_walk_word)


## The spoils' faces, for the current set-out. Built by `_place` once the seat
## is known, and again whenever it changes: the phone's seat is derived from the
## band it has, and the phone and the pad lay a face out differently.
func _build_faces() -> void:
	_faces_seat = _seat
	_faces_compact = _compact
	for face: Control in _faces:
		face.queue_free()
	_faces.clear()
	for i: int in range(_spoils.size()):
		var face: Control = _spoil_face(_spoils[i])
		face.modulate.a = _face_a[i]
		_plate.add_child(face)
		_plate.move_child(face, i)
		_faces.append(face)


## A card's keyboard handle. The whole pedestal, invisible until it has focus,
## and then it wears the lantern ring every glass surface shares.
func _focus_key(id: String) -> Button:
	var key: Button = Button.new()
	key.flat = true
	key.set_anchors_preset(Control.PRESET_FULL_RECT)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.focus_mode = Control.FOCUS_ALL
	key.add_theme_stylebox_override("focus", GlassStyle.focus_ring(GOLD, 10))
	key.pressed.connect(_take_card.bind(id))
	return key


func _spoil_face(sp: Dictionary) -> Control:
	var box: Control = Control.new()
	box.size = _seat
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On the phone a face lies on its side: art at the left, the words beside
	# it. Stood up, three of them are taller than the phone is.
	var art_side: float = COMPACT_ART if _compact else ART_H
	var art_rect: Rect2 = Rect2(14.0, (_seat.y - art_side) * 0.5, art_side, art_side) \
		if _compact else Rect2(0.0, 2.0, _seat.x, ART_H)
	var art: String = sp["art"]
	if art != "":
		var tex: TextureRect = TextureRect.new()
		tex.texture = RewardKit.mip(art)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tex.size = art_rect.size
		tex.position = art_rect.position
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tex)
	else:
		var mark: Label = _caption(str(sp["glyph"]), 32 if _compact else 44, TEXT, 0)
		mark.size = art_rect.size
		mark.position = art_rect.position
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(mark)

	# Light text, not the window's dark paint: nothing here is backlit through
	# a sheet, so ink on a shard would just be a hole in it.
	var text_x: float = art_rect.end.x + 10.0 if _compact else 0.0
	var text_w: float = _seat.x - text_x - (12.0 if _compact else 0.0)
	var name_label: Label = _caption(str(sp["name"]).to_upper(), 12 if _compact else 13,
		TEXT, 3)
	name_label.size = Vector2(text_w, 20.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _compact \
		else HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	# What the thing DOES. The rows screen carried it on the row because a touch
	# device cannot open a tooltip; a relic you cannot read is a relic you took
	# blind, so the embers carry it too — two lines under the name, dim.
	var sub: String = sp["sub"]
	var sub_label: Label = null
	if sub != "":
		sub_label = _caption(sub, 11, TEXT_DIM, 0)
		sub_label.add_theme_font_override("font",
			RewardKit.font(GlassStyle.ALEGREYA_400, 0))
		sub_label.add_theme_font_size_override("font_size", 12 if _compact else 13)
		sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_label.max_lines_visible = 2
		sub_label.horizontal_alignment = name_label.horizontal_alignment
		sub_label.size = Vector2(text_w, 34.0)
		box.add_child(sub_label)
	if _compact:
		var top: float = (_seat.y - (20.0 + (36.0 if sub_label != null else 0.0))) * 0.5
		name_label.position = Vector2(text_x, top)
		if sub_label != null:
			sub_label.position = Vector2(text_x, top + 21.0)
	else:
		name_label.position = Vector2(0.0, ART_H + 6.0)
		if sub_label != null:
			sub_label.position = Vector2(0.0, ART_H + 27.0)
	return box


func _caption(text: String, px: int, col: Color, tracking: int) -> Label:
	var l: Label = RewardKit.text(text, GlassStyle.CINZEL_700, px, col, tracking)
	return l


func _word(text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", RewardKit.font(GlassStyle.CINZEL_700, 3))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT_DIM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	b.add_theme_stylebox_override("focus", GlassStyle.focus_ring(GOLD, 6))
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- the burst

func _ready() -> void:
	_place()
	resized.connect(_place)


## The entrance runs on this screen's own clock, not on tweens or tree timers.
## A screen frozen under a modal (Main's `_freeze_under_modal`) stops
## processing, so it holds its entrance AND its news, where a tree timer would
## keep handing the run spoils from behind the veil; and a headless test can
## drive the whole break with `advance`, as `LanternFlame.advance` does.
func _process(delta: float) -> void:
	advance(delta)


## A beat of the husk sitting there, then the cracks take light, THEN it
## goes. Without the first two the break has nothing to be a break from and
## reads as a transition; with them it reads as a thing failing. Once the last
## card has landed the clock stops and nothing here animates again.
func advance(delta: float) -> void:
	if _settled:
		return
	_t += delta
	_set_blaze(_ramp(SIT, BLAZE))
	_set_burst(1.0 - pow(1.0 - _ramp(SIT + BLAZE, BURST), 5.0))     # quint out
	_set_cool(_ramp(SIT + BLAZE + BURST * 0.5, COOL))
	for i: int in range(_spoils.size()):
		var at: float = SIT + BLAZE + BURST * 0.66 + 0.05 * float(i)
		_reveal_face(_ramp(at, 0.24), i)
		if _t >= at:
			_announce(i)
	var rise: float = CARD_IN + 0.08
	for i: int in range(_cards.size()):
		var wait: float = SIT + BLAZE + BURST * 0.72 + 0.06 * float(i)
		_card_in(1.0 - pow(1.0 - _ramp(wait, rise), 3.0), i)            # cubic out
	if _t >= SIT + BLAZE + BURST + 0.06 * float(_cards.size()) + rise:
		_settled = true
		set_process(false)
		_on_entrance_done()


## 0 until `start`, 1 from `start + span`, linear between, on the entrance clock.
func _ramp(start: float, span: float) -> float:
	return clampf((_t - start) / span, 0.0, 1.0)


## The one door every announcement goes through. A beat that has been overtaken
## — by a resume that arrived with this spoil already banked, or by the player
## walking on before it fired — has to go quiet rather than fire late, because
## on the far side of this signal is a run that will happily take the gold twice.
func _announce(i: int) -> void:
	if _banked[i]:
		return
	_banked[i] = true
	claimed.emit(_spoils[i]["what"], _spoils[i]["id"])


func _set_blaze(v: float) -> void:
	_blaze = v
	_field.queue_redraw()
	_bed.queue_redraw()


func _set_burst(v: float) -> void:
	_burst = v
	_field.queue_redraw()
	_bed.queue_redraw()
	_place_faces()


func _set_cool(v: float) -> void:
	_cool = v
	_field.queue_redraw()
	_bed.queue_redraw()


func _reveal_face(v: float, i: int) -> void:
	_face_a[i] = v
	if i < _faces.size():
		_faces[i].modulate.a = v


func _card_in(v: float, i: int) -> void:
	_card_a[i] = clampf(v * (CARD_IN + 0.08) / CARD_IN, 0.0, 1.0)
	_card_rise[i] = CARD_RISE * (1.0 - v)
	_place_card(i)


func _dim_card(v: float, i: int) -> void:
	_card_dim[i] = v
	_place_card(i)


## The entrance is over: hand the keyboard somewhere to start, unless the
## player has already put it somewhere themselves.
func _on_entrance_done() -> void:
	var vp: Viewport = get_viewport()
	if vp == null or vp.gui_get_focus_owner() != null or _confirm != null:
		return
	var first: Control = _card_keys[0] if not _picked and not _card_keys.is_empty() \
		else _walk_word
	# Held without its ring: a pointer player never asked for a highlighted card,
	# and the first arrow or Enter from a pad starts from here all the same.
	if first != null and first.is_visible_in_tree():
		first.grab_focus(true)


# ---------------------------------------------------------------- the set-out

## Where the column stands. Centred in whatever band is left once the insets
## come off, and pinned to the TOP of that band when the band is shorter than
## the column — the buttons running off the bottom is a thing you can still see
## and scroll your eye to, the spoils hidden under the top edge is not, and the
## spoils are what the screen is for. With no insets this lands within four
## pixels of the raw centre, so nothing moves on a screen that owns its canvas.
func _anchor() -> Vector2:
	var rise: float = -(SEAT_Y_LEAN if _lean else SEAT_Y) + SEAT.y * SEAT_RISE
	var drop: float = (LEAN_FOOT if _lean
		else CARD_Y + _card_h()) + FOOT_REACH
	var top: float = _top()
	var band: float = size.y - top - safe_bottom
	return Vector2(size.x * 0.5,
		top + rise + maxf(0.0, (band - rise - drop) * 0.5))


## What the top edge loses: the lab's strip, or on the route the run HUD's bar
## and its first relic row (the Flame's lantern hangs below that, at the left).
func _top() -> float:
	return maxf(safe_top, RunHud.relic_row_bottom(shape) if under_hud else 0.0)


func _card_w() -> float:
	return CardView.CARD_W * _card_scale


func _card_h() -> float:
	return CardView.CARD_H * _card_scale


func _place() -> void:
	if _compact:
		_layout_compact()
	else:
		_layout_column()
	_build_shards()
	if _faces.size() != _spoils.size() or _faces_seat != _seat \
			or _faces_compact != _compact:
		_build_faces()
	if _motes != null:
		if _mote_node == null:
			_motes.embers(Vector2.ZERO, 340.0, hue)
			_mote_node = _motes.stage.get_child(0) as GPUParticles2D
		_mote_node.position = _light() + Vector2(0.0, 8.0 * _k)
		var pm: ParticleProcessMaterial = _mote_node.process_material as ParticleProcessMaterial
		if pm != null:
			pm.emission_box_extents.x = 340.0 * _k
	_field.queue_redraw()
	_bed.queue_redraw()
	_place_faces()
	for i: int in range(_cards.size()):
		_place_card(i)
	if not _card_rel.is_empty():
		_rack.position = _centre + _card_rel[0]
		_rack.size = Vector2(_card_rel[-1].x - _card_rel[0].x + _card_w(), _card_h())
	var span: float = _foot_x.y - _foot_x.x
	if _take_line != null:
		_take_line.size = Vector2(span, 22.0)
		_take_line.position = Vector2(_foot_x.x, _foot_y + (8.0 if _compact else 14.0))
	if _bar != null:
		_bar.size = Vector2(span, 30.0)
		_bar.position = Vector2(_foot_x.x, _foot_y + (28.0 if _compact else 42.0))


## The pad and the desktop: the concept's own column, spoils over the fire
## over the offering, centred.
func _layout_column() -> void:
	_seat = SEAT
	_husk_at = HUSK_AT
	_bed_y = BED_Y
	_centre = _anchor()
	_seat_rel = _seat_positions()
	_card_rel.clear()
	var n: int = _card_ids.size()
	var span: float = float(n) * _card_w() + float(maxi(0, n - 1)) * _card_gap
	for i: int in range(n):
		_card_rel.append(Vector2(-span * 0.5 + float(i) * (_card_w() + _card_gap), CARD_Y))
	_foot_y = _centre.y + (LEAN_FOOT if _lean else CARD_Y + _card_h())
	_foot_x = Vector2(0.0, size.x)


## The phone (`RewardEmbersPhone`): the offering at the right, the spoils as a
## column clear of the lantern's seat, the fire on the floor between them.
func _layout_compact() -> void:
	var lantern: Dictionary = LayoutBook.resolve(&"chrome", shape, 0).get("lantern", {})
	var set_out: Dictionary = RewardEmbersPhone.lay_out(size, _top(),
		size.y - maxf(safe_bottom, FLOOR_GAP), _spoils.size(), _card_ids.size(),
		Vector2(_card_w(), _card_h()), _card_gap,
		LayoutBook.num(lantern.get("left")) + LayoutBook.num(lantern.get("w"),
			RunLantern.NATURAL) + 10.0)
	_centre = set_out["centre"]
	_seat = set_out["seat"]
	_husk_at = set_out["husk_at"]
	_bed_y = set_out["bed_y"]
	_seat_rel = set_out["seat_rel"]
	_card_rel = set_out["card_rel"]
	_foot_y = set_out["foot_y"]
	_foot_x = set_out["foot_x"]


## Faces ride their shard out rather than appearing where it lands, so the item
## and the piece carrying it are never two separate events.
func _place_faces() -> void:
	for i: int in range(mini(_faces.size(), _seat_rel.size())):
		var home: Vector2 = _seat_rel[i] - _seat * 0.5
		_faces[i].position = _centre + home \
			+ (_husk_at - home) * (1.0 - _burst) * 0.35


func _place_card(i: int) -> void:
	if i >= _card_rel.size():
		return
	var seat: Control = _cards[i].get_parent()
	seat.position = _centre + _card_rel[i] + Vector2(0.0, _card_rise[i])
	seat.modulate.a = _card_a[i] * _card_dim[i]


## Follow a re-pick. The phone and the pad lay the screen out differently, so
## crossing that line rebuilds the faces (`_place`); the offering is re-scaled in place,
## so a card the player is mid-hover over keeps its identity.
func set_shape(stage_shape: StringName) -> void:
	if stage_shape == shape or not StageShape.REFERENCES.has(stage_shape):
		return
	shape = stage_shape
	_read_shape()
	var span: Vector2 = Vector2(CardView.CARD_W, CardView.CARD_H)
	for card: CardView in _cards:
		var seat: Control = card.get_parent()
		seat.custom_minimum_size = span * _card_scale
		seat.size = seat.custom_minimum_size
		card.scale = Vector2(_card_scale, _card_scale)
		card.position = (seat.custom_minimum_size - span) * 0.5
	if _lantern != null:
		_lantern.set_shape(shape)
	_place()


# ---------------------------------------------------------------- the choice

func _take_card(id: String) -> void:
	if _picked:
		return
	_picked = true
	var had_key: bool = _card_keys.any(func(k: Button) -> bool: return k.has_focus())
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in range(_card_ids.size()):
		if _card_ids[i] != id:
			tw.tween_method(_dim_card.bind(i), _card_dim[i], PASSED_A, 0.30)
	if _take_line != null:
		tw.tween_property(_take_line, "modulate:a", 0.0, 0.22)
	_stand_down()
	if had_key and _walk_word != null:
		_walk_word.grab_focus()
	claimed.emit(&"card", id)


## The offering has been answered: nothing on it takes a pick or the keyboard
## any more, and "Leave it" has nothing left to leave.
func _stand_down() -> void:
	for card: CardView in _cards:
		card.set_playable(false)
	for key: Button in _card_keys:
		key.focus_mode = Control.FOCUS_NONE
		key.disabled = true
	if _skip_word != null:
		_skip_word.visible = false


func _skip() -> void:
	_take_card("")


## "Walk on". With the offering still unanswered the player is asked first —
## an offer walked past is gone for good, and this is the one place the screen
## refuses to be quiet about a mistake. Announcements never need asking: they
## are banked on the way out whatever happens.
func _on_walk_on() -> void:
	if _left:
		return
	if not _picked and not _card_ids.is_empty():
		_open_confirm()
		return
	_leave()


func _leave() -> void:
	if _left:
		return          # the button and request_leave() reach the same door
	_left = true
	# Whatever the entrance has not got to yet is banked NOW, before the screen
	# says it is done. Walking on early is impatience, not a refusal of the gold
	# — and a caller that has been told the screen is finished should never then
	# be handed another claim out of it.
	for i: int in range(_spoils.size()):
		_announce(i)
	if not _picked and not _card_ids.is_empty():
		_take_card("")
	finished.emit()


## Mark a slot already spent without emitting — the state a RESUMED reward is
## in: `pendingReward.taken` is saved per slot. A banked announcement looks like
## any other (it is the player's, and dimming it would read as lost); its
## callback simply goes quiet. A card slot already answered stands the offering
## down. Silently ignores a slot this reward never offered.
func mark_taken(what: StringName) -> void:
	if what == &"card":
		if _card_ids.is_empty():
			return
		_picked = true
		for i: int in range(_cards.size()):
			_card_dim[i] = PASSED_A
			_place_card(i)
		if _take_line != null:
			_take_line.visible = false
		_stand_down()
		return
	for i: int in range(_spoils.size()):
		var mine: StringName = _spoils[i]["what"]
		if mine == what:
			# Settled before this screen existed — the entrance still plays it
			# out, but its callback must not hand the run a second helping.
			_banked[i] = true


func request_leave() -> void:
	_on_walk_on()


# ---------------------------------------------------------------- the route

## What the first-run hint points at: the offering, which is the one decision
## on this screen (`ui.hint.reward`). Without one, the screen itself.
func callout_anchor() -> Control:
	return _rack if not _card_ids.is_empty() else self


## The Flame's reading, in the hero's lantern beside the spoils, so a card taken
## here is seen changing the flame here (lock §9). Main hands it the reading as
## the screen opens (`instant`) and again after a claim moves the deck. The
## lantern is built on the first reading, so a run whose aspect has no ways
## never grows one.
func show_flame(event: Dictionary, instant: bool = false) -> void:
	if _lantern == null:
		_lantern = RunLantern.new(shape)
		add_child(_lantern)
	_lantern.show_flame(event, instant)


# ---------------------------------------------------------------- the confirm

func _open_confirm() -> void:
	if _confirm != null:
		return
	_set_keys(false)
	_confirm = RewardLeaveConfirm.new(minf(RewardScreen.PANEL_W, size.x - 40.0))
	_confirm.answered.connect(_on_confirm)
	add_child(_confirm)


func _on_confirm(leave: bool) -> void:
	_confirm.queue_free()
	_confirm = null
	_set_keys(true)
	if leave:
		_leave()
	elif _walk_word != null and _walk_word.is_inside_tree():
		_walk_word.grab_focus()


## Bar the screen's own keys while the confirm holds the question, so a Tab
## from "Stay" cannot land on a card behind the veil.
func _set_keys(on: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	for key: Button in _card_keys:
		key.focus_mode = mode if not _picked else Control.FOCUS_NONE
	for word: Button in [_skip_word, _walk_word]:
		if word != null:
			word.focus_mode = mode
