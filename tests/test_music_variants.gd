extends RefCounted
## The same-scene alternates (#659): the default holds everywhere but the two
## named scenarios, the elite draw stays inside its allowed set, the boss
## switches on a return, and every named stem ships and imports.

const ELITE_SET: Array[String] = ["act4-combat-a", "act4-combat-b", "act4-combat-d"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("test_music_variants: %s" % what)


static func run(fails: Array[String]) -> void:
	var bus: MusicBus = MusicBus.new()
	bus._rng.seed = 659

	# Defaults: no context, and unrelated cues, answer with the FILES stem.
	_check(fails, bus.resolve(&"act4Combat") == "act4-combat", "act4Combat default is C")
	_check(fails, bus.resolve(&"act4Boss") == "act4-boss", "act4Boss default is A")
	_check(fails, bus.resolve(&"act1Combat", &"elite") == "act1-combat",
		"a cue with no variant entry keeps its default under any context")
	_check(fails, bus.resolve(&"act4Combat", &"unknown") == "act4-combat",
		"an unlisted context falls back to the default")

	# Elite: only A/B/D, and over many draws all three appear, never C.
	var seen: Dictionary = {}
	for i: int in range(200):
		var stem: String = bus.resolve(&"act4Combat", &"elite")
		_check(fails, ELITE_SET.has(stem), "elite draw '%s' is outside A/B/D" % stem)
		seen[stem] = true
	_check(fails, seen.size() == ELITE_SET.size(), "elite draw reaches A, B and D")

	# Boss: return is B, first meeting is A.
	_check(fails, bus.resolve(&"act4Boss", &"return") == "act4-boss-b", "boss return is B")

	# The decision path: context from the real Vigil data.
	var vigil: VigilState = VigilState.blank()
	var boss_row: int = MusicBus.ACT4_INDEX * MusicBus.WAYSTONES_PER_ACT + WorldMap.ROWS
	_check(fails, MusicBus.combat_context("boss", 3, vigil) == &"",
		"a fresh Vigil meets the boss for the first time")
	vigil.deeds["bestWaystone"] = boss_row - 1
	_check(fails, MusicBus.combat_context("boss", 3, vigil) == &"",
		"reaching the node before the boss is not meeting it")
	vigil.deeds["bestWaystone"] = boss_row
	_check(fails, MusicBus.combat_context("boss", 3, vigil) == &"return",
		"having reached the boss node before is a return")
	vigil.deeds["bestWaystone"] = 0
	vigil.deeds["wins"] = 1
	_check(fails, MusicBus.combat_context("boss", 3, vigil) == &"return",
		"a Vigil that has won has met the boss")
	_check(fails, MusicBus.combat_context("boss", 3, null) == &"", "no Vigil, no return")
	_check(fails, MusicBus.combat_context("boss", 2, vigil) == &"",
		"only the Act IV boss varies")
	_check(fails, MusicBus.combat_context("elite", 3, vigil) == &"elite"
		and MusicBus.combat_context("elite", 1, vigil) == &""
		and MusicBus.combat_context("normal", 3, vigil) == &"",
		"only Act IV elites draw alternates")

	# Every variant path exists, imports, and is a loadable stream.
	for cue: StringName in [&"act4Combat", &"act4Boss"]:
		for stem: String in bus.variants_of(cue):
			var path: String = MusicBus.DIR % stem
			_check(fails, ResourceLoader.exists(path), "%s exists" % path)
			_check(fails, FileAccess.file_exists(path + ".import"), "%s has an import sidecar" % path)
			_check(fails, load(path) is AudioStreamMP3, "%s loads as AudioStreamMP3" % path)
	_check(fails, bus.variants_of(&"act4Combat").size() == 4
		and bus.variants_of(&"act4Boss").size() == 2, "variant lists are C+A/B/D and A+B")
	bus.free()
