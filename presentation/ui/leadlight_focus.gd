class_name LeadlightFocus
extends RefCounted
## Focus is for the keyboard and the pad (docs/design/2026-10-03-title-rooms
## §2.10, §6). Godot 4.7 gives a tapped button hidden focus, but any code-path
## `grab_focus()` with no argument shows it, even on a control that already
## held it hidden: that is how a touch player came to see a gold ellipse round
## the title's lantern. Every code path that places focus goes through `give`,
## which shows it only when the last input was a key or a pad.
##
## Main notes every input event (`note`); a screen that consumes a key in its
## own `_input` notes it first, since Main's `_input` will not see it.

## Whether the last meaningful input was a key or a pad (else a pointer).
static var keyed: bool = false


## Read the modality from one input event. A bare modifier or a Cmd, Ctrl or
## Alt chord (a screenshot or system shortcut) and pointer motion say nothing.
static func note(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed() and is_navigation(event as InputEventKey):
			keyed = true
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			keyed = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			keyed = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch \
			or event is InputEventScreenDrag:
		keyed = false


## A key a keyboard player moves or acts with: not Shift, Ctrl, Alt, Meta or
## Caps Lock alone, and not held with Cmd, Ctrl or Alt (Shift+Tab still counts).
static func is_navigation(event: InputEventKey) -> bool:
	var key: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	if key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
		return false
	return not (event.meta_pressed or event.ctrl_pressed or event.alt_pressed)


## Put focus on `control`, shown only to a keyboard or pad player, or always
## with `force_visible` (a key that asked for it).
static func give(control: Control, force_visible: bool = false) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.grab_focus(not (keyed or force_visible))


## `give` once the frame's deferred calls run, for a control just built. The
## control is held weakly: a screen freed before then (a language rebuild, a
## room closed at once, a test tearing down) is skipped without an error.
static func give_deferred(control: Control, force_visible: bool = false) -> void:
	_give_held.call_deferred(weakref(control), force_visible)


static func _give_held(held: WeakRef, force_visible: bool) -> void:
	var held_object: Object = held.get_ref()
	var control: Control = held_object as Control
	if control != null:
		give(control, force_visible)
