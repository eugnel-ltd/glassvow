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

	# The decision path through the real maps and the real commit: what a
	# Vigil records when a run ends where it ends.
	var content: ContentDB = ContentDB.load_full()
	_check(fails, MusicBus.combat_context("boss", 3, VigilState.blank()) == &"",
		"a fresh Vigil meets the boss for the first time")
	_check(fails, _boss_context_after(content, "death", 3, "boss") == &"return",
		"a loss to the Act IV boss makes the next meeting a return")
	_check(fails, _boss_context_after(content, "death", 3, "elite") == &"",
		"a death at the Act IV elite has not met the boss")
	_check(fails, _boss_context_after(content, "win", 2, "boss") == &"",
		"a win that ended after Act III never met the Act IV boss")
	var vigil: VigilState = VigilState.blank()
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


## The boss context after one run ends at the last node of `node_type` on the
## real map of act index `act`, committed through `VigilState.commit_run`.
static func _boss_context_after(content: ContentDB, outcome: String, act: int,
		node_type: String) -> StringName:
	var run: RunState = RunState.new_run(content, 65900 + act,
		"run-music-%s-%d-%s" % [outcome, act, node_type])
	run.act = act
	var map: WorldMap = WorldMap.act4(run, content) \
		if act == MusicBus.ACT4_INDEX else WorldMap.benchmark(run)
	var node: MapNode = null
	for candidate: MapNode in map.nodes:
		if candidate.type == node_type:
			node = candidate
	if node == null:
		return &"no-node"
	run.waystones_lit = node.row + 1
	var vigil: VigilState = VigilState.blank()
	if not vigil.commit_run(run, outcome, content):
		return &"no-commit"
	return MusicBus.combat_context("boss", MusicBus.ACT4_INDEX, vigil)
