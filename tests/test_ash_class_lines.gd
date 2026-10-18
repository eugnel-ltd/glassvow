extends RefCounted
## #544 A7: aspect selection, class once accounting and legacy v2 paths.
const COPY: Dictionary = {
	"flame.ashwarden.hearth": [
		"它燒得慢，燒得久。",
		"It burns slow, and it burns long."
	],
	"flame.ashwarden.steady": [
		"灰下的火，認得你了。",
		"Under the ash, the fire knows you now."
	],
	"flame.ashwarden.true": [
		"別的都燒成了灰，只剩一種火。",
		"Everything else has burned to ash. One fire is left."
	],
	"flame.ashwarden.soot": [
		"煙多於火。",
		"More smoke than fire."
	],
	"flame.ashwarden.sootDeath": [
		"你的火從來只有煙。",
		"Your fire was only ever smoke."
	],
	"flame.ashwarden.fringe": [
		"煙裏有另一種顏色。",
		"There is another colour in the smoke."
	],
	"codex.lantern.smolder": [
		"灰綠的火伏得低，在灰下燒得最久。",
		"An ash-green fire lies low, and lasts longest under the ash."
	],
	"codex.lantern.hand": [
		"明黃的火分出許多火尖，像一隻手；手裏握着的越多，它燒得越亮。",
		"A candle-yellow fire parts into many tips, like a hand; the more the hand holds, the brighter it burns."
	],
	"codex.lantern.endure": [
		"珠光的火又直又靜，風來了也不倒。",
		"A pearl fire stands straight and still, and does not fall when the wind comes."
	]
}
const Stagecraft: GDScript = preload("res://tests/test_stagecraft.gd")
const ASH_PREFIX: String = "flame.ashwarden."


static func _check(fails: Array[String], ok: Variant, message: String) -> void:
	if ok != true:
		fails.append("ash class lines: " + message)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full(false)
	_conditions(content, fails)
	_copy(content, fails)
	_hearth(content, fails)
	_readings_and_once(content, fails)
	_legacy_falls(content, fails)
	_promised_replay(content, fails)
	_stagecraft_once(content, fails)


static func _state(content: ContentDB, id: String, aspect: int,
		cards: Array[String] = []) -> RunState:
	var state: RunState = RunState.new_run(content, 54407, id, {"aspect": aspect})
	if not cards.is_empty():
		state.player.deck.clear()
		for card: String in cards:
			state.player.deck.append(CardInst.new(state.next_uid(), StringName(card)))
	return state


static func _conditions(content: ContentDB, fails: Array[String]) -> void:
	var parsed: Dictionary = LineTable.parse_conditions("aspect=1 shards>=1")
	var ash: RunState = _state(content, "ash-context", 1)
	var dusk: RunState = _state(content, "dusk-context", 0)
	var ctx: Dictionary = LineTable.context(ash, 1)
	_check(fails, parsed["ok"] == true and ctx.get("aspect") == 1
			and PoolBeats.context_of(ash).get("aspect") == 1,
		"aspect grammar or shared context is absent")
	_check(fails, LineTable.conditions_match(parsed["conditions"], ctx)
			and not LineTable.conditions_match(parsed["conditions"], LineTable.context(dusk, 1))
			and not LineTable.conditions_match(parsed["conditions"], {"shards": 1})
			and LineTable.specificity(parsed["conditions"]) == 2,
		"aspect condition matched the wrong or missing class, or lost specificity")
	for clause: String in ["aspect=-1", "aspect=ashwarden", "aspect=1 aspect=0", "aspect=1.0"]:
		_check(fails, LineTable.parse_conditions(clause)["ok"] == false,
			"malformed aspect condition accepted: " + clause)
	_check(fails, not ClassScope.admits(content, 1, ["aspect2"]),
		"A7 changed the Ash deferral gate")


