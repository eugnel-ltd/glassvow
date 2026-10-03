extends RefCounted
## The authored copy that closes a journey plays where it closes: each closer
## once, straight after its completing fight, while four panes are lit (and
## the two the act-2 boss win closes, in turn); the Unreadable Page's newest
## page read as its own scene; the Queue heard at the first Act IV crossing;
## the Eighth Omen's broken words after every waystone; and the Night Stall's
## lantern lines in the merchant's mouth.

const RUN_PATH: String = "user://test_quest_closers_run_v2.json"
const VIGIL_PATH: String = "user://test_quest_closers_vigil_v2.json"
const MapCompose: GDScript = preload("res://tests/test_map_compose.gd")
const LIT: Array[String] = ["paleOnes", "hollowLamplighter", "unreadablePage"]


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("quest_closers: %s" % what)


static func run(fails: Array[String]) -> void:
	var content: ContentDB = ContentDB.load_full()
	_closer_rules(fails, content)
	_boss_win_closers(fails, content)
	_shade_closer(fails, content)
	_page_scenes(fails, content)
	_queue_at_the_door(fails, content)
	_pool_looks(fails)
	_omen_echoes(fails, content)
	_stall_voice(fails, content)
	SaveService.clear(RUN_PATH)
	SaveService.clear_vigil(VIGIL_PATH)


## Staging law: a completed journey owes its closer at four lit panes, never
## below, never once heard, and never again once a past run has told it.
static func _closer_rules(fails: Array[String], content: ContentDB) -> void:
	var usurper: Array[String] = ["usurper"]
	var dim: Main = _boss_main(content, ["paleOnes"])
	dim.game.run.quest_completions = ["usurper"]
	_check(fails, not dim._stage_closer(usurper) and dim.game.run.pending_scene == null
			and dim.game.run.pool_beats.is_empty(),
		"a closer played with fewer than four panes lit")
	_dispose(dim)
	var lit: Main = _boss_main(content, LIT)
	var omen: Array[String] = ["eighthOmen"]
	lit.game.run.quest_completions = ["usurper"]
	_check(fails, not lit._stage_closer(omen), "an uncompleted journey owed its closer")
	_check(fails, lit._stage_closer(usurper)
			and _pending_scene(lit) == "line:closer.usurper",
		"a completed journey at four panes did not queue its closer")
	var draws: int = lit.game.run.pool_draws.size()
	lit.game.run.pending_scene = null
	_check(fails, lit._stage_closer(usurper)
			and _pending_scene(lit) == "line:closer.usurper"
			and lit.game.run.pool_draws.size() == draws,
		"a drawn but unheard closer was not replayed as drawn")
	lit.game.run.pending_scene = null
	lit._vigil.scenes_seen.append("line:closer.usurper")
	_check(fails, not lit._stage_closer(usurper), "a heard closer was queued again")
	_dispose(lit)
	var told: Main = _boss_main(content, LIT)
	told.game.run.quest_completions = ["usurper"]
	told._vigil.line_once.append("closer.usurper")
	_check(fails, not told._stage_closer(usurper), "a closer a past run told played again")
	_dispose(told)
	var after: Array[String] = PoolBeats.closers_after("usurper")
	_check(fails, after == ["eighthOmen"]
			and PoolBeats.closers_after("eighthOmen").is_empty()
			and PoolBeats.closers_after("ownShade").is_empty(),
		"the boss-win chain order is wrong (%s)" % str(after))


