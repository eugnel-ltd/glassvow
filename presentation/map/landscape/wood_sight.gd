extends RefCounted
## What Act I's woodland must leave in sight on the journey camera's picture
## plane (R3.1, issue #660; `MapJourneyCameraContract.projected_plane`: x
## across, y down the screen). One grid per land: per fine and coarse cell, the
## least depth (toward the camera) of what it protects, INF where nothing. A
## card fits where everything protected under its silhouette lies in front of
## it, so a crown may stand behind a road, a stone or the water, never in front
## of them.
##
## The planting (`wood_planting.gd`) says what is protected; this holds the
## grid and answers the fit test in a few array reads per cell.

const Atlas = preload("res://presentation/map/landscape/impostor_atlas.gd")

## Fine cells (metres), and fine cells per coarse cell.
const FINE: float = 0.25
const COARSE: int = 4
## How far behind protected content a card must stand (metres of depth).
const DEPTH_MARGIN: float = 0.15

## Toward the journey camera (a depth is a point's dot with it).
var toward: Vector3
var _pitch_sin: float
var _pitch_cos: float
var _origin: Vector2
var _fine_columns: int = 0
var _fine_rows: int = 0
var _fine: PackedFloat32Array = []
var _coarse_columns: int = 0
var _coarse: PackedFloat32Array = []


## An empty grid over the picture of `bounds`, from the tallest thing
## protected above the far edge to the near edge.
func begin(bounds: Rect2) -> void:
	var pitch: float = deg_to_rad(MapJourneyCameraContract.PITCH)
	_pitch_sin = sin(pitch)
	_pitch_cos = cos(pitch)
	toward = Vector3(0, _pitch_sin, _pitch_cos)
	_origin = Vector2(bounds.position.x, bounds.position.y * _pitch_sin - 8.0)
	_fine_columns = ceili(bounds.size.x / FINE) + 1
	_fine_rows = ceili((bounds.size.y * _pitch_sin + 10.0) / FINE) + 1
	_fine.resize(_fine_columns * _fine_rows)
	_fine.fill(INF)
	_coarse_columns = ceili(float(_fine_columns) / COARSE)
	_coarse.resize(_coarse_columns * ceili(float(_fine_rows) / COARSE))
	_coarse.fill(INF)


## A point's place on the picture plane.
func plane(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z * _pitch_sin - point.y * _pitch_cos)


## How deep a point stands toward the camera.
func depth(point: Vector3) -> float:
	return point.dot(toward)


## Protects the cells under `rect` down to `depth`.
func protect_rect(rect: Rect2, depth_value: float) -> void:
	var c0: int = maxi(0, floori((rect.position.x - _origin.x) / FINE))
	var c1: int = mini(_fine_columns - 1, floori((rect.end.x - _origin.x) / FINE))
	var r0: int = maxi(0, floori((rect.position.y - _origin.y) / FINE))
	var r1: int = mini(_fine_rows - 1, floori((rect.end.y - _origin.y) / FINE))
	for row: int in range(r0, r1 + 1):
		for column: int in range(c0, c1 + 1):
			var index: int = row * _fine_columns + column
			if depth_value < _fine[index]:
				_fine[index] = depth_value
				var coarse: int = (row / COARSE) * _coarse_columns + column / COARSE
				_coarse[coarse] = minf(_coarse[coarse], depth_value)


## Whether a card of `tile` for a plant at `base`, at `scale_value`, hides
## nothing protected: every protected cell under its silhouette lies in front
## of it.
func fits(tile: int, base: Vector3, scale_value: float) -> bool:
	# `Atlas.rect`, with the camera's pitch worked out once.
	var rect: Rect2 = Rect2(plane(base) + Atlas.low[tile] * scale_value, Atlas.size[tile] * scale_value)
	var limit: float = base.dot(toward) + Atlas.shifts[tile] * scale_value + DEPTH_MARGIN
	var coarse_size: float = FINE * COARSE
	var c0: int = maxi(0, floori((rect.position.x - _origin.x) / coarse_size))
	var c1: int = mini(_coarse_columns - 1, floori((rect.end.x - _origin.x) / coarse_size))
	var r0: int = maxi(0, floori((rect.position.y - _origin.y) / coarse_size))
	var r1: int = mini(_coarse.size() / _coarse_columns - 1, floori((rect.end.y - _origin.y) / coarse_size))
	for row: int in range(r0, r1 + 1):
		for column: int in range(c0, c1 + 1):
			if _coarse[row * _coarse_columns + column] >= limit:
				continue
			if not _fits_cell(tile, rect, limit, column, row):
				return false
	return true


## The fine cells of one coarse cell, under the card's silhouette: a cell is
## under it where any of the silhouette's rows across the cell's height
## covers the cell (a small card's rows are finer than the grid).
func _fits_cell(tile: int, rect: Rect2, limit: float, coarse_column: int, coarse_row: int) -> bool:
	var rows: PackedVector2Array = Atlas.spans[tile]
	var row_height: float = rect.size.y / rows.size()
	var pad: float = FINE * 0.5 / rect.size.x
	for fy: int in range(coarse_row * COARSE, mini((coarse_row + 1) * COARSE, _fine_rows)):
		var y: float = _origin.y + fy * FINE - rect.position.y
		var first: int = maxi(0, floori(y / row_height))
		var last: int = mini(rows.size() - 1, floori((y + FINE) / row_height))
		if first > last:
			continue
		var span: Vector2 = Vector2(INF, -INF)
		for band: int in range(first, last + 1):
			if rows[band].x <= rows[band].y:
				span = Vector2(minf(span.x, rows[band].x), maxf(span.y, rows[band].y))
		if span.x > span.y:
			continue
		for fx: int in range(coarse_column * COARSE, mini((coarse_column + 1) * COARSE, _fine_columns)):
			if _fine[fy * _fine_columns + fx] >= limit:
				continue
			var x: float = (_origin.x + (fx + 0.5) * FINE - rect.position.x) / rect.size.x
			if x >= span.x - pad and x <= span.y + pad:
				return false
	return true
