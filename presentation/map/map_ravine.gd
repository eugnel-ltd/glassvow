class_name MapRavine
extends RefCounted
## The two ravines that cut the map's ground across the journey axis (+X).
##
## `MapLandscape` draws the ground in three plates with a gap between them, and
## stands a waystone on a pier wherever it falls in or beside a gap. The fast
## layout asks the same question to keep waystones off the ravine, so both read
## it from here. The centre line uses a polynomial sine, not the engine's: it is
## the one place the layout needs a curve, and pure IEEE arithmetic gives every
## device the same answer (docs/map/production-layout.md).

## The journey-axis (X) coordinate of each ravine's centre line before the wobble.
const CUTS: Array[float] = [-20.5, 10.5]
## The ground ends this far either side of the centre line.
const HALF_WIDTH: float = 1.5
## A waystone this close to the bank of a ravine stands on a pier.
const PIER_MARGIN: float = 0.8
## How far the centre line wanders from its cut: the sum of the two sine amplitudes.
const WANDER: float = 1.7


## X of one ravine's centre line at lane coordinate `z`.
static func centre(cut: float, z: float) -> float:
	return cut + sine(z * 0.19) * 1.4 + sine(z * 0.61) * 0.3


## True when `x` is within `HALF_WIDTH + margin` of either centre line at `z`.
static func holds(x: float, z: float, margin: float = 0.0) -> bool:
	var reach: float = HALF_WIDTH + margin
	for cut: float in CUTS:
		if absf(x - cut) < reach + WANDER and absf(x - centre(cut, z)) < reach:
			return true
	return false


## Sine from a Taylor series on [-PI/2, PI/2] (error under 1e-11): addition,
## multiplication and `floorf` only, so the result is the same on every device.
static func sine(angle: float) -> float:
	var folded: float = angle - floorf(angle / TAU + 0.5) * TAU
	if folded > PI * 0.5:
		folded = PI - folded
	elif folded < -PI * 0.5:
		folded = -PI - folded
	var square: float = folded * folded
	return folded * (1.0 + square * (-1.0 / 6.0 + square * (1.0 / 120.0
		+ square * (-1.0 / 5040.0 + square * (1.0 / 362880.0
		+ square * (-1.0 / 39916800.0 + square * (1.0 / 6227020800.0
		+ square * (-1.0 / 1307674368000.0))))))))
