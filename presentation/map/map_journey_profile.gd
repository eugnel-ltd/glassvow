class_name MapJourneyProfile
extends RefCounted
## Which acts are drawn as a journey land, and how: the one per-act table the
## map reads instead of asking whether the act is the first. A row says that
## its act draws a journey land, of what land class, under what light, at what
## gate and threshold, and whether the title's prefetch warms it. An act with
## no row keeps the painted landscape, its own gate and no threshold.
##
## Act I is the only row. Another act gains the journey land by gaining a row
## here (and the land's own geometry), never by a branch elsewhere.

## One act's journey. `land` is the land class (`MapJourneyLandscape`, or a
## class that extends it); `light` is called as `light(key, environment)` and
## sets the act's key light and environment; `gate` and `threshold` are the
## ids of the node its road ends at and of its opening threshold; `warm` is
## whether the title's prefetch warms it.
class Row extends RefCounted:
	var land: GDScript
	var light: Callable
	var gate: String
	var threshold: String
	var warm: bool

	static func make(land_class: GDScript, light_function: Callable, gate_id: String,
			threshold_id: String, warms: bool) -> Row:
		var row: Row = Row.new()
		row.land = land_class
		row.light = light_function
		row.gate = gate_id
		row.threshold = threshold_id
		row.warm = warms
		return row


## The act the floor's warm-ups and bakes stand in: the one act with a row.
const FIRST_ACT: int = 0

## The rows by act index; a test swaps it and restores `default_rows()`.
static var rows: Dictionary[int, Row] = default_rows()


static func default_rows() -> Dictionary[int, Row]:
	var table: Dictionary[int, Row] = {}
	table[FIRST_ACT] = Row.make(MapJourneyLandscape, MapJourneyLandscape.light,
		MapLandscapeAssets.GATES[FIRST_ACT], "vigil", true)
	return table


## Whether `act` has a journey row.
static func has(act: int) -> bool:
	return rows.has(act)


## The land class a journey act draws (`has` first).
static func land_class(act: int) -> GDScript:
	return rows[act].land


## Sets `key` and `environment` to the journey light of `act` (`has` first).
static func light(act: int, key: DirectionalLight3D, environment: Environment) -> void:
	rows[act].light.call(key, environment)


## The id of the node an act's road ends at: the journey row's, else the
## painted act's gate.
static func gate_id(act: int) -> String:
	return rows[act].gate if rows.has(act) else MapLandscapeAssets.GATES[act]


## The id of the act's opening threshold; empty for an act without one.
static func threshold_id(act: int) -> String:
	return rows[act].threshold if rows.has(act) else ""


## Whether the title's prefetch warms `act`'s journey land.
static func warms(act: int) -> bool:
	return rows.has(act) and rows[act].warm
