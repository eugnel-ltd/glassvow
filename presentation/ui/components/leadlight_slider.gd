class_name LeadlightSlider
extends HSlider
## A 0–100 slider on the canonical Theme's gold track and lantern disc, at the
## touch floor. Kept as a type so every screen builds the same one.


func _init(value_now: float = 0.0) -> void:
	min_value = 0.0
	max_value = 100.0
	step = 1.0
	value = value_now
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(160.0, RunStyle.hit_floor(24.0))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("focus", LeadlightGlassBox.make(
		LeadlightGlassBox.Shape.RECT, "focus", false, 0.0))
