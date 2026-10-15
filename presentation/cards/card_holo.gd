class_name CardHolo
extends RefCounted
## THE CARD HOLOGRAM (#657; the owner's picks, 14 Oct 2026; the research and
## its stills: `holo-design.md` on the local research branch
## `research/cards-holo-2026-10-14`).
##
## A canvas_item shader worn as the material of a card's picture: the live
## card's stage render (CardView), a baked face (BakedCard) or a pile's top
## back (PileStack). It reads that picture and adds the hologram in card space,
## driven by one motion signal (HoloMotion). It never reads the screen and adds
## no pass, so it costs no backbuffer copy, and it lives on the canvas, so the
## card's 3D stage stays frozen while the device moves: the 3D surface recipe
## (CardSurface) is what the card is made of; this is how its foil answers the
## room's light.
##
## FRONTS BY TIER, one recipe each, every recipe its own shader with its own
## constants (docs/solutions/conventions/per-recipe-shader-knobs.md):
##   starter            bare, on purpose: the contrast is what makes the rest
##                      worth having
##   common             silver rim: one glint runs round the cut
##   uncommon           spectral frame: a spectrum in the frame band and the
##                      rule; the rules plate is left exactly as rendered
##   rare               cut glass: the art window a mosaic of dichroic shards
##   special            oil: curses and statuses, the finish that takes light
##                      away
## A rarity with no recipe here (a relic's `boss`, the undesigned `mythic`)
## wears none: those recipes land with the first card that needs one.
##
## BACKS: "lit panes" (back_panes.gdshader) for every back, each with its own
## knobs, tuned to its painting, in its `holo` entry in content/card-backs.json
## (`parse_back_knobs`). A back looks the same whatever the card's rarity, and
## its 3D recipe is a quiet shared stock, so two shimmering systems never stack
## on one back.

const FRONTS: Dictionary = {
	"rim": preload("res://presentation/cards/holo/front_common_rim.gdshader"),
	"frame": preload("res://presentation/cards/holo/front_uncommon_frame.gdshader"),
	"cut-glass": preload("res://presentation/cards/holo/front_rare_glass.gdshader"),
	"oil": preload("res://presentation/cards/holo/front_special_oil.gdshader"),
}
const BY_RARITY: Dictionary = {
	"common": "rim",
	"uncommon": "frame",
	"rare": "cut-glass",
	"special": "oil",
}
const BACK: String = "panes"
const BACK_SHADER: Shader = preload("res://presentation/cards/holo/back_panes.gdshader")
## The knobs a back's `holo` entry sets (back_knobs.gdshaderinc), by kind:
## a number, a whole number, an [x, y] point in card px or an [r, g, b] colour.
const BACK_KNOBS: Dictionary = {
	"band_mode": "int", "band_angle": "number", "centre": "point",
	"palette": "colour", "palette_mix": "number", "strength": "number",
	"scale": "number",
}
## The band modes: a linear stripe, rings from the centre, a sweep round it.
const BAND_MODES: int = 3


## The recipe a card wears, or "" for none: a back's panes when it carries
## knobs, else its rarity's.
static func recipe_of(data: Dictionary) -> String:
	if data.has("back"):
		var knobs_v: Variant = data.get("holo")
		if typeof(knobs_v) != TYPE_DICTIONARY:
			return ""
		var knobs: Dictionary = knobs_v
		return "" if knobs.is_empty() else BACK
	return str(BY_RARITY.get(str(data.get("rarity", "")), ""))


## A fresh material for the card `data` describes, or null when it wears none.
static func material_for(data: Dictionary) -> ShaderMaterial:
	var recipe: String = recipe_of(data)
	if recipe == "":
		return null
	if recipe == BACK:
		var knobs: Dictionary = data["holo"]
		return back_material(knobs)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FRONTS[recipe]
	return mat


