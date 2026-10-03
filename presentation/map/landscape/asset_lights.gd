extends RefCounted
## A trial gateway's separate lamp pair. The gateway's light itself is the
## land's (`lamps.gd`): flames on `Kit.LAMP_ANCHORS`, pools in the ground, and
## the real lights that follow the pilgrim.
static func attach_trial(model: Node3D) -> bool:
	var source: PackedScene = load("res://assets/art/map-journey/lamp-pair.glb") as PackedScene
	if source == null:
		return false
	model.add_child(source.instantiate())
	return true
