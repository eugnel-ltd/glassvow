class_name MapChartingVeil
extends Control
## Stands in for the world map while its layout compiles off the main thread.
## Drawn on the first frame after the route, so the OS never sees a blocked
## main thread (iOS terminates an app whose main thread stalls at launch).
## A pulsing lantern ember says the wait is live. Main swaps in the map when
## the compile lands.

const LABEL_PT: int = 22
const EMBER_PX: int = 28
const PULSE_S: float = 0.9

var _label: Label = null
var _ember: TextureRect = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground: ColorRect = ColorRect.new()
	ground.color = GlassStyle.NIGHT_BOT
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_ember = TextureRect.new()
	_ember.texture = GlassStyle.disc(GlassStyle.EMBER, 1.0, EMBER_PX)
	_ember.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_ember.custom_minimum_size = Vector2(EMBER_PX, EMBER_PX)
	_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_ember)
	_label = Label.new()
	_label.text = Locale.active.t("ui.pilgrimage.charting")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", LABEL_PT)
	_label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_label)


func _ready() -> void:
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_ember, "modulate:a", 0.25, PULSE_S) \
		.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_ember, "modulate:a", 1.0, PULSE_S) \
		.set_trans(Tween.TRANS_SINE)