## The act-2 boss win that closes the Usurper and the Eighth Omen plays both
## closers in turn, each as a run scene in its own look, then the reward. Each
## step is a save the load contract accepts.
static func _boss_win_closers(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content, VigilState.QUEST_IDS)
	main.game.run.quest_completions = ["usurper", "eighthOmen"]
	main._on_combat_over("win")
	_check(fails, _playing(main, "line:closer.usurper"),
		"the act-2 boss win did not play the Usurper's closer")
	_check(fails, main.game.run.pending_reward != null, "the closer dropped the reward")
	_check(fails, _loads(content, "line:closer.usurper"),
		"the win with its closer owed is not a loadable save")
	var resumed: Main = _main(content, false)
	resumed._continue_run(SaveService.load_run(content, RUN_PATH))
	_check(fails, _playing(resumed, "line:closer.usurper"),
		"a resumed run did not replay the owed closer")
	_dispose(resumed)
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null:
		TreeReady.once(player)
		_check(fails, player._director.stage.has_actor("usurper"),
			"the Usurper's closer did not seat the Usurper")
		_check(fails, player._copy.line_label().text
				== Locale.active.t("content.quests.usurper.death"),
			"the Usurper's closer is not the authored line")
	main._on_scene_finished()
	_check(fails, _playing(main, "line:closer.eighthOmen"),
		"the Usurper's closer did not hand on to the Eighth Omen's")
	_check(fails, _loads(content, "line:closer.eighthOmen"),
		"the chained closer is not a loadable save")
	var omen: ScenePlayer = main._route_screen as ScenePlayer
	if omen != null:
		TreeReady.once(omen)
		var grade: StringName = omen._script.beats[0]["grade"]
		_check(fails, omen._copy.style == StageDirection.STYLE_TITLE and grade == &"inverted",
			"the Eighth Omen's closer is not a title card in the inverted grade")
	main._on_scene_finished()
	_check(fails, main.game.run.pending_scene == null and main._reward_screen != null,
		"the closers did not hand on to the reward")
	_check(fails, main._vigil.scenes_seen.has("line:closer.usurper")
			and main._vigil.scenes_seen.has("line:closer.eighthOmen"),
		"the heard closers were not remembered")
	_dispose(main)
	var early: Main = _boss_main(content, VigilState.QUEST_IDS)
	early.game.run.act = 1
	early.game.run.quest_completions = ["usurper"]
	early._on_combat_over("win")
	_check(fails, early.game.run.pool_beats.is_empty() and early.game.run.pending_scene == null,
		"a boss win outside act 2 played a closer")
	_dispose(early)
	var last: Main = _boss_main(content, LIT)
	last.game.run.quest_completions = ["eighthOmen"]
	last._on_combat_over("win")
	_check(fails, last.game.run.pending_run_end != null
			and _playing(last, "line:closer.eighthOmen"),
		"a run-ending act-2 win did not play its closer before the end")
	_check(fails, _loads(content, "line:closer.eighthOmen"),
		"a run end with its closer owed is not a loadable save")
	_dispose(last)


## The third shade out owes the Own Shade's closer; a shade short of it does not.
static func _shade_closer(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content, VigilState.QUEST_IDS)
	main.game.run.act = 1
	main.game.run.pending_quest_id = "ownShade"
	main.game.run.quest_completions = ["ownShade"]
	main._on_combat_over("win")
	_check(fails, _playing(main, "line:closer.ownShade"),
		"the Own Shade's completing fight did not play its closer")
	_check(fails, _loads(content, "line:closer.ownShade"),
		"the shade's closer is not a loadable save")
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null:
		TreeReady.once(player)
		_check(fails, player._copy.style == StageDirection.STYLE_WHISPER
				and player._director.stage.has_actor("shade"),
			"the Own Shade's closer is not whispered by the shade")
	_dispose(main)
	var partial: Main = _boss_main(content, VigilState.QUEST_IDS)
	partial.game.run.act = 1
	partial.game.run.pending_quest_id = "ownShade"
	partial._on_combat_over("win")
	_check(fails, partial.game.run.pool_beats.is_empty(),
		"a shade that did not complete the journey drew its closer")
	_dispose(partial)


