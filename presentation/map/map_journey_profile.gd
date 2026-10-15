class_name MapJourneyProfile
extends RefCounted
## Which acts are drawn as a journey land, and how: the one per-act table the
## map reads instead of asking whether the act is the first. A row says that
## its act draws a journey land, of what land class, under what light, at what
## gate and threshold, and whether the title's prefetch warms it. An act with
## no row keeps the painted landscape, its own gate and no threshold.
##
## Acts I and II are the rows players reach (Act II since #660 II.3). Another
## act gains the journey land by gaining a row here (and the land's own
## geometry), never by a branch elsewhere; until players may see it, its row
## stands behind `DEV_FLAG`.

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


## The act the floor's warm-ups and bakes stand in: the one act with a row
## players reach (a dev row's land has no floor to bake).
const FIRST_ACT: int = 0
const SECOND_ACT: int = 1
## The command-line flag that adds a dev row (`enable_dev`): an act NUMBER
## counted from 1, as `--act=` (`ActFlag`). Naming an act players already
## reach as a journey land (`--journey-act=2`, Act II's causeways since II.3)
## changes nothing.
const DEV_FLAG: String = "--journey-act="

## The rows by act index; a test swaps it and restores `default_rows()`.
static var rows: Dictionary[int, Row] = default_rows()


static func default_rows() -> Dictionary[int, Row]:
	var table: Dictionary[int, Row] = {}
	table[FIRST_ACT] = Row.make(MapJourneyLandscape, MapJourneyLandscape.light,
		MapLandscapeAssets.GATES[FIRST_ACT], "vigil", true)
	# Act II's causeways end at the act's own gate, open on no threshold, and
	# are built ahead as Act I's are: under the title for a restored run, and
	# under Act I's boss rewards (`NextActMap`).
	table[SECOND_ACT] = Row.make(MapCausewayLandscape, MapCausewayLandscape.light,
		MapLandscapeAssets.GATES[SECOND_ACT], "", true)
	return table


## The rows only `DEV_FLAG` adds: lands not yet for players (none since Act
## II's went to players).
static func dev_rows() -> Dictionary[int, Row]:
	var table: Dictionary[int, Row] = {}
	return table


## Adds the dev row `value` (the flag's act number) names. Empty when it did,
## otherwise the message to print: a wrong act is refused, never clamped.
static func enable_dev(value: String) -> String:
	var parsed: Dictionary = ActFlag.parse(value)
	if parsed.has("error"):
		return DEV_FLAG + " " + str(parsed["error"])
	var act: int = parsed["act_index"]
	if rows.has(act):
		return ""
	var dev: Dictionary[int, Row] = dev_rows()
	if not dev.has(act):
		return "%s has no dev journey land for Act %d" % [DEV_FLAG, ActFlag.number_of(act)]
	rows[act] = dev[act]
	return ""


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


static var _pending_release: Array[GDScript] = []


## Lets go of what `act`'s journey land builds with after its workers finish.
## Nothing for an act with no row.
static func release_kit(act: int) -> void:
	if rows.has(act) and not _pending_release.has(rows[act].land):
		_pending_release.append(rows[act].land)
	reap_kits()


## Main-thread cleanup: an abandoned worker can still read its kit until its
## current stage ends. Never join it under a visible frame.
static func reap_kits() -> void:
	for land_class: GDScript in _pending_release.duplicate():
		var job: MapJourneyPrefetch = MapJourneyPrefetch._current
		if job != null and land_class == MapJourneyProfile.land_class(job._act):
			continue
		var used: bool = false
		for land: MapJourneyLandscape in MapScene._abandoned:
			if land.get_script() == land_class and land.busy():
				used = true
				break
		if not used:
			land_class.release_kit()
			_pending_release.erase(land_class)


## Lets go of what every journey land but `keep`'s builds with: no journey
## land but that act's is built any more (`MapJourneyPrefetch`; -1 keeps none).
static func release_kits(keep: int = -1) -> void:
	var kept: GDScript = rows[keep].land if rows.has(keep) else null
	_pending_release.erase(kept)
	for act: int in rows:
		if rows[act].land != kept:
			release_kit(act)