## A back's lit panes on its own `knobs`, or null for none.
static func back_material(knobs: Dictionary) -> ShaderMaterial:
	if knobs.is_empty():
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BACK_SHADER
	for key: String in knobs:
		mat.set_shader_parameter(key, knobs[key])
	return mat


## Where the card's whole stage lies in the UV of a `crop`-texel picture cut
## `cut` texels in from each side of the stage and drawn past its edges over
## the stage's whole rect (CardView._Crop): the shader's `stage_uv`.
static func crop_uv(crop: Vector2, cut: float) -> Vector4:
	var whole: Vector2 = crop + Vector2(cut, cut) * 2.0
	return Vector4(-cut / crop.x, -cut / crop.y, whole.x / crop.x, whole.y / crop.y)


## A back's `holo` entry as shader values, or a String naming what is wrong.
## Every key must be a known knob of the right kind; a back sets the ones its
## painting needs and no others.
static func parse_back_knobs(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return "is not an object"
	var given: Dictionary = raw
	if given.is_empty():
		return "is empty"
	var out: Dictionary = {}
	for key_v: Variant in given:
		var key: String = str(key_v)
		if not BACK_KNOBS.has(key):
			return "has no knob '%s'" % key
		var value: Variant = _knob(str(BACK_KNOBS[key]), given[key_v])
		if value == null:
			return "%s is not a %s" % [key, BACK_KNOBS[key]]
		out[key] = value
	if out.has("band_mode"):
		var mode: int = out["band_mode"]
		if mode < 0 or mode >= BAND_MODES:
			return "band_mode is not between 0 and %d" % (BAND_MODES - 1)
	return out


static func _knob(kind: String, value: Variant) -> Variant:
	match kind:
		"number":
			return _number(value)
		"int":
			var n: Variant = _number(value)
			if n == null:
				return null
			var f: float = n
			return int(f) if f == roundf(f) else null
		"point", "colour":
			if typeof(value) != TYPE_ARRAY:
				return null
			var given: Array = value
			if given.size() != (2 if kind == "point" else 3):
				return null
			var nums: Array[float] = []
			for each: Variant in given:
				var n: Variant = _number(each)
				if n == null:
					return null
				var f: float = n
				nums.append(f)
			if kind == "point":
				return Vector2(nums[0], nums[1])
			return Color(nums[0], nums[1], nums[2])
	return null


## A JSON number as a float, or null.
static func _number(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		var whole: int = value
		return float(whole)
	if typeof(value) == TYPE_FLOAT:
		var real: float = value
		return real
	return null


## Wear `mat` over `picture`, its tilt driven every frame while `host` is
## visible. `own` returns the card's own lean (CardView.holo_lean), or is
## empty for a card that never tilts on its own. The driver is a child of
## `host`, so it goes with it.
static func wear(picture: CanvasItem, mat: ShaderMaterial, host: CanvasItem,
		own: Callable = Callable()) -> Lean:
	picture.material = mat
	var lean: Lean = Lean.new(mat, host, own)
	host.add_child(lean)
	return lean


## The driver: one per card wearing a hologram. It steps the shared motion
## signal only while its card shows, so with no card on screen the game polls
## no sensor (the OS keeps them running: HoloMotion); it writes the one uniform
## only when the value moved.
class Lean:
	extends Node
	var mat: ShaderMaterial
	var host: CanvasItem
	var own: Callable
	var _last: Vector2 = Vector2(INF, INF)

	func _init(material: ShaderMaterial, shown_by: CanvasItem, own_lean: Callable) -> void:
		mat = material
		host = shown_by
		own = own_lean

	func _process(delta: float) -> void:
		if not host.is_visible_in_tree():
			return
		var ambient: Vector2 = HoloMotion.ambient(get_viewport(), delta)
		var mine: Vector2 = own.call() if own.is_valid() else Vector2.ZERO
		var t: Vector2 = HoloMotion.lean_of(ambient, mine, HoloMotion.still())
		if t != _last:
			_last = t
			mat.set_shader_parameter("tilt", t)