## The act-2 boss win reads the page it turned, once, only while it is carried,
## and the closers it earned follow the page.
static func _page_scenes(fails: Array[String], content: ContentDB) -> void:
	var pages: Array = content.quests["unreadablePage"].get("pages", [])
	_check(fails, pages.size() == SceneScript.PAGE_COUNT,
		"the page scenes do not cover the %d authored pages" % pages.size())
	var zh: Locale = Locale.new(Locale.CODE_ZH_HANT)
	_check(fails, zh.set_language(Locale.CODE_ZH_HANT), "zh-Hant did not load")
	for i: int in range(pages.size()):
		var key: String = SceneScript.PAGE_KEY % i
		var en_text: String = Locale.new(Locale.CODE_EN).t(key)
		_check(fails, en_text != key and zh.t(key) != key and zh.t(key) != en_text,
			"page %d is not bilingual" % (i + 1))
	for bad: String in ["unreadable-page-0", "unreadable-page-6", "unreadable-page-01",
			"unreadable-page-x", "opening"]:
		_check(fails, SceneScript.quest_page(bad) == null, "%s built a page" % bad)
	for n: int in range(1, 6):
		var main: Main = _page_main(content, n, true)
		main._on_combat_over("win")
		var scene_id: String = "unreadable-page-%d" % n
		_check(fails, _playing(main, scene_id), "page %d was not read" % n)
		var player: ScenePlayer = main._route_screen as ScenePlayer
		if player != null:
			TreeReady.once(player)
			_check(fails, player._copy.line_label().text == Locale.active.t(
					SceneScript.PAGE_KEY % (n - 1)),
				"page %d is not its authored text" % n)
		_dispose(main)
	var seen: Main = _page_main(content, 2, true)
	seen._vigil.scenes_seen.append("unreadable-page-2")
	seen._on_combat_over("win")
	_check(fails, not _playing(seen, "unreadable-page-2"), "a read page was read again")
	_dispose(seen)
	var dropped: Main = _page_main(content, 3, false)
	dropped._on_combat_over("win")
	_check(fails, not _playing(dropped, "unreadable-page-3"),
		"a page was read without the page in the deck")
	_dispose(dropped)
	var both: Main = _page_main(content, 4, true)
	both.game.run.quest_completions = ["usurper"]
	both._on_combat_over("win")
	_check(fails, _playing(both, "unreadable-page-4"), "the page did not come first")
	both._on_scene_finished()
	_check(fails, _playing(both, "line:closer.usurper"),
		"the closer did not follow the page")
	_dispose(both)


