extends RefCounted
## #543: deed rewards speak the existing localised card/relic name. The
## terminal fold keeps stable unlock IDs and persists the same Dawn titles.

const Diff: GDScript = preload("res://tests/support/diff.gd")
const RUN_PATH: String = "user://test_dawn_reward_names_run_v2.json"
const VIGIL_PATH: String = "user://test_dawn_reward_names_vigil_v2.json"
const REWARD_IDS: Array[String] = [
	"card:flawlessForm", "card:quakeblow", "card:resonantLance", "relic:prismCharm",
]
const NAMES: Dictionary = {
	"en": ["Quakeblow", "Resonant Lance", "Flawless Form", "Prism Charm"],
	"zh-Hant": ["震地擊", "共鳴長槍", "無瑕之形", "稜鏡護符"],
}


class ProbeMain extends Main:
	var dawn_shown: int = 0

	func _show_dawn() -> void:
		dawn_shown += 1


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("dawn_reward_names: %s" % what)


static func run(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		var content: ContentDB = ContentDB.load_full()
		Locale.active.hydrate_content(content)
		_all_reward_names(content, fails)
		_winning_deeds(content, fails)
		Locale.active.restore_content()
	Locale.active = previous
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)


static func _all_reward_names(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	for deed: Dictionary in content.deeds.values():
		for unlock: String in deed.get("unlocks", []):
			var rows: Dictionary = {}
			var id: String = ""
			if unlock.begins_with("card:"):
				rows = content.cards
				id = unlock.trim_prefix("card:")
			elif unlock.begins_with("relic:"):
				rows = content.relics
				id = unlock.trim_prefix("relic:")
			else:
				continue
			var expected: String = str(rows[id]["name"])
			_check(fails, main._unlock_dawn_copy(unlock) == expected,
				"%s %s should display %s, got %s" % [Locale.active.code,
					unlock, expected, main._unlock_dawn_copy(unlock)])
	for id: String in ["lamplighter", "phials", "omens", "emberglass", "act4"]:
		_check(fails, main._unlock_dawn_copy(id) == Locale.active.t("ui.dawn.unlock.%s" % id),
			"existing %s unlock sentence changed" % id)
	for id: String in ["poolWave2", "poolWave3", "poolFull"]:
		_check(fails, main._unlock_dawn_copy(id) == Locale.active.t("ui.dawn.unlock.pool"),
			"existing %s pool sentence changed" % id)
	for unknown: String in ["futureUnlock", "card:unknownReward", "relic:unknownReward", "card:"]:
		_check(fails, main._unlock_dawn_copy(unknown) == unknown.capitalize(),
			"unknown %s lost its existing safe fallback" % unknown)
	main.free()


static func _winning_deeds(content: ContentDB, fails: Array[String]) -> void:
	TestProfile.wipe(RUN_PATH, VIGIL_PATH)
	var main: ProbeMain = ProbeMain.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main.content = content
	var run: RunState = RunState.new_run(content, 54327, "run-dawn-reward-names", {
		"quests": main._vigil.quests,
	})
	run.stats["shatters"] = 15
	run.stats["perfects"] = 3
	run.pending_run_end = {"outcome": "win", "bequestAnswered": true}
	main.game = GlassvowGame.new(content, run)
	main._map = WorldMap.benchmark(run)
	run.map = main._map.to_dict()
	main._on_terminal_commit("commit")
	_check(fails, main.dawn_shown == 1, "winning fold did not hold and show its Dawn")
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	_check(fails, loaded != null, "winning Dawn checkpoint did not load")
	var vigil: VigilState = SaveService.load_vigil(VIGIL_PATH)
	var rewards: Array[String] = []
	for id: String in vigil.unlocks:
		if id.begins_with("card:") or id.begins_with("relic:"):
			rewards.append(id)
	rewards.sort()
	_check(fails, rewards == REWARD_IDS, "persisted rewards changed stable IDs: %s" % [rewards])
	if loaded != null and typeof(loaded.pending_dawn) == TYPE_DICTIONARY:
		var dawn_difference: String = Diff.deep_eq(
			StateBuild.jsonish(loaded.pending_dawn), StateBuild.jsonish(run.pending_dawn))
		_check(fails, dawn_difference.is_empty(),
			"loaded Dawn differs from the held terminal fold at %s" % dawn_difference)
		var events: Array = loaded.pending_dawn["events"]
		var titles: Array[String] = []
		for event: Dictionary in events:
			if event.get("kind") == "unlock":
				titles.append(str(event.get("title", "")))
		var screen: DawnScreen = DawnScreen.new(events, events.size())
		var labels: Array[String] = []
		for node: Node in screen.find_children("*", "Label", true, false):
			labels.append((node as Label).text)
		for name: String in NAMES[String(Locale.active.code)]:
			_check(fails, titles.count(name) == 1,
				"%s persisted Dawn should name %s exactly once: %s" % [Locale.active.code, name, titles])
			_check(fails, labels.count(name) == 1,
				"%s rebuilt Dawn should label %s exactly once" % [Locale.active.code, name])
		screen.free()
	else:
		_check(fails, false, "winning checkpoint owes no durable Dawn events")
	main.free()
