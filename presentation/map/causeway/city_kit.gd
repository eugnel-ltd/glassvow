extends RefCounted
## What Act II's land draws with, held for every build (#660 II.3): the
## masonry atlas (`tools/map_atelier/journey/masonry/build_masonry.py`) on the
## masonry's materials, and the water's. Readied a step at a time on the main
## thread before a land is built on a worker, its two textures taken from the
## loader's threads one at a time (`ImpostorAtlas.Take`), as Act I's stone is
## (`LandStone.prepare_step`); let go once Act II's map is never shown again
## (`release`).
const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")
const MASONRY: Shader = preload("res://presentation/map/causeway/masonry.gdshader")
const WATER: Shader = preload("res://presentation/map/causeway/city_water.gdshader")
const ALBEDO_PATH: String = "res://assets/art/map-journey/masonry/masonry-albedo.png"
const NORMAL_PATH: String = "res://assets/art/map-journey/masonry/masonry-normal.png"
## The materials' parts: the masonry under a deck and its walls (`body`), its
## coping, treads, piers' caps and the lantern posts (`trim`), the decks'
## paving (`deck`).
const PARTS: PackedStringArray = ["body", "trim", "deck"]
## Each part's tint over the atlas (sRGB) and whether it is paving (the deck's
## own UV) or ashlar (projected on the world).
const TINTS: Dictionary = {"body": Color(1.25, 1.28, 1.35), "trim": Color(1.45, 1.45, 1.5),
	"deck": Color(1.2, 1.2, 1.22)}

static var _take: Atlas.Take = null
static var _albedo: Texture2D = null
static var _normal: Texture2D = null
## Whether the atlas cannot load: the land is drawn in flat masonry then.
static var failed: bool = false


## Readies the atlas a step at a time and answers whether nothing is left to
## wait for (ready, or unable to load). `wait`ing (a map opening now), it
## waits for the loader.
static func prepare_step(wait: bool = false) -> bool:
	if ready() or failed:
		return true
	if _take == null:
		_take = Atlas.Take.new(PackedStringArray([ALBEDO_PATH, NORMAL_PATH]))
		_take.request()
	if not _take.step(wait):
		return false
	if _take.failed:
		failed = true
		push_error("Act II masonry: cannot load the masonry atlas; the causeways are drawn flat")
	else:
		_albedo = _take.textures[ALBEDO_PATH]
		_normal = _take.textures[NORMAL_PATH]
	_take = null
	return true


static func ready() -> bool:
	return _albedo != null and _normal != null


## Lets the atlas go: Act II's map is not shown again (`MapJourneyProfile`'s
## release on an act change). A later Act II readies it again.
static func release() -> void:
	_take = null
	_albedo = null
	_normal = null
	failed = false


## A new material for masonry `part` (`PARTS`), reading the land's light mask
## (`city_mask.gd`); flat masonry in `fallback` where the atlas is not ready.
static func masonry(part: String, fallback: Color) -> Material:
	if not ready():
		var flat: StandardMaterial3D = StandardMaterial3D.new()
		flat.albedo_color = fallback
		flat.roughness = .95
		return flat
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = MASONRY
	material.set_shader_parameter("albedo_atlas", _albedo)
	material.set_shader_parameter("normal_atlas", _normal)
	material.set_shader_parameter("paving", part == "deck")
	var tint: Color = TINTS[part]
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return material


## A new material for the still water.
static func water() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER
	return material
