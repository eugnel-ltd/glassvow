extends RefCounted
## Act II's causeway proportions and placeholder materials: the archive's
## drowned-city preset (`stone_bridge/presets.gd`, 7d64678b), revived on the
## fast layout. Distances are world metres.
##
## The archive drew its decks 4.8 m up and its water at 1.18 m. Here the deck
## datum is the record's own ground (y = 0) and the one still water level stands
## `FREEBOARD` under it, as the approved painting has it ("about one metre below
## the walking deck"). Every height the archive wrote in absolute metres below
## its water (the pier feet, the foundations, the arch springing) is kept at the
## same distance from the water here, so the masonry keeps its proportions.

## The walking deck's datum: the record's ground.
const DATUM: float = 0.0
## How far the still water lies under the deck datum (the archive's 1.18 m).
const FREEBOARD: float = 1.18
const WATER: float = DATUM - FREEBOARD
## The archive's masonry and paving colours (placeholders until II.3's atlas).
const STONE: Color = Color("44536b")
const TRIM: Color = Color("526277")
const PAVING: Color = Color("555f70")


static func drowned_city() -> Dictionary:
	return {"arch_spacing": 8.0, "pier_width": 1.3, "crown_thickness": .46,
		"crossing_arch_rise": .85, "parapet_height": .83, "parapet_width": .20,
		"tread_width": 1.60, "sample_spacing": .8,
		"water_level": WATER,
		# The archive's absolute heights, held at their distance from its water.
		"foundation_level": WATER - 1.63, "pier_foot": WATER - 1.58,
		"spring_cap": WATER + .17, "arch_floor": WATER - .18, "bed": WATER - 3.18,
		"stone_colour": STONE, "trim_colour": TRIM, "paving_colour": PAVING}


## Flat placeholder materials in the archive's colours: the body below the
## deck, the trim (coping, treads, piers' caps) and the deck's paving.
static func materials(settings: Dictionary) -> Dictionary:
	var stone: Color = settings["stone_colour"]
	var coping: Color = settings["trim_colour"]
	var paving: Color = settings["paving_colour"]
	var body: StandardMaterial3D = _stone(stone)
	var trim: StandardMaterial3D = _stone(coping)
	trim.metallic_specular = .20
	var deck: StandardMaterial3D = _stone(paving)
	return {"body": body, "trim": trim, "deck": deck}


static func _stone(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = .95
	return material