static func _copy(content: ContentDB, fails: Array[String]) -> void:
	for id: String in COPY:
		var row: Dictionary = LineTable.row_by_id(content.line_table, id)
		_check(fails, LineTable.text(row, true) == COPY[id][0]
				and LineTable.text(row, false) == COPY[id][1] and row.get("once") == true,
			"supplied bilingual once-only copy changed: " + id)
		_check(fails, LineTable.conditions_match(row.get("conditions"), {"aspect": 1})
				and not LineTable.conditions_match(row.get("conditions"), {"aspect": 0}),
			"Ash row leaks into Dusk: " + id)
	var dusk: RunState = _state(content, "dusk-rows", 0)
	var ash: RunState = _state(content, "ash-rows", 1)
	for slot: String in FlameLines.SPOKEN + [FlameLines.SLOT_SOOT_DEATH]:
		var d: Dictionary = PoolBeats.draw(dusk, VigilState.blank(), content, slot, slot)
		var a: Dictionary = PoolBeats.draw(ash, VigilState.blank(), content, slot, slot)
		_check(fails, str(d.get("id")) == slot
				and str(a.get("id")) == ASH_PREFIX + slot.trim_prefix("flame."),
			"shared slot did not select its class row: " + slot)


static func _hearth(content: ContentDB, fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	vigil.scenes_seen.append("opening")
	var ash: RunState = _state(content, "first-ash-hearth", 1)
	# Other specific hearth conditions already match when Ash is unlocked.
	ash.shards.append("paleOnes")
	ash.quests["hollowLamplighter"] = {"state": "armed", "progress": 1}
	var row: Dictionary = PoolBeats.stage(ash, vigil, content,
		PoolBeats.SLOT_HEARTH, PoolBeats.KEY_START, PoolBeats.RESUME_MAP)
	_check(fails, str(row.get("id")) == ASH_PREFIX + "hearth"
			and str(row.get("speaker")) == "keeper", "first Ash hearth did not win selection")
	var cursor: int = ash.rng_state()
	var loaded: RunState = RunState.from_save_dict(ash.to_save_dict(), content)
	_check(fails, loaded != null and loaded.aspect == 1
			and PoolBeats.row_of(content.line_table, loaded) == row,
		"first Ash hearth did not survive a v2 save")
	if loaded != null:
		_check(fails, PoolBeats.stage(loaded, vigil, content, PoolBeats.SLOT_HEARTH,
				PoolBeats.KEY_START, PoolBeats.RESUME_MAP) == row and loaded.rng_state() == cursor,
			"replayed hearth changed its promised row or consumed RNG")
	_check(fails, vigil.commit_run(ash, "abandon", content), "hearth run did not fold")
	var next: RunState = _state(content, "later-ash-hearth", 1)
	var later: Dictionary = PoolBeats.stage(next, vigil, content,
		PoolBeats.SLOT_HEARTH, PoolBeats.KEY_START, PoolBeats.RESUME_MAP)
	_check(fails, str(later.get("id")).begins_with("pool.hearth."),
		"first Ash hearth repeated instead of returning to the normal pool")
	var player: ScenePlayer = ScenePlayer.new(SceneScript.pool_beat("", "hearth"),
		0, StageShape.IDENTITY, null, row)
	player.instant = true
	TreeReady.once(player)
	_check(fails, player._copy.line_label().text
			== LineTable.text(row, Locale.active.code == Locale.CODE_ZH_HANT)
			and player._director.stage.has_actor("keeper"),
		"the existing hearth surface did not speak the Keeper's Ash row")
	player.free()


static func _draw_owed(game: GlassvowGame, vigil: VigilState) -> Array[String]:
	game.flame_events(true)
	var owed: Array[String] = game.take_flame_lines()
	for slot: String in owed:
		PoolBeats.draw(game.run, vigil, game.content, slot, slot)
	return owed


static func _readings_and_once(content: ContentDB, fails: Array[String]) -> void:
	var vigil: VigilState = VigilState.blank()
	var decks: Array = [
		["smolder", ["venomStrike", "venomStrike", "venomStrike", "venomStrike", "preparation", "preparation"]],
		["hand", ["preparation", "preparation", "preparation", "preparation", "preparation"]],
		["endure", ["bulwark", "bulwark", "bulwark", "bulwark", "bulwark"]],
	]
	for case: Array in decks:
		var cards: Array[String] = []
		var source_cards: Array = case[1]
		cards.assign(source_cards)
		var state: RunState = _state(content, "ash-colour-" + str(case[0]), 1, cards)
		var game: GlassvowGame = GlassvowGame.new(content, state)
		_check(fails, FlameLines.codex(content, vigil, state).size() == vigil.line_once.filter(
				func(id: String) -> bool: return id.begins_with(FlameLines.CODEX_PREFIX)).size(),
			"codex disclosed an unseen colour")
		var owed: Array[String] = _draw_owed(game, vigil)
		_check(fails, owed.has(FlameLines.CODEX_PREFIX + str(case[0]))
				and state.pool_draws.has(FlameLines.CODEX_PREFIX + str(case[0]))
				and not state.pool_draws.has("flame.steady") and not state.pool_draws.has("flame.true"),
			"real Ash reading did not reveal only its colour and class lines")
		if str(case[0]) == "smolder":
			_check(fails, owed == [FlameLines.SLOT_STEADY, FlameLines.SLOT_FRINGE,
					"codex.lantern.smolder"], "real Steady/fringe transition changed")
			var main: Main = Main.new()
			TestProfile.install(main)
			main.content = content
			main.game = game
			_check(fails, main._stage_flame_line()
					and str(state.pending_scene.get("id")) == "line:flame.ashwarden.steady",
				"Main did not stage the Ash once ID on the shared whisper slot")
			state.pending_scene = null
			main.free()
		_check(fails, vigil.commit_run(state, "abandon", content), "Ash colour did not fold")
	var loaded: VigilState = VigilState.from_dict(vigil.to_dict())
	_check(fails, loaded != null and FlameLines.codex(content, loaded, null).size() == 3
			and loaded.line_once.has(ASH_PREFIX + "steady")
			and loaded.line_once.has(ASH_PREFIX + "true"), "Ash heard state did not persist")
	var dusk: RunState = _state(content, "dusk-after-ash", 0)
	_check(fails, str(PoolBeats.draw(dusk, vigil, content,
			FlameLines.SLOT_STEADY, FlameLines.SLOT_STEADY).get("id")) == "flame.steady",
		"Ash consumed Dusk's once accounting")
	var again: RunState = _state(content, "ash-after-ash", 1)
	_check(fails, PoolBeats.draw(again, vigil, content,
			FlameLines.SLOT_STEADY, FlameLines.SLOT_STEADY).is_empty(), "Ash repeated across runs")


static func _legacy_falls(content: ContentDB, fails: Array[String]) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/ashwarden_v2_run.json"))
	var legacy: RunState = RunState.from_save_dict(raw, content)
	_check(fails, legacy != null and legacy.aspect == 1, "historical Ash v2 fixture no longer loads")
	if legacy == null:
		return
	# An evolved pre-deferral run: six existing cards, two of each way.
	legacy.player.deck.clear()
	for id: String in ["venomStrike", "venomStrike", "preparation", "preparation", "bulwark", "bulwark"]:
		legacy.player.deck.append(CardInst.new(legacy.next_uid(), StringName(id)))
	_check(fails, str(Flame.read(content, legacy)["tier"]) == Flame.TIER_SOOT,
		"legacy fall control does not actually read Soot")
	var legacy_game: GlassvowGame = GlassvowGame.new(content, legacy)
	legacy_game.flame_events(true)
	_check(fails, legacy_game.take_flame_lines() == [FlameLines.SLOT_SOOT],
		"real Ash Soot transition did not owe its whisper")
	var vigil: VigilState = VigilState.blank()
	_check(fails, vigil.commit_run(legacy, "death", content)
			and vigil.defeat_epitaphs == [ASH_PREFIX + "sootDeath"]
			and not vigil.line_once.has("flame.sootDeath"),
		"actual legacy Ash Soot death consumed Dusk's epitaph")
	_check(fails, vigil.commit_run(legacy, "death", content) and vigil.defeat_epitaphs.size() == 1,
		"terminal receipt replay wrote another epitaph")
	var dusk: RunState = _state(content, "dusk-soot-after-ash", 0,
		["uppercut", "preparation", "warCry", "uppercut", "preparation", "warCry"])
	_check(fails, str(Flame.read(content, dusk)["tier"]) == Flame.TIER_SOOT
			and vigil.commit_run(dusk, "death", content)
			and vigil.defeat_epitaphs == [ASH_PREFIX + "sootDeath", "flame.sootDeath"],
		"Dusk lost its original Soot-death epitaph after a legacy Ash fall")
	var later: RunState = RunState.from_save_dict(raw, content)
	later.run_id = "later-ash-soot-fall"
	later.player.deck = legacy.player.deck.duplicate()
	_check(fails, vigil.commit_run(later, "death", content)
			and vigil.defeat_epitaphs[-1].begins_with("pool.loss.e"),
		"later Ash Soot fall repeated its once epitaph")


static func _promised_replay(content: ContentDB, fails: Array[String]) -> void:
	var legacy: RunState = _state(content, "already-promised-dusk-line", 1)
	legacy.pool_beats[FlameLines.SLOT_STEADY] = "flame.steady"
	legacy.pool_draws.append("flame.steady")
	var loaded: RunState = RunState.from_save_dict(legacy.to_save_dict(), content)
	_check(fails, loaded != null, "v2 promised legacy line rejected")
	if loaded == null:
		return
	var cursor: int = loaded.rng_state()
	_check(fails, str(PoolBeats.draw(loaded, VigilState.blank(), content,
			FlameLines.SLOT_STEADY, FlameLines.SLOT_STEADY).get("id")) == "flame.steady"
			and loaded.rng_state() == cursor and loaded.pool_draws == ["flame.steady"],
		"aspect filtering rewrote a saved promised ID or consumed RNG")


## Main's actual victory, line scene completion, store and reward route.
static func _stagecraft_once(content: ContentDB, fails: Array[String]) -> void:
	var main: Main = Stagecraft._flame_main(content, "monster", 0)
	var state: RunState = main.game.run
	state.aspect = 1
	state.player.deck.clear()
	for id: String in ["venomStrike", "venomStrike", "venomStrike", "venomStrike", "preparation", "preparation"]:
		state.player.deck.append(CardInst.new(state.next_uid(), StringName(id)))
	main.game.flame_events(true)
	main._on_combat_over("win")
	_check(fails, Stagecraft._flame_playing(main, "line:flame.ashwarden.steady"),
		"actual victory did not play Ash Steady")
	main._on_scene_finished()
	_check(fails, Stagecraft._flame_playing(main, "line:flame.ashwarden.fringe"),
		"Ash fringe did not follow Ash Steady")
	main._on_scene_finished()
	_check(fails, state.pending_scene == null and main._reward_screen != null
			and main._vigil.scenes_seen.has("line:flame.ashwarden.steady")
			and main._vigil.scenes_seen.has("line:flame.ashwarden.fringe")
			and not main._vigil.scenes_seen.has("line:flame.steady"),
		"Ash completion failed its own scene once flags or reward handoff")
	var saved: RunState = SaveService.load_run(content, Stagecraft.RUN_PATH)
	_check(fails, saved != null and saved.aspect == 1
			and saved.pool_draws.has(ASH_PREFIX + "steady")
			and saved.pool_draws.has("codex.lantern.smolder"),
		"actual scene store lost Ash once/codex accounting")
	Stagecraft._flame_dispose(main)
	SaveService.clear(Stagecraft.RUN_PATH)
	SaveService.clear_vigil(Stagecraft.VIGIL_PATH)
