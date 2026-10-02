class_name LeadlightChoice
extends HBoxContainer
## A segmented glass choice: one lit pane among several, in one lead strip.

signal chosen(index: int)

var _buttons: Array[LeadlightPane] = []
var _group: ButtonGroup = ButtonGroup.new()


func _init(labels: PackedStringArray, selected: int = 0,
		stage_shape: StringName = StageShape.IDENTITY) -> void:
	add_theme_constant_override("separation", 0)
	for i: int in range(labels.size()):
		var pane: LeadlightPane = LeadlightPane.new(labels[i], stage_shape,
			LeadlightGlassBox.Shape.RECT)
		pane.toggle_mode = true
		pane.button_group = _group
		pane.set_pressed_no_signal(i == selected)
		pane.lit = false
		pane.pressed.connect(func() -> void: chosen.emit(i))
		_buttons.append(pane)
		add_child(pane)


func buttons() -> Array[LeadlightPane]:
	return _buttons


func selected() -> int:
	for i: int in range(_buttons.size()):
		if _buttons[i].button_pressed:
			return i
	return -1