## The first Act IV crossing lets the Queue be heard after act4-entry; a repeat
## crossing does not.
static func _queue_at_the_door(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _crossing_main(content)
	main._on_boss_relic_chosen("")
	_check(fails, _playing(main, "act4-entry"), "the first crossing did not play act4-entry")
	main._on_scene_finished()
	_check(fails, _playing(main, "line:payoff.mirror")
			and main.game.run.pool_draws.has("payoff.mirror"),
		"the Queue was not heard after the first crossing")
	_check(fails, _loads(content, "line:payoff.mirror"),
		"the Queue's owed line is not a loadable save")
	var player: ScenePlayer = main._route_screen as ScenePlayer
	if player != null:
		TreeReady.once(player)
		_check(fails, player._copy.style == StageDirection.STYLE_CHORUS,
			"the Queue does not speak as a chorus")
	main._on_scene_finished()
	_check(fails, main.game.run.pending_scene == null and main._map_screen is WorldMapScreen,
		"the Queue did not hand on to the Act IV map")
	_dispose(main)
	var late: Main = _crossing_main(content)
	late._vigil.scenes_seen.append("act4-entry")
	late._on_boss_relic_chosen("")
	_check(fails, _playing(late, "unsealing-short"), "a repeat crossing did not play the door")
	late._on_scene_finished()
	_check(fails, _playing(late, "line:payoff.mirror"),
		"a Vigil that crossed before the Queue could speak never hears it")
	_dispose(late)
	var heard: Main = _crossing_main(content)
	heard._vigil.scenes_seen.append("act4-entry")
	heard._vigil.scenes_seen.append("line:payoff.mirror")
	heard._on_boss_relic_chosen("")
	heard._on_scene_finished()
	_check(fails, heard.game.run.pending_scene == null and heard._map_screen is WorldMapScreen,
		"a heard Queue spoke again at a later crossing")
	_dispose(heard)
	var told: Main = _crossing_main(content)
	told._vigil.scenes_seen.append("act4-entry")
	told._vigil.line_once.append("payoff.mirror")
	told._on_boss_relic_chosen("")
	told._on_scene_finished()
	_check(fails, not told.game.run.pool_beats.has(PoolBeats.KEY_L3),
		"a Queue a past run told spoke again")
	_dispose(told)


## Every slot look parses into the vocabulary, and an unregistered voice with
## a look speaks in it instead of whispering.
static func _pool_looks(fails: Array[String]) -> void:
	for slot: String in SceneScript.POOL_LOOKS:
		var look: Dictionary = SceneScript.POOL_LOOKS[slot]
		var script: SceneScript = SceneScript.pool_beat("", slot)
		var grade: StringName = script.beats[0]["grade"]
		var ambient: StringName = script.beats[0]["ambient"]
		_check(fails, grade == StringName(str(look.get("grade", "none")))
				and ambient == StringName(str(look.get("ambient", "motes"))),
			"%s look did not reach its beat" % slot)
	var plain: SceneScript = SceneScript.pool_beat("", "waystone")
	var plain_ambient: StringName = plain.beats[0]["ambient"]
	_check(fails, plain_ambient == &"motes" and plain.line_count() == 1,
		"an ordinary slot lost the quiet motes")


## Under the Eighth Omen a waystone's echo is followed by the omen's words,
## one per row in turn; under any other omen, or off a waystone, nothing.
static func _omen_echoes(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content, VigilState.QUEST_IDS)
	main.game.run.act = 0
	main.game.run.omens = ["eighthOmen", null, null]
	for row: int in [0, 1, 5]:
		main._map.nodes[0].row = row
		var key: String = main._omen_echo_key("waystone:n0")
		_check(fails, key == "content.quests.eighthOmen.waystoneEchoes.%d" % (row % 4),
			"row %d echoed %s" % [row, key])
	_check(fails, main._omen_echo_key("hearth:start").is_empty(),
		"a hearth line carried the omen's words")
	main.game.run.omens = ["ashfall", null, null]
	_check(fails, main._omen_echo_key("waystone:n0").is_empty(),
		"another omen carried the Eighth Omen's words")
	# The tail line is resumable: the cursor rides the pending beat.
	main.game.run.omens = ["eighthOmen", null, null]
	main._map.nodes[0].row = 2
	main.game.run.pending_pool = PoolBeats._pending(PoolBeats.SLOT_WAYSTONE,
		"pool.waystone.w60", "waystone:n0", PoolBeats.RESUME_NODE)
	main._show_pending_pool()
	var echo_player: ScenePlayer = main._route_screen as ScenePlayer
	_check(fails, echo_player != null and echo_player._script.line_count() == 2
			and echo_player._cursor == 0,
		"the waystone beat under the omen is not the echo then the words")
	if echo_player != null:
		main._on_pool_advance(echo_player)
	_check(fails, int(float(str(PoolBeats.pending_of(main.game.run).get("cursor", 0)))) == 1,
		"advancing to the omen's words did not persist the cursor")
	main._show_pending_pool()
	var rebuilt: ScenePlayer = main._route_screen as ScenePlayer
	_check(fails, rebuilt != null and rebuilt._cursor == 1,
		"a rebuilt waystone beat replayed the echo before the omen's words")
	if rebuilt != null:
		TreeReady.once(rebuilt)
		_check(fails, rebuilt._copy.line_label().text == Locale.active.t(
				"content.quests.eighthOmen.waystoneEchoes.2")
				and not rebuilt._director.front_fx.active(),
			"the rebuilt beat is not the omen's words, standing without effects")
	_dispose(main)
	var tail: Array[Dictionary] = [{
		"key": "content.quests.eighthOmen.waystoneEchoes.1", "style": "title"}]
	var script: SceneScript = SceneScript.pool_beat("", "waystone", tail)
	var row_d: Dictionary = {"speaker": "walker", "en": "An echo.", "zh": "迴聲。"}
	var first: ScenePlayer = ScenePlayer.new(script, 0, StageShape.IDENTITY, null, row_d)
	first.instant = true
	TreeReady.once(first)
	_check(fails, first._copy.line_label().text == "An echo."
			and first._copy.style == StageDirection.STYLE_WHISPER,
		"the waystone's own echo did not play first")
	first.free()
	var second: ScenePlayer = ScenePlayer.new(script, 1, StageShape.IDENTITY, null, row_d)
	second.instant = true
	TreeReady.once(second)
	_check(fails, second._copy.line_label().text
			== Locale.active.t("content.quests.eighthOmen.waystoneEchoes.1")
			and second._copy.style == StageDirection.STYLE_TITLE,
		"the omen's words did not follow the echo as a title")
	second.free()


## The stall speaks the lantern's lines: its price out of reach, and the
## throne told the moment it is sold; otherwise the greeting stands.
static func _stall_voice(fails: Array[String], content: ContentDB) -> void:
	var main: Main = _boss_main(content, VigilState.QUEST_IDS)
	main.game.run.act = 1
	main.game.run.quests["usurper"]["state"] = "armed"
	main.game.run.player.gold = 100
	_check(fails, main._shop_line(false) == Locale.active.t("content.quests.usurper.poor"),
		"a short purse did not hear the lantern's price")
	main.game.run.player.gold = 700
	_check(fails, main._shop_line(false).is_empty(), "a full purse was turned away")
	_check(fails, main._shop_line(true) == Locale.active.t("content.quests.usurper.bought"),
		"the sale did not tell the throne")
	main.game.run.quests["usurper"]["state"] = "dormant"
	main.game.run.player.gold = 100
	_check(fails, main._shop_line(false).is_empty(), "the stall quoted an unoffered lantern")
	_dispose(main)
	var stall: ShopScreen = ShopScreen.new({}, 0, content)
	stall.say(Locale.active.t("content.quests.usurper.poor"))
	_check(fails, stall._say.text == Locale.active.t("content.quests.usurper.poor"),
		"the stall did not speak the line")
	stall.say("")
	_check(fails, stall._say.text == Locale.active.t("ui.shop.greeting"),
		"an empty line did not restore the greeting")
	stall.free()


static func _run(content: ContentDB, shards: Array[String], act: int) -> RunState:
	var vigil: VigilState = VigilState.blank()
	for id: String in shards:
		vigil.quests[id]["state"] = "complete"
		vigil.shards.append(id)
	var run_state: RunState = RunState.new_run(content, 56501, "run-565-closers", {
		"quests": vigil.quests.duplicate(true),
		"shards": vigil.shards.duplicate(),
	})
	run_state.act = act
	return run_state


## With all six lit act 2 is not the last act, so the win takes the reward
## branch; with fewer it ends the run.
static func _boss_main(content: ContentDB, shards: Array[String]) -> Main:
	var main: Main = _main(content)
	var run_state: RunState = _run(content, shards, 2)
	var map: WorldMap = WorldMap.new()
	map.nodes.append(MapNode.make("boss", ["sovereign"], 0))
	map.at = 0
	run_state.node_id = map.nodes[0].id
	run_state.map = map.to_dict()
	run_state.pending_combat = "boss"
	run_state.pending_enemy_ids = ["sovereign"]
	main.game = GlassvowGame.new(content, run_state)
	main._map = map
	main.game.cb = CombatState.new()
	main.game.cb.kind = &"boss"
	return main


static func _page_main(content: ContentDB, progress: int, carried: bool) -> Main:
	var main: Main = _boss_main(content, VigilState.QUEST_IDS)
	var page: Dictionary = main.game.run.quests["unreadablePage"]
	page["state"] = "complete" if progress >= 5 else "revealed"
	page["progress"] = progress
	if carried:
		main.game.run.player.deck.append(
			CardInst.new(main.game.run.next_uid(), &"unreadablePage", false))
	return main


static func _crossing_main(content: ContentDB) -> Main:
	var main: Main = _main(content)
	var run_state: RunState = _run(content, VigilState.QUEST_IDS, 2)
	var map: WorldMap = WorldMap.for_run(run_state, content)
	map.at = -1
	run_state.map = map.to_dict()
	main.game = GlassvowGame.new(content, run_state)
	main._map = map
	return main


static func _pending_scene(main: Main) -> String:
	var pending_v: Variant = main.game.run.pending_scene
	if typeof(pending_v) != TYPE_DICTIONARY:
		return ""
	var pending: Dictionary = pending_v
	return str(pending.get("id", ""))


## The stored run passes the load contract and owes `scene_id`.
static func _loads(content: ContentDB, scene_id: String) -> bool:
	var loaded: RunState = SaveService.load_run(content, RUN_PATH)
	if loaded == null or typeof(loaded.pending_scene) != TYPE_DICTIONARY:
		return false
	var pending: Dictionary = loaded.pending_scene
	return str(pending.get("id", "")) == scene_id


static func _playing(main: Main, scene_id: String) -> bool:
	var player: ScenePlayer = main._route_screen as ScenePlayer
	return player != null and player._script.id == scene_id


static func _main(content: ContentDB, fresh: bool = true) -> Main:
	if fresh:
		SaveService.clear(RUN_PATH)
		SaveService.clear_vigil(VIGIL_PATH)
	var main: Main = Main.new()
	TestProfile.install(main, RUN_PATH, VIGIL_PATH)
	main._map_layout_compile = MapCompose.fake_layout_compile()
	main.content = content
	main._vigil.scenes_seen.append("opening")
	main._transitions = TransitionLayer.new()
	main._transitions.instant = true
	main.add_child(main._transitions)
	main._music = MusicBus.new()
	main.add_child(main._music)
	main._sfx_bus = SfxBus.new()
	main.add_child(main._sfx_bus)
	return main


static func _dispose(main: Main) -> void:
	main._clear_route()
	for child: Node in main.get_children():
		child.free()
	main.free()
