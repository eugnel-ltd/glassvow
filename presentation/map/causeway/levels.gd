extends "res://presentation/map/landscape/landform.gd"
## The heights Act II's ordinary decks are graded to: the archive's terrace
## grading (`common/terrace_levels.gd`), which keeps the proven graph grading
## and drops Act I's river incision, on the deck datum instead of the archive's
## 4.8 m upland. Two things rise or fall from the datum:
##
## - **High bridges.** Where a road crosses one of the layout's two ravines
##   (`MapRavine`), now a deep channel in the water, its deck rises `RAVINE_RISE`
##   over the channel; the road grading (`_grade_roads`) keeps each approach to
##   a usable incline, which the flights then turn into steps.
## - **Bridgeheads and passes.** Where a raised road crosses an ordinary one,
##   the raised road's two landings stand `BRIDGEHEAD` over the datum (the
##   ordinary decks step up to them) and the ordinary deck under it dips
##   `PASS_DEPTH`, which keeps it the archive's 0.58 m dry margin above the
##   water. Between them the crossing keeps the archive's walking body (2.12 m)
##   clear under the raised arch: the raised roads of the fast layout are short
##   (7 to 11 m), and the water allows the ordinary deck no deeper pass.
const Presets = preload("res://presentation/map/causeway/presets.gd")
const RAVINE_RISE: float = 1.4
## The crown is full height this far either side of a ravine's centre line (the
## ravine's half width and a little more), and falls to the datum by
## `RAVINE_SHOULDER` beyond.
const RAVINE_CROWN: float = MapRavine.HALF_WIDTH + .6
const RAVINE_SHOULDER: float = 3.4
const PASS_DEPTH: float = .6
const BRIDGEHEAD: float = 1.4
## Ordinary roads fall from a bridgehead at a flight's grade (the woodland's
## 0.27 would leave a short raised road too little room to clear them).
const PAD_GRADE: float = .5
## A bridgehead's landing is level this far round its pad (every road leaving
## it, the raised one included, so the raised road has mostly left the other
## decks before it climbs), and falls to the datum by `HEAD_SHOULDER` beyond.
const HEAD_LANDING: float = 1.2
const HEAD_SHOULDER: float = 3.5


func _init() -> void:
	pass_depth = PASS_DEPTH
	pad_landing = HEAD_LANDING
	pad_grade = PAD_GRADE


## The ordinary deck before grading: the datum, crowned over each ravine and
## raised at each bridgehead.
func upland(x: float, z: float) -> float:
	var head: float = 0.0
	for pad: Vector2 in abutments:
		head = maxf(head, 1.0 - smoothstep(HEAD_LANDING, HEAD_SHOULDER, Vector2(x, z).distance_to(pad)))
	return deck_base(x, z) + BRIDGEHEAD * head


## The datum, crowned over each ravine: what a raised road climbs from, above
## its bridgeheads.
func deck_base(x: float, z: float) -> float:
	var crown: float = 0.0
	for cut: float in MapRavine.CUTS:
		if absf(x - cut) > RAVINE_CROWN + RAVINE_SHOULDER + MapRavine.WANDER:
			continue
		var across: float = absf(x - MapRavine.centre(cut, z))
		crown = maxf(crown, 1.0 - smoothstep(RAVINE_CROWN, RAVINE_CROWN + RAVINE_SHOULDER, across))
	return Presets.DATUM + RAVINE_RISE * crown


func natural_height(x: float, z: float) -> float:
	return upland(x, z) - cut_depth(x, z)


## The graded ordinary deck at (x, z): near a road, its own graded segments
## dominate neighbouring branches, so a bridgehead keeps its height without a
## radial bump; away from every road, the natural height.
func height(x: float, z: float) -> float:
	var at: Vector2 = Vector2(x, z)
	var total: float = 0
	var weight_sum: float = 0
	for segment: Array in ground_cells.get(Vector2i(floori(x / 4), floori(z / 4)), []):
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(at, a, b)
		var distance: float = at.distance_to(closest)
		var t: float = clampf((closest - a).dot(b - a) / maxf(.000001, a.distance_squared_to(b)), 0, 1)
		var weight: float = exp(-distance * distance / .4) * a.distance_to(b) / maxf(.000001, distance * distance)
		var ha: float = segment[2]
		var hb: float = segment[3]
		total += lerpf(ha, hb, t) * weight
		weight_sum += weight
	return total / weight_sum if weight_sum > .000001 else natural_height(x, z)
