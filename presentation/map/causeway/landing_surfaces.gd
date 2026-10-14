extends "res://presentation/map/causeway/smooth_surfaces.gd"
## The raised decks' surface: where a raised deck meets the ordinary deck at
## exactly its height (a shared landing), the ordinary deck owns the ground, so
## each landing is drawn once. Heights are never warped. The archive's
## `common/landing_surfaces.gd`.
var lower: RefCounted
var pads: PackedVector2Array = []


func field(at: Vector2) -> Dictionary:
	var result: Dictionary = super.field(at)
	if result["distance"] == INF:
		return result
	var landing: Dictionary = lower.field(at)
	var height: float = result["height"]
	var landing_height: float = landing["height"]
	if absf(height - landing_height) > .00001:
		return result
	var distance: float = result["distance"]
	var landing_distance: float = landing["distance"]
	result["distance"] = maxf(distance, -landing_distance)
	result["delegated"] = distance <= 0 and landing_distance <= 0
	return result
