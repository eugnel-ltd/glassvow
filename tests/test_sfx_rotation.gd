extends RefCounted
## The opening lane's six start-up cues: four resolve to one file each, two
## (`roomOpen`, `roomClose`) rotate through numbered variants chosen at random.

const SINGLE_CUES: Array[StringName] = [
	&"kindleCatch", &"glassTakesLight", &"paneRise", &"paneChoose",
]
const ROTATING_CUES: Dictionary[StringName, int] = {
	&"roomOpen": 4,
	&"roomClose": 3,
}
const DRAWS: int = 400


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("sfx_rotation: %s" % what)


static func run(fails: Array[String]) -> void:
	var bus: SfxBus = SfxBus.new()
	_single_cues(fails, bus)
	_rotations(fails, bus)
	_unknown_cue_is_not_rotated(fails, bus)
	bus.free()


static func _exists(stem: StringName) -> bool:
	return ResourceLoader.exists(SfxBus.DIR % stem)


static func _single_cues(fails: Array[String], bus: SfxBus) -> void:
	for id: StringName in SINGLE_CUES:
		_check(fails, bus.resolve(id) == id, "%s is not a single cue" % id)
		_check(fails, _exists(id), "%s.mp3 does not resolve" % id)


static func _rotations(fails: Array[String], bus: SfxBus) -> void:
	for id: StringName in ROTATING_CUES:
		var count: int = ROTATING_CUES[id]
		var variants: Array[StringName] = bus.variants_of(id)
		_check(fails, variants.size() == count,
			"%s lists %d variants, expected %d" % [id, variants.size(), count])
		for stem: StringName in variants:
			_check(fails, _exists(stem), "%s.mp3 does not resolve" % stem)
		_check(fails, not _exists(id),
			"%s.mp3 exists beside its variants and would shadow the rotation" % id)
		var seen: Dictionary[StringName, bool] = {}
		for _i: int in range(DRAWS):
			var stem: StringName = bus.resolve(id)
			_check(fails, variants.has(stem), "%s drew a stray stem %s" % [id, stem])
			seen[stem] = true
		_check(fails, seen.size() == count,
			"%s drew %d of its %d variants in %d plays" % [id, seen.size(), count, DRAWS])


## A cue that is not a rotation must never be renamed by the draw.
static func _unknown_cue_is_not_rotated(fails: Array[String], bus: SfxBus) -> void:
	_check(fails, bus.resolve(&"click") == &"click", "click was rotated")
	_check(fails, bus.variants_of(&"click") == [&"click"], "click lists variants")
